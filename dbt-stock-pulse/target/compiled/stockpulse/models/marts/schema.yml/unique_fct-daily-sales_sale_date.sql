
    
    

select
    sale_date as unique_field,
    count(*) as n_records

from "stockpulse"."analytics_marts"."fct-daily-sales"
where sale_date is not null
group by sale_date
having count(*) > 1


