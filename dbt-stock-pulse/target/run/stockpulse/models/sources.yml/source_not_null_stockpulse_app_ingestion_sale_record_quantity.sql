
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select quantity
from "stockpulse"."public"."ingestion_sale_record"
where quantity is null



  
  
      
    ) dbt_internal_test