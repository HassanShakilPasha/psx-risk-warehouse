# Grain Definition Document
## PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange
**Course**: DL3004 Final Project - Phase 1: Business Analysis & Dimensional Design  
**Team**: Saqib Qazi (24L-2506) | Hassan Shakil (24L-2521) | Ammara Saleem (24L-2571)

The grain states exactly what one row of a fact table represents. It is fixed before choosing dimensions and measures, and every row loaded must respect it. Each fact table below has its formal grain statement, unique identifying keys, valid measures, and operational grain rules.

---

## 1. `fact_daily_stock_price`

| Attribute | Definition |
|---|---|
| **Grain Statement** | *"One row represents one listed stock on one trading day."* |
| **Fact Type** | Periodic snapshot fact (daily) |
| **Business Process** | Daily stock trading (end-of-day market summary) |
| **Unique Key (Grain)** | `(date_key, stock_key)` |
| **Measures at Grain** | `open_price`, `high_price`, `low_price`, `close_price`, `ldcp`, `volume`, `daily_log_return`, `price_range_pct`, `volatility_20d`, `volatility_60d`, `avg_volume_20d`, `risk_percentile` |
| **Expected Size** | ~1.09 million rows (2015 – Oct 2026) |

### Grain Rules
- **One stock has only one row per trading day**: duplicates in the source are removed (latest load retained).
- **Futures contracts (symbols containing '-') are excluded** because they are derivative instruments with separate expiration dynamics.
- **Days with no trading for a listed stock are preserved** (`volume = 0`) so liquidity dry-ups can be accurately monitored.
- **Weekends and official exchange holidays have no rows**.
- **Rationale**: PSX publishes end-of-day data only; daily is the lowest atomic grain available and supports roll-up across week, month, quarter, and year hierarchies.

---

## 2. `fact_market_daily`

| Attribute | Definition |
|---|---|
| **Grain Statement** | *"One row represents the whole PSX market on one trading day."* |
| **Fact Type** | Periodic snapshot fact (daily, aggregated) |
| **Business Process** | Market-wide daily activity |
| **Unique Key (Grain)** | `date_key` |
| **Measures at Grain** | `stocks_listed`, `stocks_traded`, `advancers`, `decliners`, `total_volume`, `market_return`, `market_volatility_20d`, `median_stock_volatility_20d`, `pct_stocks_high_risk` |
| **Expected Size** | ~2,900 rows |

### Grain Rules
- **Exactly one row per trading day**.
- **Built directly from `fact_daily_stock_price`** for the same trading day, guaranteeing reconciliation across granular and aggregate facts.
- **Rationale**: Analytical questions on systemic market turbulence compare the exchange day-by-day. Pre-aggregating these metrics avoids continuous full-table scans across 1M+ rows.

---

## 3. `fact_sector_daily`

| Attribute | Definition |
|---|---|
| **Grain Statement** | *"One row represents one sector on one trading day."* |
| **Fact Type** | Periodic snapshot fact (daily, aggregated) |
| **Business Process** | Sector daily performance |
| **Unique Key (Grain)** | `(date_key, sector_key)` |
| **Measures at Grain** | `stocks_traded`, `sector_volume`, `avg_return`, `avg_volatility_20d`, `pct_high_risk` |
| **Expected Size** | ~100,000 rows |

### Grain Rules
- **Exactly one row per sector per trading day**.
- **Sector mapping is retrieved from the active `dim_stock` SCD2 version** valid on that specific trading date.
- **Rationale**: Sector performance comparisons and policy sensitivity analyses represent high-frequency analytical queries.

---

## 4. `fact_policy_decision`

| Attribute | Definition |
|---|---|
| **Grain Statement** | *"One row represents one SBP policy rate decision taking effect on a date."* |
| **Fact Type** | Transaction fact |
| **Business Process** | Monetary policy decisions (State Bank of Pakistan) |
| **Unique Key (Grain)** | `date_key` |
| **Measures at Grain** | `policy_rate_pct`, `previous_rate_pct`, `change_bps` |
| **Expected Size** | ~60 decisions |

### Grain Rules
- **One row per policy decision effective date**.
- **Decisions that keep the benchmark rate unchanged are explicitly preserved** as `'Hold'` (`change_bps = 0`).
- **Rationale**: Policy decisions are discrete transaction events occurring on irregular calendar dates. Event-window joins align these decisions with market trading days.

---

## 5. `fact_market_event`

| Attribute | Definition |
|---|---|
| **Grain Statement** | *"One row represents one event of one type for one stock on one trading day."* |
| **Fact Type** | Factless fact (event tracking) |
| **Business Process** | Market events (corporate actions, price limits, trading halts) |
| **Unique Key (Grain)** | `(date_key, stock_key, event_type_key)` |
| **Measures at Grain** | None (factless) |
| **Expected Size** | ~150,000 rows |

### Grain Rules
- **One row per stock, per date, per event type**.
- A stock can record multiple distinct event types on the same date (e.g. corporate action adjustment and upper price-limit lock).
- **Rationale**: The business only needs to verify event occurrences; count aggregations directly answer event-frequency questions.

---

## 6. Summary Matrix of Grains

| Fact Table | Grain Statement | Natural Grain Keys | Fact Type |
|---|---|---|---|
| `fact_daily_stock_price` | One row per listed stock on one trading day | `(date_key, stock_key)` | Periodic snapshot |
| `fact_market_daily` | One row represents the whole PSX market on one trading day | `date_key` | Periodic snapshot (aggregated) |
| `fact_sector_daily` | One row represents one sector on one trading day | `(date_key, sector_key)` | Periodic snapshot (aggregated) |
| `fact_policy_decision` | One row represents one SBP policy rate decision taking effect on a date | `date_key` | Transaction |
| `fact_market_event` | One row represents one event of one type for one stock on one trading day | `(date_key, stock_key, event_type_key)` | Factless fact |
