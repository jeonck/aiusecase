---
title: "Drive에 있는 PDF 보고서를 Ask Gemini로 요약하고 수치 표 뽑기"
description: "Google Drive에서 17쪽짜리 영문 PDF를 열어 둔 채 Chrome의 Ask Gemini에 한 줄 요청하면, 5줄 요약과 숫자 근거 표가 출처 표시와 함께 돌아온다."
weight: 20
date: 2026-09-11
lastmod: 2026-09-11
icon: "summarize"
usecase: true
categories: ["리서치·학습"]
tools: ["Chrome Ask Gemini", "Google Drive"]
difficulty: "초급"
duration: "2분"
tags: ["PDF", "요약", "보고서", "Drive", "사이드패널"]
---

## 어떤 문제를 해결하나

업계 보고서 PDF는 받아 두기만 하고 안 읽습니다. 17쪽 영문 보고서를 훑어 "그래서 숫자가 뭐야" 를 뽑는 데 20분은 걸리는데, 그 20분이 안 나서 Drive에 쌓입니다.

Drive에서 PDF를 열어 둔 상태로 Chrome의 **Ask Gemini** 패널에 한 줄만 쓰면, 요약과 수치 표가 문장 단위 출처 표시와 함께 나옵니다.
[Gmail 일정 등록 사례]({{< relref "/docs/usecases/automation/gmail-event-to-calendar-ask-gemini" >}})와 같은 패널이지만, 이번엔 **탭 내용이 아니라 Drive 파일 자체**를 Workspace 앱으로 읽는다는 점이 다릅니다.

## 사전 준비

- Chrome에 Google 계정으로 로그인, `✦ Ask Gemini` 버튼이 보일 것
- Gemini에 Google Workspace 앱(Drive)이 연결되어 있을 것 — [gemini.google.com/apps](https://gemini.google.com/apps)
- 요약할 PDF가 내 Drive(또는 공유받은 파일)에 있을 것. 여기서는 Spacelift의 공개 보고서 *2026 State of Infrastructure Automation – The AI Readiness Gap* (17쪽) 을 씁니다

## 단계별 사용법

{{< step title="Drive 홈에서 Ask Gemini 패널을 연다" image="01-drive-home.png" caption="패널 아래 Sharing 줄이 '홈 - Google Drive' — 아직 파일이 아니라 목록 화면을 보고 있는 상태입니다." >}}
Drive 홈에서 브라우저 오른쪽 위 `✦ Ask Gemini` 를 누릅니다. 이 시점에 패널이 공유하는 건 **파일 목록 페이지**라서, 여기서 "요약해 줘" 라고 하면 어떤 파일인지 되묻습니다. 파일을 먼저 여는 게 순서입니다.
{{< /step >}}

{{< step title="PDF를 열고 Sharing 줄이 파일명으로 바뀌는지 본다" image="02-open-file.png" caption="Sharing 줄이 PDF 제목으로 바뀌었습니다. 이제 요청하면 이 파일을 읽습니다." >}}
목록에서 PDF를 더블클릭해 Drive 미리보기로 엽니다. 패널의 Sharing 줄이 `"2026 State of Infrastructure Automation… .pdf"` 로 바뀌면 준비 끝입니다.

이 사례에서는 Claude Code가 Drive 커넥터로 파일 ID를 찾아 `drive.google.com/file/d/<ID>/view` 를 직접 열었습니다. 사람이 열든 도구가 열든 결과는 같습니다 — 패널은 **현재 탭이 무엇이냐**만 봅니다.
{{< /step >}}

{{< step title="요약 형식을 정해서 한 줄로 요청한다" image="03-answer.png" caption="응답 상단의 'Workspace ▾' 는 Drive 파일을 Workspace 앱으로 읽었다는 표시. 문장마다 ▾ 를 누르면 근거 위치가 열립니다." >}}
{{< prompt title="입력 프롬프트" >}}
이 문서를 핵심 5줄로 요약하고, 숫자가 나온 주장은 표로 따로 정리해줘
{{< /prompt >}}

"요약해 줘" 만 쓰면 길이도 형식도 제멋대로입니다. **줄 수**와 **숫자는 표로** 두 가지를 못 박는 게 핵심입니다.

돌아온 5줄 (원문 영문 → 한국어로 바로 나옵니다):

1. AI로 개발 속도는 급증했지만, 생성된 코드가 인프라 팀에 부담을 주며 **AI–인프라 격차**가 생기고 있다
2. 대다수 기업이 AI 거버넌스에 자신감을 보이지만, 실제 **공식 정책을 갖춘 곳은 소수**
3. AI가 생성한 IaC를 검증 없이 운영에 배포하는 **바이브 코딩** 관행이 확산 중
4. 검증 없는 AI 코드로 보안 설정 오류·인프라 표류·에이전틱 시스템 사고 등 장애가 이미 빈번
5. 해결책은 단순 자동화가 아니라 **플랫폼 엔지니어링** 도입과 AI 전용 지표 측정·관리

패널 제목도 `AI 도입 현황 및 거버넌스 요약` 으로 자동으로 바뀝니다.
{{< /step >}}

{{< step title="수치 표를 확인하고 필요한 숫자만 가져간다" image="04-table.png" caption="분류 / 주요 내용 및 수치. 각 행 끝의 ▾ 가 해당 숫자가 나온 페이지로 연결됩니다." >}}
패널을 내리면 요청한 표가 나옵니다.

| 분류 | 수치 |
| --- | --- |
| AI 성숙도 분류 (AIMI) | Fragmented 32% · Outpacing 25% · Exposed 24% · Pioneer 19% |
| 개발 속도 및 코드 생성 | 89% 개발자 속도 증가 · 82% 코드의 25~74%가 AI 도움 · 62% 개발팀이 인프라팀보다 AI 도입 빠름 |
| 인프라 팀 여파 | 86% 인프라 팀 부담 증가 · 40% 보안 취약점 발생 가속 · 40% 거버넌스 관리 난이도 상승 |

보고서를 인용할 때 필요한 건 결국 이 표입니다. 숫자 옆 ▾ 를 눌러 원문 페이지를 한 번 확인하고 가져가면 됩니다.
{{< /step >}}

## 결과

17쪽 영문 보고서 → 한국어 5줄 + 수치 표. 입력 한 줄, 2분.
"읽어야 하는데" 상태로 Drive에 쌓여 있던 PDF가 "숫자 세 개 알고 있는" 상태가 됐고, 더 볼지 말지를 그 숫자로 결정할 수 있습니다.

## 주의사항

- **Sharing 줄을 반드시 확인하세요.** 목록 화면(`홈 - Google Drive`)인 채로 요청하면 엉뚱한 파일을 잡거나 되묻습니다. 파일을 연 뒤 줄이 바뀌는 걸 보고 입력합니다.
- **`Workspace ▾` 라벨이 없으면 탭 텍스트만 읽은 겁니다.** Drive 미리보기 탭의 텍스트는 현재 보이는 페이지 근처만 잡힐 수 있습니다. 라벨이 안 뜨면 Workspace 앱 연결이 꺼진 것이니 [gemini.google.com/apps](https://gemini.google.com/apps) 에서 Drive를 켜세요.
- **숫자는 ▾ 로 한 번은 원문을 보세요.** 이 사례의 표는 원문과 맞았지만, 퍼센트의 분모(전체 응답자인지 특정 그룹인지)는 요약에서 빠지기 쉽습니다. 인용할 숫자만이라도 페이지를 엽니다.
- 스캔본 PDF(이미지)는 텍스트 레이어가 없으면 못 읽습니다. 그런 파일은 Drive에서 `Google 문서로 열기` 로 OCR을 먼저 거칩니다.
- 회사 Drive(Workspace 계정)는 관리자가 Gemini 앱 연결을 막아 두면 라벨 없이 텍스트 답만 옵니다.

## 응용

- 프롬프트를 `이 계약서에서 날짜·금액·위약 조항만 표로` 로 바꿔 계약서 검토 전 훑어보기
- 여러 보고서를 탭으로 열고 `@` 로 탭을 추가한 뒤 `두 보고서의 수치를 한 표로 비교` (최대 10개 탭)
- 요약 결과를 그대로 Google 문서에 붙여 팀 공유용 1페이지 브리프 만들기
- 논문 PDF: `연구 질문·방법·결과·한계 4줄` 형식으로 고정해 읽을지 말지 판단
