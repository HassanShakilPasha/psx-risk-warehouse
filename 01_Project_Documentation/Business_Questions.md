# Business Questions
## PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange
**Course**: DL3004 Final Project - Phase 1: Business Analysis & Dimensional Design  
**Team**: Saqib Qazi (24L-2506) | Hassan Shakil (24L-2521) | Ammara Saleem (24L-2571)

The warehouse is designed to answer the following **14 analytical questions**. They are grouped by business area, and each is mapped to the fact table, dimensions, and measures that answer it. The dimensional model follows the business questions, not the layout of the source files.

---

## 1. Risk & Volatility

| # | Business Question | Fact Table(s) | Dimensions | Measures |
|:---:|---|---|---|---|
| **Q1** | Which stocks are currently in the High volatility tier, and how volatile are they? | `fact_daily_stock_price` | `dim_stock`, `dim_risk_tier`, `dim_date` | `volatility_20d`, `risk_tier` |
| **Q2** | Which sectors have the highest average 20-day volatility each month? | `fact_sector_daily` | `dim_sector`, `dim_date` | `avg_volatility_20d` |
| **Q3** | How has market volatility trended by month and year from 2015 to 2026? | `fact_market_daily` | `dim_date` | `market_volatility_20d` |
| **Q4** | Which stocks spent the most trading days in the High risk tier in a given year? | `fact_daily_stock_price` | `dim_stock`, `dim_risk_tier`, `dim_date` | count of days by tier |

---

## 2. Systemic vs Idiosyncratic Risk

| # | Business Question | Fact Table(s) | Dimensions | Measures |
|:---:|---|---|---|---|
| **Q5** | On which days and months was turbulence market-wide (a high share of stocks in the High tier)? | `fact_market_daily` | `dim_date` | `pct_stocks_high_risk` |
| **Q6** | Which stocks were highly volatile while the overall market was calm (company-specific risk)? | `fact_daily_stock_price`, `fact_market_daily` | `dim_stock`, `dim_date` | `volatility_20d` vs `market_volatility_20d` |
| **Q7** | How does market breadth (advancers vs decliners) change during high-volatility periods? | `fact_market_daily` | `dim_date` | `advancers`, `decliners` |

---

## 3. Monetary Policy Transmission

| # | Business Question | Fact Table(s) | Dimensions | Measures |
|:---:|---|---|---|---|
| **Q8** | How does market volatility change in the 10 trading days before and after an SBP policy rate decision? | `fact_policy_decision`, `fact_market_daily` | `dim_date`, `dim_policy_action` | `market_volatility_20d` |
| **Q9** | Do rate hikes and rate cuts affect market returns and volatility differently? | `fact_policy_decision`, `fact_market_daily` | `dim_policy_action`, `dim_date` | `market_return`, `change_bps` |
| **Q10** | Which sectors are most sensitive to policy rate changes (e.g. banks vs cement)? | `fact_sector_daily`, `fact_policy_decision` | `dim_sector`, `dim_date`, `dim_policy_action` | `avg_return`, `avg_volatility_20d` |

---

## 4. Liquidity & Trading Activity

| # | Business Question | Fact Table(s) | Dimensions | Measures |
|:---:|---|---|---|---|
| **Q11** | Which stocks and sectors trade the most volume, and is low liquidity linked to higher risk? | `fact_daily_stock_price` | `dim_stock`, `dim_sector`, `dim_risk_tier` | `avg_volume_20d`, `volatility_20d` |
| **Q12** | How many stocks were listed and actively traded each year, and which stocks were delisted? | `fact_market_daily`, `dim_stock` | `dim_date`, `dim_stock` | `stocks_listed`, `stocks_traded`, `is_active` |

---

## 5. Market Events & Tail Risk

| # | Business Question | Fact Table(s) | Dimensions | Measures |
|:---:|---|---|---|---|
| **Q13** | Which stocks had corporate action adjustments (bonus, split, rights) and how often? | `fact_market_event` | `dim_stock`, `dim_event_type`, `dim_date` | count of events |
| **Q14** | Which stocks hit price-limit moves most often, and in which periods? | `fact_market_event` | `dim_stock`, `dim_event_type`, `dim_date` | count of events |

---

## 6. Strategic Rationale: Why These Questions Matter
- **Risk & Volatility (Q1–Q4)**: Informs risk managers where capital is exposed today and reveals cyclical volatility regimes.
- **Systemic vs Idiosyncratic (Q5–Q7)**: Enables portfolio managers to distinguish macro shocks from company-specific failures, determining whether hedging or selective divestment is warranted.
- **Monetary Policy (Q8–Q10)**: Quantifies the transmission mechanism of SBP policy rate revisions to asset valuations and capital costs.
- **Liquidity & Activity (Q11–Q12)**: Differentiates artificial volatility caused by thin liquidity from true information discovery.
- **Market Events (Q13–Q14)**: Separates corporate capitalization adjustments from market-driven drawdowns.
