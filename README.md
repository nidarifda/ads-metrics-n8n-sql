# Ads Metrics (n8n + Postgres)

Ingest ads CSV → model CAC/ROAS → expose a tiny `/metrics` API.

- n8n orchestrates: download CSV → parse → UPSERT → dedupe/index  
- Postgres warehouse with provenance (`load_date`, `source_file_name`)  
- KPIs: **CAC = spend/conversions**, **ROAS = (conversions × 100) / spend**  
- Compact comparison: **last 30 days vs prior 30 days**  
- JSON API: `GET /metrics?start=YYYY-MM-DD&end=YYYY-MM-DD`

## Repo layout
/ingestion/n8n_workflow.json  
/sql/01_create_table.sql  
/sql/02_upsert_example.sql  
/sql/03_dedupe_and_index.sql  
/sql/04_kpi_compact_query.sql  
/sql/04b_kpi_by_platform.sql  
/sql/05_view_v_ads_daily.sql  
/sql/07_agent_demo_query.sql  
/docs/n8n_workflow.png  
/docs/kpi_modeling_result.png  
/docs/sample_metrics_response.json

## Setup (Postgres)
```bash
# create table + unique index (idempotent loads)
psql "$DATABASE_URL" -f sql/01_create_table.sql
psql "$DATABASE_URL" -f sql/03_dedupe_and_index.sql
```
- Uniqueness key: `(date, platform, account, campaign, country, device)`  
- Provenance: `load_date TIMESTAMPTZ DEFAULT now()`, `source_file_name TEXT`

## Run ingestion (n8n)
1) Import `ingestion/n8n_workflow.json`  
2) Configure Postgres credentials on nodes  
3) Click **Execute workflow** (top lane) — re-run to prove idempotency

## Verify data & provenance
```sql
SELECT COUNT(*) FROM public.ads_spend;

SELECT load_date::timestamp(0) AS load_batch, COUNT(*)
FROM public.ads_spend
GROUP BY 1 ORDER BY 1 DESC;

SELECT COALESCE(source_file_name,'(null)') AS file,
       MIN(load_date) AS first_load,
       MAX(load_date) AS last_load,
       COUNT(*) AS rows
FROM public.ads_spend
GROUP BY 1
ORDER BY last_load DESC;
```

## KPIs (SQL)
**Compact 30d vs prior 30d**
```bash
psql "$DATABASE_URL" -f sql/04_kpi_compact_query.sql
```
**By platform**
```bash
psql "$DATABASE_URL" -f sql/04b_kpi_by_platform.sql
```
**Daily view** (creates `public.v_ads_daily`)
```bash
psql "$DATABASE_URL" -f sql/05_view_v_ads_daily.sql
```

## API (Analyst Access)
**Production URLs**  
`GET https://<your-n8n-host>/webhook/metrics`  
`GET https://<your-n8n-host>/webhook/metrics?start=YYYY-MM-DD&end=YYYY-MM-DD`  

- No params → defaults to **last 30 days ending at MAX(date)**

**Example**
```bash
curl "https://<your-n8n-host>/webhook/metrics?start=2025-06-01&end=2025-06-30"
```
Sample output: `docs/sample_metrics_response.json`

> n8n path: `/metrics` → Postgres (binds one JSON param `$1` = `{"start": "...", "end": "..."}`) → Respond to Webhook.

## Agent demo (bonus)
User: “Compare CAC and ROAS for last 30 days vs prior 30 days.”  
Answer path: call `/metrics` (no params) or run `sql/07_agent_demo_query.sql`

## Screenshots
Workflow: `docs/n8n_workflow.png`  
KPI table: `docs/kpi_modeling_result.png`

## Deliverables
- n8n access (production URL or `ingestion/n8n_workflow.json`)  
- Public GitHub repo with `/ingestion`, `/sql`, `/docs`, README  
- Results screenshot(s) or API sample JSON  
- Loom (≤ 5 min) explaining approach & key decisions

## Notes
- Revenue = conversions × 100 (per prompt)  
- Windows use inclusive bounds (true 30 vs prior 30)  
- Percent deltas return NULL when prior is 0
