---
title: "Gemini 웹앱 @Gmail @Google Calendar로 사람 개입 없이 일정 등록하기 — 그리고 중복 2건"
description: "Ask Gemini 사이드 패널 대신 gemini.google.com에서 @Gmail·@Google Calendar 앱 호출로 같은 일을 시켰다. 브라우저 조작은 Claude가 전부 했고, 결과는 엉뚱한 메일 + 확인 없는 등록 + 중복 2건이었다. 실패 사례로 남긴다."
weight: 20
date: 2026-09-11
lastmod: 2026-09-11
icon: "event_busy"
usecase: true
categories: ["업무 자동화"]
tools: ["Gemini 웹앱", "Gmail", "Google Calendar", "ego-browser", "Claude Code"]
difficulty: "중급"
duration: "3분"
tags: ["Gemini앱", "일정관리", "자동화", "실패사례", "중복등록"]
---

## 어떤 문제를 해결하나

[Ask Gemini 사이드 패널 사례]({{< relref "/docs/usecases/automation/gmail-event-to-calendar-ask-gemini" >}})는 "메일을 열어 두고 → 패널을 열고 → 한 줄 입력" 세 번의 손이 갑니다.
gemini.google.com 웹앱은 `@Gmail`, `@Google Calendar` 로 앱을 직접 호출할 수 있으니 **탭을 열 필요 없이 한 문장**으로 끝나야 합니다. 그리고 웹앱은 일반 웹페이지라 에이전트 브라우저로 입력·전송까지 완전 자동화됩니다.

그래서 해 봤고, **결과는 나빴습니다.** 이 페이지는 잘 된 사례가 아니라 "왜 사이드 패널 방식이 더 안전한가" 를 보여 주는 대조군입니다.

## 사전 준비

- gemini.google.com 에 로그인, Workspace 앱(Gmail, Calendar) 연결 ([gemini.google.com/apps](https://gemini.google.com/apps))
- 에이전트가 조작할 브라우저 — 여기서는 ego-browser(로그인 공유 Chromium)
- 등록 대상 메일: `Microsoft Event Registration Confirmation` (Agent in a Day, 9/22 9:00–17:00 Eastern)

## 단계별 사용법

{{< step title="한 문장으로 요청한다 (사람은 여기까지)" image="01-prompt.png" caption="새 채팅에 @Gmail·@Google Calendar 를 명시한 프롬프트. 이 입력도 Claude가 넣었습니다." >}}
{{< prompt title="입력 프롬프트" >}}
@Gmail 에서 Microsoft 행사 등록 확인 메일(Agent in a Day)을 찾아서, 그 일정을 @Google Calendar 에 추가해줘. 제목·일시(시간대 포함)·장소를 먼저 보여주고 등록해.
{{< /prompt >}}

"먼저 보여주고 등록해" 를 붙인 건 확인 단계를 기대해서였습니다. 사이드 패널은 항상 Cancel / Add Event 카드를 먼저 보여 줬으니까요.

```js
await page.click('loc=role:textbox[name*="Gemini 프롬프트"]');
await page.keyboard.insertText("@Gmail 에서 Microsoft 행사 등록 확인 메일 …");
await page.keyboard.press("Enter");
```
{{< /step >}}

{{< step title="A/B 두 답이 뜨고, 둘 다 엉뚱한 메일을 골랐다" image="02-ab-options.png" caption="'어떤 대답이 더 유용한가요?' 비교 화면. 옵션 A·B 모두 Microsoft 메일이 아니라 Meetup 그룹 메일을 잡았습니다." >}}
Gemini가 응답 비교 실험(옵션 A / 옵션 B)을 띄웠습니다. 문제는 내용입니다.

| | 요청한 메일 | Gemini가 찾은 메일 |
| --- | --- | --- |
| 발신 | Microsoft (MS Event) | Texas Information Technology Meetup Group |
| 제목 | Agent in a Day - NetCom Learning - United States | Agent in a Day \| Hands on Workshop |
| 일시 | 9/22 9:00–17:00 **Eastern** | 9/22 8:00–16:00 **Central** |

같은 행사의 다른 채널 메일입니다. 프롬프트에 "Microsoft" 를 썼는데도 제목 키워드 `Agent in a Day` 가 더 세게 먹혔습니다.
사이드 패널은 **열어 둔 그 메일**만 보기 때문에 이런 오매칭이 구조적으로 없습니다.
{{< /step >}}

{{< step title="확인 카드 없이 두 옵션이 각각 등록해 버렸다" image="03-both-added.png" caption="옵션 A·B 둘 다 '성공적으로 추가했습니다'. 캘린더에는 같은 일정이 두 개 생겼습니다." >}}
"먼저 보여주고 등록해" 라고 했지만 보여 주는 것과 등록이 **한 응답 안에서** 이뤄졌습니다. 그리고 A/B 비교의 두 옵션이 각각 캘린더 API를 호출해서, 캘린더 MCP로 확인해 보니:

```
17:50:11  Agent in a Day | Hands on Workshop  9/22 08:00–16:00 CDT  (옵션 A)
17:50:18  Agent in a Day | Hands on Workshop  9/22 08:00–16:00 CDT  (옵션 B)
09-08     Agent in a Day | Hands on Workshop  9/22 08:00–16:00 CDT  (Gmail 자동 등록, 원래 있던 것)
```

원래 Gmail이 자동으로 넣어 둔 일정까지 합쳐 **같은 일정 3개**. 요청한 Microsoft 행사(9:00 Eastern)는 등록되지 않았습니다.
{{< /step >}}

## 결과

원한 것: 일정 1개 추가. 얻은 것: 엉뚱한 일정 중복 2개, 원하는 일정 0개.
소요 3분, 뒷정리(중복 삭제)는 사람이 캘린더에서 해야 합니다 — Claude의 캘린더 삭제 호출은 안전장치에 막혔습니다. 막히는 게 맞습니다.

같은 일을 사이드 패널로 하면: 열어 둔 메일만 읽음 → 카드로 확인 → 사람이 Add Event. 손은 세 번 더 가지만 오등록이 없습니다.

## 주의사항

- **`@Gmail` 검색은 제목 키워드에 끌려갑니다.** 발신자·날짜를 같이 못 박으세요: `발신자가 Microsoft 이고 제목에 Registration Confirmation 이 들어간 메일`. 그래도 확인 단계는 별도 턴으로 분리하세요: 1턴 "찾아서 보여만 줘", 2턴 "그걸 등록해".
- **"보여주고 등록해" 는 한 턴에서 확인 절차가 되지 않습니다.** 모델은 보여 주는 것과 등록을 같은 응답에서 끝냅니다. 등록 전 멈추게 하려면 등록 지시를 프롬프트에서 빼야 합니다.
- **A/B 응답 비교가 뜨면 부작용도 두 번입니다.** 읽기 작업이면 상관없지만, 캘린더 추가·메일 발송 같은 쓰기 작업에서는 치명적입니다. 쓰기 작업은 임시 채팅(`임시 채팅` 버튼)에서 하면 비교 실험이 덜 뜹니다 — 보장은 아닙니다.
- **에이전트가 쓰기 작업을 자동화할 때는 "실행 전 사람 확인" 을 프롬프트가 아니라 절차로 넣으세요.** 이 사례처럼 프롬프트에 부탁하는 건 안 먹힙니다. 에이전트 쪽에서 "등록해" 를 보내기 전에 멈추고 사람에게 묻게 해야 합니다.
- 뒷정리: 캘린더에서 9/22 `Agent in a Day | Hands on Workshop` 이 3개 보이면, `Gmail에서 수신한 이메일에서 생성된 일정` 설명이 붙은 것 하나만 남기고 지우면 됩니다.

## 응용

이 실패에서 그대로 쓸 수 있는 것은 **읽기 전용 작업**입니다.

- `@Gmail 에서 이번 주 받은 행사 안내 메일 목록을 일시·장소와 함께 표로` → 등록은 사이드 패널이나 사람이
- `@Google Calendar 다음 주 일정 중 온라인 링크 없는 것만` → 누락 점검
- 쓰기 작업은 2턴으로: "후보 보여 줘" → 사람이 고르고 → "이걸 등록해"
