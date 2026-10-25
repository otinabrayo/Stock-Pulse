WITH django_sales AS (
    SELECT
        id::text AS record_id,
        transaction_id,
        sku,
        product_id,
        sold_at,
        quantity,
        unit_price,
        unit_cost,
        source_run_id,
        created_at AS record_created_at,
        'django_csv' AS source_system,
        1 AS source_priority
    FROM {{ source('stockpulse_app', 'ingestion_salerecord') }}
),

kafka_sales AS (
    SELECT
        event_id::text AS record_id,
        transaction_id,
        sku,
        NULL::bigint AS product_id,
        sold_at,
        quantity,
        unit_price,
        unit_cost,
        NULL::uuid AS source_run_id,
        ingested_at AS record_created_at,
        'kafka' AS source_system,
        2 AS source_priority
    FROM {{ source('stockpulse_app', 'kafka_sales_events') }}
),

combined_sales AS (
    SELECT * FROM django_sales
    UNION ALL
    SELECT * FROM kafka_sales
),

ranked_sales AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id, sku
            ORDER BY source_priority, record_created_at, record_id
        ) AS business_key_rank
    FROM combined_sales
)

SELECT
    record_id,
    transaction_id,
    sku,
    product_id,
    sold_at,
    quantity,
    unit_price,
    unit_cost,
    source_run_id,
    record_created_at,
    source_system
FROM ranked_sales
WHERE business_key_rank = 1
