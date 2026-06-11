-- ============================================================================
-- Beezap analytics — contact_results (latest "Final" report per contact)
-- Source: tenant_*.contact_results (unified topic cdc.contact_results)
-- ============================================================================
-- `results` holds the structured outcome/report payload as JSON text and is
-- kept as-is (String) so Superset/ClickHouse JSON functions (JSONExtract*)
-- can be used to slice by whatever fields the report form defines.

CREATE TABLE beezap.contact_results_queue
(
    id          String,
    contact_id  String,
    results     String,
    created_by  String,
    updated_by  Nullable(String),
    created_at  String,   -- stored as VARCHAR in Postgres
    updated_at  String,   -- stored as VARCHAR in Postgres

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.contact_results',
    kafka_group_name = 'clickhouse_beezap_contact_results',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

CREATE TABLE beezap.contact_results
(
    tenant_id   UUID,
    id          UUID,
    contact_id  UUID,
    results     String,
    created_by  String,
    updated_by  Nullable(String),
    created_at  DateTime64(3),
    updated_at  DateTime64(3),

    is_deleted  UInt8,
    _version    UInt64
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY (tenant_id, contact_id, id);

CREATE MATERIALIZED VIEW beezap.contact_results_mv TO beezap.contact_results AS
SELECT
    beezap_tenant_id(__source_schema)                  AS tenant_id,
    toUUID(id)                                         AS id,
    toUUID(contact_id)                                 AS contact_id,
    results,
    created_by,
    updated_by,
    beezap_parse_datetime(created_at, __source_ts_ms)  AS created_at,
    beezap_parse_datetime(updated_at, __source_ts_ms)  AS updated_at,
    (__deleted = 'true')                               AS is_deleted,
    __source_ts_ms                                     AS _version
FROM beezap.contact_results_queue;
