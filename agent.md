# PSX Market Risk Data Warehouse (DL3004 DWBI Final Project)
## Autonomous Agent Execution Guide & Step‑by‑Step Protocol (`agent.md`)

> **Document Purpose** – This file is the definitive, step‑by‑step roadmap for the AI Agent (Antigravity) and the student team to deliver the **DL3004 Data Warehousing & Business Intelligence** final project. Every rule, schema convention, deliverable, and grading rubric entry from the official university course briefs and the approved Phase 1 submission is codified here.

---

## 1. ACADEMIC CONTEXT & TEAM SPECIFICATION

- **Course**: DL3004 – Data Warehousing & Business Intelligence (DWBI)
- **Weighting**: 15% of total course grade
  - **Phase 1 (Weeks 1–3)**: Design & Business Analysis — **30%** *(COMPLETED & APPROVED)*
  - **Phase 2 (Weeks 4–6)**: Physical DW Implementation & ETL Pipeline — **40%** *(IN PROGRESS)*
  - **Phase 3 (Weeks 7–8)**: OLAP Analytics, Optimization & Power BI Dashboard — **30%** *(UPCOMING)*
- **Project Title**: *PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange*
- **Project Team**:
  - Saqib Qazi (24L-2506)
  - Hassan Shakil (24L-2521)
  - Ammara Saleem (24L-2571)

---

## 2. AGENT OPERATING PRINCIPLES & INTERACTION PROTOCOL

### 2.1 Strict Behavioral Directives
1. **One Step at a Time** – The agent must never batch‑execute multiple independent steps. After each step it:
   - Commits the change with a clear, conventional commit message.
   - Displays the exact Git diff.
   - Awaits explicit user confirmation before proceeding.
2. **Executable PostgreSQL** – All SQL is written for **PostgreSQL 14+** and tested with `psql`/pgAdmin:
   - Use `DOUBLE PRECISION` for continuous metrics (volatilities, returns).
   - Use `DECIMAL(12,4)` for equity prices and `DECIMAL(5,2)` for policy rates.
   - There is **no `TRY_CAST`** in PostgreSQL — use custom safe casting (`safe_cast_numeric`) or regex guards.
3. **Idempotent & Reproducible** – Every script must be safe to run repeatedly:
   - `DROP TABLE IF EXISTS … CASCADE` before `CREATE TABLE`.
   - `CREATE SCHEMA IF NOT EXISTS`.
   - `TRUNCATE … RESTART IDENTITY CASCADE` for staging and fact tables before reloads.
   - Deterministic random seeds (`random.seed(42)` / `numpy.random.seed(42)`) for any synthetic data generation.
4. **Zero‑Fabrication Policy** – Never fabricate row counts, runtimes, or query plan costs. Wherever a runtime metric is needed, execute the query or insert a placeholder such as `<PASTE EXPLAIN ANALYZE OUTPUT>`.
5. **Viva‑Readiness & Design Justification** – Every dimensional modeling decision (grain, surrogate‑key strategy, SCD type, snowflake on `dim_sector`, pre-aggregated daily snapshot facts) is grounded directly in the approved Phase 1 submission and must be justified to examiners in 1–3 concise sentences.
6. **No Secret Leaks** – All credentials are read from `.env` via `python‑dotenv`. Only a sanitized `.env.example` is committed.

---

## 3. OFFICIAL PHASE 1 DIMENSIONAL ARCHITECTURE

The dimensional model was officially submitted and approved in Phase 1 (`DWBI_Phase1/`). It comprises **5 Fact Tables** and **6 Dimensions** forming a conformed star/snowflake schema.

```
                         ┌─────────────────┐
                         │   dim_sector    │
                         │ (Snowflaked dim)│
                         └────────┬────────┘
                                  │ 1
                         ┌────────┴────────┐
                         │   dim_stock     │
                         │  (SCD Type 2)   │
                         └────────┬────────┘
                                  │ 1
        ┌─────────────────────────┼─────────────────────────┐
        │ many                    │ many                    │ many
        ▼                         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│fact_daily_stock_ │      │fact_sector_daily │      │fact_market_event │
│      price       │      │(Aggregated daily)│      │ (Factless fact)  │
│(Periodic snapshot│      └────────┬─────────┘      └────────┬─────────┘
└───────┬──────────┘               │                         │
        │ many                     │ many                    │ many
        └──────────────────────────┼─────────────────────────┘
                                   │
                                   ▼
                         ┌───────────────────┐
                         │     dim_date      │
                         │(Conformed Calendar│
                         └─────────▲─────────┘
                                   │ 1
        ┌──────────────────────────┴──────────────────────────┐
        │ many                                                │ many
┌───────┴──────────┐                                  ┌───────┴──────────┐
│fact_market_daily │                                  │fact_policy_decis.│
│(Aggregated daily)│                                  │ (Transaction)    │
└──────────────────┘                                  └─────────▲────────┘
                                                                │ many
                                                                │ 1
                                                      ┌─────────┴────────┐
                                                      │dim_policy_action │
                                                      │ (Static lookup)  │
                                                      └──────────────────┘
```

### 3.1 Dimensions
1. **`dim_date`** (Conformed Calendar Dimension):
   - Smart Key: `date_key INT PK` (`YYYYMMDD`).
   - Natural Key: `full_date DATE NOT NULL UNIQUE`.
   - Attributes: `day_of_month`, `day_name`, `day_of_week`, `week_of_year`, `month`, `month_name`, `quarter`, `year`, `year_month`, `is_weekend`, `is_trading_day`.
   - Hierarchies: $\text{Year} > \text{Quarter} > \text{Month} > \text{Day}$ and $\text{Year} > \text{Week} > \text{Day}$.
2. **`dim_sector`** (Snowflaked Dimension):
   - Key: `sector_key INT PK GENERATED ALWAYS AS IDENTITY`.
   - Natural Key: `sector_code VARCHAR NOT NULL UNIQUE`.
   - Attributes: `sector_name`, `sector_group`, `legacy_codes`.
   - Hierarchy: $\text{Sector Group} > \text{Sector}$.
3. **`dim_stock`** (SCD Type 2 Equity Dimension):
   - Key: `stock_key INT PK GENERATED ALWAYS AS IDENTITY`.
   - Natural Key: `symbol VARCHAR NOT NULL`.
   - Attributes: `company_name`, `sector_key FK -> dim_sector(sector_key)`, `first_trade_date`, `last_trade_date`, `is_active`, `effective_from`, `effective_to`, `is_current`.
   - Hierarchy: $\text{Sector Group} > \text{Sector} > \text{Stock}$.
4. **`dim_risk_tier`** (Static Lookup Dimension):
   - Key: `risk_tier_key INT PK` (Static keys: `1`=Low [0.00–0.40], `2`=Medium [0.40–0.80], `3`=High [0.80–1.00], `4`=Not Rated).
   - Attributes: `tier_name`, `percentile_min`, `percentile_max`, `tier_description`, `sort_order`.
5. **`dim_event_type`** (Static Lookup Dimension):
   - Key: `event_type_key INT PK` (Static keys: `1`=Bonus Issue, `2`=Stock Split, `3`=Rights Issue, `4`=Price-Limit Lock).
   - Attributes: `event_type_code`, `event_type_name`, `event_category`, `detection_rule`.
6. **`dim_policy_action`** (Static Lookup Dimension):
   - Key: `policy_action_key INT PK` (Static keys: `1`=Hike, `2`=Cut, `3`=Hold).
   - Attributes: `action_name`, `action_description`.

### 3.2 Fact Tables & Grains
1. **`fact_daily_stock_price`** (Periodic Snapshot Fact — Daily):
   - Grain: *"One row represents one listed stock on one trading day."*
   - Keys: `date_key PK/FK`, `stock_key PK/FK`, `risk_tier_key FK`.
   - Measures: `open_price`, `high_price`, `low_price`, `close_price`, `ldcp`, `volume`, `daily_log_return`, `price_range_pct`, `volatility_20d`, `volatility_60d`, `avg_volume_20d`, `risk_percentile`, `is_traded`, `is_ohlc_valid`, `load_timestamp`.
2. **`fact_market_daily`** (Periodic Snapshot Fact — Daily, Aggregated):
   - Grain: *"One row represents the whole PSX market on one trading day."*
   - Keys: `date_key PK/FK`.
   - Measures: `stocks_listed`, `stocks_traded`, `advancers`, `decliners`, `total_volume`, `market_return`, `market_volatility_20d`, `median_stock_volatility_20d`, `pct_stocks_high_risk`, `load_timestamp`.
3. **`fact_sector_daily`** (Periodic Snapshot Fact — Daily, Aggregated):
   - Grain: *"One row represents one sector on one trading day."*
   - Keys: `date_key PK/FK`, `sector_key PK/FK`.
   - Measures: `stocks_traded`, `sector_volume`, `avg_return`, `avg_volatility_20d`, `pct_high_risk`, `load_timestamp`.
4. **`fact_policy_decision`** (Transaction Fact):
   - Grain: *"One row represents one SBP policy rate decision taking effect on a date."*
   - Keys: `date_key PK/FK`, `policy_action_key FK`.
   - Measures: `policy_rate_pct`, `previous_rate_pct`, `change_bps`, `load_timestamp`.
5. **`fact_market_event`** (Factless Fact — Event Tracking):
   - Grain: *"One row represents one event of one type for one stock on one trading day."*
   - Keys: `date_key PK/FK`, `stock_key PK/FK`, `event_type_key PK/FK`, `load_timestamp`.

---

## 4. REPOSITORY DIRECTORY SCAFFOLD

```
psx-risk-warehouse/
├── 01_Project_Documentation/
│   ├── Course_Specs/                            # Official course & lab PDF briefs
│   │   ├── DWBI Final Project Overview.pdf
│   │   ├── DWBI Lab Phase 1.pdf
│   │   ├── DWBI Lab Phase 2.pdf
│   │   └── DWBI Lab Phase 3.pdf
│   ├── Phase_1_Submission/                      # Official graded Phase 1 submission files
│   │   ├── 01_Project_Proposal.pdf
│   │   ├── 02_Business_Requirements_Document.pdf
│   │   ├── 03_Business_Questions.pdf
│   │   ├── 04_Fact_and_Dimension_Identification.pdf
│   │   ├── 05_Grain_Definition.pdf
│   │   ├── 06_Schema_1_Conceptual.png
│   │   ├── 06_Schema_2_Logical.png
│   │   ├── 06_Schema_3_Physical.png
│   │   ├── 06_Star_Snowflake_Schema_Diagram.pdf
│   │   └── 07_Data_Dictionary.xlsx
│   ├── Proposal.md                              # Markdown representation of Proposal
│   ├── BRD.md                                   # Markdown representation of BRD
│   ├── Business_Questions.md                    # 14 Business Questions mapped to DW
│   ├── Fact_Dimension_ID.md                     # Bus Matrix, Fact/Dim classification
│   ├── Grain_Definition.md                      # Formal grain definitions
│   ├── schema.dbml                              # Physical schema definition in DBML
│   ├── data_dictionary.csv                      # Full column dictionary exported from Excel
│   ├── Data_Cleaning_Report.md                  # Phase 2: Cleaning audit & transformations
│   ├── Data_Quality_Report.md                   # Phase 2: DQ checks (completeness, accuracy, integrity)
│   ├── Indexing_Report.md                       # Phase 3: EXPLAIN ANALYZE comparison report
│   ├── Business_Insights_Report.md              # Phase 3: Executive business recommendations
│   └── Presentation_Outline.md                  # Phase 3: 10–12 slide viva outline
├── 02_Data/
│   ├── raw_data/                                # Raw daily CSVs (5 stocks + 1 index from PSX)
│   ├── supplementary/                           # Reference lookup CSVs (rates, sectors, metadata)
│   │   ├── sbp_policy_rates.csv                 # SBP interest rate announcements (2015–2026)
│   │   └── stock_metadata.csv                   # Symbol-to-sector and company name mappings
│   ├── cleaned_data/                            # Transformed/validated extracts
│   └── generate_data.py                         # Deterministic synthetic generator (≥95 extra stocks)
├── 03_ETL/
│   ├── staging.sql                              # Staging DDL (schema: project_staging)
│   ├── load_staging.py                          # Bulk CSV copy into staging layer
│   ├── cleaning.sql                             # SQL transformations (dedup, standardization, casts)
│   ├── dimensions.sql                           # Dimension loaders (surrogate keys, Unknown row -1)
│   ├── facts.sql                                # Fact loaders (surrogate key lookup joins)
│   ├── data_quality.sql                         # Automated DQ audit suite (0 orphans, 0 recon gap)
│   └── run_etl.py                               # Master Python ETL pipeline orchestrator
├── 04_Data_Warehouse/
│   ├── 00_setup.sql                             # Database & 3-schema creation
│   └── warehouse.sql                            # Full Star/Snowflake DDL (PK/FK/SK/constraints)
├── 05_Analytics/
│   ├── analytics.sql                            # Window functions, LAG() returns, rankings
│   ├── OLAP.sql                                 # Multidimensional ROLLUP & CUBE with GROUPING()
│   ├── Views.sql                                # Reporting views in project_reporting
│   └── indexing/                                # EXPLAIN ANALYZE execution plans before/after
├── 06_Dashboard/
│   ├── PSX_Risk_Dashboard.pbix                  # 3-Page Power BI Desktop model connected to PostgreSQL
│   ├── PSX_Risk_Dashboard.pdf                   # Complete export of all dashboard pages
│   └── screenshots/                             # High-resolution visual screenshots
├── .env.example
├── .gitignore
├── requirements.txt
├── README.md
├── agent.md
└── fixes.md
```

---

## 5. MASTER EXECUTION ROADMAP BY PHASE

### PHASE 1 — Business Analysis & Dimensional Design (100% COMPLETE)
- [x] **Proposal** (`01_Project_Documentation/Proposal.md` & `Phase_1_Submission/01_Project_Proposal.pdf`)
- [x] **BRD** (`01_Project_Documentation/BRD.md` & `Phase_1_Submission/02_Business_Requirements_Document.pdf`)
- [x] **14 Business Questions** (`01_Project_Documentation/Business_Questions.md` & `Phase_1_Submission/03_Business_Questions.pdf`)
- [x] **Fact & Dimension ID + Bus Matrix** (`01_Project_Documentation/Fact_Dimension_ID.md` & `Phase_1_Submission/04_Fact_and_Dimension_Identification.pdf`)
- [x] **Grain Definition Document** (`01_Project_Documentation/Grain_Definition.md` & `Phase_1_Submission/05_Grain_Definition.pdf`)
- [x] **Star/Snowflake Schema** (`01_Project_Documentation/schema.dbml` & `Phase_1_Submission/06_Star_Snowflake_Schema_Diagram.pdf`)
- [x] **Data Dictionary** (`01_Project_Documentation/data_dictionary.csv` & `Phase_1_Submission/07_Data_Dictionary.xlsx`)

---

### PHASE 2 — Physical Data Warehouse Implementation & ETL (IN PROGRESS)

| Step | Script / Deliverable | Purpose & Validation Rules |
|:---:|---|---|
| **2.1a** | `02_Data/supplementary/sbp_policy_rates.csv` | Historical SBP policy rate announcements (effective date, rate %, change bps) from 2015 to 2026 (~60 decisions). |
| **2.1b** | `02_Data/supplementary/stock_metadata.csv` | Master lookup mapping symbols to company names, sector codes, and sector names. |
| **2.1c** | `02_Data/generate_data.py` | Python generator (`numpy.random.seed(42)`) creating ≥95 realistic stock CSVs in `02_Data/raw_data/` so the dataset exceeds the lab minimum of **≥100 dimension records** and **≥10,000 fact rows**. |
| **2.2** | `04_Data_Warehouse/00_setup.sql` | Idempotent setup creating database `dwbi_project` and three schemas: `project_staging`, `project_dw`, `project_reporting`. |
| **2.3** | `03_ETL/staging.sql` | DDL for permissive staging tables (`TEXT` types) to guarantee zero drop during ingestion: `stg_daily_prices`, `stg_policy_rates`, `stg_stock_metadata`. |
| **2.4** | `03_ETL/load_staging.py` | Python streaming loader extracting `symbol` from CSV filenames, loading all raw data via PostgreSQL `COPY`. Handles UTF-8/Latin-1. Truncates before load. |
| **2.5** | `03_ETL/cleaning.sql` | SQL transformations in staging: deduplication (`ROW_NUMBER()`), whitespace trimming, upper-casing symbols, safe numeric casting (`safe_cast_numeric`), and populating `stg_daily_prices_clean`. Excludes futures (`symbol LIKE '%-%'`). |
| **2.6** | `04_Data_Warehouse/warehouse.sql` | Creates full dimensional DDL in `project_dw`: 6 dimensions (`dim_date`, `dim_sector`, `dim_stock`, `dim_risk_tier`, `dim_event_type`, `dim_policy_action`) and 5 facts (`fact_daily_stock_price`, `fact_market_daily`, `fact_sector_daily`, `fact_policy_decision`, `fact_market_event`) with primary keys, identity surrogate keys, foreign keys, and indexes. |
| **2.7** | `03_ETL/dimensions.sql` | Loads static lookup dimensions (keys 1–4), generates calendar `dim_date` (2015–2027) via `generate_series`, inserts the **Unknown Member (`-1`)** on all dimensions, and loads `dim_sector` and `dim_stock` (SCD Type 2). |
| **2.8** | `03_ETL/facts.sql` | Idempotent fact loading (`TRUNCATE … RESTART IDENTITY CASCADE`). Joins staging to dimensions on natural keys (`symbol`, `full_date`). Derives returns, 20d/60d rolling volatility, percentiles, and risk tiers. Aggregates `fact_market_daily` and `fact_sector_daily`. |
| **2.9** | `03_ETL/data_quality.sql` | Automated DQ audit suite testing: (1) Completeness (zero nulls in PK/FK), (2) Row-count reconciliation (staging vs fact = 0 diff), (3) Measure reconciliation (total volume match), (4) FK Integrity (zero orphan records across all FK paths). |
| **2.10**| `03_ETL/run_etl.py` | Master orchestrator running steps 2.3 through 2.9 sequentially with logging to `03_ETL/etl.log` and transaction rollback on error. |
| **2.11**| `01_Project_Documentation/Data_Cleaning_Report.md` | Documents transformations, before/after record counts, and malformed data handling. |
| **2.12**| `01_Project_Documentation/Data_Quality_Report.md` | Documents automated DQ audit results with real SQL outputs (0 orphans, 0 reconciliation gap). |

---

### PHASE 3 — OLAP Analytics, Optimization & BI Dashboard (UPCOMING)

| Step | Script / Deliverable | Purpose & Validation Rules |
|:---:|---|---|
| **3.1** | `05_Analytics/Views.sql` | Production reporting views in `project_reporting`: `vw_monthly_market`, `vw_sector_risk`, `vw_stock_performance`. |
| **3.2** | `05_Analytics/analytics.sql` | Analytical SQL queries using window functions (`LAG()`, `RANK()`, rolling averages) answering the 14 business questions. |
| **3.3** | `05_Analytics/OLAP.sql` | Advanced multidimensional queries using `ROLLUP` (hierarchical subtotals: Sector Group → Sector → Stock) and `CUBE` (cross-tab: Sector × Volatility Regime) with `GROUPING()` functions. |
| **3.4** | `05_Analytics/indexing/` & `Indexing_Report.md` | Compares execution time and query cost via `EXPLAIN (ANALYZE, BUFFERS)` before and after creating B-Tree composite indexes. |
| **3.5** | `06_Dashboard/PSX_Risk_Dashboard.pbix` | 3-Page Power BI Desktop model connected to PostgreSQL: (1) Executive Overview, (2) Detailed Sector & Volatility Analysis, (3) Strategic Decision Page. |
| **3.6** | `01_Project_Documentation/Business_Insights_Report.md` | Executive synthesis answering the 14 business questions with actionable strategic recommendations. |
| **3.7** | `01_Project_Documentation/Presentation_Outline.md` | 10–12 slide viva presentation deck covering business problem, dimensional model, ETL pipeline, OLAP findings, and dashboard demonstration. |

---

## 6. TECHNICAL PATTERNS & CODE TEMPLATES

### 6.1 Dimension Load Pattern with Unknown (-1) Member
```sql
-- Step 1: Pre-populate Unknown row
INSERT INTO project_dw.dim_sector (sector_key, sector_code, sector_name, sector_group, legacy_codes)
OVERRIDING SYSTEM VALUE
VALUES (-1, 'UNKNOWN', 'Unknown Sector', 'Unknown', NULL)
ON CONFLICT (sector_key) DO NOTHING;

INSERT INTO project_dw.dim_stock (stock_key, symbol, company_name, sector_key, first_trade_date, last_trade_date, is_active, effective_from, effective_to, is_current)
OVERRIDING SYSTEM VALUE
VALUES (-1, 'UNKNOWN', 'Unknown Stock', -1, '2015-01-01', '9999-12-31', TRUE, '2015-01-01', NULL, TRUE)
ON CONFLICT (stock_key) DO NOTHING;
```

### 6.2 Fact Load Pattern with Surrogate Key Mapping
```sql
TRUNCATE project_dw.fact_daily_stock_price RESTART IDENTITY CASCADE;

INSERT INTO project_dw.fact_daily_stock_price (
    date_key, stock_key, risk_tier_key,
    open_price, high_price, low_price, close_price, ldcp,
    volume, daily_log_return, price_range_pct,
    volatility_20d, volatility_60d, avg_volume_20d, risk_percentile,
    is_traded, is_ohlc_valid, load_timestamp
)
SELECT
    COALESCE(d.date_key, -1),
    COALESCE(s.stock_key, -1),
    COALESCE(r.risk_tier_key, 4), -- Default 4 = Not Rated
    c.open_price, c.high_price, c.low_price, c.close_price, c.ldcp,
    c.volume, c.daily_log_return, c.price_range_pct,
    c.volatility_20d, c.volatility_60d, c.avg_volume_20d, c.risk_percentile,
    c.volume > 0 AS is_traded,
    (c.low_price <= c.open_price AND c.open_price <= c.high_price AND
     c.low_price <= c.close_price AND c.close_price <= c.high_price AND
     c.close_price > 0) AS is_ohlc_valid,
    CURRENT_TIMESTAMP
FROM project_staging.stg_daily_prices_clean c
LEFT JOIN project_dw.dim_date d ON d.full_date = c.trade_date
LEFT JOIN project_dw.dim_stock s ON s.symbol = c.symbol AND s.is_current = TRUE
LEFT JOIN project_dw.dim_risk_tier r ON c.risk_percentile >= r.percentile_min AND c.risk_percentile < r.percentile_max;
```

### 6.3 Automated Data Quality Checks
```sql
-- 1. FK Integrity (Zero Orphans)
SELECT 'fact_daily_stock_price -> dim_stock' AS relationship, COUNT(*) AS orphan_count
FROM project_dw.fact_daily_stock_price f
LEFT JOIN project_dw.dim_stock s ON f.stock_key = s.stock_key
WHERE s.stock_key IS NULL
UNION ALL
SELECT 'fact_daily_stock_price -> dim_date', COUNT(*)
FROM project_dw.fact_daily_stock_price f
LEFT JOIN project_dw.dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

-- 2. Row Count & Volume Reconciliation
SELECT
    (SELECT COUNT(*) FROM project_staging.stg_daily_prices_clean) AS stg_rows,
    (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price)      AS fact_rows,
    (SELECT COUNT(*) FROM project_staging.stg_daily_prices_clean) -
    (SELECT COUNT(*) FROM project_dw.fact_daily_stock_price)      AS row_discrepancy;
```

---

## 7. IMMEDIATE ACTION ITEMS (READY FOR EXECUTION)
1. **Data Source Supplements**: Create `02_Data/supplementary/sbp_policy_rates.csv`, `02_Data/supplementary/stock_metadata.csv`, and `02_Data/generate_data.py` (Step 2.1).
2. **Database Setup**: Execute `04_Data_Warehouse/00_setup.sql` to establish `project_staging`, `project_dw`, and `project_reporting` (Step 2.2).
3. **ETL Implementation**: Author and execute `staging.sql`, `load_staging.py`, `cleaning.sql`, `warehouse.sql`, `dimensions.sql`, `facts.sql`, and `data_quality.sql` (Steps 2.3–2.9).
