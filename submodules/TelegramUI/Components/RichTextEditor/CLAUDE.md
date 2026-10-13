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
**opted into** via the `forceNewTextInput` ("Force Text Field v2") experimental flag. By default the composer is a
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
  `xcodebuild test -scheme RichTextEditor-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
  Expects an "iPhone 17 Pro" simulator booted; override with `DEVICE=…`.
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
`nodeStart + langLen + 3`. The value is stored AS TYPED, trimmed, empty → nil; only the renderer lowercases.

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
yet — verify via an RTE-active composer (`forceNewTextInput` ON — Debug Settings ▸ "Force Text Field v2") or the attachment editor.

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
strikethrough on checked text (matches the InstantPage rendering). Active when the native composer is (opt-in via `forceNewTextInput`); runtime-verified.

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
(the native composer is opt-in via `forceNewTextInput`). Runtime-verified.

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

## Verification traps in this package (earned, 2026-08)

Six measurement traps that cost real time during the input-backend seam work. Each is specific to this
package or this repo, and each produced a **green result that meant nothing** until it was caught.

- **`Scripts/iostest.sh` prints one `Executed …` summary PER TARGET, and the LAST is Core's.** Tailing the
  log gives you the Core number (a few hundred) and reads as the whole suite (a few thousand). Always record
  the decomposition: `N executed (UIKit X / S skipped + Core Y), exit 0`.
- **`swift test --filter <Suite>` selects nothing here** and prints `Executed 0 tests, with 0 failures` — a
  vacuous pass. Use `Scripts/iostest.sh <Target>/<Suite>` instead.
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

**And the general form of all six:** before recording an empty or zero result as evidence, prove the
instrument can produce a non-empty one. A count from an unvalidated command is not a measurement.
