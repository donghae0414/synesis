**English** | [한국어](README.ko.md)

# Synesis

> **Knowledge is not what we collect, but what we come to understand.**

A personal knowledge system that grows through conversation.

A library remembers information.  
Synesis remembers understanding.

## Install

Synesis works in Claude Code, Codex, and pi. All three load the same skills from
`plugins/synesis/skills/`.

**Claude Code**

```bash
claude plugin marketplace add donghae0414/synesis
claude plugin install synesis@synesis
```

**Codex**

```bash
codex plugin marketplace add donghae0414/synesis
codex plugin add synesis@synesis
```

**pi**

```bash
pi install git:github.com/donghae0414/synesis
```

## Setup

After you install, ask your agent to "set up synesis". The setup skill:

- checks the Python packages that `deep-fetch` needs and installs them (it asks first
  if your Python is externally managed),
- detects your Obsidian vaults or lets you pick any notes folder (Obsidian is
  optional),
- records the confirmed folder in `~/.config/synesis/config.json`.

`deep-fetch` needs Python 3.10 or newer. The default `python3` on macOS is 3.9, so
install a newer one if you do not have it (for example `brew install python`).

## Reading the web: deep-fetch

The `deep-fetch` skill reads public web pages, including pages that block ordinary
HTTP clients. It tries official public APIs first (Reddit, X, YouTube, Hacker News,
arXiv, and others), then a TLS-impersonating fetch chain, then a local browser.
It stops at logins and paywalls. Runtime state (logs, per-site learning, browser
packages) is kept in `~/.local/state/deep-fetch/`.

You are responsible for using it lawfully and within each site's terms of service.

## Plain Korean

The `plain-korean` skill writes Korean documents and replies by the principles of
ASD-STE100, so that readers understand them on the first read. Ask your agent to
write, rewrite, or check Korean text in this style, or to answer this way for the
rest of the conversation.

## Design decisions

- [Knowledge structure: domains, subtopics, and MOCs (Korean)](docs/decisions/2026-09-29-knowledge-structure.md) — Agreed direction and open questions for implementation planning.

## Development

- `bash plugins/synesis/skills/setup/tests/run-cases.sh` tests the setup script.
- `bash plugins/synesis/skills/deep-fetch/scripts/smoke.sh` runs the deep-fetch checks.
- `bash scripts/check-manifests.sh` checks that the Claude Code, Codex, and pi
  manifests agree on name and version.

## Acknowledgments

`deep-fetch` is a fork of [`insane-search`](https://github.com/fivetaku/insane-search)
by [GPTaku (fivetaku)](https://github.com/fivetaku), distributed under the MIT License.
The upstream author is not affiliated with Synesis and does not endorse this fork.
[`UPSTREAM.md`](plugins/synesis/skills/deep-fetch/UPSTREAM.md) lists the upstream
commit and every change.

The `plain-korean` skill started from [a post by Andrej Karpathy on X](https://x.com/karpathy/status/2105819303471976479)
that suggests asking LLMs for writing close to ASD-STE100. Its rules adapt the
principles of ASD-STE100 Simplified Technical English, Issue 9, to Korean. This
repository does not include the text of the standard or its dictionary.

## License

MIT. See [`LICENSE`](LICENSE). `deep-fetch` keeps the upstream copyright notice in
[`plugins/synesis/skills/deep-fetch/LICENSE`](plugins/synesis/skills/deep-fetch/LICENSE).
