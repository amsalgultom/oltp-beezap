#!/usr/bin/env bash
# ============================================================================
# Beezap CDC — register/update the Debezium PostgreSQL connector
# ============================================================================
# Run this on the new Ubuntu server (the docker-compose host), NOT inside a
# container. Requires: curl, envsubst (apt package gettext-base), jq.
#
#   ./kafka-connect/register-connector.sh
#
# Reads connection details from ../.env, substitutes them into
# connectors/beezap-postgres-cdc.json, and POSTs to the Kafka Connect REST
# API (http://localhost:8083, published by the kafka-connect service).
# If the connector already exists, PUTs the updated config instead.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/../.env}"
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="beezap-postgres-cdc"
TEMPLATE="${SCRIPT_DIR}/connectors/${CONNECTOR_NAME}.json"

if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
else
    echo "Env file not found: ${ENV_FILE}" >&2
    exit 1
fi

for var in PG_HOST PG_PORT PG_DATABASE DEBEZIUM_DB_USER DEBEZIUM_DB_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        echo "Missing required env var: ${var} (set it in ${ENV_FILE})" >&2
        exit 1
    fi
done

rendered=$(envsubst < "${TEMPLATE}")

if curl -fsS -o /dev/null "${CONNECT_URL}/connectors/${CONNECTOR_NAME}"; then
    echo "Connector '${CONNECTOR_NAME}' already exists — updating config..."
    echo "${rendered}" | jq '.config' | curl -fsS -X PUT \
        "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config" \
        -H "Content-Type: application/json" -d @- | jq .
else
    echo "Registering new connector '${CONNECTOR_NAME}'..."
    echo "${rendered}" | curl -fsS -X POST \
        "${CONNECT_URL}/connectors" \
        -H "Content-Type: application/json" -d @- | jq .
fi

echo
echo "Status: ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status"
curl -fsS "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | jq .
