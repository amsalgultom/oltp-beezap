#!/usr/bin/env bash
# ============================================================================
# Beezap CDC — Kafka topic bootstrap (run against Server B: Kafka broker)
# ============================================================================
# Run this from INSIDE the kafka-connect container, which bundles the Kafka
# CLI tools (kafka-topics.sh) used to talk to the existing Kafka broker on
# Server B:
#
#   docker compose exec kafka-connect bash /kafka/create-topics.sh
#
# (the kafka/ directory is bind-mounted into the container — see
# docker-compose.yml)
#
# All commands are idempotent (--if-not-exists). Replication factor defaults
# to 1 (single-broker Server B); override with REPLICATION_FACTOR if Server B
# has multiple brokers.
# ============================================================================
set -euo pipefail

BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS:-xx.xx.8.60:9092}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-1}"
KAFKA_BIN="${KAFKA_BIN:-/kafka/bin}"

create_topic() {
    local name="$1"
    local partitions="$2"
    shift 2
    echo "Creating topic: ${name} (partitions=${partitions}, rf=${REPLICATION_FACTOR})"
    "${KAFKA_BIN}/kafka-topics.sh" \
        --bootstrap-server "${BOOTSTRAP_SERVERS}" \
        --create --if-not-exists \
        --topic "${name}" \
        --partitions "${partitions}" \
        --replication-factor "${REPLICATION_FACTOR}" \
        "$@"
}

# ----------------------------------------------------------------------------
# Kafka Connect internal topics (config/offset/status storage for the
# Debezium worker, distributed mode)
# ----------------------------------------------------------------------------
create_topic "connect-configs" 1 --config cleanup.policy=compact
create_topic "connect-offsets" 25 --config cleanup.policy=compact
create_topic "connect-status" 5 --config cleanup.policy=compact

# ----------------------------------------------------------------------------
# CDC topics (post-routing, unified across all tenants — see
# kafka-connect/connectors/beezap-postgres-cdc.json RegexRouter)
# Retention: 7 days. ClickHouse persists the durable copy; this is just
# enough to allow consumer restarts/backfills.
# ----------------------------------------------------------------------------
RETENTION_MS=$((7 * 24 * 60 * 60 * 1000))

create_topic "cdc.tenants" 1 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.users" 1 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.user_sessions" 1 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.contact_results" 1 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.contact_results_history" 1 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.wa_chat_contacts" 3 --config "retention.ms=${RETENTION_MS}"
create_topic "cdc.wa_chat_messages" 3 --config "retention.ms=${RETENTION_MS}"

echo "Done. Current topics:"
"${KAFKA_BIN}/kafka-topics.sh" --bootstrap-server "${BOOTSTRAP_SERVERS}" --list
