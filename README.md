**English** | [한국어](README.ko.md)

# Synesis

> **Knowledge is not what we collect, but what we come to understand.**

A personal knowledge system that grows through conversation.

A library remembers information.  
Synesis remembers understanding.

## Setup

Ask Codex to "set up synesis". It installs the `insane-search` plugin and its
dependencies (asking first if your Python is externally managed), detects your
Obsidian vaults or lets you pick any notes folder (Obsidian is optional), and
records the confirmed folder in `~/.config/synesis/config.json`.

## Design decisions

- [Knowledge structure: domains, subtopics, and MOCs (Korean)](docs/decisions/2026-09-29-knowledge-structure.md) — Agreed direction and open questions for implementation planning.

## Acknowledgments

Synesis reads the web through [`insane-search`](https://github.com/fivetaku/gptaku-plugins-codex/tree/main/plugins/insane-search-codex),
a Codex plugin by [GPTaku (fivetaku)](https://github.com/fivetaku), distributed under the MIT License.
The setup skill installs it from the `gptaku-codex` marketplace.
