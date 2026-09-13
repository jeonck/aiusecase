---
title: "Claude 스킬 만들고 쓰기 — 30건 쓰며 굳어진 규칙을 프로젝트 스킬 aiusecase-writer로"
description: "스킬은 SKILL.md 한 장 + references + scripts 폴더다. skill-creator 스킬로 뼈대를 만들고, 이 사이트 30건을 쓰며 반복한 규칙(번들 구조·숏코드·캡처 마스킹·.md 함정·커밋 형식)과 매번 다시 짜던 스크립트 2개를 담아 저장소 .claude/skills/에 넣었다. 같은 세션에서는 못 불러온다는 점까지."
weight: 14
date: 2026-09-12
lastmod: 2026-09-12
icon: "extension"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "skill-creator"]
difficulty: "중급"
duration: "10분"
tags: ["Claude스킬", "SKILL.md", "프로젝트스킬", "자동화", "규칙화"]
---

## 어떤 문제를 해결하나

Claude 에게 같은 종류의 일을 반복시키면 매번 같은 설명을 다시 합니다. "front matter 는 이 키로, 캡처는 이렇게 가리고, 번들 안 `.md` 는 404 나니까 `.txt` 로…". 이 사이트 사례 30건을 쓰는 동안 그 설명이 대화마다 되풀이됐고, 터미널 렌더 스크립트는 여섯 번 다시 짰습니다.

**스킬**은 그 반복을 파일로 굳히는 것입니다. `SKILL.md` 한 장(언제 쓰는지 + 절차) 에 참고 문서와 스크립트를 폴더로 붙이면, 다음 세션의 Claude 는 그걸 읽고 시작합니다. 이 사례는 `skill-creator` 스킬로 `aiusecase-writer` 스킬을 만들어 저장소에 넣은 기록입니다 — 스킬로 스킬을 만든 셈입니다.

## 사전 준비

- Claude Code (데스크톱 앱 또는 CLI). 스킬은 `~/.claude/skills/<이름>/`(개인) 또는 저장소의 `.claude/skills/<이름>/`(프로젝트, git 으로 공유)에 둡니다
- `skill-creator` 스킬 — 뼈대 생성(`init_skill.py`)과 검증·패키징(`package_skill.py`) 스크립트가 들어 있음
- 굳힐 만큼 반복된 작업. 세 번째 같은 설명을 하고 있다면 스킬 후보

## 단계별 사용법

{{< step title="skill-creator 로 뼈대를 만든다" image="01-skill-tree.png" caption="init_skill.py 가 만든 폴더에서 예시 파일을 지우고 채운 결과. SKILL.md + references 2 + scripts 2. frontmatter 의 description 이 '언제 이 스킬을 쓰나'." >}}
{{< prompt title="입력 프롬프트" >}}
클로드 스킬 사용법에 관한 유스케이스를 추가
{{< /prompt >}}

Claude 는 먼저 `skill-creator` 스킬을 불러 절차를 읽습니다(스킬 사용 규칙: 해당되는 스킬이 있으면 그걸 먼저 읽는다). 절차의 1단계 "구체적 사용 예를 이해한다" 는 이 세션에 30건이 있어 건너뛰고, 바로 뼈대를 만듭니다.

```bash
python3 ~/.claude/skills/skill-creator/scripts/init_skill.py aiusecase-writer --path .claude/skills
```

`.claude/skills/` 에 둔 이유: **저장소와 함께 배포**됩니다. 이 repo 를 clone 한 누구의 Claude 든 같은 규칙으로 사례를 씁니다. `~/.claude/skills/` 는 내 Mac 에서만.

스킬의 뼈대는 셋입니다.

| 파일 | 역할 | 언제 읽히나 |
| --- | --- | --- |
| `SKILL.md` frontmatter (`name`, `description`) | 언제 쓰는 스킬인지 | 항상 (목록에 상주) |
| `SKILL.md` 본문 | 절차·규칙 | 스킬이 호출될 때 |
| `references/`, `scripts/` | 상세 문서, 실행 코드 | 필요할 때만 |

이 3단계 로딩이 핵심입니다. `description` 은 항상 컨텍스트에 있으니 짧고 정확하게, 본문은 5천 단어 이하, 긴 건 references 로.
{{< /step >}}

{{< step title="SKILL.md 에 절차와 목소리를, references 에 세부를" image="02-skill-body.png" caption="SKILL.md 본문. 6단계 워크플로, 목소리 규칙, 스크립트 목록. 명령형으로, 2인칭 없이." >}}
30건에서 뽑은 규칙이 이렇게 들어갔습니다.

- **워크플로 6단계** — 스캐폴드 → 작업하며 캡처 → index.md → 번들 파일(`.md`→`.txt`) → `hugo` 빌드 exit 0 확인 → 커밋·푸시
- **목소리** — 한국어, 숫자 우선, 실패는 본문에 남긴다, 마지막 세 섹션 고정
- **references/page-structure.md** — front matter 키 전부, 섹션 순서, 숏코드 3종 문법, relref 규칙
- **references/captures.md** — 상황별 캡처 방법 표(ego-browser / AppleScript+screencapture / Claude 앱 / 터미널 렌더 / 비디오 프레임), 마스킹 체크리스트(이메일·아바타·파일명·탭·크레딧·키)

`SKILL.md` 는 **다른 Claude 인스턴스가 읽는 문서**입니다. 그래서 "You should…" 가 아니라 "Do X. Never Y." 로, 당연한 건 빼고 비직관적인 것만 씁니다 — 예: "번들 안 `.md` 는 Hugo 가 콘텐츠로 삼켜 404 난다", "존재하지 않는 페이지로 relref 걸면 빌드가 깨진다". 둘 다 이번 주에 실제로 겪은 것입니다.
{{< /step >}}

{{< step title="매번 다시 짜던 코드를 scripts/ 로" image="03-mask-result.png" caption="scripts/mask.py 로 Drive 캡처의 파일 목록과 인사말을 픽셀화하고 탭줄을 잘라낸 결과. 위는 실제 명령." >}}
스킬의 `scripts/` 는 "같은 코드를 세 번째 짜고 있다" 는 신호에 대한 답입니다.

- `render_terminal.py` — 명령/출력 줄을 터미널 PNG 로. `$` 줄은 초록, `//` 주석은 주황, FAIL/error 는 빨강. **이 사례의 이미지 1·2·4 가 이 스크립트 결과물**입니다
- `mask.py` — `--box x0,y0,x1,y1` 로 픽셀화, `--crop` 으로 잘라내기. 위 화면이 결과

스크립트는 컨텍스트에 읽어 들이지 않고 **실행만** 하면 되니 토큰도 아낍니다. 6번 다시 짠 코드가 이제 한 줄 호출입니다.
{{< /step >}}

{{< step title="검증·패키징, 그리고 '같은 세션에서는 못 부른다'" image="04-validate-and-invoke.png" caption="package_skill.py 가 frontmatter·이름·구조를 검증하고 zip 을 만듦. 바로 Skill 도구로 부르면 Unknown skill — 스킬 목록은 세션 시작 때 읽는다." >}}
```bash
python3 ~/.claude/skills/skill-creator/scripts/package_skill.py .claude/skills/aiusecase-writer ./dist
# ✅ Successfully packaged skill to: ./dist/aiusecase-writer.zip
```

검증은 frontmatter 형식, `name` 규칙, description 품질, 폴더 구조를 봅니다. zip 은 다른 사람에게 건네는 배포본 — [aiusecase-writer.zip](aiusecase-writer.zip).

만들자마자 `Skill(skill="aiusecase-writer")` 로 불러 봤더니 **`Unknown skill`**. 사용 가능한 스킬 목록은 세션이 시작될 때 한 번 읽습니다. 그래서 이 사례 자체는 스킬 파일을 직접 읽고 그 규칙대로 썼고, **다음 세션부터** `/aiusecase-writer` 한 줄로 부릅니다.
{{< /step >}}

## 결과

| | |
| --- | --- |
| 만든 것 | `.claude/skills/aiusecase-writer/` — SKILL.md 60줄, references 2, scripts 2 |
| 걸린 시간 | 1분 7초 (init → 패키징). 규칙은 30건을 쓰며 이미 정해져 있었음 |
| 대체하는 것 | 사례마다 반복하던 설명 ~15줄, 6번 다시 짠 터미널 렌더 코드 |
| 호출 | 다음 세션부터 `/aiusecase-writer 이번 작업을 사례로 남겨줘` |
| 배포 | git 에 포함 — clone 하는 모든 Claude 가 같은 규칙 |

스킬은 "Claude 에게 가르친 것을 파일로 저장하는 방법" 입니다. 대화가 끝나면 사라지는 지식이 저장소에 남습니다.

## 주의사항

- **세 번 반복한 뒤에 만드세요.** 한 번 한 일을 스킬로 만들면 규칙이 아니라 추측이 들어갑니다. 이 스킬의 모든 줄은 실제로 겪은 것입니다.
- **description 이 트리거입니다.** "유스케이스 작성", "사례 추가", "이 작업을 사례로 남겨" 처럼 사용자가 실제로 쓸 말을 넣으세요. 여기가 약하면 스킬이 있어도 안 불립니다.
- **SKILL.md 는 짧게, 세부는 references 로.** 본문이 길면 매 호출마다 컨텍스트를 먹습니다. 표·문법·체크리스트는 references 에 두고 SKILL.md 에서 파일명만 가리킵니다.
- **새 스킬은 새 세션에서.** 같은 세션에서 `Unknown skill` 이 나오는 건 정상입니다.
- **프로젝트 스킬은 git 에 들어갑니다.** 스크립트에 개인 경로·토큰이 없는지 확인하세요. 이 스킬의 스크립트는 `git rev-parse` 로 저장소 루트를 찾아 폰트 경로를 잡습니다.
- 명령형으로 쓰세요. "You should mask emails" 가 아니라 "Pixelate email addresses before commit". 읽는 쪽이 사람이 아닙니다.

## 응용

- 반복되는 문서 작업마다 하나씩: 주간 보고 스킬, 릴리스 노트 스킬, PR 설명 스킬
- 팀 저장소의 `.claude/skills/` 에 코드 리뷰 체크리스트·커밋 규칙 스킬 → 신입의 Claude 도 첫날부터 팀 규칙
- 이 사이트의 다른 반복: "캡처 → 마스킹 → 번들" 만 떼어 `capture-masker` 스킬로
- 스킬 안에 `scripts/check.sh` 를 두어 완료 조건(빌드 exit 0, 이미지 폭, `.md` 없음)을 자동 검사
