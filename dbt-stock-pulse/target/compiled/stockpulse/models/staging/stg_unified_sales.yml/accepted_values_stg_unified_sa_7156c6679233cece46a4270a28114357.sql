
    
    

with all_values as (

    select
        source_system as value_field,
        count(*) as n_records

    from "stockpulse"."analytics_staging"."stg_unified_sales"
    group by source_system

)

select *
from all_values
where value_field not in (
    'django_csv','kafka'
)


