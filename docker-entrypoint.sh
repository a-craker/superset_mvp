#!/bin/sh
set -e

ROLE="${SUPERSET_ROLE:-web}"

: "${ADMIN_USERNAME:=admin}"
: "${ADMIN_PASSWORD:=admin}"
: "${ADMIN_FIRSTNAME:=Admin}"
: "${ADMIN_LASTNAME:=User}"
: "${ADMIN_EMAIL:=admin@example.com}"

if [ "$ROLE" = "web" ]; then
  echo "Running database migrations..."
  superset db upgrade

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

  echo "Starting Gunicorn..."
  exec gunicorn \
    --bind "0.0.0.0:8088" \
    --workers ${SUPERSET_WORKERS:-4} \
    --worker-class sync \
    --timeout ${SUPERSET_TIMEOUT:-300} \
    --limit-request-line 0 \
    --limit-request-field_size 0 \
    "superset.app:create_app()"
fi

if [ "$ROLE" = "worker" ]; then
  echo "Starting Celery worker..."
  exec celery --app superset.tasks.celery_app:app worker \
    --loglevel INFO \
    --concurrency ${CELERY_WORKER_CONCURRENCY:-2}
fi

if [ "$ROLE" = "beat" ]; then
  echo "Starting Celery beat..."
  exec celery \
    --app superset.tasks.celery_app:app beat \
    --loglevel INFO \
    --schedule /app/superset_home/celerybeat-schedule
fi

echo "Unknown SUPERSET_ROLE: $ROLE (expected web|worker|beat)"
exit 1