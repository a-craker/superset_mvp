#!/bin/sh
set -e

: "${ADMIN_USERNAME:=admin}"
: "${ADMIN_PASSWORD:=admin}"
: "${ADMIN_FIRSTNAME:=Admin}"
: "${ADMIN_LASTNAME:=User}"
: "${ADMIN_EMAIL:=admin@example.com}"

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

exec superset run -h 0.0.0.0 -p 8088