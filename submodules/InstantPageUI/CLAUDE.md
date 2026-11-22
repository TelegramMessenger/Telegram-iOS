# InstantPage V2 & rich-text messages

Typed markdown with structure the message-entity set can't represent (headings, lists, tables, formulas, nested
blockquotes) is sent as a **rich message**: a `RichTextMessageAttribute` carrying an `InstantPage`, drawn by
`ChatMessageRichDataBubbleContentNode` through the **InstantPage V2** renderer. Architecture and invariants (streaming
reveal, table/text-box layout, custom-emoji and entity round-trips, task-list checkboxes, nested blockquotes, thinking
blocks, the markdown send/edit/copy/paste paths, rich-message media via `Message.effectiveMedia`) are in
[`docs/instantpage-richtext.md`](../../docs/instantpage-richtext.md).

**Inline buttons & document blocks**: `textButton` (inline, inside `RichText`), `pageBlockButtonRow` and
`pageBlockDocument`. All three are modelled losslessly (Postbox + FlatBuffers + both Api directions) and rendered in V2;
V1 Instant View skips them. The server emits all three. The RichText article editor also produces `pageBlockDocument`:
attaching a file (Files tab) makes a `MediaKind.document` block that sends as `InstantPageBlock.document`, and tapping a
downloaded one in the bubble opens it via `openMessage(…, mediaSubject: .richTextMedia(fileId))`.

The invariants are in [`docs/instantpage-richtext.md`](../../docs/instantpage-richtext.md) under "Inline buttons &
document blocks". The ones that bite hardest:
- `textButton` follows the inline **formula** attachment path (real run-delegate ascent/descent, top-level item), not
  the inline-image path; the attachment carries its own measurements because the line-breaker cannot re-measure.
- Interactive V2 items route taps through a **pageView closure** (`buttonTapped`, like `checkboxTapped`), not
  `tapActionAtPoint`; the closure carries a `Promise<Bool>` the tapped pill subscribes to for its loading shimmer.
- `InstantPageTheme.withUpdatedFontStyles` reconstructs field by field, so omitting a colour there silently reverts it.
- The `InstantPageButton` FlatBuffers tables must live in `RichText.fbs` (include cycle).
- `ReplyMarkupButtonAction` is reused and therefore wider than the schema permits.
- Two media sites fail *silently* for `.document`.
- `InstantPageAnchorPath` must NOT recurse into `.buttonRow`.
- A pill needs `clipsToBounds`, or its `cornerRadius` is covered by the `draw(_:)` background bitmap and it renders as a
  rect.
- An inline pill's **type icon trails the label** (the pill is ~20pt tall, so a corner badge would be shaved by the
  capsule), and the pill is measured 14pt wider to hold it. The width is unconditional, so it moves line breaks and the
  editor must reserve the identical amount.
- `attachment.ascent` is a *full* font ascent; don't compare it directly with `lineAscent`, the *reduced*
  `floor(ascender + descender)` box.
- A width cap travels as `inlineButtonMaxWidth`, forwarded through all 31 recursive `attributedStringForRichText`
  calls; `boundingWidth` is nil on the paragraph path and also drives the inline-image clamp.

Open: markdown-edit data loss; `checkboxFill`/`checkboxForeground` are
misnamed (they are the `.primary` button colours).

**Text Size**: a rich bubble follows Settings ▸ Appearance ▸ Text Size through ONE `contentScale`
(`baseDisplaySize / 17`) passed to `layoutInstantPageV2`, applied once to the unscaled theme's fonts (whole-point floor)
and once to `InstantPageMetrics` (pixel snap), never to an already-scaled theme. Code, table and quote body stay equal
at every step, so `codeBlockFontSize` is a whole-point floor, not a pixel snap. Tests pin the grid to 3x because the test
process reports a 1x screen. Details in [`docs/instantpage-richtext.md`](../../docs/instantpage-richtext.md) under
"Text Size / content scale".

**Unsupported blocks**: every block this build cannot decode arrives as `InstantPageBlock.unsupported`, and V2 renders it
as the shared "please update" pill from `submodules/TelegramUI/Components/UnsupportedContentPill`, which the chat's
standalone unsupported-media bubble also draws (its constants are load-bearing for that bubble's appearance). A run of
adjacent unsupported blocks collapses to one pill; the chat wallpaper reaches the renderer through
`InstantPageV2RenderContext.wallpaperBackgroundNode`. Details in [`docs/instantpage-richtext.md`](../../docs/instantpage-richtext.md)
under "Unsupported blocks".

**Rich reply quotes**: a reply quoting a selection of a rich message sends `quote_rich`, one `RichText` per covered text
node (`EngineMessageReplyQuote.richText`; `text`/`entities` are its derived flat form, so every quote consumer reads
those unchanged). The pure core (node table, builder, the server's validation rule) is
`TelegramCore/Sources/Utils/RichReplyQuote.swift`; the renderer stamps each laid-out run with its node and flat range so
a selection maps to nodes. The enumerator and the V2 layout share the node-id scheme and nothing checks the pair. Details
in [`docs/instantpage-richtext.md`](../../docs/instantpage-richtext.md) under "Rich reply quotes".
