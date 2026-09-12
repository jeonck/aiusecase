---
title: "Dify 워크플로로 회의록 → 결정사항·액션아이템 JSON — DSL로 작성해 API로 배포"
description: "시작(회의록·팀) → LLM(JSON 스키마 강제) → 종료(result) 3노드 워크플로를 Claude가 DSL YAML로 써서 Dify에 import. 테스트 실행으로 회의록 한 장이 summary·decisions·action_items JSON이 되는 걸 확인하고 게시해 API 엔드포인트를 얻는다."
weight: 51
date: 2026-09-12
lastmod: 2026-09-12
icon: "account_tree"
usecase: true
categories: ["업무 자동화"]
tools: ["Dify", "Claude Code", "ego-browser"]
difficulty: "중급"
duration: "15분"
tags: ["Dify", "워크플로", "DSL", "회의록", "JSON", "API"]
---

## 어떤 문제를 해결하나

챗봇은 사람이 대화하는 용도고, **워크플로**는 시스템이 호출하는 용도입니다. 입력이 정해져 있고(회의록 텍스트) 출력도 정해져 있어야(JSON) 다음 시스템(슬랙·노션·지라)에 넘길 수 있습니다.

Dify 워크플로를 노드 편집기에서 마우스로 만들 수도 있지만, 이 사례는 **Claude 가 DSL YAML 을 써서 import** 했습니다. 노드 3개짜리도 클릭이 30번인데, YAML 은 80줄이고 버전 관리가 됩니다.

## 사전 준비

- Dify Cloud 계정 + 모델 (샌드박스 크레딧 또는 본인 API 키)
- DSL 형식 참고용으로 기존 앱 하나를 내보내 두면 좋습니다 ([챗봇 사례]({{< relref "/docs/usecases/automation/dify-chatbot-site-guide" >}})의 `chatbot-dsl.yml`). 버전(`version: 0.7.0`)과 모델 provider 표기(`langgenius/openai/openai`)를 거기서 베낍니다

## 단계별 사용법

{{< step title="DSL YAML 을 쓴다 — 시작 · LLM · 종료" image="02-imported.png" caption="import 직후 편집기. 시작(minutes 필수, team 선택) → '회의록 → JSON'(gpt-5) → 종료(result). 노드 위치까지 YAML 에 있습니다." >}}
[workflow-dsl.yml](workflow-dsl.yml) 의 핵심:

```yaml
app: { mode: workflow, name: 회의록 정리 워크플로, … }
version: 0.7.0
workflow:
  graph:
    nodes:
    - id: start
      data: { type: start, variables: [{ variable: minutes, type: paragraph, required: true, max_length: 20000 },
                                       { variable: team, type: text-input, required: false }] }
    - id: llm
      data:
        type: llm
        model: { provider: langgenius/openai/openai, name: gpt-5, mode: chat, completion_params: { temperature: 0.2 } }
        prompt_template:
        - role: system
          text: '너는 회의록 정리 담당이다. … 반드시 아래 JSON 스키마로만 답한다(코드블록·설명 없이 JSON 만):
                 {"team","summary"(3문장 이내),"decisions":[…],"action_items":[{"owner","task","due"}],"open_questions":[…]}. 없으면 null.'
        - role: user
          text: '팀: {{#start.team#}}   회의록: {{#start.minutes#}}'
    - id: end
      data: { type: end, outputs: [{ variable: result, value_selector: [llm, text] }] }
    edges: [start→llm, llm→end]
```

변수 참조는 `{{#노드id.변수#}}`. 종료 노드의 `outputs` 가 API 응답의 키가 됩니다.

import 는 화면의 `DSL 가져오기` 로 파일을 올리거나, 콘솔 API 로 직접:

```js
fetch("/console/api/apps/imports", { method: "POST", headers: { "X-CSRF-Token": csrf, "Content-Type": "application/json" },
  body: JSON.stringify({ mode: "yaml-content", yaml_content: yaml }) })
// → {"status":"completed","app_id":"0eb0a769-…","app_mode":"workflow"}
```
{{< /step >}}

{{< step title="테스트 실행 — 회의록 한 장을 넣는다" image="03-run-input.png" caption="테스트 실행 패널. 회의록 원문(참석자·논의·결정·미결)과 팀 이름." >}}
{{< prompt title="입력 (회의록 원문)" >}}
9/12 플랫폼팀 주간회의 (참석: 민수, 지영, 현우)
- 지난주 kind 로컬 클러스터 사례를 사이트에 올렸고 반응이 좋았음. 지영: CKS 세트도 이번 주 안에 올리자고 제안. 다들 동의.
- Argo CD 폴링 3분이 데모에서 답답했다는 피드백. 현우가 GitHub 웹훅 연동을 다음 주 수요일까지 붙이기로 함.
- 민수: OG 카드 한글 폰트를 Pretendard로 바꿔 보자는 의견. 결정은 보류, 다음 회의에서 샘플 보고 정하기로.
- 사이트 방문 통계 대시보드가 없다. 누가 할지 정하지 못함.
- 지영이 CKAD 문제 세트 설명서를 금요일까지 다듬기로.
{{< /prompt >}}

일부러 **담당자가 없는 항목**(CKS 세트), **결정이 보류된 항목**(폰트), **미결 항목**(대시보드)을 섞었습니다. 이걸 어떻게 분류하는지가 검증 포인트입니다.
{{< /step >}}

{{< step title="결과 — JSON 그대로" image="04-result.png" caption="결과 탭. summary · decisions 3 · action_items 3(owner null 포함) · open_questions 1. 코드블록 없이 JSON 만." >}}
```json
{"team":"플랫폼팀",
 "summary":"지난주 kind 로컬 클러스터 사례를 게시해 반응이 좋았다. CKS 세트를 이번 주에 올리기로 하고, … 사이트 방문 통계 대시보드 담당자는 미정이고 CKAD 설명서는 지영이 금요일까지 다듬는다.",
 "decisions":["CKS 세트를 이번 주 안에 사이트에 올리기로 함.","Argo CD에 GitHub 웹훅 연동을 적용하기로 함.","OG 카드 한글 폰트 변경은 다음 회의에서 샘플을 보고 결정하기로 함."],
 "action_items":[{"owner":null,"task":"CKS 세트를 사이트에 올리기","due":"이번 주 안에"},
                 {"owner":"현우","task":"Argo CD에 GitHub 웹훅 연동 추가","due":"다음 주 수요일까지"},
                 {"owner":"지영","task":"CKAD 문제 세트 설명서 다듬기","due":"금요일까지"}],
 "open_questions":["사이트 방문 통계 대시보드를 누가 담당할 것인가?"]}
```

세 검증 포인트 모두 통과: 담당자 없는 항목은 `owner: null`, 보류된 폰트 건은 "다음 회의에서 결정" 이라는 **결정**으로, 대시보드는 `open_questions` 로. 프롬프트에 "추측하지 않는다. 없으면 null" 을 넣은 효과입니다.
{{< /step >}}

{{< step title="게시 → API 엔드포인트" image="05-access.png" caption="액세스 지점. 웹 앱(udify.app/workflow/…)과 API(api.dify.ai/v1). 워크플로에는 Trigger(일정·웹훅) 옵션도 보입니다." >}}
```bash
curl -X POST https://api.dify.ai/v1/workflows/run \
  -H "Authorization: Bearer app-…" -H "Content-Type: application/json" \
  -d '{"inputs":{"minutes":"…회의록…","team":"플랫폼팀"},"response_mode":"blocking","user":"ci"}'
# → {"data":{"outputs":{"result":"{\"team\":…}"}}}
```

이 한 줄이 슬랙 봇·노션 자동화·CI 에서 호출하는 접점입니다. 웹 앱 URL(`udify.app/workflow/5K2JMiR41TL6wUrX`)은 사람이 폼에 붙여넣는 용도.
{{< /step >}}

## 결과

DSL 80줄 → import → 테스트 → 게시, 15분. 회의록 텍스트가 스키마가 고정된 JSON 이 됐고, `owner: null` 같은 빈 값 처리까지 프롬프트대로 나왔습니다.
같은 DSL 을 복사해 `프롬프트만 바꾸면` 이슈 분류기, 고객 문의 태깅기가 됩니다 — 그게 YAML 로 만든 이유입니다.

## 주의사항

- **JSON 을 강제하려면 "코드블록·설명 없이" 를 명시하세요.** 안 그러면 ```json 으로 감싸서 오고, 다음 시스템에서 파싱이 깨집니다. 더 확실하게는 LLM 노드 뒤에 `코드` 노드(JSON.parse)나 `파라미터 추출기` 노드를 붙입니다.
- **DSL 의 `version` 과 모델 provider 문자열은 기존 앱에서 베끼세요.** `langgenius/openai/openai` 처럼 플러그인 기반 표기라 버전마다 다릅니다. 틀리면 import 는 되는데 노드에 모델이 비어 있습니다.
- **import 는 새 앱을 만듭니다.** 같은 이름으로 여러 번 하면 앱이 여러 개. 업데이트는 앱 메뉴의 `DSL 가져오기(덮어쓰기)` 나 `/console/api/apps/<id>/imports` 를 씁니다.
- **temperature 를 낮추세요.** 분류·추출은 0.2 정도. 기본 0.7 은 같은 회의록에 다른 JSON 을 줍니다.
- 샌드박스 크레딧은 gpt-5 실행 한 번에 여러 크레딧이 나갑니다. 본인 키를 등록한 뒤 작은 모델로 시작하세요.

## 응용

- 슬랙 `#meeting-notes` 채널 → 웹훅 트리거 → 이 워크플로 → `action_items` 를 지라 이슈로
- 고객 문의 메일 → `{category, urgency, reply_draft}` JSON → 헬프데스크
- 이 사이트의 새 사례 초안 → `{title, category, tools, difficulty, tags}` front matter 자동 생성
- 종료 노드 뒤에 HTTP 요청 노드를 붙여 결과를 노션 API 로 바로 전송
