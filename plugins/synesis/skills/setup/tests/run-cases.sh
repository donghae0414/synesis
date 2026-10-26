#!/bin/bash
# Stub-driven case suite for plugins/synesis/skills/setup/scripts/setup.sh.
#
# Runs under /bin/bash (3.2.57 on macOS): no associative arrays, no mapfile, no
# empty-array expansion under `set -u`. Everything lives inside ONE mktemp -d root
# which is removed by the EXIT trap; HOME, XDG_CONFIG_HOME, the deep-fetch bootstrap
# script and the Obsidian paths are all redirected into that root, so the real
# ~/.config/synesis, ~/Library and the real Python packages are never touched.
#
# Usage: /bin/bash plugins/synesis/skills/setup/tests/run-cases.sh
# Exit: 0 = every case passed, 1 = at least one case failed.
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP="$TESTS_DIR/../scripts/setup.sh"
STUB_BOOT="$TESTS_DIR/stubs/bootstrap.sh"
REAL_PY="$(command -v python3 || true)"

[ -f "$SETUP" ]      || { printf 'cannot find setup.sh at %s\n' "$SETUP" >&2; exit 1; }
[ -x "$STUB_BOOT" ]  || chmod +x "$STUB_BOOT"

ROOT="$(mktemp -d -t synesis-setup-tests)" || { printf 'mktemp -d failed\n' >&2; exit 1; }
cleanup() {
  chmod -R u+rwX "$ROOT" 2>/dev/null
  rm -rf "$ROOT"
}
trap cleanup EXIT

PASSN=0
FAILN=0
SKIPN=0

CASE=""
CASEDIR=""
ERRS=""
OUT=""
RC=0

# --- per-case environment ----------------------------------------------------
# Every knob is reset here, so a case only has to override what it exercises.
new_case() {
  CASE="$1"
  ERRS=""
  OUT=""
  RC=0
  CASEDIR="$ROOT/$CASE"
  mkdir -p "$CASEDIR/home" "$CASEDIR/xdg" "$CASEDIR/vault"
  printf '{"vaults":{}}\n' > "$CASEDIR/obsidian.json"

  CASE_HOME="$CASEDIR/home"
  CASE_XDG="$CASEDIR/xdg"
  VAULTDIR="$CASEDIR/vault"
  # resolve_dir() reports the physical path, which on macOS means /private/var/...
  VAULTDIR_REAL=$(cd "$CASEDIR/vault" && pwd -P)
  RUN_CWD="$ROOT"
  PATH_PREFIX=""

  SYNESIS_BOOTSTRAP="$STUB_BOOT"
  SYNESIS_OBSIDIAN_APP="$CASEDIR/no-such-obsidian-app"
  SYNESIS_OBSIDIAN_JSON="$CASEDIR/obsidian.json"
  SYNESIS_PYTHON_EXTERNALLY_MANAGED=""

  STUB_BOOT_PY_RC=0
  STUB_BOOT_CHECK_RC=0
  STUB_BOOT_INSTALL_RC=0
  STUB_BOOT_OBS="$CASEDIR/bootstrap-obs"
  rm -f "$STUB_BOOT_OBS"
}

# Run setup.sh with the current case's environment. Assignments happen inside the
# command substitution's subshell, so nothing leaks into the next case.
sr() {
  OUT=$(
    cd "$RUN_CWD" || exit 99
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_XDG"
    if [ -n "$PATH_PREFIX" ]; then export PATH="$PATH_PREFIX:$PATH"; fi
    unset PIP_BREAK_SYSTEM_PACKAGES
    if [ -n "$SYNESIS_BOOTSTRAP" ]; then export SYNESIS_BOOTSTRAP; else unset SYNESIS_BOOTSTRAP; fi
    export SYNESIS_OBSIDIAN_APP SYNESIS_OBSIDIAN_JSON
    export STUB_BOOT_PY_RC STUB_BOOT_CHECK_RC STUB_BOOT_INSTALL_RC STUB_BOOT_OBS
    if [ -n "$SYNESIS_PYTHON_EXTERNALLY_MANAGED" ]; then
      export SYNESIS_PYTHON_EXTERNALLY_MANAGED
    else
      unset SYNESIS_PYTHON_EXTERNALLY_MANAGED
    fi
    /bin/bash "$SETUP" "$@" 2>&1
  )
  RC=$?
}

# --- assertions --------------------------------------------------------------
err() { ERRS="${ERRS:+$ERRS
}    - $*"; }

has()   { case "$OUT" in *"$1"*) ;; *) err "output missing: $1" ;; esac; }
hasnt() { case "$OUT" in *"$1"*) err "output should not contain: $1" ;; *) ;; esac; }
rc_is() { [ "$RC" = "$1" ] || err "exit code $RC, expected $1"; }

count_is() {  # $1 = grep -E pattern, $2 = expected count, $3 = label
  n=$(printf '%s\n' "$OUT" | grep -cE "$1")
  n=$(printf '%s' "$n" | tr -d ' ')
  [ "$n" = "$2" ] || err "$3: found $n, expected $2"
}

boot_obs_is() {  # $1 = expected PIP_BREAK_SYSTEM_PACKAGES value written by the bootstrap stub
  if [ -f "$STUB_BOOT_OBS" ]; then
    grep -q "^PIP_BREAK_SYSTEM_PACKAGES=$1$" "$STUB_BOOT_OBS" \
      || err "bootstrap observed $(cat "$STUB_BOOT_OBS"), expected PIP_BREAK_SYSTEM_PACKAGES=$1"
  else
    err "bootstrap --install never ran (no $STUB_BOOT_OBS)"
  fi
}

# Puts a python3 wrapper first in PATH that answers setup.sh's EXTERNALLY-MANAGED
# probe with $1 (0 = externally managed, 1 = not) and delegates everything else.
fake_python_managed() {
  mkdir -p "$CASEDIR/bin"
  {
    printf '#!/bin/bash\n'
    printf 'for a in "$@"; do case "$a" in *EXTERNALLY-MANAGED*) exit %s;; esac; done\n' "$1"
    printf 'exec %s "$@"\n' "$REAL_PY"
  } > "$CASEDIR/bin/python3"
  chmod +x "$CASEDIR/bin/python3"
  PATH_PREFIX="$CASEDIR/bin"
}

file_exists()  { [ -e "$1" ] || err "expected to exist: $1"; }
file_absent()  { [ ! -e "$1" ] || err "should not exist: $1"; }
dir_absent()   { [ ! -d "$1" ] || err "directory should not exist: $1"; }

cfg_path() {
  case "$CASE_XDG" in
    /*) printf '%s\n' "$CASE_XDG/synesis/config.json" ;;
    *)  printf '%s\n' "$CASE_HOME/.config/synesis/config.json" ;;
  esac
}

json_get() {  # $1 = file, $2 = key -> value on stdout, empty on any problem
  python3 -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
if isinstance(d, dict):
    v = d.get(sys.argv[2])
    if v is not None: print(v)
' "$1" "$2" 2>/dev/null
}

cfg_key_is() {  # $1 = key, $2 = expected value
  c=$(cfg_path)
  if [ ! -f "$c" ]; then err "config not written at $c"; return; fi
  v=$(json_get "$c" "$1")
  [ "$v" = "$2" ] || err "config $1 = '$v', expected '$2'"
}

json_valid() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null \
    || err "not valid JSON: $1"
}

finish() {
  if [ -n "$ERRS" ]; then
    printf 'FAIL %s:\n%s\n' "$CASE" "$ERRS"
    printf '%s\n' "$OUT" | sed 's/^/      | /'
    FAILN=$((FAILN + 1))
  else
    printf 'PASS %s\n' "$CASE"
    PASSN=$((PASSN + 1))
  fi
}

skip_case() {  # $1 = name, $2 = reason
  printf 'SKIP %s: %s\n' "$1" "$2"
  SKIPN=$((SKIPN + 1))
}

# =============================================================================
# deep-fetch bootstrap discovery
# =============================================================================
new_case bundled_bootstrap_default
SYNESIS_BOOTSTRAP=""
sr --skip-deps --vault "$VAULTDIR"
has 'deep-fetch/scripts/bootstrap.sh'
BUNDLED=$(cd "$TESTS_DIR/../../deep-fetch/scripts" 2>/dev/null && pwd)/bootstrap.sh
[ -f "$BUNDLED" ] || err "bundled bootstrap missing at $BUNDLED"
rc_is 0
finish

new_case bootstrap_missing_exit1
SYNESIS_BOOTSTRAP="$CASEDIR/no-such-bootstrap.sh"
sr --vault "$VAULTDIR"
has '[fail] deep-fetch bootstrap.sh not found at'
file_absent "$(cfg_path)"
rc_is 1
finish

new_case no_python310_exit1
STUB_BOOT_PY_RC=1
sr --vault "$VAULTDIR"
has 'bootstrap: Python 3.10 or newer not found'
has '[fail] deep-fetch needs Python 3.10 or newer'
file_absent "$STUB_BOOT_OBS"
file_absent "$(cfg_path)"
rc_is 1
finish

new_case no_python310_skip_deps_ok
STUB_BOOT_PY_RC=1
sr --skip-deps --vault "$VAULTDIR"
cfg_key_is deps skipped
rc_is 0
finish

new_case codex_never_called
mkdir -p "$CASEDIR/bin"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$CASEDIR/codex-called" > "$CASEDIR/bin/codex"
chmod +x "$CASEDIR/bin/codex"
PATH_PREFIX="$CASEDIR/bin"
sr --vault "$VAULTDIR"
file_absent "$CASEDIR/codex-called"
rc_is 0
finish

# =============================================================================
# dependencies
# =============================================================================
new_case deps_missing_needs_approval
STUB_BOOT_CHECK_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
sr
has 'NEEDS_CONFIRMATION: deps'
has '[warn] approval installs curl_cffi'
file_absent "$STUB_BOOT_OBS"
rc_is 2
finish

new_case deps_install_with_approval
STUB_BOOT_CHECK_RC=1
STUB_BOOT_INSTALL_RC=0
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
sr --allow-user-site --vault "$VAULTDIR"
has '[ok] deep-fetch dependencies installed'
hasnt 'NEEDS_CONFIRMATION: deps'
boot_obs_is 1
cfg_key_is deps ok
rc_is 0
finish

new_case deps_install_fails
STUB_BOOT_CHECK_RC=1
STUB_BOOT_INSTALL_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
sr --allow-user-site --vault "$VAULTDIR"
has '[fail] bootstrap.sh --install failed'
rc_is 1
finish

new_case consent_bypass_impossible
# The seam only forces the restrictive direction, so 0 is ignored and the python3
# that bootstrap reports is probed. The wrapper makes that python3 externally
# managed, so the case does not depend on which Python this machine has.
STUB_BOOT_CHECK_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=0
fake_python_managed 0
sr --vault "$VAULTDIR"
has 'NEEDS_CONFIRMATION: deps'
has '[warn] python3 is PEP 668 externally-managed; not installing without approval'
rc_is 2
if [ -s "$STUB_BOOT_OBS" ]; then err "install ran without approval: $(cat "$STUB_BOOT_OBS")"; fi
cfg_key_is deps pending
finish

new_case non_externally_managed_install
STUB_BOOT_CHECK_RC=1
STUB_BOOT_INSTALL_RC=0
if [ -z "$REAL_PY" ]; then
  skip_case non_externally_managed_install "no python3 on PATH to wrap"
else
  fake_python_managed 1
  sr --vault "$VAULTDIR"
  has '[ok] installing deep-fetch dependencies'
  has '[ok] deep-fetch dependencies installed'
  hasnt 'NEEDS_CONFIRMATION: deps'
  boot_obs_is unset
  cfg_key_is deps ok
  rc_is 0
  finish
fi

new_case skip_deps_with_vault
STUB_BOOT_CHECK_RC=1
sr --skip-deps --vault "$VAULTDIR"
has '[warn] dependency setup skipped by user'
file_absent "$STUB_BOOT_OBS"
cfg_key_is deps skipped
rc_is 0
finish

new_case skip_deps_alone
STUB_BOOT_CHECK_RC=1
sr --skip-deps
hasnt 'NEEDS_CONFIRMATION: deps'
has 'NEEDS_CONFIRMATION: vault'
file_absent "$(cfg_path)"
rc_is 2
finish

new_case skip_deps_wins_over_allow
STUB_BOOT_CHECK_RC=1
sr --skip-deps --allow-user-site --vault "$VAULTDIR"
has '[warn] dependency setup skipped by user'
file_absent "$STUB_BOOT_OBS"
cfg_key_is deps skipped
rc_is 0
finish

new_case deps_pending_vault_valid
STUB_BOOT_CHECK_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
sr --vault "$VAULTDIR"
has 'NEEDS_CONFIRMATION: deps'
cfg_key_is deps pending
cfg_key_is vault "$VAULTDIR_REAL"
rc_is 2
finish

new_case deps_and_vault_pending
STUB_BOOT_CHECK_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
sr
has 'NEEDS_CONFIRMATION: deps'
has 'NEEDS_CONFIRMATION: vault'
has 'waiting on your answer for: deps, vault'
file_absent "$(cfg_path)"
rc_is 2
finish

new_case deps_and_create_dir_pending
STUB_BOOT_CHECK_RC=1
SYNESIS_PYTHON_EXTERNALLY_MANAGED=1
MISSING="$CASEDIR/not-yet"
sr --vault "$MISSING"
has 'NEEDS_CONFIRMATION: deps'
has "NEEDS_CONFIRMATION: create-dir $MISSING"
has 'waiting on your answer for: deps, create-dir'
dir_absent "$MISSING"
file_absent "$(cfg_path)"
rc_is 2
finish

# =============================================================================
# Obsidian detection and vault candidates
# =============================================================================
new_case obsidian_absent_warn
SYNESIS_OBSIDIAN_APP="/nonexistent/Obsidian.app"
SYNESIS_OBSIDIAN_JSON="/nonexistent/obsidian.json"
sr --vault "$VAULTDIR"
has '[warn] Obsidian not found. Install from https://obsidian.md'
has "[ok] vault recorded: $VAULTDIR_REAL"
rc_is 0
finish

new_case zero_vaults
printf '{"vaults":{}}\n' > "$CASEDIR/obsidian.json"
sr
count_is '^candidate: ' 0 'candidate lines'
rc_is 2
finish

new_case multiple_vaults
mkdir -p "$CASEDIR/v1" "$CASEDIR/v2"
printf '{"vaults":{"a":{"path":"%s"},"b":{"path":"%s"}}}\n' "$CASEDIR/v1" "$CASEDIR/v2" \
  > "$CASEDIR/obsidian.json"
sr
count_is '^candidate: ' 2 'candidate lines'
count_is '^default: ' 1 'default lines'
rc_is 2
finish

new_case default_suggested_without_vault
sr
has "default: $CASE_HOME/Documents/synesis"
has 'NEEDS_CONFIRMATION: vault'
dir_absent "$CASE_HOME/Documents/synesis"
file_absent "$(cfg_path)"
rc_is 2
finish

new_case default_not_printed_with_vault
sr --vault "$VAULTDIR"
hasnt 'default: '
rc_is 0
finish

new_case default_not_repeated_as_candidate
mkdir -p "$CASE_HOME/Documents/synesis" "$CASEDIR/v1"
printf '{"vaults":{"a":{"path":"%s"},"b":{"path":"%s"}}}\n' "$CASE_HOME/Documents/synesis" "$CASEDIR/v1" \
  > "$CASEDIR/obsidian.json"
sr
count_is '^candidate: ' 1 'candidate lines'
has "candidate: $CASEDIR/v1"
has "default: $CASE_HOME/Documents/synesis"
rc_is 2
finish

new_case default_chosen_creates_and_records
sr --vault "$CASE_HOME/Documents/synesis" --create-vault
[ -d "$CASE_HOME/Documents/synesis" ] || err "default folder was not created"
cfg_key_is vault "$(cd "$CASE_HOME/Documents/synesis" 2>/dev/null && pwd -P)"
rc_is 0
finish

# =============================================================================
# config file handling
# =============================================================================
new_case corrupt_config_backup
mkdir -p "$CASE_XDG/synesis"
printf 'not json\n' > "$CASE_XDG/synesis/config.json"
sr --vault "$VAULTDIR"
has '[warn] existing config was unreadable; backed up to'
ls "$CASE_XDG"/synesis/config.json.bak-* >/dev/null 2>&1 || err "no config.json.bak-* was created"
json_valid "$CASE_XDG/synesis/config.json"
cfg_key_is vault "$VAULTDIR_REAL"
rc_is 0
finish

new_case nondict_config_backup
mkdir -p "$CASE_XDG/synesis"
printf '[1,2]\n' > "$CASE_XDG/synesis/config.json"
sr --vault "$VAULTDIR"
has '[warn] existing config was unreadable; backed up to'
ls "$CASE_XDG"/synesis/config.json.bak-* >/dev/null 2>&1 || err "no config.json.bak-* was created"
json_valid "$CASE_XDG/synesis/config.json"
rc_is 0
finish

new_case xdg_relative_fallback
CASE_XDG="relative/dir"
sr --vault "$VAULTDIR"
has '[warn] XDG_CONFIG_HOME is not absolute; falling back to $HOME/.config'
file_exists "$CASE_HOME/.config/synesis/config.json"
dir_absent "$RUN_CWD/relative/dir"
cfg_key_is vault "$VAULTDIR_REAL"
rc_is 0
finish

new_case xdg_absolute_alternate
CASE_XDG="$CASEDIR/alt-xdg"
sr --vault "$VAULTDIR"
hasnt 'XDG_CONFIG_HOME is not absolute'
file_exists "$CASEDIR/alt-xdg/synesis/config.json"
cfg_key_is vault "$VAULTDIR_REAL"
rc_is 0
finish

new_case preserve_other_keys
mkdir -p "$CASE_XDG/synesis"
printf '{"vault":"/x","other":1}\n' > "$CASE_XDG/synesis/config.json"
sr --vault "$VAULTDIR"
cfg_key_is other 1
cfg_key_is vault "$VAULTDIR_REAL"
rc_is 0
finish

# =============================================================================
# argument handling
# =============================================================================
new_case help_exit0
sr --help
has 'Usage: bash'
has '--create-vault'
rc_is 0
finish

new_case bogus_arg_exit1
sr --definitely-not-an-option
has 'unknown option: --definitely-not-an-option'
rc_is 1
finish

new_case vault_missing_value_exit1
sr --vault
has '--vault requires a path'
rc_is 1
finish

# =============================================================================
# vault decision
# =============================================================================
new_case vault_nonexistent_create_dir_pending
MISSING="$CASEDIR/notes-missing"
sr --vault "$MISSING"
has "NEEDS_CONFIRMATION: create-dir $MISSING (parent: "
has "[warn] notes folder does not exist yet: $MISSING"
dir_absent "$MISSING"
file_absent "$(cfg_path)"
rc_is 2
finish

new_case vault_create_vault_creates
MISSING="$CASEDIR/notes-created"
sr --vault "$MISSING" --create-vault
created=$(printf '%s\n' "$OUT" | sed -n 's/^\[ok\] created notes folder: //p' | head -1)
if [ -z "$created" ]; then
  err "no '[ok] created notes folder:' line"
else
  [ -d "$created" ] || err "reported folder does not exist: $created"
  cfg_key_is vault "$created"
fi
[ -d "$MISSING" ] || err "requested folder was not created: $MISSING"
rc_is 0
finish

new_case vault_is_file_exit1
printf 'x\n' > "$CASEDIR/a-file"
sr --vault "$CASEDIR/a-file"
has "[fail] --vault path exists but is not a directory: $CASEDIR/a-file"
file_absent "$(cfg_path)"
rc_is 1
finish

new_case mkdir_fails_under_file_exit1
printf 'x\n' > "$CASEDIR/blocker"
sr --vault "$CASEDIR/blocker/sub" --create-vault
has '[fail] cannot create notes folder:'
lm=$(printf '%s\n' "$OUT" | grep -n '^    mkdir' | head -1 | cut -d: -f1)
lf=$(printf '%s\n' "$OUT" | grep -n '^\[fail\] cannot create notes folder' | head -1 | cut -d: -f1)
if [ -z "$lm" ]; then
  err "no indented mkdir error line"
elif [ -z "$lf" ] || [ "$lm" -ge "$lf" ]; then
  err "indented mkdir error (line $lm) must precede the [fail] line (line ${lf:-none})"
fi
rc_is 1
finish

new_case vault_mode600_exit1
LOCKED="$CASEDIR/locked"
mkdir -p "$LOCKED"
chmod 600 "$LOCKED"
sr --vault "$LOCKED"
chmod 700 "$LOCKED"
has "[fail] cannot enter notes folder: $LOCKED"
reported=$(printf '%s\n' "$OUT" | sed -n 's/^\[fail\] cannot enter notes folder: //p' | head -1)
[ -n "$reported" ] || err "the [fail] line reported an empty path"
file_absent "$(cfg_path)"
rc_is 1
finish

new_case tilde_normalization
sr --vault '~/syn-nope'
has "NEEDS_CONFIRMATION: create-dir $CASE_HOME/syn-nope (parent: "
dir_absent "$CASE_HOME/syn-nope"
rc_is 2
finish

new_case relative_normalization
RUN_CWD="$CASEDIR"
EXPECT_BASE=$(cd "$CASEDIR" && pwd -P)
sr --vault ./syn-rel
has "NEEDS_CONFIRMATION: create-dir $EXPECT_BASE/syn-rel (parent: "
dir_absent "$CASEDIR/syn-rel"
rc_is 2
finish

# =============================================================================
# static checks
# =============================================================================
new_case syntax_check
OUT=$(/bin/bash -n "$SETUP" 2>&1); RC=$?
rc_is 0
[ -z "$OUT" ] || err "bash -n produced output"
finish

new_case unbound_none_noargs
sr
count_is 'unbound variable' 0 'unbound variable messages'
finish

new_case unbound_none_vault
sr --vault "$VAULTDIR"
count_is 'unbound variable' 0 'unbound variable messages'
finish

# =============================================================================
printf '\n%s\n' "-----------------------------------------------"
printf 'total: %s passed, %s failed, %s skipped\n' "$PASSN" "$FAILN" "$SKIPN"
[ "$FAILN" -eq 0 ] || exit 1
exit 0
