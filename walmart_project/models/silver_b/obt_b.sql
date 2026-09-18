{#-
    Metadata-driven One Big Table (OBT).

    To add / remove a source table in the OBT, edit ONLY the `sources` list below.
    The SELECT list and the JOIN chain are generated from it.

    - First entry  -> the driving table (goes in FROM), `join_on` must be none
    - Every other entry -> LEFT JOIN-ed using its `join_on` expression
    - `columns` -> raw SQL snippet, already aliased, NO trailing comma
-#}

{%- set sources = [
    {
        "relation": ref('orders_t'),
        "alias": "o",
        "join_on": none,
        "columns": """
            o.order_id,
            o.store_id,
            o.order_timestamp,
            o.payment_method,
            o.order_status,
            o.total_amount,
            o.created_timestamp AS order_created_timestamp,
            o.updated_timestamp AS order_updated_timestamp,
            o.is_active         AS order_is_active,
            o.processed_at      AS order_processed_at,
            current_timestamp()   AS obt_b_processed_at
        """
    },
    {
        "relation": ref('customers_t'),
        "alias": "c",
        "join_on": "o.customer_id = c.customer_id",
        "columns": """
            c.customer_id,
            c.first_name        AS customer_first_name,
            c.last_name         AS customer_last_name,
            c.email             AS customer_email,
            c.phone             AS customer_phone,
            c.city              AS customer_city,
            c.province          AS customer_province,
            c.country           AS customer_country,
            c.created_timestamp AS customer_created_timestamp,
            c.updated_timestamp AS customer_updated_timestamp,
            c.is_active         AS customer_is_active,
            c.processed_at      AS customer_processed_at
        """
    },
    {
        "relation": ref('order_items_t'),
        "alias": "oi",
        "join_on": "o.order_id = oi.order_id",
        "columns": """
            oi.order_item_id,
            oi.quantity,
            oi.unit_price,
            oi.line_amount,
            oi.created_timestamp AS order_item_created_timestamp,
            oi.updated_timestamp AS order_item_updated_timestamp,
            oi.is_active         AS order_item_is_active,
            oi.processed_at      AS order_item_processed_at
        """
    },
    {
        "relation": ref('products_t'),
        "alias": "p",
        "join_on": "oi.product_id = p.product_id",
        "columns": """
            p.product_id,
            p.product_name,
            p.category,
            p.brand,
            p.price,
            p.created_timestamp AS product_created_timestamp,
            p.updated_timestamp AS product_updated_timestamp,
            p.is_active         AS product_is_active,
            p.processed_at      AS product_processed_at
        """
    },
    {
        "relation": ref('stores_t'),
        "alias": "s",
        "join_on": "o.store_id = s.store_id",
        "columns": """
            s.store_name,
            s.city              AS store_city,
            s.province          AS store_province,
            s.country           AS store_country,
            s.created_timestamp AS store_created_timestamp,
            s.updated_timestamp AS store_updated_timestamp,
            s.is_active         AS store_is_active,
            s.processed_at      AS store_processed_at
        """
    }
] -%}
{#-
    NOTE: employees_t is intentionally NOT joined here.
    There is no order -> employee relationship in the source data; joining on
    store_id would fan every order line out by the store's employee count and
    inflate every measure. dim_employees is built from silver_t.employees_t.
-#}

SELECT
{%- for src in sources %}
    -- {{ src.relation.identifier }} ({{ src.alias }})
    {{ src.columns | trim }}{{ "," if not loop.last else "" }}
{%- endfor %}

{% for src in sources -%}
    {%- if loop.first %}
FROM {{ src.relation }} {{ src.alias }}
    {%- else %}
LEFT JOIN {{ src.relation }} {{ src.alias }}
    ON {{ src.join_on }}
    {%- endif %}
{% endfor -%}
