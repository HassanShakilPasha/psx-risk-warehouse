# fixes.md — Audit Log & Changelog

> This file tracks every architectural improvement, data alignment, and structural refinement across the repository.

---

## Revision 4 — 2026‑10‑25 (Phase 2, Phase 3 & Final Submission Comprehensive Audit)

### 1. Critical Audit Performed
Conducted a deep forensic audit evaluating the repository against the official grading rubrics for Phase 2 (40%), Phase 3 (30%), and the Final Submission/Viva defense. Detailed in artifact `critical_audit_phase2_3_final.md`.

### 2. High-Stakes Risks & Failure Modes Identified
- **GAP P2-01 (Volume Minimum Size Violation)**: Lab 2 explicitly mandates $\ge 100$ dimension records and $\ge 10,000$ fact rows. Current raw data contains only 5 stocks (~8,065 rows). Solution: `02_Data/generate_data.py` must synthesize $\ge 95$ realistic stocks to achieve 160,000+ fact rows.
- **GAP P2-02 (Missing Supplementary Data)**: Phase 1 committed to `fact_policy_decision` and `fact_sector_daily`, but no SBP policy rate data or stock-to-sector lookup exists on disk. Solution: Created specifications for `02_Data/supplementary/sbp_policy_rates.csv` and `stock_metadata.csv`.
- **GAP P2-03 (Factless Fact Mechanics)**: Established concrete detection rules in `facts.sql` for `fact_market_event` based on $\pm 7.5\%$ circuit breaker limit-locks and corporate action adjustments.
- **GAP P2-04 (Aggregation Consistency)**: Enforced that `fact_market_daily` and `fact_sector_daily` must be populated directly from `fact_daily_stock_price` within the same transaction to guarantee reconciliation.
- **GAP P3-01 (CRITICAL DASHBOARD FLAW)**: Audited `06_Dashboard/PSX Power BI Dashboard.pdf` page-by-page. Found that Page 3 currently displays an internal Databricks ETL pipeline monitor (`raw_to_bronze`, `bronze_to_silver`, batch durations) instead of the mandatory **Business Decision Page** ("Based on the dashboard, what decision should management take?"). Solution: Redesign Page 3 around 3 strategic risk decisions (Interest Rate Hedging, Sector Capital Allocation, Volatility Haircut Triggers).
- **GAP P3-02 (OLAP Syntax Mandate)**: Specified multi-level `ROLLUP` (`Sector Group -> Sector -> Stock`) and `CUBE` (`Sector Group x Risk Tier`) with `GROUPING()` subtotal labels matching Lab 3 requirements.
- **GAP P3-03 (Optimization Protocol)**: Outlined exact `EXPLAIN (ANALYZE, BUFFERS)` benchmarking methodology to capture query cost and runtime speedups before and after B-Tree composite indexing.

### 3. Examiner Viva Defense Alignment
Codified airtight answers for the three highest-probability examiner questions:
1. Why the architecture transitioned from Databricks (Phase 1 proposal) to PostgreSQL (Phase 2/3 lab requirement).
2. Why `dim_sector` is snowflaked from `dim_stock` (shared by `fact_sector_daily`).
3. How zero row-loss and volumetric reconciliation are mathematically guaranteed.

---

## Revision 3 — 2026‑10‑25 (Phase 1 Official Submission Integration & Folder Restructuring)

### 1. Folder Structure Improvements
- **Course Specification Centralization**: Moved loose university lab briefs (`DWBI Final Project Overview.pdf`, `DWBI Lab Phase 1.pdf`, `DWBI Lab Phase 2.pdf`, `DWBI Lab Phase 3.pdf`) from repository root into `01_Project_Documentation/Course_Specs/`. Root is now clean and uncluttered.
- **Official Submission Preservation**: Moved loose `DWBI_Phase1/` directory into `01_Project_Documentation/Phase_1_Submission/`, preserving all 10 graded submission artefacts (`01_Project_Proposal.pdf`, `02_Business_Requirements_Document.pdf`, `03_Business_Questions.pdf`, `04_Fact_and_Dimension_Identification.pdf`, `05_Grain_Definition.pdf`, `06_Schema_1_Conceptual.png`, `06_Schema_2_Logical.png`, `06_Schema_3_Physical.png`, `06_Star_Snowflake_Schema_Diagram.pdf`, `07_Data_Dictionary.xlsx`).
- **Data Dictionary Export**: Extracted Sheet 4 (Columns) from `07_Data_Dictionary.xlsx` into `01_Project_Documentation/data_dictionary.csv`, providing an Excel-ready and Git-diffable column dictionary.
- **Native Markdown Documentation**: Generated full markdown equivalents matching the official Phase 1 submissions in `01_Project_Documentation/`:
  - `Proposal.md`
  - `BRD.md`
  - `Business_Questions.md` (all 14 analytical questions)
  - `Fact_Dimension_ID.md` (enterprise bus matrix, fact/dimension classifications, key strategies)
  - `Grain_Definition.md` (atomic grain definitions and operational rules for all 5 facts)
  - `schema.dbml` (physical schema specification for dbdiagram.io)

### 2. Schema Canon Alignment
Synchronized `agent.md` and `README.md` with the official Phase 1 submitted and approved schema:
- **5 Fact Tables**:
  1. `fact_daily_stock_price` (Periodic Snapshot — Daily)
  2. `fact_market_daily` (Periodic Snapshot — Daily, Aggregated)
  3. `fact_sector_daily` (Periodic Snapshot — Daily, Aggregated)
  4. `fact_policy_decision` (Transaction Fact)
  5. `fact_market_event` (Factless Fact)
- **6 Dimensions**:
  1. `dim_date` (Conformed Calendar, Smart Key `YYYYMMDD`)
  2. `dim_sector` (Snowflaked Dimension referenced by `dim_stock` and `fact_sector_daily`)
  3. `dim_stock` (SCD Type 2 Equity Dimension)
  4. `dim_risk_tier` (Static Lookup: Low, Medium, High, Not Rated)
  5. `dim_event_type` (Static Lookup: Bonus, Split, Rights, Price-Limit)
  6. `dim_policy_action` (Static Lookup: Hike, Cut, Hold)

### 3. Academic Details & Team Synchronization
- Added official student team details across all documentation:
  - **Saqib Qazi (24L-2506)**
  - **Hassan Shakil (24L-2521)**
  - **Ammara Saleem (24L-2571)**
- Confirmed evaluation breakdown: Phase 1 (30%), Phase 2 (40%), Phase 3 (30%) totaling 15% of course grade.
- Marked Phase 1 as **100% Completed & Approved**.

---

## Revision 2 — 2026‑10‑25 (Post‑Audit Forensic Rewrite)
- Resolved volume reality (5 stocks + 1 index) and planned `generate_data.py`.
- Formulated SBP policy rate reference and schema.
- Replaced non-existent `try_cast` with custom safe casting function.
- Enforced `TRUNCATE … RESTART IDENTITY CASCADE` for fact load idempotency.
- Fixed `.gitignore` negation (`!.env.example`) and added `numpy>=1.24.0` to `requirements.txt`.

---

## Revision 1 — 2026‑10‑25 (Initial Scaffolding)
- Established 3-schema PostgreSQL DWBI layout and initial template files.
