with medications as (
    select * from {{ ref('stg_medications') }}
),

patients as (
    select patient_id from {{ ref('dim_patients') }}
)

select
    m.patient_id,
    m.encounter_id,
    m.medication_start,
    m.medication_stop,
    m.medication_code,
    m.medication_description,
    m.base_cost,
    m.total_cost
from medications m
inner join patients p on m.patient_id = p.patient_id