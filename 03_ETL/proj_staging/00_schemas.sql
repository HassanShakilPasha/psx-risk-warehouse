-- Warehouse layers: raw + staging tables live in project_staging, the star schema in project_dw,
-- BI views in project_reporting.
CREATE SCHEMA IF NOT EXISTS project_staging;
CREATE SCHEMA IF NOT EXISTS project_dw;
CREATE SCHEMA IF NOT EXISTS project_reporting;
