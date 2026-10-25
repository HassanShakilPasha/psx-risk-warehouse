# PSX Risk Data Warehouse (DL3004 DWBI Final Project)
## Autonomous Agent Execution Guide & Step-by-Step Protocol (`agent.md`)

> **Document Purpose:** This file serves as the strict, step-by-step master execution roadmap for the AI Agent (Antigravity) and the student for the **DL3004 Data Warehousing & Business Intelligence (DWBI)** final project. Every single step, rule, schema convention, deliverable, and rubric requirement is codified here.

---

## 1. AGENT OPERATING PRINCIPLES & INTERACTION PROTOCOL

### 1.1 Strict Behavioral Directives
1. **One Step at a Time:** The agent must **NEVER** rush ahead or dump multiple steps simultaneously. Execute exactly one step, verify outputs, provide the exact Git commit message, and **wait for explicit user confirmation** before moving to the next.
2. **Real, Runnable PostgreSQL Code:** All SQL must strictly adhere to the PostgreSQL dialect (tested via `psql` or pgAdmin 4). No pseudo-code, no T-SQL, no MySQL syntax.
3. **Reproducibility & Idempotency:** Every script must be safe to re-run from scratch (`DROP TABLE IF EXISTS`, `CREATE SCHEMA IF NOT EXISTS`, `TRUNCATE` before reloads, deterministic seeding).
4. **Zero Fabrication Policy:** Never fabricate row counts, query execution times, cost estimates, or Data Quality (DQ) reconciliation figures. Place explicit placeholders like `<<paste EXPLAIN ANALYZE output>>` or `<<paste DQ count>>` whenever actual runtime output is required.
5. **Academic Defense ("Viva Readiness"):** Accompany all dimensional modeling choices (e.g., choice of grain, surrogate key generation method, fact table classification, SCD type) with 1–3 concise sentences explaining the architectural *why*.
6. **No Secret Leaks:** Read all credentials via `.env` with `python-dotenv`. Commit only `.env.example` with sanitized placeholders.

---

## 2. PROJECT CONTEXT & ARCHITECTURAL MAPPING

### 2.1 The Academic Context & Dataset Origin
- **Course:** DL3004 Data Warehousing & Business Intelligence
- **Weighting:** 15% of final course grade (Phase 1 = 30%, Phase 2 = 40%, Phase 3 = 30%)
- **Source Foundation:** Pakistan Stock Exchange (PSX) Daily Market Summary data and State Bank of Pakistan (SBP) policy rate series, originally processed through a Databricks Medallion Lakehouse (Bronze & Silver layers).
- **Core Pivot:** The **Databricks Silver tables** (`silver.daily_prices`, `ref_sector`, `ref_policy_rate`) serve purely as external **source systems**. The Data Warehouse (star schema, staging, cleaning, ETL pipeline, OLAP, indexing, and Power BI dashboards) is built independently in **PostgreSQL**.

### 2.2 End-to-End Pipeline Architecture
```
┌────────────────────────────────┐
│   Source System: PSX Silver    │ (Exported CSVs from Databricks / Synthetic Generator)
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│     Schema: project_staging    │ (stg_daily_prices, stg_stocks, stg_sectors, stg_rates)
│     - Permissive TEXT types    │
│     - Raw file ingestion       │
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│     Cleaning & Transformation   │ (Deduplication, NULL handling, TRIM/INITCAP, Casts)
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│        Schema: project_dw      │ (Dimensional Star Schema)
│  - dim_date (Surrogate Key)    │
│  - dim_stock (Surrogate Key)   │
│  - dim_sector (Surrogate Key)  │
│  - fact_daily_market (Trades)  │
│  - fact_risk_metric (Vol/Tier) │
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│   Schema: project_reporting    │ (vw_monthly_market, vw_sector_risk, vw_stock_performance)
└───────────────┬────────────────┘
                ▼
┌────────────────────────────────┐
│     Power BI Desktop (PBIX)    │ (Page 1: Exec, Page 2: Analytics, Page 3: Decision)
└────────────────────────────────┘
```

---

## 3. TARGET REPOSITORY SCAFFOLD

The local repository structure conforms strictly to the course specification:

```
psx-risk-warehouse/
├── 01_Project_Documentation/
│   ├── Proposal.md                     # Phase 1: One-page project proposal
│   ├── BRD.md                          # Phase 1: Business Requirements Document
│   ├── Business_Questions.md           # Phase 1: 10+ analytical questions across 3 themes
│   ├── Fact_Dimension_ID.md            # Phase 1: Business processes & dimension identification
│   ├── Grain_Definition.md             # Phase 1: Formal grain statements
│   ├── schema.dbml                     # Phase 1: Physical model in DBML (for dbdiagram.io)
│   ├── data_dictionary.csv             # Phase 1: Complete data dictionary (Excel-ready)
│   ├── Data_Cleaning_Report.md         # Phase 2: Staging cleaning transformations & metrics
│   ├── Data_Quality_Report.md          # Phase 2: Completeness, accuracy, and integrity metrics
│   ├── Indexing_Report.md              # Phase 3: EXPLAIN ANALYZE comparison before/after index
│   ├── Business_Insights_Report.md     # Phase 3: Analytical findings & executive recommendations
│   └── Presentation_Outline.md         # Phase 3: 10-12 slide defense outline
├── 02_Data/
│   ├── raw_data/                       # Sample source CSVs (>=100 dims, >=10,000 facts)
│   ├── cleaned_data/                   # Transformed/clean exports if staged externally
│   └── generate_data.py                # Deterministic synthetic data generator (if needed)
├── 03_ETL/
│   ├── staging.sql                     # Staging tables DDL
│   ├── load_staging.py                 # Automated CSV to PostgreSQL ingestion
│   ├── cleaning.sql                    # SQL transformation & staging cleaning logic
│   ├── dimensions.sql                  # Dimension loading scripts with surrogate keys
│   ├── facts.sql                       # Fact loading scripts with surrogate key lookups
│   ├── data_quality.sql                # Automated validation queries (reconciliation & orphans)
│   └── run_etl.py                      # Master Python orchestrator
├── 04_Data_Warehouse/
│   ├── 00_setup.sql                    # Database & 3 schemas setup
│   └── warehouse.sql                   # Core DDL (star schema tables, constraints, PKs, FKs)
├── 05_Analytics/
│   ├── analytics.sql                   # Window functions, LAG growth, rolling trends
│   ├── OLAP.sql                        # Advanced ROLLUP and CUBE queries with GROUPING()
│   ├── Views.sql                       # Reporting views in project_reporting
│   └── indexing/                       # Raw query plans (before_plan.txt, after_plan.txt)
├── 06_Dashboard/
│   ├── PSX_Risk_Dashboard.pbix         # 3-Page Power BI interactive workbook
│   └── screenshots/                    # High-res exports of pages 1, 2, and 3
├── .env.example                        # Template for database credentials
├── .gitignore                          # Strict gitignore matching university spec
├── requirements.txt                    # Python environment requirements
├── README.md                           # Master project documentation & execution order
└── agent.md                            # THIS EXECUTION ROADMAP
```

---

## 4. MASTER STEP-BY-STEP EXECUTION ROADMAP

### PHASE 0: REPOSITORY SCAFFOLD & ENVIRONMENT SETUP
- [ ] **Step 0.1: Initialize Folder Structure**
  - Create all required directories with `.gitkeep` files.
- [ ] **Step 0.2: Configure Git & Dependencies**
  - Create standard `.gitignore` preventing data dumps, logs, and `.env` leaks.
  - Create `.env.example` with `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`.
  - Create `requirements.txt` (`pandas`, `sqlalchemy`, `psycopg2-binary`, `python-dotenv`).
- [ ] **Step 0.3: Starter README**
  - Create comprehensive starter `README.md` containing pipeline architecture, tech stack, and execution run order.
  - **Commit Target:** `chore(setup): scaffold project directory and configuration`

---

### PHASE 1: BUSINESS ANALYSIS & DIMENSIONAL DESIGN (Weeks 1–3, 30 Marks)
*Objective: Design the dimensional model completely before touching code.*

- [ ] **Step 1.1: Silver Dataset Audit & Business Scenario Definition**
  - Inspect sample data from PSX daily market summaries and SBP interest rates.
  - Frame the business scenario: Pakistan Equities Capital Market Risk & Regime Warehouse.
  - Define minimum data volume targets: $\ge 100$ stocks/symbols, $\ge 10,000$ daily market fact rows.
- [ ] **Step 1.2: One-Page Project Proposal (`01_Project_Documentation/Proposal.md`)**
  - Business problem, stakeholder needs (risk managers, portfolio analysts, regulators).
  - Scope of analytical solution and targeted outcomes.
- [ ] **Step 1.3: 10 Analytical Business Questions (`01_Project_Documentation/Business_Questions.md`)**
  - Formulate at least 10 concrete questions mapped across 3 themes:
    1. *Market Volatility & Macro Regimes* (Interest rate impacts, high-volatility clustering).
    2. *Sector & Stock Concentration Risk* (Turbulent sectors, volume vs volatility correlation).
    3. *Extreme Tail Events & Trading Activity* (Largest single-day swings, liquidity dry-ups).
  - Explicitly tag every question with required measures and dimensional attributes.
- [ ] **Step 1.4: Fact & Dimension Identification (`01_Project_Documentation/Fact_Dimension_ID.md`)**
  - Identify business processes (Daily Market Trading, Periodic Risk Evaluation).
  - Select Fact Table Types with full academic justification:
    - `fact_daily_trading` (Transaction Fact: open, high, low, close, volume, value).
    - `fact_risk_snapshot` (Periodic Snapshot: moving volatility, beta, risk tier).
  - Identify Dimensions: `dim_date`, `dim_stock`, `dim_sector`, `dim_policy_rate`.
- [ ] **Step 1.5: Grain Definition Document (`01_Project_Documentation/Grain_Definition.md`)**
  - Unambiguous grain statements for each fact table:
    - *Trading Grain:* "One row represents the trading activity of one listed stock on one trading day."
    - *Risk Grain:* "One row represents the end-of-day statistical risk profile of one stock on one trading day."
- [ ] **Step 1.6: Keys, Hierarchies & SCD Strategy**
  - Define Natural Keys (`symbol`, `trade_date`, `sector_code`).
  - Define Surrogate Keys (`stock_key`, `date_key`, `sector_key`).
  - Document dimension hierarchies (e.g., `Market -> Sector -> Stock` and `Year -> Quarter -> Month -> Day`).
  - Formulate SCD policy (Type 1 for sector changes and basic stock data; Type 2 strategy if historical tracking required).
- [ ] **Step 1.7: Physical Schema Design (DBML) (`01_Project_Documentation/schema.dbml`)**
  - Generate complete `dbdiagram.io` DBML code with PKs, FKs, types, and relationships.
  - Document Conceptual, Logical, and Physical schema walkthrough.
- [ ] **Step 1.8: Data Dictionary (`01_Project_Documentation/data_dictionary.csv`)**
  - Create table: `table_name`, `column_name`, `data_type`, `description`, `key_type` (PK/FK/NK/SK/none), `example_value`.
- [ ] **Step 1.9: Business Requirements Document (`01_Project_Documentation/BRD.md`)**
  - Compile the complete, formal BRD ready for PDF conversion.
  - **Commit Target:** `docs(design): complete Phase 1 dimensional model and documentation`

---

### PHASE 2: PHYSICAL DW IMPLEMENTATION & ETL (Weeks 4–6, 40 Marks)
*Objective: Build the staging area, load dimensions with surrogate keys, load facts, and prove data quality.*

- [ ] **Step 2.1: Data Sampling & Generation Strategy**
  - Place raw PSX sample CSVs in `02_Data/raw_data/`.
  - Validate volume: confirm $\ge 100$ stocks and $\ge 10,000$ market records.
  - Implement `02_Data/generate_data.py` (with deterministic random seed) if synthetic augmentation is needed.
- [ ] **Step 2.2: Setup Database & Schemas (`04_Data_Warehouse/00_setup.sql`)**
  - Create database `dwbi_project`.
  - Create schemas: `project_staging`, `project_dw`, `project_reporting`.
- [ ] **Step 2.3: Staging Layer DDL & Loader (`03_ETL/staging.sql`, `03_ETL/load_staging.py`)**
  - Create staging tables (`stg_daily_prices`, `stg_stock_info`, `stg_sector_info`, `stg_policy_rates`) with permissive `TEXT` types.
  - Provide automated loading script using pandas / PostgreSQL `COPY`.
- [ ] **Step 2.4: Data Cleaning & Staging Transformations (`03_ETL/cleaning.sql`, `01_Project_Documentation/Data_Cleaning_Report.md`)**
  - Write SQL transformations: deduplication (`ROW_NUMBER() OVER (...)`), `TRIM()`, `UPPER()`/`INITCAP()`, NULL handling (`COALESCE`), and safe type casting.
  - Record and tabulate before-and-after row counts in the cleaning report.
- [ ] **Step 2.5: Data Warehouse DDL (`04_Data_Warehouse/warehouse.sql`)**
  - Create dimensional tables with `INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`.
  - Create fact tables with Foreign Key constraints referencing dimension surrogate keys.
  - Include an "Unknown" member (`-1`) in dimensions to gracefully catch missing references.
- [ ] **Step 2.6: Dimension Load Scripts (`03_ETL/dimensions.sql`)**
  - Populate `dim_date` using PostgreSQL `generate_series('2015-01-01'::date, '2026-12-31'::date, '1 day'::interval)`.
  - Load `dim_sector` and `dim_stock` using `INSERT INTO ... SELECT DISTINCT` from staging.
- [ ] **Step 2.7: Fact Load Scripts (`03_ETL/facts.sql`)**
  - Populate fact tables by joining staging tables to dimensions on natural/business keys, projecting surrogate keys.
  - Ensure zero row loss through proper join validation.
- [ ] **Step 2.8: Data Quality Validation Suite (`03_ETL/data_quality.sql`, `01_Project_Documentation/Data_Quality_Report.md`)**
  - **Completeness:** Check NULL counts across all mandatory key and metric fields.
  - **Accuracy:** Revenue/Volume reconciliation:
    $$\sum \text{Volume}_{\text{staging\_clean}} - \sum \text{Volume}_{\text{fact\_trading}} = 0$$
  - **Integrity (Orphan Check):** Left join from fact to dimensions verifying orphaned rows $= 0$.
  - Output results to dedicated DQ result tables and compile the formal report.
- [ ] **Step 2.9: Python ETL Orchestrator (`03_ETL/run_etl.py`)**
  - Single-command execution script to run staging, cleaning, dimension load, fact load, and DQ tests sequentially.
  - **Commit Target:** `feat(etl): complete physical schema, ETL pipeline, and DQ validation`

---

### PHASE 3: OLAP, OPTIMIZATION & BI DASHBOARD (Weeks 7–8, 30 Marks)
*Objective: Build analytical SQL, advanced OLAP aggregations, optimize query performance, and deliver Power BI dashboards.*

- [ ] **Step 3.1: Analytical SQL Queries (`05_Analytics/analytics.sql`)**
  - Window functions: monthly volume & price growth via `LAG()`.
  - Top-N stocks by trading liquidity per sector via `DENSE_RANK()`.
  - 20-day and 60-day rolling average volatility.
- [ ] **Step 3.2: OLAP Multi-Dimensional Queries (`05_Analytics/OLAP.sql`)**
  - **ROLLUP:** `Sector -> Market Tier -> Symbol` with `GROUPING()` functions for subtotals and grand totals.
  - **CUBE:** `Sector x Volatility Regime x Policy Rate Era`.
- [ ] **Step 3.3: Reporting Views (`05_Analytics/Views.sql`)**
  - Create mandatory views in schema `project_reporting`:
    - `vw_monthly_sales` (or `vw_monthly_market`)
    - `vw_customer_analysis` (or `vw_sector_risk`)
    - `vw_product_performance` (or `vw_stock_performance`)
- [ ] **Step 3.4: Query Optimization & Indexing (`01_Project_Documentation/Indexing_Report.md`)**
  - Select 3 resource-heavy queries.
  - Run `EXPLAIN (ANALYZE, BUFFERS)` before indexing; record execution time and cost.
  - Add targeted indexes (`B-Tree`, composite index on foreign keys / filter columns).
  - Run `EXPLAIN (ANALYZE, BUFFERS)` after indexing; document plan changes (e.g., Sequential Scan to Index Scan).
  - Fill the official Indexing Comparison Table.
- [ ] **Step 3.5: Power BI Dashboard Implementation (`06_Dashboard/`)**
  - Connect Power BI Desktop to PostgreSQL `project_reporting` views.
  - **Page 1: Executive Overview:** High-level market KPIs (Market Cap Traded, High Risk Ratio, Active Stocks), time-series trend of market turbulence.
  - **Page 2: Detailed Analysis:** Sector-level risk distribution, Stock risk tier heatmaps, SBP interest rate overlay.
  - **Page 3: Management Decision Page:** Concrete, evidence-backed strategic recommendations (e.g., risk mitigation, margin requirements adjustments).
  - Save as `.pbix` and export screenshots to `06_Dashboard/screenshots/`.
- [ ] **Step 3.6: Business Insights Report (`01_Project_Documentation/Business_Insights_Report.md`)**
  - Written report synthesizing analytical outputs into concrete business strategies.
- [ ] **Step 3.7: Final Presentation Slide Outline (`01_Project_Documentation/Presentation_Outline.md`)**
  - 10–12 slide viva presentation covering problem statement, star schema, ETL challenges, OLAP insights, dashboard demo, and lessons learned.
  - **Commit Target:** `feat(analytics): deliver OLAP, views, indexing report, and BI artifacts`

---

## 5. TECHNICAL STANDARDS & SQL PATTERNS

### 5.1 Naming & Schema Rules
| Component | Convention | Example |
|---|---|---|
| Schemas | `project_staging`, `project_dw`, `project_reporting` | `project_dw` |
| Staging Tables | `stg_<source_name>` | `project_staging.stg_daily_prices` |
| Dimension Tables | `dim_<entity>` | `project_dw.dim_stock` |
| Fact Tables | `fact_<process>` | `project_dw.fact_daily_trading` |
| Reporting Views | `vw_<subject>` | `project_reporting.vw_sector_risk` |
| Surrogate Keys | `<entity>_key` (`INT GENERATED ALWAYS AS IDENTITY`) | `stock_key` |
| Natural / Business Keys | `<entity>_id` or `symbol` (`VARCHAR`) | `symbol` |

### 5.2 Mandatory Dimension Load Pattern
```sql
-- Idempotent Dimension Load with 'Unknown' Member
INSERT INTO project_dw.dim_stock (stock_key, symbol, company_name, sector_name)
OVERRIDING SYSTEM VALUE
VALUES (-1, 'UNKNOWN', 'Unknown Stock', 'Unknown Sector')
ON CONFLICT (stock_key) DO NOTHING;

INSERT INTO project_dw.dim_stock (symbol, company_name, sector_name)
SELECT DISTINCT
    TRIM(symbol),
    COALESCE(INITCAP(TRIM(company_name)), 'N/A'),
    COALESCE(INITCAP(TRIM(sector_name)), 'Unassigned')
FROM project_staging.stg_daily_prices
WHERE symbol IS NOT NULL
ON CONFLICT (symbol) DO NOTHING;
```

### 5.3 Mandatory Fact Load Pattern (SK Lookup)
```sql
INSERT INTO project_dw.fact_daily_trading (
    date_key,
    stock_key,
    open_price,
    high_price,
    low_price,
    close_price,
    traded_volume,
    traded_value
)
SELECT
    COALESCE(d.date_key, -1)   AS date_key,
    COALESCE(s.stock_key, -1)  AS stock_key,
    stg.open_price::NUMERIC(12,2),
    stg.high_price::NUMERIC(12,2),
    stg.low_price::NUMERIC(12,2),
    stg.close_price::NUMERIC(12,2),
    stg.traded_volume::BIGINT,
    stg.traded_value::NUMERIC(18,2)
FROM project_staging.stg_daily_prices_clean stg
LEFT JOIN project_dw.dim_date  d ON d.full_date = stg.trade_date
LEFT JOIN project_dw.dim_stock s ON s.symbol    = stg.symbol;
```

### 5.4 Mandatory Reconciliation Check (Accuracy & Integrity)
```sql
-- 1. Accuracy Reconciliation: Zero difference allowed
SELECT
    (SELECT SUM(traded_volume::BIGINT) FROM project_staging.stg_daily_prices_clean) AS staging_volume,
    (SELECT SUM(traded_volume) FROM project_dw.fact_daily_trading)                   AS dw_volume,
    (SELECT SUM(traded_volume::BIGINT) FROM project_staging.stg_daily_prices_clean) -
    (SELECT SUM(traded_volume) FROM project_dw.fact_daily_trading)                   AS difference;

-- 2. Foreign Key Integrity: Must return 0
SELECT COUNT(*) AS orphaned_records
FROM project_dw.fact_daily_trading f
LEFT JOIN project_dw.dim_stock s ON f.stock_key = s.stock_key
WHERE s.stock_key IS NULL;
```

---

## 6. EXAMINER VIVA & GRADING DEFENSE CHECKLIST

| Rubric Area | Weight | Critical Success Criteria | Common Failure Mode to Avoid |
|---|---|---|---|
| **Phase 1: Business Analysis & Design** | 30% | Clear grain statement, 10+ analytical questions, full DBML & ERD with explicit PK/FK/SK, documented hierarchies. | Copying source tables directly instead of designing around analytical business processes. |
| **Phase 2: Database & ETL** | 40% | Clean 3-schema architecture, surrogate key mapping, idempotent load scripts, 100% verified DQ report (0 orphans, 0 discrepancy). | Dropping natural business keys; silent row loss due to `INNER JOIN` in fact load; unhandled nulls. |
| **Phase 3: OLAP & BI Dashboard** | 30% | Functional `ROLLUP` and `CUBE` with `GROUPING()`, measurable indexing improvements via `EXPLAIN ANALYZE`, 3-page Power BI dashboard with a concrete decision. | Visuals without concrete business recommendations; missing indexing metrics; non-working Power BI connections. |

---

## 7. IMMEDIATE NEXT STEP

This file (`agent.md`) is now the binding contract for the project.

**Current State:** Ready to initiate **Step 0: Repo Scaffold & Configuration Setup**.
When the user gives the command to proceed, the agent will execute Step 0, create the folders and configuration files, and halt for user inspection.
