#!/bin/bash

# User variables - Change these to match your server setup and backup preferences
REMOTE_DB_HOST="255.255.255.255"
REMOTE_DB_PORT="5432"
REMOTE_DB_USER="tknt-agent"
REMOTE_DB_PASSWORD="XY5G98pw0aFGJ7MgQ6QS"
REMOTE_DB_NAME="tknt"
SCHEMA="tasknote"
DOCKER_IMAGE="postgres:15.8-bookworm"
SERVICE="tasknote"

# Internal variables - Do not change these unless you know what you're doing
BACKUP_FILE="./${SERVICE}_backup_$(date +%Y-%m-%d_%H%M%S).sql"

echo "Backing up database ${REMOTE_DB_NAME} from host ${REMOTE_DB_HOST} with user ${REMOTE_DB_USER}..."

docker run --rm \
  -e PGPASSWORD="${REMOTE_DB_PASSWORD}" \
  --network="host" \
  "${DOCKER_IMAGE}" \
  pg_dump -h "${REMOTE_DB_HOST}" -p "${REMOTE_DB_PORT}" -U "${REMOTE_DB_USER}" -d "${REMOTE_DB_NAME}" \
  --data-only --schema="${SCHEMA}" --inserts --no-comments \
  --on-conflict-do-nothing > "${BACKUP_FILE}"

if [ $? -ne 0 ]; then
  echo "Error: Backup failed."
  exit 1
fi

echo "Backup completed successfully. The backup file is located at ${BACKUP_FILE}"
echo "File size: $(du -h "${BACKUP_FILE}" | cut -f1)"
