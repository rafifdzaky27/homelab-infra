#!/usr/bin/env bash
# Weekly restore test: restore the latest snapshot into a throwaway Postgres and compare table counts.
set -euo pipefail
: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${COMPOSE_DIR:?}" "${PG_IMAGE:?}"
WORK="$(mktemp -d)"
NAME="sparky-restore-test"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

set -a; . "$COMPOSE_DIR/.env"; set +a
restic restore latest --tag sparky --target "$WORK"
DUMP="$(find "$WORK" -name sparky.dump | head -n1)"
test -s "$DUMP"

docker run -d --name "$NAME" -e POSTGRES_PASSWORD=restore-test "$PG_IMAGE" >/dev/null
for _ in $(seq 1 30); do docker exec "$NAME" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done
docker exec "$NAME" createdb -U postgres restoretest
docker exec -i "$NAME" pg_restore -U postgres -d restoretest --no-owner --no-privileges < "$DUMP" || true

count() { docker exec "$1" psql -U "$2" -d "$3" -Atc "select count(*) from information_schema.tables where table_schema='public'"; }
LIVE="$(count sparkyfitness-db "$SPARKY_FITNESS_DB_USER" "$SPARKY_FITNESS_DB_NAME")"
REST="$(count "$NAME" postgres restoretest)"
echo "public tables live=$LIVE restored=$REST"
[ "$LIVE" -gt 0 ] && [ "$LIVE" = "$REST" ]
echo "restore test ok"
