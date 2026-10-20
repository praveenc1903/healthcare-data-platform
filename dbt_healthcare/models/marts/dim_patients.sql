with patients as (select * from {{ ref('stg_patients') }})
select
    patient_id, gender, race, ethnicity, marital,
    age, birth_year, is_deceased,
    city, state, county, income
from patients