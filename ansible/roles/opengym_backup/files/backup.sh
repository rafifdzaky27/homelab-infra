#!/usr/bin/env bash
# openGym nightly backup: data/ -> restic (local), optional offsite copy.
# data/ is the whole instance: db.json, state-<uid>.json, secret, vapid.json, audit.log, uploads/.
# The api writes every file through tmp + rename, so each file in the snapshot is whole.
set -euo pipefail
exec 9>/run/lock/opengym-backup.lock
flock -n 9 || { echo "another backup is running"; exit 1; }

: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${DATA_DIR:?}"
test -s "$DATA_DIR/db.json"

restic backup "$DATA_DIR" --tag opengym --host srv-gym-01 --exclude '*.tmp'
restic forget --tag opengym --host srv-gym-01 --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

if [ -n "${RESTIC_OFFSITE_REPOSITORY:-}" ]; then
  restic -r "$RESTIC_OFFSITE_REPOSITORY" copy --from-repo "$RESTIC_REPOSITORY" \
    --from-password-file "$RESTIC_PASSWORD_FILE" --tag opengym latest
fi
echo "backup ok"
