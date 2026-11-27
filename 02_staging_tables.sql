-- STAGING layer: clean, typed copy of raw. One row per business key, no surrogate keys yet.

-- Returns the number in a text value, or NULL if it is blank or not a number (commas removed).
CREATE OR REPLACE FUNCTION project_staging.to_num(v TEXT) RETURNS NUMERIC AS $$
 SELECT CASE WHEN REPLACE(TRIM(v), ',', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
 THEN REPLACE(TRIM(v), ',', '')::NUMERIC END
$$ LANGUAGE sql IMMUTABLE;

CREATE TABLE IF NOT EXISTS project_staging.stg_market_summary (
 trade_date DATE NOT NULL,
 symbol TEXT NOT NULL,
 sector_code TEXT,
 company_name TEXT,
 open_price NUMERIC(12,4),
 high_price NUMERIC(12,4),
 low_price NUMERIC(12,4),
 close_price NUMERIC(12,4) NOT NULL,
 ldcp NUMERIC(12,4),
 volume BIGINT,
 source_row_id BIGINT,
 batch_id INT,
 PRIMARY KEY (symbol, trade_date)
);

CREATE TABLE IF NOT EXISTS project_staging.stg_sector (
 sector_code TEXT PRIMARY KEY,
 sector_name TEXT NOT NULL,
 security_type TEXT,
 source_row_id BIGINT,
 batch_id INT
);

CREATE TABLE IF NOT EXISTS project_staging.stg_policy_rate (
 effective_date DATE PRIMARY KEY,
 policy_rate NUMERIC(5,2) NOT NULL,
 change_bps INT,
 direction TEXT,
 source_row_id BIGINT,
 batch_id INT
);

-- Control tables
CREATE TABLE IF NOT EXISTS project_staging.rejected_rows (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 source_table TEXT NOT NULL,
 source_row_id BIGINT,
 reason TEXT NOT NULL,
 batch_id INT,
 rejected_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_staging.load_watermark (
 pipeline_name TEXT PRIMARY KEY,
 last_loaded_date DATE
);
