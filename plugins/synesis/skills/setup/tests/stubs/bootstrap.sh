#!/bin/bash
# Stub for insane-search's bootstrap.sh, reached through SYNESIS_BOOTSTRAP.
# bash 3.2 compatible. Environment variables:
#
#   STUB_BOOT_CHECK_RC=<n>    exit code for the no-argument prerequisite check
#                             (default 0). On 0 it prints
#                               bootstrap: Python and Node prerequisites look available
#                             otherwise
#                               bootstrap: missing prerequisites detected
#   STUB_BOOT_INSTALL_RC=<n>  exit code for `--install` (default 0)
#   STUB_BOOT_OBS=<file>      observation file. On `--install` the stub writes
#                               PIP_BREAK_SYSTEM_PACKAGES=<value-or-unset>
#                             so tests can assert whether setup.sh set the PEP 668
#                             override. The file staying absent proves --install
#                             was never called.
set -u

if [ $# -eq 0 ]; then
  rc="${STUB_BOOT_CHECK_RC:-0}"
  if [ "$rc" = 0 ]; then
    printf 'bootstrap: Python and Node prerequisites look available\n'
  else
    printf 'bootstrap: missing prerequisites detected\n'
  fi
  exit "$rc"
fi

case "$1" in
  --install)
    obs="${STUB_BOOT_OBS:-}"
    if [ -n "$obs" ]; then
      printf 'PIP_BREAK_SYSTEM_PACKAGES=%s\n' "${PIP_BREAK_SYSTEM_PACKAGES:-unset}" > "$obs"
    fi
    rc="${STUB_BOOT_INSTALL_RC:-0}"
    printf 'bootstrap: install run (rc=%s)\n' "$rc"
    exit "$rc"
    ;;
  *)
    printf 'bootstrap: unknown argument: %s\n' "$1" >&2
    exit 64
    ;;
esac
