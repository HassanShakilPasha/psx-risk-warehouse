-- --------------------------------------------------------------
-- PSX Market Risk Data Warehouse – Dimension Load Script (Phase 2)
-- Author: Hassan Shakil (24L‑2521)
-- --------------------------------------------------------------

-- 0️⃣ Ensure target schema exists (already created by warehouse.sql)
CREATE SCHEMA IF NOT EXISTS project_dw;

-- ------------------------------------------------------------------
-- 1️⃣ Insert the sentinel "Unknown" members (-1) into every dimension.
--    Identity columns use OVERRIDING SYSTEM VALUE so the explicit -1 is accepted.

-- dim_date – unknown date (1900‑01‑01)
INSERT INTO project_dw.dim_date (
    date_key, full_date, day_of_month, day_name, day_of_week,
    week_of_year, month, month_name, quarter, year, year_month,
    is_weekend, is_trading_day
) OVERRIDING SYSTEM VALUE
VALUES (
    -1, DATE '1900-01-01', 1, 'Monday', 1,
    1, 1, 'January', 1, 1900, '1900-01',
    FALSE, FALSE
)
ON CONFLICT (date_key) DO NOTHING;

-- dim_sector – unknown sector
INSERT INTO project_dw.dim_sector (
    sector_key, sector_code, sector_name, sector_group, legacy_codes
) OVERRIDING SYSTEM VALUE
VALUES (
    -1, 'UNKNOWN', 'Unknown Sector', 'Unknown', NULL
)
ON CONFLICT (sector_key) DO NOTHING;

-- dim_stock – unknown stock (links to unknown sector)
INSERT INTO project_dw.dim_stock (
    stock_key, symbol, company_name, sector_key,
    first_trade_date, last_trade_date, is_active,
    effective_from, effective_to, is_current
) OVERRIDING SYSTEM VALUE
VALUES (
    -1, 'UNKNOWN', 'Unknown Stock', -1,
    DATE '2015-01-01', DATE '9999-12-31', TRUE,
    DATE '2015-01-01', NULL, TRUE
)
ON CONFLICT (stock_key) DO NOTHING;

-- dim_risk_tier – static lookup (fixed keys 1‑4)
INSERT INTO project_dw.dim_risk_tier (risk_tier_key, tier_name, percentile_min, percentile_max, tier_description, sort_order)
VALUES
    (1, 'Low',    0.00, 0.40, 'Low volatility tier (0‑40th percentile)', 1),
    (2, 'Medium', 0.40, 0.80, 'Medium volatility tier (40‑80th percentile)', 2),
    (3, 'High',   0.80, 1.00, 'High volatility tier (80‑100th percentile)', 3),
    (4, 'Not Rated', NULL, NULL, 'No volatility data / not classified', 4)
ON CONFLICT (risk_tier_key) DO UPDATE SET
    tier_name = EXCLUDED.tier_name,
    percentile_min = EXCLUDED.percentile_min,
    percentile_max = EXCLUDED.percentile_max,
    tier_description = EXCLUDED.tier_description,
    sort_order = EXCLUDED.sort_order;

-- dim_event_type – static lookup (fixed keys 1‑4)
INSERT INTO project_dw.dim_event_type (event_type_key, event_type_code, event_type_name, event_category, detection_rule)
VALUES
    (1, 'BONUS',  'Bonus Issue',      'Corporate Action', 'LDCP differs from previous close by >1%'),
    (2, 'SPLIT',  'Stock Split',      'Corporate Action', 'Split ratio present in metadata'),
    (3, 'RIGHTS', 'Rights Issue',     'Corporate Action', 'Rights quantity field non‑null'),
    (4, 'LIMIT',  'Price‑Limit Lock', 'Liquidity Event',  'Close hits upper or lower price limit')
ON CONFLICT (event_type_key) DO UPDATE SET
    event_type_code = EXCLUDED.event_type_code,
    event_type_name = EXCLUDED.event_type_name,
    event_category  = EXCLUDED.event_category,
    detection_rule  = EXCLUDED.detection_rule;

-- dim_policy_action – static lookup (fixed keys 1‑3)
INSERT INTO project_dw.dim_policy_action (policy_action_key, action_name, action_description)
VALUES
    (1, 'Hike', 'Policy rate increased'),
    (2, 'Cut',  'Policy rate decreased'),
    (3, 'Hold', 'Policy rate unchanged')
ON CONFLICT (policy_action_key) DO UPDATE SET
    action_name = EXCLUDED.action_name,
    action_description = EXCLUDED.action_description;

-- ------------------------------------------------------------------
-- 2️⃣ Load dim_date for the full calendar range (2015‑01‑01 → 2027‑12‑31)
INSERT INTO project_dw.dim_date (
    date_key, full_date, day_of_month, day_name, day_of_week,
    week_of_year, month, month_name, quarter, year, year_month,
    is_weekend, is_trading_day
)
SELECT
    TO_CHAR(d,'YYYYMMDD')::INT AS date_key,
    d::DATE               AS full_date,
    EXTRACT(DAY FROM d)::INT       AS day_of_month,
    TRIM(TO_CHAR(d,'Day'))         AS day_name,
    EXTRACT(ISODOW FROM d)::INT    AS day_of_week,
    EXTRACT(WEEK FROM d)::INT      AS week_of_year,
    EXTRACT(MONTH FROM d)::INT     AS month,
    TRIM(TO_CHAR(d,'Month'))       AS month_name,
    EXTRACT(QUARTER FROM d)::INT   AS quarter,
    EXTRACT(YEAR FROM d)::INT      AS year,
    TO_CHAR(d,'YYYY-MM')           AS year_month,
    EXTRACT(ISODOW FROM d) IN (6,7) AS is_weekend,
    EXTRACT(ISODOW FROM d) < 6      AS is_trading_day
FROM generate_series('2015-01-01'::DATE, '2027-12-31'::DATE, INTERVAL '1 day') AS g(d)
ON CONFLICT (date_key) DO NOTHING;

-- ------------------------------------------------------------------
-- 3️⃣ Load dim_sector from staging metadata (stg_stock_metadata)
--    Expected columns in the staging table:
--      sector_code, sector_name, sector_group, legacy_codes
INSERT INTO project_dw.dim_sector (sector_code, sector_name, sector_group, legacy_codes)
SELECT DISTINCT
    sm.sector_code,
    sm.sector_name,
    sm.sector_group,
    sm.legacy_codes
FROM stg_stock_metadata sm
WHERE sm.sector_code IS NOT NULL
ON CONFLICT (sector_code) DO UPDATE SET
    sector_name   = EXCLUDED.sector_name,
    sector_group  = EXCLUDED.sector_group,
    legacy_codes  = EXCLUDED.legacy_codes;

-- ------------------------------------------------------------------
-- 4️⃣ Load dim_stock (SCD 2) from staging metadata (stg_stock_metadata) and price dates
--    Expected columns in the staging table:
--      symbol, company_name, sector_code, first_trade_date, last_trade_date, is_active
--    The surrogate sector_key is resolved via a join to dim_sector.
INSERT INTO project_dw.dim_stock (
    symbol, company_name, sector_key,
    first_trade_date, last_trade_date, is_active,
    effective_from, effective_to, is_current
)
SELECT
    sm.symbol,
    sm.company_name,
    COALESCE(ds.sector_key, -1) AS sector_key,
    sm.first_trade_date,
    sm.last_trade_date,
    sm.is_active,
    sm.first_trade_date AS effective_from,
    NULL AS effective_to,
    TRUE AS is_current
FROM stg_stock_metadata sm
LEFT JOIN project_dw.dim_sector ds ON ds.sector_code = sm.sector_code
WHERE sm.symbol IS NOT NULL
  AND sm.symbol NOT LIKE '%-%'   -- exclude futures (as per cleaning rules)
ON CONFLICT (symbol, effective_from) DO UPDATE SET
    company_name   = EXCLUDED.company_name,
    sector_key     = EXCLUDED.sector_key,
    first_trade_date = EXCLUDED.first_trade_date,
    last_trade_date  = EXCLUDED.last_trade_date,
    is_active        = EXCLUDED.is_active,
    effective_to     = EXCLUDED.effective_to,
    is_current       = EXCLUDED.is_current;

-- ------------------------------------------------------------------
-- 5️⃣ (Optional) – Future SCD‑2 handling block (commented for reference)
/*
   When a tracked attribute (e.g., sector_key) changes for an existing symbol,
   the typical pattern is:
   1. UPDATE the current row: set effective_to = <change_date> and is_current = FALSE;
   2. INSERT a new version with effective_from = <change_date>, is_current = TRUE.
   This script only performs the initial load; the incremental SCD‑2 logic would be
   added to the nightly ETL job.
*/

-- ------------------------------------------------------------------
-- 6️⃣ Verification suite (run after loading dimensions)
--    Paste the output of each query into the viva report.

-- 6.1 Unknown members exist in all six dimensions
SELECT 'dim_date'      AS dim, COUNT(*) FROM project_dw.dim_date      WHERE date_key = -1;
SELECT 'dim_sector'    AS dim, COUNT(*) FROM project_dw.dim_sector    WHERE sector_key = -1;
SELECT 'dim_stock'     AS dim, COUNT(*) FROM project_dw.dim_stock     WHERE stock_key = -1;
SELECT 'dim_risk_tier' AS dim, COUNT(*) FROM project_dw.dim_risk_tier WHERE risk_tier_key = -1;
SELECT 'dim_event_type' AS dim, COUNT(*) FROM project_dw.dim_event_type WHERE event_type_key = -1;
SELECT 'dim_policy_action' AS dim, COUNT(*) FROM project_dw.dim_policy_action WHERE policy_action_key = -1;

-- 6.2 No duplicate business keys (sector_code, full_date, event_type_code, action_name)
SELECT 'sector_code duplicates' AS check_desc, COUNT(*) FROM (
    SELECT sector_code FROM project_dw.dim_sector GROUP BY sector_code HAVING COUNT(*) > 1
) t;
SELECT 'full_date duplicates' AS check_desc, COUNT(*) FROM (
    SELECT full_date FROM project_dw.dim_date GROUP BY full_date HAVING COUNT(*) > 1
) t;
SELECT 'event_type_code duplicates' AS check_desc, COUNT(*) FROM (
    SELECT event_type_code FROM project_dw.dim_event_type GROUP BY event_type_code HAVING COUNT(*) > 1
) t;
SELECT 'action_name duplicates' AS check_desc, COUNT(*) FROM (
    SELECT action_name FROM project_dw.dim_policy_action GROUP BY action_name HAVING COUNT(*) > 1
) t;

-- 6.3 Exactly one current row per symbol
SELECT COUNT(*) FROM project_dw.dim_stock WHERE is_current = TRUE GROUP BY symbol HAVING COUNT(*) > 1;

-- 6.4 Orphan sector references in dim_stock
SELECT COUNT(*) FROM project_dw.dim_stock ds LEFT JOIN project_dw.dim_sector dsr ON ds.sector_key = dsr.sector_key WHERE dsr.sector_key IS NULL AND ds.sector_key <> -1;

-- 6.5 Row count for dim_date (including Unknown)
SELECT COUNT(*) FROM project_dw.dim_date;

-- ------------------------------------------------------------------
-- 7️⃣ Business‑key ↔ surrogate‑key examples (runnable queries)
--    These are useful for the facts loader and viva.

-- Example 1: stock key lookup for a few symbols
SELECT symbol, stock_key, sector_key, is_current
FROM project_dw.dim_stock
WHERE symbol IN ('LUCK','HBL','OGDC');

-- Example 2: sector key lookup (first five rows)
SELECT sector_code, sector_key, sector_name
FROM project_dw.dim_sector
ORDER BY sector_key
LIMIT 5;

-- Example 3: date key lookup for a specific calendar day
SELECT full_date, date_key
FROM project_dw.dim_date
WHERE full_date = DATE '2026-01-15';

-- --------------------------------------------------------------
-- End of dimensions load script
-- --------------------------------------------------------------