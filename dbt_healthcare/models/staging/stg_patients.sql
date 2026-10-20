with source as (
    select * from {{ source('raw', 'patients') }}
)

select
    "Id" as patient_id,
    gender,
    race,
    ethnicity,
    marital,
    datediff('year', birthdate, coalesce(deathdate, current_date())) as age,
    year(birthdate) as birth_year,
    case when deathdate is not null then true else false end as is_deceased,
    city,
    state,
    county,
    healthcare_expenses,
    healthcare_coverage,
    income
from source