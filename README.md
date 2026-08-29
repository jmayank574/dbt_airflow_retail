# dbt_airflow_retail

Walmart retail demo dataset loaded into a hosted Postgres/TimescaleDB database
(**Ghost** / `ghost.build`), as the raw layer for a dbt + Airflow pipeline.

## Layout

| Path | What |
|---|---|
| `walmart_dataset/ddl/walmart_schema.sql` | DDL for the 6 source tables |
| `walmart_dataset/data/*.csv` | Synthetic source data (one file per table) |
| `walmart_dataset/load_data.py` | Loads the CSVs into schema `raw` via `COPY` (idempotent) |
| `.claude/skills/walmart-db/` | Claude Code skill: full reference for the dataset & DB |

## Data model (schema `raw`, ~52.8k rows)

`customers` (2k), `stores` (25), `products` (500), `employees` (250),
`orders` (10k), `order_items` (30k). Primary keys only; relationships are logical.

## Loading the data

```powershell
# needs: uv, the ghost CLI (authenticated), and the walmart_db database
$env:DATABASE_URL = (ghost connect walmart_db)
uv run python walmart_dataset/load_data.py
```

The connection string is never committed — `.env` is gitignored and the string
is fetched from the Ghost CLI at runtime.
