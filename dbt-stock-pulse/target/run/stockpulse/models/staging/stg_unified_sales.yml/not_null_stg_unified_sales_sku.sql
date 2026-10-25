
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sku
from "stockpulse"."analytics_staging"."stg_unified_sales"
where sku is null



  
  
      
    ) dbt_internal_test