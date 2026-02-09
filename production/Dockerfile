# docker build -t superset-clickhouse:1.0.0 .

FROM apache/superset:6.0.0

# Entrypoint
USER root

# 1. Bootstrap pip into the virtual environment (since it's missing)
RUN /app/.venv/bin/python -m ensurepip --default-pip

# 2. Install the driver using the venv's pip
RUN /app/.venv/bin/python -m pip install --no-cache-dir \
    clickhouse-connect==0.10.0 \
    psycopg2-binary==2.9.9

# Entrypoint
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
