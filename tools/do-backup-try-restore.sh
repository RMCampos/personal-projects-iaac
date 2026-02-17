#!/bin/bash

# User variables - Change these to match your PostgreSQL setup and backup file
BACKUP_FILE="tasknote_backup_2026-02-17_180023.sql"
DOCKER_IMAGE="postgres:15.8-bookworm"

# Internal variables - Do not change these unless you know what you're doing
POSTGRES_HOST="localhost"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="default"
POSTGRES_DB="postgres"
CONTAINER_NAME="tmp-backup-db"

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Error: Backup file '${BACKUP_FILE}' not found."
  exit 1
fi

LOCAL_PORT="5432"
# if port is in use, find an available one
while lsof -i :${LOCAL_PORT} >/dev/null 2>&1; do
  echo "Port ${LOCAL_PORT} is in use. Trying next port..."
  LOCAL_PORT=$((LOCAL_PORT + 1))
done

echo "Using local port ${LOCAL_PORT} for PostgreSQL container."

# Start empty postgres DB with docker
docker run --rm -d \
  --name "${CONTAINER_NAME}" \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  -e POSTGRES_DB="${POSTGRES_DB}" \
  -p 127.0.0.1:"${LOCAL_PORT}":5432 \
  "${DOCKER_IMAGE}"

# Wait for the database to be ready
until docker exec -it "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}"; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 5
done

echo "PostgreSQL is ready. Starting to restore backup from ${BACKUP_FILE}..."

if [ -f "init.sql" ] && [ -s "init.sql" ]; then
  echo "Init file found. Initializing database..."
  docker run --rm \
  --network="host" \
  -v "$(pwd)":/backup \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h 127.0.0.1 -p "${LOCAL_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /backup/init.sql

  if [ $? -ne 0 ]; then
    echo "Error: Database initialization failed."
    exit 1
  fi
else
  echo "Warning: No init file found. Skipping database initialization."
fi

docker run --rm \
  --network="host" \
  -v "$(pwd)":/backup \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h 127.0.0.1 -p "${LOCAL_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f "/backup/${BACKUP_FILE}"

if [ $? -ne 0 ]; then
  echo "Error: Database restore failed."
  exit 1
fi

echo "Database restore completed successfully."
echo "You can connect to the database using the following command:"
echo "psql -h 127.0.0.1 -p ${LOCAL_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "⚠️ Remember to stop the PostgreSQL container after use with: docker stop ${CONTAINER_NAME}"
