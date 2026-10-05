#!/usr/bin/env bash
# Weekly restore test: restore the latest snapshot to a temp dir, check every JSON file parses
# and the profile and state-file counts match the live instance.
set -euo pipefail
: "${RESTIC_REPOSITORY:?}" "${RESTIC_PASSWORD_FILE:?}" "${DATA_DIR:?}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

restic restore latest --tag opengym --host srv-gym-01 --target "$WORK"
REST="$WORK$DATA_DIR"
test -s "$REST/db.json"
test -s "$REST/secret"

python3 - "$DATA_DIR" "$REST" <<'PY'
import json, pathlib, sys
live, rest = map(pathlib.Path, sys.argv[1:])
for f in rest.glob("*.json"):
    json.loads(f.read_text())          # raises on a truncated or corrupt file
users = lambda d: len(json.loads((d / "db.json").read_text()).get("users", []))
states = lambda d: len(list(d.glob("state-*.json")))
print(f"users live={users(live)} restored={users(rest)} states live={states(live)} restored={states(rest)}")
assert users(rest) == users(live) and states(rest) == states(live), "count mismatch"
PY
echo "restore test ok"
