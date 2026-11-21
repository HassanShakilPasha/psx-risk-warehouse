# Business Requirements Document (BRD)
## PSX Market Risk Data Warehouse: Volatility and Risk Analytics for the Pakistan Stock Exchange
**Course**: DL3004 Final Project - Phase 1: Business Analysis & Dimensional Design  
**Team**: Saqib Qazi (24L-2506) | Hassan Shakil (24L-2521) | Ammara Saleem (24L-2571)

---

## 1. Purpose
This Business Requirements Document (BRD) defines what the PSX Market Risk Data Warehouse must deliver: who uses it, which business needs it serves, which data and measures it must contain, and how success is judged.

---

## 2. Business Background
Investors, analysts and risk teams in Pakistan follow the PSX daily but lack a consolidated, historical and risk-focused view. Volatility clusters (calm and turbulent periods follow each other), and large policy rate moves by the SBP have repeatedly shaken the market. A warehouse that measures risk consistently across stocks, sectors and time supports better monitoring and research.

---

## 3. Stakeholders

| Stakeholder | Role | Main need |
|---|---|---|
| **Equity / risk analyst** | Primary user | Find high-risk stocks and sectors; compare risk over time |
| **Portfolio manager** | Decision maker | Know whether turbulence is market-wide or limited to certain companies |
| **Economic researcher** | Analyst | Study the market's reaction to SBP rate decisions |
| **Compliance / market surveillance** | Monitor | Track unusual price-limit moves and corporate action adjustments |
| **Data engineering team (project team)** | Builder / owner | Reliable, documented, incrementally loaded warehouse |

---

## 4. Business Objectives

| ID | Objective | Success measure |
|---|---|---|
| **BO-1** | Identify which stocks and sectors are in a high-risk regime | Daily risk tier available for every rated stock |
| **BO-2** | Separate systemic from company-specific risk | Daily market-level stress measure (% of stocks high risk) |
| **BO-3** | Measure the market's reaction to monetary policy | Every SBP decision linked to market volatility before/after |
| **BO-4** | Monitor liquidity and market events | Corporate actions, price-limit moves and no-trade days recorded |
| **BO-5** | Provide trusted history for 2015 onwards | Complete trading history with daily incremental updates |

---

## 5. Business Requirements

| ID | Requirement | Priority | Objective |
|---|---|:---:|:---:|
| **BR-01** | The system shall store end-of-day prices and volume for every PSX security for every trading day since 1 Jan 2015. | Must | BO-5 |
| **BR-02** | The system shall compute a daily log return for each stock using the PSX previous close (LDCP). | Must | BO-1 |
| **BR-03** | The system shall compute 20-day and 60-day annualised volatility for each stock. | Must | BO-1 |
| **BR-04** | The system shall assign each stock a daily risk tier (Low / Medium / High / Not Rated) based on its volatility percentile. | Must | BO-1 |
| **BR-05** | The system shall aggregate risk and activity per sector per day. | Must | BO-1 |
| **BR-06** | The system shall produce daily market measures: breadth, market return, market volatility, % of stocks high risk. | Must | BO-2 |
| **BR-07** | The system shall store every SBP policy rate decision with its rate, change and direction. | Must | BO-3 |
| **BR-08** | The system shall record market events: corporate action adjustments, price-limit moves and no-trade days. | Should | BO-4 |
| **BR-09** | The system shall keep history of company name and sector changes (SCD Type 2). | Should | BO-5 |
| **BR-10** | The system shall flag delisted or suspended stocks instead of deleting them. | Should | BO-5 |
| **BR-11** | The system shall support analysis by day, week, month, quarter and year. | Must | All |
| **BR-12** | Results shall be available in an interactive Power BI dashboard. | Must | All |

---

## 6. Functional Requirements

| ID | Function |
|---|---|
| **FR-01** | Load new daily files incrementally and re-load any past period (backfill) without code changes. |
| **FR-02** | Reject malformed records into a quarantine area with a reason; never stop the whole load. |
| **FR-03** | Remove duplicate stock-day records; one row per stock per trading day. |
| **FR-04** | Exclude futures/derivatives (symbols containing '-') from stock analysis. |
| **FR-05** | Look up surrogate keys for every fact row; unmatched keys go to an 'Unknown' member (`-1`). |
| **FR-06** | Record every load in an execution log (start, end, status, rows inserted/updated/rejected). |
| **FR-07** | Allow filtering and drilling through the date, sector and stock hierarchies in the dashboard. |

---

## 7. Data Requirements & Governance

| Item | Requirement |
|---|---|
| **Sources** | PSX Daily Market Summary (primary); SBP Structure of Interest Rates; PSX sector reference list |
| **History** | 1 Jan 2015 to present (~2,900 trading days, ~1.09M stock-day rows) |
| **Refresh** | Daily, after PSX publishes the closing summary |
| **Quality rules** | Valid date; numeric prices and volume; $\text{low} \le \text{open/close} \le \text{high}$; $\text{prices} > 0$; one row per stock per day |
| **Corporate actions** | Returns use LDCP so splits/bonuses do not appear as crashes; detected adjustments recorded as events |
| **Privacy** | No personally identifiable information: data is aggregated exchange-level market data |

---

## 8. Key Measures (KPIs)

| Measure | Definition | Formula |
|---|---|---|
| **Daily log return** | Price change of a stock vs its previous close | $\ln(\text{close} / \text{LDCP})$ |
| **20-day volatility** | Annualised standard deviation of the last 20 daily returns | $\text{stddev}(\text{return}, 20\text{ days}) \times \sqrt{252}$ |
| **Risk percentile** | Rank of a stock's 20-day volatility among all stocks that day | $\text{percent\_rank}(\text{volatility\_20d})\text{ per day}$ |
| **Risk tier** | Bucket of risk percentile | $\text{Low} < 0.40 \le \text{Medium} < 0.80 \le \text{High}$ |
| **Market return** | Equal-weighted average of all stock returns that day | $\text{avg}(\text{daily\_log\_return})$ |
| **% stocks high risk** | Share of rated stocks in the High tier (systemic stress) | $\text{count}(\text{High}) / \text{count}(\text{rated})$ |
| **Market breadth** | Advancing vs declining stocks | $\text{count}(\text{return} > 0), \text{count}(\text{return} < 0)$ |
| **Policy rate change** | Change in SBP policy rate per decision | $\text{new rate} - \text{previous rate (bps)}$ |

---

## 9. Non-Functional Requirements
- **Performance**: Dashboard visuals should return in under 5 seconds; fact tables clustered/indexed on date and stock keys.
- **Reliability**: Loads are idempotent; re-running the same period produces no duplicates.
- **Auditability**: Every row carries a `load_timestamp`; every load is logged.
- **Maintainability**: Code in version control; documented data dictionary and run guide.
- **Compliance**: PSX data used for academic purposes only; full data is not redistributed.

---

## 10. Assumptions and Constraints
- PSX publishes no file on weekends and market holidays; those dates are non-trading days.
- PSX adjusts LDCP for corporate actions; where it does not, extreme moves are flagged and excluded from volatility.
- Sector codes changed over time; a reference mapping aligns old and new codes.
- Volatility needs at least 15 valid returns in a 20-day window; otherwise the stock is classified as `'Not Rated'`.

---

## 11. Acceptance Criteria
1. All 14 business questions can be answered from the warehouse.
2. Row counts reconcile between source files and the stock fact (minus quarantined and excluded records).
3. Every fact foreign key resolves to a dimension row (zero orphans).
4. The dashboard shows stock, sector and market risk with date drill-down.
