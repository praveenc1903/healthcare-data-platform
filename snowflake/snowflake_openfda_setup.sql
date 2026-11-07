-- =====================================================================
-- openFDA ingestion: Snowflake setup and operations
-- Project: healthcare-data-platform
--
-- Flow:  Lambda -> S3 (openfda/) -> Snowpipe -> healthcare.raw.openfda_drug_events
--
-- Run sections 1-6 once, in order, to set everything up.
-- Sections 7-9 are day-to-day checks and operations.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Session context
--    Everything below lands in healthcare.raw (bronze).
--    accountadmin owns the storage integration.
-- ---------------------------------------------------------------------
use role accountadmin;
use warehouse healthcare_wh;
use database healthcare;
use schema raw;


-- ---------------------------------------------------------------------
-- 1. Storage integration (one-time)
--    Lets Snowflake read S3 by assuming an IAM role in our AWS account.
--    No AWS keys are stored in Snowflake.
--
--    WARNING: never use CREATE OR REPLACE on this. Recreating it generates
--    a new external ID and breaks the trust policy in Terraform.
-- ---------------------------------------------------------------------
create storage integration if not exists s3_openfda_int
  type = external_stage
  storage_provider = 'S3'
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::755922498863:role/healthcare-data-platform-snowflake-s3'
  storage_allowed_locations = ('s3://healthcare-data-platform-raw-755922498863/openfda/');

-- Copy STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID from this output
-- into terraform/terraform.tfvars, then run terraform apply.
desc integration s3_openfda_int;


-- ---------------------------------------------------------------------
-- 2. File format
--    NDJSON: one JSON report per line, so each line becomes one row.
-- ---------------------------------------------------------------------
create file format if not exists ndjson_format
  type = json;


-- ---------------------------------------------------------------------
-- 3. External stage
--    A named pointer to the S3 folder, authenticated via the integration.
--    Stores no data itself.
-- ---------------------------------------------------------------------
create stage if not exists openfda_stage
  url = 's3://healthcare-data-platform-raw-755922498863/openfda/'
  storage_integration = s3_openfda_int
  file_format = ndjson_format;

-- Connection test: should list the files in S3.
-- "Access denied" = trust policy not applied yet (wait ~1 min and retry).
list @openfda_stage;


-- ---------------------------------------------------------------------
-- 4. Bronze table
--    raw         : the whole JSON report, untouched (VARIANT)
--    source_file : which S3 file the row came from (lineage)
--    loaded_at   : when the row arrived (filled automatically)
-- ---------------------------------------------------------------------
create table if not exists openfda_drug_events (
    raw         variant,
    source_file string,
    loaded_at   timestamp_ntz default current_timestamp()
);


-- ---------------------------------------------------------------------
-- 5. Initial manual load (one-time)
--    Loads every file already in S3. COPY remembers loaded files for
--    64 days, so rerunning it skips files it has already loaded.
-- ---------------------------------------------------------------------
copy into openfda_drug_events (raw, source_file)
from (select $1, metadata$filename from @openfda_stage);


-- ---------------------------------------------------------------------
-- 6. Snowpipe (one-time)
--    The same COPY as above, run automatically whenever S3 sends a
--    "new file" notification. auto_ingest = true makes it listen.
-- ---------------------------------------------------------------------
create pipe if not exists openfda_pipe
  auto_ingest = true
  as
  copy into openfda_drug_events (raw, source_file)
  from (select $1, metadata$filename from @openfda_stage);

-- Copy notification_channel (the SQS ARN) into terraform/terraform.tfvars
-- as snowpipe_sqs_arn, then terraform apply to create the S3 notification.
show pipes like 'openfda_pipe';


-- =====================================================================
-- DAY-TO-DAY CHECKS AND OPERATIONS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7. Is the pipe working?
--    executionState should be RUNNING and pendingFileCount 0.
-- ---------------------------------------------------------------------
select system$pipe_status('healthcare.raw.openfda_pipe');

-- Latest loads first. A new file each day (06:00 UTC) = pipeline healthy.
-- Note: loaded_at is in Snowflake's session timezone (default US Pacific),
-- while S3 file names use UTC.
select
    source_file,
    count(*)       as rows_loaded,
    max(loaded_at) as loaded_at
from openfda_drug_events
group by 1
order by 3 desc;

-- Totals: expect 100 rows per file.
select count(distinct source_file) as files, count(*) as rows_total
from openfda_drug_events;


-- ---------------------------------------------------------------------
-- 8. Backfill a missed file
--    Snowpipe only reacts to files created AFTER the S3 notification
--    exists. Load anything older by naming the file explicitly.
--    Path is relative to the stage URL (starts at drug_event/).
--
--    Do NOT use ALTER PIPE ... REFRESH here: the pipe keeps its own load
--    history, separate from manual COPY, so it would reload files that
--    the manual COPY already loaded.
-- ---------------------------------------------------------------------
copy into openfda_drug_events (raw, source_file)
from (select $1, metadata$filename from @openfda_stage)
files = ('drug_event/ingest_date=2026-10-23/events_004022.json');


-- ---------------------------------------------------------------------
-- 9. Pause and resume the pipe
--    While paused, S3 notifications queue up and are processed on resume,
--    as long as the pause lasts under 14 days.
--    An idle pipe costs nothing, so pausing is rarely needed for cost.
--
--    To stop the whole pipeline instead, disable the daily trigger in AWS:
--      aws events disable-rule --name healthcare-data-platform-daily-ingest --region eu-west-2
-- ---------------------------------------------------------------------

-- Pause
alter pipe healthcare.raw.openfda_pipe set pipe_execution_paused = true;
select system$pipe_status('healthcare.raw.openfda_pipe');   -- executionState: PAUSED

-- Resume
alter pipe healthcare.raw.openfda_pipe set pipe_execution_paused = false;
select system$pipe_status('healthcare.raw.openfda_pipe');   -- executionState: RUNNING


-- ---------------------------------------------------------------------
-- 10. Preview the raw JSON (useful when writing dbt models)
--     :   walks into the JSON      [0]  first item of a list
--     ::string casts to plain text (no quotes)
-- ---------------------------------------------------------------------
select
    raw:safetyreportid::string                    as report_id,
    raw:receivedate::string                       as received_date,
    raw:patient:drug[0]:medicinalproduct::string  as first_drug,
    source_file
from openfda_drug_events
limit 10;
