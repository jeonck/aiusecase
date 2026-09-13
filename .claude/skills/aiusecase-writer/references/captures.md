# Captures

## How to take them

| Situation | Method |
| --- | --- |
| Web app the agent can drive | `ego-browser` → `page.screenshot({ path })` (no permission, no window juggling) |
| Chrome window incl. side panel (Ask Gemini) | AppleScript bounds + `screencapture -x -R x,y,w,h` (needs Screen Recording for Claude app). Bring Chrome front first: `osascript -e 'tell application "Google Chrome" to activate'` |
| Chrome at a fixed width / URL | AppleScript `make new window`, `set bounds`, `set URL`, then screencapture; close the window after |
| Claude app itself (conversation, diff pane) | `open -a Claude; screencapture -x`; `mcp__ccd_view__show_pane` to open diff first |
| Terminal output | `scripts/render_terminal.py` — do not screenshot a terminal |
| Video frames | ego-browser: set `video.currentTime`, wait `seeked`, `page.screenshot`; canvas export is tainted |

Downloads do not fire in ego-browser; fetch via `page.evaluate` + API, or leave to the user.

## Mask before commit (`scripts/mask.py`)

Pixelate, never crop-only when the item is inside the useful area:

- email addresses (Sharing lines, git authors in Argo CD, account menus)
- avatars, "Hello, <name>" greetings, workspace/account names
- personal file names (Drive lists, finance sheets, school, interviews)
- browser tab titles, bookmark bar, sidebar session titles
- inbox counts, credit balances if the user did not ask to show them
- API keys, tokens, webhook URLs — never capture at all

Public, work-neutral content (nginx, kubectl output, this site) needs no masking.

## Check

Open the final PNG (Read tool) once. Look for a stray last letter of an email at the
edge of a mask — it happened.
