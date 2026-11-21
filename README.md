# Pakistan Stock Exchange (PSX) Market Risk Data Warehouse
### DL3004 — Data Warehousing & Business Intelligence (DWBI) Final Project

[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL%2014+-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![pgAdmin](https://img.shields.io/badge/GUI-pgAdmin%204-326690?logo=postgresql&logoColor=white)](https://www.pgadmin.org/)
[![Python](https://img.shields.io/badge/ETL-Python%203.10+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Power BI](https://img.shields.io/badge/BI-Power%20BI%20Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)

**Project Team**:
- Saqib Qazi (24L-2506)
- Hassan Shakil (24L-2521)
- Ammara Saleem (24L-2571)

---

## 1. Executive Summary & Business Scenario

The **Pakistan Stock Exchange (PSX) Market Risk Data Warehouse** is an enterprise-grade dimensional data warehouse designed to analyze equity market volatility, sector risk regimes, liquidity dynamics, and the transmission of macroeconomic interest rate decisions by the **State Bank of Pakistan (SBP)**.

Between 2020 and 2026, the SBP moved the benchmark policy rate from 7% to a record 22% and back down, while the equity market experienced sharp rallies and sell-offs. In emerging capital markets like Pakistan, risk clusters: calm periods are punctuated by sharp macro shocks, currency adjustments, and liquidity contractions. This project ingests daily market trading summaries and central bank policy decisions, cleans and structures them through a multi-tier PostgreSQL warehouse, and powers multidimensional OLAP cubes and executive BI dashboards.

### Core Business Themes & 14 Business Questions
1. **Risk & Volatility (Q1–Q4):** Identifies which stocks and sectors occupy High-risk tiers, compares 20-day rolling annualized volatility across sectors, and tracks long-term historical volatility trends.
2. **Systemic vs Idiosyncratic Risk (Q5–Q7):** Separates market-wide turbulence (% of stocks in High risk tier) from company-specific volatility, examining market breadth (advancers vs decliners) during market crashes.
3. **Monetary Policy Transmission (Q8–Q10):** Measures market volatility in 10-day event windows before and after SBP policy rate decisions, contrasting rate hikes vs cuts and evaluating sector interest-rate sensitivities.
4. **Liquidity & Activity Dynamics (Q11–Q12):** Links trading volume and turnover to volatility, tracking active vs inactive listings over time.
5. **Market Events & Tail Risk (Q13–Q14):** Analyzes corporate actions (bonus shares, stock splits, rights issues) and upper/lower price-limit locks.

---

## 2. End-to-End Pipeline Architecture

The project strictly follows the enterprise **Three-Schema Data Warehouse Architecture** implemented in PostgreSQL:

```
┌────────────────────────────────────────────────────────┐
│                     SOURCE SYSTEMS                     │
│  - PSX Daily Market Summaries (Closing Prices & Volumes) │
│  - SBP Structure of Interest Rates (Policy Decisions)   │
│  - PSX Sector Classification Master Data               │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Ingestion (`load_staging.py` / PostgreSQL COPY)
                            ▼
┌────────────────────────────────────────────────────────┐
│                 SCHEMA: project_staging                │
│  - Permissive TEXT data types to guarantee zero drop   │
│  - Landing tables: stg_daily_prices, stg_policy_rates, │
│    stg_stock_metadata                                  │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Cleaning & Transformation (`cleaning.sql`)
                            │ (Deduplication, TRIM, UPPER, safe casts, DQ flags)
                            ▼
┌────────────────────────────────────────────────────────┐
│                   SCHEMA: project_dw                   │
│  - Conformed Star / Snowflake Dimensional Model        │
│  - 6 Dimensions (Surrogate Keys & -1 Unknown member):  │
│      dim_date (Conformed), dim_sector (Snowflake),     │
│      dim_stock (SCD Type 2), dim_risk_tier,            │
│      dim_event_type, dim_policy_action                 │
│  - 5 Fact Tables with Strict Referential Integrity:    │
│      fact_daily_stock_price (Periodic Snapshot)        │
│      fact_market_daily      (Aggregated Daily)         │
│      fact_sector_daily      (Aggregated Daily)         │
│      fact_policy_decision   (Transaction)              │
│      fact_market_event      (Factless Fact)            │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Aggregations, Window Functions & OLAP
                            ▼
┌────────────────────────────────────────────────────────┐
│               SCHEMA: project_reporting                │
│  - Reporting Views:                                    │
│      vw_monthly_market, vw_sector_risk, vw_stock_perf  │
│  - Advanced OLAP: ROLLUP, CUBE, GROUPING()             │
│  - Query Optimization via B-Tree Indexing & EXPLAIN    │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ PostgreSQL Native Connector / ODBC
                            ▼
┌────────────────────────────────────────────────────────┐
│                 POWER BI DESKTOP (PBIX)                │
│  - Page 1: Executive Market Overview (KPIs & Trends)   │
│  - Page 2: Detailed Sector & Volatility Analysis       │
│  - Page 3: Strategic Decision Page (Action Plan)       │
└────────────────────────────────────────────────────────┘
```

---

## 3. Repository Directory Structure

Conforming strictly to the university course specification:

```
psx-risk-warehouse/
├── 01_Project_Documentation/
│   ├── Course_Specs/                            # University course & lab PDF briefs
│   │   ├── DWBI Final Project Overview.pdf      # Complete pipeline specification
│   │   ├── DWBI Lab Phase 1.pdf                 # Phase 1 lab brief (Design - 30%)
│   │   ├── DWBI Lab Phase 2.pdf                 # Phase 2 lab brief (Implementation - 40%)
│   │   └── DWBI Lab Phase 3.pdf                 # Phase 3 lab brief (Analytics & BI - 30%)
│   ├── Phase_1_Submission/                      # Graded Phase 1 submission files
│   │   ├── 01_Project_Proposal.pdf
│   │   ├── 02_Business_Requirements_Document.pdf
│   │   ├── 03_Business_Questions.pdf
│   │   ├── 04_Fact_and_Dimension_Identification.pdf
│   │   ├── 05_Grain_Definition.pdf
│   │   ├── 06_Schema_1_Conceptual.png
│   │   ├── 06_Schema_2_Logical.png
│   │   ├── 06_Schema_3_Physical.png
│   │   ├── 06_Star_Snowflake_Schema_Diagram.pdf
│   │   └── 07_Data_Dictionary.xlsx              # 9-sheet official data dictionary
│   ├── Proposal.md                              # Project Proposal & Problem Statement
│   ├── BRD.md                                   # Formal Business Requirements Document
│   ├── Business_Questions.md                    # 14 analytical questions mapped to DW
│   ├── Fact_Dimension_ID.md                     # Bus Matrix & Fact/Dimension classification
│   ├── Grain_Definition.md                      # Atomic grain statements for all 5 facts
│   ├── schema.dbml                              # Physical schema definition in DBML
│   ├── data_dictionary.csv                      # Full column dictionary exported from Excel
│   ├── Data_Cleaning_Report.md                  # Phase 2: Transformations & before/after counts
│   ├── Data_Quality_Report.md                   # Phase 2: Completeness, reconciliation & orphan audits
│   ├── Indexing_Report.md                       # Phase 3: EXPLAIN ANALYZE before/after index
│   ├── Business_Insights_Report.md              # Phase 3: Executive findings & strategic actions
│   └── Presentation_Outline.md                  # Phase 3: Viva presentation slide outline
│
├── 02_Data/                                     # Data storage & generator
│   ├── raw_data/                                # Source CSVs (PSX market data)
│   ├── supplementary/                           # Reference lookup CSVs (rates, sectors, metadata)
│   │   ├── sbp_policy_rates.csv                 # SBP interest rate announcements (2015–2026)
│   │   └── stock_metadata.csv                   # Master symbol-to-sector and company mappings
│   ├── cleaned_data/                            # Validated/transformed extracts
│   └── generate_data.py                         # Deterministic synthetic generator (≥95 extra stocks)
│
├── 03_ETL/                                      # Extraction, Transformation & Loading
│   ├── staging.sql                              # Staging tables DDL (schema: project_staging)
│   ├── load_staging.py                          # Automated CSV-to-PostgreSQL ingestion script
│   ├── cleaning.sql                             # SQL cleaning logic (dedup, standardization, casting)
│   ├── dimensions.sql                           # Dimension loader with surrogate keys & 'Unknown' member
│   ├── facts.sql                                # Fact loader with surrogate key lookup joins
│   ├── data_quality.sql                         # Automated DQ test suite (0 orphans, 0 reconciliation gap)
│   └── run_etl.py                               # Master Python ETL pipeline orchestrator
│
├── 04_Data_Warehouse/                           # DDL & Database Setup
│   ├── 00_setup.sql                             # Database creation & 3 schemas setup
│   └── warehouse.sql                            # Full Star/Snowflake schema DDL (PK, FK, constraints)
│
├── 05_Analytics/                                # OLAP & Query Optimization
│   ├── analytics.sql                            # Window functions, daily returns, sector rankings
│   ├── OLAP.sql                                 # Multidimensional ROLLUP & CUBE with GROUPING()
│   ├── Views.sql                                # Production reporting views in project_reporting
│   └── indexing/                                # Query execution plans before & after optimization
│
├── 06_Dashboard/                                # Business Intelligence Deliverables
│   ├── PSX_Risk_Dashboard.pbix                  # 3-Page Power BI Desktop model connected to PostgreSQL
│   ├── PSX_Risk_Dashboard.pdf                   # Complete export of all dashboard pages
│   └── screenshots/                             # High-resolution visual screenshots
│
├── .env.example                                 # Environment template for DB credentials
├── .gitignore                                   # Strict ignore rules (no passwords, logs, dumps)
├── requirements.txt                             # Python dependencies
├── README.md                                    # Master project documentation
├── agent.md                                     # Detailed step-by-step agent execution guide
└── fixes.md                                     # Audit log & changelog of improvements
```

---

## 4. Deliverables & Evaluation Roadmap

| Phase | Milestone | Weight | Key Deliverables | Status |
|---|---|:---:|---|:---:|
| **Phase 1** | **Business Analysis & Dimensional Design** | 30% | Proposal, BRD, 14 Business Questions, Grain Statements, Fact/Dimension ID, Bus Matrix, Star/Snowflake Schema Diagram (Conceptual, Logical, Physical), Data Dictionary (`.xlsx` & `.csv`). | **Completed & Approved** |
| **Phase 2** | **Physical Implementation & ETL Pipeline** | 40% | PostgreSQL DDL (`00_setup.sql`, `warehouse.sql`), ETL Scripts (`staging.sql`, `load_staging.py`, `cleaning.sql`, `dimensions.sql`, `facts.sql`), Data Cleaning Report, Data Quality Audit Report (0 orphans, 0 reconciliation gap). | **In Progress** |
| **Phase 3** | **OLAP, Optimization & BI Dashboard** | 30% | Analytical SQL (`LAG()`, window functions), `ROLLUP` & `CUBE` queries, Reporting Views, Indexing Report (`EXPLAIN ANALYZE`), 3-Page Power BI Dashboard (`.pbix`), Business Insights Report, Viva Presentation Outline. | **Pending** |

---

## 5. Environment Setup & Prerequisites

### 5.1 Software Requirements
- **PostgreSQL 14+** (tested via pgAdmin 4 or `psql`)
- **Python 3.10+** (with `pandas`, `sqlalchemy`, `psycopg2-binary`, `python-dotenv`, `numpy`)
- **Power BI Desktop** (connecting via native PostgreSQL connector or ODBC)

### 5.2 Installation & Setup
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
   Copy `.env.example` to `.env` and provide your PostgreSQL credentials:
   ```bash
   cp .env.example .env
   ```

---

## 6. Script Execution Run Order

Every script is idempotent and can be executed via `psql` or **pgAdmin 4**:

| Step | Script File | Description | Output / Validation Target |
|:---:|---|---|---|
| **1** | `04_Data_Warehouse/00_setup.sql` | Creates database `dwbi_project` and schemas: `project_staging`, `project_dw`, `project_reporting`. | Schemas created successfully. |
| **2** | `03_ETL/staging.sql` | DDL for staging tables with permissive `TEXT` types (`stg_daily_prices`, `stg_policy_rates`, `stg_stock_metadata`). | Staging tables ready for ingestion. |
| **3** | `03_ETL/load_staging.py` | Python script streaming raw CSVs into `project_staging` using fast bulk copy. | All raw rows loaded into staging. |
| **4** | `03_ETL/cleaning.sql` | Cleans data: deduplication, trim whitespace, standardize text, handle nulls, and cast types. | Cleaned staging view `stg_daily_prices_clean`. |
| **5** | `04_Data_Warehouse/warehouse.sql` | Creates Star/Snowflake Schema: 6 dimensions, 5 facts with PK, FK, and Identity SKs. | Tables created with strict constraints. |
| **6** | `03_ETL/dimensions.sql` | Populates `dim_date` via `generate_series`, loads dimensions with identity surrogate keys and Unknown member `-1`. | Dimensions fully populated. |
| **7** | `03_ETL/facts.sql` | Loads all 5 fact tables by joining staging to dimensions on business keys (`symbol`, `full_date`). | Fact rows loaded with zero row drop. |
| **8** | `03_ETL/data_quality.sql` | Executes Completeness, Accuracy (Reconciliation), and Foreign Key Integrity (Orphan) audits. | Discrepancy = 0, Orphans = 0. |
| **9** | `05_Analytics/Views.sql` | Creates reporting views: `vw_monthly_market`, `vw_sector_risk`, `vw_stock_performance`. | Views accessible in `project_reporting`. |
| **10** | `05_Analytics/analytics.sql` | Executes window analytical queries (monthly growth via `LAG()`, sector liquidity rankings). | Answers to analytical questions. |
| **11** | `05_Analytics/OLAP.sql` | Executes multi-dimensional aggregations using `ROLLUP` and `CUBE` with `GROUPING()`. | Subtotal & grand total rollups. |
| **12** | `05_Analytics/indexing/` | Compares query execution time and cost via `EXPLAIN (ANALYZE, BUFFERS)` before and after indexing. | Documented performance speedups. |
| **13** | `06_Dashboard/` | Open Power BI Desktop, refresh PostgreSQL connection, verify visualizations and Decision Page. | Complete `.pbix` ready for viva. |

*Alternatively, the complete ETL pipeline can be executed via the master orchestrator:*
```bash
python 03_ETL/run_etl.py
```
