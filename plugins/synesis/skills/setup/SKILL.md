---
name: setup
description: "Use when the user asks to set up, install, or configure Synesis — including first-time setup, registering an Obsidian vault or notes folder, or repairing a broken Synesis install."
---

# Synesis Setup

이 스킬 디렉터리 기준 `scripts/setup.sh`를 실행해 Synesis를 설정한다. **아래 절차를 손으로 대신 수행하지
않는다** — 의존성 설치와 config 기록은 항상 스크립트를 통해서만 한다. 웹 읽기 스킬 `deep-fetch`는
이 플러그인에 들어 있어서 따로 설치하지 않는다. setup은 그 의존성만 확인한다.

```
bash scripts/setup.sh
```

(이 SKILL.md 파일 기준 상대 경로. 이후 재실행 명령에서도 같은 디렉터리를 쓴다.)

## exit 0 — 완료

`[ok]` / `[warn]` / `[skip]` 각 줄과 마지막 `summary:` 줄을 한국어로 사용자에게 요약한다. 기록된 노트 폴더
경로는 스크립트가 출력한 그대로 보여준다 — 심볼릭 링크가 해소되어 사용자가 입력한 경로와 다를 수 있다.

새로 만든 기본 폴더를 골랐고 Obsidian이 설치되어 있다면(`[ok] Obsidian installed`), "Obsidian에서 보려면
'Open folder as vault'로 이 폴더를 한 번 열어 주세요"라고 안내한다. `obsidian.json`은 직접 수정하지 않는다.

## exit 2 — 사용자 확인 대기 (실패 아님)

실패가 아니라 다음 입력을 기다리는 상태다. `NEEDS_CONFIRMATION:` 줄을 전부 모아 **한 턴에 모두** 묻는다.

- **`deps`** — "deep-fetch 의존성 5개(curl_cffi, beautifulsoup4, pyyaml, pypdf, markdownify)를
  `[warn]` 줄에 나온 Python의 user-site(`~/Library/Python/<ver>`)에 설치해도 되는지" 확인한다.
  Homebrew의 site-packages는 건드리지 않는다는 점을 함께 설명한다.
- **`vault`** — 출력된 `default:` 경로를 1번 기본값으로, `candidate:` 줄(등록된 Obsidian vault)을 그
  다음 번호로, 마지막에 "다른 경로 직접 입력"을 붙여 하나의 목록으로 보여주고 "어느 폴더로 하시겠어요?"라고
  묻는다.
  - 기본값은 새 폴더를 권장하는 이유와 함께 설명한다: 기존 노트와 섞이지 않는 깨끗한 곳에서 시작하고,
    기존 노트가 필요하면 나중에 하나씩 가져오면 된다.
  - 기존 Obsidian vault를 고르면 synesis가 그 폴더에 노트를 직접 추가한다는 점을 알린다.
  - 후보가 0개이거나 Obsidian이 없으면 기본값과 "다른 경로 직접 입력"만 보여준다. Obsidian은 선택
    사항이다.
- **`create-dir`** — 출력된 절대경로와 부모 경로를 그대로 인용하며 "이 폴더가 없습니다. 만들까요?"라고
  묻는다.

승인된 항목만 붙여 재실행한다: `bash scripts/setup.sh --allow-user-site --vault "<path>" --create-vault`.
**폴더 생성은 `--create-vault` 승인이 있을 때만 일어난다.** 사용자가 기본값(`default:` 경로)을 고른 것은
그 폴더를 만드는 데 대한 승인이므로 `--vault "<default 경로>" --create-vault`로 바로 재실행한다(이미 있으면
그대로 쓴다). 후보 vault나 직접 입력한 경로에는 미리 붙이지 않는다.

config 키 이름은 `vault`지만 실제 뜻은 "노트 폴더"다. 사용자에게 설명할 때 "vault"라는 단어를 강요하지
말고 "노트 폴더"로 말한다. Obsidian 사용자는 그 vault 폴더를 지정하면 되고, Obsidian을 쓰지 않는 사용자는
아무 폴더나 지정하면 된다. Obsidian은 선택 사항이다.

**deps를 거부하면** `[warn]`으로 안내하고, 스크립트가 `[warn] ... run manually: PIP_BREAK_SYSTEM_PACKAGES=1 bash
"<deep-fetch 스킬 경로>/scripts/bootstrap.sh" --install` 형태로 출력한 수동 명령을 그대로 인용해 알려준 뒤
(`bootstrap.sh`는 이 스킬이 아니라 같은 플러그인의 deep-fetch 스킬 안에 있다)
`--skip-deps --vault "<path>"`로 재실행해 노트 폴더 등록만 마친다. `--skip-deps` 없이 재실행하면 deps
요청이 다시 나와 exit 2가 반복된다.

**vault를 거부하거나 등록할 폴더가 없다고 답하면**, vault는 **한 번의 setup 실행에서 최대 한 번만** 묻고
거기서 멈춘다. 재실행하지 않는다. "설정이 미완료이며 config는 기록되지 않았다"와 "나중에
`bash <이 스킬 디렉터리>/scripts/setup.sh --vault <path>`로 이어서 하면 된다"를 보고한다. 노트 폴더 없는
config는 절대 쓰지 않는다.

**왕복 횟수.** 기본값을 고르면 2회다: (1) `setup.sh` → exit 2, (2) `setup.sh --vault <default> --create-vault`
→ exit 0. 직접 입력한 경로가 없는 폴더일 때의 최악 경로는 3회다: (1) `setup.sh` → exit 2 (`deps`?, `vault`),
(2) `setup.sh --vault <p>` → exit 2 (`create-dir <abs p>`), (3) `setup.sh --vault <p> --create-vault` →
exit 0. 사용자가 (1)에서 이미 "없으면 만들어 주세요"라고 답했다면 (2)에서 곧바로 `--create-vault`를 함께
붙여 3회를 2회로 줄인다. 미리 묻지 않고 임의로 붙이지 않는다. `deps`와 `create-dir`는 한 실행에서 동시에
대기할 수 있고, 그때도 한 턴에 둘 다 묻는다.

## exit 1 — 치명 실패

`[fail]` 줄을 그대로 인용해 원인을 보고한다. 재시도할지는 사용자에게 먼저 확인한다.

`[fail] deep-fetch needs Python 3.10 or newer`이면 deep-fetch가 쓸 Python이 없다는 뜻이다(macOS 기본
`python3`는 3.9다). Python 3.10 이상을 설치하라고(예: `brew install python`) 알리고, 그동안 노트 폴더만
등록하려면 `--skip-deps --vault "<path>"`로 재실행할 수 있다고 제안한다.

## 금지 사항

- `~/.config/synesis/config.json`을 직접 편집하지 않는다.
- `pip install`을 직접 실행하지 않는다.
- 항상 `scripts/setup.sh`를 통해서만 상태를 바꾼다.
