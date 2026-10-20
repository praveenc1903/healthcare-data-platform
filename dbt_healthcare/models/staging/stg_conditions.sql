with source as (
    select * from {{ source('raw', 'conditions') }}
)

select
    "PATIENT" as patient_id,
    "ENCOUNTER" as encounter_id,
    "START" as condition_start,
    "STOP" as condition_stop,
    "CODE" as condition_code,
    "DESCRIPTION" as condition_description
from source