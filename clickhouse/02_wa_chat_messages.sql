-- ============================================================================
-- Beezap analytics — wa_chat_messages (the core message-delivery fact table)
-- Source: tenant_*.wa_chat_messages (unified topic cdc.wa_chat_messages)
-- ============================================================================
-- This file is the fully worked-out example of the per-entity pattern used
-- by every other 0X_*.sql file in this directory:
--
--   <entity>_queue  (Kafka engine, raw JSON)
--          |
--          v  materialized view (type casts, tenant_id derivation,
--          |   timestamp parsing, soft-delete flag, version)
--          v
--   <entity>        (ReplacingMergeTree, deduplicated "current state")
--
-- Columns intentionally NOT replicated (excluded via the Debezium connector's
-- column.exclude.list — see kafka-connect/connectors/beezap-postgres-cdc.json):
--   content, media_url, media_filename, meta_data, error_message,
--   template_parameters, attachment, link_file, bot_response
-- These are message bodies / raw media / free-text error data — large,
-- potentially sensitive, and not needed for delivery-funnel / campaign /
-- agent analytics. If you need them later, add the columns back to
-- table.include.list exclusions AND to the queue/target tables + MV below.

-- ----------------------------------------------------------------------------
-- Raw Kafka ingestion table
-- ----------------------------------------------------------------------------
CREATE TABLE beezap.wa_chat_messages_queue
(
    id                  String,
    contact_id          String,
    message_id          Nullable(String),
    type                String,
    sender              String,             -- enum: user | contact
    status              String,             -- enum: sent | delivered | read | failed
    media_type          Nullable(String),
    sent_by             Nullable(String),   -- agent username who sent the message
    bot_id              Nullable(Int32),
    "timestamp"         Nullable(String),
    created_at          Nullable(String),   -- stored as VARCHAR in Postgres
    updated_at          Nullable(String),   -- stored as VARCHAR in Postgres
    category_message    String,             -- enum: private | template
    template_name       Nullable(String),
    template_language   Nullable(String),
    agent               Nullable(String),
    delivered_at        Nullable(String),   -- stored as VARCHAR in Postgres
    read_at             Nullable(String),   -- stored as VARCHAR in Postgres
    failed_at           Nullable(String),   -- stored as VARCHAR in Postgres
    campaign_id         Nullable(String),
    participant_phone   Nullable(String),
    participant_name    Nullable(String),
    reply_to_message_id Nullable(String),

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.wa_chat_messages',
    kafka_group_name = 'clickhouse_beezap_wa_chat_messages',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

-- ----------------------------------------------------------------------------
-- Deduplicated target table (latest version per message)
-- ----------------------------------------------------------------------------
CREATE TABLE beezap.wa_chat_messages
(
    tenant_id           UUID,
    id                  UUID,
    contact_id          UUID,
    message_id          Nullable(String),
    type                LowCardinality(String),
    sender              LowCardinality(String),
    status              LowCardinality(String),
    media_type          LowCardinality(Nullable(String)),
    sent_by             Nullable(String),
    bot_id              Nullable(Int32),
    raw_timestamp       Nullable(String),
    created_at          DateTime64(3),
    updated_at          DateTime64(3),
    category_message    LowCardinality(String),
    template_name       Nullable(String),
    template_language   Nullable(String),
    agent               Nullable(String),
    delivered_at        Nullable(DateTime64(3)),
    read_at             Nullable(DateTime64(3)),
    failed_at           Nullable(DateTime64(3)),
    campaign_id         Nullable(UUID),
    participant_phone   Nullable(String),
    participant_name    Nullable(String),
    reply_to_message_id Nullable(String),

    is_deleted          UInt8,
    _version            UInt64
)
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(created_at)
ORDER BY (tenant_id, created_at, id);

-- ----------------------------------------------------------------------------
-- Materialized view: queue -> target
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW beezap.wa_chat_messages_mv TO beezap.wa_chat_messages AS
SELECT
    beezap_tenant_id(__source_schema)                  AS tenant_id,
    toUUID(id)                                         AS id,
    toUUID(contact_id)                                 AS contact_id,
    message_id,
    type,
    sender,
    status,
    media_type,
    sent_by,
    bot_id,
    "timestamp"                                        AS raw_timestamp,
    beezap_parse_datetime(created_at, __source_ts_ms)  AS created_at,
    beezap_parse_datetime(updated_at, __source_ts_ms)  AS updated_at,
    category_message,
    template_name,
    template_language,
    agent,
    beezap_parse_datetime_or_null(delivered_at)        AS delivered_at,
    beezap_parse_datetime_or_null(read_at)             AS read_at,
    beezap_parse_datetime_or_null(failed_at)           AS failed_at,
    toUUIDOrNull(campaign_id)                          AS campaign_id,
    participant_phone,
    participant_name,
    reply_to_message_id,
    (__deleted = 'true')                               AS is_deleted,
    __source_ts_ms                                     AS _version
FROM beezap.wa_chat_messages_queue;
