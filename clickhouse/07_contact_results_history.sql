-- ============================================================================
-- Beezap analytics — contact_results_history (append-only submission history)
-- Source: tenant_*.contact_results_history (unified topic cdc.contact_results_history)
-- ============================================================================
-- One row per save/submit event. ReplacingMergeTree (keyed on id, versioned
-- by _version) is used even though the source table is append-only, purely
-- to dedupe in case Kafka redelivers a message (at-least-once delivery) —
-- it keeps the same pattern/views uniform across all entities.

CREATE TABLE beezap.contact_results_history_queue
(
    id          String,
    contact_id  String,
    results     String,
    saved_by    String,
    created_at  String,   -- stored as VARCHAR in Postgres

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.contact_results_history',
    kafka_group_name = 'clickhouse_beezap_contact_results_history',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

CREATE TABLE beezap.contact_results_history
(
    tenant_id   UUID,
    id          UUID,
    contact_id  UUID,
    results     String,
    saved_by    String,
    created_at  DateTime64(3),

    is_deleted  UInt8,
    _version    UInt64
)
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(created_at)
ORDER BY (tenant_id, contact_id, created_at, id);

CREATE MATERIALIZED VIEW beezap.contact_results_history_mv TO beezap.contact_results_history AS
SELECT
    beezap_tenant_id(__source_schema)                  AS tenant_id,
    toUUID(id)                                         AS id,
    toUUID(contact_id)                                 AS contact_id,
    results,
    saved_by,
    beezap_parse_datetime(created_at, __source_ts_ms)  AS created_at,
    (__deleted = 'true')                               AS is_deleted,
    __source_ts_ms                                     AS _version
FROM beezap.contact_results_history_queue;
