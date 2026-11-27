-- Numbers for the Data Cleaning Report. Run after run_etl.py.

-- 1. Rows per layer
SELECT 'raw_market_summary' AS table_name, COUNT(*) AS row_count FROM project_staging.raw_market_summary
UNION ALL SELECT 'stg_market_summary', COUNT(*) FROM project_staging.stg_market_summary
UNION ALL SELECT 'raw_sector', COUNT(*) FROM project_staging.raw_sector
UNION ALL SELECT 'stg_sector', COUNT(*) FROM project_staging.stg_sector
UNION ALL SELECT 'raw_policy_rate', COUNT(*) FROM project_staging.raw_policy_rate
UNION ALL SELECT 'stg_policy_rate', COUNT(*) FROM project_staging.stg_policy_rate
UNION ALL SELECT 'rejected_rows', COUNT(*) FROM project_staging.rejected_rows;

-- 2. Rejected rows by reason (raw = staging + rejected for every source)
SELECT source_table, reason, COUNT(*) AS row_count
FROM project_staging.rejected_rows
GROUP BY source_table, reason
ORDER BY source_table, row_count DESC;

-- 3. Batch log
SELECT * FROM project_staging.etl_batch ORDER BY batch_id DESC;

-- 4. Before / after examples of text cleaning
SELECT r.symbol AS raw_symbol, s.symbol, r.company_name AS raw_company_name, s.company_name
FROM project_staging.stg_market_summary s
JOIN project_staging.raw_market_summary r ON r.raw_row_id = s.source_row_id
WHERE r.company_name <> s.company_name
LIMIT 15;

-- 5. Missing values left in staging (allowed: open price is sometimes blank in the source)
SELECT COUNT(*) FILTER (WHERE open_price IS NULL) AS open_missing,
 COUNT(*) FILTER (WHERE high_price IS NULL) AS high_missing,
 COUNT(*) FILTER (WHERE low_price IS NULL) AS low_missing,
 COUNT(*) FILTER (WHERE ldcp IS NULL) AS ldcp_missing,
 COUNT(*) FILTER (WHERE sector_code IS NULL) AS sector_missing
FROM project_staging.stg_market_summary;

-- 6. Sector codes in the market data that are not in the sector list (old pre-2015 codes)
SELECT m.sector_code, COUNT(DISTINCT m.symbol) AS stocks
FROM project_staging.stg_market_summary m
LEFT JOIN project_staging.stg_sector s ON s.sector_code = m.sector_code
WHERE s.sector_code IS NULL
GROUP BY m.sector_code
ORDER BY stocks DESC;

-- 7. Coverage
SELECT MIN(trade_date), MAX(trade_date), COUNT(DISTINCT trade_date) AS trading_days, COUNT(DISTINCT symbol) AS symbols
FROM project_staging.stg_market_summary;
