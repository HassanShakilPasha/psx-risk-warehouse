# Pakistan Stock Exchange (PSX) Risk Data Warehouse
### DL3004 — Data Warehousing & Business Intelligence (DWBI) Final Project

[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL%2014+-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![pgAdmin](https://img.shields.io/badge/GUI-pgAdmin%204-326690?logo=postgresql&logoColor=white)](https://www.pgadmin.org/)
[![Python](https://img.shields.io/badge/ETL-Python%203.10+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Power BI](https://img.shields.io/badge/BI-Power%20BI%20Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)

---

## 1. Executive Summary & Business Scenario

The **Pakistan Stock Exchange (PSX) Risk Data Warehouse** is an enterprise-grade dimensional data warehouse designed to analyze equity market volatility, sector risk regimes, liquidity dynamics, and the transmission of macroeconomic interest rate decisions by the **State Bank of Pakistan (SBP)**.

In emerging capital markets like Pakistan, risk is non-linear and tends to cluster: calm market periods are punctuated by sharp macro shocks, currency adjustments, and monetary policy rate revisions. This project ingests daily market trading summaries and central bank policy decisions, cleans and structures them through a multi-tier PostgreSQL warehouse, and powers multidimensional OLAP cubes and executive BI dashboards.

### Core Business Objectives & Questions
1. **Macro Regime Impact:** How do SBP policy rate revisions impact overall market liquidity, trading volumes, and systemic volatility?
2. **Sector & Stock Concentration Risk:** Which industrial sectors (e.g., Commercial Banks, Oil & Gas, Fertilizers, Cement) display heightened turbulence, and are risk clusters idiosyncratic or market-wide?
3. **Extreme Events & Liquidity Dry-Ups:** What are the historical distribution patterns of extreme tail events (price swings exceeding $\pm 10\%$) across market sectors over time?

---

## 2. End-to-End Pipeline Architecture

The project strictly follows the enterprise **Three-Schema Data Warehouse Architecture** implemented in PostgreSQL:

```
┌────────────────────────────────────────────────────────┐
│                     SOURCE SYSTEMS                     │
│  - PSX Daily Market Summaries (Closing Prices & Volumes) │
│  - SBP Policy Rate Announcements (Monetary Policy)     │
│  - PSX Sector Classification Master Data               │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Ingestion (`load_staging.py` / PostgreSQL COPY)
                            ▼
┌────────────────────────────────────────────────────────┐
│                 SCHEMA: project_staging                │
│  - Permissive TEXT data types to guarantee zero drop   │
│  - Raw landing tables: stg_daily_prices, stg_rates     │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Cleaning & Transformation (`cleaning.sql`)
                            │ (Deduplication, TRIM, INITCAP, NULL handling, Casts)
                            ▼
┌────────────────────────────────────────────────────────┐
│                   SCHEMA: project_dw                   │
│  - Star Schema Dimensional Model                       │
│  - Dimensions with Surrogate Keys & Unknown (-1) row:  │
│      dim_date, dim_stock, dim_sector                   │
│  - Fact Tables with Foreign Key Constraints:           │
│      fact_daily_trading, fact_risk_snapshot            │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Aggregations, Window Functions & OLAP
                            ▼
┌────────────────────────────────────────────────────────┐
│               SCHEMA: project_reporting                │
│  - Reporting Views:                                    │
│      vw_monthly_market, vw_sector_risk, vw_stock_perf  │
│  - Advanced OLAP: ROLLUP, CUBE, GROUPING()             │
│  - Query Optimization via B-Tree Indexing              │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ PostgreSQL Native Connector / ODBC
                            ▼
┌────────────────────────────────────────────────────────┐
│                 POWER BI DESKTOP (PBIX)                │
│  - Page 1: Executive Market Overview (KPIs & Trends)   │
│  - Page 2: Detailed Sector & Volatility Analysis       │
│  - Page 3: Strategic Risk Decision & Recommendations   │
└────────────────────────────────────────────────────────┘
```

---

## 3. Repository Directory Structure

Conforming strictly to the university project specification:

```
psx-risk-warehouse/
├── 01_Project_Documentation/        # Graded academic reports & specifications
│   ├── Proposal.md                  # Phase 1: Project Proposal & Problem Statement
│   ├── BRD.md                       # Phase 1: Business Requirements Document
│   ├── Business_Questions.md        # Phase 1: 10+ analytical questions mapped to dimensions
│   ├── Fact_Dimension_ID.md         # Phase 1: Process identification & table classification
│   ├── Grain_Definition.md          # Phase 1: Formal atomic grain definitions
│   ├── schema.dbml                  # Phase 1: Physical data model in DBML (dbdiagram.io)
│   ├── data_dictionary.csv          # Phase 1: Excel-ready data dictionary
│   ├── Data_Cleaning_Report.md      # Phase 2: Staging transformations & before/after counts
│   ├── Data_Quality_Report.md       # Phase 2: Completeness, reconciliation & orphan audits
│   ├── Indexing_Report.md           # Phase 3: EXPLAIN ANALYZE comparison before/after index
│   ├── Business_Insights_Report.md  # Phase 3: Executive findings & strategic actions
│   └── Presentation_Outline.md      # Phase 3: Viva presentation slide outline
│
├── 02_Data/                         # Data storage & generator
│   ├── raw_data/                    # Raw sample CSVs (>=100 dimensions, >=10,000 facts)
│   ├── cleaned_data/                # Validated/transformed extracts
│   └── generate_data.py             # Reproducible synthetic generator (random.seed pinned)
│
├── 03_ETL/                          # Extraction, Transformation & Loading
│   ├── staging.sql                  # Staging tables DDL (schema: project_staging)
│   ├── load_staging.py              # Automated CSV-to-PostgreSQL ingestion script
│   ├── cleaning.sql                 # SQL cleaning logic (dedup, standardization, casting)
│   ├── dimensions.sql               # Dimension loader with surrogate keys & 'Unknown' member
│   ├── facts.sql                    # Fact loader with surrogate key lookup joins
│   ├── data_quality.sql             # Automated DQ test suite (0 orphans, 0 reconciliation gap)
│   └── run_etl.py                   # Master Python ETL pipeline orchestrator
│
├── 04_Data_Warehouse/               # DDL & Database Setup
│   ├── 00_setup.sql                 # Database creation & 3 schemas setup
│   └── warehouse.sql                # Star schema DDL (PK, FK, constraints, surrogate keys)
│
├── 05_Analytics/                    # OLAP & Query Optimization
│   ├── analytics.sql                # Window functions, monthly growth via LAG(), rankings
│   ├── OLAP.sql                     # Multidimensional ROLLUP & CUBE with GROUPING()
│   ├── Views.sql                    # Production reporting views in project_reporting
│   └── indexing/                    # Query execution plans before & after optimization
│
├── 06_Dashboard/                    # Business Intelligence Deliverables
│   ├── PSX_Risk_Dashboard.pbix      # 3-Page Power BI Desktop model connected to PostgreSQL
│   └── screenshots/                 # High-resolution PDF/image exports of all dashboard pages
│
├── .env.example                     # Environment template for DB credentials
├── .gitignore                       # Strict ignore rules (no passwords, logs, dumps)
├── requirements.txt                 # Python dependencies
├── README.md                        # Master project documentation
└── agent.md                         # Detailed step-by-step agent execution guide
```

---

## 4. Environment Setup & Prerequisites

### 4.1 Software Requirements
- **PostgreSQL 14+** (tested on local instance via pgAdmin 4 or `psql`)
- **Python 3.10+**
- **Power BI Desktop** (Windows or virtualized environment)

### 4.2 Installation & Configuration
1. **Clone the repository:**
   ```bash
   git clone https://github.com/HassanShakilPasha/psx-risk-warehouse.git
   cd psx-risk-warehouse
   ```

2. **Set up Python Virtual Environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate       # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Configure Database Credentials:**
   Copy the `.env.example` file to `.env` and provide your local PostgreSQL credentials:
   ```bash
   cp .env.example .env
   ```
   Edit `.env`:
   ```ini
   PGHOST=localhost
   PGPORT=5432
   PGDATABASE=dwbi_project
   PGUSER=postgres
   PGPASSWORD=your_password_here
   ```

---

## 5. Script Execution Run Order

Every script is idempotent and can be executed from scratch in **pgAdmin 4 Query Tool** or via `psql`. Follow this exact sequential run order:

| Step | Script File | Description | Output / Validation Target |
|:---:|---|---|---|
| **1** | `04_Data_Warehouse/00_setup.sql` | Creates database `dwbi_project` and schemas: `project_staging`, `project_dw`, `project_reporting`. | Schemas created successfully. |
| **2** | `03_ETL/staging.sql` | DDL for staging tables with permissive `TEXT` types (`stg_daily_prices`, `stg_rates`). | Staging tables ready for ingestion. |
| **3** | `03_ETL/load_staging.py` | Python script streaming raw CSVs into `project_staging` using fast bulk copy. | All raw rows loaded into staging. |
| **4** | `03_ETL/cleaning.sql` | Cleans data: deduplication, trim whitespace, standardize text, handle nulls, and cast types. | Cleaned staging view / table created. |
| **5** | `04_Data_Warehouse/warehouse.sql` | Creates Star Schema: `dim_date`, `dim_stock`, `dim_sector`, `fact_daily_trading`, `fact_risk_snapshot`. | Tables created with PK, FK, and Identity SKs. |
| **6** | `03_ETL/dimensions.sql` | Populates `dim_date` via `generate_series`, loads dimensions with identity surrogate keys and member `-1`. | Dimensions fully populated. |
| **7** | `03_ETL/facts.sql` | Loads fact tables by joining staging to dimensions on business keys (`symbol`, `trade_date`). | Fact rows loaded with zero row drop. |
| **8** | `03_ETL/data_quality.sql` | Executes Completeness, Accuracy (Reconciliation), and Foreign Key Integrity (Orphan) audits. | Discrepancy = 0, Orphans = 0. |
| **9** | `05_Analytics/Views.sql` | Creates reporting views: `vw_monthly_market`, `vw_sector_risk`, `vw_stock_performance`. | Views accessible in `project_reporting`. |
| **10** | `05_Analytics/analytics.sql` | Executes window analytical queries (monthly growth via `LAG()`, sector liquidity rankings). | Analytical query results. |
| **11** | `05_Analytics/OLAP.sql` | Executes multi-dimensional aggregations using `ROLLUP` and `CUBE` with `GROUPING()`. | Subtotal & grand total rollups. |
| **12** | `05_Analytics/indexing/` | Compares query execution time and cost via `EXPLAIN (ANALYZE, BUFFERS)` before and after indexing. | Documented performance speedups. |
| **13** | `06_Dashboard/` | Open Power BI Desktop, refresh PostgreSQL connection, verify visualizations and Decision Page. | Complete `.pbix` ready for viva. |

*Alternatively, steps 2 through 8 can be run in one command using the master orchestrator:*
```bash
python 03_ETL/run_etl.py
```

---

## 6. Data Source & Sampling Strategy

- **Source System:** Daily market summaries from the Pakistan Stock Exchange (closing prices, traded volumes, high/low range, traded values) paired with State Bank of Pakistan interest rate benchmark files.
- **Minimum Volume Compliance:**
  - $\ge 100$ distinct listed stocks and dimensions.
  - $\ge 10,000$ daily market fact rows covering multiple calendar years and monetary policy cycles.
- **Sampling Integrity:** Raw data slices are selected across continuous temporal windows (e.g. 2020–2024) to maintain time-series integrity for rolling 20-day volatility and monthly `LAG()` growth calculations, avoiding broken referential integrity.

---

## 7. Deliverables & Evaluation Roadmap

| Phase | Milestone | Weight | Key Deliverables | Status |
|---|---|:---:|---|:---:|
| **Phase 1** | **Business Analysis & Dimensional Design** | 30% | Proposal, BRD, 10 Business Questions, Grain Statement, Fact/Dimension Identification, DBML Schema Diagram, Data Dictionary (`.xlsx`/`.csv`). | In Progress |
| **Phase 2** | **Physical Implementation & ETL Pipeline** | 40% | PostgreSQL DDL (`00_setup.sql`, `warehouse.sql`), ETL Scripts (`staging.sql`, `cleaning.sql`, `dimensions.sql`, `facts.sql`), Data Cleaning Report, Data Quality Audit Report (0 orphans). | Pending |
| **Phase 3** | **OLAP, Optimization & BI Dashboard** | 30% | Analytical SQL (`LAG()`, window functions), `ROLLUP` & `CUBE` queries, Reporting Views, Indexing Report (`EXPLAIN ANALYZE`), 3-Page Power BI Dashboard (`.pbix`), Business Insights Report, Viva PPT. | Pending |

---

## 8. Academic Integrity & Defense Readiness

- **Independent DWBI Implementation:** Designed from first principles around analytical business questions using relational PostgreSQL dimensional modeling, distinct from prior operational/lakehouse prototypes.
- **Surrogate Key Discipline:** Every dimension uses system-generated identity surrogate keys (`INT GENERATED ALWAYS AS IDENTITY`), retaining natural business keys (`symbol`, `sector_code`) for auditing.
- **Guaranteed Reconciliation:** Fact load queries employ verified left joins and validation scripts guaranteeing that staging volume matches warehouse volume with zero discrepancy.
