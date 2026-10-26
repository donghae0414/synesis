# Sourced by run.sh and bootstrap.sh. The engine needs Python 3.10 or newer, and on
# macOS the first `python3` in PATH is often Apple's 3.9.
# pick_python sets PY to the interpreter to use and returns 0, or prints why none
# fits to stderr and returns 1. DEEP_FETCH_PYTHON, when set, is the only candidate.
# bash 3.2 compatible.

python_ok() { "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; }

pick_python() {
  PY=""
  if [ -n "${DEEP_FETCH_PYTHON:-}" ]; then
    if python_ok "$DEEP_FETCH_PYTHON"; then PY="$DEEP_FETCH_PYTHON"; return 0; fi
    printf 'deep-fetch: DEEP_FETCH_PYTHON=%s is not a runnable Python 3.10 or newer\n' "$DEEP_FETCH_PYTHON" >&2
    return 1
  fi
  for cand in python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
    command -v "$cand" >/dev/null 2>&1 || continue
    if python_ok "$cand"; then PY="$cand"; return 0; fi
  done
  printf 'deep-fetch: Python 3.10 or newer not found (python3 is %s). Install one, for example `brew install python`, or set DEEP_FETCH_PYTHON.\n' \
    "$(python3 -c 'import sys; print(sys.version.split()[0])' 2>/dev/null || echo missing)" >&2
  return 1
}
