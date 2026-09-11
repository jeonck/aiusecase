# AI Usecases

실제로 써본 AI 활용 사례를 **캡처 이미지 + 단계별 사용법**으로 남기고, **카테고리로 분류**해 축적하는 지식 사이트.

- 사이트: <https://aiusecases.metacog.co.kr>
- 테마: [Lotus Docs](https://lotusdocs.dev) (Hugo Module)
- 배포: `main` 브랜치 푸시 → GitHub Actions → GitHub Pages

## 로컬에서 띄우기

Hugo **extended** 0.140 이상과 Go 1.21 이상이 필요합니다(테마를 Hugo Module 로 가져오기 때문입니다).

```bash
hugo server -D          # http://localhost:1313
```

## 새 유스케이스 추가하기

```bash
./scripts/new-usecase.sh <카테고리폴더> <영문-슬러그> "<한글 제목>"
# 예)
./scripts/new-usecase.sh automation slack-daily-digest "슬랙 채널 하루치 요약하기"
```

생성된 폴더에 캡처 PNG를 넣고 `index.md` 를 채운 뒤 푸시하면 끝입니다.
자세한 규칙은 [유스케이스 추가하기](https://aiusecases.metacog.co.kr/docs/guide/contribute/) 문서를 보세요.

### 카테고리 폴더

| 폴더 | 카테고리 |
| --- | --- |
| `automation` | 업무 자동화 |
| `writing` | 문서·글쓰기 |
| `coding` | 코딩·개발 |
| `data` | 데이터·분석 |
| `media` | 이미지·영상 |
| `research` | 리서치·학습 |

## 디렉터리 구조

```
content/
  docs/
    guide/                     이용 가이드 · 기여 방법 · 템플릿
    usecases/<카테고리>/<슬러그>/
        index.md               본문
        01-*.png               캡처 이미지 (같은 폴더에 두면 바로 참조됨)
  categories/ tools/ tags/ difficulty/   분류 인덱스 페이지
layouts/
  docs/                        단건·목록·분류 페이지 오버라이드
  shortcodes/                  step · screenshot · prompt
  partials/kb/                 요약 카드 · 카드 · 스크린샷 렌더러
assets/kb/kb.css               지식 저장소 전용 스타일
scripts/new-usecase.sh         새 사례 생성기
```

## 본문에서 쓰는 숏코드

| 숏코드 | 예시 |
| --- | --- |
| `step` | `{{< step title="메일 열기" image="01-open.png" caption="설명" >}}…{{< /step >}}` |
| `screenshot` | `{{< screenshot src="flow.svg" alt="흐름" caption="설명" >}}` |
| `prompt` | `{{< prompt title="입력 프롬프트" >}}실제 프롬프트{{< /prompt >}}` |
| `alert` | `{{< alert context="warning" >}}주의 내용{{< /alert >}}` |

`step` 은 페이지 안에서 번호가 1부터 자동으로 매겨집니다. 이미지 파일이 아직 없으면 "캡처 이미지 자리" 안내 박스가 대신 표시됩니다.

## 커스텀 도메인

`static/CNAME` 에 `aiusecases.metacog.co.kr` 가 들어 있어 Pages 배포 시 자동 적용됩니다.
GitHub 저장소 **Settings → Pages** 에서 Source 를 **GitHub Actions** 로 설정해야 워크플로가 배포할 수 있습니다.

## 캡처 올리기 전 확인

이메일 주소, 실명, 사내 시스템 주소, 고객사명, API 키·토큰은 가리고 올립니다. 공개 사이트이고, 커밋 히스토리에 남습니다.
