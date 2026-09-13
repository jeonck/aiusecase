# Page structure

## Path

`content/docs/usecases/<category>/<slug>/index.md` — a page bundle. Images and
downloadable files live in the same folder and are referenced by bare filename.

## Front matter

```yaml
---
title: "동사로 끝나는 구체적 제목 — 부제는 대시 뒤에"
description: "한 문단. 무엇을 했고 결과가 무엇인지. 실패도 한 줄."
weight: 10            # 카테고리 안 정렬. 같은 시리즈는 연속 숫자
date: YYYY-MM-DD
lastmod: YYYY-MM-DD
icon: "material_icon_name"   # Material Symbols 이름
usecase: true
categories: ["코딩·개발"]     # 정확히 하나, 한글 카테고리명
tools: ["Claude Code", "kind"] # 실제로 쓴 도구. 목록 필터 칩이 된다
difficulty: "초급" | "중급" | "고급"
duration: "3분"               # 실측
tags: ["…"]
---
```

Never leave `draft: true` on a finished page.

## Sections, in order

```
## 어떤 문제를 해결하나      — 2~3 문단. 전 사례 링크는 relref
## 사전 준비                — 불릿
## 단계별 사용법            — {{< step >}} 3~6개
## 결과                     — 표(구간/시각/소요) 또는 3줄
## 주의사항                 — 실제로 걸린 것만, 굵은 첫 문장
## 응용                     — 3~4 불릿
```

## Shortcodes

```
{{< step title="…" image="01-xxx.png" caption="캡처에 무엇이 보이는지 한 문장" >}}
본문 (마크다운, 코드블록 가능)
{{< /step >}}

{{< prompt title="입력 프롬프트" >}}
사용자가 실제로 입력한 문장 그대로
{{< /prompt >}}

{{< screenshot src="00-extra.png" alt="…" caption="…" >}}   # step 밖 추가 이미지
```

Steps auto-number. The first step's prompt is the user's literal request; later
prompts are what was typed into the tool (Dify, Gemini, NotebookLM …).

## Links

- Other use cases: `[제목]({{< relref "/docs/usecases/<category>/<slug>" >}})` — target must exist.
- Bundle files: `[kind-dev.yaml](kind-dev.yaml)`. `.md` → rename to `.txt` first.
- External: normal markdown links.

## Images

- Name `01-…png`, `02-…png` in step order. Extra images `00-…`.
- Width ≥ 1200 px for screens; terminal renders 1500 px.
- Mobile-capture pages can use `860 px` (Retina 430 pt).
