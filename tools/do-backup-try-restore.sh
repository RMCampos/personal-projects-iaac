#!/bin/bash

POSTGRES_HOST="localhost"
POSTGRES_USER="user"
POSTGRES_PASSWORD="fill-in-your-password"
POSTGRES_DB="db"
SCHEMA="public"
BACKUP_FILE="backup_2026-02-17.sql"
DOCKER_IMAGE="postgres:15.8-bookworm"
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
  --name ${CONTAINER_NAME} \
  -e POSTGRES_USER=${POSTGRES_USER} \
  -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
  -e POSTGRES_DB=${POSTGRES_DB} \
  -p ${LOCAL_PORT}:5432 \
  ${DOCKER_IMAGE}

# Wait for the database to be ready
until docker exec -it ${CONTAINER_NAME} pg_isready -U "${POSTGRES_USER}" -h localhost -p ${LOCAL_PORT}; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 5
done

echo "PostgreSQL is ready. Starting to restore backup from ${BACKUP_FILE}..."

DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME} 2>/dev/null)

if [ $? -ne 0 ] || [ -z "${DB_IP}" ]; then
  echo "Error: Failed to get container IP address."
  echo "Make sure the container is running and accessible, then try again."
  exit 1
fi

echo "Container IP address: ${DB_IP}"

if [ -f "init.sql" ] && [ -s "init.sql" ]; then
  echo "Init file found. Initializing database..."
  docker run --rm \
  -v "$(pwd)":/backup \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h ${DB_IP} -p ${LOCAL_PORT} -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /backup/init.sql

  if [ $? -ne 0 ]; then
    echo "Error: Database initialization failed."
    exit 1
  fi
else
  echo "Warning: No init file found. Skipping database initialization."
fi

docker run --rm \
  -v "$(pwd)":/backup \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  "${DOCKER_IMAGE}" \
  psql -h ${DB_IP} -p ${LOCAL_PORT} -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /backup/${BACKUP_FILE}

if [ $? -ne 0 ]; then
  echo "Error: Database restore failed."
  exit 1
fi

echo "Database restore completed successfully."
echo "You can connect to the database using the following command:"
echo "psql -h localhost -p ${LOCAL_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "⚠️ Remember to stop the PostgreSQL container after use with: docker stop ${CONTAINER_NAME}"
