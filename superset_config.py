import os

# --- Server Basics ---
SUPERSET_WEBSERVER_ADDRESS = "0.0.0.0"
SUPERSET_WEBSERVER_PORT = 8088
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY")

# --- Database & Redis ---
SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://superset:{os.getenv('POSTGRES_PASSWORD')}@superset-db:5432/superset"
REDIS_URL = "redis://superset-redis:6379/0"

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_REDIS_URL": REDIS_URL,
    "CACHE_DEFAULT_TIMEOUT": 86400,
}
DATA_CACHE_CONFIG = CACHE_CONFIG
RATELIMIT_STORAGE_URI = "redis://superset-redis:6379/1"

CELERY_CONFIG = {
    "broker_url": REDIS_URL,
    "result_backend": REDIS_URL,
}

# --- Custom UI & Nav Bar Security ---
HTML_SANITIZATION = False
HTML_SANITIZATION_ALLOWED_ATTRIBUTES = {
    "a": ["href", "title", "target", "style", "class"],
    "div": ["style", "class"],
    "span": ["style", "class"],
}

# --- Feature Flags ---
FEATURE_FLAGS = {
    "EMBEDDED_SUPERSET": True,
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "GENERIC_CHART_AXES": True,
}

# --- Production Headers ---
HTTP_HEADERS = {"X-Frame-Options": "ALLOWALL"}
ENABLE_CORS = True
