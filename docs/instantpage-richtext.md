# InstantPage V2 & rich-text message rendering

This file documents the **rich-text message** pipeline and the **InstantPage V2** renderer that backs it.

A rich message is a `RichTextMessageAttribute` carrying an `InstantPage` (sent with `text: ""`), produced when typed markdown contains structure the regular message-entity set can't represent (headings, lists, tables, formulas, nested blockquotes) and drawn by `ChatMessageRichDataBubbleContentNode` via the InstantPage V2 layout/renderer — including AI-streaming progressive reveal, inline custom emoji, and entity (mention / hashtag / …) cases. It also covers the send / edit / copy / paste round-trips between markdown and `InstantPage`.

These are detailed, non-obvious invariants — read the relevant section before touching the corresponding code. (Moved out of `CLAUDE.md` to keep that file focused; `CLAUDE.md` retains a brief pointer back to here.)

## Text Size / content scale (bugs.telegram.org/c/62776, 2026-09-22)

A rich message follows Settings ▸ Appearance ▸ Text Size like a plain bubble. Before this, nothing on the
rich path read a font size: the bubble built its theme from the fixed chat-message table, `layoutInstantPageV2`
always used `InstantPageMetrics.unscaled`, "Show more" was `Font.regular(17.0)`, and the node's layout cache
was keyed on theme identity only — so even a scaled theme would have kept serving the old layout.

### Where things live

| File | What |
|---|---|
| `InstantPageUI/Sources/InstantPageV2ContentScale.swift` | `InstantPageV2ScaledLayoutInputs` — page theme, page metrics, quote theme, quote metrics from the BASE theme and ONE `contentScale`. The testable seam (`layoutInstantPageV2` needs `PresentationStrings`, which no test bundle can build). |
| `InstantPageUI/Sources/InstantPageV2Layout.swift` | `layoutInstantPageV2(…, contentScale: CGFloat = 1.0)`. `theme` must be the UNSCALED theme. |
| `InstantPageUI/Sources/InstantPageChatMessageTheme.swift` | `instantPageChatMessageAuthoredFontSize` (17) — the divisor; `codeBlock` category now 15. |
| `InstantPageUI/Sources/InstantPageTheme.swift` | `fontSizeMultiplier` stored on the theme; the H1–H6 ladder scales by it. |
| `InstantPageUI/Sources/InstantPageMetrics.swift` | `codeBlockFontSize = floor(15 · scale)`; `init(scale:screenScale:)`. |
| `ChatMessageRichDataBubbleContentNode.swift`, `ChatSendMessageRichTextPreview.swift`, `ButtonEditorScreen.swift` | Pass `instantPageChatMessageContentScale(baseFontSize:)` (the button editor previews the bubble's 17pt table, so it scales with it); the bubble's and the send preview's layout caches are keyed on the font size; "Show more" at the base size. |
| `InstantPageUI/Tests/InstantPageContentScaleTests.swift` | The rounding contract, all seven steps. |

### Non-obvious invariants

- **One scale, applied once.** `contentScale = baseDisplaySize / 17` is fractional at six of the seven steps
  (0.824 … 1.529). It is consumed at exactly two rounding chokepoints: `withUpdatedFontStyles` floors every
  font to whole points, and `InstantPageMetrics(scale:)` snaps every geometry constant to the pixel grid — the
  same two paths the nested-quote scale (15/17) already went through. Nothing downstream multiplies by it again;
  a quote inside a scaled page is `base × (contentScale · quoteScale)`, rounded once, never a scaled theme scaled
  again. Rounding twice happens to agree for the paragraph at all seven steps, which is luck, not a property.
- **Code = table = quote body**, all "one step below body" (15 at 17), and they stay equal at every step AND
  inside a quote at every step. Code rides `InstantPageMetrics`, so it must take the fonts' whole-point floor,
  not the pixel snap — `floorToScreenPixels(15 × 19/17)` is 16.67 against a 16pt table.
- **The theme's stored `fontSizeMultiplier`** is what the heading ladder scales by. Recovering it from the
  floored subheader drifts by a point (H2 = 21 instead of 22 at `.large`). This also moves the **full-page
  Instant View reader** (V1 `InstantPageLayout` heading blocks) at every non-standard reader font size —
  e.g. reader `.large` (1.15): H2 was floor(20 × 25/22) = 22, is floor(20 × 1.15) = 23. Deliberate: the
  ladder now scales by the same number as the body text beside it.
  `InstantPageContentScaleTests.testInstantViewReaderLadderScalesWithItsBodyAtEveryReaderSize` pins it.
- **`layoutInstantPageV2` asserts** `theme.fontSizeMultiplier == 1.0 || contentScale == 1.0`. A pre-scaled
  theme scaled again floors its categories twice while the multiplier compounds exactly, and the ladder
  and body drift apart. The reader's themes arrive pre-scaled and pass 1.0; chat hosts pass the authored
  theme plus the scale.
- **The test process reports a 1x screen** (`UIScreen.main.scale == 1.0`, measured 2026-09-22), on which a
  pixel snap IS a floor. Any test about the grid passes `screenScale: 3.0` explicitly, or it cannot fail.
- **Text Size does not change the theme object**, so the bubble's and the preview's layout caches carry the
  font size as their own key.
- **Not scaled, on purpose:** inline/block button labels (15/16pt, see "Inline buttons"); the NATIVE editor,
  which lays out at `RichTextRenderMetrics.default` (17pt, pinned equal to the unscaled chat table by
  `RichTextV2MetricsParityTests`) and carries its own `baseFontSize = 17.0` in `RichTextEditorChatInputNode`.
  Scaling it is a separate decision — it needs the presentation font size plumbed in and the parity tests
  widened to a scale parameter. Until then the dual-field switch latching to native shows a size jump for
  non-`.regular` users.
- **The LEGACY composer follows Text Size everywhere** (2026-09-22). `ChatTextInputPanelNode` read the font
  size at fourteen sites and eight of them — inherited from upstream, which still has them — carried an
  always-true `if "".isEmpty { baseFontSize = 17.0 }` pin: the placeholder font, the empty-field minimum
  height, the vertical text insets and the initial rendering config. The per-keystroke re-decoration was not
  pinned, so typed text scaled on the first keystroke while the placeholder stayed 17pt and an empty field
  opened at 31 and animated to the scaled height when its text node loaded. All reads now go through
  `chatTextInputBaseFontSize(for:)` / `chatTextInputFieldMinHeight(for:)` /
  `chatTextInputFieldVerticalInsets(for:)` (`ChatTextInputFontMetrics.swift`; the latter two switch
  exhaustively on `PresentationFontSize`, so a new step fails to compile rather than silently taking 31), a Text Size change
  rebuilds the placeholder and re-decorates live text (`fontSizeUpdated`, beside `themeUpdated`), and
  `ChatTextInputFontMetricsTests` asserts the minimum height equals what the legacy text view measures for
  an empty field at every step — the exact property whose violation was the animation.
  Two knock-ons of the field growing. The panel holds two `ChatTextInputActionButtonsNode`s: `mediaActionButtons`
  (the mic, OUTSIDE the field beside the attachment button) and `sendActionButtons` (the send capsule, INSIDE
  the field). Both used to be sized to the field's minimal height, equal to 40 only while pinned. The mic is
  now a fixed 40×40 like the attachment button; the send node keeps following the field so its capsule
  (inset 3pt) fits it at every step — 40×34 at 17pt, 40×41 at 23pt. And that capsule's background was a
  stretchable circle baked at diameter 34, a constant 17pt radius: it is now regenerated for
  `min(width, height)` of its frame, and the slowmode ring and stars effect layer take the same radius.
- Two `layoutInstantPageV2` callers stay at 1.0 on purpose: `TextProcessingRichContentView` (the
  text-processing screen, not a chat bubble) and `FormulaEditorScreen`, whose preview theme is authored at a
  22pt paragraph as a stylised preview — the bubble's divisor would compound onto a base that is not 17.
  The bubble, the send preview and the button editor preview pass the chat scale.

## AI streaming animation (rich-text bubbles)

`ChatMessageRichDataBubbleContentNode` progressively reveals InstantPage V2 content while `TypingDraftMessageAttribute` is on the message. Mirrors the older animation in `ChatMessageTextBubbleContentNode`, adapted to the heterogeneous V2 layout. The "Thinking…" indicator is now server-sent as `InstantPageBlock.thinking` rendered inside the pageView (see "InstantPage thinking blocks" section).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramUI/Components/StreamingTextReveal/Sources/TextRevealController.swift` | Pacing controller, shared by both bubbles. EWMA inter-arrival → velocity-smoothed cursor. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` (`InstantPageV2TextView`) | Drawing split: private `TextRenderView` does `draw(_)` inside a `renderContainer` whose layer carries a `revealMaskLayer`; new chars spawn cropped `SnippetLayer` siblings of the render container that animate in (blur + alpha + scale + position) and are absorbed into the mask on completion. Ported from `InteractiveTextComponent`. |
| `submodules/InstantPageUI/Sources/InstantPageV2RevealCost.swift` | `InstantPageV2RevealCostMap` + `InstantPageV2View.applyReveal(revealedCount:costMap:animated:)`. Bridges the global width-based cursor to per-text-view char counts (via `charCountForWidthBudget`) and per-item visibility / table-row pop-in. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `InstantPageTextLine.characterRects` (line-local CT coords, baseline-relative positive-up) populated when `computeRevealCharacterRects: true` is passed to `layoutInstantPageV2(...)`. Uses `CTFontGetBoundingRectsForGlyphs` for actual glyph ink, not advance widths. |
| `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/...` | Streaming detection (`TypingDraftMessageAttribute`), display-link wiring, container sizing. The hardcoded "Thinking…" header was removed; thinking is now rendered by the pageView via `InstantPageBlock.thinking`. |

### Non-obvious invariants

- **Cost unit is points of width, not characters.** Each item's cost = its width in points along the reading direction. Text contributes sum of glyph ink widths; non-text items contribute `frame.width`. Table cells are floored at `cell.frame.width` so narrow- or empty-cell tables don't race through the cursor. Reveal pace becomes "points per second" — uniform across content types.
- **Mask uses per-glyph ink bounds, unioned per line.** Each revealed glyph's mask rect comes from `CTFontGetBoundingRectsForGlyphs` (not advance widths) so italics, accents, descenders are covered exactly. Per line, glyphs are unioned into one mask rect; consecutive fully-revealed lines union further — fully-revealed prefix is always one `CALayer`.
- **`containerNode` does ALL the clipping.** During streaming, containerNode is sized to `revealedItemsMaxY` (no header offset, no closing pad; `streamingHeaderOffset` is `0.0`). The bubble itself is taller (`revealedContentSize.height + 2`) — the strip below containerNode is empty bubble background. pageView keeps its full `pageLayout.contentSize`; anything past containerNode's bottom is clipped at containerNode (`clipsToBounds = true` set in init). Do NOT shorten the pageView or set `pageView.clipsToBounds`.
- **The pageView is REUSED across `stableVersion` bumps for the same message id.** `ensurePageView` calls `existing.renderContext?.updateContent(webpage:)` (where `webpage` is now a `public private(set) var` with an `updateContent` mutator) and returns the existing view; `update(layout:)` then diffs item views by stable id, tearing down only views whose block was removed. The pageView is rebuilt only when the bubble is recycled with a different message or webpage. The reveal cursor on `TextRevealController` persists across chunks; the seed re-apply (`applyReveal(revealedCount: previousAnimateGlyphCount, …, animated: false)`) is now a continuation from the reused views' state, eliminating the per-chunk flash-of-full-text-then-mask that required the earlier from-scratch re-seed.
- **Layout cache key includes `message.stableVersion`.** Each AI chunk bumps stableVersion; without this the cached layout would shadow newly-arrived content.
- **`TypingDraftMessageAttribute` is the streaming gate.** Same trigger TextBubble uses. The InstantPage's `isComplete` flag is informational only.
- **Width-based cost → char count bridge.** Mask APIs (`updateRevealCharacterCount`) still take character counts. `applyRevealEntry` calls `charCountForWidthBudget(textItem:widthBudget:)` to translate the width-based local cursor into the per-text-view character count.
- **The hardcoded "Thinking…" header was removed.** `streamingStatusTextNode`, `streamingStatusShimmerView`, and the header-layout machinery no longer exist. `streamingHeaderOffset` is now a constant `0.0` — the pageView starts at the top of the bubble. The "Thinking…" indicator is now server-sent as `InstantPageBlock.thinking` and rendered inside the pageView (see "InstantPage thinking blocks" section below).
- **Display-link tick re-layouts on extent change.** Tick reads `revealedContentSize` at the new cursor; if the height differs from the previous cursor, calls `requestFullUpdate`. So the bubble grows in flight when the cursor crosses a line/item boundary, not just between chunks. Tick passes `animated: true` to `applyReveal` to fire the snippet pop-in.

### Send-time media continuity (no blink on Local→Cloud)

A rich message with media used to **blink** on send because `ensurePageView` keyed pageView
reuse on `message.id`, which flips namespace Local→Cloud at send time, forcing a full pageView
rebuild → fresh `InstantPageImageNode`s → `setSignal` re-run → fade-in flash.

- **The reuse key is `message.stableId`, NOT `message.id`.** `stableId` is preserved across the
  Local→Cloud transition (it is also what `ChatMessageBubbleItemNode` uses to reuse the content
  node instance), so the pageView and its positional `.media(index)` media views survive send;
  the reused views keep their already-rendered pixels. A genuinely recycled bubble has a
  different `stableId`, so recycling still rebuilds.
- **The data layer already re-homes the bytes.** `ApplyUpdateMessage.swift` calls
  `applyMediaResourceChanges` for `RichTextMessageAttribute`, moving the local upload bytes onto
  the new Cloud resource ids — so even the reference node's pattern (reload only if not
  semantically equal) would resolve from cache. Here we avoid the reload entirely by keeping the
  views.
- **The render context's `MessageReference` is refreshed on the id flip.**
  `InstantPageV2RenderContext.updateContent(webpage:message:imageReference:fileReference:)` swaps
  the message-scoped reference + closures when `messageId` changes (Local→Cloud), so LIVE
  consumers — inline video `NativeVideoContentId.message`/fetch, audio playlist key/fetch,
  gallery — use the Cloud reference immediately. The webpage-only `updateContent(webpage:)`
  remains for streamed AI chunks (message id stable → no refresh).
- **The reused media node's INTERACTIVE bindings are refreshed too — its image is NOT.** The
  poster `InstantPageImageNode` is reused (its already-decoded pixels are byte-identical to the
  Cloud image, since `ApplyUpdateMessage` *moved* the bytes onto the new resource id — so the
  image signal is deliberately never re-set, which is what avoids the blink). But its `self.media`
  identity and fetch-status subscription are still bound to the stale *local* resource, and
  tap-to-open depends on both: `openInstantPageMedia`'s `centralIndex` match compares the tapped
  `self.media` against the fresh (Cloud) gallery entries via `InstantPageMedia ==`
  (full `EngineMedia` equality), and the image tap gate keys on `fetchStatus`. Left stale, tap
  silently no-ops (image) or opens nothing (video) until a scroll-recycle rebuild. So the V2 media
  views (`InstantPageV2MediaImageView`/`VideoView`/`CoverImageView`) call
  `InstantPageImageNode.updateInteractiveMediaBinding(sourceLocation:media:imageReferenceForMedia:fileReferenceForMedia:)`
  from `update(item:)` **only when `item.media.media.id` changed** — re-pointing `self.media`, the
  status subscription, and `fetchControls` at the Cloud resource *without* touching the image
  signal. (Gated on the id change so it never churns during AI-streaming relayouts, where the id
  is stable.)
- **Coverage.** Single image, video, and **collage** cells are covered — collage flattens into
  ordinary positional `.mediaImage`/`.mediaVideo` views, so each cell gets the reuse + binding
  refresh for free. **Slideshow** was verified to send with no blink and working tap-to-open with
  **no slideshow-specific code** (its container view + pages reconcile through the same positional
  reuse). If a future change makes a slideshow rich message blink or break tap-to-open on send,
  apply the same `updateInteractiveMediaBinding` refresh to `InstantPageV2SlideshowView`'s pages.

### Whole-content vs same-content updates

`ensurePageView` splits a same-`stableId` content change two ways. A **same-content update** keeps
the view and lets `InstantPageV2View.update` diff item views by stable id — a streamed chunk, the
Local→Cloud send flip, a text edit that preserves shape, a checkbox tap, a `<details>` toggle. A
**whole-content update** rebuilds the view and crossfades: the outgoing view stays live (0.12s out)
under the new one (0.1s in), the same numbers `ChatMessageTextBubbleContentNode` uses.

Load-bearing details, none of which the compiler checks:

- **Compare `richPageKey.caseTag`, never `richPageKey`.** The key carries `ObjectIdentifier`s of
  the attribute and page, and a streamed chunk produces a fresh `RichTextMessageAttribute` on every
  tick — comparing keys would dissolve the bubble on every chunk.
- **The fingerprint (`instantPageStructureFingerprint`) reads strings, not identities.** In: case
  tags, child counts, optional-child *presence*, and every string the user reads — `RichText` leaves
  and their wrapper tags (so adding bold counts), urls, captions, table cell text, button labels,
  `formula` latex. Out: `MediaId`, `webpageId`, `fileId`, `peerId`, invisible `anchor` names.
  - **Excluding media identity is load-bearing.** The send flip rewrites every `MediaId` in the page,
    *including the inline ones inside `RichText.image`*, while nothing visible changes. Fold them in
    and every rich message with media dissolves on send.
  - Optional *value* is payload, which is why ticking a checkbox (`checked: Bool?` going
    `false`→`true`) does not dissolve but a checkbox marker appearing does.
  - **`RichText.textDate` contributes its model `date`, never the formatted string** — so the
    relative-date refresh timer re-lays-out ("3 minutes ago" → "4 minutes ago") without dissolving.
  - Still excluded as presentation payload: heading `level`, list `ordered`, preformatted `language`,
    `blockQuote.collapsed`, `details.expanded`, `image.spoiler`.
- **The `InstantPage ==` guard is what makes the pending-edit exit safe.** `.pendingEdit →
  .original` fires when the server confirms an edit, at which point the content usually matches the
  optimistic local page already on screen; without the guard that is a flash for nothing.
- **The outgoing view is live, not a snapshot** — a snapshot would freeze a playing inline video and
  stop custom-emoji loops mid-dissolve. It is safe because `mediaRegistry` is per-root-view and every
  bubble-side lookup goes through `self.pageView`, which already points at the new view.
- **The fade-in is gated on a local `crossfadeIn` flag, not on `fadingOutPageView != nil`.** A
  dissolve from a previous update can still be in flight when a scroll recycle rebuilds for a
  different message; keying off the slot would fade the recycled bubble in for no reason. The
  recycle path also drops the stale dissolve outright.
- **A non-animated pass takes the same-content path.** `update(layout:theme:)` re-renders every
  reused view, so the content is correct either way; rebuilding would only re-create media wrappers
  and their fetches for a transition nobody sees.

### Status node (date/time/checks) positioning

The `ChatMessageDateAndStatusNode` mirrors TextBubble's placement, adapted to the heterogeneous V2 layout. The node is a child of `self` (the content node), **not** of the clipping `containerNode`, so it is never clipped — the bubble height must be grown to contain it.

- **X is a fixed left edge, not the last line's `minX`.** Anchor x = `pageHorizontalInset` (10pt, the page layout's text inset; pageView sits at self-x 0). The status layout is measured with `boundingWidth - 2·pageHorizontalInset` (mirrors TextBubble's `boundingWidth - sideInsets`) so the right-aligned date lands at the right inset instead of off the bubble. Using `lastTextLineFrame.minX` (which is large for nested/indented last lines) shoved the date off to the right.
- **Trail the last line only when the bottom-most item is text.** `lastTextLineFrameIfLastItemIsText(in:)` (in `InstantPageV2Layout.swift`) returns the last line frame *only* when the bottom-most top-level item (max `maxY`) is a `.text`; otherwise nil, so the date wraps below all content (anchored at `contentSize.height`). For tables/images/etc. the date must not trail text buried above the final item.
- **InstantPage draws the baseline at the line frame's `maxY`** (`InstantPageRenderer` draws each line at `lineOrigin.y + lineFrame.height`), so the visible text of a plain line sits ~5pt below `maxY`. A date that **trails** on the line (`statusHeight == 0`) adds `trailingBottomPadding` (5pt) to align with the text; a date that **wraps** onto its own line below (`statusHeight > 0`) sits at the bare `maxY`. The pad is 0 for lines taller than their font line height (a tall inline attachment, e.g. a formula, already pushes `maxY` down). `lastTextLineFrameIfLastItemIsText` returns `(frame, trailingBottomPadding)`; the bubble applies the pad only in the trailing case.
- **Bubble height leaves ~6pt below the date.** One unified formula for all cases: `boundingSize.height = max(boundingSize.height, statusBottomEdge + 6.0)`, where `statusBottomEdge = statusAnchorY + max(1, statusHeight)`. The `statusAnchorY` in the measure (`continue`) closure must mirror the `statusFrameY` in the apply closure exactly, or the date will be clipped/misplaced. (`streamingHeaderOffset` is `0.0` — there is no header offset to add.) 6pt matches TextBubble's bottom bubble inset.
- **`hasDraft` adds the same 6pt at the streaming site.** The status max() above is gated by `!hasDraft`, so during streaming (status hidden, alpha=0) it can't supply the bubble's bottom inset. A separate `boundingSize.height += 6.0` inside `if hasDraft` in the SizeBlock closure does it instead — same 6pt, so the streaming bubble's bottom breathing room matches its post-stream height and there's no 6pt grow-pop when the status node fades in at finalize. The `hadDraft && !hasDraft` finalize pass doesn't need it because `!hasDraft` re-enables the status max(). If you ever refactor the `+6.0` constant out of the status max() into a `bottomInset` (TextBubble's pattern), kill this separate term at the same time — they're two ends of the same invariant.
- **Trailing full-width media → overlaid pill, no reserved space.** When the bottom-most laid-out item is full-width visual media (`.mediaImage`/`.mediaVideo`/`.mediaCoverImage`/`.mediaMap`/`.slideshow`/`.mediaPlaceholder`), `lastFullWidthMediaFrame(in:)` (`InstantPageV2Layout.swift`) returns its frame and the status switches from `.Bubble{Incoming,Outgoing}` to the image-style `.Image{Incoming,Outgoing}` pill, positioned at the media's bottom-right corner (`layoutConstants.image.statusInsets`, with the X anchor clamped to `contentSize.width` to drop the 4pt `instantPageV2MediaEdgeBleed`), and reserving **no** vertical space — the width-growth and the `statusBottomEdge + 6.0` height reservation are both gated on `mediaStatusFrame == nil`, and the status layout input becomes `.standalone(reactionSettings:)`. The full-width gate (`frame.width >= contentSize.width - 12.0`) excludes a narrow/centered trailing media, which keeps the normal below-content bubble status. **The check is over the bottom ROW, not the bottom item**: a `.collage` lays out one media item *per cell*, so a mosaic ends in several items side by side and the single bottom-most item is a ~half-width cell — which failed the gate and fell back to the inline text-time style. `lastFullWidthMediaFrame` collects every item within **2pt** of the bottom edge, requires all of them to be overlay-eligible media, and gates on the union's width. That tolerance is load-bearing in both directions: mosaic cells in a row share a bottom edge to within rounding, while a caption or text line sits a whole line-height lower — which is what keeps a *captioned* collage on the text-time style.
- **A pill can't host multi-row reactions, so non-inline reactions move outside the bubble.** The `wantsReactionsOutside` decision must be made *before* layout (it feeds `ChatMessageBubbleItemNode`'s pre-layout `needReactions`), so it can't consult laid-out items — hence two detectors. The **prepare phase** does a model-only structural check (the effective `InstantPage`'s last block is empty-caption visual media) and reports `ChatMessageBubbleContentProperties.wantsReactionsOutside = endsWithMedia && hasNonInlineReactions`; `ChatMessageBubbleItemNode` ORs that flag into `needReactions` (`if needReactions || forceReactionsOutside`), routing reactions to the external reaction-buttons node. The **layout phase** does the authoritative full-width check for the visual pill (above) and passes empty `reactions`/`reactionPeers` to the status node. Inline reactions stay *in* the pill via the `.standalone` reaction settings, mirroring `ChatMessageInteractiveMediaNode`. The two detectors can disagree only for a pathologically narrow trailing media (structural says "external", layout declines the pill) — accepted and documented, does not occur with server rich media (always full-width). **The collage case used to be the realistic instance of that disagreement and is now closed** (see the bottom-row check above); the decoupling remains as the defence, so reactions are unaffected either way — they key off `wantsReactionsOutside`, which is structural.

## InstantPage V2 table — flush frame, inset borders, rounded corners

A V2 `.table` block's item frame is **full-width / flush** with the bubble interior (so a horizontally-scrollable wide table's scroll container bleeds edge-to-edge), but the actual grid **borders start at the body-text side inset** — matching the V1 renderer. The grid card also has a **10pt rounded outer border**.

### Non-obvious invariants

- **`InstantPageV2TableItem.contentInset` (= page `horizontalInset`) is the linchpin.** `layoutTable` (`InstantPageV2Layout.swift`) sizes columns against `contentBoundingWidth = boundingWidth − horizontalInset·2` (so a fitting table aligns with body text on both sides) and stores `contentInset` on the item; the item `frame.width` is the flush `boundingWidth`, and `contentSize.width` stays the **bare grid width** (`totalWidth`, no inset).
- **The renderer (`InstantPageV2TableView`) realizes the inset as a view shift, not baked coordinates.** In `init` AND `update` it shifts the grid `contentView` to `x: contentInset`, sets `scrollView.contentSize.width = contentSize.width + contentInset * 2.0` (**margin on both sides**, mirroring V1's `InstantPageScrollableNode`), and `scrollView.clipsToBounds = true`. Cells, inner border lines, and the title stay x=0-relative inside `contentView`, so the single shift carries them all; the rounded outer border is `contentView.layer`'s own border (see below), which wraps the shifted layer automatically.
- **Scrollable tables clip to the full width with no inset on the clip.** The inset lives inside the scroll content as a symmetric margin on both sides (`contentInset * 2.0`): a fitting table (`grid + 2·inset ≤ boundingWidth`) doesn't scroll and shows both-side inset; an overflowing table rests with its left border at the inset and scrolls until its right border reaches a matching trailing inset (it does **not** jam flush against the screen edge — matches V1). The scroll-indicator threshold and `contentSize.width` use the same `+ contentInset * 2.0`, so "does it scroll" is exactly `grid > boundingWidth − 2·inset`.
- **Overflowing tables compress instead of scrolling wide (V2 second pass).** When the sum of columns' minimum (maximally-wrapped) widths exceeds the content width, `layoutTable` (`InstantPageV2Layout.swift`) runs `compressTableColumnsToFit(...)`: it scales columns proportionally to their **natural (`maxColumnWidths`)** widths down to a per-column floor (`v2TableMinCompressedColumnWidth = 60.0`, of which 26pt is cell padding), clamping any column that would drop below the floor and redistributing the remaining shrink (water-filling). A column narrower than its widest word wraps that word (taller cell). Two outcomes: **(a) fits** (`Σ min(floor, naturalWidth) ≤ contentBoundingWidth`) → the widths sum to exactly `contentBoundingWidth`, no scroll; **(b) doesn't fit** (floors still overflow) → columns stay at the fully-compressed floored width and the table **still scrolls, but at that narrow floored width** (`totalWidth = Σ floored + borderWidth`), NOT the full natural widths — i.e. the compressed shape is always preferred over the wide one, minimizing the scroll extent. Natural widths are used only for a degenerate zero-column table. The floor is an absolute value, not derived from glyph widths, so a single very long token can still overflow its cell horizontally (accepted trade-off; no word-overflow guard).
- **Manual cell-coordinate helpers MUST add `contentInset`.** Because the shift is a real `contentView` frame change, UIKit `hitTest` and `self.convert(_:to:)` paths (`propagateVisibilityRect`, the row-reveal mask) handle it automatically — but the *manual* coordinate helpers `findTextItem` / `collectSelectableTextItems` (the live tap / URL / text-selection path) compute cell/title positions arithmetically and must add `table.contentInset` to the x-offset, or in-cell hit-testing is off by the inset. (These helpers still do **not** account for the table's live horizontal `scrollView.contentOffset` — a pre-existing limitation, so in-cell hit-testing is only correct at scroll offset 0.) The dead-but-symmetric `lastTextLineFrame(in:)` table branch has the same omission but has no callers.
- **The 10pt rounded outer border is `contentView.layer`'s own border, NOT sublayers.** `v2TableCornerRadius = 10.0` (`InstantPageV2Layout.swift`). The renderer sets `contentView.layer.cornerRadius`/`borderColor`/`borderWidth = bordered ? v2TableBorderWidth : 0.0` in BOTH `init` and `update` (the four straight outer-edge rect layers were removed; `lineLayers` now holds only inner grid lines). **Border-only — deliberately no `masksToBounds`:** `cornerRadius` rounds the layer's border without clipping contents (filled corner cells round their own fills separately — see next bullet), and there is **zero interaction with the streaming reveal mask** (`contentView.layer.mask`, set only during AI streaming) — the border reveals row-by-row with the rows and is part of the masked layer. The rounded card belongs to the grid (scrolls with it). For a non-empty-title table (never produced by markdown/AI), the border wraps title+grid since `contentView` includes the title region — an accepted, approved nuance.
- **Filled corner cells round their own fills to match the border.** A header/striped cell's background is a stripe `CALayer`; `tableStripeCornerMask(cellFrame:gridWidth:gridHeight:effectiveBorderWidth:)` detects which grid corners the cell's (grid-local) frame touches — `firstCol/firstRow` via `frame.min{X,Y} <= effectiveBorderWidth/2 + 0.5`, `lastCol/lastRow` via `frame.max{X,Y} >= grid{Width,Height} - …` (gridWidth = `item.contentSize.width`, gridHeight = `item.contentSize.height - gridOffsetY`) — and rounds only those corners: `stripe.cornerRadius = max(0, v2TableCornerRadius - effectiveBorderWidth)` (the `-borderWidth` leaves an even border ring; borderless → full radius) + `stripe.maskedCorners`, in BOTH `init` and `update`. A `CALayer`'s `backgroundColor` honors `cornerRadius`+`maskedCorners` with no `masksToBounds`. A full-width (colspan) header rounds both top corners; a one-row filled table rounds all four; bottom corners round only when the last row is filled. The empty-mask branch resets `cornerRadius = 0` **and** `maskedCorners = []` so reused stripes (persist across streaming chunks) don't keep stale rounding. Detection is grid-local, so it's independent of the `contentInset` shift / horizontal scroll.

## InstantPage V2 code block — edge-to-edge plain band

A `.preformatted` block renders as a **plain, square, `codeBlockBackgroundColor` rectangle spanning its container's interior edge to edge**, with its monospace text — and a **bold, lowercased language line above it** — at exactly the x a paragraph occupies at that nesting level. So the band's interior side padding IS the paragraph inset; it is not a code-block constant. No accent bar, no tint, no corner radius: a code block reads as a highlighted table row, not as a quote variant (it was one, from the 2026-07-06 reskin until 2026-08-18).

The message hosts pass `codeBlockBackgroundColor` the same value they give `tableHeaderColor`. The field is **revived, not new** — V2 stopped reading it in the July reskin while V1 full-page Instant View still does, so the presets in `InstantPageTheme.swift` are untouched and V1 is unaffected.

### Non-obvious invariants

- **`LayoutContext.childBleed` is how a full-bleed block reaches its container's edges.** V2 lays a container's children out flush against a band at `horizontalInset: 0` and then translates them, precisely so no block needs to know it is nested — that is what makes media, tables, collages and slideshows land *inside* a quote rather than at the page's leading edge. A block can therefore only reach the container's interior if the container tells it how far it may go. Each container sets and restores `childBleed` with the same `let saved = …; defer { … }` idiom `theme` and `metrics` already use. `layoutCodeBlock` is the only consumer today.
- **The bleed is GEOMETRIC, not logical.** `minXSide` is always the smaller-x edge; a container that mirrors itself for RTL (a block quote moves its bar to the trailing edge) resolves that when it *sets* the value, so no consumer reads `context.rtl`. Getting this backwards is invisible in LTR.
- **Every non-top-level sequence RESETS the bleed rather than inheriting it.** `layoutBlockSequence` assigns the page inset for `.topLevel` and `.none` for everything else (`.cell`, `.detail`, the table title), and `layoutList` does the same for its sub-blocks — which reach `layoutBlock` directly and so never pass through that reset. An inherited page-level bleed would send a band punching out through a table cell's own edge. The `.none` default on `LayoutContext` means a missed container degrades to the old inset geometry rather than to an escaping band.
- **A block quote's bleed stops just INSIDE its accent bar** (`instantPageV2QuoteBarWidth`, shared with the quote frames that draw it) so the bar stays continuous down the whole quote instead of being interrupted for the child's height. Note the quote's child band ends 45pt from the page's right edge while its fill ends at 9pt, so a nested band carries ~36pt of empty fill on its right — pre-existing quote geometry, accepted.
- **In the `fitToWidth` shrink a band contributes its INNER content, not its own frame — and "exclude the band" is NOT enough.** `layoutBlockSequence` sizes a rich bubble from `max(item.frame.maxX) + horizontalInset`; a band reaching `boundingWidth` would clamp **every message containing a code block to a full-width bubble**, however short its text. But `layoutCodeBlock` returns a SINGLE `.codeBlock` item with the text and language line nested inside it — they are not members of `items` — so dropping the band outright drops the code text from the shrink entirely. A message whose widest content is its code then gets a bubble narrower than the width that text was laid out against, and **the code text is clipped at the bubble's edge** (shipped and caught on device, 2026-08-18). `instantPageV2FitWidthMaxX` therefore reaches in and returns `block.frame.minX + inner.frame.maxX` over the text and language items — the offset matters because the nested frames are block-local. `instantPageV2StretchCodeBands` then re-widens the band to the surviving `contentSize.width` — the same reason `centerBlockFormulas` runs after `contentSize` rather than before it. **The stretch moves the TRAILING edge only**: the leading edge carries the bleed and the text's block-local x is measured from it. Regression: `InstantPageV2CodeBandTests.testBubbleIsWideEnoughForCodeWiderThanEveryOtherBlock`.
- **The language line is a real laid-out text item, not a view-built label.** It used to be the only font in the V2 renderer not baked into an attributed string at layout time — the one place the content scale could leak past the layout — which is why `codeBlockLanguageFontSize` had to travel on the item at all. It now mirrors the **quote author's** derivation (the `caption` category pushed to bold at the `paragraph` size), so the editor's copy cannot be set to something different, and it is lowercased at layout time so the model's casing never reaches the screen.
- **Editor parity travels through `RichTextRenderMetrics.code` (`RichTextCodeMetrics`)** — the vertical inset and the language-line gap, sourced by the adapter from `InstantPageMetrics`. The bleed deliberately does NOT: it is a property of the host's container geometry (canvas margins, bubble insets), not of the shared type scale, so each surface computes its own. The editor half is in the RichTextEditor's own `CLAUDE.md`.

Design record: `docs/superpowers/specs/2026-08-18-code-block-edge-to-edge-design.md`.

### Syntax highlighting (added 2026-08-25)

V2 code blocks are syntax-highlighted from the **same cache regular text bubbles use**: libprisma behind
`Syntaxer`, `CachedMessageSyntaxHighlight` keyed by `Spec(language, text)`, generated off the main queue and
applied synchronously from cache. Nothing highlights on a layout path; a MISS renders plain and the colours
arrive on the next layout after the async job lands. `layoutCodeBlock` overlays the cached entities onto the
string it just built (`applyInstantPageSyntaxHighlight`), and `ChatMessageRichDataBubbleContentNode` drives
generation exactly as the text bubble does — extract specs, read
`DerivedDataMessageAttribute.data["code"]`, start `asyncUpdateMessageSyntaxHighlight`.

**Three pre-existing, silent defects had to be fixed before any of this was visible:**

- **`InstantPageBlock(apiBlock:)` hard-coded `language: nil`** when decoding `pageBlockPreformatted`,
  discarding the field the outgoing `apiBlock()` correctly sends. Every page decoded from the API came back
  language-less, so a code block's language survived the send and was lost on the echo — which disabled
  highlighting for every rich message AND every web Instant View article, and showed an empty language field
  when editing a sent message. Nothing could author a language for a rich block before, so nothing surfaced
  it.
- **`generateMessageSyntaxHighlight` handed libprisma the raw language.** `LanguageTree::find` is an exact
  `std::map` lookup with lowercase keys, so `"Swift"` — or `" swift "` — resolved to no grammar, returned
  the text untokenized, and produced zero entities. Silent: no error, just a block that never highlights.
  Measured: `"swift"` → 3 entities, `"Swift"` → 0. Normalizing at that one call fixes every caller.
- **V2 never read `cachedMessageSyntaxHighlight`**, though it has been a parameter of `instantPageV2Layout`
  and a field on its `LayoutContext` since V2 was written. V1's `attributedStringForPreformattedText` did
  apply it, so web articles highlighted and V2 did not.

**Non-obvious invariants**

- **Extraction and application must normalize the language the same way.** `instantPageSyntaxHighlightSpecs`
  (hoisted out of `BrowserUI` into `TextFormat`, where three consumers can reach it) and the V2 apply both
  run it through `normalizedCodeBlockLanguage`. A page storing under `"swift"` and looking up `"Swift"`
  misses every time, silently.
- **That extractor's recursion previously ended in `default: break`, so code nested in a `blockQuote` was
  collected by NOBODY** — unhighlighted even in the browser. Rich messages nest code in quotes routinely.
- **A cached highlight can outlive the text it described** (it is persisted per message), so every apply
  validates each range against the current string and drops the WHOLE highlight on any mismatch. Applying
  one partially colours arbitrary spans of unrelated code.
- **The rich bubble's cached-layout key includes the highlight.** It otherwise keys on `messageStableVersion`,
  and whether a `storeLocallyDerivedData` write bumps that is Postbox's business — without the clause a
  newly-arrived highlight can be computed, persisted, and never painted, because the node keeps serving the
  layout it cached before the job finished.
- **The palette is libprisma's LIGHT one everywhere**, including dark mode, because that is what the message
  path has always baked and it keeps the editor WYSIWYG against the sent message. libprisma ships a dark
  palette that nothing uses.

The editor half — the authorable language field and the host-provided highlighter seam — is in the
RichTextEditor's own `CLAUDE.md`.

## InstantPage V2 block media — flush (edge-to-edge), un-rounded

Every V2 block-media kind lays out **flush** with the bubble interior (0 inset, full bounding width) and **un-rounded** (cornerRadius 0). The bubble's existing rounded clipping container rounds any media that meets the bubble's top/bottom edge. V1 (`InstantPageLayout.swift`) is unchanged. (Audio is **also** full-width / x = 0 as of the V2 audio port, but it does not use this helper — it has its own `layoutAudio` arm; the wrapped `InstantPageAudioNode` supplies its own 17pt internal content inset. See the "InstantPage V2 audio/music" section below.)

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `instantPageV2MediaFrame(naturalSize:flush:cornerRadius:boundingWidth:horizontalInset:)` — the shared frame helper; `instantPageV2MediaEdgeBleed` constant; the `flush: Bool` parameter on `layoutTypedMediaWithCaption` (image/video/webEmbed-cover/map) and `layoutMediaWithCaption` (webEmbed-placeholder/postEmbed/channelBanner/relatedArticles). (Collage/slideshow and **audio** no longer route through these — see their dedicated sections.) |
| `submodules/InstantPageUI/Sources/InstantPageV2MediaViews.swift`, `…/InstantPageRenderer.swift` (`InstantPageV2MediaPlaceholderView`) | Renderer — **no change needed**: every media view + the placeholder view already does `clipsToBounds = item.cornerRadius > 0.0`, so cornerRadius 0 means the view doesn't self-clip; the bubble's `containerNode` clips. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | The clipping container: `containerNode` (`clipsToBounds = true`, `cornerRadius = layoutConstants.image.defaultCornerRadius` ≈ 15–16pt) is what rounds flush media at the bubble edge. |

### Non-obvious invariants

- **`flush` is a parameter, not inferred from cornerRadius.** **Every** remaining media call site now passes `flush: true`. Audio — the former lone `flush: false` caller — was moved to its own `layoutAudio` arm in the V2 audio port, so `instantPageV2MediaFrame`'s `flush == false` branch is now **dead code** (a candidate for a follow-up cleanup: drop the `flush` parameter and the inset branch entirely). On the flush path the helper forces the returned corner radius to `0` regardless of the caller's `cornerRadius` argument (the legacy `8.0`/`0.0` args at the call sites are now inert — kept as-is, documented in the helper).
- **Small images are NOT upscaled.** The `scale = min(availableWidth / naturalSize.width, 1.0)` cap is kept (now against `availableWidth = boundingWidth`). A small image stays at natural size, **flush-left at x = 0** (not stretched to full width). Large images (the common server/AI case) fill the width.
- **Full-width media bleeds `instantPageV2MediaEdgeBleed` (4pt) past the trailing edge.** The pageView sits at `x: -1` inside `containerNode` (a border-hiding hairline), so a frame at `x: 0, width: boundingWidth` falls ~1px short of the container's right rounded-clip edge → a 1px corner notch. A small over-bleed on **full-width** items only (`fillsWidth = scaledSize.width >= availableWidth - 1.0`) closes it; a genuinely small image gets no bleed. **The bleed never widens the bubble** because `layoutInstantPageV2` clamps `contentSize.width = min(maxX, boundingWidth)` (gated by `context.fitToWidth`, which both callers — the rich bubble and the send preview — pass `true`).
- **Captions stay inset.** `layoutCaptionAndCredit` is still called with the page `horizontalInset` and offset by the **un-bled** `scaledSize.height`; the caption/credit text is inset under a full-bleed image. The `isCover && captionHeight > 0` cover-padding block is unchanged.
- **Audio is no longer routed through this helper.** As of the V2 audio port it has a dedicated `layoutAudio` arm emitting a typed `.mediaAudio` item at a full-width (x = 0), height-48 frame (matching V1 `InstantPageLayout.swift`); the wrapped `InstantPageAudioNode` self-insets its content by 17pt, and audio does **not** participate in `instantPageV2MediaEdgeBleed` (its node background is transparent). See the dedicated "InstantPage V2 audio/music" section below.
- **`.map` blocks get a 600×300 (2:1) fallback when the sender omits dimensions.** AI/server-sent `.map` blocks can arrive with `dimensions == 0×0` (the wire `w`/`h` are *required* `Int32`, but the sender may put 0; our `pageBlockMap` parse and both serializers — Postbox `sw`/`sh`, FlatBuffers `required dimensions` — preserve whatever arrives, so the zero originates upstream). A zero `naturalSize.height` hits `instantPageV2MediaFrame`'s `else` branch and returns a **height-0** frame: the map collapses to no space, the caption slides up into it, and the V1 node's pin (positioned at `size.height*0.5 − 10 − pinSize/2`) floats over the caption. **The `.map` arm in `InstantPageV2Layout.swift` substitutes `PixelDimensions(600, 300)` whenever `width <= 0 || height <= 0`, and feeds that `effectiveDimensions` to BOTH the layout `naturalSize` AND the `InstantPageMapAttribute`** — the latter is essential because a `MapSnapshotMediaResource(width:0,height:0)` makes `MKMapSnapshotter` render nothing, so fixing only the frame would yield a correctly-sized *blank* box. Real web-article maps (the V1 renderer) always carry real dimensions, so V1 never trips this; the fallback is deliberately scoped to the V2 `.map` arm rather than V1 or the wire/parse layer.
- **`.map` blocks show a theme placeholder while the snapshot loads (2026-06-27).** The map image is generated on-demand by `MKMapSnapshotter` (`chatMapSnapshotImage` → `chatMapSnapshotData` self-fetches via `engine.resources.custom`), which takes ~seconds; the pin (`ChatMessageLiveLocationPositionNode`) draws immediately, so the map area was **blank (pin over transparent)** until the fetch completed. `InstantPageImageNode.layout()`'s `.geo` arm now passes `emptyColor: theme.list.mediaPlaceholderColor`, and `chatMapSnapshotImage` emits an **initial `nil`** frame that fills `emptyColor` when there's no image yet — **corner-safe** (`addCorners` runs after the fill, unlike a node `backgroundColor` which would bleed past rounded corners) and **gated on `emptyColor`** so callers that don't opt in keep the prior transparent loading state. Shared, so it applies to every map render: web instant pages, rich messages, AND the RichTextEditor's own **`.location` blocks**, which now author `.map` (`MediaKind.location` → `.map`; see `richtext-composer.md`).

## InstantPage V2 audio/music

`InstantPageBlock.audio` renders in V2 as a control **styled exactly like the standard music message bubble** (`ChatMessageInteractiveFileNode`'s music layout) — a dedicated `InstantPageV2AudioContentNode`, NOT the V1 `InstantPageAudioNode` (which V2 used in the first iteration and which still backs V1's full-page Instant View). It replaces the earlier inert grey `.mediaPlaceholder(kind: .audio)`. Playback stays on `InstantPageMediaPlaylist`, with two deliberate behavior changes for the rich-message context: the shared playlist identity is **message-scoped** so concurrent rich-message audio bubbles don't collide, and rich-message audio files are fetched via a **message reference** (not the synthesized webpage) so a stale file reference can revalidate.

Specs: [`2026-06-02-instantpage-v2-audio-design.md`](docs/superpowers/specs/2026-06-02-instantpage-v2-audio-design.md) (initial port) + [`2026-06-02-instantpage-v2-audio-file-style-design.md`](docs/superpowers/specs/2026-06-02-instantpage-v2-audio-file-style-design.md) (file-bubble styling). Plans: [`2026-06-02-instantpage-v2-audio.md`](docs/superpowers/plans/2026-06-02-instantpage-v2-audio.md) + [`2026-06-02-instantpage-v2-audio-file-style.md`](docs/superpowers/plans/2026-06-02-instantpage-v2-audio-file-style.md).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageMediaPlaylist.swift` | `InstantPageMediaPlaylistId` is a **public enum** — `.instantPage(webpageId:)` (V1 full-page IV) / `.richMessage(messageId:)` (V2 rich bubble). `InstantPageMediaPlaylist.init` takes an injected `playlistId:` (no longer derived from the webpage) and a `messageReference: MessageReference?` threaded into each `InstantPageMediaPlaylistItem`. The item's `fileReference(_:)` helper builds a `.message(message:media:)` file reference when a (resolvable-id) message reference is present, else the legacy `.webPage(...)`. |
| `submodules/InstantPageUI/Sources/InstantPageV2AudioContentNode.swift` | **The V2 control** — replicates `ChatMessageInteractiveFileNode`'s music layout: a Ø44 `SemanticStatusNode` (album art via `playerAlbumArt` + play/pause) + a small bottom-right `streamingStatusNode` download/progress overlay + title/performer `TextNode`s + a line `MediaPlayerScrubbingNode`. Big control play/pause from **our** `filteredPlaylistState`; small overlay download/progress from `messageMediaFileStatus`; tap via a `UITapGestureRecognizer` (`controlTapped` routes fetch / `play` / `togglePlayPause`); fetch via `messageMediaFileInteractiveFetched(fetchManager:…)`. |
| `submodules/InstantPageUI/Sources/InstantPageAudioNode.swift` | **V1 only** (full-page Instant View) — unchanged except `init` takes an injected `playlistId:`. No longer used by V2. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `InstantPageV2MediaAudioItem` (frame/media/webPage — no cornerRadius/attributes); the `.mediaAudio` `InstantPageV2LaidOutItem` case + its `frame`/`offsetBy`/`collectMedias` arms; the `.audio` block's `layoutAudio` arm (full-width x = 0, height 44 — the file node's music `normHeight`; the `InstantPageMedia` carries `caption: nil`/`credit: nil`, the visible caption is a separate item via `layoutCaptionAndCredit`). |
| `submodules/InstantPageUI/Sources/InstantPageV2MediaViews.swift` | `InstantPageV2MediaAudioView` (hosts `InstantPageV2AudioContentNode` via the shared `WrapperRef` weak-box pattern; wires its `play`/`togglePlayPause`/`seek`/`fetch` closures + the `filteredPlaylistState` playback signal) + `handleOpenAudioTap` (builds the playlist + `setPlaylist`, mirroring V1's `InstantPageControllerNode.openMedia`). |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2RenderContext.message: MessageReference?` (carries both the playlist-key id via `.id` AND the file-fetch reference); the `.mediaAudio` arms in `stableId`/`reuse`/`makeItemView`. |
| `submodules/InstantPageUI/Sources/InstantPageV2RevealCost.swift` | `.mediaAudio` is a non-text reveal entry charging `frame.width` (like other media). |
| `submodules/TelegramCore/Sources/Network/FetchedMediaResource.swift` | The `.message` media-reference revalidation arm also searches `RichTextMessageAttribute.instantPage.media` (not just `message.media`), so a stale instant-page file reference inside a rich message can recover. |
| rich bubble + send preview | `ChatMessageRichDataBubbleContentNode` passes `message: MessageReference(item.message)`; `ChatSendMessageRichTextPreview` passes `message: nil`. |

### Non-obvious invariants

- **The playlist key is message-scoped, NOT webpage-scoped, for rich bubbles.** Every rich message synthesizes its `TelegramMediaWebpage` with the SAME constant id `(namespace: 0, id: 0)` (`ChatMessageRichDataBubbleContentNode`), and `mediaIndex` restarts at 0 per page — so keying playback by `(webpageId, mediaIndex)` (V1's scheme) would make two audio bubbles on screen share/fight playback state (scrubber + play/pause icon). The discriminated `InstantPageMediaPlaylistId.richMessage(messageId)` isolates them. The audio view resolves `renderContext.message?.id` → `.richMessage(messageId)`, else `.instantPage(webpageId:)`; the send preview (no message) takes the webpage fallback — harmless since only one preview is ever on screen. The V1 full-page IV path is byte-identical (always `.instantPage(...)`).
- **`InstantPageMediaPlaylistId` had to become `public`.** It is exposed through `InstantPageMediaPlaylist`'s `public init`, which BrowserUI constructs cross-module; an internal type in a public initializer is a hard Swift compile error (independent of `-warnings-as-errors`). This surfaced only at full-build time — the per-module reasoning didn't catch it.
- **The big control's play/pause comes from OUR playlist, the small overlay's download/progress from the resource status — two separate signals.** The file node (`ChatMessageInteractiveFileNode`) for music keys its play/pause off the **peer-messages** playback model (`messageFileMediaPlaybackStatus` → `peerMessagesMediaPlaylistAndItemId`), which our attribute-embedded audio is NOT part of — so `InstantPageV2AudioContentNode` drives the big `statusNode` `.play`↔`.pause` from **our** `filteredPlaylistState` (keyed by the message-scoped `playlistId` + `InstantPageMediaPlaylistItemId(index:)`) and the small `streamingStatusNode` from `messageMediaFileStatus`. This split (rather than reusing the file node) is why the redesign is a replicated layout, not a hosted `ChatMessageInteractiveFileNode`.
- **Fetch MUST go through the fetch manager, not `freeMediaFileInteractiveFetched`.** `messageMediaFileStatus`'s progress (`.Fetching`) is derived from the fetch manager's `hasEntry` flag; `freeMediaFileInteractiveFetched` bypasses the manager (`hasEntry` stays false), so the overlay would stick on the static download icon and never show the animated ring. The control fetches via `messageMediaFileInteractiveFetched(fetchManager:messageId:messageReference:file:…)`.
- **Tap is a `UITapGestureRecognizer`, never an ASControl** (same invariant as the V1 `InstantPageAudioNode` play button): ASControl `.touchUpInside` is cancelled by the chat `ListView`'s gesture system. The plain `tapView` covers the whole control → `controlTapped` (fetch-when-remote / `togglePlayPause`-when-playing / `play`-else).
- **`InstantPageV2AudioContentNode.updatePresentationData` must refresh EVERYTHING theme/incoming-dependent.** `TextNode` (unlike `ASTextNode`) has no stored `attributedText` — the strings live in `titleAttributedString`/`descriptionAttributedString` and are fed to `TextNode.asyncLayout`. On an in-place theme/direction change `updatePresentationData` rebuilds those strings AND `statusNode.backgroundNodeColor` + `foregroundNodeColor` + `overlayForegroundNodeColor` + `scrubbingNode.updateColors(…)`; missing any leaves a stale-colored control. Font size is `presentationData.chatFontSize.baseDisplaySize` (plain `PresentationData` has no `.fontSize`).
- **Audio is NOT a gallery item.** `InstantPageV2MediaAudioView` does not register in the root media registry (no `didMoveToWindow`/`registerInRootRegistry`) and returns `nil` from `instantPageTransitionNode` / no-ops `instantPageUpdateHiddenMedia` — explicit per-class witnesses, not the protocol-extension default. Its media IS enrolled in `collectMedias`/`allMedias()` so `handleOpenAudioTap` can gather the page's sibling voice/music files for the playlist (matching V1's `mediasFromItems`). The `WrapperRef` weak box breaks the wrapper → node → closure → wrapper retain cycle (the `play` closure captures only the box + value locals, never `self`).
- **Full-width item frame, file-node internal layout.** The `.audio` arm lays the item at `x = 0, width = boundingWidth, height = 44` (the file node's music `normHeight`), NOT inset by `horizontalInset`. The control's internal geometry is copied from the file node's non-thumbnail music branch (Ø44 control at x = 3, `controlAreaWidth = 55`, title at x = 55). Music-only: any voice file renders music-style (no waveform/transcription). No edge-bleed.
- **Audio files fetch via a message reference (the former recipient-fetch risk is resolved).** `InstantPageMediaPlaylistItem.fileReference(_:)` builds `.message(message: messageReference, media: file)` when the playlist carries a **resolvable-id** `MessageReference` (rich bubbles), else the legacy `.webPage(...)` (V1 full-page IV, whose webpage is real). The fetch-reference fallback uses the same `message?.id != nil` test as the playlist-key fallback, so a `.none`-content reference degrades to the webpage path consistently. Because the rich-message file lives in `RichTextMessageAttribute.instantPage.media` (not `message.media`), `FetchedMediaResource.swift`'s `.message` revalidation arm was taught to search the attribute's instant page too — so a **stale** file reference can re-fetch the message and recover (a synthetic-`(0,0)`-webpage reference never could, because that webpage doesn't exist server-side). This also fixes a latent pre-existing bug: instant-page **image** references in rich messages couldn't revalidate either.
- **Fixed a dormant inverted `InstantPagePlaylistLocation.isEqual`** (it returned `false` for equal locations and `true` for unequal — backwards). `areSharedMediaPlaylistsEqual` ANDs the playlist `id` and `location`; it gates only seek-forwarding inside `setPlaylist`, a path the instant-page audio scrubber doesn't take (it uses `playlistControl(.seek)`), so the bug was inert. The corrected equality is safe even though all rich-message locations share the synthetic `(0,0)` webpageId: the `.richMessage(messageId)` **id** (ANDed in) disambiguates different rich-message playlists.

## InstantPage V2 collage & slideshow blocks

`InstantPageBlock.collage` and `.slideshow` (grouped photos/videos with a caption) render in V2 by porting V1. Collage flattens into the existing media-item machinery; slideshow is a dedicated interactive carousel.

**`.collage` is no longer web-IV-only (added 2026-07-08).** The RichText editor's multi-media containers
(a `MediaBlock`/`ChatInputMedia` holding `items.count >= 2` photos/videos with one shared caption — see
`docs/richtext-composer.md` §4 "Inline media") now also emit `.collage` on send/edit/draft, from both the
composer (`ChatInputContentInstantPage`) and the article editor (`RichTextEditorMessageConversion`'s
`InstantPageBuilder`) converters — the first editor/rich-message path to produce a `.collage` block
(needed zero codec work; it was already first-class through Postbox/FlatBuffers/upload). A container of
exactly 1 item still sends the plain `.image`/`.video` block, byte-identical to before.

**`.slideshow` is now editor-produced too (added 2026-07-17).** A multi-media container carries a
`displayMode` (`.mosaic` default / `.slideshow`; mirrored `MediaBlock.displayMode` ↔
`ChatInputMedia.displayMode`, Codable back-compat → `.mosaic`). Both forward converters branch on it:
`.mosaic → .collage`, `.slideshow → .slideshow` (same inner `.image`/`.video` blocks); the reverse
`chatInputBlocks(fromInstantPageBlocks:)` gained a `.slideshow` arm (sharing the collage arm's item
helper) so the mode round-trips on edit. The mode is toggled in the **article editor** via a top-right
button (mosaic↔slideshow); the composer stays mosaic-only. So `.slideshow` is now produced both by real
web Instant View articles and by editor-authored slideshow albums. Design + plan:
`docs/superpowers/{specs,plans}/2026-07-17-richtext-media-layout-toggle*`.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `layoutCollage(...)` — mosaic via `chatMessageBubbleMosaicLayout` (the `MosaicLayout` module, same engine grouped messages use), emitting one existing `.mediaImage`/`.mediaVideo` item per cell. `layoutSlideshow(...)` + the `InstantPageV2SlideshowItem` laid-out item (+ its `frame`/`offsetBy`/`collectMedias` arms). |
| `submodules/InstantPageUI/Sources/InstantPageV2SlideshowView.swift` | The carousel view: a paged `UIScrollView` of `InstantPageImageNode` pages + a `PageControlNode`, with all pages created **eagerly**. |
| `…/InstantPageRenderer.swift` | `InstantPageItemView.instantPageTransitionNode(for:)` / `instantPageUpdateHiddenMedia(_:)` (gallery hooks, nil/no-op defaults); `transitionArgsFor`/`applyHiddenMedia` dispatch through them. The `.slideshow` arms in `InstantPageV2ItemKind`/`stableId`/`reuse`/`makeItemView`. |
| `…/InstantPageV2RevealCost.swift` | `.slideshow` is a non-text reveal entry (collage cells already are, being top-level media items). |

### Non-obvious invariants

- **Collage is a flatten, not a container.** `layoutCollage` computes the mosaic, then emits each cell as an ordinary top-level `.mediaImage`/`.mediaVideo` item (cornerRadius 0) into the parent layout — exactly as V1 does (`flattenedItemsWithOrigin`). Consequence: gallery enumeration (`allMedias`), the media registry, hidden-media, the reveal-cost map, and view reuse all handle collage cells **for free**, with no collage-specific code in any of those subsystems. There is **no** `.collage` laid-out item or view.
- **Right-edge collage cells bleed 4pt** (`instantPageV2MediaEdgeBleed`, applied only to `MosaicItemPosition.right` cells) for the same bubble-rounded-clip reason as full-width single media; interior gaps are the mosaic's 1pt spacing; outer corners are rounded by the bubble's `containerNode`.
- **A collage with an undecodable item is not laid out as a collage at all** (2026-08-18). The
  `.collage` arm of `layoutBlock` checks `blockRendersAsUnsupported(_:)` first and returns the
  "please update" pill for the whole block, caption included — a mosaic reserves a slot per inner
  block but emits a cell only per *resolvable* one, so an `.unsupported` item would leave a hole and
  shift the remaining tiles. `.slideshow` is deliberately excluded (it degrades quietly instead).
  See "Unsupported blocks" below for the predicate and its other two readers.
- **Slideshow IS a container** (it's swipeable), so it gets its own laid-out item + view, unlike collage. Adding the `.slideshow` case to `InstantPageV2LaidOutItem` forces a `.slideshow` arm in every no-`default` switch over it: `frame`, `offsetBy`, `stableId`, `reuse`, `makeItemView`, and the reveal-cost `computeEntries` (plus `collectMedias`, which has a `default` but needs the arm to enumerate slideshow medias for the gallery).
- **Slideshow pages are created eagerly, deviating from V1's lazy central±1 paging.** In a chat bubble a slideshow is a handful of images, so eager creation avoids V1's index bookkeeping and makes the gallery transition source available for **every** page (even off-screen). Height = the tallest image `fitted(boundingWidth × 1200)`; only `.image` inner blocks render (matches V1 — videos become empty pages).
- **The slideshow registers under EVERY contained media index, and re-registers on an in-window rebuild.** Its stableId is positional (`.positional(.slideshow, position)`, not `.media(index)` like the static media views), so it can be reused for a *different* slideshow at the same block position; `rebuildPages()` re-runs `registerMedias()` (guarded by `window != nil`) so the new indices land in the registry. The gallery hooks iterate the live page nodes and match by `InstantPageMedia` identity, so registering one view under N indices is idempotent.
- **The 4 static media views answer the gallery hooks with explicit per-class witnesses, NOT a shared protocol-extension override** — an extension-only implementation is statically dispatched and would silently bind to the nil default when invoked through the `InstantPageItemView`-typed registry wrapper.

## InstantPage V2 media spoiler (revealable dust)

A `pageBlockPhoto`/`pageBlockVideo` (and thus a collage cell) can carry a **spoiler** flag — the medium is
hidden behind an animated "dust" cover until the recipient taps it, mirroring the regular
`MediaSpoilerMessageAttribute` path in `ChatMessageInteractiveMediaNode`. This is how a rich message
(`RichTextMessageAttribute` → InstantPage) carries a media spoiler; the composer-authoring side is in
`docs/richtext-composer.md` §4.

### Where things live

| Concern | Location |
|---|---|
| model flag | `InstantPageBlock.image`/`.video` gain `spoiler: Bool` (`SyncCore_InstantPage.swift`); Postbox key `"sp"`, flatBuffers `Models/InstantPageBlock.fbs` `spoiler:bool (id:4)` |
| wire | `ApiUtils/InstantPage.swift` reads/ORs `pageBlockPhoto` `flags.1` / `pageBlockVideo` `flags.2` — **no `TelegramApi` change** (the bit rides the existing `flags` Int32; constructor ids `1759c560`/`7c8fe7b6` unchanged) |
| laid-out item | `InstantPageV2MediaImageItem`/`VideoItem` gain `spoiler: Bool` (`InstantPageV2Layout.swift`); single-media + collage item-constructing cases thread it |
| render | `InstantPageV2MediaViews.swift` — `MediaSpoilerDustOverlay` hosts a `MediaDustNode` (import `InvisibleInkDustNode`) in both `InstantPageV2MediaImageView`/`VideoView` |

### Non-obvious invariants

- **The dust cover is NON-interactive; reveal is driven through the wrapped node's own tap.** The overlay
  (`containerNode` + `dustNode`) is `isUserInteractionEnabled = false`, so taps fall through to the sibling
  `InstantPageImageNode` below it. Each view's `openMedia` closure is **gated**: while `overlay.concealed`,
  the first tap calls `overlay.reveal()` (which sets `concealed = false` synchronously and drives
  `MediaDustNode.tap(at:)` → the wipe animation → the `revealed` callback removes the cover) and returns
  **without** opening the gallery; once revealed, taps fall through to `handleOpenMediaTap` (gallery). This
  mirrors `ExtendedMediaOverlayNode.reveal(animated:)` but with a non-interactive cover instead of an
  interactive button.
- **Reuse resets reveal state by media id.** A positionally-reused media view (`stableId = .media(index)`,
  reconciled through `update(item:)` → `updateSpoiler`) keyed on `EngineMedia.Id`: a different id or
  `spoiler == false` tears down the cover; the same spoiler medium keeps its (possibly already-revealed)
  state — so scrolling can't bleed a stale reveal onto a different photo, and a re-layout of the same photo
  doesn't re-hide it. **No `InstantPageRenderer.reuse(existingView:)` change** was needed — it already routes
  through `update(item:)`.
- **Collage cells inherit spoiler for free.** `layoutCollage` flattens inner `.image`/`.video` into ordinary
  top-level `.mediaImage`/`.mediaVideo` items (see the collage section above), threading each inner block's
  `spoiler` — so an album with one spoiler cell just works, with no collage-specific spoiler code.
- **The long-press-Send options preview** renders through the same `InstantPageV2View`, so a spoiler'd media
  shows the dust cover in the preview bubble automatically.

## InstantPage V2 rich-message video (auto-download & inline autoplay)

Video block media in a **rich message** (`RichTextMessageAttribute` → InstantPage V2, drawn by
`ChatMessageRichDataBubbleContentNode`) now auto-downloads and auto-plays inline like regular chat
media (`ChatMessageInteractiveMediaNode`) — previously it was a static poster + play glyph that only
downloaded/played on tap-to-gallery, and image auto-download ignored per-message settings. The fix is
**layering-safe**: it lives entirely in `InstantPageUI` + the chat bubble, with **no** dependency on
`ChatMessageInteractiveMediaNode` (that would invert the module layering — `InstantPageUI` is a
low-level module also used by web Instant View / `BrowserUI`). HLS inline-range preloading and
live-photo are deliberately **out of scope** (they fall back to tap-to-gallery).

Spec: [`docs/superpowers/specs/2026-07-09-instantpage-v2-video-autodownload-autoplay-design.md`](docs/superpowers/specs/2026-07-09-instantpage-v2-video-autodownload-autoplay-design.md).
Plan: [`docs/superpowers/plans/2026-07-09-instantpage-v2-video-autodownload-autoplay.md`](docs/superpowers/plans/2026-07-09-instantpage-v2-video-autodownload-autoplay.md).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2RenderContext` gains 3 policy closures — `shouldAutoDownloadImage`/`shouldAutoDownloadFile`/`shouldAutoplayVideo` (all default `{ _ in false }`). `InstantPageItemView` gains `instantPageUpdateIsVisible(_:)` (default no-op), driven by `updateItemVisibility()` on every `visibilityRect` change (alongside `updateEmojiVisibility`). |
| `submodules/InstantPageUI/Sources/InstantPageImageNode.swift` | `init` gains optional `autoDownloadImage`/`autoDownloadFile` overrides (default `nil` ⇒ current V1/web-IV global-settings behavior); the image + image-file fetch gates consult them. The video (`else`) branch stays poster-only. |
| `submodules/InstantPageUI/Sources/InstantPageV2MediaViews.swift` | `makeMediaWrapper` forwards the two download overrides. `InstantPageV2MediaVideoView` hosts an inline `UniversalVideoNode`/`NativeVideoContent` (`updateInlineVideo`/`tearDownVideoNode`) layered above the poster. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | Computes the 3 closures from the chat item and sets a real `sourceLocation`. |
| `ChatSendMessageRichTextPreview.swift` | Unchanged — keeps the defaults (`message: nil` + off closures) → static poster. |

### Non-obvious invariants

- **Policy is computed in the bubble, consumed as booleans in `InstantPageUI`.** The bubble has the
  chat item, so it computes download via `shouldDownloadMediaAutomatically(settings:
  item.controllerInteraction.automaticMediaDownloadSettings, peerType:
  associatedData.automaticDownloadPeerType, networkType: …automaticDownloadNetworkType, authorPeerId:
  message.author?.id, contactsPeerIds: …, media:)` and autoplay via `(file.isAnimated ?
  energyUsageSettings.autoplayGif : .autoplayVideo) && completedResourcePath(file) != nil`.
  `InstantPageUI` never learns chat semantics — it just calls the closures. The closure types mirror the
  existing `imageReference`/`fileReference` split (concrete `TelegramCore` types) because `EngineMedia`'s
  wrap/unwrap helpers are `internal` to `TelegramCore`.
- **The inline player must be framed to the aspect-FITTED rect, not to `bounds`.** `instantPageV2MediaFrame`
  caps a portrait item's height at its display width, so the box deliberately stops matching the media
  aspect; the poster (`wrappedNode`) compensates by rendering aspect-fit over a blurred backdrop. The
  `UniversalVideoNode` is layered ABOVE that poster, so sizing it to `self.bounds` squashed the video into
  the capped box *and* hid the blurred backdrop — a portrait video rendered square and stretched while
  images did not. `InstantPageV2MediaVideoView.inlineVideoFrame(in:)` now centres the player on the same
  fitted rect the poster uses. It is gated on `item.fit`, which **only single media sets** — collage cells
  construct the item without it and keep filling their bounds, preserving mosaic crop-to-fill and the
  1pt-bleed clipping documented at the construction site.
- **Video content id MUST be message-scoped, not webpage-scoped.** Every rich message synthesizes the
  same webpage id `(0,0)`, so keying the player by webpage would make two on-screen rich-message videos
  collide in the universal video manager. `InstantPageV2MediaVideoView` uses the existing
  `NativeVideoContentId.message(UInt32(bitPattern: messageId.id), file.fileId)` — same trap the V2 audio
  port hit (`.richMessage(messageId)`). The inline player is only built when `renderContext.message?.id`
  exists, so the send-preview (nil message) never needs one.
- **Visibility gating has no dead-attach window.** The player's `canAttachContent` is toggled by
  `instantPageUpdateIsVisible` (from the root's `visibilityRect` → `updateItemVisibility`). A player
  built *before* the first visibility tick starts with `canAttachContent = false`, but first display
  always flips `visibilityRect` nil→rect (a *change*) → the tick attaches it. A player built on a *later*
  update (e.g. after a fetch completes, with no visibility change) is seeded `canAttachContent =
  self.localIsVisible`, which is already true for an on-screen view. Both orderings attach.
- **Auto-download is decoupled from autoplay (fixes the "never downloads" gap).** When
  `shouldAutoDownloadFile(file)` is true the video bytes are fetched (once per media id, via
  `freeMediaFileInteractiveFetched` with the render-context `.message` `fileReference`) **even if
  autoplay is off** — so a rich-message video prefetches per settings instead of only on tap.
  `videoFetchMediaId` dedups; the `MetaDisposable` `set()` cancels a stale fetch on media switch and is
  disposed in `deinit`.
- **Reuse & spoiler.** Positional reuse keeps the player only when `videoNodeMediaId == mediaId`
  (else teardown + rebuild); a concealed spoiler cover suppresses the player (`wantAutoplay =
  shouldAutoplayVideo && !concealed`), and the spoiler reveal path re-runs `updateInlineVideo` so
  autoplay starts after the dust clears. Gallery transition hides the player via
  `instantPageUpdateHiddenMedia`.
- **Collage cells inherit this for free** — `.collage` flattens into ordinary `.mediaVideo` items, so
  each cell is an `InstantPageV2MediaVideoView` with no collage-specific code.

## Copy protection (screenshot-protected rich-message media & secure gallery)

Media in a **rich message** honors the chat's copy protection the way regular media does
(`ChatMessageInteractiveMediaNode`'s `captureProtected`): every rendered image/video/thumbnail layer
is excluded from screenshots and screen recordings via `setLayerDisableScreenshots`, and tapping one
opens a **secure** `InstantPageGalleryController` — protected content, no share / save-to-camera-roll.
V1 Instant View and web IV are untouched (their pages are public web content), and so is the send
preview.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2RenderContext.captureProtected` (default `false`) + `updateCaptureProtected(_:)`. `updateInlineImages()` seeds and refreshes each `InstantPageV2InlineImageView`. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | `isCaptureProtected(item:)` = `associatedData.isCopyProtectionEnabled \|\| message.isCopyProtected()`; passed to the render-context initializer and refreshed at the top of `ensurePageView` on every apply. |
| `submodules/InstantPageUI/Sources/InstantPageImageNode.swift` | `captureProtected` drives the inner `TransformImageNode` and the (weakly tracked) spoiler blur node; `transitionNode(media:)` does the protected-snapshot dance. |
| `submodules/InstantPageUI/Sources/InstantPageV2MediaViews.swift` | `makeMediaWrapper` seeds it; the image/video/map/cover views re-read it in `update(item:theme:renderContext:)`; the inline autoplay `NativeVideoContent` takes `captureProtected:`; `handleOpenMediaTap` forwards it to the gallery. |
| `InstantPageV2SlideshowView.swift`, `InstantPageV2DocumentContentNode.swift`, `InstantPageV2InlineImageView.swift` | Slideshow pages, the document row's thumbnail, and inline `RichText.image` cells. |
| `InstantPageMediaOpen.swift` → `InstantPageGalleryController.swift` → `InstantImageGalleryItem.swift` | `captureProtected` threads to each gallery entry: protected zoomable image node, `NativeVideoContent(captureProtected:)`, and `setShareMedia(nil)` to withhold the footer action button. |

### Non-obvious invariants

- **The flag is mutable state on the render context, not a constructor snapshot.**
  `isCopyProtectionEnabled` is a *peer* setting that can be toggled while the message is on screen.
  That changes neither the webpage nor the page layout, so nothing rebuilds the V2View — the bubble
  refreshes the context up front in `ensurePageView` (ahead of every reuse branch, including the two
  early returns) and each media view re-reads it in its own `update(…)`. Seeding it only at
  construction leaves an on-screen message unprotected until it is scroll-recycled.
- **A capture-protected layer is excluded from `snapshotContentTree` too.** So the gallery
  open/close animation would fly a blank rect. `InstantPageImageNode.transitionNode(media:)` mirrors
  `ChatMessageInteractiveMediaNode.transitionNode(adjustRect:)`: add an **unprotected** `UIImageView`
  copy of `imageNode.image` over the protected node, snapshot, remove the stand-in, then
  `setLayerDisableScreenshots` the resulting snapshot so the transition itself stays uncapturable.
- **A concealed spoiler must be protected as well.** The blur cover is a sibling `TransformImageNode`
  the enclosing view owns (`makeSpoilerBlurredNode()`), not a child of the sharp node, so protecting
  the sharp node alone leaves a screenshot of the blurred cover — enough to read the media's shape.
  `InstantPageImageNode` keeps a weak reference to the node it vends and keeps the two in sync.
- **`NativeVideoContent` takes `captureProtected` at construction**, so a toggle has to *rebuild* the
  inline player. `InstantPageV2MediaVideoView` therefore tracks `videoNodeCaptureProtected` alongside
  `videoNodeMediaId` and includes it in the "player is still current" early-out.
- **The video gallery's footer needs no gating.** `InstantPageGalleryEntry.item` passes
  `originData: nil`, and `ChatItemGalleryFooterContentNode.setup(origin:caption:)` zeroes its whole
  `buttonsState` when origin is nil — so no share button exists on that path to begin with. Only the
  image path (`InstantPageGalleryFooterContentNode`) needed `setShareMedia(nil)`.
- **Document blocks were already covered.** Tapping one routes through
  `openMessage(…, mediaSubject: .richTextMedia(fileId))` → the chat's `GalleryController`, which
  derives protection from the message itself. Only the row's *thumbnail* is protected in the bubble;
  the file name/size text is metadata, and the regular chat file bubble does not protect its label
  either.
- **`InstantPageUI` gained a direct `UIKitRuntimeUtils` dep** (for `setLayerDisableScreenshots`);
  everything else reaches protection through `TransformImageNode.captureProtected`.

## InstantPage V2 text item height (true font line box)

`layoutTextItem` (`InstantPageV2Layout.swift`) sizes a `.text` item to the **true font line height**, not the cap box. A single-line item measures exactly `fontAscent + fontDescentBelowBaseline` (`A + D`); the old behavior was the cap box `fontLineHeight = floor(fontAscent + fontDescent)` (`A − D`).

### Non-obvious invariants

- **Two edits in `layoutTextItem`:** the line stack starts at `lineBoxTopInset = max(0, fontAscent − fontLineHeight)` (was `0`), and the returned height is `lines.last.frame.maxY + extraDescent + fontDescentBelowBaseline` (the `+ fontDescentBelowBaseline` contains the last line's descender). Net: every text item grows ~`(A − L) + D` (~8pt @17pt) and its glyphs draw ~`lineBoxTopInset` (~4pt) lower within their box; the page grows.
- **Per-line frames stay the cap box** (`height = lineAscent = fontLineHeight`). Only the stack's starting origin moves and the total is padded — so the baseline is still drawn at each line frame's `maxY`, inter-line advance (`lineAscent + fontLineSpacing + extraDescent`) is unchanged, and decorations / inline attachments / `characterRect` / the reveal mask (all line-frame-relative) translate consistently.
- **`lineBoxTopInset` is exact, NOT pixel-snapped** — it is an intra-item line offset; crispness rides on the item's own pixel-snapped frame origin (intra-item line positions may already be fractional, e.g. after a non-integral `extraDescent`).
- **Formulas / tall inline content still inflate** via `lineAscent`/`extraDescent`; the `"\u{200b}"`+anchors `height = 0` case is preserved.
- **Inline custom emoji are sized to ≈ the line box** so they fit the taller box rather than overflowing it (see "Inline custom emoji").

## Inline custom emoji (RichText.textCustomEmoji)

`RichText.textCustomEmoji(fileId:alt:)` renders an inline **animated** custom emoji inside rich-data bubbles. Covers API parsing, Postbox + FlatBuffers serialization, and display in the InstantPage V2 renderer; the emoji participates in the streaming reveal above. (The **send / edit / copy / paste** round-trip that produces `.textCustomEmoji` from typed markdown is a separate section below: "Custom emoji in markdown messages".)

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_RichText.swift` | Enum case `textCustomEmoji(fileId: Int64, alt: String)` + Postbox coding (discriminator 17, keys `ce.f`/`ce.a`), `==`, `plainText` (returns `alt`), and FlatBuffers codec. |
| `submodules/TelegramCore/FlatSerialization/Models/RichText.fbs` | FlatBuffers schema — `RichText_CustomEmoji` union member + table. **Source of truth**; the Bazel `flatc` genrule regenerates `*_generated.swift` at build time (the checked-in `Sources/*_generated.swift` is stale). |
| `submodules/TelegramCore/Sources/ApiUtils/RichText.swift` | `Api.RichText.textCustomEmoji` ⇄ Swift, lossless both ways. |
| `submodules/InstantPageUI/Sources/InstantPageTextItem.swift` (`attributedStringForRichText`) | Emits a single placeholder char carrying `ChatTextInputAttributes.customEmoji` (a `ChatTextInputTextCustomEmojiAttribute`) + a `CTRunDelegate` sized to the font line height (`font.ascender − font.descender + 4·pointSize/17` ≈ 24pt @17pt). |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` (line-breaker) | Collects per-line `InstantPageTextLine.emojiItems`; overwrites each placeholder char's `characterRect` with a full cell (`width = itemSize`) so it feeds the reveal cost map. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` (`InstantPageV2View`) | Owns the `InlineStickerItemLayer`s: `updateInlineEmoji` (create/reuse/remove/position), `updateEmojiReveal` (reveal-driven pop-in), `updateEmojiVisibility` + `propagateVisibilityRect`. Layers attach to each text view's `emojiContainerView`. |

### Non-obvious invariants

- **flatc casing/`required` gotchas.** Edit `RichText.fbs`, not the generated Swift. Scalars (`long`) cannot be `(required)` — only strings/tables can. A union member `RichText_CustomEmoji` generates the Swift enum case `.richtextCustomemoji` (everything after the suffix's first letter is lowercased); the table type stays `TelegramCore_RichText_CustomEmoji` and field accessors keep `.fbs` casing (`value.fileId`). See the `flatbuffers-codegen` memory.
- **`ChatTextInputTextCustomEmojiAttribute` is reused end-to-end** (display layer ⇄ layout model). The attribute is written to the placeholder in `attributedStringForRichText` and read back by the V2 line-breaker under the SAME key (`ChatTextInputAttributes.customEmoji`); `InlineStickerItemLayer.init` consumes it directly and resolves the file lazily from `fileId`.
- **Emoji participates in the streaming reveal.** Its placeholder char's `characterRect` is overwritten to a full cell (width = `itemSize`), so the width-based cost map charges it like other content. `updateEmojiReveal` pops the layer in (alpha 0→1 + scale) when `charIndexInItem < currentRevealCharacterCount`; unrevealed → opacity 0.
- **Inline emoji/images are CENTERED on the font line box, NOT baseline-aligned, and do NOT inflate the line.** The line-breaker keeps `lineAscent = fontLineHeight` (only formulas grow it) and places each attachment at `baselineY − fontLineHeight/2 − size/2`, so it bleeds symmetrically about the line box instead of doubling the line height and shoving the text baseline down (the prior `lineAscent = emoji.size` behavior was a regression from V1 `layoutTextItemWithString`, which centers via `(fontLineHeight − imageHeight)/2`). Custom emoji are sized to ≈ the line box (`size = font.ascender − font.descender + 4·pointSize/17`) so they fit the true-font-height item box (see "InstantPage V2 text item height") with minimal bleed. Mirrors the chat `InteractiveTextComponent`. The cell's `characterRect` is centered the same way (`y = fontLineHeight/2 − size/2`) so the reveal mask (`renderer: y = minY + lineAscent − rect.maxY`) tracks it; a tall attachment grows `extraDescent` so the next line isn't overlapped. Three things must stay in lockstep: the display frame, the `characterRect`, and `extraDescent`.
- **Inline-attachment x must be the LEADING edge, computed RTL-safely via `v2LeadingOffsetForRange` (`InstantPageV2Layout.swift`).** An attachment's left edge is `min(CTLineGetOffsetForStringIndex(start), CTLineGetOffsetForStringIndex(end))` — NOT the bare start-index offset. `CTLineGetOffsetForStringIndex` at the start index returns the glyph's LEFT edge in LTR but its RIGHT edge in RTL (string index increases leftward), so the old single-offset form (`…, range.location, nil`) shoved emoji/images/formulas ~one advance (≈ the attachment width) too far right on RTL lines — e.g. an emoji in an Arabic thinking-block line, while the CoreText-drawn text stayed correct. The helper mirrors `Display.TextNode`'s `addEmbeddedItem` (incl. directional-boundary secondary-offset handling) and the strikethrough/underline/marked/spoiler decorations in this same file, which already used the `min`/`abs` form. For pure-LTR lines it returns exactly the start-index offset, so LTR is byte-identical. Applies to all 5 attachment sites: the emoji/image/formula display frames AND the emoji/image `characterRect` (reveal mask). The widths stay the fixed `size`/`rendered.size` values (the run-delegate advance), only the x is corrected.
- **Layers sit ABOVE the reveal mask.** They attach to `InstantPageV2TextView.emojiContainerView` (a sibling above `renderContainer`), NOT inside it — so the reveal mask wipes glyphs while emoji pop in independently. Adding a CTRunDelegate-glyph to the mask would clip-wipe them instead.
- **Layers are owned by `InstantPageV2View`, not the text view.** Keyed by `InlineStickerItemLayer.Key(id: fileId, index: occurrence)`. The pageView is now REUSED across `stableVersion` bumps (see streaming section), so the inline-emoji dict PERSISTS across chunks; `updateInlineEmoji` prunes stale keys (emoji whose blocks have been removed) and creates/repositions layers for new or unchanged emoji each update pass.
- **`visibilityRect` gates looping; `nil` means "not visible".** The bubble's `visibility` override pushes a full-width sub-rect to the root `pageView.visibilityRect`, re-pushed in the apply closure after `pageView.frame` is set. `propagateVisibilityRect` converts the rect into each nested V2View's coordinate space (`self.convert(_:to:)`) for details bodies / table cells+title, fanning out via each child's `didSet`.
- **CTRunDelegate extent buffers must be freed.** Every inline-attachment arm (`.image`/`.formula`/`.textCustomEmoji`) in `attributedStringForRichText` allocates an `extentBuffer`; the `dealloc` callback must `deallocate()` it (it re-runs per layout pass).
- **The inline-attachment placeholder MUST NOT be whitespace** (`instantPageInlineAttachmentPlaceholder = U+FFFC`, fixed 2026-08-17; all four arms were `" "`). CoreText lets TRAILING WHITESPACE hang past the container's right edge at a break opportunity — correct for a real space, catastrophic for a space carrying a run-delegate advance: an attachment at the end of a line rendered **outside the bubble** instead of wrapping. Measured over a width sweep against the pre-fix code, an emoji overflowed by up to **28pt** and an image or pill by ~**4–5pt** (the atom's own advance was charged, but the real space in front of it hung, carrying the atom past the edge with it) — so the emoji is the loud symptom and the other two are the quiet ones. `U+FFFC` is line-break class **CB**: break opportunities on both sides, width charged to the line. A no-break space (`U+00A0`, class GL) would NOT do — glue suppresses breaks on both sides, so it would fuse an attachment to its neighbouring words and make a whole sentence unbreakable. **All four inline arms share the one constant** — `.textCustomEmoji`, `.image`, `.formula` and the `.textButton` pill — because they share the bug exactly. Three consequences ride along: `InstantPageTextLine.drawInTile` must SKIP any run `instantPageRunIsInlineAttachment` matches (emoji / media-id / formula / button attribute — mirroring `InteractiveTextComponent`'s `Attribute__EmbeddedItem` skip) or a `.notdef` box paints under the hosted view, and skipping is positionally safe because CTRun glyph positions are line-relative; `InstantPageMultiTextAdapter.inlineMarkdown` must map the placeholder out of the copied text (to the emoji marker, or to a space for the attachments it has no markdown for); and `currentText` — what Translate / Share / Look Up receive — substitutes a space, which is safe only because it is length-preserving in UTF-16 so every offset it hands out stays valid. **Deliberately still a real space:** `instantPageInlineButtonSpacerString`, the pill-to-pill gap. It IS whitespace, and a gap that hangs at a line end is the correct behaviour for it. Guarded by `InstantPageInlineAttachmentWrappingTests`.
- **A `RichText.textDate` renders as a LINK in V2 whatever its `format`** (`.link(false)` — colour, no underline), matching what `StringWithAppliedEntities` does for a `FormattedDate` entity in a regular text message: the link colour and the `TelegramTextAttributes.Date` tap stamp are **unconditional**, and `format` decides ONLY whether the displayed text is replaced by an autoformatted one (nil ⇒ the literal inner text stands). **A format-less date is the common case, not an edge case** — `ChatInputContentInstantPage.richText(from:)` emits `format: nil` for *every* client-composed rich message (`ChatInputInlineEntity.date` carries only the timestamp, as do the `tg://timestamp` Document marker and `GenerateTextEntities`), and the wire maps `flags == 0` to nil as well — so gating the colour+stamp on `format` (as the first version of this did) left composed dates as dead body text: not a link, not tappable. The one thing that does gate styling is the `formatDate` closure: the V2 path always supplies it, the V1 reader supplies none, renders the server's literal text, and is deliberately left in body colour rather than turning every reader date blue. Tap dispatch is unchanged (`ChatMessageRichDataBubbleContentNode.entityTapContent` → `.date(date, "")`; the display string is unused by `ChatMessageBubbleItemNode`). Guarded by `InstantPageDateEntityTests`.
- **Known limitation: the client never round-trips a date's `format`.** Every client-side carrier of a date is timestamp-only, so composing/editing a message that contained a `.relative` or `.full(…)` date re-emits it format-less and it stops autoformatting (this is symmetric with plain text messages — `GenerateTextEntities` drops it there too — and is why the styling above must not depend on the format). Restoring it means widening `ChatInputInlineEntity.date`, the `tg://timestamp` marker and `GenerateTextEntities` together.

## RichText entity cases (mention / hashtag / bot command / bank card / auto link)

`RichText.textMention`, `.textMentionName(text:peerId:)`, `.textHashtag`, `.textCashtag`, `.textBotCommand`, `.textBankCard`, `.textAutoUrl`, `.textAutoEmail`, `.textAutoPhone` render the message-entity flavors of rich text inside rich-data bubbles with full tap interaction mirroring `ChatMessageTextBubbleContentNode`. Covers API parsing, Postbox + FlatBuffers serialization, display, and tap routing. (`textDate` and `textSpoiler` are implemented too and follow the same shape — see the `RichText.textDate` bullet above and the spoiler handling in `attributedStringForRichText` / `ChatMessageRichDataBubbleContentNode.revealSpoilers`.)

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_RichText.swift` | The 9 enum cases (each wraps `text: RichText`; `textMentionName` adds raw `peerId: Int64`) + Postbox coding (discriminators 18–26, wrapped text under key `"t"`, mention-name peerId under `"mn.p"`), `==`, `plainText`, FlatBuffers codec. |
| `submodules/TelegramCore/FlatSerialization/Models/RichText.fbs` | Union members + tables (`RichText_MentionName` adds `peerId:long`). Source of truth — same flatc gotchas as the custom-emoji section above. |
| `submodules/TelegramCore/Sources/ApiUtils/RichText.swift` | `Api.RichText` ⇄ Swift, lossless. `textMentionName` carries `userId` ⇄ `peerId`. |
| `submodules/InstantPageUI/Sources/InstantPageTextItem.swift` (`attributedStringForRichText`) | Display: auto url/email/phone reuse the `InstantPageUrlItem` (`url:`) path; the six entity cases push `.link(false)`, recurse, then attach the matching `TelegramTextAttributes.*` key over the produced range. |
| `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/...` | Tap routing: `entityForTapLocation` reads the attribute dict at the tapped point; `entityTapContent` maps keys → `ChatMessageBubbleContentTapAction.Content`. |

### Non-obvious invariants

- **Display attaches the same `TelegramTextAttributes.*` keys the chat text bubble uses; the bubble reads them back.** Contract: `textMention`→`PeerTextMention` (String); `textMentionName`→`PeerMention` (`TelegramPeerMention`, peerId built as `EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, …)` — `InstantPageTextItem` imports TelegramCore but NOT Postbox, so bare `PeerId` is out of scope); `textHashtag` AND `textCashtag`→`Hashtag` (`TelegramHashtag`; no dedicated cashtag key/tap-action — the leading `$` distinguishes them); `textBotCommand`→`BotCommand`; `textBankCard`→`BankCard`. Auto url/email/phone go through the URL path (`mailto:`/`tel:`/raw), NOT an entity key.
- **`linkSelectionRects` and the bubble tap path check EVERY interactive key**, not just URL: URL, the five entity keys, `Date`, and `InstantPageButtonActionAttribute` — so press-highlight and the link-loading shimmer cover entities, dates and page buttons too. A key omitted there loses its highlight and shimmer silently.
- **Rich-data text selection must reach a line's trailing edge.** This is general to rich-data selection, not just entities: `InstantPageTextItem.attributesAtPoint(_:orNearest:)`'s `orNearest: true` (selection-drag) path returns `line.range.upperBound` (via `CTLineGetStringRange`) when the point is at/past `lineFrame.maxX`. `TextSelectionNode` uses that index as the **exclusive** upper bound, so clamping to the last character's index — as the `orNearest: false` hit-testing path correctly does — would leave the last character/item of every line unselectable. Mirrors `Display.TextNode`. Do not collapse the two `orNearest` paths back together.

## Markdown send: entity vs. rich detection

On message send, the app auto-decides: if the typed markdown maps onto the regular message-entity set (bold/italic/code/strikethrough/spoiler/links/blockquote/fenced-code) it sends a **normal message** via the existing entity path; if it contains structure the entity set can't represent it sends a **rich message** (`RichTextMessageAttribute` carrying an `InstantPage`, rendered by `ChatMessageRichDataBubbleContentNode`). Always-on (no flag). **Effective rich triggers are headings, lists, and tables only.**

### Where things live

| File | Responsibility |
|---|---|
| `submodules/BrowserUI/Sources/BrowserMarkdown.swift` | The classifier `richMarkdownAttributeIfNeeded(context:text:)` (pre-filter `markdownMightNeedRichLayout` → parse via existing `inputRichTextAttributeFromText` → block inspection `instantPageNeedsRichLayout`/`blockIsEntityExpressible`/`richTextIsEntityExpressible`), plus the markdown→InstantPage conversion (`markdownWebpage`, `markdownBlocks(from:)`, `markdownBlocksWithGeneratedAnchors`). |
| `submodules/TelegramUI/Sources/ChatControllerNode.swift` (`sendCurrentMessage`, ~line 4860) | The gate: `if !isSpecialChatContents, let attribute = richMarkdownAttributeIfNeeded(context:, text: effectiveInputText.string)` routes to the rich branch; the unchanged `else` is the entity path. |

### Non-obvious invariants

- **Boundary rule:** send rich iff the parse yields an `InstantPageBlock` with no entity equivalent. Entity-expressible whitelist (→ normal): `.paragraph`, `.preformatted`, `.blockQuote` (empty caption), `.anchor`, `.unsupported`, **and `.divider`** (`---` is too common in casual text to trigger rich). **`.formula` (block and inline) DOES trigger rich**, gated by strict math detection (see "Formulas trigger rich messages" below) so casual `$` usage (`$5-$10`, `$FOO=$BAR`) stays plain. So effective triggers = headings, lists, tables, formulas.
- **Approach A (parse-then-inspect):** the classifier reuses the real parser, so "what triggers rich" can't drift from "what the rich renderer shows." `markdownMightNeedRichLayout` is a cheap necessary-condition over-approximation — it may over-trigger a parse but must **never** false-negative. It detects `#`, list markers, dash-lines (`-{1,}`, which also catches setext-H2 underlines → heading blocks), `\n=` (setext H1), `|`, `![`, and math delimiters `$`/`\(`/`\[` (formulas now trigger rich; the strict detection step decides whether a `$` run is actually math).
- **Chat vs. document path = `file == nil` / `context.documentURL == nil`.** `inputRichTextAttributeFromText` passes `file: nil`; the document-attachment path passes a real file. Two chat-only behaviors key off this: (a) generated heading anchors are **skipped** (`markdownBlocksWithGeneratedAnchors` runs only for documents — anchors exist for intra-document `#slug` links and otherwise prepend a spurious invisible `.anchor` block per heading); (b) a level-1 `#` heading maps to `.heading(text:, level: 1)`, not `.title` (the document/article-title treatment). H2–H6 → `.heading(level: 2…6)` for both paths. This converter only ever emits `.title` (H1-doc) or `.heading` — never `.header`/`.subheader`.
- **The classifier is fed the RAW `effectiveInputText.string`**, not the post-`convertMarkdownToAttributes` `inputText`, so inline `**bold**` survives into the rich render. The entity branch still uses the converted `inputText`.
- **Bypassed for `.customChatContents`** (business links / quick replies) via `isSpecialChatContents`. The compose/send gate lives here; **editing has its own symmetric re-classification** — see "Editing rich messages" below.
- **Transmission:** `RichTextMessageAttribute` → `Api.InputRichMessage` via `messages.sendMessage(richMessage:)` (flag bit 23, `StandaloneSendMessage.swift`); recipients reconstruct it from the incoming `richMessage` field (`StoreMessage_Telegram.swift`). The rich branch sends `text: ""` + the attribute, nils `mediaReference` (no separate webpage preview), and bypasses 4096-char chunking. iOS < 15 / oversize markdown → `inputRichTextAttributeFromText` returns nil → entity path (which chunks).

## Editing rich messages (InstantPage → markdown)

Rich messages (`RichTextMessageAttribute`, `text == ""`) are made editable by reconstructing markdown source from the stored `InstantPage`, populating the editor with it, and re-classifying on save — the inverse of the send path above. Always-on (no flag). Images/videos are out of scope (skipped by the converter).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/BrowserUI/Sources/InstantPageToMarkdown.swift` | `markdownStringFromInstantPage(_:)` — the inverse converter (block + inline + list + table + escaping). Pure, best-effort, never fails. |
| `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift` | `setupEditMessage`: rich message → reconstruct markdown into the edit field. `editMessage` (save): re-classify the raw input, route rich-or-plain. |
| `submodules/TelegramStringFormatting/Sources/InstantPagePreviewText.swift` | `previewText()` extensions (`RichText`/`InstantPage*`) — one-line plaintext previews. |
| `submodules/TelegramStringFormatting/Sources/MessageContentKind.swift` | `messageContentKind` returns `.text(instantPage.previewText())` for rich, cascading to all preview surfaces. |

### Non-obvious invariants

- **The converter emits CommonMark inline, NOT the entity-regex dialect.** `**bold**`, `*italic*`, `` `code` ``, `~~strike~~`, `[text](url)` — because re-send re-parses the text through the *rich* path (`richMarkdownAttributeIfNeeded` → `NSAttributedString(markdown:)`, Apple CommonMark), not `convertMarkdownToAttributes` (whose dialect is `__italic__`/`||spoiler||`). The two parsers disagree on `__`/`*`; the rich round-trip is the contract.
- **Re-classify every edit (edit ≡ send).** `editMessage` runs the same `richMarkdownAttributeIfNeeded` on the edit field's attributed text (so reattached custom emoji round-trip — see the custom-emoji section). Rich → `pendingUpdateMessageManager.add(text: "", entities: nil, richText: attr, …)`; else the unchanged plain path. So normal→rich (add a table) and rich→plain (drop all triggers) both work. Bypassed for `.customChatContents`.
- **Change-detection compares the rich attribute.** The save guard adds `currentRichText != richTextAttribute` (rich branch — skips no-op rich edits) and `currentRichText != nil` (plain branch — so rich→plain still saves even when `text.string` looks unchanged). `RichTextMessageAttribute` is `Equatable` on `instantPage`.
- **The `text.length == 0` early-return guard is safe for rich.** `convertMarkdownToAttributes` only rewrites inline tokens, never strips `#`/`-`/`|`, so a rich message's markdown source stays non-empty and passes; the rich branch then sends `text: ""`.
- **Known limitation:** a rich→plain edit that leaves only inline-formatted text loses `*italic*` (the entity path recognizes only `__…__`). Rare edge; the rich round-trip contract holds.
- **`previewText()` lives in TelegramStringFormatting, not TextFormat/TelegramCore.** It will gain a `strings: PresentationStrings` param (to localize the `"Photo"`/`"Video"`/`"Table"` placeholders), so it must sit in a UI-string module — `messageContentKind`/`descriptionStringForMessage` (same module) already take `strings:`. Teaching `messageContentKind` about rich cascades the preview to the edit accessory panel, reply/pinned panels, and forward preview in one place (those surfaces need no individual change).

## Copying rich messages as markdown (whole message + partial selection)

Rich messages (`RichTextMessageAttribute`, `text == ""`) are copyable as markdown two ways: the context-menu **Copy** action copies the whole message; a **text selection** inside the rich-data bubble copies just the selected range. Both reconstruct markdown that mirrors the edit round-trip (`markdownStringFromInstantPage`). Always-on.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` | Whole-message Copy (**three** action sites: the regular menu, the anchored menu, and the quick-reply/welcome menu). Each computes `richMessageMarkdown` / `richMessageInstantPage` from the message's `RichTextMessageAttribute.instantPage`, opens the Copy gate with `richMessageMarkdown != nil`, and short-circuits to `UIPasteboard.general.items = [richMessagePasteboardItem(fromInstantPage:)]` — the WYSIWYG fragment + RTF + plain, not raw markdown text (the old `storeMessageTextInPasteboard(markdown, …)` behaviour). **A rich message is sent with `text: ""`**, so any `messageText.isEmpty` gate on that path must also test `richMessageInstantPage != nil` or the image-copy branch throws the document away (fixed 2026-08-17 in the regular menu's `resourceAvailable` arm). |
| `submodules/BrowserUI/Sources/InstantPageToMarkdown.swift` | `markdownStringFromInstantPage` — the block-tree → markdown converter (also used by the edit round-trip). Blocks joined by `\n\n`; nested blockquotes via recursive `> ` wrapping. |
| `submodules/InstantPageUI/Sources/InstantPageTextItem.swift` | `InstantPageMarkdownBlockContext` (`kind` + `quoteDepth`) and the `markdownContext: InstantPageMarkdownBlockContext?` field on `InstantPageTextItem`. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `stampMarkdownContext`/`bumpQuoteDepth`; stamps `markdownContext` during layout (heading/title/code/list/blockQuote/`layoutQuoteText`/table-cell). |
| `submodules/InstantPageUI/Sources/InstantPageMultiTextAdapter.swift` | `markdownForRange(_ range: NSRange)` + the private attributed-substring→inline-markdown converter `inlineMarkdown(from:)`. |
| `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/.../ChatMessageRichDataBubbleContentNode.swift` | Intercepts `.copy` in the `TextSelectionNode` `performAction` closure: `textSelectionNode.getSelection()` → `adapter.markdownForRange(range)` → stores as plain `NSAttributedString(string:)`. |

### Non-obvious invariants

- **The V2 layout discards block role.** A `.text` layout item from an `H2` heading is byte-identical to a body paragraph — heading level and the title category are dropped with no back-reference to the source `InstantPageBlock`. Precise structural markdown for a *selection* therefore requires stamping `markdownContext` at layout time (lists/code/tables/details are structurally recoverable; **heading level and `.title` are not**, so they MUST be stamped). Plain paragraphs stay `nil` (≡ plain).
- **`quoteDepth` is orthogonal to `kind`** so a heading/list/code line inside a blockquote round-trips (e.g. `> ## Title`). `bumpQuoteDepth` lifts a quote's children by 1; nested quotes accumulate. `layoutQuoteText` (single-paragraph blockquote fast path AND `.pullQuote`) bumps once — it is never reached by the multi-block recursion, so no double-count.
- **A blockquote is exploded into one text item per line.** `markdownForRange` must re-coalesce a run of consecutive `quoteDepth > 0` segments into ONE `\n`-joined block (each line prefixed at its own depth); otherwise every quote line becomes its own block separated by a blank line. Code/table/list runs are likewise coalesced (one fence; one pipe table; one tight list).
- **Both converters emit compact nested-quote markers (`>>`, not `> >`).** Selection: `String(repeating: ">", count: depth) + " "`. Whole-message: when wrapping a line that already starts with `>`, prepend a bare `>`. Keep the two in sync.
- **Inline markdown is read from display attributes, not the RichText tree.** `inlineMarkdown` inspects the slice's `UIFont` (bold/italic/mono — font-based, no symbolic-trait flag for named fonts), `.strikethroughStyle`, and `TelegramTextAttributes.URL` (→ `InstantPageUrlItem.url`, angle-bracketed if it contains `(`/`)`/space). Custom-emoji placeholders now emit the `[<alt>](tg://emoji?id=…)` marker from the display attribute's `fileId` (alt is best-effort — the display placeholder may be a bare space; see the custom-emoji round-trip section).
- **`.copy` stores plain text.** Passing `NSAttributedString(string: markdown)` through the existing `performTextSelectionAction(.copy)` path (`storeAttributedTextInPasteboard`) generates no entities, so the literal `**`/`#`/`>`/`|` survive. The whole-message Copy uses `storeMessageTextInPasteboard(_, entities: nil)` directly.
- **Fidelity caveats (intentional):** custom emoji are now preserved as `[<alt>](tg://emoji?id=…)` markers (selection copy uses a best-effort alt — see the custom-emoji round-trip section below); ordered list + checkbox loses the ordinal (`-` wins); a partial table selection emits touched cells as rows (no forced header `---` separator); block prefixes apply to the whole touched line on a mid-line selection (correct markdown).

## Collapsed quotes (blockQuote.collapsed) in V2

A quote the author marked collapsed renders as a **three-line preview** that fades out into an expand chevron, matching `InteractiveTextComponent` so a rich bubble and a regular text message in the same chat collapse to the same size and look the same doing it — same arrow asset (`Item List/ExpandingItemVerticalRegularArrow`, 6pt in / 3pt up from the trailing-bottom corner, rotated π when expanded), same bottom-fade tile, same trailing "…". Tapping anywhere in the quote toggles it, animated by the chat list's own item-update animation. Added 2026-08-18.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageV2QuoteCollapse.swift` | The whole testable core: `instantPageV2QuoteCollapseState`, `instantPageV2TextLineCount`, `instantPageV2QuoteBudgetedItems`, the truncation ellipsis, `instantPageV2QuoteChevronSideInset`, and the 3-line budget + chevron-clearance constants. Free of `LayoutContext` on purpose — see the testability note below. |
| `submodules/InstantPageUI/Sources/InstantPageV2QuoteFade.swift` | The bottom-fade tile (`generateBlockMaskImage()` ported verbatim) and `InstantPageV2QuoteFadeMaskLayer`. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `layoutBlockQuote` applies the budget in its child loop and reserves the expanded chevron's clearance; `InstantPageV2QuoteFrameItem` carries `collapseState` + `path`; `LayoutContext`/`layoutInstantPageV2` carry `expandedQuotePaths`. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2QuoteFrameView` draws + animates the chevron; `InstantPageV2View.applyCollapsedQuoteFades` hangs the fade off content views; `collapsibleQuoteAt(point:)` is the hit lookup; `TextRenderView.draw` paints `additionalTrailingLine`. |
| `submodules/InstantPageUI/Sources/InstantPageTextItem.swift` | `InstantPageTextLine.additionalTrailingLine` — the appended "…" token. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | Owns `currentExpandedQuotePaths`, passes it into layout AND into the layout cache key, and resolves the toggle last in `tapActionAtPoint`. |

### Non-obvious invariants

- **Collapsible is not the same as collapsed.** A quote shows a control only when the author marked it AND it exceeds three text lines (`instantPageV2QuoteCollapseState`). Mirrors the reference's `segmentLines.count > 3`. Collapsibility is author-set; the reader cannot collapse a quote the author left open.
- **Expansion is a LAYOUT INPUT, not view state** — `layoutInstantPageV2(expandedQuotePaths:)`, exactly like the older `expandedDetails`. Clipping at view time cannot work: the page's height would size for the expanded content and the bubble would reserve space it does not draw.
- **`expandedQuotePaths` is part of the `currentPageLayout` CACHE KEY.** The bubble caches its laid-out page and reuses it when the inputs match; omitting the set means a toggle mutates state, requests an update, and then gets the stale layout back — a dead tap that looks like a broken gesture rather than a stale cache.
- **Keyed by structural path, not ordinal.** `InteractiveTextComponent` keys by block index; V2 keys by the `pathPrefix` it already threads (the same addressing `checkboxTapped` uses) because AI streaming appends blocks and shifts ordinals under the state.
- **Truncation happens INSIDE `layoutBlockQuote`'s child loop**, so nothing needs re-positioning — the siblings after a truncated item do not exist yet — and `contentHeight` is right by construction. The truncated item's height comes from the uniform line pitch (`lines[1].minY − lines[0].minY`), not a re-measure.
- **The ellipsis is APPENDED, never folded into the line.** `InstantPageTextLine.additionalTrailingLine` carries a "…" drawn after the line's own glyphs, the way the reference does it — rewriting the line with `CTLineCreateTruncatedLine` would invalidate `range`, the per-line attachment/spoiler/underline frames and the character rects all at once, breaking hit-testing, inline emoji placement and the streaming reveal. It is dropped when the line already fills the band (no room, and the reference's own token lands inside the faded corner there anyway).
- **The fade is a MASK, not an overlay.** A quote's fill is translucent accent over the chat wallpaper, so painting a background-coloured gradient over the last line would show as a grey smear. `InstantPageV2QuoteFadeMaskLayer` carves the bottom 8pt and a radial hole around the chevron out of the content's alpha instead. Its `backgroundColor` is the dissolve control, not decoration: a mask composites its background BEHIND its contents, so animating clear → white fills the carve-out back in and the fade cross-fades away as the quote expands.
- **The fade is applied by a POST-PASS over positioned views** (`applyCollapsedQuoteFades`), because a quote's content is not grouped — `layoutBlockQuote` emits the frame and its children as flat siblings, so geometry is the only thing tying a text view to the quote it sits in. Innermost containing quote wins; a quote never masks its own frame view (which is what carries the chevron). Details bodies and table cells nest their own `InstantPageV2View`, and masking the container masks the subtree, so nesting needs no special case.
- **An expanding quote's mask must keep tracking the quote.** The dissolve animates `backgroundColor`, but the mask's FRAME is animated to the new (taller) rect at the same time — leave it at the old rect and the newly revealed lines are clipped for the length of the expand animation. The teardown is token-guarded so re-collapsing mid-animation cannot let the stale completion strip the mask.
- **Nothing past the cut is DISCARDED — it is drawn and not reserved for.** `layoutBlockQuote` runs two heights: `contentHeight` (what the quote reserves, and therefore how tall it is) and `drawnHeight` (where the next child is positioned). They diverge past the three-line cut. So every child sits at the SAME coordinates collapsed and expanded, no view is created or destroyed by a toggle, and the whole transition is the quote's height plus the mask. A medium, table or nested quote below the cut is carried as `overflow` rather than dropped — dropping it tears its view down on collapse and rebuilds it on expand, which blinks. Inline content (custom emoji, images, formulas, buttons) needs nothing extra: it lives in the text view's own container subviews, which the mask covers.
- **A collapsing quote keeps its cut lines DRAWN, as `InstantPageV2TextItem.overflowHeight`.** Truncating at layout time is what makes the quote three lines tall, but lines that no longer exist cannot be animated away — they can only blink out, which is what a collapse looked like before this. The truncated item therefore keeps every line and shrinks only its laid-out box; the surplus spills past the view's bounds (nothing there clips) and the quote's mask hides it. The mask is created at the quote's PRE-toggle rect and animated closed, because a mask born already closed reproduces the very snap the overflow exists to remove.
- **The "…" is the one drawn difference between the two states, and it CROSSFADES.** Because the cut lines stay drawn as overflow, every line and every line position is identical collapsed and expanded; only the token differs, and it would otherwise blink in and out while the geometry around it animated. `InstantPageV2TextView` keeps the bitmap already in `renderView.layer.contents`, forces the redraw, and dissolves between the two — the mechanism `InteractiveTextComponent` uses for its spoiler reveal (`animateContents(layer:from:)`), which is far cheaper than a snapshot because the old backing store is already there. Gated on the box being the same size, which is the honest precondition for a contents crossfade (a resized layer squashes the old bitmap) and also keeps it off the AI-streaming path, which grows the box and has its own reveal.
- **Overflow is only safe when nothing follows the cut inside the quote.** The spill is invisible because the mask is transparent below the quote's bottom edge — above it the mask is opaque, so a caption under the cut would be overlapped. Once the budget is exhausted every later child is dropped, so the caption is the only thing that can sit there: `layoutBlockQuote` passes `keepingOverflow` only for an empty caption, and the captioned case keeps the old lossy truncation (and its snap).
- **Only the EXPANDED state reserves room for the chevron.** A collapsed quote's fade already clears that corner. Expanded, the layout measures the last row's `instantPageV2QuoteChevronSideInset` — the last LINE's drawn edge for text, since a paragraph's frame always spans the band — and adds 10pt only when the arrow would land on content.
- **Only text costs budget.** A medium / table / nested quote is kept whole if it begins before the budget is exhausted and dropped entirely if not — never clipped. So a collapsed quote whose first child is an image is taller than three lines. Deliberate; see the design doc.
- **The caption is never budgeted.** It is the quote's attribution — chrome, not content.
- **The frame view stays `isUserInteractionEnabled = false`.** An interactive view would take the touch before `tapActionAtPoint` ran, so a link inside the visible three lines would toggle the quote instead of opening. The host resolves the tap through `collapsibleQuoteAt(point:)`, after its URL and entity hits.
- **`layoutQuoteText` is NOT the single-paragraph blockquote path**, whatever the comment there says: its only caller is `.pullQuote`, and every `.blockQuote` goes through `layoutBlockQuote`. Its frame item is pinned `.notCollapsible`.
- **Recipients only see this for SINGLE-PARAGRAPH quotes.** `pageBlockBlockquoteBlocks` has no `collapsed` field in the schema, so a multi-block quote loses the flag in transit (`apiInputBlock` picks that form for anything but a lone `.paragraph`). Local surfaces — composer, send preview, article editor, drafts — honour it for every shape. Closing the gap needs `pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true` server-side.

### Testability

`layoutBlockQuote` is `private` and a `LayoutContext` needs a `TelegramMediaWebpage`, `PresentationStrings` and a themed `InstantPageTheme`, so no test drives the layout — nothing in the repo calls `layoutInstantPageV2` from a test. That is why the budgeting arithmetic, the ellipsis and the chevron clearance live in their own file as pure functions, tested by `InstantPageV2QuoteCollapseTests` against items built with `layoutTextItem`. `InstantPageV2QuoteFadeTests` samples the fade tile's alpha directly — the tile is written in blend modes (`.copy` radial, `.destinationIn` linear), and getting one wrong still yields a plausible greyscale image that masks the wrong pixels. The view wiring (mask attachment, chevron animation, hit lookup, bubble state) has no automated coverage; it was verified on the simulator instead — tap-to-toggle, the chevron, the fade, and the collapse/expand animation all confirmed working 2026-08-18, after four rounds in which each remaining artifact was reported and fixed in turn (chevron asset → background chrome → the clip → the ellipsis). Still unverified by anyone: RTL, a quote with an author caption, and nested collapsible quotes.

## Custom emoji in markdown messages (send + edit/copy/paste round-trip)

Custom emoji typed into the compose field survive when a message is sent as a **rich** message (heading/list/table/formula), rendering as `RichText.textCustomEmoji` (the display side is the "Inline custom emoji" section above). The carrier across Apple's CommonMark parser is a shared markdown-link marker `[<alt>](tg://emoji?id=<fileId>)`, used identically by the forward (send) and reverse (edit/copy/paste) paths so encode and decode cannot drift. Always-on. **Scope: only rich messages — a custom emoji alone never forces a rich message** (it stays on the entity path as a `.CustomEmoji` entity, the pre-existing behavior).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TextFormat/Sources/CustomEmojiMarkdownMarker.swift` | The marker format — single source of truth: `customEmojiMarkdownURL(fileId:)`, `parseCustomEmojiFileId(fromMarkdownURL:)`, `escapeCustomEmojiMarkdownAlt(_:)`, and `chatInputTextWithReattachedCustomEmoji(_:)` (markers → live `customEmoji` attributes). In TextFormat so both BrowserUI and InstantPageUI can import it. |
| `submodules/BrowserUI/Sources/BrowserMarkdown.swift` | Forward: `markdownSourceInjectingCustomEmojiMarkers` rewrites each `customEmoji` run into the marker; `richMarkdownAttributeIfNeeded(context:attributedText:)` (signature changed from `text:`); the marker-URL intercept in `markdownInlineContent` → `.textCustomEmoji`. |
| `submodules/BrowserUI/Sources/InstantPageToMarkdown.swift` | Reverse (whole-message copy + edit reconstruction): `.textCustomEmoji` → emit the marker. |
| `submodules/InstantPageUI/Sources/InstantPageMultiTextAdapter.swift` | Reverse (text-selection copy): emit the marker from the display attribute's `fileId` (alt best-effort). |
| `submodules/TelegramUI/Sources/ChatControllerNode.swift`, `…/Chat/ChatMessageDisplaySendMessageOptions.swift` | Send + send-options-preview call sites pass the `NSAttributedString` (`effectiveInputText` / `textInputView.attributedText`); the rich send now passes `inlineStickers`. |
| `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift` | Edit-load (`setupEditMessage`) reattaches markers via `chatInputTextWithReattachedCustomEmoji`; edit-save (`editMessage`) re-classifies the attributed edit text. |
| `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` | Paste (`chatInputTextNodeShouldPaste`) reattaches plain-text markdown markers → live emoji. |

### Non-obvious invariants

- **One shared marker, one set of helpers.** All emit sites (forward normalize, reverse copy/edit, selection copy) use `customEmojiMarkdownURL` + `escapeCustomEmojiMarkdownAlt`; the forward intercept and both reattach sites use `parseCustomEmojiFileId`. The marker is internal/transient — it exists only in the rich-conversion source string and on the clipboard, never persisted as a URL entity.
- **CommonMark preserves the `tg://emoji?id=N` link URL verbatim** under the `NSLink` attribute (spike-verified). `markdownLink`'s `as? NSURL` branch returns `url.absoluteString`, which `parseCustomEmojiFileId` matches by strict prefix. Negative (signed Int64) file ids survive too (the reattach regex is `(-?\d+)`).
- **Scope guard is structural.** `markdownSourceInjectingCustomEmojiMarkers` works on a LOCAL copy — `effectiveInputText` is never mutated. A marker is an entity-expressible link, so an emoji-only message classifies not-rich (`markdownMightNeedRichLayout` finds no `#`/`|`/`![`/`$`/list tokens) and takes the entity path; the untouched `customEmoji` attribute becomes a `.CustomEmoji` entity.
- **`richMarkdownAttributeIfNeeded` now takes `attributedText: NSAttributedString`** (was `text: String`); it normalizes to the marker'd source internally, then calls the unchanged `inputRichTextAttributeFromText(text:)`. All three call sites (send, edit-save, send-options preview) pass the attributed string.
- **Edit-load AND paste reattach to live attributes; copy stays textual.** `setupEditMessage` and `chatInputTextNodeShouldPaste` run `chatInputTextWithReattachedCustomEmoji` so the field shows the animated emoji, not raw token text. The paste branch is guarded by `.contains("tg://emoji?id=")` AND `reattached.string != plainText`, and runs only after the rich pasteboard types miss — `private.telegramtext`/RTF already decode the indexed `tg://emoji?id=<id>&t=<n>` RTF-link form via `chatInputStateStringFromRTF`. `previewText()` is unchanged (keeps the alt glyph).
- **NEVER write composer state back through `ChatTextInputState(inputText:selectionRange:)`** (fixed 2026-08-18 — the *second* cause of "pasted headings disappear", and the one that survived the splice fix). That initializer re-derives the model from a FLATTENED `NSAttributedString` via `chatInputContent(from:)`, which has no vocabulary for headings, lists, quotes, tables or media — so it silently retypes every structural block as a body paragraph. `serviceTasksForChatPresentationIntefaceState` (`ChatInterfaceInputContexts.swift`) used it to write resolved custom-emoji `TelegramMediaFile`s back into the composer, and a pasted rich message arrives with `file == nil` on every emoji (that is what `chatInputContent(fromInstantPage:)` produces). So the paste rendered correctly and then, a few hundred milliseconds later when `resolveInlineStickers` returned, the whole composer flattened — **headings visible, then gone**, with nothing in the paste path at fault. The write-back now runs on the model: `ChatInputContent.resolvingCustomEmojiFiles(_:)` + `.unresolvedCustomEmojiFileIds()` (`TelegramCore/ChatInputContent/ChatInputContentCustomEmoji.swift`), whose `switch` over `ChatInputBlock` is exhaustive so a new block case must say where its runs live. Two things fall out: the detection also walks the model, so emoji inside a table cell / collapsed quote / media caption are now resolved at all (the flat scan could not even see them); and the resolver is **attribute-only** — no text, no structure change — which is what makes it safe to keep the existing structural `selection` instead of recomputing one. Guarded by `ChatInputContentCustomEmojiTests`, including a test asserting the flat round-trip IS lossy, so the reason survives a future simplification. **Closed 2026-08-18:** the five autocomplete panels plus `insertText`, translate, the paste splice, the clear button and the emoji-suggestion sweep now go through `ChatTextInputState.replacingFlatRange(_:with:)`, a structural splice over `ChatInputContent`'s flat axis (`TelegramCore/ChatInputContent/ChatInputContentReplaceRange.swift`). `ComposerFlatRebuildGuardTests` scans the composer sources and fails on a new site that takes a mutable copy of the derived `inputText`. **Exempted in that guard, and NOT a live bug:** `ChatTextInputPanelNode.toggleQuoteCollapse` carries the same shape — it converts a `.block` quote range into a `.collapsedBlock` placeholder and back, which is block-level surgery a text replace-range cannot express — but it is unreachable with structured content. Only the legacy `ChatInputTextNode` ever invokes it; on the native node it is a stored property nothing calls (the editor has its own `collapseQuoteRun`/`expandCollapsedQuote`), and a composer holding a heading has already latched to native. Verified 2026-08-18, correcting an earlier claim here that it still flattened. Also still open: a cross-block range with a block quote at either end is a no-op, and `AttachmentTextInputPanelNode` / `ComposeTodoScreen` carry the old pattern on their own surfaces.
- **The flat projection is READ on the send path too, so what it drops is dropped from the message** (fixed 2026-08-18). The sibling of the rule above, and the one that bit hardest because the projection is usually thought of as display-only. `attributedString(from:)` rendered an EXPANDED `.blockQuote` as `bq.content.plainText` — a bare `String` — discarding every inline attribute inside the quote. But `ChatTextInputState.inputText` is derived from that function, and `sendCurrentMessage` serialises `expandedInputStateAttributedString(composeInputState.inputText)` into entities (draft sync, `ChatInterfaceState.synchronizeableInputState`, takes the same route). So **a custom emoji inside a quote arrived at the recipient as its `alt` text**, and bold / italic / links / mentions / spoilers in a quote were silently flattened with it. The branch now recurses with the attribute-preserving builder. Two things make that safe rather than merely better: the characters are identical either way — a quote's `plainText` IS its content's `plainText`, and the default `renderListMarkers: false` adds none of its own — so the **flat axis every selection offset is measured against does not move** (pinned by two tests); and the quote's `.block` attribute is applied only where one is not already set, so a code block nested in a quote keeps its own kind instead of being overwritten. `.pullQuote` had the identical hole (`pq.text`) and was fixed with it. **COLLAPSED quotes were never affected** — they stow the whole attributed string in `.collapsedBlock` and `expandedInputStateAttributedString` splices it back intact — which is why the bug looked intermittent; `ChatInputQuoteInlineAttributeTests` pins both forms so they cannot drift. That suite was validated by reverting the fix with the tests in place: four of the seven go red.
- **The clipboard carried the headings all along — the SPLICE ate them** (fixed 2026-08-17, after the reattach-ordering fix below left headings still missing). Every copy path already put a lossless fragment (or structural markdown) on the clipboard, and the `InstantPage → ChatInputContent → Document` bridge is lossless in both directions (verified block-by-block). The loss was one step further in: `Document.insertingFragment` inline-merges a pasted paragraph into the split half of the host paragraph, and that merge keeps the **host's** style. `isInlineMergeable` accepted every heading level, and the composer's host paragraph is always body — so a fragment beginning (or ending) with a heading came out as body text. See the `isInlineMergeable` note in the RichTextEditor `CLAUDE.md` for the directional rule that replaced it. **Debugging lesson: the emoji surviving while headings did not was the diagnostic** — both ride the same clipboard and the same bridge, so a loss affecting only block structure could not be in either; it had to be in the block-level splice.
- **The emoji reattach must NOT outrank STRUCTURAL markdown-on-paste** (ordering fixed 2026-08-17). A *text selection* copied out of a rich bubble is markdown that can carry both `# `/`> `/`- ` structure AND emoji markers. The reattach used to run first and claim every such paste, yielding live emoji beside LITERAL `#`/`>` characters — the headings and quotes silently lost. `chatInputTextNodeShouldPaste` now parses the markdown once up front and takes the rich path ahead of the reattach **when the parsed content is not `isEntityExpressible()`** — i.e. only for content the legacy field genuinely cannot hold. Inline-only text (bold, a link, a lone emoji) keeps its old route, so an ordinary emoji paste does not trip the one-way native latch; it still reaches the markdown branch below the reattach. The markdown parser decodes the markers itself (`BrowserMarkdown` → `RichText.textCustomEmoji`), so it is strictly the more faithful reader for structured text.
- **Empty alt → a space.** CommonMark drops `[](url)` (no run carries the link attribute), which would silently lose the emoji; every emit site and the reattach substitute a space when the alt is empty.
- **Rich send attaches `inlineStickers`** (was `[:]`) + bubble-up packs, so the local store has the files. **OPEN runtime risk:** the wire send uses `Api.InputRichMessage.documents: nil` (`apiInputRichMessage()` in `SyncCore_RichTextMessageAttribute.swift`), so recipient rendering depends on the server back-filling `documents` from the embedded `documentId` — UNVERIFIED. If recipients see only the fallback glyph, populate `documents:` there.
- **Accepted limitations:** edit-load reattaches with `file: nil` (renders via lazy fileId resolution, but the premium-emoji gate is bypassed on edit); an alt containing a literal `]` won't reattach on edit-load (cosmetic — re-save still parses it); `parseCustomEmojiFileId` (strict prefix) vs `Pasteboard.swift`'s `URLComponents` parse could drift if the marker format ever changes.

## Formulas trigger rich messages (strict math detection)

`$…$`/`$$…$$` (and `\(…\)`/`\[…\]`) math triggers a rich message, gated by a
strict boundary rule so casual `$` stays plain. Inverse companion of the
markdown-send gate above.

### Non-obvious invariants

- **Inline `$…$`/`$$…$$` detection requires a 4-way boundary** (in `markdownReplacingInlineFormulas`, `BrowserMarkdown.swift`): outer side of each delimiter = line edge OR non-alphanumeric; inner side = non-whitespace; opener/closer `$`-counts must match (1 or 2). This is what rejects `$5-$10`/`$FOO=$BAR`/`cost$5$total` (alphanumeric outer) while keeping `$x$`, `($x$)`, `the answer is $x$.`. The outer check is the addition over a plain "no-space-inside" rule.
- **Block `$$` detection** (`markdownBlockFormulaReplacement`): single-line `$$…$$` requires an exact `$$` opener (not `$$$`) and trailing whitespace only; multi-line requires a **bare** `$$` opener line. `$$x$$ trailing text` falls through to the inline rule. The `\[…\]` opener path is unchanged and exempt from these `$$`-only guards.
- **Detection is shared with the document path; the gate is chat-only.** `markdownPreparedSource` (detection) runs for both chat and document attachments. The triggers (`richTextIsEntityExpressible`/`blockIsEntityExpressible` → `.formula` is non-expressible; `$`/`\(`/`\[` in `markdownMightNeedRichLayout`) are read only by the chat classifier `richMarkdownAttributeIfNeeded`.

## InstantPageListItem task-list checkboxes (`- [ ]` / `- [x]`)

`InstantPageListItem` carries a first-class `checked: Bool?` — the **third** associated value of `.text(RichText, String?, Bool?)` / `.blocks([InstantPageBlock], String?, Bool?)`, orthogonal to the ordered-list `num` — representing a GitHub-style task-list checkbox. `nil` = not a checkbox item, `false` = unchecked, `true` = checked. Covers markdown parse, Postbox + FlatBuffers serialization, Telegram API transmission, display (V1 + V2), the edit round-trip, and previews.

Spec: [`docs/superpowers/specs/2026-05-27-instantpage-list-checkbox-design.md`](docs/superpowers/specs/2026-05-27-instantpage-list-checkbox-design.md). Plan: [`docs/superpowers/plans/2026-05-27-instantpage-list-checkbox.md`](docs/superpowers/plans/2026-05-27-instantpage-list-checkbox.md).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_InstantPage.swift` | The `checked: Bool?` enum payload; Postbox coding (key `"ck"`, tri-state Int32); `==`; FlatBuffers codec. Internal tri-state helpers `checkedFromTriState`/`triState(fromChecked:)`. |
| `submodules/TelegramCore/FlatSerialization/Models/InstantPageBlock.fbs` | `checkState:int32 (id: 2)` on `InstantPageListItem_Text` + `_Blocks`. **Source of truth**; the Bazel `flatc` genrule regenerates the Swift (checked-in `*_generated.swift` is stale). |
| `submodules/TelegramCore/Sources/ApiUtils/InstantPage.swift` | `checked` / `num` accessors; reads & writes the API `checkbox`=flags.0 / `checked`=flags.1 bits via `checkedFromApiFlags` / `apiFlags(fromChecked:)` across all four list-item types. |
| `submodules/BrowserUI/Sources/BrowserMarkdown.swift` | Forward parse: `markdownTaskListMarker` detects `[ ]`/`[x]`/`[X]`; the result routes into `checked` (NOT `num`). |
| `submodules/BrowserUI/Sources/InstantPageToMarkdown.swift` | Reverse: emits `- [ ] ` / `- [x] ` from `item.checked` for the edit round-trip. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | V2 detection via `item.checked`; `.checklist(checked:colors:)` marker carrying `InstantPageV2CheckboxColors`. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | V2 marker view (`InstantPageV2ListMarkerView`) hosts a real `CheckNode`. |
| `submodules/InstantPageUI/Sources/InstantPageLayout.swift` | V1 detection via `item.checked` (renders the existing `InstantPageChecklistMarkerItem`). |
| `submodules/TelegramStringFormatting/Sources/InstantPagePreviewText.swift` | `previewText()` renders a `☐`/`☑︎` glyph + body for checkbox items. |

### Non-obvious invariants

- **`checked` is orthogonal to `num`.** The API keeps `checkbox`/`checked` as flags **separate from the list number**, so an ordered item can be both numbered AND a checkbox. This is exactly why the first-class field replaced an earlier sentinel-string-in-`num` prototype (which could not represent both). No `\u{001f}tg-md-task:*` sentinel remains anywhere.
- **API bits are `checkbox`=flags.0, `checked`=flags.1 on ALL FOUR list-item constructors** (`pageListItemText`/`Blocks` and `pageListOrderedItemText`/`Blocks`, in and out — `pageListItemText#2f58683c`, `pageListOrderedItemText#cd3ea036`, etc.). The iOS `Api.*` layer exposes only `flags: Int32`; mask the bits (`apiFlags(fromChecked:)` / `checkedFromApiFlags`). Because state rides the flags (not the text), it survives the server round-trip for sender + recipients — **including the sender's own send-confirmation echo** (`applyUpdateMessage` replaces local attributes with the server's reconstruction, `ApplyUpdateMessage.swift`).
- **Tri-state persistence `0=nil, 1=unchecked, 2=checked`** in BOTH Postbox (key `"ck"`, decoded with `decodeInt32ForKey(orElse: 0)`) and FlatBuffers (`checkState:int32`, default 0). Absent/0 → `nil`, so pre-existing stored pages decode unchanged.
- **Detection reads `item.checked != nil`** in both layout engines (was `instantPageTaskListMarkerState(item.num)`); the V2 marker kind is `.checklist(checked: item.checked == true, colors:)`. The empty-blocks `.blocks → .text(.plain(" "), num, checked)` promotion must carry `checked` through, not drop it.
- **V2 `CheckNode` is hosted directly in a plain `UIView`**, not an ASDisplayNode tree, so `checkNode.displaysAsynchronously = false` is set to avoid a first-draw blank flash. (The V2 pageView is now REUSED across streaming chunks via stable-id diffing — see the AI streaming section; `CheckNode` views survive across chunks as long as their list item is present.) `InstantPageV2CheckboxColors` (background←`panelAccentColor`, stroke←`pageBackgroundColor`, border←`controlColor`) is carried on the `.checklist` payload and mirrors the V1 `instantPageChecklistMarkerTheme`.
- **Forward parser keeps `[ ]` detection but routes to `checked`.** `markdownApplyTaskListMarker`/`markdownStrippingTaskListMarker`/`markdownTaskListMarker` still strip the marker from the item text; the state flows into `checked` while ordered items keep their real `"\(ordinal)"` number. The reverse converter emits lowercase `[x]` / `[ ]`, which the forward `hasPrefix` guards re-parse — that is the round-trip contract.
- **The enum-arity change is compile-enforced.** Adding the third associated value broke every `.text`/`.blocks` construction/destructure; the full build is the completeness gate. Read-only consumers outside the core set exist (`BrowserInstantPageContent.swift`, `CachedFaqInstantPage.swift`) — grep `\.(text|blocks)\(` repo-wide when touching the enum again.

### Tap-to-toggle (editable rich messages)

Task-list checkboxes in a rendered rich message are **interactive when the message is editable**: tapping one flips it and persists the change by editing the message.

Where things live:

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/InstantPageCheckboxToggle.swift` | Pure transform `InstantPage.togglingCheckbox(at: [Int], to: Bool) -> InstantPage` — rebuilds the block tree following a structural path and flips the target list item's `checked` (no-op on an unresolvable/non-checkbox path). |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `InstantPageV2ListMarkerItem.checkboxPath: [Int]?`; a `pathPrefix: [Int]` threaded through `layoutBlockSequence`/`layoutBlock`/`layoutList`/`layoutDetails`/`layoutBlockQuote` stamps each `.checklist` marker with its path. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2ListMarkerView` installs a tap gesture when `interactive`, flips its own `CheckNode` optimistically, and fires `onCheckboxTapped(path, newValue)`; `InstantPageV2View.checkboxTapped` routes it up (mirrors `detailsTapped`). |
| `submodules/TelegramUI/Components/ChatControllerInteraction/Sources/ChatControllerInteraction.swift` | `canEditMessageRichText: (EngineRawMessage) -> Bool` (sync gate, mirrors `canSetupReply`) + `toggleMessageRichTextCheckbox: (EngineMessage.Id, [Int], Bool) -> Void` (the edit action). Both have no-op defaults so only the real chat wires them. |
| `submodules/TelegramUI/Sources/ChatController.swift` | Implements both closures. The toggle looks up the message, re-checks `canEditMessage`, applies `togglingCheckbox`, and submits via `pendingUpdateMessageManager.add(text: "", richText:)` — the composer's rich-edit path (mirrors the native-todo `requestToggleTodoMessageItem`). |
| `submodules/TelegramUI/Components/Chat/.../ChatMessageRichDataBubbleContentNode.swift` | `checkboxesInteractive(item:resolved:)` gate + sets `pageView.checkboxTapped` per apply. |

Non-obvious invariants:

- **Checkbox identity is a structural `[Int]` path**, not an ordinal: each element indexes the current container's children — block-array index at page/`.details`/`.blockQuote`/list-item-`.blocks` levels; item index at `.list` level. The layout stamping (`InstantPageV2Layout`) and the toggle walker (`InstantPageCheckboxToggle`) MUST keep identical semantics — they were built and reviewed as a matched pair. Decoupled from `<details>` expand/collapse state.
- **The path is absolute-from-root only because every `layoutBlockSequence` that can reach a list is entered with a correct prefix.** The two secondary `layoutBlockSequence` call sites (table cells, hard-coded `[.paragraph]`; and the details title) contain no lists, so no checkbox is produced there; a `kind != .cell` guard in `layoutList` is belt-and-suspenders against future misrouting.
- **The toggle applies to `attribute.instantPage`, so taps must only ever fire against that page.** The bubble's `checkboxesInteractive` gate enforces this: interactive only when `resolved.key` is `.original` AND `resolved.instantPage === attribute.instantPage` (class identity — excludes the show-more `fullInstantPage` rendering, which shares the `.original` key but is a different `InstantPage` object) AND `canEditMessageRichText(item.message)`. Translations (`.translated`) and in-flight pending edits (`.pendingEdit`) are inert. Non-editable messages (incoming, past the edit window) are inert — and AI-streamed rich messages are incoming, hence never tappable.
- **Optimistic flip, model supersedes.** The marker view flips its own `CheckNode` on tap; the pending/edited attribute re-render then supersedes (or, on failure, reverts, since the model was unchanged). Known minor edges of this state-free optimism: (1) an unrelated `update()` before the pending edit lands rebuilds the marker from the old `checked`, briefly reverting the visual; (2) a rapid double-tap re-reads the still-stale `checked` and re-sends the same value rather than toggling back — the pending-edit manager coalesces, so the net state is consistent, just not a double-toggle. Both are acceptable given the edit lands promptly.
- **Gating uses closures because `canEditMessage` is `internal` to the `TelegramUI` module** and the rich-data bubble lives in a separate component module that cannot call it. The two closures bridge the boundary; **their init-parameter order must match the `ChatController` call-site order** (Swift requirement) — they sit between `displayTodoToggleUnavailable` and `openStarsPurchase`.

## InstantPageBlock.blockQuote nested blocks

`InstantPageBlock.blockQuote` carries `(blocks: [InstantPageBlock], caption: RichText)` — a sequence of nested page blocks (paragraphs, headings, lists, code, even nested quotes), not the legacy text-only payload. `.pullQuote` is unchanged (still `(text: RichText, caption: RichText)`; the TL API has no `pullQuoteBlocks` constructor).

Spec: [`docs/superpowers/specs/2026-05-29-instantpage-blockquote-blocks-design.md`](docs/superpowers/specs/2026-05-29-instantpage-blockquote-blocks-design.md).

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_InstantPage.swift` | Enum case shape; Postbox coding (legacy `"t"` lift → new `"b"` object array); equality (array-aware, mirrors `.collage`); FlatBuffers codec. |
| `submodules/TelegramCore/FlatSerialization/Models/InstantPageBlock.fbs` | `InstantPageBlock_BlockQuote`: `text` (now optional, legacy fallback) + `caption (required)` + new `blocks:[InstantPageBlock] (id: 2)`. **Source of truth**; Bazel regenerates the `*_generated.swift`. |
| `submodules/TelegramCore/Sources/ApiUtils/InstantPage.swift` | Parse both `pageBlockBlockquote` (lift text→`[.paragraph]`) and `pageBlockBlockquoteBlocks`; encode legacy-when-possible. |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `layoutBlockQuote(blocks:…)` recurses into children; legacy single-paragraph fast path delegates to `layoutQuoteText` (the renamed shared text core, also used by `.pullQuote`). |
| `submodules/InstantPageUI/Sources/InstantPageLayout.swift` | V1 `.blockQuote` arm recurses via `layoutInstantPageBlock(...)`; same single-paragraph fast path. |
| `submodules/BrowserUI/Sources/BrowserMarkdown.swift` | Forward: one quote carrying all child blocks. Entity-expressibility gate (below). |
| `submodules/BrowserUI/Sources/InstantPageToMarkdown.swift` | Reverse: `markdownBlockQuoteBlocks(_:)` recurses per child and prefixes `> ` per line. |
| `submodules/TelegramStringFormatting/Sources/InstantPagePreviewText.swift` | Concatenates child `previewText()`s + caption. |

### Non-obvious invariants

- **Legacy shapes lift to `[.paragraph(text)]` at every decode boundary.** API `pageBlockBlockquote`, the Postbox `"t"` key (old cached pages), and the FlatBuffers `text` field (now optional) each lift into a single-paragraph blocks array. New writes emit only `blocks` (`"b"` / the FB vector). So pre-existing stored pages and older senders decode unchanged.
- **Outbound stays on the legacy wire constructor when the shape allows.** `apiInputBlock()` emits `pageBlockBlockquote` for empty or single-`.paragraph` quotes (so older recipients understand the common chat case) and `pageBlockBlockquoteBlocks` only for genuinely nested quotes.
- **Both renderers share one text core for the single-paragraph fast path.** `layoutQuoteText` (V2; the function formerly named `layoutBlockQuote`, `isPull:` distinguishes pull vs block) and the V1 fast-path branch keep the legacy italicized-body styling; nested children render with their own normal category styling.
- **V1 and V2 have SEPARATE spacing functions, and must keep them** (`InstantPageLayoutSpacings.swift`, split back apart 2026-08-17). `spacingBetweenBlocksV1(upper:lower:)` is the Instant View reader's original flat table of absolute gaps (20 / 25 / 27 / 31 / 32 / 34), tuned against the reader's large page type; `spacingBetweenBlocks(upper:lower:kind:metrics:)` is V2's padding-plus-base model tuned against the chat bubble's 15/17pt type. They were briefly unified behind the V2 model, which collapsed the reader's rhythm — the two share no rule, so any common body would just be a switch on which renderer is asking. **The six V1 call sites are all in `InstantPageLayout.swift`; every other caller is V2.** Guarded by `InstantPageV1SpacingTests`, which pins V1's literals and asserts the two functions still disagree. The V2 model below is unchanged.
- **Block spacing (V2) is one base gap plus a per-type padding** (`InstantPageLayoutSpacings.swift`). `spacingBetweenBlocks` is `upper.verticalPadding + instantPageBaseBlockSpacing + lower.verticalPadding`, with two overrides ahead of it: a flush side yields 0, and two `.paragraph` (body) blocks have no gap at all — not even their padding. At a sequence edge only the present block's padding applies; the base is strictly a between-two-blocks quantity. `InstantPageBlock.spacing` is the single tuning surface — every type seeds `verticalPadding` at 8.0, so a non-paragraph pair currently reads 24pt. The flush flags are **directional** (`flushAbove` / `flushBelow`) because each structural zero is one-sided: `.cover` / `.channelBanner` are flush above but take a real gap below, `.relatedArticles` is flush below, `.anchor` is flush both ways. Consecutive `.details` rows deliberately LOST their flush (0 → 24pt) — that is flush-against-its-own-kind, which no per-type property expresses; the fix, if it matters, is a `stacksWithSameType` property, not a reinstated pairwise case. `spacingBetweenBlocks` still takes `kind` but does not read it, kept for container-specific spacing later.
- **Nested children use a FIXED 10pt inter-child gap, not `spacingBetweenBlocks`.** The full page-flow spacing (24pt around quotes) is too airy when nested, and 0 is too tight. `childSpacing = 10.0` lives in both layout files; the first child hugs the container's `verticalInset` (no leading gap). Combined with a nested quote's own 4pt top inset this gives ~14pt effective separation.
- **Entity-expressibility:** a quote is entity-expressible (→ regular message path) only if its caption is empty AND every child is an entity-expressible `.paragraph`. A nested-structure or multi-paragraph quote is not, so it sends via the rich path. **Behavior change:** markdown `> p1\n>\n> p2` is now ONE quote with two paragraphs (rich) rather than two consecutive entity quotes — correct semantics.
- **The enum-arity change is compile-enforced** across all modules; the full Bazel build is the completeness gate (no per-module build). `CachedFaqInstantPage.swift` matches `case .blockQuote:` payload-less and needs no edit. `BrowserReadability.swift` constructs `.blockQuote(blocks: [.paragraph(.italic(...))], …)` and is easy to miss in the spec's file list — grep `\.blockQuote(` repo-wide when touching the case again.

## Inline buttons & document blocks

The TL schema that reshaped `keyboardButton`/`keyboardInlineButton` also added inline buttons inside
`RichText` (`textButton`), block-level button rows (`pageBlockButtonRow`), and a generic file block
(`pageBlockDocument`). All three are modelled losslessly (Postbox + FlatBuffers + both Api
directions) **and rendered in V2**; V1 Instant View still skips them via its `default:` arms.
Because the models round-trip, no cached page needed re-fetching when the rendering landed.

A later revision split `keyboardInlineButton` back out into its own `KeyboardInlineButton` type
(plus `keyboardInlineButtonRow`, which `replyInlineMarkup.rows` now carries). That split does not
reach this module: `pageBlockButtonRow` carries `Api.PageButton`, a separate type, and the reply-markup
domain model merges keyboard and inline buttons anyway.

The models were added first and left unrendered on purpose, so that the rendering could land as a pure
view change with no cache migration. That is why the sections below separate the (lossless, tested)
model layer from the V2 rendering built on top of it.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_InstantPageButton.swift` | `InstantPageButton` (`text`/`action`/`color`) + Postbox coding, **and** the `ReplyMarkupButtonAction` FlatBuffers codec — which exists only to serve page buttons, hence living beside its consumer. |
| `submodules/TelegramCore/Sources/ApiUtils/InstantPageButton.swift` | `Api.PageButton` ⇄ model, `richButtonStyle` ⇄ `ReplyMarkupButton.Style.Color`, and `apiInlineButtonType()` for the outgoing direction. |
| `submodules/TelegramCore/FlatSerialization/Models/RichText.fbs` | `RichText_TextButton`, `InstantPageButton`, and the 10-member `InstantPageButtonAction` union + tables. |
| `submodules/TelegramCore/FlatSerialization/Models/InstantPageBlock.fbs` | `InstantPageBlock_ButtonRow`, `InstantPageBlock_Document`. |
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_RichText.swift` | `case textButton` (Postbox tag **29**) + `==` + `plainText` (returns the label) + FlatBuffers codec. |
| `submodules/TelegramCore/Sources/SyncCore/SyncCore_InstantPage.swift` | `case buttonRow` (tag **31**), `case document` (tag **32**), codecs, and the `allMedia(mediaDict:)` arm. |
| `submodules/TextFormat/Tests/` | `InstantPageButtonModelTests`, `RichTextButtonTests`, `InstantPageBlockNewCasesTests` — 24 tests over both codecs. |
| `submodules/InstantPageUI/Sources/InstantPageInlineButton.swift` | `InstantPageInlineButtonAttachment` (the measured payload) + `instantPageInlineButtonAttachment(button:labelString:maxWidth:)`, the **single** construction path for both inline and row pills, incl. the ellipsis truncation + `instantPageButtonColors(_:theme:isInline:isDisabled:)` + the padding and font-size constants. |
| `submodules/InstantPageUI/Sources/InstantPageV2ButtonViews.swift` | `InstantPageV2ButtonPillView` (one pill: `backgroundColor` fill + press state + label recolour + the `TextLoadingEffectView` shimmer and its `Promise<Bool>` subscription), `InstantPageV2ButtonPillContentView` (draws the label + type icon, at whichever placement its `isInline` selects), `InstantPageV2InlineButtonView`, `InstantPageV2ButtonRowView`. |
| `submodules/TelegramUI/Components/RichTextButtonIcons/` | The action → icon mapping, its sizes/insets, and the `richTextEditorButtonIcon` bridge the editor hosts register. A leaf module because both the renderer and the editor need it — see "The type icon". |
| `submodules/InstantPageUI/Sources/InstantPageV2DocumentContentNode.swift` | `InstantPageV2DocumentContentNode` (file row) + `InstantPageV2DocumentView` (item view). |
| `submodules/InstantPageUI/Sources/InstantPageTextStyleStack.swift` | `.semibold` / `.medium` baseline weights (button labels are semibold regardless of the surrounding paragraph) + the `InstantPageInlineButtonAttribute` key. |
| `submodules/InstantPageUI/Sources/InstantPageTheme.swift` | `buttonDanger{Background,Foreground}Color`, `buttonSuccess{Background,Foreground}Color` (split so a host can pass a solid fill: the default 15% tint is unreadable over a saturated outgoing bubble), `checkboxFill`, `checkboxForeground` — all defaulted, all threaded through `withUpdatedFontStyles`. |

### Geometry (as shipped; tuned by eye, not derived)

| | Inline `textButton` | Block `pageBlockButtonRow` |
|---|---|---|
| Label font | 15pt semibold | 16pt semibold |
| Horizontal inner padding | 7pt | 7pt |
| Vertical inner padding | 1pt | implied by the fixed height |
| Height | derived: label ink + 2·vPad | fixed **40pt** (a touch target) |
| Corner radius | `bounds.height / 2` (capsule) | `bounds.height / 2` → 20pt |
| Width | label ink + 2·hPad + (icon ? 14 : 0), capped at the line width | justify: equal share of the row, wrapping at 8; left/center/right: label ink + 2·(badge ? 18 : 7), greedy wrap |
| Type icon | trailing the label: 4pt gap + a 10×10 box, centred on the label's **cap** box | 10×10 badge inset 8/6 from the top-right corner |

Font sizes are **fixed**, not scaled by the Instant View font-size setting and not by the chat's Text Size
(`contentScale`, see "Text Size / content scale") — a pill is a control with its own typography, and a wider
pill would move line breaks the editor has to mirror. The two pill shapes therefore read differently side by side: a block pill
is much taller than an inline one, and its radius is correspondingly larger. If they ever need to look
related, a fixed radius rather than `height / 2` is the lever.

### The type icon

Both pill kinds carry the bot-keyboard type icon for their action, from the one mapping in
`submodules/TelegramUI/Components/RichTextButtonIcons` (`richTextButtonIconName(for:)`). The
**placement differs by kind, and that is forced, not stylistic**: an inline pill is the label's ink box
plus 2pt of padding — about 20pt tall — so a corner badge has nowhere to sit without being shaved by
the capsule clip. An inline icon therefore trails the label on the same optical line and the pill is
measured `richTextInlineButtonIconReserve` (14pt) wider to hold it.

That module exists as its own leaf rather than living in `InstantPageUI` because **both** the V2
renderer and the rich-text editor draw these, and the editor's composer host cannot import
`InstantPageUI` — `InstantPageUI` already depends on `ChatRichTextEditorComposer`, so that edge would
be a cycle.

- **The inline reserve is unconditional width, so it moves line breaks.** Unlike the block badge's
  side inset (which only binds in the row layout's tight-padding fallback), it widens every
  icon-bearing inline pill, and therefore re-wraps the paragraph the pill sits in. This is why the
  editor must reserve the identical amount even where it draws nothing — `RichTextButtonMetrics`
  carries `inlineIconReserve`, pinned to the renderer's constant by `RichTextV2ButtonParityTests`.
- **The reserve belongs to the label+icon GROUP, not to the label.** `instantPageButtonLabelOrigin`
  recovers the label's ink width as `size.width − 2·padding − iconReserve` and centres the whole
  group. Omitting either subtraction slides the label right by half the reserve — and drags the
  custom-emoji squares with it, since they are derived from that same origin.
- **The icon centres on the label's cap box, not the pill box** (`baseline − capHeight/2`). The pill's
  box is asymmetric around the text because it also holds the descender, so pill-centring sits the icon
  visibly low against the letters it follows. The two differ by ~0.6pt at 15pt.
- **Whether there is an icon is a separate question from whether its image loaded.** The editor's seam
  (`RichTextButtonIcon`) answers existence from the pure action → name lookup and produces the ink
  lazily through a tint closure. A bare `UIImage?` would conflate the two: an asset that fails to load
  (an unbundled unit test, a renamed file) would silently re-flow every paragraph holding a button, and
  only in the editor — the renderer decides the same question from the name and would keep reserving.
  The closure also lets the row packer ask the question per padding attempt without rasterising.
- **The editor's icon must be resolved through `ButtonActionCodec`, not from `ButtonAction` directly.**
  `RichTextEditorCore` can name only `url` / `copyText` / `disabled`; every other action travels as an
  opaque `.unsupported(kind:payload:)`. `richTextEditorButtonIcon` decodes it back so a
  `.openUserProfile` button draws the profile icon in the composer, and — the case that actually bites
  — so an iconless `.callback` reserves nothing on either side. `richTextButtonHasBadge` remains as the
  coarse fallback for an editor with no provider registered, and is wrong for exactly that case.

### Non-obvious invariants

- **`InstantPageButton` and `InstantPageButtonAction` tables MUST live in `RichText.fbs`, not
  `InstantPageBlock.fbs`.** `RichText_TextButton` needs them and `InstantPageBlock.fbs` already
  `include`s `RichText.fbs`, so defining them there creates an include cycle.
- **`ReplyMarkupButtonAction` is deliberately reused as the page-button action type**, so a Stage 2
  page-button tap can call the existing `ChatMessageItemView.performMessageButtonAction` instead of a
  parallel dispatch. The type is therefore **wider than the schema allows**: `text`, `requestPhone`,
  `requestMap`, `setupPoll` and `requestPeer` come only from `Api.ButtonType` and cannot occur on a
  page button. Only 10 cases are reachable, which is exactly the FlatBuffers union's membership; the
  five unreachable ones collapse onto `disabled` when encoded (Postbox stays lossless).
- **`richTextIsEntityExpressible` returns `false` for `textButton`** (`BrowserMarkdown.swift`), so a
  button forces the rich send path. That file has `default:` clauses — had this defaulted to `true`,
  button-bearing content would be sent as plain message entities and the buttons destroyed at send
  time.
- **`allMedia(mediaDict:)` and `applyMediaResourceChanges` both need `.document`, and neither is
  fully compiler-protected.** `allMedia` ends in `default:` (omitting `.document` compiles and then
  silently stops the page fetching its file). `applyMediaResourceChanges`
  (`State/ApplyUpdateMessage.swift`) hands a locally uploaded file's resource data to the cloud
  resource on send confirmation — omitting `.document` re-downloads a just-sent file.
- **`InstantPageAnchorPath` intentionally does NOT recurse into `.buttonRow`.** That file's recursion
  set must match what `InstantPageV2Layout.layoutBlock` recurses through, because both drive a shared
  `detailsIndexCounter` ordinal; since V2 does not lay out `.buttonRow`, recursing would
  desynchronise `<details>` anchor navigation. Anchors inside a **`RichText.textButton`** *do*
  resolve — that descent lives in `richTextContainsAnchor`.
- **A button behaves as a discrete atom, never as flowing text**, in every text-shaping helper: not
  split by a prefix drop (`markdownDroppingPrefixLength`), always displayable
  (`markdownHasDisplayableContent`), never whitespace-only (`markdownIsWhitespaceOnly`), and not
  trimmed internally (`BrowserReadability`'s `trimStart`/`trimEnd`/`trim`/`addNewLine`). It sits with
  `.image` and `.textCustomEmoji`.
- **KNOWN LOSSY, deferred: editing a button-bearing rich message drops its buttons.** Markdown has
  no spelling for a button, so the InstantPage → markdown → InstantPage round-trip keeps the label
  and loses action + style. `InstantPageToMarkdown.swift` states this at the site. The fix, if picked
  up, is a positive `InstantPage.containsButtons` check gating the edit affordance — not a `default:`
  clause.
- **`keyboardButtonStyle` is bit-identical at `flags.10`** to the pre-unification constructors, so
  `ReplyMarkupButton.Style` and its rendering in `ChatMessageActionButtonsNode` were untouched by the
  migration.

### Rendering invariants (V2)

- **A button row's alignment comes from `pageBlockButtonRow`'s flag bits**, read as
  `InstantPageButtonRowAlignment` (`justify = 0`, so cached pages keep the old layout with no
  migration; precedence `left > center > right` when a malformed row sets several bits). Justify keeps
  the equal-column split and its fixed 8-per-row chunking; left/center/right hug the label and wrap
  greedily by width, still capped at 8. **Each wrapped row is aligned on its own width**, so a short
  last row re-centres rather than staying flush with the row above.
- **One RTL rule covers all four modes: a row lays out in the page's reading direction.** `align_left`
  means *leading* (the right edge on an RTL page), `align_right` means trailing, and the first button
  of a row sits at the reading start — so pills run right-to-left on RTL pages, justify included. This
  deliberately differs from V2 table cells, which apply `.left`/`.right` literally.
- **Pass 1's `maxWidth` is what makes pass 2 safe.** Every pill is measured capped to
  `availableWidth − 2·extra`, so no single pill can exceed the row; greedy packing therefore never
  produces an overflowing row, and an over-long label ellipsises instead. `extra` is the badge reserve
  *beyond* the padding the attachment builder already adds (`iconReserve − hPad`), because the pill
  centres its label under a top-right badge.
- **Justify's truncation cap is knowingly 14pt more conservative** than the hug path's: it passes
  `columnWidth − 2·iconReserve` and the attachment builder subtracts `2·hPad` again. Unifying them
  would shift where ellipses appear on already-published pages, so it is left alone and documented at
  the site.
- **`textButton` follows the inline-FORMULA path, not the inline-image path.** The two disagree twice,
  and both choices matter. (1) The formula run delegate reports **real** ascent/descent
  (`InstantPageTextItem.swift:854`) so CoreText grows the line box; the image one reports `0/0`
  (:818) and then owns manual centring with symmetric bleed. A pill is taller than its glyphs, so the
  image model would overlap the lines above and below. (2) Formulas are emitted as **top-level items**
  into `additionalItems`; images are created at view-update time into a sibling container above the
  reveal mask. A button must *be* a view (own press state, own tap target), which the formula path
  already gives.
- **The attachment must carry its own measurements.** The V2 line-breaker raises
  `lineAscent`/`lineDescent` from the attachment itself and has no `styleStack` to re-measure with —
  hence `InstantPageInlineButtonAttachment` holds `size`/`ascent`/`descent`, mirroring
  `InstantPageMathAttachment.rendered`.
- **`instantPageInlineButtonAttachment(button:labelString:)` is the ONLY construction path.** Inline
  and row pills must agree on whether `size` includes padding, because the pill view's label centring
  reads exactly `size.width - 2 · hPad`. Two independent constructions drifted apart once already.
- **The pill recolours its label in the view, not at construction.**
  `attributedStringForRichText` bakes the *paragraph* colour and has no `InstantPageTheme`, so
  `instantPageButtonColors(...).label` can only be applied where the theme exists — the view. Skipping
  this silently renders `danger`/`success` labels in body-text colour and never dims disabled ones.
- **`clipsToBounds` is what makes the pill a pill.** The view implements `draw(_:)`, so UIKit paints
  `backgroundColor` **into the layer's `contents` bitmap**; `cornerRadius` rounds the layer's own
  background but does **not** clip `contents` without `masksToBounds`. Without the clip the rounded
  corners are drawn and then covered by the square bitmap, and the pill renders as a rect.
- **Line-height inflation: never compare `attachment.ascent` against `lineAscent` directly.**
  `lineAscent` starts at `fontLineHeight`, which is the *reduced* `floor(ascender + descender)` box
  (~12.4pt at 17pt — `descender` is negative), whereas `attachment.ascent` comes from
  `CTLineGetTypographicBounds` and is a *full* font ascent (~16.3pt for a 15pt label plus padding).
  Comparing them grew every button-bearing line by ~4pt. The button loop therefore discounts
  `lineBoxTopInset` (the ascender headroom the line stack is already shifted down by) and
  `baselineToNextTopSlack` (inter-line spacing the next line does not need) — the same reserves inline
  formulas bleed into — and only genuine overflow grows the line.
- **An overflowing pill needs an arm in the re-break block.** A pill's entire width lives in a
  `CTRunDelegate` on one placeholder character, so `CTTypesetterSuggestLineBreak` can suggest a break
  *after* it. The layout recovers by discarding a line wider than the bound and re-breaking before the
  attachment — but only for attachment kinds listed there. Images, formulas and buttons each have an
  arm; a new inline attachment kind needs one too or it will silently spill past the bubble.
- **A pill wider than the whole line is truncated, because it cannot be re-broken.** That recovery path
  is guarded by `lineCharacterCount > 1`, so a pill alone on a line is left alone. Hence
  `instantPageInlineButtonAttachment(maxWidth:)` truncates the label with a tail ellipsis on cluster
  boundaries (`CTTypesetterSuggestClusterBreak`), the ellipsis inheriting the label's own attributes.
- **The cap arrives via `inlineButtonMaxWidth`, deliberately NOT `boundingWidth`.** Three traps here:
  (1) `boundingWidth` is `nil` on the V2 paragraph path — only table cells pass it — so a cap routed
  through it silently never applies; `layoutParagraph` passes the width explicitly. (2) The 31 recursive
  `attributedStringForRichText` calls must forward the cap, or a button nested in a `.concat` (the normal
  case) loses it. (3) `boundingWidth` *also* drives the inline-**image** clamp
  (`fittedToWidthOrSmaller`), which has never been active on this path, so reusing it would silently
  resize existing inline images.
- **KNOWN BUG, pre-existing and unfixed: recursion never forwards `boundingWidth`.** A *nested* inline
  image therefore never gets its `fittedToWidthOrSmaller` clamp — only a top-level one, and only on
  paths that pass the width at all (table cells). Independent of the button work.
- **`checkboxFill` / `checkboxForeground` are misnamed for their current use.** They are the `.primary`
  button's solid fill and label colour; nothing checkbox-related reads them. `InstantPageListItem`
  checkboxes still derive their own colours. Rename or wire them up before relying on the names.
- **A button-label custom emoji uses a DIFFERENT run delegate from a body-text one**, rewritten by
  `instantPageButtonLabelWithFittedEmoji` inside `instantPageInlineButtonAttachment` — the single
  construction path — and therefore before truncation and before measurement, so the reserved advance
  and the drawn square are the same number by construction. Two of the body-text delegate's three
  numbers are wrong in a pill. Its **width** is `A − D + 4·pointSize/17`, which overflows the pill's
  ink box (≈21.3 vs ≈19.7pt at the 15pt inline label font) and gets shaved by `clipsToBounds`; a
  button-label emoji is sized to `A − D` instead, so it reads slightly smaller than the same emoji in
  the surrounding paragraph. Its **descent** is `font.descender`, which is NEGATIVE — inert in body
  text, because the V2 line layout pins `lineDescent` to `fontDescentBelowBaseline` and never reads
  it, but a pill measures itself with `CTLineGetTypographicBounds`, so for a label that is *only* an
  emoji (no other run contributing a positive descent) the line's descent comes back negative and the
  pill collapses from ≈19.7pt to ≈12.9pt. The button-label delegate negates it.
- **`instantPageButtonLabelOrigin` is shared by the drawing and the emoji placement, deliberately.**
  It is the math that used to be inlined in `InstantPageV2ButtonPillContentView.draw(_:)`, `- 0.33`
  optical nudge included. Recomputing it at the emoji site instead is the same drift hazard the
  "single construction path" rule already exists for.
- **The placement functions must not read a pill's live `bounds`.** `updateInlineEmoji()` runs during
  `update(layout:theme:animation:)`, before a freshly created `InstantPageV2InlineButtonView` has run
  `layoutSubviews` — so its pill's frame is still zero. Both functions take `pillSize` explicitly, and
  the renderer sources it from the item (`item.frame.size`, `item.buttons[i].frame.size`).
- **Pill emoji live in the page's central `inlineStickerItemLayers` registry, not in the pill.** That
  is what makes them inherit the reveal, energy-setting and visibility-rect gates rather than needing
  a parallel implementation of all three. `InstantPageEmojiLayerData.textView` is therefore generalised
  to `hostView: UIView?`: `updateEmojiReveal` downcasts it, so a pill host lands in the existing `else`
  → `revealed = true`, which is correct because a pill already pops in atomically when its paragraph
  finishes revealing. The button views are deliberately NOT given a `renderContext` — the renderer
  creates the layers and already holds one.
- **`emojiContainerView` sits ABOVE the pill's `contentView`, and that ordering is load-bearing twice
  over.** The label is painted into the content view's layer `contents` bitmap, so a sublayer must be
  above it to be seen at all; and the loading shimmer is deliberately inserted BELOW `contentView`, so
  an emoji placed there would be washed by the sweep instead of riding on top of it.
- **An emoji layer's `dynamicColor` is the pill's `resolvedLabelColor`, not the label string's baked
  colour** — the same reason the label itself is recoloured in the view rather than at construction.
  Sourcing it from `attachment.labelString` would tint a template emoji in a `danger` or disabled pill
  with body-text colour.
- **Not covered: spoilers inside a button label.** A pill renders no spoiler treatment at all, so an
  emoji under a `.textSpoiler` in a label shows unhidden — exactly as the label text around it already
  does.
- **`richButtonStyle`'s `link:flags.3` is stored as its own `InstantPageButton.isLink`, not as a
  fourth `ReplyMarkupButton.Style.Color` case.** That enum is shared with bot reply markups, whose
  `keyboardButtonStyle` has no link bit, and it is `Int32`-raw-valued and persisted by both features.
  Keeping the facts independent also means `link` + `bg_danger` round-trips losslessly even though
  the renderer makes `link` win. No TL regeneration was needed: `Api.RichButtonStyle` is already a
  bare `flags: Int32` and its constructor id `63312061` is the same `0x3C610BD`.
- **`apiFlagsAndStyle()` accumulates the flag word and THEN checks it.** Its previous shape opened
  with `guard let color = self.color else { return (0, nil) }`, which would drop the style object
  entirely for a link-only button and lose `flags.3` on the way out. `apiRichStyleFlagWord` is public
  so that composition is testable.
- **`link` wins over the background bits, and the link uses the page's ordinary link colour.** Same
  first-match precedence as `bg_primary > bg_danger > bg_success` and `align_left > center > right`,
  so a malformed style is deterministic rather than evaluation-order dependent.
- **A link-styled button is only honoured on an inline `RichText.textButton`.** A `pageBlockButtonRow`
  entry stores and round-trips `isLink` but never reads it — rows always draw pills.
- **The link route produces no attachment**, so it is invisible to every piece of attachment
  machinery: the line-breaker's re-break arm, the `lineAscent` discount, `additionalItems`, and the
  pill view. Two side effects follow: a link button's label is selectable and copyable (a pill's is
  not, being outside the text), and it reveals character-by-character with its paragraph instead of
  popping in atomically.
- **`.link(false)` is pushed for every non-`.disabled` action, not only `.url`.** The action decides
  which tap attribute is attached, not whether the label looks like a link — a link-styled
  `.callback` is visually indistinguishable from a link-styled `.url`. Note also that the link route
  deliberately does NOT push `.fontSize`/`.medium`: a pill owns its typography, a link inherits the
  paragraph's.
- **An emoji-only link-button label gets NO underline.** The underline on a link button is never
  markup: `InstantPageTextStyleStack.textAttributes()` adds it when the link colour equals the
  surrounding text colour, which is the normal state in the chat-bubble themes and in the
  caption/credit categories (see `setupStyleStack`). Under a custom emoji it draws as a stray rule —
  wider than the glyph and detached from it — and there is no word for it to distinguish, so
  `attributedStringForLinkStyleButton` strips `underlineStyle` when `richTextIsOnlyCustomEmoji(button.text)`.
  That helper's switch is exhaustive on purpose (a new `RichText` case must decide) and answers `false`
  for `.underline`, which is how an explicitly underlined label inside the button keeps its underline.
  Whitespace and non-underlining wrappers (`.bold`, `.url`, `.textSpoiler`, …) still count as
  emoji-only; one word anywhere in the label brings the underline back.
- **Only `.url` rides `TelegramTextAttributes.URL`.** That is what buys the long-press menu, the
  concealed-URL confirmation, anchor scrolling and the link-progress shimmer for free.
  `.urlAuth` and `.openWebView` carry URLs but take the button-dispatch route instead, because their
  dispatch differs from opening a plain URL. `.disabled` renders as ordinary text with no link
  styling and no attribute at all — a link-coloured span that does nothing is worse than plain text.
- **`InstantPageButtonActionAttribute` must appear in `linkSelectionRects`'s `interactiveKeys`
  allow-list.** Omitting it costs the tap highlight *and* the loading shimmer, silently, because the
  bubble's `linkProgressRects` is computed from exactly those rects.
- **`.custom` tap actions do not receive `tapAction.activate`.** `ChatMessageBubbleItemNode`'s
  `.custom` arm calls the closure and ignores the field, so the link-button arm mints its own promise
  by calling `makeActivate(...)()` inside the closure — that call is what wires the shimmer. Any
  future `.custom` arm wanting progress must do the same.
- **Interactive V2 items route taps through a pageView closure, NOT `tapActionAtPoint`.**
  `buttonTapped` on `InstantPageV2View` mirrors the pre-existing `checkboxTapped`
  (`InstantPageRenderer.swift:178`). `.custom` + `rects` on `ChatMessageBubbleContentTapAction` is for
  *text-attribute* taps (entities, spoilers, "Show more"), not item views.
- **The `reuse` arm must re-wire `onButtonTapped`.** A recycled view may have been created against a
  previous `InstantPageV2View`; without re-wiring, taps silently stop working after scrolling away and
  back.
- **`performMessageButtonAction` lives on `ChatMessageItemView`, so a content node cannot call it.**
  The rich bubble synthesises a `ReplyMarkupButton` and calls
  `ChatMessageBubbleContentNode.performRichTextButtonAction`, a closure wired by
  `ChatMessageBubbleItemNode` (~:5060) alongside `requestInlineUpdate`/`requestFullUpdate`.
- **`InstantPageTheme.withUpdatedFontStyles` (:173) reconstructs the struct field by field.** Any
  field omitted there silently reverts to its `init` default — for
  the button danger/success colours that resets a bubble's theme-derived colours the moment the
  user changes Instant View font size. Nothing warns; it compiles.
- **Mid-paragraph buttons pop in when their whole paragraph finishes revealing**, not when the cursor
  reaches them, because an inline attachment lands in `additionalItems` *after* the text item it sits
  inside and the cost map walks items in array order. **Formulas already behave this way**; fixing it
  means interleaving sub-item cost entries inside a text entry, i.e. changing the cost model.
- **`pageBlockDocument` is produced by the RichText article editor** (attach a file → `MediaKind.document`
  → `InstantPageBlock.document`), so the renderer is exercised by real content. Download and cancel
  work through the **fetch manager**
  (`messageMediaFileStatus` keys progress off its `hasEntry`, so `freeMediaFileInteractiveFetched` would
  show no ring). **Runtime-verified 2026-07-31** (thumbnails, download/cancel, tap-to-open) — this block
  had never been on screen before.
- **Tapping a downloaded file opens it through the stock pipeline.** The row's `.Local` tap travels
  `InstantPageV2DocumentContentNode.openDocument` → `InstantPageV2DocumentView.onDocumentTapped` →
  `InstantPageV2View.documentTapped` → `ChatMessageBubbleContentNode.openRichTextDocument` →
  `ChatMessageBubbleItemNode` → `controllerInteraction.openMessage(…, mediaSubject:
  .richTextMedia(file.fileId))`, which reaches `BrowserScreen` for pdf/markdown,
  `presentDocumentPreviewController` otherwise, the SVG warning and `canShare`. **Naming the medium is
  load-bearing**: a rich message's files live in the `RichTextMessageAttribute`'s `InstantPage`, not
  `message.media`, so `mediaForMessage`'s default first-match resolution over `effectiveMedia` could open
  a DIFFERENT attachment — which is exactly why this was previously left inert. `mediaForMessage` returns
  `[]` on a named-but-absent medium: opening nothing beats opening the wrong file.
- **`documentTapped` must be wired in BOTH renderer arms** (create and reuse), like `buttonTapped`. A
  recycled view may have been created against a previous `InstantPageV2View`; without re-wiring, taps
  silently stop working after scrolling away and back.
- **The row has two modes.** `isAuthoring` (the editor, via `StandaloneInstantPageDocumentView`) shows the
  thumbnail (or a static file glyph when there is none), never fetches, and its tap is inert — a just-picked
  file is already local and an edit-loaded cloud file is re-sent by reference. Message mode keeps download /
  progress / cancel plus the open affordance. Built with `message: nil` and NO authoring flag, `fetchStatus`
  stays nil and `updateFetchState` maps that to `.download` — a download arrow over a file the user just chose.
- **LOAD-BEARING — `tapped()` and `updateFetchState()` must partition `fetchStatus` IDENTICALLY**, or the
  control lies about what tapping it does. In particular **`.none` means "status not known YET"** (the
  `messageMediaFileStatus` subscription is async, so this is the window right after a bubble appears), **not
  "downloaded"**: it renders as a download arrow, so it must FETCH. Mapping `.none` alongside `.Local` to
  open — the shape the original inert `break` invited — opened undownloaded files instead of fetching them.
  Partition: `.Local` → open; `.Fetching` → cancel; `.Remote`/`.Paused`/`.none` → fetch.
- **The thumbnail is a sibling node, which changes which foreground colour the control uses.** A file with a
  preview (`previewRepresentations` — the picker populates them for `image/*` and `application/pdf` in
  `PollAttachmentScreen`; `immediateThumbnailData` or an `image/*` mime also qualify) renders a
  `TransformImageNode` fed by `chatMessageImageFile(…, thumbnail: true)`, in the SAME Ø40 slot as the status
  disc, with the disc scrimmed over it (`mediaOverlayControlColors`) and hidden entirely when idle
  (authoring, or `.Local`). **Do NOT pass `foregroundNodeColor: .clear` for the overlay look:**
  `SemanticStatusNodeAppearanceContext.effectiveForegroundColor` prefers `overlayForegroundNodeColor` only
  when the status node owns a `backgroundImage`, and ours is nil — so a clear foreground renders the download
  arrow and the progress ring **invisible** over artwork. Pass the overlay colour as the foreground.
- **The thumbnail deliberately does NOT change the row height.** Telegram's own file bubbles grow to 59–74pt
  for artwork, but `MediaBlockBox` sizes the editor's row from `kind` alone — it is account-free and cannot
  resolve the file — so a thumbnail-dependent height would desync the editor preview from the V2 renderer.
  Any height change must be uniform across all document rows and applied to `documentRowHeight` **and**
  `InstantPageV2Layout`'s `documentFrame` together.
- **`InstantPageDocumentColorOverride` is required outside a bubble.** The row's title/description colours
  come from `theme.chat.message.incoming/outgoing`; without the override an editor-hosted row renders in
  outgoing-bubble colours. Twin of `InstantPageAudioColorOverride`.
- **KNOWN: `fetch`/`cancelFetch` and the status subscription all guard on `message?.id`**, so on a message
  with no id (a pending/unsent one) the row shows a download arrow whose tap quietly does nothing. Routing
  through a `.standalone(media:)` reference when there is no message id is the fix if it matters.
- **`.buttonRow` still sits in `InstantPageAnchorPath`'s `default:`** — Stage 1's reason ("V2 does not
  lay it out") has expired, but the outcome is unchanged for a new one: a button's label renders
  inside its own view, so it is not a page-text anchor scroll target.
- **The loading shimmer needs the label in a child view.** A `UIView`'s own `draw(_:)` output lands in
  its layer's `contents`, and sublayers always composite *above* that — so a `TextLoadingEffectView`
  added to a pill that draws its own label would wash over the text. Hence
  `InstantPageV2ButtonPillContentView`: the pill keeps the fill and the touch handling, the child
  draws, and the shimmer is inserted between them. `ChatMessageActionButtonsNode` gets this for free
  by inserting below its title *node*.
- **The shimmer is tinted with the pill's label colour, not the reference's white.** A chat action
  button sits on a translucent dark blur; a neutral V2 pill's fill is `0xf3f4f5` in the light theme,
  where a white sweep is invisible. `instantPageButtonColors` already resolves a label colour that
  contrasts with the fill in all four IV themes.
- **`InstantPageV2ButtonRowView.rebuild()` must reuse pills positionally.** A pill now holds an
  in-flight loading effect, and a `.callback` tap updates the message — which relayouts the bubble and
  calls `rebuild()`. Recreating the pills there wipes the shimmer the tap just started. Same reuse
  policy, and same swap-on-edit consequence, as `ChatMessageActionButtonsNode.asyncLayout`.
- **Only `.url`, `.openWebApp`, `.openWebView` and `.callback` ever shimmer.** Those are the arms of
  `performMessageButtonAction` that take the `progress` promise; `.switchInline`, `.copyText`,
  `.openUserProfile`, `.payment` and `.urlAuth` leave it unfulfilled, so nothing appears. This needs
  no special-casing — reply-markup buttons behave identically.
- **A supplied promise suppresses the `.requestInProgress` title panel.** Both web-app entry points
  used to raise a panel across the top of the chat: `openWebAppImpl`
  (`ChatControllerOpenWebApp.swift`) for `.openWebView`, and `requestMessageActionCallback`
  (`ChatController.swift`) for `.openWebApp` and `.callback`. Each now raises it only when
  `progress == nil`, so a surface that shows the loading state on the button itself does not also get
  a panel. The surfaces that pass nil — the reply keyboard (`ChatButtonKeyboardInputNode`), the game
  bubble, and the menu / inline-bot panels — keep the panel as their only indicator. Threading a
  promise into a new caller therefore silently *removes* its panel; that is the intent, but only if
  that caller actually renders the promise.
- **A button inside `<details>` or a table cell is inert, and so never shimmers.** The nested
  `InstantPageV2View`s built in `InstantPageRenderer.swift` never get `buttonTapped` propagated —
  only `rootMediaRegistryHost` is pushed down, by `propagateRegistryHost`. Pre-existing; unrelated to
  the loading effect, but it is why a nested button does nothing at all.

## Unsupported blocks (InstantPageBlock.unsupported)

Every block this build cannot decode arrives as `InstantPageBlock.unsupported` — it is the
`default:` arm of the API-block conversion in `SyncCore_InstantPage.swift`, so a page authored
against a newer server is a page full of them. V2 renders each as the shared "please update" pill;
V1 Instant View still skips the block.

The pill is the same component the chat's standalone unsupported-media bubble draws:
`submodules/TelegramUI/Components/UnsupportedContentPill`. Its constants are a literal port of that
bubble's geometry and are load-bearing for its appearance — changing one changes every unsupported
message in the app.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/TelegramUI/Components/UnsupportedContentPill/Sources/UnsupportedContentPill.swift` | `UnsupportedContentPillStrings` / `Colors` / `Layout`, and the single `measureUnsupportedContentPill(...)` both the pure layout pass and the view run. |
| `.../UnsupportedContentPillView.swift` | The view: badge, text column, action button, and either a `.free` wallpaper bubble background or the static `colors.fill`. |
| `submodules/InstantPageUI/Sources/InstantPageV2UnsupportedItem.swift` | `InstantPageV2UnsupportedItem`, `redundantUnsupportedBlockIndices(_:)`, `layoutUnsupportedBlock(...)`, `unsupportedContentTearZones(in:)`, `unsupportedActionFrame(in:containing:)` (tap arbitration). |
| `submodules/InstantPageUI/Sources/InstantPageV2UnsupportedView.swift` | `InstantPageV2UnsupportedView` — the V2 item view wrapping the pill. |
| `submodules/InstantPageUI/Sources/InstantPageTheme.swift` | `unsupportedPillFillColor` / `unsupportedPillPrimaryColor` and the derived `unsupportedPillColors`. |

### Non-obvious invariants

- **A `.collage` carrying an `.unsupported` item is unsupported as a whole** (2026-08-18). The
  mosaic reserves a slot for every inner block and emits a cell only for the ones it can resolve, so
  an undecodable item leaves a *hole* and pushes the surrounding tiles into the wrong geometry —
  visibly wrong rather than visibly missing. One pill replaces the entire block, caption included.
  The rule lives in `blockRendersAsUnsupported(_:)`, which is what every reader asking "is this
  block unsupported" must call instead of matching `case .unsupported`: the `.collage` arm of
  `layoutBlock`, the run collapsing below, and `InstantPageBlock.spacing(metrics:)` (where the guard
  sits **ahead of** the switch, or the media arm would hand the pill a full-bleed block's
  flush-both-sides rhythm). Deliberately **not** extended to `.slideshow`, whose failure is
  different — it drops an undecodable item silently, one page fewer, and still renders the rest —
  and only one level deep, since a collage's items are flat media blocks. V1 is unchanged.
- **A maximal run of adjacent `.unsupported` blocks renders as ONE pill.** `layoutBlockSequence`
  consults `redundantUnsupportedBlockIndices` in every sequence, nested ones included — and a
  collage-turned-pill counts as part of a run, so it never stacks a second pill on a neighbour's.
  It reports
  indices to **skip** rather than returning a filtered array, because the loop index becomes
  `pathPrefix + [i]` — the structural path checkbox toggling and anchors address blocks by.
  Filtering would renumber every block after a collapsed run and silently toggle the wrong checkbox.
- **The layout value carries geometry only.** `TextNode.asyncLayout(nil)`'s apply creates a *new*
  node per call and the chat bubble re-lays out on every apply, so the view instead owns its three
  text nodes and re-derives them through the same measure function. `constrainedWidth` travels on
  the layout so the view can reproduce the host's measure pass exactly.
- **Colours travel on `InstantPageTheme` and MUST be listed in `withUpdatedFontStyles`.** That
  method reconstructs the theme field by field; an omitted field silently reverts to its init
  default the first time the reader changes Instant View font size. Nothing warns; it compiles.
- **The wallpaper travels as `InstantPageV2RenderContext.wallpaperBackgroundNode`, a closure.** A
  closure so a message-scoped context does not retain the chat's background node. No absolute-rect
  plumbing exists or is needed: `WallpaperBubbleBackgroundNode` is a portal view that mirrors its
  source, so setting the frame is the whole contract.
- **The Update button is always rendered.** `InstantPageV2View.unsupportedActionTapped` is nil in
  the send preview, the text-processing screen and the formula editor, where the tap is inert — the
  alternative (hiding it) would change the pill's width between preview and sent message.
- **The Update button only works if the host steps out of the way — twice.** The button is a real
  `UIButton` inside the page view, but a chat bubble arbitrates every touch over its content: unless
  `tapActionAtPoint` returns `.ignore` for the button's rect, the bubble's
  `TapLongTapOrDoubleTapGestureRecognizer` claims the touch and cancels the button's tracking, so it
  highlights and then does nothing. `ChatMessageRichDataBubbleContentNode` resolves that rect
  **first**, before the collapsible-quote toggle, through
  `InstantPageV2View.unsupportedActionFrame(at:)` → `unsupportedActionFrame(in:containing:)`, which
  works off the **layout** (mid-touch there is no useful way to ask a pill view) and, unlike
  `unsupportedContentTearZones`, **does** recurse into `details` bodies and table cells.
  `ChatMessageUnsupportedBubbleContentNode` answers the same question for the standalone bubble via
  the pill view's `actionContains`. The recognizer has its own escape hatch — it fails when the
  hit-test result *is* a `UIButton` — and the second half is what lets that fire: the button's label
  is a `TextNode`, whose view is interactive by default and would otherwise be the deepest hit,
  so `UnsupportedContentPillView` sets `isUserInteractionEnabled = false` on it. Only the button's
  rect is claimed; the rest of the card stays ordinary bubble content, so the message's own tap and
  long-press survive. (Fixed 2026-08-18; the rich bubble had neither half and its button was dead.)
- **`UnsupportedContentPillLayout.actionFrame(in:)` is the one source for where the button lands.**
  The view positions its button there and layout-only hosts test against it; `in size:` rather than
  the layout's own `size` because a host may stretch the pill wider and the button is pinned to the
  trailing edge.
- **A pill nested in a `<details>` body or a table cell still has an inert button.** Tap arbitration
  finds it, but nested `InstantPageV2View`s only get `detailsTapped` forwarded — `unsupportedActionTapped`
  (like `checkboxTapped`, `buttonTapped` and `documentTapped`) is not propagated into sub-layout
  views, so the closure is nil there. Pre-existing, and not specific to the pill.
- **Reveal cost is `.nonText`.** The pill pops in atomically with its position in the stream, like a
  button row.

### Tearing the bubble across a pill

In a chat bubble the pill does not sit *on* the bubble — the bubble background is **torn** across
it: a full-width band is cut out, so the pill's content floats over the chat wallpaper.

The band travels as geometry, not as a flag. `unsupportedContentTearZones(in:)` reads the
**top-level** `.unsupportedContent` items of a laid-out page and pads each by
`instantPageUnsupportedTearPadding` (6pt). `ChatMessageRichDataBubbleContentNode` maps them into its
own space through `ChatMessageBubbleContentNode.unsupportedContentAreas()`, and
`ChatMessageBubbleItemNode` collects them during its content-node layout loop, resolves them **once**
with `resolveBubbleTearZones`, and hands the same bands to both `ChatMessageBackground` and
`ChatMessageBubbleBackdrop`.

Load-bearing details:

- **Top level only, and the flag is what enforces it** — not the non-recursive walk. A blockquote
  (and a list) lays its children out with `layoutBlock` and appends the resulting items straight
  into its PARENT's array, offset, so a quoted pill sits in `layout.items` looking exactly like a
  top-level one. `InstantPageV2UnsupportedItem.isTopLevel` is recorded during layout — the last
  point that still knows the difference — as `pathPrefix.count == 1`. Depth, not `kind`: a
  blockquote lays its children out with the *enclosing* sequence's kind, so `kind` cannot tell.
  Not recursing merely keeps the walk cheap; it excludes only the containers that build a sub-layout
  of their own (`details`, table cells).
- **The mask is subtractive via `CALayer.luminanceToAlpha()`**: a **white** surface with **black**
  bands. The backdrop's existing mask is the **black**-filled `bubbleMaskForType` image, which works
  only because a `CALayer` mask reads alpha and ignores colour — so it cannot simply be filtered,
  which would map it to alpha 0 and erase the whole backdrop. `BubbleBackdropMaskView` re-renders it
  as a white `.alwaysTemplate` image when torn (alpha and stretch caps both survive template
  rendering) and drops back to the plain image when not, so the filter is never installed on the
  bubbles that are never torn.
- **`luminanceToAlpha` is a private `CAFilter` and can be nil.** Then the bubble renders **untorn** —
  never masked by a surface that would hide it.
- **A residual run of bubble ≤ 8pt** at the top or bottom is absorbed into the band, so a message
  whose only content is an unsupported block has no bubble at all. The band merge runs **twice** in
  `resolveBubbleTearZones` because absorption can pull two bands to the same edge and make them
  touch when they did not before.
- **`ChatMessageBackground.updateTearMask` takes the size as a parameter** rather than reading
  `self.bounds`: the layout passes set the node's own frame *after* calling it.
- **`ChatMessageShadowNode` and `backgroundHighlightNode` are deliberately NOT torn.** The shadow is
  only drawn in the context-menu preview; the highlight is the ~0.3s jump-to-message flash and does
  paint over the gaps briefly.
- **`ChatMessageBubbleBackdrop.maskView` stays public** and is now a `BubbleBackdropMaskView`.
  `ChatMessageInstantVideoBubbleContentNode` sets `overrideMask` and hangs its own round
  `BubbleMaskLayer` on that view's layer; that still works, because the extra layer lands above the
  now-empty shape image and an instant-video bubble is never torn.
- **Moving the silhouette into a child made the backdrop stop animating, and nothing said so.**
  `BubbleBackdropMaskView` holds the stretchable `bubbleMaskForType` image in a `shapeView` child,
  where the backdrop used to *be* that image view. Animating a `UIImageView`'s bounds stretches a
  9-slice image on the curve; animating a container that re-seats its child in `layoutSubviews`
  does not — `layoutSubviews` runs at the next commit with the model (destination) bounds, so the
  silhouette jumped while the mask's own layer animated underneath it. The bubble body kept
  animating (`ChatMessageBackground` still holds its image directly), so only the wallpaper
  backdrop looked wrong: it snapped outright when shrinking, and grew with square-cut edges and a
  popping tail when growing. `BubbleBackdropMaskView.updateFrame(_:animator:)` and its two
  transition overloads move both boxes together, and all three
  `ChatMessageBubbleBackdrop.updateFrame` overloads go through them.
  `ChatMessageBackdropFrameTests` is the guard. `layoutSubviews` stays as the backstop for the
  unanimated paths (mask creation in `setType`, the node's own `frame` didSet).
- **Never ask `CALayer.frame` whether a frame changed.** It is DERIVED —
  `origin.y == position.y - bounds.height * anchor.y` — and that round-trip is lossy for an origin
  that is not representable. The chat's bubble inset is 7/3: `2.3333333333333335` goes in,
  `2.333333333333332` comes back out, so an exact `equalTo` answers "changed" forever
  (`ChatMessageBackdropFrameRoundTripTests` pins the numbers, measured on device 2026-09-15).
  `ChatMessageBubbleItemNode`'s `.System` branch was gated on
  `!backgroundNode.frame.equalTo(backgroundFrame)` and therefore re-ran on **every** pass, including
  the many that re-apply an unchanged layout — and because
  `ContainedViewLayoutTransition.updateFrame(layer:)` carries the same derived-frame guard, the
  background and backdrop layers re-targeted each time, restarting a fresh full-duration animation
  from the layer's PRESENTATION value. The mask, its silhouette and the wallpaper portal are framed
  at `(-1,-1,w+2,h+2)` / `(0,0,w,h)`, integral origins that round-trip exactly, so their guard *did*
  fire and they stayed on the first timeline: two halves of one bubble on two clocks, which reads as
  the backdrop lagging its own outline. The gate now compares `previousBackgroundFrame`, the value
  the previous pass computed, which never goes through a layer. **This was invisible until the
  silhouette animated** — before that it snapped, so there was no second clock to disagree with.
  The hazard is general: any `updateFrame(layer:)` caller whose rect has a non-representable origin
  re-targets on every repeat call.
- **With a patterned or gradient wallpaper the pill's own portal background and the torn gap are the
  same pixels**, so the pill's card vanishes and only its badge and text read. That is the intended
  effect and is why the band is full-width. With a plain-colour theme the pill keeps its faint
  service fill and still reads as a card.

## InstantPage thinking blocks (InstantPageBlock.thinking)

`InstantPageBlock.thinking(RichText)` renders server-sent reasoning as dimmed, continuously-shimmering text inside rich-data bubbles. V2 renderer only; V1 ignores the block (returns `[]`). The shimmer and fade-in mechanics are deliberately separate from the char-reveal cursor so thinking blocks do not affect the reveal pacing of the answer content that follows them.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `InstantPageV2ThinkingItem` layout item + `layoutThinking(...)` (paragraph color × 0.55 alpha for the dimmed style) + `layoutBlock` `.thinking` arm. |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2ThinkingView` — a `ShimmeringMaskView` wrapping a private inner `InstantPageV2TextView`; `InstantPageV2StableItemId.thinking(Int)` stable-id namespace; `makeItemView`/`reuse`/`stableId` arms for the `.thinking` item kind; the two-counter (content + thinking) stable-id loop in `InstantPageV2View.update`. |
| `submodules/InstantPageUI/Sources/InstantPageV2RevealCost.swift` | `.thinking(start:)` cost entry: contributes **zero** cursor cost; triggers whole-block alpha fade-in when `revealedCount >= start`. |
| `submodules/InstantPageUI/Sources/InstantPageLayout.swift` | V1 has no explicit `.thinking` case — it falls through `layoutInstantPageBlock`'s `default:` to an empty layout (no-op). |

### Non-obvious invariants

- **Zero reveal cost is the linchpin.** Thinking blocks do not advance the width-based cursor, so the answer's reveal position is identical whether or not thinking blocks are present — and is unaffected as they appear and disappear across streaming chunks. The answer text always reveals at the same rate regardless of how much thinking precedes it.
- **Whole-block fade, not char reveal.** The inner text is drawn fully under the shimmer mask at all times; the reveal mechanism is a simple alpha visibility keyed to the block's `start` index. A top-of-page thinking block (`start == 0`) is visible from the very first frame.
- **Shimmer runs continuously while the view is displayed** via `ShimmeringMaskView`'s `HierarchyTrackingLayer` self-animation. It does not stop when streaming ends.
- **Top-level only; separate stable-id namespace.** Thinking blocks appear only at the top level of the page. They use the `InstantPageV2StableItemId.thinking(Int)` namespace, numbered by a counter independent of content blocks. This means adding or removing a thinking block never renumbers the stable ids of content blocks — which, combined with pageView reuse, ensures content views and reveal state persist as thinking blocks come and go across chunks.
- **V1 is a no-op.** `InstantPageLayout.swift` has no `.thinking` case; the block falls through `layoutInstantPageBlock`'s `default:` to an empty layout, so V1 rendering silently skips it.

## Anchor navigation in rich bubbles (intra-message `#anchor` links)

Tapping a fragment-only link (`[Jump](#section)`) inside a rich-data bubble scrolls the chat so the matching in-message anchor lands ~8pt below the content-area top, expanding any enclosing collapsed `<details>` first. Anchors come from **server/AI-sent** InstantPages only — block-level `InstantPageBlock.anchor(name)` or inline `RichText.anchor` over a heading/paragraph; the markdown **compose** path deliberately skips generating heading-slug anchors for chat (`markdownBlocksWithGeneratedAnchors` runs only for documents), so user-typed messages have no anchors. The whole downstream scroll chain (`ChatControllerInteraction.scrollToMessageIdWithAnchor` → `ChatMessageBubbleItemNode.getAnchorRect` → `historyNode.scrollToMessage(.bottom(anchorY))`) pre-existed; this feature fills the two bubble-side seams that were stubbed.

### Where things live

| File | Responsibility |
|---|---|
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | `InstantPageV2View.anchorFrame(name:)` (live-layout frame walk, mirrors `findTextItem`; handles `.text`/`.codeBlock`/`.thinking`/`.details`/`.table`) + `firstCollapsedDetails(forOrdinalPath:)` (maps an ordinal path to the first not-yet-expanded `<details>`'s live index). |
| `submodules/InstantPageUI/Sources/InstantPageAnchorPath.swift` | **NEW.** Pure `instantPageAnchorPath(in:name:)` model walk → the `<details>`-sibling-ordinal path to an anchor (`nil` = absent, `[]` = outside any details, `[2,0]` = inside the 3rd top-level details then its 1st nested details) + `richTextContainsAnchor`. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | `getAnchorRect` (delegates to `anchorFrame`, +8pt top margin); the `tapActionAtPoint` fragment route + streaming gate; the `scrollToAnchor` resolve→expand→scroll state machine (`pendingScrollAnchor` + progress guard); the post-relayout hook. |

### Non-obvious invariants

- **The ordinal path is mapped to live indices, never reproduced.** The layout's `detailsIndexCounter` (`InstantPageV2Layout.swift`) is **expansion-dependent** — a `<details>` nested inside a *collapsed* parent has no index until the parent expands and re-lays-out (a collapsed details has `innerLayout == nil`; its children aren't laid out). So `instantPageAnchorPath` returns ordinals, and `firstCollapsedDetails` reads the real index from the live laid-out `.details` item. Expansion is iterative: expand one collapsed level → `requestMessageUpdate` → the post-relayout hook re-runs `scrollToAnchor` → repeat until the anchor resolves via `anchorFrame`.
- **The model walk's recursion set MUST equal the containers the V2 layout recurses through `layoutBlock`** (and thus counts `<details>` in via `detailsIndexCounter`): exactly `.blockQuote`, `.cover`, and `.list`'s `.blocks` items — all of which the layout **flattens** into the parent `items` array (only `layoutDetails` nests a separate `innerLayout`, which is the level boundary). `instantPageAnchorPath` recurses those three sharing the `inout detailsOrdinal`, and treats `.details` as a new level. It deliberately does **NOT** recurse `.postEmbed`/`.collage`/`.slideshow` — the V2 layout lays out only their media/caption (never their child blocks), so it never counts a `<details>` inside them; recursing them would desync the model walk's ordinals from the layout. An anchor inside such a non-laid-out child is unresolvable by `anchorFrame` anyway, so skipping it is a no-op either way.
- **`anchorFrame` and the model walk are only ever both consulted when `anchorFrame` fails.** `scrollToAnchor` first tries `anchorFrame` (covers everything currently laid out — top level, expanded details, tables, thinking blocks); only on a miss does it consult `instantPageAnchorPath`. So the only consequential model-walk output is a **non-empty** path (anchor buried in a collapsed details); `nil`/`[]` both no-op.
- **`getAnchorRect` stays a pure synchronous query.** ChatController calls it inside `forEachVisibleItemNode`; all expansion is orchestrated by `scrollToAnchor`/`pendingScrollAnchor` **before** the scroll fires. The chat scroll consumes only the returned rect's `minY`.
- **Anchor taps are rejected while the message streams** (`TypingDraftMessageAttribute`) → `.none`. So `pendingScrollAnchor` is only ever set post-stream, and the reveal cursor never interacts with anchor scrolling.
- **A fragment-only URL (`#…`, empty base) is always intercepted** — never opened as an external URL. If it resolves → scroll; if not (missing or empty anchor) → no-op (press-highlight only). A real URL carrying a fragment (`https://x.com/p#s`, non-empty base) keeps the unchanged external-URL handling.
- **The expansion loop terminates** via a progress guard (`lastExpandedPendingDetailsIndex == collapsedIndex` → give up): each relayout pass either resolves+scrolls (clearing pending) or advances to a strictly deeper collapsed `<details>`.
- **No `activate:` on the anchor tap action** (unlike external-URL taps): anchor scrolling is local and instant, so the link-loading shimmer (`makeActivate`) would falsely imply network activity. The press-highlight `rects` are still passed.

## "Show more" for partial rich messages (on-demand full page)

A server-sent rich message can arrive **partial** when the content is long: the `RichMessage` `isPartial` flag maps to `instantPage.isComplete == false`. The bubble then renders the partial page plus an inline **"Show more"** link; tapping it fetches the full page (once) and expands the bubble in place.

### Data model

- `RichTextMessageAttribute` (`SyncCore_RichTextMessageAttribute.swift`) carries the partial `instantPage` **and** an optional `fullInstantPage: InstantPage?` (nil until fetched). The partial page is **never replaced** — the full page is stored alongside it (encoded/decoded; both in `==`).
- `engine.messages.requestFullRichText(id:)` (`TelegramEngineMessages.swift`) requests `messages.getRichMessage`, then `transaction.updateMessage(id,…)` sets the existing attribute's `fullInstantPage` to the fetched complete page (keeping `instantPage`), and returns the updated attribute. It yields `.single(nil)` for non-Cloud ids and on network failure (no postbox change).
- The seed-config merge (`SyncCore_StandaloneAccountTransaction.swift`) preserves a previously-fetched `fullInstantPage` if a later server update for the same message arrives without one (same partial `instantPage`).

### Where things live

| File | Responsibility |
|---|---|
| `…/TelegramCore/Sources/SyncCore/SyncCore_RichTextMessageAttribute.swift` | The `fullInstantPage` field (init / encode / decode / `==`). |
| `…/TelegramCore/Sources/TelegramEngine/Messages/TelegramEngineMessages.swift` | `requestFullRichText(id:)` — fetch + `updateMessage` to fill `fullInstantPage`. |
| `…/TelegramCore/Sources/SyncCore/SyncCore_StandaloneAccountTransaction.swift` | Seed-config merge preserving a fetched `fullInstantPage` across later updates. |
| `…/Chat/ChatMessageRichDataBubbleContentNode/…` | The "Show more" link (layout, tap via `tapActionAtPoint` `.custom` + `updateTouchesAtPoint` highlight, `TextLoadingEffectView` shimmer), the node-local expand state, the effective-page selection, and the downward-expand. |
| `Telegram/Telegram-iOS/en.lproj/Localizable.strings` | `Chat.RichText.ShowMore` = "Show more" (→ `strings.Chat_RichText_ShowMore`). |

### Non-obvious invariants

- **Expand state is node-local and per-message, NOT derived from the attribute.** `showMoreExpanded: (messageId, value)?` is snapshotted at layout time and resolved against the current `item.message.id`, so **every fresh display of a message starts collapsed (partial)** even when its attribute already carries a cached `fullInstantPage`; only an in-place tap expands, and that expansion survives same-message relayouts. Resolving against the message id makes any *other* message collapse automatically (no stale-snapshot bug, no manual reset).
- **The bubble renders `(showMoreExpanded ? attribute.fullInstantPage : nil) ?? attribute.instantPage`** — the full page only while expanded — in both the webpage build and `layoutInstantPageV2`. `scrollToAnchor` resolves anchors against the same effective page.
- **The link shows only when `!showMoreExpanded` AND `!attribute.instantPage.isComplete`** (plus the original gates: not streaming via `TypingDraftMessageAttribute`, `id.namespace == .Cloud` since `requestFullRichText` is a no-op otherwise, and not a preview / `.messageOptions` context). The date/status trails the link's line by substituting the link frame for the last-text-line frame (see the status-node section).
- **`showMoreExpanded` is part of BOTH layout caches.** It is in the `currentPageLayout` cache key **and** the `pageView` content key (`pageViewMessageKey`). This is required because the cached-expand path (full page already on the attribute) performs **no postbox write**, so `stableVersion` does not bump — without the key, the cached partial layout/content would shadow the expand.
- **Tap (`activateShowMore`):** if `fullInstantPage` is already cached → set expanded + `requestMessageUpdate` immediately (no network, no shimmer); otherwise shimmer the link and fetch, expanding only once the full page lands. Guards against a second in-flight request and against re-expanding.
- **Expand grows the bubble downward in screen space** (top fixed) via `info?.setInvertOffsetDirection()` on the `ListViewItemApply` in the apply closure, fired only on the `appliedShowMoreExpanded → showMoreExpanded` transition (never on first apply). Same mechanism as `ChatMessageInteractiveFileNode`'s audio-transcription expand and the text/fact-check bubbles; the ListView clamps it to what fits.

## Rich-message media in the gallery / shared-media / preview pipelines (`Message.effectiveMedia`)

A rich message's media (images / videos / audio / documents) lives in `attribute.instantPage.media`, **not** in `message.media` (which is empty — rich messages are sent with `text: ""` and no media reference). To make that media participate in the *same* shared-media-index, gallery, file-list, playback, download, and save/copy pipelines that normal `message.media` flows through, there is one shared accessor and a set of opt-in call-site swaps.

### The accessor

`Message.effectiveMedia: [Media]` (+ a delegating `EngineMessage.effectiveMedia`) in `submodules/TelegramCore/Sources/Utils/MessageUtils.swift`:

```swift
var effectiveMedia: [Media] {
    if !self.media.isEmpty { return self.media }     // normal message: identical to message.media
    if let richText = self.richText { return richText.instantPage.allMedia() }  // rich: the instant-page media
    return self.media
}
```

`Message.richText` (same file) is already a typed `RichTextMessageAttribute?`; `InstantPage.allMedia()` (`SyncCore_InstantPage.swift`) recursively gathers media from the page's blocks (audio/collage/cover/details/image/list/slideshow/video) via its `[MediaId: Media]` dict. **For a normal message `effectiveMedia == message.media`**, so swapping a `message.media` read for `message.effectiveMedia` is behavior-preserving for non-rich content and only adds the rich media where the site should consider it. **Scope is first-media** for now (call sites keep their `.first` / iterate-and-break logic; the helper returns all media but callers stop at the first match — the `//TODO:rewrite to take all media` markers remain).

### Where things live

| Layer | What |
|---|---|
| **Discovery / index** | `tagsForStoreMessage` (`StoreMessage_Telegram.swift`) indexes rich media into `MessageTags` (photo/video/gif/voice/file). **This is the linchpin**: it makes rich messages *appear* in every tag-queried surface (shared-media tabs, search, downloads) — which is exactly why each rendering-side site below then needs `effectiveMedia`, or it renders the surfaced message blank. |
| **Extraction helper** | `Message.effectiveMedia` (above). |
| **Shared-media grids / rows** | `PeerInfoVisualMediaPaneNode`, `PeerInfoGifPaneNode`, `ListMessageItem` (row-type selection) + `ListMessageFileItemNode` (file/music/voice row), `ChatListSearchMediaNode` (search media grid). |
| **Gallery open + items** | `GalleryController` (`tagsForMessage` + `mediaForMessage` — the duplicated `message.media`/`message.richText` blocks were collapsed into one `effectiveMedia` loop), `GalleryData.chatMessageGalleryControllerData`, `SecretMediaPreviewController` (its own local `mediaForMessage`), and the gallery item nodes `ChatDocumentGalleryItem` / `ChatExternalFileGalleryItem` / `ChatAnimationGalleryItem` (these re-derive from `message.media` in `node()`, so a rich doc/animation rendered **blank** without the swap) + `UniversalVideoGalleryItem` secondary affordances + `ChatItemGalleryFooterContentNode`. |
| **Playback** | `PeerMessagesMediaPlaylist.extractFileMedia` (the peer music/voice playlist), `OverlayAudioPlayerControllerNode` (audio context menu). |
| **Resolution / downloads / cleanup** | `FetchedMediaResource.findMediaResourceById(message:)`, `SyncCore_RecentDownloadItem`, `StoreDownloadedMedia`, `DeleteMessages.addMessageMediaResourceIdsToRemove(message:)` (rich media was **leaking on delete**), `CollectCacheUsageStats`, `ChatHistoryListNode` (download manager), `ChatListSearch{ListPaneNode,ContainerNode}`. |
| **Actions** | `ChatInterfaceStateContextMenus` (Save-to-Camera-Roll, copy-image, save-audio/music-to-files, debug/premium), `ChatControllerNode` (post-suggestion media ref), `ChatControllerLoadDisplayNode` (edit send-validation), `ShareController.saveToCameraRoll`. |

### Non-obvious invariants

- **The tag-index change is what creates the work.** `tagsForStoreMessage` surfacing rich messages into tag-queried lists, *without* the rendering-side `effectiveMedia` swaps, produces visible **blank cells / blank rows / wrong row types**. Index and render must move together.
- **The rich message's own in-chat bubble + in-bubble gallery do NOT read `message.media`** — a rich message renders via `ChatMessageRichDataBubbleContentNode` (InstantPage V2), in-bubble image/video tap opens `InstantPageGalleryController` (reads the instant page directly), and in-bubble audio uses `InstantPageV2AudioContentNode`. So the text-bubble / interactive-file / interactive-media nodes' `message.media` reads are **never reached by a rich message** and are deliberately left alone.
- **Rich audio plays out of an `InstantPageMediaPlaylist`, so the mini player bar needs its own tap arm** (fixed 2026-08-17). The file lives in the `RichTextMessageAttribute`, so playback is keyed by `InstantPageMediaPlaylistId.richMessage(messageId:)` with an `InstantPagePlaylistLocation` — NEITHER of which is a `PeerMessages*` type. `MediaPlaybackHeaderPanelComponent`'s `tapAction` matched only `PeerMessagesMediaPlaylistItemId` + `PeerMessagesPlaylistLocation`, so tapping the bar for rich audio did nothing at all. `InstantPagePlaylistLocation` now lives in **`AccountContext/Sources/MediaManager.swift`** (public, beside `PeerMessagesPlaylistLocation`) and carries the originating `messageId` — `AccountContext` is the one module both the panel and `InstantPageUI` already depend on; routing the panel through `InstantPageUI` instead would drag the whole reader into the chat-list header. The panel's new arm opens the same `makeOverlayAudioPlayerController` at that message, which works because a rich message IS `.music`-tagged (see the `tagsForStoreMessage` row above) so the player's own music-tagged history list finds it. `messageId == nil` (the Instant View reader) stays inert, exactly as before.
- **Do NOT route the FORWARD path through `effectiveMedia`** (`ChatControllerNode` `forwardedMessages` ~556/560/568). The `RichTextMessageAttribute` already travels with a forward, so the forwarded copy reconstructs from the attribute; injecting the instant-page media as top-level `message.media` there would **double-render** (rich bubble + a separate media attachment). That `message.media` processing is caption-hiding / poll-stripping only, both irrelevant to rich — left as `message.media`.
- **Rich messages are edited as reconstructed MARKDOWN, not via the media-caption edit path.** So `ChatControllerLoadDisplayNode`'s edit caption-max-length / original-media-reference reads (~1241/1775/4463) stay on `message.media` — they belong to the `.media` edit state a rich message never enters. (The send-*validation* `.contains` at ~2273 IS swapped, so an edit that leaves only media isn't wrongly rejected.)
- **`RichTextMessageAttribute.associatedMediaIds` stays `[]` — intentionally.** `MessageHistoryTable` resolves `associatedMediaIds` via `getMedia(id)` in the postbox **media table**, but rich-message media is embedded inside the attribute blob, not the table — so returning the keys would be a no-op without also inserting the media into the table. The embedded-blob approach is self-contained.
- **`fullInstantPage` is not indexed** (the server doesn't index it either, and it's fetched on demand after store-time). The first media lives in the partial `instantPage` anyway.
- **Only switch the loop SOURCE, never the per-type branches.** Many swapped loops still contain `TelegramMediaPoll`/`TelegramMediaPaidContent`/`TelegramMediaWebpage` branches that rich messages never match — that's fine and intentional; only the `for … in <msg>.media` source changes.
- **Build-only completeness gate.** Every swap is type-identical (`[Media]` → `[Media]`), so the only compile risk is a receiver that is neither `Message` nor `EngineMessage`; the full Bazel build is the gate (no per-module build / unit tests). Deferred, NOT done: chat-list/reply/pinned/notification/forward thumbnail **previews** and the "Photo"/"Video" media-kind **labels** (`messageContentKind`/`ChatListItemStrings`) — those are preview surfaces, not blank-cell breakage — and **multi-media** (first-media-only is the current scope).

## The chat-message text categories, and editor layout parity (2026-08-14)

`layoutInstantPageV2` takes its fonts from the caller, so there is **no single V2 look** — and the three
chat-side callers had each hand-copied their own `InstantPageTextCategories` table, which drifted: the
bubble carried heading `lineSpacingFactor` 1.0 / body 0.9 while the long-press send preview and the
TextProcessing screen carried 0.685 / 1.0, so **the send preview did not match the bubble it was
previewing**. All three now share `InstantPageTextCategories.chatMessage(primaryText:secondaryText:)`
(`InstantPageChatMessageTheme.swift`) with the bubble's values. That deliberately changed the preview and
TextProcessing; the bubble's values won because it is the surface the recipient sees.

The same table is what the **rich-text editor lays text out with**, so an author composing a rich message
sees the message. `InstantPageTheme.richTextRenderMetrics(edgeSpacingReduction:)`
(`InstantPageRichTextMetricsAdapter.swift`) projects any theme into the editor's `RichTextRenderMetrics`
contract, and `chatMessageRenderMetrics()` is the convenience both editor hosts call. The heading ladder
comes from `headingTextAttributes(level:link:)` rather than being restated, so H1–H6's derivation from the
subheader's authored 22 (and its response to the reader's font-size slider and the chat's Text Size) stays
shared. That ladder is **22 / 20 / 18 / 17 / 16 / 15** serif medium (retuned 2026-08-17); H1 and H2 carry
their own base sizes there rather than returning the `header` / `subheader` categories, which stay at 24 / 22
for the page title/subtitle and the `pageBlockHeader` / `pageBlockSubheader` blocks. The ladder scales by the
theme's stored `fontSizeMultiplier` (the product of every `withUpdatedFontStyles` applied), **not** by a ratio
recovered from the live subheader size: that size is already floored, and at the chat `.large` step the
recovered 24/22 put H2 on 21 where floor(20 × 19/17) is 22. `codeBlock` reports the metrics'
`codeBlockFontSize` (15 at page scale), the size `layoutCodeBlock` actually draws; the chat table now says 15
too, while the Instant View themes keep their 14.

**`InstantPageUI` gained a direct dep on `RichTextEditorUIKit`**, which it already had transitively via
`ChatRichTextEditorComposer`, so there is no cycle. The adapter has to live on this side: the composer
module cannot import `InstantPageUI` (that direction *is* the cycle), which is why the composer passes
`RichTextRenderMetrics.default` and a test pins that default equal to the adapted theme.

Two parity test suites live in `//submodules/InstantPageUI:InstantPageUITests`, both calling the
renderer's own functions so a change on either side that breaks parity fails here:
`RichTextV2MetricsParityTests` pins the editor's line formulas against `layoutTextItem`, its resolved font
faces against `InstantPageTextStyleStack`'s family scheme, and the **whole** pairwise gap table against
`spacingBetweenBlocks`; `RichTextV2FrameParityTests` pins that the editor composes those primitives into
the same running origin. **Do not change a value in `chatMessage` without expecting the editor to move
with it** — that coupling is the point. Editor-side detail, and what is deferred, is in
`submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md`.

## Compact InstantPage previews

`TelegramStringFormatting/InstantPagePreviewBuilder.swift` owns the shared compact
preview. Block traversal, caption handling, collection summaries, whitespace
normalization, and inline semantics produce one attributed string. The chat list
uses its `.string` as the backing text and consumes its attributes directly; never
independently fold the plain and attributed forms or reconstruct rich content from
message entities.

Collages/slideshows prefer their own caption and credit. Without a collection
caption, caption-bearing children retain their order and captionless siblings keep
media labels. Pure image/video collections use localized counts (including nested
covers/collections). Other media remain ordinary child previews. Empty containers
are skipped. Thinking text is a fallback when no answer content contributes.

Preview bodies are limited to 200 grapheme clusters, with an ellipsis on truncation.
Traversal also limits depth (64), nodes (4,096), and inspected UTF-16 units (16,384).
Spoilers, custom emoji, dates, italic, underline, and strikethrough survive nesting.
Dates use supplied presentation settings; nil-format dates retain their literal text.
Unresolved custom emoji keeps its identity in preview metadata and displays alt
text (or `�` if empty). Only a resolved file receives the native custom-emoji
attribute: entity text nodes otherwise replace alt text by a blank attachment.
The modern composer accessory uses the existing entity-aware text component.

`styleInstantPagePreview` applies a consumer's fonts/colors without deleting semantic
attributes. Formula/table runs use U+FFFC plus icon and fallback metadata, never
spaces. `renderInstantPagePreviewIcons` consumes icon markers, retaining semantic
attributes; materialize on the body before adding author prefixes. Its subsequent
calls are idempotent. `instantPagePreviewPlainText` provides spoken/textual icon
labels; it must not replace the visual backing string used by attribute ranges.

Regression targets (run through `Make.py test --target` as documented in CLAUDE.md):
`//submodules/TelegramStringFormatting:TelegramStringFormattingTests` (resource-free
collector fixtures) and `//submodules/ChatListUI:ChatListUITests` (unhosted
selection/composition fixtures). The latter bundles real generated strings data
and English localization, with test-scoped resource lookup redirection for AppBundle.
Both production and minimal UIKit test hosts deadlocked during pre-main Texture/UIKit
initialization on iOS 26.5; an iOS 27.0 hosted retry also failed to start tests.

Thumbnail selection and dedicated relative-date refresh timers are outside this
preview change.

Validation on 2026-09-29: 23 collector tests and 8 selection/composition tests passed;
the full simulator app build passed after the review fixes. Live screen appearance,
VoiceOver playback, and attribute-only message-edit invalidation still need manual
verification; helper tests do not establish those UI behaviors.
