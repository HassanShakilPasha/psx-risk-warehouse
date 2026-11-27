# Source CSVs -> RAW -> STAGING in PostgreSQL.
# Connection comes from environment variables: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD.
# Usage: python run_etl.py
import os

import psycopg2

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "02_Data", "raw_data")

SOURCES = [
    ("psx_market_summary.csv", "project_staging.raw_market_summary"),
    ("psx_sectors.csv", "project_staging.raw_sector"),
    ("sbp_policy_rate.csv", "project_staging.raw_policy_rate"),
]


def run_sql_file(cur, name):
    print("Running", name)
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        cur.execute(f.read())


def load_raw(cur, file_name, table):
    cur.execute("INSERT INTO project_staging.etl_batch (source_name, status) VALUES (%s, 'RUNNING') RETURNING batch_id", (file_name,))
    batch_id = cur.fetchone()[0]
    with open(os.path.join(DATA, file_name), encoding="utf-8") as f:
        columns = f.readline().strip().split(",")
        cur.copy_expert(f"COPY {table} ({', '.join(columns)}) FROM STDIN WITH (FORMAT csv)", f)
    cur.execute(f"UPDATE {table} SET batch_id = %s WHERE batch_id IS NULL", (batch_id,))
    rows = cur.rowcount
    cur.execute("UPDATE project_staging.etl_batch SET rows_read = %s WHERE batch_id = %s", (rows, batch_id))
    print(f"  {file_name}: {rows} rows -> {table} (batch {batch_id})")


def main():
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "dwbi_project"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD"),
    )
    cur = conn.cursor()
    try:
        for name in ["00_schemas.sql", "01_raw_tables.sql", "02_staging_tables.sql"]:
            run_sql_file(cur, name)
        conn.commit()

        # Full reload: raw is replaced with the current files each run.
        print("Loading RAW")
        for _, table in SOURCES:
            cur.execute(f"TRUNCATE {table} RESTART IDENTITY")
        for file_name, table in SOURCES:
            load_raw(cur, file_name, table)
        conn.commit()

        run_sql_file(cur, "03_staging_load.sql")
        cur.execute("""
            UPDATE project_staging.etl_batch e
            SET rows_rejected = (SELECT COUNT(*) FROM project_staging.rejected_rows r WHERE r.batch_id = e.batch_id),
                status = 'SUCCESS'
            WHERE status = 'RUNNING'
        """)
        conn.commit()

        cur.execute("SELECT batch_id, source_name, rows_read, rows_rejected, status FROM project_staging.etl_batch WHERE loaded_at > now() - interval '1 hour' ORDER BY batch_id")
        for row in cur.fetchall():
            print(row)
    except Exception:
        conn.rollback()
        cur.execute("UPDATE project_staging.etl_batch SET status = 'FAILED' WHERE status = 'RUNNING'")
        conn.commit()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
