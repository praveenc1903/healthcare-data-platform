with source as ( select * from {{source('raw', 'procedures')}})

select
    "PATIENT" as patient_id,
    "ENCOUNTER" as encounter_id,
    "START" as procedure_start,
    "STOP" as procedure_stop,
    "CODE" as procedure_code,
    "DESCRIPTION" as procedure_description,
    "BASE_COST" as base_cost
from source