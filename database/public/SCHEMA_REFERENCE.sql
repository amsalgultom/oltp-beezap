-- ============================================================================
-- SCHEMA REFERENCE (READ-ONLY DOCUMENTATION — DO NOT RUN AS A MIGRATION)
-- ============================================================================
-- DDL view of the tables defined by the numbered migrations in this folder.
-- The numbered migration files (001_*.ts ...) remain the source of truth and
-- are NOT changed or replaced by this file.
--
-- Tables covered:
--   - tenants
--
-- Replace "{schema}" with the actual schema name (typically "public").
-- ============================================================================


-- ============================================================================
-- TABLE: tenants
-- Source: 001_create_tenants.ts (no later alters)
-- ============================================================================
CREATE TABLE "{schema}"."tenants" (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),                   -- 001
    name        VARCHAR(255) NOT NULL,                                        -- 001
    slug        VARCHAR(100) NOT NULL UNIQUE,                                 -- 001
    wa_number   TEXT NOT NULL,                                                -- 001, comment: Encrypted WhatsApp number
    waba_id     TEXT NOT NULL,                                                -- 001, comment: Encrypted WhatsApp Business Account ID
    email_wa    TEXT NOT NULL,                                                -- 001, comment: Encrypted email for WA API auth
    password_wa TEXT NOT NULL,                                                -- 001, comment: Encrypted password for WA API auth
    url_wa_api  VARCHAR(500) NOT NULL,                                        -- 001
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,                                -- 001
    settings    JSONB NOT NULL DEFAULT '{}',                                  -- 001, comment: Tenant-specific settings (rate limits, features, etc.)
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,           -- 001
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP            -- 001
);

CREATE UNIQUE INDEX "idx_tenants_slug"      ON "{schema}"."tenants" (slug);       -- 001
CREATE INDEX        "idx_tenants_is_active" ON "{schema}"."tenants" (is_active);  -- 001
