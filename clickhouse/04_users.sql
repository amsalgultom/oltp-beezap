-- ============================================================================
-- Beezap analytics — users (per-tenant agents/operators)
-- Source: tenant_*.users (unified topic cdc.users)
-- ============================================================================
-- Small dimension table used to enrich agent-performance dashboards (joins
-- on username via wa_chat_messages.agent/sent_by, user_sessions.username).
-- Columns intentionally NOT replicated (excluded via column.exclude.list):
-- password, meta_data.

CREATE TABLE beezap.users_queue
(
    id          Int32,
    username    String,
    email       Nullable(String),
    full_name   Nullable(String),
    level       String,
    role_id     Nullable(Int32),
    is_active   UInt8,
    last_login  Nullable(String),
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
    kafka_topic_list = 'cdc.users',
    kafka_group_name = 'clickhouse_beezap_users',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

CREATE TABLE beezap.users
(
    tenant_id   UUID,
    id          Int32,
    username    String,
    email       Nullable(String),
    full_name   Nullable(String),
    level       LowCardinality(String),
    role_id     Nullable(Int32),
    is_active   UInt8,
    last_login  Nullable(DateTime64(3)),
    created_at  DateTime64(3),
    updated_at  DateTime64(3),

    is_deleted  UInt8,
    _version    UInt64
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY (tenant_id, id);

CREATE MATERIALIZED VIEW beezap.users_mv TO beezap.users AS
SELECT
    beezap_tenant_id(__source_schema)                  AS tenant_id,
    id,
    username,
    email,
    full_name,
    level,
    role_id,
    is_active,
    beezap_parse_datetime_or_null(last_login)          AS last_login,
    beezap_parse_datetime(created_at, __source_ts_ms)  AS created_at,
    beezap_parse_datetime(updated_at, __source_ts_ms)  AS updated_at,
    (__deleted = 'true')                               AS is_deleted,
    __source_ts_ms                                     AS _version
FROM beezap.users_queue;
