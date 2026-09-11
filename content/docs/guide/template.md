---
weight: 30
title: "유스케이스 템플릿"
description: "새 사례를 쓸 때 복사해서 쓰는 뼈대"
icon: "content_paste"
---

`./scripts/new-usecase.sh` 가 아래 내용으로 파일을 만들어 줍니다. 손으로 만들 때는 이걸 복사하세요.

````markdown
---
title: "제목 — 무엇을 하는지 한 줄로"
description: "검색 결과와 카드에 보이는 한 문장 설명"
weight: 10
date: 2026-01-01
lastmod: 2026-01-01
icon: "bolt"
usecase: true
categories: ["업무 자동화"]
tools: ["도구 이름"]
difficulty: "초급"
duration: "5분"
tags: ["키워드"]
---

## 어떤 문제를 해결하나

원래 어떻게 하던 일인지, 뭐가 불편했는지 2~3문단.

## 사전 준비

- 필요한 계정 / 권한 / 확장

## 단계별 사용법

{{</* step title="첫 단계" image="01-xxx.png" caption="캡처 설명" */>}}
무엇을 눌렀는지까지 적습니다.
{{</* /step */>}}

{{</* step title="두 번째 단계" image="02-xxx.png" */>}}
{{</* prompt title="입력 프롬프트" */>}}
실제로 입력한 프롬프트 원문
{{</* /prompt */>}}
{{</* /step */>}}

## 결과

뭐가 달라졌는지. 가능하면 시간으로.

## 주의사항

- 어디서 틀렸는지, 무엇을 확인해야 하는지

## 응용

- 같은 패턴이 먹히는 다른 상황
````
