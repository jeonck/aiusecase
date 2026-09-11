---
title: "매뉴얼의 사전 준비 항목을 공식 도움말로 검증하기"
description: "써 놓은 매뉴얼이 정말 맞는지, Claude Code가 공식 도움말 페이지를 직접 읽어 대조하고 틀린 항목을 고쳐 diff로 보여준다."
weight: 10
date: 2026-09-11
lastmod: 2026-09-11
icon: "fact_check"
usecase: true
categories: ["리서치·학습"]
tools: ["Claude Code", "WebSearch", "WebFetch"]
difficulty: "초급"
duration: "5분"
tags: ["팩트체크", "공식문서", "매뉴얼", "Gemini"]
---

## 어떤 문제를 해결하나

사용법 매뉴얼은 대개 **써 본 기억**으로 씁니다. 그래서 "확장을 켜야 한다" 처럼 대충 맞는 말이 들어가고, 공식 명칭이 아니라 나중에 검색해도 안 나옵니다.
"Workspace 확장" 이 정확히 어디서 켜는 무엇인지, 회사 계정에서는 왜 안 되는지, 시크릿 창에서는 되는지 — 한 번은 공식 문서와 대조해야 합니다.

직접 하면 도움말 사이트를 뒤지고, 해당 문단을 찾고, 내 글과 비교해서 고치는 데 20~30분입니다.
Claude Code에 "내 매뉴얼의 사전 준비 항목이 공식 도움말과 맞는지 확인해 줘" 라고 하면, 검색 → 페이지 읽기 → 대조 → 수정까지 한 턴에 끝납니다.

이 사례의 대상은 [Gmail 행사 등록 메일을 Ask Gemini로 구글 캘린더에 등록하기]({{< relref "/docs/usecases/automation/gmail-event-to-calendar-ask-gemini" >}}) 매뉴얼입니다.

## 사전 준비

- 검증할 매뉴얼 파일이 저장소 안에 있을 것 (Claude가 읽고 고칠 수 있어야 합니다)
- Claude Code에서 웹 검색/페이지 읽기(WebSearch, WebFetch)가 허용되어 있을 것

## 단계별 사용법

{{< step title="어떤 항목을 무엇과 대조할지 말한다" image="01-fetch.png" caption="Claude가 검색으로 공식 도움말 URL을 찾고, 페이지를 열어 필요한 문단만 뽑아 읽습니다." >}}
{{< prompt title="입력 프롬프트" >}}
Ask Gemini 매뉴얼의 "사전 준비"와 "주의사항"이 Google 공식 도움말과 맞는지 확인해 줘.
support.google.com 기준으로만 보고, 틀리거나 빠진 항목이 있으면 매뉴얼을 직접 고쳐.
{{< /prompt >}}

두 가지를 명시하는 것이 핵심입니다.

- **출처 범위**: `support.google.com 기준으로만`. 안 그러면 블로그·커뮤니티 글까지 섞여서 근거가 약해집니다
- **행동**: `매뉴얼을 직접 고쳐`. 안 그러면 "이런 차이가 있습니다" 로 끝나고 반영은 다시 시켜야 합니다

Claude는 먼저 검색으로 후보 URL을 추린 뒤(`Use Gemini in Chrome`, `Create & manage your calendar events with Gemini Apps` 두 페이지), 각 페이지에서 "탭 공유", "Workspace 연결", "요구 사항", "제한 사항" 문단만 추출해 읽습니다.
{{< /step >}}

{{< step title="공식 문서에서 근거 문단을 확인한다" image="02-help-page.png" caption="'When you share a Workspace webpage' 문단. 매뉴얼의 '확장'이라는 표현이 공식적으로는 'Workspace 앱 연결'임이 여기서 확인됩니다." >}}
Claude가 뽑아 온 근거는 이렇습니다.

| 매뉴얼에 쓴 것 | 공식 도움말 | 판정 |
| --- | --- | --- |
| "Google Workspace **확장**이 켜져 있을 것" | "connect the Workspace app … connect Google Workspace apps & services to Gemini Apps" | 명칭 틀림 → **앱 연결**, 설정 위치 `gemini.google.com/apps` 추가 |
| (없음) | "Sign in to Chrome (not available in Incognito mode)" | **시크릿 창 불가** 누락 |
| "관리자가 Gemini 확장을 막아둔 경우" | "with a work or school Google Account, access must be enabled by your administrator" | 표현 수정, 학교 계정 추가 |
| "필요하면 알림·참석자를 손봅니다" | "Cannot add/invite people to events", "Cannot add or update location/description of existing events" | 맞지만 근거 보강 → **Gemini는 참석자 초대 불가** 명시 |
| (없음) | "Include `@Google Calendar` in your prompt" | 카드 안 뜰 때의 대처법으로 추가 |

여기서 사람이 할 일은 표를 훑고 "고쳐" 라고 하는 것뿐입니다. 판정이 애매한 항목만 도움말 페이지를 직접 열어 보면 됩니다.
{{< /step >}}

{{< step title="diff로 수정 내용을 확인한다" image="03-diff.png" caption="Claude 앱 오른쪽 diff 패널. 빨간 줄이 원래 문장, 초록 줄이 공식 도움말 기준으로 바뀐 문장입니다." >}}
Claude가 매뉴얼을 고치고 diff 패널을 띄웁니다. 5줄 추가, 2줄 삭제.

- 사전 준비: "Workspace 확장" → "Workspace **앱** 연결 (gemini.google.com/apps)", 시크릿 창 불가 추가
- 주의사항: 참석자 초대 불가, `@Google Calendar` 지정법, 회사·학교 계정 관리자 승인

diff를 보고 그대로 커밋하면 끝입니다. 표현이 마음에 안 들면 그 줄만 다시 시킵니다.
{{< /step >}}

## 결과

기억으로 쓴 사전 준비 3줄이 공식 문서 기준 5줄이 됐습니다. 걸린 시간은 프롬프트 한 번, 표 확인, diff 확인 — 5분.
특히 "확장" 같은 비공식 명칭을 공식 명칭으로 바꿔 두면, 나중에 독자가 설정 화면에서 찾을 수 있게 됩니다.

## 주의사항

- **출처를 제한하세요.** `support.google.com 기준으로만` 처럼 도메인을 지정하지 않으면 커뮤니티 답변이 근거로 섞입니다. 커뮤니티 글은 "안 된다" 는 사례는 많지만 "왜" 는 틀린 경우가 많습니다.
- **판정 표를 요구하세요.** 고친 결과만 받으면 왜 바꿨는지 알 수 없습니다. "매뉴얼 문장 / 공식 문구 / 판정" 표를 먼저 받고 diff를 보는 순서가 안전합니다.
- **도움말도 틀리거나 오래됐을 수 있습니다.** 이번 사례에서도 캘린더 도움말은 "확인 알림에서 Undo" 라고만 적혀 있어 등록 **전** 확인 카드가 뜬다는 내 경험과 달랐습니다. 이럴 땐 직접 해 본 쪽을 남기고, 도움말 문구는 참고로만 씁니다.
- WebFetch는 로그인이 필요한 페이지(사내 위키, Workspace 관리자 콘솔)는 못 읽습니다. 그런 근거는 캡처를 붙여 주거나 본문을 붙여넣어야 합니다.

## 응용

- 사내 시스템 매뉴얼을 벤더 공식 릴리스 노트와 대조해 **바뀐 메뉴 이름** 찾기
- 블로그 글의 설치 절차를 해당 도구의 README 최신 버전과 대조하기
- 강의 자료의 CLI 옵션을 `--help` 출력이나 공식 레퍼런스와 대조하기
- 이 사이트의 모든 유스케이스를 분기마다 한 번씩 "공식 문서와 아직 맞나" 재검증
