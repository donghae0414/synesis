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

## Plain Korean

The `plain-korean` skill writes Korean documents and replies by the principles of
ASD-STE100, so that readers understand them on the first read. Ask Codex to write,
rewrite, or check Korean text in this style, or to answer this way for the rest
of the conversation.

## Design decisions

- [Knowledge structure: domains, subtopics, and MOCs (Korean)](docs/decisions/2026-09-29-knowledge-structure.md) — Agreed direction and open questions for implementation planning.

## Acknowledgments

Synesis reads the web through [`insane-search`](https://github.com/fivetaku/gptaku-plugins-codex/tree/main/plugins/insane-search-codex),
a Codex plugin by [GPTaku (fivetaku)](https://github.com/fivetaku), distributed under the MIT License.
The setup skill installs it from the `gptaku-codex` marketplace.

The `plain-korean` skill started from [a post by Andrej Karpathy on X](https://x.com/karpathy/status/2105819303471976479)
that suggests asking LLMs for writing close to ASD-STE100. Its rules adapt the
principles of ASD-STE100 Simplified Technical English, Issue 9, to Korean. This
repository does not include the text of the standard or its dictionary.
