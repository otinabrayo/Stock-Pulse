
  create view "stockpulse"."analytics_staging"."stg-sales__dbt_tmp"
    
    
  as (
    select
    id as sale_record_id,
    transaction_id,
    sku,
    product_id,
    sold_at,
    quantity,
    unit_price,
    unit_cost,
    source_run_id,
    created_at as record_created_at
from "stockpulse"."public"."ingestion_salerecord"
  );