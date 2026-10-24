select
    id as product_id,
    sku,
    name as product_name,
    category,
    active as is_active,
    created_at as product_created_at,
    updated_at as product_updated_at
from {{ source('stockpulse_app', 'ingestion_product') }}
