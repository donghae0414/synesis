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

## 설계 결정

- [지식 저장 구조: 도메인, 세부 주제, MOC](docs/decisions/2026-09-29-knowledge-structure.md) — 구현 계획에서 참조할 합의 내용과 미결정 사항입니다.

## 감사의 말

Synesis는 웹 문서를 읽을 때 [GPTaku (fivetaku)](https://github.com/fivetaku) 님의 Codex 플러그인
[`insane-search`](https://github.com/fivetaku/gptaku-plugins-codex/tree/main/plugins/insane-search-codex)를 사용합니다 (MIT License).
setup 스킬이 `gptaku-codex` 마켓플레이스에서 이 플러그인을 설치합니다.
