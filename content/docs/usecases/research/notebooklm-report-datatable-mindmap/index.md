---
title: "NotebookLM에 보고서 PDF 넣고 수치 데이터 표·마인드맵까지 뽑기"
description: "17쪽 영문 보고서 PDF 한 개를 NotebookLM(Gemini Notebook) 소스로 올리고, 자동 요약 → 출처 번호 달린 답변 → 페이지 번호가 붙은 42행 수치 표 → 마인드맵까지 뽑는다. 브라우저 조작은 전부 Claude가 했다."
weight: 30
date: 2026-09-11
lastmod: 2026-09-11
icon: "auto_stories"
usecase: true
categories: ["리서치·학습"]
tools: ["NotebookLM", "Claude Code", "ego-browser"]
difficulty: "중급"
duration: "10분"
tags: ["NotebookLM", "PDF", "보고서", "데이터표", "마인드맵", "브라우저자동화"]
---

## 어떤 문제를 해결하나

[Ask Gemini로 Drive PDF 요약하기]({{< relref "/docs/usecases/research/drive-pdf-summary-ask-gemini" >}})는 "지금 열어 둔 파일 한 번 훑기" 용입니다.
그 보고서를 **계속 참조**해야 한다면 — 팀 발표 자료에 숫자를 넣고, 나중에 "그 통계 몇 페이지였지" 를 다시 찾아야 한다면 — 채팅 한 번으로는 부족합니다.

NotebookLM(2026년 9월 현재 화면 이름은 **Gemini Notebook**, `notebook.google.com`)은 파일을 **소스**로 올려 두고, 그 소스만 근거로 답하며, 문장마다 출처 번호를 답니다.
여기에 스튜디오의 **데이터 표** 기능을 쓰면 보고서 안의 설문 수치가 페이지 번호와 함께 표로 떨어집니다.

이 사례에서는 소스 업로드부터 데이터 표·마인드맵 생성까지 **브라우저 조작 전체를 Claude Code가 했습니다.** 사람은 "이 PDF로 NotebookLM 사례 만들어" 한 줄만 썼습니다.

## 사전 준비

- Google 계정으로 NotebookLM 사용 가능할 것 (`notebook.google.com`)
- 소스로 올릴 PDF. 여기서는 Spacelift *2026 State of Infrastructure Automation – The AI Readiness Gap* (17쪽, 16.7MB)
- Claude가 직접 조작하게 하려면 **에이전트가 제어할 수 있는 브라우저**가 필요합니다. 이 사례는 [ego-browser](https://github.com/ego-browser)(로그인 상태를 공유하는 Chromium)를 썼습니다. Chrome의 Claude 확장은 파일 업로드 상한이 10MB라 이 파일을 못 올립니다

## 단계별 사용법

{{< step title="NotebookLM 홈에서 새 노트북을 만든다" image="01-home.png" caption="홈 화면. '새로 만들기' 를 누르면 빈 노트북과 소스 추가 대화상자가 함께 열립니다." >}}
{{< prompt title="입력 프롬프트" >}}
컴퓨터 유즈로 이번에 구글의 notebooklm 활용 사례를 만들어줘.
2026 State of Infrastructure Automation - The AI Readiness Gap .pdf 파일을 finder에 열어 두었어.
{{< /prompt >}}

Claude는 `mdfind` 로 다운로드 폴더의 PDF 경로를 찾고, ego-browser 로 `notebook.google.com` 을 열어 로그인 상태를 확인한 뒤 `새로 만들기` 를 누릅니다.

```js
const task = await taskSpace("NotebookLM PDF summary usecase");
const page = task.page("p1");
await page.goto("https://notebooklm.google.com/");   // notebook.google.com 으로 리다이렉트
await page.click('loc=css:button[aria-label="새 노트 만들기"]');
```

페이지의 접근성 트리를 읽어 버튼을 이름으로 찾기 때문에, 화면 좌표를 맞출 필요가 없습니다.
{{< /step >}}

{{< step title="PDF를 소스로 올린다" image="02-add-source.png" caption="소스 추가 대화상자. 파일 업로드 · 웹사이트 · Drive · Play 북 · 복사된 텍스트 중 파일 업로드를 씁니다." >}}
`파일 업로드` 는 OS 파일 선택창을 띄우는데, 에이전트 브라우저는 이 창을 가로채서 경로를 직접 넣습니다.

```js
const chooser = page.waitForFileChooser({ timeout: 10000 });
await page.click("text=파일 업로드");
await (await chooser).setFiles("/Users/mac/Downloads/2026 State of Infrastructure Automation - The AI Readiness Gap.pdf");
```

업로드 직전에 "5시간마다 한도 초기화" 안내 대화상자가 겹쳐 떠서 먼저 닫아야 했습니다. 이런 돌발 팝업은 사람이 하면 무의식적으로 닫지만, 자동화에서는 매번 스냅샷을 찍어 확인하는 이유입니다.
{{< /step >}}

{{< step title="자동 요약과 추천 질문을 확인한다" image="03-auto-summary.png" caption="소스 처리가 끝나면 제목·이모지·5문장 요약·추천 질문 3개가 자동으로 채워집니다." >}}
업로드 후 20초쯤 지나면 노트북 제목이 `The 2026 State of Infrastructure Automation: AI Readiness Gap` 으로 바뀌고 요약이 뜹니다.

> 대다수의 기업이 AI를 적극적으로 도입하면서도 그에 걸맞은 거버넌스 체계를 갖추지 못했음을 지적합니다. … 조직을 네 가지 성숙도 단계로 분류하며, 플랫폼 엔지니어링 도입과 자동화된 통제 시스템 구축이 핵심임을 강조합니다.

추천 질문(`AI 거버넌스 파라독스와 바이브 코딩이 조직에 미치는 영향은?` 등)은 보고서 구조를 미리 보여 주는 목차 역할을 합니다. 여기까지는 아무것도 묻지 않았습니다.
{{< /step >}}

{{< step title="표 형식을 지정해 질문한다" image="04-chat-answer.png" caption="AIMI 4단계 표. 셀마다 출처 번호(1, 2, 3…)가 붙어 있고 누르면 원문 위치가 열립니다." >}}
{{< prompt title="채팅 입력" >}}
보고서의 4단계 AI 성숙도 분류(AIMI)를 각 단계의 비율, 특징, 권고 조치와 함께 표로 정리하고, 우리 팀이 어느 단계인지 판단할 수 있는 체크 질문 3개를 만들어줘
{{< /prompt >}}

| 단계 | 비율 | 특징 한 줄 | 권고 |
| --- | --- | --- | --- |
| Exposed | 24% | 거버넌스 없이 AI 사용, IaC 15%, 인시던트 97% | IaC 커버리지 확대 최우선 |
| Fragmented | 32% | 팀별로 제각각, 표준화 미비 | 워크플로 표준화, 플랫폼 엔지니어링 |
| Outpacing | 25% | 도입은 빠른데 거버넌스가 못 따라감 | 파이프라인 안에 자동 가드레일 |
| Pioneer | 19% | AI 전부터 IaC 75%+, 공식 정책 71% | 에이전틱 거버넌스 선제 구축 |

체크 질문 3개(IaC 코드화 비율 / AI 생성 코드 자동 검증 여부 / AI 특화 지표 측정 여부)도 각 단계 기준값과 함께 돌아왔습니다.
답변 표 안에 `<br>` 이 글자 그대로 보이는 건 NotebookLM 렌더링 버그입니다 — 내용에는 영향 없습니다.
{{< /step >}}

{{< step title="스튜디오 '데이터 표'로 수치를 전부 뽑는다" image="05-data-table.png" caption="42행 표. 지표 / 수치 / 대상 그룹 / 페이지 / 출처. '대상 그룹' 열이 있어서 전체 응답자와 Pioneer·Exposed 하위 그룹 수치가 섞이지 않습니다." >}}
오른쪽 스튜디오 패널의 `데이터 표` 를 누르고 설명란에 열 구성을 적습니다.

{{< prompt title="데이터 표 설명" >}}
보고서에 나온 모든 설문 수치를 '지표 / 수치 / 대상 그룹 / 페이지' 4열로 정리
{{< /prompt >}}

1~2분 뒤 `인프라 자동화 보고서 설문 지표 요약` 이라는 42행 표가 생깁니다. 몇 개만 보면:

| 지표 | 수치 | 대상 | p. |
| --- | --- | --- | --- |
| 최소 1개 이상의 AI 유발 인프라 사고 경험 | 93% | 전체 | 9 |
| 최소 1개 이상의 AI 유발 인프라 사고 | 97% | Exposed | 9 |
| AI 유발 사고 전혀 없음 | 17% | Pioneer | 9 |
| 공식 AI 거버넌스 정책 보유 | 30% | 인프라 리더 | 7 |
| 조직의 AI 거버넌스 능력에 자신감 | 86% | 인프라 리더 | 7 |
| AI 특화 지표(AI 생성 IaC 양) 측정 | 15% | 전체 | 12 |

"자신감 86% vs 실제 정책 30%" 같은 대비가 표에서 바로 보입니다. Ask Gemini 요약에서는 **분모(대상 그룹)** 가 빠지기 쉬웠는데, 여기서는 열로 강제했습니다.
{{< /step >}}

{{< step title="마인드맵으로 구조를 잡는다" image="06-mindmap.png" caption="루트 'The AI Readiness Gap (2026)' 아래 6개 가지. 가지를 누르면 하위 항목이 펼쳐지고, 노드를 누르면 채팅에 그 주제로 질문이 들어갑니다." >}}
같은 패널의 `마인드맵` 을 누르면 30초 안에 생깁니다. 가지는 AIMI · Readiness Dimensions · Key Findings & Gaps · AI-Caused Incidents · Platform Engineering Solution · Tactical Recommendations 여섯 개.

보고서를 처음 보는 사람에게 "이 문서는 이런 구조" 라고 설명할 때 이 한 장이면 됩니다. 발표 자료 목차로 그대로 옮겨도 됩니다.
{{< /step >}}

## 결과

PDF 한 개 → 요약 + 출처 달린 Q&A + 42행 수치 표(페이지 번호 포함) + 마인드맵. 10분.
사람이 한 일은 프롬프트 한 줄. 업로드·팝업 닫기·질문·스튜디오 생성·캡처는 Claude가 브라우저를 직접 조작했습니다.

노트북은 계속 남아 있으니, 다음에 같은 보고서에서 다른 숫자가 필요하면 채팅 한 줄이면 됩니다.

## 주의사항

- **Chrome 확장으로는 이 파일을 못 올립니다.** Claude in Chrome 의 파일 업로드 상한은 10MB, 이 PDF는 16.7MB. Pillow 로 2MB까지 줄이는 방법도 있지만, 원본 그대로 올리려면 파일 선택창을 가로챌 수 있는 에이전트 브라우저(ego-browser 등)가 필요합니다.
- **한도가 있습니다.** 2026년 9월 기준 노트북별 한도가 5시간마다 초기화됩니다. 데이터 표·마인드맵·오디오 오버뷰는 각각 한도를 씁니다. 스튜디오 대화상자의 "AI 사용량" 바를 보고 생성하세요.
- **자동화 중 팝업을 놓치면 이후 클릭이 전부 빗나갑니다.** 안내 대화상자 하나 때문에 "파일 업로드" 클릭이 대화상자 뒤로 갔습니다. 액션마다 스냅샷으로 대화상자 유무를 확인하는 습관이 필요합니다.
- **데이터 표의 '출처' 열은 소스 번호([1])이지 페이지가 아닙니다.** 페이지 열을 따로 요청해야 합니다. 이 사례처럼 설명란에 열 이름을 명시하세요.
- 스튜디오 항목 클릭은 접근성 트리에 잘 안 잡혀서 좌표 클릭을 썼습니다. 좌표는 스크린샷을 보고 잡았고, 한 번은 옆 버튼(데이터 표 만들기)을 눌러 엉뚱한 대화상자가 열렸습니다. 결과 확인 없이 다음 단계로 넘어가면 안 되는 이유입니다.
- 화면 이름이 **Gemini Notebook** 으로 바뀌었고 주소도 `notebook.google.com` 입니다. `notebooklm.google.com` 은 리다이렉트됩니다. 검색할 땐 두 이름 다 써 보세요.

## 응용

- 분기마다 나오는 같은 벤더 보고서를 소스로 누적 → `2025 대비 어떤 수치가 바뀌었나` 를 한 노트북에서 비교
- RFP·제안요청서 PDF → 데이터 표로 "요구사항 / 필수여부 / 페이지" 추출해 체크리스트 초안
- 강의 PDF 여러 개 → 마인드맵 + 플래시카드로 시험 대비
- 사내 규정집 → 소스로 올려 두고 "이 경우 결재 라인은?" 을 출처 번호 달린 답으로 받기
