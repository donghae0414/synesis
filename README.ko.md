[English](README.md) | **한국어**

# Synesis

> **지식은 모아둔 것이 아니라, 이해하게 된 것이다.**

대화를 통해 자라나는 개인 지식 시스템.

도서관은 정보를 기억한다.  
Synesis는 이해를 기억한다.

## 설정

Codex에게 "synesis 설정해줘"라고 요청하세요. `insane-search` 플러그인과 그 의존성을 설치하고
(Python이 externally-managed 환경이면 먼저 동의를 구합니다), Obsidian vault를 감지하거나 원하는
노트 폴더를 직접 지정할 수 있게 합니다(Obsidian은 선택 사항입니다). 확인된 폴더는
`~/.config/synesis/config.json`에 기록됩니다.

## 쉬운 한국어

`plain-korean` 스킬은 ASD-STE100의 원칙에 따라 한국어 문서와 답변을 씁니다. 목표는 독자가 한 번 읽고
오해 없이 이해하는 글입니다. 글을 새로 쓰거나 고쳐 쓰거나 점검해 달라고 요청할 수 있습니다. 이후 답변을
이 방식으로 해 달라고 요청할 수도 있습니다.

## 설계 결정

- [지식 저장 구조: 도메인, 세부 주제, MOC](docs/decisions/2026-09-29-knowledge-structure.md) — 구현 계획에서 참조할 합의 내용과 미결정 사항입니다.

## 감사의 말

Synesis는 웹 문서를 읽을 때 [GPTaku (fivetaku)](https://github.com/fivetaku) 님의 Codex 플러그인
[`insane-search`](https://github.com/fivetaku/gptaku-plugins-codex/tree/main/plugins/insane-search-codex)를 사용합니다 (MIT License).
setup 스킬이 `gptaku-codex` 마켓플레이스에서 이 플러그인을 설치합니다.

`plain-korean` 스킬은 [Andrej Karpathy의 X 게시물](https://x.com/karpathy/status/2105819303471976479)에서 출발했습니다.
이 게시물은 LLM에게 ASD-STE100에 가까운 글을 요청하자고 제안합니다. 규칙은 ASD-STE100 Simplified Technical
English Issue 9의 원칙을 한국어에 맞게 바꿔 썼습니다. 이 저장소에는 표준 원문과 사전을 싣지 않습니다.
