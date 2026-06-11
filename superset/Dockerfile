# ============================================================================
# Beezap analytics — Superset image
# Adds the ClickHouse SQLAlchemy/DBAPI driver to the official Superset image
# and bakes in our config (datasource for ClickHouse, Redis cache, etc.).
# ============================================================================
FROM apache/superset:4.0.2

USER root

# clickhouse-connect provides the `clickhousedb://` SQLAlchemy dialect used
# to register the ClickHouse database connection in Superset.
RUN pip install --no-cache-dir clickhouse-connect==0.7.19

COPY superset_config.py /app/pythonpath/superset_config.py

USER superset
