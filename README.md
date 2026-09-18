# dbt_airflow_retail

Walmart retail demo pipeline: Postgres (Ghost) → Databricks `bronze` → dbt star schema.

## Architecture

```
Postgres (Ghost)  --CDC-->  Databricks bronze
                                   |
                              dbt (walmart_project/)
                                   |
                 silver_t (incremental, typed sources)
                                   |
                 silver_b.obt_b (One-Big-Table + quality checks)
                                   |
        gold ephemeral dims  -->  dim_* SCD2 snapshots
                                   |
                          gold.fact.fact_orders
```

**Planned, not yet built:** AWS S3 as a second source, Apache Airflow orchestration.

## Layout

| Path | What |
|---|---|
| `walmart_project/` | The dbt project (models, snapshots, tests) |
| `walmart_project/models/silver_t/` | Incremental, typed source tables (`bronze` → `silver_t`) |
| `walmart_project/models/silver_b/obt_b.sql` | One-Big-Table, grain = order line |
| `walmart_project/models/gold/ephemeral/` | Deduped dimension projections feeding the SCD2 snapshots |
| `walmart_project/snapshots/` | SCD2 dimension history (`dim_customers`, `dim_products`, `dim_stores`, `dim_orders`, `dim_employees`) |
| `walmart_project/models/gold/fact/fact_orders.sql` | Fact table, grain = order line |
| `.claude/skills/` | Claude Code skills for this project |

## Running

```powershell
cd walmart_project
dbt run
dbt snapshot
dbt test
```

Requires `walmart_project/profiles.yml` (gitignored) with a valid Databricks token.
