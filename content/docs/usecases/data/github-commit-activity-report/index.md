---
title: "GitHub 커밋 활동을 API로 모아 리포트 만들기"
description: "GitHub Search API로 내 저장소 전체의 12개월 커밋 수와 최근 1,000건을 받아, 사람·AI 에이전트·자동화 봇 비중과 저장소별 분포를 차트와 표로 정리한다."
weight: 10
date: 2026-09-11
lastmod: 2026-09-11
icon: "monitoring"
usecase: true
categories: ["데이터·분석"]
tools: ["Claude Code", "GitHub CLI", "pandas", "matplotlib"]
difficulty: "중급"
duration: "15분"
tags: ["GitHub", "API", "차트", "리포트", "커밋분석"]
---

## 어떤 문제를 해결하나

저장소가 40개를 넘어가면 "내가 요즘 뭘 얼마나 하고 있나" 를 GitHub 프로필 잔디만으로는 알 수 없습니다.
잔디는 커밋 **수**만 보여 주고, 그중 얼마가 매일 도는 자동화 파이프라인이고 얼마가 내 손인지, 어느 저장소에 시간이 쏠렸는지는 안 나옵니다.

Claude Code에 "내 GitHub 커밋 활동을 지난 12개월치 분석해서 리포트로 만들어 줘" 라고 하면, API 호출 → 집계 → 차트 → HTML 리포트까지 한 번에 나옵니다.
중간에 **분류 기준이 틀렸던 걸 발견해서 고친 과정**이 이 사례의 핵심입니다.

## 사전 준비

- `gh` CLI 로그인 (`gh auth status` 로 확인). 검색 API는 인증 없이는 분당 10회로 막힙니다
- Python 3 + `pandas`, `matplotlib`
- 차트에 한글이 들어가면 한글 폰트 파일 하나 (여기서는 사이트에 이미 있던 나눔고딕 TTF 재사용)

## 단계별 사용법

{{< step title="API 두 종류로 데이터를 받는다" image="01-gh-api.png" caption="월별 수는 total_count 하나만, 상세 분석용은 최근 1,000건을 100건씩 10페이지로 받습니다." >}}
{{< prompt title="입력 프롬프트" >}}
내 GitHub 저장소 전체의 최근 12개월 커밋 활동을 분석해 줘.
월별 추이, 누가 커밋했는지(사람/AI/봇), 저장소별 분포를 차트와 표로 만들어 HTML 리포트로 정리해.
{{< /prompt >}}

Claude는 저장소를 하나씩 도는 대신 **커밋 검색 API**를 씁니다. `user:jeonck` 한정자로 내 소유 저장소 전체를 한 번에 잡을 수 있습니다.

```bash
# 월별: 개수만 필요하니 total_count 만 받는다 (12회 호출)
gh api -X GET search/commits -f q="user:jeonck committer-date:2026-08-01..2026-08-31" --jq .total_count

# 상세: 최근 1,000건 (검색 API 상한) — 저장소, 작성자, 날짜, 메시지 첫 줄
gh api -X GET search/commits -f q="user:jeonck committer-date:>=2026-08-01" -f per_page=100 -f page=1 \
  --jq '.items[] | [.repository.name, .commit.author.name, .commit.author.date[0:10], (.commit.message|split("\n")[0])] | @tsv'
```

호출 사이에 `sleep 2` 를 넣습니다. 커밋 검색은 인증해도 분당 30회 제한입니다.
{{< /step >}}

{{< step title="첫 집계에서 분류가 틀린 걸 잡는다" image="02-chart.png" caption="고친 뒤의 차트. 월별 추이 / 작성 주체 비율 / 저장소 Top 10." >}}
Claude가 처음 만든 분류는 **작성자 이름**만 봤습니다. 이름에 `bot` 이 있으면 봇, `Claude` 면 AI, 나머지는 사람.

그런데 저장소별 표에서 `one-sentence` 저장소가 "사람 137건" 으로 1위였습니다. 매일 한 문장씩 자동 게시하는 파이프라인 저장소가 사람 1위일 리 없습니다.
메시지를 뽑아 보니 `Add sentence No.475 — Hopper (2026-09-11-12)` — **GitHub Actions 가 내 토큰으로 커밋해서 작성자가 `jeonck`** 으로 찍힌 것이었습니다.

그래서 분류 기준을 메시지 패턴까지 보도록 바꿨습니다.

```python
AUTO = re.compile(r"scheduled run|Add sentence No\.|^Merge branch|\(\d{4}-\d{2}-\d{2}-\d{2}\)|^(daily|auto)", re.I)
def kind(row):
    a = row.author.lower()
    if "bot" in a or "action" in a or AUTO.search(row.msg): return "자동화(봇·스케줄)"
    if "claude" in a or "qwen" in a or "gemini" in a:        return "AI 에이전트"
    return "사람"
```

| 구분 | 이름만으로 | 메시지 패턴 반영 |
| --- | --- | --- |
| 사람 | 45% | **36%** |
| AI 에이전트 | 16% | 17% |
| 자동화 | 39% | **47%** |

사람 커밋이 9%p 줄었습니다. 이 차이가 이 리포트에서 가장 중요한 숫자입니다.
{{< /step >}}

{{< step title="HTML 리포트로 묶어 브라우저에서 본다" image="03-report.png" caption="차트 + 저장소×작성 주체 표 + '읽는 법' 세 줄. 파일 하나라 슬랙에 그대로 첨부할 수 있습니다." >}}
pandas 의 `DataFrame.to_html()` 과 차트 PNG 한 장을 HTML 파일 하나에 넣습니다. 별도 대시보드 도구 없이 `file://` 로 열면 끝입니다.

리포트에서 읽어 낸 것:

- 8월 커밋 1,356건은 7월의 2.4배지만, **절반 가까이가 스케줄 워크플로**. 잔디가 진해진 이유는 파이프라인을 여러 개 띄웠기 때문
- 사람 손이 집중된 저장소는 `handson`(온프렘 k8s 실습), `toolian`, `field-cases` — 실제로 뭔가를 배운 곳
- AI 에이전트 공동 작성이 큰 곳은 `video-shortcraft`(53건), `toolian`(26건) — 새 도구를 빠르게 만든 곳
{{< /step >}}

## 결과

40여 개 저장소의 12개월 활동이 리포트 한 장으로 정리됐습니다. API 호출 22번, 파이썬 40줄, 15분.
"잔디가 진하다" 는 인상이 "자동화 47%, 사람 36%, AI 17%" 라는 숫자가 됐고, 어디에 내 시간이 실제로 갔는지가 저장소 단위로 보입니다.

## 주의사항

- **작성자 이름으로 사람/봇을 나누지 마세요.** Actions 가 개인 토큰(`GITHUB_TOKEN` 대신 PAT)으로 커밋하면 작성자가 본인으로 찍힙니다. 커밋 메시지 패턴, 커밋 시각(매일 같은 시각), 파일 경로까지 봐야 합니다. 첫 결과가 그럴듯해 보여도 **1위 항목을 직접 열어 보는 것**이 이 사례에서 얻은 교훈입니다.
- **검색 API 는 1,000건까지만 줍니다.** 그 이상은 기간을 쪼개서 여러 번 부르거나, 저장소별 `commits` API 로 가야 합니다. 월별 총계는 `total_count` 라 상한이 없습니다.
- **`user:` 한정자는 내 소유 저장소만 잡습니다.** 조직 저장소나 남의 저장소에 한 기여는 `author:` 로 따로 세야 합니다.
- 비공개 저장소도 검색에 포함됩니다. 리포트를 공유할 땐 저장소 이름이 노출돼도 되는지 확인하세요.
- 차트 한글은 matplotlib 에 폰트를 직접 등록해야 합니다 (`font_manager.addfont`). 안 하면 □ 로 나옵니다.

## 응용

- 팀 저장소에 `org:` 한정자로 같은 분석 → 사람별·주차별 리뷰 부하 파악
- PR 검색(`search/issues` + `is:pr`)으로 **리뷰 대기 시간** 분포 뽑기
- 커밋 메시지 접두어(`feat:`, `fix:`, `chore:`) 비율로 저장소 성숙도 비교
- 매주 월요일 크론으로 돌려 슬랙에 리포트 HTML 첨부
