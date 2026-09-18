-- Sourced from silver_t.customers_t directly (NOT obt_b): obt_b is driven
-- from orders, so a customer with no orders yet would be silently dropped.
SELECT
    DISTINCT
    customer_id,
    first_name          AS customer_first_name,
    last_name           AS customer_last_name,
    email               AS customer_email,
    phone               AS customer_phone,
    city                AS customer_city,
    province            AS customer_province,
    country             AS customer_country,
    created_timestamp   AS customer_created_timestamp,
    updated_timestamp   AS customer_updated_timestamp,
    is_active           AS customer_is_active,
    processed_at        AS customer_processed_at,
    CURRENT_TIMESTAMP() AS customer_gold_processed_at
FROM
    {{ ref('customers_t') }}
