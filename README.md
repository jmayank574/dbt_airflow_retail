# dbt_airflow_retail

Walmart retail demo pipeline: Postgres (Ghost) → Databricks `bronze` → dbt star schema.

## Architecture

```
Airflow (orchestrate DAG, daily 11am UTC)
    |
    +-- 1. trigger + wait: Databricks "ingest_walmart job" (CDC --> bronze)
    |
    +-- 2. dbt, layer by layer, test after each:
             silver_t (incremental, typed sources)
                    |
             silver_b.obt_b (One-Big-Table + quality checks)
                    |
             gold ephemeral dims  -->  dim_* SCD2 snapshots
                    |
             gold.fact.fact_orders
```

**Possible later, not committed to:** AWS S3 as a second source.

## Layout

| Path | What |
|---|---|
| `walmart_project/` | The dbt project (models, snapshots, tests) |
| `walmart_project/models/silver_t/` | Incremental, typed source tables (`bronze` → `silver_t`) |
| `walmart_project/models/silver_b/obt_b.sql` | One-Big-Table, grain = order line |
| `walmart_project/models/gold/ephemeral/` | Deduped dimension projections feeding the SCD2 snapshots |
| `walmart_project/snapshots/` | SCD2 dimension history (`dim_customers`, `dim_products`, `dim_stores`, `dim_orders`, `dim_employees`) |
| `walmart_project/models/gold/fact/fact_orders.sql` | Fact table, grain = order line |
| `walmart_project/airflow/` | Airflow 3.3.2 docker-compose stack orchestrating the pipeline |
| `walmart_project/airflow/dags/orchestrate.py` | The DAG: triggers the Databricks ingestion job, then runs dbt layer-by-layer with a test after each layer |
| `.claude/skills/` | Claude Code skills for this project |

## Running

**dbt directly:**
```powershell
cd walmart_project
dbt run
dbt snapshot
dbt test
```
Requires `walmart_project/profiles.yml` (gitignored) with a valid Databricks token.

**Via Airflow** (orchestrates the same steps, scheduled daily at 11am UTC, plus triggers the upstream Databricks ingestion job first):
```powershell
cd walmart_project/airflow
docker compose up -d
```
UI at `http://localhost:8080` (admin/admin). Requires `walmart_project/airflow/.env` (gitignored) with `DATABRICKS_HOST`/`DATABRICKS_TOKEN`.
