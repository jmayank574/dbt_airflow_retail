{#-
    Fact table for sales analytics.

    Grain: one row per order line (order_item_id) - same grain as obt_b.
    Foreign keys reference the business keys tracked by the SCD2 dim_*
    snapshots (dim_orders, dim_customers, dim_products, dim_stores); no
    dim_employees FK exists here (see obt_b for why employees aren't joined).
-#}

SELECT
    -- grain
    order_item_id,

    -- foreign keys
    order_id,
    customer_id,
    product_id,
    store_id,

    -- degenerate dimensions
    order_timestamp,
    payment_method,
    order_status,

    -- measures
    -- total_amount deliberately excluded: it's an order-level total that
    -- repeats on every line of the order, so SUM(total_amount) here would
    -- overcount any order with more than one line. Use SUM(line_amount)
    -- grouped by order_id instead.
    quantity,
    unit_price,
    line_amount,

    CURRENT_TIMESTAMP() AS fact_orders_processed_at
FROM
    {{ ref('obt_b') }}
