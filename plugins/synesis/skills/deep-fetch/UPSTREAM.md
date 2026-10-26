# Upstream

deep-fetch is a fork of `skills/insane-search/` from
[fivetaku/insane-search](https://github.com/fivetaku/insane-search).

- Upstream commit: `33efae832d48670a09bb1d2329a8505963ff7e74` (v0.17.3, 2026-10-20)
- License: MIT, Copyright (c) 2026 fivetaku. The full text is in `LICENSE` in this
  folder and applies to every file that came from upstream.
- The upstream author is not affiliated with Synesis and does not endorse this fork.
  The upstream `DISCLAIMER.md` explains the intended use: read public content only,
  and follow each site's terms of service and the law.

## Taken from upstream

- `SKILL.md` (edited, see below)
- `engine/` (one patch, see below)
- `references/` (one edit, see below)
- `LICENSE`

## Not taken

- `setup/setup.sh` and `setup/gptaku-update-check.cjs`: the GitHub star prompt and the
  SessionStart update-check hook that the script adds to `~/.claude/settings.json`.
- `.claude-plugin/plugin.json` and its `gptaku-core` dependency. Synesis ships its own
  manifests.
- `routing.json`, `assets/`, `README*`, `PLATFORMS.md`, `CHANGELOG.md`, `DISCLAIMER.md`.
- `tests/coverage_battery.py`, `tests/live_benchmark/`, `tests/test_x_search.py`
  (network benchmarks and coverage runs). The tests in `engine/tests/` are kept.

## Added in this fork

- `scripts/python.sh`: picks a Python 3.10 or newer (`DEEP_FETCH_PYTHON`, `python3`,
  `python3.14` to `python3.10`). Upstream needs 3.10 (`dataclass(slots=True)`, and
  curl_cffi 0.15 has no 3.9 wheel), and the default macOS `python3` is 3.9.
- `scripts/run.sh`: runs the engine from the skill folder. It sets
  `INSANE_OBSERVATIONS_DIR`, `INSANE_LEARNED_PATH`, and `INSANE_NODE_DEPS_DIR` to
  `${XDG_STATE_HOME:-~/.local/state}/deep-fetch/`, so runtime state stays out of the
  plugin folder.
- `scripts/bootstrap.sh`: checks and installs the Python packages and, when node and
  npm exist, the Node packages for the browser fallback.
- `scripts/smoke.sh`: runs `engine/bias_check.py` and `engine/tests/test_*.py` with
  `PYTHONPATH` set to the skill folder and engine state in a temporary folder.
  `test_smoke.py` makes real requests to example.com and httpbin.org.

## Changes to upstream files

- `engine/executor.py`: `NODE_DEPS_DIR` reads `INSANE_NODE_DEPS_DIR` before it falls
  back to the upstream default `~/.insane-search/node`.
- `SKILL.md`: renamed to `deep-fetch`. Removed the Step 0 star prompt. Replaced
  `${CLAUDE_PLUGIN_ROOT}` paths and `python3 -m engine` calls with `scripts/run.sh`.
  Replaced Claude-only tool names (WebFetch, WebSearch, Read) with neutral wording.
  Pointed the dependency instructions at `scripts/bootstrap.sh` and the test hint at
  `scripts/smoke.sh`, and stated the Python 3.10 requirement.
- `references/twitter.md`: the X search example uses `scripts/run.sh`.

Environment variable names keep the upstream `INSANE_` prefix. This keeps the diff
small when changes are taken from upstream again.

## Syncing with upstream

1. Download the new upstream commit and compare its `skills/insane-search/` with this
   folder.
2. Copy changed `engine/` and `references/` files, then apply the changes listed above
   again.
3. Run `bash scripts/smoke.sh` and fetch one real URL with `bash scripts/run.sh`.
4. Update the commit hash at the top of this file.
