#!/bin/bash

# User variables - Change these to match your server setup and backup preferences
REMOTE_DB_HOST="255.255.255.255"
REMOTE_DB_PORT="5432"
REMOTE_DB_USER="postgres"
REMOTE_DB_PASSWORD="${REMOTE_DB_PASSWORD:-default}"
REMOTE_DB_NAME="postgres"
BACKUP_FILE="backup_2026-02-17.sql"
DOCKER_IMAGE="postgres:15.8-bookworm"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file '${BACKUP_FILE}' not found."
  exit 1
fi

docker run --rm \
  -v "$(pwd)":/backup \
  --network="host" \
  -e PGPASSWORD="${REMOTE_DB_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h ${REMOTE_DB_HOST} -p ${REMOTE_DB_PORT} -U "${REMOTE_DB_USER}" -d "${REMOTE_DB_NAME}" -f /backup/${BACKUP_FILE}

if [ $? -ne 0 ]; then
  echo "Error: Database restore failed."
  exit 1
fi

echo "Database restore completed successfully."
