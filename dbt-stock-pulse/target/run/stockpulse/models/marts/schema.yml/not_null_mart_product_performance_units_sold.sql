
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select units_sold
from "stockpulse"."analytics_marts"."mart_product_performance"
where units_sold is null



  
  
      
    ) dbt_internal_test