-- stg_openfda_event_drugs
-- Grain: one row per drug per openFDA adverse event report.
-- Source: healthcare.raw.openfda_drug_events (one JSON report per row).

with source as (
    -- Bronze table: raw JSON reports loaded from S3 via COPY INTO
    select * from {{ source('raw', 'openfda_drug_events') }}
),

deduped as (
    -- Daily API pulls overlap, so the same report can appear in several files.
    -- Keep only the most recently loaded copy of each report.
    select *
    from source
    qualify row_number() over (
        partition by raw:safetyreportid::string   -- group copies of the same report
        order by loaded_at desc                   -- newest load first
    ) = 1                                         -- keep the newest copy only
)

select
    d.raw:safetyreportid::string              as report_id,         -- parent report ID (links back to stg_openfda_adverse_events)
    f.index                                   as drug_seq,          -- position of the drug in the report's list (0, 1, 2...)
    f.value:medicinalproduct::string          as medicinal_product, -- drug name as reported (often a brand name)
    f.value:openfda:generic_name[0]::string   as generic_name,      -- first generic name; null if openFDA couldn't map the drug
    f.value:drugcharacterization::int         as drug_role_code,    -- 1 = suspect, 2 = concomitant, 3 = interacting
    f.value:openfda:rxcui                     as rxcui_list         -- RxNorm codes (array); used to match Synthea medication_code
from deduped d,
-- Explode the drug array: one output row per drug, still linked to its parent report d.
-- Reports with no drug list produce no rows.
lateral flatten(input => d.raw:patient:drug) f