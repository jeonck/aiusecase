---
title: "Claude Code로 보고서 수치를 8장 PPT로 — 코드로 만들고 렌더로 검수"
description: "NotebookLM 데이터 표에서 검증한 수치로 Claude Code가 pptxgenjs 스크립트를 써서 .pptx를 만들고, LibreOffice로 렌더해 눈으로 검수한 뒤 PowerPoint에서 연다. 편집 가능한 진짜 파일, 숫자마다 대상 그룹과 페이지 출처."
weight: 20
date: 2026-09-11
lastmod: 2026-09-11
icon: "co_present"
usecase: true
categories: ["문서·글쓰기"]
tools: ["Claude Code", "pptxgenjs", "LibreOffice", "PowerPoint"]
difficulty: "중급"
duration: "15분"
tags: ["PPT", "pptx", "발표자료", "보고서", "차트", "자동화"]
---

## 어떤 문제를 해결하나

[NotebookLM 슬라이드]({{< relref "/docs/usecases/research/notebooklm-presenter-slides" >}})는 5분 만에 예쁜 6장을 주지만, 그림 속 글자는 못 고치고, 수치 하나는 주어가 바뀌어 있었고, 다운로드도 에이전트에서는 안 됐습니다.
회사에서 실제로 쓰는 PPT 는 **편집이 되고, 숫자가 맞고, 우리 템플릿에 얹을 수 있어야** 합니다.

Claude Code 에 "이 수치 표로 팀장 보고용 8장 PPT 만들어 줘" 라고 하면, 코드(pptxgenjs)로 .pptx 를 생성하고 → 스키마 검증 → LibreOffice 렌더 → 이미지로 검수 → 고쳐서 다시 렌더까지 돌립니다. 결과물은 PowerPoint 에서 바로 열리는 243KB 파일입니다.

## 사전 준비

- Claude Code + `pptx` 스킬 (pptxgenjs 사용법·검증 스크립트·렌더 스크립트가 들어 있음)
- Node.js, LibreOffice(렌더 검수용), Poppler `pdftoppm`
- **검증된 수치.** 여기서는 [NotebookLM 데이터 표]({{< relref "/docs/usecases/research/notebooklm-report-datatable-mindmap" >}})(지표 / 수치 / 대상 그룹 / 페이지)를 그대로 썼습니다. 이 표가 없으면 PPT 의 숫자를 믿을 근거가 없습니다

## 단계별 사용법

{{< step title="수치 표를 주고 구성·규칙을 한 줄로 요청한다" image="01-build-script.png" caption="Claude가 쓴 build.js 의 핵심. 큰 숫자 콜아웃 함수 하나, 네이티브 차트, 슬라이드마다 출처 페이지." >}}
{{< prompt title="입력 프롬프트" >}}
ppt 만들기 자동화 사례를 유스케이스로 추가 할 수 있을까?
{{< /prompt >}}

Claude 는 앞 사례의 데이터 표를 근거로 8장 구성을 잡습니다: 표지 → 한 장 요약(3 수치) → AIMI 4단계(차트) → 거버넌스 역설 → 바이브 코딩(차트) → 사고(차트 2) → Pioneer vs Exposed 비교표 → 다음 분기 3가지.

스크립트에서 지킨 규칙:

- **숫자마다 대상 그룹**을 작은 글씨로 붙임 (`전체 응답자` / `인프라 리더` / `Pioneer 조직`) — 표지에 이 원칙을 명시
- **차트는 네이티브** `addChart` — 그림이 아니라 PowerPoint 차트라 나중에 값 수정·색 변경이 됨
- **슬라이드마다 출처 페이지** `p.4, 13` — 데이터 표의 페이지 열을 그대로
- 색은 `1E2761` 남색 + `F59E0B` 주황 하나. 폰트는 Arial(한글은 시스템 폰트가 대체)
{{< /step >}}

{{< step title="검증 → 렌더 → 눈으로 검수 → 고친다" image="02-render-qa.png" caption="LibreOffice 로 렌더한 8장. 첫 렌더에서 7번 제목이 두 줄로 넘쳐 부제와 겹쳤고, 가로 막대 순서가 뒤집혀 있었습니다 — 고친 뒤 모습." >}}
```bash
node build.js
python3 scripts/office/validate.py ai-readiness-gap-brief.pptx      # 스키마·관계·차트 검사
python3 scripts/office/soffice.py --headless --convert-to pdf …     # LibreOffice 렌더
pdftoppm -jpeg -r 110 ai-readiness-gap-brief.pdf slide              # 슬라이드별 이미지
```

첫 렌더에서 Claude 가 잡은 결함 세 개:

| 슬라이드 | 문제 | 수정 |
| --- | --- | --- |
| 7 | 제목이 두 줄로 넘쳐 부제와 겹침 | 제목을 짧게, 나머지는 부제로 |
| 3 | 세로축 최대 100% 라 막대가 납작함 | 최대 40% 로 |
| 5, 6 | 가로 막대가 아래에서 위로 그려져 순서가 뒤집힘 | 데이터 배열을 역순으로 |

코드를 고치고 다시 렌더. 손으로 PPT 를 고치는 게 아니라 **생성 코드를 고치기** 때문에, 같은 구성으로 다른 보고서를 만들 때 그대로 재사용됩니다.
{{< /step >}}

{{< step title="PowerPoint에서 연다" image="03-powerpoint.png" caption="Mac PowerPoint 에서 연 결과. 하단 '접근성: 문제 없음' — 모든 텍스트 상자에 isTextBox 를 줘서 스크린리더가 텍스트로 읽습니다." >}}
`open -a "Microsoft PowerPoint" ai-readiness-gap-brief.pptx`. 8장, 243KB, 차트는 클릭하면 데이터 편집이 뜹니다.

파일: [ai-readiness-gap-brief.pptx](ai-readiness-gap-brief.pptx) — 내려받아 열어 보세요.
{{< /step >}}

## 결과

검증된 수치 표 → 편집 가능한 8장 .pptx, 15분. 사람이 한 일은 요청 한 줄과 렌더 이미지 훑어보기.

NotebookLM 슬라이드와의 차이:

| | NotebookLM 슬라이드 | Claude Code + pptxgenjs |
| --- | --- | --- |
| 생성 시간 | 5분 | 15분 (검수 포함) |
| 비주얼 | 장마다 다른 일러스트 | 숫자·차트 중심, 일러스트 없음 |
| 수치 정확도 | 1건 주어 오류 | 데이터 표 그대로 + 대상 그룹 표기 |
| 편집 | 텍스트만, 그림 속 글자 불가 | 전부 (네이티브 차트 포함) |
| 템플릿 적용 | 불가 | 회사 .potx 에 얹기 가능 |
| 재사용 | 매번 새로 생성 | 코드 재실행 |

첫인상은 NotebookLM, 실제 보고는 이쪽입니다. 둘 다 같은 데이터 표에서 나왔습니다.

## 주의사항

- **수치 출처 없이 시작하지 마세요.** PPT 생성기는 준 숫자를 예쁘게 배치할 뿐입니다. 데이터 표(지표/수치/대상 그룹/페이지)를 먼저 만들고 그걸 입력으로 주세요.
- **렌더 검수는 필수.** 코드로 만든 슬라이드는 텍스트 넘침·겹침이 첫 렌더에 꼭 몇 개 있습니다. 이번에도 3개. 이미지를 보고 코드를 고치는 한 바퀴를 예산에 넣으세요.
- **한글 폰트.** 스크립트는 Arial 을 지정했고 한글은 PowerPoint 가 시스템 폰트(맑은 고딕/Apple SD Gothic)로 대체합니다. LibreOffice 렌더와 실제 PowerPoint 의 줄바꿈이 조금 다를 수 있으니 긴 제목은 여유를 두세요.
- **색은 `#` 없는 6자리.** `"#1E2761"` 이나 8자리는 파일이 깨집니다. 스킬 문서에 있는 함정 목록을 Claude 가 따르지만, 직접 고칠 때 주의.
- 그래프가 가로 막대일 때 첫 항목이 **아래**에 그려집니다. 위에서 아래 순서를 원하면 배열을 뒤집으세요.
- 회사 템플릿(.potx)에 얹으려면 스킬의 템플릿 편집 경로(unzip → slide XML 편집 → zip)를 씁니다. 처음부터 만드는 것보다 손이 더 갑니다.

## 응용

- 같은 스크립트에 **다른 보고서의 데이터 표**를 넣어 분기마다 재생성
- 주간 지표 대시보드: 시트에서 숫자를 읽어 `stat()` 콜아웃 3개 + 차트 1개짜리 1장 PPT 를 매주 자동 생성
- 회사 .potx 템플릿의 레이아웃을 `thumbnail.py` 로 훑어 고른 뒤, 본문만 채우기
- 발표 후 `자세한 자료` 버전: 같은 데이터로 텍스트 많은 읽기용 덱을 한 벌 더
