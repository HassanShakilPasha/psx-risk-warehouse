-- Staging + dimensions -> facts. Business keys (symbol, date, sector code) are swapped for surrogate keys.

BEGIN;
TRUNCATE project_dw.fact_daily_stock_price, project_dw.fact_market_daily, project_dw.fact_sector_daily, project_dw.fact_policy_decision, project_dw.fact_market_event;

----------------------------------------------------------------------
-- 1. fact_daily_stock_price
----------------------------------------------------------------------
-- returns and rolling measures per symbol
DROP TABLE IF EXISTS tmp_stock_daily;
CREATE TEMP TABLE tmp_stock_daily AS
WITH r AS (
 SELECT m.*,
 CASE WHEN close_price > 0 AND ldcp > 0 THEN LN(close_price / ldcp) END AS daily_log_return
 FROM project_staging.stg_market_summary m
)
SELECT r.*,
 CASE WHEN ldcp > 0 THEN (high_price - low_price) / ldcp END AS price_range_pct,
 CASE WHEN COUNT(daily_log_return) OVER w20 >= 15 THEN STDDEV_SAMP(daily_log_return) OVER w20 * SQRT(252) END AS volatility_20d,
 CASE WHEN COUNT(daily_log_return) OVER w60 >= 15 THEN STDDEV_SAMP(daily_log_return) OVER w60 * SQRT(252) END AS volatility_60d,
 AVG(volume) OVER w20 AS avg_volume_20d
FROM r
WINDOW w20 AS (PARTITION BY symbol ORDER BY trade_date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW),
 w60 AS (PARTITION BY symbol ORDER BY trade_date ROWS BETWEEN 59 PRECEDING AND CURRENT ROW);

-- rank of volatility among rated stocks each day (0 = calmest, 1 = most volatile)
ALTER TABLE tmp_stock_daily ADD COLUMN risk_percentile DOUBLE PRECISION;
UPDATE tmp_stock_daily t SET risk_percentile = p.pr
FROM (
 SELECT symbol, trade_date, PERCENT_RANK() OVER (PARTITION BY trade_date ORDER BY volatility_20d) AS pr
 FROM tmp_stock_daily
 WHERE volatility_20d IS NOT NULL
) p
WHERE t.symbol = p.symbol AND t.trade_date = p.trade_date;

INSERT INTO project_dw.fact_daily_stock_price (date_key, stock_key, risk_tier_key, open_price, high_price, low_price, close_price, ldcp, volume, daily_log_return, price_range_pct, volatility_20d, volatility_60d, avg_volume_20d, risk_percentile, is_traded, is_ohlc_valid)
SELECT COALESCE(d.date_key, -1),
 COALESCE(s.stock_key, -1),
 COALESCE(
 CASE WHEN t.risk_percentile IS NULL THEN (SELECT risk_tier_key FROM project_dw.dim_risk_tier WHERE tier_name = 'Not Rated')
 ELSE (SELECT rt.risk_tier_key FROM project_dw.dim_risk_tier rt WHERE rt.percentile_min <= t.risk_percentile ORDER BY rt.percentile_min DESC LIMIT 1) END,
 -1),
 t.open_price, t.high_price, t.low_price, t.close_price, t.ldcp, t.volume,
 t.daily_log_return, t.price_range_pct, t.volatility_20d, t.volatility_60d, t.avg_volume_20d, t.risk_percentile,
 t.volume > 0,
 t.low_price > 0 AND t.low_price <= t.close_price AND t.close_price <= t.high_price AND (t.open_price IS NULL OR t.open_price BETWEEN t.low_price AND t.high_price)
FROM tmp_stock_daily t
LEFT JOIN project_dw.dim_date d ON d.full_date = t.trade_date
-- the stock version that was valid on the trading date (SCD Type 2 lookup)
LEFT JOIN project_dw.dim_stock s ON s.symbol = t.symbol AND t.trade_date BETWEEN s.effective_from AND COALESCE(s.effective_to, DATE '9999-12-31');

----------------------------------------------------------------------
-- 2. fact_market_daily (aggregated from fact_daily_stock_price)
----------------------------------------------------------------------
INSERT INTO project_dw.fact_market_daily (date_key, stocks_listed, stocks_traded, advancers, decliners, total_volume, market_return, market_volatility_20d, median_stock_volatility_20d, pct_stocks_high_risk)
WITH daily AS (
 SELECT f.date_key,
 COUNT(*) AS stocks_listed,
 COUNT(*) FILTER (WHERE f.is_traded) AS stocks_traded,
 COUNT(*) FILTER (WHERE f.close_price > f.ldcp) AS advancers,
 COUNT(*) FILTER (WHERE f.close_price < f.ldcp) AS decliners,
 SUM(f.volume) AS total_volume,
 AVG(f.daily_log_return) AS market_return,
 PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.volatility_20d) AS median_stock_volatility_20d,
 COUNT(*) FILTER (WHERE rt.tier_name = 'High')::DOUBLE PRECISION / NULLIF(COUNT(f.risk_percentile), 0) AS pct_stocks_high_risk
 FROM project_dw.fact_daily_stock_price f
 JOIN project_dw.dim_risk_tier rt ON rt.risk_tier_key = f.risk_tier_key
 GROUP BY f.date_key
)
SELECT date_key, stocks_listed, stocks_traded, advancers, decliners, total_volume, market_return,
 CASE WHEN COUNT(market_return) OVER w >= 15 THEN STDDEV_SAMP(market_return) OVER w * SQRT(252) END,
 median_stock_volatility_20d, pct_stocks_high_risk
FROM daily
WINDOW w AS (ORDER BY date_key ROWS BETWEEN 19 PRECEDING AND CURRENT ROW);

----------------------------------------------------------------------
-- 3. fact_sector_daily (aggregated, sector through dim_stock)
----------------------------------------------------------------------
INSERT INTO project_dw.fact_sector_daily (date_key, sector_key, stocks_traded, sector_volume, avg_return, avg_volatility_20d, pct_high_risk)
SELECT f.date_key,
 s.sector_key,
 COUNT(*) FILTER (WHERE f.is_traded),
 SUM(f.volume),
 AVG(f.daily_log_return),
 AVG(f.volatility_20d),
 COUNT(*) FILTER (WHERE rt.tier_name = 'High')::DOUBLE PRECISION / NULLIF(COUNT(f.risk_percentile), 0)
FROM project_dw.fact_daily_stock_price f
JOIN project_dw.dim_stock s ON s.stock_key = f.stock_key
JOIN project_dw.dim_risk_tier rt ON rt.risk_tier_key = f.risk_tier_key
GROUP BY f.date_key, s.sector_key;

----------------------------------------------------------------------
-- 4. fact_policy_decision
----------------------------------------------------------------------
INSERT INTO project_dw.fact_policy_decision (date_key, policy_action_key, policy_rate_pct, previous_rate_pct, change_bps)
WITH p AS (
 SELECT effective_date, policy_rate,
 COALESCE(previous_rate, LAG(policy_rate) OVER (ORDER BY effective_date)) AS previous_rate,
 COALESCE(change_bps, ((policy_rate - LAG(policy_rate) OVER (ORDER BY effective_date)) * 100)::INT, 0) AS change_bps
 FROM project_staging.stg_policy_rate
)
SELECT COALESCE(d.date_key, -1),
 COALESCE(a.policy_action_key, -1),
 p.policy_rate,
 p.previous_rate,
 p.change_bps
FROM p
LEFT JOIN project_dw.dim_date d ON d.full_date = p.effective_date
LEFT JOIN project_dw.dim_policy_action a ON a.action_name = CASE WHEN p.change_bps > 0 THEN 'Hike' WHEN p.change_bps < 0 THEN 'Cut' ELSE 'Hold' END;

----------------------------------------------------------------------
-- 5. fact_market_event (factless): one row per detected event
----------------------------------------------------------------------
INSERT INTO project_dw.fact_market_event (date_key, stock_key, event_type_key)
WITH e AS (
 SELECT f.date_key, f.stock_key,
 CASE WHEN LAG(f.close_price) OVER w > 0 AND ABS(f.ldcp / LAG(f.close_price) OVER w - 1) > 0.01 THEN 'PRICE_ADJ' END AS adj,
 CASE WHEN f.ldcp > 0 AND f.close_price / f.ldcp - 1 >= 0.075 THEN 'LIMIT_UP'
 WHEN f.ldcp > 0 AND f.close_price / f.ldcp - 1 <= -0.075 THEN 'LIMIT_DOWN' END AS lim,
 CASE WHEN f.volume = 0 THEN 'NO_TRADE' END AS no_trade
 FROM project_dw.fact_daily_stock_price f
 JOIN project_dw.dim_stock s ON s.stock_key = f.stock_key
 WINDOW w AS (PARTITION BY s.symbol ORDER BY f.date_key)
)
SELECT e.date_key, e.stock_key, t.event_type_key
FROM e
JOIN project_dw.dim_event_type t ON t.event_type_code IN (e.adj, e.lim, e.no_trade);

Commit ;
