-- ============================================================
-- INSURANCE CLAIMS FRAUD DETECTION PIPELINE
-- Platform: Databricks (Unity Catalog + Delta Lake)
-- Architecture: Medallion — Bronze / Silver / Gold
-- Author: M Priyadarsini
-- Domain: Insurance — Claims Fraud Detection
-- Description: End-to-end medallion architecture pipeline
--              ingesting raw claims data through to an
--              AI-ready Gold layer with fraud risk scoring
--              and agent-queryable governed data products
-- ============================================================

-- ============================================================
-- SECTION 1: CATALOG & GOVERNANCE SETUP
-- Unity Catalog — full catalog/schema/volume separation
-- Mirrors enterprise RBAC and data lineage standards
-- ============================================================

-- Create catalog
CREATE CATALOG IF NOT EXISTS insurance_cat;

-- Schema separation per medallion layer
CREATE SCHEMA IF NOT EXISTS insurance_cat.raw;
CREATE SCHEMA IF NOT EXISTS insurance_cat.bronze;
CREATE SCHEMA IF NOT EXISTS insurance_cat.silver;
CREATE SCHEMA IF NOT EXISTS insurance_cat.gold;

-- Volume for raw file landing zone
-- Decouples file ingestion from Delta table processing
-- Enables replay, audit, and incremental ingestion patterns
CREATE VOLUME IF NOT EXISTS insurance_cat.raw.raw_files;

-- ============================================================
-- SECTION 2: SAMPLE DATA SETUP
-- Realistic anonymized insurance claims data
-- 10 claims with mixed legitimate and fraudulent patterns
-- ============================================================

-- Raw claims table for demo purposes
CREATE TABLE IF NOT EXISTS insurance_cat.default.claims_raw (
  claim_id            INTEGER,
  policy              INTEGER,
  certificate         INTEGER,
  claim_amount        DECIMAL(10,2),
  policy_coverage     DECIMAL(10,2),
  claim_description   STRING,
  incident_date       DATE,
  claim_date          DATE,
  is_fraud            INTEGER   -- 0 = legitimate, 1 = fraudulent
);

INSERT INTO insurance_cat.default.claims_raw VALUES
(1,  10001, 20001,  2500.00,  10000.00, 'Minor fender bender in parking lot. No injuries.',         '2026-01-10', '2026-01-12', 0),
(2,  10002, 20002,  8500.00,  10000.00, 'Vehicle stolen from driveway overnight.',                  '2026-01-15', '2026-01-16', 1),
(3,  10003, 20003,  1200.00,  15000.00, 'Windshield cracked by debris on highway.',                 '2026-01-20', '2026-01-25', 0),
(4,  10004, 20004,  9000.00,  10000.00, 'Total loss after collision at intersection.',              '2026-02-01', '2026-02-03', 1),
(5,  10005, 20005,   800.00,  12000.00, 'Water damage from burst pipe in garage.',                  '2026-02-05', '2026-02-10', 0),
(6,  10006, 20006,  3500.00,  10000.00, 'Rear-ended at traffic light. Whiplash claim.',             '2026-02-12', '2026-02-28', 0),
(7,  10007, 20007,  7200.00,   8000.00, 'Fire damage to vehicle. Cause unknown.',                   '2026-03-01', '2026-03-02', 1),
(8,  10008, 20008,   450.00,  10000.00, 'Hail damage to roof and hood.',                            '2026-03-10', '2026-03-15', 0),
(9,  10009, 20009,  6800.00,   9000.00, 'Flood damage. Vehicle submerged.',                         '2026-03-20', '2026-03-21', 1),
(10, 10010, 20010,  1800.00,  20000.00, 'Side mirror damaged in hit and run.',                      '2026-04-01', '2026-04-05', 0);

-- ============================================================
-- SECTION 3: BRONZE LAYER — RAW INGESTION
-- Full-fidelity copy of raw data as Delta table
-- Zero transformations — preserves source fidelity
-- Enables full audit trail and replay capability
-- ============================================================

CREATE TABLE IF NOT EXISTS insurance_cat.bronze.bronze_claims
USING DELTA
AS
SELECT *
FROM insurance_cat.default.claims_raw;

-- Verify Bronze layer
SELECT COUNT(*) AS total_claims FROM insurance_cat.bronze.bronze_claims;

-- ============================================================
-- SECTION 4: SILVER LAYER — CLEANSED & CONFORMED DATA
-- Three core transformations:
-- 1. Time-based metric: report delay days
-- 2. Financial ratio: claim vs coverage
-- 3. Text standardisation: lowercase description
-- ============================================================

CREATE TABLE IF NOT EXISTS insurance_cat.silver.silver_claims
USING DELTA AS
SELECT
  claim_id,
  policy,
  certificate,
  claim_amount,
  policy_coverage,
  claim_description,
  incident_date,
  claim_date,
  is_fraud,

  -- Transformation 1: Time-based metric
  -- Days between incident and claim filing — key fraud signal
  -- Fraudulent claims often filed very quickly or very late
  datediff(claim_date, incident_date)         AS report_delay_days,

  -- Transformation 2: Financial ratio
  -- Claim amount vs coverage limit
  -- Ratios close to 1.0 indicate potential over-claiming
  claim_amount / policy_coverage              AS claim_ratio,

  -- Transformation 3: Text standardisation
  -- Lowercase normalisation for consistent NLP/AI analysis
  lower(claim_description)                   AS claim_description_clean

FROM insurance_cat.bronze.bronze_claims;

-- Verify Silver layer with transformations
SELECT
  claim_id,
  claim_amount,
  policy_coverage,
  report_delay_days,
  ROUND(claim_ratio, 2)         AS claim_ratio,
  claim_description_clean,
  is_fraud
FROM insurance_cat.silver.silver_claims
ORDER BY claim_ratio DESC;

-- ============================================================
-- SECTION 5: GOLD LAYER — AI-READY FEATURE ENGINEERING
-- ML and AI consumption layer
-- Fraud detection features + composite risk score
-- Agent-queryable data product for LLM tool use and RAG
-- ============================================================

CREATE TABLE IF NOT EXISTS insurance_cat.gold.gold_claims
USING DELTA AS
SELECT
  claim_id,
  policy,
  certificate,
  claim_amount,
  policy_coverage,
  claim_description_clean,
  report_delay_days,
  ROUND(claim_ratio, 2)                       AS claim_ratio,
  is_fraud,

  -- Feature 1: High amount indicator
  -- Flags claims exceeding 75% of policy coverage
  CASE
    WHEN claim_ratio > 0.75 THEN 1 ELSE 0
  END                                         AS high_amount_indicator,

  -- Feature 2: Delayed report indicator
  -- Flags claims filed more than 7 days after incident
  CASE
    WHEN report_delay_days > 7 THEN 1 ELSE 0
  END                                         AS delayed_report_indicator,

  -- Feature 3: Composite fraud risk score (0.0 to 1.0)
  -- Weighted combination of financial and behavioural signals
  -- Tunable weights — extensible for additional features
  ROUND(
    (claim_ratio * 0.5) +
    (CASE WHEN report_delay_days <= 2 THEN 0.3 ELSE 0 END) +
    (CASE WHEN claim_ratio > 0.75 THEN 0.2 ELSE 0 END),
    2
  )                                           AS fraud_risk_score

FROM insurance_cat.silver.silver_claims;

-- Verify Gold layer — the full AI-ready output
SELECT
  claim_id,
  claim_amount,
  policy_coverage,
  claim_ratio,
  report_delay_days,
  high_amount_indicator,
  delayed_report_indicator,
  fraud_risk_score,
  CASE
    WHEN fraud_risk_score > 0.5 THEN 'FRAUD RISK'
    ELSE 'LOW RISK'
  END                                         AS risk_label,
  is_fraud
FROM insurance_cat.gold.gold_claims
ORDER BY fraud_risk_score DESC;

-- ============================================================
-- SECTION 6: GOVERNED VIEWS — AGENT-QUERYABLE DATA PRODUCTS
-- Production-ready views for AI agents, LLM tools,
-- BI dashboards, and ML model training pipelines
-- ============================================================

-- View 1: High-risk claims only (fraud_risk_score > 0.5)
-- Reduces AI/LLM token cost — agents query only high-risk records
-- Enforces business rules consistently in one place
CREATE OR REPLACE VIEW insurance_cat.gold.vw_high_risk_claims AS
SELECT
  claim_id,
  policy,
  certificate,
  claim_amount,
  claim_description_clean,
  report_delay_days,
  claim_ratio,
  high_amount_indicator,
  delayed_report_indicator,
  fraud_risk_score,
  is_fraud
FROM insurance_cat.gold.gold_claims
WHERE fraud_risk_score > 0.5
ORDER BY fraud_risk_score DESC;

-- View 2: Risk tier segmentation for ML training
CREATE OR REPLACE VIEW insurance_cat.gold.vw_risk_tiered AS
SELECT *,
  CASE
    WHEN fraud_risk_score >= 0.8 THEN 'CRITICAL'
    WHEN fraud_risk_score >= 0.6 THEN 'HIGH'
    WHEN fraud_risk_score >= 0.4 THEN 'MEDIUM'
    ELSE 'LOW'
  END                                         AS risk_tier
FROM insurance_cat.gold.gold_claims;

-- View 3: Aggregated summary for BI dashboards
CREATE OR REPLACE VIEW insurance_cat.gold.vw_fraud_summary AS
SELECT
  COUNT(*)                                    AS total_claims,
  SUM(CASE WHEN fraud_risk_score > 0.5
      THEN 1 ELSE 0 END)                      AS high_risk_count,
  ROUND(AVG(fraud_risk_score), 3)             AS avg_risk_score,
  SUM(CASE WHEN is_fraud = 1
      THEN claim_amount ELSE 0 END)           AS total_fraud_amount,
  ROUND(AVG(claim_ratio), 2)                  AS avg_claim_ratio
FROM insurance_cat.gold.gold_claims;

-- ============================================================
-- SECTION 7: VALIDATION QUERIES
-- Verify all layers and views are working correctly
-- Screenshot these for portfolio and YouTube
-- ============================================================

-- High risk claims view 
SELECT * FROM insurance_cat.gold.vw_high_risk_claims;

-- Risk tier distribution
SELECT
  risk_tier,
  COUNT(*)                                    AS claim_count,
  ROUND(AVG(fraud_risk_score), 3)             AS avg_score
FROM insurance_cat.gold.vw_risk_tiered
GROUP BY risk_tier
ORDER BY avg_score DESC;

-- Fraud summary dashboard 
SELECT * FROM insurance_cat.gold.vw_fraud_summary;

-- Layer record counts — verify medallion pipeline
SELECT 'Bronze' AS layer, COUNT(*) AS records
FROM insurance_cat.bronze.bronze_claims
UNION ALL
SELECT 'Silver', COUNT(*)
FROM insurance_cat.silver.silver_claims
UNION ALL
SELECT 'Gold', COUNT(*)
FROM insurance_cat.gold.gold_claims;

-- ============================================================
-- END OF PIPELINE
-- Full Medallion Architecture — Bronze / Silver / Gold
-- AI-ready Gold layer with fraud risk scoring
-- Agent-queryable governed data products
-- ============================================================
