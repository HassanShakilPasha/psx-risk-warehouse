# Project Proposal
## PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange
**Course**: DL3004 Final Project - Phase 1: Business Analysis & Dimensional Design  
**Team**: Saqib Qazi (24L-2506) | Hassan Shakil (24L-2521) | Ammara Saleem (24L-2571)

---

## 1. Introduction
The Pakistan Stock Exchange (PSX) lists over 500 securities across more than 30 sectors. Every trading day it publishes an end-of-day Market Summary with the open, high, low, close, volume and previous close (LDCP) of every security. Between 2020 and 2026 the State Bank of Pakistan moved the policy rate from 7% to a record 22% and back down, while the market went through sharp rallies and sell-offs. This makes PSX a rich case for risk analytics.

This project designs and builds a **dimensional data warehouse** on eleven years of PSX data (2015 to October 2026, about 2,900 trading days and 1.09 million stock-day records) so that analysts can see where market risk sits, how it moves over time and how it reacts to monetary policy.

---

## 2. Problem Statement
The raw PSX files are one flat, pipe-delimited text file per day, compressed, with no history, no sector names and no risk measures. Answering a simple question such as *"which sectors were most volatile around the June 2023 rate hike?"* needs thousands of files to be combined, cleaned, adjusted for corporate actions and turned into volatility measures. There is no single, trusted, query-ready source for this analysis.

---

## 3. Objectives
- **Model the PSX business processes** (daily trading, market activity, sector performance, policy decisions, market events) as a star/snowflake schema.
- **Provide daily volatility and risk-tier measures** per stock, per sector and for the whole market.
- **Separate systemic (market-wide) from idiosyncratic (company-specific) risk**.
- **Link market behaviour to SBP policy rate decisions** for event analysis.
- **Track corporate actions, price-limit moves and no-trade days** as market events.
- **Deliver an interactive BI dashboard** on top of the warehouse.

---

## 4. Scope

| In scope | Out of scope |
|---|---|
| All securities in the PSX daily Market Summary, Jan 2015 to Oct 2026 (stocks, funds) | Intraday / tick-level trading data |
| SBP policy rate decisions over the same period | Price prediction or trading recommendations |
| Daily volatility, risk tiers, market breadth, sector aggregates, event tracking | Individual investor or account data (no PII) |
| Incremental daily loading and historical backfill | Futures and derivatives contracts (excluded from the stock model) |

---

## 5. Data Sources

| Source | Content | Frequency / Volume | Use |
|---|---|---|---|
| PSX Daily Market Summary (`dps.psx.com.pk`) | Symbol, sector code, company, OHLC, volume, LDCP per security | Daily; ~2,900 files; ~1.09M rows | `fact_daily_stock_price`, `dim_stock`, `dim_sector`, events |
| SBP Structure of Interest Rates | Policy rate and effective dates | Per decision; ~60 rows | `fact_policy_decision` |
| PSX Sector List (reference) | Sector code to name mapping | Static; ~35 rows | `dim_sector` |
| Generated Calendar | Dates 2015–2027 | Static; ~4,700 rows | `dim_date` |

---

## 6. Proposed Solution & Architecture
The warehouse follows a layered architecture (Staging → Dimensional Core → Reporting) implemented in PostgreSQL:

$$\text{PSX files + SBP rates} \longrightarrow \text{Staging Layer} \longrightarrow \text{Cleansed Layer} \longrightarrow \text{Dimensional Warehouse} \longrightarrow \text{Power BI Dashboard}$$

The dimensional layer is designed around five core business processes:

| Business process | Fact table | Fact type |
|---|---|---|
| Daily stock trading | `fact_daily_stock_price` | Periodic snapshot (daily) |
| Market-wide daily activity | `fact_market_daily` | Periodic snapshot (aggregated) |
| Sector daily performance | `fact_sector_daily` | Periodic snapshot (aggregated) |
| SBP monetary policy decisions | `fact_policy_decision` | Transaction |
| Market events | `fact_market_event` | Factless fact |

These facts share conformed dimensions: `dim_date`, `dim_stock` (SCD Type 2), `dim_sector` (snowflaked), `dim_risk_tier`, `dim_event_type`, and `dim_policy_action`.

---

## 7. Tools and Technologies
- **Database & Warehouse**: PostgreSQL 14+, pgAdmin 4
- **ETL & Data Processing**: Python 3.10+, Pandas, SQLAlchemy, psycopg2
- **Data Modelling**: DBML (dbdiagram.io), Draw.io, Excel
- **Business Intelligence**: Power BI Desktop (PostgreSQL native/ODBC connector)
- **Version Control**: Git and GitHub

---

## 8. Project Plan & Grading Milestones

| Phase | Duration | Weight | Key Deliverables |
|---|---|:---:|---|
| **Phase 1: Business Analysis & Design** | Weeks 1–3 | 30% | Proposal, BRD, 14 Business Questions, Fact/Dimension ID, Grain Definition, Schema (Conceptual/Logical/Physical), Data Dictionary |
| **Phase 2: DW Implementation & ETL** | Weeks 4–6 | 40% | Staging, Cleansed, Dimension & Fact DDL/ETL scripts, SCD handling, Data Cleaning & DQ Reports |
| **Phase 3: OLAP, BI & Optimization** | Weeks 7–8 | 30% | Analytical SQL (window functions), OLAP (ROLLUP/CUBE), Reporting Views, Indexing Report (`EXPLAIN ANALYZE`), 3-page Power BI Dashboard, Business Insights Report, Final Presentation |

---

## 9. Expected Outcomes
- A documented star/snowflake schema with **5 fact tables and 6 dimensions**.
- A warehouse answering **14 analytical questions** on risk, systemic stress, monetary policy, liquidity, and market events.
- A 3-page Power BI dashboard for risk monitoring at stock, sector, and market level.
