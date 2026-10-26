#!/usr/bin/env bash
# Checks that the Claude Code, Codex, and pi manifests describe the same plugin:
# same name and version, and marketplace entries and pi skill paths that point at
# the plugin folder. Run it before a release.
#
# Usage: bash scripts/check-manifests.sh   Exit: 0 = consistent, 1 = mismatch.
# bash 3.2 compatible.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json, os, sys

root = sys.argv[1]
files = {
    "package.json (pi)": "package.json",
    "Claude plugin.json": "plugins/synesis/.claude-plugin/plugin.json",
    "Codex plugin.json": "plugins/synesis/.codex-plugin/plugin.json",
    "Claude marketplace.json": ".claude-plugin/marketplace.json",
    "Codex marketplace.json": ".agents/plugins/marketplace.json",
}
data, errors = {}, []
for label, rel in files.items():
    try:
        with open(os.path.join(root, rel)) as f:
            data[label] = json.load(f)
    except Exception as e:
        errors.append("%s: cannot read %s (%s)" % (label, rel, e))
if errors:
    print("\n".join(errors)); sys.exit(1)

manifests = ["package.json (pi)", "Claude plugin.json", "Codex plugin.json"]
for key in ("name", "version"):
    values = {label: data[label].get(key) for label in manifests}
    if len(set(values.values())) != 1:
        errors.append("%s differs: %s" % (key, ", ".join("%s=%r" % kv for kv in values.items())))

plugin_dir = os.path.realpath(os.path.join(root, "plugins/synesis"))
name = data["Claude plugin.json"].get("name")

def entry_path(label, entry):
    src = entry.get("source")
    path = src.get("path") if isinstance(src, dict) else src
    if not isinstance(path, str):
        errors.append("%s: entry %r has no source path" % (label, entry.get("name")))
        return
    if os.path.realpath(os.path.join(root, path)) != plugin_dir:
        errors.append("%s: entry %r points at %s, not plugins/synesis" % (label, entry.get("name"), path))

for label in ("Claude marketplace.json", "Codex marketplace.json"):
    entries = [e for e in data[label].get("plugins", []) if e.get("name") == name]
    if len(entries) != 1:
        errors.append("%s: expected one entry named %r, found %d" % (label, name, len(entries)))
    for e in entries:
        entry_path(label, e)

skills = (data["package.json (pi)"].get("pi") or {}).get("skills") or []
if [os.path.realpath(os.path.join(root, s)) for s in skills] != [os.path.join(plugin_dir, "skills")]:
    errors.append("package.json (pi): pi.skills should be ['./plugins/synesis/skills'], found %r" % skills)

if errors:
    print("\n".join(errors)); sys.exit(1)
print("manifests consistent: %s %s" % (name, data["Claude plugin.json"].get("version")))
PY
