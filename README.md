# Apache Superset Production Deployment

This repository contains a production-ready deployment of Apache Superset, optimized for a 4-core server and integrated with a pre-existing ClickHouse data warehouse.

## Project Structure

```text
.
├── docker-compose.yml     # Service orchestration & networking
├── Dockerfile             # Custom image build (Drivers & Environment)
├── docker-entrypoint.sh   # Automation: DB migrations, Admin setup, & Server boot
├── superset_config.py     # Application-level logic & security settings
└── .env                   # Environment variables (Credentials & Scaling)

```

### File Explanations

* **`docker-compose.yml`**: Manages the lifecycle of the metadata database, cache, and the Superset application itself.
* **`Dockerfile`**: Defines the custom environment, specifically ensuring that the necessary database drivers are available within the Python virtual environment.
* **`docker-entrypoint.sh`**: Handles the "Cold Start" sequence, ensuring the database is upgraded and an admin user exists before starting the web server.
* **`superset_config.py`**: The primary configuration file that overrides default Superset behaviors, such as security sanitization and caching.

---

## Services Deployed (YAML Breakdown)

Based on the `docker-compose.yml`, three primary services are deployed:

1. **`superset`**: The core application container. It is connected to the external `production` network to communicate with your existing `clickhouse-server`.
2. **`superset-db` (Postgres 15)**: The "Source of Truth" for Superset. It stores all your dashboards, charts, user accounts, and permissions.
3. **`superset-redis` (Redis 7)**: Acts as both a performance cache and a message broker, ensuring high-speed data retrieval and session management.

---

## ClickHouse Driver Installation

The deployment uses an `ensurepip` approach within the `Dockerfile` to inject the driver into the specific virtual environment used by the official Superset image:

* It bootstraps `pip` into the `/app/.venv/bin/python` path.
* It installs `clickhouse-connect==0.10.0`, which allows Superset to translate SQLAlchemy queries into ClickHouse-native SQL.
* It also installs `psycopg2-binary` to facilitate communication with the Postgres metadata store.

---

## Gunicorn Settings & Purpose

To handle production traffic on a 4-core server, Gunicorn is configured in `docker-entrypoint.sh` with the following parameters:

* **`--workers 2`**: Specifies the number of independent processes. We use 2 to ensure we don't starve the CPU, leaving cores available for ClickHouse and Postgres.
* **`--worker-class gthread`**: Enables a threaded worker model. Unlike "sync" workers, threads can handle "I/O wait" (waiting for ClickHouse to return data) without blocking the entire process.
* **`--threads 4`**: Each worker handles 4 threads, providing a total of 8 concurrent request slots.
* **`--preload`**: Loads the application code in the master process before forking workers, which significantly reduces the RAM footprint on your server.
* **`--timeout 300`**: Ensures that long-running data aggregations from ClickHouse don't cause the web server to kill the connection prematurely.

---

## Superset Config Detail (`superset_config.py`)

The configuration file is tailored for a professional dashboard experience:

* **HTML Sanitization (`HTML_SANITIZATION = False`)**: This is the most critical setting for your custom UI. It allows you to use HTML and CSS classes in Markdown components to create your cross-dashboard navigation bar.
* **Allowed Attributes**: We've white-listed `class` and `style` for `<a>`, `<div>`, and `<span>` tags so your CSS templates can target your navigation buttons.
* **Redis Caching**: Configures `CACHE_CONFIG` to point to the Redis service, enabling the "short-term memory" that makes dashboards load instantly for view-only users.
* **Feature Flags**: Enables `DASHBOARD_CROSS_FILTERS` and `EMBEDDED_SUPERSET` to provide an interactive, modern analytics experience.
* **CORS & Headers**: Configured with `X-Frame-Options: ALLOWALL` to ensure that your dashboards can be safely displayed within other parts of your infrastructure if needed.

---

