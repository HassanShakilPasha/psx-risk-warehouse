# Fact and Dimension Identification
## PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange
**Course**: DL3004 Final Project - Phase 1: Business Analysis & Dimensional Design  
**Team**: Saqib Qazi (24L-2506) | Hassan Shakil (24L-2521) | Ammara Saleem (24L-2571)

---

## 1. Business Processes & Fact Table Classification

Each business process that produces measurable events becomes a fact table. The choice of fact type follows how the business process generates data:

| Business Process | Fact Table | Fact Type | Why This Type? |
|---|---|---|---|
| **Daily stock trading** | `fact_daily_stock_price` | Periodic snapshot | PSX publishes the state of every security at end-of-day; one row per stock per day at a regular cadence. |
| **Market-wide daily activity** | `fact_market_daily` | Periodic snapshot (aggregate) | Market measures (breadth, market volatility) are calculated once per day for the entire exchange. Pre-aggregation avoids repeated 1M+ row scans. |
| **Sector daily performance** | `fact_sector_daily` | Periodic snapshot (aggregate) | Sector queries are frequent; a pre-aggregated daily sector table guarantees sub-second response times. |
| **SBP monetary policy decisions** | `fact_policy_decision` | Transaction | Each policy decision is a discrete event that occurs on irregular dates. |
| **Market events** | `fact_market_event` | Factless fact | Records that an event occurred (stock, date, event type) with no additive numeric measure; analysis counts occurrences. |

---

## 2. Enterprise Bus Matrix

The bus matrix shows which conformed dimensions each fact uses. Shared dimensions ensure facts can be sliced and diced across identical axes:

| Fact Table | `dim_date` | `dim_sector` | `dim_stock` | `dim_risk_tier` | `dim_event_type` | `dim_policy_action` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `fact_daily_stock_price` | ✓ | ✓ *(via stock)* | ✓ | ✓ | | |
| `fact_market_daily` | ✓ | | | | | |
| `fact_sector_daily` | ✓ | ✓ | | | | |
| `fact_policy_decision` | ✓ | | | | | ✓ |
| `fact_market_event` | ✓ | ✓ *(via stock)* | ✓ | | ✓ | |

---

## 3. Fact Tables and Measures

### 3.1 `fact_daily_stock_price` — Periodic Snapshot Fact (Daily)
- **Process**: Daily stock trading (end-of-day market summary)
- **Foreign Keys**: `date_key`, `stock_key`, `risk_tier_key`

| Measure | Description | Data Type | Additivity |
|---|---|---|---|
| `open_price` | Opening price (PKR); may be blank in source | `DECIMAL(12,4)` | Non-additive |
| `high_price` | Day high (PKR) | `DECIMAL(12,4)` | Non-additive |
| `low_price` | Day low (PKR) | `DECIMAL(12,4)` | Non-additive |
| `close_price` | Closing price (PKR) | `DECIMAL(12,4)` | Non-additive |
| `ldcp` | Last Day Close Price adjusted for corporate actions | `DECIMAL(12,4)` | Non-additive |
| `volume` | Number of shares traded | `BIGINT` | Additive |
| `daily_log_return` | $\ln(\text{close\_price} / \text{ldcp})$ | `DOUBLE PRECISION` | Non-additive |
| `price_range_pct` | $(\text{high} - \text{low}) / \text{ldcp}$: intraday range | `DOUBLE PRECISION` | Non-additive |
| `volatility_20d` | Annualized standard deviation of last 20 daily returns | `DOUBLE PRECISION` | Non-additive |
| `volatility_60d` | Annualized standard deviation of last 60 daily returns | `DOUBLE PRECISION` | Non-additive |
| `avg_volume_20d` | 20-day rolling average volume (liquidity gauge) | `DOUBLE PRECISION` | Non-additive |
| `risk_percentile` | Cross-sectional percentile rank of `volatility_20d` (0–1) | `DOUBLE PRECISION` | Non-additive |

### 3.2 `fact_market_daily` — Periodic Snapshot Fact (Daily, Aggregated)
- **Process**: Market-wide daily activity
- **Foreign Keys**: `date_key`

| Measure | Description | Data Type | Additivity |
|---|---|---|---|
| `stocks_listed` | Stocks present in that day's market summary | `INT` | Semi-additive |
| `stocks_traded` | Stocks with volume > 0 | `INT` | Semi-additive |
| `advancers` | Stocks closing higher than LDCP | `INT` | Semi-additive |
| `decliners` | Stocks closing lower than LDCP | `INT` | Semi-additive |
| `total_volume` | Total shares traded across all market securities | `BIGINT` | Additive |
| `market_return` | Equal-weighted average daily log return | `DOUBLE PRECISION` | Non-additive |
| `market_volatility_20d` | 20-day annualized rolling volatility of market return | `DOUBLE PRECISION` | Non-additive |
| `median_stock_volatility_20d` | Cross-sectional median stock volatility | `DOUBLE PRECISION` | Non-additive |
| `pct_stocks_high_risk` | Share of stocks in High risk tier (systemic stress gauge) | `DOUBLE PRECISION` | Non-additive |

### 3.3 `fact_sector_daily` — Periodic Snapshot Fact (Daily, Aggregated)
- **Process**: Sector daily performance
- **Foreign Keys**: `date_key`, `sector_key`

| Measure | Description | Data Type | Additivity |
|---|---|---|---|
| `stocks_traded` | Stocks in sector with volume > 0 | `INT` | Semi-additive |
| `sector_volume` | Total shares traded in sector | `BIGINT` | Additive |
| `avg_return` | Equal-weighted average return of sector stocks | `DOUBLE PRECISION` | Non-additive |
| `avg_volatility_20d` | Equal-weighted average volatility of sector stocks | `DOUBLE PRECISION` | Non-additive |
| `pct_high_risk` | Share of sector stocks in High risk tier | `DOUBLE PRECISION` | Non-additive |

### 3.4 `fact_policy_decision` — Transaction Fact
- **Process**: Monetary policy announcements (State Bank of Pakistan)
- **Foreign Keys**: `date_key`, `policy_action_key`

| Measure | Description | Data Type | Additivity |
|---|---|---|---|
| `policy_rate_pct` | Policy rate after the decision | `DECIMAL(5,2)` | Non-additive |
| `previous_rate_pct` | Policy rate prior to the decision | `DECIMAL(5,2)` | Non-additive |
| `change_bps` | Change in basis points (+ hike, - cut, 0 hold) | `INT` | Additive |

### 3.5 `fact_market_event` — Factless Fact (Event Tracking)
- **Process**: Market events (corporate actions, price limits, trading halts)
- **Foreign Keys**: `date_key`, `stock_key`, `event_type_key`
- **Measures**: None (factless). Analytical queries perform counts of event occurrences.

---

## 4. Dimensions, Attributes, and Hierarchies

| Dimension | Type | Attributes | Hierarchy | Change Handling |
|---|---|---|---|---|
| **`dim_date`** | Conformed | `date_key`, `full_date`, `day_of_month`, `day_name`, `day_of_week`, `week_of_year`, `month`, `month_name`, `quarter`, `year`, `year_month`, `is_weekend`, `is_trading_day` | $\text{Year} > \text{Quarter} > \text{Month} > \text{Day}$; $\text{Year} > \text{Week} > \text{Day}$ | Static (generated once, 2015–2027) |
| **`dim_sector`** | Dimension (Snowflaked) | `sector_key`, `sector_code`, `sector_name`, `sector_group`, `legacy_codes` | $\text{Sector Group} > \text{Sector}$ | Type 1 (overwrite name corrections) |
| **`dim_stock`** | Dimension (SCD Type 2) | `stock_key`, `symbol`, `company_name`, `sector_key`, `first_trade_date`, `last_trade_date`, `is_active`, `effective_from`, `effective_to`, `is_current` | $\text{Sector Group} > \text{Sector} > \text{Stock}$ | Type 2 on `company_name` and `sector_key` (preserves historical classification) |
| **`dim_risk_tier`** | Static Lookup | `risk_tier_key`, `tier_name`, `percentile_min`, `percentile_max`, `tier_description`, `sort_order` | None | Static |
| **`dim_event_type`** | Static Lookup | `event_type_key`, `event_type_code`, `event_type_name`, `event_category`, `detection_rule` | $\text{Event Category} > \text{Event Type}$ | Static |
| **`dim_policy_action`**| Static Lookup | `policy_action_key`, `action_name`, `action_description` | None | Static |

---

## 5. Natural and Surrogate Key Architecture

Every dimension utilizes an integer surrogate key (`INT GENERATED ALWAYS AS IDENTITY`), retaining the source natural key for traceability:

| Dimension | Natural Key (Source) | Surrogate Key | Strategy |
|---|---|---|---|
| `dim_date` | `full_date` (`DATE`) | `date_key` (`INT`) | Smart Key `YYYYMMDD` (readable, partitionable, sortable) |
| `dim_stock` | `symbol` (`VARCHAR`) | `stock_key` (`INT`) | Auto-increment sequence; new key allocated per SCD2 version |
| `dim_sector` | `sector_code` (`VARCHAR`) | `sector_key` (`INT`) | Auto-increment sequence; maps legacy codes to canonical key |
| `dim_risk_tier` | `tier_name` (`VARCHAR`) | `risk_tier_key` (`INT`) | Static sequence 1–4 |
| `dim_event_type` | `event_type_code` (`VARCHAR`)| `event_type_key` (`INT`)| Static sequence 1–4 |
| `dim_policy_action`| `action_name` (`VARCHAR`) | `policy_action_key` (`INT`)| Static sequence 1–3 |

---

## 6. Key Design Decisions (Viva Justification)
1. **Snowflake on Sector**: `dim_stock` references `dim_sector` so sector names and hierarchies are maintained once and shared cleanly with `fact_sector_daily`.
2. **SCD Type 2 on Stock**: When companies rename or reclassify sectors, new surrogate keys preserve the sector mapping that was active on the actual trading date.
3. **Conformed Date Dimension**: Plays the role of trading date, monetary policy decision date, and event date, allowing seamless cross-fact event-window joins.
4. **Static Lookups**: Pre-populated dimensions (`dim_risk_tier`, `dim_event_type`, `dim_policy_action`) provide human-readable labels and deterministic sort orders for Power BI visuals.
5. **Pre-aggregated Snapshot Facts**: Aggregating market and sector metrics into daily snapshots eliminates costly scans of 1M+ stock records during BI filtering.
