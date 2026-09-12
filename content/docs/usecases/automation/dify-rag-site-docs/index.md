---
title: "Dify RAG — 사이트 문서로 Q&A 봇, 청킹·임베딩 한도·검색 실패를 겪으며 답이 나오기까지"
description: "이 사이트의 k8s 사례 6건을 지식 베이스로 올리고 검색→LLM→답변 채팅 플로우를 DSL로 만든다. PDF가 이미지 청크로만 잘리고, 줄 단위 청킹으로 검색이 엉망이고, 샌드박스 크레딧과 Gemini 무료 한도에 두 번 막힌 끝에 출처 달린 답이 나온다. RAG에서 진짜 시간이 어디에 드는지의 기록."
weight: 52
date: 2026-09-12
lastmod: 2026-09-12
icon: "manage_search"
usecase: true
categories: ["업무 자동화"]
tools: ["Dify", "Gemini API", "Claude Code", "ego-browser"]
difficulty: "고급"
duration: "40분"
tags: ["Dify", "RAG", "지식베이스", "임베딩", "청킹", "Gemini"]
---

## 어떤 문제를 해결하나

[안내 챗봇]({{< relref "/docs/usecases/automation/dify-chatbot-site-guide" >}})은 프롬프트에 사례 이름을 나열한 것이라 "Helm 롤백하면 `--set` 값은 어떻게 되나" 같은 **본문 속 내용**은 모릅니다. 문서를 통째로 알게 하려면 RAG — 문서를 잘라 임베딩해 두고, 질문과 비슷한 조각을 찾아 LLM 에 넘기는 구조입니다.

Dify 는 이걸 **지식** 메뉴와 **지식 검색** 노드로 제공합니다. 이 사례는 그 기능 소개가 아니라, 실제로 답이 나오기까지 **네 번 막힌 기록**입니다. RAG 데모가 10분이면 되는데 실제 구축이 반나절 걸리는 이유가 여기 다 있습니다.

## 사전 준비

- Dify Cloud + **본인 모델 API 키**. 샌드박스 크레딧(200)은 임베딩과 gpt-5 호출로 이 사례 중간에 소진됐습니다. Gemini 키(무료)를 등록했고, 그 무료 한도에도 한 번 걸립니다
- 지식으로 올릴 문서. 여기서는 이 사이트의 k8s 사례 6건을 합친 마크다운([aiusecases-k8s-docs.txt](aiusecases-k8s-docs.txt), 29KB) — Hugo 숏코드를 벗겨 낸 순수 텍스트
- 브라우저 조작과 콘솔 API 호출은 Claude 가 ego lite 로

## 단계별 사용법

{{< step title="첫 번째 벽 — PDF 가 이미지 청크로만 잘린다" image="01-chunk-preview.png" caption="AI Readiness Gap PDF 의 청크 프리뷰. Chunk 1~7 이 전부 '![image](…)' 88자. 디자인 위주 PDF 는 표준 파서가 텍스트를 거의 못 건집니다." >}}
{{< prompt title="입력 프롬프트 (Claude Code에)" >}}
dify 를 이용한 챗봇, 워크플로, RAG앱 을 개별 유스케이스로 작성
{{< /prompt >}}

처음엔 [NotebookLM 사례]({{< relref "/docs/usecases/research/notebooklm-report-datatable-mindmap" >}})에 썼던 17쪽 보고서 PDF 를 올렸습니다. 지식 → 생성 → 파일 업로드 → 청크 설정 프리뷰. 결과가 위 화면입니다 — 청크가 거의 전부 이미지 링크. 검색 테스트를 해 보니 상위 결과가 `![image](https://…file-preview)` 뿐이라 LLM 에 줄 텍스트가 없습니다.

NotebookLM 은 같은 PDF 를 잘 읽었는데 Dify 표준 파서는 못 읽습니다. 벡터 DB 에 넣기 전에 **청크 프리뷰를 반드시 보라**는 첫 교훈. 이 PDF 는 뺐고 텍스트 문서로 바꿨습니다.
{{< /step >}}

{{< step title="두 번째 벽 — 줄 단위 청킹으로 검색이 엉망" image="02-embedded.png" caption="마크다운을 올려 임베딩 완료. 하지만 세그먼트 식별자 기본값 '\\n' 때문에 한 줄짜리 청크가 수백 개." >}}
사이트의 k8s 사례 6건을 마크다운 하나로 합쳐 올렸습니다. 임베딩은 됐는데 검색 테스트 결과가 이랬습니다.

```
0.545  - kind 클러스터 + ingress-nginx + `localhost/aiusecases:dev` 이미지 적재 (앞 사례)
0.518  Ingress를 붙이다 두 번 막히고, 두 번 고친다
0.509  - 앞 사례의 kind 클러스터 (`kind-dev`) + ingress-nginx + …
```

전부 **한 줄**입니다. 청크 설정의 세그먼트 식별자 기본값이 `\n`(줄바꿈)이라 마크다운의 불릿·제목이 각각 청크가 됐고, 질문에 답할 문단은 어디에도 통째로 없습니다. 문서를 지우고 식별자를 `\n\n`(빈 줄 = 문단), 최대 길이 2000 으로 다시 올렸습니다. 청크 수 500+ → 약 50.

이 설정은 콘솔 API 로도 됩니다 — Claude 는 화면 대신 이렇게 했습니다.

```js
POST /console/api/datasets/{id}/documents
{ data_source: { type: "upload_file", info_list: { file_info_list: { file_ids: [id] } } },
  indexing_technique: "high_quality",
  process_rule: { mode: "custom", rules: { segmentation: { separator: "\\n\\n", max_tokens: 2000, chunk_overlap: 100 } } },
  embedding_model: "gemini-embedding-001", embedding_model_provider: "langgenius/gemini/google" }
```
{{< /step >}}

{{< step title="세 번째 벽 — 크레딧 소진, 네 번째 벽 — 무료 한도" image="03-rag-flow.png" caption="최종 채팅 플로우: 시작 → 지식 검색(aiusecases-k8s-docs, top_k 6) → 답변 생성(Gemini 2.5 Flash, 컨텍스트 연결) → 답변. DSL 로 import." >}}
[rag-dsl.yml](rag-dsl.yml) 의 핵심 두 노드:

```yaml
- id: kr
  data: { type: knowledge-retrieval, dataset_ids: [<지식 id>], retrieval_mode: multiple,
          multiple_retrieval_config: { top_k: 6, reranking_enable: false, … }, query_variable_selector: [sys, query] }
- id: llm
  data:
    type: llm
    context: { enabled: true, variable_selector: [kr, result] }     # 검색 결과를 컨텍스트로
    prompt_template:
    - role: system
      text: '아래 컨텍스트에 있는 내용만 근거로 한국어로 답한다. 컨텍스트에 없으면 "문서에 없는 내용입니다" 라고 답하고 추측하지 않는다. … 컨텍스트: {{#context#}}'
```

import 하고 미리보기에서 물었더니 `Model quota has been exceeded` — **샌드박스 200 크레딧이 5 로** 떨어져 있었습니다. 챗봇·워크플로 테스트의 gpt-5 호출과 두 번의 임베딩이 다 먹었습니다.

Gemini API 키를 등록하고 LLM 을 `gemini-2.5-flash` 로 바꿨습니다. 그런데 이번엔 **검색 결과가 빈 배열**. 지식 베이스의 임베딩 모델이 여전히 OpenAI(`text-embedding-3-small`, 크레딧 소진)라 **질문을 임베딩하지 못해** 아무것도 못 찾은 겁니다. 지식 베이스의 임베딩 모델은 만든 뒤 못 바꿉니다 → Gemini 임베딩(`gemini-embedding-001`)으로 **새 지식 베이스**를 만들고 문서를 다시 올렸습니다.

그러자 `429 RESOURCE_EXHAUSTED — embed_content_free_tier_requests, limit: 100`. Gemini 무료 티어는 임베딩 **분당 100 요청**. 청크 150개를 한꺼번에 밀어 넣으니 걸렸습니다. 1분 기다렸다가 청크를 2000자로 키워(약 50개) 다시 → 성공.
{{< /step >}}

{{< step title="답이 나온다 — 출처와 함께" image="04-answer-citation.png" caption="'Helm 롤백하면 --set 으로 준 값은 어떻게 되나?' → 문서의 문장을 인용해 답하고 아래에 인용 청크(aiusecases-k8s-docs.md)." >}}
> Helm 롤백은 values 오버라이드도 되돌립니다. --set으로 얹은 값은 해당 리비전에만 있으며, 롤백 후에는 사라집니다. 이 사례에서 image.tag=v2-typo는 사라지고 replicaCount=2만 남았습니다.

[Helm 사례]({{< relref "/docs/usecases/coding/helm-chart-deploy-test-on-kind" >}})의 주의사항 문단 그대로입니다. 두 번째 질문 "Argo CD selfHeal 을 켠 상태에서 kubectl scale 로 줄이면?" 도 [Argo CD 사례]({{< relref "/docs/usecases/coding/argocd-gitops-on-kind" >}})의 실험 2 문단을 인용해 답했습니다.

**답이 안 나온 질문도 있습니다.** "kind 클러스터에서 Ingress 가 localhost 로 안 붙을 때 원인이 뭐였어?" 는 top 6 안에 정답 문단(컨트롤러가 worker 에 뜨고 포트 매핑은 control-plane)이 안 들어와 "문서에 없는 내용입니다" 가 나왔습니다. 검색 테스트에서 질문을 "localhost:8080 응답 없음 컨트롤러 파드 worker 포트 매핑" 처럼 문서 어휘로 바꾸면 정답 문단이 1위(0.804)로 올라옵니다. 임베딩 검색은 **질문의 어휘가 문서 어휘와 가까울수록** 맞습니다 — 리랭커나 하이브리드 검색을 붙이는 이유.
{{< /step >}}

{{< step title="게시된 웹 앱" image="05-webapp.png" caption="udify.app 공개 페이지. 여는 문장과 추천 질문 3개, 'kind 노드에서 etcd 스냅샷 뜰 때 주의할 점은?' → distroless 라 sh 가 없다는 CKA 사례 문단 인용." >}}
`게시하기` → 공개 URL `https://udify.app/chat/mxXREobuChLUHYAL`. DSL 의 `opening_statement` 와 `suggested_questions` 가 첫 화면에 뜹니다. 추천 질문은 **검색 테스트로 답이 나오는 걸 확인한 것만** 넣었습니다.
{{< /step >}}

## 결과

| 막힌 곳 | 원인 | 해결 |
| --- | --- | --- |
| PDF 청크가 이미지뿐 | 디자인 PDF, 표준 파서 | 텍스트 문서로 교체 |
| 검색 결과가 한 줄짜리 | 세그먼트 식별자 `\n` | `\n\n` + 2000자 |
| `Model quota exceeded` | 샌드박스 크레딧 소진 | Gemini 키 등록 |
| 검색 결과 빈 배열 | 지식의 임베딩 모델이 소진된 OpenAI | Gemini 임베딩으로 새 지식 |
| `429 embed 100/min` | Gemini 무료 한도 | 청크 줄이고 1분 대기 |

최종: 문서 6건, 청크 약 50개, 출처 달린 답. 걸린 시간 40분 중 플로우 만드는 데 5분, 나머지는 위 표.

## 주의사항

- **청크 프리뷰를 먼저 보세요.** 임베딩(유료·한도)을 쓰기 전에 청크가 문장인지 이미지 링크인지 한 줄짜리인지 확인합니다. 이 사례의 첫 두 벽은 프리뷰 30초로 피할 수 있었습니다.
- **마크다운은 `\n\n` 으로 자르세요.** 기본 `\n` 은 불릿 문서에서 최악입니다. 표·코드블록이 많으면 부모-자식 모드도 고려.
- **지식 베이스의 임베딩 모델은 못 바꿉니다.** 만들 때 고른 모델이 소진되거나 사라지면 검색이 조용히 빈 배열을 냅니다. 오류가 안 나서 더 찾기 어렵습니다 — `workflow-runs/{id}/node-executions` 로 검색 노드 출력이 `[]` 인지 보세요.
- **무료 임베딩 한도는 분당입니다.** 문서 하나를 올릴 때 청크 수가 한도 아래인지, 아니면 여러 번 나눠 올리세요.
- **"문서에 없는 내용입니다" 가 나오면 검색부터 의심.** LLM 이 게으른 게 아니라 컨텍스트에 정답 문단이 안 들어온 겁니다. 검색 테스트 화면에서 같은 질문을 넣어 상위 청크를 보세요.
- 추천 질문은 검증한 것만. 첫 화면의 질문이 "문서에 없다" 로 끝나면 신뢰가 바로 깨집니다.

## 응용

- 이 사이트 전체(30건)를 마크다운으로 합쳐 지식으로 → 안내 챗봇을 RAG 로 교체
- 사내 위키 export → 청킹 설정만 맞추고 같은 DSL 재사용
- 지식 검색 노드 뒤에 `조건 분기` 를 두어 검색 결과가 비면 "관련 문서 없음 + 담당자 안내" 로 분기
- 하이브리드 검색 + 리랭커(유료)를 켜고 같은 질문 세트로 적중률 비교
