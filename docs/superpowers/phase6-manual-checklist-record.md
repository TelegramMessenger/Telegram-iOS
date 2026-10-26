# Phase 6 gate item 3 — the 22-item manual checklist

**Build under test:** `bazel-bin/Telegram/Telegram.ipa`, built from `d636d9b808` (everything since is
docs-only — verified, the binary is current). **Device: iPhone 17 Pro K1** (`CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9`),
already booted. **Debug Settings ▸ "Force Text Field v2" must be ON** — without it the legacy composer is
under test and every row below is meaningless.

Mark each `PASS` / `FAIL` / `N/A`, and for a FAIL note what you saw. **A row you did not actually perform is
blank, not a pass** — this checklist is the only evidence for completion bullet C2, and the automated half
cannot see any of it.

## Install (per CLAUDE.md — note the guard before the destructive `rm`)

```sh
K1=CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9
BUNDLE=ph.telegra.Telegraph
STAGE=$(mktemp -d)
unzip -q -o bazel-bin/Telegram/Telegram.ipa -d "$STAGE"
SRC="$STAGE/Payload/Telegram.app"
DEST="$(xcrun simctl get_app_container "$K1" "$BUNDLE" app)"
[ -x "$SRC/Telegram" ] || { echo "no fresh bundle at SRC=$SRC — aborting"; exit 1; }
xcrun simctl terminate "$K1" "$BUNDLE" 2>/dev/null
rm -rf "$DEST" && cp -Rp "$SRC" "$DEST"
xcrun simctl launch "$K1" "$BUNDLE"
```

Install from the **`.ipa`**, never from `Telegram_archive-root/` — that directory goes stale silently after
an incremental build and its mtime is a fake `Jan 1 1980`, so staleness is undetectable by eye.

---

## Result so far — recorded honestly

**2026-08-24, user, on K1 with the freshly reinstalled build (framework md5 verified identical to the
`.ipa`): "All seems to work."**

**What that is:** a genuine SMOKE PASS. The composer opens, the editor behaves as it did before the branch,
and nothing is visibly broken. For a stage whose success criterion is *"there is no intentional behavior or
visual change"*, that is the expected and correct observation — and it is real evidence, not nothing.

**What that is NOT:** the 22 itemised rows. They are left blank below **deliberately**. Several of them
probe states a general look does not reach — a kana composition undone as one step (5), Backspace at the
start of a table's first cell (9), the shadow caret's ~14pt threshold (10), Undo-twice after a two-step
markdown paste (19), CPU after window detach (20). Marking those passed on the strength of an overall
impression would put false evidence under completion bullet C2, which is the one bullet nothing automated
can support.

**Gate disposition (updated 2026-08-24):** smoke pass **plus rows 3 and 20 explicitly performed and
passed** — the two rows carrying this branch's only intentional behaviour change and its most recently
fixed teardown path. The remaining 20 rows stay blank: not failures, simply not itemised. That is a judgement worth stating plainly rather than rounding up, because C2 rests on it
and stage 2 inherits it.

**The two rows most worth doing if the gate is to be closed literally:**
- **Item 3** — the only intentional behaviour change on the branch. Accepting an inline prediction used to
  eat characters past the ghost (`"country"` for `"countryBeta"`); this confirms the fix in a real keyboard.
- **Item 20** — focus the composer, push another screen, come back. Task 42 fixed a transient caret that
  survived teardown and was invisible to all 2350 UIKit tests; this and the Task-42 check below are the
  human eyes on that area.

---

## Autocorrect / prediction (1–4) — the area the differential oracle already found a defect in

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Type a sentence with an obvious typo, accept the suggestion — word replaces, caret lands after it, **one** Backspace reverts to the typed form | | |
| 2 | Reject via the "x" — typed form stays, underlined | | |
| 3 | Type a partial word so an inline prediction appears, tap it — completion commits, **no duplicated word** | **PASS** | user, 2026-08-24, on the reinstalled K1 build — the human confirmation of `d636d9b808` |
| 4 | With a prediction showing, move the caret by tap — ghost disappears and is **not** committed | | |

> **Item 3 is the one to watch.** The oracle found and we fixed a bug where accepting a prediction ate
> characters past the ghost (`"country"` for `"countryBeta"`). This row is the human confirmation of
> `d636d9b808`.

## IME composition (5–6)

| # | Check | Result | Notes |
|---|---|---|---|
| 5 | Japanese kana: compose, watch the marked underline, commit from the candidate bar; **Undo once reverts the whole composition as one step** | | |
| 6 | Pinyin: interrupt mid-composition by tapping elsewhere — composition **commits**, does not vanish | | |

## Structural editing (7–9)

| # | Check | Result | Notes |
|---|---|---|---|
| 7 | In a blockquote, Return twice — the second exits into a body paragraph | | |
| 8 | At the start of paragraph 2, Backspace — paragraphs merge, caret at the join | | |
| 9 | At the start of a table's first cell, Backspace — the documented behaviour, **not a crash** | | |

## Selection, loupe, handles (10–14)

| # | Check | Result | Notes |
|---|---|---|---|
| 10 | Long-press → loupe, drag — magnifier grows from the caret; grey shadow caret appears only past ~14pt separation | | |
| 11 | Drag a handle to the screen edge — auto-scrolls, the **dragged** endpoint extends, anchor stays put | | |
| 12 | Select right-to-left, Copy, paste elsewhere — pasted text is the **logical** selection | | |
| 13 | Type Hebrew into an empty paragraph — caret starts on the **right** before the first keystroke | | |
| 14 | Wide table: scroll a row horizontally, tap in a cell — caret lands under the finger, handles follow the scrolled content | | |

## Floating cursor (15–16) — Task 42 territory

| # | Check | Result | Notes |
|---|---|---|---|
| 15 | Long-press spacebar and drag — caret moves; UIKit's range pushes do **not** turn it into a selection; release leaves a caret | | |
| 16 | Floating-cursor drag to the top/bottom edge — auto-scrolls; reaching the document start does not clamp oddly | | |

## Spelling (17–18)

| # | Check | Result | Notes |
|---|---|---|---|
| 17 | Misspell a word, wait for the red underline, tap, pick a guess; **Undo once restores the misspelling** | | |
| 18 | Toggle spellchecking off in the host — underlines clear immediately | | |

## Paste, lifecycle, scale (19–22)

| # | Check | Result | Notes |
|---|---|---|---|
| 19 | Paste a large markdown fragment — lands as structure; **Undo twice** returns to pre-paste (the two-step paste is deliberate) | | |
| 20 | Focus the composer, push another screen (window detach) — no crash, **no runaway CPU** (the `CADisplayLink`s must stop); return and the caret still works | **PASS** | user, 2026-08-24 — the human eyes on Task 42's teardown area |
| 21 | `Select All` in a ~500-block document — wash complete on screen, scrolling smooth, memory does not spike | | |
| 22 | Rotate with an active selection — handles reposition, no duplicate chrome | | |

---

## Three checks owed separately (not part of the 22, same session worth doing)

| Check | Origin | Result | Notes |
|---|---|---|---|
| Hold a key to autorepeat in a long document; compare typing latency against pre-Phase-5 | Task 40b Step 3c | | |
| A real IME composition surviving **rotation / keyboard resize** | Task 41 | | |
| Floating cursor, then tear the editor down **mid-gesture** — no bright caret left on screen | Task 42 | | |

> Item 20 and the Task-42 check overlap deliberately: Task 42 fixed a transient caret that survived
> teardown, and it was invisible to all 2350 UIKit tests until a test was written for it.
