-- Staging -> dimensions. Full reload: dimensions (and the facts that point to them) are rebuilt each run.
-- Run after 03_staging_load.sql; facts are loaded afterwards by 06_facts.sql.
TRUNCATE project_dw.dim_date, project_dw.dim_sector, project_dw.dim_stock, project_dw.dim_risk_tier, project_dw.dim_event_type, project_dw.dim_policy_action RESTART IDENTITY CASCADE;

----------------------------------------------------------------------
-- 1. dim_date: every calendar day of the years covered by the data
----------------------------------------------------------------------
INSERT INTO project_dw.dim_date
SELECT TO_CHAR(d, 'YYYYMMDD')::INT,
 d::DATE,
 EXTRACT(DAY FROM d)::INT,
 TRIM(TO_CHAR(d, 'Day')),
 EXTRACT(ISODOW FROM d)::INT,
 EXTRACT(WEEK FROM d)::INT,
 EXTRACT(MONTH FROM d)::INT,
 TRIM(TO_CHAR(d, 'Month')),
 EXTRACT(QUARTER FROM d)::INT,
 EXTRACT(YEAR FROM d)::INT,
 TO_CHAR(d, 'YYYY-MM'),
 EXTRACT(ISODOW FROM d) >= 6,
 d::DATE IN (SELECT DISTINCT trade_date FROM project_staging.stg_market_summary)
FROM generate_series(
 (SELECT DATE_TRUNC('year', LEAST(MIN(m.trade_date), (SELECT MIN(effective_date) FROM project_staging.stg_policy_rate))) FROM project_staging.stg_market_summary m),
 (SELECT DATE_TRUNC('year', MAX(trade_date)) + INTERVAL '1 year - 1 day' FROM project_staging.stg_market_summary),
 INTERVAL '1 day') AS d;

INSERT INTO project_dw.dim_date VALUES (-1, '1900-01-01', 1, 'Unknown', 0, 0, 0, 'Unknown', 0, 0, 'Unknown', FALSE, FALSE);

----------------------------------------------------------------------
-- 2. dim_sector (Type 1): official sector list + any code in the price data that is not in the list
----------------------------------------------------------------------
INSERT INTO project_dw.dim_sector (sector_key, sector_code, sector_name, sector_group) VALUES (-1, 'UNKNOWN', 'Unknown', 'Unknown');

INSERT INTO project_dw.dim_sector (sector_code, sector_name, sector_group)
SELECT sector_code, sector_name, COALESCE(security_type, 'Unknown')
FROM project_staging.stg_sector
ORDER BY sector_code;

-- old codes (PSX renumbered sectors) that appear in the price data but not in the current list
INSERT INTO project_dw.dim_sector (sector_code, sector_name, sector_group, legacy_codes)
SELECT DISTINCT m.sector_code, 'Legacy Sector ' || m.sector_code, 'Legacy', m.sector_code
FROM project_staging.stg_market_summary m
WHERE NOT EXISTS (SELECT 1 FROM project_dw.dim_sector s WHERE s.sector_code = m.sector_code)
ORDER BY m.sector_code;

----------------------------------------------------------------------
-- 3. dim_stock (SCD Type 2 on company_name and sector)
-- A new version starts whenever a stock's name or sector differs from its previous trading day.
----------------------------------------------------------------------
INSERT INTO project_dw.dim_stock (stock_key, symbol, company_name, sector_key, is_active, is_current) VALUES (-1, 'UNKNOWN', 'Unknown', -1, FALSE, FALSE);

INSERT INTO project_dw.dim_stock (symbol, company_name, sector_key, first_trade_date, last_trade_date, is_active, effective_from, effective_to, is_current)
WITH days AS (
 SELECT symbol, trade_date, company_name, sector_code,
 CASE WHEN company_name IS DISTINCT FROM LAG(company_name) OVER w
 OR sector_code IS DISTINCT FROM LAG(sector_code) OVER w THEN 1 ELSE 0 END AS is_change
 FROM project_staging.stg_market_summary
 WINDOW w AS (PARTITION BY symbol ORDER BY trade_date)
),
numbered AS (
 SELECT *, SUM(is_change) OVER (PARTITION BY symbol ORDER BY trade_date) AS version_no
 FROM days
),
versions AS (
 SELECT symbol, version_no, MIN(company_name) AS company_name, MIN(sector_code) AS sector_code, MIN(trade_date) AS effective_from
 FROM numbered
 GROUP BY symbol, version_no
),
stock_span AS (
 SELECT symbol, MIN(trade_date) AS first_trade_date, MAX(trade_date) AS last_trade_date
 FROM project_staging.stg_market_summary
 GROUP BY symbol
)
SELECT v.symbol,
 COALESCE(v.company_name, v.symbol),
 COALESCE(s.sector_key, -1),
 sp.first_trade_date,
 sp.last_trade_date,
 sp.last_trade_date >= (SELECT MAX(trade_date) FROM project_staging.stg_market_summary) - 30,
 v.effective_from,
 LEAD(v.effective_from) OVER (PARTITION BY v.symbol ORDER BY v.version_no) - 1,
 LEAD(v.effective_from) OVER (PARTITION BY v.symbol ORDER BY v.version_no) IS NULL
FROM versions v
JOIN stock_span sp ON sp.symbol = v.symbol
LEFT JOIN project_dw.dim_sector s ON s.sector_code = v.sector_code
ORDER BY v.symbol, v.version_no;

----------------------------------------------------------------------
-- 4. Static lookup dimensions (values from the Phase 1 design)
----------------------------------------------------------------------
INSERT INTO project_dw.dim_risk_tier VALUES
 (-1, 'Unknown', NULL, NULL, 'Tier could not be determined', 0),
 (1, 'Low', 0.00, 0.40, 'Bottom 40% least volatile stocks that day', 1),
 (2, 'Medium', 0.40, 0.80, 'Middle 40% of stocks by volatility that day', 2),
 (3, 'High', 0.80, 1.00, 'Top 20% most volatile stocks that day', 3),
 (4, 'Not Rated', NULL, NULL, 'Fewer than 15 valid returns in the last 20 days', 4);

INSERT INTO project_dw.dim_event_type VALUES
 (-1, 'UNKNOWN', 'Unknown', 'Unknown', 'Not applicable'),
 (1, 'PRICE_ADJ', 'Corporate action price adjustment', 'Corporate Action', 'LDCP differs from the previous day''s close by more than 1% (bonus, split, rights, dividend)'),
 (2, 'LIMIT_UP', 'Large up move (price limit)', 'Price Limit', 'Daily return >= +7.5%'),
 (3, 'LIMIT_DOWN', 'Large down move (price limit)', 'Price Limit', 'Daily return <= -7.5%'),
 (4, 'NO_TRADE', 'Listed but not traded', 'Liquidity', 'Stock in the market summary with volume = 0');

INSERT INTO project_dw.dim_policy_action VALUES
 (-1, 'Unknown', 'Action could not be determined'),
 (1, 'Hike', 'Policy rate increased'),
 (2, 'Cut', 'Policy rate decreased'),
 (3, 'Hold', 'Policy rate unchanged');
