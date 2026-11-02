# RichTextEditorUIKit: the legacy (canvas) editor

`RichTextEditorView` (the façade hosts use) over `DocumentCanvasView` (a custom `UITextInput` canvas), plus UIKit
layout, mapping and styling the engine editor also uses. Read the package guide (`RichTextEditor/CLAUDE.md`) first.
Siblings: `InputBackend/CLAUDE.md` (input-backend adapter), `Sources/RichTextEngineEditor/CLAUDE.md` (engine editor).

## Map
- Façade `RichTextEditorView.swift` (+`ComposerHost`, +`DebugOverlay`, +`LayoutSnapshot`); knobs `CodeStyle`,
  `QuoteStyle`, `PullQuoteStyle`, `MediaBlockStyle`, `Theme/RichTextEditorTheme.swift`.
- `Canvas/DocumentCanvasView.swift` plus `DocumentCanvasView+<Concern>.swift` extensions (`+UITextInput`, `+Editing`,
  `+Navigation`, `+Interaction`, `+Clipboard`, …).
- Boxes (`CanvasBlock`): `BlockBox` (paragraph; a quote is `style == .quote`), `MediaBlockBox`, `TableBlockBox`
  (`[[BlockStack]]` cells), `CodeBlockBox`, `BlockQuoteBox`, `PullQuoteBox`, `DetailsBox`, `ButtonRowBox`,
  `CollapsedQuoteBox`. `BlockStack` backs the root and every cell (one edit engine for both); `LeafTextRegion`.
- `Layout/` (`BlockLayoutEngine` seam, `BlockLayout` TK2, `BlockLayoutTK1`, `RichTextFontLeading`); `Mapping/`
  (contract: package guide); chrome views (`CaretView`, `TransientCaretView`, `SelectionHighlightView`,
  `SelectionHandleView`, `BlockBackingView`, `GripYieldingScrollView`); `NativeTextChecking.swift`,
  `RTFConversion.swift`.

## Layout

### Dual layout-engine back-port
`protocol BlockLayoutEngine` (one method per call) hides TextKit: `BlockLayout` (TK2) on iOS 16+, `BlockLayoutTK1` on
iOS 13–15, chosen by `makeBlockLayout(...)`. `BlockLayoutBackend.forceTextKit1` (tests) is compiled `#if DEBUG &&
false`: off even in debug until you flip the `&& false`. `+EditMenu` falls back from `UIEditMenuInteraction` to
`UIMenuController` (custom items become flat `UIMenuItem`s).
- The target is `@available(iOS 13.0, *)`; only real APIs keep a higher floor: TK2 and `UIEditMenuInteraction` 16, the
  loupe (`UITextLoupeSession`) and `inlinePredictionType` 17, Translate 17.4, `isEditable` 18. App consumers
  (`RichTextEditorChatInputNode`, `RichTextAttachmentScreen`, `StandaloneInstantPageImageView`) are iOS 13 too.
- TK1 deliberately lacks spoiler text hiding, the loupe and inline predictions.

### Layout convention
The parent drives layout (`performLayout` → `canvas.layoutContent()`). For a content-height change a view never
`setNeedsLayout()`s itself; it calls `notifyContentSizeChanged()` (→ `onContentSizeChange` → host `onChange` →
`update`). `editing { }`, the IME marked-text commit/update, `setBlocks` and the undo block do only that; the façade's
`onContentSizeChange` is a relay. Where the façade needs geometry synchronously it calls `performLayout(size:
bounds.size)` (`revealCaret`, the `document` setter). Canvas-direct tests reading post-edit geometry install
`simulateParentLayout()`. Outside the convention (no height effect): `setNeedsDisplay`, `syncSpoilers`' reveal relayout,
parent→child layout of backing views.

### Baselines, heights and gaps
- `BlockLayoutEngine.baselineDelta` (engines supply `rawFirstBaselineFromTop`) MEASURES TextKit's baseline (its
  placement is undocumented) and corrects it to `F.ascender` at glyph draw, `attachmentBox` and
  `firstLineBaselineFromTop`; caret/selection rects keep the full box. Never the `baselineOffset` attribute (a real
  sub/superscript field; it would round-trip), never the engine bridge's re-pin as well (double correction); legacy has
  no whole-point snapping. TK1 shifts manually (`shouldSetLineFragmentRect…` is not called under a TK2-backed
  `NSLayoutManager`). Empty-line fallbacks (`listMarkerBaselineFromTop`, `placeholderDraw`) use `firstBaselineFromTop`
  unshifted. `LineHeightCenteringTests`.
- Heights use `correctedBoundingHeight` (on the seam), never `boundingHeight`.
- Rhythm: `richTextSpacingBetweenBlocks` (`BlockSpacing.swift`) transcribes V2's `spacingBetweenBlocks`; rule ORDER
  matters (arms overlap). `CanvasBlock.spacingKind` has no default, so a new block type must choose its rhythm. Adjacent
  list items collapse into one virtual `.list` block (as `buildListBlocks`).
- A gap is ONE quantity: owned by the lower neighbour if it can, else the paragraph above, else bare. A framed atom
  (table/code/quote/details) fills its frame and never owns one, or the `+Navigation` escape probe (`owner.frame.minY −
  step/2`) hits nothing and the caret cannot leave a table (`CanvasTableNavTests`). A tap in a gap goes to the block
  below.
- Never sum box heights: bare gaps belong to no frame and live only in `BlockStack.bareGapAbove(_:_:)` /
  `bareTrailingGap(_:)`, read by `layout` and `currentHeight` (→ `intrinsicContentSize` → `contentSize`). Every height
  path calls `applyRootSpacingConfig()` itself. `RichTextEditorViewTests.test_document*_scrollContentCoversEveryBlock`.
- `facingInset`: adjacent `BlockBox`es are `bottomInset + topInset` apart; list items stack tight only if both share
  quote-ness. Between adjacent non-`BlockBox` framed atoms (`isFramedAtom`: code, table, collapsed quote; an expanded
  quote is a `BlockBox`), `layout` and `measuredHeight` in lockstep add `verticalInsetBase + framedNeighborMargin`,
  owned by no block. `QuoteVerticalInsetTests`.

### Code blocks are edge-to-edge plain bands
No accent bar, tint or radius: a plain `theme.codeBackground` band across the container's interior; the text (bold
language line above) sits at a paragraph's x for that nesting level (the side padding IS the paragraph inset).
- `CodeBlockBox` paints its own fill; never route code through the quote underlay (it walks top-level boxes only).
- `blockViewFrame` outsets `frame` by `horizontalBleed` (geometric `minXSide`, as `InstantPageV2ChildBleed`), and
  `BlockBackingView` clips to it. `BlockStack.layout(origin:width:codeBleed:)` sets it per layout: root → canvas edge
  (or `CodeStyle.horizontalBleed`), block quote → inside the bar, details/cells/list items → none.
- A compact host indents instead: the composer sets `CodeStyle(horizontalBleed: 0, horizontalInset: 8, cornerRadius:
  4)`. Never both non-zero; the inset also narrows the measure (`setWidth` / `measuredHeight(forWidth:)` / init layout
  subtract it twice). Deliberately not WYSIWYG (the composer also zeroes `mediaBlockStyle.horizontalBleed`).
- Padding: `CodeStyle` + `StyleSheet.codeVerticalInset` / `codeLanguageSpacing`; unset fields resolve against
  `RichTextRenderMetrics.code` (9/9 interior, 6pt vertical). `applyRenderMetrics` re-resolves them and the code font
  (`metrics.code` fallback), or setting `renderMetrics` after `codeStyle` leaves stale values.

### Render-only attributes, the `U+FFFC` atom, repainting
- Inline code, link styling, the prediction ghost, spoiler-hide and emoji are rendering attributes or private markers
  (`.rtInlineCode`, `.rtSpoiler`, `.link`), stripped on read-back (`characterAttributes(from:)`, `currentBlock()`). The
  two `.foregroundColor` users (ghost, spoiler hide) remove only their own ranges.
- `applyDisplayOverride` (table column alignment, header bold) must be idempotent: re-assigning
  `layout.attributedString` resets spoiler-hide ranges → infinite `layoutIfNeeded` loop. Assign only on change.
- Emoji and the spoiler atom are one `U+FFFC` with their ref in `CharacterAttributes` (one UTF-16 position; the position
  model and tokenizer are untouched). Host views are pooled by `instanceID`, hosted in the canvas overlay or a table's
  content view (riding H-scroll), and culled.
- `bindRealizedView` repaints on `view.box !== box`, not only `renderSignature`: a split keeps the `BlockID` but makes a
  new `BlockBox` whose `renderVersion` restarts at 0 (a same-height half would keep its old bitmap).

## Document structure

### Leaf regions
`leafRegions()` / `allLeafRegions()` (recursing into cells) drive selection, caret, text and draw, in DOCUMENT order
(navigation indexes them), so "the box's primary text" is `textStart`, never `.first`. The view class and `+UITextInput`
land together (`UITextInputStringTokenizer(textInput: self)` needs the conformance).

### Code blocks and the language line
- `CodeBlockBox`: a monospace layout plus the language line as a LEADING second leaf region (`languageLayout`,
  `TextNodeRef.codeLanguage`); `currentCode()` reads plain text back.
- `textStart`/`textLength`/`textRef` mean the CODE region, and `activeStack` resolves a box by that PRIMARY region
  (`leafRegions().first(where: { $0.globalStart == b.textStart })`, fallback refusing the other regions), or a
  language-line caret applies its offset to the code layout (`insertCodeBlockNewline` splices wrongly). `pos >=
  textStart && pos <= textStart + textLength` is NOT equivalent: containers report a degenerate `textStart ==
  nodeStart`.
- Backspace in a language (or author) line arrives as a RANGE with no `activeStack`: `applySelectionReplaceOutcome` asks
  `regionIsOffTheTopLevelEngine(_:)` (exhaustive over `TextNodeRef`, no `default`) → `applyLeafReplaceOutcome`.
- `sameOwningStack` uses `owningStack(at:)` (which stack, not box), or Select All over a pull quote (ending on its empty
  author) stops toggling: another `resolveBox`-family patch (debt below).
- Code text: Enter inserts a newline (`insertCodeBlockNewline()`). Double Return (`codeBlockDoubleReturnExit`): trailing
  blank line → body after (`exitCodeBlockToBodyParagraph`); first blank line, local 0 or 1 → body before
  (`exitCodeBlockToBodyParagraphBefore`); wholly empty → un-code (`uncodeEmptyCodeBlock`); middle → newline. Backspace
  in an empty block un-codes. In `applyReplaceOutcome` a code endpoint acts like media.
- Language line: Return moves to the code start; Backspace at its start un-makes a wholly empty block or steps out;
  formats, emoji and links are inert.
- Text services are off in both regions (`caretIsInCodeRegion`). Adding a `UITextInputTraits` member (as
  `autocapitalizationType`) moves the differential harness's census tests. UIKit caches traits, so `refreshSelectionUI`
  reloads them on entering/leaving code.
- `makeCodeBlock()` (`+ParagraphFormat`) joins the touched top-level paragraphs into one code block (refusing a
  selection over a non-text block) and splits back on `"\n"`.

### Tables
- Cells render body/quote at 15pt (headings keep sizes; explicit `fontSize` wins) via `tableCellVariant()`
  (`StyleSheet.tableCells`), one mapper per `TableBlockBox`. Split/merge replacements inherit it (`CanvasBlock.mapper`,
  passed by `applyReplaceOutcome`, `insertParagraphBreak`, `mergeParagraphsOutcome`); empty-cell typing
  (`typingAttributeDict`) takes the owning box's mapper via `activeStack`.
- Cell padding is a cell metric (`cellVerticalPadding = 14`, `cellPadding` 6); cell stacks have `verticalInsetBase = 0`.
- `deleteTable()`: one undo step, joins neighbours, caret to the successor (or a fresh paragraph).
- Backspace on a structural row/column selection (`deleteTableStructuralSelection`, first in `deleteBackward`) →
  `deleteTableRow` / `deleteTableColumn`; ALL rows or columns → an empty body paragraph in place; the selection clears.

### Media blocks
- Backspace replaces the media IN PLACE with an empty body paragraph (`replaceMediaWithEmptyParagraphOutcome(at:)`) on a
  tap-selected media (`imageSelection == id`), at caption start (caption discarded), on a selection equal to the node
  span (`from == nodeStart && to == coverableContentEnd`), and on the OS object-replacement range after a tap. That last
  is compiler-invisible: the `selectedTextRange` setter clears `imageSelection`, then iOS sets a range anchored in the
  PRECEDING block, so the setter stashes `imageObjectDeletePending`, which `deleteBackward` consumes first when the
  selection touches the gap (`insertText` or a non-matching `deleteBackward` clears it).
- No media delete leaves zero blocks. Menu Delete: `MediaControlRequest.delete` → `deleteMediaBlock(id:)`, or
  `deleteMediaItem(blockID:itemIndex:)` for one album cell.
- Select All + Backspace drops a wholly covered media (`lo <= nodeStart && hi >= coverableContentEnd`) and truncates a
  partly covered caption (code endpoints alike); the merged paragraph takes the start's style, else the end's, else
  body.
- `insertTable`/`insertMedia`: an EMPTY caret paragraph is replaced (checked first: it is both `local == 0` and `==
  textLength`), an interior caret splits, start → before, end → after; never a caption or code. A lone
  `[table]`/`[media]` document is valid.
- Captionless (audio, document): `textLength 0`, `textStart == nodeStart`, `leafRegions() == []` (routed via
  `mediaBox(atGap:)` / `isGapPosition`), `closestPosition → nodeStart`, no caption or Enter; height `verticalInset +
  rowHeight + verticalInset`, `audioRowHeight` 44 / `documentRowHeight` 52 equal to `InstantPageV2Layout`'s frames;
  `insertMedia` puts the caret in a following body paragraph. Coverage: `coverableContentEnd(_:)` (`nodeStart + 1`
  captionless, else `textStart + textLength`).
- `toggleMediaSpoiler(blockID:itemIndex:)` rebuilds in place (one step; an in-range index flips that cell, else the
  block to `!first.isSpoiler`), from `imageSelectionMenu` and the album "•••" menu
  (`MediaControlRequest.toggleSpoiler`). The editor's cover never reveals (`MediaDustNode`, `revealOnTap = false`);
  `isSpoiler` is in `syncMediaItemViews`' signature. Albums: `RichTextEditorMediaView/CLAUDE.md`.

### Backspace at an atom's gap, and after an atom
- At a media's or collapsed quote's leading gap (`nodeStart`; `mediaBox(atGap:)` / `collapsedQuoteBox(atGap:)`) a plain
  caret acts on the PREVIOUS block: its last grapheme goes, or the block if empty (caret stays); a non-text previous
  atom and a leading media are no-ops; a leading collapsed quote expands. iOS sends a RANGE
  `[prevTextPosition(before: gap), gap]`: media collapse it to a gap caret; the collapsed-quote handler fires when
  `selTo` is the gap AND `selFrom >= prevTextPosition(before: selTo)`, NOT on `selFrom == selTo`.
  `CanvasImageEditTests` (`test_backspaceAtGap_*`).
- At local 0 of the paragraph after a non-text atom (`isNonParagraphAtom(_:)`: media, table, code) nothing merges into
  the atom: an empty paragraph is removed (`removeBlockOutcome(at:parkingCaretAt:)`), a non-empty one kept, and the
  caret steps to the atom's nearest text slot (`prevTextPosition`: caption end, last cell end, code end), never its node
  start.

### Quotes
A quote is a `BlockBox` with `style == .quote`. At top level (in a cell, cell behaviour wins):
- Backspace in an EMPTY quote un-quotes (else an empty first quote is undeletable).
- A tap below the last block (`+Interaction`) appends an empty body paragraph (`insertEmptyBodyParagraph(at:)`) unless
  one is already last; gated on `tapBelowAddsTrailingParagraph`.
- Double Return on an empty quote line: run's last line → body after; first → before (also from the content start with
  an empty line above, `quoteDoubleReturnExitIndex`); wholly empty run → un-quote; middle → split (`emptyQuoteIsRunEdge`
  → `exitQuoteToBodyParagraph`). No Shift+Return exit.
- Quote and list coexist (`setParagraphStyle`/`setList` never clear each other). `quoteIndent` stacks on the marker
  inset (`StyleSheet.paragraphStyle`) and the marker/checkbox columns (`listMarkerDraw`, `checklistMarkerCanvasRect`)
  add `quoteLeadingInset`; keep it stacking. Double Return ends the list first: the empty-item branch keeps `.quote` and
  `quoteDoubleReturnExitIndex` is nil while the line has a `listMembership` (`DoubleReturnExitTests`). Backspace on an
  empty quoted item clears both (`CanvasQuoteEditTests`).
- `QuoteStyle` is per host: `RichTextEditorView.quoteStyle` → `applyQuoteStyle` (rebuilds the stylesheet).

### Collapsed quotes
Core `Block.collapsedQuote`, shaped like audio media (`mediaBlock` + `mediaAtom`, nodeSize 3; the leading gap is the
caret slot). `CollapsedQuoteBox` draws the preview and a corner expand glyph. `collapseQuoteRun(atIndex:)` /
`expandCollapsedQuote(atIndex:)` move only a caret that was INSIDE the run. Composer: one flat character +
`ChatTextInputTextQuoteAttribute(isCollapsed: true)` (`ComposerDocumentBridge`).
- No leaf region; its caret draws at the leading edge and a range covers it (`coverableContentEnd == nodeStart + 1`).
  Tap body → gap caret; tap the glyph → expand.
- Horizontal navigation stops on the gap (`atomGap`; `snapToRenderable` accepts it). Vertical navigation MUST step
  through it: `verticalPosition`'s `collapsedQuoteBox(atGap:)` branch (Down → next block, Up → end of the one above);
  without it the OS falls back to its own line geometry and skips the atom.

### Lists and checklists
- Backspace at `local == 0` of a list item (collapsed caret, empty or not): nested → `outdent()`; top-level → body
  paragraph keeping its text (later items renumber); quoted → body. Right after `resolveBox`, gated on `listMembership
  != nil`, before merge and empty-quote. `CanvasStructuralTests`.
- Checklist: Core `ListMarker.checklist` + `checked: Bool?` (`setList(.checklist)` seeds `false`, re-applying keeps it).
  The box is a host view (no `CheckNode` here): `registerChecklistMarkerViewProvider(_: (checked, size) -> (UIView &
  RichTextChecklistMarkerView)?)`, coloured from `theme.list.itemCheckColors`. Pooled and culled in the gutter
  (`+ChecklistMarkers`); `BlockBox.hostsChecklistCheckbox` (stamped in `stampListMarkers`, part of `renderSignature` so
  a late provider repaints) suppresses the glyph. A marker tap toggles as ONE undo step (`toggleChecklistItem`,
  caret-neutral).
- Geometry (`checklistMarkerCanvasRect()`): `checklistMarkerSize(for:)` (`capHeight.rounded()`) × 1.4
  (`checklistMarkerScale`), bottom on the baseline, left at the gutter, pixel-floored; the text inset reserves it.
- Return continues unchecked, Return on an empty item exits, indent/outdent keep `checked`; no strikethrough.
  Round-trip: `DocumentChatInputContentBridge` and both `Document → InstantPage` builders (`docs/richtext-composer.md`).

## Input and selection

### One selection, one `UITextInput`
- Selection is ONE `(anchor, head)` range on the global axis (structural slots included), clamped per block; per-block
  `enumerateTextSegments` rects union into the highlight. Endpoints resolve through `activeStack` / `allLeafRegions()`,
  checked against Core's `PositionResolver`. Geometry (views, scroll, culling) never feeds back into the model.
- The canvas is the SOLE `UITextInput`; blocks draw in pooled non-focusable `BlockBackingView`s.
  `caretRect`/`closestPosition`/`selectionRects`/`contentSize` come from ALL box frames, never realized views.
- All own-drawn: no persistent `UITextSelectionDisplayInteraction` (except the loupe's per drag), no canvas `draw(_:)`
  (one layer can't back a tall document). Caret, wash and handles are on-top views, in a table's scrolling content view
  for cell endpoints. Don't un-clamp a table's `contentOffsetX` for the OS selection UI: the OS then fights the caret.
- `caretRect(for:)` is OS navigation geometry, real even while the caret is hidden. Vertical arrows come via
  `position(from:in:direction:)` + the `selectedTextRange` setter (arrow `keyCommands` never fire); results are
  `snapToRenderable`'d.

### Selection notifications and the caret reveal
- Every `anchor`/`head` change brackets `inputDelegate.selectionWillChange/DidChange`, or the next arrow starts from a
  stale `selectedTextRange`. `editing { }` and the undo closure bracket BOTH `text*` and `selection*` (without the
  latter, programmatic emoji inserts leave the caret behind).
- Every caret-moving op fires `onSelectionChange`, gesture range selections too (`applySelection`); the composer tracks
  the selection through it (else the next `setInputContent` collapses a double-tap selection). Over-firing is safe.
- It never scrolls: the façade sets `isCaretRevealOwed` and calls `onCaretRevealNeeded`; the host's
  `update(…caretReveal:)` runs `revealCaret` (package guide, "The host decides when the caret is revealed"). The
  content-size relay asks only when no selection report follows (`selectionChangeFollowsContentSizeChange`). Legacy's
  reveal ignores the animation and sets `contentOffset` at once (a fast second arrow would compute against an in-flight
  offset), lays out first unless `layoutIsCurrent`, tracks a >64pt (image-gap) caret as a 24pt top band, pads `min(12,
  (visible − caret)/2)` (`ShortFieldCaretRevealTests`) and passes nil ends (minimum scroll). `scrollCaretIntoView` is
  ask-then-reveal (the input-backend client's).
- A gesture selection brackets ONCE (`applySelection`); pending autocorrect commits on it. No fake→real "jiggle"
  bracket: each `selectionDidChange` costs the keyboard's synchronous `updateForChangedSelection` (~25 ms).
  `SelectionInteractionTests.test_applySelection_firesASingleSelectionBracket_noAutocorrectJiggle`.

### Highlight and edit-menu dismissal
- UITextView-style wash: `selectionFillRects(start:end:fillTrailingLine:)` (only in `drawNonTableSelectionHighlight`)
  extends a line covered to its end to the trailing edge, one covered from its start to x=0, a spanned empty line full
  width. Glyph-hugging `selectionRects` still feed the OS, menu position, spoiler dust, marked text and table cells.
- `UIEditMenuInteraction` doesn't self-dismiss: `dismissEditMenuForSelectionOrTextChange()` runs from `setCaret` /
  `setSelectionHead` / `setSelectionAnchor`, the `selectedTextRange` setter and `editing { }` UNCONDITIONALLY
  (`editMenuVisible` is already false at touch-down). Flows that present after selecting use `applySelection` (outside
  the hook), then `presentEditMenu()`.

### Grapheme safety
- `closestOffset(toPoint:)` (both engines) never returns an offset inside a composed sequence, or the next edit leaves a
  stray code unit.
- `applySelectionReplaceOutcome`, the chokepoint for every selection-replacing edit, first runs
  `rangeExpandedToGraphemeBoundaries`: the composer's Backspace is a RANGE that can halve a surrogate pair.
- `deleteBackward` (top-level and in-cell) removes `graphemeClusterLengthBeforeCaret(global:)` units, from the region's
  own string (a grapheme never spans regions).

### Left/right arrow navigation moves a whole grapheme, not one UTF-16 unit
The OS drives horizontal arrows via `position(from:in:direction:)` → `nextTextPosition`/`prevTextPosition`, which step
by `rangeOfComposedCharacterSequence` (a one-unit step lands mid-surrogate and looks stuck). Its
`position(from:offset:±1)` probes are not grapheme-aware but don't move the caret. Open: shift+arrow may need the same.

### `text(in:)` emits `"\n"` at every top-level paragraph boundary
It behaves like a `UITextView` over a `"\n"`-joined string: Hangul and other CJK keyboards compose via `insertText` + a
ranged `selectedTextRange` + `deleteBackward`, reading `text(in:)`, and without the separator recompose across the
break. One `"\n"` per crossed boundary, even for a range wholly inside the gap; cell boundaries stay glued
(`CanvasCrossCellEditTests`). `CanvasTextInputTests.test_textInRange_*`.

### Gestures
- Gate-only arbitration: handle/knob pan vs scroll is decided in `gestureRecognizerShouldBegin`, never
  `require(toFail:)` or forced simultaneity. The tap fires at once (multi-tap escalation in `handleTap`); the host
  scroll view sets `delaysContentTouches = false`.
- Both scroll views (each table's, and `RichTextEditorView.scrollView`) are `GripYieldingScrollView`s, declining near a
  grip (`canvas.isSelectionDragTouch`, seam `yieldsToGrip(at:)`), or a vertical knob pull scrolls the document.
- `tapOutcome`'s "inside the selection" is VISUAL (`selectionRects().contains`): a tap beside a selection collapses it.
  A collapsed caret keeps the offset test (`resolved == head`).
- A FOCUSING tap only places the caret (`menuToggleAction`'s `wasFirstResponder` gate): `didJustBecomeFirstResponder`
  (set in `becomeFirstResponder`, consumed by `performSingleTap`), not `isFirstResponder`, because the composer focuses
  on touch-DOWN (`ensureFocusedOnTap`).
- `DocumentTokenizer` finds word/paragraph boundaries per leaf region (the stock tokenizer glues regions).
- Marked text is storage-backed (body paragraphs only), outside `editing{}`, one undo step per composition. A system
  inline prediction (`setMarkedText` with `sel:{0,0}`) is dismissed, never committed, by the finalize chokepoints.

### Selection-handle drag
- The knob is drawn 2·`knobRadius` past the caret (`SelectionHandleView.boundingFrame`), so `.began` captures
  `selectionDragGrabOffset = caretCenter(endpoint) − touch` (`captureSelectionDragOffset`) and every map (`.changed`,
  auto-scroll) is `closestGlobalPosition(to: touch + offset)` (`selectionDragPosition(forTouch:)`): no jump.
- `SelectionHandleView` is hit-testable with NO recognizers: `point(inside:)` =
  `caretLocalRect.insetBy(-dragHitTolerance)` (±22pt, as `isSelectionDragTouch`, fed by `setCaretLocalRect` in
  `positionHandle`); the drag stays the canvas pan. As hit-test view (Display walks up from it) it lets the host set
  Display's gesture flags via `RichTextEditorView.configureSelectionHandleView: ((UIView) -> Void)?`, once per handle
  view: `disablesInteractiveTransitionGestureRecognizer` (the load-bearing one), `disablesInteractiveModalDismiss`,
  `disablesInteractiveKeyboardGestureRecognizer`. Keep it hit-testable with its hit area on the caret, or Display never
  consults them.
- The composer uses only this per-knob hook (editor-wide flags break its scrolling); `RichTextAttachmentScreen` adds the
  three flags editor-wide.

### Floating cursor
`+FloatingCursor`. `point` is an ABSOLUTE canvas coordinate (no delta, no clamp). The `selectedTextRange` setter ignores
the ranges iOS pushes mid-gesture (`floatingCursorActive`), which would turn the move into a selection. A bright
`TransientCaretView` follows raw `point.x`; `CaretView` waits at alpha 0.4 on the snapped position (full alpha + blink
on end); both host via `caretHostPlacement(forGlobal:)` / `hostOverlay(_:at:)` (riding cell scroll). Updates bracket the
input delegate but skip the host report; `onSelectionChange` fires once at the end. `cancelFloatingCursor` invalidates
the self-retaining auto-scroll `CADisplayLink`.

### Loupe
- The loupe grows from the caret only for a system `cursorView` of a `UITextSelectionDisplayInteraction` (with any own
  view, even a `UITextCursorView`, it grows at the touch), so `handleLongPress` creates a FRESH interaction per drag,
  passes its `cursorView` as `fromSelectionWidgetView`, and removes it on release. A persistent one goes stale under
  view virtualization and crashes (use-after-free in `-[UITextSelectionDisplayInteraction setActivated:]`). Its chrome
  sits in `selectionChromeContainer`, which block-view reloads never free.
- Mid-drag `TransientCaretView` follows the finger; `CaretView` shadows the snapped caret in
  `RichTextEditorTheme.shadowCursor` (HSL gray: HSB `saturation: 0` whitens a bright accent; restored on `.ended`), only
  ≥ `loupeShadowMinSeparation` (14pt) away; the borrowed system cursor is `alpha 0.01`. On release the widget snaps to
  the final caret before `invalidate()`.
- The drag reports once: per frame `setCaret(global:reportSelectionChange: false)`, `.ended` re-runs `setCaret`,
  `.cancelled`/`.failed` call `onSelectionChange`; the input-delegate bracket is coalesced
  (`beginCoalescedSelectionDrag()` / `endCoalescedSelectionDrag()`) so suggestions don't churn; the caret reveal waits
  for the end too. `SelectionInteractionTests` (`test_loupe*`).
- `LocationAdaptiveLongPressGestureRecognizer` picks `minimumPressDuration` per touch (`loupeDelayNearCursor` within
  `loupeNearCursorRadius`, else `loupeDelayFarFromCursor`); never 0 (tap and long-press share touches).

## Editing
- "Type something…" shows only on the LAST block (`BlockBox.isLastBlock`, stamped in `stampListMarkers`).
- Return in a heading (`insertParagraphBreak`) makes the tail body, even at offset 0, and clears its runs' pinned
  `fontSize` (a split is not a `merging` call).
- `insertInlineButton` types the label (one space if empty), selects it, then `makeSelectionInlineButton` +
  `replaceInlineButton`: three undo steps (debt).
- Open: inline toggles at a collapsed caret show the inherited state but don't affect the next character; Format ▸ Date
  is a no-op (dates only round-trip, as link markers).

## Writing direction and text checking

### RTL / writing direction
- `BlockLayoutEngine.baseDirection(atOffset:)` = `CTRunGetStatus(firstRun).contains(.rightToLeft)`, the first-run rule
  of `TextNode` / `InstantPageV2Layout`, so the editor agrees with the sent message; nil when empty.
- `+WritingDirection`: `resolvedDirection(forGlobal:)` = override → content → `typingWritingDirection` (= override →
  keyboard `Locale.characterDirection` → `effectiveUserInterfaceLayoutDirection`). `applyWritingDirectionOverride` sets
  `layoutDirectionModel` and `mapper.baseWritingDirection` (`.auto` → `.natural`) for `StyleSheet.paragraphStyle`.
  `setBaseWritingDirection` is a deliberate no-op: the document override is the only manual control.
- `selectionFillRects(…isRTL:)` flips edges for RTL lines.
- Empty paragraphs: `refreshEmptyBoxWritingDirections()` sets `BlockBox.writingDirectionOverride` from
  `typingWritingDirection` (→ `emptyTextCaretDirection`, caret at `x ≈ containerWidth − 2`), on `reload`,
  `becomeFirstResponder`, `currentInputModeDidChangeNotification` and every edit (`RTLEmptyLineCaretTests`).
- TK2 `caretRect(atOffset:)` uses the `.selection` segment, not `.standard` (which misses the RTL alignment shift;
  `RTLCaretTrackingTests`). TK1 uses the direction-correct edge of the glyph's ADVANCE box (before a character `minX`
  LTR / `maxX` RTL, at the end the reverse), direction from `resolvedCaretDirection()` cached per `renderVersion`
  (`closestOffset` calls `caretRect` per offset); `TK1RTLCaretTests` pins it to TK2.
- Host: `layoutDirectionOverride` (round-trips through `document`); the attachment screen has Auto/LTR/RTL; the composer
  auto-detects.
- Limitations: mixed-direction paragraphs follow their base direction; gutter ornaments and table columns aren't
  mirrored; no composer override UI; no mapping to `InstantPage.rtl`.

### Text checking (native `UITextCheckingController`)
iOS's private `UITextCheckingController`, with the canvas as client, supplies spelling/grammar flags, tap-to-fix and
autocorrect-revert; we draw the underlines. Default on (`isSpellCheckingEnabled`); display-only.
- Private API ships in release by owner decision (App Store 2.5.1 risk). `NSClassFromString`; unresolved → off (no
  fallback). Dispatch only in `NativeTextChecking.swift`; names we send are XOR-0x5A (`ObfuscatedStrings`). The client
  callbacks keep their real `@objc` names: the residual in the package guide's "Private UIKit names are not in the
  binary".
- Its `didChange*`/`consider*`/`inserted*` methods are no-op stubs, so `driveNativeChecking()` calls
  `checkSpellingForWordInRange:` per word (`NativeTextChecker.checkSpellingForWord`) and
  `checkGrammarForSentenceInRange:onPause:` per sentence (~0.35 s debounce). `-textChecker` loads asynchronously:
  `preheat()`, then spin the run loop.
- Offsets become `UITextRange`s via `nativeTextRangeForGlobalLocation:length:` by IMP cast (`@convention(c)`): not
  `perform(_:with:with:)` (boxes the scalar), not `positionFromPosition:offset:` from `beginningOfDocument` (1-based
  axis).
- Flags arrive via `replaceRange:withAnnotatedString:…` and clear via `removeAnnotation:forRange:`; `nativeReplace`
  clamps them to the region (`clampedSpellRegionLocal`; grammar can cross it) into `spellResults[BlockID]`:
  `NSTextAlternatives` ⇒ `.correction`, display style 2 ⇒ `.spelling`, else `.grammar` (colours `misspellingUnderline` /
  `grammarUnderline` / `correctionUnderline`). `isExcludedSpellRange` drops flags over `.link`, `.rtInlineCode`,
  `.rtSpoiler` (else the squiggle leaks the hidden word), the `markedRange` and the word being typed.
- Underlines use `selectionRects`: `SelectionHighlightView.drawSpellingUnderlines(in:)` outside tables; in cells
  `CellSelectionView.drawCellSpelling(in:)` mirrors `drawCellSelection`'s `-box.blockViewFrame.origin` translate + raw
  `region.canvasOrigin`, NOT `canvas.selectionRects` (scroll subtracted twice). Every drawer there stays
  GState-balanced.
- Tap-to-fix (only when `wasFirstResponder`): `misspelledWord(atCanvasPoint:)` (works in cells) →
  `beginSpellingCorrection` selects via `applySelection`, clears a stale `tableSelection` after the hit guard (else
  Backspace deletes rows), sets `pendingSpellingMenu`: iOS 16+ `menuFor` shows guesses while it is set (bypassing
  `contextMenuItemsProvider`), iOS 13–15 `UIMenuController` with `spellGuess0…3`;
  `dismissEditMenuForSelectionOrTextChange` clears it. A fix is one `editing { applySelectionReplaceOutcome }` step +
  re-check. Guesses come from public `UITextChecker.guesses`, or a `.correction`'s stashed `NSTextAlternatives`, which
  add "Revert to '<original>'".
- Open: spelling is pinned by `NativeTextCheckingLiveTests`; grammar and correction are unverified in-app — grammar
  checking did NOT fire in the unit-test host (OS-service-dependent, async) and corrections are keyboard-driven; confirm
  on device in an RTE-active composer (`ios_rich_input_mode = 1`) or the attachment editor (the sim test account's
  composer is the legacy input). A late grammar callback can land after a newer edit (clamped); a cold `UITextChecker`
  can return empty first guesses. Debt: share the `stashedAlternatives` lookup (`spellingGuesses` / `revertTarget`); `if
  let` the legacy `revertTo!`.

## Undo and clipboard

### Undo
- A PRIVATE per-canvas `UndoManager` (`effectiveUndoManager = undoManagerOverride ?? ownUndoManager`), so UIKit's
  registrations on the shared one never reach `canUndo`; only `registerUndo` from `editing{}` and composition commits
  enter it. `override var undoManager` exposes it to ⌘Z, shake and the Edit menu; the attachment screen's pill calls the
  same `undo()`/`redo()`. Tests inject `undoManagerOverride` (`UndoBufferIsolationTests`).
- `undo()`/`redo()` start with `finalizeMarkedText()` and fire `onChange` after the manager settles (inside
  `UndoManager.undo()` `canUndo/canRedo` are stale).
- Runs coalesce (`editing(coalescing:)`) while an edit continues the open run (same kind `.typing`/`.deleting`,
  collapsed caret, at `openUndoRun.caret`). A run breaks on a caret move, typing↔deleting, a selection-replace,
  structural/format/paste edits (`.none`), IME commit, resign and `setBlocks` (`breakUndoCoalescing()`). Only
  char-insert `insertText` sites pass `.typing` and plain-delete `deleteBackward` sites `.deleting`; structural deletes
  and `replace(_:withText:)` (autocorrect, dictation: one step per utterance) stay `.none`. `UndoCoalescingTests` (seam
  `undoRegistrationCount`).
- Undo restores a CARET for content edits that collapsed it (at `max(beforeAnchor, beforeHead)`), the SELECTION for
  formatting.

### Copy and paste
- Copy writes the private UTI `org.telegram.richtexteditor.fragment` (JSON `Document` fragment), `public.rtf` and
  `public.utf8-plain-text` (always); multi-line plain paste splits into paragraphs. A text rep wins on paste (fragment,
  RTF, plain); `fragment(fromRTF:)` uses Core's `RTFImport`, falling back to `NSAttributedString` only on hard failure.
- Media paste goes to the host, never inline: `paste(_:)` with no text rep calls `onPasteMedia?()`; Paste shows when
  `canPasteMedia?()`. The composer wires both to `handlePastedMedia(perform:)` (shared with the legacy input).
- `plainTextFragmentTransformer: ((String) -> Document?)?` (host markdown, `docs/richtext-composer.md` §7) runs only
  with no fragment/RTF rep and a non-empty result; `pasteMarkdownTwoStep(plainText:rich:)` splices the raw text (one
  step), then replaces it with the rich document on the NEXT run-loop cycle (synchronously, `groupsByEvent` merges both
  steps). Step 1 sets `suppressHostChangeNotification` (no `notifyContentSizeChanged()`, trailing `refreshSelectionUI()`
  or `onSelectionChange()`), so the raw state never shows. Undo: rich → plain → gone.
- RTF export is hand-rolled (`RTFConversion.swift`, `rtfData(from:)`): iOS has no `NSTextTable`, so tables are written
  as `\trowd`…`\row`. Not exported: list markers, colours, cell media, cell backgrounds. Custom emoji ride
  `tg://emoji?id=<id>&n=<seq>`; the per-export `&n=` keeps adjacent identical emoji apart.

## Host integration

### Façade and knobs
- `RichTextEditorView` is the façade; the canvas and boxes stay internal so the `UITextInput` witnesses can stay
  internal.
- Knobs default to document-editor behaviour; the composer sets them in `didLoad` before seeding: `contentPageMargin`
  (`CanvasMetrics.pageMargin` 16 → 0), `minimumContentHeight` (44 → 0), `placeholders` ("" draws nothing),
  `canvasBackgroundColor` (`.systemBackground` → nil), `tapBelowAddsTrailingParagraph` (→ false), `renderMetrics` (→
  `.default`), `mediaBlockStyle` (`horizontalBleed` 16 → 0, read at box creation; cell media always 0).
- Every host seeds a `document` (nothing renders until then) and re-runs `update(...)` on `onChange`.
  `RichTextEditorChatInputNode` routes the panel's negative `inputHitTestSlop` ring to the canvas in a
  re-entrancy-guarded `hitTest(_:with:)`.

### Parent-driven layout and state
- `update(size:insets:contentMargins:…) -> CGFloat`: the parent passes size and scroll insets (it owns keyboard insets)
  and gets the content height; `contentInsetAdjustmentBehavior = .never`, no keyboard observation, only `update` writes
  insets.
- A CHANGED top inset re-seats a scroll view resting at the top (`contentOffset.y = −insets.top`); no other relayout
  moves the user's scroll (`RichTextEditorViewTests.test_update_tallDocument_restsBelowTheTopInset`).
- `height(forWidth:contentMargins:)` matches `update` without reflowing (`measuredHeight(forWidth:)` on a scratch
  layout; `TableBlockBox.height` never resizes cells, `recompute()` does) and never reads live `contentMargins`: the
  composer passes `trackedContentMargins` so a draft set before the first `update` measures right; nil = live margins
  (`RichTextAttachmentScreen`).
- `onChange` (no payload) fires on edits, size changes and selection moves; `update` never fires it synchronously
  (recursion).
- `currentState() -> EditorState` is a pure read for toolbars; inline flags are uniform-over-selection or the caret's
  inherited format, from predicates (`rangeIsBold` …) shared with `toggle*`.
- `contentMargins` is hit-testable padding inside the content (added to the 16pt `pageMargin`); insets are bands content
  scrolls under. Its setter neither lays out nor fires; `update` → `performLayout` calls `canvas.layoutContent()`
  explicitly. Settings that reload, relayout or redraw belong in `update`, not setters.
- `performLayout` floors the canvas at the visible height so taps below a short document hit it; `update` still returns
  the real height. `onBecameFirstResponder` / `onResignedFirstResponder` fire once per genuine transition.

### Theme
- `RichTextEditorTheme`: `primaryText`/`secondaryText` are default foregrounds (non-caption/`.caption`); `accent` covers
  links, quote bar, caret, handles and selection (the wash reads `mapper.theme.accent` live); `codeBackground` is
  painted by `CodeBlockBox` (hosts set it to `tableHeaderBackground`). Assigning rebuilds the mapper and reloads only
  when `bounds.width > 0`. Composer path: `ChatRichTextThemeColors` → `applyRichTextTheme` →
  `RichTextEditorChatInputNode`.
- Set the theme BEFORE `document`: the setter bakes the foreground into blocks and an unsized theme change doesn't
  re-map them (black text in dark mode). Composer: `didLoad`; attachment screen: its `if component == nil` block.
- Theme colours never persist: `AttributedStringMapper` injects the per-style default foreground and strips one equal
  to it on read-back (explicit equal colours too), so every reverse caller passes the run's paragraph style (`BlockBox`
  → its style, captions → `.caption`, `+Editing` → the start box's); a wrong one pollutes the model. Limitation:
  removing a link in a `.caption` run with `primaryText != secondaryText` leaves an explicit foreground.

### Keyboard language, custom input, emoji views
- `inputPrimaryLanguage` / `initialInputPrimaryLanguage` / `resetInputPrimaryLanguage()` feed a single-shot
  `textInputMode` override (→ `interfaceState.inputLanguage`); UIKit consumes it on `becomeFirstResponder`, so add no
  side-effect-free read path.
- `insertText(_:)` (one step), `deleteBackward()`, `customInputView` (→ `inputView` + `reloadInputViews()`; an
  `EmptyInputView` hides the keyboard while the caret keeps rendering). The emoji keyboard is consumer-side
  (`RichTextEmojiKeyboardController`): the package stays free of `AccountContext`/TelegramUI; `insertEmoji(id:altText:)`
  takes the fileId string.
- `registerEmojiViewProvider` returns `(UIView & RichTextEmojiView)?`; `syncEmojiViews` sets `dynamicColor =
  theme.primaryText` (template emoji tint like text). The composer's `EmojiTextAttachmentView` conforms retroactively in
  `ChatTextInputPanelNode`; the `ChatRichTextInputNode` seam stays `-> UIView?` (shared with the legacy input), so
  `RichTextEditorChatInputNode` `as?`-casts. The article editor returns `RichTextInlineEmojiView`.

### `composerSelectedRange` and the edit-menu hook
- `composerSelectedRange: NSRange` is the selection in the composer's flat UTF-16 space (exactly
  `ComposerDocumentBridge`'s flattening: paragraphs joined by `"\n"`, code blocks count their code text, other
  non-paragraph blocks nothing); `RichTextEditorChatInputNode.selectedRange` forwards to it and `ChatTextInputPanelNode`
  drives every insert and caret move off it (a wrong mapping splits emoji). The setter brackets the input delegate.
  `+ComposerSelection` flattens a code block by `textStart`, not `leafRegions().first` (the language line).
- `contextMenuItemsProvider: ((defaultElements) -> [UIMenuElement])?` reshapes the edit menu, only for a non-collapsed
  selection on iOS 16+ (`UIMenuItem` needs a `#selector`). The composer's Format submenu (secret-chat gated) calls
  editor commands (Quote → `setParagraphStyle(.quote)`, Code → `performFormatAction(.code)` → `makeCodeBlock()`); Link
  reuses the host's `openLinkEditing` via `currentLink()` / `selectedText()` / `setLink` / `removeLink`.

### Code syntax highlighting is a host seam
- `registerSyntaxHighlighter(_:)`: the host answers `(language, text) -> [RichTextSyntaxToken]`; inert until a language
  is typed. The editor detects, debounces (~300ms from `performEditing` and `setBlocks`, never selection), caches (empty
  answers too) and applies. Hosts use `asyncStanaloneSyntaxHighlight` with the LIGHT palette (as the sent message).
- `CodeBlockBox.applySyntaxHighlight` bakes colours into the string (lossless only because code runs are plain),
  reassigns only on change, drops a token set whole if a range no longer fits; colours never reach `Document`.
- Repaint `blockViews[box.id]?.setNeedsDisplay()`, not the canvas; no `notifyContentSizeChanged()`. `setBlocks` runs
  `reapplyCachedSyntaxHighlights()` before first layout (a rebuild comes from the colourless model).
- Painting rebuilds the storage, breaking an IME composition; safe only while marked text stays in top-level body
  paragraphs (`isBodyParagraphPosition` requires `box is BlockBox`).

### DEBUG layout overlay
`debugShowLayoutOverlay` (`+DebugOverlay`, DEBUG only, ON by default; set `false` to hide) draws frames, insets and
margins; refreshed from `performLayout` / `scrollViewDidScroll`.

## Known trade-offs and tech debt

### TECH DEBT — resolveBox degenerate-container misroute
Known-brittle point patches; generalize, re-architecting if needed.
- `activeStack(at:)` / `leafRegion(containingGlobal:)` descend into `BlockQuoteBox.children` and cells;
  `resolveBox(at:)` / `box(containingGlobal:)` don't. Containers have a degenerate extent (`textStart == nodeStart`,
  `textLength == 0`), so an interior position matches no top-level box and the fallback returns the FOLLOWING block
  (`pos < nextBox.textStart`). Author regions sit off `activeStack`'s child descent, so its own `resolveBox` fallback
  misroutes them too.
- Patched sites (Backspace variants, Return in an author line, the empty-paragraph-after-atom handler,
  `insertTable`/`insertMedia`, `currentState()`, `isBodyParagraphPosition`) swap to `activeStack`/`leafRegion` or guard
  with `!isInsideBlockQuote(pos)` / `!isInsideTable(pos)`; nothing stops the next call site.
- Trap: tests with a NON-EMPTY following block hide it (the empty-paragraph-after-atom handler fires only for an empty
  one).
- Fix: one descending resolver (fold `resolveBox` / `box(containingGlobal:)` into the `activeStack` descent, or give
  containers a real extent), no following-block fallback, the author a first-class leaf on the child axis (or
  `activeStack` descending to it); then delete the guards. Until then a new acting `resolveBox` /
  `box(containingGlobal:)` call site is a smell: prefer `activeStack` / `leafRegion`, or guard the container cases.

### Render-only styling; headings regular weight
- Render-only, so not preserved as user overrides: a link run's foreground/underline (suppressed on read-back) and table
  header-row bold.
- Headings are regular weight (`StyleSheet.font` adds no bold); bold is a pure user toggle. Don't bake bold into heading
  fonts: it leaks into the model and survives a heading→body conversion.

### Open: legacy draws a two-digit ordinal through its text
`BlockBox.listMarkerDraw` left-anchors the marker with `StyleSheet`'s text indent, which can't know the ordinal, so
legacy (and the composer on it) shows `10F`. A fix needs the number in the paragraph style.

### `SpoilerDustView` uses private `CAEmitterBehavior`
`createEmitterBehavior` drives the twinkle and finger explosion: App Store risk, guarded by a live canary test.
