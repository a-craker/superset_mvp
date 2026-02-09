FROM apache/superset:latest

USER root

# 1. Driver installation
RUN /app/.venv/bin/python -m ensurepip --default-pip
RUN /app/.venv/bin/python -m pip install --no-cache-dir clickhouse-connect

# 2. Inject custom config (HTML_SANITIZATION = False)
COPY superset_config.py /app/pythonpath/superset_config.py

# 3. Fix internal system permissions
RUN chown -R superset:superset /app/pythonpath
RUN chown -R superset:superset /app/superset_home

# 4. Entrypoint
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER superset
ENTRYPOINT ["/entrypoint.sh"]
