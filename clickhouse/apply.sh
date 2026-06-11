#!/usr/bin/env bash
# ============================================================================
# Apply all Beezap ClickHouse schema files, in order.
#
# Run from the repo root on the new Ubuntu server, after `docker compose up -d`:
#
#   ./clickhouse/apply.sh
#
# Requires:
#   - envsubst (gettext-base package)
#   - docker compose, with a running `clickhouse` service
#   - ../.env containing at least KAFKA_BOOTSTRAP_SERVERS, and optionally
#     CLICKHOUSE_USER / CLICKHOUSE_PASSWORD
#
# Safe to re-run: every statement uses CREATE ... IF NOT EXISTS or
# CREATE OR REPLACE, except the CREATE VIEW statements in 08_views.sql,
# which will fail with "already exists" on a second run — drop them first
# if you need to re-apply that file (see README).
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

: "${KAFKA_BOOTSTRAP_SERVERS:?Set KAFKA_BOOTSTRAP_SERVERS in .env (e.g. xx.xx.8.60:9092)}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-}"

cd "$ROOT_DIR"

FILES=(
  clickhouse/00_functions.sql
  clickhouse/01_database_and_tenants.sql
  clickhouse/02_wa_chat_messages.sql
  clickhouse/03_wa_chat_contacts.sql
  clickhouse/04_users.sql
  clickhouse/05_user_sessions.sql
  clickhouse/06_contact_results.sql
  clickhouse/07_contact_results_history.sql
  clickhouse/08_views.sql
)

for f in "${FILES[@]}"; do
  echo ">> Applying $f"
  envsubst '${KAFKA_BOOTSTRAP_SERVERS}' < "$f" \
    | docker compose exec -T clickhouse \
        clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --multiquery
done

echo "All ClickHouse schema files applied."
