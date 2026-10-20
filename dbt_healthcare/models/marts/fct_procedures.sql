with procedures as (
    select * from {{ ref('stg_procedures') }}
),

patients as (
    select patient_id from {{ ref('dim_patients') }}
)

select
    pc.patient_id,
    pc.encounter_id,
    pc.procedure_start,
    pc.procedure_stop,
    pc.procedure_code,
    pc.procedure_description,
    pc.base_cost
from procedures pc
inner join patients p on pc.patient_id = p.patient_id