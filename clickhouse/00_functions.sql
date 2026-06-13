-- ============================================================================
-- Beezap analytics — shared helper functions
-- ============================================================================
-- Used by every entity's materialized view (0X_*.sql files). Defining these
-- once avoids repeating the same parsing logic 7 times.
-- ============================================================================

-- Extract the tenant slug from a Debezium __source_schema value of the form
-- "tenant_<slug>" (e.g. "tenant_mtf" -> "mtf").
--
-- Used in materialized views to join with beezap.tenants table and recover
-- the tenant UUID. This avoids assuming a specific UUID format in the
-- schema name.
CREATE FUNCTION IF NOT EXISTS beezap_tenant_id AS (source_schema) ->
    substring(source_schema, 8);


-- Parse a "should be a timestamp but is stored as VARCHAR" Postgres column
-- (see database/tenant/SCHEMA_REFERENCE.sql notes on wa_chat_messages /
-- contact_results / contact_results_history) into a non-nullable
-- DateTime64(3), with graceful fallbacks:
--   1. epoch seconds as a 9-10 digit numeric string
--   2. epoch milliseconds as a 12-13 digit numeric string
--   3. any format parseDateTime64BestEffortOrZero can handle (ISO-8601 etc.)
--   4. otherwise fall back to the Debezium event time (__source_ts_ms), so a
--      row is never lost / never gets a zero-date just because of a bad
--      string.
--
-- BEST EFFORT: after the initial snapshot lands, spot-check rows where the
-- parsed value looks suspicious (e.g. compare against _version /
-- __source_ts_ms) and extend this function if real data uses a format not
-- covered above.
CREATE FUNCTION IF NOT EXISTS beezap_parse_datetime AS (s, fallback_ms) ->
    multiIf(
        match(ifNull(s, ''), '^[0-9]{9,10}$'), fromUnixTimestamp64Milli(toInt64(s) * 1000),
        match(ifNull(s, ''), '^[0-9]{12,13}$'), fromUnixTimestamp64Milli(toInt64(s)),
        parseDateTime64BestEffortOrZero(ifNull(s, ''), 3) != toDateTime64(0, 3),
            parseDateTime64BestEffortOrZero(s, 3),
        fromUnixTimestamp64Milli(fallback_ms)
    );


-- Same heuristics as beezap_parse_datetime, but for genuinely OPTIONAL
-- timestamp columns (e.g. delivered_at / read_at / failed_at) where an empty
-- value means "hasn't happened yet" and must stay NULL rather than falling
-- back to the event time.
CREATE FUNCTION IF NOT EXISTS beezap_parse_datetime_or_null AS (s) ->
    if(ifNull(s, '') = '', NULL,
        multiIf(
            match(s, '^[0-9]{9,10}$'), fromUnixTimestamp64Milli(toInt64(s) * 1000),
            match(s, '^[0-9]{12,13}$'), fromUnixTimestamp64Milli(toInt64(s)),
            parseDateTime64BestEffortOrZero(s, 3) != toDateTime64(0, 3),
                parseDateTime64BestEffortOrZero(s, 3),
            NULL
        )
    );
