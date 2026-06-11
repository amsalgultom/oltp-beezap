-- ============================================================================
-- SCHEMA REFERENCE (READ-ONLY DOCUMENTATION — DO NOT RUN AS A MIGRATION)
-- ============================================================================
-- Consolidated, "as of today" definitions for the tables below, merging the
-- original CREATE TABLE migration with every later ALTER migration that
-- touched it. This file exists purely so the full shape of these tables can
-- be seen in one place instead of jumping across many migration files.
--
-- Tables covered:
--   - users
--   - wa_chat_contacts
--   - wa_chat_messages
--   - user_sessions
--   - contact_results
--   - contact_results_history
--
-- Replace "{schema}" with the actual tenant schema name (e.g. "tenant_xxx").
-- Each column / index is annotated with the migration file that introduced
-- it. The numbered migration files (001_*.ts ... 050_*.ts) remain the
-- source of truth and are NOT changed or replaced by this file.
-- ============================================================================


-- ============================================================================
-- TABLE: users
-- Source: 001_create_users.ts (no later alters)
-- ============================================================================
CREATE TABLE "{schema}"."users" (
    id          SERIAL PRIMARY KEY,                                   -- 001
    username    VARCHAR(100) NOT NULL,                                -- 001
    email       VARCHAR(255),                                         -- 001
    password    VARCHAR(255) NOT NULL,                                -- 001
    full_name   VARCHAR(255),                                         -- 001
    level       VARCHAR(50) NOT NULL DEFAULT 'user',                  -- 001
    role_id     INTEGER,                                              -- 001
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,                        -- 001
    last_login  TIMESTAMP WITH TIME ZONE,                             -- 001
    meta_data   JSONB NOT NULL DEFAULT '{}',                          -- 001
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,   -- 001
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP    -- 001
);

CREATE UNIQUE INDEX "idx_{schema}_users_username" ON "{schema}"."users" (username);  -- 001
CREATE INDEX "idx_{schema}_users_role_id"        ON "{schema}"."users" (role_id);    -- 001
CREATE INDEX "idx_{schema}_users_is_active"      ON "{schema}"."users" (is_active);  -- 001


-- ============================================================================
-- TABLE: wa_chat_contacts
-- Source: 005_create_contacts.ts
-- Altered by: 022, 028, 029, 030, 033, 041, 043, 044, 049
-- ============================================================================

-- ENUM types
CREATE TYPE "{schema}"."enum_wa_chat_contacts_status"           AS ENUM ('open', 'close');             -- 005
CREATE TYPE "{schema}"."enum_wa_chat_contacts_response_message" AS ENUM ('Y', 'N', 'X');                -- 005
CREATE TYPE "{schema}"."enum_wa_chat_contacts_handle_by"        AS ENUM ('agent', 'bot');               -- 005
CREATE TYPE "{schema}"."enum_wa_chat_contacts_service_type"     AS ENUM ('official', 'unofficial');     -- 022

CREATE TABLE "{schema}"."wa_chat_contacts" (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),                                  -- 005
    phone              VARCHAR(50) NOT NULL,                                                         -- 005
    masking_number     VARCHAR(50) NOT NULL,                                                         -- 005
    name               VARCHAR(100) NOT NULL,                                                        -- 005
    agent              VARCHAR(100),                                                                 -- 005
    meta_data          TEXT,                                                                         -- 005
    current_bot_id     INTEGER,                                                                      -- 005
    previous_bot_id    INTEGER,                                                                      -- 005
    last_message       TEXT,                                                                         -- 005
    last_message_time  VARCHAR(50),                                                                  -- 005
    unread_count       INTEGER NOT NULL DEFAULT 0,                                                   -- 005
    status             "{schema}"."enum_wa_chat_contacts_status" NOT NULL DEFAULT 'close',           -- 005
    response_message   "{schema}"."enum_wa_chat_contacts_response_message" NOT NULL DEFAULT 'N',     -- 005
    handle_by          "{schema}"."enum_wa_chat_contacts_handle_by" NOT NULL DEFAULT 'bot',          -- 005
    unique_blast       VARCHAR(255),                                                                 -- 005
    is_blocked         BOOLEAN NOT NULL DEFAULT FALSE,                                               -- 005
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,                           -- 005
    updated_at         TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,                           -- 005

    service_type       "{schema}"."enum_wa_chat_contacts_service_type" NOT NULL DEFAULT 'official',  -- 022
    campaign_id        UUID,                                                                         -- 028 (originated from blast session)
    campaign_name      VARCHAR(255),                                                                 -- 029 (denormalized wa_campaigns.name)
    is_group           BOOLEAN NOT NULL DEFAULT FALSE,                                               -- 030
    group_jid          VARCHAR(100),                                                                 -- 030
    is_unsaved         BOOLEAN NOT NULL DEFAULT TRUE,                                                -- 043 (true until a contact_result is saved)
    delivery_status    VARCHAR(20)                                                                   -- 049 (sent | delivered | read | failed)
);

-- Indexes
CREATE INDEX "idx_{schema}_contacts_phone"        ON "{schema}"."wa_chat_contacts" (phone);                  -- 005
CREATE INDEX "idx_{schema}_contacts_masking"      ON "{schema}"."wa_chat_contacts" (masking_number);         -- 005
CREATE INDEX "idx_{schema}_contacts_status"       ON "{schema}"."wa_chat_contacts" (status);                 -- 005
CREATE INDEX "idx_{schema}_contacts_handle_by"    ON "{schema}"."wa_chat_contacts" (handle_by);              -- 005
CREATE INDEX "idx_{schema}_contacts_unique_blast" ON "{schema}"."wa_chat_contacts" (unique_blast);           -- 005
CREATE INDEX "idx_{schema}_contacts_current_bot"  ON "{schema}"."wa_chat_contacts" (current_bot_id);         -- 005

CREATE INDEX "idx_{schema}_contacts_service_type" ON "{schema}"."wa_chat_contacts" (service_type);           -- 022

CREATE INDEX "idx_{schema}_chat_contacts_campaign_id" ON "{schema}"."wa_chat_contacts" (campaign_id);        -- 028

CREATE INDEX "idx_chat_contacts_group_jid" ON "{schema}"."wa_chat_contacts" (group_jid)
    WHERE group_jid IS NOT NULL;                                                                             -- 030

-- Composite uniqueness guard: only one open chat per phone/masking/service combo
CREATE UNIQUE INDEX "idx_{schema}_contacts_unique_phone_masking_service_status"
    ON "{schema}"."wa_chat_contacts" (phone, masking_number, service_type, status);                          -- 033

CREATE INDEX "idx_{schema}_chat_contacts_agent" ON "{schema}"."wa_chat_contacts" (agent);                    -- 041 (created CONCURRENTLY)

-- Filter/sort indexes for getContacts (all scoped to is_blocked = false AND status = 'open' AND handle_by = 'agent')
CREATE INDEX "idx_{schema}_contacts_base_last_msg"
    ON "{schema}"."wa_chat_contacts" (last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent';                                    -- 044

CREATE INDEX "idx_{schema}_contacts_agent_last_msg"
    ON "{schema}"."wa_chat_contacts" (agent, last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent';                                    -- 044

CREATE INDEX "idx_{schema}_contacts_campaign_last_msg"
    ON "{schema}"."wa_chat_contacts" (campaign_id, last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent';                                    -- 044

CREATE INDEX "idx_{schema}_contacts_unread"
    ON "{schema}"."wa_chat_contacts" (last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent' AND unread_count > 0;               -- 044

CREATE INDEX "idx_{schema}_contacts_unsaved"
    ON "{schema}"."wa_chat_contacts" (last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent' AND is_unsaved = true;              -- 044

CREATE INDEX "idx_{schema}_contacts_name"
    ON "{schema}"."wa_chat_contacts" (name)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent';                                    -- 044

CREATE INDEX "idx_{schema}_contacts_delivery_status"
    ON "{schema}"."wa_chat_contacts" (delivery_status, last_message_time DESC)
    WHERE is_blocked = false AND status = 'open' AND handle_by = 'agent' AND delivery_status IS NOT NULL;    -- 049


-- ============================================================================
-- TABLE: wa_chat_messages
-- Source: 006_create_messages.ts
-- Altered by: 027, 030, 031, 045
-- ============================================================================

-- ENUM types
CREATE TYPE "{schema}"."enum_wa_chat_messages_sender"           AS ENUM ('user', 'contact');           -- 006
CREATE TYPE "{schema}"."enum_wa_chat_messages_status"           AS ENUM ('sent', 'delivered', 'read', 'failed'); -- 006
CREATE TYPE "{schema}"."enum_wa_chat_messages_category_message" AS ENUM ('private', 'template');        -- 006

CREATE TABLE "{schema}"."wa_chat_messages" (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),                                 -- 006
    contact_id          UUID NOT NULL,                                                              -- 006 (-> wa_chat_contacts.id, no FK constraint defined)
    message_id          VARCHAR(255),                                                               -- 006, comment: WhatsApp message ID
    content             TEXT,                                                                       -- 006
    type                VARCHAR(50) NOT NULL DEFAULT 'text',                                        -- 006
    sender              "{schema}"."enum_wa_chat_messages_sender" NOT NULL DEFAULT 'contact',       -- 006
    status              "{schema}"."enum_wa_chat_messages_status" NOT NULL DEFAULT 'sent',          -- 006
    media_url           TEXT,                                                                       -- 006
    media_type          VARCHAR(50),                                                                -- 006
    media_filename      VARCHAR(255),                                                               -- 006
    meta_data           TEXT,                                                                       -- 006, comment: Additional metadata as JSON string
    sent_by             VARCHAR(100),                                                               -- 006, comment: Username of agent who sent the message
    bot_id              INTEGER,                                                                    -- 006, comment: Bot that sent this message
    error_message       TEXT,                                                                       -- 006
    "timestamp"         VARCHAR(255),                                                               -- 006
    created_at          VARCHAR(255),                                                               -- 006 (NOTE: stored as string, not a real timestamp)
    updated_at          VARCHAR(255),                                                               -- 006 (NOTE: stored as string, not a real timestamp)
    category_message    "{schema}"."enum_wa_chat_messages_category_message" NOT NULL DEFAULT 'private', -- 006
    template_name       VARCHAR(255),                                                               -- 006
    template_language   VARCHAR(255),                                                               -- 006
    template_parameters TEXT,                                                                       -- 006, comment: Template parameters as JSON string
    agent               VARCHAR(255),                                                               -- 006
    attachment          VARCHAR(255),                                                               -- 006
    link_file           VARCHAR(255),                                                               -- 006
    delivered_at        VARCHAR(255),                                                               -- 006
    read_at             VARCHAR(255),                                                               -- 006
    failed_at           VARCHAR(255),                                                               -- 006
    bot_response        TEXT,                                                                       -- 006

    campaign_id         UUID,                                                                       -- 027 (-> wa_campaigns.id)
    participant_phone   VARCHAR(30),                                                                -- 030 (sender phone within a group chat)
    participant_name    VARCHAR(100),                                                               -- 030 (sender display name within a group chat)
    reply_to_message_id VARCHAR(255)                                                                -- 031 (-> wa_chat_messages.message_id being replied to)
);

-- Indexes
CREATE INDEX "idx_{schema}_messages_contact_id"      ON "{schema}"."wa_chat_messages" (contact_id);              -- 006
CREATE INDEX "idx_{schema}_messages_message_id"      ON "{schema}"."wa_chat_messages" (message_id);              -- 006
CREATE INDEX "idx_{schema}_messages_sender"          ON "{schema}"."wa_chat_messages" (sender);                  -- 006
CREATE INDEX "idx_{schema}_messages_status"          ON "{schema}"."wa_chat_messages" (status);                  -- 006
CREATE INDEX "idx_{schema}_messages_created_at"      ON "{schema}"."wa_chat_messages" (created_at);              -- 006
CREATE INDEX "idx_{schema}_messages_contact_created" ON "{schema}"."wa_chat_messages" (contact_id, created_at);  -- 006

CREATE INDEX "idx_{schema}_chat_messages_campaign_id" ON "{schema}"."wa_chat_messages" (campaign_id);            -- 027

CREATE INDEX "idx_chat_messages_reply_to" ON "{schema}"."wa_chat_messages" (reply_to_message_id)
    WHERE reply_to_message_id IS NOT NULL;                                                                       -- 031

-- Dashboard monitoring aggregation indexes
CREATE INDEX "idx_{schema}_chat_messages_category_agent_status"
    ON "{schema}"."wa_chat_messages" (category_message, agent, status);                                          -- 045

CREATE INDEX "idx_{schema}_chat_messages_category_campaign_status"
    ON "{schema}"."wa_chat_messages" (category_message, campaign_id, status);                                    -- 045

CREATE INDEX "idx_{schema}_chat_messages_category_created_status"
    ON "{schema}"."wa_chat_messages" (category_message, created_at, status);                                     -- 045


-- ============================================================================
-- TABLE: user_sessions
-- Source: 047_create_user_sessions.ts (no later alters)
--
-- Tracks user login sessions for online/offline monitoring. Each successful
-- login inserts a row. Logout (manual, expired, or forced) updates
-- logout_time + is_online = false.
-- "Online" = is_online = true AND last_activity within heartbeat window.
-- ============================================================================
CREATE TABLE "{schema}"."user_sessions" (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),         -- 047
    user_id        INTEGER NOT NULL,                                   -- 047 (-> users.id, no FK constraint defined)
    username       VARCHAR(255) NOT NULL,                              -- 047
    device_info    VARCHAR(255),                                       -- 047
    user_agent     TEXT,                                               -- 047
    ip_address     VARCHAR(64),                                        -- 047
    login_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),    -- 047
    last_activity  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),    -- 047
    logout_time    TIMESTAMP WITH TIME ZONE,                           -- 047
    logout_reason  VARCHAR(20),                                        -- 047 ('manual' | 'expired' | 'forced')
    is_online      BOOLEAN NOT NULL DEFAULT TRUE,                      -- 047
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),    -- 047
    updated_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()     -- 047
);

CREATE INDEX "idx_{schema}_user_sessions_user_id"  ON "{schema}"."user_sessions" (user_id);                    -- 047
CREATE INDEX "idx_{schema}_user_sessions_username" ON "{schema}"."user_sessions" (username);                   -- 047
CREATE INDEX "idx_{schema}_user_sessions_online"   ON "{schema}"."user_sessions" (is_online, last_activity);   -- 047


-- ============================================================================
-- TABLE: contact_results
-- Source: 020_create_contact_results.ts (no later alters)
--
-- Holds only the latest snapshot ("Final" report) of a contact's result.
-- ============================================================================
CREATE TABLE "{schema}"."contact_results" (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- 020
    contact_id  UUID NOT NULL,                                -- 020 (-> wa_chat_contacts.id, no FK constraint defined)
    results     TEXT NOT NULL,                                -- 020
    created_by  VARCHAR(255) NOT NULL,                        -- 020
    updated_by  VARCHAR(255),                                 -- 020
    created_at  VARCHAR(255) NOT NULL,                        -- 020 (NOTE: stored as string, not a real timestamp)
    updated_at  VARCHAR(255) NOT NULL                         -- 020 (NOTE: stored as string, not a real timestamp)
);

CREATE UNIQUE INDEX "idx_{schema}_contact_results_contact_id"
    ON "{schema}"."contact_results" (contact_id);             -- 020


-- ============================================================================
-- TABLE: contact_results_history
-- Source: 048_create_contact_results_history.ts (no later alters)
--
-- Append-only history of every contact result save/submit. While
-- contact_results keeps only the latest snapshot, this table records one row
-- per save event so a "Detail" report can show the full submission history
-- per contact.
-- ============================================================================
CREATE TABLE "{schema}"."contact_results_history" (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),  -- 048
    contact_id  UUID NOT NULL,                                -- 048 (-> wa_chat_contacts.id, no FK constraint defined)
    results     TEXT NOT NULL,                                -- 048
    saved_by    VARCHAR(255) NOT NULL,                        -- 048
    created_at  VARCHAR(255) NOT NULL                         -- 048 (NOTE: stored as string, not a real timestamp)
);

CREATE INDEX "idx_{schema}_contact_results_history_contact_id"
    ON "{schema}"."contact_results_history" (contact_id);     -- 048

CREATE INDEX "idx_{schema}_contact_results_history_created_at"
    ON "{schema}"."contact_results_history" (created_at);     -- 048
