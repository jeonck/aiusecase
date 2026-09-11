---
title: "모바일 화면을 캡처로 확인하며 CSS 고치기"
description: "브라우저 창을 폰 폭으로 좁혀 Claude가 직접 캡처해 보게 하고, 눈에 띄는 레이아웃 문제를 CSS 두 줄로 고친 뒤 다시 캡처해 전후를 비교한다."
weight: 10
date: 2026-09-11
lastmod: 2026-09-11
icon: "phone_android"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "Hugo", "Chrome"]
difficulty: "초급"
duration: "10분"
tags: ["반응형", "CSS", "모바일", "캡처", "Hugo"]
---

## 어떤 문제를 해결하나

문서 사이트는 대개 데스크톱에서 만들고 데스크톱에서만 봅니다. 그런데 링크를 받는 쪽은 절반이 폰입니다.
"모바일에서 이상하지 않아?" 를 확인하려면 폰을 꺼내거나 개발자 도구로 폭을 바꿔 가며 스크롤해야 하고, 그러다 보면 안 합니다.

Claude Code는 **화면을 볼 수 있습니다.** 로컬 서버를 띄우고 브라우저 창을 폰 폭으로 좁힌 뒤 캡처해서 Claude에게 보여 주면, 문제를 찾고 CSS를 고치고 다시 캡처해서 전후를 비교하는 것까지 대화 안에서 돌아갑니다.

## 사전 준비

- 로컬에서 띄울 수 있는 사이트 (`hugo server`, `npm run dev` 등)
- Claude Code 데스크톱 앱 + 화면 기록 권한 ([캡처 방법]({{< relref "/docs/usecases/writing/claude-computer-use-screenshot-manual" >}}) 참고)
- Chrome. 창 폭을 AppleScript 로 바꿀 수 있어서 개발자 도구 없이 폰 폭을 만들 수 있습니다

## 단계별 사용법

{{< step title="폰 폭으로 창을 좁혀 첫 화면을 찍는다" image="01-mobile-first-look.png" caption="430px 폭. 요약 카드가 세로로 다섯 칸 쌓여 첫 화면을 다 차지하지만, 이건 정보량 대비 자연스러운 편입니다." >}}
{{< prompt title="입력 프롬프트" >}}
hugo server 띄우고 Chrome 창을 430px 폭으로 좁혀서 유스케이스 페이지를 찍어 봐. 모바일에서 이상한 데 있으면 고쳐.
{{< /prompt >}}

Claude는 서버를 백그라운드로 띄우고, Chrome 새 창을 만들어 폭을 지정한 뒤 캡처합니다.

```bash
hugo server -D --port 1313 &
osascript -e 'tell application "Google Chrome"
  set w to make new window
  set URL of active tab of w to "http://localhost:1313/docs/usecases/automation/gmail-event-to-calendar-ask-gemini/"
  set bounds of w to {0, 33, 430, 927}
end tell'
screencapture -x -R0,33,430,894 mobile.png
```

개발자 도구의 기기 에뮬레이션과 달리 **진짜 뷰포트**라 미디어 쿼리가 그대로 먹습니다. 첫 화면은 문제 없음 — 다음 섹션으로 내려갑니다.
{{< /step >}}

{{< step title="문제를 찾고 CSS를 고쳐 다시 찍는다" image="02-before-after.png" caption="왼쪽 수정 전: 캡처가 단계 번호 칸만큼 들여써져 좁습니다. 오른쪽 수정 후: 캡처가 본문 폭을 다 씁니다." >}}
`#단계별-사용법` 앵커로 이동해 찍은 두 번째 캡처에서 Claude가 짚은 문제:

> 단계 본문이 번호 동그라미(32px) + 간격만큼 들여써져 있어서, 그 안에 들어가는 캡처 이미지가 430px 화면에서 310px 밖에 못 씁니다. 캡처 속 글자가 읽기 어렵습니다.

데스크톱에서는 번호 칸이 전체 폭의 4% 라 티가 안 나지만, 폰에서는 10% 입니다. 고치는 방법은 좁은 화면에서만 캡처가 들여쓰기를 무시하게 하는 것.

```css
@media (max-width: 575.98px) {
    /* 좁은 화면에서는 캡처가 번호 칸 들여쓰기를 무시하고 본문 폭을 다 쓴다 */
    .kb-step .kb-shot { margin-left: calc(-32px - .7rem); }
}
```

텍스트는 그대로 들여쓴 채 두고 이미지만 왼쪽으로 당깁니다. `hugo server` 가 CSS 변경을 자동 반영하므로 창을 새로고침하고 같은 위치를 다시 찍어 나란히 놓습니다.
{{< /step >}}

{{< step title="diff 를 확인하고 커밋한다" image="03-diff.png" caption="바뀐 건 미디어 쿼리 안의 두 줄뿐입니다." >}}
전후 캡처가 나란히 보이면 판단은 쉽습니다. Claude 앱의 diff 패널에서 변경이 두 줄인 걸 확인하고 커밋합니다.

이 사례에서 Claude가 **고치지 않은** 것도 있습니다. 첫 캡처의 요약 카드가 세로로 길게 쌓이는 건 "폰에서는 자연스러운 편" 이라 두었습니다. 캡처를 보고 판단했기 때문에 불필요한 수정을 안 한 것이고, 그걸 사람이 바꾸고 싶으면 그때 시키면 됩니다.
{{< /step >}}

## 결과

폰 폭에서 단계 캡처의 표시 폭이 310px → 350px (+13%). CSS 두 줄, 10분.
숫자보다 중요한 건 "모바일 확인" 이 **"찍어 봐"** 한마디가 됐다는 점입니다. 이제 페이지를 추가할 때마다 같은 요청을 붙이면 됩니다.

## 주의사항

- **캡처는 Claude가 보고, 판단은 같이 합니다.** "이상한 데 있으면 고쳐" 라고 열어 두면 사소한 것까지 손댈 수 있습니다. 위 사례처럼 판단 근거를 말하게 하고, 캡처를 사람도 같이 보세요.
- **AppleScript 로 창 폭을 바꾸는 건 macOS Chrome 에서만 됩니다.** 다른 환경에서는 개발자 도구 기기 모드나 Playwright 의 `viewport` 옵션을 씁니다. 전자는 사람이 조작해야 하고, 후자는 캡처가 페이지 영역만 나옵니다(브라우저 UI 없음 — 이 용도엔 오히려 낫습니다).
- **Retina 화면은 픽셀이 2배**입니다. 430px 창을 찍으면 860px 이미지가 나옵니다. 전후 비교 이미지를 만들 때 폭을 맞추세요.
- 서버를 백그라운드로 띄웠으면 끝나고 `pkill -f "hugo server"` 로 내립니다. 안 내리면 다음 세션에서 포트가 막힙니다.

## 응용

- PR 마다 주요 페이지를 375 / 768 / 1280px 세 폭으로 찍어 **전후 비교 이미지를 PR 설명에 첨부**
- 다크 모드 토글 후 같은 위치를 찍어 대비 문제 확인
- 긴 표가 있는 페이지에서 가로 스크롤이 생기는지 좁은 폭으로 점검
- 이 사이트의 모든 유스케이스 페이지를 순회하며 캡처 → 깨진 페이지 목록 만들기
