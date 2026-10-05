#!/usr/bin/env bash
# SparkyFitness nightly backup: pg_dump + .env -> restic (local), optional offsite copy.
set -euo pipefail
exec 9>/run/lock/sparky-backup.lock
flock -n 9 || { echo "another backup is running"; exit 1; }

: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${COMPOSE_DIR:?}" "${STAGE_DIR:?}" "${DB_USER:?}" "${DB_NAME:?}"
# Fixed staging path: restic forget groups snapshots by path, so a random temp dir would never prune.
find "$STAGE_DIR" -mindepth 1 -delete
trap 'find "$STAGE_DIR" -mindepth 1 -delete' EXIT

docker exec sparkyfitness-db pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$STAGE_DIR/sparky.dump"
test -s "$STAGE_DIR/sparky.dump"
# .env holds BETTER_AUTH_SECRET and the API encryption key; both are needed for a real restore.
cp "$COMPOSE_DIR/.env" "$STAGE_DIR/env"

restic backup "$STAGE_DIR" --tag sparky --host srv-fit-01
restic forget --tag sparky --host srv-fit-01 --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

if [ -n "${RESTIC_OFFSITE_REPOSITORY:-}" ]; then
  restic -r "$RESTIC_OFFSITE_REPOSITORY" copy --from-repo "$RESTIC_REPOSITORY" \
    --from-password-file "$RESTIC_PASSWORD_FILE" --tag sparky latest
fi
echo "backup ok"
