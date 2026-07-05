# databricks-insurance-fraud-detection
End-to-end medallion architecture pipeline  ingesting raw claims data through to an AI-ready Gold layer with fraud risk scoring and agent-queryable governed data products
# 🔍 Insurance Claims Fraud Detection Pipeline
### Medallion Architecture on Databricks — Bronze / Silver / Gold

![Databricks](https://img.shields.io/badge/Databricks-Unity%20Catalog-FF3621?logo=databricks)
![Delta Lake](https://img.shields.io/badge/Delta-Lake-00ADD8)
![SQL](https://img.shields.io/badge/Language-SQL-orange)
![Domain](https://img.shields.io/badge/Domain-Insurance-blue)
![Status](https://img.shields.io/badge/Status-Live-brightgreen)

> *Production-grade insurance claims analytics platform built on  
> Databricks using the medallion architecture pattern.*  
> *M Priyadarsini | Compounding Mind 

---

## 🎯 The Problem

Insurance companies process thousands of claims monthly — each
requiring manual review to detect fraud signals buried in financial
ratios, reporting timelines, and free-text descriptions.

Traditional approaches:
- ❌ Manual review — slow, inconsistent, not scalable
- ❌ Siloed data — no unified platform for raw to ML-ready
- ❌ No governance — no audit trail, no access controls
- ❌ Not AI-ready — data not structured for LLM or ML consumption

---

## ✅ The Solution

A production-grade end-to-end pipeline on Databricks using the
medallion architecture — from raw file ingestion through to an
AI-ready Gold layer with composite fraud risk scoring and
agent-queryable governed data products.

**One platform. Full governance. AI-ready output.**

---

## 🏗 Architecture

```
RAW Volume (Unity Catalog)
      ↓
BRONZE Layer — Full-fidelity Delta table (zero transformations)
      ↓
SILVER Layer — Cleansed + conformed data
  → report_delay_days (fraud signal)
  → claim_ratio (financial signal)  
  → claim_description_clean (NLP-ready)
      ↓
GOLD Layer — AI-ready feature engineering
  → high_amount_indicator
  → delayed_report_indicator
  → fraud_risk_score (weighted composite 0.0–1.0)
      ↓
GOVERNED VIEWS — Agent-queryable data products
  → vw_high_risk_claims (fraud_risk_score > 0.5)
  → vw_risk_tiered (CRITICAL / HIGH / MEDIUM / LOW)
  → vw_fraud_summary (BI dashboard ready)
```

---

## 🧠 Medallion Layer Design

| Layer | Schema | Purpose | Format |
|---|---|---|---|
| **RAW** | insurance_cat.raw | Landing zone — immutable files | Volume |
| **BRONZE** | insurance_cat.bronze | Full-fidelity raw copy | Delta Table |
| **SILVER** | insurance_cat.silver | Cleansed + transformed data | Delta Table |
| **GOLD** | insurance_cat.gold | ML-ready + fraud risk scoring | Delta Table |

---

## 🔑 Silver Transformations

| Transformation | Field | Business Value |
|---|---|---|
| Report Delay Days | `report_delay_days` | Days between incident and filing — key fraud signal |
| Claim Ratio | `claim_ratio` | Claim vs coverage — flags over-claiming |
| Text Standardisation | `claim_description_clean` | Lowercase for NLP/AI analysis |

---

## 🎯 Gold Fraud Risk Features

| Feature | Logic | Weight |
|---|---|---|
| `high_amount_indicator` | claim_ratio > 0.75 | 0.20 |
| `delayed_report_indicator` | report_delay_days > 7 | — |
| `fraud_risk_score` | Weighted composite (0.0–1.0) | 0.50 + 0.30 + 0.20 |

**Fraud Risk Score Formula:**
```sql
(claim_ratio * 0.5) +
(CASE WHEN report_delay_days <= 2 THEN 0.3 ELSE 0 END) +
(CASE WHEN claim_ratio > 0.75 THEN 0.2 ELSE 0 END)
```

---

## 📊 Sample Output

### Gold Layer — Fraud Risk Scoring
| Claim | Amount | Ratio | Delay | Risk Score | Label |
|---|---|---|---|---|---|
| 4 | $9,000 | 0.90 | 2 days | **0.54** | FRAUD RISK |
| 2 | $8,500 | 0.85 | 1 day | **0.51** | FRAUD RISK |
| 7 | $7,200 | 0.90 | 1 day | **0.65** | FRAUD RISK |
| 1 | $2,500 | 0.25 | 2 days | **0.13** | LOW RISK |
| 8 | $450 | 0.05 | 5 days | **0.03** | LOW RISK |

### Fraud Summary View
| Total Claims | High Risk | Avg Score | Total Fraud Amount |
|---|---|---|---|
| 10 | 4 | 0.267 | $31,500 |

---

## 🛠 Tech Stack

- **Platform:** Databricks (Unity Catalog)
- **Storage:** Delta Lake (ACID-compliant, time travel enabled)
- **Governance:** Unity Catalog — catalog/schema/volume separation
- **Language:** SQL (Databricks SQL)
- **Architecture:** Medallion — Bronze/Silver/Gold
- **Output:** AI-ready data products — LLM, RAG, ML ready

---

## 📁 Repository Structure

```
insurance-fraud-detection-databricks/
│
├── sql/
│   └── 01_insurance_fraud_pipeline.sql   # Full pipeline
│
└── README.md
```

---

## 🚀 How to Run

### Prerequisites
- Databricks workspace (Community Edition works)
- SQL warehouse or cluster running

### Steps
```sql
-- Run the full pipeline top to bottom
-- in a Databricks SQL notebook or editor

-- Section 1: Catalog + schema setup
-- Section 2: Sample data load
-- Section 3: Bronze layer creation
-- Section 4: Silver layer + transformations
-- Section 5: Gold layer + fraud scoring
-- Section 6: Governed views
-- Section 7: Validation queries
```

---

## 💡 Why This Architecture Matters

**For enterprise data teams:**
- Delta Lake ACID compliance — safe concurrent reads/writes
- Unity Catalog governance — RBAC-ready from day one
- Volume-based raw ingestion — decouples files from Delta
- Schema-per-layer isolation — independent SLAs per layer

**For AI/ML teams:**
- Gold layer is LLM and RAG ready — pre-filtered, ordered
- Governed views reduce token cost for AI agents
- Fraud risk score is ML feature-engineered — ready for model training
- Agent-queryable data products — structured for tool use

---

## 🔗 Related Projects

| Project | Platform | Domain |
|---|---|---|
| [Customer Feedback Intelligence](../snowflake-cortex-feedback-pipeline) | Snowflake Cortex | AI/Retail |
| [Payment Profit Pipeline](../bigquery-payment-pipeline) | BigQuery + Snowflake | Financial Services |
| Insurance Fraud Detection (this project) | Databricks + Delta Lake | Insurance |

---

## 📺 Watch the Full Tutorial

🎥 **YouTube:** https://youtube.com/@compoundingmind
---

## 💼 Work With Me

This is the kind of pipeline I build for enterprise clients 
in financial services, pharma, and retail.

- 📅 [Book a free 15-min call](https://calendly.com/mama-priyadarsini/15-minute-business-strategy-call)
- 🔗 [LinkedIn](https://www.linkedin.com/in/m-priyadarsini-00427141/)
- 🎥 [YouTube — Compounding Mind](https://www.youtube.com/@compoundingmind)

---

## 👩‍💻 About

Built by **M Priyadarsini** — Senior Data Engineer & Architect 
with 20 years of enterprise experience across financial 
services, pharma, and retail.

Clients include: Sun Life Financial · CPPIB · Sanofi · 
Nielsen · Fairstone Bank

Available for remote consulting — Canada + US time zones.
📅 [Book a free 15-min call](https://calendly.com/mama-priyadarsini/15-minute-business-strategy-call)

*Built during Sunning's nap times. One step a day.* 🍼❄️

*One step a day.* 🍼🍁

---

*© 2026 M Priyadarsini · 1144Canada Inc.*
