-- Data quality validation. Every check returns one row: what was checked, the result, and PASS/FAIL.
-- Run after 06_facts.sql. Screenshot the output for the Data Quality Report.
WITH checks AS (
 -- COMPLETENESS
 SELECT 1 AS n, 'Completeness' AS category, 'Fact rows with unknown date (-1)' AS check_name,
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE date_key = -1)::NUMERIC AS result, 0::NUMERIC AS expected
 UNION ALL SELECT 2, 'Completeness', 'Fact rows with unknown stock (-1)',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE stock_key = -1), 0
 UNION ALL SELECT 3, 'Completeness', 'Fact rows with unknown risk tier (-1)',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE risk_tier_key = -1), 0
 UNION ALL SELECT 4, 'Completeness', 'Fact rows with missing close price',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE close_price IS NULL), 0
 UNION ALL SELECT 5, 'Completeness', 'Trading days without a market row',
 (SELECT COUNT(*) FROM project_dw.dim_date d WHERE d.is_trading_day AND NOT EXISTS (SELECT 1 FROM project_dw.fact_market_daily m WHERE m.date_key = d.date_key)), 0
 UNION ALL SELECT 6, 'Completeness', 'Policy decisions with unknown action (-1)',
 (SELECT COUNT(*) FROM project_dw.fact_policy_decision WHERE policy_action_key = -1), 0

 -- ACCURACY (reconciliation between layers)
 UNION ALL SELECT 7, 'Accuracy', 'Rows: staging minus fact_daily_stock_price',
 (SELECT COUNT(*) FROM project_staging.stg_market_summary) - (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price), 0
 UNION ALL SELECT 8, 'Accuracy', 'Volume: staging minus fact_daily_stock_price',
 (SELECT SUM(volume) FROM project_staging.stg_market_summary) - (SELECT SUM(volume) FROM project_dw.fact_daily_stock_price), 0
 UNION ALL SELECT 9, 'Accuracy', 'Volume: fact_daily_stock_price minus fact_market_daily',
 (SELECT SUM(volume) FROM project_dw.fact_daily_stock_price) - (SELECT SUM(total_volume) FROM project_dw.fact_market_daily), 0
 UNION ALL SELECT 10, 'Accuracy', 'Volume: fact_market_daily minus fact_sector_daily',
 (SELECT SUM(total_volume) FROM project_dw.fact_market_daily) - (SELECT SUM(sector_volume) FROM project_dw.fact_sector_daily), 0
 UNION ALL SELECT 11, 'Accuracy', 'Raw rows not accounted for (raw - staging - rejected)',
 (SELECT COUNT(*) FROM project_staging.raw_market_summary) - (SELECT COUNT(*) FROM project_staging.stg_market_summary)
 - (SELECT COUNT(*) FROM project_staging.rejected_rows WHERE source_table = 'raw_market_summary'), 0
 UNION ALL SELECT 12, 'Accuracy', 'Policy decisions: staging minus fact',
 (SELECT COUNT(*) FROM project_staging.stg_policy_rate) - (SELECT COUNT(*) FROM project_dw.fact_policy_decision), 0
 UNION ALL SELECT 13, 'Accuracy', 'Risk percentile outside 0-1',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE risk_percentile < 0 OR risk_percentile > 1), 0
 UNION ALL SELECT 14, 'Accuracy', 'Negative volume or volatility',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price WHERE volume < 0 OR volatility_20d < 0 OR volatility_60d < 0), 0

 -- INTEGRITY (fact rows without a matching dimension row)
 UNION ALL SELECT 15, 'Integrity', 'fact_daily_stock_price -> dim_date orphans',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price f LEFT JOIN project_dw.dim_date d ON d.date_key = f.date_key WHERE d.date_key IS NULL), 0
 UNION ALL SELECT 16, 'Integrity', 'fact_daily_stock_price -> dim_stock orphans',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price f LEFT JOIN project_dw.dim_stock s ON s.stock_key = f.stock_key WHERE s.stock_key IS NULL), 0
 UNION ALL SELECT 17, 'Integrity', 'fact_daily_stock_price -> dim_risk_tier orphans',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price f LEFT JOIN project_dw.dim_risk_tier r ON r.risk_tier_key = f.risk_tier_key WHERE r.risk_tier_key IS NULL), 0
 UNION ALL SELECT 18, 'Integrity', 'fact_sector_daily -> dim_sector orphans',
 (SELECT COUNT(*) FROM project_dw.fact_sector_daily f LEFT JOIN project_dw.dim_sector s ON s.sector_key = f.sector_key WHERE s.sector_key IS NULL), 0
 UNION ALL SELECT 19, 'Integrity', 'fact_market_event -> dim_event_type orphans',
 (SELECT COUNT(*) FROM project_dw.fact_market_event f LEFT JOIN project_dw.dim_event_type e ON e.event_type_key = f.event_type_key WHERE e.event_type_key IS NULL), 0
 UNION ALL SELECT 20, 'Integrity', 'fact_policy_decision -> dim_policy_action orphans',
 (SELECT COUNT(*) FROM project_dw.fact_policy_decision f LEFT JOIN project_dw.dim_policy_action a ON a.policy_action_key = f.policy_action_key WHERE a.policy_action_key IS NULL), 0
 UNION ALL SELECT 21, 'Integrity', 'Fact rows whose stock version was not valid on that date',
 (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price f JOIN project_dw.dim_stock s ON s.stock_key = f.stock_key JOIN project_dw.dim_date d ON d.date_key = f.date_key
 WHERE f.stock_key > 0 AND d.full_date NOT BETWEEN s.effective_from AND COALESCE(s.effective_to, DATE '9999-12-31')), 0
)
SELECT n, category, check_name, result, expected, CASE WHEN result = expected THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY n;

-- Row counts per fact table (for the report)
SELECT 'fact_daily_stock_price' AS fact, COUNT(*) AS row_count FROM project_dw.fact_daily_stock_price
UNION ALL SELECT 'fact_market_daily', COUNT(*) FROM project_dw.fact_market_daily
UNION ALL SELECT 'fact_sector_daily', COUNT(*) FROM project_dw.fact_sector_daily
UNION ALL SELECT 'fact_policy_decision', COUNT(*) FROM project_dw.fact_policy_decision
UNION ALL SELECT 'fact_market_event', COUNT(*) FROM project_dw.fact_market_event;
