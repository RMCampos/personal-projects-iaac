#!/bin/bash

POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_USER="user"
POSTGRES_PASSWORD="fill-in-your-password"
POSTGRES_DB="db"
SCHEMA="public"
BACKUP_FILE="./backup_$(date +%Y-%m-%d).sql"
DOCKER_IMAGE="postgres:15.8-bookworm"
CONTAINER_NAME="db"

echo "Backing up database ${POSTGRES_DB} from host ${POSTGRES_HOST} with user ${POSTGRES_USER}..."

docker run --rm \
  -e PGPASSWORD="${POSTGRES_PASSWORD}" \
  ${DOCKER_IMAGE} \
  pg_dump -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d ${POSTGRES_DB} \
  --data-only --schema=${SCHEMA} --inserts --no-comments \
  --on-conflict-do-nothing > ${BACKUP_FILE}

if [ $? -ne 0 ]; then
  echo "Error: Backup failed."
  exit 1
fi

echo "Backup completed successfully. The backup file is located at ${BACKUP_FILE}"
echo "File size: $(du -h ${BACKUP_FILE} | cut -f1)"
