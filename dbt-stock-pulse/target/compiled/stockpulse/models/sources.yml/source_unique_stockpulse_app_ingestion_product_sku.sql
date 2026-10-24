
    
    

select
    sku as unique_field,
    count(*) as n_records

from "stockpulse"."public"."ingestion_product"
where sku is not null
group by sku
having count(*) > 1


