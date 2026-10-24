
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sku
from "stockpulse"."public"."ingestion_sale_record"
where sku is null



  
  
      
    ) dbt_internal_test