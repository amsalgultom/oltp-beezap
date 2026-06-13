-- ============================================================================
-- Beezap analytics â€” user_sessions (agent login/logout / online tracking)
-- Source: tenant_*.user_sessions (unified topic cdc.user_sessions)
-- ============================================================================
-- "Online" = is_online = true AND last_activity within the app's heartbeat
-- window (see source schema doc). Powers agent-activity dashboards.

CREATE TABLE IF NOT EXISTS beezap.user_sessions_queue
(
    id              String,
    user_id         Int32,
    username        String,
    device_info     Nullable(String),
    user_agent      Nullable(String),
    ip_address      Nullable(String),
    login_time      String,
    last_activity   String,
    logout_time     Nullable(String),
    logout_reason   Nullable(String),
    is_online       UInt8,
    created_at      Nullable(String),
    updated_at      Nullable(String),

    __op             LowCardinality(String),
    __source_ts_ms   Int64,
    __source_schema  LowCardinality(String),
    __deleted        LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = '${KAFKA_BOOTSTRAP_SERVERS}',
    kafka_topic_list = 'cdc.user_sessions',
    kafka_group_name = 'clickhouse_beezap_user_sessions',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 1000;

CREATE TABLE IF NOT EXISTS beezap.user_sessions
(
    tenant_id       UUID,
    id              UUID,
    user_id         Int32,
    username        String,
    device_info     Nullable(String),
    user_agent      Nullable(String),
    ip_address      Nullable(String),
    login_time      DateTime64(3),
    last_activity   DateTime64(3),
    logout_time     Nullable(DateTime64(3)),
    logout_reason   LowCardinality(Nullable(String)),
    is_online       UInt8,
    created_at      DateTime64(3),
    updated_at      DateTime64(3),

    is_deleted      UInt8,
    _version        UInt64
)
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(login_time)
ORDER BY (tenant_id, login_time, id);

CREATE MATERIALIZED VIEW IF NOT EXISTS beezap.user_sessions_mv TO beezap.user_sessions AS
SELECT
    coalesce(t.id, toUUID('00000000-0000-0000-0000-000000000000'))  AS tenant_id,
    toUUID(q.id)                                       AS id,
    q.user_id,
    q.username,
    q.device_info,
    q.user_agent,
    q.ip_address,
    beezap_parse_datetime(q.login_time, q.__source_ts_ms)  AS login_time,
    beezap_parse_datetime(q.last_activity, q.__source_ts_ms) AS last_activity,
    beezap_parse_datetime_or_null(q.logout_time)       AS logout_time,
    q.logout_reason,
    q.is_online,
    beezap_parse_datetime(q.created_at, q.__source_ts_ms)  AS created_at,
    beezap_parse_datetime(q.updated_at, q.__source_ts_ms)  AS updated_at,
    (q.__deleted = 'true')                             AS is_deleted,
    q.__source_ts_ms                                   AS _version
FROM beezap.user_sessions_queue q
LEFT JOIN beezap.tenants t ON t.slug = beezap_tenant_id(q.__source_schema);

