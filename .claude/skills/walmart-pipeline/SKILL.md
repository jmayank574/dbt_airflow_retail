---
name: walmart-pipeline
description: >-
  Reference for the Walmart retail dbt + Airflow pipeline in this project. Use
  whenever the user asks about the dbt models, the star schema (fact/dims/
  snapshots), the Airflow orchestration DAG, the Databricks connection, or how
  to run/rebuild the pipeline.
---

# Walmart dbt + Airflow pipeline

Synthetic Walmart retail data, ingested into Databricks and transformed into a
star schema with dbt, orchestrated by Airflow. This replaced an earlier
CSV/Postgres-only setup (`walmart_dataset/`, deleted) — don't reference that
old layout, it no longer exists.

## Architecture

```
Airflow (orchestrate DAG, daily 11am UTC)
    |
    +-- 1. trigger + wait: Databricks "ingest_walmart job" (CDC --> bronze)
    |
    +-- 2. dbt, layer by layer, test after each:
             silver_t (incremental, typed sources)
                    |
             silver_b.obt_b (One-Big-Table, grain = order line)
                    |
             gold ephemeral dims  -->  dim_* SCD2 snapshots
                    |
             gold.fact.fact_orders
```

Bronze ingestion (Databricks Job `ingest_walmart job`, wrapping a Lakeflow/DLT
pipeline `ingest_walmart`) is a Databricks-native job, not code in this repo —
Airflow's `ingest_cdc` task triggers it via `databricks-sdk` and polls for
completion before dbt runs.

## dbt project (`walmart_project/`)

| Layer | Path | What |
|---|---|---|
| Source | `models/source/sources.yml` | `walmart.bronze.*` — 6 tables (customers, orders, products, employees, order_items, stores). No freshness config yet (deliberately deferred). |
| `silver_t` | `models/silver_t/*.sql` | Incremental, typed per-source tables (`unique_key` on PK, filters on `updated_timestamp`) |
| `silver_b` | `models/silver_b/obt_b.sql` | One-Big-Table: metadata-driven join of orders/customers/order_items/products/stores. Grain = `order_item_id`. **Edit only the `sources` list at the top to add/remove a joined table.** |
| `gold/ephemeral` | `models/gold/ephemeral/eph_*.sql` | Deduped dimension projections. Source **directly from `silver_t`** (not `obt_b`) for customers/products/stores/employees — obt_b is driven from orders, so anything with zero orders would be silently dropped if dims were built off it. `eph_orders` is the one exception (correctly sources from `obt_b`, since order lines only exist in the context of an order). Materialized `ephemeral` — never persist standalone, only compile inline wherever referenced (e.g. inside `dbt snapshot`). Running `dbt run --select gold/ephemeral` directly is a harmless no-op. |
| `gold/fact` | `models/gold/fact/fact_orders.sql` | Fact table, grain = `order_item_id`, sourced from `obt_b`. FKs: `order_id`, `customer_id`, `product_id`, `store_id`. Measures: `quantity`, `unit_price`, `line_amount`. **`total_amount` deliberately excluded** — it's an order-level total that repeats per line in `obt_b`; summing it at this grain would overcount orders with >1 line item. |
| Snapshots | `snapshots/dim_*.yml` | SCD2 history via `ref('eph_*')`, `strategy: timestamp`. `dim_orders` snapshots order-line data (unusual for SCD2 — normally used for slowly-changing dims, not transactional facts; kept for the learning value). |

Schema per layer is set directly by `macros/custom_schema.sql` (no
`<target>_<custom>` concatenation) — `silver_t` lands in schema `silver_t`,
`silver_b` in `silver_b`, `gold` in `gold`, matching `dbt_project.yml`'s
`+schema:` config.

`fact_orders`'s `properties.yml` has `relationships` tests checking its FKs
against `dim_customers`/`dim_products`/`dim_stores` — these only pass if
`dbt snapshot` has already run; if `dbt test` runs before `dbt snapshot`,
these tests error out on missing tables.

## Databricks connection

`walmart_project/profiles.yml` (gitignored) — host, `http_path` (SQL
warehouse), catalog `walmart`, PAT token. Regenerate the token in Databricks
(User Settings → Developer → Access tokens) if you see "Invalid access
token".

## Airflow orchestration (`walmart_project/airflow/`)

- Docker Compose stack, Airflow **3.3.2** (`LocalExecutor`; no Celery/Redis —
  not needed for one DAG). Airflow 3 split the old `webserver` into a
  separate `api-server`, and DAG parsing is a dedicated `dag-processor`
  service now — both are mandatory, not optional add-ons.
- `dags/orchestrate.py` — the DAG described above. TaskFlow API throughout
  (`@task` for the Python Databricks-trigger task, `@task.bash` for every dbt
  step). Scheduled `"0 11 * * *"` (11am UTC daily), `catchup=False`.
- The whole `walmart_project/` dir is bind-mounted into the containers at
  `/opt/airflow/dbt_project` — DAG tasks `cd` there and run `dbt ...` against
  your real, live project files (no rebuild needed after editing a model).
- `dbt-core`, `dbt-databricks`, and `databricks-sdk` are installed via
  `_PIP_ADDITIONAL_REQUIREMENTS` in `docker-compose.yaml` (installs at every
  container start — fine for learning, a real setup would bake a custom
  image instead).
- Credentials: `airflow/.env` (gitignored) holds `AIRFLOW_UID`,
  `DATABRICKS_HOST`, `DATABRICKS_TOKEN` — read via `env_file:` into every
  container. **Never hardcode these in DAG code** (this happened once before
  and was caught/fixed prior to pushing).
- `airflow/config/airflow.cfg` is auto-generated on container start (contains
  a `fernet_key` secret) — gitignored, don't commit it.
- Login: `admin`/`admin` (created by `airflow-init` via `_AIRFLOW_WWW_USER_*`
  env vars, using `FabAuthManager` — Airflow 3 defaults to a different auth
  manager with an auto-generated password otherwise).

## Running

**dbt directly:**
```powershell
cd walmart_project
dbt run
dbt snapshot
dbt test
```

**Via Airflow** (same steps, plus triggers the Databricks ingestion job first):
```powershell
cd walmart_project/airflow
docker compose up -d
```
UI at `http://localhost:8080`.

## Gotchas

- Airflow's `ingest_walmart job` also has its own native "Scheduled" trigger
  inside Databricks, independent of this DAG. If both fire, ingestion could
  run twice. Not yet reconciled — worth pausing the native schedule once
  Airflow is trusted to own triggering it.
- `dbt source freshness` runs in the DAG but has nothing to check yet — no
  `freshness:` block defined on `sources.yml`. Deferred deliberately.
- This repo is **public** on GitHub — always check new files for hardcoded
  hosts/tokens/keys before committing (`profiles.yml`, `airflow/.env`,
  `airflow/config/airflow.cfg` are the recurring risk spots, all gitignored).
- AWS S3 as a second source is a maybe-later idea, not committed to or built.
