-- ============================================================================
-- Beezap analytics — user_sessions (agent login/logout / online tracking)
-- Source: tenant_*.user_sessions (unified topic cdc.user_sessions)
-- ============================================================================
-- "Online" = is_online = true AND last_activity within the app's heartbeat
-- window (see source schema doc). Powers agent-activity dashboards.

CREATE TABLE beezap.user_sessions_queue
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

CREATE TABLE beezap.user_sessions
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

CREATE MATERIALIZED VIEW beezap.user_sessions_mv TO beezap.user_sessions AS
SELECT
    beezap_tenant_id(__source_schema)                  AS tenant_id,
    toUUID(id)                                         AS id,
    user_id,
    username,
    device_info,
    user_agent,
    ip_address,
    beezap_parse_datetime(login_time, __source_ts_ms)  AS login_time,
    beezap_parse_datetime(last_activity, __source_ts_ms) AS last_activity,
    beezap_parse_datetime_or_null(logout_time)         AS logout_time,
    logout_reason,
    is_online,
    beezap_parse_datetime(created_at, __source_ts_ms)  AS created_at,
    beezap_parse_datetime(updated_at, __source_ts_ms)  AS updated_at,
    (__deleted = 'true')                               AS is_deleted,
    __source_ts_ms                                     AS _version
FROM beezap.user_sessions_queue;
