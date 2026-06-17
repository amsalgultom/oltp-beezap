import os
from urllib.parse import urlparse

# ============================================================================
# Beezap analytics — Superset configuration
# All secrets/hosts come from environment variables set in docker-compose.yml
# / .env, so this file can stay in version control.
# ============================================================================

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

# Parse external Redis URL (format: redis://host:port/db)
_redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
_redis_parsed = urlparse(_redis_url)
_redis_host = _redis_parsed.hostname or "localhost"
_redis_port = int(_redis_parsed.port or 6379)
_redis_password = os.environ.get("REDIS_PASSWORD")

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
# Connects to external Redis at _redis_host:_redis_port
# Each cache type uses a separate DB number (1, 2, 3)
# ----------------------------------------------------------------------------
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_results_",
    "CACHE_REDIS_HOST": _redis_host,
    "CACHE_REDIS_PORT": _redis_port,
    "CACHE_REDIS_PASSWORD": _redis_password,
    "CACHE_REDIS_DB": 1,
}
DATA_CACHE_CONFIG = CACHE_CONFIG

FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_filter_",
    "CACHE_REDIS_HOST": _redis_host,
    "CACHE_REDIS_PORT": _redis_port,
    "CACHE_REDIS_PASSWORD": _redis_password,
    "CACHE_REDIS_DB": 2,
}

EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "superset_form_data_",
    "CACHE_REDIS_HOST": _redis_host,
    "CACHE_REDIS_PORT": _redis_port,
    "CACHE_REDIS_PASSWORD": _redis_password,
    "CACHE_REDIS_DB": 3,
}

# ----------------------------------------------------------------------------
# Misc
# ----------------------------------------------------------------------------
# Beezap's ClickHouse data refreshes continuously via Kafka; keep chart-level
# caching short so dashboards reflect near-real-time data.
SQLLAB_CTAS_NO_LIMIT = True

# ----------------------------------------------------------------------------
# Embedding — required for the Next.js analytics dashboard
# ----------------------------------------------------------------------------
FEATURE_FLAGS = {
    "EMBEDDED_SUPERSET": True,
}

# Allow the Next.js app to embed dashboards via guest tokens.
# Set this to the exact origin of the Next.js frontend.
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": [os.environ.get("NEXTJS_APP_URL", "http://localhost:3000")],
}

# Guest token JWT secret — must match NEXTAUTH_SECRET in .env.local (or use its own)
GUEST_TOKEN_JWT_SECRET = os.environ.get("SUPERSET_GUEST_TOKEN_SECRET", SECRET_KEY)
GUEST_TOKEN_JWT_ALGO = "HS256"
GUEST_TOKEN_HEADER_NAME = "X-GuestToken"
GUEST_TOKEN_JWT_EXP_SECONDS = 300  # 5 minutes — frontend refreshes automatically
