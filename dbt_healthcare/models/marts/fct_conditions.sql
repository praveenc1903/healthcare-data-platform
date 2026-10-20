with conditions as (
    select * from {{ ref('stg_conditions') }}
),

patients as (
    select patient_id from {{ ref('dim_patients') }}
)

select
    c.patient_id,
    c.encounter_id,
    c.condition_start,
    c.condition_stop,
    c.condition_code,
    c.condition_description,
    datediff('day', c.condition_start, coalesce(c.condition_stop, current_date())) as condition_duration_days
from conditions c
inner join patients p on c.patient_id = p.patient_id