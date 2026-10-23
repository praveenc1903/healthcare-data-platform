-- stg_openfda_event_reactions
-- Grain: one row per reaction per openFDA adverse event report.
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
    d.raw:safetyreportid::string          as report_id,             -- parent report ID (links back to stg_openfda_adverse_events)
    f.index                               as reaction_seq,          -- position of the reaction in the report's list (0, 1, 2...)
    f.value:reactionmeddrapt::string      as reaction_term,         -- reaction in MedDRA terminology, e.g. 'Headache'
    f.value:reactionoutcome::int          as reaction_outcome_code  -- 1 recovered, 2 recovering, 3 not recovered,
                                                                    -- 4 recovered with sequelae, 5 fatal, 6 unknown
from deduped d,
-- Explode the reaction array: one output row per reaction, still linked to its parent report d.
-- Reports with no reaction list produce no rows.
lateral flatten(input => d.raw:patient:reaction) f