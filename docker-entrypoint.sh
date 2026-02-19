#!/bin/sh
set -e

# Defaults for admin user
: "${ADMIN_USERNAME:=admin}"
: "${ADMIN_PASSWORD:=admin}"
: "${ADMIN_FIRSTNAME:=Admin}"
: "${ADMIN_LASTNAME:=User}"
: "${ADMIN_EMAIL:=admin@example.com}"

echo "Running database migrations..."
superset db upgrade

# Create admin if it doesn't exist
if ! superset fab list-users | grep -q "${ADMIN_USERNAME}"; then
  echo "Creating admin user..."
  superset fab create-admin \
    --username "${ADMIN_USERNAME}" \
    --firstname "${ADMIN_FIRSTNAME}" \
    --lastname "${ADMIN_LASTNAME}" \
    --email "${ADMIN_EMAIL}" \
    --password "${ADMIN_PASSWORD}"
fi

echo "Initializing Superset..."
superset init

echo "Starting Gunicorn (Production Mode - Threaded)..."
# Using 2 workers + 4 threads = 8 concurrent connections, ideal for 4 cores. -- RESOURCE SPECIFIC
exec gunicorn \
  --bind "0.0.0.0:8088" \
  --workers ${SUPERSET_WORKERS:-2} \
  --worker-class gthread \
  --threads 4 \
  --timeout ${SUPERSET_TIMEOUT:-300} \
  --limit-request-line 0 \
  --limit-request-field_size 0 \
  --preload \
  "superset.app:create_app()"