---
title: "Dify로 사이트 안내 챗봇 만들어 배포하기 — 프롬프트 한 문단, 공개 URL까지 10분"
description: "Dify Cloud에서 빈 챗봇 앱을 만들고 시스템 프롬프트 한 문단을 넣어 이 사이트의 사례를 추천하는 안내봇을 만든다. 미리보기로 검증하고 게시하면 udify.app 공개 URL과 API가 생긴다. 브라우저 조작은 Claude가 ego lite로."
weight: 50
date: 2026-09-12
lastmod: 2026-09-12
icon: "smart_toy"
usecase: true
categories: ["업무 자동화"]
tools: ["Dify", "Claude Code", "ego-browser"]
difficulty: "초급"
duration: "10분"
tags: ["Dify", "챗봇", "LLM앱", "노코드", "배포"]
---

## 어떤 문제를 해결하나

"우리 서비스 안내 챗봇 하나 만들자" 는 말이 나오면 보통 서버·프레임워크·프론트엔드 얘기로 번집니다.
Dify 는 그걸 **프롬프트 한 문단 + 게시 버튼**으로 줄입니다. 모델 호출, 대화 메모리, 웹 UI, API 키 관리가 다 들어 있습니다.

이 사례에서는 이 사이트(aiusecases.metacog.co.kr)의 사례를 골라 주는 안내봇을 만들었습니다. 사용자가 "하고 싶은 일" 을 말하면 카테고리·가까운 사례·첫 단계를 답합니다. Dify Cloud 무료 샌드박스, 브라우저 조작은 [ego lite]({{< relref "/docs/usecases/automation/ego-lite-browser-agent-driving" >}}) 로 Claude 가 했습니다.

## 사전 준비

- [cloud.dify.ai](https://cloud.dify.ai) 계정. 무료 샌드박스에 OpenAI 모델용 크레딧 200 이 들어 있습니다 (gpt-5 기준 대화 몇 번이면 소진 — 아래 주의사항)
- 챗봇이 알아야 할 내용 한 문단. 여기서는 카테고리 6개와 대표 사례 이름
- 자동화하려면 ego lite 에서 Dify 로그인. 사람이 직접 해도 클릭 10번

## 단계별 사용법

{{< step title="빈 앱 → 챗봇 → 이름" image="01-create.png" caption="'빈 상태로 시작' 대화상자. 초보자용 기본 앱 유형을 펼치면 챗봇·에이전트·텍스트 생성기. 챗봇을 고르면 시작→LLM→답변 3노드 채팅 플로우가 만들어집니다." >}}
{{< prompt title="입력 프롬프트 (Claude Code에)" >}}
dify 를 이용한 챗봇, 워크플로, RAG앱 을 개별 유스케이스로 작성
{{< /prompt >}}

스튜디오 → `생성` → `빈 상태로 시작` → `초보자용 기본 앱 유형` → **챗봇**. 이름 `AI Usecases 안내봇`.
2026년 9월 현재 "챗봇" 을 고르면 내부적으로 **채팅 플로우**(시작 → LLM → 답변)가 만들어지고 모델은 `gpt-5` 가 기본으로 잡힙니다.
{{< /step >}}

{{< step title="LLM 노드의 SYSTEM 프롬프트에 한 문단" image="02-prompt.png" caption="LLM 노드 설정 패널. SYSTEM 415자. 카테고리·대표 사례·답변 형식·모르는 주제 처리 규칙." >}}
{{< prompt title="SYSTEM 프롬프트" >}}
너는 aiusecases.metacog.co.kr(AI 활용 사례 지식 저장소)의 안내봇이다. 사이트에는 6개 카테고리가 있다: 업무 자동화, 문서·글쓰기, 코딩·개발, 데이터·분석, 이미지·영상, 리서치·학습. 대표 사례: Gmail 메일을 Ask Gemini로 캘린더 등록, NotebookLM으로 보고서 요약·슬라이드·오디오, Claude Drive 커넥터로 파일 정리, kind+Podman 로컬 k8s, Helm/Argo CD 배포, CKA·CKAD 연습 문제 세트, pptxgenjs로 PPT 생성. 사용자가 하고 싶은 일을 말하면 (1) 맞는 카테고리 하나, (2) 가장 가까운 사례 1~2개, (3) 첫 단계 한 줄을 한국어로 5줄 이내로 답한다. 사이트에 없는 주제면 '아직 사례가 없다'고 말하고 가장 가까운 것을 제안한다.
{{< /prompt >}}

네 가지가 들어 있습니다: **정체성**(어느 사이트의 봇인가), **지식**(카테고리·사례 이름), **출력 형식**(3항목 5줄), **경계**(없는 주제 처리). 이 정도면 RAG 없이도 안내봇은 됩니다 — 사례가 수백 건이 되면 RAG(지식 검색) 로 넘어갑니다 — 다음 사례.

USER 메시지는 기본값 `{{#sys.query#}}` 그대로. 메모리는 켜 두면 이전 대화를 기억합니다.
{{< /step >}}

{{< step title="미리보기로 검증" image="03-preview.png" caption="'회의록 녹음 파일을 요약해서 팀에 공유하고 싶어' → 카테고리 문서·글쓰기, 가까운 사례 2개, 첫 단계 한 줄. 형식대로." >}}
오른쪽 `미리보기` 패널에서 바로 대화합니다. 답이 프롬프트의 형식(카테고리 / 가까운 사례 / 첫 단계)을 그대로 따랐습니다.

여기서 프롬프트를 고치고 다시 물어보는 루프가 챗봇 개발의 전부입니다. 코드 배포가 없으니 한 번에 10초.
{{< /step >}}

{{< step title="게시 → 공개 URL과 API" image="04-access.png" caption="액세스 지점. 웹 앱 URL(udify.app/chat/…)과 백엔드 API(api.dify.ai/v1). 사이트 임베드 코드와 MCP 서버 옵션도 있습니다." >}}
`게시하기` → `게시`. 액세스 지점 페이지에 세 가지가 생깁니다.

- **웹 앱 URL** — `https://udify.app/chat/c1thJ3bUktEIclS6`. 로그인 없이 누구나 대화
- **사이트에 임베드** — iframe / 스크립트 스니펫. 이 사이트 우하단에 붙이면 안내봇이 됨
- **백엔드 API** — `POST https://api.dify.ai/v1/chat-messages`, API 키 발급. 슬랙 봇·자체 UI 에서 호출

DSL 도 내보낼 수 있습니다: [chatbot-dsl.yml](chatbot-dsl.yml) — 이 파일을 다른 워크스페이스에서 `DSL 가져오기` 하면 같은 앱이 복원됩니다.
{{< /step >}}

{{< step title="최종 사용자 화면" image="05-webapp.png" caption="udify.app 의 공개 웹 앱. '쿠버네티스 자격증 준비하려는데 로컬에서 연습할 방법 있어?' → 코딩·개발, kind+Podman / CKA·CKAD 세트, kind create cluster 부터." >}}
공개 URL 을 열어 아무 계정 없이 물어봤습니다. 답변이 미리보기와 같은 형식으로, 이 사이트의 [로컬 k8s]({{< relref "/docs/usecases/coding/local-k8s-dev-env-kind-podman" >}})·[CKA 세트]({{< relref "/docs/usecases/coding/cka-practice-problem-set" >}}) 사례를 가리킵니다.
{{< /step >}}

## 결과

빈 앱에서 공개 URL 까지 10분. 코드 0줄, 서버 0대.
프롬프트 415자가 봇의 전부라서, 사례가 늘면 그 문단만 고치면 됩니다. 정확히는 그게 한계이기도 합니다 — 사례 20건까지는 프롬프트에 이름을 나열할 수 있지만 200건이면 RAG 가 필요합니다.

## 주의사항

- **샌드박스 크레딧은 gpt-5 로 금방 없어집니다.** 이 사례 3개(챗봇·워크플로·RAG)를 만드는 동안 200 크레딧이 5 로 떨어졌고, RAG 의 마지막 호출이 `Model quota has been exceeded` 로 막혔습니다. 실제로 쓰려면 설정 → 모델 공급자에 본인 API 키(OpenAI, Gemini 등)를 등록하세요. 첫 시도는 `gpt-4o-mini` 같은 작은 모델로.
- **"챗봇" 이 채팅 플로우로 만들어집니다.** 예전 Dify 의 단순 챗봇(프롬프트 한 칸)과 달리 노드 편집기가 열립니다. 3노드 그대로 두면 됩니다.
- **프롬프트 편집기는 contenteditable 입니다.** 자동화할 때 `fill()` 이 안 먹고, 클릭 후 키보드 입력으로 넣어야 합니다.
- **공개 URL 은 정말 공개입니다.** 누구나 크레딧을 씁니다. 액세스 지점에서 웹 앱 토글을 끄거나, 설정에서 인증을 켜세요.
- DSL 내보내기 버튼은 파일 다운로드라 에이전트 브라우저에서는 안 잡혔습니다. `GET /console/api/apps/<id>/export` 를 CSRF 토큰과 함께 호출하면 YAML 이 옵니다.

## 응용

- 사내 위키 FAQ 봇: 프롬프트에 "자주 묻는 질문 20개와 답" 을 넣고 임베드
- 이 사이트 우하단에 임베드 → 방문자가 "이런 거 하고 싶은데" 라고 물으면 사례로 안내
- API 로 슬랙 봇 연결 → `/usecase 회의록 요약` 슬래시 커맨드
- 프롬프트를 카테고리별로 나눠 Gem 처럼 여러 봇 운영
