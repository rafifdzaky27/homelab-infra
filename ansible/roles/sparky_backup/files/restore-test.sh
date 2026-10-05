#!/usr/bin/env bash
# Weekly restore test: restore the latest snapshot into a throwaway Postgres and compare table counts.
set -euo pipefail
: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${DB_USER:?}" "${DB_NAME:?}" "${PG_IMAGE:?}"
WORK="$(mktemp -d)"
NAME="sparky-restore-test"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
docker rm -f "$NAME" >/dev/null 2>&1 || true

restic restore latest --tag sparky --host srv-fit-01 --target "$WORK"
DUMP="$(find "$WORK" -name sparky.dump | head -n1)"
test -s "$DUMP"
test -s "$(dirname "$DUMP")/env"

docker run -d --name "$NAME" -e POSTGRES_PASSWORD=restore-test "$PG_IMAGE" >/dev/null
for _ in $(seq 1 30); do docker exec "$NAME" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done
docker exec "$NAME" createdb -U postgres restoretest
# Role grants for the app user do not exist in the throwaway DB; --no-owner/--no-privileges skips them.
docker exec -i "$NAME" pg_restore -U postgres -d restoretest --no-owner --no-privileges < "$DUMP" || true

count() { docker exec "$1" psql -U "$2" -d "$3" -Atc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema')"; }
LIVE="$(count sparkyfitness-db "$DB_USER" "$DB_NAME")"
REST="$(count "$NAME" postgres restoretest)"
echo "tables live=$LIVE restored=$REST"
[ "$LIVE" -gt 0 ] && [ "$LIVE" = "$REST" ]
echo "restore test ok"
