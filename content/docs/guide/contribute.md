---
weight: 20
title: "유스케이스 추가하기"
description: "캡처 이미지를 올리고 단계별 사용법을 쓰는 절차"
icon: "add_circle"
---

## 한 줄 요약

**스크립트로 폴더를 만들고 → 캡처 PNG를 그 폴더에 넣고 → 본문을 채우고 → 푸시합니다.**

## 1. 사례 폴더 만들기

```bash
./scripts/new-usecase.sh <카테고리> <영문-슬러그> "<한글 제목>"
```

예를 들어 업무 자동화 카테고리에 슬랙 요약 사례를 만든다면:

```bash
./scripts/new-usecase.sh automation slack-daily-digest "슬랙 채널 하루치 요약하기"
```

`content/docs/usecases/automation/slack-daily-digest/index.md` 가 템플릿과 함께 생성됩니다.

사용 가능한 카테고리 폴더:

| 폴더 | 카테고리 |
| --- | --- |
| `automation` | 업무 자동화 |
| `writing` | 문서·글쓰기 |
| `coding` | 코딩·개발 |
| `data` | 데이터·분석 |
| `media` | 이미지·영상 |
| `research` | 리서치·학습 |

{{< alert context="info" >}}
폴더 이름(슬러그)은 **영문 소문자와 하이픈**만 씁니다. URL이 되기 때문입니다. 제목은 한글로 자유롭게 쓰세요.
{{< /alert >}}

## 2. 캡처 이미지를 폴더에 넣기

만들어진 폴더에 PNG를 그대로 복사합니다. 별도 등록 과정이 없습니다 — **같은 폴더에 있으면 참조됩니다.**

```
content/docs/usecases/automation/slack-daily-digest/
├── index.md
├── 01-open.png
├── 02-prompt.png
└── 03-result.png
```

파일명은 `01-`, `02-` 처럼 **단계 번호로 시작**하게 지으면 순서가 눈에 보여 관리가 쉽습니다.

본문에서는 단계에 붙이거나:

```markdown
{{</* step title="채널 열기" image="01-open.png" caption="요약할 채널을 연다" */>}}
설명을 여기에 씁니다.
{{</* /step */>}}
```

단독으로 넣습니다:

```markdown
{{</* screenshot src="03-result.png" alt="요약 결과" caption="이렇게 나옵니다" */>}}
```

{{< alert context="warning" >}}
**캡처를 올리기 전에 가릴 것** — 이메일 주소, 실명, 사내 시스템 주소, 고객사명, API 키, 토큰.
이 사이트는 공개됩니다. 한번 푸시된 이미지는 커밋 히스토리에 남습니다.
{{< /alert >}}

## 3. 본문 채우기

`index.md` 상단 front matter에서 분류를 지정합니다. 이게 카테고리/도구/난이도 페이지에 자동 반영됩니다.

```yaml
categories: ["업무 자동화"]     # 카테고리 (한글 그대로)
tools: ["Claude", "Slack"]       # 사용한 도구
difficulty: "중급"               # 초급 / 중급 / 고급
duration: "5분"                  # 실제로 걸린 시간
tags: ["요약", "협업"]           # 자유 키워드
usecase: true                    # 요약 카드 표시 (지우지 마세요)
```

본문은 템플릿에 있는 섹션 순서를 지켜 주세요. 순서가 같아야 나중에 비교하며 읽을 수 있습니다.

### 쓸 때 지킬 것 세 가지

1. **클릭한 것을 적습니다.** "Gemini를 실행한다"가 아니라 "상단 툴바의 Gemini 아이콘을 누른다".
2. **프롬프트는 원문 그대로 남깁니다.** 다듬지 말고 실제로 입력한 것을 `prompt` 숏코드에 넣으세요.
3. **틀렸던 지점을 적습니다.** 주의사항 섹션이 이 저장소에서 제일 값이 나가는 부분입니다. 잘 된 이야기는 누구나 쓸 수 있습니다.

## 4. 미리 보고 푸시하기

```bash
hugo server -D        # http://localhost:1313 에서 확인
git add .
git commit -m "usecase: 슬랙 채널 하루치 요약하기"
git push
```

`main` 에 푸시되면 GitHub Actions가 빌드해서 <https://aiusecases.metacog.co.kr> 에 반영합니다. 보통 1~2분 걸립니다.

## 사용할 수 있는 서식

| 숏코드 | 용도 |
| --- | --- |
| `step` | 번호가 자동으로 매겨지는 단계. `title`, `image`, `caption` |
| `screenshot` | 단독 이미지. `src`, `alt`, `caption` |
| `prompt` | 실제 입력한 프롬프트 박스 |
| `alert` | 강조 박스. `context="info|warning|danger|success"` |
| `tabs` / `tab` | 도구별 대안을 나란히 보여줄 때 |
