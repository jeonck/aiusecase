---
name: aiusecase-writer
description: This skill should be used when adding or editing a use case page in the aiusecase repository (aiusecases.metacog.co.kr, Hugo + Lotus Docs). It covers the page-bundle layout, front matter fields, step/prompt/screenshot shortcodes, capture masking rules, terminal-render images, the .md-in-bundle pitfall, and the commit message convention. Trigger on requests like "유스케이스 작성", "사례 추가", "이 작업을 사례로 남겨", or when editing files under content/docs/usecases/.
metadata:
  version: "1.0.0"
  date: "2026-09-12"
---

# aiusecase-writer

Write a use case the way the other 30 in this repo are written: something that was
**actually performed in this session**, with real captures, real numbers, and the
places where it broke. Never describe a hypothetical flow as if it ran.

## Workflow

1. **Scaffold** — `./scripts/new-usecase.sh <category> <slug> "<제목>"`.
   Categories: `automation` 업무 자동화 · `writing` 문서·글쓰기 · `coding` 코딩·개발 ·
   `data` 데이터·분석 · `media` 이미지·영상 · `research` 리서치·학습.
   Delete the generated `IMAGES.md` once real images are in place.
2. **Do the work first, capture as it happens.** Captures are evidence, not decoration.
   See `references/captures.md` for how to take them and what to mask.
3. **Write `index.md`** following `references/page-structure.md` (front matter, sections,
   shortcodes). Keep the literal prompt the user typed in the first `{{< prompt >}}`.
4. **Bundle files** the reader can download (YAML, scripts, DSL, pptx) next to `index.md`.
   Rename any `.md` bundle file to `.txt` — Hugo swallows `.md` inside a bundle as content
   and the link 404s.
5. **Build and check**: `hugo --quiet -d <scratch>/pub; echo $?` must print 0.
   A dangling `relref` to a page that does not exist yet fails the build — link only to
   pages that exist, or write the link after the target page is committed.
6. **Commit and push** — Korean subject, body says what was done and what was masked,
   then the `Co-Authored-By` line from the session. Push; the site deploys from `main`.

## Voice

- Korean, plain, present tense. Short paragraphs. No marketing adjectives.
- Numbers over adjectives: seconds, counts, PASS/FAIL, before/after.
- Failures stay in the text ("첫 시도 8/12", "404 → raw URL 로 우회"). They are the most
  reused part of a page.
- Each page ends with `## 결과` (a table when there are timings), `## 주의사항`
  (concrete, from what actually bit), `## 응용` (3–4 bullets).

## Scripts

- `scripts/render_terminal.py` — turn command/output lines into a dark terminal PNG
  (Menlo for ASCII, Nanum Gothic for Korean; `$` lines green, `//`/`==`/`#` orange,
  FAIL/error lines red). Use when the evidence is terminal output rather than a screen.
- `scripts/mask.py` — pixelate boxes in a PNG (`--box x0,y0,x1,y1` repeatable, `--crop`).
  Use before committing any capture that shows emails, names, file lists, avatars, tabs.

## References

- `references/page-structure.md` — front matter keys, section order, shortcode syntax.
- `references/captures.md` — capture methods (screencapture/AppleScript/ego-browser),
  masking checklist, image naming.
