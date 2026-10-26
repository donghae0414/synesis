#!/usr/bin/env bash
# deep-fetch entry point. Runs the engine from this skill directory and keeps the
# engine's runtime state (observation logs, per-host learning, Node packages) in
# ${XDG_STATE_HOME:-$HOME/.local/state}/deep-fetch, outside the plugin tree, so a
# plugin update neither loses that state nor ships it.
#
#   bash scripts/run.sh "<URL>" [engine options]           -> python3 -m engine
#   bash scripts/run.sh --module engine.x_search "<query>"  -> python3 -m engine.x_search
#
# An INSANE_* variable that is already set wins over these defaults. The interpreter
# is chosen by scripts/python.sh (Python 3.10+, DEEP_FETCH_PYTHON overrides).
# bash 3.2 compatible.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$SKILL_DIR/scripts/python.sh"
pick_python || exit 1
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/deep-fetch"

export INSANE_OBSERVATIONS_DIR="${INSANE_OBSERVATIONS_DIR:-$STATE_DIR/observations}"
export INSANE_LEARNED_PATH="${INSANE_LEARNED_PATH:-$STATE_DIR/learned.json}"
export INSANE_NODE_DEPS_DIR="${INSANE_NODE_DEPS_DIR:-$STATE_DIR/node}"

MODULE=engine
if [ "${1:-}" = "--module" ]; then
  if [ $# -lt 2 ]; then
    printf 'run.sh: --module needs a module name (for example engine.x_search)\n' >&2
    exit 64
  fi
  MODULE="$2"
  shift 2
fi

cd "$SKILL_DIR"
exec "$PY" -m "$MODULE" "$@"
