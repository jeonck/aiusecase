---
title: "ego lite 브라우저로 로그인된 웹앱을 Claude가 직접 조작하게 하기"
description: "Chrome 확장은 끊기고 컴퓨터 사용은 브라우저에 읽기 전용일 때, 에이전트용 Chromium인 ego lite를 쓰면 NotebookLM 업로드·Gemini 웹앱 입력·Drive 검색을 Claude가 스크립트 한 장으로 끝낸다. 이 사이트의 사례 세 개가 이걸로 만들어졌다."
weight: 30
date: 2026-09-11
lastmod: 2026-09-11
icon: "smart_toy"
usecase: true
categories: ["업무 자동화"]
tools: ["ego lite", "ego-browser CLI", "Claude Code"]
difficulty: "중급"
duration: "10분"
tags: ["브라우저자동화", "에이전트", "ego-browser", "NotebookLM", "Gemini앱", "파일업로드"]
---

## 어떤 문제를 해결하나

"Claude가 브라우저를 대신 조작한다" 는 말은 실제로 세 가지 경로가 있고, 하루 동안 셋 다 써 보니 각각 벽이 있었습니다.

| 경로 | 되는 것 | 이번에 부딪힌 벽 |
| --- | --- | --- |
| 컴퓨터 사용 (화면 클릭) | 네이티브 앱 조작, 화면 캡처 | 브라우저는 **읽기 전용** — 클릭·타이핑 차단 |
| Claude in Chrome 확장 | 웹페이지 DOM 클릭·입력 | 탭 그룹이 호출마다 끊김, 파일 업로드 **10MB 상한**, 사이드 패널(브라우저 UI)은 접근 불가 |
| **ego lite** (에이전트용 Chromium) | 웹페이지 전부 + 파일 선택창 가로채기 + 캡처 파일 저장 | 브라우저 자체 UI(Chrome 전용 Ask Gemini 패널 등)는 당연히 없음 |

ego lite 는 사람과 에이전트가 같이 쓰도록 만든 Chromium 입니다. Chrome 프로필을 가져와 **로그인 상태를 공유**하고, `ego-browser` CLI 로 Node.js 스크립트를 던지면 탭을 열고 읽고 클릭합니다.
이 사이트의 [NotebookLM]({{< relref "/docs/usecases/research/notebooklm-report-datatable-mindmap" >}}), [Gemini 웹앱 일정 등록]({{< relref "/docs/usecases/automation/gemini-webapp-gmail-to-calendar-autonomous" >}}), [Gemini 웹앱 Drive 요약]({{< relref "/docs/usecases/research/gemini-webapp-drive-checklist" >}}) 세 사례가 사람 손 없이 이걸로 만들어졌습니다.

## 사전 준비

- ego lite 설치 + `ego-browser onboarding` 완료. Chrome 프로필을 가져오면 Google 로그인이 그대로 넘어옵니다 (`ego-browser import --browser chrome --profile Default`)
- Claude Code 에 `ego-browser` 스킬 (사용법·API 레퍼런스가 스킬 문서에 들어 있어 Claude 가 알아서 읽습니다)
- 버전: ego-browser 0.5.0 / Chromium 152 / Node 24 기준

## 단계별 사용법

{{< step title="스페이스 하나 열고, 관찰 → 행동 → 관찰을 한 스크립트에 넣는다" image="01-script.png" caption="NotebookLM 사례에서 실제로 돌린 스크립트 골자. 파일 선택창 가로채기와 캡처 저장이 한 heredoc 안에 있습니다." >}}
{{< prompt title="입력 프롬프트 (사람이 쓴 전부)" >}}
컴퓨터 유즈로 이번에 구글의 notebooklm 활용 사례를 만들어줘.
2026 State of Infrastructure Automation - The AI Readiness Gap .pdf 파일을 finder에 열어 두었어.
{{< /prompt >}}

Claude 는 `ego-browser nodejs <<'EOF' … EOF` 형태로 스크립트를 실행합니다. 원칙 세 가지:

- **목표 하나 = TaskSpace 하나.** `taskSpace("이름")` 으로 만들고 `spaceId` 를 기억해, 다음 라운드는 `taskSpace(3)` 으로 이어 갑니다. 탭과 `p1` 같은 페이지 라벨은 라운드 사이에 살아남고, JS 변수는 죽습니다
- **한 heredoc 에 행동 + 기대 상태 대기 + 다음 스냅샷.** 마지막에 `console.log(await page.snapshot())` 을 찍어 두면 다음 라운드가 관찰 없이 바로 행동합니다
- **캡처는 `page.screenshot({ path })`.** 화면 기록 권한도, 창 좌표도 필요 없습니다. 이 사이트의 캡처 문제가 여기서 사라졌습니다
{{< /step >}}

{{< step title="접근성 스냅샷의 ref 와 loc 으로 요소를 집는다" image="02-snapshot.png" caption="snapshot() 출력. 버튼·입력창마다 ref 번호와 loc 셀렉터가 붙어 있고, 맨 아래 dialog 가 떠 있는 것까지 보입니다." >}}
좌표 대신 **의미**로 집습니다. `@25` 같은 ref 는 한 라운드 안에서만 유효하고, `loc=css:…` / `loc=role:button[name="…"]` / `text=…` 는 라운드를 넘어서도 씁니다.

```js
await page.click('loc=role:button[name="데이터 표"]');      // 역할 + 이름
await page.fill('loc=css:textarea[aria-label="만들려는 데이터 표에 대한 설명"]', "…");
await page.click("text=지금 생성");                          // 화면 글자
```

스냅샷은 **팝업을 잡는 데** 특히 유용합니다. NotebookLM 에서 업로드 직전에 "5시간마다 한도 초기화" 안내 대화상자가 겹쳐 떴는데, 스냅샷 끝에 `dialog [ref=61]` 로 드러나서 먼저 닫고 진행했습니다. 사람은 무의식적으로 닫는 팝업이 자동화에서는 이후 클릭을 전부 빗나가게 합니다.
{{< /step >}}

{{< step title="파일 선택창을 가로채 16.7MB PDF 를 올린다" image="03-file-chooser.png" caption="NotebookLM 소스 추가 대화상자. '파일 업로드'를 누르면 OS 파일 선택창이 뜨는데, 그걸 스크립트가 받아 경로를 직접 넣습니다." >}}
```js
const chooser = page.waitForFileChooser({ timeout: 10000 });   // 클릭 전에 먼저 기다린다
await page.click("text=파일 업로드");
await (await chooser).setFiles("/Users/mac/Downloads/….pdf");
```

Chrome 확장은 파일을 base64 로 실어 보내서 10MB 상한이 있습니다. ego lite 는 브라우저가 로컬 경로를 직접 읽으므로 상한이 사이트 쪽(NotebookLM 200MB)뿐입니다. 이게 NotebookLM 사례를 자동화할 수 있었던 결정적 차이입니다.
{{< /step >}}

{{< step title="Gemini 웹앱처럼 입력창이 특이한 페이지는 키보드 API 로" image="04-gemini-webapp.png" caption="Gemini 웹앱에 에이전트가 넣은 프롬프트와 A/B 응답. 사이드 패널은 못 건드리지만 웹앱은 일반 페이지라 전부 됩니다." >}}
Gemini 웹앱의 프롬프트 입력창은 `textarea` 가 아닌 contenteditable 이라 `fill()` 이 안 먹습니다. 클릭해서 포커스를 준 뒤 키보드로 넣습니다.

```js
await page.click('loc=role:textbox[name*="Gemini 프롬프트"]');
await page.keyboard.insertText("@Gmail 에서 … @Google Calendar 에 추가해줘");
await page.keyboard.press("Enter");
await page.waitForFunction(() => !document.querySelector('button[aria-label*="중지"]'), undefined, { timeout: 120000 });
```

응답 완료는 "응답 중지" 버튼이 사라지는 것으로 잡았습니다. 고정 `waitForTimeout` 보다 관찰 가능한 조건이 낫습니다.
결과 자체는 [실패 사례]({{< relref "/docs/usecases/automation/gemini-webapp-gmail-to-calendar-autonomous" >}})였지만, 그건 Gemini 의 판단 문제지 조작 문제가 아니었습니다 — 오히려 "자동화가 잘 될수록 잘못된 쓰기 작업도 잘 된다" 는 교훈이 남았습니다.
{{< /step >}}

## 결과

하루에 세 사례, 브라우저 조작 0회 사람 개입. NotebookLM 은 업로드 → 질문 → 스튜디오 생성 2종 → 결과 열기까지 스크립트 8개.
그전에 Chrome 확장으로 같은 걸 시도했을 땐 탭 그룹 오류로 세 번 실패하고 결국 사람이 입력했습니다.

부수 효과: 캡처가 `page.screenshot` 으로 바로 파일이 되니, [화면 기록 권한과 창 좌표 계산]({{< relref "/docs/usecases/writing/claude-computer-use-screenshot-manual" >}}) 이 필요 없어졌습니다. 웹 화면 캡처는 앞으로 이쪽입니다.

## 주의사항

- **로그인 상태를 공유한다 = 에이전트가 내 계정으로 뭐든 할 수 있다.** 이 세션에서도 Drive 업로드와 캘린더 삭제는 Claude Code 의 안전장치(분류기)가 막았습니다. 막히는 게 정상입니다. 쓰기 작업(등록·발송·삭제)은 스크립트가 아니라 사람이 마지막 클릭을 하도록 `task.handOff()` 로 넘기세요.
- **ref 는 행동 직후 무효가 됩니다.** `click` 한 뒤 같은 라운드에서 `@25` 를 다시 쓰면 실패합니다. 여러 행동을 연달아 할 땐 `loc=…` 셀렉터를 쓰거나 스냅샷을 다시 찍습니다.
- **`text=…` 는 유일해야 합니다.** `text=스튜디오` 가 패널 제목과 안내 문구 두 곳에 걸려 에러가 났습니다. 에러 메시지가 후보를 알려 주니, 그걸 보고 `loc=role:` 로 좁히면 됩니다.
- **좌표 클릭은 최후 수단이고, 결과를 반드시 확인합니다.** 스튜디오 목록 항목이 접근성 트리에 안 잡혀 좌표로 눌렀다가 옆 버튼(데이터 표 만들기)이 눌려 엉뚱한 대화상자가 열렸습니다. 클릭 뒤 스크린샷 한 장이 이런 걸 잡습니다.
- **브라우저 자체 UI 는 범위 밖입니다.** Chrome 의 Ask Gemini 사이드 패널, 확장 프로그램 팝업, 주소창은 ego lite 에도 없거나 못 건드립니다. 그런 사례는 여전히 [사람이 화면을 맞추고 Claude 가 찍는 방식]({{< relref "/docs/usecases/research/drive-pdf-summary-ask-gemini" >}})입니다.
- **끝나면 `task.finish({ keep: [] })`.** 결과 페이지를 사용자가 봐야 하면 `keep: ["p1"]`. 사용자가 직접 연 탭은 `keep: []` 이어도 닫히지 않습니다.
- 스크립트마다 새 Node 프로세스라 변수는 안 남고, 스페이스·탭·라벨만 남습니다. `spaceId` 를 대화에 남겨 두세요.

## 응용

- 사내 포털·그룹웨어처럼 **API 가 없는 로그인 웹앱**의 반복 조회 (결재 대기 목록, 근태 조회) → 스크립트로 읽어 표로
- SaaS 관리 콘솔에서 **설정값 100개 읽어 오기** — 화면마다 스냅샷 → `page.evaluate` 로 일괄 추출
- 이 사이트의 모든 웹 사례 캡처를 `page.screenshot` 으로 재촬영해 화면 기록 권한 의존 제거
- 쓰기 작업은 "후보를 읽어 표로 보여 주기" 까지만 자동화하고, 실행은 `handOff()` 로 사람에게
