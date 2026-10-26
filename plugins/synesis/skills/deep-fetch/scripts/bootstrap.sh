#!/usr/bin/env bash
# deep-fetch dependency check and install.
#
#   bash scripts/bootstrap.sh                check only. Exit 0 = Python packages ready,
#                                            1 = something is missing (nothing installed).
#   bash scripts/bootstrap.sh --install      install the missing Python packages with pip
#                                            (--user outside a virtualenv), then the Node
#                                            packages for the browser fallback when node
#                                            and npm exist. Exit 0 = done.
#   bash scripts/bootstrap.sh --print-python print the interpreter that run.sh and
#                                            --install use. Exit 1 = none fits.
#
# The interpreter comes from scripts/python.sh (Python 3.10+, DEEP_FETCH_PYTHON wins).
# Node is optional: without it only the local browser fallback is unavailable, so a
# missing node or npm is reported but never fails the check.
# The PEP 668 decision belongs to the caller: export PIP_BREAK_SYSTEM_PACKAGES=1 to
# allow a user-site install into an externally-managed Python.
# bash 3.2 compatible: no arrays, no [[ ]], `set -e` deliberately not used.
set -u

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/deep-fetch"
NODE_DEPS_DIR="${INSANE_NODE_DEPS_DIR:-$STATE_DIR/node}"
. "$SKILL_DIR/scripts/python.sh"

MODE=check
case "${1:-}" in
  "")             ;;
  --install)      MODE=install ;;
  --print-python) MODE=print ;;
  *) printf 'bootstrap: unknown argument: %s\n' "$1" >&2; exit 64 ;;
esac

if ! pick_python 2>/dev/null; then
  pick_python 2>&1 | sed 's/^deep-fetch: /bootstrap: /'
  exit 1
fi

if [ "$MODE" = print ]; then
  command -v "$PY"
  exit 0
fi

# Prints the pip specs that are missing or too old, space separated (empty = ready).
missing_python() {
  "$PY" - <<'PY'
import importlib
specs = (("curl_cffi", "curl_cffi>=0.15.0"), ("bs4", "beautifulsoup4"),
         ("yaml", "pyyaml"), ("pypdf", "pypdf"), ("markdownify", "markdownify"))
missing = []
for module, spec in specs:
    try:
        mod = importlib.import_module(module)
    except Exception:
        missing.append(spec)
        continue
    if module == "curl_cffi":
        try:
            version = tuple(int(x) for x in mod.__version__.split(".")[:2])
        except Exception:
            version = (0, 0)
        if version < (0, 15):
            missing.append(spec)
print(" ".join(missing))
PY
}

node_ready() { command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; }

MISSING=$(missing_python) || { printf 'bootstrap: %s failed while checking packages\n' "$PY"; exit 1; }

if [ -z "$MISSING" ]; then
  node_ready || printf 'bootstrap: note: node or npm is missing; the local browser fallback stays unavailable\n'
  printf 'bootstrap: Python prerequisites look available (%s)\n' "$(command -v "$PY")"
  exit 0
fi

printf 'bootstrap: missing prerequisites detected (%s)\n' "$(command -v "$PY")"
printf '  python packages: %s\n' "$MISSING"

if [ "$MODE" != install ]; then
  printf 'bootstrap: rerun with --install to install them\n'
  exit 1
fi

USER_FLAG="--user"
if "$PY" -c 'import sys; sys.exit(0 if sys.prefix != sys.base_prefix else 1)'; then
  USER_FLAG=""                                     # inside a virtualenv: --user is refused
fi
# $MISSING and $USER_FLAG are intentionally unquoted: word splitting yields one
# argument per package spec, and an empty USER_FLAG disappears.
# shellcheck disable=SC2086
"$PY" -m pip install $USER_FLAG -U $MISSING || { printf 'bootstrap: pip install failed\n'; exit 1; }

STILL=$(missing_python)
if [ -n "$STILL" ]; then
  printf 'bootstrap: still missing after install: %s\n' "$STILL"
  exit 1
fi

if node_ready; then
  # The engine also installs these on its first browser fallback; doing it here
  # avoids that delay. System Chrome is used (channel: chrome), so no bundled browser.
  mkdir -p "$NODE_DEPS_DIR" \
    && cp "$SKILL_DIR/engine/templates/package.json" "$NODE_DEPS_DIR/" \
    && (cd "$NODE_DEPS_DIR" && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --no-audit --no-fund) \
    || printf 'bootstrap: warning: Node packages for the browser fallback were not installed\n'
else
  printf 'bootstrap: note: node or npm is missing; skipped the browser fallback packages\n'
fi

printf 'bootstrap: install step completed\n'
exit 0
