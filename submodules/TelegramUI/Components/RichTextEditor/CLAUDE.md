# RichTextEditor — project guide

A from-scratch **WYSIWYG rich-text editor for iOS** (UIKit; TextKit 2 on iOS 16+, TextKit 1 on iOS 13–15;
floor **iOS 13**) with images
(captions), lists, tables, links, inline custom emoji, and Telegram-style spoilers. The **defining
requirement** is **continuous selection across the whole document, including partial selection
*through* table cells** — which (per verified spike research) is only achievable with a **custom
`UITextInput` view owning one global position model**, NOT nested text views.

## Location & status in the monorepo

Moved in-tree **2026-06-09** to `submodules/TelegramUI/Components/RichTextEditor`; the standalone
`~/Documents/RichTextEditor` repo is the **pre-move archive** — it still holds the full per-phase
spec/plan/spike/handoff history and the project's original git log, none of which migrated in-tree.
Development continues here via **SwiftPM** exactly as before.

**Now wired into the app.** `ChatTextInputPanelNode` depends on `:RichTextEditorUIKit`, so both Bazel
targets — `//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore` and
`:RichTextEditorUIKit` — **fully compile and run down to iOS 13** as part of the app build.

**Two InputDec source trees live alongside the editor's own code, and THIS REPO OWNS BOTH
(2026-09-15).** `Sources/RichTextInputDecObjC/` is the private-UIKit behavior kernel and
`Sources/RichTextInputDecUpstream/` is the text engine. Both came from the separate
`~/Documents/InputDec`; that repo lost its `.git` and is now an archive, so these copies are the
live code and are edited here like any other source — no re-sync, no re-port, no hash list. The
retired machinery (`PORTED-FILES*.sha256`, `Scripts/verify-ported-files.sh`) is deleted; each tree's
own `PROVENANCE.md` / `VENDOR.md` is now an ORIGIN record and still worth reading before touching
anything, because the deviations they list are facts about the code. See the root `CLAUDE.md`'s
"The vendored InputDec engine and kernel" for the compile-floor mechanism, the
certified-build-vs-selection-floor decision, what remains generated-and-pinned, and the
exception-guard rule (`TGRichTextInputDecPerform` / `TGRichTextInputDecPerformReturningObject` are
the only sanctioned way for Swift to call into the kernel — it still raises `NSException` on a
contract mismatch). The design plan,
`docs/superpowers/plans/2026-08-16-inputdec-backend-introduction.md`, left the tree on 2026-10-12 and
is in git history.

**What is NOT here yet is the engine's PROOF**, and it is the reason `~/Documents/InputDec` must not
be deleted: 1,078 unit and 196 UI test cases, the stock-`UITextView` oracle host they compare
against, and their fixtures still live only there. Two consequences to hold in mind until they are
imported. The engine's behaviour has no test in this repo beyond what the editor's own suites happen
to exercise — so a change to `Sources/RichTextInputDecUpstream/` is, today, less covered than a
change to the editor above it, and deserves a host test written for it. And `IDProjectSmokeTests`,
which greps the engine's source and fails on a mention of `UITextView` or a private canvas
class/selector even inside a comment, is not running here: that rule still holds for this code, and
nothing enforces it.

**Dual layout-engine back-port (2026-06-17).** TextKit was quarantined behind a one-method-per-call seam,
`protocol BlockLayoutEngine` (`Layout/BlockLayoutEngine.swift`), so the layout engine is swappable:
`BlockLayout` (TextKit 2, `@available(iOS 16.0, *)`) on iOS 16+, and **`BlockLayoutTK1`** (TextKit 1, iOS 7+,
ungated) on iOS 13–15. `makeBlockLayout(...)` picks TK2 on iOS 16+ / TK1 below; the runtime debug toggle
`BlockLayoutBackend.forceTextKit1` forces TK1 on any OS for testing the back-port (currently `#if DEBUG &&
false` → **off** even in debug, so the running app uses TK2 on iOS 16+; flip the `&& false` to opt in). The
system edit menu likewise falls back from `UIEditMenuInteraction` (iOS 16+) to **`UIMenuController`** (iOS
13–15) — see `DocumentCanvasView+EditMenu` (shared responder actions; custom items become flat `UIMenuItem`s).

**InstantPage V2 layout parity (2026-08-14).** The editor lays text out **pixel-identically to the
InstantPage V2 renderer**, so what an author types reads like the message the recipient sees. This
REPLACED the earlier `lineHeightMultiple` + glyph-centering model described here before; that model
cannot express V2's geometry at all (see "Why not a multiple" below). Both editor hosts opt in.

**The contract.** `RichTextRenderMetrics` (`Mapping/RichTextRenderMetrics.swift`) is a host-supplied
value set — per-style `(family, size, weight, lineSpacingFactor)` plus the block-rhythm scalars and
`edgeSpacingReduction` — and it **owns V2's line formulas as functions**:

```
L(F)      = floor(F.ascender + F.descender)     // V2's "fontLineHeight": a REDUCED box, not lineHeight
S(F,f)    = floor(L · f)                        // V2's "fontLineSpacing"; f scales L, NOT the point size
pitch     = L + S                               // baseline-to-baseline advance; always integral
firstBaseline(F) = F.ascender
textHeight(F,f,n) = ceil(A + |D|) + (n−1)·pitch
```

`StyleSheet` is a projection of it (`metrics`), so the heading ladder is V2's **22 / 20 / 18 / 17 / 16 /
15 serif medium** (retuned 2026-08-17 from 24 / 22 / 20 / 19 / 18 / 17; see the note under
`InstantPageTheme.headingTextAttributes` on why H1/H2 no longer borrow the `header` / `subheader`
categories). `RichTextRenderMetrics.default` is the chat-message look; hosts set
`RichTextEditorView.renderMetrics`. This retired `TextLayoutMetrics`/`textLayoutMetrics`,
`blockVerticalInset`, and `StyleSheet.bodyBaseSize` (now `metrics.body.size`;
`AttributedStringMapper.withBodyBaseSize` → `withBodyFontSize`).

**The `ceil` is load-bearing.** `layoutTextItem` returns `ceil(height)` because callers stack blocks by
adding sizes to a running origin, so one fractional box makes every later origin fractional. Omitting it
left every editor block ~0.7pt short and the error accumulated down the document — caught by the parity
test, not by inspection. The pitch is integral by construction, which is *why* the per-paragraph
correction stays independent of the line count.

**Why not a multiple.** `lineHeightMultiple` cannot express this: at the Instant Page reader's heading
factor (0.685) V2 wants a pitch TIGHTER than the font's natural line height, and
`NSParagraphStyle.lineSpacing` cannot go negative. So `StyleSheet.paragraphStyle` pins
`minimumLineHeight == maximumLineHeight == pitch` — one mechanism for both directions. An explicit
model-level `lineHeightMultiple` is user content and takes over instead; the two must never combine.

**Baseline placement is MEASURED, not derived.** `BlockLayoutEngine.baselineDelta` (a shared extension,
so the two engines cannot drift — each supplies only `rawFirstBaselineFromTop`) reads the baseline
TextKit actually produced and corrects it to `F.ascender`, V2's position. TextKit's placement inside a
pinned box is undocumented, so an analytic formula would silently drift across OS versions. Applied at
glyph-draw / `attachmentBox` / `firstLineBaselineFromTop`; caret/selection rects keep the full box.
**Not** the `baselineOffset` attribute — that is a real `CharacterAttributes` field (sub/superscript)
and would round-trip into the model. (The TK1 `NSLayoutManagerDelegate.shouldSetLineFragmentRect…`
baseline hook is **NOT invoked** under the TextKit-2-backed `NSLayoutManager` on modern iOS — verified
at runtime — so TK1 shifts manually too.) **The empty-line fallbacks must mirror it:** an empty
paragraph lays out no fragment, so `BlockBox.listMarkerBaselineFromTop` and `placeholderDraw` compute
the baseline analytically, and under this model that is simply `firstBaselineFromTop` — no shift.
Guarded by `LineHeightCenteringTests`, `ListRenderingTests`, `CanvasDecorationsTests`.

**Every height consumer goes through `correctedBoundingHeight`, never `boundingHeight`.** It lives on
the engine seam precisely so no call site can forget: the correction was first applied at one site
(`BlockBox`) and **four** other height paths — the collapsed-quote preview, the pull quote, the media
caption, code blocks — silently disagreed, which two existing height-parity tests caught.

**Font families are load-bearing, not stylistic.** `FontResolver.font(spec:bold:italic:family:)` mirrors
`InstantPageTextStyleStack`: **Georgia** for regular-weight serif, the **system serif design** (New York)
for weighted serif — bold there is a WEIGHT, not a symbolic trait — **Menlo** for monospace, system sans
otherwise. Every line formula is a function of `ascender`/`descender`, so resolving New York where the
renderer resolves Georgia shifts every line while type-checking perfectly.

**Block rhythm mirrors `spacingBetweenBlocks`.** `richTextSpacingBetweenBlocks`
(`Canvas/BlockSpacing.swift`) is a transcription over `RichTextBlockSpacingKind`, the InstantPage cases
the editor can produce; **rule ORDER is load-bearing** (several arms would otherwise both match). Two
body paragraphs sit **1pt** apart, a heading takes both paddings, two bare images butt at 1pt.
`CanvasBlock.spacingKind` has **no default implementation** on purpose — a conservative default would
compile everywhere while silently giving a new block type the wrong rhythm. Adjacent list items collapse
into the single virtual `.list` block the renderer sees, mirroring `buildListBlocks`; the shared
`ParagraphBlock.standaloneFormulaLatex` predicate lives in Core so the classification cannot drift from
what `InstantPageBuilder` emits.

**GAP OWNERSHIP IS LOAD-BEARING.** V2's gap is ONE quantity between two blocks, not two facing insets,
and it is carried by whichever neighbour can own it — preferring the lower, falling back to the
paragraph above. A framed atom (table / code / quote / details) fills its own frame and has no external
inset, so giving it the gap leaves **unowned dead space**; the arrow-key escape probe in `+Navigation`
(`owner.frame.minY − step/2`) then lands in nothing and **the caret cannot leave a table**
(`CanvasTableNavTests` caught exactly this). Only where no paragraph can own it — a non-`BlockBox` at a
sequence edge, or two such neighbours — is the gap laid down as bare space. Side effect to know: a tap in
a gap resolves to the block below.

**A BARE GAP BELONGS TO NO BOX FRAME, so no height may be summed from box heights.** `BlockStack` owns the
ownership rule in exactly one place — `bareGapAbove(_:_:)` / `bareTrailingGap(_:)` — read by BOTH `layout`
and the live `currentHeight`, because the two silently disagreed: `DocumentCanvasView.intrinsicContentSize`
(what `performLayout` feeds to `scrollView.contentSize`) summed box heights and so under-reported the
laid-out extent by **4pt per bare gap, accumulating** (36pt for five non-paragraph blocks). The trailing
blocks then sat outside the scrollable range — unreachable, overlapping the host's bottom inset band. A
paragraphs-only document has no bare gaps, which is why it stayed hidden; the stateless
`measuredHeight`/`measuredContentHeight` path was correct all along, so measure and commit disagreed.
Guarded by the three `RichTextEditorViewTests.test_document*_scrollContentCoversEveryBlock` cases, which
assert the scroll content EQUALS `root.contentHeight` + margins. Related: every height path calls
`applyRootSpacingConfig()` rather than inheriting the last one's rhythm state — `intrinsicContentSize` is
read BEFORE the layout pass, so it cannot assume `layoutContent` ran first.

**Scope.** Only the document's TOP-LEVEL sequence is on V2's rhythm (`BlockStack.spacingModel ==
.instantPageV2`). Stacks nested in a container — table cells, details, block-quote children — keep the
pre-parity facing-inset model verbatim (`.containerInterior`), and author-line placement in both quote
types deliberately measures the RAW line box. Those interiors have no V2 reference yet.

**Deferred:** container interiors (block quote incl. V2's `quoteScale` 15/17 content scaling, pull
quote, code-block insets), list marker geometry, table cell insets, media captions/credits, details
chrome — and inline-attachment line inflation (V2 inflates `lineAscent` for formulas/buttons and adds
`extraDescent` for tall inline images; a pinned `maximumLineHeight` clips that, so plain text and custom
emoji are exact while those are not).

**Verification.** `//submodules/InstantPageUI:InstantPageUITests` holds both parity layers:
`RichTextV2MetricsParityTests` calls `layoutTextItem` and `spacingBetweenBlocks` directly and pins the
formulas, the resolved font faces, and the **whole** pairwise gap table plus both edges (and pins
`RichTextRenderMetrics.default` against the adapted theme — the composer depends on that default because
it cannot import `InstantPageUI`, which would be a cycle); `RichTextV2FrameParityTests` pins the
composition via the DEBUG-only `RichTextEditorView.layoutSnapshot()`. Line-break agreement between
TextKit and `CTTypesetterSuggestLineBreak` was measured at **50/50** over a 10-string corpus × 5 widths
(CJK, RTL, hyphens, trailing spaces, emoji), which is why the wrapped-text parity assertions are
unconditional. **Runtime-checked in the chat composer**, which is what surfaced the outer-padding
problem the `edgeSpacingReduction` trim above fixes — a reminder that measured parity against the
renderer's functions does not by itself mean a host's field reads right. **Still unverified on screen:**
the composer-vs-sent-bubble and article-editor-vs-sent-message side-by-side comparisons. If you have the
`mcp__XcodeBuildMCP__*` tools, those are the two screenshots worth taking; a code block still will not
match exactly (the editor draws `monospacedSystemFont` where the renderer uses Menlo, and nothing reads
`metrics.codeBlock` yet) — though its GEOMETRY is now shared, via `metrics.code` (see below).

So **the UIKit target is gated `@available(iOS 13.0, *)`** (`RichTextEditorCore` is pure-Foundation,
always-available), with only genuine higher-OS APIs kept at their real floor: the TK2 `BlockLayout` type + the
4 `UIEditMenuInteraction` touch-points at **iOS 16**; the magnifier loupe (`UITextLoupeSession`) +
`inlinePredictionType` at **iOS 17**; Translate at **17.4**; `isEditable` at **18**. **TK1 trade-offs on iOS
13–15** (deliberate): no spoiler text-hiding (UIKit `NSLayoutManager` has no rendering/temporary-attribute
analog), no loupe, no inline predictions — everything else (editing, tables, lists, links, emoji, selection,
IME, edit menu) works. Full SwiftPM suite is green on both engines (TK1 via the DEBUG `forceTextKit1`). The
app-side consumers (`RichTextEditorChatInputNode`, `RichTextAttachmentScreen` + its helpers,
`StandaloneInstantPageImageView`) are also lowered to iOS 13; the editor is the native chat-composer backend,
native from the start with `ios_rich_input_mode = 1` or the `useInputDecEngine` experimental flag (which also selects
the engine editor; "Force Text Field v2", `forceNewTextInput`, was removed 2026-10-15). By default the composer is a
dual-field switch — the legacy input, latching to the native editor only when content becomes legacy-non-representable
(`ChatTextInputPanelNode`; `ios_rich_input_mode` server flag). (Inverted the earlier default + `forceLegacyTextInput` opt-out.)

**Spoiler-texture resource access is build-system-split (via `#if SWIFT_PACKAGE`).** `SpoilerDustView`
resolves the particle texture two ways: under **SwiftPM** it uses `UIImage(named: "TextSpeckle", in:
.module, …)` (the generated `.module` accessor); under **Bazel** it uses the app's **`AppBundle`** —
`UIImage(bundleImageName: "Components/TextSpeckle")`, with `//submodules/AppBundle` in the UIKit
target's Bazel `deps` — because `.module` only exists under SwiftPM (it failed the Bazel compile).
`import AppBundle` is likewise gated `#if !SWIFT_PACKAGE`. So **both build systems compile**: the
Bazel/app build *and* the SwiftPM workflow (`swift test`, `Scripts/iostest.sh`, the `Demo/` app). When
editing this resource path, keep both `#if` branches in sync.

## Build & test (SwiftPM, not Bazel) — all from this directory

- **Core (UIKit-free) tests, fast:** `swift test` (runs on macOS).
- **UIKit tests, iOS simulator:** `Scripts/iostest.sh [Class/Test filter]` — wraps
  `xcodebuild test -scheme RichTextEditor-Package -destination 'platform=iOS Simulator,id=<udid>'`.
  Defaults to the dedicated **iPhone 18 Pro K1** (`03A7DA9C-1832-49B8-9858-2F54F2FB5A04`) BY UDID — a bare `name=` is ambiguous
  across the K-sims; override with `DEVICE=<udid>`. The K-sims were re-created by the Xcode 27
  update (2026-09-15), which removed every simulator, so these UDIDs are new.
- **Demo app (visual check):** `cd Demo && xcodegen generate && xcodebuild …` then
  `xcrun simctl install/launch/io screenshot`. The generated `RichTextEditorDemo.xcodeproj` is gitignored.

All UIKit sources/tests are wrapped in `#if canImport(UIKit) … #endif` so `swift test` keeps compiling
Core on macOS while the UIKit suite runs only on the simulator. The suite is ~690 tests (Core + UIKit);
the exact number is one `grep -r 'func test' Tests` away — it isn't tracked here.

## Architecture & conventions

**Two SwiftPM targets:**
- `RichTextEditorCore` — **no UIKit**: the model (`Document`/`Block`/`TextRun`/`CharacterAttributes`/…),
  JSON (`DocumentCodec`) and `.rtdoc`-package (`DocumentPackage`) serialization, the ProseMirror-style
  **global position model** (`DocumentTree` + `PositionResolver`), the selection model (`RTSelection`),
  `TableMap`, and list numbering (`ListNumbering`). Core stays UIKit-free so it's shareable and
  `swift test`-able on macOS.
- `RichTextEditorUIKit` — the views (depends on Core).

**Public surface.** `RichTextEditorView` is the **only public** type (the façade), with the small value type
`RichTextEditorPlaceholders` (a config struct, below). `DocumentCanvasView` (the multi-block editing surface)
and everything else are **internal** — keeping them internal lets their `UITextInput` witnesses stay internal
(a public type conforming to public `UITextInput` would force every witness `public`).

**Compact-host (chat-composer) configuration knobs (added 2026-06-16, `RichTextEditorView+ComposerHost.swift`).**
The editor's defaults assume a full-page document; a compact host (the chat composer,
`ChatRichTextEditorComposer`) tunes these via the façade. **Every knob defaults to the document-editor
behavior, so the attachment screen / Demo / SwiftPM tests are unchanged.** The composer sets each in `didLoad`
*before* seeding the document so the first layout picks them up:
- `contentPageMargin` (default `CanvasMetrics.pageMargin` = 16) — the built-in horizontal page margin on each
  side (`DocumentCanvasView.pageMargin`, used by `contentLeftPad`/`contentRightPad`; media bleed is governed
  separately by the `mediaBlockStyle` knob). Composer → 0.
- `minimumContentHeight` (default 44) — the floor `performLayout` applies to the returned content height.
  Composer → 0 (the height hugs the text; the host owns the min field height).
- `placeholders` (`RichTextEditorPlaceholders`, default = "Type something…" + the two list hints) — the empty-
  paragraph placeholder strings, stamped onto top-level boxes in `stampListMarkers`; an empty string for a case
  draws nothing. Composer → all "".
- `canvasBackgroundColor` (default `.systemBackground`, the document "page") — the canvas background; the
  scroll view + `BlockBackingView`s are already clear. Composer → `nil` (transparent over the input panel).
- `tapBelowAddsTrailingParagraph` (default `true`) — whether a tap in the empty area below the document's last
  block appends a new empty body paragraph there (the `point.y > boxes.last.frame.maxY` affordance in
  `+Interaction.swift`; see the quote-escape note below). The full-page article editor keeps it on; the compact
  composer has no "empty area below the content" to grow into, so **Composer → `false`** (a tap there just places
  the caret in the trailing paragraph). Unlike the other knobs the composer sets this in `didLoad` purely for
  behavior — it doesn't affect layout, so its timing vs. the document seed is immaterial.
- `renderMetrics` (`RichTextRenderMetrics`, default `.default` = the chat-message look) — the whole
  font + line-geometry + block-rhythm contract; see the V2 layout-parity note above. Applied via
  `applyRenderMetrics` → mapper rebuild + reload (mirrors `quoteStyle`). **BOTH hosts pass V2 metrics**:
  the composer assigns `RichTextRenderMetrics.default` (it cannot import `InstantPageUI` — that edge is a
  cycle, and the default is pinned equal to the adapted theme by test), the article editor calls
  `InstantPageTheme.chatMessageRenderMetrics()`. This replaced `textLayoutMetrics`, whose per-style
  `lineHeightMultiple` + paragraph-spacing model is gone: V2 keeps ALL inter-block spacing in the rhythm
  table and its strings carry none, so a residual per-style spacing would double-count every gap. It also
  replaced `blockVerticalInset` — the rhythm is the contract's now, and a host that needs tighter outer
  padding trims `edgeSpacingReduction` (V2's own parameter; the bubble passes 1.0) rather than
  reintroducing a compact knob. **The composer does exactly that, trimming 6 (`composerEdgeSpacingReduction`).**
  V2 gives a top-level paragraph `blockVerticalPadding + 2` = 6pt at each SEQUENCE EDGE — not to be
  confused with the 1pt inter-paragraph gap — so an untrimmed one-line field measured 33pt against the
  text's own 21pt, which read as too much padding in the input panel. In a page that padding IS the page
  margin; in the composer the panel already owns the padding around the field, which is why the
  pre-parity config zeroed the block inset for the same reason. The trim touches only the edges, so the
  interior rhythm stays V2-exact. An explicit per-paragraph `lineHeightMultiple` in the model still
  overrides the pinned box.
- `mediaBlockStyle` (`MediaBlockStyle`, default `.default` = `horizontalBleed` 16 == `CanvasMetrics.pageMargin`,
  the document edge-to-edge look) — how far a top-level media block bleeds beyond the text content strip on each
  side; applied via `applyMediaBlockStyle` (pure geometry, no mapper rebuild) and read at `MediaBlockBox` creation
  (`setBlocks`/`insertMedia`); table-cell media always passes `horizontalBleed: 0`. Composer →
  `MediaBlockStyle(horizontalBleed: 0)` so media insets like the text paragraphs.

Two host-side runtime contracts the composer had to honor (apply to any non-attachment host): **seed an initial
`document`** (the canvas starts with ZERO blocks; nothing renders/edits until the `document` setter runs), and
**re-run `update(...)` in response to `onChange`** (the view is parent-driven and does not self-layout on a
content change — without this, typed text is never laid out).

**Keyboard input language (added 2026-06-26).** `RichTextEditorView` exposes
`inputPrimaryLanguage` (read the live keyboard language back), `initialInputPrimaryLanguage`
(seed the language the keyboard opens in next focus), and `resetInputPrimaryLanguage()`,
forwarding to a one-time `textInputMode` override on `DocumentCanvasView` (the actual first
responder) — a verbatim port of the legacy `ChatInputTextView` mechanism so the chat composer
repopulates `interfaceState.inputLanguage` (emoji-keyword search + draft persistence).
LOAD-BEARING: the override is single-shot (first `textInputMode` query consumes the
pre-selection); UIKit queries it on `becomeFirstResponder` before any host read-back, so do not
add a separate non-side-effecting read path.

**Dynamic theme (added 2026-06-17, `Theme/RichTextEditorTheme.swift`).** `RichTextEditorView.theme:
RichTextEditorTheme` is a host-settable struct of eleven UIColors; assigning it updates the mapper, pushes the
accent to the caret/selection-handles/blockquote views, reloads — **only when the view is sized (`bounds.width >
0`)** — so boxes rebuild with the themed mapper, and redraws. **`.default` reproduces the editor's prior hardcoded colors exactly, so the look is unchanged until a
host sets a theme.** Host wiring: the **chat composer** wires it — `ChatTextInputPanelNode` maps
`PresentationTheme` → `ChatRichTextThemeColors` (a `UIColor`-only seam type in `ChatInputTextNode`) and pushes
it via `ChatRichTextInputNode.applyRichTextTheme`, which `RichTextEditorChatInputNode` maps to this `theme`.
`RichTextAttachmentScreen` now also wires a theme. What each color drives:
- `primaryText` (default `.black`) — default foreground for runs with no explicit color.
- `secondaryText` (default `.black`) — default foreground for `.caption`-style runs.
- `placeholder` (default `.placeholderText`) — empty-paragraph, marked-text ghost, and media placeholder text.
- `accent` (default `.link`) — link text, the blockquote bar + fill, the caret, the selection visuals
  (handles via a pushed `accentColor`; the body/cell selection *wash* reads `mapper.theme.accent` live),
  the table-control resize knobs, the selection-outline stroke, and the active-handle pill fill.
- `tableBorder` (default the prior dynamic grid color) / `tableHeaderBackground` (default `white 0.5/0.1`) — the
  table grid stroke and header-row fill (the former `TableBlockBox.gridColor`/`headerRowBackground` statics).
- `codeBackground` (default prior dynamic color) — the code band's plain fill, painted by `CodeBlockBox`
  itself. Both hosts set it to the same value as `tableHeaderBackground`, so a code block reads as a
  highlighted table row. (Declared but unread until 2026-08-18.)
- `listMarker` (default `.label`) — list bullet/number marker color.
- `inlineCodeBackground` (default `.systemGray5`) — inline-code run background pill.
- `markedTextUnderline` (default `.label`) — IME marked-text (composing) underline.
- `spoilerDust` (default `.secondaryLabel`) — spoiler particle ("dust") tint.

**Apply the theme BEFORE seeding the `document` (host-ordering invariant).** The `document` setter builds each
block's attributed string with the mapper's *current* theme (baking in the foreground color), and — per above —
the `theme` setter re-maps already-built boxes only when `bounds.width > 0`. So a host that assigns `theme`
*after* `document` while the view is still unsized (its frame set later in the same layout pass) leaves
pre-existing text in the `.default` foreground; an empty document is unaffected (later typed text uses the
by-then-themed mapper). Both hosts therefore theme before seeding — the composer in `didLoad`,
`RichTextAttachmentScreen` in its `if component == nil` init block (before `editor.document = …`). (Regressed
once: pre-existing text rendered black in dark mode, fixed 2026-06-26.)

**Round-trip invariant (load-bearing):** theme colors are applied at render time only and **never persist into the
`Document`**. `AttributedStringMapper` is symmetric — the forward pass injects the per-style default
(`secondaryText` for `.caption`, else `primaryText`) for un-colored runs; the reverse (`characterAttributes(from:
style:)` / `runs(from:style:)`) strips a foreground equal to that per-style default back to `nil`. Every
reverse-mapper caller MUST pass the run's paragraph style (`BlockBox` → its style, `MediaBlockBox` captions →
`.caption`, `+Editing` → the start box's style; `+State` reads only format flags, so its `.body` default is fine)
— a wrong style compares against the wrong default and pollutes the model. An explicit user color exactly equal to
the style default is also stripped (visually identical, re-themable). Known limitation: removing a link inside
a `.caption` run under a theme where `primaryText != secondaryText` leaves an explicit foreground (latent; see
`removeLink`).

**Host input hooks (added 2026-06-12 for the emoji keyboard).** The façade exposes three generic, UIKit-only
input hooks so a consumer can drive a custom input panel: `insertText(_:)` (plain text at the caret, one undo
step), `deleteBackward()`, and `customInputView: UIView?` (forwarded to the canvas's `inputView` +
`reloadInputViews()` — set an `EmptyInputView` to suppress the system keyboard *while the canvas stays first
responder*, so the caret keeps rendering under a separate panel). The actual Telegram **emoji keyboard** is
wired **consumer-side** in `RichTextAttachmentScreen` (`RichTextEmojiKeyboardController`, hosting
`ChatEntityKeyboardInputNode`) — the package itself stays free of `AccountContext`/TelegramUI. Custom emoji
insert via the existing `insertEmoji(id:altText:)` (id = the Telegram fileId string) + a host
`registerEmojiViewProvider` that renders an `InlineStickerItemLayer`.

**Emoji-view template tinting (`RichTextEmojiView`, added 2026-07-17).** `registerEmojiViewProvider` returns a
`(UIView & RichTextEmojiView)?` (not a bare `UIView?`) — `RichTextEmojiView` (in `DocumentCanvasView.swift`,
alongside `RichTextChecklistMarkerView`) requires one settable `var dynamicColor: UIColor?`. The editor keeps it
synced to the current text color (`mapper.theme.primaryText`) on **every** `syncEmojiViews` pass (cheap — the
host setter no-ops on an unchanged value; self-healing across theme changes, since a theme reload relays out), so
a Telegram **custom *template* emoji** (single-color, `file.isCustomTemplateEmoji`) mask-tints to the surrounding
text — matching the legacy input. Both hosts conform their view: the **chat composer** builds an
`EmojiTextAttachmentView` (which gained a `dynamicColor` property forwarding to its `InlineStickerItemLayer`;
the `RichTextEmojiView` conformance is declared retroactively in `ChatTextInputPanelNode`, the one module importing
both — so `EmojiTextAttachmentView` stays free of a rich-text-editor dep). The `ChatRichTextInputNode` protocol
seam that carries the provider stays `-> UIView?` (unchanged; the legacy backend shares it), so
`RichTextEditorChatInputNode`'s registration closure `as?`-casts the returned view to the conforming type (the
runtime finds the panel-module conformance in the linked app). The **article editor**
(`RichTextEmojiKeyboardController.customEmojiView`) returns a small `RichTextInlineEmojiView` wrapper forwarding
`dynamicColor` to its `InlineStickerItemLayer`. A non-template (full-color) emoji ignores `dynamicColor`.

**Parent-driven layout + state query (added 2026-06-12, branch `feature/richtext-message-serialization`).**
The façade is now driven by its host rather than self-laying-out:
- `update(size:insets:) -> CGFloat` — the parent supplies the frame `size` and scroll `insets` (it owns the
  keyboard/panel inset, e.g. from `environment.inputHeight`); returns the measured content height. The view
  set `scrollView.contentInsetAdjustmentBehavior = .never` and **removed all `UIResponder` keyboard
  observation**. A private `performLayout(size:)` sizes the scroll view/canvas; only `update` writes insets
  (so a system `layoutSubviews` pass can't clobber the parent inset). Caret-follow scrolling stays internal.
  **A CHANGED TOP inset re-seats a scroll view that is resting at the top** (`contentOffset.y = −insets.top`,
  applied after `performLayout` so the new content size is in place; gated on the top inset actually changing,
  so a keyboard-driven bottom inset or a post-edit re-layout never moves a scroll the user owns). UIKit only
  CLAMPS the offset on an inset change and `contentInsetAdjustmentBehavior` is `.never`, so nothing else does
  it: a SHORT document is clamped into place for free (the visible-height floor makes `−top` its only valid
  offset) but a document TALLER than the viewport leaves offset 0 in range — which is why the article editor
  opened with its first screenful hidden under the navigation bar while the composer looked fine (its top inset
  is 0). Guarded by `RichTextEditorViewTests.test_update_tallDocument_restsBelowTheTopInset` +
  `…_doesNotResetAScrolledOffset`.
- `height(forWidth:contentMargins:) -> CGFloat` — a side-effect-free content-height measure (the Phase-2
  follow-up to the composer's `textHeightForWidth`). Mirrors what `update(...)` returns at that width
  (same `minimumContentHeight` floor + `contentMargins`) but reflows NOTHING live: the per-block
  `measuredHeight(forWidth:)` chain reads structural insets and measures text via a reused per-engine
  scratch layout (`BlockLayoutEngine.boundingHeight(forWidth:)`). De-stateful-ized `TableBlockBox.height`
  in passing (it no longer resizes cell layouts to measure; `recompute()` owns cell layout).
  **LOAD-BEARING — the measure must be PURE w.r.t. the live `contentMargins`, not just the live layout
  (2026-06-30).** `measuredContentHeight` derives the content WIDTH from the margins (`contentWidth` =
  `width − contentLeftPad − contentRightPad`), so reading the live `canvas.contentMargins` makes the result
  depend on whether `update(...)` has run yet. A host that sizes its field from this BEFORE the first
  `update(...)` (the chat composer when a draft is applied before the editor is framed — `bounds.width == 0`,
  so `setInputContent` skips the corrective `update`) then measures the text at the FULL width (the right-inset
  reservation is still 0 → fewer wrapped lines → a too-short height), and the field visibly GROWS one pass
  later when the real margins land — the device-verified "pre-set draft text jumps on open, not every time"
  bug (the intermittency is the async draft-push racing the first layout). Fix: `height(forWidth:contentMargins:)`
  + `measuredContentHeight(forWidth:contentMargins:)` take the intended margins explicitly; the composer's
  `textHeightForWidth` passes its `trackedContentMargins` (the value the next `update` will apply), so the
  measure is correct on the first pass regardless of the race. `nil` keeps the live-margins behavior for hosts
  that always `update` before measuring (`RichTextAttachmentScreen`), so they're byte-unchanged.
- `onChange: (() -> Void)?` — payload-free; fires on any edit, content-size change, or selection move
  (funneled from the canvas's `onContentSizeChange` + `onSelectionChange`, the latter fired unconditionally by
  `editing { }`). The host re-runs its layout (→ `update`) in response. **`update` must NOT synchronously fire
  `onChange`** (would recurse) — guarded by a regression test.
- `currentState() -> EditorState` — a pure read (bold/italic/underline/strikethrough/code, paragraphStyle,
  listMarker, link, hasSelection, isInTable, canUndo, canRedo) built from canvas internals; drives a host
  toolbar's per-action availability + selected state. Inline flags are uniform-over-selection, or the caret's
  inherited run format when collapsed. The 5 format predicates are extracted (`rangeIsBold` etc.) and shared
  by the `toggle*` commands and `currentState`.
- `deleteTable()` — removes the caret's table (one undo step; caret lands on the successor block, or a fresh
  empty paragraph if it was the only block). No-op when not in a table. (This is the handle-menu "Delete Table"
  / caret-based path, which *joins* the surrounding content.)
- **Backspace with a table structural (row/column) selection** (`deleteTableStructuralSelection`, hooked at the
  top of `deleteBackward` since the parked caret would otherwise hit the in-cell delete) deletes the selected
  rows / columns — routing to the existing `deleteTableRow` / `deleteTableColumn` (which already read
  `structuralRowRange()` / `structuralColumnRange()`). When the selection covers EVERY row or EVERY column
  (`lowerBound <= 0 && upperBound >= rowCount/columnCount − 1`) — which would empty the table — it removes the
  whole table block instead, replacing it **in place** with an empty body paragraph (caret there). Distinct from
  `deleteTable()` above (which joins): full-selection backspace leaves an empty paragraph where the table was.
  The structural selection is cleared afterward (mirrors the handle menu's `structuralAction`).
- `composerSelectedRange: NSRange { get set }` — the selection in the **chat composer's flat UTF-16
  coordinate space** (the document's top-level paragraphs joined by `"\n"`, exactly the
  `ComposerDocumentBridge` flattening; non-paragraph blocks contribute nothing). Maps that flat offset
  to/from the editor's global selection axis (which carries non-renderable structural slots between blocks),
  collapsing each paragraph break to one `"\n"` so a multi-UTF-16-unit emoji + the separators line up 1:1
  with what `ChatTextInputPanelNode` inserts. **This is load-bearing for the chat composer:**
  `RichTextEditorChatInputNode.selectedRange` forwards to it, and the panel drives ALL insert/replace/caret
  moves off `selectedRange`. While it was a stub (getter = end-of-text, setter = no-op) the panel was
  selection-blind — the caret never advanced after a programmatic insert and a surrogate-pair emoji was split
  on a delete/insert cycle, leaving a stray code unit (a "service character"). The setter brackets
  `selectionWillChange/DidChange` (programmatic move). Implemented in `DocumentCanvasView+ComposerSelection`.

**Host edit-menu hook (added 2026-06-17, `RichTextEditorView` + `DocumentCanvasView+EditMenuActions`).**
`contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])?` lets a host **transform**
the iOS-16 edit menu. The editor calls it from `editMenuInteraction(_:menuFor:suggestedActions:)` with
`defaultElements` = the system suggested actions (Cut/Copy/Paste/Select + Writing Tools) **followed by the
editor's own custom items** (the built-in "Format" submenu + Look Up / Translate / Share); the host returns the
final children. Consulted **only for a non-collapsed selection** (matches `customEditMenuElements()`' own gating)
and **only on iOS 16+** — on iOS 13–15 (`UIMenuController`) host items are NOT injected (a `UIMenuItem` needs an
Obj-C `#selector` and can't carry a closure; `UIAction` hides its handler, so the closure-based host items can't
be bridged). `nil` ⇒ the editor's default menu, unchanged. The chat composer (`ChatTextInputPanelNode`) uses it
to drop the editor's 3-item built-in Format submenu and splice in its richer 10-item one (Bold/Italic/Monospace/
Link/Strikethrough/Underline/Quote/Spoiler/Date/Code, secret-chat gated), routing each to the editor's native
engine (`toggleBold()` etc.; Quote → `setParagraphStyle(.quote)`; Date/Code are deferred no-ops); Link reuses the
host link UI (a branched `openLinkEditing` in `ChatControllerLoadDisplayNode`, using `currentLink()` /
`selectedText()` / `setLink`/`removeLink`). `selectedText() -> String` is the selected substring (for that link
editor). Spec/plan for this work were intentionally not retained in-tree.

**Composer bridge round-trip — custom emoji / mention / date (added 2026-06-19, `feature/richtext-composer-bridge-gaps`).**
`ComposerDocumentBridge` (`ChatRichTextEditorComposer`) and `EntityMessageBuilder` (`RichTextEditorMessageConversion`)
convert the composer's `Document` to/from the chat `NSAttributedString` currency. They now round-trip three inline
features that previously dropped: **custom emoji** (`ChatTextInputAttributes.customEmoji` ↔ `CharacterAttributes.emoji`
as a one-`U+FFFC` run; the original placeholder text is kept in `EmojiRef.altText` and re-emitted, since the Document
interior must stay a single `U+FFFC`), and **mention/date**, which are stored in the Document's existing
`CharacterAttributes.link` field as `tg://user?id=` / `tg://timestamp?t=` markers — **no new `CharacterAttributes`
field** (keeps Core markdown-clean). The encode/decode + the chat-attribute emit are centralized in the shared
`TextFormat` codec `MentionDateMarkers.swift` (`mentionMarkdownURL`/`parseMentionPeerId`, `dateMarkdownURL`/`parseDate`,
`classifyChatLink`, `chatInputLinkAttribute`) so the three sites (`document(from:)` / `attributedString(from:)` /
`buildEntityMessage`) + `composerContentEqual` can't drift; unit-tested in `//submodules/TextFormat:TextFormatTests`
(the repo's first `ios_unit_test`). The send path is automatic — the builder stamps the chat attributes and
`generateChatInputTextEntities` already emits `.CustomEmoji`/`.TextMention`/`.FormattedDate`. **Creation is unchanged**
(the Date menu item remains a no-op — this is preservation only; **code-block round-tripping + creation landed in the
follow-up note below**). **Known accepted limitation:** a `textUrl` whose string equals a
`tg://` marker (via markdown/paste/edit) is reinterpreted as a mention/date on round-trip — low-probability,
documented in `MentionDateMarkers.swift`. Spec/plan in `docs/superpowers/{specs,plans}/2026-06-18-richtext-composer-bridge-gaps*`.

**Load-bearing invariant — the iOS-16 edit menu needs `Display.Window1.hitTest` to forward to it.**
`UIEditMenuInteraction` hosts its menu in a top-level `_UIEditMenuContainerView` subview of the app window.
Telegram's `Window1.hitTest` (`submodules/Display/Source/WindowContent.swift`) only forwards touches to window
subviews whose class matches an allow-list; it was extended (2026-06-17) to match `"EditMenu"` (alongside the
pre-iOS-16 `"UITransitionView"` / `"ContextMenuContainerView"`). **Without that match, taps on the menu fall
through to the content below and every item is inert** — the symptom that surfaced first here because this is a
custom `UITextInput` presenting `UIEditMenuInteraction` directly. Any editor change that relies on the system
edit menu being interactive in the Telegram app depends on this allow-list entry.

**Deferred:** pending caret formatting (inline toggles at a *collapsed* caret are currently inert — they show
the inherited state but don't affect the next typed char). (Table structural row/column selection + its
delete-via-Backspace now landed — see `deleteTableStructuralSelection` above.) **Code blocks landed**
(2026-06-19, `feature/richtext-code-block`) as a first-class multi-line `Block.code` — see the dedicated note
below; they now losslessly round-trip and Format▸Code creates one. Dates now *round-trip* via the link scheme
(see the composer-bridge note above), but the Date menu item remains a creation no-op (no native
timestamp-creation UI yet).

**Composer code blocks — first-class `Block.code` (added 2026-06-19, `feature/richtext-code-block`).** A
multi-line code block is now a first-class `Block.code(CodeBlock)` (`Core/Model/CodeBlock.swift`: `id` +
`language: String?` + plain `runs` whose text may contain interior `"\n"`), rendered by a new
`CodeBlockBox: CanvasBlock` (`Canvas/CodeBlockBox.swift`) — a monospace `BlockLayoutEngine` inside a band the
box paints ITSELF (see the edge-to-edge note below; it shared the quote's `BlockquoteUnderlay` until
2026-08-18). **It reuses the
existing position model unchanged:** `Block.code` maps to a `.paragraph` `DocNode` carrying a `TextNodeRef.code`
leaf, sized `content + 2` exactly like a wrap-heavy paragraph — multi-line interior `"\n"`s need **no** new
position/selection/tokenizer machinery (they're a linear UTF-16 range TextKit wraps). `currentBlock()` reads
back the **plain** layout string (display-only monospace attrs never enter the model). Editing affordances
mirror quotes (`+UITextInput`/`+Editing`/`+Interaction`): **Enter** inserts an interior newline via
`insertCodeBlockNewline()` (replacing any selection); **double-return** (Enter on an empty line —
`codeBlockDoubleReturnExit`) EXITS — a **trailing** blank line → body paragraph *after*
(`exitCodeBlockToBodyParagraph`), the **first** blank line → body *before* (`exitCodeBlockToBodyParagraphBefore`; fires at local 0 OR local 1 — the
start of content right after a leading blank — so **two newlines at the beginning** break out above),
a **wholly-empty** block → un-code (`uncodeEmptyCodeBlock`); a MIDDLE blank line just inserts another newline.
**Backspace** in a fully-empty code block un-codes it to body;
a **tap below** a trailing code block appends a body paragraph; **cross-block** edits treat a code endpoint
like media (truncate-and-keep partial coverage, drop full coverage) in `applyReplaceOutcome`. **Creation:**
`makeCodeBlock()` (`+ParagraphFormat`, façade-forwarded) toggles the touched top-level paragraphs into one code
block (joining BOTH paragraph and existing-code text, refusing a selection that spans a non-text block) and
toggles back to body paragraphs split on `"\n"`; wired to the composer's Format▸Code via
`performFormatAction(.code)`. The chat round-trip is the **bridge** (`ComposerDocumentBridge` two-pass
`document(from:)` + emit) and **send** (`EntityMessageBuilder` → `.Pre`), centralized through `TextFormat`
`CodeBlockMarkers.swift` (`chatInputCodeBlockAttribute` / `codeBlockRanges`, unit-tested); the `composerParagraphs`
flat-mapping counts a code block's interior. Full SwiftPM suite green (Core 102 + UIKit 714); the app build +
`TextFormatTests` are green; **no logged-in-sim pass yet** (non-gating). The composer flat-coordinate mapping
and the position axis were the load-bearing reuse points — code blocks added zero new invariants there. Spec/plan:
`docs/superpowers/{specs/2026-06-19-richtext-code-block-design.md,plans/2026-06-19-richtext-code-block.md}`.

**Code-block LANGUAGE field + syntax highlighting (added 2026-08-25).** A code block's language is
**authored in an always-visible, editable line at the top of the band**, and code is syntax-highlighted in
both editor hosts. `CodeBlock.language` and its whole serialization path already existed; this added the
authoring UI and wired the highlighter.

**The language line is a second LEAF REGION on `CodeBlockBox`** — its own `BlockLayoutEngine`
(`languageLayout`), its own `TextNodeRef.codeLanguage`, and a `DocumentTree` shape change: `.code` maps to a
CONTAINER of two paragraph children, `[language, code]`. It mirrors a pull quote's `[text, author]`, with
the extra region LEADING and **never content-gated** (a quote author appears only once its quote has
content; the language field is always visible, which is also what keeps the code text's offset stable).
`nodeSize` is `len + langLen + 6`; the language text sits at `nodeStart + 1`, the code text at
`nodeStart + langLen + 3`. The value is stored AS TYPED, trimmed, empty → nil; only the highlighter lowercases
(`richTextNormalizedCodeLanguage`). The ENGINE line renders it as stored too (p13 fix, below): rendering it
lowercased wrote the lowercased text back on every re-render, since the line is what the language is read from.

- **`textStart`/`textLength`/`textRef` still mean the CODE region, and `activeStack` resolves a box by that
  PRIMARY region** (`leafRegions().first(where: { $0.globalStart == b.textStart })`, plus a fallback that
  refuses a position inside one of the box's own non-primary regions). This is the load-bearing part: a
  caret in the language line otherwise resolved to the code box with a LANGUAGE-relative offset, which
  callers applied to the CODE layout — `insertCodeBlockNewline` spliced a newline into the code at the
  wrong offset. It compiles and reads correctly at every call site. With the guard, every legacy
  `box is CodeBlockBox` branch is inert in the language line **by construction** rather than by each site
  remembering to ask which region it is in. NB the naive `pos >= textStart, pos <= textStart + textLength`
  is NOT equivalent — containers report a degenerate `textStart == nodeStart`, so it would newly match them.
- **`leafRegions()` is DOCUMENT order** (navigation indexes `allLeafRegions()` positionally), so a code
  box's `.first` is now its LANGUAGE line. Every consumer that means "the box's primary text" must use
  `textStart`. `+ComposerSelection`'s flat mapping did not, and flattened a code block to its language,
  dropping the code from the composer axis entirely.
- **A range edit inside the language line routes region-aware.** iOS delivers a backspace there as a RANGE,
  which resolves to no `activeStack`, so the top-level engine returned `.unchanged` — the character was
  selected and never deleted. `applySelectionReplaceOutcome` asks `regionIsOffTheTopLevelEngine(_:)`
  (exhaustive over `TextNodeRef`, no `default`) and routes author AND language through
  `applyLeafReplaceOutcome`.
- **Editing semantics:** Return moves to the code start (a `.Pre` language has no second line — this is
  where it diverges from the trailing author, which splits); Backspace at the start un-makes a wholly-empty
  block or steps out without deleting; inline formats, emoji and links are inert; text services are off in
  BOTH code regions (`caretIsInCodeRegion`), because iOS capitalizes `let` to `Let` and autocorrects
  identifiers. That made `autocapitalizationType` the SEVENTH `UITextInputTraits` member the canvas
  implements — the differential harness censuses that set, so adding one moves those tests. UIKit caches
  traits, so `refreshSelectionUI` reloads them when the caret crosses into or out of a code block.
- **`sameOwningStack` needed its own resolver.** It asked `activeStack` "which box + local" when it only
  wanted "which stack", so once the guard above refused author/language positions, Select-All over a pull
  quote (whose end endpoint lands on the empty author region) stopped toggling. `owningStack(at:)` answers
  the narrower question. This is now the third narrow resolver in the `resolveBox` family the tech-debt
  note above describes — the generalization it asks for is still owed.

**Syntax highlighting is HOST-PROVIDED, because this package cannot see the highlighter.**
`RichTextEditorUIKit` depends only on `RichTextEditorCore`, `AppBundle` and `MosaicLayout`, and must keep
doing so to stay SwiftPM-testable and to keep the Demo app buildable — libprisma lives behind
`TextFormat`/`TelegramCore`. So the editor owns detection, debounce, cache and apply, and the host answers
`(language, text) -> [RichTextSyntaxToken]` through `registerSyntaxHighlighter(_:)`, the same seam pattern
as `registerEmojiViewProvider` / `mapper.formulaRenderer`. Package tests inject a stub, so `swift test`
never needs libprisma. Both hosts answer via `asyncStanaloneSyntaxHighlight`, baking the LIGHT palette —
the palette decision lives host-side, so what the editor shows is what the sent message shows.

- **Highlighting is inert until a language is typed** (an empty one is skipped), and an unknown language
  yields an empty token list that is cached like any other answer, so it is attempted once per
  (language, text) rather than every pass.
- **The pass is debounced ~300ms** from `performEditing` and `setBlocks`, never from a selection change: the
  caret moving through code changes no spec.
- **`CodeBlockBox.applySyntaxHighlight` rebuilds the block's string with the colours baked in**, which is
  lossless HERE ONLY because a code block's runs are plain by construction — no link, emoji, inline-code or
  spoiler attribute lives inside one. It re-assigns `layout.attributedString` only when the result differs
  (the idempotence rule), and drops a token set WHOLE when any range no longer fits the text. Colours never
  reach `Document`: `currentCode()` reads the plain string back.
- **Repaint the BLOCK VIEW, not the canvas.** A code block draws into a pooled `BlockBackingView`, so
  `setNeedsDisplay()` on the canvas leaves its bitmap stale until some unrelated layout pass happens to run
  `syncBlockViews()`. That is why highlighting first appeared only after the caret left the block. The pass
  calls `blockViews[box.id]?.setNeedsDisplay()` and deliberately does NOT call `notifyContentSizeChanged()`
  — colours never change metrics, and firing it would ask the host to re-lay-out on every arrival.
- **A rebuild re-applies from cache SYNCHRONOUSLY.** A theme / quote-style change or an undo restore
  reconstructs every box from the model, which carries no colours, so waiting for the debounced pass showed
  a plain frame — the "text loses highlight when the device changes theme" report. `setBlocks` calls
  `reapplyCachedSyntaxHighlights()` before the new boxes are first laid out.
- **Painting rebuilds the block's text storage**, which would pull the rug from under an IME composition.
  Safe today only because marked text is confined to top-level body paragraphs
  (`isBodyParagraphPosition` requires `box is BlockBox`); if IME support ever reaches code blocks, that
  needs a guard.

Three defects OUTSIDE this package had to be fixed before any of it was visible, all pre-existing and all
silent: `InstantPageBlock(apiBlock:)` hard-coded `language: nil` when decoding `pageBlockPreformatted`, so
every page decoded from the API came back language-less; `generateMessageSyntaxHighlight` passed the raw
language to libprisma, whose grammar lookup is an exact lowercase-keyed map, so `"Swift"` produced zero
tokens; and V2's `layoutCodeBlock` never read the `cachedMessageSyntaxHighlight` its layout context has
always carried. See `docs/instantpage-richtext.md`.

**Floating cursor — hold-spacebar-to-move-cursor (added 2026-06-23, runtime-verified 2026-06-24, `feature/richtext-floating-cursor`, phase 1 of 2).**
The iOS keyboard-as-trackpad gesture is implemented on the canvas (the bare sole `UITextInput`, which own-draws
everything and installs NO `UITextSelectionDisplayInteraction`) via the three optional `UITextInput` methods
`begin`/`update`/`endFloatingCursor` (`DocumentCanvasView+FloatingCursor.swift`). **Two runtime discoveries
corrected the original spec's assumptions** (the spec's relative-delta + hide-steady-caret design did NOT match
how iOS actually drives a bare `UITextInput` — both are wrong; see the spec's "Runtime corrections" addendum):

1. **The `point` is an ABSOLUTE canvas (content) coordinate**, not a relative delta — it already tracks the cursor
   across the whole document. So `update` feeds it straight to `closestGlobalPosition` (no delta, no viewport
   clamp). The clamp in the first cut froze the caret mid-text and couldn't reach the document start.
2. **`begin`/`update` fire fine on the bare `UITextInput` (no `UITextInteraction` needed), BUT during the gesture
   iOS ALSO pushes selection RANGES** (anchored at the gesture-start position) through the **`selectedTextRange`
   setter**; applying them turns the cursor MOVE into a text SELECTION (the headline bug). The setter therefore
   **ignores writes while `floatingCursorActive`** (`DocumentCanvasView+UITextInput`) — the floating handlers own
   the caret. **This is the load-bearing invariant of the feature.**

Visual model (matches iOS): a **bright gliding shadow** (`TransientCaretView`) follows the finger **continuously**
(`moveFloatingCaret(toGlobal:shadowX:)` positions it at the raw `point.x`, clamped to host bounds — only the
*underlying* caret snaps to a grapheme position), while the **steady `CaretView` becomes a dimmed (alpha 0.4)
"landing" indicator** at the snapped position via the `floatingCursorActive` branch in `updateCaretView` (NOT
hidden — the early design hid it, leaving no landing cue). On `end` the shadow fades and the steady caret returns
to full alpha + blink at the landing. Each `update` moves the caret through a **lightweight bracketed path**
(`moveFloatingCaret`) that brackets `inputDelegate.selectionWillChange/DidChange` but **deliberately suppresses
the host scroll-follow** (`onSelectionChange`/`scrollCaretIntoViewIfNeeded`) per-update — the gesture owns
scrolling via a `CADisplayLink` **vertical auto-scroll** driver (mirrors the table-drag auto-scroll, advances the
stored `floatingCursorPoint` by the scroll delta); `onSelectionChange` fires once on `end`. `TransientCaretView`
and the steady caret both host via the extracted `caretHostPlacement(forGlobal:)`/`hostOverlay(_:at:)`, so they
ride table-cell horizontal scroll. Document-wide landing (body/caption/code/table cells). An interrupted gesture
(resign-FR / window-removal) is torn down by `cancelFloatingCursor` (invalidates the self-retaining display link).
**`TransientCaretView` is built generically so phase 2 (text drag-and-drop drop caret via
`UITextCursorDropPositionAnimator`, iOS 17+, a separate cycle) can adopt it as the animator's `cursorView`.**
Status: **runtime-verified in the chat composer** (smooth glide, visible landing caret, reaches both ends, no
stray selection); full SwiftPM suite green (Core 102 + UIKit; incl. `TransientCaretViewTests` + the rewritten
`FloatingCursorTests`) and the full Bazel app build is green. (Per the module convention, the per-phase
design spec/plan are not retained in-tree; this note is the in-tree record.)

**Loupe grow-from-cursor + gliding shadow caret (added 2026-07-06, runtime-verified, squashed to master, `feature/richtext-loupe-grow-cursor`).**
The long-press magnifier (`UITextLoupeSession`) now **animates from the caret** and drags with the floating-cursor
visual. **This is the ONE scoped exception to "no `UITextSelectionDisplayInteraction`":** the loupe's grow
animation IGNORES a bare/own caret view passed as `fromSelectionWidgetView` — device-verified, a bare `UIView`,
a frozen-solid one, AND even a `UITextCursorView`-conforming view all fail (the loupe grows at the *touch*, not
the widget). It only honors a real system `cursorView`, which is owned by a `UITextSelectionDisplayInteraction`.
So `handleLongPress` **creates a FRESH interaction per drag and tears it down on release** (`removeInteraction`),
borrowing `interaction.cursorView` as the widget. **Per-drag lifecycle is load-bearing:** a PERSISTENT interaction
goes stale against the canvas's view virtualization and crashes with a use-after-free in
`-[UITextSelectionDisplayInteraction setActivated:]` (`objc_retain` on a freed selection view) on a SUBSEQUENT
drag after intervening edits (device-log-verified). Its injected chrome (cursor / lollipops / accessory, ~26
views) is corralled in a dedicated `selectionChromeContainer` (returned from the `selectionContainerViewBelowText`
delegate) that the block-view reload loop never frees, and `removeInteraction` clears it on release — no
orphaned-lollipop leak.

**Visual during the drag** (the spacebar floating-cursor look): the **accent** `TransientCaretView` glides at the
raw finger x (unsnapped, `positionLoupeShadow`); OUR own `CaretView` is the desaturated **"shadow"** at the
snapped real-caret position (`RichTextEditorTheme.shadowCursor`, a light **HSL-lightness** gray — NOT HSB
`saturation:0`, which whitens a bright accent; recolored for the drag and restored on `.ended` via
`loupeSavedCaretAccent`); the borrowed system cursor is kept **near-invisible** (`alpha 0.01`, grow anchor only)
so its native blink can't flicker through. On release the widget is **snapped to the final caret**
(`setNeedsSelectionUpdate`+`layoutManagedSubviews`) BEFORE `invalidate()`, so the loupe animates OUT onto the
caret, not the finger (the loupe's `move(to: finger)` had been dragging the widget along). `CaretView`
**conforms to `UITextCursorView`** (`isBlinking`/`resetBlinkAnimation`) so a future non-interaction path could
hand it directly, but the loupe still needs the interaction-owned cursor today.

**The gray shadow shows only once the accent glider diverges from it by ≥ `loupeShadowMinSeparation` (14pt, added
2026-07-06).** While the finger sits on top of the snapped caret the shadow is redundant clutter, so `CaretView` is
hidden until the accent (finger x) and the snapped caret separate (mid-character / between snap points), then it
appears to cue where the caret will land. `positionLoupeShadow` sets `caretView.isHidden` per frame from the pure
`loupeShadowShouldShow(accentX:snappedX:)` (both in the shared overlay-container space); `updateCaretView`'s
`loupeDragActive` branch defaults it VISIBLE each refresh so the terminal `setCaret` (no following
`positionLoupeShadow`) leaves the final caret shown. Guarded by
`SelectionInteractionTests.test_loupeShadowShouldShow_onlyBeyondMinSeparation`.

**The drag reports the selection ONCE, at the final position — not per frame (added 2026-07-06).** Both report
channels are deferred to the drag's end, each by its own "fire once" mechanism:
- **Host report** (`onSelectionChange` → the composer's `onChange`: interface-state selection commit + re-layout).
  `handleLongPress` moves the caret each frame with `setCaret(global:reportSelectionChange:false)`, which
  SUPPRESSES `onSelectionChange`. It fires once on the terminal state: `.ended` re-runs the default `setCaret`
  (reports); `.cancelled`/`.failed` call `onSelectionChange?()` directly so the host isn't left stale.
- **OS input-delegate bracket** (`selectionWillChange/DidChange` → the keyboard's autocorrect/candidate bar).
  Left un-coalesced, a per-frame bracket makes the **keyboard suggestions visibly JUMP** on every move. The drag
  reuses the selection-handle-drag coalescing: `.began` calls `beginCoalescedSelectionDrag()`, `setCaret` now
  skips the bracket while `coalescingSelectionNotifications` is set (mirroring `setSelectionHead`), and the
  terminal `endCoalescedSelectionDrag()` fires exactly ONE bracket for the final caret. (The `selectedTextRange`
  getter stays live throughout; the keyboard only recomputes on a bracket.)

This is the same "report once at the end" model the floating cursor (spacebar-trackpad, `moveFloatingCaret` +
`endFloatingCursor`) uses for the host report, and it's the ONE loupe caret-move exception to the repo-wide
*"any caret-moving op must fire `onSelectionChange`"* invariant. NOTE the loupe goes further than the floating
cursor, which still brackets the input delegate per frame (its keyboard shows no suggestion bar during the
trackpad gesture, so it doesn't churn visibly). Trade-off: the outer-document scroll-follow (bundled into the
composer's `onSelectionChange` closure) is likewise deferred to the drag's end — negligible in the compact
composer; a dedicated per-drag auto-scroll driver (like the floating cursor's) is the follow-up if a tall
full-page editor needs edge auto-scroll during a loupe drag. Guarded by
`SelectionInteractionTests.test_setCaret_withReportSuppressed_defersHostReport_untilTheDragEnds` (host) +
`…test_loupeDrag_coalescesInputDelegate_soKeyboardSuggestionsDoNotChurn` (keyboard).

**Proximity-adaptive long-press delay** (`LocationAdaptiveLongPressGestureRecognizer` — sets `minimumPressDuration`
per-touch in `touchesBegan` before `super`): near-instant (`loupeDelayNearCursor`) when the touch starts within
`loupeNearCursorRadius` of the caret ("grab the cursor"), longer (`loupeDelayFarFromCursor`) otherwise. A literal
`0` is unusable — tap and long-press share touches, so `0` fires the loupe on every quick tap.

**`inputHitTestSlop` (composer, `RichTextEditorChatInputNode`).** The panel's negative slop (a bigger tap target)
is now applied by a `hitTest(_:with:)` override on the node, routing a touch in the slop ring around `editorView`
into the editor's canvas — `ASDisplayNode.hitTest` is forwarded to by `_ASDisplayView` when overridden (with a
re-entrancy guard, so `super.hitTest` is the standard UIView pass). Build-verified only.

The host action bar (12 icon actions + ContextUI context menus) lives in the separate `RichTextAttachmentScreen`
module, not this package. Full session handoff: `~/Documents/RichTextEditor/docs/superpowers/handoffs/2026-06-12-richtext-session-handoff.md`.

**Session updates (2026-06-13 → 06-16, branch `feature/richtext-message-serialization`).** All TDD'd, full
SwiftPM suite green (657 UIKit tests + Core). No runtime/app pass yet; the conversion + `RichTextAttachmentScreen`
+ Demo edits are Bazel/xcodegen (not SwiftPM-compiled) so verified by inspection only. The later items
(edit-menu auto-dismiss, Select-All-image delete, quote affordances, content margins, the parent-driven layout
sweep) extend this block below; the layout sweep also has a spec/plan pair in
`docs/superpowers/{specs,plans}/2026-06-16-richtext-parent-driven-layout*`.
- **Type scale + `Title` removed.** `ParagraphStyleName` is now `heading1, heading2, heading3, body, caption,
  quote` (no `title`; no backwards-compat decode shim — a persisted `"title"` simply fails to decode). Sizes
  (`StyleSheet`, as of 2026-06-13): H1 24 / H2 21 / H3 19 **serif**, Body 17 sans, Caption 15 sans, Quote 17
  sans — **superseded 2026-08-14 by V2 parity, retuned 2026-08-17** (H1 22 / H2 20 / H3 18 / H4 17 / H5 16 /
  H6 15 serif MEDIUM, from `RichTextRenderMetrics`; see the layout-parity note near the top). **`caption`
  is a render-only style** (media-block captions, 15pt) — never offered in the picker, never persists as a
  paragraph style (a caption serializes as the MediaBlock's runs); `MediaBlockBox` lays the caption out as
  `.caption`. Exhaustive `switch ParagraphStyleName` sites (StyleSheet ×2, conversion ×2) all carry `.caption`.
  **Table cells render body/quote at a smaller base — 15pt, not 17 (2026-06-26).** `StyleSheet` gained a
  `bodyBaseSize` (default 17) read by `baseSize(.body/.quote)` and a `static let tableCells` variant (15);
  `AttributedStringMapper.tableCellVariant()` copies a mapper onto it preserving theme/emojiScale. Each
  `TableBlockBox` derives a cell mapper once and builds every cell box with it. To keep edits consistent, a
  box created as a split/merge replacement **inherits its source box's mapper** (`CanvasBlock` now exposes
  `mapper { get }`; the three cell-capable creators — `applyReplaceOutcome` merge, `insertParagraphBreak` split,
  `mergeParagraphsOutcome` — pass `start.box.mapper`/`p.mapper`/`upper.mapper` instead of the canvas mapper), and the
  empty-cell typing path (`typingAttributeDict`'s empty-storage branch) resolves the owning box via
  `activeStack` and uses **its** mapper — so an empty cell's first typed character is 15pt too. Headings keep
  their fixed sizes in cells. (An explicit run `fontSize` still wins; read-back pins the rendered 15pt.)
  **Paired cell-padding mechanism fix.** Cell vertical padding is now an explicit cell metric
  (`TableBlockBox.cellVerticalPadding = 14`) applied at the CELL level (`recompute` content origin +
  row-height math), parallel to the horizontal `cellPadding` (6) — and the cell `BlockStack` carries NO block
  inset (`verticalInsetBase = 0`). Previously the cell's 14pt vertical gap came *incorrectly* from
  `cellPadding` (6) + the document's 8pt inter-block inset (`BlockBox.defaultVerticalInset`) leaking into the
  cell stack; that coupling tied cell padding to document-body block spacing (font-independent), so the
  smaller 15pt text looked under-filled / vertically centered. The **visual is unchanged from before the font
  change** (14pt top/bottom), but it's now decoupled from `defaultVerticalInset` and lives in one cell metric.
- **`DocumentMetadata` removed entirely** → `Document { schemaVersion, blocks }` (it had become a vestigial
  single-`title` wrapper that nothing read; the doc's title is a `.heading1` block). `DocumentCodec` dropped
  its now-dead ISO-8601 date strategy.
- **First-responder callbacks** on the façade: `onBecameFirstResponder` / `onResignedFirstResponder`, each
  fires **once on the genuine transition** (the canvas `becomeFirstResponder()`/`resignFirstResponder()`
  capture `wasFirstResponder` before `super`), so a repeat tap while already focused doesn't re-fire.
- **Taps land anywhere in the unobscured editor**, not only on text. `performLayout` floors the canvas height
  at the **visible** viewport (`size.height − contentInset.top − bottom`, read from the just-applied insets),
  so the canvas (which owns the tap/long-press/loupe recognizers) covers the empty area below a short doc;
  `closestGlobalPosition` maps such taps to the nearest position (doc end), matching UITextView. Flooring at
  the *visible* (not full-frame) height keeps `scrollView.contentSize == visible area` for a short doc → zero
  scrollable range (no phantom bounce over the inset bands) and it re-flows when insets change. `update`
  returns the real **content** height (unchanged contract).
- **`contentMargins` (`UIEdgeInsets`) is distinct from the scroll insets.** Insets are non-interactable bands
  the content scrolls UNDER (nav bar / keyboard / input panel, applied via `update(size:insets:)` →
  `scrollView.contentInset`). Margins are interior padding that is PART of the content: on the canvas, the text
  lays out inset by them — `root.layout(origin: (pageMargin + margins.left, margins.top), …)`, content width
  `= bounds.width − (pageMargin + left) − (pageMargin + right)` (additive to the built-in 16pt `pageMargin`),
  and `intrinsicContentSize.height` grows by `top + bottom`. Because the margin sits INSIDE the canvas, its
  area still hit-tests (a tap there places the caret at the nearest position) — unlike an inset. Both
  `setParagraphsWidthIfNeeded` and `layoutSubviews` derive width from the shared `contentWidth(forWidth:)`
  helper so they can't drift. **Applied via `RichTextEditorView.update(size:insets:contentMargins: = .zero)`**,
  alongside `insets` — NOT a side-effecting property. General rule (project convention): any setting that
  triggers re-load / re-layout / re-draw belongs in `update`, not a property whose setter hides a layout pass.
  `contentMargins` is a **plain stored value** on the canvas (read by `layoutContent()` / `intrinsicContentSize`,
  persisted across system passes); the setter does NOT `setNeedsLayout()` and does NOT fire
  `onContentSizeChange`/`onChange`. Instead the `update` that sets it re-runs `performLayout`, which lays the
  canvas out **explicitly** via `canvas.layoutContent()` (the body of `layoutSubviews`, factored out) rather
  than `layoutIfNeeded()` — so the new value takes effect even when the canvas frame is unchanged (e.g. a short
  doc whose height is floored to the viewport, where only top/bottom margins changed). A test asserts
  `update(...contentMargins:)` does not synchronously fire `onChange`.

  **Layout convention.** The parent drives layout explicitly (`performLayout` → `canvas.layoutContent()`)
  and a view never `setNeedsLayout()`s itself for a content-height change — it calls `notifyContentSizeChanged()`
  (fires `onContentSizeChange` → the host's `onChange`, which re-calls `update`). Every height-affecting path
  follows this: `editing { }`, the IME marked-text commit/update, `setBlocks`, and the undo block call
  `notifyContentSizeChanged()` only; the façade's `onContentSizeChange` is a **pure relay** (`onChange` only),
  and where the façade needs fresh geometry synchronously it lays out explicitly — `scrollCaretIntoView` and
  the `document` setter call `performLayout(size: bounds.size)`. The old `invalidateIntrinsicContentSize()`
  override is gone (its only job was firing `onContentSizeChange`, and it carried an implicit UIKit layout
  schedule). **Canvas-direct tests** that read post-edit geometry install `simulateParentLayout()` (a test-only
  hook that re-lays-out on the content-size notification, simulating the real parent) instead of relying on the
  UIKit `needsLayout` flag. **Out of scope** (do NOT affect content height, kept as UIKit-internal mechanism):
  `setNeedsDisplay` (repaint), `syncSpoilers`' reveal re-layout, and the parent→child `view.setNeedsLayout()` /
  `tv.layoutIfNeeded()` on block/table backing views.
- **`MediaBlock` is a multi-media container** (added 2026-07-08): `items: [MediaItem]` holds one or more
  photos/videos with one shared caption (additive/back-compat — a convenience single-item initializer +
  back-compat Codable decode keep every existing call site and persisted document unchanged). It stays
  **one atom** in the position model regardless of item count (`DocumentTree` still emits one `.mediaAtom`
  per block), so `nodeSize`/`textStart`/caret/select-all/covered-delete below are unaffected —
  multiplicity lives only in `items` and the mosaic render (`RichTextEditorMediaView`'s `CLAUDE.md`;
  send/edit round-trip in `docs/richtext-composer.md` §4 and `docs/instantpage-richtext.md`).
- **`MediaItem.isSpoiler` — per-item media spoiler** (added 2026-07-08): optional-Codable `Bool` (absent ⇒
  `false`, back-compat). Toggled by `DocumentCanvasView.toggleMediaSpoiler(blockID:itemIndex:)` (in-place
  `MediaBlockBox` rebuild, ONE undo step — same mechanism as `deleteMediaItem`); `itemIndex` in range flips
  that one cell, nil/out-of-range flips the whole block to `!first.isSpoiler`. Surfaced via the façade
  `RichTextEditorView.toggleMediaSpoiler(itemIndex:)` → `toggleSelectedMediaSpoiler` (reads `imageSelection`).
  **Authoring:** the single-media tap-select edit menu (`imageSelectionMenu` gains a "Spoiler" `UIAction`)
  and, for albums, the per-cell "•••" menu (via `MediaControlRequest.isSpoiler`/`toggleSpoiler`, host-built).
  **In-editor render is a NON-revealable cover:** `MediaProviderItem.isSpoiler` is folded into the
  `syncMediaItemViews` items-signature (so a toggle re-provides the cell), and `MediaItemNodeView`
  (`RichTextEditorMediaView`) hosts a `MediaDustNode` per spoiler cell with `revealOnTap = false`,
  non-interactive so taps still select. The revealable message-side render + wire/persistence round-trip are
  in `docs/instantpage-richtext.md` + `docs/richtext-composer.md` §4. Design/plan:
  `docs/superpowers/{specs,plans}/2026-07-08-richtext-media-spoiler*`.
- **Backspace targeting a media block replaces it with an empty body paragraph IN PLACE** (2026-06-27, supersedes
  the older per-case media-backspace rules). `replaceMediaWithEmptyParagraphOutcome(at:)` removes the media block and
  drops a fresh empty `.body` paragraph in its slot, caret there — NOT the old delete-and-merge-into-the-block-above
  (`deleteImageBox`) nor the old "act on the previous paragraph" gap behavior. It unifies every way a Backspace
  "lands on" a media block, reached on FOUR paths in `deleteBackward` / `applySelectionReplaceOutcome`:
  - **collapsed caret at the media's leading gap** (`mediaBox(atGap: head)` branch) — **NOTE: narrowed
    2026-07-21** to the TAP-SELECTED case only (`imageSelection == img.id`); a plain non-selected gap caret now
    acts on the PREVIOUS block instead (see the "Backspace at a media block's leading gap" note below);
  - **collapsed caret at the start of the caption** (`pos.box is MediaBlockBox, pos.local == 0`) — empty OR
    non-empty caption (the caption text is **discarded**);
  - **a selection whose bounds EXACTLY equal a media node's span** (`from == nodeStart && to == textStart +
    textLength`) in `applySelectionReplaceOutcome` (deliberate select-the-image-then-delete);
  - **the iOS object-replacement RANGE of a tap-selected media — the LOAD-BEARING, compiler-invisible case**
    (device-log-verified). Tapping a media runs `selectImage` (collapsed caret at the gap, `imageSelection` set),
    but the `selectedTextRange` setter clears `imageSelection` and, right before Backspace, **iOS OVERRIDES the
    selection to a RANGE whose head sits at the media's gap yet ANCHORS IN THE PRECEDING BLOCK** — iOS's
    object-replacement geometry is offset from our position model, so the range does NOT cover the media node. A
    naive `selFrom != selTo` delete erases the *preceding* text and KEEPS the media ("cursor moves into the
    paragraph above"). So the setter stashes the just-cleared image into **`imageObjectDeletePending`** (a
    `BlockID?` on the canvas), and `deleteBackward` consumes it at the top — when the selection touches that
    media's gap — to replace the media. `insertText` and any non-matching `deleteBackward` clear the flag so it
    can't go stale. **Lesson (reinforced): a bare custom `UITextInput` receives OS-driven `selectedTextRange`
    writes that turn a tap into an *offset* object-replacement range — unit tests that set the caret/selection
    directly miss it; capture the real sequence from the device (`NSLog` + `xcrun simctl spawn <udid> log
    stream`), don't hypothesise twice.**

  A media delete never leaves a zero-block document (a lone-block replace yields the empty paragraph). The image
  edit-menu **"Delete"** still fully REMOVES the block — only Backspace was respecified. (`deleteBlock(at:parkingCaretAtGapOf:)`
  was removed with its sole caller.) **Name corrected 2026-08-21 (Task 36c), behaviour VERIFIED not inherited:**
  this said `deleteImageBox`, which no longer exists under that spelling and was not this path's callee anyway.
  The menu's Delete closure is `+Media.swift`'s `MediaControlRequest.delete` → `deleteMediaBlock(id:)`
  (whole block) or `deleteMediaItem(blockID:itemIndex:)` (one album cell). `deleteImageBoxOutcome`'s own doc
  comment in `+Editing.swift` is where this whole class of mis-attribution is described — including why its
  count is deliberately not written down anywhere. Do not restate it here.

**Backspace at a media block's leading gap (2026-07-21).** A plain, NON-tap-selected caret at a media
block's leading gap (`nodeStart`, the slot to the LEFT of the image) now acts on the PREVIOUS block
rather than the media: it deletes the previous block's last grapheme (caret moves into that block), or,
if the previous block is empty, deletes the empty block (caret stays at the image's shifted gap); a
non-text previous atom (table / block quote whose boundary isn't renderable) is a safe no-op with the
caret left at the gap; a LEADING image (no previous block) is a no-op. A TAP-SELECTED image (the tint;
`imageSelection == img.id`, or the `imageObjectDeletePending` range path) still replaces the media with
an empty paragraph on Backspace, as does Backspace at CAPTION start (offset 0). Both the collapsed-caret
gap Backspace and the OS object-replacement RANGE `[prevEnd … gap]` (collapsed to a gap caret before the
gap branch) route through the same logic. This keys on `mediaBox(atGap:)`, so it applies to EVERY
`MediaBlockBox` including caption-less **audio** (`MediaKind.audio`) — consistent with images; audio stays
deletable via tap-select + Backspace through the `imageSelection == img.id` branch. See `deleteBackward`
(`DocumentCanvasView+UITextInput.swift`) and `CanvasImageEditTests` (`test_backspaceAtGap_*`).

- **Backspace at the start of a paragraph AFTER a non-text block deletes the empty paragraph, never the block**
  (`deleteBackward`, the mirror of the leading-gap rule above). A collapsed caret at the start (`local == 0`) of
  a paragraph whose previous block is a non-text **atom** — an image (`MediaBlockBox`), a table (`TableBlockBox`),
  or a code block (`CodeBlockBox`), unified via `isNonParagraphAtom(_:)` — must NOT delete that block (you can't
  merge text into it): an **empty** paragraph is removed (`removeBlockOutcome(at:parkingCaretAt:)`, so *"deleting the
  last paragraph" is always possible*), a **non-empty** one is kept; either way the caret steps back to the
  block's nearest text slot via `prevTextPosition` (an image's caption end, a table's last cell end, a code
  block's end) — never the block's degenerate node-start boundary. Previously the image branch called
  `deleteImageBox(at: pos.index - 1)` and silently destroyed the image; the table branch moved the caret but
  *kept* the empty paragraph (undeletable); the code branch left the empty paragraph in place. Text blocks
  (body/heading/quote/list paragraphs) still take the normal merge path below. (Select All + backspace still
  removes a covered image — that goes through `applyReplaceOutcome`, below.)
- **An audio media block (`MediaKind.audio`) is a CAPTION-LESS atom** (2026-06-27) — unlike image/video/location it
  has **no caption** (not rendered, editable, or in the position model). `DocumentTree` emits `mediaBlock([mediaAtom])`
  (nodeSize 3, no caption paragraph), and `MediaBlockBox` is **dual-moded on `kind == .audio`** — `textLayout` →
  `emptyLayout`, `textLength 0`, `nodeSize 3`, `textStart == nodeStart`, `leafRegions() == []` (the FIRST block with
  zero leaf text regions — the caret/nav/selection machinery routes media via `mediaBox(atGap:)`/`isGapPosition`, not
  caption regions, so an empty `leafRegions` is tolerated), `height == verticalInset + audioRowHeight + verticalInset`,
  `closestPosition → nodeStart`, `currentBlock()` caption `[]` (an incoming caption is dropped), and no caption
  draw/placeholder. The non-audio (captioned) path is byte-unchanged. `insertMedia(kind: .audio)` lands the caret in a
  **following body paragraph** (created if the audio is last / followed by a non-paragraph atom) since there's no
  caption to land in. The Select-All / covered-range delete checks (`endpointFullyCovered`, the exact-node-span
  backspace) route through `coverableContentEnd(_:)` — audio → `nodeStart + 1` (the atom span), else
  `textStart + textLength` — because audio's `textStart + textLength` collapses to `nodeStart`. Backspace targeting
  audio still replaces it with an empty paragraph via the gap path (below); the caption-start branch never fires
  (no caption position exists).

  **Generalised to documents (2026-07-31).** The predicate is now `MediaKind.isCaptionless` (`.audio ||
  .document`), mirrored by `MediaBlock.isCaptionless` / `MediaBlockBox.isCaptionless`; every former `isAudio`
  branch above — plus `DocumentTree` and the three `DocumentCanvasView+Editing` sites (`coverableContentEnd`,
  the media-caption Enter guard, `insertMedia`'s caret landing) — keys on it. The ONE kind-specific value is
  the row height: `audioRowHeight` 44 vs `documentRowHeight` **52**, selected by `MediaBlockBox.rowHeight`.
  **Both must equal the matching V2 frame height in `InstantPageV2Layout`** (the box reserves the slot, the
  renderer fills it), or the editor preview stops matching the sent bubble. The narrower `isAudio` accessor
  survives on BOTH `MediaBlock` and `MediaBlockBox` for callers that mean audio *specifically* (several tests
  assert audio identity — `isCaptionless` would silently also accept a document). Gap-caret Backspace,
  tap-select delete, vertical nav and Select-All coverage needed no change at all: they key on
  `mediaBox(atGap:)`, not the kind. Round-trip + recipient rendering: `docs/richtext-composer.md` §4 and
  `docs/instantpage-richtext.md`.
- **Inserting a table or image on an EMPTY paragraph replaces it; mid-paragraph it splits** (`insertTable`,
  `insertMedia`). Both share one branch order: an **empty** caret paragraph (`pos.box as? BlockBox` with
  `textLength == 0`) is **replaced** by the new block (`replaceSubrange(pos.index...pos.index)`) so no stray
  empty paragraph is left beside it — even between content (`A | empty | B` → `A | block | B`); a caret strictly
  **interior** to a non-empty paragraph (`0 < local < textLength`) **splits** it into upper + block + lower;
  caret at the **start** of a non-empty paragraph inserts the block **before** it, at the **end** inserts
  **after**. The empty-replace check must run FIRST (an empty paragraph is both `local == 0` and
  `local == textLength`, so it would otherwise fall into the insert-before branch and survive). Replacing the
  document's only block is fine — a lone `[table]`/`[image]` is a valid document (the caret lands in the first
  cell / caption; tap-below re-adds a paragraph). The empty-replace only targets `BlockBox` paragraphs, so it
  never replaces an image caption / code block the caret happens to sit in.
- **Select All + backspace removes a covered image, even a leading/trailing one** (`applyReplaceOutcome` cross-block).
  A media endpoint is now dropped when the selection covers its **whole node** (leading gap + entire caption:
  `lo <= box.nodeStart && hi >= box.textStart + box.textLength`), so the merge path's `replaceSubrange(start...
  end)` clears it like a covered MIDDLE image already was. A **partially**-covered media endpoint (selection
  starts/ends partway through a caption) still truncates-and-keeps (the Phase 2c behavior). Previously only
  middle images were dropped; an image at a selection endpoint (which Select All always makes of the first/last
  block) was truncate-kept, so CMD+A then Backspace left the image behind. The paragraph↔paragraph merge is the
  same path generalized: a fully-covered media endpoint contributes no runs, and the merged paragraph inherits
  the start block's style (else the end's, else a fresh body paragraph when both endpoints were media).
- **Quote-block escape/delete affordances** (a `quote` is a `BlockBox` with `style == .quote`). Three behaviors,
  each top-level only (an in-table quote keeps the cell behaviors): **(A)** Backspace in an **empty** quote
  un-quotes it (`style = .body; restyle`) instead of doing nothing — an empty quote, especially the document's
  FIRST block, otherwise matched no `deleteBackward` branch and was undeletable. Mirrors empty-list-item Return.
  A non-empty quote's backspace still just deletes a char. **(B)** Tapping in the empty area **below the
  document's last block** (`point.y > boxes.last.frame.maxY`) inserts a new empty body paragraph after it
  (`insertEmptyBodyParagraph(at:)`) — so you can always start a normal paragraph below the final block, whatever
  its type (image / table / quote / code / non-empty paragraph). **The one exception:** when the last block is
  ALREADY an empty body paragraph, the tap is let through to the normal caret-placement path (no redundant empty
  is stacked). This started as a quote/code-only escape hatch and was generalized 2026-06-25 (paired with the
  *"deleting the last paragraph"* backspace rule above, so a tapped-in trailing paragraph is also removable).
  **Gated on `tapBelowAddsTrailingParagraph` (added 2026-06-28, default `true`):** the article editor keeps it;
  the chat composer sets it `false` (a compact field has no empty area below the content to grow into) — see the
  compact-host knob list above.
  **(C)** **Double-return** (Enter on an empty line inside a quote or code block — added 2026-06-30, replacing
  the earlier Shift+Return) EXITS the block with a new empty body paragraph (caret there): the run's **last /
  wholly-empty** line → **after**, its **first** line → **before**, a wholly-empty block → un-quote / un-code;
  a MIDDLE empty line splits normally (no exit). For a quote *run*, first/last = the first/last consecutive
  `.quote` paragraph (`emptyQuoteIsRunEdge` → `exitQuoteToBodyParagraph`, which replaces the edge empty quote
  line with a body so the before/after side follows from which edge it sat on). **Reachability (2026-06-30):**
  after the first Enter at the start of a block the caret lands on the content line (past the new break), so the
  *before*-exit also fires from the start of content with an empty line directly above — code via the local-1
  branch of `codeBlockDoubleReturnExit`, quotes via `quoteDoubleReturnExitIndex` (caret at content start with an
  empty quote line above) — so **two newlines at the beginning** break out *above* instead of stacking blank
  lines. The old Shift+Return path (its `UIKeyCommand` + `performShiftReturn` + `caretIsOnFirstLine`) was removed.
- **"Type something…" placeholder shows only on the document's LAST block** (`BlockBox.isLastBlock`, stamped
  in `stampListMarkers` like `isTopLevelBlock`); an empty body paragraph elsewhere shows no placeholder (list
  hints are unaffected). An empty non-last paragraph still reserves its line + caret — only the hint is gone.
- **Selection highlight is UITextView-style** via a NEW draw-only `DocumentCanvasView.selectionHighlightRects`
  + `BlockLayout.selectionFillRects(start:end:fillTrailingLine:)` (used ONLY by `drawNonTableSelectionHighlight`).
  A line covered to its end fills to the container trailing edge; a line covered from its beginning fills to
  the leading edge (x=0) — so an indented quote/list fills full-width on covered lines (first line included,
  via `start == 0`) instead of hugging the indent; an empty line spanned by the selection gets a synthesized
  full-width row. The glyph-hugging **`selectionRects` is unchanged** — it still feeds the OS witness,
  edit-menu position, spoiler-dust geometry, and marked-text underline. (Body/caption only; table-cell
  selection still uses glyph-hugging rects — a deferred consistency follow-up.)
- **Edit menu auto-dismisses on any text/selection change** (native UITextView behavior). The canvas owns its
  own `UIEditMenuInteraction`, which — once presented — does NOT self-dismiss on a selection change (it just
  repositions via `targetRectFor`), so the canvas must call `dismissMenu()` itself. A new
  `dismissEditMenuForSelectionOrTextChange()` is called from the three selection setters (`setCaret` /
  `setSelectionHead` / `setSelectionAnchor`), the UITextInput **`selectedTextRange` setter** (the system path:
  keyboard cursor-drag / autocorrect / predictive text), and the `editing { }` text-mutation wrapper — so
  typing, deleting, programmatic + gesture + system caret moves, and boundary-move backspaces all close the menu.
  The dismiss is **UNCONDITIONAL — NOT gated on `editMenuVisible`**: the system flips that flag to false on a
  touch-down BEFORE the gesture's setter runs, so gating on it skipped the dismiss exactly when the user moved
  the cursor (the bug); `dismissMenu()` on a non-presented interaction is a harmless no-op. The
  present-after-change gesture flows — Select / Select All / double-/triple-tap / handle-drag `.ended` /
  long-press `.ended` — are unaffected because they change the selection via `applySelection` (deliberately
  NOT a dismiss point) and call `presentEditMenu()` AFTER any setter. `applySelection` stays out of the hook
  for exactly this reason.

**Compiler-invisible invariant (block-view repaint gate).** `bindRealizedView` forces a repaint when the box
**instance** bound to a realized view changes (`view.box !== box`), in addition to the `renderSignature` gate.
A structural edit (Enter-split / Backspace-merge) keeps a surviving block's `BlockID` but swaps its `BlockBox`
for a brand-new one whose fresh `BlockLayout` resets `renderVersion` to 0 — and `renderVersion` is per-instance,
so comparing it across the replacement is meaningless (a same-height/style upper half collided with the old
signature and skipped the repaint, leaving the pre-split full-text bitmap). The lower half always gets a new
`BlockID` → fresh view → always repaints, which is why only the surviving (upper) half went stale.

**The block model.** The canvas holds a `[CanvasBlock]`; conformers are `BlockBox` (paragraph),
`ImageBlockBox` (image + a first-class caption text region), and `TableBlockBox` (grid of `[[BlockStack]]`
cells). A `BlockStack` is a vertical run of blocks that backs both the document root **and each table
cell** (so the same split/merge/edit engine serves top-level and in-cell). `leafRegions()` /
`allLeafRegions()` is the recursion workhorse — selection, caret, text, and draw all iterate it,
recursing into cells.

**`+UITextInput` compile gotcha.** Any `UITextInputStringTokenizer(textInput: self)` /
`inputDelegate?.…change(self)` needs the `UITextInput` conformance to type-check, so the view class and
its `+UITextInput` extension are co-dependent and land together. Remember `import RichTextEditorCore` in
UIKit files.

## RTL / writing direction (added 2026-06-28)

RTL paragraphs (Arabic/Hebrew/…) lay out per-paragraph, **auto-detected by default**, with a persisted
**whole-document override**. Auto-detected direction is **render-only**; only the override persists.

- **Model.** `TextAlignment` gained `.natural` (leading) and it is the **default** for new paragraphs (absolute
  `.left/.center/.right/.justified` stay explicit overrides). `Document.layoutDirection`
  (`.auto/.leftToRight/.rightToLeft`, default `.auto`) is the override (Core; `DocumentCodec` defaulted decode →
  `.auto`). Both pure-Foundation; the Core→UIKit `NSWritingDirection` mapping is UIKit-side.
- **Detection.** `BlockLayoutEngine.baseDirection(atOffset:)` — one protocol-extension default impl over the
  engine's `attributedString` using `CTRunGetStatus(firstRun).contains(.rightToLeft)` (the same first-run
  heuristic as `TextNode`/`InstantPageV2Layout`, so the editor agrees with how the sent message renders). Both
  engines inherit it; nil on empty.
- **Resolution + reporting** (`DocumentCanvasView+WritingDirection.swift`): `resolvedDirection(forGlobal:)` =
  forced override → content detection → `typingWritingDirection`; `typingWritingDirection` = forced → keyboard
  language (`Locale.characterDirection`) → app `effectiveUserInterfaceLayoutDirection`. `applyWritingDirectionOverride`
  sets `layoutDirectionModel` + `mapper.baseWritingDirection` (`.auto`→`.natural`). `baseWritingDirection(for:in:)`
  returns the resolved direction; **`setBaseWritingDirection` is a deliberate no-op** — the whole-document override
  is the single manual control (per-range UIKit writes are ignored).
- **Layout.** `StyleSheet.paragraphStyle(…baseWritingDirection:)` sets `ps.baseWritingDirection` (threaded via
  `AttributedStringMapper.baseWritingDirection`; 11 call sites). `selectionFillRects(…isRTL:)` flips the
  leading/trailing physical edge for RTL lines (both engines; `isRTL:false` is byte-identical to the old LTR math).
- **Empty-paragraph caret** follows `typingWritingDirection`: `refreshEmptyBoxWritingDirections()` sets
  `BlockBox.writingDirectionOverride` on empty top-level boxes (all modes), whose `didSet` pushes
  `BlockLayoutEngine.emptyTextCaretDirection`; both engines' `caretRect(atOffset:)` return `x ≈ containerWidth-2`
  for empty + `.rightToLeft` (LTR/non-empty unchanged). Refreshed from `reload`, `becomeFirstResponder`,
  **`UITextInputMode.currentInputModeDidChangeNotification`** (so the caret re-flips live on a keyboard/globe-key
  change or first keyboard appearance), **and after every edit (the `editing {}` wrapper, added 2026-06-29)** —
  a structural edit can CREATE an empty paragraph (Enter for a new line) or EMPTY one (delete its last char),
  and without re-deriving the hint the new RTL line kept its caret on the LEFT until the next reload/refocus
  (the reported "empty line cursor on the left" bug). The in-`editing` call is empty-box-only work (`restyle`
  no-ops on empty storage) and the `writingDirectionOverride != desired` guard makes it a cheap no-op when no
  box changed emptiness. Regression-guarded by `RTLEmptyLineCaretTests`.
- **LOAD-BEARING (TK2) — the non-empty caret uses the `.selection` text segment, NOT `.standard`** (2026-06-29,
  `BlockLayout.caretRect(atOffset:)`). For an RTL paragraph the `.standard` segment reports the caret x in a
  non-right-aligned coordinate (text measured from a left origin), so it sits left of the glyphs by the line's
  right-alignment displacement and — the headline symptom — **FREEZES the end-of-text caret on a wrapped RTL line**
  (it doesn't track the text growing leftward as you type past the first line). `.selection` is the glyph-accurate
  geometry the selection wash already trusts (`selectionRects`/`selectionFillRects`); for a zero-width (caret)
  range it returns a zero-width segment at the true insertion point. **LTR is byte-identical** (the two segment
  types agree there), so this only moves the RTL caret. Regression-guarded by `RTLCaretTrackingTests` (caret tracks
  leftward while typing on line 2; caret-at-0 sits at the container right edge = the rendered glyph edge; interior
  caret sits on the glyph boundary). **`BlockLayoutTK1` (iOS 13–15) got the matching fix (2026-06-29):** its
  `caretRect` placed the caret at the glyph's LTR pen origin (`location.x`) for every offset and the last glyph's
  INK right edge at end-of-text — both wrong for RTL (the caret sat a glyph off and the end caret overshot the
  container / jumped on trailing spaces). It now places the caret on the **direction-correct edge of the glyph's
  ADVANCE (enclosing) box** — leading edge before a char (`minX` LTR / `maxX` RTL), trailing edge at end
  (`maxX` LTR / `minX` RTL). Direction comes from `resolvedCaretDirection()` (forced override baked in the
  paragraph style; `.natural` → `baseDirection` content detection), cached per `renderVersion` since
  `closestOffset` calls `caretRect` per offset. `TK1RTLCaretTests` pins TK1 to TK2 at every offset (RTL + LTR).
  Limitation (shared with TK2's first-run heuristic): a paragraph mixing an embedded opposite-direction run is
  positioned by its base direction. The running app uses TK2 on iOS 16+; TK1 is the iOS 13–15 / `forceTextKit1` path.
- **Façade + host.** `RichTextEditorView.layoutDirectionOverride` (modeled like `theme`; round-trips through
  `document`). `RichTextAttachmentScreen` has an Auto/LTR/RTL action-bar control; the chat composer relies on
  auto-detect (no manual toggle this round).
- **LOAD-BEARING — font FAMILY is display-only and must NOT round-trip.** `NSTextStorage` font-fixing substitutes a
  script font into a run's `.font` **in storage** when the style font can't render the glyphs (Arabic/Hebrew/CJK).
  `characterAttributes(from:)` must therefore **not** capture `fontFamily` from the rendered font — it once did, so
  the substituted family round-tripped and the font visibly changed on a backspace **merge** (`mergeParagraphsOutcome` →
  `currentParagraph()`). Font **size** IS still pinned on read-back (the 15pt table-cell round-trip needs it);
  bold/italic round-trip via font traits; forward `font(for:)` still honors an explicit import-set `fontFamily`.
- **LOAD-BEARING — bold is a user-intent MARKER (`.rtBold`), not the rendered trait (2026-06-29).** The iOS
  **"Bold Text" accessibility setting** stamps `.traitBold` onto the script font TextKit substitutes for Arabic/
  Hebrew/CJK (verified: under the setting `systemFont` itself stays non-bold, so Latin is fine, but the
  substituted `.SF Arabic` is `.traitBold` whether or not the user bolded — the rendered font alone can't tell
  user-bold from ambient-bold). So model bold rides a private render-only `NSAttributedString.Key` **`.rtBold`**
  (the `rtInlineCode`/`rtSpoiler` precedent): set by the forward mapper (`attributes(for:)`) + `toggleBold`, read
  by `characterAttributes` + `rangeIsBold` — decoupling model bold from the ambiguous font trait. **Marker-less**
  storage (e.g. an RTF-imported `NSAttributedString`) falls back to the **ambient-stripped** `.traitBold`
  (`boldIsAmbient`: re-substitute the non-bold style base for the run's `text` via `CTFontCreateForString` — which
  matches TextKit's fixing — and if THAT is also bold, drop `ca.bold`; `runs(from:)` passes the run text). Never
  persisted to the Core model (read back to `CharacterAttributes.bold`). Without this, backspace-merging an Arabic
  line under Bold Text baked `bold=true` into the model ("the whole previous line becomes bold") AND the toolbar
  toggle couldn't apply persistent bold to a substituted script (it read the ambient trait, so the first tap
  *removed* bold). Guarded by `RTLBoldReadbackTests`. **Limitation:** under Bold Text the OS erases the
  user-vs-ambient distinction in the *rendered* font, so a bold toggle on a substituted script may not visibly
  change on-screen — the *model* is correct (what a sent message carries).
- **Deferred:** gutter-ornament mirroring (list markers / quote bar / checklist / indents to the right gutter),
  table-column direction, a composer override UI, and mapping the override → rich-message `InstantPage.rtl`.

## Text checking — native `UITextCheckingController` engine (rewritten 2026-07-14; supersedes the public-`UITextChecker` pass)

Spelling + **grammar** underlines + tap-to-fix + **autocorrect-revert**, driven by iOS's **private**
`UITextCheckingController` hosted with the **canvas as its client**, with our **own-drawn** underline. This
**replaced** the earlier public-`UITextChecker` pass (2026-07-12): that engine (`SpellChecking`/
`UITextCheckerAdapter`/`runSpellCheckPass`/`scheduleSpellCheck`/`resolveSpellLanguage`) is **deleted**; the
rendering, `spellResults` store, and tap-to-fix menu are **reused**. Default **on**
(`RichTextEditorView.isSpellCheckingEnabled`, gates `spellCheckingType`).

**⚠️ SHIPS PRIVATE API IN RELEASE, by owner decision.** `UITextCheckingController` is resolved via
`NSClassFromString` — App Store Guideline **2.5.1** risk (a static binary scan for the private class/selector
*strings* can bounce the whole app submission). Mitigation: every private symbol WE **send** (the class name, the
selectors we call — `initWithClient:`/`preheatTextChecker`/`checkSpellingForWordInRange:`/
`checkGrammarForSentenceInRange:onPause:`/`invalidate` — and the `NSTextAlternatives*` attribute keys + KVC
accessors) is **obfuscated** (XOR-0x5A byte arrays decoded at runtime, `ObfuscatedStrings` in
`NativeTextChecking.swift`). **No fallback** — if the class won't resolve (future iOS), checking is simply off.
All private-API *dispatch* is **confined to `NativeTextChecking.swift`**. **Residual, unavoidable plaintext:** the
private `UITextChecking` **client-protocol** selectors the controller **calls back on us** —
`@objc(replaceRange:withAnnotatedString:relativeReplacementRange:)` / `@objc(removeAnnotation:forRange:)` /
`@objc(annotatedSubstringForRange:)` / `validAnnotations` in `DocumentCanvasView+NativeTextCheckingClient.swift`
— MUST keep their exact fixed selector names (the controller messages them by name), so they land in the binary's
`__objc_methname` as plaintext and can't be obfuscated on a Swift `@objc` method. So the obfuscation covers the
*sent* surface, not the *vended* client selectors; a thorough scanner could still recognize the client-protocol
conformance. (`smart*Type` are public `UITextInputTraits`; `nativeTextRangeForGlobalLocation:length:` is our own.)

**RE + driving model (the plan's original driving was WRONG — verified live via disassembly + a sim probe):**
- The controller's `didChange*`/`consider*`/`inserted*` **notify methods are no-op stubs** on modern iOS
  (`considerTextCheckingForRange:` = bare `ret`). Real driving is **synchronous per-word
  `checkSpellingForWordInRange:`** (`NativeTextChecker.checkSpellingForWord`) + per-sentence
  `checkGrammarForSentenceInRange:onPause:`, from `driveNativeChecking()` — word/sentence-enumerated via
  `NSString.enumerateSubstrings(.byWords/.bySentences)`, debounced ~0.35s, rebuilding each region's flags.
- `-textChecker` is **lazy + async** (`_initWithAsynchronousLoading:1`, nil until `_doneLoading`) → `preheat()`
  then let the runloop spin.
- **Bridging (LOAD-BEARING):** the controller reads text via the canvas's public `UITextInput` methods, but
  driving needs a `UITextRange` from a global offset. `perform(_:with:with:)` would box the scalar offset as a
  pointer (garbage), and `positionFromPosition:offset:` is relative to `beginningOfDocument` (global **1** on this
  1-based axis → off-by-one). Fixed by a canvas converter `nativeTextRangeForGlobalLocation:length:` (wraps
  `DocumentTextPosition` directly) called through an **IMP cast** (`@convention(c)`).

**Delivery + translation.** The controller flags a range by calling back the client's
`replaceRange:withAnnotatedString:relativeReplacementRange:` with an `NSTextAlternativesDisplayStyle` attribute
(and `NSTextAlternatives` for a correction), and `removeAnnotation:forRange:` to clear. `nativeReplace` translates
the global `DocumentTextRange` → region-local (`clampedSpellRegionLocal`, shared with the stash — **clamps to the
region**, since a grammar range can span a boundary and overrun `enumerateAttributes`) → `spellResults[BlockID]`
(now `[(range, style)]`). **Style** (`SpellStyle` .spelling/.grammar/.correction) from `style(from:)`: alternatives
present ⇒ `.correction`; `NSTextAlternativesDisplayStyle == 2` (live-observed) ⇒ `.spelling`; else ⇒ `.grammar`.
- **Style-aware render:** `drawSpellingUnderlines`/`drawCellSpelling` group flags by style and stroke each with its
  themed color — `misspellingUnderline` (red) / `grammarUnderline` (green) / `correctionUnderline` (blue).
- **Tap-to-fix guesses** come by style: `.spelling`/`.grammar` from a **public `UITextChecker.guesses`** call
  (candidate lookup only — the checking PASS stays native; the deleted `SpellChecking` seam was NOT re-added);
  `.correction` from the stashed `NSTextAlternatives` (read via guarded KVC on the delivered instance —
  `alternativeStrings`/`primaryString`). A `.correction` also offers **"Revert to '<original>'"**
  (`pendingSpellingMenu.revertTo` → `applySpellingReplacement(primary)`, one undo step).

**Runtime status (2026-07-14):** spelling is **live-proven** — `NativeTextCheckingLiveTests` drives a real
`DocumentCanvasView` client and the controller flags `{0,6}`+`{7,5}` for "helllo wrold today" ("today" not
flagged). Full Bazel build green; SwiftPM suite green (1392, incl. `NativeTextChecking*Tests` + the reused
`SpellCheck*Tests`); app smoke-launch stable with native checking wired. **Grammar + correction are UNVERIFIED
in-app:** grammar checking did NOT fire in the unit-test host (OS-grammar-service-dependent/async), and corrections
are keyboard-driven — both are ready infrastructure, to confirm **on-device**. Also **the sim test account's chat
composer is the LEGACY `UITextView` input** (RTE not active there), so there is no in-composer visual confirmation
yet — verify via an RTE-active composer (`ios_rich_input_mode = 1`, or content the legacy field cannot hold) or the attachment editor.

- **Exclusions** (`isExcludedSpellRange`, applied in `clampedSpellRegionLocal`): a flagged range overlapping a `.link` / `.rtInlineCode` / **`.rtSpoiler`**
  run, the active IME `markedRange` (clamped to the region), or the caret's in-progress word is dropped. Emoji/
  spoiler `U+FFFC` atoms are word boundaries so never inside a flagged word. **`.rtSpoiler` MUST stay excluded** —
  else a squiggle draws over hidden-spoiler dust and leaks the word (found in final review).
- **Own-drawn, both TextKit engines.** Rects come from the shared `selectionRects`/`layout.selectionRects` (no
  TK2-only API). Body/caption/quote/list draw via `drawSpellingUnderlines(in:)` in `SelectionHighlightView.draw`
  (filtered `!isInsideTable`); **table cells** draw via `drawCellSpelling(in:)` in the per-table `CellSelectionView`
  (rides horizontal scroll). Color: `RichTextEditorTheme.misspellingUnderline` (default `.systemRed`).
  **LOAD-BEARING:** `drawCellSpelling` mirrors `drawCellSelection`'s `-box.blockViewFrame.origin` translate + raw
  `region.canvasOrigin` (NOT `canvas.selectionRects`, which subtracts scroll → double-count). `drawCellSelection`
  had to gain a `saveGState`/`restoreGState` bracket around its own translate — once a second draw call
  (`drawCellSpelling`) chained after it in the same context, its un-popped CTM double-translated the underline
  (invisible for any off-origin table). Any future third draw in that overlay must keep every drawer GState-balanced.
- **Tap-to-fix.** `misspelledWord(atCanvasPoint:)` (unfiltered for tables — `selectionRects` folds cell h-scroll,
  so tap-to-fix works in cells too) → `beginSpellingCorrection` selects the word (reuses `applySelection` for the
  `onSelectionChange` + input-delegate bracket) and clears any stale `tableSelection` (**after** the hit-guard, so
  a stray Backspace can't then delete table rows), sets `pendingSpellingMenu`, presents the menu. The iOS-16
  `menuFor` short-circuits to the guesses `UIMenu` when `pendingSpellingMenu != nil` (bypasses the host
  `contextMenuItemsProvider`); iOS 13–15 uses `UIMenuController` + fixed `spellGuess0…3` selectors. Replace =
  `editing { applySelectionReplaceOutcome(...) }` (one undo step) then re-check. Gated on `wasFirstResponder` (a focusing
  tap only places the caret). `pendingSpellingMenu` cleared at the top of `dismissEditMenuForSelectionOrTextChange`.
- **Display-only** — nothing spell-related enters `Document`; **no `RichTextEditorCore` change**.
- **LOAD-BEARING (kept from the public feature):** `drawCellSpelling` mirrors `drawCellSelection`'s
  `-box.blockViewFrame.origin` translate + raw `region.canvasOrigin` (NOT `canvas.selectionRects`, which subtracts
  scroll); `drawCellSelection` keeps its `saveGState`/`restoreGState` bracket so its CTM translate doesn't
  double-translate the chained `drawCellSpelling`. `.rtSpoiler` MUST stay excluded (else a squiggle leaks a hidden
  word). The global position axis is **1-based** (first paragraph `textStart == 1`).
- **On-device / follow-up verification (non-blocking):** confirm grammar underlines fire on a real device (green,
  `.grammar`) + the `.correction`/autocorrect-revert path (blue + Revert) with a live autocorrection; confirm the
  in-composer visual with an RTE-active composer. Async-grammar staleness (a late grammar callback landing after a
  newer edit rebuilt the region — bounded/non-crashing via the clamp, self-corrects next edit); UITextChecker
  cold-start may leave the FIRST tap-to-fix guesses empty (separate engine from the native preheat); the
  `.correction` stash + revert are best-effort infra. Minor cleanups: share the `stashedAlternatives` lookup
  between `spellingGuesses`/`revertTarget`; `if let` the legacy `revertTo!`. Spec/plan:
  `docs/superpowers/{specs/2026-07-14-richtext-native-textchecking-design.md,plans/2026-07-14-richtext-native-textchecking.md}`;
  the RE + spike record is the `project_uitextcheckingcontroller_spike` memory.

## R7 tables in the InputDec engine editor (2026-09-04)

`.table` round-trips as a container owning one engine block per cell (`EngineBlockRole.tableCell`),
placed by the host through the engine's `blockFrames` — a placed RUN shares an anchor; `blockInsets`
apply inside a placed frame except `bottom`, which extends the run — on a grid `EngineTableGrid` solves
with the legacy box's numbers (proportional `ColumnSpec` widths floored at 100, 6/14 paddings halved
when `compact`, spans via `TableMap`). Two synchronous passes in `layoutSubviews` (`syncTableFrames`:
columns on the document set, rows from the engine's used heights). A cell's newline is `U+2028` in the
engine and `\n` in the model — the engine raises on an interior `U+000A`. Return moves to the next cell
(decided at the surface gate before the controller edits: a caret move, no undo step). **Past the LAST
cell it asks whether the next role is a SIBLING of the table — still inside the table's own container,
and not that container's own line — never merely whether a next role exists.** That question was wrong
twice: a quote's AUTHOR line answered "yes" and parked the caret in the quote's own field, and the
block FOLLOWING a details answered "yes" for a table that was the details' last body item, so Return
jumped out of the block instead of adding a paragraph — but only when something followed the details,
since with nothing after it the index ran off the end and the right branch was taken by accident,
which is what made it read as a details bug. Tab is the same rule's other door
(`moveCaretToNextTableCell` calls the same function), so it had the same defect and took the same fix.
Shift+Return (hardware) inserts a newline; backspace at a cell start travels; a replacement across cells is
re-issued per cell at the gate as one edit. A wide table scrolls inside an engine-owned
scroll view whose content view hosts the chrome (`TableChromeView`), the custom-emoji and dust
overlays — one surface, as legacy's `TableBackingView`; a document set replaces only the span that
differs, so the run's scroll view and its offset survive one. The caret's vertical crossing between
blocks is by document order upstream, so
the engine's snapshot source gained an optional geometric answer for placed runs. Tier C (row/column
verbs, rectangular selection, renderer-parity columns) is still open; `insertTable` is the one verb
in.

## R7 lists in the InputDec engine editor (2026-09-04)

List markers are **host-positioned views in the gutter**, not text
(`+ListMarkers.swift`). The shared mapper already reserves the space —
`StyleSheet.paragraphStyle(list:)` indents a list item — so before this the engine editor rendered a
correctly indented list beside an empty gutter, which is what a device pass reported.

Neither seam that carries this editor's other non-text decoration can draw one: `displayDecorator`
returns an `NSAttributedString`, so it only restyles text that already exists. And putting the marker
IN the text would shift every canonical offset after it — a role is structure only, so the engine's
text is the one copy of the characters, and selection, the flat geometry and every surface-gate rule
are measured on those offsets. So a marker is pooled per list block, positioned from
`id_frameForBlock(at:)` and parented into the engine's scroll content, exactly like the container
bands.

Load-bearing details, each of which the first cut got wrong until the legacy path was read:

- **Geometry agrees with legacy by construction, not by copying.** The marker hangs at
  `listIndentStep * level` from the block's leading edge and its line box starts at the text's TOP.
  That second one holds only because both editors lay out on the V2 contract, where
  `RichTextRenderMetrics.firstBaselineFromTop(font) == font.ascender` — which reduces legacy's
  `textOrigin.y + baselineFromTop - ascender` to the text top exactly.
- **The touch target is inflated to ≥30pt** (`EngineListMarkerGeometry.touchTarget`), mirroring
  `DocumentCanvasView.checklistBox(atCanvasPoint:)`. A drawn checkbox is ~17pt at body size; sizing
  the hit test to the drawn box makes a checkbox that ignores most taps aimed at it. The host's
  checkbox is wrapped in `ListCheckboxHostView` for this — the editor cannot override
  `point(inside:)` on a view someone else supplied.
- **A checklist is tappable with or without a host provider.** With none it falls back to Core's own
  `☐`/`☑` glyph, drawn and hit-tested the same way, so whether a box can be ticked never depends on
  the host's configuration (legacy hit-tests the marker rect either way).
- **Ticking goes through `adoptRolePlan`, never a document set.** Structure changed and no text did,
  which is exactly what that primitive is for; a document set would rebuild every role for one flag.
  (It USED to matter far more: a structural repair cleared the whole undo history, so ticking a box
  through one discarded the user's typing. The editor owns its stack now and nothing clears it.)
- **Table cells are deliberately unmarked**, matching legacy's `stampListMarkers`.

Numbering is Core's `ListNumbering.labels`, fed from `currentRoles` alone so a layout pass
materialises no text; a container contributes no membership and therefore ENDS a numbered run. Note
Core's `labels` does NOT read `style` today, so the quote-as-its-own-numbering-scope behaviour this
file claims elsewhere is not in the current implementation — both editors share whatever Core does,
which is the property that matters.

## R7 media in the InputDec engine editor (2026-09-05)

`.media` round-trips as an ATTACHMENT ATOM — one `U+FFFC` carrying a `MediaTextAttachment` whose
bounds are computed from the proposed line fragment on every layout (height from
`MediaSlotGeometry` at legacy's canvas width, the line plus the bleed; width clamped to the line) —
plus, for image/video/location, a caption line `.secondary(kind: .mediaCaption)` identified
`<id>#caption`, rendered `.caption` centred and read back at `.caption` so no size is pinned.
Audio and document have no caption line. The hosted view (`+MediaHosting.swift`) sits on
`id_attachmentFrame`, widened by `mediaBlockStyle.horizontalBleed` when the slot spans the line,
pooled by block id with legacy's items signature, culled 50pt off-screen.

Load-bearing, each of which a first cut got wrong:

- **The attachment is value-equal**, for ONE consumer: the document setter's differing-span diff,
  which compares rendered blocks with `NSAttributedString.isEqual`. `NSTextAttachment` compares by
  pointer, so without this every media block would read as changed on every set, dragging its
  caption's engine identity into the replaced span and losing a caret in the caption. `.attachment`
  is deliberately not a presentation key: settle never rewrites it, which is why `insertMedia` and
  `applyMediaShape` write it explicitly — so the derived-presentation guard never compares it and is
  NOT a second consumer of this equality (an earlier version of this note said it was). The emoji
  attachment still compares by pointer — a known gap, not fixed here.
- **Backspace on media is TWO steps** (product decision, diverging from legacy): after the atom, at
  the caption's start, and a tap on the poster all SELECT the atom (the host draws legacy's tint;
  UIKit's native highlight is not relied on over a hosted view); the next Backspace drops atom and
  caption through `replaceAcrossBlocks`'s covered-container rule. The discriminator is the
  PRE-EDIT selection, read at the first-refusal handler. Both doors (`consumeBackspaceAtMediaUnit`,
  the gate's join range) reach one function. A SEPARATE rule (§5.5,
  `applyBackspaceAtStartOfBlockAfterMediaUnit`) covers Backspace at the START of the block that
  follows a unit: the caret always travels to the caption's end (or past a caption-less atom), but
  the block it travelled from is deleted only when it is an empty STANDALONE PARAGRAPH — a table
  cell, a code block's language line, or a quote's first child sitting right after a unit travels
  but is never removed positionally out of the container that still declares it.
- **`insertMedia`/`insertDocument` place the unit against the caret's whole CONTAINER SPAN**, not
  the engine block the caret happens to sit in: offset 0 of the span inserts before the whole
  container, anything else inserts after it — never between a container's own lines. A caret inside
  a code block's body or a pull quote's body is measured against `containerSpan(containing:)`, so
  the unit never lands between a code block's language line and its body (which would orphan the
  code, and once `settleLanguageLinePresence` re-mints a language line the merge in
  `EngineBlockRole.document` takes the LAST line — silently dropping the language the user typed)
  or between a pull quote's body and its author line.
- **A range that enters a unit keeps its atom.** Coverage for media counts the caption: covered =
  atom inside the range and no caption text surviving. A partly covered unit is re-issued as its
  outside part plus its caption clip (`truncateAroundMediaUnits`), the atom never touched — legacy's
  keep-and-truncate.
- **The atom's stops are never typed into.** Offset 0 opens a paragraph above; offset 1 is the
  caption's offset 0 (or a paragraph below a caption-less kind). A bypass path (dictation) that
  lands text beside the attachment is rescued at settle (`settleMediaAtomIntegrity`), and a
  captioned atom's caption line is kept present (`settleCaptionLinePresence`) — the forward pass and
  settle must agree or a set and an edit disagree about one document. The gate and all three settle
  rules dispatch on the atom's KIND (`MediaShape.isCaptionless`), never on whether a caption line
  happens to exist — the two disagree in exactly the damaged states these rules exist to repair —
  and share one insertion point, `insertCaptionLine(afterAtomAt:)`, so a repaired line and a
  presence-expected line cannot come out spelled differently.
- **A fresh block at either of the atom's stops is a role problem, not a text problem** (spec §6.3;
  only a bypass path — dictation, an IME commit — can mint one, since the gate never forwards a
  newline there). At the TRAILING stop `declareFreshBlocks` rejoins it into the atom whenever the
  kind is captioned or the block is empty, and integrity moves the merged tail to the caption's
  start in the same pass; declaring it a body paragraph instead puts a paragraph BETWEEN atom and
  caption, and the adjacency-based presence rule then mints a SECOND caption line sharing one
  `captionLineID`. At the LEADING stop the controller keeps the atom's identity — and so its ROLE —
  on the block ABOVE while the ATTACHMENT travels to the fresh block below, so the two roles are
  swapped back (detected by which block carries the attachment); left alone, integrity reads the
  role-holding block as an atom whose attachment is gone and the media is lost.
- **Host commands never clear history.** Inserts are one recorded edit (`replaceFlat(adopting:)`
  + `restyleFlat` for the attachment, which cannot travel through a text edit); the ••• verbs are
  role changes with the inverse registered by identity (`applyMediaShape`). Unlike `insertTable`.
- **The ••• menu's Delete is the same drop edit as the second Backspace** (`deleteMediaBlock` calls
  the identical `replaceAcrossBlocks` covered-container rule) — and it is a DELIBERATE divergence
  from legacy: it leaves a fresh empty paragraph in the unit's place even when a sibling paragraph
  already exists, where legacy's menu delete removed the block outright. Kept as specified; costs
  one stray empty paragraph after a menu delete for a user used to legacy's behavior.
- **UIKit's interaction is refused over a media host** (`gestureRecognizerShouldBegin:` on the host
  view, the assistant's recognizers being attached to it), so a poster tap is not followed by the
  engine placing a caret. The veto EXEMPTS the host view's own `panGestureRecognizer` and
  `pinchGestureRecognizer` — the host view is itself a `UIScrollView`, and without the exemption a
  drag starting on a hosted media view could no longer scroll the editor at all. The host view's
  own tap recognizer only receives touches whose view is the host itself, or the ••• button's touch
  would be cancelled under it.
- The atom's font is 1pt (`mediaAtomFont`): the line box is the attachment's own height plus a
  descent too small to see.

## R7 nesting in the InputDec engine editor (2026-09-05)

A block quote holds any block at any depth: paragraphs and lists, code, pull quotes, media, tables,
quotes. `EngineBlockRole` is a struct of `ancestry` (the `EngineAncestor`s enclosing the engine block,
outermost first; empty at top level) and `position` (`.standalone`, `.secondary`, `.tableCell`).
**An engine block belongs to quote Q iff Q is in its ancestry** — a child, a nested container's
lines and Q's own author line alike (`secondary(owner: .blockQuote(Q), kind: .blockQuoteAuthor)` has
Q as its innermost ancestor). Spans (`span(of:around:)`), bands (one per quote in any ancestry),
spacing units, coverage and author-line presence all ask that one question. `container` /
`containerID` mean the IMMEDIATE leaf container — the block itself, a second line's owner, a cell's
table — never the quote.

Load-bearing:

- **Depth is a render input.** Text at depth d is the quote mapper's (15pt at every depth: assign,
  never multiply) indented `quoteIndent × d` in its paragraph style; a code child keeps the code face;
  a cell is PLACED and not indented; the author line's depth counts its own quote, so the top-level
  author line is at one indent as before. `probeShapeKey` carries the depth and `probeBlock` wraps the
  probe in the ancestry, so an empty nested line measures at its own indent.
- **The regroup is a stack walk** (`EngineBlockRole.document(roles:blocks:)`): open containers are
  closed while they are not a prefix of the next role's ancestry, keyed on id, so two same-id quotes
  separated by a block stay two.
- **A fresh block inherits its predecessor's ancestry**, except after a block quote's author line,
  where it takes the quote's PARENT (the Return-in-author exit). Every fresh paragraph is minted by
  `freshBodyRole(within:)`; a top-level one by `freshBodyRole()`.
- **Every exit moves one level, and belongs to the CHILD UNIT rather than to a role.** Return on an
  empty last child of Q leaves Q for Q's parent; Backspace at the start of a lone child un-quotes Q one
  level (`unwrapQuote`, shared with both commands); at the start of the first of several children the
  child is LIFTED out before Q (legacy's extraction — the engine editor used to merge it upward
  instead, so a user who learned the merge needs one more Backspace now). The Backspace exits fire for
  every child KIND — a paragraph, a code block, a pull quote — because they are keyed on the unit's
  FIRST role (a code block's always-visible language line, not its body) and the lift moves every role
  of the unit, so a code block leaves with its language line attached. A second line that is not its
  unit's first (a pull quote's author, a media caption) is INSIDE a child, never its start, and Q's own
  author line belongs to no unit: both stay walls. A cell declines outright — a table's exits are its
  own. Gated on the role's own shape being a paragraph, as they were until the final review, the exits
  fired for one child kind in four and the boundary rule admitted the keystroke instead: at the start of
  a lone quoted code block the caret stepped out of the quote and nothing else happened.
  Backspace whose previous sibling is a nested quote WITHOUT an author line is a WALL,
  same as one WITH an author line — the caret travels to the sibling's last child's end. (Spec §6.2
  originally said the author-less case merges into the last child; that mis-stated both legacy and
  this engine's actual pre-existing behaviour and was corrected in the spec 2026-09-05.) An empty
  first child is removed. Coverage is per ancestor, outermost first (`coveredUnit`), so a range wholly
  covering a nested quote drops it with its author line, and the survivor's ancestry is the longest
  common prefix of the two cut edges.
- **Author-line presence settles every quote whose line is wrong in one pass** (typing into an empty
  quote inside an empty quote gives both their lines); the forward pass and settle must agree about
  what a quote HOLDS. That test was "any PRIMARY engine block within the quote is non-empty" until
  2026-09-11, when it became "does the quote hold a child that is not an empty body paragraph" — see
  "Only a body paragraph may be internally empty" below, which is also why an empty nested quote now
  gives its PARENT a line.
- **Both doors of one Backspace decide in the same order.** UIKit delivers a Backspace at a block's
  start either as a collapsed caret or as the RANGE covering the join with the block above, and every
  rule that has both is ONE function taking an index. The empty-container dissolve was reachable from
  the caret door alone, so a quote whose children were all empty dissolved through one door and merely
  merged two of those children through the other — a quote the user had just emptied survived. The
  range door now asks `applyDissolveOfEmptyContainer` first, matching
  `tgid_deleteBackwardHandler`'s order (dissolve, list, quote child). It marks `structureTouchedThisEdit`
  itself: the dissolve's CONTAINER arm rebuilds through the document setter, whose edit
  `isApplyingHostDocument` swallows, so without the mark the gate's veto path reads "nothing changed"
  and the consumer is never told (measured: 0 deliveries). The DELIVERY is each door's own — the caret
  door delivers in `dissolveEmptyContainerAtCaret`, the gate's veto path delivers for the range door —
  because a delivery left inside the shared rule lands beside the veto path's and fires `onChange`
  twice. The dissolve's LEAF arm (an empty code block, pull quote or 1x1 table becoming a paragraph)
  rebuilds through the `document` setter, which only moves the undo baseline, so it registers its own
  step (`recordUndoStepForStructuralChange`, caret at the container's start for both doors). Without
  it one ⌘Z took back the dissolve together with the edit before it (2026-10-12,
  `EngineEmptyContainerDissolveUndoTests`; the CONTAINER arm edits through the funnel and was
  already right).
- **Quote toggles**: the deepest quote every touched block shares is dissolved; otherwise the touched
  TOP-LEVEL units are wrapped (a selection across a quote and a neighbour nests it); refused from a
  cell. `touchedBlockIndices` includes an author line's own role, so tapping Quote with the caret ON a
  quote's author line toggles that quote off too — between Tasks 1 and 5 it did nothing from there;
  Task 5's toggle dissolves it, per spec §8.1. Legacy's composer nested on every tap.
  `unwrapBlockQuoteLevel` and `blockQuoteDepth` are real.
- **All three container commands register a `prepareUndoForStructuralRepair` snapshot**, like
  `insertTable` — `wrapInBlockQuote`'s wrap branch, `makeCodeBlock` and `makePullQuote`. They rebuild
  through the document setter, which sets `isApplyingHostDocument`, so `engineDidChangeDocument`
  returns early: `structureTouchedThisEdit` is never set, settle never runs, and
  `registerReplayRoleSnapshot` — the only producer of `rolesForReplay` — is never called. Undo then had
  nothing at all to pop (measured: ⌘Z after a wrap left the document exactly as the wrap made it), and
  in the shape where the engine DOES replay it would rebuild roles by identity against a
  `structureByEngineIdentity` the set had just overwritten, keeping the first block's post-wrap role
  and returning every later block as a fresh top-level paragraph — a half-wrapped document. The cost is
  the documented one — and it is now paid in full: a container command is ONE undo step and the
  history before it survives, where it used to be cleared outright. `unwrapBlockQuoteLevel`
  and the toggle's unwrap branch need none — they go through `unwrapQuote`'s real edits and settle.
- **`makeCodeBlock` / `makePullQuote` are a silent no-op anywhere inside a quote**, at any depth:
  `applyContainerCommand` resolves the touched containers at any depth but looks its two endpoints up
  in top-level `document.blocks` alone, so a nested child matches nothing and the command returns
  before it mutates (pinned by
  `EngineNestedQuoteGateTests.test_makeCodeBlockOverAQuoteChildAndATopLevelParagraphIsANoOp`). It was a
  no-op inside a quote before this rung too, by a different route, so it is not a regression — but this
  rung makes "inside a quote" the common state, so those are dead Format-menu items there. Recorded,
  not fixed; closing it means rebuilding through the roles rather than through `document.blocks`.
- **Bands nest and are re-sorted by depth every sync pass** (only when the order differs); a nested code
  band or medium is flush with the quote's inner edge and never bleeds; a nested table is solved
  `quoteIndent × depth` narrower and placed that far in.
- **A quoted table's gap above it comes from `tableGapAbove`, never from the spacing walk's rhythm gap
  or top interior on a PLACED first role.** A placed cell already consumes an inset inside its own
  frame, so charging the gap there too buried it and drifted the first row's cells 24pt apart.
  `tableGapAbove` instead sums the outermost opened quote's rhythm gap plus one top interior per
  opened quote. The two cannot be collapsed into one decision because of pass order:
  `syncTableFrames` produces the grids that `syncContainerBlockInsets` consumes, so the insets pass
  runs after the pass it would need to hand the gap to. If it ever drifts a third time, the documented
  remedy is a grid-free `EngineBlockSpacing.placedTopReservations(...)` running the same `layOut` walk
  with empty grids.
- **A quoted medium is BUILT with `horizontalBleed: 0`**, not merely hosted without a bleed — legacy
  decides it in the same place (`BlockQuoteBox` builds every nested child box with
  `horizontalBleed: 0`). Hosting without a bleed but building WITH one leaves the slot's canvas
  inflated, so the medium reserves roughly `2 × bleed × aspect` too much HEIGHT (measured: a 1000×500
  photo on a 310pt column came back `294 × 163` where its true aspect is `147`). `MediaSlotGeometry`'s
  header names the box and the engine attachment as a pair that must stay in lockstep on this.
- **Insertion lands where the caret is, at any depth** (spec §8.5, amended 2026-09-08 after the K3
  pass). `insertMedia`/`insertDocument` mint every role `.within(role.ancestry)` and stamp the atom's
  attributes at `role.containerDepth`, so a photo asked for inside a quote becomes a child of it, measured
  against the indented line. `insertTable` resolves its anchor through `Document.insertingBlock(_:after:)`,
  which descends into quotes — resolved in the top-level list, as it was, a caret inside a quote matched
  nothing and the grid was appended at the END of the document. The quote no-op these replace was legacy's
  v1 rule; it outlived the render half that this rung shipped. A caret in a CELL still places the unit after
  the whole table, and a caret on a container's second line after that container's span — container rules,
  not depth rules.
- **`.details` was the next `EngineAncestor` case and it landed** — R7-details (2026-09-08), the
  section below. This rung built in three traps on purpose for that one to discharge, all because
  they quietly assumed the only `EngineAncestor` is a quote, and all three are now gone:
  `innermostQuote` (`ancestry.last?.quote`, which read `nil` once a non-quote ancestor was innermost)
  is `innermostAncestor`; `EngineBlockSpacing.units` matched `.blockQuote` explicitly at each level
  and `interiorContributions` charged every ancestor a `quoteTopInset`/`quoteBottomInset`/
  `authorSpacing` unconditionally, and both dispatch on the ancestor's kind now. `EngineAncestor`'s
  own doc-comment claim that adding a case is "one new case and nothing else" was stale as of this
  rung and stayed stale through the next: the sites are enumerated in "R7 details" below.
  `.buttonRow` was called "the last container that traps" here, and it is not a container at all —
  it holds no child blocks, so `EngineAncestor` never gained a case for it. It was the last BLOCK
  kind that traps, and R9-buttons discharged it (2026-09-09; see "R9 buttons" below).

Deferred, recorded rather than fixed:

- ~~A quoted table's top edge overhangs its band by 7pt.~~ **FIXED** — `syncContainerDecorations`
  unions the TABLE's frame (`tableFrame(forTableAt:)`) for a placed role rather than the cell's own,
  which is its TEXT frame sitting `border 1 + padding 14` inside the grid. Measured 2026-09-08: the
  band now sits one quote interior (8pt) above the table's top and one below its bottom; with the fix
  removed the band's top lands 7pt BELOW the table's, exactly as this entry described. Pinned by
  `EngineNestedQuoteGeometryTests.test_theBandCoversAQuotedTablesRealTop`, which fails under that
  removal. The entry outlived its defect — it was still being cited as open two rungs later.
  A quoted medium never had the overhang: its frame is a text-line frame, already a band member.
- **A quoted list marker's vertical alignment carries the same pre-existing offset as a top-level
  one — but the offset now SCALES WITH DEPTH.** `syncListMarkers` adds `interiorPadding(...).top` to
  `frame.minY`, but the engine places a stacked frame AFTER that inset is reserved. `interiorPadding`
  is a SUM over every ancestor whose span starts at that role, so a list item that is the first child
  of a nested quote is 16pt low where the pre-existing top-level case was 8pt — 24pt at depth 3. Same
  fix, larger error; the magnitude is recorded here so the user's deferred alignment pass knows what it
  is correcting. The pointer comment sits at the site (`+ListMarkers.swift`, above `textTop`).

Probes (spec §9), answered by measurement, each of which cost real work to get:

- **P1 (media, Task 7) = FULL FRAGMENT.** TextKit 2 proposes a fragment at the FULL line width under a
  head indent, so the attachment must subtract the indent itself
  (`MediaTextAttachment.horizontalIndent`). Measured: without the subtraction a nested atom on a
  310pt column came back `(x 13, w 310)` against the top-level `(x 5, w 310)` — same width, hanging
  8pt off each side (centred alignment splitting the 16pt overflow); with it, `(x 21, w 294)`, maxX
  flush.
- **P2 (tables, Task 6) = FULL.** The placed run's content view sits at the engine's text origin and
  carries no indent of its own, so the indent is the host's to add — both for the cell frames and for
  the chrome, which is therefore NOT offset twice.
- **P3 (bands, Task 3) = safe.** Depth-sorting the bands every sync pass is safe (deterministic order
  plus an `elementsEqual` guard); no fallback was needed.

**Adjacent tables share ONE placed run, and each table's grid rects are relative to that run's
anchor** — so a table whose predecessor is also placed must carry the height of everything before it
in the run (`syncTableFrames`'s `runOffset`). Without it two tables are laid out from the same origin
and draw on top of each other. This shipped in R7-tables and went unseen for two rungs because the
shapes that show it are rare: it reached a user through a details whose body ends in a table, with
another table inserted after the block, where the two gaps happen to be equal and the frames coincide
EXACTLY. Two adjacent top-level tables were overlapping by 29pt the whole time — and the first test
written for it asserted only that the second table's `minY` was greater, which an overlap satisfies.
Assert `minY >= previous.maxY`, never the ordering alone.

## Derived-view completeness (2026-09-08)

**Presentation is derived from the role, and so is everything DRAWN from it.** The editor asserts
both, and the second half is newer and the one that decides whether anything appears at all:
`verifyPresentationIsDerived` says a block's ATTRIBUTES match its role and says nothing about whether
the block is on screen. A table was once in the document, in the roles, and drawn nowhere — no grid,
no chrome, no cells — with nothing anywhere reporting it, and it took a day of device round-trips to
find because every probe written for it asserted on ROLES and the roles were correct every time.

- **`EngineDerivedViewExpectation` maps roles → the key set each view pool must hold**, and
  `verifyDerivedViewsAreComplete` compares. A cell needs a grid AND chrome keyed by its table, a
  details title a chevron and a separator, every ancestor a decoration, a top-level list item a
  marker.
- **It derives its expectation from the ROLES, never from the sync pass it checks.** Each sync
  computes its own `live` set and culls against it, so comparing a pool to that set agrees with the
  producer by construction — including when the producer is wrong, which is the case this exists to
  catch: `syncTableChrome`'s `live` set is what omitted the missing table. A check that shares the
  producer's derivation is not a check, the same reason the presentation check re-renders every block
  rather than trusting what the bridge last wrote.
- **Per LAYOUT, not per settle.** The presentation check runs from settle and from the restore path,
  so a mutation reaching neither is unchecked — which is how an undo left every restored block wearing
  the presentation it had before. Every path that changes roles is followed by a layout, whatever
  route it took, so this has no such gap.
- **On pool KEYS, never on visibility.** A media host is HIDDEN when culled off-screen, not removed:
  hidden is not missing.
- **MEDIA IS DELIBERATELY EXCLUDED**, and the check is what established that — it fired on its first
  run and the reported thing was correct. A media view is host-SUPPLIED and `syncMediaViews`
  legitimately creates none when there is no provider, when the provider answers nil ("ask again next
  pass"), or when the frame is not ready. None of that is visible in the roles, and a guess would trap
  during ordinary typing in a debug build — a worse failure than the one being guarded and one the
  check would be CAUSING. The checkable half for media is the reverse direction (no pooled view
  outlives its atom), which is not this invariant.
- **`EngineDerivedViewExpectation` is a second source of truth** about which roles own which views: a
  new pool needs a field there or the check silently under-tests it. That entry is part of adding a
  pool, and joins the site list under "adding the THIRD `EngineAncestor` case" below.
- **The WIRING is pinned as well as the rule** (`derivedViewVerificationCount`). A check nothing calls
  is worth nothing, and that is not hypothetical: the details chevron had a hit-test rule, a passing
  test for it, and no caller anywhere in the app for the whole rung.

**And a host knob the editor never reads is a lie with a getter.**
`HostConfigurationConsumerTests` discovers every `public var` in the two host-configuration files and
every `public static let ...: CGFloat` on a shape and requires a reader in `Sources/`, or an exemption
with a written reason. `DeferredConfigurationRegisterTests` is its complement — that one says a member
NAMES its rung, this one says it HAS a reader — and neither could catch the other's case:
`tapBelowAddsTrailingParagraph` lived outside the register's single scanned file and its
hand-maintained member list, stored and read by nothing, defaulted `false` where legacy defaults
`true`. **What neither proves: a reader is a mention, not a call.**

## Retiring `quoteDepth` as a public affordance (2026-09-08)

`EngineBlockRole.quoteDepth` was public and its name lied: since R7-details it counts CONTAINERS, so
three separate reads that meant QUOTES silently got the wrong number the moment a details existed —
the host's quote-level control reported 1 for a caret in a top-level details, "None" un-DETAILED a
block, and the quote-sized 15pt mapper was chosen for a details' body that is in no quote at all.

It is **`containerDepth`, and `internal`**. The rename is the fix: a raw depth should be awkward to
reach and impossible to mistake for a count of quotes. Nothing outside the module ever read it — the
`quoteDepth` hits elsewhere in the repo are `InstantPageMarkdownBlockContext`'s unrelated field — so
narrowing it cost nothing.

Ask `enclosingQuoteCount`, `innermostEnclosingQuote` or `isInsideAQuote` when QUOTES are meant (they
are what the host's `blockQuoteDepth` and the quote-sized mapper actually want), and
`EngineAncestor.contentIndent(styleSheet:)` when INDENT is — **a details contributes none, so a depth
is not a width.** What legitimately wants the raw count: the spacing walk's nesting level, the
child-depth walk in `childUnits`, and "is this inside any container at all" in the bridge.

## The role next to this one is a structural question (2026-09-08)

**`currentRoles[i ± 1]` answers what is STORED next to a role; every navigation rule wants what is
next to it in the document's STRUCTURE.** The two differ at exactly one place — a container edge —
and six defects across three rungs were that difference, every one found by a person rather than a
test, because the omission is valid code that behaves correctly on every shape its author tried.

`RoleNeighbour` (`EngineRoleNeighbour.swift`) is that question, asked through `neighbour(after:)` /
`neighbour(before:)`: `.sameLeafContainer`, `.sibling`, `.ownLineOfEnclosingContainer`,
`.outsideContainer(_, beyond:)`, `.documentEdge`.

- **A `switch` over it must never carry a `default`.** The exhaustiveness IS the instrument — a rule
  that forgets a container edge fails to BUILD, and a future container kind breaks every call site
  until each has decided. A `default:` arm hands all of that back.
- **Five cases because the sites need five.** The LEAF container (the next cell of my table, a code
  block's body after its language line) is a different question from a sibling (a different child of
  my ancestor); `.ownLineOfEnclosingContainer` is its own case because forgetting a quote's author or
  a details' title is three of the six defects.
- **A TOP-LEVEL role has no enclosing container**, so `.outsideContainer` never occurs there and the
  top-level table's "Return moves into the paragraph after" falls out of the type rather than needing
  an exception. `.outsideContainer` reports the INNERMOST container only, and still reports it when
  `beyond` is nil, because a rule minting a sibling needs to know which container it is minting into.

**IT ANSWERS ABOUT A ROLE'S CONTAINER, NOT ABOUT A CONTAINER'S NEIGHBOUR, and that limit is why
`moveCaretPastDetails` does NOT use it.** That rule asks what follows the whole details. Asked from
the details' last role, the innermost ancestor may be a NESTED container — a details whose last child
is a quote reports the quote — and when the details is itself a quote's last child, the role after it
is that outer quote's author line, which the type cannot see from inside and would hand back as a
landable sibling. `roleIsOwnedLineOfAnEnclosingContainer` stays for exactly that site. A
container-relative neighbour is a different type nobody has needed twice yet.

- **What deliberately stays raw:** plan-building arithmetic (`plan.insert(at:)`), span-building loops
  (`containerSpan`'s `while`), the settle rejoin's separator choice, and `EngineBlockSpacing`'s walk,
  which has its own unit structure and no view to call. Over-abstraction is the real risk here, not
  under — a type that swallowed role surgery would make it harder to read and prevent no defect.
- **What it does NOT do:** it will not tell you whether the right answer at a boundary is mint, travel
  or wall. It forces a decision where the compiler can see one was not made.

**Two live defects were found by writing it; one was fixed and the other turned out not to be one.**
Inserting a CAPTION-LESS atom (audio, document) as a details' last body item, with a block after the
details, minted no trailing paragraph and left the caret on the block OUTSIDE the details — fixed,
since that branch exists to give such an atom somewhere to type.

**Backspace at a table's first cell travels to the container's own LEADING LINE if it has one, and
otherwise leaves the container** (decided 2026-09-08). A details has its TITLE and the caret lands at
its end; a quote has no leading line, so there is nothing inside to travel to and the caret leaves.
Both halves were already the behaviour — the `.ownLineOfEnclosingContainer` arm handles the title —
so making the type explicit turned what looked like an inconsistency into a stated rule. Pinned by
`EngineTableEditingTests.test_backspaceAtTheFirstCellOfADetailsTableJumpsToTheTitle` and
`…OfAQuotedTableLeavesTheQuote`.

**And one thing measured rather than assumed:** `applyBackspaceAtARegionBoundary` keeps BOTH its typed
test and its older ancestry test. They ask different questions — whether my container ends above me,
and whether `previous` sits in a container I am not in — and commenting the second out fails
`test_aParagraphAfterADetailsStaysOutsideItThroughBothDoors` and `test_probeRangeDoorJoinAfterADetails`.

Pinned by `EngineRoleNeighbourTests` — every case, both directions, neuter-verified by collapsing
`.sameLeafContainer` into `.sibling`, which fails exactly the three tests that distinguish them.

## One placement pass for tables (2026-09-08)

**The space above a placed table is decided once, in the branch that decides where it goes.**
`EngineBlockSpacing.layOut` cannot reserve on a placed first role — the engine applies a placed
block's `top` inset INSIDE its own frame, so reserving there moves the cell's TEXT rather than the
table — so it DIVERTS that quantity into `placedReservations` instead of skipping it and letting a
second function re-derive it. `blockInsets` is `blockLayout`, returning `(insets, placedReservations)`;
`tableGapAbove` is gone.

That re-derivation drifted four times: a quoted table's first-row cells 24pt apart, the chrome drawing
a grid on top of the table above it, two adjacent top-level tables overlapping by 29pt, and a details'
hairline drawn through the grid below it.

- **Reservations are keyed by ROLE INDEX and accumulate.** A table opening two quotes has three units
  whose `range.lowerBound` is the same role — the outer quote's, the inner quote's and the table's —
  so `+=` into one index yields the total the deleted function computed as an explicit sum. The map is
  valid for ONE layout pass and must never be stored across passes; `tablePlacements`, keyed by
  `BlockID`, is the thing that is.
- **No walk was added.** `tableGapAbove`'s own comment claimed a single owner was impossible because of
  pass order. It is not: `syncTableFrames` ALREADY calls the walk with the grids before it places, for
  the last row's bottom insets. The grid-free `placedTopReservations` that comment proposed must not be
  written. Measured over five 200-pass batches: 0.3205–0.3252 ms/layout, against 0.3259 before.
- **`TablePlacement` (dy, indent, size) is the one value both consumers read.** The chrome no longer
  derives its own indent and has NO fallback: a missing placement asserts, because guessing a plausible
  number is what let a grid draw in the wrong place while looking reasonable. The derived-view
  completeness check gains a placement row.

**The refactor was NOT fully behaviour-neutral, and the golden is what proved it.** Five of the six
`EngineTablePlacementGoldenTests` fixtures are byte-identical. The sixth — a details whose body BEGINS
with a table — moved from 16 to 14, and neither number was ever right: `tableGapAbove` charged a
TOP-LEVEL RHYTHM gap of 16 (the gap a bare table gets after a paragraph) between a details' title and
its first body child, which is not the quantity that belongs between a container's own line and its
first child. `DetailsShape.titleBodyGap` (14) is, and a paragraph in that position already got it —
the table did not, because that gap was the THIRD skip on a placed role and nothing delivered it. It is
diverted too now. Reproducing the 16 would have meant re-inventing the bug inside the new code.

**Record the corpus BEFORE touching the code, and record the wrong numbers too.** Fixture 6 was
deliberately recorded holding the defect. That is what made the disagreement visible as a
one-fixture-moved result rather than a mystery, and what let the fix's blast radius be read off the
diff. The existing geometry suites could not have done it: they assert relationships — a is left of b,
c is below a — which several wrong absolute layouts also satisfy.

**The follow-up this section originally named is already done.** "A quoted table's band overhangs its
grid's real top by 7pt" was carried forward from a deferred note that had outlived its defect: the
band already unions `tableFrame(forTableAt:)` for a placed role. Measured, and neuter-verified against
the test that guards it. Decoration therefore does NOT need to become a third `TablePlacement`
consumer — the frame it needs, it already has.

## A container's own lines are not its children (2026-09-08)

**A quote's span ENDS with its author line and a details' span BEGINS with its title**, so "the
span's first role" and "the span's last role" are not the first and last CHILD. Rules written against
that assumption broke six times across two rungs: an empty code block counted as an empty child, a
quote judged covered because its only child's atom was, a caret landing on the span's first primary
which was a table CELL, a quote's author line taken for the block after a table, and settle
destroying a folded details because its title read as an orphan.

`ContainerContents` (`+Ancestry.swift`) now owns that distinction rather than leaving it to each rule:

- **`ownedLines`** — the roles the container ITSELF owns, in span order, never children — with
  `leadingOwnedLine` (a details' title) and `trailingOwnedLine` (a quote's author) naming their
  POSITION, and `firstChildRole` / `lastChildRole` for the thing a rule usually meant when it reached
  for a span bound. A container with no children reports its single owned line as both, which is true
  of a FOLDED details: its title is the whole of its span.
- **Two emptiness answers, spelled once.** `isEmpty` (every child a bare empty direct paragraph) is
  joined by `ownedLinesAreEmpty` — a details with a TYPED TITLE is not empty however empty its body
  (details decision 5), while a quote's author is a field and never keeps one alive — and by
  `holdsContent`, which settle asks instead of scanning a span for "a primary or a details title".
  `containerOwnedContentIsEmpty` is gone; it was the second spelling.
- **`EngineBlockRole.isOwnedLine(of:)` / `isOwnedLine(_:of:)` is THE ownership test**, and it lives on
  the ROLE rather than the view so that `EngineBlockSpacing` — a free function over a roles array,
  with no view to call — uses the same one. Keyed on `containerID`, never on the kind: a CHILD's own
  second line (a code block's language, whose container is the code block) belongs to its child's
  unit. Nine hand-rolled copies of that predicate are now one.

**What deliberately still takes a raw `span(of:)`:** decoration bands, the fold's offset arithmetic,
the "role after this container" boundary, and coverage at the gate. Every one of them wants the
container as an EXTENT — which is what a span is for — and none indexes into it looking for a child.
The rule worth keeping is not "never call `span(of:)`" but **"never index a span to find a child or
an owned line"**; that is what `ContainerContents` answers. A grep-shaped ban was considered and
rejected: the honest allow-list would have run to twenty legitimate leaf-container groupings, and
this package's own `HostConfigurationConsumerTests` already records why a grep test proves little.

Pinned by `EngineContainerContentsTests`, which asserts both container kinds from both ends, the
folded-details case, and both emptiness answers — with a contrast case (an empty quote, which owns no
author line at all) proving the accessors read the document rather than returning a constant.
Author-line presence is keyed on CONTENT, not on the author text: a quote with a non-empty child
carries an author-line ROLE whether or not anybody typed an attribution, which is why that contrast
case has to use an empty quote.

## One Backspace rule table for both doors (2026-09-08)

**UIKit delivers a Backspace at a block's start two ways** — as a collapsed caret there, or as the
RANGE covering the join with the block above — and which one a device chooses is not ours to predict.
Every rule for that position therefore has two doors, and the ORDER used to live in two hand-written
lists: `tgid_deleteBackwardHandler` (the caret door) and `decideTextInput` (the gate). They drifted
three times, each found on a device one at a time, because nothing anywhere compared the two doors.

`EngineBlockRole`-indexed rules now live in ONE array, `backspaceJoinRules`
(`+BackspaceRules.swift`), which both doors walk. A rule added to it is added to both doors; there is
nowhere else to put one.

- **Every rule in the table fires at the START of the role it is given.** That is the one position
  with two deliveries, and it is the only precondition a door needs: `caret == flatOffset(ofRoleAt:
  i)` at the caret door is exactly what `rangeIsTheJoinBefore(i, range:)` says at the gate. Each rule
  owns whatever ELSE it requires — a role kind, a list membership — so a door cannot forget a guard
  and the two cannot spell one differently. The gate's redundant `listMembership` guard is gone;
  `applyBackspaceAtStartOfListItem` always owned that test.
- **One Backspace is deliberately NOT in the table**: a caret INSIDE a media atom, which selects it.
  That shape has no join counterpart BY CONSTRUCTION — a join range ends at a role start — so it is a
  property of the delivery, not an exception carved to make the table fit.
- **Delivery is the DOOR's, and the contract is a return value, not a convention.**
  `BackspaceRuleOutcome` is `.notHandled` / `.handled` / `.handledOwingADelivery`; the last means the
  rule's mutation reaches nobody (its `document =` set was swallowed by `isApplyingHostDocument`, or
  it only moved the caret), so the caret door flushes and the gate marks `structureTouchedThisEdit`
  for its veto path. Those two are the SAME statement said at two doors. A delivery written into a
  rule lands beside the door's and the same keystroke notifies twice — measured at 2 on the boundary
  rule. Consequence of unifying it: the boundary rule now delivers SYNCHRONOUSLY through the gate,
  where it used to arrive a run-loop turn later.
- **A rule must not read the caret out of `engineSelectedRange`.** It is a collapsed caret at one
  door and the join RANGE at the other, so the same rule lands the caret a position apart depending
  on the delivery. `unwrapContainer` did, and Backspace at a details title's start left the caret at
  the start of the unwrapped title through one door and at the end of the block above through the
  other; it takes an explicit `caretLanding` now, which the two Backspace rules pass and the two
  COMMANDS (which mean the live selection) leave nil. The quote-child LIFT had the sharper version of
  the same bug: it declared roles and never touched the selection at all, which at the gate left a
  live one-character SELECTION straddling the join — a Backspace that appeared to select a character
  instead of deleting one.

**The test that pins it is `EngineBackspaceDoorEquivalenceTests`**, and it is the part worth keeping:
for every rule, the same document and the same keystroke through BOTH doors must produce the same
roles, the same text AND the same caret. It found all three caret defects above on its first run.
Two traps it documents from its own history: the range door must have the selection ON the join
before the replace (UIKit always does; without it the harness drives rules with whatever selection
the document set left behind, and three rules "disagreed" by that artifact alone), and the comparison
has to be shown capable of reporting a difference or a green matrix means nothing.

## R7 details in the InputDec engine editor (2026-09-08)

A detail block is the SECOND `EngineAncestor` kind, and adding it is what turned the ancestry from
"a stack of quotes" into "a stack of containers". A details is an always-visible **title line** above
a body that a **fold** hides; both nest freely, in either order and to any depth
(`ancestry: [.blockQuote(q), .details(d), .blockQuote(q2)]` is an ordinary ancestry).

**The title is a SECONDARY REGION, like a code block's language line and a quote's author line** —
`EngineBlockRole.secondary(owner: .details(shape), line: shape.titleLineID, kind: .detailsTitle)`,
identified `"<id>#title"` so the chrome and the line are separate view-pool entries. It is the
details' own line and belongs to no child unit: `childUnits` skips a secondary whose `containerID`
is the container's own id, which is why the exits count the body's children and not the title.

Load-bearing, each of which a first cut got wrong:

- **`quoteDepth` counted CONTAINERS, and three reads meant QUOTES** (it is `containerDepth` and
  INTERNAL now — see "Retiring `quoteDepth` as a public affordance" above). `enclosingQuoteCount` drives the
  host's `blockQuoteDepth` (which reported 1 for a caret in a top-level details); `innermostEnclosingQuote`
  drives `unwrapBlockQuoteLevel` (whose "None" un-DETAILED a block) and the Quote toggle's dissolve
  branch, which still asked `common.last?.quote` — the exact `ancestry.last?.quote` shape §3.3 exists
  to eliminate — and so nested a quote instead of un-quoting from inside a quoted details; and
  `isInsideAQuote` chooses the 15pt mapper, which keyed on depth rendered a top-level details' body
  quote-sized. `probeShapeKey` carries the ancestry's KIND SEQUENCE for the same reason and one more:
  depth pins neither the face nor the indent, and `quote > quote` against `quote > details` is the
  same depth at 32pt against 16pt of indent — keyed on depth they shared one cached measurement and
  whichever was measured first gave the other its empty-line indent and typing attributes. The media
  bleed is the one place the two terms genuinely diverge: a details contributes no indent and still
  suppresses the bleed, deliberately, matching the sibling decision for the code band.
- **A container's indent is what IT contributes, never `quoteIndent x depth`.** A quote contributes
  `quoteIndent`; **a details contributes 0** — legacy indents only its TITLE's glyphs
  (`DetailsShape.titleGlyphIndent`, 26pt, a paragraph indent that leaves the title's FRAME full
  width) and its body sits flush with surrounding content. So every geometry read goes through
  `EngineAncestor.contentIndent(styleSheet:)` summed over the ancestry, and `containerDepth` survives
  only as a COUNT (how many containers, for the mapper's 15pt-at-any-depth rule and the band levels).
  Probe P1 answered COMPOSES: a quoted title indents by the quote's 16 PLUS its own 26, its body by
  the quote's 16 alone. Reading depth where indent is meant does not merely use a wrong width for a
  details — it adds an indent that must not be there at all.
- **A details' title keeps its container alive, and a FOLDED details has NOTHING ELSE.** Every rule
  that asks "does this container still have content" counts `.detailsTitle` alongside the primaries.
  Written as an exemption for a folded details' OWN title — which is how it was fixed first — it
  leaves the question asked of the PARENT unanswered: an outer details, or a quote, whose only child
  is a folded details has a span holding nothing but that folded title, and was itself collected as
  an orphan and destroyed on the next keystroke.
- **A FOLDED details is a container with NO PRIMARY, and every rule that asks "does this container
  still have content" has to know that.** Its span is exactly one role, its secondary title. Three
  rules read that as damage and had to be taught otherwise: settle's orphaned-line rule rewrote the
  title to a paragraph — dropping the `.details` ancestor and with it `foldedChildren`, the ONLY copy
  of the body — on the next keystroke ANYWHERE in the document; `containerIsCovered` filtered the
  span to primaries and so reported a folded details never covered, leaving it standing through
  Select All with the deleted body still in the model; and the boundary Backspace removed a details'
  last empty child, which leaves an EXPANDED details with no primary and hands it straight to the
  same settle rule. No fold test could see any of it: a fold goes through the document setter, whose
  edit `isApplyingHostDocument` swallows, so **settle never runs during a fold** — it takes a
  keystroke afterwards.
- **A details' TITLE is content; a quote's author is a field.** Decision 5 says so for the unwrap,
  and the same split governs two more rules: `ContainerContents.isEmpty` counts child units only, so
  the empty-container dissolve had to be guarded (insert a details, type a title, press Backspace
  once — the whole block collapsed to one empty paragraph), and coverage counts `.detailsTitle`
  alongside the primaries where it skips `.blockQuoteAuthor` and `.codeLanguage`.
- **Folding MOVES the body; it never copies it.** `DetailsShape.foldedChildren` holds the body in
  MODEL form while folded and is empty while expanded, and `flatten` emits the children only when
  `expanded`. That is model content living in a shape, which reads as a violation of "a role is
  STRUCTURE ONLY" — it is not, and the rule it actually rests on is sharper: **no TWO sources of
  truth hold the same text.** A folded body is the first content in this editor that is not editable
  — it cannot be caret-walked, selected or spell-checked, because it is not in the engine at all — so
  it has exactly one home and nothing to drift from. Do NOT "fix" it into a side table keyed by id:
  the body would then need purge-on-delete, remap-on-identity-churn and restore-on-undo, and it is
  lost by the first one that is missed. In the shape it travels with the role through plans, the
  regroup, the identity map and the undo replay snapshot for free. It is also deliberately NOT a
  presentation key (`probeShapeKey` ignores it), or two details differing only in what they have
  folded away would measure differently.
- **The toggle rebuilds through the DOCUMENT** (`setExpanded`): the model already holds the body in
  whichever place the state says, so flipping `expanded` and re-setting the document moves it across
  and `flatten` decides what reaches the engine. A caret in the body lands at the END of the title on
  a fold — the body is about to stop existing on the engine's axis.
- **The regroup opens and closes ancestry for EVERY role, and only primaries contribute a child.**
  A folded details' ONLY role is its secondary title, so a regroup driven by primary roles alone read
  such a document as EMPTY and crashed on the next index. `EngineBlockRole.document` now walks every
  role: close while the open stack is not a prefix of this role's ancestry, open the rest, then
  `continue` for a secondary.
- **`ContainerContents` / `childUnits` is the ONLY child enumeration.** A rule that filters a span by
  `secondaryKind == nil` and treats each survivor as a child is asking about ROLES, and that was the
  single cause of four device defects in R7-nesting. The empty-container test asks per CHILD UNIT,
  each unit must be a direct child (`innermostAncestor?.id == id`), and its shape must be a paragraph.
- **Three rules keyed on `.blockQuoteAuthor` BY NAME and had to key on ownership instead**
  (`EngineBlockRole.isOwnedByAnAncestorContainer`): `settleOrphanedSecondaryLines`, `coveredUnit`'s
  leaf test, and the ancestry walk. The settle one is the instructive failure — it rewrote every
  title to a body paragraph on EVERY settle, with the strings unchanged, so it read as a gate bug.
- **`unwrapContainer` is shared by both kinds and they differ in ONE place**: a quote's author line
  is DROPPED (an attribution is metadata about a container that no longer exists) while a details'
  title SURVIVES as an ordinary paragraph (it is the heading the user typed) — decision 5.
- **The gate's exits.** Return in the title moves into the body and inserts nothing (a language
  line's rule exactly); Return on the empty last child leaves the details for its parent. Backspace
  at the start of the title unwraps one level; at the start of the FIRST BODY CHILD it is a WALL and
  the caret travels to the title's end — the block above a details' body is a heading, not text to
  merge into. A wholly empty details un-details in place. The `.details` arm is checked
  INNERMOST-first, ahead of the outermost-first quote walk, and both doors of every one of these
  reach one function taking an index.
- **A details draws ONE HAIRLINE and no band** — `ContainerDecorationKind.detailsSeparator`, 0.5pt at
  the bottom of its span in BOTH states. Probe P2 answered that the band's union gives the column
  only BY ACCIDENT (every ordinary child returns a full-width text frame), so the hairline's x and
  width are pinned to the column at the details' own level; a details holding only a table would
  otherwise get a hairline hugging the grid.
- **The chevron IS the interaction** (spec §8.2), so it carries its own tap, like the list checkbox —
  and `textInteractionMayBegin` refuses over it, like a media host, so the tap is the fold's and not
  also a caret placement. The tapped VIEW does not decide which details folds: the action re-resolves
  the point through `detailsChevron(at:)`, which is hit-tested DEEPEST-FIRST (legacy's rule) with a
  +-12pt slop, because the view pool's z-order is insertion order and says nothing about nesting.
  Geometry is `DetailsShape.chevronSize` 18 at `chevronLeadingInset` 3 from the content's leading
  edge; `detailsChevronImage` falls back to `drawnChevron`, so a details is foldable whether or not a
  host configures one. `textInteractionMayBegin` refuses over the chevron's OWN box and not the
  inflated target: inflated by the full 12pt the refusal reached 4pt past the title's first glyph — a
  tap on the title's first character folded the block instead of placing a caret — and 21pt above the
  title's centre, into a block the details does not contain. Inside the slop but outside the box a tap
  both folds and places a caret, which is the harmless direction. **This was wired only at the end of the rung** — the view was built
  `isUserInteractionEnabled = false` under a comment claiming a canvas gesture consulted
  `detailsChevron(at:)`, there was no such gesture, and the rung's headline capability was
  unreachable outside XCTest while a geometry test pinned a rule nothing invoked.
- **The top inset is the SAME in both states** (`DetailsShape.topInset` 6), deliberately, so the
  title and chevron do not move when folding; only the bottom differs (16 expanded / 17 folded), and
  the first body block hangs `titleBodyGap` 14 below the title.
- **A container's own line is not a child, and the boundary Backspace is a WALL at BOTH doors.**
  `consumeBackspaceAtARegionBoundary` is the caret door; `applyBackspaceAtARegionBoundary(at:)` is the
  rule, and the gate asks it as the last of its five before falling through to `replaceAcrossBlocks`.
  Missing there, the same keystroke MERGED where the caret door walled: a details' first body child
  was pulled up into its TITLE ("Notesone"), and when that child was the details' only one and empty
  the container was left with no children at all. The rule also declines to remove the empty
  paragraph it travels from when that paragraph is its container's only child
  (`isTheOnlyChildOfItsContainer`) — the bridge mints a rescue child on the next flatten anyway.
  **The DELIVERY is each door's**, as it is for the dissolve: the caret door flushes on a true
  result, and at the gate the structural arm's notification comes from the veto path (structure
  changed) while the wall arm's comes from the caret's own selection change. Left inside the shared
  rule — which is where it was, correctly, while the rule had one door — it landed beside the veto
  path's and the same keystroke notified twice. Measured at 2, and the first of the two was also
  PRE-SETTLE: the rule's `performHostStructuralEdit` degenerates to a bare body at the gate, so a
  consumer reading `document` from it sees one `normalisePresentation` has not touched.
- **`EngineBlockSpacing`'s container branch keys on the ANCESTOR, not on `unit.quote`.** Keyed on the
  quote — which is nil for a details — a details unit fell through to a `default: break`, so none of
  those insets ever reached `blockInsets` AND `layOut` never recursed into the details' children at
  all: a quote inside one got no interior, a code block no padding, a table's cells no text insets.
  The hairline was then drawn 16pt below the last body block in space nothing had reserved,
  overlapping whatever followed. `test_theTitleDoesNotMoveWhenFolding` could not catch it — the top
  inset was applied in NEITHER state, so the comparison was trivially satisfied. Two deposits are
  PLACED-aware, like every other table arm in that file: BOTH bottoms spread over the last row's cells
  through `deposit(bottom:)` — the container's own interior and the level-0 trailing gap, which a
  details reaches because its span's last role can be a table's final cell where a quote's is always
  its author line — and the title gap is skipped when the first body block is a table, because the
  engine applies an inset INSIDE a placed frame and it would move the cell's text rather than the
  table. **Recorded, not fixed: a details whose first body block is a table therefore has no
  title-to-body gap.** The remedy is `tableGapAbove` learning the details' contributions, and this
  file's own history says spelling that decision twice is how the last 24pt drift happened.
- **`insertDetailsBlock` places through the DOCUMENT, not a role plan** — `insertTable`'s and
  `insertMediaBlock`'s family (empty caret paragraph replaced, mid-paragraph split, offset 0 before,
  otherwise after; before/after measured against the whole CONTAINER). The set re-flattens, so every
  minted block takes the ancestry its position in the tree implies and decision 3 falls out: a
  details asked for inside a quote, or inside another details, becomes a child of it. Like
  `insertTable`, it is one undo step (`recordUndoStepForStructuralChange`) — which used to mean
  clearing the history and no longer does.
- **The four `EngineDocumentTree` walks reach into any container**, through one shared pair
  `ancestryChildren` / `replacingAncestryChildren`. They said "quotes only" while a details body was
  out of reach; that also made `setExpanded` a silent no-op for a details nested in another details.
  A table's cells stay out of the pair on purpose: a cell's role names the TABLE as its container, so
  a block in a cell is never one of the `containerID`s these walks are handed.

**Adding the THIRD `EngineAncestor` case is not one case.** `EngineAncestor`'s doc comment used to
claim it was; R7-nesting made that stale and this rung kept it stale. The sites are: `contentIndent`,
`EngineBlockSpacing.interiorContributions` (per-kind interiors), `EngineBlockSpacing.spacingKind`
(which rhythm the container takes — a details borrows the block quote's), `leafInteriorPadding`,
`Block.ancestryChildren` / `replacingAncestryChildren`, `ContainerDecorationKind` and its derivation
in the decoration pass, `EngineDerivedViewExpectation` (a container that owns a view owns a field
there, or the completeness check silently stops checking it), `EngineDocumentBridge.flatten` and `render(role:)`, `unwrapContainer`'s
owned-line arm, `EngineDocumentBridge.probeShapeKey` (whose ancestry component is a per-kind
`"q"`/`"d"` map and would silently label a third kind `"q"`, re-creating the cache collision it
exists to prevent), and `SecondaryRegionKind` plus `isOwnedByAnAncestorContainer` if the new
container owns a line of its own.

## R9 buttons in the InputDec engine editor (2026-09-09)

The last `richTextEngineUnimplemented` trap. `Block.buttonRow` was a `preconditionFailure` in
`EngineDocumentBridge`, so **any document holding a button row crashed the editor on a document
SET** — not on an authoring verb — while `RichTextAttachmentScreen` already wired all four host
hooks. Both halves of R9-buttons landed together: block-level rows and inline `textButton` pills.

**A button row is NOT a container**, whatever the older notes said. `ButtonRowBlock` has
`buttons: [ButtonRef]` and an `alignment` and no child blocks, so `EngineAncestor` gained nothing
and no ancestry, indent, band or unwrap rule changed. It is a fifth `EngineBlockShape`.

**The row is ONE attachment character, and that is forced rather than chosen.**
`richTextPackButtonRow` stretches pills to fill the width under `.justify` and wraps at
`maximumButtonsPerRow`, and it is pinned to the V2 renderer by `RichTextV2ButtonParityTests`. One
attachment per pill would hand line-breaking to TextKit and lose both. So the row follows the media
atom: `ButtonRowTextAttachment` with dynamic bounds, a hosted `RichTextButtonRowView` over the frame
TextKit gives it. Legacy's per-pill caret atoms have no equivalent here and are not needed — a pill
is targeted by hit-testing, which is how legacy resolves it too.

**`ButtonRowShape` carries the WHOLE model**, because a row owns no text: its labels are chrome.
It is the only shape whose `block(runs:)` ignores its runs entirely — even `.media` has a caption
line to take them from. Every pill-level edit is therefore a SHAPE REWRITE through
`applyButtonRowShape`, `applyMediaShape`'s pattern.

**The packing seam is a public file OUTSIDE `Canvas/`.** `richTextPackButtonRow`, `ButtonPillView`
and `ButtonRowMenuPillView` are internal and live under `Canvas/`, which this branch does not edit.
`Sources/RichTextEditorUIKit/RichTextButtonSurface.swift` republishes them from the same module —
no edit in there, and no second copy of arithmetic the parity test pins. `ButtonRowBackingView` is
NOT reusable: it is bound to `ButtonRowBox` and `BlockBackingView`.

Non-obvious things this rung cost, each found by running rather than by reading:

- **An atom's `.font` and `.paragraphStyle` must be pinned alongside its `.attachment`.** A
  RENDERED atom comes from `NSAttributedString(attachment:)` and carries no typography; an INSERTED
  one is a `U+FFFC` typed into the engine carrying the ambient TYPING attributes. Pin only the
  attachment and `verifyPresentationIsDerived` traps the moment a row is inserted rather than
  rendered. Media already pinned both; copying its attachment without its attributes is the trap.
- **`settleButtonRowAtomIntegrity` is what makes a row deletable.** Selecting the atom and pressing
  Backspace removes the CHARACTER, leaving a zero-length block — and because the shape carries the
  whole model, that block still read back as a full row. Measured: `lengths=[0, 5]` with the role
  still `row(r)`. Media never had this because its integrity pass already demotes an
  attachment-less atom.
- **`showsButtonRowMenuAffordance` is part of the MEASUREMENT, not the drawing.** A row showing the
  "…" packs its pills into 34pt less width, so wiring `onRequestButtonRowMenu` must re-render every
  live row's atom (`rerenderButtonRowAtoms`), not merely redraw it.
- **The engine gives hosted views their own tap recognisers** — row view and inline pill alike, as
  it already does for a details chevron, a checklist marker and a media poster. Routing an inline
  pill through `textInteractionMayBegin` was wrong twice: it fires on touch-DOWN, so a drag that
  merely began on a pill opened the host's sheet, and it made a query side-effecting. The seam's
  views stay passthrough by default because the LEGACY canvas resolves pill taps centrally.

**Two existing media mechanisms were GENERALISED over atom kind rather than copied**, each pinned
by goldens committed one commit ahead of the change:

- `planAtomUnitPlacement` — `insertMediaBlock`'s five placement arms, now shared with
  `insertButtonRow`. Placement is against the whole CONTAINER, so a caret in a cell places the unit
  after the whole TABLE. That is what keeps a row out of a cell — `cellParagraph` drops one, because
  a cell is one inline text on the wire — WITHOUT a dead button, the defect already fixed for media
  on K3. A row asked for inside a quote or details becomes its child.
- `atomUnitIndex` and the three Backspace rules (`beforeAtomUnit`, `afterAtomUnit`,
  `consumeBackspaceInsideAnAtomUnit`). `atomUnitIndex` is a **sibling** of `mediaAtomIndex`, not a
  widening of it: that function has four callers in `+SurfaceGate.swift` which are CAPTION logic,
  and a row has no caption. Backspace on a row is therefore media's walk exactly — park, select,
  delete — and a row reaches back to a preceding media atom and vice versa.

**Inline pills were rendering as blank space**, and fixing that surfaced a pre-existing data-loss
bug in the shared mapper: the `ca.button` branch dropped `ca.spoiler` in BOTH directions, with the
same self-justifying comment the `ca.emoji` branch beside it had already been fixed for. So a
spoilered inline button lost its spoiler from the model on every round trip, in the legacy editor
too. Both halves are fixed; fixing either alone leaves the loss.

## Block selection rectangles (2026-09-15)

**A selection is measured against each block's SLOT, not its text container.** A slot is the block's
canvas plus the space `blockInsets` reserves around it, and slots TILE — the stacking pass advances
by top inset, canvas, bottom inset — so a wash built from them leaves nothing between blocks. Before
this, segments were clipped to the text container and a fully selected document was a row of stripes
with 3-40pt of bare paper between every pair, a quote's 8/6 band interior bare, a code box's
9.79/8.46 bare, and 14pt of every table cell bare. That was never seven defects; it was one rule
measuring against the wrong rect. Four rules in `IDDocumentLayoutCoordinator`: a segment reaches the
slot's leading edge when its line is covered from its beginning, its trailing edge when covered to
its end (both borrowed from the legacy canvas's `selectionFillRects`), its top when it is the block's
first line and `extendHead`, its bottom when it is the last and `extendTail`.

**Per SEGMENT, not per block, and that is load-bearing.** A selection that ENDS inside a paragraph
must still stop at the glyph under the finger, and `containsLogicalStart`/`containsLogicalEnd` must
stay on the segments that own them. A select-all's LAST line therefore still hugs its final glyph
rather than filling the column — that is correct, not a leftover defect, and a stock text view does
the same. What changed for that block is only the vertical: it now reaches the rhythm above it.

**A block's reserved space is TWO things, washed on different conditions** (device report,
2026-09-15). The padding INSIDE the block's own box belongs to the block and is covered whenever the
block's content is; the rhythm OUTSIDE that box separates it from its neighbours and is covered only
when the selection actually reaches past — the same condition that decides whether a line fills to
its end. Collapsed into one rule, selecting a quote on its own hugged its text and author and left
its band bare, 8pt at the top and 5pt at the bottom. The engine gets the split from
`selectionBoxForBlockIdentifier:` (the declared box clipped to the slot); a block with no box of its
own answers `CGRectNull`, which means all of its reserved space is rhythm — right for a paragraph.

**A selected paragraph break on an EMPTY line draws a narrow mark** (same report). A selection that
ENDS on a blank line covers that line's break and nothing else: no glyph to hug, no line to fill, so
the segment came back zero-width and a zero-width rect draws nothing. On screen the line the finger
had just been dragged onto read as skipped, and a document ending in a blank line showed nothing
there under select-all. `IDBlockTextGeometry` now stands the break up as a mark about a space wide
(0.22 of the line, floor 4pt). **The mark carries NO boundary role, and is excluded from endpoint
promotion** — it is a drawing, not a claim: the selection's logical end lives on the break and the
block BEFORE it already owns it. Letting the mark claim it too trips the coordinator's
duplicate-endpoint guard, which discards the geometry for the whole document and draws no selection
at all — the same defect arriving by another route, and the reason the promotion path needs the
exclusion as well as the enumeration.

**The mark carries the selection's logical END, and the block before it yields.** A separator's
canonical range belongs to the block before it — but the selection's logical *end* is a place on
screen, and that place is the caret for the end offset, which sits at the START of the line after the
break. An empty line is where the two differ visibly, because it draws a mark there: leaving the
claim with the block before put the trailing HANDLE a line above the mark (device, 2026-09-15). So
`id_selectionGeometryAttemptForCanonicalRange` suppresses the previous block's `separatorTail`
endpoint claim under exactly the condition that makes the mark — next block empty, its head extension
is this separator, selection stops there — and the two cannot disagree about who owns the end.
Exactly one claimant either way: neuter either half and the duplicate guard takes the whole
document's selection down.

The yield is NOT conditional on the next line being empty, and that matters: the divergence was just
as wrong on a line with text, only invisible there because no mark contradicted it. On such a line
the block contributes no segment at all and the endpoint rect is a zero-width one synthesised above
the coordinator — so the handle lands correctly and nothing is drawn, which is what a line whose text
is not selected should look like. Generalising the MARK as well was measured to be inert and would
draw a mark over a line's first glyph if it ever stopped being; the mark stays empty-lines-only.

**The mark takes the LINE's height, and `IDBlockLayout` is the level that knows it.** Measured in the
geometry it is the GLYPH box, several points short of the pinned line, so it read small beside the
full-width fill the same line gets from a pass-through selection and the handle sat high. Four
sources below that level were measured and none answers: `enumerateTextLayoutFragmentsFromLocation:`
returns no fragment for an empty block, the container's height is unbounded,
`insertionRectForLocation:` answers the same glyph-height caret, and a tail-extended re-measure of
the same range answers the same box (a nested enumeration inside the segment enumeration does not
answer at all). An empty block is one line by definition, so its `usedSize` is that line's
BOX, and the layout sizes the mark there.

**The box is not the line, and the difference is all at the top.** `usedSize` is the PINNED box —
`pitch`, which the stylesheet sets as minimum == maximum line height — and a pinned box is the line
plus the spacing separating it from its neighbour. TextKit bottom-aligns the line inside it, the
baseline one descender above the bottom, so the spacing sits ABOVE the glyphs: a mark filling the box
reached up into the previous line (device, 2026-09-15). Measured on an empty body line: box 23.00,
ascender 16.19, descender −4.10, so the line is 20.29 and the 2.71 above it belongs between the
blocks. The mark is therefore `ascender − descender` tall, bottom-aligned in the box.

**UIKit expands the rect carrying the selection's end by a point and then integralizes it**, which is
why that mark arrives as 37…60 where the engine measured 38.71…59.00. Assert against the line ABOVE
rather than against the spacing: a box-sized mark arrives at 36 and a line-sized one at 37, and that
difference survives the rounding while a 2.71pt claim does not.

**REVERTED, kept as a record.** The paragraph that follows describes a change that shipped briefly
on 2026-09-15 and was rolled back because the previous state read better on the device. The code is
not in the tree; the analysis is right and cost several rounds, so it is left here for whoever takes
the question up again.

**A rect that carries a logical endpoint is the LINE; the rhythm is a separate rect.** UIKit draws
the selection HANDLE to the full height of whichever rect carries the start or end, so a rect grown
into the space reserved above its block puts the handle's bar up there too — reaching into the block
above. Reported from the device as "the issue appears when there is some other block with spacing
above": the same line looked right selected on its own (nothing grows, because nothing beyond it is
covered) and reached up as soon as the selection came from above. Measured: a paragraph after a code
block, endpoint rect 39pt tall over a 23pt line. The wash still wants that space — leaving it out is
the gap this whole change exists to close — so it is emitted as its own rect carrying no flags. The
two abut, so the column still reads as one piece.

Two things that took a round each to find. **A band keeps the core's BOUNDARY ROLE and drops only
its logical flags**: the role records which separator the rect's canonical range covers, and
`IDRichSelectionGeometryResultIsValid` refuses a segment whose range is a separator's without it —
stripping it discarded the whole document's geometry. And **a break MARK emits no bands**: it stands
for a break rather than a covered line, and its height was chosen to exclude exactly the spacing a
band would put back, as a sliver its own width.

**The rects UIKit hands back are 1pt taller than the engine measured them** at the selection's
logical start and end. Measured: the coordinator answers a paragraph's wash at y 14 and
`selectionRects(for:)` returns y 13. It is UIKit's, it predates all of this, and a test that asserts
equality against a decoration's frame will fail by exactly that point — assert coverage with a cap.

**A block whose visible box is wider than its column declares that box itself** — `selectionBoxes`
on the engine, filled by the host from the frame it has ALREADY assigned to that block's decoration
(a container's band in `syncContainerDecorations`, an atom's hosted view in `syncMediaViews`), passed
in verbatim; only minX/width are read. One derivation on purpose: an outset computed to match a band
is a second derivation of the band's position and drifts from it, which is how the collapsed quote's
fold glyph came to be drawn in two places. Writing it does NOT lay out — a column moves nothing, and
a setter that invalidated layout would re-enter the host pass that assigns it. A placed cell never
takes a column (its slot is already the whole cell, and a quote holding a table must not stretch each
cell's wash across the grid); nor does a button row or a collapsed quote, whose hosted views sit at
`id_attachmentFrame` exactly, so a column would NARROW their wash rather than widen it.

**A placed run's leading rhythm belongs to its first row.** A host reserves the gap above a table by
starting the run's placed frames below the run's anchor, so that space is inside the run and inside
no cell's rect — the one hole a document of slots still had, and one the design probe missed because
it measured block frames. `closeRun` hands it to the blocks at the top of the run. The ~1pt borders
between adjacent washed cells are left alone deliberately: they are the grid's to draw, and the
coverage test demands only that every uncovered band is at most a border thick AND inside the table.

**The wash is ABOVE the text and above hosted views.** Measured 2026-09-15:
`_UITextSelectionHighlightView` sits at engine subview `[5]`, `MediaAtomHostView` at `[4]`, because
the engine brings its selection container to the front on every presentation update. This matches the
legacy canvas, which puts its wash on top deliberately (`// keep the selection wash above newly-added
emoji`) because custom emoji, images and pills are VIEWS hosted above the text layer and a
behind-text wash would leave every one of them an unwashed island. **So a hosted view must not paint
a selected state of its own.** `MediaAtomHostView` did, and a selected photo rendered in three tones
— (178,215,255) in the 16pt bleed, (142,189,237) in the core, a hard seam at each column edge.

If the native behind-text look is ever wanted it needs TWO painters, and the reason is structural: a
below-stack wash would hide table selection entirely, because a table's cells and chrome live inside
an `IDPlacedRunScrollView` that is itself inside the block stack. The second painter would then have
to reproduce UIKit's `(204, 221, 237)` over white, which is not `accent @ 0.30` — pure
`tintColor @ 0.2` predicts `(204, 228, 255)`, so red matches and green and blue are pulled 7 and 18
lower by something undocumented. Custom emoji and spoiler dust are both
`isUserInteractionEnabled = false`, so they could move below such a wash; media, pills and previews
could not, since they take taps.

**The engine's own suite asserts parity with a stock text view, and this rule breaks that on
purpose.** Eight of its contracts went red; seven now compare against stock THROUGH one transform —
`IDSelectionRectExpectedFromStock`, *stock's rect with a side moved out to the container's line edge
on whichever sides the line is covered* — rather than against numbers of our own, which would leave a
suite that can no longer report a regression. The transform has no third answer, so anything beyond
the sides a caller names still fails, and each caller states its sides in words and derives the
container from the block's own layout. **The sides are LOGICAL and the direction is the LINE's, not
the rect's**: an RTL line covered to its end fills its LEFT edge, and measured on `["abc", "אבג"]` the
Hebrew block's rect reports `NSWritingDirectionLeftToRight` while its line fills to the right — so
reading the direction off the rect is both wrong and circular. The eighth was never a parity contract:
a head-only zero-length range now yields a break MARK on an empty block (carrying the head boundary
role, which the validator requires, and no logical endpoint) and nothing on a full one.

**The differential corpus is scoped instead of transformed.** Its snapshots record rects and
endpoint flags but nothing about line COVERAGE, and for a rect that is both first and last — every
single-line selection — neither side's coverage is derivable, so the transform cannot be applied
there exactly. `selectionRects` is therefore compared only between two hosts of OUR OWN
(`IDFieldIsComparableAcrossHostKinds`), and the deciding argument is the comparator's shape: it
returns the FIRST difference per host pair, so a known-divergent field stops the stock pairs from
checking every field at every later checkpoint — and `canonical`, `selection`, `markedRange` and the
two traces are what that corpus is for. Engine-vs-engine stays exact, and
`testEverySelectionStockHighlightsIsHighlightedHereToo` still checks selection geometry against stock
by AREA, which survives the divergence. **Keyed on host kind and on that one field, never on a
scenario name**, or it quietly becomes "geometry is not compared".

**And `Scripts/hostapp.sh test` did not run that suite at all** until 2026-09-15: it ran
`InputDecHost` only, so a change under `Sources/RichTextInputDecUpstream/` could go green while
breaking the engine's own contracts, which is exactly what happened here. It runs both schemes now.

**Running it also surfaced six failures that had nothing to do with selection, and they were not
behavioural.** Every one was an authorization fixture asserting that upstream's own `.xcresult` RUN
RECORDS are on disk. The fixtures themselves are here and their CONTENTS all pass — the private
selector, the owning category, the decision, the fallback host, the Hopper addresses, the runtime pin.
Only the disk check failed, and it is unsatisfiable rather than merely unmet: of the 48 artifacts
cited, 22 survive in the `~/Documents/InputDec` archive and **26 exist nowhere at all**, `.xcresult`
being transient run output. Copying the survivors would not restore it either, since an existence
check passes on an empty directory of the right name. The checks are now a shape check,
`IDIsUpstreamRunArtifactPath`, which carries that reasoning; the provenance claim lives in
`PROVENANCE.md`. **The Hopper markdown those fixtures also cite IS versioned here and keeps its
on-disk assertion** — check what this repo owns, not what upstream's disk once held. The shape check
promptly found two fixture entries naming neither a well-formed bundle nor any extant file, which the
old assertion had also failed on invisibly; they are pinned by name, and the predicate has its own
test, because a shape check nothing can fail is inert.

## R7 collapse fidelity (2026-09-15)

A folded quote's preview is laid out by the editor's OWN text layout — a `BlockLayoutEngine`, the
same seam the legacy canvas uses, republished through `RichTextLayoutSurface.swift`. Before this it
was a `UILabel` over `blockPlainText`, and that one fact produced four defects: no formatting, custom
emoji as blank boxes, **spoilers leaked in the clear**, and the text sat 0.33pt above the expanded
quote's.

**`firstLineBaselineFromTop` is what a layout REPORTS, not where it DRAWS.** Two attempts at the
baseline fix compared that value against `RichTextRenderMetrics.firstBaselineFromTop` — the same
number — and so computed a correction of exactly zero, twice, while the text did not move. Rendering
both surfaces and scanning for ink is what separated them:

| | first ink |
| --- | --- |
| `drawText(at: .zero)` on a bare layout | 3.33 below the origin (the CORRECTED baseline) |
| an engine block | 4.67 below the block top (the RAW TextKit baseline) |

So the preview's origin carries `rawFirstBaselineFromTop - firstLineBaselineFromTop`, both read from
the layout, which keeps it a relationship rather than a constant fitted to 15pt at 3×.

**A first-ink scan resolves to ONE DEVICE PIXEL** — 1/3 pt at 3× — so a parity assertion tighter than
that is asserting below the noise floor. `EngineInkMeasurement.swift` also carries the trap that
`drawHierarchy(afterScreenUpdates:)` yields an all-black image off-screen; use `layer.render(in:)`
over an opaque fill.

**An emoji inside a hidden spoiler must have its VIEW hidden, not just its glyphs**, and the preview
does the glyph-hiding, the view-hiding and the dust in ONE pass with ONE answer. A foreground colour
does nothing to a hosted view; `+CustomEmoji.swift` records that legacy has this bug today, and a
folded quote is worse than legacy's case because a reader cannot open the spoiler to check. The three
assertions live in ONE test case deliberately — neutering the view-hiding leaves the other two green,
which is exactly how this would ship broken.

**Every spoiler in a folded quote is hidden, always**, and that is the EXISTING reveal rule applied
rather than a new one: its single definition is "the selection reveals a run it is inside", and a
folded quote's content is off the engine's axis. No second reveal predicate exists.

**A marker costs width, never a line.** Non-text blocks contribute one inline SF Symbol
(`CollapsedQuoteMarkers`), so `maxPreviewLines` keeps meaning what it means in the V2 renderer and in
`InteractiveTextComponent`. A marker that broke the line would surface as a folded quote showing two
lines — which this rung has already seen once, from the cap arithmetic.

Still open and NOT this rung's: the multi-block wire gap (a folded quote of 2+ blocks sends unfolded —
`pageBlockBlockquoteBlocks` has no `collapsed` field), media thumbnails in the preview, and
tap-to-reveal.

**Truncation is a property of the BOX the text is poured into, never of the text — and spelled on
the text it silently becomes a line cap of ONE.** The preview carried `.byTruncatingTail` in its
paragraph style, and a truncating mode there beats the container in both text systems that read the
string: `boundingRect` measures one truncated line however long it is (which is why
`CollapsedQuoteTextAttachment.measuring` exists), and TextKit lays out one line even with
`maximumNumberOfLines` set to three. Measured: 19.0pt against the 57.0pt the same string gives when
the style WRAPS and the container truncates. The box was right throughout — `slot` caps at
`N x pitch` — so every geometry question about the atom answered correctly while a reader saw one
ellipsized line. The cap is `BlockLayoutEngine.capLines(_:truncating:)`, ONE call carrying both
halves because each is the other's silent failure mode: a cap with no truncation ends mid-word, a
truncation with no cap is the defect above.

**The engine answers with the layout's RESERVATION; a hosted emoji needs the VISIBLE box.**
`id_attachmentFrame` is what TextKit reserved from `attachmentBounds`, and
`EmojiTextAttachment.renderBoost` is the amount an emoji is DRAWN larger than its reservation — the
legacy canvas has always added it, because its box comes from `BlockLayout.attachmentBox`, which
does. This surface added it nowhere, so the same 15pt emoji was 17.9pt in an engine block against
21.9pt in a folded quote's preview (which goes through a layout): the reported "the custom emoji size
differs between collapsed and expanded quotes". The grow is now
`EmojiTextAttachment.visibleBox(_:for:)`, called by both layout engines and by
`attachmentOverlayPlacement` — and it belongs in the PLACEMENT rather than in the emoji sync, because
that function is also what the placement check re-reads: applied at the sync alone, every hosted
emoji reads as drifted by the boost. It is the identity for every other attachment kind, so the pills
and the formula targets pass through it untouched.

**A custom emoji OVERHANGS its line box and must not GROW anything** (2026-09-15). Two separate
facts, and conflating them cost a round trip.

The overhang is a DECISION: the boost makes a 17pt body emoji 24.29pt on a 23pt pinned line, hanging
~2pt below and ~0.7pt above with 0.7pt of clearance from the next line's glyphs. That is what the V2
renderer draws — its own comment says it bleeds "rather than forcing the line taller and pushing the
text baseline down" — and what the legacy canvas draws. **Asked, and the answer was to keep WYSIWYG**:
editor, legacy composer and sent bubble all draw 24.29. Do not clamp it to the line box; that would
make the editor the only one of the three that disagrees.

The GROWTH was a real defect, and a PRE-EXISTING one. `trailingLineBoxOverhang` gives back the empty
band a pinned line box reserves below its glyphs, and it returned 0 whenever the last line carried ANY
attachment — right for a media atom or a button row, whose line TextKit inflates to the attachment,
wrong for anything that rides a text line without inflating it. So a paragraph ENDING in one kept a
band the renderer does not: measured through the composer's own `height(forWidth:)`, body went 49 → 51
and H1 58 → 61 the moment an emoji was typed at the end. **H1's boost is ZERO**, which is what proves
this is the overhang rule and not the drawn size.

**The test is now whether the attachment FITS the pinned line, and fit is per-SIDE**
(`RichTextInlineAttachmentFit.fitsPinnedLine`, which the three inline attachment types answer through
`RichTextInlineAttachment.reservedBox(forFont:)`; an ATOM does not conform and is always a no-fit).
The pin bottom-aligns the line, so the room is asymmetric — `pinned - |descender|` above the baseline
and only `|descender|` below it — and an attachment SHORTER than the box still inflates it by
overhanging the baseline. Measured at 17pt body, against a 23pt box:

| trailing attachment | reserves | ascent / descent | line box | band given back |
| --- | --- | --- | --- | --- |
| custom emoji | 20.29 | 16.19 / 4.10 | 23.0 | yes — fits exactly |
| inline formula, 14 tall | 14.00 | 11.2 / 2.8 | 23.0 | yes |
| inline formula, 22 tall | 22.00 | 17.6 / 4.4 | 23.2994 | no — 0.2994 of excess DESCENT |
| inline button pill | 19.90 | 15.28 / 4.62 | 23.5176 | no — likewise, and it is the shortest |
| inline formula, 40 tall | 40.00 | 32 / 8 | 40.0 | no |

A height comparison would have called the 22pt formula and the pill fits and handed back a band that
is no longer there. **Consequence worth knowing: at today's pill metrics NO inline button qualifies** —
its line really is ~0.5pt taller, and the bubble's own pill inflates its line too, so that is parity
rather than a gap. The rule is written so a pill that ever does fit picks the band up with no further
change.

**The LINE BOX never moved in either case** — 23 at body, 30 at H1, with and without — which is exactly
why this hid: every assertion anyone had was on the block frame, and the block frame is the half that
was right. `height(forWidth:)` is the question the composer asks and the one that showed it.

**Which of the two sizes was correct is a question the V2 renderer settles**, and it is worth knowing
that neither answer is exactly its own: V2 draws `A - D + 4 * pointSize / 17`, so **21.43pt** at 15pt,
against the mapper's flat `style == .body ? 4 : 0`. **Still open, deliberately not changed here:** the
mapper's boost is not V2's formula — it is 0.47pt generous at 15pt and, worse, ZERO for a heading
where V2 gives `4 x 22/17 = 5.18`. Aligning it is a parity fix that moves the LEGACY canvas's emoji in
every quote and every heading, which is a visible change nobody asked for; recorded rather than
quietly made.

## R7 collapse in the InputDec engine editor (2026-09-15)

A block quote folds to a non-editable three-line preview and back, from a glyph in its trailing-top
corner.

**One model block is an `EngineAncestor` when open and an `EngineBlockShape` when folded.** That is
the whole design, and it is `DetailsShape.foldedChildren`'s rule applied to a container with no title
line to keep behind: a folded quote has no children on the axis for an ancestry to enclose, so it
leaves the ancestry and becomes `.collapsedQuote(QuoteShape)` — a SIXTH `EngineBlockShape`, and the
only one that is a container in the model.

**The point of making it an atom is that it inherits rules rather than growing them.**
`atomUnitIndex` gained one case and the two-step Backspace, tap-to-select, cross-block replace and
gap navigation all started answering for it. The alternative — a `.secondary` preview line inside a
still-open quote — buys the ancestry pass's band for free and pays with a duplicate of every atom
rule, which is the "a pair a backend can half-implement" shape this file keeps recording.

**`QuoteShape.foldedChildren` is non-empty iff `collapsed`, and so is `QuoteShape.author`.** An open
quote's children are on the engine's axis and its author is its `#author` secondary line; a copy on
the shape would be a second source of truth for the same text.

**Adding the sixth case is not one case.** The compiler named every consumer, and two of them were
decisions rather than mechanics — both in `+SurfaceGate.swift`, neither in the spec's own site list:
`isLeafBody` (a folded quote owns no editable text, so a newline has nothing to land in) and
`leafIsAChildContainer` (a folded quote is a child atom like a medium, and deliberately NOT the
answer `.blockQuote` gets two lines below, which is an open quote's own line). Two more followed:
`isContainer`, and the region-boundary WALL — which answers `false` ONLY because the atom rules sit
above it in `backspaceJoinRules`, a dependency the code now names along with the test that holds the
pair together.

**The gate's media branch is now an ATOM-UNIT branch** (`decideTextInputAtAnAtomUnit`), and its body
did not change: a folded quote is captionless, so it takes the path that was already there for audio
and documents. Before it, typing at a folded quote's gap produced `["x￼"]` — the character went into
the atom's own block, where the shape ignores runs. **`.standalone(.buttonRow)` is deliberately NOT
routed there**: it reaches the same door and appears to fall through to `.forward(text)`, which is
the same defect one kind over. Observed while writing this rung, NOT run down, no test either way.

**Two divergences from the legacy canvas, both deliberate:**

- **Backspace.** Legacy's collapsed quote acts on the PREVIOUS block at its gap, and a leading
  collapsed quote EXPANDS. Here it is the uniform atom behaviour: the caret PARKS at the atom's end,
  and the press after that selects. **A user can see this.**
- **The look is legacy's** — a three-line plain preview and a corner glyph — and NOT the V2
  renderer's truncate-with-fade-and-bottom-chevron. Closing that gap is R8's frame-parity work.

**The two glyphs never coexist and are culled differently.** An open quote's collapse glyph is synced
from the DECORATION pass (its position is defined against the band, whose frame is only known there)
and culled against a live set of its OWN — `live` holds every BAND's key, and a folded quote still
draws a band, so culling against it leaves the glyph floating over its own preview. A folded quote's
expand glyph belongs to its preview view instead.

**`isCollapsible` is a MEASURED fact, so the glyph is checked in the REVERSE direction.** The roles
cannot say whether a quote is taller than its own preview, so "every quote has a glyph" is false by
construction and `derivedViewShortfall` asks instead that no pooled glyph outlives its quote —
`structuralChrome`'s shape. That check does not merely fail, it TRAPS, and it caught the cull bug
above when the guard was neutered. The folded quote's PREVIEW view is the forward direction, like
`buttonRows`: engine-owned, so one missing is unambiguously a defect.

**The preview's measurement and its drawing must not be two derivations.** The attachment carries the
preview string AND its attributes, and the view reads them back off it. Measurement also has to strip
`.byTruncatingTail` first: under a truncating mode `boundingRect` measures ONE truncated line however
long the string is, so a 2,400-character preview measured 18pt tall and the three-line cap never
engaged. Truncation is a drawing concern; the legacy canvas never meets this because it caps a real
TextKit layout by height.

**A leaf container's interior is declared TWICE, and declaring it once is invisible until someone
looks at the background.** `EngineBlockSpacing.layOut` reserves it in the LAYOUT (the code, pull
quote and media arms do this); `leafInteriorPadding` is the decoration pass's mirror of the same
numbers and feeds the BAND alone. R7-collapse declared the folded quote's interior only in the
second, so the band was drawn 8pt above the atom into space the rhythm had never reserved — a folded
quote sat 8pt closer to the block above it than an open one, while the text stayed 8pt inside the
band in both states. That is why it was reported as "the background differs, the text origin is
correct": the text origin WAS correct.

`layOut` dispatches on the spacing KIND, and `.blockQuote` had no case there before this, because an
OPEN quote is a CONTAINER unit that `continue`s before the switch — so the kind could not reach it
and a folded quote fell into `default: break`. The arm is guarded on the SHAPE rather than on that
reasoning, so a future leaf of this kind cannot pick up a quote's padding by accident.

Pinned by `EngineQuoteCollapseGeometryTests`
.test_theBandSitsTheSameDistanceBelowThePrecedingBlockInBothStates, which compares the gap above the
band in the two states. The band tests written with the rung compared `minX` and `width` only and
could not see it.

**A folded quote only survives SENDING when its content is one paragraph, and that is the wire's
limit rather than the editor's.** Every client hop carries `collapsed` — the composer's
`chatInputContent(fromDocument:)`, `isEntityExpressible()` (which refuses a collapsed quote, so the
send takes the rich InstantPage path), `instantPage(from:)`, Postbox's `qcol`, FlatBuffers'
`collapsed:OptionalBool`, and the edit path's `chatInputContent(fromInstantPage:)`. The loss is at the
Api boundary: `pageBlockBlockquote` carries the flag in its `flags`, but a quote of two or more blocks
must use `pageBlockBlockquoteBlocks`, which has no such field, so the fold is dropped outbound and
read back as `false`. An author line does NOT count against this — it travels as the caption.

Pre-existing and documented at `InstantPage.swift`'s `apiInputBlock`; closing it needs
`pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true` server-side. This rung did not introduce it,
it made it reachable. Do not try to fix it client-side: the flag cannot be expressed on that
constructor, and re-encoding a quote as `pageBlockDetails` (which does carry flags) changes how it
renders. `CollapsedQuoteWireProbeTests` pins the boundary and its multi-block case is written to FAIL
once the schema gains the field.

**The toggle's caret arms OVERLAP at the span's end, and that is what makes their order matter.** A
folded quote's atom end IS its span's end, and that is exactly where Backspace parks a caret arriving
from the block below — so a caret there is ON the quote and the first arm must claim it. Written with
`inside` excluding `after` the two were mutually exclusive, the order meant nothing, and unfolding
from a parked caret threw it onto the author line. That is `+Details.swift`'s recorded K3 defect one
container kind over, and it was found here by a NEUTER that refused to go red — the tests all passed
either way.

## R9 formulas in the InputDec engine editor (2026-09-09)

**A formula is already a block, and no `Block.formula` case exists or should.** A block-level
formula is a STANDALONE FORMULA PARAGRAPH — `ParagraphBlock.standaloneFormulaLatex`: body style, no
list, exactly one run carrying a formula. `InstantPageBuilder` promotes such a paragraph to
`InstantPageBlock.formula` (wire type 29) on send, and Core keeps that definition in one place
precisely so the editor's spacing classification cannot drift from what is sent. The wire carries
both kinds — `RichText.formula` (type 16) inline, the block form at 29 — and `FormulaEditorScreen`
previews the block one.

**The renderer was stored and never wired.** `registerFormulaRenderer` put the provider in
`deferredConfiguration` and nothing handed it to the bridge's mapper, so every formula rendered as
its own LaTeX source. That is `attributedFormulaString`'s documented degradation rather than a
blank, which is why it went unnoticed.

**Registration REBUILDS, and must.** It changes a formula run from N characters of LaTeX to ONE
attachment character — a text LENGTH change no attribute merge can express — and
`RichTextAttachmentScreen` sets its document BEFORE registering (line 1376 against 1395), so the
un-rendered pass always happens. `applyFormulaRenderer` reads the document, swaps the mapper and
bridge, and writes it back: the same three steps `applyCodeStyle` and `applyMediaBlockStyle` take.

**A formula draws itself.** `RichTextFormulaRenderResult` is a `UIImage` plus baseline metrics and
`FormulaTextAttachment` assigns `self.image`, so this is the one atom kind here needing no view
pool — unlike a media atom, a button pill or a custom emoji.

**The spacing test reads the engine's storage, not the model.** `standaloneFormulaRoleIndices()`
ports `BlockBox.spacingKind` verbatim in substance — body, no list, length 1, sole attachment a
`FormulaTextAttachment` — and hands `EngineBlockSpacing` a plain `Set<Int>`. That is NOT content in
a role: the structure-only rule forbids a role CARRYING text, not a pass READING it at the moment
of use, and legacy avoids the model here for its own reason ("reaching the model would mean
`currentParagraph()`, which re-derives every run from the attributed string, and this is read on
every layout pass for every block"). The arm sits BEFORE the list check, mirroring
`InstantPageBuilder`'s dispatch order, which `BlockBox` says the layout side must match. An
UNRENDERED formula is deliberately not classified — it is literally a paragraph of text at that
moment.

**`insertFormula` makes a BLOCK**, diverging from legacy, whose `insertFormula` inserts "one inline
atom" at the caret. It places through `planAtomUnitPlacement`, so it lands where a media atom or a
button row would. NO trailing paragraph is minted, unlike those two: they are text-free and leave
nowhere to type, while a formula paragraph IS a paragraph — and typing after the formula correctly
turns the block form into an inline one, which is the same fact `standaloneFormulaLatex` encodes.
`makeSelectionInlineFormula()` is the inline gesture, mirroring `makeSelectionInlineButton()`;
legacy implements it as a genuine thin forwarder, since its `insertFormula` already replaces the
selection.

**A formula's tap target is a transparent view, and its `layer.contents` is load-bearing.** A
formula is the only tappable thing here with no view of its own, so it gets an empty one purely to
carry a recogniser — and a layer that renders NOTHING receives no real touches even though
`hitTest:` returns it (project `CLAUDE.md`, "iOS 26/27 windows and touch delivery"), while a
near-zero background alpha only works above an undocumented threshold. A test pins that `contents`
is set; only a real tap proves delivery — and a device pass on K3 (2026-09-10) confirmed it, so the
transparent-`contents` trick is a MEASURED fix here rather than a hopeful one.

**The mapper has FOUR early returns, not three.** Fixing the formula spoiler needed BOTH directions,
not just the read-back the spec predicted: the general branch's formula arm has its own
`return dict` placed before the `if ca.spoiler` line, so the marker never reached the attributed
string. Measured — the atom carried `RTFormula` and no `RTSpoiler`. Emoji, button and formula have
now all been repaired, in both directions; "the general branch carries it" holds only for runs that
actually reach the end of the general branch.

## DEBUG layout overlay (added 2026-06-28, `RichTextEditorView+DebugOverlay.swift`)

`RichTextEditorView.debugShowLayoutOverlay` (`#if DEBUG`, **ON by default in DEBUG**; set `false` to hide) draws a
non-interactive topmost overlay: the field frame (red outline), scroll insets (blue bands), content margins (green
ring), and per-block frames (orange, indexed), with inset/margin numeric labels. Refreshed from `performLayout` /
`scrollViewDidScroll`; reads geometry via `bounds` / `debugContentInset` / `canvas`. Compiled out of release entirely.

## TECH DEBT — `resolveBox` degenerate-container misroute (needs generalization; may require re-architecture)

**Status: known-brittle. The current fixes are point-patches, not a design. Generalize this — changing the
architecture if that's what it takes.**

**Root cause (one bug, many faces).** Position→box resolution has TWO mechanisms that disagree:
- `activeStack(at:)` / `leafRegion(containingGlobal:)` — **container-aware**: they descend into
  `BlockQuoteBox.children` / table cells and resolve the real leaf.
- `resolveBox(at:)` / `box(containingGlobal:)` — **NOT** container-aware: a `BlockQuoteBox`/`TableBlockBox`
  has a *degenerate* `CanvasBlock` text extent (`textStart == nodeStart`, `textLength == 0`; the real text is
  in children), so a position **inside** such a container matches no top-level box and the fallback loop
  returns the **following top-level block** (`pos < nextBox.textStart`). A quote/pull-quote **author** region
  is the same trap from the other side: it's a *second* leaf region off `activeStack`'s child-descent, so
  `activeStack`'s own resolveBox-based fallback mis-resolves it too.

So **any code that calls `resolveBox`/`box(containingGlobal:)` with a position that can be container-interior,
and then ACTS on the result, edits/reads the wrong (following) block.** This produced a whole family of device
bugs, each fixed individually (see git log ~2026-07-05): in-text/first-line/sibling/mid-text Backspace, the
object-replacement-range Backspace (`sel=a..b`), Return-in-author, the empty-paragraph-after-atom handler
(line ~530, twice), `insertTable`/`insertMedia`, `currentState()` toolbar state, and IME
`isBodyParagraphPosition`.

**How they were patched (the brittle part).** Two ad-hoc moves, applied per call site: (a) swap `resolveBox`
→ `activeStack`/`leafRegion`; or (b) bolt on a `!isInsideBlockQuote(pos)` / `!isInsideTable(pos)` guard. There
is **no invariant** preventing the next `resolveBox` consumer from re-introducing the bug — every new call
site is a fresh landmine, and the guards are easy to forget. `RTEDBG q0705*` instrumentation (now stripped)
was needed twice because unit tests with a *non-empty* following block hid the misroute (line ~530 only fires
when the following block is empty).

**The real fix (do this).** Make position resolution container-aware **by construction** so a single resolver
cannot mis-resolve a container-interior position:
- Unify on ONE descending resolver (fold `resolveBox`/`box(containingGlobal:)` into the `activeStack` descent,
  or give containers a non-degenerate `CanvasBlock` extent so the fallback loop can't skip them), and retire
  the degenerate-`textLength` fallback that returns the following block.
- Represent the author as a first-class leaf on the child axis (or make `activeStack` descend to it) so it
  stops being a special-cased "second region."
- Then delete the scattered `!isInsideBlockQuote`/`!isInsideTable` guards and the `resolveBox`→`activeStack`
  swaps — they become unnecessary once resolution can't misroute.
- Guardrail until then: a new `resolveBox`/`box(containingGlobal:)` call site that acts on the result is a
  code smell — prefer `activeStack`/`leafRegion`, and if you must use `resolveBox`, guard the container cases.

## TECH DEBT — display-only font size is PINNED into runs on read-back (needs a style-inheritance re-think)

**Status: known-brittle. The style-transition font fixes are point-patches. Generalize this.**

**Root cause.** A run's rendered font SIZE is display-derived from the paragraph style (heading1 = 24, body =
17, table cells = 15 via the `tableCells` mapper variant), NOT stored per-run — EXCEPT that
`AttributedStringMapper.characterAttributes(from:)` **unconditionally PINS** the rendered size into
`CharacterAttributes.fontSize` on read-back (`currentParagraph()` / `runs(from:)`). That pin exists so a
non-default size survives being moved between contexts (the "15pt table-cell round-trip": copy a cell, paste
elsewhere, keep 15pt). But it means **any run that moves to a paragraph with a DIFFERENT style keeps its old
size, overriding the new style** — because the pinned `fontSize` beats the style default at layout time. Font
FAMILY does NOT have this problem (it's deliberately not round-tripped — see the RTL font-family invariant).

**Where it bites (patched ~2026-07-05):**
- **MERGE across styles is handled centrally in `ParagraphBlock.merging`** (Core): when the two paragraphs'
  styles differ, the appended (other) runs get their `fontSize` cleared so they inherit the surviving style's
  size. This covers every merge path at once — `deleteBackward`'s top-level `applyReplaceOutcome` merge (Backspace at
  a body paragraph's start into a preceding heading — reached as a RANGE `[prevEnd, thisStart]`, NOT a
  collapsed caret, so it goes through `applySelectionReplaceOutcome` → `applyReplaceOutcome` → `merging`) and
  `mergeParagraphsOutcome`. Same-style merges keep the pin (preserving the 15pt table-cell round-trip).
- **SPLIT (`insertParagraphBreak`) is still a separate patch**: Return in a heading makes the tail a body
  paragraph and clears the tail runs' `fontSize` (a split is not a `merging` call, so it needs its own sweep).
  **Except at offset 0 of a NON-EMPTY heading (engine only, 2026-09-23):** there the "tail" is the whole
  heading, so the engine instead inserts an empty BODY paragraph above it and keeps the heading — text,
  style, identity — with the caret still at its start (`decideReturnAtStartOfHeading`,
  `+SurfaceGate.swift`; `HarnessHeadingReturnAtStartTests`). Mid and end Returns keep the rule above; an
  empty heading and a heading list item are left to their own rules. The legacy canvas still demotes.
  **Its inverse (2026-09-23):** Backspace at the start of a heading whose block above is an EMPTY
  standalone paragraph of the same container removes that empty paragraph and keeps the heading
  (`headingAfterEmptyParagraph` in `backspaceJoinRules`, `+BackspaceRules.swift`;
  `HarnessHeadingReturnBackspaceTests`) — the engine's own merge keeps the UPPER block, so Return then
  Backspace at a heading's start used to demote it. A non-empty paragraph above still takes the heading's text.

**Still ad-hoc on the split side and anywhere else runs cross a style boundary WITHOUT going through
`merging`** — paste, RTF import, format-menu style change, list/quote wraps, drag are each a fresh place the
pinned size can leak the wrong value. There is **no invariant** enforcing "a run's size follows its paragraph
style unless the user explicitly overrode it." (**Lesson:** the merge fix was first written as scattered
per-call-site patches AND a collapsed-caret-only unit test; both missed that iOS delivers Backspace-at-start as
a RANGE. Centralizing in `merging` + testing the range form fixed it.)

**The real fix (do this).** Separate *style-derived* size from a *user-explicit* size override:
- Do NOT pin the style-default size on read-back; only pin a size that DIFFERS from the run's paragraph-style
  default (mirrors how foreground color is stripped when it equals the style default — see the round-trip
  invariant). Then a heading run reads back with `fontSize == nil` and inherits whatever paragraph style it
  lands in; the 15pt cell case is handled by resolving the size against the *cell's* style at pin time (pin
  only when 15 ≠ the destination style's default), or by carrying the cell size as context, not per-run.
- Then delete the scattered `fontSize = nil` patches in `insertParagraphBreak` / `mergeParagraphsOutcome` — they
  become unnecessary once size inherits the style by construction.
- Guardrail until then: any new code path that moves runs into a different-styled paragraph must strip the
  runs' pinned `fontSize` (or it will render at the wrong size).

## Load-bearing invariants (compiler-invisible — violating these silently breaks the editor)

- **One flat global `(anchor, head)` range, coordinate-free.** Selection is a single linear range over one
  global position axis spanning the whole document (including non-renderable structural token slots); it's
  clamped per block and the per-block `enumerateTextSegments` rects are unioned for the highlight. The
  editing engine resolves endpoints through `activeStack` / `allLeafRegions()` and is **coordinate-free** —
  all position math is validated against Core's `PositionResolver`. Geometry (views, scroll offsets,
  culling) never feeds back into the position/selection/editing model.
- **The canvas is the SOLE `UITextInput`.** Image/table/paragraph blocks render via their own pooled,
  **non-focusable** `BlockBackingView`s (the ProseMirror node-view split) — render surfaces only, never
  first responders. `caretRect`/`closestPosition`/`selectionRects`/`contentSize` derive from **box frames
  over ALL boxes**, never the realized (possibly culled) views, so off-screen view virtualization changes
  no editing/selection/nav/hit-test behavior.
- **No PERSISTENT `UITextSelectionDisplayInteraction`; everything is own-drawn.** The canvas installs none
  persistently and has **no `draw(_:)` override** — it is a pure container of bounded subviews (a single
  CALayer/CGContext can't back an arbitrarily tall document; GPU max-texture ~16K px). Caret (`CaretView`),
  selection wash (`SelectionHighlightView` + per-table `CellSelectionView`), and handles (`SelectionHandleView`)
  are dedicated on-top layers/views, hosted in a table's scrolling content view for cell endpoints so they
  **ride horizontal overscroll**. (Un-clamping a table's `contentOffsetX` so the OS selection UI could ride
  the bounce makes the OS text system *fight* the caret — rejected; the clamp stays and we own-draw.)
  `caretRect(for:)` must still report a **real** position even when the visible caret is hidden — it feeds
  the OS's nav/scroll/loupe/edit-menu. **The ONE scoped exception:** a FRESH interaction is created per
  long-press loupe drag and torn down on release, borrowed only to hand the loupe a real `cursorView` widget
  (a bare/own caret is ignored by the grow animation) — per-drag, or it crashes against the view virtualization.
  See the "Loupe grow-from-cursor" note above.
- **`caretRect` is OS-facing nav geometry.** Hardware vertical arrows are driven by the OS via
  `position(from:in:direction:)` + the `selectedTextRange` setter — **not** `keyCommands` (arrow
  `keyCommands` never fire here). Vertical-nav results are `snapToRenderable`'d so the caret can't strand
  on a non-renderable structural slot.
- **Any pure `anchor`/`head` change must bracket `inputDelegate.selectionWillChange/DidChange`** — else the
  OS keeps a stale `selectedTextRange` and the next hardware arrow navigates from the wrong spot.
  (memory: `selection-changes-need-inputdelegate-bracket`) **This includes EDITS**, not just pure selection
  moves: `editing { }` and the undo closure bracket BOTH `text*` and `selection*` (like `reload`), because
  every edit also moves the caret. Omitting the selection bracket is invisible under system-keyboard typing
  (UIKit owns the selection there) but breaks **programmatic** inserts — e.g. the custom emoji keyboard:
  the caret appeared not to advance and a re-insert dropped a stray bare `U+FFFC` "service character".
- **Engine host sets: the selection UIKit reads at `textDidChange:` must already describe the NEW text.**
  UIKit builds the document state it sends the keyboard daemon from the selection at that moment, and
  the engine's controller holds untracked snapshot ranges, so a host set (undo/redo snapshot, content
  set) that re-seats the caret only after the bracket sends the old offsets against the new text. At
  composer-harness fuzz seed 15 that put the selection between the halves of a surrogate pair and kbd
  ABORTED (`NSRangeException` in `TIRevisionHistory`), stalling every later keyboard sync.
  `TGIDObservingBlockTextView` re-seats by a text-storage edit's rule before `textDidChange:` in
  `tgid_replaceBlocksInRange:` / `tgid_setAttributedBlocks:`; `HarnessInputDelegateContractTests` pins
  it against a stock `UITextView`.
- **Any caret-moving op must fire `onSelectionChange`** so the host can scroll-follow the caret (the
  façade's `scrollCaretIntoView`). Over-firing is safe — it early-returns when already visible and scrolls
  **non-animated** (an animated scroll races the OS arrow dispatch → nondeterministic geometry).
  (memory: `caret-moves-fire-onselectionchange-for-scroll`)
- **Display-only attributes never enter the Core model.** Inline-code, link styling, the inline-prediction
  ghost, spoiler-hide, and emoji are applied as TextKit **rendering attributes** or private storage markers
  (`.rtInlineCode` / `.rtSpoiler` / `.link`); `characterAttributes(from:)` / `currentBlock()` strip them on
  read-back so the model stays markdown-clean. The two `.foregroundColor` consumers (prediction-ghost vs
  spoiler-hide) each track + remove only their own ranges so they never clobber. A render-only display
  override (`applyDisplayOverride`, the table column-alignment / header-bold pass) **must be idempotent** —
  unconditionally re-assigning `layout.attributedString` resets the spoiler-hide ranges every layout pass
  → an infinite `layoutIfNeeded` loop; only assign when the rebuilt string actually differs.
- **Emoji and the spoiler atom are a single `U+FFFC`** carrying their ref in `CharacterAttributes` — exactly
  1 UTF-16 position, so `DocumentTree`/`PositionResolver`/the editing engine/tokenizer are untouched.
  Host-provided `UIView`s are pooled by `instanceID`, hosted in the canvas overlay (body/caption) or the
  table's content view (cells, ride H-scroll), and culled.
- **Caret placement snaps to composed-character boundaries — never mid-emoji.** `closestOffset(toPoint:)`
  (both `BlockLayout` and `BlockLayoutTK1`) skips offsets INSIDE a composed character sequence (surrogate
  pair / ZWJ / variation-selector emoji), so a tap can only land on a grapheme boundary. Without this a tap
  near an emoji places the caret mid-cluster, and the next insert/delete (incl. via the chat composer's
  `selectedRange`) splits the cluster → a stray code unit (the "service character"). Pairs with the
  grapheme-aware `deleteBackward` below — both keep the editor surrogate-safe.
- **Range delete/replace expands to whole grapheme clusters.** `applySelectionReplaceOutcome` (THE chokepoint for
  every selection-replacing edit — delete, type-over, paste, `replace(_:withText:)`) runs
  `rangeExpandedToGraphemeBoundaries` first, so a range covering only PART of a composed sequence is widened
  to the whole cluster. This is load-bearing for the **chat composer**: the OS delivers backspace there as a
  RANGE delete (`selFrom≠selTo`) that can cover just one half of a surrogate-pair emoji — deleting it verbatim
  left a lone surrogate (rendered `U+FFFD`), the composer "service character". The collapsed-caret
  `deleteBackward` grapheme snap did NOT cover this path; the expansion does.
- **Left/right arrow navigation moves a whole grapheme, not one UTF-16 unit.** The OS drives horizontal
  arrows through `position(from:in:direction:)` → `nextTextPosition`/`prevTextPosition`; the within-region
  step advances by `rangeOfComposedCharacterSequence`, so one press crosses a whole emoji. Stepping one
  UTF-16 unit lands the caret mid-surrogate (renders at the same glyph edge → looks stuck), so crossing an
  emoji took two presses. (The OS also *probes* `position(from:offset:±1)`, which is NOT grapheme-aware and
  can return a mid-surrogate offset, but it doesn't drive the caret — the move is `position(in:direction:)` +
  the `selectedTextRange` setter with grapheme-aligned values. A latent follow-up if shift+arrow selection
  ever needs sub-grapheme hardening.)
- **Backspace deletes a whole grapheme cluster, not one UTF-16 unit.** `deleteBackward`'s in-place delete
  (both the top-level and in-cell branches) removes `graphemeClusterLengthBeforeCaret(global:)` units, not a
  hardcoded 1 — so a *standard* Unicode emoji typed from the system keyboard (surrogate-pair scalar, ZWJ
  sequence, skin-tone / flag / variation-selector combo, all multi-UTF-16-unit) is removed as one unit
  instead of leaving an orphaned half. Computed via `rangeOfComposedCharacterSequence` on the leaf region's
  own string (the global axis is 1:1 with UTF-16 inside a region; a grapheme never spans regions). A
  custom-emoji `U+FFFC` and any plain BMP char are single-unit clusters, so it's a no-op for them.
- **Gesture arbitration is gate-only.** Handle/knob pan vs scroll pan is resolved *only* via
  `gestureRecognizerShouldBegin` — never `require(toFail:)` or forced simultaneous recognition. The
  single-tap recognizer fires immediately with manual multi-tap escalation in `handleTap` (no
  double-tap-failure delay); the host scroll view sets `delaysContentTouches = false`. **Both scroll views
  yield near a grip** via `GripYieldingScrollView` (a `UIScrollView` subclass overriding
  `gestureRecognizerShouldBegin` to return `false` when `canvas.isSelectionDragTouch(point)` — its testable
  seam is `yieldsToGrip(at:)`): used for the per-table inner scroll AND the **outer** document scroll
  (`RichTextEditorView.scrollView`, `canvas` wired in init). Before the outer scroll adopted it, a vertical
  knob pull raced the document scroll and the knob "felt dead" (2026-06-29).
- **The single-tap "inside the selection/caret" test (`tapOutcome`) is VISUAL, not offset-based.** A tap
  toggles the edit menu only when its *point* lands on the rendered selection (`selectionRects().contains`)
  — NOT merely when `closestGlobalPosition` resolves to an offset within `[selFrom, selTo]`. A tap in the
  empty area beside a selection resolves to a *boundary* offset inside the range but is visually outside, so
  it must collapse the selection + place the caret (the composer "tap-to-deselect doesn't work" bug). The
  collapsed-caret branch keeps the offset test (`resolved == head`).
- **A FOCUSING tap only places the caret — it never opens the menu** (`menuToggleAction`'s `wasFirstResponder`
  gate). The focus transition is captured by `didJustBecomeFirstResponder` (set in `becomeFirstResponder`,
  consumed by the next `performSingleTap`), **not** by reading `isFirstResponder` at touch-up: the chat
  composer focuses the editor on touch-**down** (`ChatTextInputPanelNode`'s `ensureFocusedOnTap`), so by the
  time the tap handler runs `isFirstResponder` is already true and can't distinguish the focusing tap.
  Otherwise the empty composer (caret at 0, a focusing tap resolves to 0 == `head` → `.toggleMenu`) pops the
  menu on the first tap. A second tap on the caret of the now-focused field toggles it normally.
- **Gesture-driven RANGE selections fire `onSelectionChange`** (`applySelection`, shared by `selectWord` /
  `selectParagraph` / `selectAllText`), exactly like `setCaret`. The chat composer tracks the editor selection
  through this hook; without it a double-tap word-selection never reaches the panel's interface state and the
  next `setInputContent` re-apply collapses it back to the stale caret (the double-tap "flash then deselect"
  bug). Pairs with the repo-wide invariant *"any caret-moving op must fire `onSelectionChange`."*
- **Word/paragraph boundaries come from the custom `DocumentTokenizer`**, which scans each leaf region's OWN
  string — not the global axis (whose structural slots the stock tokenizer mis-reads, gluing regions with
  no separator).
- **Marked text / IME is storage-backed** (body paragraphs only today): composing text is applied
  **outside** `editing{}` with one undo per composition; a system inline prediction (signalled by
  `setMarkedText` `sel:{0,0}`, ghost trailing) is **dismissed, never committed**, by our finalize
  chokepoints so the keyboard's own accept lands clean.
- **A gesture selection fires the OS input-delegate bracket exactly ONCE — no autocorrect "jiggle" (removed
  2026-07-06).** A short-lived experiment (added then removed the same day) tried to DISMISS the keyboard's pending
  autocorrect on a deliberate selection/cursor-move (⌘A especially) by bracketing a fake→real selection round-trip
  (`autocorrectDismissJiggle`) under an `isDroppingPendingAutocorrection` window that no-op'd the four text-mutation
  entry points. **It was removed because it was the dominant selection-latency cost:** each `selectionDidChange`
  drives the keyboard's synchronous `updateForChangedSelection` (~25ms on device — the ONE required bracket is
  already that expensive), and the jiggle added TWO more, so a double-tap word-select went from ~33ms to ~90ms
  (device-measured with `RTEDBG perf` timing). It was also non-standard — a stock `UITextView` simply lets a pending
  correction COMMIT when the selection moves. So `applySelection` (word / paragraph / Select-All) now brackets
  `selectionWillChange/DidChange` **once** around the range set, with no block and no jiggle; a pending correction
  commits on selection-move like any text view. `dropPendingAutocorrection` / `autocorrectDismissJiggle` /
  `isDroppingPendingAutocorrection` and the loupe/handle-drag `dropPendingAutocorrection()` calls are all gone.
  Guarded by `SelectionInteractionTests.test_applySelection_firesASingleSelectionBracket_noAutocorrectJiggle`. (The
  loupe/handle-drag input-delegate **coalescing** — `beginCoalescedSelectionDrag`, a separate feature — is unaffected.)
- **The undo buffer is a PRIVATE, per-canvas `UndoManager`, NOT the responder-chain `UIResponder.undoManager`**
  (`DocumentCanvasView.effectiveUndoManager = undoManagerOverride ?? ownUndoManager`, the latter a private
  `UndoManager()`). The responder-chain manager is shared app-wide, so other responders' (and the system
  text-input subsystem's) selection/typing undo registrations would surface in the editor's `canUndo` /
  `undo()` — the device-observed "a selection change is undoable / undo is active on the FIRST tap before any
  content edit" bug (fixed 2026-06-30). Only the editor's own `registerUndo` (every content `editing{}` + the
  composition commit) may enter this buffer. Tests inject their own via `undoManagerOverride` (every undo test
  already did — production simply never wired a private manager until this fix). Regression-guarded by
  `UndoBufferIsolationTests`. **The private manager is EXPOSED to the responder chain** via
  `override var undoManager { effectiveUndoManager }` (added 2026-07-01), so the SYSTEM undo affordances —
  hardware ⌘Z / ⌘⇧Z, shake-to-undo, and the Edit-menu Undo/Redo — act on our edits. They were DEAD between the
  2026-06-30 private-manager switch and this fix, because the responder chain exposed the app-wide *shared*
  manager (which our edits never touch). Safe by construction: the override changes only WHO can call `undo()`
  on our manager, not WHAT is registered into it (still only `registerUndo` content edits — nothing on
  selection), and it's a private instance no other responder holds, so the foreign-entry pollution above (which
  lived in the shared instance) cannot reappear; UIKit records no cursor movements / typing undos into a bare
  custom `UITextInput`. The `RichTextAttachmentScreen` nav-bar pill drives the same `undo()`/`redo()`.
  (⌘Z runtime-verified 2026-07-01.)
- **`undo()`/`redo()` fire a trailing `onChange` AFTER the manager settles** (`RichTextEditorView`). The undo/redo
  closure's own refresh (`notifyContentSizeChanged`) runs WHILE STILL INSIDE `UndoManager.undo()/redo()`, so a
  host that re-reads `currentState().canUndo/canRedo` synchronously from it sees the stack BEFORE the group is
  finalized — stale for the LAST undo/redo only (intermediate steps read the same value either way). Symptom:
  the undo (or redo) control stays enabled after the final undo (redo) until an unrelated `update()` (e.g. a
  rotation) re-reads state. The explicit trailing `onChange?()` refreshes the host with the settled availability.
  Regression-guarded by `UndoBufferIsolationTests.test_undoRedo_fireOnChange_soHostRefreshesAvailability`.
- **Typing/deleting undo COALESCES into whole runs** (`editing(coalescing:)`, added 2026-07-01). Every edit
  still snapshots the whole document, but `editing` SKIPS `registerUndo` when this edit CONTINUES an open run —
  same kind (`.typing`/`.deleting`), collapsed caret, landing exactly where the last keystroke left off
  (`openUndoRun.caret`) — so one undo reverts the whole uninterrupted run (like an iOS composer), not one char
  per step. The run-start snapshot already captures the pre-run doc, so skipping registration is all it takes;
  redo is unchanged (the closure lazily captures the post-run doc). A run BREAKS on: a caret move / a
  typing↔deleting switch / a selection-replace (all caught by the contiguity check), any structural / format /
  paste edit (the default `coalescing: .none`), and IME composition commit + resign-first-responder + `setBlocks`
  (which call `breakUndoCoalescing()`; `setBlocks` also covers the undo/redo restore). Only the 3 char-insert
  `insertText` sites pass `.typing` and the 3 plain-delete `deleteBackward` sites pass `.deleting`; every
  structural delete (paragraph merge / `removeBlockOutcome` / media-replace / un-quote / un-code / cross-block merge)
  stays `.none`. Scope note: system replacements via `replace(_:withText:)` (autocorrect/dictation) stay
  `.none`, so a dictation utterance is its own undo step. `undoRegistrationCount` is a test seam counting new
  steps; `UndoCoalescingTests`.
- **Undo restores a CARET for content edits, the SELECTION for formatting** (`editing`, added 2026-07-01). The
  undo closure restores the pre-edit `anchor`/`head` — which for a selection-delete/replace would re-select the
  restored text. Instead, when the edit COLLAPSED the caret (post-`body()` `anchor == head` — every content
  edit: delete / type-over / paste) the registration collapses the restored selection to a caret at the END of
  the pre-edit span (`max(beforeAnchor, beforeHead)`); a selection-preserving edit (formatting — bold/italic/
  link/style leaves a range post-`body()`) restores the pre-edit SELECTION so you still see what was
  un-formatted. Matches an iOS composer (macOS/VSCode re-select the restored text; iOS uses a plain caret).
  `UndoCoalescingTests`.
- **`text(in:)` MUST emit a `"\n"` at every top-level paragraph boundary** (`DocumentCanvasView+UITextInput`),
  exactly like a `UITextView` over a `"\n"`-joined string — because the global axis carries NO newline char
  between blocks, only a structural token gap. The system keyboard reads document context through `text(in:)`,
  and **not every IME drives `setMarkedText` on this view** — the Hangul (and other CJK) keyboard composes via
  `insertText` + a ranged `selectedTextRange`-set + `deleteBackward` + `insertText`, tracking positions itself
  and reading `text(in:)` for context. Without the separator it sees two stacked paragraphs as ONE continuous
  line and recomposes a syllable **across the invisible line break** — the trailing consonant of the lower line
  migrates onto the line above (the reported Korean-deletion bug). The `"\n"` is emitted for each crossed
  boundary, **including a range that lands entirely inside the inter-block gap** (the read the keyboard makes
  immediately before a lower line's first character). **Table-cell boundaries stay glued** (a table is one
  editing surface; cells don't compose marked text, and `CanvasCrossCellEditTests`/`test_copy_acrossCells…`
  rely on the un-separated cross-cell read). Covered by `CanvasTextInputTests.test_textInRange_*`.
- **PRIVATE API risk:** `SpoilerDustView` uses `CAEmitterBehavior` (`createEmitterBehavior`) for the
  twinkle + finger-attractor explosion — App-Store-review risk, guarded by a live canary test.
- **View-frame ownership** (the repo-wide rule applies here too): a reusable component lays out against
  `self.bounds`; it never writes `self.frame` — the parent positions it.

## Known render-only trade-offs

These keep the model markdown-clean at the cost of not separately preserving a user override: **(1)** a
link run's `foreground`/`underline` styling is render-only (suppressed on read-back); **(2)** table
**header-row** bold is render-only, so user-bold inside a header cell isn't separately preserved.

Headings are **regular weight by default** (`StyleSheet.font` does not force bold for them — they read as
larger serif); bold is a pure user-emphasis toggle that round-trips uniformly across every style. (This
replaced the earlier behavior where headings baked bold into their font, which leaked `**bold**` into the
model and left residual bold on a heading→body down-convert.) Type scale (2026-06-13; sizes since superseded
by V2 parity — see the layout-parity note): H1 24 / H2 21 / H3 19
serif, Body 17 sans, Caption 15 sans, Quote 17 sans — see the 2026-06-13 session block above. **Inside table
cells body/quote drop to a 15pt base (2026-06-26)** via a per-cell `StyleSheet.tableCells` mapper variant — see
the type-scale bullet in that session block.

**Interactive checklist / task list (added 2026-06-26).** A first-class checklist marker
(`ListMarker.checklist` + `ListMembership.checked: Bool?`, Core). **Creation:** the list picker offers
"Checklist"; `setList(.checklist)` seeds `checked: false` (re-applying `.checklist` to an already-checked item
PRESERVES its state). **Interactive checkbox — `CheckNode` via a host hook (the editor package stays
`CheckNode`/AsyncDisplayKit-free):** `RichTextEditorView.registerChecklistMarkerViewProvider(_ : (checked, size)
-> (UIView & RichTextChecklistMarkerView)?)` supplies a `CheckNode`-backed checkbox; both hosts wire it — the chat
composer threads checkbox colors through the `ChatRichTextThemeColors` seam (sourced from
`theme.list.itemCheckColors` in `ChatTextInputPanelNode.makeRichTextThemeColors`), `RichTextAttachmentScreen`
reads `appliedTheme.list.itemCheckColors`. The editor hosts/pools/culls the view in the marker gutter (mirrors the
inline-emoji machinery, `DocumentCanvasView+ChecklistMarkers.swift`), SUPPRESSES the Unicode glyph for `.checklist`
(`BlockBox.hostsChecklistCheckbox`, stamped in `stampListMarkers` + folded into `renderSignature` so a late
provider repaints), and a tap on the marker hit-rect toggles `checked` as ONE undo step (`toggleChecklistItem`,
caret-neutral, animates the hosted view). **Marker geometry** (`BlockBox.checklistMarkerCanvasRect()`): side =
`StyleSheet.checklistMarkerSize(for:)` (`font.capHeight.rounded()`) × `checklistMarkerScale` (1.4), bottom on the
text baseline (grows top/bottom/right, left edge anchored at the gutter), `floorToScreenPixels`-snapped; the list
text inset reserves the scaled width + a gap. **Return** continues the list with a fresh `checked:false` item
(empty-item Return exits the list; indent/outdent preserve `checked`). **Message round-trip (composer):** sends as
a rich message — `ChatInputContent` gained `.checklist` + `checked: Bool?` (the draft currency → draft persistence
free; raw enum value appended, optional Codable back-compat), threaded through `DocumentChatInputContentBridge`
(both directions) and BOTH `Document→InstantPage` builders (`ChatInputContentInstantPage` for the composer +
`RichTextEditorMessageConversion/InstantPageBuilder` for the attachment-screen send) into `InstantPageListItem.checked`.
Recipient checkboxes are display-only/static; the SENDER can re-edit (falls out of the reverse bridge). No
strikethrough on checked text (matches the InstantPage rendering). Active when the native composer is (`ios_rich_input_mode = 1`, or latched by content); runtime-verified.

**Quote + list combine as a container (added 2026-07-02).** A paragraph can be BOTH `style == .quote` AND a
list item (`setParagraphStyle`/`setList` never clear each other), i.e. a list *inside* a quote. Two subsystems
that used to ignore the quote in that case now treat it as a proper container: **(1) inset** — the quote's
leading inset (`quoteIndent`, the bar→text gap) now **STACKS on top of** the list marker inset rather than being
skipped (`StyleSheet.paragraphStyle` — the old mutually-exclusive `else if style == .quote` became an additive
`indent`), and the marker/checkbox columns add the same `quoteLeadingInset` (`BlockBox.listMarkerDraw` /
`checklistMarkerCanvasRect`) so a quoted list clears the bar instead of drawing over it; **(2) numbering** —
`ListNumbering.labels` now resets its counters at a quote boundary (a quote is its own numbering scope, exactly
like a non-list paragraph resets), so a quoted run numbers `1,2,…` independently and the surrounding list
restarts after the quote. This required forwarding each box's `style` into `ListNumbering` via `listMarkerLabels`
(previously only `list` was passed). Guarded by `ListRenderingTests` (inset/marker/caret) + `ListNumberingTests`
(quote-scope). This deliberately reverses the earlier "quote's flat +16 must NOT stack" decision — do not re-revert.

**Inter-block vertical spacing — two follow-on fixes (`BlockStack`, added 2026-07-02).** The gap between two
adjacent blocks is `boxes[i].bottomInset + boxes[i+1].topInset`, computed by `facingInset` — but only for
`BlockBox`es. Two cases had no gap: **(a)** a plain list item next to a *quoted* list item — the "two list items
stack tight (`return 0`)" rule fired even though they sit in different containers, so `facingInset` now guards
that rule on same-quote-ness (`(box.style == .quote) == (n.style == .quote)`); a body↔quote list pair falls
through to the framed-neighbor margin. **(b)** two adjacent **framed atoms** that are NOT `BlockBox`es
(code / table / collapsed-quote — `isFramedAtom`): each fills its whole frame and its own insets are INTERNAL
padding, and `facingInset` never runs for them, so their fills sat flush. `layout` (and, in lockstep,
`measuredHeight`) now inserts an external `verticalInsetBase + framedNeighborMargin` gap between two such atoms —
a bare gap belonging to no block's frame (tolerated by `closestPosition`, which maps a tap there to the block
below). An expanded quote is a `BlockBox` (consecutive quotes still merge into one fill; a quote↔non-quote gap is
reserved by the non-quote neighbor via `facingInset`), so it is deliberately excluded from `isFramedAtom`.
Guarded by `QuoteVerticalInsetTests`.

**Double-return on a list inside a quote — end the list first, THEN exit (`insertParagraphBreak` /
`quoteDoubleReturnExitIndex`, added 2026-07-02).** Ending a list is a two-step exit when the list is inside a
quote: Return on an empty quoted list item ENDS THE LIST but stays in the quote (an empty quote line), and only a
FURTHER Return leaves the quote. Two coordinated changes: `insertParagraphBreak`'s empty-list-item branch keeps
the paragraph's style (`if p.style != .quote { p.style = .body }`) instead of always forcing `.body`, so a quoted
list item becomes an empty **quote** line; and `quoteDoubleReturnExitIndex` returns nil while the empty quote line
still has a `listMembership` (both the on-line and the line-above cases), so the quote-exit dispatch doesn't fire
until the list has ended. Guarded by `DoubleReturnExitTests`.

**Backspace on an empty quoted list item → a plain empty paragraph (`deleteBackward`, added 2026-07-02).** The
empty-quote Backspace branch (un-quote → body) now also clears `listMembership`, so an empty **quoted list item**
(e.g. the first, empty line of a list inside a quote) collapses ALL the way to a plain empty paragraph rather than
leaving a body list item with a stray marker. `listMembership = nil` is a no-op for a plain (non-list) quote, so
that case is unchanged. Guarded by `CanvasQuoteEditTests`. (Backspace is a one-step full exit here, unlike Return's
two-step end-list-then-exit — Backspace is a delete gesture and matches the pre-existing empty-quote/empty-code
Backspace-to-body behavior.)

**Backspace at the START of a list item → outdent, or break the list (`deleteBackward`, added 2026-07-02).** A
collapsed caret at `local == 0` of ANY list item (empty or not) now: **nested (`level > 0`)** → `outdent()` (cancel
one indent level, stays a list item); **top-level (`level == 0`)** → break the list here — the item becomes a body
paragraph keeping its contents (`listMembership = nil; style = .body`), so items before it stay a list and items
after start a fresh one (numbering resets across the non-list gap). This branch sits right after `resolveBox` and
takes priority over the merge-into-previous and empty-quote branches, so it replaces the old "backspace at a list
item start merges into the previous block" behavior. Non-list paragraphs still merge (the branch is gated on
`listMembership != nil`). A quoted list item breaks straight to a **body** paragraph (un-quotes), consistent with
the one-step empty-quote Backspace above. Guarded by `CanvasStructuralTests` + `CanvasQuoteEditTests`.

## Configurable quote geometry + collapsed quotes (added 2026-06-28)

Two related quote features. **(1) Per-host quote geometry** — a `QuoteStyle` value (leading/trailing inset,
spacing before/after, bar width, corner radius, fill alpha) set via `RichTextEditorView.quoteStyle` and applied
through `DocumentCanvasView.applyQuoteStyle` (rebuilds the mapper stylesheet); the full-page article editor and the
compact chat composer pass different values. **(2) Collapsed quotes** — a first-class
`Block.collapsedQuote(CollapsedQuote)` atom (legacy chat-input parity) reusing the AUDIO-media DocNode shape
(`mediaBlock`+`mediaAtom`, nodeSize 3, caption-less; the leading gap is the caret slot). `CollapsedQuoteBox` draws
the folded preview + a corner expand glyph; `collapseQuoteRun(atIndex:)` folds a run of consecutive quotes into one
atom, `expandCollapsedQuote(atIndex:)` restores them — caret relocation on collapse/expand is conditional (only a
caret that was INSIDE the run moves). Composer round-trip: one flat char + `ChatTextInputTextQuoteAttribute(
isCollapsed: true)` via `ComposerDocumentBridge`, sent through the InstantPage builder. Available in both hosts
(the native composer: `ios_rich_input_mode = 1`, or latched by content). Runtime-verified.

**Collapsed-quote atom — caret/nav/delete invariants (compiler-invisible, device-log-verified).** The collapsed
quote behaves like a caption-less media atom: it owns NO leaf region (`leafRegions() == []`), so it routes through
the same gap machinery as audio media via `collapsedQuoteBox(atGap:)` (mirroring `mediaBox(atGap:)`).
- **Caret** at the gap draws at the quote's leading edge (`caretRect` / `caretHostPlacement`); a range covers it
  (`coverableContentEnd == nodeStart + 1`). **Tap** the body to place the caret at the gap; tap the corner glyph to
  expand.
- **Horizontal nav** stops on the gap (`nextTextPosition` / `prevTextPosition` via `atomGap`); `snapToRenderable`
  treats the gap as renderable.
- **Vertical nav MUST step THROUGH the gap** — `verticalPosition` has an explicit `collapsedQuoteBox(atGap:)` branch
  (Down → block after, Up → end of block above), mirroring the media-gap branch. Without it a multi-line move (the
  OS's `position(from:in:.up/.down, offset: 2)`) STALLS on the gap (offset:2 == offset:1); the OS reads "no
  progress", abandons `position(from:in:)`, and falls back to its own line geometry that SKIPS the captionless atom
  (the intermittent "arrow jumps over the quote" bug).
- **Backspace** at the gap acts on the PREVIOUS block, never the quote: a non-empty previous paragraph loses its
  last grapheme, an EMPTY one is removed (caret stays on the quote's gap), a LEADING collapsed quote (nothing
  before) expands. LOAD-BEARING: iOS delivers this Backspace as an object-replacement RANGE anchored at the
  previous block's end (`selFrom = prevTextPosition(before: gap)`, `selTo = gap`) — exactly like a media atom — so
  the handler fires on `selTo` being a collapsed gap AND `selFrom >= prevTextPosition(before: selTo)` (admits the
  range AND the collapsed caret; excludes a genuine selection that merely ends at the gap), NOT on `selFrom ==
  selTo`. (Same "capture the device log, don't hypothesise twice" lesson as the media object-replacement-range case.)

## Selection-handle drag — touch offset, outer-scroll yield, host knob config (added 2026-06-29)

Three fixes to the selection-handle ("knob") drag, runtime-verified in the chat composer.

- **The drag keeps its starting touch→knob offset (not line-centered).** The knob is drawn OFFSET from the text
  line (`SelectionHandleView.boundingFrame`: a knob 2·`knobRadius` past the caret's open end), so mapping the raw
  finger point snapped the dragged endpoint to whatever line sat under the finger. `handleSelectionHandlePan`
  `.began` now captures `selectionDragGrabOffset = caretCenter(draggedEndpoint) − touch`
  (`captureSelectionDragOffset`), and every drag map — the `.changed` branch AND the auto-scroll re-extend tick —
  goes through `selectionDragPosition(forTouch:)` = `closestGlobalPosition(to: touch + offset)`. Anchoring on the
  caret CENTER makes the first map (touch ≈ grab point) land exactly on the grabbed endpoint (no jump at grab) and
  the constant offset is preserved for the rest of the drag — the iOS handle-tracking feel.

- **`GripYieldingScrollView` (generalized from the old `TableScrollView`).** See the gesture-arbitration invariant
  above: the OUTER document scroll now yields its pan near a grip (it never did before — the root cause of the
  "knobs feel dead, only the line drags" report; the gate was already covering the knobs, but the un-gated outer
  scroll won the vertical pull). Same class backs the per-table inner scroll.

- **Handle views are hit-testable + host-configurable, so a knob drag isn't hijacked by interactive
  dismiss/transition gestures.** `SelectionHandleView` is now `isUserInteractionEnabled = true` with a
  `point(inside:)` hit area = `caretLocalRect.insetBy(-dragHitTolerance)` (the SAME ±22pt zone as
  `isSelectionDragTouch`, fed via `setCaretLocalRect` in `positionHandle`) — **it adds NO recognizers; the drag is
  still the canvas pan, which receives the touch as an ancestor.** Being the window hit-test result for a knob
  touch lets a host set Display's gesture flags on it (Display walks UP from the hit-test view), scoping the effect
  to knob interaction — NOT the whole editor surface (setting them there was rejected). The package can't import
  Display, so the new façade hook `RichTextEditorView.configureSelectionHandleView: ((UIView) -> Void)?` (invoked
  once per handle view, applied in the canvas `didSet`) lets the host apply them. The three flags:
  `disablesInteractiveTransitionGestureRecognizer` (the navigation back-swipe a HORIZONTAL knob drag triggers — the
  load-bearing one, gated at `WindowContent.doesViewTreeDisableInteractiveTransitionGestureRecognizer`, distinct
  from the keyboard check), `disablesInteractiveModalDismiss` (the attachment sheet), and
  `disablesInteractiveKeyboardGestureRecognizer`. **Scope differs by host:** the **compact composer**
  (`RichTextEditorChatInputNode`) uses ONLY the per-knob hook (editor-wide was rejected — it would kill normal
  scroll/dismiss in the small field); the **full-page attachment editor** (`RichTextAttachmentScreen`) sets the
  hook AND the same three flags editor-wide on `editor` (a full-page editor shouldn't back-swipe/dismiss from any
  in-editor interaction while editing). **Compiler-invisible:** the per-knob flag is consulted only when the knob
  is the window hit-test result, so the handle MUST stay hit-testable and its hit area MUST track the caret —
  verified on device (the hit test lands on `SelectionHandleView`).

**Code blocks are edge-to-edge plain bands (2026-08-18, `feature/code-block-edge-to-edge`).** A code block
stopped being a quote variant: no accent bar, no tint, no corner radius. Its band is a plain
`RichTextEditorTheme.codeBackground` rectangle spanning its container's interior edge to edge, and its code
text — plus a **bold, lowercased language line above it** — sits at exactly the x a paragraph occupies at
that nesting level. So the band's interior side padding IS the paragraph inset; it is no longer a constant.

- **`CodeBlockBox` paints its own fill** and left `blockquoteDecorations()`, which was deleted with its
  struct (the code case was its only producer). That is also the FIX for a live bug: the quote underlay's
  feed walks top-level boxes only, so a code block inside a quote or a table cell previously had **no fill
  at all**.
- **`blockViewFrame` outsets `frame` by `horizontalBleed`** — geometric sides (`minXSide` is the smaller-x
  edge), mirroring the renderer's `InstantPageV2ChildBleed`. `BlockBackingView` clips to `blockViewFrame`, so
  a bleed missing there renders as a band clipped back to the text column. It is assigned by
  `BlockStack.layout(origin:width:codeBleed:)` at LAYOUT time, not at construction: it moves with the host's
  content margins while the box does not. Root → the canvas edge by default, or `CodeStyle.horizontalBleed`
  when a host sets one; block quote → just inside the accent bar, so the bar stays continuous; details /
  table cells / list items → none, conservatively.
- **A COMPACT host bleeds NOTHING and indents the text instead.** The composer's canvas sits INSIDE the
  input field's rounded background (inset by the panel's `textInputViewInternalInsets`, 12 left / 11 right)
  and its right `contentMargins` additionally reserves the accessory + send button strip — so any outward
  bleed reads as spilling past what the field shows. The composer therefore sets
  `CodeStyle(horizontalBleed: 0, horizontalInset: 8, cornerRadius: 4)`: the band spans exactly the text
  column, and `horizontalInset` moves the code IN from its edges — the inward counterpart of the outward
  bleed. **`horizontalBleed` and `horizontalInset` are alternatives**; a host sets one or the other, never
  both to non-zero. The inset narrows the text MEASURE as well as its origin (`setWidth` /
  `measuredHeight(forWidth:)` / the init layout all subtract it twice), or the code would wrap at the
  band's full width and overrun its trailing edge. **Deliberately NOT WYSIWYG** against the sent bubble
  (full-bleed, square) — a compact field is a different container shape from a message bubble, the same
  reason the composer zeroes `mediaBlockStyle.horizontalBleed`.
- **`CodeStyle` (host knob) + `StyleSheet.codeVerticalInset` / `codeLanguageSpacing`** replaced the borrowed
  `quoteIndent` / `quoteTrailingInset` / `quoteTopInset` / `quoteBottomInset`. Both fields are optional and
  resolve against `RichTextRenderMetrics.code` (`RichTextCodeMetrics`), so an unset host renders the
  renderer's own numbers. `applyRenderMetrics` MUST re-resolve them — `metrics.code` is the fallback, so a
  host setting `renderMetrics` after `codeStyle` would otherwise keep stale defaults.
- This closed two real parity breaks: interior padding was 9/**22** here (it read `quoteTrailingInset`)
  against the renderer's 9/9, and vertical padding a raw 3pt against its font-box-corrected 6pt.

Renderer side + the design record: `docs/superpowers/specs/2026-08-18-code-block-edge-to-edge-design.md`.


## Status

**Done** (model + editing + rendering all in place): the Core model, global position model, and JSON/`.rtdoc`
serialization; continuous **cross-block and partial-cross-cell selection + editing** — the headline
requirement, incl. editing across stacks via `applyReplaceOutcome` / `applyMultiRegionClearOutcome`; structural editing
(Enter splits / Backspace merges / cross-block delete) with snapshot undo; **lists** (rendering +
`setList` / indent / outdent, incl. an **interactive checklist** — tappable `CheckNode` checkbox + message
round-trip + emoji external share, see the note above), **images** (caption + gap cursor + selection highlight), **tables**
(rendering, cross-cell caret & Tab nav, in-cell editing, row/column insert-delete + per-column alignment +
header row, in-canvas row/column controls + multi-row/column range selection); **formatting**
(bold/italic/strike/inline-code/underline, paragraph styles H1–H3/Body/Quote, alignment, links);
**insert** table/image; the **iOS-standard touch model** (tap-caret, double/triple select, long-press
loupe, handle-drag) + **system edit menu** (Look Up / Translate / Share / Format / basic Writing Tools);
**visual design alignment**; **inline predictive text + marked-text/IME**; **inline custom emoji**; the
**block-view architecture** (every block in its own bounded layer; per-table horizontal scroll; off-screen
**view virtualization**); and the **Telegram-style spoiler effect**.

**The editor is full-WYSIWYG — markdown abandoned.** There is no markdown serializer, and none is planned. Cross-app interchange uses **RTF** (see Phase 5d below).

**Phase 5d rich copy/paste — done.** Within-app fidelity via the private pasteboard UTI `org.telegram.richtexteditor.fragment` carrying a JSON-encoded `Document` fragment (inline formatting incl. custom emoji / mention / date, and paragraph/quote/code/list block structure — preserved across any editor instance, including between chat composers). Cross-app via **RTF** read+write (`public.rtf`) plus a plain-text fallback (`public.utf8-plain-text`) always written/accepted. Multi-line plain paste splits into paragraphs (replaced the old newline→space flattening). Fragment scope = paragraph family + inline; tables and media (images) are NOT carried in a fragment (deferred); image-paste-to-attachment in the composer is a host concern, wired via the paste-media hooks (see below). The extract/splice are pure Core (`Document.extractFragment` / `Document.insertingFragment` in `RichTextEditorCore/Model/DocumentFragment.swift`); the `copy`/`cut`/`paste` responders + the three-representation pasteboard write are in `DocumentCanvasView+Clipboard.swift`; RTF conversion is `RTFConversion.swift`.

**Checklist external share — emoji (added 2026-06-26).** Checklist items serialize to the EXTERNAL RTF +
plain-text reps as an emoji checkbox prefix (`⬜ ` U+2B1C unchecked / `✅ ` U+2705 checked) and are auto-detected
(emoji-only, optional VS16, strips exactly one) on import/paste, via the pure-Core `ChecklistEmojiMarker` codec
(`prefix(checked:)` / `strippingMarker(_:)`) + `externalChecklistPlainText([Block])`. Injected at the export sites
(`RTFConversion.rtfData` prefix + the `NSAttributedString`-fallback per-line detect; the plain rep via
`pasteboardItem` → `externalChecklistPlainText`) and the import sites (`RTFImport.flushParagraph` text + `\listtext`
detect; `plainTextFragment` per-line detect). The in-app private fragment round-trips `checked` losslessly
(`blockPlainText` / `text(in:)` stay marker-free). Accepted limitation: a paragraph the user literally typed
starting with `✅ `/`⬜ ` is read as a checklist on external paste.

**Inline-merging a pasted paragraph is DIRECTIONAL — it keeps the HOST's style, so it must not swallow a
heading (`isInlineMergeable`, fixed 2026-08-17).** The predicate accepted every heading level, so a fragment
whose first (or only) block was a heading folded into the split half of the host paragraph and came out
retyped as the host's style. In the chat composer the host is always a body paragraph, so **pasting a copied
rich message silently lost its headings** — the reported "headings are not pasted". The two directions are not
symmetric and the predicate now takes the host style:
- a plain **body** fragment paragraph carries no block structure, so folding it loses nothing → always folds.
  This one MUST keep folding: pasting text into a heading has to stay in the heading.
- a **heading** fragment paragraph loses its level when folded → folds only into a host of that same style
  (`# X` pasted inside an H1 must not shatter it into three blocks). Anywhere else it stands as its own block,
  and the split-and-assemble path below places it — including mid-paragraph, which now splits the host rather
  than dissolving the heading into it.

`Document.replacingRange` delegates its splice to `insertingFragment`, so the markdown-on-paste two-step path
inherits the same rule. Guarded by `DocumentFragmentHeadingPasteTests` (Core).

**Paste never leaves a spurious empty paragraph (load-bearing, `Document.insertingFragment`).** The multi-block
splice assembles `[headBlock] + middle + [tailPara]`, where head/tail are the host paragraph split at the caret;
it inline-merges a fragment block into a split half only per the directional rule above (`isInlineMergeable`).
Pasting a NON-inline-mergeable LAST block — a **list item (checklists), quote, or code block** — at a paragraph
END (empty tail) would otherwise leave the empty host tail as a trailing empty paragraph (symmetric leading case at
a paragraph start). It now drops an empty OUTERMOST split-half (`headBlock`/`tailPara` only — keyed on
`text.isEmpty`, keeps ≥1 block; INTERIOR fragment empties live in `middle` and are preserved), with the caret →
end of the last pasted block when the tail is dropped. This is the true fix for the "paste adds a trailing empty
paragraph" bug (a trailing empty *in the fragment* — handled earlier at higher layers — was a different, narrower
case; the host-tail empty is the general one and lives here in Core, shared by both editors).

**Paste-media-to-send is host-delegated (2026-06-25).** The editor never embeds pasted media inline — images/GIF/video/stickers go to the chat *send* flow. Two façade hooks (`RichTextEditorView.canPasteMedia` / `onPasteMedia`, both `(() -> Bool)?`, forwarded to `DocumentCanvasView`): `paste(_:)` pastes a TEXT rep if one exists (fragment/RTF/plain — **text wins**), else calls `onPasteMedia?()`; `clipboardCanPerformAction(.paste)` also offers Paste when `canPasteMedia?()` is true (so the menu shows for an image-only clipboard). The editor stays Telegram-UTI-agnostic — the hooks are plain closures the host fills. The chat composer wires them (`ChatTextInputPanelNode.loadTextInputNode`) to a shared `handlePastedMedia(perform:)` (the gif/mp4/heics/png-sticker/jpeg detection extracted from the legacy `chatInputTextNodeShouldPaste`, so both the old and new composers route media identically), restoring the legacy paste-to-send the new composer had lost.

**Host plain-text transform hook + two-step paste (2026-07-24, markdown-on-paste).** `RichTextEditorView.plainTextFragmentTransformer: ((String) -> Document?)?` (forwarded to `DocumentCanvasView`) lets a host convert pasted PLAIN text into a rich `Document` — the editor stays markdown-agnostic (the composer/article hosts inject a CommonMark parser; see `docs/richtext-composer.md` §7). `paste(_:)` consults it only when the pasteboard has **no** richer rep (fragment/RTF) and it returns a non-empty `Document`, then runs `pasteMarkdownTwoStep(plainText:rich:)`: step 1 splices the RAW text (`spliceFragmentInEditing`, one undo step), step 2 — **deferred to the next run-loop cycle** — `replaceRange`s it with `rich`. Two events are REQUIRED for two undo groups: the private `UndoManager` uses default `groupsByEvent`, so a synchronous step 2 would coalesce into one group (one undo would wipe the paste instead of reverting rich→plain). Step 1 sets **`suppressHostChangeNotification`** so `notifyContentSizeChanged()` (gated at its definition — `setBlocks` also calls it) and the `editing {}` trailing `refreshSelectionUI()`/`onSelectionChange()` no-op, keeping the intermediate raw-text state off-screen (no text flash, no caret jump — the caret moves once, in step 2). Undo therefore steps rich → plain → gone.

**RTF export is hand-rolled and emits real tables (2026-06-25, `RTFConversion.swift`).** iOS has **no `NSTextTable` / `NSParagraphStyle.textBlocks`** (AppKit-only) — confirmed by spike — so `NSAttributedString` cannot represent or round-trip a real RTF table; a genuine table can only be produced by emitting the control words by hand. So `rtfData(from:)` now builds the **entire** RTF document by hand for ALL documents (one path; the old `NSAttributedString` export is gone) via one shared inline-run encoder (`inlineRTF`) + `escapeRTFText` (UTF-16 `\u<signed-16>?` escaping). Tables emit `\trowd`/`\trhdr`/`\cellx<cumulative-twips>`/`\intbl`/`\cell`/`\row` (`tableRTF`), so a Telegram table copied into Word/Pages/Notes becomes a **real table**. Parity kept on export (not added): no list markers, no foreground/theme colors, media-in-cell dropped, cell background colors dropped. Custom emoji ride the `tg://emoji?id=<id>&n=<seq>` hyperlink marker (the `&n=` per-export sequence stops adjacent identical emoji from coalescing). Spec/plan: `docs/superpowers/{specs/2026-06-25-richtext-rtf-tables-design.md,plans/2026-06-25-richtext-rtf-tables.md}`.

**RTF import is a custom pure-Foundation parser in Core (2026-06-25, `RichTextEditorCore/Serialization/RTFTokenizer.swift` + `RTFImport.swift`).** Because iOS `NSAttributedString` flattens all block structure (no `NSTextTable`/`textLists`), a custom lexer (`RTFTokenizer`: groups, control words, `\'XX` cp1252, `\uN` signed-16 + surrogate + `\uc` skip, escapes) feeds a group-state document builder (`RTFDocumentParser`) that **reconstructs tables / headings / code / lists** + inline runs/links/emoji from third-party RTF (Word/Pages/web). `fragment(fromRTF:)` (UIKit) tries `RTFImport.document(fromRTF:)` **first** and falls back to the old `NSAttributedString` path only on hard failure (not-RTF / zero blocks) — so exotic RTF is never worse than the flatten, and the editor's own export→import now **round-trips structure losslessly** (the `RTFConversionTests` round-trip suite is the parse-compat gate; pure-Foundation parser is `swift test`-able on macOS via `RTFImportTests`/`RTFImportCorpusTests`). Heuristics (text always survives, only block style may differ): heading by font size (`\fsN/2` ≥23→H1/20–22→H2/18–19→H3), all-mono paragraph→code block, best-effort lists (`\ilvl`/`\listtext` marker→`.bullet`/`.ordered`+level). **Imported links whose anchor text IS their own URL are stripped to plain text** — `fragment(fromRTF:)` runs
`Document.strippingSelfReferentialLinks()` on BOTH the custom-parser and `NSAttributedString`-fallback results.
A copied web link usually has the URL as its label; carrying it as a link run pins a destination the plain URL
already gives, and the sent message would become a `textUrl` instead of a plain, auto-detected URL. A genuine
text link (a label that differs from its target) is kept, as is anything pasted through the private fragment UTI
(no importer involved). The predicate `linkIsSelfReferential(text:url:)` (Core) tolerates the normalizations a
producer applies — an added `mailto:` / `http(s)://` scheme (the latter only when the text carries no scheme of
its own), a percent-encoded path, a trailing `/` — and is a **deliberate duplicate** of `TextFormat`'s
`chatInputLinkIsSelfReferential` (Core cannot import app modules; keep the two rules in step). The composer's
markdown-on-paste path applies the same rule host-side — see `docs/richtext-composer.md` §7.
Non-goals: colors, nested tables, full Word list-table fidelity, images, codepage beyond cp1252. Graceful degradation: unknown control words → no-op; unknown/`{\*\…}` destinations consumed to their `}`; never crashes. **Paragraph breaks (load-bearing, fixed 2026-06-26 — the "pasting removes newlines" bug):** Cocoa/AppKit (TextEdit, Notes, Safari, Mail, Pages — i.e. *every* rich-app copy) serializes a paragraph break as a **backslash immediately followed by a literal CR/LF** (`a\⏎b`), which the RTF spec defines as equivalent to `\par` — NOT a literal `\par` (only the editor's own export and hand-written test RTF use literal `\par`, which is why this slipped the original suite). `RTFTokenizer` therefore maps `\`+CR/LF (CRLF collapsed to one) to a `\par` token; without it every cross-app paste glued all paragraphs into one. **Empty paragraphs survive:** an explicit `\par` is a paragraph *terminator*, so `flushParagraph(allowEmpty:)` emits an empty body paragraph for two consecutive `\par` (a blank line); the implicit end-of-document flush passes `allowEmpty:false`, so a doc with no trailing `\par` gains no spurious empty final paragraph. (Raw, un-backslashed CR/LF stays ignored per spec; `\line` is still a soft in-paragraph break.) Regression-guarded by `RTFImportTests.test_backslash*`/`test_*Par*` + `RTFImportCorpusTests.test_cocoaStyle_*`. Spec/plan: `docs/superpowers/{specs/2026-06-25-richtext-rtf-import-design.md,plans/2026-06-25-richtext-rtf-import.md}`.

**Other open work:** Phase 5e images toolbar (Photos/Files picker, alignment toggle, interactive drag-resize); Phase 6b new
paragraph styles (Subtitle / Code) + a Dash list marker (Caption landed 2026-06-13 as a render-only style); Phase 6c floating pill keyboard toolbar
with active-state (`currentFormatState()`), replacing the crude demo toolbar; block-view **Step 3**
(arbitrary non-focusable embeds); perf follow-ups (viewport-size the wash/chrome overlays; incremental
layout; emoji count-virtualization); spoiler a11y (VoiceOver hiding of unrevealed text) + markdown
`||spoiler||`.

## Workflow

Phase-by-phase, each its own cycle: **brainstorm (`superpowers:brainstorming`) → spec → plan → TDD /
`superpowers:subagent-driven-development` (test after each task) → holistic review →
`superpowers:finishing-a-development-branch`** on a feature branch. Commit messages end with the
`Co-Authored-By` trailer.

**Design docs are not in-tree.** The per-phase specs, plans, spike findings, and handoffs live only in the
pre-move archive at `~/Documents/RichTextEditor/docs/superpowers/{specs,plans,spikes,handoffs}/`. The
foundational two: the main design spec (`2026-05-30-ios-rich-text-editor-design.md`) and the
table-selection **spike findings** (`2026-05-30-table-selection-spike-findings.md` — the API learnings that
drove the single-`UITextInput` architecture and its caveats).

## The K-sims moved to iOS 27, and two suites are now environmental (2026-09-15)

Xcode 27 (`27A266a`) removed every simulator; the dedicated K-sims came back as **iPhone 18 Pro on
iOS 27.0** with new UDIDs (K1 `03A7DA9C-1832-49B8-9858-2F54F2FB5A04`, K2
`E643A78E-DB62-4DA4-9F54-BD0836F434AF`, K3 `4483DD69-685A-4FE1-89BE-65F992C271F2`). Every script and
recipe that named a UDID was updated; older plans and specs still name the dead ones, deliberately —
they are records of runs that happened.

Two suites fail on 27.0 for reasons that are **the runtime, not the code**, and each was told apart
from a real regression by measurement rather than by argument:

- **`LegacyDifferentialTests` (5 cases)** says so itself: `test_theRunningSimulatorIsTheCorpusCaptureBuild`
  fails with "DIFFERENTIAL RUN IS ON THE WRONG SIMULATOR RUNTIME." The differential corpus was
  captured on iOS 26.5 / `23F73`, so a comparison against it on 27.0 means nothing. That test exists
  to make the other four uninterpretable rather than quietly wrong — which is exactly what a
  differential baseline should do when its baseline moves. Re-capture the corpus on 27.0 before
  reading those four again.
- **`IDUpstreamResponderModelTests` (6 cases)** is a genuine iOS 27 behaviour change in UIKit's
  private responder/keyboard wiring (`inputDelegate` binding, `requiresKeyboard`). **Proven, not
  assumed:** the same commit passes 21/21 on a freshly created iOS 26.5 simulator and fails 6 on
  27.0, and the 2026-09-15 master merge touched none of the code those tests exercise
  (`Sources/RichTextInputDecUpstream/`, `InputBackend/` and `RichTextInputDecObjC/` are byte-identical
  across it). Do not "fix" them against 27.0 until the real UIKit change is understood — the port's
  responder model is pinned to stock behaviour, so the question is what stock now does.

**Making an iOS 26.5 control takes seconds and settles this class of question**:
`xcrun simctl create RTE-control-26.5 "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5`,
then `DEVICE=<udid> Scripts/iostest.sh <filter>`. An OS bump and a merge landing together is exactly
the shape where "it broke after I merged" is the wrong conclusion.

## Verification traps in this package (earned, 2026-08)

Nine measurement traps that cost real time during the input-backend seam work. Each is specific to this
package or this repo, and each produced a **green result that meant nothing** until it was caught.

- **`Scripts/iostest.sh` prints one `Executed …` summary PER TARGET, and the LAST is Core's.** Tailing the
  log gives you the Core number (a few hundred) and reads as the whole suite (a few thousand). Always record
  the decomposition: `N executed (UIKit X / S skipped + Core Y), exit 0`.
- **`swift test --filter <Suite>` DOES work — but the UIKit bundle prints its own `Executed 0 tests` line
  FIRST, above Core's real result.** So `--filter … | head -1`, or eyeballing the first summary, yields a
  false zero that reads as a vacuous pass. (An earlier version of this entry claimed the filter selects
  nothing at all; that was wrong, and it was wrong because it was written from a `head -1`. Corrected
  2026-08-24 when a Core suite filtered cleanly to 6 tests.) This is the same trap as the entry above it,
  one level down: **read ALL the summary lines, never the first or the last.**
- **`swift test` compiles NO canvas code.** All 67 `Canvas/*.swift` files are `#if canImport(UIKit)`-guarded
  and the SwiftPM test build targets macOS, so a mutation planted in one of them proves nothing about
  compilation. Build for the simulator when the claim is "this would/wouldn't compile".
- **`sysctlbyname("kern.osversion")` in a simulator returns the HOST MAC's build** (e.g. `25G76`), not the
  simulated iOS build. Use `ProcessInfo.operatingSystemVersionString`. This matters because two iOS 26.5
  runtimes can be installed (`23F73` and a beta) sharing one identifier, and `device.plist` records only the
  identifier.
- **The `UITextInput` position axis is SPARSE**: a top-level paragraph boundary occupies TWO position slots
  where the text projection emits one `"\n"`. Offsets are NOT character indices. `positionFromPosition:offset:`
  does raw arithmetic then snaps, so aiming at a character index lands one character early past every
  boundary. See `DocumentCanvasView+ComposerSelection.swift` for the existing global↔flat mapper.
- **`BlockLayoutEngine.attributedString` returns the LIVE storage.** `let before = layout.attributedString`
  and comparing it after a mutation compares the object with ITSELF, so the assertion passes no matter what
  happened. A formatting lock-out test passed before its guard existed this way; only a control asserting
  the same gesture DOES change an unguarded block caught it. Copy first
  (`NSAttributedString(attributedString:)`), and commit the control alongside.
- **A canvas nobody retains is deallocated before a debounced pass fires.** `_ = makeCanvas(...)` in a test
  leaves the scheduled work item's `[weak self]` nil, so the pass never runs — and a test asserting
  "nothing was requested" then passes against a dead canvas rather than against the rule. Hold the canvas,
  and give any "nothing happens" test a positive control in the same document.
- **`DispatchQueue.main.async { fulfill }` is not a way to wait for `asyncAfter`.** The timer-backed work
  can land after the plain async block, so the wait returns before the pass has run. Spin the runloop
  (`RunLoop.current.run(until:)`).
- **Never `pgrep -f "<pattern>"` from a watcher whose own command line contains that pattern** — it matches
  itself and the loop never exits. Wait on a PID or a sentinel file. (Cost 42 minutes once.)
- **`swift build` cannot gate the vendored `RichTextInputDecObjC` kernel.** Every kernel header and
  `.m` is `TARGET_OS_IOS`-guarded, so on macOS the target's eleven guarded objects compile at ~2.4 KB
  each defining zero Objective-C classes, while an iOS-simulator build of those same eleven `.m` files
  defines 15 classes (confirmed identical between the SwiftPM simulator build and Bazel's
  `libRichTextInputDecObjC.a`). A broken `#import` spelling stayed green under `swift build` for two
  whole tasks; only an iOS-simulator or Bazel build is evidence about this code.
- **SwiftPM does not propagate `cSettings.headerSearchPath` to a Swift importer's module build.** Only
  `include/` itself is passed to dependents as a search path; a `cSettings` entry applies to this
  target's own `.m` compiles, not to the clang module build a Swift `import` triggers. That is why the
  two authored public headers (`include/TGRichTextInputDec.h`, `include/TGRichTextInputDecContract.h`)
  import the kernel as `"Kernel/…"` rather than by bare name — a quoted import under the
  umbrella-directory module resolves relative to the including file's own directory first. Bazel's
  `includes` attribute lists both `include` and `include/Kernel`, so it accepts either spelling —
  "simplifying" those two imports back to bare names would regress SwiftPM while Bazel stayed green,
  silently, and in the opposite direction from where you'd look.
- **A header ADDED to an `include/` umbrella directory is invisible to the other targets' Xcode build
  until their explicit module PCMs are deleted.** SwiftPM gives each C-family target an
  umbrella-DIRECTORY module, and Xcode's explicit-modules build keeps the PCM it built before the
  header existed (`DerivedData/<pkg>/Build/Intermediates.noindex/{,Swift}ExplicitPrecompiledModules/<Module>-*.pcm`).
  The symptom does not look like a module problem: the `#import` resolves (no "file not found"), the
  file's own target compiles, and every OTHER target reports "call to undeclared function" for what
  the header declares. Clearing `ModuleCache.noindex` does not help; deleting those PCMs does
  (2026-10-12, adding `TGPrivateRuntimeNames.h`; three builds).
- **A DerivedData directory's mtime is not its birth time.** `%Sm` moves every time anything inside the
  directory is touched, so a directory created well before your run can still read as "created just
  now" if you check it late. Task A7 concluded a DerivedData directory "did not exist before this run"
  from exactly that misread; re-checked with `stat -f %SB` (birth) vs `%Sm` (mtime), the directory's
  actual birth predated the moment that had been read as its creation, and some of the object files
  inside it were older than others — a cache hit sitting next to a fresh compile, not all-fresh output.
  Prefer "this artifact could not have existed before, because its source did not" over any timestamp
  argument alone. Same trap the root `CLAUDE.md` already documents for `Telegram_archive-root/`.

- **A test that WAITS for a callback cannot see a duplicate of it, and a test that COUNTS one must
  drain its own setup first.** An `XCTestExpectation` armed for "fires exactly once" fulfils on the
  first delivery and `wait(for:)` returns; a second delivery a run-loop turn later lands after the
  test method has finished, so the test passes while the contract is broken. That is how a double
  `onChange` survived in the engine editor across three documented "fix rounds" of the exactly-once
  property — and the two cases that DID trip over it (`EngineListContinuationTests`, on a repeat
  `fulfill`) had the whole class skipped from every run as flaky rather than read (2026-09-04).
  Counting deliveries over a fixed window catches it, but the counter has a trap of its own: seeding
  the document and the caret is itself a change that schedules a delivery, and with the counter
  installed straight afterwards that setup delivery is counted against the edit, so EVERY case reads
  as 2 whatever the code does — which is exactly the wrong conclusion it produced first. Drain a
  run-loop turn between the setup and the counter, then confirm by reverting the fix and watching the
  count go back up. See `EngineChangeNotificationCountTests`.

**And the general form of all ten:** before recording a result as evidence, prove the instrument can
produce the other answer — an empty one where you expect content, a 2 where you expect a 1. A count
from an unvalidated command is not a measurement.

## Wide tables under a finger (2026-09-11)

Four defects behind one report — "wide tables are barely scrollable and don't overscroll" — every
one visible only on a table wider than the canvas, and three of them in the structural chrome that
rung B built on a table that fit:

- **The structural chrome claimed every touch over the table.** `TableStructuralChromeView` spans the
  table so its grips can hang outside the grid, and with no `point(inside:)` of its own every touch on
  the body was its. The run's horizontal pan is hosted by the stack canvas BENEATH it, which the chrome
  is not inside, so with the caret in a wide table a swipe scrolled nothing at all — and the view's own
  tap recogniser beat the engine's text tap, so a tap on another cell moved no caret either. The view
  now exists for touches only over a grip or a knob, and a grip wins over a knob whose 44pt box reaches
  into the gutter over it.
- **The chrome was anchored at the scrolled cell frame and then shifted again.** `tableFrame(forTableAt:)`
  reads the engine's cell frame, which rides the run's scroll; the view was placed at it AND
  `viewRect(_:scrolls:)` subtracted the offset, so the outline and the column grip sat one offset left
  of their cell and the row grip left the gutter with the content. Anchored at the unscrolled origin now,
  with everything the chrome draws clipped to the run's visible band (legacy's `drawTableChrome` clip),
  so a scrolled-off grip is neither drawn beside the table nor hittable there.
- **The document's scroll won a vertical knob drag.** The engine is a scroll view whose pan begins on
  any vertical movement even when the content fits (it bounces), and it cancelled the chrome's pan
  under it — a horizontal knob drag extended the selection, a vertical one did nothing.
  `tgid_shouldBeginScrollPanHandler` is legacy's `GripYieldingScrollView` yield: the scroll pan declines
  a touch on a knob, and only a knob. A second hook, because `tgid_shouldBeginTextInteractionHandler`
  exempts the scroll pan on purpose — a drag that starts on a photo must still scroll the editor.
- **No overscroll was upstream.** Every scroll tick re-runs the stack canvas's layout pass
  (`scrollViewDidScroll:` marks the text view for layout), and `closeRun` clamped the run's offset into
  range on every run, cancelling the rubber band one frame at a time. Upstream `511a07b4` clamps only
  when the run's geometry changes, and assigns the frame and content size only on a change — a
  same-value assignment re-adjusts the offset too, which is what made the first cut of the fix read as
  no fix at all. Re-ported the same day.

- **The chrome did not follow a scroll at all** ("cell selection does not follow scrolling", the
  next report): the chrome was re-placed only from the editor's `layoutSubviews`, and a scroll tick
  lays out the ENGINE and nothing else — the engine is a subview, and nothing marks its host. The
  sink gained `engineDidLayout`, sent after the engine's own `layoutSubviews`, and the editor
  re-syncs the structural chrome from it (only that: every other overlay inside a run lives in the
  run's content view and rides the scroll on its own). The harness had shown this first — a bare
  `layoutIfNeeded` after a programmatic scroll re-synced nothing — and the first reading of that was
  "the harness differs from the device", which it did not.

- **A cell edit scrolled the table back to its start** ("setting alignment on cells resets
  scrolling"). The splice keeps the first cell's identity, so the run's scroll view survives, but
  every other cell is a fresh block the host has not placed when the engine's change pass runs: for
  that one pass the run is a single cell wide and the engine clamps the offset to zero, and the host
  pushes the frames a layout later. `replaceTable` sets the offset aside in `pendingRunOffsetRestores`
  and `restorePendingRunOffsets` (from `engineDidLayout`) puts it back on the first pass in which
  every cell of the table is placed again — legacy's `pendingOffsetRestore` in `TableBackingView`.
  Recorded BEFORE the edit: the article host re-runs its layout from `onChange`, synchronously, and
  that lays the engine out inside the notification block — recorded after it, the one pass that
  could restore found nothing, and the device still reset.

- **Three more from the same screen** (2026-09-11): choosing an alignment dropped the structural
  selection — the splice parks the caret and the selection funnel clears on any move it was not told
  about, so `replaceTable` now runs under `isParkingCaretForStructuralSelection`, and a structural
  action still clears afterwards through the menu's `perform`; the run's scroller showed its own
  horizontal indicator (upstream `IDPlacedRunScrollView` now shows none — a host draws its chrome);
  and a knob on the table's top or right border was cut in half, because `draw` cannot paint outside
  the view's bounds — the chrome now overhangs those two borders by `knobOverhang`, and the visible
  band reaches past the run's right edge by the same amount.

- **The right border never scrolled into view.** The run is the union of the placed cell frames and
  the outer border lies outside every cell, so the content ended one border short. The last column's
  frame is now one border wider and its right inset one border larger, both from
  `EngineTableGrid.trailingBorderExtension(for:)` — the mirror of the last row's bottom inset, which
  already extended the run downwards.
- **Tapping a cell often placed nothing.** The knobs' 44pt boxes (legacy's size, at the side
  midpoints) reach 22pt into the neighbouring cells — the centre of the cell above or below the
  focused one on a ~43pt row — and both the chrome's tap recogniser and the text-interaction veto
  treated that as the knob's. A knob now keeps its drag and gives up the tap: the chrome view is its
  recognisers' delegate (`claimsTouch(at:for:)` — tap for grips, pan for knobs; a recogniser that
  receives a tap and does nothing with it still cancels the text tap under it), and the veto learned
  `isTap` from the shim, refusing a tap over grips only and a drag over both.

Two harness facts from the same investigation, worth more than the hour they cost: `axe tap` (an
instant down/up) never places a caret in the engine — `axe touch --down --up --delay 0.08` does — so a
"tap does nothing" from AXe is not a defect; and the XcodeBuildMCP debugger's DAP backend cannot
evaluate expressions, while `xcrun lldb -p <pid> --batch -s <script>` against the simulator process
can (after `expr @import UIKit`), which is how the view hierarchy, the hit-test and the clamp were all
confirmed in-process before a line was changed.

## Inline formulas and buttons inside tables; Button ▸ Inline (2026-09-11)

The Add menu was unreachable inside a table — the action bar disabled "+" whenever the caret was
in a cell — so nothing could be added there, inline formulas included, although `insertInlineFormula`
had worked in a cell all along. The bar's "+" is now always reachable and the menu NARROWS in a cell
to the two inline forms, each as its own item (Formula, Button): a block placed from a cell lands
after the whole table (`planAtomUnitPlacement`), so Standalone and Row would read as items that do
nothing. The "list" button stays disabled in tables.

Button became a submenu like Formula, for the same reason (an inline pill and a block row are
different documents): "Inline" authors the pill in `ButtonEditorScreen` FIRST — prefilled with the
selection's text as its label — and calls the new protocol verb `insertInlineButton(_:)`, which puts
the pill at the caret, replacing the selection; "Row" is `insertButtonRow` as before. The engine's
verb mirrors `insertInlineFormula`: a cell is a paragraph like any other, a code block takes the
label as plain text, an atom refuses. The LEGACY view's implementation is composed from the verbs
its canvas already has (type the label, select it, `makeSelectionInlineButton`, then
`replaceInlineButton`) because the canvas is closed to this branch — three undo steps for one
insertion, and an empty label is typed as a single space so there is a run to convert. The old
"selection becomes a pill" item is gone from the menu; `makeSelectionInlineButton` stays on the
protocol for the composer's edit menu. `RichText_MenuInlineButton` reads "Button" and is the
submenu's parent; only `RichText.MenuButtonInline` ("Inline") was added.

## Autocorrection underline and revert in the engine editor (2026-09-11)

"When a word gets auto-corrected, UITextView underlines it in blue and a tap offers the original;
we don't have one." Recovered by in-process work on iOS 26.5 `23F73` (`xcrun lldb -p`, a Python
breakpoint tracer, `disassemble -n`, runtime ivar dumps — Hopper reported no content). The first
theory was wrong and shipped as `52df72b99e`; the measured mechanism is this:

- **How the keyboard delivers an accepted correction — NOT through `insertText:alternatives:style:`.**
  `_UIKeyboardStateManager acceptAutocorrectionForWordTerminator:` → `acceptAutocorrection:…` →
  `applyAutocorrection:` → `-[UIKBInputDelegateManager replaceRange:oldText:withText:forReplaceAction:]`
  → the text input's plain **`replaceRange:withText:`** with the corrected word (traced: "taht"→"that",
  "thier"→"their"). The engine's `insertText:alternatives:style:` never fires for a correction; the
  delegate manager takes that family only for a client that inserts text WITH alternatives.
- **The underline is UIKit's, drawn by the text-choice acceleration assistant.** After the replace,
  `underlineCandidate:` → `-[UIKeyboardImpl underlineCandidate:]` (gated on
  `+[UITextSelectionDisplayInteraction isTextAccelerationUIEnabled]` and `shouldUnderlineCandidate:`)
  → `_rangeForAutocorrectionText:` → `-[_UITextChoiceAccelerationAssistant addUnderlineForCandidate:range:]`
  (the assistant is owned by the text input's `UITextInteractionAssistant`), which stores the range
  and candidate and later — from `updateUnderlineGeometryIfNeeded`, a delayed perform that the
  engine's own `setNeedsSelectionDisplayUpdate` schedules through `setNeedsUnderlineUpdate` — asks
  the text input for `selectionRectsForRange:` and places a `_UITextUnderlineView` (the display
  interaction's, in its host view below the text) at each rect's **private `baselineOffset`**. The
  tap is the assistant's `_UITextChoiceInteraction`; the prompt with the original word is its
  `_UITextChoiceAccelerationBubble`. All of it already ran against the engine.
- **What was wrong: the baseline was infinity.** `-[UITextInputController selectionRectsForRange:]`
  asks the layout controller's `requestTextGeometryAtPosition:typingAttributes:resultBlock:` for the
  range's end and stamps the block's baseline (`setBaselineOffset:`) on every rect. UIKit's block
  takes FOUR arguments — `(NSTextContainer *, CGRect, CGFloat baselineOffset, UITextPosition *)` —
  and the engine's stand-in invoked it with the rect alone: a CGRect travels in d0–d3 whatever its
  position, so the rect always landed, and the baseline was read from d4, which nobody had set.
  `underlineRectForTextSelectionRect:forCandidate:` falls back to three quarters of the height only
  when it reads 0, so infinity went straight through: `<_UITextUnderlineRect: rect = {{112, 70},
  {34, 24}}; offset = inf>`, underline subview at `{{112, inf}, {34, 2}}`.
- **The fix is upstream, in two layers.** `id_requestTextGeometryAtPosition:` now invokes the block
  with all four arguments and the line's baseline (from the same TextKit segments the selection
  rects use; 0 when the block has no layout yet — read as "unknown", never raised, since this runs
  inside UIKit's own geometry calls). And `IDRichTextSelectionRect` carries a `baselineOffset` of its
  own — TextKit 2's `baselinePosition` from `enumerateTextSegmentsInRange:`, threaded through
  `IDBlockSelectionSegment` and `IDDocumentSelectionSegment` — so the rect's answer is per LINE where
  UIKit's stamp is one value per range. Pinned upstream by parity tests against `UITextView` (both the
  rect's answer and the stamped ivar, within 1pt of the font's ascender) and host-side by
  `EngineSelectionRectBaselineTests`, which reads the stamped storage past the engine's accessor.
  Neuter-verified: dropping either layer alone fails its own test.
- **The shim's `TGIDTextAlternatives` family stays**, corrected in what it claims:
  `insertText:alternatives:style:`, `rangeWithTextAlternatives:atPosition:` and the rest are
  `UITextView`'s surface for text inserted WITH alternatives (dictation), annotated through the layout
  controller into TextKit 2 temporary attributes; a keyboard correction does not use it.
  `EngineTextAlternativesTests` pins the family.
- **Measuring it cost more than fixing it, and three harness facts are the reason.** (1) `axe type`
  is a hardware keyboard, which never accepted a correction here — six characters land in under
  100ms, before the candidate exists — and after three uncorrected "teh"s the keyboard LEARNED the
  word; tap the on-screen keys (`axe touch --delay 0.08`, one every 0.35s) and pause ~2s before the
  space. (2) An lldb breakpoint that stops while the word is typed breaks the candidate timing and
  reads as "no autocorrection at all": break only on the acceptance methods. (3) The assistant keeps
  its underline data across corrections, so a dump after the fact shows the stored range and the
  zero-framed underline view even when the trace missed the moment — that dump is what found the
  infinity. The upstream `IDAutocorrectionDecisionUITests` fail for the same reason (1) on this
  machine, on the stock `UITextView` too: environmental, not a regression.
- **Then the prompt came up 68pt below its word, and that was a second defect — the container's
  coordinate space.** UIKit places the bubble through two conversions and performs only one:
  `-[_UITextChoiceAccelerationAssistant convertedSelectionRect:]` is
  `[[self _underlineView] convertRect:[rect rect] fromView:[[self _document] textInputView]]`, moving
  the word's rect into the client's `-selectionContainerView` (where it hangs the underline view),
  and `showPromptForReplacementCandidate:originalCandidate:delay:` then hands those same numbers to
  `-[_UITextChoiceAccelerationBubble updateWithChoices:fromParentView:referenceTextView:presentedFromRect:textHighlightColor:]`
  with `referenceTextView:` = `-textInputView` — read back relative to the text input view, no second
  conversion. **So the container and `-textInputView` must be ONE space.** A stock `UITextView`
  satisfies it by construction (scrolled to `contentOffset` 120, its `_UITextContainerView` and its
  selection container are the same rect and the container's origin in it is `{0, 0}`); the engine's
  `IDNativeSelectionPresentationBackend` anchored the container to the host's **`bounds`**, so a
  scrolled editor put the two a content offset apart — on K3 the word's rect `{{16, 137}, {25, 24}}`
  (window y 269.3, where it is drawn) reached the bubble as `referenceRect` `{{16, 337.3}, …}`, the
  composer's 68pt top inset below it. The container now starts where the block stack does and keeps
  the viewport's size, which takes no part in the mapping. `IDTextView` had the same defect one text
  container inset out, fixed the same way. Upstream `d0787f4b`; pinned by a parity test against a
  stock text view at the same scroll offset, by two upstream round-trip tests, and host-side by
  `EngineSelectionContainerSpaceTests` (both host assertions fail by exactly 68 when neutered).
  Everything drawn IN the container — the underline, the selection, the grabbers — was always right:
  those go through the explicit conversion, which is why only the prompt moved.

## Three structural changes from the table review (2026-09-11)

A scoped re-review of the table/inline wave found three defects, and each belonged to a class the
branch had already paid for more than once. These are the answers to the classes, not to the
reproductions.

### 1. The derived-view check asks WHERE, not only WHETHER

`verifyDerivedViewsAreComplete` asked whether a role's view exists. Every table defect taken from a
device report was the other question — the view existed and was in the wrong place: the chrome stayed
put while the cells scrolled under it, the outline sat one offset left of its cell, a table drew on
top of the one above it. `derivedViewPlacementDrift()` (`+DerivedPlacement.swift`) answers it for the
grid chrome, the structural chrome and every attachment overlay, comparing each view's `frame` and
its SUPERVIEW against the placement now.

- **It shares the producer's derivation, deliberately — and that is the opposite of the rule the
  existence check follows.** The two answer different questions. Existence asks whether the producer's
  own `live` set agrees with the roles, so a check reading that set agrees by construction and is
  worthless. Placement asks whether the pass RAN, so the one thing it must not do is derive the number
  a second way: two derivations of one placement is the defect, not the instrument. `syncTableChrome`,
  `syncTableStructuralChrome`, `syncCustomEmojiViews`, `syncInlineButtonPills` and
  `syncFormulaTapTargets` all place from `gridChromePlacement` / `structuralChromeFrame` /
  `attachmentOverlayPlacement`, and the check re-reads those. What it cannot catch is a placement
  function that is itself wrong; the golden and behavioural tests own that half.
- **The structural chrome's SCROLL INPUTS are checked too.** Its frame is anchored at the table's
  UNSCROLLED origin, so it does not move when the run scrolls — `contentOffsetX` and `visibleWidth`
  are the only things a scroll changes, and they are what went stale. Neutering the chrome's
  scroll-follow now trips the check in a test that asserts nothing about the chrome:
  `structural chrome t0 drawn at offset 0.0 with the run at 40.0`.
- **It runs on the ENGINE's own pass too** (`verifyDerivedViewPlacement` from `engineDidLayout`) —
  a run's horizontal scroll dirties the engine and marks nothing else, so the pass that moves a
  table's cells is one the host's `layoutSubviews` never sees. Two guards keep it honest:
  `isPlacingDerivedViews`, because the engine lays out in the MIDDLE of the host's pass (when
  `syncTableFrames` pushes frames) and the syncs after that point are legitimately stale then; and
  `layer.needsLayout()`, because a pending host pass is about to re-place everything. Existence is
  NOT checked there — the engine lays out before the host has ever placed a view for a freshly set
  document, and "not created yet" is not a defect.

### 2. A table's scroll offset is host-owned state, not parked work

`replaceTable` used to read the run's offset, park it in a dictionary, and put it back when an event
arrived. That produced three defects in two days: the value had to be recorded BEFORE the change
notification (the article host lays out synchronously from it), it was applied on an event a pass
could fail to deliver, and a measurement probe could spend it against a width nobody had committed
to. `runScrollOffsets` + `runScrollIdentities` (`syncRunScrollOffsets`) replace it: every settled
pass MIRRORS each run's offset into the host, and a pass whose table has different cell identities
than the mirror was taken against PUSHES the host's value back instead. Nothing is parked, so none of
the three has anywhere to happen — and it covers every rebuild, not only the edits that remembered to
park one.

- **Identity is the whole signal.** A splice keeps the first cell and mints the rest, so for the one
  pass in which the run holds a single placed cell the engine clamps the offset to zero. Different
  identities ⇒ that clamp; the same identities ⇒ the user. Runs whose cells are not all placed are
  skipped in both directions: the run is not at its real width, so its offset means nothing.
- **`height(forWidth:)` now ends with `pushRunScrollOffsets()`.** A probe WIDER than a table leaves
  its run with no scrolling range, the engine clamps the offset to zero, and restoring the frame does
  not bring it back — the composer probes before choosing a width, so this was the ordinary path.
  That was a fourth defect, found by writing the test for the third.

### 3. The chrome's controls are views

The grips and the knobs were rects in an array, drawn by `TableStructuralChromeView.draw` and
hit-tested by a parallel loop over the same source. The two loops disagreed: a knob is SHOWN when its
centre is inside the run's visible band, while its 44pt hit box reaches 22pt further, so a knob
scrolled out of the run kept a strip of invisible hit area at the band's edge — and the document's
scroll pan yields to knobs, so a horizontal drag there resized a selection instead of scrolling the
table. Each control is now a `TableStructuralControlView` with a frame, an `isHidden`, and its own
recogniser; the container draws the outline and nothing else.

- **One geometry, one visibility, UIKit's hit-testing.** `drawnHandleRects`/`drawnKnobRects` are
  derived from the visible children, so the test seams cannot describe anything but what is on screen
  and touchable.
- **The tap/pan split is what a control CARRIES**: a grip has a tap recogniser and no pan, a knob a
  pan and no tap. `claimsTouch(at:for:)` and the container's `UIGestureRecognizerDelegate` are gone,
  and a tap over a knob is never delivered to the chrome at all — which is what kept it from
  cancelling the engine's text tap (the 44pt boxes reach into the neighbouring cells' centres).
- **A drag cannot jump knobs**, because the knob IS the gesture's view. `draggingStructuralKnob` and
  its `began`-only lookup are deleted.
- **Controls are reconciled by KEY, never rebuilt.** A knob drag updates the chrome on every frame,
  and a view replaced under a live pan takes the gesture down with it. The key is the control's shape
  (`knob.end.lower`, `grip.rows`), never its range.
- **What a grip LOOKS like is legacy's `drawHandleDots`, carried over** (2026-09-11): three dots —
  ⋮ in the left gutter for a row, ⋯ below the table for a column — 4pt across with a 3pt gap, in
  `secondaryLabel`; and ONLY while its own row or column is the structural selection do they sit on
  an accent bar and invert to `systemBackground`. The bar rounds the two corners AWAY from the table
  (radius = its short side) and leaves the two meeting the border square, so it reads as a
  half-capsule hanging off the grid. The engine editor drew a filled accent capsule in both states
  and no dots at all. Those two semantic colours are legacy's own literals — the editor theme has no
  entry for either, and matching the look means matching them. The knobs already matched (an accent
  circle of `knobRadius`). Pinned by rendering `draw(_:)` into a buffer and counting the dots, which
  is the only kind of test that can say anything about a look.

## The table chrome is a view tree, and nothing draws on a scroll (2026-09-11)

Both chromes rasterised themselves on every update. The grid chrome stroked its border, filled its
cells and painted its interior lines in `draw(_:)`; the structural chrome stroked its outline there,
and `update(...)` — which a placed run's horizontal scroll calls on EVERY tick, because the engine
lays out per tick and the host re-places the chrome from `engineDidLayout` — ended in
`setNeedsDisplay()`. A knob drag did the same per frame. Both are now view trees whose pieces are
positioned, never redrawn.

- **The grid chrome**: a clipping container of per-cell fill views, one view per interior line
  segment, and the outer frame as a LAYER BORDER on a rounded view. A border is painted inside the
  layer's own rounded edge, which is exactly what a stroke inset by half its width was; the clip is
  `clipsToBounds` + `cornerRadius` on the fill container, at the same radius the clip path used.
- **Merged cells stopped needing an eraser.** The drawn version painted a full-height line per gap
  and then repainted every spanning cell OVER it — with a `.copy` blend, because a merged cell with
  no fill of its own had to erase the line rather than cover it. Interior lines are now SEGMENTS
  that stop where a cell spans the gap, so nothing is painted that has to be taken back, and a
  `clear` fill is no longer doing double duty as an eraser.
- **The structural chrome**: the outline is a bordered view (radius `outerCornerRadius + width/2`,
  `maskedCorners` from the model's `UIRectCorner`), and the band clip — whose only effective edge
  was the run's right edge, which sits exactly on this view's own width — is `clipsToBounds`. Hit
  testing is unaffected: `point(inside:)` answers for the controls, so a knob's 44pt box still takes
  touches past the top edge while only its 4pt circle shows.
- **Grips and knobs**: a bar view (rounded on the two corners away from the table) plus fixed-size
  dot views. The bar stretches with the selection; the dots do not — a stretched bitmap could not
  have given that, and it is why legacy's look survives the change.
- **Every grip rides the table's scroll, and the row grip is MIRRORED** (2026-09-11). Legacy anchors
  its row grip to the table's unscrolled left edge, so it sits in the gutter whatever the run does;
  here a grip hangs off an EDGE of the table, and an edge that scrolls away takes its grip with it —
  so a wide table shows the leading grip at its start and the trailing one at its end, and
  `viewRect(_:scrolls:)`'s asymmetry is gone with the parameter. `HandleSide` (`leading`/`trailing`/
  `below`) is what tells the mirrored pair apart: it keys the control's reuse across passes, picks
  which way its dots run, and picks the two corners its selected bar rounds. The visible band opens
  by a grip's width on BOTH sides now, and the chrome view's frame carries a gutter on each — the
  band's right edge and the view's width are the same number, which is what keeps `clipsToBounds`
  the band clip.
- **What pins it**: `test_noTableChromeClassOverridesDraw` compares each chrome class's `draw(_:)`
  IMP against `UIView`'s, so an override cannot come back unnoticed;
  `test_noTableChromeViewAsksToRedrawOnResize` rules out `contentMode = .redraw`, the other door
  (it asks for a fresh `draw(_:)` on every bounds change — every frame of a knob drag); and
  `test_aScrollLeavesEveryChromeLayerWithNothingToDisplay` walks both layer trees after a scroll and
  asserts nothing wants to rasterise.
- **The one `draw(_:)` left in the editor is the list marker**, which draws TEXT. It is guarded by
  an equality check on label/font/colour and is re-placed only from the host's layout pass, so it is
  not on the scroll path at all.
- **Reading a view tree in a test**: `CALayer.render(in:)` is how the look tests get pixels without
  a window, and it IGNORES `maskedCorners` — it rounds all four. So one-sided rounding is asserted
  where it is declared (`shownBarCorners`) and the dots from the buffer.

## A toolbar query that scheduled itself (2026-09-11)

"When there is any kind of handle selection, scrolling a table lags a lot." It was not the scroll
path at all — `sample` on the running app put 399 of 420 main-thread samples in one stack:

    scheduleSelectionDrivenOnChange → RichTextAttachmentScreenComponent.View.update
      → RichTextEngineEditorView.currentState() → currentInlineTraits()
        → structuralTraitState(_:) → engineSelectedRange.setter
          → -[UITextInputController setSelectedTextRange:] → _coordinateSelectionChange:

The engine answers an inline trait for its CURRENT selection and has no range-taking variant, so
asking what a structural selection's cells are wearing meant parking the selection in each cell and
putting it back. Every park reached the selection funnel, which SCHEDULES a host `onChange`; the
article host answers one by re-running its component update, which asks for `currentState()`, which
parks the selection again. A structural selection left the editor in a run-loop-cadence loop, and a
scroll — which relayouts the engine per tick — fought it for the main thread.

- **A probe is not a selection change.** `isProbingInlineTraits` makes the funnel ignore the parked
  moves: the selection is restored before the call that made them returns, so reporting them was
  false. (`isParkingCaretForStructuralSelection`, which was already set here, guards something else —
  the structural selection's own clear — and `replaceTable` needs the notification it suppresses.)
- **One pass, not four.** It ran per trait, so a four-trait toolbar query parked the selection
  4×(cells+1) times. All four are read per cell now, and answered together as `InlineTraitQuartet`.
- **Cached against the only two things that can change it**: the document, and the structural
  selection. A host that asks on every update pays once per change.
- Pinned by `EngineChangeNotificationCountTests
  .test_readingTheToolbarsTraitsOverAStructuralSelectionSchedulesNothing`, which counts deliveries
  over a window (waiting for one would have seen the first and missed the loop entirely) — the same
  instrument trap that file was written for.

**The lesson worth keeping is about `sample`.** The synthetic harness — 60 scroll ticks over a
6-column table, timed — measured 0.9ms per tick both with and without a selection, and would have
sent the fix in the wrong direction: the per-tick placement check I suspected costs 0.055ms. The loop
only exists with a real HOST attached, because the host's update is one half of it. `sample <pid> 2`
on the simulator's own process is the instrument that found it, and it took one run.

### The row outline's corners

With a grip on both sides of the table, a row selection rounds NOTHING: an outline corner curving
away from a bar's square edge reads as a notch. The left-hand pair had been square for that reason
since the grip existed; the right-hand pair joined them when the grip was mirrored.

## A list marker sits on the ENGINE's baseline (2026-09-11)

"Fix list bullet/item alignment." The marker floated above its text: 1.7pt at body, 4.0pt at a
heading, measured from rendered ink and reproduced in the harness from the device's own numbers.

**The engine pins each line box to V2's pitch and TextKit BOTTOM-ALIGNS the line inside it** — the
baseline sits exactly one descender above the box's bottom, verified across five styles. The marker
was placed at the font's ascender from the box TOP, so it floated by `pitch - lineHeight`.

- **Legacy does not have this problem, and that is why the rule was wrong here.** Legacy CORRECTS
  TextKit's placement back to V2's (`BlockLayoutEngine.baselineDelta`, "baseline placement is
  MEASURED, not derived") and then draws the marker on the corrected baseline, so
  `firstBaselineFromTop(font) == font.ascender` holds for it. The engine draws its own attributed
  text with no such correction; porting legacy's marker geometry without porting its correction is
  what carried the defect over.
- **`EngineListMarkerGeometry.baselineFromLineTop(font:pinnedLineHeight:)` is the engine's rule**,
  and it degrades correctly: `maximumLineHeight` is 0 when the style pins nothing (an explicit
  model-level `lineHeightMultiple` takes over instead), and the box is then the font's own line, for
  which the formula reduces to the ascender exactly.
- **The marker's FONT comes from the mapper the bridge rendered that role with**
  (`EngineDocumentBridge.renderMapper(for:)`), not the plain one: a quote renders its text at 15pt
  at any depth, so the marker was a 17pt ordinal beside 15pt text — and on a different baseline,
  since a different pitch is pinned.
- **The `interiorPadding(...).top` term is gone** with the deferred note that described it. It was
  there to push the marker down inside a container, and the engine already places a nested block's
  frame below that inset; the ink test at depth is what settles it.
- **Pinned against RENDERED INK**, because where a glyph lands is the whole question: the tests
  render the editor's layer and compare the ink of the marker column with the ink of the text
  column, using the SAME glyphs in both ("1." marker against "1." text) so each glyph's own ink
  extents cancel. Two traps that cost measurements: an 'H' compared against a "1." folds the two
  glyphs' different ink boxes into the answer, and an unwindowed scan picks up the quote's BAR and
  its author-line placeholder instead of the marker.

## Focus is the ENGINE's transition to report (2026-09-11)

"Focusing on an editor does not expand the article editor." `RichTextAttachmentScreen` has wired
`editor.onBecameFirstResponder` to `requestAttachmentMenuExpansion()` all along, and a TAP never
fired it.

The wrapper (`RichTextEngineEditorView`) is not the text client — it deliberately never calls
`super.becomeFirstResponder()`, the engine child is the `UITextInput` — so its override runs only
when a host focuses the editor PROGRAMMATICALLY. A tap is delivered to the engine by UIKit's
text-interaction assistant, which calls `-becomeFirstResponder` on the engine directly; the
wrapper's override is never entered. So the host heard about every focus except the one users
perform.

- **`engineDidBecomeFirstResponder` / `engineDidResignFirstResponder` are on the observation sink**,
  beside `engineDidLayout`, overridden on `TGIDObservingBlockTextView` (telegram-authored — no
  upstream edit). `wasFirstResponder` is captured before `super`, matching `IDBlockTextView`'s own
  overrides, so a tap inside an already-focused editor reports nothing.
- **The wrapper's overrides no longer fire the host callbacks at all.** Left there as well, a
  programmatic focus would report twice — the wrapper forwards to the engine, which now reports.
  `test_focusIsReportedExactlyOncePerTransition` pins both doors.
- The tap path is pinned by driving `editor.engine.becomeFirstResponder()` directly, which is what
  the assistant does; a test that focuses through the wrapper cannot see this defect, which is why
  the editor had responder tests throughout and none of them caught it.

## Only a body paragraph may be internally empty (2026-09-11)

"An empty table does not cause an author block to appear in a quote." A quote holds CHILDREN, and a
child is content however empty its own text is — a table, a code block, a media atom, a button row,
a nested quote are all structure somebody added, and a quote holding one has something to attribute.
The one block that may be internally empty, and mean nothing, is a bare body paragraph.

Both passes that decide an author line asked the narrower question instead — "is any PRIMARY engine
block within the quote non-empty" — so a quote whose only child was a fresh table, or an empty code
block, or an empty nested quote, never got its author line.

- **Two passes, because a document SET never settles.** `EngineDocumentBridge.flatten` decides it on
  the set (over the MODEL's children) and `authorLinePresenceThatIsWrong` decides it on the next
  keystroke (over the ROLES). They must agree or a quote gains or loses its line the moment the user
  types anywhere, which is what `EngineBlockQuoteTests.test_settleAgreesWithTheForwardPassAbout…`
  pins from both ends. Each half was neuter-verified against its own test.
- **The role-side answer is `ContainerContents.isEmpty`**, which already asked it correctly of each
  child UNIT — the settle rule was a second, narrower spelling beside it. The model-side answer is
  `EngineDocumentBridge.isEmptyBodyParagraph`, named in both comments as the other's twin.
- **A PULL quote is not a container and takes the other rule.** It holds TEXT — one engine block, no
  children — so its author line follows that block's own length, which is what
  `PullQuoteBox.shouldShowAuthor` and the forward pass both ask. Asked the container question it
  answers "holds content" for an EMPTY pull quote (a `.pullQuote` shape is not a paragraph shape),
  and settle would mint a line the forward pass does not. The dispatch is on the owner's kind.
- **What this changes on screen:** a quote shows its author field as soon as it holds any child that
  is not an empty paragraph — including a nested quote, so `> >` shows the OUTER quote's field
  immediately while the inner's waits for text. Seven existing expectations moved with the rule and
  each says why at its assertion.
- **One test had to be re-fixtured rather than re-expected.**
  `test_deletingTheLastCharacterAfterAQuotedTableKeepsTheCaretInItsParagraph` guarded a caret restore
  that only runs when settle REMOVES an author line, and a quote holding a table never loses one now
  — so its fixture is two bare paragraphs (the shape that still reaches that path) and a sibling case
  pins the table's new behaviour over the original fixture. Re-expecting it would have left the
  caret-restore defect uncovered with a green test standing over it.

## A table in flight is the editor's, not the sheet's (2026-09-11)

The catch above was necessary and not sufficient. "'Catching' a decelerating table actually catches
the outer attachment controller's dismiss gesture" — and that is a level above the engine.
**Measured afterwards, with the caret in a table: the first responder IS inside the screen's editor,
so `isPanGestureEnabled` was already answering false and the sheet's pan was never the thief in that
case.** (A first walk said otherwise; it had found the wrong instance — there are TWO
`RichTextEngineEditorView`s in that window, and the responder is inside the screen's.) The gate below
is still right — it closes the unfocused case, which is a real one — but the focused case needed the
run to keep the gesture, which is the bullet above.

`AttachmentContainer`'s pan **recognises simultaneously with every other pan** (its delegate returns
true for pan-vs-pan) and decides what to do by walking up from the hit view to the nearest scroll
view — skipping a placed run by its aspect ratio and finding the ENGINE, the vertical one. The only
thing that keeps it off the editor is the screen's `isPanGestureEnabled`, which was
`!viewTreeContainsFirstResponder(view: editor)`: with the editor unfocused, which is exactly how you
read a document you are scrolling tables in, the sheet's dismiss was live over the whole editor. A
finger put down to catch a coasting table gave the sheet the drag.

- **`RichTextEngineEditorView.hasTableScrollInFlight`** (from `IDBlockTextView.id_hasPlacedRunInFlight`,
  upstream `ec31cab8`) is the fact the screen needs; `isPanGestureEnabled()` now answers false while
  it is true. The run is not in the touch's responder chain and cannot decline the gesture itself —
  the screen declines on its behalf, for exactly as long as the run is moving.
- **A content touch is not held back for 150ms, and that is what let a BOUNCE be caught at all.**
  `UIScrollView.delaysContentTouches` was YES on the engine and NO on the runs — so the delay came
  from the view that ENCLOSES them, and everything the content does with a touch was that late: the
  caret, a tap, and the catch. A coast (~800ms) survives the delay; a rubber band (~300ms) usually
  does not, so the catch arrived after the bounce had finished, which is exactly the shape of the
  report ("I can catch a decelerating table, but not an overscroll-bouncing one"). The pan still
  CANCELS a delivered touch once it knows the gesture is a scroll — `canCancelContentTouches` is
  untouched — which is the arrangement legacy's own canvas uses (`delaysContentTouches = false`).
- **The release settle belongs to the CAUGHT touch, and applying it to every touch ate the bounce.**
  The first shape of it settled every run whenever any touch ended — so the finger that pulled a run
  past its edge lifted, UIKit had not started its own rubber band yet, and the run was clamped home
  in one frame (traced: −31.3 → 0.0 in a single step where the natural spring takes four). There was
  then no bounce to catch at all, which is what the second "the bounce is still not catching"
  report was. The settle now matches the remembered touch and does nothing for any other.
- **Catching a BOUNCE holds it where the finger stopped it; the release springs it back.** Clamping
  at the catch — the first shape of this — snapped a rubber band home the instant it was touched,
  which is not catching it (user, K3: "I can now catch a decelerating table, but not an
  overscroll-bouncing one"). Measured on device: assigning the CURRENT offset stops the animation and
  moves nothing, for a coast and a rubber band alike. The other half needs a signal a run cannot get
  — it hears about touches only when they BEGIN — so `IDRunCatchReleaseObserver` on the canvas
  reports the END of a touch and each run settles back into range then. A run moving under its own
  gesture again is left alone: a catch the user drags ends as any drag does, with UIKit's own bounce.
- **A caught run also KEEPS the gesture.** Catching a scroll view means two things everywhere else
  in iOS — the coast stops, and the finger that stopped it owns the drag that follows — and the run
  did only the first: the pan's direction test (there so a vertical drag belongs to the document)
  declined the drag after a catch too, sending it to whatever encloses the editor. A run held by the
  touch that caught it now skips that test.
- **"In flight" includes the finger that CAUGHT it.** A scroll view caught under a finger is
  TRACKING until that finger lifts; a run never receives the touch, so UIKit never puts it in that
  state, and "dragging or coasting" alone is true for one instant after the catch and false by the
  time the finger moves — which is precisely when the outer gesture was taking it. The run remembers
  the catching touch weakly and counts itself in flight while that touch is down, reassigning on
  every touch its pan is offered so a recycled `UITouch` cannot be read as a catch still held.

## A run is caught in the instant UIKit says it is NOT decelerating (2026-09-15)

"Bounce is still not catching on K3", twice, after two fixes that changed nothing. The catch had
**never fired** — not for a bounce, not for a coast. A device trace of six touches (164 lines) holds
no `CAUGHT` line at all.

What the trace shows, one rubber band, `max = 136`:

    …255.601  off  x=160.8  decel=1 drag=1        ← the frame before the touch
    …255.618  recv         decel=0 drag=0 track=1 ← the callback: off=161.0  pres=161.0
    …255.634  off  x=157.2  decel=1 drag=0        ← 16ms later: decelerating AGAIN
    …256.018  off  x=136.0  decel=1               ← sprung home, finger still down
    …256.351  canvas-touch-ended                  ← the finger lifts 330ms after it settled

**UIKit clears `isDecelerating` as its pan takes the touch and sets it again on the next frame.** The
gate read the flag inside exactly that transient, so it declined every catch there has ever been. Two
consequences, and the second is why the "fix" was so hard to find: what feels like catching a COAST is
the pan taking over once the finger moves, not our code; and the catch's single
`setContentOffset:self.contentOffset` could not have stopped anything either — at that instant there
is no deceleration to cancel.

So the fix is two halves, each useless alone:

- **`id_isAnimatingNow`** replaces `isDecelerating` in the gate: did this run MOVE under its own
  animation within `id_animationGraceInterval` (0.05s, three frames)? Motion is recorded only while
  the run is decelerating or dragging, so a host assigning an offset during a layout pass is not
  mistaken for flight.
- **`-setContentOffset:` PINS a caught run** at the offset it was caught, every frame, until the
  finger lifts. UIKit resumes the bounce regardless of what the catch assigned; pinning is what "held
  where the finger stopped it" means. `isDragging` releases the pin, so a catch the user then drags is
  handed back to its own pan, and the existing release settles it into range.

**`delaysContentTouches = NO` (2026-09-12) is NOT part of this**, and the commit that made it claims
it is. That property delays touches to VIEWS; the catch lives in a gesture-recogniser callback, which
is never delayed. The change is still right on its own terms (it matches legacy and lands taps
sooner), but it explained nothing — recorded here because the commit message will otherwise mislead
the next reader.

**The A/B is what makes the fix safe to believe.** Upstream's unit bundle: 187 failures / 84 cases
without it, 184 / 82 with it, the ONLY difference being the two new tests going green. That also
surfaced something bigger — ~82 upstream cases now fail on Xcode 27 / iOS 27 that were 0 failures on
26.5, the same class as `IDUpstreamResponderModelTests` on this side.

## A tap that catches a moving table presses nothing (2026-09-15)

Stopping a scroll view with a finger is not a tap on its content. A placed run cannot enforce that
itself — it never receives the touch — so the host's chrome refuses it on the run's behalf, and the
rule has TWO shapes because the chrome sits in two places:

- **Inside the run** (button pills, formula tap targets, and every other overlay
  `attachmentOverlayPlacement` hosts): the run's pan already sees the touch and catches it, so only
  the ACTION needs suppressing. `EngineRunTouchGate` is the delegate on every such recogniser, asking
  the new upstream `-[IDBlockTextView id_isPlacedRunInFlightForView:]` — the per-view sibling of
  `id_hasPlacedRunInFlight`, so a pill in table A is not deadened because table B is coasting. It
  answers NO for a view in no run, which is why `gatedTapRecognizer(action:)` is used for markers and
  chevrons too: no call site has to judge whether its control can end up in a table.
- **Outside the run**: the structural chrome is parented to the ENGINE (a row grip would otherwise
  ride the horizontal scroll out of the gutter), so refusing its recogniser is not enough — the
  control still swallowed the touch, the run's pan below never saw it, and nothing caught the table
  while nothing else happened either ("we don't catch the table over handles, the touch just doesn't
  do anything", K3). It declines the HIT instead (`point(inside:)` → false while its table moves), so
  the touch reaches the canvas and a catch is the ordinary path.

**At touch-DOWN, always.** A tap fires on release, by which time the catching finger has lifted and
the run has been let go; a gate asked then sees a settled run and lets the press through.

## A knob claims a DRAG, not a TAP (2026-09-15)

"It's almost impossible to invoke the context menu by tapping in a cell when focused" — and fine in
body text. The chrome is live whenever the caret is in a table (`structurallyChromedTable()` falls
back to `tableAtCaret()`), and it draws four resize knobs at the focused cell's edge midpoints, each
with a 44pt hit box. **Measured over an 87x34 cell: 77% of it was dead.** Each knob was a
hit-testable view carrying only a pan, so a touch there died on it — the text interaction never saw
it, and neither a caret nor the edit menu could be placed.

44pt is the right DRAG target and the wrong tap target. So the knob views are drawing only
(`isUserInteractionEnabled = false`, `point(inside:)` answers for GRIPS alone — a grip IS a tap
target) and the drag moved to ONE pan on the editor, `tableKnobPan`, which begins only when the
finger starts inside a knob box and captures WHICH knob once, at `began`, so a drag cannot jump
knobs. It competes for the gesture without owning the touch, which is how legacy does it: there the
knobs are drawn by the canvas and the canvas's own pan handles them. Coverage over the focused cell
went 77% → 0%.

**This rule was already written down, already believed, and already tested — at the wrong layer.**
`test_aTapOverAKnobIsTheTextsAndADragIsTheChromes` asserted `textInteractionMayBegin(isTap: true)`
AND that the knob took its own touches. Those cannot both hold: the veto is only consulted for a
touch the text view actually RECEIVES, so the veto said "this tap is the text's" while the knob's
view swallowed it one layer down. Passing test, broken behaviour, 77% of a cell dead.

**And narrowing hit-testing exposed a live coupling**: `tableStructuralControlContains` — the veto
that keeps a text DRAG off a knob — derived its answer from `point(inside:)`, so it silently lost the
knobs and a text drag would have begun on top of a knob drag. They are separate accessors now
(`containsControl(at:)` vs `point(inside:)`) because they ask genuinely different questions: *is a
control here* against *does this view take the touch*.

## A block's FRAME is a line box; the rhythm below it is the renderer's (2026-09-15)

"Now the spacing between body paragraphs is 1pt larger than it should be. Maybe it leaks from the
shared rhythm?" It leaked from the block's own HEIGHT, and it was 2pt, not 1.

`StyleSheet` pins every line box to V2's pitch (`minimumLineHeight == maximumLineHeight`, because the
reader's heading factor wants a pitch TIGHTER than the font's natural line height and a `lineSpacing`
cannot go negative), so an engine block measures `lines * pitch`. **V2's item measures
`ceil(ascender + |descender|) + (lines - 1) * pitch`** — it reserves only the DESCENDER below the last
baseline, not a whole box. The difference, `trailingLineBoxOverhang`, is empty space the glyphs never
use, and `BlockLayoutEngine` has always subtracted it from the legacy canvas's boxes. **The engine
path never did**, so every stacked block stood that much too tall and pushed everything below it down.

It hid for months because the two numbers coincided: at body factor 0.9 the pitch was 22 and V2's
item-plus-gap was 21 + 1 = 22 as well. Raising body line spacing a point split them, the drift
doubled to 2pt, and it became visible. Measured on K3: paragraph→paragraph advanced 24 where the
bubble and the legacy editor advance 22.

**The correction lives in the SPACING, because the frame cannot move.** The engine sizes each canvas
to `usedSize.height` and no host-side value shortens it, so `EngineBlockSpacing` subtracts the
overhang from every quantity deposited BELOW a block — the rhythm gap, the trailing edge, a
container's bottom interior, a quote's `authorSpacing`, a details' `titleBodyGap`, the code and
pull-quote interiors — through one `spaceBelow` helper that charges it **exactly once per boundary**.
Charging per deposit would take it two or three times at a container's end and pull the next block
into the text above it.

Three consequences to know:

- **An inset can now be NEGATIVE** (paragraph→paragraph is 1 − 2 = −1). That is correct: the boxes
  overlap by the empty part of the upper one. The engine stacks with `y += usedSize.height +
  bottom`, so nothing clamps it.
- **A frame's bottom is one overhang below its glyphs.** Anything measuring a gap from
  `frame.maxY` — a band, a separator, a test — measures from the box, not the text, and must say so.
  `trailingLineBoxOverhang(atRole:)` is that quantity; the container bands subtract it, and sixteen
  geometry expectations now read `constant - overhang` rather than a bare constant.
- **It is per ROLE, not per document**, because it is per line box: a quote's 15pt child gives back
  1pt where a 17pt body paragraph gives back 2. Golden 4 moving by 1 while goldens 1, 3, 5 and 6 moved
  by 2 is the proof that the per-role read works — it comes from the attributes the bridge actually
  renders each line with, not from a style guessed per shape.

An attachment line offers no overhang: TextKit inflates its box to the attachment, so a media atom, a
button row, or a paragraph ending in one is left alone.

**SUPERSEDED FOR THE ENGINE by the first-baseline fix (2026-09-16) — the correction moved, and the
paragraph above is now a description of the `.off` arm.** The overhang fixed the block's HEIGHT and
left the dead band where it was: at the TOP of the box, above the first line, because TextKit
bottom-aligns a line inside a pinned box. That band is the composer's "the first line is offset to
the bottom way too much". `EngineDocumentBridge.v2BaselinePlacedStyle` re-pins the box to
`ceil(ascender + |descender|)` and carries `pitch - box` as `lineSpacing`, which TextKit adds BELOW
each line — so the band lands between the lines, where it reads as leading, and never above the
first one.

**The two are the same quantity.** A block of `n` lines loses the band `n` times (each box is that
much smaller) and gains it `n - 1` times (each gap is that much wider): net one band, the same one
the overhang gave back. So `used == V2's item height` now, where it used to be
`used - overhang == V2's item height`, and **`trailingLineBoxOverhang` answers 0 for every stacked
role the bridge renders.** The rhythm on screen is unchanged; only where the empty space sits is.

It is not dead code — `.off` is a supported rollback, and the mechanism is still live there, for
a style the placement declines (`pitch <= ceil(fontBox)`), and for an attachment line, which offers
no band either way. `EngineParagraphRhythmTests` drives the double-charge guard under `.off` for
exactly that reason and pins the subsumption under `.safe` beside it. **The LEGACY canvas is
untouched**: this lives in the bridge, not in `StyleSheet`, and legacy corrects the same placement
its own way with `BlockLayoutEngine.baselineDelta` — applying both would double-correct.

**And the box being the right SIZE does not put the text in the right PLACE.** `.safe` rounds the
box UP to `ceil(fontBox)`, and TextKit bottom-aligns inside it, so the baseline still sits
`pinnedLineHeight - fontBox` low — 0.7129 at 17pt body, which a user spotted on K3 as "still ~half a
point lower than it should be" and which measured at 14.42 against the placeholder cap's 13.70.
`EngineBlockSpacing.applyV2BaselineShift` gives it back as a NET-ZERO INSET PAIR: the drop comes out
of the block's top inset and the same amount goes back below it. Heights stay integral, every later
origin stays put, the document's height does not move, and only the glyphs shift.

**It is per ROLE and it has to be** — the drop is a rounding remainder of `ascender - descender`, so
it is six different numbers across the styles one field can hold, from 0.0996 at 15pt to 0.9062 at
heading5. A single host-side nudge is exact for its own style and leaves every other one FURTHER from
V2 than it started: a `-0.713` tuned on body puts every quote child, caption and pull quote 0.613 too
high. That was asked directly and answered by measurement, not argument —
`EngineLineBaselineTests.test_theSafeArmsResidualIsFontDependentSoAHostNudgeCannotBePrecise`, which
fails and asks to be deleted if the residuals ever do become uniform.

**THE CONSEQUENCE ANY GEOMETRY READ HAS TO KNOW: a text block's canvas is now exactly its glyph
box.** Its TOP is V2's item top, so a gap measured to a canvas top needs no correction. Its BOTTOM is
the last descender, where V2's item runs one drop further — so a gap measured from a frame's bottom
edge, or an inset compared against a design constant, reads `constant + drop` / `constant - drop` and
must say so, exactly as those sites already did for `trailingLineBoxOverhang(atRole:)`. Four did:
the details' title-to-body gap, a media unit's caption padding, the gap above a table, and the
collapsed-quote glyph — whose two states legitimately differ by one 15pt drop now, because the folded
one is an ATOM whose line TextKit inflates and which the lift therefore excludes.

PLACED roles are excluded for the same reason `trailingLineBoxOverhangs` excludes them: the engine
applies a placed block's insets INSIDE its host-computed frame, so a top inset would move a cell's
text against a height the host owns. The golden corpus is what says the blast radius — across six
fixtures only `inset` lines moved, all net-zero pairs, and golden 2 (two adjacent tables, no stacked
text) did not move at all.

## A substituted face's LEADING is not clamped by the pin (2026-09-17)

Reported as "typing in arabic text expands the line a bit". It does, and the cause is not the font
box: **`maximumLineHeight` clamps a run's ascent and descent, and the font's LEADING is added on top
of the clamped box**, where no paragraph-style property reaches it. Latin never showed it —
`.SFUI-Regular` reports `leading == 0` — so the pin looked absolute until a run substituted a face
that declares some. At 17pt body against a 21pt box, one line: Arabic (`.SFArabic-Regular`) 22.1621,
Thai (`.ThonburiUI-Regular`) 22.1355, Korean 21.51; Hebrew, Chinese and Japanese unaffected.

**Devanagari is the control that names the mechanism.** `.SFDevanagari-Regular` has the tallest font
box of the six — 26.08, five points PAST the pin — and inflates the line by nothing at all, because
the pin clamps exactly the two metrics it is documented to clamp. Only leading escapes, and the
scripts that grow the line are precisely the ones whose face declares it. So this is one property,
not a table of scripts to maintain.

**V2 never reads it.** The renderer advances by `lineAscent = floor(A + D)` of the PARAGRAPH's font,
raised only by an inline attachment, never by a glyph run's own metrics
(`InstantPageV2Layout.swift:4280,4560`) — the same refusal that keeps an inline custom emoji from
inflating a line. So the bubble renders Arabic on the Latin grid and the editor did not, which is a
parity break rather than a cosmetic one. In TextKit 2 it also COMPOUNDS: a two-line Arabic paragraph
measured 46.324 against the grid's 44.0, a five-line one sat 5.81 off.

`RichTextFontLeading` states the rule and all four layout-construction sites apply it —
`BlockLayoutTK1`, `BlockLayout`, and `IDBlockLayout`'s block layout plus its empty-line prototype
(which is what a blank paragraph's height is measured from). `CollapsedQuoteTextAttachment` expresses
the same thing by dropping `.usesFontLeading` from its `boundingRect` options. Nothing is clipped:
leading is the empty band a face asks for BETWEEN lines, never ink, and ascent/descent were already
being clamped.

**THE BOUNDARY, because the rule has two halves and only one is a property.** `usesFontLeading`
governs a line's own box — with it off every fragment measures exactly the pinned box. It does NOT
govern the ADVANCE to the next line, which is `box + max(lineSpacing, leading)`; the flag cannot
drive that below the leading. So the rule closes the gap only where a style has spare `lineSpacing`.
The engine's `.safe` re-expression is exactly that room, and it is enough: measured per style, worst
leading against the spacing `.safe` leaves, heading1 1.4695/3 … body 1.1621/2 are all absorbed, with
pullQuote 1.0020/1 leaking 0.00195pt (~1/170 of a device pixel at 3×). **`StyleSheet`'s own pin
leaves `lineSpacing == 0`, so the LEGACY canvas is improved by the flag but not closed** — closing it
means giving legacy the same re-expression, which is a change to that backend and was not made here.
`ScriptLineHeightTests` asserts both halves including the boundary, so a later change that closes it
fails loudly instead of passing a stale case; `EngineScriptLineHeightTests` asserts the finished
result on the engine side.

### …and the engine rewrites `.font` to the substituted face, which made the line JUMP (2026-09-17)

The follow-up report was "when typing Arabic, the line moves up and down (likely depending on the
symbols typed)". It is a second, independent defect that the height fix above uncovered rather than
caused, and the mechanism is worth knowing on its own:

**`engine.attributedBlocks` does not hand back what the bridge wrote.** The mapper and the bridge
both emit the style's font; the engine's storage comes back carrying the face CoreText SUBSTITUTED —
`.SFArabic-Regular` for Arabic, `.ThonburiUI-Regular` for Thai, `.AppleSDGothicNeoI-Regular` for
Korean, `.SFUI-Semibold` for bold. Anything host-side that reads `.font` off engine storage is
therefore reading a rendering decision, not the style.

`EngineBlockSpacing.v2BaselineDrop` was doing exactly that, and it computes `pinned - (ascender -
descender)`. Against the same 21pt pin: Latin's 20.287 box gives **0.7129**, Arabic's 21.117 gives
**0** (clamped — the substituted box is TALLER than the pin), Korean's ~17 gives **4.0**. The drop is
applied as a net-zero inset pair, so the block's whole top inset moved by that much. And
`spacingLineAttributes` samples the block's **LAST character**, so the answer flipped on the
keystroke — `"Hi م"` read 0 where `"م Hi"` read 0.7129 for the same two runs in the other order.
Once per typed character that changes script.

**The fix is `EngineBlockSpacing.pinnedBoxFont`: read `IDInlineTextBaseFontAttributeName`, not
`.font`.** That marker already exists, the bridge stamps it and the engine maintains it, and it is
the pre-substitution face. It also strips bold and italic — which is *more* correct here, because
`StyleSheet` derives the pitch from `font(for: style, attributes: .plain)` — while PRESERVING a
genuine style-level face change, so inline code's monospaced font still answers as itself. Verified
across latin, bold latin, arabic, bold arabic, thai and inline code.

**The general rule this leaves: never read `.font` off `engine.attributedBlocks` to reason about a
STYLE.** It answers what was drawn. For anything compared against V2 — which reads the paragraph's
font once and never re-reads it per run — go through `pinnedBoxFont`, or through the bridge.
`EngineScriptLineHeightTests` drives both the document-set path and the real typing path
(`engine.insertText` character by character, which is what UIKit calls for a keyboard edit), because
the substitution happens in the engine and only the typed path proves the marker is *maintained*
rather than merely stamped.

## An ordered list is ONE marker column and ONE text column (2026-09-17)

V2 measures every marker in a list, keeps `maxIndexWidth`, RIGHT-aligns each marker to that shared
column and starts every item's text past it (`InstantPageV2Layout.swift:3390,3428,3463,3489`). So the
bubble draws a list that crosses ten with its periods in one column and its text in another.

The editor did neither. `orderedMarkerExtraInset` was charged per ITEM — the 2026-09-11 fix for a
worse defect, `10.` drawn straight through its own text (`10F`, `11F`) — which removed the overlap
and left raggedness behind it. Measured on a 1…12 list: items 1–9 laid text at x=5.0 and items 10–12
at 15.28, and no two periods aligned anywhere.

`orderedListMarkerColumns()` now answers per RUN: the reservation and the marker-column width are the
run's maximum, and `syncLabelMarker` right-aligns the label inside that width. Two properties are
deliberately different:

- **The reservation is still counted in CHARACTERS**, not measured off the rendered glyphs, so `1.`
  and `7.` cannot indent differently and a renumber cannot shift the text sideways.
- **The column width IS measured**, because it positions a marker rather than reserving space for one
  — which is exactly what V2's `maxIndexWidth` is.

A run ends at any role that is not an ordered item at the same level — a paragraph between two lists,
a container, a different nesting level — mirroring `ListNumbering`, so a short list below a long one
does not inherit a width it has no numbers for.

**Visible consequence to expect:** single-digit markers now right-align too, so `1.` sits a hair
further right than `2.` — their periods line up instead of their left edges. That is V2's look, not a
regression. `EngineListMarkerTests`'s two 2026-09-11 cases encoded the per-item rule and were
rewritten: one now owns the SIZE of the reservation, the other had to start comparing against a plain
paragraph, because with a list-wide reservation item nine and item ten have identical frames and
comparing them asserts nothing.

## Every block origin sits on a WHOLE POINT, so selection rects abut (2026-09-17)

Reported as "line selection rects seem to be non-pixel-aligned", and after a first fix as "still,
selection rects sometimes misalign, especially between the first and the second lines". The second
report is the important one: **the defect was never alignment, it was ABUTMENT** — a white unfilled
row between the wash of line one and line two, visible in a screenshot and reproduced as

```
rect 0  y=12.0000  maxY=34.0000
rect 1  y=34.3333  maxY=57.3333   gap = +0.3333     <- the seam
rect 4  ...                       gap = -0.3333     <- and a matching overlap
```

**Snapping to the device pixel grid is not enough, and that cost a round.** The rhythm is integral by
construction — `pitch = L + S` with both terms floored, the `.safe` box is `ceil(fontBox)` — so block
HEIGHTS were whole numbers, but `v2BaselineDrop` is a `ceil(fontBox) - fontBox` remainder applied as a
net-zero inset pair, so block ORIGINS sat that fraction above a whole point and interior line
boundaries (`origin + k * pitch`) inherited it. Putting those on 1/3pt boundaries satisfied every
"is it on the grid" assertion and changed nothing on screen, because **the selection drawing
integralises to whole POINTS**: the first rect ended at 34.0 while the next began at 34.3333.

`EngineBlockSpacing.snappedToWholePoints` therefore rounds to the nearest POINT, and four independent
sources feed it — each found by measurement, and the last three only because the fixture was widened
past plain paragraphs:

1. **`v2BaselineDrop`**, snapped inside that function ITSELF, because the layout walk, the decoration
   pass and several geometry tests all read it and must not disagree.
2. **The code block's LANGUAGE LINE had no `.paragraphStyle` at all**, so no pinned box: its height
   was TextKit's raw font box, 20.2871 where every other body line is 21. It takes the body style
   from the style sheet now.
3. **`codeInteriorPadding`** subtracts font-derived overheads, which is V2's own rule and stays it —
   so the whole inset array and the placed reservations are snapped once at the end of the walk,
   **BEFORE `applyV2BaselineShift`**, keeping that shift exactly net-zero. Snapping afterwards would
   round the pair independently and let up to a point per block accumulate into the document height.
4. **A media atom's LINE was its slot plus the 1pt `mediaAtomFont`'s descent**, because TextKit sizes
   a line as `max(ascent) + max(descent)` and an atom at origin `.zero` is all ascent. The atom
   declares that descent in its own bounds now, so the line is `(h - d) + d = h`.

5. **The host's `contentMargins.top`**, which is where the text starts and therefore what every
   block origin is measured from. The chat panel's vertical pair is `textInputViewInternalInsets`
   (5.0 / 4.0) plus `calculateTextFieldRealInsets` (4.5 / 5.5) — deliberately lopsided so the TOTAL
   is even — and the engine is handed the 4.5 / 5.5 half as `contentMargins`. Passed through, that
   put every composer block origin on a HALF POINT, which is why the seam came back in the chat
   composer after the article editor (which passes 12.0) was clean. `textContainerInset(forContentMargins:)`
   snaps the top and hands the remainder to the bottom, so the pair's SUM — the thing the panel's
   invariant is actually about — is untouched and only the split moves, 4.5 / 5.5 to 5 / 5.
   Horizontal is deliberately left alone: the defect is vertical and the right inset carries the
   panel's accessory arithmetic.

**WHY a fractional origin shows at all, measured rather than assumed.** The coordinator does no
rounding — a segment's rect is TextKit's own line rect, extended to the block's SLOT only at the
block's first and last segment. What comes back is quantised in its HEIGHT: a first rect measured
`[12.0, 34.3333]`, height 22.3333, arrives as `[12.0, 34.0]`, height 22.0, while the next rect keeps
its fractional origin of 34.3333. So it is the height that is rounded to a whole point, not the
position — and with an integral slot top that puts the bottom a third of a point short of where the
next line begins. The engine contains exactly one `CGRectIntegral` and it is the rendering surface;
there is no `floor`/`ceil`/`round` anywhere in the selection path, so the quantisation is TextKit's
or UIKit's, not ours. The consequence for this file is the rule above: keep the origins on whole
points and the rounding is a no-op.

**THE TRADE, and it is a real one.** An integral canvas origin forces an integral lift: the canvas
top is `slotStart + topInset - drop`, so with the slot boundaries integral (they must be, or the
first rect of a selection is integralised into a seam again) an exact fractional drop is impossible.
So the baseline is now within **half a point** of V2's instead of exactly on it — worst measured 0.46
at a code block, 0.287 at body. The alternative is to round the selection rects alone and leave the
text exact, which means reaching into the upstream coordinator and re-transforming its stock-parity
suite. The seam was reported twice; the half-point was not.

A consequence worth knowing: snapping collapses most drops onto 1.0, so **counting distinct APPLIED
drops can no longer tell a per-role correction from a constant.** `EngineParagraphRhythmTests` asks
the question of the EXACT residuals instead, and additionally requires each applied value to be the
snap of its OWN residual — the test's own guard caught this, which is what a guard is for.

**What the corpus said about the blast radius:** across both rounds every `cell`, `chrome` and
`placement` value stayed byte-identical and only `inset[...]` lines moved, with their top+bottom sums
unchanged. Golden 2 — two adjacent tables, no stacked text — never moved at all. The re-record was
scripted to ASSERT that shape (inset-only, net sums preserved, whole points) before rewriting
anything.

`EnginePixelAlignmentTests` pins origins, heights and rect edges over a fixture with all six heading
levels, a wrap, a quote, a code block, a table and a medium — plus **`test_consecutiveSelectionRectsAbut`,
the assertion that was missing**: every edge was on the grid the whole time and no test asked whether
they MET. Abutment is asserted on a TEXT fixture, because a table's cells sit side by side (its rects
step backward in y between rows) and the ~1pt bands between adjacent washed cells are the grid's
borders to draw. A case reproducing the reported shape — a wrapped paragraph whose second line opens
with a custom emoji — is pinned beside it. There is also a case requiring the drop to stay within half
a point of exact, so the snap cannot quietly become a disable.

This is all in `RichTextEngineEditor`; the legacy canvas is byte-unchanged.

## Deleting a block's TEXT empties the block, it does not delete the block (2026-09-17)

`replacingRange` computes a delete as the COMPLEMENT — `prefix = [0, lo)`, `suffix = [hi, size)`,
both via `extractFragment` — and `extractFragment` keeps a block only where it covers some of that
block's TEXT. So a block whose text IS exactly the deleted range appeared in **neither** half and
vanished outright, **taking its heading level, list membership or code language with it.** Selecting
everything on a line and deleting leaves a blank line, in this editor as in any other.

**The rule: a range covering exactly one block's whole text deletes the text, never the block.** The
block is restored between the two halves, emptied and keeping its shape
(`emptiedKeepingShape` — style, list, language, author and identity; exhaustive with no `default`, and
nil for a block with no single text region of its own, where "emptying its text" is not a thing that
can happen to it).

**The complement model stays right for everything else**, which is exactly what the rule's two
equalities protect: it fires only when BOTH endpoints sit on the block's own text boundaries, so a
range over a block's whole SPAN still drops it (a fully covered table) and a range crossing a
paragraph break still joins the two halves. Both are pinned as controls.

One behaviour deliberately IMPROVES with it: replacing a whole paragraph's text with a fragment now
keeps the style it was rewriting, because the fragment folds into the surviving emptied block instead
of landing in the gap where that block used to be — **an AI rewrite of a heading stays a heading.**

This was found while writing a control for the paste-caret rule, where a delete-based control
asserted the wrong thing because of it. It is in Core, so the legacy canvas gets it too —
`CanvasReplaceRangeTests`, `CanvasClipboardTests`, `ClipboardChecklistTests` and
`DocumentRevisionTests` (54 cases) are green across the change.

## The caret goes after everything inserted, and the document grows a line if it must (2026-09-17)

Measured after a paste of a fragment ending in a table: the caret landed at the end of the paragraph
BEFORE it — and a fragment ending in a code block left it inside the code body with nothing after it.

**The cause is in `Document.insertingFragment`.** Its caret is
`globalTextStart(ofBlockAt: last) + lastLen`, and `lastLen` falls to `default: 0` for every block with
no trailing text — a table, a medium, a button row, a quote, a details. That is a STRUCTURAL position
INSIDE the block rather than after it, so the engine's nearest-text scan resolved it backwards into
the preceding paragraph. The scan was doing the only sensible thing with a position that has no text.

The rule, as asked for: **the caret goes after all the inserted content; if the inserted content ends
in a block other than body/header AND the insertion is at the end of the document, a line is added
below and the caret goes there.** Mid-document no line is added — a block already follows — and the
caret goes to the start of it.

- **Only `insertingFragment` can say where the inserted content ENDS**, because the answer depends on
  whether the fragment's ends inline-merged into the split host and whether the empty host tail was
  dropped, all decided in that function. So it reports it:
  `insertingFragmentReportingInsertion` / `replacingRangeReportingInsertion`, with the old two-tuple
  entry points delegating so **legacy's three call sites are untouched**. Re-deriving it in the engine
  would be the "second derivation" this file keeps warning about, and it cannot be recovered from the
  returned caret — for a text-less block that caret is a position inside the block.
- **`lastInsertedBlockIndex` is nil when the fragment folded wholly into existing text** (a code-block
  destination, or a single inline-mergeable paragraph). The caret is then already mid-text and the
  policy must not fire.
- **`lastIndex` is NOT the last inserted block when the host's tail survived** (a mid-paragraph
  paste): the last assembled block is then existing content and the inserted run ends one earlier —
  unless the fragment's own last block was absorbed INTO that tail, where the tail is partly inserted
  and is the right answer. That distinction is `tailAbsorbedFragment`.
- **"Body or header" is every paragraph style a top-level block can hold.** `ParagraphStyleName` has
  no `.quote` — a quote is a CONTAINER block — so `.caption` and `.pullQuote` (both render-only) are
  the only paragraph styles on the other side, and every non-paragraph KIND is there with them. A
  LIST item is an ordinary body paragraph and stays on the typing side, so pasting a list leaves the
  caret in its last item where Return continues the list.
- **The policy lives in the ENGINE's `replaceRange`, not in Core**, so the legacy canvas's paste is
  byte-unchanged. It therefore also governs the AI-compose replace, which wants the same thing.

Note: writing a control here is what surfaced the emptied-block defect above — a `replaceRange` that
emptied a block's whole text used to REMOVE the block. That is fixed; the line now survives, emptied,
and a delete-based control can delete a whole block's text and still assert that the policy grows
nothing.

## Copy and paste carry a `Document`, not a string (2026-09-17)

**The engine writes exactly ONE representation, `public.utf8-plain-text`, so every block structure is
ABSENT from a copy rather than degraded.** Measured before any of this existed: a document of
`paragraph / table / paragraph` copied as `"before\n\n\n\n\nafter"` — the five newlines being the
table's four empty cells. Reported as "tables are not preserved when copying/pasting"; it was every
structure, not only tables.

The legacy editor has carried the answer since Phase 5d, and it is reused WHOLE rather than
reimplemented: `RichTextEditorClipboard.pasteboardItem(for:)` writes the private fragment UTI (a JSON
`Document`, lossless within the app), `public.rtf` and plain text. That is what makes a fragment
copied in one editor paste into the other, and that file's own comment already said the two callers
must not drift.

**`copy:`/`paste:` land on the ENGINE, not on the wrapper**, which is why the editor never reached
its own clipboard. `TGIDObservingBlockTextView` already overrode `paste:` and `cut:` for the
chat's media hooks, so the seam is two more hooks of the same shape — `tgid_copyHandler` and
`tgid_richPasteHandler`, each returning NO to fall through to the engine. **`cut:` needs none of its
own**: it is already a copy plus an empty replacement, so it picks the rich copy up through
`copy:` and its deletion still reaches the surface gate.

**What makes it small is the global position axis.** Copy is `selectedGlobalRange()` +
`Document.extractFragment`; paste is `Document.replacingRange`. Those are the same two functions the
AI-compose flow uses, so there is no clipboard-specific range logic and no second definition of "the
selected sub-document".

- **Rich paste is consulted FIRST, before the engine's own `hasText` test.** `pasteboardItem(for:)`
  always writes plain text as well, so an engine-first order would claim every rich copy this editor
  ever made.
- **A collapsed caret pastes through the same call.** `replacingRange` over an empty range splices
  rather than replaces — including mid-paragraph, where it folds an inline-mergeable first block into
  the host paragraph instead of breaking it in two.
- **Block ids are regenerated by `replacingRange`**, which is what makes pasting the SAME clipboard
  twice safe: an id keys the hosted-view pool, so two blocks sharing one would share one hosted view.
  Pinned by a test that pastes twice and compares the id set.
- **A pasted button's opaque action is downgraded to `.disabled`** — legacy's rule, and
  `Document.convertingUnsupportedButtonActions()` is now public because the engine editor is its
  second consumer. A callback / web-app / payment binding belongs to the message it arrived in.
- **An endpoint inside a table or a medium takes the whole block** (`expandingRangeOverNonTextBlocks`),
  so a half-selected table copies as a table rather than as the text of the cells the selection
  crossed. (Since p19 the engine applies this on its own axis, `clipboardSelection()`, so Cut deletes
  exactly what Copy took; a range inside ONE caption or cell is that region's text.)

**A pasted occurrence needs a fresh identity at EVERY level, and the run level was missing one.**
`EmojiRef.instanceID` is documented as *unique per occurrence* and IS the hosted-view pooling key
(`syncCustomEmojiViews` keys on it deliberately, so the same sticker twice is two views). A fragment
carries the original's verbatim, so after a paste two occurrences claimed ONE view and only one of
them drew — reported as "after I pasted a paragraph with a custom emoji, the custom emoji is only
displayed in the pasted one".

This is `regeneratingIDs`'s own rule one level down — its comment already says *"block views are
keyed by `BlockID`, so a paste that reuses an existing block's id steals its view and the original
block disappears"* — and it was missed because every arm forwarded `runs:` verbatim. The `.media` arm
says why in miniature: a caption "has no nested BlockID", which is true and not the whole question.
`regeneratingRunIdentities` is the other half, applied in every arm that carries `[TextRun]`, so
**both branches of `replacingRange`, `insertingFragment`, and every existing caller are covered by one
change** — the fragment-scoped `regeneratingTopLevelIDs()` was already the designated hook.

- **`EmojiRef` is the ONLY run-level identity**: a formula and an inline button are identified
  positionally and carry none, which is why the helper is exhaustive at one case rather than a sweep.
- **Regenerate on the way IN, not on the way out.** The clipboard fragment keeps the original ids;
  `replacingRange` gives the incoming fragment fresh ones. Regenerating at copy time instead would
  collide on the second paste of the same clipboard, and regenerating the whole document would
  restart every untouched emoji's animation.
- **The editor's own instrument found it before a human could have**: `derivedViewPlacementDrift`
  TRAPPED on the shared view sitting at one occurrence's rect while the other wanted it at its own
  (`custom emoji at 1 at (41.2 …) wants (11.9 …)`). That trap also killed the test process mid-run
  while the printed summary still said "8 tests, 0 failures" — the "a failed bundle prints green"
  trap in a new guise, and the reason the test-case NAMES must be counted rather than the summary.

**Harness fact, measured rather than assumed: the ENGINE's own paste is ASYNCHRONOUS.** Straight after
`paste(nil)` the document still reads empty and the text arrives a run-loop turn later, while the
rich path is synchronous (it goes through the document setter). A plain-text control that does not
spin fails against working code — which is exactly what the first run of these tests did.

## `insertDocument` lands where the caret is, at any depth (2026-09-17)

It carried the stale guard `insertMediaBlock` shed on 2026-09-08, with the identical justification —
*"§8.5: the quote no-op the media spec already states for both inserts — inserting top-level roles
between a quote's children would split it."* That reasoning is sound about roles built at TOP LEVEL
and says nothing about whether the insert should happen. **Rendering the blocks WITHIN the caret's
ancestry is the fix**, and `EngineDocumentBridge.engineRepresentation(for:within:)` has existed for
it since R7-nesting; its own comment names this case, because building a fragment at top level and
re-parenting the roles afterwards *"gives correct structure wrapped around wrong TEXT"* — a quoted
block renders through the quote mapper and is indented.

With the caret in a quote this silently did nothing, for THREE host commands: the article editor's
**AI ▸ generate**, **attaching a file**, and the style-paragraph insert. Silently because the guard
returns before the framing, so there is not even an `onChange` — the same symptom the media guard
produced on K3 ("to a user holding a quote the + button simply did nothing").

- **The empty-paragraph replace branch lost its depth test too**, so an empty paragraph inside a
  quote is consumed exactly as one at top level is. The guards that remain are the ones that carry
  the meaning — a cell, a container's own line and a non-paragraph shape are all still excluded — so
  it cannot eat a code body or a details title.
- **A caret in a CELL still places after the whole table.** `containerSpan` groups a cell with its
  table, so the span covers the grid and the `owningTable` guard keeps the replace branch out. That
  is the container rule, not a depth rule, and a control test pins it.
- The caret's role is resolved BEFORE the framing, so a caret that resolves to nothing still fires
  no settle and no `onChange` — `insertMediaBlock`'s ordering, kept for its reason.

## The global position axis is Core's, not legacy's (2026-09-17)

`selectedGlobalRange()` and `replaceRange(from:to:with:)` TRAPPED on the engine at rung `R7-paste`,
and the stated premise was wrong: *"these are offsets into legacy's global position model, which the
engine does not have"*. **Tapping the AI button in the article editor killed the app**
(`EXC_BREAKPOINT`, K3 2026-09-17) — `RichTextAttachmentScreen` opens that flow with
`if let sel = self.editor.selectedGlobalRange()`, so it trapped on the CALL and whether anything was
selected never got a chance to matter. `replaceRange` would have trapped again on the way back, on
both the rich and the `.empty` arms.

- **The axis is `RichTextEditorCore`'s.** `DocumentTree.documentSize`,
  `Document.globalTextStart(ofBlockAt:)`, `PositionResolver` — a pure function of a `Document`, and
  the axis `Document.extractFragment` and `Document.replacingRange` already speak. Legacy merely
  stores its caret on it, which is what made it look like legacy's.
- **A role IS a text node.** `EngineBlockRole.position` carries exactly the key `TextNodeRef` is
  keyed on — a `BlockID` plus which region of that block it is — so the map is one-to-one and
  exhaustive over `Position` (a seventh shape or a sixth secondary kind fails to BUILD rather than
  resolving to a wrong region). `PositionResolver` walks the rest of the tree at any depth, through
  cells and containers alike, so **no arithmetic over containers is re-derived here** — which is the
  whole reason this is small.
- **`replaceRange` IS `Document.replacingRange`.** That function defines the axis, so no boundary
  rule is restated; the caret it returns is on the same axis. Like `insertTable` it rebuilds through
  the document setter, which is one undo step (it used to clear the history outright).

**The one genuine asymmetry is inside a run, and it is why this cannot be `offset - roleStart`:** a
formula's `TextRun.text` is its LaTeX source while the engine renders it as a single `U+FFFC`
(`EngineDocumentBridge.modelRuns(readingBack:)`). Custom emoji and inline buttons are one `U+FFFC` on
BOTH sides and need no conversion. **And the conversion must READ the engine rather than assume the
substitution happened** — with no formula renderer registered the engine holds the LaTeX verbatim
(`attributedFormulaString`'s documented degradation) and the two axes coincide. That is not
hypothetical: the first version of the formula test asserted the asymmetry without registering a
renderer, and the implementation was right while the test was wrong.

- **`nil` still means EXACTLY "nothing is selected"** — the one answer the trap existed to avoid
  giving wrongly. An endpoint that cannot be expressed is not folded into it: a role holding no text
  (a media atom, a button row, a collapsed quote) answers its whole BLOCK's span via
  `PositionResolver.blockSpan(ofBlockWithID:in:)`, which for media and tables is the same snap
  `Document.expandingRangeOverNonTextBlocks` performs a moment later anyway.
- **A caret in a bare GAP resolves to the nearest text position, forward first.** `replacingRange`
  parks its caret between two blocks whenever neither boundary was mid-paragraph — the ordinary shape
  of a whole-block delete, which is what the AI flow's empty result performs — and a gap is inside no
  text node. `±1` is NOT enough: a media block's atom sits two tokens from its caption's first
  offset, so the scan is outward.
- `blockSpan` walks OUTERMOST-first, which is what makes it correct for the blocks whose container
  and children deliberately share one `BlockID` (a code block is a container of two paragraphs all
  carrying `cb.id`; a media block's atom and caption carry `img.id`).

**Adjacent and NOT fixed here:** `insertDocument` — the AI flow's no-selection arm — is still a
silent no-op when the caret is inside any container (`containerDepth > 0`), the §8.5 quote no-op. So
AI-generate with the caret in a quote does nothing. Pre-existing, recorded rather than quietly
widened.

`EngineGlobalPositionTests` pins it, and both halves were neuter-verified: answering the engine's own
flat offset fails 6 of 9, and restricting the gap scan to the exact position fails exactly the one
case written for it.

## Body line spacing is one number, shared with the bubble (2026-09-15)

"Increase line spacing by 1pt at 17pt body font." The number lives in ONE place —
`InstantPageTextCategories.chatMessage`'s `paragraph` entry — and `RichTextRenderMetrics.default`
mirrors it for the package's own use, with `RichTextV2MetricsParityTests` failing if the two drift.
Changing it moves the chat bubble, the send preview, the TextProcessing screen and both editor hosts
together, which is the point: the editor renders what the sent message will look like.

**It is a FACTOR on a reduced box, so "one point" is not a value you can type.** The factor
multiplies `floor(ascender + descender)` — 12pt at 17pt SF, not 17 and not `font.lineHeight` — and
the product is floored, so every factor in `[11/12, 1.0)` buys exactly the same point and anything
below `11/12` buys nothing. 0.9 → **0.95**: spacing 10 → 11, pitch 22 → 23. 0.95 rather than the
minimum that works, because mid-interval still reads as one more point if the font's metrics ever
shift. Quotes carry the same factor at 15pt, where 0.9 and 0.95 both floor to 9 — they did not move,
and a test says so.

**The caret grows with it, and that is the architecture, not a side effect.** `StyleSheet` pins
`minimumLineHeight == maximumLineHeight` to the pitch (a `lineSpacing` cannot go negative, and the
reader's heading factor wants a pitch TIGHTER than the font's natural line height), so the line box
IS the pitch and the caret spans it. Three things fell out of the extra point, all of them
bookkeeping against recorded geometry, none of them a defect:

- **Both differential tables excused the caret's ORIGIN differing from stock but required its SIZE to
  match** — and the two heights were equal at 22pt only because two different fonts happened to agree
  there. Raising the pitch turned 108 caret checkpoints across three families into unexplained
  differences. The predicate now compares the height against the editor's OWN body pitch
  (`differentialBodyLinePitch`), which keeps what the equality was worth — a caret that vanishes or
  changes shape still fails — and moves with the metrics instead of against them.
- **Four of the six table placement goldens moved**, by one point per body line above the table and
  nothing else: not a width, not a cell height, not a run-relative chrome or placement, not an inset.
  Golden 2 opens with a table and golden 4's paragraph is inside a quote (15pt), so neither moved.
- Nothing in the InstantPage V2 suite moved at all, because its assertions are formulas over the same
  metrics rather than recorded numbers.

## A selection vanishes when it ends on a paragraph break (2026-09-15)

"Selection is not visible if at least one of the selected lines is empty." The emptiness is a
symptom of a wider rule: **the selection's boundary landed on a paragraph break.** An empty line has
exactly one canonical offset, so EVERY selection that touches one is bounded that way — which is why
it reads as an empty-line bug and why the same defect, in a document with no empty line at all, took
out `alpha|beta` selected `0..6` ("alpha\n") and `5..7` ("\nb") just as completely. The sweep is in
`IDBlockTextViewParityTests.testEverySelectionStockHighlightsIsHighlightedHereToo`; a fix aimed only
at empty lines would have left half of it standing.

**A separator is offered to BOTH of its sides.** `IDDocumentLayoutCoordinator` asks the block before
it to extend its TAIL and the block after it to extend its HEAD, under the identical condition that
the separator's offset is selected. Only the tail side has anything to draw: a tail extension widens
the last segment to the end of its line, which IS the newline's highlight, while a head extension
widens the first segment to the line's LEADING EDGE — where a range at the block's offset 0 already
sits. Two defects followed from the head side's empty answer, and either one alone blanked the whole
document:

- **`IDBlockTextGeometry` reported "nothing to draw" as "failed to measure".** A zero-width rect set
  `exact = NO`, which returns nil, which the coordinator reads as *this block's geometry cannot be
  trusted* and discards the segments for EVERY block. A zero-length range no extension could widen
  now contributes no segment and the block stays exact.
- **Both sides claimed the same logical endpoint.** A selection that STARTS on a separator is
  `containsStart` for the tail side (the selection begins at `cursor + blockLength`) and for the head
  side (it begins at `cursor - 1`) — the same offset, two segments. The duplicate-endpoint guard in
  `IDRichSelectionGeometryResultIsValid` then rejected the result wholesale. The head side now yields
  to a separator already claimed, so the start handle lands on the separator's own line.

Removing the geometry defect alone leaves the second; removing the attribution defect alone leaves
the first. **The selection is all-or-nothing** — one bad segment discards the document — so any
future rule here has to be sure it can never produce one, and `CGRectIsEmpty` is not the test for
that: it is also true of a zero-HEIGHT rect.

The third change is the one that only shows up with TWO empty lines in a row. The old dedupe
suppressed the whole participation of a block whose text was untouched when its head separator was
already claimed — but an empty block IS a separator and nothing else, so suppressing it dropped its
own line's highlight. Ownership is settled per claim now, not by refusing to ask.

## A run cannot catch its own deceleration (2026-09-11)

"When a large table scroll is decelerating, it's not possible to catch it." Suspected to be the outer
scroll view's `canCancelContentTouches` / `touchesShouldCancelInContentView:`; it is one level more
basic than that, and the measurement says so plainly.

**A placed run's scroll view is not in the touch's responder chain at all.** Every touch in the
canvas's tree lands on `IDBlockStackCanvasView` — the block canvases and `IDPlacedRunScrollView`
both let touches fall through so the text interaction sees a cell — so from a point over a cell the
chain is `canvas → text view → editor → window`, with the run nowhere in it (measured with
`hitTest:` plus a `nextResponder` walk). `-[UIScrollView touchesBegan:withEvent:]` is what stops a
decelerating scroll view under a finger, and it is never called on a run. Nothing about the outer
view's cancelling can matter, because the touch never reaches the run to be cancelled.

- **The hook is `gestureRecognizer:shouldReceiveTouch:` for the run's OWN pan** (upstream
  `8fb91aa1`): UIKit delivers it as the pan receives the touch, which is the moment a scroll view
  normally catches itself, and the run is already its pan's delegate. It is independent of where the
  pan is hosted, of the delay the enclosing scroll view puts on content touches, and of any
  recogniser of ours competing for the touch. Answering it decides nothing — it returns YES always,
  and the pan's own gate still accepts or declines the drag.
- **A canvas-hosted recogniser of our own was the first attempt (`984086f7`) and was not enough.** It
  does fire — traced on device — but it depends on our touch reaching a recogniser added to a view
  the run is not inside, and the catch still did not happen with a real finger.
- **A caught run settles at its offset CLAMPED into range.** Caught mid-rubber-band it would
  otherwise rest outside its own range with nothing left to bring it back, since the bounce it
  interrupted is what would have.
- **Nothing available here can test the catch end to end, and the reasons are worth keeping.**
  `isDecelerating` stays false through a programmatic animated `setContentOffset`, so no harness can
  make a scroll view decelerate. On device, AXe *can* flick a run (the earlier claim that it cannot
  was a measurement error — the table under test had only 35pt of range), but two `axe` invocations
  are ~1s apart while a coast lasts ~0.8s, so a synthesised catch touch always lands after the run
  has already settled. What IS measured on device: the run scrolls and decelerates (`decel=1`,
  offsets traced), and calling the catch mid-coast from the debugger stops it dead — at 121.3 where
  the same flick otherwise ran to 174.

## One table, one run (2026-09-11)

"Scrolling one table (inside a block quote) scrolls it, and for some reason another table on the top
level. Also, a scrollable table inside a block quote is not properly clipped." Two reports, ONE
cause: **adjacent placed blocks are one RUN, and two tables with nothing stacked between them are
adjacent.**

A run is the engine's unit of placed layout — one anchor, one horizontal scroll view, one clip — and
it is what makes a table's cells scroll together. Nothing told it where one table ends: a top-level
table followed by a quoted one (the quote's first child) produced a single run holding both. So they
shared one scroll view (a drag on either moved both) and one clip, which the engine keys by the run's
FIRST block — the top-level table's, cut at the canvas edge — so the quoted table was never cut at
its quote's interior. The host was computing the right clip for it and handing over an entry the
engine had no run to apply it to.

- **`placedRunStarts` is the missing boundary** (upstream `1e604527`): a set of blocks that BEGIN a
  run whatever precedes them. Absent or empty is the old behaviour exactly. Only the host knows where
  one table stops, so this is a declaration, not an inference — the engine sees blocks and frames.
- **The host declares every table's first cell**, so it is one run per table, always. There is no
  shape in which two tables should share a scrolling surface.
- **The host's `runOffset` accumulation is GONE with it.** A table's grid rects are relative to its
  own run's anchor, and the engine puts that anchor where the previous run's extent left the stacking
  cursor — which is the same sum the host was carrying by hand ("the grid plus the bottom insets
  deposited on its last row"). Getting that sum wrong is what once drew a table on top of the one
  above it, so it is deleted rather than kept beside the engine's own answer.
- **Nothing moved on screen, and the goldens are how that is known**: in both two-table fixtures
  every absolute `cell[...]` frame and every inset is byte-identical, and exactly two lines changed —
  the second table's `placement dy` and its grid chrome, both of which are RUN-RELATIVE and are now
  measured from the table's own anchor. A test that compares two tables' chrome frames must convert
  to the engine's space first; two of them did not, and one was asserting the shared run as a
  precondition.
- **Pinned by the two reports themselves** (`EngineTableScrollingTests`): scrolling one table leaves
  the other at 0, and a quoted table after a top-level one is still cut at `[bar, column − trailing]`.
  Neutered, the first reproduces "both tables scrolled" and the second reproduces a 0…320 window on a
  310pt column — the user's two sentences.

## A quote holds its content back on BOTH sides (2026-09-11)

"Block quotes should have a right inset. Check what it is in legacy and apply it here." Legacy's
answer is `BlockQuoteBox`: `inner = max(width - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)`
for the content, with the underlay drawn over the whole frame — 16 in on the left and **22 short on
the right** by default. The engine applied the leading half from the day quotes landed and the
trailing half nowhere: `StyleSheet.quoteTrailingInset` existed, was assigned by the legacy canvas
alone, and was read by NOTHING on this side, so a quoted line ran out to the column edge while the
bar held it back on the left.

- **The text narrows through a negative `tailIndent`** (`EngineDocumentBridge.quoteIndented`, which
  already carried the head indent), presentation-only and composing per level like its twin. A
  negative value measures from the container's trailing edge, which is what "stop 22pt short" means;
  0 is exactly the defect.
- **A block INSET could not do this job when this landed, and the probe that said so found a
  defect.** Upstream laid every STACKED block out at the full canvas width — `blockLayoutWidth`
  subtracted a block's insets only on the PLACED branch (`IDBlockStackCanvasView`) — so a `right`
  inset moved and sized the canvas VIEW and left the text measure alone. That is fixed upstream now
  (`a71301dd`, re-ported the same day: it was silently truncating a two-digit ordinal's column, see
  "A two-digit ordinal…" below), so a horizontal block inset does narrow the measure. The quote
  still narrows through the paragraph style, deliberately: its LEADING inset has always been a head
  indent, the two edges belong in one place, and a paragraph-level indent is what legacy does and
  what composes per level for nesting.
- **Resolved at INIT as well as in the setter.** `QuoteStyle.default` already carries 22, and both
  hosts pass 22, so a knob wired only in its setter would have applied in the article editor (which
  assigns a style) and nowhere else. That is this module's recurring deferred-configuration trap,
  and `HostConfigurationConsumerTests` cannot see it — a reader is a mention, not a call.
- **The LEADING inset is still deliberately NOT synced from the host knob.** The engine indents by
  the sheet's own `quoteIndent` (16) where the article host asks legacy for 9. Recorded rather than
  quietly changed: it is a visible move nobody asked for.
- **The ATOM subtracts both halves itself, and probe P1 extends to the tail.** TextKit 2 proposes the
  FULL container width to `attachmentBounds` whatever indents the paragraph carries, so with the
  leading half alone a quoted photo came back 294pt wide on the 272pt line its own paragraph now
  stops at — centred alignment hanging it 11pt off each end. `atomHorizontalReduction` is
  `contentIndent + contentTrailingInset` summed over the ancestry, and media and button rows share
  it.
- **A nested TABLE is narrowed and clipped on both sides**: `TablePlacement.containerTrailingInset`
  joins `containerIndent`, the grid is solved that much narrower, and `tableClipOutsets` pulls the
  cells' right edge in by it — so a scrolled quoted table stops where the quote's own paragraphs
  stop instead of running out over the margin. The chrome's window still opens a `gripGutter` past
  the cells on each side; that difference is the grips' overhang and is unchanged.
- **A details contributes nothing on either side**, and the two *details* fixtures in
  `EngineTablePlacementGoldenTests` not moving is what says so — the same five-unchanged-one-changed
  evidence that corpus exists for.
- **Every applier that swaps the bridge now goes through `remakeBridge`**, which carries
  `showsButtonRowMenuAffordance` across. It is stamped from whether a host is listening, not derived
  from the mapper or the configuration, and it is part of the MEASUREMENT — losing it re-packs every
  row to a width the sent message will not have. Six inline constructions each reset it; both hosts
  happen to register that hook last, which is the only reason it never showed. The quote style's
  rebuild was the seventh door and the reason to stop relying on the ordering.

## Where a table is clipped (2026-09-11)

A scrolling table was cut at the TEXT COLUMN while its chrome was cut at the engine's own bounds, so
the cells vanished a text inset before the grips did. Both now stop at one place, and where that is
depends on what the table is inside.

- **ONE derivation, two consumers.** `tableClipX(forTableAt:)` answers where a table is clipped in
  the engine's x. The engine cuts the CELLS there (a new upstream `placedRunClipOutsets`, keyed by
  the run's first block: positive widens the clip, negative narrows it) and the structural chrome
  view IS that window, so `clipsToBounds` cuts the grips and the outline at the same x. Neither
  derives the number for itself — the mismatch as reported was two rules for one edge.
- **Top level: the canvas.** The table stays where it is laid out, at the text inset like every other
  block; only the window changes, so a scrolled table passes UNDER the inset and is cut at the
  editor's edge. The grips live in that inset, which is why the app's ~16pt margin shows one whole
  and the test harness's default does not (the tests that measure grip movement set the app's).
- **Nested: the container's interior.** A table inside a quote is indented past the quote's bar, and
  its content must not scroll out over it — the outset is negative there, narrowing the clip to the
  interior. The chrome extends past the table for its grips, so it is framed from the WINDOW and
  places its contents at an offset inside it (`structuralChromeTableOrigin`): `tableOrigin` stopped
  being a constant when the window stopped being the table's own rect.
- **A run RESTS in its column and is CLIPPED by its window, and those are two questions** (upstream
  `e7f9a5d8`, superseding `12484b05`'s clip-derived travel). The clip decides what is visible; the
  column — `placedRunColumnOutsets`, defaulting to the text column — decides how far the run
  scrolls, so its far edge comes to rest on the column's far edge and no further. Both halves were
  reported: derived from the clip, a quoted table could not reach its own right border (the last
  `quoteTrailingInset` of its last column was unreachable and the grip hanging off that border was
  never drawn — "the right control handle is clipped inside a quote"); derived from the clip the
  other way, once the window was opened for the handles the table would have come to REST out in
  the quote's margin, putting the handle back outside the window.
- **ONE BOUNDARY cuts the table and its chrome** (2026-09-11): the container's interior opened by
  `gripGutter` on each side, `tableClipX` for both, with `tableColumnOutsets` stating the interior
  separately. The two used to differ by exactly that gutter, and the half nobody was watching was
  the OUTLINE — a selected cell scrolled partly out had its outline drawn 15pt further into the
  quote's indent than its own cells, 1pt from the band's edge. Consequence to know: a scrolled
  table's TEXT now shows through that gutter too, 15pt into the container's indent and margin.
- **A nested table is FLUSH with its container's interior, and its CHROME's window is what opens**
  (2026-09-11, corrected the same day). At the top level the text inset is the gutter the row grips
  live in and the document's rhythm is the band the column grip hangs in; a container's interior has
  neither, so a quoted table's grips were clipped away against the quote's bar and its column grip
  drew over the quote's own author line. The first fix reserved a `gripGutter` (15) on each side of
  the TABLE — and that read, correctly, as a table pushed in from everything around it (user report).
  The room was already there: a quote indents its content, and the grips hang into that. So the table
  takes its container's indent and nothing more, and `tableClipX` — the CHROME's window — opens a
  gutter either side of the cells' window instead. **That is the one place the cells' clip and the
  chrome's window differ**, and the difference is exactly the chrome's overhang; the cells' window
  (`tableClipOutsets`, what the engine is given) must NOT open, or a scrolled table's text runs out
  over the quote's bar. The VERTICAL reservation stays: the last row still carries `gripHeight` (17)
  more bottom inset, because below a nested table sits the container's own next line and there is no
  rhythm gap to hang the column grip in. Top-level tables are untouched either way, so a bare
  document's renderer parity is untouched; the four nested fixtures in
  `EngineTablePlacementGoldenTests` moved twice, and say why.
- **The run does not move.** Upstream grows the scroll view by the outsets and shifts its content
  view right by the leading one, so the content is laid out exactly where it was; the scrollable
  range is unchanged too (the content size grows by what the frame grew by), and whether a run
  scrolls at all is still measured against its column.


## The caret is drawn a run-loop iteration late unless the engine flushes it (2026-09-11)

"When typing the cursor sometimes lags behind the typed text." Measured on K3 frame by frame: the
caret stayed at the line's start through the first FIVE keystrokes — about 330ms — while the glyphs
advanced, then jumped and thereafter trailed by roughly a character. A stock `UITextView` driven
identically never lags by a single frame.

**The engine's geometry was never the problem.** A per-frame sampler showed `caretRectForPosition:`
advancing in lockstep with the text at every tick, and a swizzled trace showed UIKit ASKING six
times per keystroke and receiving the right answer — while the cursor view's own frame still held
the previous position a millisecond later. So the answer was correct, on time, and not applied.

**Where it is applied is a zero-delay run-loop timer.** Marking the selection display dirty —
`-[UITextInteractionAssistant setNeedsSelectionDisplayUpdate]`, which `id_updateInteractionGeometry`
calls — reaches `-[UITextSelectionDisplayInteraction setNeedsSelectionUpdate]`, and that method
moves nothing: it sets a pending flag (ivar `0x14`) and schedules
`_updateSelectionIfNeededResettingBlinkingAnimation:` through
`-performSelector:withObject:afterDelay:inModes:` with a delay of 0 in `kCFRunLoopCommonModes`
(disassembled on iOS 26.5 / 23F73; the selector, the `d0 = 0` and the mode array read from the live
call site). A zero-delay timer cannot run in the iteration that scheduled it, so the cursor can
never be repositioned by the CoreAnimation commit that draws the text it belongs to.

- **`-[UITextInteractionAssistant selectionChanged]` has a synchronous arm and typing does not take
  it.** It is chosen by `activeSelection.isCommitting`, `expectingCommit` or `requiresImmediateUpdate`,
  and the last is a hardcoded `return NO` on the assistant. A TAP satisfies the first (it runs inside
  `-[UITextSelection commit]`), which is why placing the caret never lagged. Breakpoints on both arms
  confirm a keystroke takes the deferred one.
- **A stock `UITextView` takes the deferred arm too** — the same breakpoint, the same arm, from
  `-[UITextInputController _insertText:fromKeyboard:]`. It does not lag because UIKit's own canvas
  rescues it: `-[_UITextLayoutCanvasView _performViewportLayout:]` posts a notification at the end of
  its `-layoutSubviews` that `-[UITextSelectionDisplayInteraction _trackingViewportDidLayout:]`
  observes and answers with `_updateSelectionIfNeeded`, inside the commit. **A text input that draws
  its own canvas posts nothing**, so only the timer is left.
- **So the engine flushes it itself**, from the end of `-[IDBlockTextView layoutSubviews]`
  (`id_flushSelectionDisplayUpdate`, upstream), through the PUBLIC
  `-[UITextSelectionDisplayInteraction layoutManagedSubviews]` — the documented synchronous entry
  point for a view to call from its own layout. The interaction is found by class on `-interactions`;
  nothing is created, and a view UIKit has not made a text client has nothing to flush.
- **ONLY after a DOCUMENT change** (`id_selectionDisplayFlushPending`, set where the change funnel
  has a real change), never after a selection-only one. `layoutManagedSubviews` is the RESETTING
  entry, and run on a pass a bare selection move triggered it disturbs the anchor the keyboard-based
  selection interaction carries between key events: the first Shift+Right became a plain Right, so
  stock's `{3,0} {3,1} {3,2}…` came out `{3,0} {4,0} {4,1}…`. Typing is the case that needed fixing
  and a selection-only change was never late — a tap takes `selectionChanged`'s synchronous arm.
  **Upstream's `IDBlockTextViewUITests` caught this and none of the unit suites could**, because it
  compares a whole keystroke TRACE against a stock oracle rather than an end state.
- **It costs no extra work.** `layoutManagedSubviews` forces the pending flag ON and runs the same
  gated body, and that body CLEARS the flag (`strb wzr, [x20, #0x14]`), so the timer already
  scheduled for this iteration fires into a cleared flag and returns at its guard. One update per
  iteration either way — it simply happens inside the commit instead of after it.
- **Why the lag was five characters and not one.** The deferral is structurally ONE run-loop
  iteration. That is invisible at a few milliseconds per keystroke (the timer's turn arrives inside
  the same display frame) and plainly visible at tens, which is what a document with tables costs —
  measured 7.4ms/keystroke against 2.8ms for three plain paragraphs in-process, and ~45ms against
  ~6ms on device. With keystrokes queued back to back the timer's turn is pushed past display
  frames, which is the freeze, and the ~30ms catch-up once the burst drains.
- **The idle blink is unaffected** (no layout passes when nothing changes), device-checked. During a
  scroll the blink resets each tick, so the caret reads solid — the same as any interaction.

Pinned upstream by `IDSelectionDisplayFlushParityTests` against a real `UITextView`, and here by
`EngineCaretFollowsTypingTests` through the Telegram wrapper. **Neither may spin the run loop between
the edit and the assertion** — one turn and the timer fires, the cursor is right whatever the engine
does, and the test passes over a live defect. Both were neuter-verified: with the flush removed the
engine cases fail and the `UITextView` oracle keeps passing.

## A host command spends that flush on its own bookkeeping (2026-09-15)

"When adding a detail block, the cursor momentarily blinks in its body, and then jumps into the
title (where it should have been)." The caret's OFFSET was right the whole time — the assertion that
`insertDetailsBlock` leaves the selection in the title has been green since the rung landed. What
was painted was the previous position, because **the flush above is armed once per document change
and the FIRST layout pass spends it**, and a host command moves the caret twice over one change:

1. `document`'s setter replaces the differing span (the engine arms the flush), then **measures** —
   `syncTableFrames` and `syncContainerBlockInsets` read engine frames, which lays the engine out
   and spends the flush — and then clamps the caret to the replaced span's new end.
2. The COMMAND then puts the caret where it belongs. That is a selection-only change as far as the
   engine can tell, so nothing re-arms, and UIKit's zero-delay timer draws it a run-loop iteration
   later — a painted frame with the cursor in the wrong BLOCK.

For a details appended at the caret the two landings are its body and its title, which is the report
word for word. Measured through the interaction's public `cursorView`: `after insert: drawnY=91`
(body), `after the layout pass that paints it: 91`, `+50ms: 56` (title).

- **The fix is one call at the end of the host's own layout pass**
  (`drawTheCaretWithAHostDocumentChange`), gated on a flag the `document` setter raises — a host
  document change that has not been drawn yet. `tgid_flushSelectionDisplayUpdate` (host-authored, on
  `TGIDObservingBlockTextView`; no upstream edit) clears the engine's pending flag and calls
  `-id_flushSelectionDisplayUpdate`, so this IS that flush rather than a second one.
- **Gated on a DOCUMENT change, not on the caret having moved.** `-layoutManagedSubviews` is the
  resetting entry and must not run on a pass a bare selection move triggered — the Shift+Right trace
  in the section above is why. Only the host knows that the command's caret move is part of the
  change and not a bare one, which is why the flag lives here rather than in the engine.
- **It is NOT details-specific, and a fix aimed at `insertDetailsBlock` would have left its siblings
  standing.** Every command that rebuilds through the document setter and then places a caret has
  it: measured late for `wrapInBlockQuote` and `makePullQuote` in a fixture where the details case
  happened not to reproduce. Which commands show it depends on where the clamp lands, so the
  reproduction is a property of the document, not of the command — pinned by two cases
  (`EngineCaretFollowsTypingTests`), the reported one and a sibling.
- **The assertion needed BOTH axes.** That file compared the drawn cursor's `minX` only, which was
  enough for typing (one line, horizontal movement) and reads a caret a whole paragraph away as
  correct — two blocks of the same kind start at the same indent. This defect is vertical.

## The toolbar's undo and redo are the engine's own stack (2026-09-17)

`undo()`/`redo()` trapped at rung `R10-undo` and `canUndo`/`canRedo` were constants, so the article
editor's two nav-bar buttons were permanently disabled with a `preconditionFailure` behind them. The
verbs are a forward to `engine.undoManager` — the private text-input controller's manager, the one
UIKit records the typing into and the one every command in this module already registers its inverse
into (`restyleFlat`, `registerReplayRoleSnapshot`, `prepareUndoForStructuralRepair`, and the list,
table, media and button-row commands). The whole rung was deciding that they could be.

**That is the opposite of legacy's answer, deliberately.** `DocumentCanvasView` keeps a PRIVATE
per-canvas manager precisely so UIKit's own registrations cannot surface in `canUndo` — it had
shipped the device-observed "undo is active on the first tap, before anything was typed", which was
a SELECTION change recorded by the shared responder-chain manager. The engine is not exposed to
that: its manager belongs to this view's controller alone. **Asserted, not assumed**
(`test_nothingIsUndoableBeforeAnEdit`) — it is the negative control for the decision, and if it ever
goes red the answer is a manager of our own, with every `registerUndo` in the module moving onto it
in the same instant.

- **The trailing `deliverChangeNotificationNow()` is load-bearing**, for the reason legacy documents
  at its own pair: the replay's notification is scheduled from INSIDE `UndoManager.undo()`, where the
  group has not finished popping, so a host re-reading `canUndo` from it sees the stack one step
  stale and the LAST undo leaves its button enabled with nothing behind it. Neuter-verified by moving
  the call BEFORE the replay, which reports `canUndo == true`. It also CONSUMES the scheduled
  delivery rather than landing beside it, so the host is still told exactly once.
- **No `unmarkText()` first, although legacy opens its pair with `finalizeMarkedText()`.** The hazard
  is real — undo replays COMMITTED text and a composition is not committed — and the engine closes it
  itself: measured on a live composition over an earlier edit, the end state is byte-identical with
  the call and without it (`"alphaXか"` to `"alphaX"`, no marked range either way). Writing it anyway
  would cost a reader the belief that this verb closes the composition, so it is not written; the
  property is pinned as a CHARACTERIZATION naming the engine as its owner.

**A run of typed characters undoes as ONE step, and the fix was one line in the engine** (2026-09-17,
the section below). This paragraph previously said the opposite and gave a reason that was WRONG —
that `groupsByEvent` closes an undo group per run-loop iteration so one keystroke is one group. It is
a true statement about `NSUndoManager` and it is not the mechanism: a stock `UITextView` has
`groupsByEvent == true` as well, and coalesces eleven keystrokes across eleven run-loop turns into
one undo. The coalescing is the OPERATION's, not the group's.

## Typing coalesces because UIKit coalesces it, and one missing marker was defeating that (2026-09-17)

Reported as "in native text views, sequences of typed characters seem to be undone together; in ours
it works letter-by-letter". It did: `"hello world"` took eleven undos. The cause was not the undo
manager, not the grouping, and not anything this module does with undo — it was a typing ATTRIBUTE.

**UIKit already implements typing coalescing, and the engine is already on the path that gets it.**
`-[UITextInputController insertText:]` registers its undo as operation type **2** (typing), which
routes to `-[UITextInputController coalesceInTextView:actionName:affectedRanges:replacementRange:replacementText:]`
and folds the keystroke into the previous `_UITextUndoOperationTyping` instead of pushing a new one.
Type **3** (replace) and type **1** (set attributes) both call `stopCoalescing` first and never fold.
The engine's typing reaches the type-2 path unchanged —
`TGIDObservingBlockTextView insertText:` → `IDBlockTextView` → `IDUIKitInputControllerCapability` →
`[activeController insertText:]` — so nothing had to be built here. (`appendUndoOperation:newGroup:`
is a bare `return` on this build, a dead stub like the `didChange*`/`consider*` family the
autocorrect section documents. Do not reach for it.)

**Coalescing is conditional, and gate 2 is the one that was failing.** In order:

1. `[undoManager respondsToSelector:@selector(_shouldCoalesceTypingForText::)]`. Passes for both:
   `-[UITextInputController undoManager]` LAZILY CREATES a `_UITextUndoManager` and sets its
   `inputController`, so the engine gets the same subclass a stock text view does.
2. `[undoManager _shouldCoalesceTypingForText:<previous typing op> :<textStorage>]`.
3. `[controller shouldStartNewUndoGroup:text textGranularity:2 operationType:2]` — must answer NO.
   It answers YES at a sentence boundary, which is how stock ends a run.
4. `[previousOp coalesceAffectedRange:replacementRange:selectedRange:textStorage:]` — contiguity.

Gate 2 refuses once anything else has been registered into the manager since that typing operation.
**And this editor was registering something after every keystroke.**
`IDInlineTextBaseFontAttributeName` was missing from the engine's `allowedTypingAttributeNames`
(`IDBlockTextView.m`), which lists `.font` and the four inline trait markers. So a typed character
arrived carrying `.font` but not the base face that font derives from; `normalisePresentation` found
the block differing from what the bridge renders, stamped the marker back, and that restyle ends in
`registerUndo`. One entry of ours between every pair of typing operations, and UIKit — correctly —
refused to fold across it.

The marker now travels with the font, which is the only place it can be right: a character carrying
`.font` and no recorded base is the defect, and the two are a pair. **The resulting attributes do not
change** — settle was already producing exactly this value; what changes is that the typing path
produces it directly instead of a restyle producing it afterwards. `verifyPresentationIsDerived` runs
over every block in DEBUG and stays silent, which is the check that the value is the same one.

**How it was found, because the method is reusable and the first explanation was wrong.** The
differential is the whole of it: a stock `UITextView` and the engine in the SAME harness, driven by
the same per-character `insertText:` with a run-loop turn between each. That immediately killed the
`groupsByEvent` theory (both true, only one coalesces) and localized the rest. Then
`imp_implementationWithBlock` over the four gates plus `registerUndoWithTarget:…` logged, per
keystroke, which gate answered what and what landed on the stack in between — and the natural
experiment was already in the trace: the SECOND keystroke coalesced (nothing of ours had been
registered yet) and every keystroke after it did not.

**A test must assert this on the TYPING ATTRIBUTES, not on the finished text.** The first version of
the mechanism test read the marker off the typed characters and passed with the fix reverted, because
`normalisePresentation` stamps it back before anything can look — a green test over a live defect.
The end state is the same either way; what differs is whether a restyle had to produce it.
`EngineTypingUndoCoalescingTests` reads the engine's typing attributes through KVC for exactly that
reason, and pins parity against a stock text view driven identically so a future UIKit change moves
both or neither.

**STILL OPEN, measured, and NOT the same mechanism: an IME composition costs one undo more than
stock.** `normalisePresentation` restyles the composed text on every IME keystroke — against
attributes the composition legitimately owns, and which `verifyPresentationIsDerived` already
declines to check while marked text is live — and each restyle registers an entry. Popping it is an
undo that changes no text, so typing `X` then composing `か` takes two undos here and one on stock.
Guarding the settle pass on `markedTextRange` was tried and does NOT close it: the entry is then
registered by the settle that follows the undo's own commit instead. Pinned by
`EngineUndoRedoHostTests.test_undoLeavesNoCompositionOpen_butCostsOneStepMoreThanStock`.

## A host layout that moves the TEXT owes the caret a draw (2026-09-17)

Reported right after the typing-coalescing fix as "sometimes, especially at first, typing text does
not move the caret — if I backspace the last letter is removed, so it may be stale only visually".
It was: the model was correct throughout and only the drawn cursor lagged.

**This is the third trigger of the same invariant**, after the engine's own edits and a host COMMAND
(the two sections above). The document is settled and the engine's in-edit flush has already put the
cursor on the caret — then the host runs
`update(size:insets:contentMargins:scrollIndicatorInsets:)`, which assigns the engine's `frame` and
`textContainerInset`. Either re-lays the text out at a new origin and takes the caret with it. No
document changed, so nothing is armed, and the cursor keeps its earlier position until UIKit's
zero-delay timer fires. **Both hosts run that pass on every `onChange`, which is every keystroke** —
the composer's field grows as the text wraps, the article editor re-runs its component update.

**How long the caret is wrong for, stated precisely, because the first version of this note was
loose about it.** The deferral is ONE run-loop iteration, and the timer does rescue it: measured,
every stale reading here is corrected by the next turn. So this is not a caret stuck in the wrong
place — it is a caret that arrives a turn late, on every keystroke. That is invisible in a quiet run
loop and plainly visible when the loop is busy, which is the mechanism the 2026-09-11 section above
already measured: with keystrokes queued back to back the timer's turn is pushed past display
frames, which reads as the caret freezing and then catching up. Do NOT cite this section as the
explanation for a caret that stays wrong indefinitely — nothing here has been shown to produce
that.

`markCaretForRedrawIfHostGeometryMoved(from:)` records the engine's text geometry before the two
assignments and marks the caret owed a draw when it moved; the flag and the function that spends it
at the end of `layoutSubviews` are now `hostChangeAwaitingCaretDraw` /`drawTheCaretWithAHostChange`,
renamed because "document change" stopped being what they mean.

- **ONLY when the geometry actually moved**, and that half is the reason the guard exists rather
  than flushing every pass: `-layoutManagedSubviews` is the RESETTING entry, and running it on a
  pass that had no business drawing is the Shift+Right anchor defect whose trace
  `tgid_flushSelectionDisplayUpdate` carries. A needless flush leaves the caret in the right place,
  so nothing about the cursor's position can catch it — `caretRedrawCount` is a test seam so the
  NEGATIVE can be asserted, and an idle repeat `update` must not increment it.
- **It was reported as a regression from the coalescing fix, and it half was.** The per-keystroke
  presentation restyle that fix removed used to leave the engine's own flush flag armed, so the
  host's next layout pass happened to spend it and redraw the caret. Measured both ways: with the
  restyle, keystrokes 2+ were correct and only the FIRST was stale (nothing had armed a second flush
  yet); without it, every keystroke was stale. So the restyle was papering over a missing rule, and
  the fix is to state the rule — restoring the accident would leave the first keystroke broken and
  the mechanism undescribed.
- **The harness has to include the host's pass or it proves nothing.** A probe that types and lays
  the ENGINE out shows no drift at all, which is what the existing `EngineCaretFollowsTypingTests`
  cases do and why they stayed green through the regression. The reproduction needs
  `editor.update(...)` with geometry that actually differs, run after the commit-time layout — the
  order the app produces, where `onChange` is async and the host's pass lands a turn later.

## The editor owns its undo stack (2026-09-17)

Reported as "⌘Z acts like it should, the undo button erases char by char". **The two were always the
same stack and the same method** — measured, same `_UITextUndoManager` instance — and the asymmetry
was the KEYBOARD. UIKit decides granularity from which entry point delivered the text:

| delivery | UIKit operation type | undos to clear `"hello world"` |
| --- | --- | --- |
| `insertText:` — a hardware key press, which is what ⌘Z implies | 2, "Typing" | **1** |
| `replaceRange:withText:` — the keyboard's correction path | 3, "Replace" | **11** |

`registerUndoOperationForType:` routes type 2 through `coalesceInTextView:…`, which folds the
keystroke into the previous typing operation; types 1 and 3 call `stopCoalescing` first and never
fold. So the same sentence is one step or eleven depending on how it was typed.

**The stack is now the editor's own, and holds `EngineUndoSnapshot` — a `Document` and a selection.**
Roles are deliberately NOT stored: the `document` setter derives them through the bridge, so a second
copy could only go stale, the same reasoning that keeps text out of a role.

- **⌘Z and the button are identical BY CONSTRUCTION**, which is what was asked for. The engine's
  `undoManager` is pointed at this stack (`tgid_undoManagerOverride`), and `UIResponder` reads that
  property for `undo:`/`redo:` and `canPerformAction:` — so the system affordances and the toolbar
  reach one object. Two paths that merely agree can stop agreeing.
- **The coalescing rule is CONTIGUITY, and it was measured rather than designed.** A stock
  `UITextView` gives ONE step for a sentence with spaces, a newline, a long word, a run followed by
  five backspaces, and type-backspace-type; TWO when the caret moves between runs, and TWO for a
  selection replacement. So a run continues while each edit begins where the last ended and replaces
  nothing. A replacement both ENDS a run and OPENS one at its end — stock replaces a selection with
  `H` and then coalesces the `I`, and missing that half was the one certification failure.
- **Two things deliberately do not end a run.** A sentence boundary: UIKit would end one, but only
  when `[UIKeyboardImpl activeInstance] nextInputWouldStartSentence`, which is false in the host the
  oracle runs in — so a DEVICE may break where we do not, and the oracle table is what to re-measure
  if that ever matters. And the typing↔deleting switch, which the LEGACY canvas does break on
  (`editing(coalescing:)`); matching iOS was the instruction, so iOS wins.
- **A STRUCTURAL edit ends the run**, and the shape that says so is `replaceFlat(_:with:adopting:)` —
  an edit carrying a plan decided a structure, where a plain `replaceFlat` is a character going in.
  Without it the double-Return exit from a code block coalesced with the newline before it and one
  undo took back both keystrokes.
- **A composition is part of the run it was typed into.** Its updates replace the marked text, so
  without an explicit rule every IME keystroke would end the run — which is exactly what had `かんじ`
  stepping back through `かん` and `か`, and what made a composition cost one undo more than stock.
- **Nothing clears the history any more.** `prepareUndoForStructuralRepair` is
  `recordUndoStepForStructuralChange` and registers an ordinary step; every table insert, quote wrap
  and paste used to throw the user's entire history away, because UIKit's text ranges described text
  that no longer existed. A snapshot has no such problem. Four claims elsewhere in this file said the
  history is cleared and have been corrected.
- **The replay machinery is GONE with the stack that needed it.** `registerReplayRoleSnapshot` and
  `installReplayRoles` existed because UIKit replays TEXT and the roles had to be reinstated
  positionally around it; a snapshot restores the document and the setter derives the roles, so there
  is no window in which text and structure disagree. `restyleFlat` likewise no longer registers an
  inverse — presentation is derived on the way back in.
- **`groupsByEvent` stays ON.** Pointing the engine's `undoManager` at this stack means upstream code
  registers into it too (`IDInlineTextFormattingController` goes through `host.undoManager`), and
  with event grouping off those arrive outside any group and `NSUndoManager` rejects them — measured
  as 100 failing tests. It costs nothing: a run registers once at its start and nothing afterwards.
- **A host `document` set is a new BASELINE, not a step.** The command that drove it registers the
  step with the before-state it captured. Missing that, the baseline stayed at whatever the editor
  held when it was constructed — an empty document — so the first keystroke after a host set
  registered "restore empty" and one undo wiped the document.

**Certification is a comparison, not a number.** `EngineTypingUndoParityTests` drives a stock
`UITextView` and the editor through the same scenario in the same process and requires the undo
TRACES to be equal. A hand-written step count would be a guess that outlives what it was guessed
from; the oracle cannot be.

## The scrollable area is the VISIBLE area, not the frame (2026-09-17)

Reported from the device: "the inset adjustment behaviour when opening keyboard/emoji keyboard in the
article editor is simply wrong." It was, in five ways at once, four of them the same misunderstanding
— that the editor's FRAME is the area its content occupies. In the article editor it is not: that
host frames the editor over the whole screen and hands it the bands the content must scroll *under*
as `contentInset` — the navigation bar on top, and on the bottom the action bar, the home indicator
and whichever of the system keyboard / emoji panel is up. The fifth is the caret, at the end.

Measured in-process on K3 (`xcrun lldb -p`), with a ~470pt article in an 810pt editor:

| state              | `contentInset` | `contentSize` | offset, before → after a drag |
|--------------------|----------------|---------------|-------------------------------|
| nothing up         | 68 / 92        | 810           | −68 → **+92**                 |
| emoji panel up     | 68 / 407       | 810           | +91 → **+407**                |
| panel closed again | 68 / 92        | 810           | +407 → **−68** (a 475pt jump) |

- **`contentSize.height` was floored at the FRAME height** (`ceil(MAX(CGRectGetHeight(self.bounds),
  …))`, in both `-id_reconcileDerivedStateForDocumentChange:` and `-layoutSubviews`), so the
  scrollable range was `contentInset.top + contentInset.bottom` for EVERY document however short —
  160pt with nothing up, 468 with the keyboard, 475 with the emoji panel. The whole article could be
  dragged off the top of the screen into blank space, and every panel transition re-clamped the offset
  inside a phantom range the transition itself had just resized. That is the jumping that was
  reported: it is not the transition that is wrong, it is that there was anywhere to jump from.
  The floor is now the VISIBLE height, which is what the legacy canvas has always used
  (`RichTextEditorView.performLayout`: "no phantom scroll/bounce over the inset bands"). Identical
  whenever the insets are zero — the InputDec app, and our chat composer, whose host passes `.zero` —
  so nothing but the article editor can see the change.
- **It is fixed in `TGIDObservingBlockTextView`, not upstream.** A `-setContentSize:` override is the
  one place both of the engine's assignments pass through, so a re-port cannot lose it.
- **`contentInsetAdjustmentBehavior` is `.never` now**, as legacy's has always been: the host owns the
  insets exactly and nothing may be added to them. It also makes `adjustedContentInset ==
  contentInset`, which is what lets the floor above read the adjusted value without feeding back
  through the `.scrollableAxes` adjustment.
- **A changed TOP inset re-seats a scroll resting at the top.** For a document that fits, the floor
  leaves `−top` as the only valid offset and UIKit's clamp is enough; a document TALLER than the
  viewport leaves offset 0 in range, so the article editor opened with its first screenful hidden
  under the navigation bar. Legacy carries the identical rule and the identical reason.
- **`scrollIndicatorInsets: nil` means "track the content insets"**, which is the protocol's own
  contract — it had come to mean "leave whatever the engine had", and the article editor is the host
  that passes nil, so its scrollbar ran under the navigation bar and behind the keyboard.
- **The body placeholder was placed from the text-container inset alone** and never saw the content
  inset, so "Type something..." was drawn 68pt too high — underneath the Close button. It stands in
  for the document's first line and now rides the same band that line does. (It still sits 4pt above
  that line, in the composer too and with no inset in play; that gap is the paragraph's own leading
  and predates this. `EngineArticleInsetTests` states the property as "the gap does not depend on the
  top inset" rather than folding 4pt into a tolerance.)

- **A band that grows can hide the caret, and nothing brought it back.** The engine scrolls the caret
  into view when the CARET moves — on an edit, on a selection change (`-id_scrollCaretToVisibleIfNeeded`)
  — and a panel opening moves the VIEWPORT instead, so a caret sitting just above the action bar ended
  up behind 250pt of emoji panel with nothing to recover it, which is the first thing the next
  keystroke hits. `update(size:insets:)` now runs the engine's own scroll-to-caret when a band GREW
  (`tgid_scrollCaretToVisibleIfNeeded`, the one forwarder needed, since the engine's is internal). Only
  when it grew: a shrinking band uncovers and cannot hide, and running it on every host layout would
  drag a scroll the user owns back to the caret. This one is NOT parity — legacy leaves the caret
  behind the keyboard too — so it is the one place here the engine is now ahead of the shipped editor.

**The two ends of the document are places you can land ON (2026-09-17).** Everywhere else the
minimum scroll is right — a caret leaving the viewport re-enters it flush against the edge it left by
— but on the FIRST line that leaves the document's own top margin above the viewport, so the first
line sits hard against the navigation bar with nothing before it and reads as "there is more up
there" when there is not; on the LAST line it leaves the bottom margin below and the caret flush
against the action bar. Measured with the keyboard up: 16pt short of the top, 18pt short of the end.
A rect that reaches the first line now reaches the content's top (`0`), one that reaches the last
line reaches `contentSize.height`, and a rect in the middle is left exactly as it was
(`test_aCaretInTheMiddleStillScrollsTheMinimum` is the half that keeps this from becoming "always
jump to an edge").

**Superseded 2026-09-17** by "The host decides when the caret is revealed", below: the rule moved
into `RichTextCaretRevealSolver` and both overrides described here are gone. The reasoning is kept
because the rule is unchanged — only its owner is. **The extension decides WHETHER as well as WHERE**,
which is why `TGIDObservingBlockTextView` replaced `-id_scrollCaretToVisibleIfNeeded` whole rather
than hooking `-id_scrollRectToVisible:` underneath it — the first cut did the latter, and it was half a fix.
Asked about the bare caret, the condition is satisfied by a first line resting FLUSH against the
navigation bar (line fully visible, margin scrolled off above it), the scroll never runs, and the
extension never gets a chance: the thing that has to be visible is the caret PLUS the end it reaches,
so that is what the containment test is given. The override is upstream's body with that one change,
so a re-port can diff the two; its guards — the responder role, editability, a collapsed selection,
finite geometry — are duplicated, at a cost worth naming, since a guard added upstream will not reach
the copy and nothing but a reader comparing them would notice. The two ends are asked of the ENGINE
(`-caretRectForPosition:` at the document's bounds) rather than guessed from the text-container
inset: what a first line's top is depends on the block's own spacing, and a guess would be wrong by
exactly the amount this recovers. `-id_scrollRectToVisible:` is declared in no header at all, so
calling it needs a local category declaration — the same arrangement the file already has for
`textInputDidChange:`.

**Where the numbers come from.** `EngineArticleInsetTests` is the article editor's real geometry
(402×810, top 68, bottom 92 / 400 / 407) rather than round numbers, and it asks the shipped editor the
same questions wherever a host can observe the answer — `test_theLegacyEditorDoesNotScrollThatDocumentEither`
exists so that the zero in the case above it is a contract and not this suite's opinion.

## The host decides when the caret is revealed (2026-09-17)

Neither editor scrolls itself to follow the caret. It reports that a reveal is owed and performs one
only inside a host's layout pass, against the geometry **that pass is applying**. Every defect this
replaced was an editor deciding against a number the host was about to change: the chat composer
flickering into scroll mode as the panel grew the field around a keystroke, and the article editor's
caret landing under a keyboard whose inset had not arrived yet — and then, when it was revealed on a
later pass, not animated.

- **`update(size:insets:contentMargins:scrollIndicatorInsets:caretReveal:)` is the only place a caret
  is revealed.** The four-argument spelling survives as a protocol extension forwarding `.none`, and
  that default is honest: a pass with nothing to say about the caret does not move it.
- **`ifNeeded` means "something asked", not "the caret is out of band."** Both hosts re-lay out for
  reasons that have nothing to do with the caret, so a bare out-of-band test would yank back a scroll
  the user deliberately dragged away. It reveals when a text or selection change recorded a request —
  `tgid_caretRevealPending` on the engine, `isCaretRevealOwed` in legacy — **or** when the pass itself
  CHANGED THE GEOMETRY the caret is measured against, which is the host moving the caret rather than
  the user. The flag is cleared whatever the outcome, including when the guards decline.
- **That second condition read "shrank the viewport" until 2026-09-18, and a shrink is one instance
  of it rather than the rule.** A pass can make the field TALLER and still hide the caret, because
  changing the field's WIDTH re-wraps the text and moves every line below the change. Measured on K3,
  dismissing the software keyboard with the caret at the end of a scrolling draft: field 274 -> 298,
  content 405 -> 428, caret 377 -> 400 against a visible band ending at 405 — eighteen points under
  the edge, with nothing asking (the caret never moved in the document; the text moved under it) and
  nothing shrinking. Reported as "pressing Return on a hardware keyboard dismisses the software
  keyboard and the caret can be hidden". The predicate is now the whole applied geometry, size and
  insets, compared with what the last pass applied.
- **Widening it widens what can yank a scroll back, and what still protects one is that an identical
  pass reveals nothing.** `ifNeeded` is only not the bare out-of-band test because a pass applying the
  SAME geometry declines — pinned by
  `EngineCaretRevealContractTests.test_aPassThatChangesNothingLeavesAUserScrollAlone`, which scrolls
  away from the caret and asserts the offset survives.
- **LEGACY has no geometry condition at all.** `RichTextEditorView.revealCaret` is gated on
  `isCaretRevealOwed` alone, so it reveals only when something asked and never when a pass hides a
  caret nobody moved. That is narrower than the engine editor in both the old shape and the new one;
  recorded rather than quietly widened, because it changes the shipped editor's behaviour.
- **The arithmetic is `RichTextCaretRevealSolver`** (Core): numbers in, an optional offset out, no
  views. It carries the clamp and the ends rule — a caret on the first line reveals the document's
  top, one on the last line its bottom. Legacy passes the two ends as nil, which the solver reads as
  "the ordinary minimum scroll"; that is its behaviour, not a downgrade.
- **The report is SEPARATE from `onChange` and synchronous.** `onChange`'s selection half is coalesced
  to a trailing async call so a toolbar never sees a transient selection; a reveal riding it lands a
  turn late, and a rapid second arrow key then computes against an in-flight offset — the
  non-determinism `RichTextEditorView.scrollCaretIntoView`'s own comment records. Hence
  `onCaretRevealNeeded`, answered by re-applying the geometry the last pass committed to.
- **One report per edit, and where that boundary is was measured.** Upstream reaches the engine's
  caret path THREE times for one `insertText` — `id_reconcileDerivedStateForDocumentChange:`, UIKit's
  selection settle, then `textInputDidChange:` — and only the last has settled geometry. So the engine
  only MARKS the fact and the wrapper reports at the end of the edit, immediately for a caret move
  with no edit in flight, and at the end of a host-driven mutation. **The in-flight marker must sit
  BELOW the `isApplyingHostDocument` guard**: a `document` set never gets a `textInputDidChange:`, so
  marking it above leaves the flag stuck and silently swallows every later caret move.
- **The applied geometry is compared against what the LAST PASS APPLIED, never against the view's
  own bounds.** A host may assign the editor's frame directly before calling `update` — the chat
  panel does, through `textFieldFrame` — so by the time the call runs the bounds are already the new
  ones, and comparing against them answers "nothing changed" for every resize there is. That is how
  the first cut of this rule shipped and did nothing: traced on the device, the field went 298 to 274
  tall and the pass still reported no shrink.
- **It is about the VISIBLE AREA, not about the insets.** The article editor's
  viewport shrinks because a band grows; the chat composer's shrinks because the FIELD does — its
  insets are always zero, and focusing it hides the accessory buttons, re-wraps the text wider and
  leaves the field shorter (281x169 to 317x146, traced on the device). Asked about insets alone the
  composer's pass declined to reveal a caret it had just put below the edge, which is the reported
  "tap the last line and the cursor ends up below the edge".
- **Animate only when the pass changed the geometry.** A reveal owed to a caret that MOVED is written
  immediately whatever the host passed, for the arrow-key reason above; one owed to a viewport that
  shrank rides the host's animation. `.spring` is a real, critically damped spring rather than an
  `easeInOut` wearing the name — not a byte-match of `ContainedViewLayoutTransition`'s private
  `kCAMediaTimingFunctionSpring`, which this package cannot reach, and the comment says so.
- **The animation crosses as a DESCRIPTION, not a transition.** `RichTextEditorAnimation` is the
  package's own type; each host maps its `ComponentTransition` / `ContainedViewLayoutTransition` at
  the boundary with an exhaustive switch, so a curve added upstream is a compile error there rather
  than a silent fallback.
- **Caret-follow now depends on a host pass arriving**, which is a new coupling. A host that installs
  `onCaretRevealNeeded` and ignores it stops following the caret, and the symptom reads as "typing
  feels broken". `caretRevealsNeverAskedAbout` counts that in DEBUG. Deliberately a count and a log
  rather than an assertion: the check is necessarily deferred, and an assertion firing a turn later
  lands inside whatever test is running by then.

**Three verification traps this work walked into**, all worth knowing before trusting a green run
here. A programmatic `selectedTextRange` set to the caret's OWN position moves nothing and reports
nothing — mistaking that for "the property is not wired" produced a confident, wrong claim that
survived into a commit message. The flicker regression was VACUOUS as first written, because a 96pt
field with short inserts produced a 102pt document and there was nothing to scroll; it now asserts
the fixture overflows threefold before asserting anything else. And the `InputDecEngine` bundle can
fail ~189 tests all reading `((windowScene) != nil)`, while the spelling family can fail in bulk when
the simulator is loaded — both environmental, both fixed by re-running the scheme alone.

## A two-digit ordinal needs more room than the base indent reserves (2026-09-11)

At ten a numbered list's marker grows a character and the text stopped clearing it: the device showed
`10F`, `11F` — the ordinal drawn straight through the item's own text. The base indent
(`listMarkerSpacing + orderedListTextInset`) reserves one character, and nothing widened it.

The extra room is **`(characters − 1) × one digit`**, measured on `0` and never on the label
(`EngineListMarkerGeometry.orderedMarkerExtraInset`). Measuring the rendered label would make `1.`
and `7.` indent differently and would shift a list's text sideways as it renumbered; counting
characters against a fixed figure advance gives every ordinal of the same length the same indent,
which is what keeps a decade of items in one column. A one-character label gets zero, so no existing
document moves — the base indent is exactly the `constant` of that formula and stays the whole answer
below ten. The level-1 and level-2 ladders (`a.`, `iii.`) are counted the same way; their glyphs are
narrower than a figure, so they are reserved slightly generously rather than clipped.

- **It is a BLOCK INSET, not the paragraph style**, and that is the load-bearing choice. The indent
  is a function of the item's NUMBER, and the number changes without the item being edited — insert
  an item above and everything below renumbers. Baked into the attributed string it would go stale
  exactly then, and only the blocks settle happened to touch would be repaired. `blockInsets` is
  recomputed from the roles on every layout pass, like the markers themselves, so it cannot.
- **One derivation, two consumers** (`orderedListMarkerInsets()`): `syncContainerBlockInsets` adds it
  to the engine's per-block inset, which moves that block's text right and narrows it, and
  `syncListMarkers` SUBTRACTS it from the frame the engine reports — the marker must not move, it
  stays in its gutter while only the text hangs further past it.
- **Measured on the role's OWN font**, through `bridge.renderMapper(for:)`: a quoted item renders at
  15pt, and a digit measured on the plain 17pt sheet would reserve too much. That is also why the
  amount is computed in the view rather than inside `EngineBlockSpacing`, which is handed one sheet.
- **Cells are excluded**, for the same reason they are unmarked: a list inside a table cell draws no
  marker in either editor, so indenting its text would open a gap for a marker that is never there.
- **The inset narrows the TEXT, which took an upstream fix** (`a71301dd`, re-ported). A block inset
  moved and sized a STACKED block's canvas and left its measure at the full column — only the PLACED
  branch subtracted insets — so item ten wrapped where every other block wraps and was then drawn one
  digit in, running ~9pt past the trailing edge (measured on K3: canvas at x 15.3, still 308.3 wide on
  a 310pt column). Every container's insets are vertical-only, which is why it took a horizontal one
  to surface. Reserving space horizontally without taking it out of the measure is half an inset, so
  the fix is at the definition rather than at this caller; pinned both sides
  (`testHorizontalBlockInsetsNarrowTheTextMeasureOfAStackedBlock` upstream,
  `test_aTwoDigitOrdinalsTextStopsAtTheSameColumnEdge` here).
- **LEGACY still has the defect.** Its `BlockBox.listMarkerDraw` left-anchors the marker exactly the
  same way and takes its text indent from the shared `StyleSheet`, which cannot know the ordinal —
  fixing it means threading the number into the paragraph style, and `Canvas/` is not this branch's
  to edit. The composer will still show `10F`.

## A tap places the caret under the finger, not at the end of the word (2026-09-18)

Reported from the chat composer: "often when I tap on the field to focus, it opens context menu like
I tapped twice. This does not happen every time." The menu is real, it is UIKit's, and a single tap
raises it. Traced live on K3 with breakpoints on the private text-interaction path:

    _handleMultiTapGesture:            state=Began taps=1      <- ONE physical tap
      _checkForRepeatedTap:
        tappedToPositionCursorWithGesture:
          _UIKeyboardTextSelectionController selectPositionAtPoint:
            didUpdateSelectionWithGesture:
              _showSelectionCommandsIfApplicableAfterDelay:     <- the menu

`-[UITextSelectionInteraction didUpdateSelectionWithGesture:]` shows the edit menu when the view was
ALREADY first responder before the gesture and the caret rect after the tap EQUALS the rect before it
— UIKit's "you tapped the caret" affordance. Two facts made an apparently first tap qualify:

- **UIKit snapped the tapped position to the word's END.** `-[UIResponder
  _findPleasingWordBoundaryFromPosition:]` returns the enclosing word's start when the tap is within
  one character of it and its END otherwise, so every tap two or more characters into a word resolves
  to the same offset. Measured: `closestPositionToPoint pt=(24,17)` -> `_findBoundary in=2` ->
  `ctrl.setSelectedTextRange start=29`. The engine mapped the point correctly; the snap discarded it.
  A draft with long tokens has whole LINES that are one word, which is why it fired so often.
- **The composer is frequently first responder while it LOOKS unfocused.** With the emoji keyboard up
  the field keeps first responder and swaps its `inputView`, so the tap that a user makes "to focus"
  is a tap on a focused field. Measured in that state: `wasOriginallyFR=1`, caret unchanged, menu.
  From a genuinely unfocused field (`wasOriginallyFR=0`) the menu never appears — including after the
  keyboard is dismissed by scrolling, which does resign.

**`TGIDObservingBlockTextView` overrides `_findBoundaryPositionClosestToPosition:withGranularity:`**
and returns the position unchanged for the WORD granularity, so a tap lands on the character under
the finger. Every tap at a different character then moves the caret, and the menu is left to the one
gesture meant to raise it. The snap has exactly ONE caller in UIKitCore —
`-[_UIKeyboardTextSelectionController selectPositionAtPoint:granularity:completionHandler:]` — so the
override changes tap placement and nothing else; every other granularity still goes to `super`.

- **It is NOT an engine defect, and the control is what says so.** A stock `UITextView` created in
  the same process resolves to the same `_UIKeyboardTextSelectionController`
  (`[tv interactionAssistant].activeSelectionController`), and the snap lives in `UIResponder`, which
  the engine does not override. `EngineTapCaretPlacementTests` keeps that as a live control: if Apple
  ever stops snapping, the control fails and says the override has become a no-op, rather than
  leaving three green tests that prove nothing.
- **The override is in the HOST layer**, `Sources/RichTextInputDecHost/`, not upstream — the upstream
  tree is grepped for private selectors, and this is a Telegram-side adaptation like the edit-menu
  provider and the gesture veto beside it.
- **This makes the engine MATCH legacy, it does not diverge from it.** `DocumentCanvasView` never had
  the snap: it handles taps with its OWN recogniser and places the caret at
  `closestGlobalPosition(to: point)` (`+Interaction.swift`), so UIKit's selection controller is not
  in its path at all. Its menu rule is `tapOutcome`, which toggles only when the tap lands on the
  rendered caret or selection — which is exactly what the engine now does, because a tap at a
  different character finally moves the caret. The engine was the outlier, and it was the outlier for
  a structural reason: hosting UIKit's private `UITextInteractionAssistant` is the whole point of this
  engine, and inheriting `_findPleasingWordBoundaryFromPosition:` came with it.

**Two harness facts from the investigation.** A stock control view added directly to the app's window
receives NO taps — `Display`'s window subclass overrides `hitTest:` and routes only to its own
container — so a side-by-side comparison has to be made by reading the two views' UIKit machinery
rather than by driving them. And the edit menu queries the pasteboard, so every reproduction raises
the system "would like to paste from" alert, which then swallows the next synthesised tap; a scripted
repro has to dismiss it between attempts or every later measurement is of the alert.

## Italic inside a pull quote is inert, and the menu says so (2026-09-23)

Format ▸ Italic over a pull quote's body is a NO-OP in the engine editor, and the composer's Format
menu shows it DISABLED there (`RichTextEditor.italicReachesSelection` →
`ChatRichTextInputNode.canPerformFormatAction(.italic)` → the `UIAction`'s `.disabled`). That is a
decision taken on evidence, because `ChatInputPullQuote`'s runs DO carry a full
`ChatInputInlineAttributes` (italic included), so "the model cannot carry it" is not true of the
wire type on its face. It is true of everything that produces and consumes one:

- **Neither editor's `Document` can hold it.** The shared mapper's read-back is
  `ca.italic = (style == .pullQuote) ? false : traits.contains(.traitItalic)` — so a pull-quote run
  never reads back italic in the legacy canvas or the engine, whatever the storage says.
- **The recipient could not see it anyway.** V2 lays a pull quote out with
  `styleStack.push(.italic)` (`layoutQuoteText`), and `InstantPageTextStyleStack.textAttributes()`
  resolves italic as a set-once `Bool` — a nested `.italic` from the run changes nothing. There is no
  "emphasis inverts inside italic" convention anywhere in that path, so an italic run in a pull quote
  renders exactly like its neighbours.

So the toggle was a command with no possible effect, and it was ACTIVELY harmful in the engine: the
engine's trait pass put an `IDInlineTextItalic` marker on every run, and on an INLINE-CODE run — whose
base face the role composes upright — that slanted the code on screen while the model stayed
unchanged; the next normalisation redrew it upright and kept the marker, so the drift outlived the
slant (composer harness, fuzz seed 82, `HarnessPullQuoteItalicOverCodeTests`). The exclusion is
`inlineFormatTargetRanges(excludingPullQuoteBodies:)` (`+TableSelection.swift`), the same mechanism
that keeps formats off a code block's language line; a selection reaching text outside the pull quote
still italicises that text. The pull quote's AUTHOR line is not excluded (its own rule, unchanged).

If either fact above changes — the mapper starts reading italic back in a pull quote, or V2 learns to
invert emphasis — Italic must become functional again, and the fix for the code-run drift is then the
other one: the code run's face carries the pull quote's ambient slant plus the user's marker,
consistently in the bridge's render and its read-back.

## Rules from the composer harness's twelfth wave (2026-09-24)

- **A paste obeys typing's refusal.** A selection covering a table only in part refuses typed text,
  and a paste over it is refused the same way (`rangeCoversATableOnlyInPart`, the one predicate
  `replaceAcrossBlocks` also asks). Every paste route used to bypass the gate: the engine's own
  plain/RTF paste replaces the selection by a storage edit the gate never sees, and a fragment
  paste widened the range over the whole table and dropped it.
- **An untracked anchor's clamp is sticky** (`IDRichTextAnchor`,
  `id_snapshotCanonicalOffsetClampedToLength:`). UIKit's input-controller range holds snapshot
  anchors; read as `MIN(snapshot, length)`, a snapshot past the end re-grew into text typed later,
  and while typing at the end it read EQUAL to every new caret, so the controller never replaced it
  (paste → Send → type → paste put the caret where the first paste ended). A position past the end
  is the end for good now.
- **A substituted face is always re-seated on its base family on read-back**
  (`withCarriedTraitsOnFallbackFaces`), even when the substitute already carries the intended
  traits: the mapper's `boldIsAmbient` distrusts a bold substituted face, so a heading's bold
  Thai/Hebrew substitute swallowed the user's Bold.
- **The composer's flat axis mirrors `ChatInputContent.blockFlatLength`**: a details (title AND
  body, at any depth) and a button row are off it. A caret inside an off-axis block still reads as
  the end of the flat text, legacy's answer (`EngineComposerAxisTests`, `EngineMediaRoundTripTests`).
- **`extractFragment` enters a details** like a block quote, and carries EMPTY code blocks and pull
  quotes (author included) under the empty paragraph's coverage rule; `replacingRange` edits inside
  one details in place. A cross-block range ENTERING a details title truncates, it does not merge
  the title away.
- **Empty-line probes are per SHAPE**: `cachedLineAttributes(for:)` is the one way to ask the
  bridge for an empty block's attributes. Each probe renders a document wrapped in the role's
  whole ancestry, so the spacing walk asking uncached made a keystroke O(depth²) in nested quotes.

## Rules from the composer harness's p11 fixes (2026-09-24)

- **A composition is typing.** Starting over a selection, the gate decides the selection first, as a
  deletion (`TGIDObservingBlockTextView setMarkedText:selectedRange:`; refused over a table covered in
  part, where the composition does not start). The commit gets the typing attributes the composition
  STARTED with, then (at a caret only, as `insertText:` does) the typed-text policy
  (`IDBlockTextView unmarkText` / `insertText:` while marked). The deletion and the composition are
  one undo step (`tgid_isResolvingCompositionSelection`).
- **A host-decided keystroke ends its own edit** (`endHostDecidedKeystroke`): a caret-door Backspace
  rule, a gate veto and a host structural command get no `textInputDidChange:`, so without it
  `isEngineEditInFlight` stayed set and no later caret move ended a run. A composition continues a run
  only when contiguous with it; settle's edits keep an open run (moved with its text) rather than
  closing it; an attribute-only edit never registers twice against one baseline.
- **UIKit's tokenizer answers a block's END as an empty line** — `TGIDLineEndCorrectingTokenizer`
  corrects that one answer (⌘←/⇧⌘← at a line's end), leaving a genuinely empty line alone.
- **Hardware Return** is claimed (`\r`, `⌘\r`) when a host sets `onHardwareReturn`; a declined one is
  `insertText("\n")` on the gated surface.
- **The chat's ⌘B & co. run the engine's own commands** (`ChatTextInputPanelNode.performNativeFormatShortcut`;
  ⇧⌘N is `clearInlineFormatting`, one step), never the `NSAttributedString` rebuild.

## Rules from the composer harness's p12 fixes (2026-09-24)

- **A presentation change re-renders IN PLACE** (`rerenderPresentation(of:)`, `RichTextEngineEditorView.swift`).
  Every applier that swaps the bridge — theme, render metrics (Text Size), code / quote / pull-quote /
  media geometry — used to re-set the document, which replaces every block (every block's rendering
  differs), so the caret went to the end, a selection was lost and an open IME composition ended.
  When the new rendering has the same blocks with the same characters, only attributes are written,
  through the adapter: no character edit, no input-delegate bracket, the selection and marked range
  stay. The TYPING attributes, and an open composition's `id_compositionTypingAttributes`, are
  translated old → new value by value (`id_translateTypingAttributesUsingBlock:`); without that the
  next typed character or committed candidate kept the old palette, and the read-back
  (`withoutCarriedPresentation` forgives only the CURRENT theme's text colour) took it for an
  explicit colour. A change of characters (the formula renderer) still takes the document set.
- **Both composition doors decide the selection first.** `setAttributedMarkedText:selectedRange:` is
  overridden like `setMarkedText:selectedRange:` and shares `tgid_resolveSelectionBeforeComposition`.
  Adding a third text-entry door means routing it through the gate too.
- **A replacement's inherited attributes stop at the first newline** (`tgid_attributeReplacement:`).
  What follows a newline is a new block and keeps the presentation settle derived from its role.
- **Return-then-text in one delivery at a heading's start is split** into the Return and the rest,
  each decided as its keystroke (`isAtStartOfNonEmptyHeading` + `typeAtCaret(deciding:at:)`). Other
  multi-character deliveries are forwarded whole, as before.
- **A one-line field (language, details title, author) turns a newline inside delivered text into a
  space** (`oneLineFieldText`: a whitespace run containing a newline → ONE space; `UITextField` maps
  each newline separately, measured). A lone "\n" is the Return key and keeps each field's own rule.
  A PASTE into such a field goes through the gate as that text (`pastePlainTextIntoOneLineField`,
  ahead of the fragment paste): the engine's own paste split the field.

## Text drag and drop in the engine editor (2026-09-24)

`UITextInteraction` installs neither half, and `UITextDraggable`/`UITextDroppable` do not install anything either, so the editor adds its own `UIDragInteraction` and `UIDropInteraction` to the engine view (`+DragAndDrop.swift`).

- **A drop is a paste read from the session, not from the clipboard.** Every paste handler takes an `EnginePasteSource` (`+Clipboard.swift`). `paste:` passes `.generalPasteboard`, which reads its contents lazily, in the same order as before. A drop passes its loaded items. The engine's own `paste:` reads the pasteboard, so a drop's plain text is inserted through the gated `replaceRange:withText:` instead (`insertPlainText(from:)`).
- **A local move is Cut + Paste, as one undo step** (p19; it was a composed pair of `Document` replacements, which deleted by Core's complement rule and dropped what the destination could not hold — see "Rules from the composer harness's p19 fixes"). The source is deleted through the surface gate, the content lands through the paste handlers, and a destination that cannot hold the payload refuses the drop.
- **Arbitration is UITextView's rule.** A long press inside the selection is the drag's, and anywhere else it is the loupe's. `tgid_shouldBeginGestureRecognizerHandler` sees each recogniser: inside the selection it refuses `UIVariableDelayLoupeGesture`, and outside it refuses the `_UIDrag…` lift. The drag is disabled whenever the focused editor has no non-empty selection, so without a selection the recognisers are exactly as they were before this.
- Tests: harness `HarnessTextDropTests` (Tier 1) and `HarnessTextDragUITests` (Tier 2, real touches).

## A long press beside the caret needs the autoscroll TICK, not the scroll (2026-09-24)

A loupe (`UIVariableDelayLoupeGesture`) that begins within 40pt of the caret is UIKit's "drag the caret
by its offset" mode (`UITextRefinementTouchBehavior`): it moves the caret to the finger when it begins,
and on release re-places it at the ORIGINAL caret plus the translation — i.e. puts it back — unless
the assistant's `autoscrolled` bit is set. Nothing about the bit is about scrolling in practice: the
stock text view starts an autoscroll session whenever the point is in the top or bottom 32pt band of
its interior, which is every point when the interior is shorter than 64pt (a composer of up to about
three lines), and the session's first tick sets the bit before it finds nothing to scroll and cancels.
So on legacy a long press always leaves the caret at the finger.

- **The engine must report ticks it does not need.** `startAutoscroll:` answers
  `autoscrollDidTick` wherever `IDVerticalAutoscrollStockSessionWouldStart` holds, even when the engine's
  own rule (8pt band, and only if it can scroll) starts nothing; `updateVerticalAutoscroll:` reports
  every real tick. Without either, the long press read as "nothing happened, then the edit menu"
  (`HarnessLongPressCaretUITests`).
- **The tick is IN ADDITION to `autoscrollWillNotStart`, never instead of it.** That notice is what
  releases the magnifiers, and it does not clear the bit, so it goes first and the tick after. Replacing
  it stalled the drag suite 2 runs in 7 (neutered: 0 in 5); both together: 0 in 5.
- **`autoscrollDidTick` is an uninventoried private send** (`setAutoscrolled:`, shape-checked) in the
  kernel's `IDUIKitInteractionCapability`. The vendored contract manifest is pinned and its generator
  is not in this repo; add it there when the generator arrives.
- Diagnosing this took lldb on BOTH backends in one process: the two runs differ only at the
  `autoscrolled` read in the touch behavior's state-3 (ended) path. The fixture geometry matters too:
  the harness's legacy focus press leaves the caret at the END (44), so a naive control never takes
  the near-caret path; press twice to put the legacy caret where the engine's is.

## Rules from the composer harness's p13 fixes: content that arrives when EDITING (2026-09-24)

- **The composer's flat axis counts an atom by its MODEL length.** A formula is one `U+FFFC` in the
  engine and its LaTeX in `ChatInputContent`; a custom emoji is one `U+FFFC` and its alt text. So
  `composerAxisSegments()` (`+Selection.swift`) carries, per on-axis block, every attachment whose model
  length is not one (`FormulaTextAttachment.latex`, `EmojiTextAttachment.ref.altText`), and both
  mappings add the difference. A model offset INSIDE an atom's span snaps to its nearer boundary; a
  range widens over every atom it touches. An inline button is `U+FFFC` on both axes. Measuring by
  engine length alone made the chat's `replacingFlatRange` at the reported selection split an emoji's
  surrogate pair (`HarnessAtomComposerAxisTests`).
- **A button row's two stops are atom stops.** The gate routes `.standalone(.buttonRow)` through
  `decideTextInputAtAnAtomUnit` (caption-less: a body paragraph above / below), and
  `settleButtonRowAtomIntegrity` lifts text found beside the row's atom into body paragraphs — the
  engine's own plain-text paste never reaches the gate, so settle is what catches it
  (`HarnessButtonRowStopTypingTests`).
- **Inline formats skip atoms; presentation over an atom is re-derived.** Bold / Italic / Underline /
  Strikethrough are not model state on ANY attachment atom, and Spoiler is model state on an INLINE
  atom (formula, button, emoji) but not on a media atom or a row. The engine's toggle and the spoiler
  transform write over the whole range, so both are followed by `rederiveAtomPresentation(touching:)`
  (`+Settle.swift`), which re-renders only the attachment characters of the touched blocks — the
  presentation keys AND the engine's four `IDInlineText*` trait markers: a marker left behind makes the
  engine (and the verifier's `withCarriedTraitsOnFallbackFaces`) derive the toggled face again however
  `.font` was corrected. The drifted face also leaked into the next IME commit
  (`HarnessAtomInlineFormatDriftTests`).
- **A quote's author line keeps its runs.** `Block.authorRuns` (`EngineBlockRole.swift`) drops only
  the render-only emphasis (bold, italic) and the pinned size; a mention, link, date or custom emoji
  there is the message's. Author lines read back at `.caption`, the style `authorLine` renders them at
  (at `.body` their runs carried the caption's size and colour as overrides). Rebuilding the author
  from `flatText` lost every entity on a mere set → get and left a custom emoji as a bare `U+FFFC`
  (`HarnessAuthorLineEntityTests`).
- **Core's non-text expansion recurses.** `Document.expandingRangeOverNonTextBlocks` walks expanded
  quote children and expanded details bodies on the axis `extractFragment` uses; a quoted medium
  entered in part used to be copied as text alone and lost by Cut + Paste
  (`HarnessQuotedMediaCopyTests`). Callers: the engine's copy / paste / drag and the article screen's
  AI selection. The legacy canvas does not call it.
- **A caption is a text region for copy and for paste.** A range inside ONE caption copies as its text
  (`Document.captionTextFragment`, asked before the whole-unit expansion), and Core's
  `replacingRangeInsideOneContainer` splices a fragment pasted into a caption as one-line runs (the
  details title's `oneLineRuns(of:)`). The complement model had dropped the whole unit
  (`HarnessCaptionFragmentPasteTests`). Drag lifted the whole unit from a caption until p19; it lifts what
  Copy takes now.
- **A composition at an atom's stop is placed ONCE, when it starts.** The gate decides each finished
  keystroke at a stop, and a vetoed candidate leaves nothing marked, so every candidate used to be
  decided as a keystroke. `tgid_compositionCaretResolver` (`TGIDObservingBlockTextView`) is asked when
  a composition starts at a collapsed caret; `resolveAtomStopBeforeComposition` (`+MediaEditing.swift`)
  moves a captioned medium's trailing stop to the caption's start, and at a leading or caption-less
  stop mints the body line typing would — with undo registration OFF and `lastSettledUndoSnapshot` put
  back to the pre-mint state, so the composition's own step reverts the line too. A composition that
  ends with the line still empty (`setMarkedText("")`, reported through the new
  `tgid_compositionDidEmptyHandler`, or a commit of nothing) removes it unrecorded
  (`HarnessAtomStopCompositionTests`).
- **Undo replays the language line as typed.** Snapshots are taken from `replayDocument`, which is the
  model except that a code language keeps its surrounding whitespace (`languagesAsTyped:`); the model
  (`document`) still trims. Replaying the trimmed model shortened the line under a caret measured on
  the line as typed, which then sat in the code BODY (`HarnessCodeLanguageRedoTests`).

## Rules from the composer harness's p14 fixes: width changes and accessibility (2026-09-24)

- **A pass that RE-WRAPS the text flushes the selection display, like a document change.**
  `-[IDBlockTextView layoutSubviews]` records the wrap width and `textContainerInset` it laid the
  blocks out against and flushes (`id_flushSelectionDisplayUpdate`) when either differs from the last
  pass. A rotation / Split View / host resize used to leave the cursor and highlight at the OLD wrap
  for one run-loop turn (`HarnessWidthChangeSelectionDisplayTests`). The first pass records only, and
  a pass at the same geometry never flushes, so the Shift+Right anchor rule above is untouched. This
  is the engine-level half of `markCaretForRedrawIfHostGeometryMoved`: the chat panel assigns the
  editor's frame directly (`textFieldFrame`) and the wrapper's `layoutSubviews` re-frames the engine,
  a path that does not go through `update(...)`; when that pass runs first, `update` finds the engine
  already at the new frame and its mark sees no change (reasoned from the code, not traced). A width change
  that DOES go through `update` can now flush twice in one pass (engine, then
  `drawTheCaretWithAHostChange`); accepted, it is one extra `layoutManagedSubviews` per width change.
- **Accessibility lives on the TEXT AREA.** `RichTextEngineEditorView.accessibilityHint` / `Label`
  forward to the engine view, the element VoiceOver focuses (legacy puts the chat's "Message" hint
  on its `UITextView`). The wrapper's getter reads the same value back, so `axe describe-ui` lists the
  hint on the container `Group` too; that is not an element and is never spoken.
- **VoiceOver reads atoms as text, on its own axis** (`RichTextEngineEditorView+Accessibility.swift`).
  The engine's raw text holds each atom as `U+FFFC`; the host answers `accessibilityValue` with:
  custom emoji → alt text, formula → LaTeX (both are the composer axis's model lengths), inline
  button → label, button row → labels joined by ", ", medium → the host's
  `accessibilityMediaName(kind)` (the composer passes `Message_Photo` / `_Video` / `_Location` /
  `_Audio` / `_File`; nil reads nothing), collapsed quote → preview text, anything else → nothing.
  Unlike the composer axis, every block is on it (details, tables, captions): VoiceOver reads what is
  on screen. Because readings change lengths, the host also maps the AX runtime's selection, which it
  otherwise derives from `-selectedTextRange` on the engine axis: `TGIDObservingBlockTextView`
  overrides `_accessibilitySelectedTextRange` and `_accessibilitySetSelectedTextRange:` through two
  host blocks; an AX offset inside an atom's reading snaps to the nearer boundary, a range widens over
  every atom it touches (the composer axis's rounding). The AX runtime's line / column queries still
  go through `UITextInput` on the engine axis. Pinned by `HarnessAccessibilityTests`; the in-process
  AX bundle is not loaded, so the private selectors are called directly there.
- **A table's run scrolls sideways to the caret** (`RichTextEngineEditorView+RunCaretReveal.swift`).
  `performCaretReveal` (inside the host's layout pass) makes a reveal OWED when a text or selection
  change asked (`tgid_caretRevealPending`) or the pass changed the WIDTH (`update`'s `widthChanged`:
  the applied width or the side margins); the wrapper's `layoutSubviews` spends it
  (`revealSelectionEndInPlacedRun`) right after `syncRunScrollOffsets`, i.e. after `syncTableFrames`
  has placed the tables. Performed inside the host's pass it measured a table a redo had just
  re-created before its cells were at their real widths, declined, and left the caret off screen
  (fuzz seed 34, pinned by `HarnessComposerFuzzTests.testEngineFuzzSeed34WidthRoundTrip`). It reveals the selection's END
  (Tab selects a cell) against the table's COLUMN (`tableColumnOutsets`, where the engine rests a
  run's far edge), not the clip window, using the vertical reveal's margins: the caret rect, plus an
  ends rule by column (first column → offset 0, last column → the run's maximum, while the caret stays
  in view). It updates `runScrollOffsets` so a height probe's `pushRunScrollOffsets` does not undo it.
  A height-only or identical pass never touches the run, which is what leaves a manual horizontal
  scroll alone (`HarnessTableCaretRevealTests.testAManualScrollAwaySurvivesPassesThatDoNotMoveTheCaret`;
  neuter-checked: triggering on any geometry change fails it). `RichTextCaretRevealSolver` stays
  vertical-only.

## Rules from the composer harness's p15 fixes: external sets, replays and scale (2026-09-25)

- **An EXTERNAL set empties the undo stack; a `document` set does not.** The chat's
  `setInputContent` with content that differs from the editor's (a draft sync, Send's clear) calls
  `RichTextEditor.discardUndoHistory()` after the set, as a stock `UITextView` and the legacy composer
  do on a `text` set; before it, one ⌘Z after Send brought the sent text back
  (`HarnessExternalSetUndoTests`). The content-equal echo returns before the rebuild and keeps the
  stack. The `document` setter itself still keeps history and only moves the baseline, because the
  editor's own commands rebuild through it and register their own step — so "a host set is a new
  BASELINE" (above) is about the SETTER, and the host decides when a set is external.
- **The setter's span scan compares atoms by what they draw.** `renderedBlocksAgree` is
  `NSAttributedString` equality except that an inline atom's attachment (custom emoji, formula, inline
  button) is compared with `drawsTheSameAs`. A fresh render mints new attachment objects, so identity
  equality made every undo / redo / set replace every block up to the last atom paragraph
  (`HarnessAtomParagraphReplayIdentityTests`). Do NOT give those attachment classes value `isEqual`:
  equal adjacent attachments coalesce into one attribute run, and everything that walks attachments
  expects one object per character. Media, button-row and collapsed-quote attachments (one per block)
  already have value `isEqual`.
- **Batch attribute edits over many small runs.** Every `tgid_mergeAttributes` is one storage edit that
  rebuilds the canonical projection of the WHOLE document, so one call per atom made Format over N
  atoms (or N media blocks) O(N²). `rederiveAtomPresentation` now keys its edits by attachment object
  and applies them in one `tgid_transformAttributesInCanonicalRange:usingBlock:`
  (`HarnessAtomFormatScalingTests`, neuter-checked). `normalisePresentation`, `rerenderPresentation`
  and `rerenderButtonRowAtoms` had the same shape and WERE superlinear (follow-up below).
- **An expanded details always has a body.** `settleDetailsWithoutBody` mints one empty body paragraph
  under a title left alone in its span (a range from the title into a one-paragraph body keeps the
  title as survivor) — the set path's shape, so get → set → get is stable
  (`HarnessDetailsBodyCrossDeleteTests`). A folded details legitimately has only its title.
- **Table rows are solved until the cells' heights stop moving.** A cell's used height is measured at
  the width it is currently placed at, so a width change's first pass solves new columns with old
  heights; `syncTableFrames` repeats (at most three passes) while the heights after its push differ
  from the ones it solved with (`HarnessTableWidthChangeRowHeightTests`).
- **A truncate never keeps a dropped unit's endpoint role.** In `replaceAcrossBlocks`, when one
  endpoint is a leaf / details title the range only enters and the OTHER endpoint's unit is covered
  whole (a table, a code block, a quote), the covered unit and everything between go and the entered
  block absorbs the text; the old truncate kept a table CELL's role on one merged engine line, which
  split the model from the engine (`HarnessWholeTableEditIntoSecondaryLineTests`).
- **Host edits inherit the attributes where the CARET is, so put it back first.** A replacement issued
  through `replaceFlat` takes the controller's typing attributes, which follow the live selection;
  after an earlier segment's cut they described the caption, not the range's start.
  `truncateAroundMediaUnits` re-selects the head segment before inserting
  (`HarnessTypingIntoCaptionFormattingTests`).
- **Links are not drawn underlined, so the typed-text policy must not strip underline.** An underline
  on the preceding character is the user's and continues into text typed inside or after a link
  (`HarnessUnderlinedLinkTypingTests`). Text leaving a link takes the colour its BLOCK derives
  (`cachedLineAttributes(for:)` — a caption's, an author line's), not the theme's primary text: the
  policy re-attributes AFTER settle, so a wrong colour there is never corrected
  (`HarnessCaptionEntityEmojiDriftTests`).

## Rules from the p15 follow-up: scale and the chat's own edits (2026-09-25)

- **A pass over the blocks never asks a per-block question that walks the blocks.** Three did:
  `canonicalStart(ofBlock:)` (the spoiler decorator's, asked for EVERY block on every canvas pass
  after a selection change), `flatOffset(ofRoleAt:)` per touched block in `normalisePresentation` and
  `rederiveAtomPresentation`, and the canvas's own re-insert of every block view. Each is O(N) and
  harmless alone; inside a per-block loop it made a caret move, a Format and a theme change O(N²).
  Ask the engine view's identity cache (`tgid_indexOfBlockIdentifier:`,
  `tgid_canonicalStartOfBlockIdentifier:` — both rebuilt once per `IDBlockDocument.blocks` array), or
  walk the offsets once alongside the loop. `engine.attributedBlocks` and `engine.tgid_blockIdentifiers`
  BUILD an array per read: never read them inside a per-block callback.
- **A presentation pass lands as ONE attribute edit.** Collect `PresentationEdit`s and hand them to
  `applyPresentationEdits` (host `tgid_mergeAttributeEditsInCanonicalRanges:attributes:removingKeys:`);
  one `tgid_mergeAttributes` per run re-projects the document and runs a canvas pass over every block
  PER RUN — a theme change over 240 paragraphs took 8.4 s, Monospace off 14.6 s
  (`HarnessPresentationPassScalingTests`). Like the single merge, the batch edits block TEXT only: a
  range's separator part is ignored (the per-run merges ignored it too, so `rerenderPresentation`'s
  separator diffs were, and are, no-ops).
- **The canvas pass does not re-insert a view that is already in place.** `insertSubview:atIndex:`
  looks the view up in `subviews` even when nothing moves; `updateForDocumentChange:width:` compares
  against the hierarchy it read at the start while nothing has changed it, and inserts as before after
  the first real change.
- **A host set is one of two things, and the HOST says which.** `discardUndoHistory()` after a set
  from OUTSIDE (Send's clear, a draft sync): the stack describes a document the user no longer has.
  `performAsOneUndoStep { document = … }` for a set made on the USER's behalf (the chat's autocomplete,
  emoji keyboard, date editor, Translate): one step restoring the pre-set snapshot, on top of the
  typing before it (`HarnessChatSideEditUndoTests`). The bare `document` setter still does neither —
  it only moves the baseline, because the editor's own commands register their own step. The chat
  composer decides by scope: `ChatRichTextInputNode.performUndoableInputChange`, which the chat's
  `updateTextInputStateAndMode` closure wraps around every transform.


## Rules from the composer harness's p16 fixes: lines, lists and flattened atoms (2026-09-25)

- **Deleting whole lines keeps the line after them as it is.** A deletion from a standalone
  paragraph's offset 0 to a later block's offset 0 (⇧↓ from a line's start, then Backspace or Cut)
  drops the blocks before that block and keeps its role, identity and text
  (`deletesWholeLinesBefore`, the first rule of `replaceAcrossBlocks` after the refusals). The merge
  keeps the FIRST block's role, which is right for everything else — typing over the same range
  (the typed text starts in the replaced line, as in a stock text view) and a deletion that keeps
  part of the first line — and wrong here: the heading below a deleted line became body, a body line
  became a heading, a quote or checked item lost its structure (`HarnessWholeLineDeletionTests`).
  Atom units and cells as the kept block keep the rules they had, and so does a range whose END
  unit is dropped whole (a quote's author line after its children). **Not for a composition:** the
  deletion a composition starts over a selection is typing (p11), and typing takes the FIRST line's
  role, so the rule would make the two disagree on one keystroke (fuzz seed 63; it checks
  `tgid_isResolvingCompositionSelection`).
- **Return at the start of a non-empty list item opens a fresh item ABOVE** and the item keeps
  itself — role, identity, `checked` (`decideReturnInListItem`). Left to the engine's split, the
  identity stayed on the emptied upper half and the check moved onto the new empty line
  (`HarnessChecklistReturnAtStartTests`). The new item is the list continuation's: same marker and
  level, unchecked, body. It is the heading's Return-at-start rule for list items; the TOP exit (a
  second Return with an empty first item above) is asked before it and still ends the list.
- **A non-empty range's end is exclusive when deciding which blocks it touches.**
  `touchedBlockIndices(for:)` (every block command: Quote, Code, Pull Quote, the table commands, the
  presentation re-derivations) and the Tab path's `touchedParagraphIndices(for:)` follow
  `NSString.paragraphRange(for:)`: a range touches a block when it holds one of its characters, its
  break included. A range ending exactly at a block's start does not touch it; a CARET at either edge
  of a block still does (`HarnessBlockCommandSelectionEndTests`).
- **Plain text never carries an atom's attachment character.** Core `runsPlainText` gives a custom
  emoji its `altText` (nothing without one), an inline button its label, a formula its LaTeX, and
  `blockPlainText` / `tableFlattenedText` use it: Format ▸ Code, a fragment pasted into code, the
  plain-text pasteboard (which a one-line field — language, details title, author — pastes from) and
  Table ▸ Convert to Text all put plain text where only text lives, and a `U+FFFC` there is a bare
  character the message sends literally (`HarnessAtomFlatteningTests`). Where the destination holds
  RUNS (a pull quote's body, a details title, a caption), a fragment is spliced as runs
  (`blockInlineRuns` in `DocumentFragment.swift`), fresh emoji instance ids included — never as its
  plain text (`HarnessPullQuoteFragmentAtomPasteTests`).
- **Never re-insert kept text as a string.** A host edit that must keep text around a replacement
  edits only what goes: `replaceAcrossCells` is one edit inside each cell, last to first, never
  crossing a cell separator; the old single span edit re-inserted the cells' kept text as plain
  strings and dropped every attribute and attachment on it. When text must MOVE, insert it and then
  put its attributes back (`restoreStyleFlat`, the two-step `insertMedia` and `replaceTable` use).
  Still open, found by the audit and not reachable from a test: `settleMediaAtomIntegrity` moves a
  tail found beside a media atom into the caption as a plain substring (a bypass-path repair only).
- **A part of ONE list item's text copies as text, not as an item** (Core `extractFragment`: no
  break and not all of its text → no `list`), so a paste folds it inline as a stock text view does;
  all of an item's text, or anything reaching past it, still copies as the item
  (`HarnessPartialFragmentPasteTests`). A heading's partial copy is left alone by decision.

## Rules from the composer harness's p17 fixes: arrow walks, list continuation, empty last lines (2026-09-25)

- **A vertical walk that runs out of lines lands on the document's edge, never nil.** A held ↑/↓ is
  `position(from: history.start, in:, offset: presses)`, and
  `-[IDRichTextLayoutController id_positionFromPosition:inDirection:offset:…]` steps one line at a time
  toward the caller's fixed goal x. A step with no line beyond it answered nil for the WHOLE request,
  and UIKit then substituted a position of its own — past a container, a line far back up the
  document (↓×4 over a code block: 12, 13, **11**, 22). The walk now ends at the document's end (↓) /
  start (↑) — a stock text view's answer — but only when the failing step's caret is on that edge's
  line (`id_canonicalOffset:…isOnTheLineOfOffset:…`); any other failure still answers nil
  (`HarnessVerticalMoveAtDocumentEdgeTests`, host `EngineVerticalNavigationTests`).
- **Crossing into or within a placed run picks a ROW, then the NEAREST member.**
  `-[IDBlockStackCanvasView verticallyAdjacentBlockIdentifierFromBlockIdentifier:…]` used a point probe
  at the goal x, which misses whenever that x lies in no cell (left of the first column — the start of
  the line under a table) or, going up, in the 1pt grid border above a row; the walk then stepped out
  of the run and skipped rows, and entering a run upward fell back on `run.firstObject`, the LAST cell.
  Leaving a placed block takes the nearest row past its edge among the placed blocks adjacent in
  document order; entering takes the near-edge row; within either, the member horizontally nearest
  the goal x (zero inside it).
- **A list continues among SIBLINGS only.** `blockIDsNeedingListContinuation` considers standalone
  blocks whose ancestry equals the carried item's; a container's own line (author, title, language,
  caption) or a cell ends the run. A fresh author line (minted by a cross-block deletion from a quoted
  item) was scheduled to inherit the item's list, and the reconciliation's `document` set landed
  between IME candidates, ending the composition with its first candidate committed
  (`HarnessCompositionAcrossQuoteEndTests`, host `EngineCompositionAcrossQuoteEndTests`). General
  hazard, still open: ANY deferred host `document` set can land inside a composition; whether it ends
  it depends on whether the replaced span reaches the marked text (it did for an Arabic item and not a
  Latin one — RTL storage differs from a fresh render, so the span grows).
- **"The document end" in `extractFragment` is the COPIED document's**, carried into the recursion as
  `endsTheCopiedDocument` — true for an expanded details ending the document, never for a quote's
  children (its author line follows). Nested empty paragraphs are admitted by the same rule as empty
  code / pull quotes, so Select All → Copy keeps a details' empty last body line; a top-level empty
  last paragraph keeps the bare rule (the trailing line a paste supplies)
  (`HarnessDetailsTrailingEmptyLineCopyTests`, Core `DocumentFragmentTrailingEmptyLineTests`).

## Rules from the composer harness's p18 fixes: host inserts and the paste complement (2026-09-25)

- **A host inserting text on the user's behalf goes through the editor, never through the flat
  projection.** `RichTextEditor.insertInlineRunsOnUsersBehalf(_:)` (engine:
  `+HostInsert.swift`) inserts at the ENGINE's selection: plain text by `insertText` (the gate and the
  typed-text policy, so it equals typing), a custom emoji by `insertEmoji` with the spoiler of the
  character BEFORE the caret (`isSpoilerActive()` answers no at a caret inside a spoiler: continuation is
  the typed-text policy's, not the typing attributes'), a link run typed then `setLink`. One undo step
  (registration off, `recordUndoStepForCommand` before the delivery) and one `onChange`
  (`deliveringOneChangeNotificationAcrossSteps`: flushes inside it keep the notification owed). The chat's
  emoji keyboard and avatar-menu Mention reach it through `ChatRichTextInputNode.insertTextOnUsersBehalf`
  (default `false`, legacy unchanged); the flat rewrite retyped every block as body and could not address a
  caret in a cell (`HarnessChatInsertStructureTests`). The non-engine native editor has no such verb and
  still takes the chat's flat transform.
- **`replacingRange` measures a range with `extractFragment`'s own coverage rule.** The copy carries an
  empty code block / pull quote (or an expanded details' empty last line) at the document's end when a range
  ends exactly at its empty text; the complement's suffix, taken from that position, carried it too, so a
  paste-back duplicated it (`HarnessEmptyPullQuoteAtEndPasteTests`). `carriedEmptyEndRegionStart` mirrors
  the copy's admission case by case (never a top-level trailing paragraph, never a quote's children) and a
  range ending there takes the rest of the document. A new admission in `extractFragment` needs its mirror
  there, or copy and paste disagree about one range again (Core `DocumentCarriedEmptyEndRegionReplaceTests`).
- **A command that restyles the SELECTED text re-adopts the typing attributes.** UIKit derives the
  input controller's typing attributes only on a selection change, and they are what a keystroke over
  the selection is attributed with. `recordingInlineFormatStep` ends with
  `tgid_adoptTypingAttributesOfSelectedText` (UIKit's `_invalidateTypingAttributes`, the re-derivation a
  selection change and an undo run; writing the first character's attributes directly carried spoiler and
  inline-code markers the allowed set keeps out, fuzz seeds 31, 41); without it Bold / Strikethrough / a link then typing over the selection
  typed plain text (`HarnessTypingOverFormattedSelectionTests`). A new command that restyles a selection
  outside `recordingInlineFormatStep` must ask for the same.
- **A fuzz known-defect filter hides everything with the same signature.** The p18 `chatInsert` filter
  counted this unrelated engine defect as the flat-rebuild one for a whole sweep; retire a filter the
  moment its fix lands and read the sweep again.
- **A selection DELETED through the gate re-derives the typing attributes.** Backspace and Cut over a
  selection are `replaceRange:withText:@""`, and a replacement keeps the replaced text's typing
  attributes; a stock text view types the next character with the caret's own
  (`tgid_rederiveTypingAttributesAfterSelectionDeletion`, `HarnessTypingOverFormattedSelectionTests`).
- **On a code block's language line the inline trait markers are presentation, not user state:**
  `normalisePresentation` re-derives them there with the presentation keys, or a marker that arrived with
  moved or pasted text re-derives its face after the font is corrected
  (`HarnessCodeLanguageMoveFormattingTests`).

## Rules from the composer harness's p19 fixes: clipboard units, moves, geometry and nil endpoints (2026-09-25)

- **Copy and Cut decide what a range holds ONCE** (`clipboardSelection()`, `+Clipboard.swift`). A range
  inside one caption or one table cell is that text region's (`captionTextFragment`,
  `tableCellFragment`): its covered text is copied and the selection is deleted. Any other range is
  widened over every UNIT it enters in part — a medium with its caption, a table, a button row, a
  folded quote — on the engine axis (`flatRangeExpandedOverUnits`), and that one widened range is both
  extracted and deleted (Cut's deletion arrives through `tgid_cutRangeHandler` and still goes through
  the surface gate). Before, Copy widened and the gate's deletion kept a partly covered unit's atom, so
  Cut + Paste duplicated the photo (`HarnessCutIntoCaptionMediaDuplicationTests`). Exception: a
  selection covering a table in part keeps the selection as its deletion, so the gate still refuses it
  (Cut is a Copy there, a move of it is refused). The paste target uses the same rule.
- **The clipboard range also takes every container the gate drops WHOLE** (`widenedOverDroppedContainers`,
  asking the gate's own `containerIsCovered`). The gate drops a container whose primary blocks a range
  covers "second lines included" — a quote's author, a code block's language — even where the range
  stops short of them; a copy that stopped there carried an empty author, so Cut + Paste of a quote's
  body lost the author (`HarnessQuoteAuthorCutMoveTests`). Core's `extractFragment` carries a quote's
  or pull quote's COVERED author slice (the author IS on the editor's axis), and `blockInlineRuns` keeps
  it as a line of its own when a quote fragment is degraded to runs. A range covering ALL of a block
  quote's children's primary text (or all of a pull quote's body) carries the WHOLE author, and
  `replacingRange`'s complement then keeps none of it: for a block quote the complement used to keep
  the author as a body paragraph, so an AI edit answered unchanged gave `[quote … by ""] [p "Auth"]`
  (2026-10-12, `DocumentSecondaryLineReplaceTests`). A range covering a code block's
  language but none of its text copies the language slice as text; a move carrying a code block WITH a
  language into a runs-only destination is refused (the language has no inline form).
- **An endpoint on a unit's EDGE is the unit block's edge on the global axis**
  (`unitAwareGlobalPosition`). `globalPosition(atFlatOffset:)` answers a text-less role's block START
  for BOTH of its offsets (and a caption's end is inside the block's span), so a selection starting just
  after an audio atom copied the audio. The clipboard verbs map through the unit-aware form;
  `globalPosition` itself is unchanged.
- **A table cell is a text region in Core.** `replacingRangeInsideOneContainer` has a `.table` arm: a
  range inside one cell's children is replaced there, the fragment degraded to inline runs
  (`blockInlineRuns`, one line per block; a medium, table or row adds nothing). The complement model had
  put the collapsed range inside the table's span, so a paste at a caret in a cell deleted the table
  (`HarnessFragmentPasteIntoTableCellTests`, Core `DocumentTableCellFragmentTests`).
- **A local drag-and-drop move IS Cut + Paste** (`performLocalMove`): the lift is `clipboardSelection()`,
  the source is deleted through the gate, the target is carried across the deletion by the length it
  removed, and the content lands through `performHostPaste` / `insertPlainText`, all inside
  `performAsOneUndoStep` and one change notification. The old composed pair of Core replacements
  deleted with the complement model (the source's halves were not joined across a container,
  `HarnessLocalMoveSourceJoinTests`) and dropped what the destination could not hold while still
  deleting it. **A move is refused where the destination cannot hold what it carries**
  (`destinationHolds`, asked by the drop proposal too): a medium, table or row into a caption, a cell or
  a pull quote's body; any inline atom into plain text (a code body, a language / author / details-title
  line) (`HarnessLocalMoveContentLossTests`). A drag from inside a caption now lifts the caption TEXT,
  as Copy does (it lifted the whole unit before).
- **A zero-width selection segment is nothing to draw, not a failure to measure — for a NON-empty range
  too** (`IDBlockTextGeometry selectionSegmentsForLocalRange:`). A lone line separator (`U+2028`) comes
  back zero-width because TextKit widens a selected separator to its line's end only when the selection
  continues past it: it is widened to the line's end, as a selected paragraph break is drawn. A
  character that draws nothing (a leading right-to-left mark) has its segment dropped; the promotion
  hands its endpoint to the neighbour, and when it is the whole selection it stands up as a narrow mark.
  A tail extension whose caret already stands on the line's trailing edge (an atom that fills its line)
  draws the break mark against that edge — the block after a break with glyphs contributes nothing, so
  otherwise nobody drew it. Each of these used to fail the whole document's geometry: no highlight, no
  handles, the edit menu placed at infinity (`HarnessAtomLineBreakSelectionGeometryTests`,
  `HarnessSoftLineBreakSelectionGeometryTests`, `HarnessBidiMarkSelectionGeometryTests`). Diagnose this
  class by logging each `exact = NO` / `return nil` in the segment pass and the coordinator: the
  failing branch is named at once.
- **A missing endpoint is the native layout controller's answer, not a contract violation.** UIKit's
  `-[UITextInputController characterRangeByExtendingPosition:inDirection:]` steps with
  `-[_UITextLayoutControllerBase positionFromPosition:offset:]` (−1 for `.left` only, +1 for every other
  direction) and hands the result UNCHECKED to `textRangeFromPosition:toPosition:`; after a keyboard
  replacement it hands an unchecked position to `emptyTextRangeAtPosition:`. The TextKit 2 controller
  reads a nil `from` as the document start and a nil `to` as `from` (disassembled, iOS 26.5); the engine
  raised `NSInvalidArgumentException` and killed the app at a document edge
  (`HarnessExtendPastDocumentEdgeTests`). Both `id_` methods now answer as the native one does; a
  position of a foreign class, an expired anchor or another document still raises. The same
  disassembly shows one more unchecked hand-off, `_caretRectForOffset:` → `caretRectForPosition:`, not
  reached by anything measured.
- **VoiceOver reads a folded quote's preview through its attachments** (`accessibilityReading(ofAttributed:)`):
  the preview holds a custom emoji as `U+FFFC` (`HarnessCollapsedQuoteAccessibilityTests`).

## Rules from the composer harness's p20 fixes: what is SENT, the engine's own paste, clusters (2026-10-01)

- **A code block is plain text in this editor.** Its body is a `Pre` entity on the text route, and a
  Telegram `Pre` / `Code` entity holds no other entity (the Bot API nesting rule; the shared decoder reads a
  code region back as one plain run; legacy's model holds it plain). So every inline command skips a code
  body as it skips the language line (`inlineFormatTargetRanges`), the composer's Format menu shows them
  disabled there (`inlineFormatsReachSelection` → `canPerformFormatAction`; Link follows Bold), the bridge
  renders AND reads a code body through `EngineDocumentBridge.plainCodeRuns`, and settle treats trait
  markers in a code body as presentation (`normalisePresentation`). Before, Bold in code was drawn and kept
  in the model, dropped by the text route and sent by the rich one: one composer state, two messages
  (`HarnessSendPathCodeFormattingTests`). If the platform ever carries formats inside `Pre`, all four go.
- **Inline format ranges are widened to composed characters** (`composedCharacterRange`, inside
  `inlineFormatTargetRanges`, answered as a one-range list so the selection itself is untouched). Half a
  surrogate pair formatted split the run inside the pair and the model read two `U+FFFD`
  (`HarnessFormatSplitSurrogateTests`). Typed EDITS are not widened: a stock text view leaves an orphaned
  modifier, and so does this editor (`HarnessAuthorLineMidClusterCrashTests`' control).
- **Every structural `"\n"` search is LITERAL** (`NSLiteralSearch`; Swift `.literal`). Foundation's default
  search matches whole composed character sequences, and a separator followed by a mark or an emoji
  modifier is one: `IDBlocksFromCanonicalAttributedString` missed the separator before an orphaned skin tone,
  rebuilt one block too few and raised out of bounds in `replaceCanonicalRange:withAttributedString:` — a
  crash for any block starting with a combining character (`HarnessAuthorLineMidClusterCrashTests`).
  `String.components(separatedBy: "\n")` splits correctly; `replacingOccurrences(of:with:)` without
  `.literal` does not.
- **The ENGINE's own paste is reduced to what the model carries, in the host's combine step**
  (`TGIDObservingBlockTextView textPasteConfigurationSupporting:combineItemAttributedStrings:forRange:`):
  attachments and bare `U+FFFC` dropped (an RTFD image / HTML `<img>` was sent as a literal `U+FFFC`; there is
  no image-paste-to-media path for a text pasteboard), CRLF / CR made `"\n"`, and presentation taken from the
  caret's typing attributes with only the trait markers, underline / strikethrough and a link kept from the
  pasted run, the face rebuilt from the destination's base face (`HarnessExternalPasteImageAttachmentTests`,
  `HarnessPastedForeignColourTests`, `HarnessPastedCarriageReturnTests`). A foreign colour had survived
  because the read-back put it in `Document.foreground` and the re-render drew it again — invisible to the
  drift check; `modelUnrepresentableFields(atBlock:)` is the non-trapping check for that class. Host paths
  that read the pasteboard string get it through `EnginePasteSource.normalisingLineEndings`.
- **The engine's paste lands 20-30 ms after `paste:`, so prepare BEFORE it and mark the moment it lands.**
  `handlePasteFromGeneralPasteboard` (the `tgid_richPasteHandler`) runs the host's paste paths, then — for a
  text pasteboard the engine will paste — resolves a caret at a unit's stop as typing would
  (`resolveAtomStopBeforeComposition`, unrecorded; a multi-line paste at a medium's stop split the unit,
  `HarnessPasteAtMediaStopTests`). The cross-block deletion before the paste registers nothing and puts the
  baseline back, so the paste's own step undoes both (`HarnessCrossBlockPasteUndoTests`). The host view's
  `tgid_pasteWillLandHandler` fires synchronously before the insertion and ends the typing run, so a paste
  is never folded into the typing before it (`HarnessPasteJoinsTypingUndoTests`).
- **A local move registers its step even when it changes nothing** (`performAsOneUndoStep(registeringWhenUnchanged:)`).
  A pull-quote move that put identical text back compared equal and registered nothing, so ⌘Z took back the
  edit before it (`HarnessPullQuoteNoOpMoveUndoTests`).
- **Quotes past `EngineAncestor.maxIndentedQuoteLevels` (8) add no indent.** Sum indents ONLY through
  `Sequence<EngineAncestor>.contentIndent(styleSheet:)` / `contentTrailingInset(styleSheet:)` (bridge, decoration,
  details chrome, tables, media, markers); a hand-written `reduce` over `contentIndent` reintroduces the
  zero-width column 18 quotes deep (`HarnessDeepQuoteColumnTests`). The floor is in levels so a rendering stays
  a function of the role.
- **A spoilered formula is never standalone** (Core `ParagraphBlock.standaloneFormulaLatex`, TelegramCore's
  `ChatInputContent` twin, and the engine's `standaloneFormulaRoleIndices` agree): the `.formula` block holds
  no inline attribute, so it went out visible (`HarnessSendPathFormulaSpoilerTests`).
- **What the chat sends is decided in TextFormat** (`chatComposerSendRoute`, `chatComposerTextMessages`),
  called by `ChatControllerNode.sendCurrentMessage` and by the harness's send-path oracle alike.
- **Colour on a run is the ROLE's unless the model can carry it.** Two leaks the p20 fix wave's
  model-unrepresentable check found: the inline-code pill's fill left on text typed over a selection
  Monospace was just applied to (the read-back now drops the theme's inline-code fill from a non-code run,
  `withoutCarriedPresentation`, `HarnessTypingOverMonospaceSelectionTests`), and a link's accent on text
  typed at a block start before a link (the engine gives the typed-text policy no `preceding` there, so the
  policy also restores the block's colour when the run itself arrived linked,
  `HarnessTypedTextBeforeLinkColourTests`). A read-back that keeps a colour makes the re-render draw it
  again, so the drift check can never see this class; `modelUnrepresentableFields(atBlock:)` can.

## Rules from the composer harness's p21 fixes: walls, held steps, empty lines, width (2026-10-01)

- **A quote with an AUTHOR is a Backspace wall where Backspace would unwrap it.** Selecting the invisible
  break before a quote and pressing Backspace / Cut (or moving it) is, to the gate, Backspace at the quote's
  start (`rangeIsTheJoinBefore`) — one rule table for both doors — and the unwraps there (`quoteChild` for a
  lone child, `pullQuoteStart`) had nowhere to keep an attribution: a block quote's author text was deleted, a
  pull quote's became a body line. `authoredQuoteWall` (`applyBackspaceAtStartOfAuthoredQuote`) runs ahead of
  both and only travels the caret to the end of the block above, as a details' first body child does. An
  author-less quote unwraps as before; the commands still unwrap an authored one
  (`HarnessSeparatorBeforeQuoteDeletionTests`). **The wall is only the Backspace half** (p22): every WIDER
  range went past it and still turned the author into body text; the general rule is the settle one under
  "p22 fixes" below.
- **A refused local move changes nothing.** `performLocalMove` puts `documentAtLift` back when its paste
  inserted nothing after the source was deleted.
- **A code block's language line is NOT a `.code` shape.** It is `.secondary(kind: .codeLanguage)` over a
  paragraph shape, so a test for `.code` misses it; ask `secondaryKind == .codeLanguage` too. A custom emoji
  inserted there landed as a bare `U+FFFC` in the language (`HarnessCustomEmojiIntoCodeLanguageTests`).
- **A composition starts where, and with the attributes, typing would.** A rule that resolves a composition's
  selection somewhere other than the selection's start (the media truncate re-selects the caption head)
  must say so: select what typing would replace and call `tgid_noteCompositionTypingAttributesOfSelection`
  (only meaningful while `tgid_isResolvingCompositionSelection`); otherwise the composition takes the
  START's typing attributes (`HarnessCompositionFromMediaStopTests`).
- **A composition that opens a step holds it until it ends** (`pendingCompositionUndoStep`): registered when
  the composition commits / empties / is found unmarked at a settle and the document changed, dropped with
  its run when it did not (a stock text view records nothing for a cancelled composition). Every other
  `registerUndoStep` flushes it first; an undo replay or external set discards it. `EngineUndoManager`
  reports a held step in `canUndo` and registers it inside `undo()`, so ⌘Z during an open composition
  still reverts it (`EngineUndoRedoHostTests.test_aMultiStepCompositionIsStillOneStep` caught the first
  version, which held the step past an undo) (`HarnessCancelledCompositionUndoTests`). **For REDO the held
  step counts as registered** (p22, below): only undo was taught about it, so redo stayed live mid-composition.
- **Typing over a selection that starts on an EMPTY line types as a caret on that line.** The controller
  types over a selection with its first character's attributes — on an empty line, its separator, which is
  not presentation anybody re-derives (a set gives it the unthemed defaults, a Return split the typing
  attributes of the moment, an undo the role's). `TGIDObservingBlockTextView` overrides
  `id_adoptEmptyBlockTypingAttributesIfNeeded` to adopt the empty-line provider's attributes for a range
  start too (and `tgid_adoptTypingAttributesOfSelectedText` re-asks it). Deliberately NOT stock: a stock text
  view keeps whatever the newline was typed with; this model has no inline state on an empty paragraph
  (`HarnessDarkThemeEmptyLineTypingColourTests`, `HarnessUndoSeparatorTypingAttributesTests`). **Except
  straight after an inline format command** (p22, below): its traits win until the selection moves.
- **A non-empty block's separator follows its last character whenever the block's text attributes are
  restored** (`-[IDBlockDocument id_restoreAttributedBlocks:changedRange:]`, the path every batched
  presentation pass lands through), as a set and the canonical rebuild already gave it. Kept as it was, a
  theme change restyled the text and left every separator in the old theme, and text typed over a
  selection starting at a line's END was the light theme's black in the dark theme. An empty block's
  separator is still not re-rendered (typing reads the provider instead, rule above).
- **The levels that indent are capped by the TEXT COLUMN, not only by a level count.** The composer's text
  column is the editor width minus `textContainerInset` (50pt on the right for the send button): 267pt at a
  402pt screen, where 8 levels × 38pt is negative — and TextKit ignores a tail indent past the column, so the
  column was narrowest just below the cap and jumped back wide past it. `syncIndentedQuoteLevelLimit`
  (`layoutSubviews`) sets `StyleSheet.indentedQuoteLevelLimit` so the indenting levels leave at least
  `EngineAncestor.minimumQuotedColumnWidth`; `indentSum` caps at the smaller of it and
  `maxIndentedQuoteLevels`. The rendering is now a function of the role AND the width's level count: a width
  change re-renders only when it moves a whole level and a quote is that deep. Measure the column, never
  the editor's bounds (`HarnessDeepQuoteNarrowColumnTests`).

## Rules from the composer harness's p22 fixes: rules, not reproductions (2026-10-01)

Three of the five p22 defects were gaps in the p21 fix wave's own changes: each p21 fix handled the
reproduced range / verb and not its neighbours. The fixes below sit where every entry point passes.

- **A held step is a registered step for REDO.** `EngineUndoManager.clearRedoStack()` runs when a
  composition opens a held step (`recordUndoForEngineEdit`'s composing branch): a stock text view's first
  marked edit registers, which empties redo. Left live, ⌘⇧Z mid-composition replayed a snapshot over the
  marked text and the pre-composition document became unreachable (`HarnessRedoDuringCompositionTests`).
  `UndoManager` has no public "clear redo": register a throwaway action in a TOP-LEVEL group of its own and
  `removeAllActions(withTarget:)` it — measured in Foundation, the removal drops a top-level group it empties
  but leaves an empty NESTED group, which is an undo that does nothing; at grouping level 0 with
  `groupsByEvent` on, `beginUndoGrouping` opens the event's group first, so event grouping is suspended
  around it. A cancelled composition: redo stays cleared (stock), and still no undo step (p21 decision:
  stock's no-op step would swallow the next ⌘Z).
- **An author line is never turned into body text.** `settleOrphanedSecondaryLines` gives a quote (or pull
  quote) whose author line has text and whose last child went an empty primary line above the author
  (`mintEmptyPrimary(beforeAuthorLineAt:)`) — the shape the bridge renders for an authored quote with no
  children, so a set round trip agrees. Being in settle, it holds for Backspace, Cut, typing, a composition,
  Return, a move and anything else that empties the body (`HarnessAuthoredQuoteWideRangeTests`). The author
  goes with its quote only when a range COVERS the quote (`containerIsCovered`; the copy is widened to match,
  p19). An EMPTY orphaned author is still removed with its quote. Mid-composition the line is left for the
  commit's settle.
- **A range ending in a block quote's author truncates there**, like a details title and a pull quote's
  author (a leaf): the start keeps its head, the author keeps its tail as the author, everything between
  goes (`replaceAcrossBlocks`' `endIsLeaf`; `HarnessQuoteBodyIntoAuthorRangeTests`). Merged, the author's tail
  became body text. A range STARTING in an author still merges the next block's tail into it (as from a
  details title); not changed.
- **A one-line field takes EXACTLY what the copy deleted.** The editor's own Copy / Cut writes a third
  private representation, `RichTextEditorClipboard.oneLineFieldTextUTI`: the engine text of the clipboard
  range (`clipboardSelection().deletion`, the range Cut deletes) on one line — every line of it, languages,
  authors, titles, captions and cells included, joined by one space, inline atoms as their text, unit atoms
  as nothing (`oneLineFieldText(ofFlatRange:)`); a drag carries the same (`EngineTextDragContext.oneLineFieldText`).
  `pastePlainTextIntoOneLineField` prefers it, then a fragment from elsewhere flattened whole (Core
  `Document.oneLineFieldText`, languages as lines), then the plain string — never the plain string first,
  which leaves authors and languages out (`HarnessFragmentIntoOneLineFieldTests`). Copy == delete (p19) needs
  paste == copy too. **Why not the fragment:** a partial copy of a code body carries the block's language
  as METADATA (Core `CodeBlockPositionTests` pins it: a pasted slice is a code block in that language), so a
  fragment cannot say whether its language was text the range held. The first version flattened it from the
  fragment and the sweep (default / edited seed 27) caught a body slice moved into the language line pasting
  the WHOLE language a second time. For the same reason a move carrying a code block with a language is
  still refused into a RUNS-only region (cell, caption, pull quote body, p19); into a one-line field it is
  allowed now. `blockPlainText` (the external plain text, Format ▸ Code, Convert to Text) is unchanged.
  The pasted text goes through `oneLineFieldText` (the gate's one-line rule) before the gate: the gate
  flattens a text containing "\n" itself but forwards a `U+2028` unread, and a code body's soft break landed
  raw in a language line (read back as "\n": model and engine split, sweep seeds 27 / 35 / 40).
- **A format command's traits win over a line break at the selection's start, until the selection moves.**
  UIKit types over a selection with its first character's attributes, and when that is a separator (an
  empty line, a line's end) no inline command formatted it. `tgid_adoptTypingAttributesOfSelectedText` records
  the selection; while it is unchanged, `TGIDObservingBlockTextView`'s override applies the traits of the
  first selected TEXT character on top of whatever the start derived (the p21 role attributes keep face and
  colour). Read live each time, so an undo of the command under the same selection types plain; any other
  selection clears it, and without a format command p21 decides (`HarnessFormatOverEmptyLineSelectionTypingTests`).
  **The record (`tgid_formatCommandSelection`) is typing state an UNDO restores**: `EngineUndoSnapshot`
  carries it and `applyUndoSnapshot` puts it back (then re-adopts), as a stock text view's undo puts back the
  attributes its newline was given. Without that, an edit over the formatted selection, undone, typed plain
  — the fuzz's chat-insert oracle (insert, undo, type) caught it at default seed 40 / edited seed 4. Any
  new typing state the host keeps beside the document belongs in the snapshot for the same reason.

## Rules from the composer harness's p23 fixes: one-line fields, entities, separators, atoms (2026-10-02)

- **A one-line field holds no line break of ANY kind, on every door.** A code language, a details title and a
  pull quote's or block quote's author (`EngineBlockRole.isOneLineField`; a caption is multi-line) take
  `EngineDocumentBridge.oneLineText`: every whitespace run holding a `Character.isNewline` ("\n", CR, CRLF,
  `U+2028`, `U+2029`, NEL) becomes ONE space — the gate's and the paste's convention since p12. It is applied by
  the render (`languageLine`, `authorLine`, `detailsTitleLine`), the read-back (`block(for:from:)`), the gate
  (any delivery into such a field, not only text holding "\n") and settle (`settleLineBreaksInOneLineFields`,
  for what the gate never sees: a composition's commit, a cross-block replacement landing in the field). Before
  p23 the language and author were rendered from model text RAW, so a "\n" there — from a set, an edit load, or
  a typed `U+2028` read back as "\n" — became the engine's block separator: two engine blocks against one role,
  a debug trap at `TableLayout.swift:65`, and the last block lost from what is sent in release
  (`HarnessNewlineInOneLineFieldCrashTests`). A new one-line field must join `isOneLineField`.
- **No rendered block holds `U+000A`.** `engineRepresentation` passes every rendering through
  `withoutBlockSeparators` (a space in a one-line field, `U+2028` elsewhere) as a backstop for a kind that maps
  its own newlines wrongly. And a role count that disagrees with the engine's blocks at layout is REBUILT from
  the engine's identities (`recoverRolesFromEngineIdentities`, still a debug assertion): returning with the roles
  shifted recovered nothing and left the extra engine block unread.
- **A set the editor normalises is reported back to the chat.** `RichTextEditorChatInputNode.setInputContent`
  sends `chatInputTextNodeDidUpdateText` a turn later (the panel swallows it during its own push) when the content
  holds something the editor changes on the way in — a line break in a one-line field, inline code over an
  entity, a multi-emoji custom-emoji run — so what Send reads is what is shown. Add a new normalisation to
  `holdsContentTheEditorNormalises`, or the chat keeps sending the pre-normalisation content. **Superseded in p24:** the report is by construction now (below); there is no list to add to.
- **No run is inline code AND a link** (a mention, a date and a URL are all `link` in this model; the platform
  lets no `Code` entity overlap one). The commands refuse like legacy, whole or in part: Monospace ON over a
  range holding a link (`inlineCodeReachesSelection`, also the Format menu's answer) and Link over a range
  holding inline code (`linkReachesSelection`) do nothing. Content arriving with both keeps the ENTITY and drops
  the code (`withoutInlineCodeOverLinks`, render and read-back; `.rtInlineCode` is a presentation key, so settle
  removes the marker an edit left). (`HarnessInlineCodeOverEntityTests`)
- **An attribute transform gives a changed non-empty block's separator its last character's attributes**, the
  rule `id_restoreAttributedBlocks:changedRange:` already applied (p21). `id_transformTextAttributesInCanonicalRange:`
  kept the separator, so after Link over a line's end the separator was plain until an undo's restore linked it,
  and typing over a selection starting on it depended on the history. Decided LINKED (a stock text view's newline
  carries the attribute; a word typed against a link joins it) (`HarnessCompositionAfterLinkFromLineEndTests`).
  Every path that changes a block's text attributes must agree on the separator, or typing over a selection
  from a line's end depends on which path ran last.
- **A runs-only destination takes the copy's COVERED TEXT.** A fragment carries a code block's language as
  metadata even for a body slice, so a cell, a caption or a pull quote's body cannot tell a copied language
  from metadata. The editor's own Copy / Cut / drag writes `RichTextEditorClipboard.coveredTextFragmentUTI`
  (Core `extractFragmentAsCoveredText`: the covered part of a language line as a line, no language otherwise)
  and `pasteFragment` uses it there; a fragment from elsewhere holds every language as content
  (`withCodeLanguagesAsText`). The move refusal into those regions stays (p19). (`HarnessCodeLanguageIntoRunsRegionTests`)
- **An atom is one run per occurrence, at every boundary that coalesces runs.** Two adjacent identical custom
  emoji have EQUAL attributes in `ChatInputRun` (file id only), so anything that merges equal runs makes one run
  of two emoji. `runs(fromChatInputRuns:)` now makes one atom per character of a custom-emoji run, each with its
  own ref — before, the run became one `U+FFFC` holding both (`HarnessAdjacentCustomEmojiRunTests`, default fuzz
  seed 48, which reached it through the fuzz's own normaliser). Do not merge atom runs in a normaliser either.

## Rules from the composer harness's p24 fixes: by construction, one normaliser, the wire trims (2026-10-02)

- **A set is reported back whenever the read-back differs from what was set** — not when it matches a list.
  `RichTextEditorChatInputNode.setInputContent` compares `currentInputContent().content` with the content it
  was given and, if they differ, sends `chatInputTextNodeDidUpdateText` a turn later. p23's
  `holdsContentTheEditorNormalises` named three normalisations; the editor had more (formatting / entities /
  atoms in a code body, an empty language, `U+2028` / CR / `U+2029` in a body, coalesced atoms) and the chat
  sent them as set (`HarnessUnreportedSetNormalisationTests`). A new normalisation needs nothing here. The
  echo the report causes is content-equal and stops at the guard; a read-back that were not idempotent would
  loop, so keep `document → ChatInputContent → document` stable.
- **An atom is one run per occurrence for formulas and pills too.** `runs(fromChatInputRuns:)` splits a
  formula run holding its LaTeX k times and a pill run holding k `U+FFFC` into k atoms, like p23's custom emoji.
- **A code body holds TEXT only, atoms included.** `plainCodeRuns` (render and read-back) maps a custom emoji
  to its alt text, a formula to its LaTeX, a pill to its label (`runsPlainText`) — what every user path
  already put there (`HarnessAtomInSetCodeBodyTests`).
- **One line-break normaliser for every door: Core `normalisedLineBreaks`.** CRLF, CR, `U+2029` and NEL become
  `"\n"` (`U+2028` is the engine's in-block break and stays). It runs in the bridge's `engineText` (so every
  body render — the SET's door), in `EnginePasteSource` (host pastes, drops) and, mirrored as a literal list
  because the module cannot call Swift, in `TGIDObservingBlockTextView`'s paste combine step. Keep the two
  lists equal. A CR that survived a set was sent and made the tokenizer's paragraph boundaries disagree with
  the rest of `UITextInput` (`HarnessSetCarriageReturnTests`). `engineText` can now SHORTEN text (CRLF → one
  break): never assume it preserves length. The gate's typed text is not normalised (no keyboard types CR).
- **Marked text obeys the one-line-field rule.** The gate never sees marked text, so a candidate holding
  `"\n"` split an author / details title before settle could repair it. `tgid_markedTextFilter` (host view,
  both marked-text doors and `insertText:` while marked) hands such a candidate to the editor, which flattens
  it with `oneLineText` when the selection is in a one-line field; the composition stays open and its inner
  selection is clamped (`HarnessCompositionNewlineInOneLineFieldTests`).
- **The model holds a code language exactly as typed; the WIRE trims it.** Only an emptied line reads back nil
  (`EngineBlockRole.merging`); `languagesAsTyped` is gone and `replayDocument` is the model. Trimming in the
  read-back made the engine and the model disagree by the edge space: a re-render from the model (theme
  change) dropped it and restored the caret one character past the shortened line, into the code body's end
  (`HarnessCodeLanguageEdgeWhitespaceTests`). Trimming at settle was rejected — it eats the space between words
  typed one key at a time. `chatInputCodeLanguageForSending` (TelegramCore) trims at the `Pre` entity
  (`generateChatInputTextEntities`) and the rich `preformatted` block; the harness's send oracle canonicalises
  the same way.
- **The length the panel counts is what the text route sends.** `RichTextEditorChatInputNode.text` (the counter
  and the length-limited edit's Send guard) includes code bodies, pull quotes and folded quotes' content
  (`HarnessLengthCounterCodeBlockTests`).
- **A host insert's linked run sheds the inline code it inherited** (`insertRunOnUsersBehalf`): typed inside or
  after inline code it took the code's face, and `setLink` refuses a range holding inline code — the
  COMMAND's refusal, which content arriving on the user's behalf must not hit (`HarnessMentionIntoInlineCodeTests`).
- **Role recovery is by identity on both halves.** The document setter records identity → role split-aware
  (`recordBlockIdentitiesAfterReplacingSpan`): a rendered block the engine split on `U+000A` gives its role to
  its FIRST engine block, the other lines stay unknown, and the blocks after the span are matched from the end.
  `recoverRolesFromEngineIdentities` makes an unknown block a body paragraph at its predecessor's depth (out of a
  block quote after its author). Zipped positionally, a split shifted every later role and "by identity"
  rebuilt the shift. Test hooks force the state no shipping path reaches: `EngineDocumentBridge.testHookRenderedBlocks`
  and `RichTextEngineEditorView.testHookExpectsRoleCountMismatch` (`HarnessRoleRecoveryByIdentityTests`).

## Private UIKit names are not in the binary (2026-10-12)

The InputDec engine is compiled into every build, flag or not, and it reaches private UIKit by name:
it looks classes, protocols and ivars up, sends private selectors, and answers callbacks UIKit sends
to its objects under private names. App Store review scans a binary's strings, so **no private UIKit
name the engine crosses with may appear in the binary as text.**

- **One table.** Every such name is a line of `Scripts/private-runtime-names.txt` (161 today).
  `Scripts/generate-private-runtime-names.py` turns it into `RichTextInputDecObjC/include/TGPrivateRuntimeNames.h`,
  which stores each name with every byte XOR 0x5A (`ObfuscatedStrings`' encoding) and exposes it as
  `TGPN_<name>()`, every `:` spelled `_` (`_canHandleResponderAction:` is
  `TGPN__canHandleResponderAction_()`), decoded once. Never hand-edit the header: add the name to
  the list and regenerate. A selector is `NSSelectorFromString(TGPN_x())`, a C string `TGPN_x().UTF8String`.
- **A callback is compiled under a neutral name and ADDED under the private one.** The method is
  `tgpn_<name>` (or an existing `id_` method), and the class's `+initialize` calls
  `TGPrivateInstallMethodAliases` with a table of `{TGPN_x, @selector(tgpn_x)}` rows
  (`TGPrivateMethodAliases.h`; the precedent is `_canAffectStatusBarAppearance` in
  `UIViewController+Navigation.m`). It uses `class_addMethod`, never `class_replaceMethod`:
  replacing clobbered every subclass that defines the private name itself, including the engine's
  own test subclasses. A SUBCLASS that overrides a neutral method installs the table again from its
  own `+initialize` (`TGIDObservingBlockTextView`), or UIKit reaches the superclass's version.
- **`class_getInstanceMethod` does not run `+initialize`**, so asking whether a class answers a
  private selector before anything has messaged it reads "no". The capability resolver and
  `IDPrivateUIKit`'s ABI checks send `[cls class]` first. Any new introspection must too.
- **The table holds names that CROSS the boundary, not every name that matches one.** A name is in
  it when UIKit calls it on our object, we send it to UIKit, or we look it up. One of the engine's
  OWN members that merely shares a private name stays out of the table, renamed `id_…` so it cannot
  be mistaken for one (`id_textInputController`, `id_selectionContainerView`, `id_scrollContainer`,
  `id_textInputTraits`, `id_snapshotBaseWritingDirectionAtPosition:` …). Check before deciding a name
  is "only ours": UIKit's `-[_UITextLayoutControllerBase textInputController]` SENDS
  `textInputController` to the engine's connection object, so the renamed property is aliased back
  under that name (measured: 84 Host failures without it).
- **The embedded contract tables are encoded too.** `Generated/TGRichTextInputDecContractData.m` and
  `RichTextInputDecUpstream/Generated/RichTextInputDecUpstreamPristineManifest.m` hold their JSON as
  XOR-encoded byte arrays, decoded by `TGPrivateRuntimeDataDecode`; regenerate one with
  `Scripts/generate-private-runtime-names.py --encode-bytes <plain file>`. `VENDOR.md` pins both the
  file's digest and the decoded digest, and `VendorSnapshotIntegrityTests` checks the decoded bytes.
- **Two guards.** `PrivateRuntimeNamesTests` (Core, `swift test`) fails when the header and the list
  disagree, and when a shipping source spells a listed name as a string literal, inside a longer
  literal (names of 8+ characters), as `@selector(…)`, as a Swift `@objc(…)` name, as an Objective-C
  method declaration or definition, or as a property accessor, and when a Swift file that spells
  `#function` declares a function whose base name is a listed name (`#function` inside
  `func selectWord()` is the literal "selectWord()": two InputDec backend wrappers leaked exactly
  that way, found by the archive scan, and are `id_selectWord()` / `id_setNeedsSelectionDisplayUpdate()`
  now). Comments are ignored, so prose may name anything. The binary check is
  `Scripts/scan-private-runtime-names.py` on the RELEASE
  `TelegramUIFramework` unzipped from the `.ipa` (usage in its docstring).
- **Known residual: the legacy canvas's text-checking client.** `DocumentCanvasView+NativeTextCheckingClient.swift`
  answers `UITextCheckingController`'s callbacks as Swift `@objc` members under their real names,
  so they are in the binary. Two are also crossed by the engine and are therefore in the table
  (`replaceRange:withAnnotatedString:relativeReplacementRange:`, `annotatedSubstringForRange:`): the
  guard test allowlists exactly those two in that one file and fails if the allowance goes stale.
  The other two (`removeAnnotation:forRange:`, `validAnnotations`) are legacy-only and NOT in the
  table, so neither guard looks for them. The "Text checking" section above records why that client
  vends real names; converting it to the alias mechanism is the way to close this.
- **The release scan, measured 2026-10-12** (`release_sim_arm64`, `TelegramUIFramework` from the
  `.ipa`): 8 hits, each attributed to an archive and a section. The four InputDec archives
  (`RichTextInputDecObjC`, `RichTextInputDecUpstream`, `RichTextInputDecHost`, `RichTextEngineEditor`)
  have NONE, embedded contract tables included. In `RichTextEditorUIKit`: the two legacy selectors
  above (`__objc_methname`), plus `selectWord` and `selectionChanged` in `__swift5_reflstr`. Those two
  are the shared input-backend types' own enum cases and a Bool field (`RichTextInputCommand.selectWord`,
  `RichTextInputEditMenuDismissReason.selectionChanged`, `…CommandResult.selectionChanged`), not
  selectors. The other four (`_textInputTraits`, `textInputTraits`, `activateSelection`,
  `selectionContainerView`) are other modules' own names (AsyncDisplayKit, PassportUI, DrawingUI,
  LegacyMediaPickerUI, MediaEditorScreen) that predate this work; `selectionChanged` is also in
  DrawingUI, ContactListUI, AttachmentUI and ShareWithPeersScreen. The main binary and the other
  frameworks have none.
- **Xcode trap when the header is new or changed:** the explicit-module PCMs of every target that
  imports `RichTextInputDecObjC` keep the old header, and the symptom is "call to undeclared function
  TGPN_…" with no "file not found". Delete `RichTextInputDec*.pcm` under
  `{,Swift}ExplicitPrecompiledModules` in that DerivedData (see "Verification traps").
