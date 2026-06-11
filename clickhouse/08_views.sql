-- ============================================================================
-- Beezap analytics — convenience + analytics views
-- ============================================================================
-- These are the objects Superset should query (not the raw *_queue/*_mv
-- internals, and generally not the deduplicated tables directly either,
-- since FINAL + is_deleted filtering is easy to forget).

-- ----------------------------------------------------------------------------
-- Per-entity "latest, non-deleted row" views
-- ----------------------------------------------------------------------------
CREATE VIEW beezap.v_tenants AS
SELECT * FROM beezap.tenants FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_users AS
SELECT * FROM beezap.users FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_wa_chat_messages AS
SELECT * FROM beezap.wa_chat_messages FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_wa_chat_contacts AS
SELECT * FROM beezap.wa_chat_contacts FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_user_sessions AS
SELECT * FROM beezap.user_sessions FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_contact_results AS
SELECT * FROM beezap.contact_results FINAL WHERE is_deleted = 0;

CREATE VIEW beezap.v_contact_results_history AS
SELECT * FROM beezap.contact_results_history FINAL WHERE is_deleted = 0;


-- ----------------------------------------------------------------------------
-- Analytics view: message delivery funnel
-- Daily counts of messages by tenant / campaign / category / sender / status.
-- e.g. sent vs delivered vs read vs failed, per campaign, per day.
-- ----------------------------------------------------------------------------
CREATE VIEW beezap.v_message_delivery_funnel AS
SELECT
    m.tenant_id,
    t.name AS tenant_name,
    t.slug AS tenant_slug,
    m.day,
    m.campaign_id,
    m.category_message,
    m.sender,
    m.status,
    m.type,
    m.message_count
FROM
(
    SELECT
        tenant_id,
        toDate(created_at) AS day,
        campaign_id,
        category_message,
        sender,
        status,
        type,
        count() AS message_count
    FROM beezap.wa_chat_messages
    FINAL
    WHERE is_deleted = 0
    GROUP BY tenant_id, day, campaign_id, category_message, sender, status, type
) AS m
LEFT JOIN
(
    SELECT id AS tenant_id, name, slug FROM beezap.tenants FINAL WHERE is_deleted = 0
) AS t
ON m.tenant_id = t.tenant_id;


-- ----------------------------------------------------------------------------
-- Analytics view: contact growth
-- Daily new-contact counts by tenant / campaign / service_type / handle_by.
-- ----------------------------------------------------------------------------
CREATE VIEW beezap.v_contact_growth AS
SELECT
    c.tenant_id,
    t.name AS tenant_name,
    t.slug AS tenant_slug,
    c.day,
    c.campaign_id,
    c.campaign_name,
    c.service_type,
    c.handle_by,
    c.new_contacts
FROM
(
    SELECT
        tenant_id,
        toDate(created_at) AS day,
        campaign_id,
        campaign_name,
        service_type,
        handle_by,
        count() AS new_contacts
    FROM beezap.wa_chat_contacts
    FINAL
    WHERE is_deleted = 0
    GROUP BY tenant_id, day, campaign_id, campaign_name, service_type, handle_by
) AS c
LEFT JOIN
(
    SELECT id AS tenant_id, name, slug FROM beezap.tenants FINAL WHERE is_deleted = 0
) AS t
ON c.tenant_id = t.tenant_id;


-- ----------------------------------------------------------------------------
-- Analytics view: agent session activity
-- Daily session count + total online seconds per tenant / agent (username).
-- "Online seconds" approximates each session's duration as
-- logout_time (or, if still open, last_activity) minus login_time.
-- ----------------------------------------------------------------------------
CREATE VIEW beezap.v_agent_sessions AS
SELECT
    s.tenant_id,
    t.name AS tenant_name,
    t.slug AS tenant_slug,
    s.day,
    s.username,
    s.session_count,
    s.online_seconds
FROM
(
    SELECT
        tenant_id,
        toDate(login_time) AS day,
        username,
        count() AS session_count,
        sum(dateDiff('second', login_time, coalesce(logout_time, last_activity))) AS online_seconds
    FROM beezap.user_sessions
    FINAL
    WHERE is_deleted = 0
    GROUP BY tenant_id, day, username
) AS s
LEFT JOIN
(
    SELECT id AS tenant_id, name, slug FROM beezap.tenants FINAL WHERE is_deleted = 0
) AS t
ON s.tenant_id = t.tenant_id;
