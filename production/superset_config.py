import os
from superset.db_engine_specs.clickhouse import ClickHouseEngineSpec

DB_ENGINE_SPECS = {
    "clickhouse": ClickHouseEngineSpec,
}

SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "change-me")

SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://superset:superset@db:5432/superset"
)

REDIS_HOST = "redis"
REDIS_PORT = 6379

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
}

DATA_CACHE_CONFIG = CACHE_CONFIG

class CeleryConfig:
    broker_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/0"
    result_backend = f"redis://{REDIS_HOST}:{REDIS_PORT}/1"
    imports = ("superset.sql_lab",)
    worker_prefetch_multiplier = 1
    task_acks_late = True

CELERY_CONFIG = CeleryConfig
