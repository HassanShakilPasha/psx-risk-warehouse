-- RAW layer: data exactly as it arrives. Same columns as the CSV header, all TEXT,
-- no keys, no cleaning. raw_row_id traces every row back to its place in the file.

CREATE TABLE IF NOT EXISTS project_staging.etl_batch (
 batch_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 source_name TEXT NOT NULL,
 loaded_at TIMESTAMPTZ DEFAULT now(),
 rows_read BIGINT,
 rows_rejected BIGINT,
 status TEXT
);

CREATE TABLE IF NOT EXISTS project_staging.raw_market_summary (
 raw_row_id BIGINT GENERATED ALWAYS AS IDENTITY,
 batch_id INT,
 trade_date TEXT,
 symbol TEXT,
 sector_code TEXT,
 company_name TEXT,
 open TEXT,
 high TEXT,
 low TEXT,
 close TEXT,
 volume TEXT,
 ldcp TEXT,
 extra_1 TEXT,
 extra_2 TEXT,
 extra_3 TEXT,
 source_file TEXT
);

CREATE TABLE IF NOT EXISTS project_staging.raw_sector (
 raw_row_id BIGINT GENERATED ALWAYS AS IDENTITY,
 batch_id INT,
 sector_code TEXT,
 sector_name TEXT,
 security_type TEXT
);

CREATE TABLE IF NOT EXISTS project_staging.raw_policy_rate (
 raw_row_id BIGINT GENERATED ALWAYS AS IDENTITY,
 batch_id INT,
 effective_date TEXT,
 policy_rate TEXT,
 previous_rate TEXT,
 change_bps TEXT
);
