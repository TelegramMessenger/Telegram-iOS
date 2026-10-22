# RichTextEditor

Telegram's from-scratch WYSIWYG rich-text editor: one shared model and two editors over it. This guide holds what
applies to the whole package; each editor and each vendored tree has its own guide (below), which loads with its files.

- **Core**: `Sources/RichTextEditorCore`, the pure-Foundation model both editors share.
- **Legacy editor / canvas editor**: `RichTextEditorView` / `DocumentCanvasView` (`Sources/RichTextEditorUIKit`).
  **Engine editor / "Input V3"**: `RichTextEngineEditorView` (`Sources/RichTextEngineEditor`), driving the vendored
  InputDec engine and kernel.
- **Legacy input**: the chat composer's old `UITextView`-based input, outside this package.

## Overview

- Headings, lists, tables, media with captions, links, custom emoji, spoilers, code blocks, quotes, details, formulas,
  buttons. The defining requirement is continuous selection across the whole document, including partial selection
  *through* table cells: one custom `UITextInput` view owning one global position model, never nested text views.
- Floor **iOS 13** (the legacy editor runs TextKit 2 on iOS 16+, TextKit 1 on 13–15); the engine editor needs iOS 18.4+.
- Hosts: the chat composer (`ChatRichTextEditorComposer`, `RichTextEditorChatInputNode`) and the article editor
  (`RichTextAttachmentScreen`, a separate module that also holds the host action bar).
- Composer mode: by default a dual-field switch — the legacy input, latching to the native editor only when content
  becomes legacy-non-representable (`ChatTextInputPanelNode`). Server flag `ios_rich_input_mode = 1` makes it native
  from the start on the legacy editor; Debug Settings ▸ "Input V3" (`ExperimentalUISettings.useInputDecEngine`) makes
  it native on the engine editor.
- The package's Bazel targets are in the app build.

### Guides
- `Sources/RichTextEditorUIKit/CLAUDE.md` — the canvas editor (layout engines, selection, editing, clipboard, undo,
  façade, theme).
- `Sources/RichTextEditorUIKit/InputBackend/CLAUDE.md` — the `RichTextInputBackend` seam and the InputDec backends.
- `Sources/RichTextEngineEditor/CLAUDE.md` — the engine editor (roles, surface gate, settle, containers, tables, undo).
- `Sources/RichTextInputDecUpstream/CLAUDE.md` — the vendored InputDec text engine (owned here).
- `Sources/RichTextInputDecObjC/CLAUDE.md` — the private-UIKit behaviour kernel.
- `Host/Engine/README.md` — the engine's own suites (unit, stock-`UITextView` oracle host, fixtures).
- Outside the package: `docs/richtext-composer.md` (composer integration), `docs/instantpage-richtext.md` (the V2
  renderer), `Tests/ComposerHarness/CLAUDE.md` (the loginless harness hosting the real composer).

## Build, test and verification

### Build and test
From this directory:
- Core (macOS, fast): `swift test`. UIKit sources and tests are `#if canImport(UIKit)`, so this builds Core only.
- UIKit + Core on a simulator: `Scripts/iostest.sh [Class/Test filter]` (`xcodebuild test -scheme
  RichTextEditor-Package`). Defaults to iPhone 18 Pro **K1** by UDID; override with `DEVICE=<udid>` (a bare `name=` is
  ambiguous across the K-sims).
- Host app (`Host/`, xcodegen): `Scripts/hostapp.sh` builds, installs and launches it; `Scripts/hostapp.sh test` runs
  the `InputDecHost` and `InputDecEngine` schemes. The engine's suites always run with `-parallel-testing-enabled NO`.
- Demo app (visual check): `cd Demo && xcodegen generate && xcodebuild …`.
- Both build systems must compile. `.module` exists only under SwiftPM, so `SpoilerDustView` loads its texture with
  `UIImage(named: "TextSpeckle", in: .module, …)` there and `UIImage(bundleImageName: "Components/TextSpeckle")` under
  Bazel (`import AppBundle` gated `#if !SWIFT_PACKAGE`). Keep both branches in sync.
- `RichTextEditorUIKit` depends only on `RichTextEditorCore`, `AppBundle` and `MosaicLayout` (SwiftPM tests and the
  Demo rely on it). Telegram services (highlighter, emoji views, formula renderer, `AccountContext`) come in through
  host seams.

### The K-sims moved to iOS 27, and two suites are environmental
The K-sims are iPhone 18 Pro on iOS 27.0: K1 `03A7DA9C-1832-49B8-9858-2F54F2FB5A04`, K2
`E643A78E-DB62-4DA4-9F54-BD0836F434AF`, K3 `4483DD69-685A-4FE1-89BE-65F992C271F2`. Two SwiftPM suites fail on 27.0
because of the runtime, not the code:
- **`LegacyDifferentialTests`:** the corpus was captured on iOS 26.5 / `23F73`, and
  `test_theRunningSimulatorIsTheCorpusCaptureBuild` fails ("DIFFERENTIAL RUN IS ON THE WRONG SIMULATOR RUNTIME") so the
  other cases cannot be read as real. Re-capture the corpus on 27.0 before reading them.
- **`IDUpstreamResponderModelTests`:** a real iOS 27 change in UIKit's private responder/keyboard wiring
  (`inputDelegate` binding, `requiresKeyboard`); passes on 26.5. The responder model is pinned to stock behaviour, so
  don't "fix" these against 27.0 until what stock now does is understood.

Use an iOS 26.5 control whenever an OS bump and a merge land together:
`xcrun simctl create RTE-control-26.5 "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5`, then
`DEVICE=<udid> Scripts/iostest.sh <filter>`.

### Verification traps
Before recording a result as evidence, prove the instrument can produce the other answer (an empty result where you
expect content, a 2 where you expect a 1).
- **Read every `Executed …` line.** `Scripts/iostest.sh` prints one per target and the last is Core's (record `N
  executed (UIKit X / S skipped + Core Y), exit 0`); under `swift test --filter` the UIKit bundle's `Executed 0 tests`
  comes first.
- **`swift test` compiles no canvas code and no kernel** (`Canvas/*.swift` is `#if canImport(UIKit)`; every
  `RichTextInputDecObjC` file is `TARGET_OS_IOS`-guarded), so a broken `#import` stays green. Only an iOS-simulator or
  Bazel build is evidence that something compiles.
- **The kernel's public headers import `"Kernel/…"` on purpose**; "simplifying" them breaks SwiftPM while Bazel stays
  green (`Sources/RichTextInputDecObjC/CLAUDE.md`).
- **A header added to an `include/` umbrella directory is invisible to other targets' Xcode build** ("call to
  undeclared function") until their explicit module PCMs are deleted:
  `DerivedData/<pkg>/Build/Intermediates.noindex/{,Swift}ExplicitPrecompiledModules/<Module>-*.pcm`. Clearing
  `ModuleCache.noindex` does not help.
- **A DerivedData directory's mtime is not its birth time**: use `stat -f %SB`, and prefer "this artifact could not
  have existed before, because its source did not".
- **`sysctlbyname("kern.osversion")` in a simulator returns the host Mac's build**; use
  `ProcessInfo.operatingSystemVersionString`. Two iOS 26.5 runtimes (`23F73` and a beta) can share one identifier.
- **The `UITextInput` position axis is sparse**: a top-level paragraph boundary occupies TWO position slots where the
  text projection emits one `"\n"`, so offsets are not character indices; `positionFromPosition:offset:` lands one
  character early past every boundary. Use the global↔flat mapper in `DocumentCanvasView+ComposerSelection.swift`.
- **`BlockLayoutEngine.attributedString` returns the live storage**: copy it (`NSAttributedString(attributedString:)`)
  before comparing, and add a positive control that the same gesture does change an unguarded block.
- **A canvas nobody retains is deallocated before a debounced pass fires** (`_ = makeCanvas(...)`), so a "nothing
  happens" test passes against a dead canvas. Hold it, and give such tests a positive control.
- **`DispatchQueue.main.async { fulfill }` does not wait for `asyncAfter`**; spin the run loop.
- **A test that waits for a callback cannot see a duplicate; a test that counts one must drain its own setup** (seeding
  the document and caret schedules a delivery). Confirm by reverting the fix (`EngineChangeNotificationCountTests`).
- **OS-driven selection writes never reach unit tests** (the object-replacement range for a tapped medium, ranges during
  the floating cursor). Capture the real sequence on a simulator (`NSLog` + `xcrun simctl spawn <udid> log stream`)
  before hypothesising a fix.
- **Caret-reveal tests can pass vacuously**: setting `selectedTextRange` to the caret's own position reports nothing,
  and a reveal/flicker regression must first assert its fixture overflows.
- **Composer harness:** the drift check cannot see a colour the read-back keeps; use
  `modelUnrepresentableFields(atBlock:)`. A fuzz known-defect filter hides everything with its signature: retire it the
  moment its fix lands.
- **Simulator driving:** `axe tap` never places a caret in the engine editor; `axe touch --down --up --delay 0.08`
  does. The XcodeBuildMCP debugger cannot evaluate expressions; `xcrun lldb -p <pid> --batch -s <script>` (after
  `expr @import UIKit`) can. Never `pgrep -f "<pattern>"` from a watcher whose command line contains the pattern.

## Core model (`RichTextEditorCore`)

- No UIKit: the model (`Document` / `Block` / `TextRun` / `CharacterAttributes` / …), JSON (`DocumentCodec`) and
  `.rtdoc` (`DocumentPackage`), the global position model (`DocumentTree` + `PositionResolver`), `RTSelection`,
  `TableMap`, `ListNumbering`, `RichTextCaretRevealSolver`.
- A document's title is a `.heading1` block. `ParagraphStyleName` has no `title` (a persisted `"title"` fails to
  decode; no shim). `caption` is render-only (media captions, 15pt): never in the picker, never persisted as a style;
  every exhaustive `switch ParagraphStyleName` carries it.
- `Block.code(CodeBlock)` (`id`, `language: String?`, plain `runs` that may contain `"\n"`) is a `DocumentTree`
  container of two paragraphs `[language, code]`: `nodeSize = len + langLen + 6`, language text at `nodeStart + 1`, code
  text at `nodeStart + langLen + 3`. The language line always exists, which keeps the code offset stable. The model
  holds the language exactly as typed (only an emptied line reads back nil); the wire trims it
  (`chatInputCodeLanguageForSending`); only the highlighter lowercases (`richTextNormalizedCodeLanguage`).
- `MediaBlock.items: [MediaItem]` (one shared caption) is ONE atom in the position model; back-compat decode keeps old
  documents valid, and `MediaItem.isSpoiler` is optional in Codable. `MediaKind.isCaptionless` (`.audio || .document`):
  `DocumentTree` emits a bare `mediaAtom` (nodeSize 3) and an incoming caption is dropped.
- A block formula is `ParagraphBlock.standaloneFormulaLatex` (body style, no list, exactly one formula run); there is no
  `Block.formula` and must not be. `InstantPageBuilder` promotes it to `InstantPageBlock.formula`. **A spoilered
  formula is never standalone**: Core's definition, TelegramCore's `ChatInputContent` twin and the engine's
  `standaloneFormulaRoleIndices` must agree, or it goes out visible (`HarnessSendPathFormulaSpoilerTests`).
- RTL: `TextAlignment.natural` (leading) is the default, `.left/.center/.right/.justified` override it;
  `Document.layoutDirection` (`.auto` by default and on decode) is the persisted whole-document override; detected
  direction is render-only.
- **One line-break normaliser, `normalisedLineBreaks`**: CRLF, CR, `U+2029` and NEL become `"\n"`; `U+2028` (the
  engine's in-block break) stays. Every door into an editor uses it. It can shorten text.

### Deleting a block's text empties the block, it does not delete it
`replacingRange` builds a delete as the complement (`[0, lo)` + `[hi, size)`). When BOTH endpoints sit on one block's
own text boundaries, the block is restored emptied, keeping its shape (`emptiedKeepingShape`: style, list, language,
author, identity; exhaustive, no `default`). A range over a block's whole span still drops it (a covered table); a range
crossing a paragraph break still joins the halves. Replacing a paragraph's whole text keeps the paragraph's style.

### Core reports where an insertion ends
`insertingFragmentReportingInsertion` / `replacingRangeReportingInsertion` report `lastInsertedBlockIndex` (nil when
the fragment folded wholly into existing text; one block before a surviving host tail unless `tailAbsorbedFragment`).
Only `insertingFragment` knows whether the ends merged or the empty tail was dropped; don't re-derive it in an editor:
the plain caret it returns is a structural position INSIDE a table, medium, button row, quote or details.

### A pasted fragment gets fresh identities at every level, on the way in
`replacingRange` regenerates block ids (`regeneratingTopLevelIDs()`; ids key the hosted-view pool) and run identities
(`regeneratingRunIdentities`, in every arm carrying `[TextRun]`). `EmojiRef.instanceID` (the emoji views' pooling key)
is the only run-level identity; formulas and inline buttons are positional. Regenerate on the way in, never at copy
time (a second paste would collide) or over the whole document (every emoji animation restarts). A pasted button's
opaque action becomes `.disabled` (`Document.convertingUnsupportedButtonActions()`, called by both editors).

## Fragments, paste and RTF (Core)

- **Full WYSIWYG, no markdown serializer.** Cross-app interchange is RTF; hosts convert pasted plain text through
  `plainTextFragmentTransformer`. Fragments: `Document.extractFragment` / `insertingFragment`
  (`Model/DocumentFragment.swift`).
- **A pasted paragraph merges inline keeping the host's style** (`isInlineMergeable`): a body paragraph always folds
  into the split host; a heading only into a host of the same style, else it stands alone
  (`DocumentFragmentHeadingPasteTests`). An empty outermost split half is dropped (keeping ≥1 block; the caret then
  ends the last pasted block); interior empties are kept. `replacingRange` edits inside one details in place.
- **What a copy carries**: a details is entered like a block quote; empty code blocks, pull quotes (author included)
  and nested empty paragraphs are carried. "The document end" is the COPIED document's (`endsTheCopiedDocument`, never
  true for a quote's children), so Select All → Copy keeps a details' empty last body line
  (`DocumentFragmentTrailingEmptyLineTests`). Part of ONE list item's text copies as text, all of it as the item; a
  heading's partial copy is left alone by decision.
- **Quote authors**: a copy carries the covered author slice (`blockInlineRuns` keeps it as its own line when degraded
  to runs). A range covering all of a quote's text carries the whole author, and `replacingRange` keeps none of it
  (`DocumentSecondaryLineReplaceTests`). A range covering only a code block's language copies it as text.
- **`replacingRange` measures by the copy's coverage rule**: `carriedEmptyEndRegionStart` mirrors each of
  `extractFragment`'s admissions of an empty end region, and a range ending there takes the rest of the document. A new
  admission needs its mirror (`DocumentCarriedEmptyEndRegionReplaceTests`).
- **Captions and table cells are text regions**: a range inside one copies as its text (`captionTextFragment`, asked
  before the whole-unit expansion; `tableCellFragment`). `replacingRangeInsideOneContainer` splices into a caption as
  one-line runs (`oneLineRuns(of:)`) and into a cell as inline runs (`blockInlineRuns`; a medium, table or row adds
  nothing) (`DocumentTableCellFragmentTests`).
- `Document.expandingRangeOverNonTextBlocks` recurses into expanded quotes and details; the engine's copy/paste/drag and
  the article screen's AI selection call it, the legacy canvas does not.
- **Plain text never carries an atom's attachment character**: `runsPlainText` gives an emoji its `altText`, a button
  its label, a formula its LaTeX (used by `blockPlainText` / `tableFlattenedText`). A destination that holds runs (pull
  quote body, details title, caption) gets the fragment as runs (`blockInlineRuns`), never as plain text.
- **Checklist external share**: external RTF and plain reps prefix items with `⬜ ` / `✅ ` and import strips exactly
  one (optional VS16) via `ChecklistEmojiMarker` / `externalChecklistPlainText` (export: `RTFConversion.rtfData`, the
  attributed-string fallback, `pasteboardItem`; import: `RTFImport.flushParagraph`, `plainTextFragment`). The private
  fragment carries `checked`; `blockPlainText` / `text(in:)` stay marker-free. Accepted: a typed paragraph starting with
  a marker pastes back as a checklist.
- **RTF import** (`Serialization/RTFTokenizer.swift` → `RTFDocumentParser` in `RTFImport.swift`) rebuilds tables,
  headings, code, lists, links and emoji, because `NSAttributedString` flattens block structure. Heading by `\fsN/2`
  (≥23 H1, 20–22 H2, 18–19 H3), all-mono paragraph → code, best-effort lists (`\ilvl` / `\listtext`); unknown control
  words and destinations are skipped and it never crashes. Non-goals: colours, nested tables, Word list tables, images,
  codepages beyond cp1252.
  - A backslash before a literal CR/LF (how Cocoa apps write a break) is `\par`; raw CR/LF is ignored; `\line` is soft.
    Consecutive `\par`s emit empty paragraphs, the end-of-document flush does not (`RTFImportCorpusTests`).
  - `Document.strippingSelfReferentialLinks()` (both results of `fragment(fromRTF:)`; never the private fragment UTI)
    turns a link whose text is its own URL into plain text; the composer's markdown-on-paste applies the same rule
    host-side. `linkIsSelfReferential(text:url:)` duplicates `TextFormat`'s `chatInputLinkIsSelfReferential` on
    purpose: keep the two in step.
  - `RTFConversionTests` (export→import round-trip) is the parse-compat gate.

## Layout: the InstantPage V2 metrics contract

Both editors lay text out pixel-identically to the InstantPage V2 renderer, so what an author types reads like the sent
message. `RichTextRenderMetrics` (`Mapping/RichTextRenderMetrics.swift`) is host-supplied — per-style `(family, size,
weight, lineSpacingFactor)`, the rhythm scalars, `edgeSpacingReduction` — and owns V2's line formulas:

```
L(F)      = floor(F.ascender + F.descender)     // V2's "fontLineHeight": a REDUCED box, not lineHeight
S(F,f)    = floor(L · f)                        // V2's "fontLineSpacing"; f scales L, NOT the point size
pitch     = L + S                               // baseline-to-baseline advance; always integral
firstBaseline(F) = F.ascender
textHeight(F,f,n) = ceil(A + |D|) + (n−1)·pitch
```

- `StyleSheet` is a projection of it: headings 22 / 20 / 18 / 17 / 16 / 15 serif medium (see the note under
  `InstantPageTheme.headingTextAttributes`), body `metrics.body.size`. Hosts set `renderMetrics` (`applyRenderMetrics`).
  `.default` is the chat-message look; the composer assigns it (importing `InstantPageUI` would be a cycle; a test pins
  it equal to the adapted theme), the article editor uses `InstantPageTheme.chatMessageRenderMetrics()`.
- **The `ceil` is load-bearing**: blocks stack by adding sizes, so one fractional height shifts every later origin.
- **Not a `lineHeightMultiple`**: `StyleSheet.paragraphStyle` pins `minimumLineHeight == maximumLineHeight == pitch`
  (`lineSpacing` cannot go negative), so the caret spans the pitch; differential tables compare caret height with
  `differentialBodyLinePitch`, not stock's caret. A model-level `lineHeightMultiple` is user content and replaces the
  pin; never combine them.
- **Font families are load-bearing** (`FontResolver.font(spec:bold:italic:family:)` mirrors
  `InstantPageTextStyleStack`): Georgia for regular serif, New York for weighted serif (bold is a weight there), Menlo
  for monospace, system sans otherwise.
- **Body line spacing is one number shared with the bubble**, in `InstantPageTextCategories.chatMessage`'s `paragraph`
  entry, mirrored by `.default`. It is 0.95 (pitch 23 at 17pt), mid-interval in `[11/12, 1.0)` where every factor adds
  the same floored point; quotes use it at 15pt. Changing it moves the bubble, send preview, TextProcessing screen,
  both editor hosts and recorded goldens together.
- **Inter-block spacing is all in the rhythm table**; strings carry no paragraph spacing. A top-level paragraph gets
  `blockVerticalPadding + 2` = 6pt at each sequence edge (interior body paragraphs sit 1pt apart); a host trims
  `edgeSpacingReduction` rather than adding a knob (the bubble 1.0, the composer 6, `composerEdgeSpacingReduction`).
  Only the top-level sequence follows V2 rhythm (`BlockStack.spacingModel == .instantPageV2`); nested stacks keep
  `.containerInterior`, and author lines measure the raw line box.
- **A substituted face's LEADING is not clamped by the pin.** Faces CoreText substitutes for Arabic, Thai and Korean
  declare leading, which TextKit adds on top of the clamped box; V2 never reads per-run metrics. `RichTextFontLeading`
  is applied at all four layout-construction sites (`BlockLayoutTK1`, `BlockLayout`, `IDBlockLayout` and its empty-line
  prototype), and `CollapsedQuoteTextAttachment` drops `.usesFontLeading`. The advance is
  `box + max(lineSpacing, leading)`, so the legacy canvas's pin (`lineSpacing == 0`) is improved but not closed: open
  debt, pinned by `ScriptLineHeightTests`.
- **A custom emoji is drawn larger than its reservation and overhangs the line box by product decision** (24.29pt on a
  23pt body line, as the bubble draws it); don't clamp it. The grow is `EmojiTextAttachment.visibleBox`, applied in the
  placement both layout engines and `attachmentOverlayPlacement` read, never only in the emoji sync. It must not grow
  anything: `trailingLineBoxOverhang` gives back the pinned line's empty bottom band only when the trailing attachment
  fits (`RichTextInlineAttachmentFit.fitsPinnedLine` via `reservedBox(forFont:)`: room is `pinned − |descender|` above
  the baseline, `|descender|` below, so a height comparison is wrong; atoms never fit). At 17pt a custom emoji fits
  exactly; no inline button pill does (its line is ~0.5pt taller, as in the bubble). Only the composer's
  `height(forWidth:)` shows a wrong band.
- **Tests** (`//submodules/InstantPageUI:InstantPageUITests`): `RichTextV2MetricsParityTests` calls V2's
  `layoutTextItem` / `spacingBetweenBlocks` and pins formulas, faces, the gap table, both edges and `.default`;
  `RichTextV2FrameParityTests` pins composition via the DEBUG-only `RichTextEditorView.layoutSnapshot()`.

## The shared mapper (`AttributedStringMapper`)

Both editors render and read back runs through it.
- **Font family never round-trips**: TextKit's font fixing writes a substituted script font into storage, so
  `characterAttributes(from:)` must not capture `fontFamily`. Forward `font(for:)` still honours an imported one.
- **Model bold is the render-only key `.rtBold`**, not the rendered `.traitBold` (under "Bold Text" a substituted font
  is bold anyway): written by `attributes(for:)` / `toggleBold`, read by `characterAttributes` / `rangeIsBold`, never
  persisted. Marker-less storage (RTF import) falls back to `boldIsAmbient`: re-substitute the non-bold base for the run
  text with `CTFontCreateForString` and drop `ca.bold` if that is bold too (`RTLBoldReadbackTests`). Under Bold Text a
  toggle on a substituted script may not change on screen; the model is correct.
- **Every early return carries the spoiler marker itself, in both directions.** The mapper has FOUR early returns; the
  custom-emoji, button and formula arms each carry `ca.spoiler` (the formula arm returns before the general branch's
  `if ca.spoiler`). Dropping it loses a spoiler on every round trip.
- **Open:** its emoji boost is a flat `style == .body ? 4 : 0`, where V2 draws `A − D + 4 * pointSize / 17`. Left
  deliberately: aligning it moves the legacy canvas's emoji in every quote and heading.

### TECH DEBT — display-only font size is PINNED into runs on read-back
- A run's size derives from its paragraph style (heading1 24, body 17, table cells 15 via the `tableCells` mapper), but
  `characterAttributes(from:)` (`currentParagraph()` / `runs(from:)`) pins the rendered size into
  `CharacterAttributes.fontSize` (the 15pt cell round-trip needs it). A run moved into a paragraph of another style
  keeps its old size, which beats the style default.
- Merges are handled in Core's `ParagraphBlock.merging` (covering `applyReplaceOutcome` and `mergeParagraphsOutcome`):
  across differing styles appended runs lose `fontSize`, same-style merges keep it. Trap: iOS delivers Backspace at a
  paragraph's start as a RANGE `[prevEnd, thisStart]`; test the range form.
- Still unguarded: paste, RTF import, a format-menu style change, list/quote wraps and drag.
- The real fix: pin a size only when it differs from the style default (resolving the cell case against the
  destination), then delete the scattered `fontSize = nil` patches. Until then, any new path moving runs into a
  differently styled paragraph must strip their `fontSize`.

## Host-integration contracts

### The host decides when the caret is revealed
Neither editor scrolls itself to follow the caret: it records that a reveal is owed and performs it only inside a host
layout pass, against the geometry that pass applies.
- `update(size:insets:contentMargins:scrollIndicatorInsets:caretReveal:)` is the only place a caret is revealed; the
  four-argument spelling forwards `.none`.
- `ifNeeded` reveals when a text/selection change recorded a request (`tgid_caretRevealPending` in the engine,
  `isCaretRevealOwed` in legacy) or, engine only, when the whole applied geometry differs from what the last pass
  applied — never from the bounds, which hosts set before `update`. Size counts, not just insets: a width change
  re-wraps text, and the composer's insets are always zero. The request is cleared whatever the outcome. A pass with
  the same geometry reveals nothing, protecting a user's scroll
  (`EngineCaretRevealContractTests.test_aPassThatChangesNothingLeavesAUserScrollAlone`). Legacy has no geometry
  condition (`RichTextEditorView.revealCaret`) and can leave a caret behind a keyboard; kept narrower deliberately.
- `RichTextCaretRevealSolver` (Core, `CaretReveal.swift`) clamps; a caret on the first line reveals the content top, on
  the last line `contentSize.height`, in the middle the minimum scroll; containment is tested on caret plus that end.
  The engine supplies the ends from `-caretRectForPosition:`; legacy passes nil.
- The request is reported synchronously via `onCaretRevealNeeded` (the host re-applies its last geometry), never via
  `onChange`, whose selection half is async (a quick second arrow key would compute against an in-flight offset). One
  report per edit, at the edit's end; the engine's in-flight marker sits BELOW the `isApplyingHostDocument` guard (a
  `document` set never gets `textInputDidChange:`, so a mark above it sticks and swallows every later caret move).
- A reveal owed to a moved caret is written immediately; one owed to geometry rides the host's animation
  (`RichTextEditorAnimation`, mapped exhaustively from `ComponentTransition` / `ContainedViewLayoutTransition`;
  `.spring` is critically damped, not `kCAMediaTimingFunctionSpring`).
- A host that installs `onCaretRevealNeeded` and ignores it stops following the caret; DEBUG counts and logs it
  (`caretRevealsNeverAskedAbout`), not an assertion: the check is deferred and would fire in a later test.

### Selection wash and hosted views
The selection wash draws above text and hosted views in both editors (the engine brings `_UITextSelectionHighlightView`
to the front on every presentation update), so a hosted view (`MediaAtomHostView`, …) must not paint a selected state.
Don't move the wash behind text: table cells live in an `IDPlacedRunScrollView` and their selection would vanish, and a
second painter would have to reproduce UIKit's undocumented colour. Only non-interactive views (custom emoji, spoiler
dust) could go below a wash.

### The system edit menu needs `Window1.hitTest`
`UIEditMenuInteraction` hosts its menu in a top-level `_UIEditMenuContainerView`; `Window1.hitTest`
(`submodules/Display/Source/WindowContent.swift`) forwards only to allow-listed classes and must match `"EditMenu"`.

### Composer bridge and chat contracts
- `ComposerDocumentBridge` (`ChatRichTextEditorComposer`) and `EntityMessageBuilder` (`RichTextEditorMessageConversion`)
  convert the composer's `Document`. A custom emoji is a one-`U+FFFC` run with its text in `EmojiRef.altText`. Mentions
  and dates are `tg://user?id=` / `tg://timestamp?t=` markers in `CharacterAttributes.link`, no new attribute (keeps
  Core markdown-clean); all encoding and decoding is `TextFormat`'s `MentionDateMarkers.swift`, shared by every
  conversion. Accepted: a `textUrl` equal to a marker comes back as a mention/date. Code blocks go through
  `CodeBlockMarkers.swift` and send as `.Pre` (`//submodules/TextFormat:TextFormatTests`).
- **A set is reported back whenever the read-back differs from what was set**:
  `RichTextEditorChatInputNode.setInputContent` compares `currentInputContent().content` with its input and, if they
  differ, sends `chatInputTextNodeDidUpdateText` a turn later, so what Send reads is what is shown
  (`HarnessUnreportedSetNormalisationTests`). A new normalisation needs nothing here. Keep `document → ChatInputContent
  → document` stable, or it loops.
- Inserts on the user's behalf (emoji keyboard, Mention) go through `RichTextEditor.insertInlineRunsOnUsersBehalf(_:)`
  via `ChatRichTextInputNode.insertTextOnUsersBehalf` (default `false`), never the flat projection; the non-engine
  editor has no such verb and takes the chat's flat transform. The chat's ⌘B & co. run the engine editor's own commands
  (`ChatTextInputPanelNode.performNativeFormatShortcut`; ⇧⌘N is `clearInlineFormatting`), never an
  `NSAttributedString` rebuild.
- What the chat sends is decided in TextFormat (`chatComposerSendRoute`, `chatComposerTextMessages`), for
  `ChatControllerNode.sendCurrentMessage` and the harness's send oracle alike. The length the panel counts
  (`RichTextEditorChatInputNode.text`) is what the text route sends, code bodies, pull quotes and folded quotes included
  (`HarnessLengthCounterCodeBlockTests`).
- **A folded quote survives sending only as one paragraph.** Every client hop carries `collapsed`
  (`chatInputContent(fromDocument:)` / `(fromInstantPage:)`, `instantPage(from:)`, Postbox `qcol`, FlatBuffers
  `collapsed:OptionalBool`; `isEntityExpressible()` refuses it, so it takes the rich path), but a quote of 2+ blocks (an
  author line does not count) needs `pageBlockBlockquoteBlocks`, which has no flag, so it sends unfolded (documented at `InstantPage.swift`'s
  `apiInputBlock`). Don't fix it client-side (`pageBlockDetails` renders differently); it needs `collapsed:flags.0?true`
  server-side. `CollapsedQuoteWireProbeTests`' multi-block case fails once the schema has it.
- Add menu: in a table cell it narrows to Formula and Button (a block placed from a cell lands after the table,
  `planAtomUnitPlacement`); "list" stays disabled in tables. Button (`RichText_MenuInlineButton`) ▸ Inline
  (`RichText.MenuButtonInline`) authors the pill in `ButtonEditorScreen`, then calls `insertInlineButton(_:)`; Row is
  `insertButtonRow`; `makeSelectionInlineButton` stays for the composer's edit menu.

## Private UIKit names

### Private UIKit names are not in the binary
The InputDec engine is compiled into every build and reaches private UIKit by name. App Store review scans a binary's
strings, so **no private UIKit name the engine crosses may appear in the binary as text.**
- **One table.** Each name is a line of `Scripts/private-runtime-names.txt`; `Scripts/generate-private-runtime-names.py`
  generates `RichTextInputDecObjC/include/TGPrivateRuntimeNames.h` (XOR 0x5A per byte, exposed as `TGPN_<name>()`, `:`
  spelled `_`). Never hand-edit the header. A selector is `NSSelectorFromString(TGPN_x())`.
- **A callback is compiled under a neutral name and added under the private one**: the method is `tgpn_<name>` (or an
  `id_` method), installed from `+initialize` by `TGPrivateInstallMethodAliases` (`TGPrivateMethodAliases.h`) with
  `class_addMethod`, never `class_replaceMethod` (that clobbers subclasses defining the private name). A subclass
  overriding a neutral method installs the table again from its own `+initialize` (`TGIDObservingBlockTextView`), or
  UIKit reaches the superclass's version.
- **`class_getInstanceMethod` does not run `+initialize`**: send `[cls class]` before any introspection.
- **The table holds names that cross the boundary.** An engine member that merely shares a private name is renamed
  `id_…`. Check first: UIKit's `-[_UITextLayoutControllerBase textInputController]` sends `textInputController` to the
  engine's connection object, so that renamed property is aliased back.
- **The embedded contract tables are encoded too** (`Generated/TGRichTextInputDecContractData.m`,
  `RichTextInputDecUpstream/Generated/RichTextInputDecUpstreamPristineManifest.m`), decoded by
  `TGPrivateRuntimeDataDecode`; regenerate with `--encode-bytes <plain file>`. `VENDOR.md` pins the file and decoded
  digests; `VendorSnapshotIntegrityTests` checks the decoded bytes.
- **Guards.** `PrivateRuntimeNamesTests` (Core) fails when the header and list disagree, and when a shipping source
  spells a listed name as a literal (or inside one, names of 8+ characters), `@selector`, `@objc(…)`, an Objective-C
  method or accessor, or a Swift function's base name in a file using `#function` (hence `id_selectWord()`); comments
  are ignored. The binary check is `Scripts/scan-private-runtime-names.py` on the release `TelegramUIFramework` from
  the `.ipa`.
- **Expected release-scan hits** (anything else is a leak): in `RichTextEditorUIKit` only, the two text-checking
  selectors below plus `selectWord` / `selectionChanged` in `__swift5_reflstr` (enum cases and a field, not selectors).
  `_textInputTraits`, `textInputTraits`, `activateSelection`, `selectionContainerView` are other modules' own names.
- **Known residual: the legacy canvas's text-checking client** (`DocumentCanvasView+NativeTextCheckingClient.swift`)
  answers `UITextCheckingController` under real names. The two the engine also crosses
  (`replaceRange:withAnnotatedString:relativeReplacementRange:`, `annotatedSubstringForRange:`) are allowlisted in that
  file only, and the allowance fails if it goes stale; `removeAnnotation:forRange:` and `validAnnotations` are not in
  the table, so no guard looks for them. Moving the client to the alias mechanism closes this.
- A new or changed header needs the importing targets' `RichTextInputDec*.pcm` deleted (see "Verification traps").

## Known gaps

- **V2 parity not yet verified** (no V2 reference): list-marker geometry, table cell insets, media captions/credits,
  details chrome, and inline-attachment line inflation (V2 grows `lineAscent` for formulas/buttons and adds
  `extraDescent` for tall inline images).
- Composer vs sent bubble and article editor vs sent message are not yet compared side by side on screen.
