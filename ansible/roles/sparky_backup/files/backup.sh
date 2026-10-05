#!/usr/bin/env bash
# SparkyFitness nightly backup: pg_dump + .env -> restic (local), optional offsite copy.
set -euo pipefail
exec 9>/run/lock/sparky-backup.lock
flock -n 9 || { echo "another backup is running"; exit 1; }

: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${COMPOSE_DIR:?}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

set -a; . "$COMPOSE_DIR/.env"; set +a
docker exec sparkyfitness-db pg_dump -U "$SPARKY_FITNESS_DB_USER" -d "$SPARKY_FITNESS_DB_NAME" -Fc > "$STAGE/sparky.dump"
test -s "$STAGE/sparky.dump"
cp "$COMPOSE_DIR/.env" "$STAGE/env"

restic backup "$STAGE" --tag sparky --host srv-fit-01
restic forget --tag sparky --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

if [ -n "${RESTIC_OFFSITE_REPOSITORY:-}" ]; then
  restic copy --from-repo "$RESTIC_REPOSITORY" --from-password-file "$RESTIC_PASSWORD_FILE" \
    -r "$RESTIC_OFFSITE_REPOSITORY" --tag sparky latest
fi
echo "backup ok"
