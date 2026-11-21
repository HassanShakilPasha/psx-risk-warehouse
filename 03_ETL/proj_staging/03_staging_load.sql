-- Raw -> Staging. Full reload: staging is emptied and rebuilt from raw every run.
TRUNCATE project_staging.stg_market_summary, project_staging.stg_sector, project_staging.stg_policy_rate;
TRUNCATE project_staging.rejected_rows RESTART IDENTITY;

----------------------------------------------------------------------
-- 1. Market summary
----------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_market;
CREATE TEMP TABLE tmp_market AS
SELECT raw_row_id,
 batch_id,
 TO_DATE(SUBSTRING(source_file FROM '[0-9]{4}-[0-9]{2}-[0-9]{2}'), 'YYYY-MM-DD') AS trade_date,
 UPPER(TRIM(symbol)) AS symbol,
 NULLIF(TRIM(sector_code), '') AS sector_code,
 -- remove the markers PSX appends to the name (XD, XB, XR, SPOT, also glued like 'Shams TextileXD')
 -- and trailing dots/dashes, then collapse spaces and use consistent casing
 INITCAP(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(company_name, '(XD|XB|XR|SPOT|[\s.\-])+$', '', 'i'), '\s+', ' ', 'g'))) AS company_name,
 project_staging.to_num(open) AS open_price,
 project_staging.to_num(high) AS high_price,
 project_staging.to_num(low) AS low_price,
 project_staging.to_num(close) AS close_price,
 project_staging.to_num(ldcp) AS ldcp,
 COALESCE(project_staging.to_num(volume), 0)::BIGINT AS volume,
 CAST(NULL AS TEXT) AS reason
FROM project_staging.raw_market_summary;

UPDATE tmp_market SET reason = CASE
 WHEN symbol IS NULL OR symbol = '' THEN 'missing symbol'
 WHEN trade_date IS NULL THEN 'no trade date in source file name'
 WHEN close_price IS NULL THEN 'close price missing or not numeric'
 WHEN sector_code IS NULL OR sector_code IN ('36', '3610') THEN 'out of scope: debt instrument'
 WHEN symbol LIKE '%PS' THEN 'out of scope: preference share'
 -- futures carry a contract month after a dash (e.g. PSO-CAUG); ETFs use a dash too (MZNP-ETF) and stay
 WHEN symbol LIKE '%-%' AND symbol NOT LIKE '%-ETF' THEN 'out of scope: futures contract'
END;

-- duplicates of (symbol, trade_date): the latest row in the file wins
UPDATE tmp_market t SET reason = 'duplicate (symbol, trade_date)'
FROM (
 SELECT raw_row_id, ROW_NUMBER() OVER (PARTITION BY symbol, trade_date ORDER BY raw_row_id DESC) AS rn
 FROM tmp_market
 WHERE reason IS NULL
) d
WHERE t.raw_row_id = d.raw_row_id AND d.rn > 1;

INSERT INTO project_staging.rejected_rows (source_table, source_row_id, reason, batch_id)
SELECT 'raw_market_summary', raw_row_id, reason, batch_id
FROM tmp_market
WHERE reason IS NOT NULL;

INSERT INTO project_staging.stg_market_summary (trade_date, symbol, sector_code, company_name, open_price, high_price, low_price, close_price, ldcp, volume, original_sector_code, source_row_id, batch_id)
SELECT trade_date, symbol, sector_code, company_name, open_price, high_price, low_price, close_price, ldcp, volume, sector_code, raw_row_id, batch_id
FROM tmp_market
WHERE reason IS NULL;

----------------------------------------------------------------------
-- 2. Sectors
----------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_sector;
CREATE TEMP TABLE tmp_sector AS
SELECT raw_row_id,
 batch_id,
 NULLIF(TRIM(sector_code), '') AS sector_code,
 INITCAP(REGEXP_REPLACE(TRIM(sector_name), '\s+', ' ', 'g')) AS sector_name,
 INITCAP(NULLIF(TRIM(security_type), '')) AS security_type,
 ROW_NUMBER() OVER (PARTITION BY TRIM(sector_code) ORDER BY raw_row_id DESC) AS rn
FROM project_staging.raw_sector;

INSERT INTO project_staging.rejected_rows (source_table, source_row_id, reason, batch_id)
SELECT 'raw_sector', raw_row_id,
 CASE WHEN sector_code IS NULL THEN 'missing sector code'
 WHEN sector_name IS NULL OR sector_name = '' THEN 'missing sector name'
 ELSE 'duplicate sector code' END,
 batch_id
FROM tmp_sector
WHERE sector_code IS NULL OR sector_name IS NULL OR sector_name = '' OR rn > 1;

INSERT INTO project_staging.stg_sector (sector_code, sector_name, security_type, source_row_id, batch_id)
SELECT sector_code, sector_name, security_type, raw_row_id, batch_id
FROM tmp_sector
WHERE sector_code IS NOT NULL AND sector_name <> '' AND rn = 1;

----------------------------------------------------------------------
-- 2b. Old sector codes -> current codes
-- PSX renumbered its sectors; rows before the change carry codes that are not in the official list.
-- Each stock takes the first official code it traded under (stock by stock, because one old code
-- was split into several new sectors). Stocks that never traded under the new list keep their old code.
-- The published code stays in original_sector_code.
----------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_sector_map;
CREATE TEMP TABLE tmp_sector_map AS
SELECT DISTINCT ON (x.symbol) x.symbol, x.sector_code AS new_code
FROM project_staging.stg_market_summary x
JOIN project_staging.stg_sector s ON s.sector_code = x.sector_code
ORDER BY x.symbol, x.trade_date;

UPDATE project_staging.stg_market_summary m
SET sector_code = n.new_code
FROM tmp_sector_map n
WHERE m.symbol = n.symbol
AND m.sector_code NOT IN (SELECT sector_code FROM project_staging.stg_sector);

----------------------------------------------------------------------
-- 3. Policy rate decisions
----------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_rate;
CREATE TEMP TABLE tmp_rate AS
SELECT raw_row_id,
 batch_id,
 CASE WHEN TRIM(effective_date) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN LEFT(TRIM(effective_date), 10)::DATE END AS effective_date,
 project_staging.to_num(policy_rate) AS policy_rate,
 project_staging.to_num(previous_rate) AS previous_rate,
 project_staging.to_num(change_bps)::INT AS change_bps
FROM project_staging.raw_policy_rate;

ALTER TABLE tmp_rate ADD COLUMN rn INT;
UPDATE tmp_rate t SET rn = d.rn
FROM (SELECT raw_row_id, ROW_NUMBER() OVER (PARTITION BY effective_date ORDER BY raw_row_id DESC) AS rn FROM tmp_rate) d
WHERE t.raw_row_id = d.raw_row_id;

INSERT INTO project_staging.rejected_rows (source_table, source_row_id, reason, batch_id)
SELECT 'raw_policy_rate', raw_row_id,
 CASE WHEN effective_date IS NULL THEN 'invalid effective date'
 WHEN policy_rate IS NULL THEN 'policy rate missing or not numeric'
 ELSE 'duplicate effective date' END,
 batch_id
FROM tmp_rate
WHERE effective_date IS NULL OR policy_rate IS NULL OR rn > 1;

INSERT INTO project_staging.stg_policy_rate (effective_date, policy_rate, previous_rate, change_bps, source_row_id, batch_id)
SELECT effective_date, policy_rate, previous_rate, change_bps, raw_row_id, batch_id
FROM tmp_rate
WHERE effective_date IS NOT NULL AND policy_rate IS NOT NULL AND rn = 1;

----------------------------------------------------------------------
-- 4. Watermark: latest trading day now in staging
----------------------------------------------------------------------
INSERT INTO project_staging.load_watermark (pipeline_name, last_loaded_date)
SELECT 'psx_market_summary', MAX(trade_date) FROM project_staging.stg_market_summary
ON CONFLICT (pipeline_name) DO UPDATE SET last_loaded_date = EXCLUDED.last_loaded_date;
