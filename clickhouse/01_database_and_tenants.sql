-- ============================================================================
-- Beezap analytics — database + tenants dimension
-- Source: public.tenants (topic cdc.tenants)
-- ============================================================================
-- This is the dimension table used to enrich every per-tenant fact table
-- (join on tenant_id). Sensitive/encrypted columns (wa_number, waba_id,
-- email_wa, password_wa) are excluded at the Debezium connector level
-- (column.exclude.list) and never reach Kafka/ClickHouse.

CREATE DATABASE IF NOT EXISTS beezap;

-- ----------------------------------------------------------------------------
-- Raw Kafka ingestion table
-- ----------------------------------------------------------------------------
CREATE TABLE beezap.tenants_queue
(
    id          String,
    name        String,
    slug        String,
    url_wa_api  String,
    is_active   UInt8,
    settings    String,            -- JSONB column, arrives as a JSON-text string
    created_at  Nullable(String),
    updated_at  Nullable(String),

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.tenants',
    kafka_group_name = 'clickhouse_beezap_tenants',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

-- ----------------------------------------------------------------------------
-- Deduplicated target table (latest version per tenant)
-- ----------------------------------------------------------------------------
CREATE TABLE beezap.tenants
(
    id          UUID,
    name        String,
    slug        String,
    url_wa_api  String,
    is_active   UInt8,
    settings    String,
    created_at  DateTime64(3),
    updated_at  DateTime64(3),

    is_deleted  UInt8,
    _version    UInt64
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY (id);

-- ----------------------------------------------------------------------------
-- Materialized view: queue -> target
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW beezap.tenants_mv TO beezap.tenants AS
SELECT
    toUUID(id)                                       AS id,
    name,
    slug,
    url_wa_api,
    is_active,
    settings,
    beezap_parse_datetime(created_at, __source_ts_ms) AS created_at,
    beezap_parse_datetime(updated_at, __source_ts_ms) AS updated_at,
    (__deleted = 'true')                              AS is_deleted,
    __source_ts_ms                                    AS _version
FROM beezap.tenants_queue;
