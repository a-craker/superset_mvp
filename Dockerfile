FROM apache/superset:6.0.0

USER root

# 1. Bootstrap pip into the virtual environment
RUN /app/.venv/bin/python -m ensurepip --default-pip

# 2. Install drivers and Gunicorn thread support
# We add gevent as a secondary option, but gthread is standard
RUN /app/.venv/bin/python -m pip install --no-cache-dir \
    clickhouse-connect==0.10.0 \
    psycopg2-binary==2.9.9 \
    gevent

# 3. Setup Entrypoint
COPY --chmod=755 docker-entrypoint.sh /entrypoint.sh

USER superset

ENTRYPOINT ["/entrypoint.sh"]