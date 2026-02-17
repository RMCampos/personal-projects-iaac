#!/bin/bash

POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_USER="user"
POSTGRES_PASSWORD="fill-in-your-password"
POSTGRES_DB="db"
BACKUP_FILE="backup_2026-02-17.sql"
DOCKER_IMAGE="postgres:15.8-bookworm"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file '${BACKUP_FILE}' not found."
  exit 1
fi

docker run --rm \
  -v "$(pwd)":/backup \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /backup/${BACKUP_FILE}

if [ $? -ne 0 ]; then
  echo "Error: Database restore failed."
  exit 1
fi

echo "Database restore completed successfully."
