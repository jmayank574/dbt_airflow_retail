-- Sourced from silver_t.products_t directly (NOT obt_b): obt_b is driven
-- from orders, so a product with no sales yet would be silently dropped.
SELECT
    DISTINCT
    product_id,
    product_name,
    category,
    brand,
    price,
    created_timestamp   AS product_created_timestamp,
    updated_timestamp   AS product_updated_timestamp,
    is_active           AS product_is_active,
    processed_at        AS product_processed_at,
    CURRENT_TIMESTAMP() AS product_gold_processed_at
FROM
    {{ ref('products_t') }}
