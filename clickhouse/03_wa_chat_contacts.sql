-- ============================================================================
-- Beezap analytics — wa_chat_contacts (conversation/contact state)
-- Source: tenant_*.wa_chat_contacts (unified topic cdc.wa_chat_contacts)
-- ============================================================================
-- Same pattern as 02_wa_chat_messages.sql. Columns intentionally NOT
-- replicated (excluded via column.exclude.list): meta_data, last_message
-- (free-text message content).

CREATE TABLE beezap.wa_chat_contacts_queue
(
    id                  String,
    phone               String,
    masking_number      String,
    name                String,
    agent               Nullable(String),
    current_bot_id      Nullable(Int32),
    previous_bot_id     Nullable(Int32),
    last_message_time   Nullable(String),
    unread_count        Int32,
    status              String,   -- enum: open | close
    response_message    String,   -- enum: Y | N | X
    handle_by           String,   -- enum: agent | bot
    unique_blast        Nullable(String),
    is_blocked          UInt8,
    created_at          Nullable(String),
    updated_at          Nullable(String),
    service_type        String,   -- enum: official | unofficial
    campaign_id         Nullable(String),
    campaign_name       Nullable(String),
    is_group            UInt8,
    group_jid           Nullable(String),
    is_unsaved          UInt8,
    delivery_status     Nullable(String),

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.wa_chat_contacts',
    kafka_group_name = 'clickhouse_beezap_wa_chat_contacts',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

CREATE TABLE beezap.wa_chat_contacts
(
    tenant_id           UUID,
    id                  UUID,
    phone               String,
    masking_number      String,
    name                String,
    agent               Nullable(String),
    current_bot_id      Nullable(Int32),
    previous_bot_id     Nullable(Int32),
    last_message_time   Nullable(DateTime64(3)),
    unread_count        Int32,
    status              LowCardinality(String),
    response_message    LowCardinality(String),
    handle_by           LowCardinality(String),
    unique_blast        Nullable(String),
    is_blocked          UInt8,
    created_at          DateTime64(3),
    updated_at          DateTime64(3),
    service_type        LowCardinality(String),
    campaign_id         Nullable(UUID),
    campaign_name       Nullable(String),
    is_group            UInt8,
    group_jid           Nullable(String),
    is_unsaved          UInt8,
    delivery_status     LowCardinality(Nullable(String)),

    is_deleted          UInt8,
    _version            UInt64
)
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(created_at)
ORDER BY (tenant_id, created_at, id);

CREATE MATERIALIZED VIEW beezap.wa_chat_contacts_mv TO beezap.wa_chat_contacts AS
SELECT
    coalesce(t.id, toUUID('00000000-0000-0000-0000-000000000000'))  AS tenant_id,
    toUUID(q.id)                                       AS id,
    q.phone,
    q.masking_number,
    q.name,
    q.agent,
    q.current_bot_id,
    q.previous_bot_id,
    beezap_parse_datetime_or_null(q.last_message_time) AS last_message_time,
    q.unread_count,
    q.status,
    q.response_message,
    q.handle_by,
    q.unique_blast,
    q.is_blocked,
    beezap_parse_datetime(q.created_at, q.__source_ts_ms)  AS created_at,
    beezap_parse_datetime(q.updated_at, q.__source_ts_ms)  AS updated_at,
    q.service_type,
    toUUIDOrNull(q.campaign_id)                        AS campaign_id,
    q.campaign_name,
    q.is_group,
    q.group_jid,
    q.is_unsaved,
    q.delivery_status,
    (q.__deleted = 'true')                             AS is_deleted,
    q.__source_ts_ms                                   AS _version
FROM beezap.wa_chat_contacts_queue q
LEFT JOIN beezap.tenants t ON t.slug = beezap_tenant_id(q.__source_schema);
