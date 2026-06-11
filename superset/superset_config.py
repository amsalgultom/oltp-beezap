import os

# ============================================================================
# Beezap analytics — Superset configuration
# All secrets/hosts come from environment variables set in docker-compose.yml
# / .env, so this file can stay in version control.
# ============================================================================

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# ----------------------------------------------------------------------------
# Superset's own metadata database (separate from the Beezap OLTP Postgres
# and from ClickHouse — this only stores dashboards, charts, users, etc.)
# ----------------------------------------------------------------------------
SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://{user}:{password}@{host}:{port}/{db}".format(
        user=os.environ.get("SUPERSET_DB_USER", "superset"),
        password=os.environ["SUPERSET_DB_PASSWORD"],
        host=os.environ.get("SUPERSET_DB_HOST", "superset-db"),
        port=os.environ.get("SUPERSET_DB_PORT", "5432"),
        db=os.environ.get("SUPERSET_DB_NAME", "superset"),
    )
)

# ----------------------------------------------------------------------------
# Redis-backed caches (results cache, filter state, explore form data)
# ----------------------------------------------------------------------------
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_results_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 1,
}
DATA_CACHE_CONFIG = CACHE_CONFIG

FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_filter_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 2,
}

EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_form_data_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 3,
}

# ----------------------------------------------------------------------------
# Misc
# ----------------------------------------------------------------------------
# Beezap's ClickHouse data refreshes continuously via Kafka; keep chart-level
# caching short so dashboards reflect near-real-time data.
SQLLAB_CTAS_NO_LIMIT = True
