FROM apache/superset:latest

# Entrypoint
USER root

# 1. Bootstrap pip into the virtual environment (since it's missing)
RUN /app/.venv/bin/python -m ensurepip --default-pip

# 2. Install the driver using the venv's pip
RUN /app/.venv/bin/python -m pip install --no-cache-dir clickhouse-connect

# Entrypoint
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
