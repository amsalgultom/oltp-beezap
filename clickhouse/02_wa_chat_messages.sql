-- ============================================================================
-- Beezap analytics â€” wa_chat_messages (the core message-delivery fact table)
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
-- column.exclude.list â€” see kafka-connect/connectors/beezap-postgres-cdc.json):
--   content, media_url, media_filename, meta_data, error_message,
--   template_parameters, attachment, link_file, bot_response
-- These are message bodies / raw media / free-text error data â€” large,
-- potentially sensitive, and not needed for delivery-funnel / campaign /
-- agent analytics. If you need them later, add the columns back to
-- table.include.list exclusions AND to the queue/target tables + MV below.

-- ----------------------------------------------------------------------------
-- Raw Kafka ingestion table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS beezap.wa_chat_messages_queue
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
CREATE TABLE IF NOT EXISTS beezap.wa_chat_messages
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
-- Materialized view: queue -> target (with tenant join)
-- Joins with beezap.tenants to recover the tenant UUID from slug.
-- If a slug doesn't exist in tenants (shouldn't happen), uses all-zero UUID
-- as a fallback for data integrity.
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS beezap.wa_chat_messages_mv TO beezap.wa_chat_messages AS
SELECT
    coalesce(t.id, toUUID('00000000-0000-0000-0000-000000000000'))  AS tenant_id,
    toUUID(q.id)                                       AS id,
    toUUID(q.contact_id)                               AS contact_id,
    q.message_id,
    q.type,
    q.sender,
    q.status,
    q.media_type,
    q.sent_by,
    q.bot_id,
    q."timestamp"                                      AS raw_timestamp,
    beezap_parse_datetime(q.created_at, q.__source_ts_ms)  AS created_at,
    beezap_parse_datetime(q.updated_at, q.__source_ts_ms)  AS updated_at,
    q.category_message,
    q.template_name,
    q.template_language,
    q.agent,
    beezap_parse_datetime_or_null(q.delivered_at)      AS delivered_at,
    beezap_parse_datetime_or_null(q.read_at)           AS read_at,
    beezap_parse_datetime_or_null(q.failed_at)         AS failed_at,
    toUUIDOrNull(q.campaign_id)                        AS campaign_id,
    q.participant_phone,
    q.participant_name,
    q.reply_to_message_id,
    (q.__deleted = 'true')                             AS is_deleted,
    q.__source_ts_ms                                   AS _version
FROM beezap.wa_chat_messages_queue q
LEFT JOIN beezap.tenants t ON t.slug = beezap_tenant_id(q.__source_schema);

