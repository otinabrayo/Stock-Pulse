
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select gross_profit
from "stockpulse"."analytics_marts"."fct_daily_sales"
where gross_profit is null



  
  
      
    ) dbt_internal_test