
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sold_at
from "stockpulse"."analytics_staging"."stg_unified_sales"
where sold_at is null



  
  
      
    ) dbt_internal_test