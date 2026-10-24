
  create view "stockpulse"."analytics_staging"."stg_products__dbt_tmp"
    
    
  as (
    select
    id as product_id,
    sku,
    name as product_name,
    category,
    active as is_active,
    created_at as product_created_at,
    updated_at as product_updated_at
from "stockpulse"."public"."ingestion_product"
  );