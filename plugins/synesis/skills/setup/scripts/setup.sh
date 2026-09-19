#!/usr/bin/env bash
# synesis setup — installs insane-search, checks its dependencies, and records
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
CODEX="${SYNESIS_CODEX_BIN:-codex}"
SKIP_DEPS=0            # --skip-deps
ALLOW_USER_SITE=0      # --allow-user-site
CREATE_VAULT=0         # --create-vault (approval to create a missing folder)
CREATE_PENDING=0       # 1 = waiting on create-dir approval -> do not write config
VAULT=""               # raw --vault argument
VAULT_ABS=""           # normalized absolute path (regardless of existence)
PENDING=""             # comma-joined confirmation queue (string, never an array)
DEPS_STATE=pending     # ok | skipped | pending
INSANE_DIR=""          # insane-search skill directory
BOOT=""                # bootstrap.sh path
VER=""; SRC=""         # plugin_probe results
CONFIG_DIR=""; CONFIG=""
MANUAL="Run manually: codex plugin add insane-search-codex@gptaku-codex"

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
  --skip-deps          insane-search 의존성 단계를 건너뛴다 (config에 deps: "skipped" 기록)
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

# --- portable watchdog -------------------------------------------------------
# This machine has neither `timeout` nor `gtimeout`, so poll the child ourselves.
run_with_watchdog() {            # $1=seconds $2=label $3=manual-command  rest=command
  local limit="$1" label="$2" manual="$3"; shift 3
  local log; log=$(mktemp -t synesis-watchdog) || { fail "cannot create temp file"; return 1; }
  "$@" </dev/null >"$log" 2>&1 &                 # stdin closed so no TTY prompt can appear
  local pid=$! waited=0 rc=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      fail "$label timed out after ${limit}s. $manual"
      sed 's/^/    /' "$log"; rm -f "$log"; return 124
    fi
    sleep 1; waited=$((waited + 1))
  done
  wait "$pid"; rc=$?
  [ "$rc" -ne 0 ] && { fail "$label exited $rc. $manual"; sed 's/^/    /' "$log"; }
  rm -f "$log"; return "$rc"
}

# --- step: codex CLI ---------------------------------------------------------
command -v "$CODEX" >/dev/null 2>&1 || die "codex CLI not found in PATH. Install codex-cli first."

# --- step: marketplace -------------------------------------------------------
marketplace_present() {   # exit 0 = present, 1 = absent, 3 = cannot parse
  "$CODEX" plugin marketplace list --json 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(3)
names={m.get("name") for m in d.get("marketplaces",[])}
sys.exit(0 if "gptaku-codex" in names else 1)
'
}

mp_present=0
marketplace_present; mp_rc=$?
case $mp_rc in
  0) mp_present=1 ;;
  1) mp_present=0 ;;
  *) # --json unsupported or broken: fall back to the human table (header on line 1)
     if "$CODEX" plugin marketplace list 2>/dev/null | awk 'NR>1 && $1=="gptaku-codex"{f=1} END{exit !f}'; then
       mp_present=1
     fi ;;
esac

if [ "$mp_present" = 1 ]; then
  skip "marketplace gptaku-codex already registered"
else
  mp_out=$("$CODEX" plugin marketplace add https://github.com/fivetaku/gptaku-plugins-codex.git 2>&1) || {
    printf '%s\n' "$mp_out" | sed 's/^/    /'
    die "failed to register marketplace gptaku-codex (network?)"
  }
  ok "marketplace gptaku-codex registered"
fi

# --- step: plugin install ----------------------------------------------------
plugin_probe() {   # exit 0 + stdout "<version>\n<source path>"; 1 = not installed/enabled; 3 = parse error
  "$CODEX" plugin list --json -m gptaku-codex 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(3)
for p in d.get("installed",[]):
    if p.get("pluginId")=="insane-search-codex@gptaku-codex" and p.get("installed") and p.get("enabled"):
        print(p.get("version") or "unknown")
        print(((p.get("source") or {}).get("path")) or "")
        sys.exit(0)
sys.exit(1)
'
}

read_probe() { VER=$(printf '%s\n' "$1" | sed -n 1p); SRC=$(printf '%s\n' "$1" | sed -n 2p); }

out=$(plugin_probe); case $? in
  0) read_probe "$out"; skip "insane-search-codex already installed, enabled ($VER)" ;;
  1) ok "installing insane-search-codex"
     run_with_watchdog "${SYNESIS_ADD_TIMEOUT:-120}" "codex plugin add" "$MANUAL" \
       "$CODEX" plugin add insane-search-codex@gptaku-codex \
       || warn "plugin add did not complete cleanly; re-checking state"
     out=$(plugin_probe); case $? in
       0) read_probe "$out"; ok "insane-search-codex installed ($VER)" ;;
       1) die "insane-search-codex is not installed+enabled after install. $MANUAL" ;;
       *) die "cannot read codex plugin list output after install. $MANUAL" ;;
     esac ;;
  *) die "cannot read codex plugin list output" ;;
esac

# --- step: locate the insane-search skill directory --------------------------
cand_list=""
if [ -n "$SRC" ]; then
  cand_list="$SRC/skills/insane-search"
fi
cache_base="$HOME/.codex/plugins/cache/gptaku-codex/insane-search-codex"
cache_ver=$(ls -1 "$cache_base" 2>/dev/null | sort -V | tail -n 1)
if [ -n "$cache_ver" ]; then
  cand_list="${cand_list:+$cand_list
}$cache_base/$cache_ver/skills/insane-search"
fi
cand_list="${cand_list:+$cand_list
}$HOME/.codex/.tmp/marketplaces/gptaku-codex/plugins/insane-search-codex/skills/insane-search"

looked=""
while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  looked="${looked:+$looked, }$cand"
  if [ -f "$cand/SKILL.md" ]; then INSANE_DIR="$cand"; break; fi
done <<< "$cand_list"

if [ -n "$INSANE_DIR" ]; then
  ok "insane-search skill found at $INSANE_DIR"
else
  die "insane-search SKILL.md not found; looked in: $looked"
fi

# --- step: dependencies ------------------------------------------------------
python_externally_managed() {
  # The seam only forces the RESTRICTIVE direction; any other value is ignored.
  [ "${SYNESIS_PYTHON_EXTERNALLY_MANAGED:-}" = 1 ] && return 0
  python3 -c "import sysconfig,os,sys; sys.exit(0 if os.path.exists(os.path.join(sysconfig.get_path('stdlib'),'EXTERNALLY-MANAGED')) else 1)"
}

BOOT="${SYNESIS_BOOTSTRAP:-$INSANE_DIR/scripts/bootstrap.sh}"
[ -f "$BOOT" ] || die "bootstrap.sh not found at $BOOT"

if [ "$SKIP_DEPS" = 1 ]; then                                          # (0) explicitly skipped
  warn "dependency setup skipped by user (--skip-deps); run manually: PIP_BREAK_SYSTEM_PACKAGES=1 bash \"$BOOT\" --install"
  DEPS_STATE=skipped
elif check_out=$(bash "$BOOT" 2>&1); then                              # (a) already satisfied
  skip "insane-search dependencies already satisfied"
  DEPS_STATE=ok
elif python_externally_managed && [ "$ALLOW_USER_SITE" != 1 ]; then    # (b) approval needed — no install
  printf '%s\n' "$check_out" | sed 's/^/    /'
  USER_SITE=$(python3 -m site --user-site 2>/dev/null)
  warn "python3 is PEP 668 externally-managed; not installing without approval"
  warn "approval installs curl_cffi, beautifulsoup4, pyyaml, pypdf, markdownify into user-site ${USER_SITE:-<unresolved>}; Homebrew site-packages are untouched"
  need deps                                                            # DEPS_STATE stays pending
else                                                                   # (c) install
  printf '%s\n' "$check_out" | sed 's/^/    /'
  ok "installing insane-search dependencies (may take a few minutes)"
  TMP=$(mktemp -t synesis-bootstrap) || die "cannot create temp file"
  if [ "$ALLOW_USER_SITE" = 1 ]; then
    PIP_BREAK_SYSTEM_PACKAGES=1 bash "$BOOT" --install 2>&1 | tee "$TMP"; rc=${PIPESTATUS[0]}
  else
    bash "$BOOT" --install 2>&1 | tee "$TMP"; rc=${PIPESTATUS[0]}      # no guard bypass
  fi
  if [ "$rc" -eq 0 ]; then ok "insane-search dependencies installed"; DEPS_STATE=ok; rm -f "$TMP"
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
