
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select source_system
from "stockpulse"."analytics_staging"."stg_unified_sales"
where source_system is null



  
  
      
    ) dbt_internal_test