import os

import psycopg2

# Connection string is read from the DATABASE_URL env var so no secret lives in
# this file. Get one with:  ghost connect walmart_db
conn_string = os.environ["DATABASE_URL"]

# CSV file -> target table. Parents first so a re-run with FKs stays valid.
csv_files = {
    "customers.csv": "raw.customers",
    "stores.csv": "raw.stores",
    "products.csv": "raw.products",
    "employees.csv": "raw.employees",
    "orders.csv": "raw.orders",
    "order_items.csv": "raw.order_items",
}

data_dir = os.path.join(os.path.dirname(__file__), "data")

conn = psycopg2.connect(conn_string)
try:
    with conn, conn.cursor() as cursor:
        for csv_file, table_name in csv_files.items():
            csv_path = os.path.join(data_dir, csv_file)
            if not os.path.exists(csv_path):
                print(f"skip  {csv_file}: file not found")
                continue

            print(f"load  {csv_file} -> {table_name} ...", end=" ", flush=True)
            cursor.execute(f"TRUNCATE {table_name} CASCADE")
            with open(csv_path, "r", encoding="utf-8") as f:
                cursor.copy_expert(
                    f"COPY {table_name} FROM STDIN WITH (FORMAT CSV, HEADER TRUE)", f
                )
            cursor.execute(f"SELECT count(*) FROM {table_name}")
            print(f"{cursor.fetchone()[0]} rows")

    print("\nDone.")
finally:
    conn.close()
