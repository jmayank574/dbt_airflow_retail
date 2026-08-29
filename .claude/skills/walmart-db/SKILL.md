---
name: walmart-db
description: >-
  Reference for the Walmart demo dataset and its Ghost (ghost.build) database in
  this project. Use whenever the user asks about the data setup, the walmart_db
  database, the raw schema, how the CSVs were loaded, the connection method, or
  wants to run SQL / analytics against this data.
---

# Walmart demo dataset — setup & basics

Synthetic Walmart retail dataset loaded into a hosted Postgres/TimescaleDB
database on **Ghost** (`ghost.build`, the "agentic DB"). Timestamps in the data
sit in 2026; it is fake data generated for demos.

## Database

| | |
|---|---|
| Provider | Ghost (`ghost.build`) — Postgres 16 + TimescaleDB |
| Database name | `walmart_db` (run `ghost list` for the id) |
| Connection details | Get the full string (host, port, db, user, password) with `ghost connect walmart_db`. Port `5432`, `sslmode=require`. Not committed here. |
| Auth | Ghost CLI, GitHub OAuth (`ghost id` to check). Password lives in `~/.pgpass`. |
| Schema holding the data | `raw` (only user schema; `public` is empty) |

### Access

```bash
ghost list                              # show databases
ghost schema walmart_db                 # tables + columns
ghost sql walmart_db "SELECT 1"         # run a query (stdin or a file also work)
ghost connect walmart_db                # print connection string (has password)
ghost serve walmart_db                  # local web SQL UI
```

From Claude Code / VS Code the **`ghost` MCP server** is configured (user scope),
exposing `ghost_sql`, `ghost_schema`, `ghost_connect`, etc. Prefer those tools in
chat. `claude mcp list` shows its status.

## Tables (schema `raw`, ~52.8k rows total)

All tables share `created_timestamp`, `updated_timestamp` (timestamp) and
`is_active char(1)` = `'Y'`/`'N'`. No foreign keys are defined — only primary
keys. Relationships below are logical.

| Table | Rows | PK | Key columns |
|---|---:|---|---|
| `raw.customers` | 2,000 | `customer_id` | first_name, last_name, email, phone, city, province, country |
| `raw.stores` | 25 | `store_id` | store_name, city, province, country |
| `raw.products` | 500 | `product_id` | product_name, category, brand, price `numeric(10,2)` |
| `raw.employees` | 250 | `employee_id` | store_id→stores, first_name, last_name, email, job_title, salary `numeric(10,2)` |
| `raw.orders` | 10,000 | `order_id` | customer_id→customers, store_id→stores, order_timestamp, payment_method, order_status, total_amount `numeric(12,2)` |
| `raw.order_items` | 30,021 | `order_item_id` | order_id→orders, product_id→products, quantity `int`, unit_price `numeric(10,2)`, line_amount `numeric(12,2)` |

Logical model: `customers` 1—* `orders` *—1 `stores`; `orders` 1—* `order_items`
*—1 `products`; `employees` *—1 `stores`.

Domain notes:
- `orders.order_status`: Pending, Completed, Cancelled, Returned (~25% each).
- `orders.payment_method`: Credit Card, Cash, Gift Card, Online, Debit Card
  (~20% each).
- `products.category`: Clothing, Electronics, Grocery, Home, Sports, Toys.
- `country` is uniformly "Canada" in this synthetic data; `province` holds US
  state names — don't read too much into geography.
- `order_timestamp` can be later than `created_timestamp` (generator artifact).

## How it was built (reproduce / reset)

1. DDL: [walmart_dataset/ddl/walmart_schema.sql](../../../walmart_dataset/ddl/walmart_schema.sql)
   — unqualified `CREATE TABLE`s. They were created inside `raw` (schema created
   with `CREATE SCHEMA IF NOT EXISTS raw;`, tables prefixed `raw.`).
2. CSVs: [walmart_dataset/data/](../../../walmart_dataset/data/) — one file per
   table, header row, column order matches the tables.
3. Loader: [walmart_dataset/load_data.py](../../../walmart_dataset/load_data.py)
   — psycopg2, `TRUNCATE ... CASCADE` then `COPY ... FROM STDIN (FORMAT CSV,
   HEADER TRUE)`. Idempotent. Reads `DATABASE_URL` from the env (no secret in
   the file). Dependency `psycopg2-binary` is in `pyproject.toml`.

Run the loader:

```powershell
$env:DATABASE_URL = (ghost connect walmart_db)
uv run python walmart_dataset/load_data.py
```

## Handy queries

```sql
-- row counts
SELECT 'orders' t, count(*) FROM raw.orders
UNION ALL SELECT 'order_items', count(*) FROM raw.order_items;

-- revenue by store
SELECT s.store_name, round(sum(o.total_amount),2) AS revenue, count(*) AS orders
FROM raw.orders o JOIN raw.stores s USING (store_id)
WHERE o.order_status = 'Completed'
GROUP BY 1 ORDER BY revenue DESC;

-- top products by units sold
SELECT p.product_name, p.category, sum(oi.quantity) AS units
FROM raw.order_items oi JOIN raw.products p USING (product_id)
GROUP BY 1,2 ORDER BY units DESC LIMIT 10;
```

## Gotchas

- `psql` is **not** installed locally, so `ghost psql` won't work — use
  `ghost sql` or the Python/psycopg path.
- `.env` at the project root is where a `DATABASE_URL=` can go, but it holds the
  DB password — it is gitignored; keep it that way.
- Two unrelated tools were once both called `ghost`; the npm `ghost-cli`
  (blogging platform) was uninstalled. The one in use is `ghost.build`.
