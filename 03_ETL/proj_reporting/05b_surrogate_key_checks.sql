-- Surrogate key checks for the dimensions. Run after 05_dimensions.sql.

-- 1. Rows per dimension
SELECT 'dim_date' AS dimension, COUNT(*) AS row_count FROM project_dw.dim_date
UNION ALL SELECT 'dim_sector', COUNT(*) FROM project_dw.dim_sector
UNION ALL SELECT 'dim_stock', COUNT(*) FROM project_dw.dim_stock
UNION ALL SELECT 'dim_risk_tier', COUNT(*) FROM project_dw.dim_risk_tier
UNION ALL SELECT 'dim_event_type', COUNT(*) FROM project_dw.dim_event_type
UNION ALL SELECT 'dim_policy_action', COUNT(*) FROM project_dw.dim_policy_action;

-- 2. Business key -> surrogate key examples
SELECT symbol, stock_key, company_name, effective_from, effective_to, is_current
FROM project_dw.dim_stock
WHERE stock_key > 0
ORDER BY symbol, effective_from
LIMIT 20;

SELECT sector_code, sector_key, sector_name FROM project_dw.dim_sector ORDER BY sector_key LIMIT 10;

-- 3. Every symbol in staging has exactly one current version (should return 0 rows)
SELECT symbol, COUNT(*) FILTER (WHERE is_current) AS current_versions
FROM project_dw.dim_stock
WHERE stock_key > 0
GROUP BY symbol
HAVING COUNT(*) FILTER (WHERE is_current) <> 1;

SELECT COUNT(DISTINCT m.symbol) AS symbols_missing_in_dim
FROM project_staging.stg_market_summary m
WHERE NOT EXISTS (SELECT 1 FROM project_dw.dim_stock s WHERE s.symbol = m.symbol);

-- 4. SCD2: stocks with more than one version (name or sector changed)
SELECT symbol, COUNT(*) AS versions
FROM project_dw.dim_stock
WHERE stock_key > 0
GROUP BY symbol
HAVING COUNT(*) > 1
ORDER BY versions DESC
LIMIT 10;

-- 5. Version periods do not overlap (should return 0 rows)
SELECT a.symbol, a.stock_key, b.stock_key
FROM project_dw.dim_stock a
JOIN project_dw.dim_stock b ON a.symbol = b.symbol AND a.stock_key < b.stock_key
WHERE a.effective_from <= COALESCE(b.effective_to, DATE '9999-12-31') AND b.effective_from <= COALESCE(a.effective_to, DATE '9999-12-31');

-- 6. Stocks whose sector is not in the sector list (mapped to -1)
SELECT COUNT(*) AS stocks_unknown_sector FROM project_dw.dim_stock WHERE stock_key > 0 AND sector_key = -1;
