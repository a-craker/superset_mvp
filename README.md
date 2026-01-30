
---

# Superset ClickHouse MVP

This repository contains a lightweight, containerized **Apache Superset** deployment. It features a custom build process to bypass internal environment limitations and includes the **ClickHouse** driver pre-installed.

## Project Structure

```text
.
├── Dockerfile               # Bootstraps pip and installs ClickHouse drivers
├── docker-compose.yml       # MVP Orchestration (Standalone)
├── docker-entrypoint.sh     # Automates DB migrations and Admin setup
└── .env                     # (Local only) Environment secrets

```

---

## Tech Stack

* **Base Image**: `apache/superset:latest`
* **Database Driver**: `clickhouse-connect`
* **Metadata Store**: Internal SQLite (standard for MVP/Testing) -- for production use separate postgres instance
* **Network**: Uses an external network named `production` to communicate with data sources.

---

## Quick Start

### 1. Network Preparation

This setup expects an external Docker network called `production` to already exist. If it doesn't, create it:

```bash
docker network create production

```

### 2. Configure Environment Variables

Create a `.env` file in the root directory. You must define a secret key for Superset to start:

```bash
# save the following credentials in .env
ADMIN_USERNAME=
ADMIN_PASSWORD=
ADMIN_FIRSTNAME=
ADMIN_LASTNAME=

```

### 3. Build and Deploy

```bash
docker compose up -d --build

```

The application will be accessible at:

`http://<your-server-ip>:8088`

---

## Connecting to ClickHouse

Once the UI is running, you can connect to your ClickHouse instance via **Settings > Data: Database Connections**. Use the following SQLAlchemy URI format:

```text
clickhousedb://{username}:{password}@{hostname}:{port}/{database}

```

*Note: Since the container is on the `production` network, use the service name of your ClickHouse container as the hostname if it is also running in Docker.*

---

## Custom Implementation Details

### The Dockerfile Fix

The official Superset image uses a virtual environment at `/app/.venv` that is missing `pip`. This build:

1. **Bootstraps `pip**` into the `/app/.venv` using `ensurepip`.
2. **Installs `clickhouse-connect**` directly into that specific virtual environment.
3. **Permissions**: Grants root access briefly to set up the entrypoint script.

### Data Persistence

Dashboard and user metadata are stored in the `superset_home` Docker volume. This ensures your work is not lost when the container is restarted or updated.

---

### Note on Production

There is a `/production` subdirectory containing a multi-container stack (Postgres, Redis, Celery Workers). That setup is intended for scaling and is currently independent of this MVP setup.

---