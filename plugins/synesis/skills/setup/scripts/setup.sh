#!/usr/bin/env bash
# synesis setup — checks the dependencies of the bundled deep-fetch skill, and records
# the user's notes folder in ${XDG_CONFIG_HOME:-$HOME/.config}/synesis/config.json.
#
# Exit codes: 0 = done, 2 = waiting on user confirmation (not a failure), 1 = fatal.
# bash 3.2 compatible: no empty-array expansion, no `declare -A`, no ${var,,},
# no mapfile, no `&>>`, no `**`. `set -e` is deliberately NOT used so that every
# failure can print its own [fail] line before the script decides what to do.

set -uo pipefail

# --- globals -----------------------------------------------------------------
# Every global that can be read before being assigned on ANY path lives here,
# and this block runs before argument parsing.
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # root of this setup skill
SKIP_DEPS=0            # --skip-deps
ALLOW_USER_SITE=0      # --allow-user-site
CREATE_VAULT=0         # --create-vault (approval to create a missing folder)
CREATE_PENDING=0       # 1 = waiting on create-dir approval -> do not write config
VAULT=""               # raw --vault argument
VAULT_ABS=""           # normalized absolute path (regardless of existence)
PENDING=""             # comma-joined confirmation queue (string, never an array)
DEPS_STATE=pending     # ok | skipped | pending
BOOT=""                # deep-fetch bootstrap.sh path
DEPS_PY=""             # interpreter that bootstrap.sh installs into
CONFIG_DIR=""; CONFIG=""

# --- reporting helpers -------------------------------------------------------
ok()   { printf '[ok] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*"; }
skip() { printf '[skip] %s\n' "$*"; }
fail() { printf '[fail] %s\n' "$*"; }
die()  { fail "$*"; printf 'summary: setup failed — %s\n' "$*"; exit 1; }
need() { PENDING="${PENDING:+$PENDING, }$1"; printf 'NEEDS_CONFIRMATION: %s\n' "$1"; }

usage() { cat <<USAGE
Usage: bash "$SETUP_DIR/scripts/setup.sh" [--vault <path>] [--create-vault] [--allow-user-site] [--skip-deps] [--help]
  --vault <path>       확인된 노트 폴더를 config에 기록한다 (이 인자 없이는 기록하지 않는다)
                       Obsidian vault든 아니든 상관없다. Obsidian은 선택 사항이다.
  --create-vault       --vault 경로가 없으면 만든다 (이 인자 없이는 만들지 않는다)
  --allow-user-site    PEP 668 externally-managed python에서 user-site 설치를 승인한다
  --skip-deps          deep-fetch 의존성 단계를 건너뛴다 (config에 deps: "skipped" 기록)
Exit codes: 0 = 완료, 2 = 사용자 확인 대기(실패 아님), 1 = 치명 실패
USAGE
}

# --- argument parsing --------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --vault)
      if [ $# -lt 2 ]; then
        printf '%s\n' "--vault requires a path" >&2
        usage >&2
        exit 1
      fi
      VAULT="$2"; shift 2 ;;
    --allow-user-site) ALLOW_USER_SITE=1; shift ;;
    --skip-deps)       SKIP_DEPS=1; shift ;;
    --create-vault)    CREATE_VAULT=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1 ;;
  esac
done

# Path normalization. Existence is NOT judged here — a missing path is a valid
# input (AC-8b); the vault step below decides what to do with it.
if [ -n "$VAULT" ]; then
  case "$VAULT" in
    "~")   VAULT="$HOME" ;;
    "~/"*) VAULT="$HOME/${VAULT#\~/}" ;;
  esac
  VAULT_ABS=$(python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$VAULT") \
    || die "cannot normalize --vault path: $VAULT"
fi

# --- step: dependencies ------------------------------------------------------
# deep-fetch is a sibling skill in this plugin; its bootstrap.sh checks and installs
# the Python packages it needs and picks the interpreter (Python 3.10+) to use.
BOOT="${SYNESIS_BOOTSTRAP:-$SETUP_DIR/../deep-fetch/scripts/bootstrap.sh}"
[ -f "$BOOT" ] || die "deep-fetch bootstrap.sh not found at $BOOT"

python_externally_managed() {
  # The seam only forces the RESTRICTIVE direction; any other value is ignored.
  [ "${SYNESIS_PYTHON_EXTERNALLY_MANAGED:-}" = 1 ] && return 0
  "$DEPS_PY" -c "import sysconfig,os,sys; sys.exit(0 if os.path.exists(os.path.join(sysconfig.get_path('stdlib'),'EXTERNALLY-MANAGED')) else 1)"
}

if [ "$SKIP_DEPS" = 1 ]; then                                          # (0) explicitly skipped
  warn "dependency setup skipped by user (--skip-deps); run manually: PIP_BREAK_SYSTEM_PACKAGES=1 bash \"$BOOT\" --install"
  DEPS_STATE=skipped
elif ! DEPS_PY=$(bash "$BOOT" --print-python 2>&1); then               # no usable interpreter
  printf '%s\n' "$DEPS_PY" | sed 's/^/    /'
  die "deep-fetch needs Python 3.10 or newer. Install one, or rerun with --skip-deps"
elif check_out=$(bash "$BOOT" 2>&1); then                              # (a) already satisfied
  skip "deep-fetch dependencies already satisfied"
  DEPS_STATE=ok
elif python_externally_managed && [ "$ALLOW_USER_SITE" != 1 ]; then    # (b) approval needed — no install
  printf '%s\n' "$check_out" | sed 's/^/    /'
  USER_SITE=$("$DEPS_PY" -m site --user-site 2>/dev/null)
  warn "$DEPS_PY is PEP 668 externally-managed; not installing without approval"
  warn "approval installs curl_cffi, beautifulsoup4, pyyaml, pypdf, markdownify into user-site ${USER_SITE:-<unresolved>}; Homebrew site-packages are untouched"
  need deps                                                            # DEPS_STATE stays pending
else                                                                   # (c) install
  printf '%s\n' "$check_out" | sed 's/^/    /'
  ok "installing deep-fetch dependencies (may take a few minutes)"
  TMP=$(mktemp -t synesis-bootstrap) || die "cannot create temp file"
  if [ "$ALLOW_USER_SITE" = 1 ]; then
    PIP_BREAK_SYSTEM_PACKAGES=1 bash "$BOOT" --install 2>&1 | tee "$TMP"; rc=${PIPESTATUS[0]}
  else
    bash "$BOOT" --install 2>&1 | tee "$TMP"; rc=${PIPESTATUS[0]}      # no guard bypass
  fi
  if [ "$rc" -eq 0 ]; then ok "deep-fetch dependencies installed"; DEPS_STATE=ok; rm -f "$TMP"
  else sed 's/^/    /' "$TMP"; die "bootstrap.sh --install failed"; fi
fi

# --- step: Obsidian detection (optional, never fatal) ------------------------
OBS_APP="${SYNESIS_OBSIDIAN_APP:-/Applications/Obsidian.app}"
OBS_JSON="${SYNESIS_OBSIDIAN_JSON:-$HOME/Library/Application Support/obsidian/obsidian.json}"
if [ -d "$OBS_APP" ] || [ -f "$OBS_JSON" ]; then ok "Obsidian installed"
else warn "Obsidian not found. Install from https://obsidian.md"; fi

# --- step: vault candidates --------------------------------------------------
candidates=$(python3 - "$OBS_JSON" <<'PY'
import json, os, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)                      # missing or corrupt file -> zero candidates
for v in (d.get("vaults") or {}).values():
    p = v.get("path")
    if p and os.path.isdir(p): print(p)
PY
)
while IFS= read -r cline; do
  [ -n "$cline" ] && printf 'candidate: %s\n' "$cline"
done <<< "$candidates"

# --- step: vault decision ----------------------------------------------------
resolve_dir() {                    # $1 = path. stdout = physical path; stderr = indented shell error
  local p="$1" out
  if out=$(cd "$p" 2>&1 && pwd -P); then printf '%s\n' "$out"; return 0; fi
  printf '%s\n' "$out" | sed 's/^/    /' >&2
  return 1
}

if [ -z "$VAULT" ]; then
  need vault
  printf 'NEEDS_VAULT_CONFIRMATION\n'
else
  if [ -d "$VAULT_ABS" ]; then                                 # (1) a directory -> record it
    vault_try="$VAULT_ABS"
    VAULT_ABS=$(resolve_dir "$vault_try") || die "cannot enter notes folder: $vault_try"
  elif [ -e "$VAULT_ABS" ]; then                               # (2) exists but not a directory
    die "--vault path exists but is not a directory: $VAULT_ABS"
  elif [ "$CREATE_VAULT" = 1 ]; then                           # (3a) missing + approved -> create
    mkerr=$(mkdir -p "$VAULT_ABS" 2>&1) || { printf '%s\n' "$mkerr" | sed 's/^/    /'
                                             die "cannot create notes folder: $VAULT_ABS"; }
    vault_try="$VAULT_ABS"
    VAULT_ABS=$(resolve_dir "$vault_try") || die "cannot enter notes folder: $vault_try"
    ok "created notes folder: $VAULT_ABS"                      # after resolution: printed == recorded
  else                                                         # (3b) missing + not approved -> ask
    warn "notes folder does not exist yet: $VAULT_ABS"
    parent=$(dirname "$VAULT_ABS"); parent_real=$(cd "$parent" 2>/dev/null && pwd -P) || parent_real="$parent"
    printf 'NEEDS_CONFIRMATION: create-dir %s (parent: %s)\n' "$VAULT_ABS" "$parent_real"
    PENDING="${PENDING:+$PENDING, }create-dir"
    CREATE_PENDING=1
  fi

  if [ "$CREATE_PENDING" != 1 ]; then
    BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$BASE" in /*) ;; *) warn "XDG_CONFIG_HOME is not absolute; falling back to \$HOME/.config"; BASE="$HOME/.config" ;; esac
    CONFIG_DIR="$BASE/synesis"; CONFIG="$CONFIG_DIR/config.json"
    mkdir -p "$CONFIG_DIR" || die "cannot create $CONFIG_DIR"
    res=$(python3 - "$CONFIG" "$VAULT_ABS" "$DEPS_STATE" <<'PY'
import json, os, sys, time, tempfile
cfg, vault, deps = sys.argv[1], sys.argv[2], sys.argv[3]
data, notes = {}, []
if os.path.exists(cfg):
    try:
        loaded = json.load(open(cfg))
    except Exception:
        loaded = None
    if isinstance(loaded, dict):
        data = loaded
    else:                                  # corrupt or non-dict: back it up, never swallow
        bak = "%s.bak-%d" % (cfg, int(time.time()))
        os.replace(cfg, bak); notes.append("BACKED_UP %s" % bak)
notes.append("unchanged" if data.get("vault") == vault else "written")
data["vault"], data["deps"] = vault, deps        # deps: "ok" | "skipped" | "pending"
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(cfg))
with os.fdopen(fd, "w") as f:
    json.dump(data, f, indent=2); f.write("\n")
os.replace(tmp, cfg); print("\n".join(notes))
PY
) || die "failed to write config"
    if printf '%s\n' "$res" | grep -q '^BACKED_UP '; then
      bak_path=$(printf '%s\n' "$res" | sed -n 's/^BACKED_UP //p')
      warn "existing config was unreadable; backed up to $bak_path"
    fi
    if printf '%s\n' "$res" | grep -q '^unchanged$'; then
      skip "vault already set to $VAULT_ABS"
    else
      ok "vault recorded: $VAULT_ABS"
    fi
  fi
fi

# --- termination -------------------------------------------------------------
if [ -n "$PENDING" ]; then
  printf 'summary: setup paused, waiting on your answer for: %s. Nothing failed; the remaining steps succeeded.\n' "$PENDING"
  exit 2
fi
printf 'summary: setup complete (vault: %s)\n' "$VAULT_ABS"
exit 0
