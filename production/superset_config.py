import os

GUNICORN_WORKERS = int(os.getenv("SUPERSET_WORKERS", 2))
SUPERSET_WEBSERVER_TIMEOUT = int(os.getenv("SUPERSET_TIMEOUT", 120))
SUPERSET_WEBSERVER_ADDRESS = "0.0.0.0"
SUPERSET_WEBSERVER_PORT = 8088

SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY")

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://superset:{os.getenv('POSTGRES_PASSWORD')}@superset-db:5432/superset"
)

REDIS_URL = "redis://superset-redis:6379/0"
RATELIMIT_STORAGE_URI = "redis://superset-redis:6379/1"

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_REDIS_URL": REDIS_URL,
}

CELERY_CONFIG = {
    "broker_url": REDIS_URL,
    "result_backend": REDIS_URL,
}


