#!/usr/bin/env bash
# deep-fetch checks: the No-Site-Name gate and the engine tests in engine/tests/.
# A few tests (test_smoke.py) make real requests to example.com and httpbin.org.
# Engine state goes to a temporary folder that is removed on exit, so the checks
# never write into the skill folder or the user's real deep-fetch state.
# Exit 0 = every check passed. bash 3.2 compatible.
set -u

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SKILL_DIR" || exit 1
. "$SKILL_DIR/scripts/python.sh"
pick_python || exit 1

STATE_TMP="$(mktemp -d -t deep-fetch-smoke)" || exit 1
trap 'rm -rf "$STATE_TMP"' EXIT
export INSANE_OBSERVATIONS_DIR="$STATE_TMP/observations"
export INSANE_LEARNED_PATH="$STATE_TMP/learned.json"
export INSANE_NODE_DEPS_DIR="${INSANE_NODE_DEPS_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/deep-fetch/node}"
export PYTHONPATH="$SKILL_DIR${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONDONTWRITEBYTECODE=1

FAILED=""
run() {  # $1 = label, rest = command
  label="$1"; shift
  if "$@"; then
    printf 'PASS %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
    FAILED="${FAILED:+$FAILED }$label"
  fi
}

run bias_check "$PY" engine/bias_check.py
for t in engine/tests/test_*.py; do
  run "$(basename "$t" .py)" "$PY" "$t"
done

if [ -n "$FAILED" ]; then
  printf 'smoke: failed: %s\n' "$FAILED"
  exit 1
fi
printf 'smoke: all checks passed\n'
