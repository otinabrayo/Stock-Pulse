
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select revenue
from "stockpulse"."analytics_marts"."mart_product_performance"
where revenue is null



  
  
      
    ) dbt_internal_test