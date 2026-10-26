[English](README.md) | **한국어**

# Synesis

> **지식은 모아둔 것이 아니라, 이해하게 된 것이다.**

대화를 통해 자라나는 개인 지식 시스템.

도서관은 정보를 기억한다.  
Synesis는 이해를 기억한다.

## 설치

Synesis는 Claude Code, Codex, pi에서 동작합니다. 세 곳 모두 `plugins/synesis/skills/`의 같은 스킬을
읽습니다.

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

## 설정

설치한 뒤 에이전트에게 "synesis 설정해줘"라고 요청하세요. setup 스킬은 다음을 합니다.

- `deep-fetch`에 필요한 Python 패키지를 확인하고 설치합니다(Python이 externally-managed 환경이면 먼저
  동의를 구합니다).
- Obsidian vault를 감지하거나, 원하는 노트 폴더를 직접 지정하게 합니다(Obsidian은 선택 사항입니다).
- 확인된 폴더를 `~/.config/synesis/config.json`에 기록합니다.

`deep-fetch`는 Python 3.10 이상이 필요합니다. macOS 기본 `python3`는 3.9이므로, 새 버전이 없으면
설치하세요(예: `brew install python`).

## 웹 읽기: deep-fetch

`deep-fetch` 스킬은 공개 웹 페이지를 읽습니다. 일반 HTTP 클라이언트를 막는 페이지도 읽을 수 있습니다.
먼저 공식 공개 API(Reddit, X, YouTube, Hacker News, arXiv 등)를 시도하고, 그다음 TLS 지문을 흉내 내는
수집 체인을, 마지막으로 로컬 브라우저를 씁니다. 로그인과 유료 벽 앞에서는 멈춥니다. 실행 중에 생기는
상태(로그, 사이트별 학습 기록, 브라우저 패키지)는 `~/.local/state/deep-fetch/`에 둡니다.

법과 각 사이트의 이용 약관을 지켜 사용할 책임은 사용자에게 있습니다.

## 쉬운 한국어

`plain-korean` 스킬은 ASD-STE100의 원칙에 따라 한국어 문서와 답변을 씁니다. 목표는 독자가 한 번 읽고
오해 없이 이해하는 글입니다. 글을 새로 쓰거나 고쳐 쓰거나 점검해 달라고 요청할 수 있습니다. 이후 답변을
이 방식으로 해 달라고 요청할 수도 있습니다.

## 설계 결정

- [지식 저장 구조: 도메인, 세부 주제, MOC](docs/decisions/2026-09-29-knowledge-structure.md) — 구현 계획에서 참조할 합의 내용과 미결정 사항입니다.

## 개발

- `bash plugins/synesis/skills/setup/tests/run-cases.sh`: setup 스크립트를 테스트합니다.
- `bash plugins/synesis/skills/deep-fetch/scripts/smoke.sh`: deep-fetch 점검을 실행합니다.
- `bash scripts/check-manifests.sh`: Claude Code, Codex, pi 매니페스트의 이름과 버전이 같은지 확인합니다.

## 감사의 말

`deep-fetch`는 [GPTaku (fivetaku)](https://github.com/fivetaku) 님의
[`insane-search`](https://github.com/fivetaku/insane-search)(MIT License)를 바탕으로 한 포크입니다.
원작자는 Synesis와 관계가 없고 이 포크를 보증하지 않습니다. 원본 커밋과 바꾼 내용은
[`UPSTREAM.md`](plugins/synesis/skills/deep-fetch/UPSTREAM.md)에 모두 적었습니다.

`plain-korean` 스킬은 [Andrej Karpathy의 X 게시물](https://x.com/karpathy/status/2105819303471976479)에서 출발했습니다.
이 게시물은 LLM에게 ASD-STE100에 가까운 글을 요청하자고 제안합니다. 규칙은 ASD-STE100 Simplified Technical
English Issue 9의 원칙을 한국어에 맞게 바꿔 썼습니다. 이 저장소에는 표준 원문과 사전을 싣지 않습니다.

## 라이선스

MIT. [`LICENSE`](LICENSE)를 보세요. `deep-fetch`는 원본 저작권 표시를
[`plugins/synesis/skills/deep-fetch/LICENSE`](plugins/synesis/skills/deep-fetch/LICENSE)에 그대로 둡니다.
