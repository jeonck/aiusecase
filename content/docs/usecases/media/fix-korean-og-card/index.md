---
title: "공유 카드(OG 이미지) 한글 깨짐을 브랜드 카드로 고치기"
description: "링크를 카톡·슬랙에 붙였을 때 뜨는 미리보기 카드가 한글을 □로 그리던 문제를, 한글 폰트와 Pillow로 만든 브랜드 베이스 카드로 페이지마다 자동 생성되게 바꾼다."
weight: 10
date: 2026-09-11
lastmod: 2026-09-11
icon: "image"
usecase: true
categories: ["이미지·영상"]
tools: ["Claude Code", "Hugo", "Python Pillow"]
difficulty: "중급"
duration: "20분"
tags: ["OG이미지", "썸네일", "한글폰트", "Hugo", "소셜공유"]
---

## 어떤 문제를 해결하나

사이트 링크를 카카오톡·슬랙·X에 붙이면 **미리보기 카드**가 뜹니다. `og:image` 메타 태그가 가리키는 이미지입니다.
이 사이트의 테마(Lotus Docs)는 페이지마다 제목·설명을 얹은 카드를 자동으로 만들어 주는데, 영문 폰트(Poppins)만 들어 있어서 **한글이 전부 □로 깨지고**, 제목이 길면 설명과 겹칩니다.

디자이너에게 카드 템플릿을 부탁하고 페이지마다 이미지를 만들어 넣는 대신, Claude Code에 "한글 깨지는 OG 카드 고쳐 줘" 라고 했습니다.
결과는 한글 폰트 + 브랜드 베이스 카드 + 테마 파티셜 오버라이드 — 페이지가 늘어나도 손댈 게 없습니다.

## 사전 준비

- Hugo 사이트 (Lotus Docs 등 `images.Text` 로 OG 카드를 만드는 테마)
- Python Pillow (베이스 카드 그리기용). `pip install pillow`
- 재배포 가능한 한글 폰트 — 여기서는 [나눔고딕](https://github.com/google/fonts/tree/main/ofl/nanumgothic) (OFL)

## 단계별 사용법

{{< step title="지금 카드가 어떻게 나오는지 본다" image="01-broken-card.png" caption="테마가 자동 생성한 카드. 영문만 살고 한글은 □, 제목 두 번째 줄이 설명과 겹칩니다." >}}
{{< prompt title="입력 프롬프트" >}}
사이트 og:image 카드가 한글이 깨져. 원인 찾고 브랜드 색으로 카드 다시 만들어서 모든 페이지에 자동 적용되게 해 줘.
{{< /prompt >}}

Claude는 `hugo` 로 빌드한 뒤 `og:image` 태그가 가리키는 파일을 열어 보고, 테마의 `get-featured-image.html` 파티셜을 찾아 원인을 짚습니다.

- 제목을 `images.Text` 로 그리는데 폰트가 `poppins-bold.ttf` → 한글 글리프 없음
- 설명의 y 좌표를 제목 **글자 수**로만 추정 → 한글은 폭이 넓어 줄이 더 늘어나고 겹침

원인이 폰트와 좌표 계산이라, 파티셜 하나를 오버라이드하면 끝난다는 판단이 여기서 섭니다.
{{< /step >}}

{{< step title="브랜드 베이스 카드를 Pillow로 그린다" image="02-fixed-cards.png" caption="같은 베이스 카드 위에 Hugo가 페이지별 제목·설명을 얹은 결과. 분류 페이지(초급·카테고리)와 긴 제목 페이지 모두 정상입니다." >}}
카드 = **베이스 이미지(고정)** + **텍스트(페이지별)** 로 나눕니다. 베이스는 한 번만 그리면 되니 Pillow 20줄이면 됩니다.

```python
from PIL import Image, ImageDraw, ImageFont
W, H = 1200, 630
im = Image.new("RGB", (W, H), (15, 23, 42))         # 남색 배경
d = ImageDraw.Draw(im)
d.rectangle((0, 0, 14, H), fill=(43, 108, 176))      # 왼쪽 강조선 (사이트 accent)
d.rounded_rectangle((70, 60, 150, 140), radius=22, fill=(43, 108, 176))
bold = "assets/opengraph/NanumGothic-Bold.ttf"
d.text((110, 100), "AI", fill="white", font=ImageFont.truetype(bold, 44), anchor="mm")
d.text((70, 540), "AI Usecases", fill=(226, 232, 240), font=ImageFont.truetype(bold, 34))
im.save("assets/opengraph/card-base.png")
```

색은 사이트 CSS의 `--kb-accent: #2b6cb0` 를 그대로 씁니다. 로고 SVG를 래스터화하는 대신 둥근 사각형 + "AI" 텍스트로 마크를 다시 그렸습니다 — Pillow는 SVG를 못 읽고, 라이브러리를 더 넣을 이유가 없습니다.

그다음 테마 파티셜을 `layouts/partials/docs/head/get-featured-image.html` 에 복사해 폰트와 좌표만 바꿉니다.

```go-html-template
{{ $base := resources.Get "opengraph/card-base.png" }}
{{ $bold := resources.Get "opengraph/NanumGothic-Bold.ttf" }}
{{ $n := strings.RuneCount $title }}
{{ $size := 56 }}{{ $perLine := 19 }}
{{ if gt $n 38 }}{{ $size = 46 }}{{ $perLine = 23 }}{{ end }}
{{ $lines := math.Ceil (div (float $n) (float $perLine)) }}
{{ $descY := add 175 (int (mul $lines (add $size 14))) | add 26 }}
```

한 줄에 들어가는 글자 수(19자)로 줄 수를 세고, 그만큼 설명을 아래로 내립니다. 제목이 38자를 넘으면 글자를 줄여 3줄을 막습니다.
{{< /step >}}

{{< step title="배포 후 실제 카드 URL을 열어 확인한다" image="03-live-card.png" caption="배포된 사이트의 og:image URL을 브라우저에서 직접 연 화면. 이 이미지가 메신저 미리보기에 그대로 뜹니다." >}}
푸시하고 GitHub Pages 배포가 끝나면 페이지 소스의 `og:image` 를 열어 봅니다.

```bash
curl -s https://aiusecases.metacog.co.kr/docs/usecases/automation/gmail-event-to-calendar-ask-gemini/ | grep -o '<meta property="og:image"[^>]*>'
```

카드 URL은 `/opengraph/card-base_hu_<해시>.png` 꼴이고, 내용이 바뀌면 해시가 바뀌므로 메신저 캐시 걱정이 없습니다.

첨부된 폰트는 `assets/` 에 있어 빌드에만 쓰이고 사이트로 배포되지는 않습니다. 저장소에 TTF 두 개(약 4MB)가 들어가는 건 감수했습니다.
{{< /step >}}

## 결과

44개 페이지(사례·분류·태그 포함)의 카드가 한 번에 바뀌었습니다. 새 페이지를 추가해도 제목·설명만 front matter 에 쓰면 카드가 따라옵니다.
`hugo.toml` 에 적혀 있었지만 실제로는 없던 `images/og-default.png` 도 이 김에 같은 베이스로 만들어 넣었습니다.

## 주의사항

- **폰트 라이선스를 확인하세요.** 시스템에 깔린 Apple SD Gothic Neo 같은 폰트는 저장소에 넣으면 안 됩니다. OFL(나눔고딕, Noto Sans KR, Pretendard)만 쓰세요.
- **Hugo `images.Text` 는 TTF만 읽습니다.** Noto Sans KR 의 `.otf`(CFF) 는 안 됩니다. 구글 폰트 저장소의 `.ttf` 를 받으세요.
- **줄 수 추정은 근사치입니다.** 영문이 많이 섞인 제목은 실제 폭이 좁아서 여백이 남고, 한글만 19자 넘게 이어지면 살짝 넘칠 수 있습니다. 카드 하나를 열어 보고 `$perLine` 을 조정하면 됩니다.
- **페이지 번들에 `*feature*`, `*cover*` 이미지가 있으면 그게 우선입니다.** 캡처 파일명에 `cover` 를 쓰면 의도치 않게 카드가 됩니다. 캡처는 `01-xxx.png` 식으로만 이름 붙이세요.
- 메신저는 카드를 캐시합니다. 옛 카드가 계속 보이면 URL 해시가 바뀌었는지부터 확인하고, 그래도 안 바뀌면 각 서비스의 캐시 초기화(카카오 개발자 콘솔, X Card Validator)를 씁니다.

## 응용

- 블로그 포스트마다 **시리즈명·회차**를 카드에 얹기 (front matter 값을 `images.Text` 로 한 줄 더)
- 사내 위키 링크 카드에 **보안 등급 배지** 표시
- 강의 자료 사이트: 챕터 번호를 큰 숫자로 넣어 목록에서 구분되게
- Pillow 베이스 카드에 카테고리별 색상 변형을 두고 파티셜에서 `.Params.categories` 로 골라 쓰기
