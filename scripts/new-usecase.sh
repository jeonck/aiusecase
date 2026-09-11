#!/usr/bin/env bash
# 새 유스케이스 페이지 번들을 만든다.
#   ./scripts/new-usecase.sh <카테고리폴더> <영문-슬러그> "<한글 제목>"
# 예)
#   ./scripts/new-usecase.sh automation slack-daily-digest "슬랙 채널 하루치 요약하기"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<USAGE
사용법: $(basename "$0") <카테고리폴더> <영문-슬러그> "<한글 제목>"

카테고리 폴더:
  automation  업무 자동화
  writing     문서·글쓰기
  coding      코딩·개발
  data        데이터·분석
  media       이미지·영상
  research    리서치·학습
USAGE
}

if [ $# -lt 3 ]; then usage; exit 1; fi

CAT="$1"; SLUG="$2"; TITLE="$3"

case "$CAT" in
    automation) CAT_KO="업무 자동화" ;;
    writing)    CAT_KO="문서·글쓰기" ;;
    coding)     CAT_KO="코딩·개발" ;;
    data)       CAT_KO="데이터·분석" ;;
    media)      CAT_KO="이미지·영상" ;;
    research)   CAT_KO="리서치·학습" ;;
    *) echo "알 수 없는 카테고리: $CAT" >&2; echo >&2; usage >&2; exit 1 ;;
esac

if ! printf '%s' "$SLUG" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    echo "슬러그는 영문 소문자/숫자/하이픈만 사용합니다: $SLUG" >&2
    exit 1
fi

DIR="$ROOT/content/docs/usecases/$CAT/$SLUG"
if [ -e "$DIR" ]; then echo "이미 존재합니다: $DIR" >&2; exit 1; fi

TODAY="$(date +%F)"
mkdir -p "$DIR"

cat > "$DIR/index.md" <<EOF
---
title: "$TITLE"
description: "한 문장으로 무엇을 하는 사례인지 적습니다"
weight: 10
date: $TODAY
lastmod: $TODAY
icon: "bolt"
usecase: true
categories: ["$CAT_KO"]
tools: ["도구 이름"]
difficulty: "초급"
duration: "5분"
tags: []
draft: true
---

## 어떤 문제를 해결하나

원래 어떻게 하던 일이고 뭐가 불편했는지 적습니다.

## 사전 준비

- 필요한 계정 / 권한 / 확장 프로그램

## 단계별 사용법

{{< step title="첫 단계" image="01-first.png" caption="캡처 설명" >}}
무엇을 눌렀는지까지 적습니다.
{{< /step >}}

{{< step title="두 번째 단계" image="02-second.png" caption="캡처 설명" >}}
{{< prompt title="입력 프롬프트" >}}
실제로 입력한 프롬프트 원문을 그대로 붙여넣습니다
{{< /prompt >}}
{{< /step >}}

{{< step title="결과 확인" image="03-result.png" caption="캡처 설명" >}}
어떤 결과가 나왔는지 적습니다.
{{< /step >}}

## 결과

무엇이 달라졌는지. 가능하면 시간으로 적습니다.

## 주의사항

- 어디서 틀렸는지, 무엇을 확인해야 하는지

## 응용

- 같은 패턴이 먹히는 다른 상황
EOF

cat > "$DIR/IMAGES.md" <<EOF
# 이 폴더에 넣을 캡처 이미지

PNG 파일을 이 폴더에 그대로 복사하면 본문에서 파일명으로 참조됩니다.

- 01-first.png
- 02-second.png
- 03-result.png

올리기 전에 이메일 주소, 실명, 사내 주소, 고객사명, API 키 등은 가려 주세요.
EOF

echo "생성 완료: $DIR"
echo
echo "다음 순서로 진행하세요."
echo "  1. 캡처 PNG 를 $DIR 에 복사"
echo "  2. $DIR/index.md 본문 작성 (다 쓰면 front matter 의 draft: true 를 지웁니다)"
echo "  3. hugo server -D 로 확인"
