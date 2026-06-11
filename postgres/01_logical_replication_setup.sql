-- ============================================================================
-- Beezap CDC setup for Debezium (Server A: PostgreSQL OLTP)
-- ============================================================================
-- Run this script as a PostgreSQL SUPERUSER, connected to the Beezap
-- database (replace `beezap` below with the real database name everywhere).
--
-- This script is idempotent where possible, EXCEPT for the wal_level change
-- below which lives in postgresql.conf and requires a server restart.
--
-- ----------------------------------------------------------------------------
-- STEP 0 — postgresql.conf changes (REQUIRES RESTART, schedule a maintenance
-- window):
--
--   wal_level = logical
--   max_replication_slots = 10        -- default is usually fine, >=4 needed
--   max_wal_senders        = 10        -- default is usually fine, >=4 needed
--
-- After editing postgresql.conf, restart PostgreSQL (a `reload` is NOT
-- enough for wal_level). Verify with:
--   SHOW wal_level;   -- must return 'logical'
--
-- ----------------------------------------------------------------------------
-- STEP 0b — pg_hba.conf changes on Server A:
-- Allow the new Ubuntu server (running Kafka Connect/Debezium) to connect.
-- Replace <NEW_SERVER_IP> with the actual IP/CIDR of the new server.
--
--   host    beezap          debezium        <NEW_SERVER_IP>/32   scram-sha-256
--   host    replication     debezium        <NEW_SERVER_IP>/32   scram-sha-256
--
-- Then `SELECT pg_reload_conf();` (no restart needed for pg_hba.conf).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- STEP 1 — Replication role for Debezium
-- ----------------------------------------------------------------------------
-- Replace 'CHANGE_ME_STRONG_PASSWORD' with a strong, unique password and
-- store it in the .env file used by docker-compose (DEBEZIUM_DB_PASSWORD).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'debezium') THEN
        CREATE ROLE debezium WITH LOGIN REPLICATION PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE beezap TO debezium;


-- ----------------------------------------------------------------------------
-- STEP 2 — Reusable helper: grant CDC read access on a schema
-- ----------------------------------------------------------------------------
-- Used below for `public` and every existing `tenant_*` schema, and should
-- be called again for each NEW tenant schema during tenant onboarding:
--   SELECT beezap_grant_cdc_privileges('tenant_<new_tenant_uuid_with_underscores>');
CREATE OR REPLACE FUNCTION beezap_grant_cdc_privileges(target_schema text)
RETURNS void AS $$
BEGIN
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO debezium', target_schema);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO debezium', target_schema);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO debezium', target_schema);
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------------------
-- STEP 3 — Grant on `public` (tenants registry) and every existing `tenant_*`
-- schema
-- ----------------------------------------------------------------------------
SELECT beezap_grant_cdc_privileges('public');

DO $$
DECLARE
    schema_name text;
BEGIN
    FOR schema_name IN
        SELECT nspname FROM pg_namespace WHERE nspname LIKE 'tenant\_%' ESCAPE '\'
    LOOP
        PERFORM beezap_grant_cdc_privileges(schema_name);
    END LOOP;
END
$$;


-- ----------------------------------------------------------------------------
-- STEP 4 — Publication for logical replication
-- ----------------------------------------------------------------------------
-- FOR ALL TABLES is used (not a filtered list) so that tables in NEW tenant
-- schemas created after this point are automatically captured at the WAL
-- level — no ALTER PUBLICATION needed on tenant onboarding. The Debezium
-- connector's schema/table include-list regexes (see
-- kafka-connect/connectors/beezap-postgres-cdc.json) decide which of these
-- tables actually get streamed to Kafka.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'beezap_cdc') THEN
        CREATE PUBLICATION beezap_cdc FOR ALL TABLES;
    END IF;
END
$$;


-- ----------------------------------------------------------------------------
-- STEP 5 — Verification
-- ----------------------------------------------------------------------------
-- Should return 'logical':
--   SHOW wal_level;
--
-- Should list 'beezap_cdc' with puballtables = true:
--   SELECT pubname, puballtables FROM pg_publication;
--
-- Sanity check: should list every table in public + tenant_* schemas:
--   SELECT schemaname, tablename FROM pg_publication_tables
--   WHERE pubname = 'beezap_cdc' ORDER BY 1, 2 LIMIT 50;
--
-- Confirm the debezium role can log in and has REPLICATION:
--   SELECT rolname, rolreplication, rolcanlogin FROM pg_roles WHERE rolname = 'debezium';
