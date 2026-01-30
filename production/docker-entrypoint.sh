#!/bin/sh
set -e

ROLE="${SUPERSET_ROLE:-web}"

if [ "$ROLE" = "web" ]; then
  superset db upgrade

  if ! superset fab list-users | grep -q "${ADMIN_USERNAME}"; then
    superset fab create-admin \
      --username "${ADMIN_USERNAME}" \
      --firstname "${ADMIN_FIRSTNAME}" \
      --lastname "${ADMIN_LASTNAME}" \
      --email "${ADMIN_EMAIL}" \
      --password "${ADMIN_PASSWORD}"
  fi

  superset init

  exec gunicorn \
    --bind 0.0.0.0:8088 \
    --workers 4 \
    --threads 8 \
    --timeout 120 \
    'superset.app:create_app()'
fi

if [ "$ROLE" = "worker" ]; then
  exec celery --app=superset.tasks.celery_app:app worker
fi

if [ "$ROLE" = "beat" ]; then
  exec celery --app=superset.tasks.celery_app:app beat
fi

echo "Unknown SUPERSET_ROLE: $ROLE"
exit 1
