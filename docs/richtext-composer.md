# Rich-text chat composer & `ChatInputContent`

The app-side rich-text **input** story: the WYSIWYG editor, the `ChatInputContent` value model that
replaced `NSAttributedString` as the composer currency, and the round-trips through send / edit / drafts /
cross-device sync.

**Authority boundaries** — this file is the app-integration reference. For:
- **editor internals** (TextKit seam, layout, boxes) → `submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md`.
- **message rendering** (InstantPage V2, rich bubbles) → [`docs/instantpage-richtext.md`](instantpage-richtext.md).

The editor is gated behind the `debugRichText` flag; the **native** engine is the rich path, the **legacy**
`UITextView` node is the production fallback (a lossy filter — see below).

---

## 1. The editor

A from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`), developed as an
in-tree **SwiftPM package** and wired into the app: `ChatTextInputPanelNode` depends on `:RichTextEditorUIKit`,
so it builds under Bazel at the repo's iOS-13 floor. Core (`:RichTextEditorCore`) is pure-Foundation.

- **TextKit is quarantined behind `protocol BlockLayoutEngine`:** `BlockLayout` (TextKit 2, `@available(iOS 16)`)
  on iOS 16+, `BlockLayoutTK1` (TextKit 1) on iOS 13–15, chosen by `makeBlockLayout(...)` /
  `BlockLayoutBackend.forceTextKit1`. Higher-OS APIs kept at their genuine floor: TK2 + `UIEditMenuInteraction`
  at 16, loupe (`UITextLoupeSession`) + inline predictions at 17, Translate at 17.4, `isEditable` at 18. **TK1
  trade-offs (iOS 13–15, deliberate):** no spoiler text-hiding, loupe, or inline predictions.
- **The system edit menu** falls back `UIEditMenuInteraction` (16+) → `UIMenuController` (13–15). iOS 13–15 keeps
  the editor's built-in menu (`UIMenuController` can't carry closure-backed items).
- **Bundled resource (spoiler texture) is build-system-split** behind `#if SWIFT_PACKAGE`: SwiftPM uses
  `.module`; Bazel uses the app's `AppBundle` (`UIImage(bundleImageName: "Components/TextSpeckle")`,
  `//submodules/AppBundle` dep).
- **Parent-driven API:** `RichTextEditorView.update(size:insets:) -> CGFloat` (parent supplies scroll insets,
  returns measured height), payload-free `onChange`, `currentState() -> EditorState`, `deleteTable()`,
  `makeCodeBlock()`, `registerMediaViewProvider`. The host `RichTextAttachmentScreen` (separate module) drives
  layout from `onChange` and owns a bottom action bar (`RichTextActionBarComponent`).

> **Invariant — a view does not own its `frame`.** Editor/component `update(...)` reads `self.bounds` and lays
> out subviews; it never writes `self.frame` (the parent chose it). See the "View frame ownership" note in the
> root `CLAUDE.md`.

---

## 2. `ChatInputContent` — the composer currency

`ChatInputContent` (`submodules/TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift`) is a
purpose-built, TelegramCore-native **value model** that replaced `NSAttributedString` as the chat composer's
currency. It is a block/run tree mirroring the editor `Document` 1:1:

- **Blocks:** `.paragraph` (body / heading1-3 / quote, + optional `list` membership), `.code`,
  `.collapsedQuote(ChatInputContent)`, `.media(ChatInputMedia)`, `.table(ChatInputTable)`.
- **Inline runs:** bold / italic / mono / strike / underline / spoiler + entity mention / url / date /
  `customEmoji(fileId:file:enableAnimation:)`.
- **Selection** is a recursive tree-path (`ChatInputPathStep{blockIndex,slot}` / `ChatInputPosition{path,offset}`
  / `ChatInputSelection{start,end}`) — chosen for nested quotes + collapsible blocks — with a content-aware
  flat↔structural bridge (`position(forFlatOffset:)` / `flatOffset(for:)` / `nsRange(in:)` / `init(nsRange:in:)`).

Conversions:
- **Display-neutral TextFormat utility** (`Sources/ChatInputContentConversion.swift`): `chatInputContent(from:)`
  / `attributedString(from:)`, round-trip-identity tested in `//submodules/TextFormat:TextFormatTests`.
  **Contiguity is load-bearing for quotes:** `chatInputContent(from:)` carves each maximal contiguous
  `.block`/.quote run (via `enumerateAttribute`, like `codeBlockRanges` for code) into ONE multi-paragraph
  `.blockQuote` — it must NOT split per-`\n`. A multi-line quote is one `.block` object spanning its interior
  newlines; splitting it produced one `.blockQuote` per line, which `attributedString(from:)` then re-emitted as
  non-contiguous runs separated by plain `\n`s → multiple on-screen quote boxes (seen both on format-apply and,
  since this feeds the persisted `"cm"` model, after re-opening a chat). Two *genuinely* separate quotes are
  divided by a non-block `\n`, so they remain two runs → two blocks (no coalescing across a non-quote gap).
- **Direct editor bridge** (`ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`):
  `Document ↔ ChatInputContent`, used by the native node — it **bypasses the `NSAttributedString` hop** where
  structural blocks (media/table/heading/list) would be flattened.

### Load-bearing invariants

- **`ChatTextInputState.==` is value-based** (`submodules/AccountContext/Sources/ChatController.swift`):
  fast-path on `selectionRange` + `inputText.isEqual(to:)`, else compare `chatInputContent(from:)` value models.
  This is strictly coarser-or-equal to the old reference equality (can only remove churn). **Scoped to the state
  type (Design A)** — *not* a global value-based `ChatTextInputTextCustomEmojiAttribute.isEqual`, which lives in
  ~90 files incl. message rendering.
- **`.media` / `.table` are off the flat axis** (`blockIsFlatParticipating`) across `plainText` /
  `blockFlatLength` / `flatOffset` / `position(forFlatOffset:)`, so the invariant `plainText ==
  attributedString(from:).string` holds. Violating it drifts the native caret past non-text blocks.
  `.collapsedQuote` legitimately *is* one flat placeholder char.
- **Custom emoji occupies its alt-string's UTF-16 length in the composer flat space** (the editor's
  `composerSelectedRange` / `composerParagraphs`), matching the content and the legacy seam — else the caret
  drifts past custom emoji.
- **Codable (drafts) goes through `AdaptedPostbox{En,De}coder`, which supports NO `singleValueContainer` and NO
  bare `Int`.** So enum discriminators are explicit `Int32` rawValues (never `encode(SomeEnum.case)`), and all
  numbers are explicit `Int32`/`Int64`. Test the model Codable via `AdaptedPostboxEncoder` (a JSON round-trip
  masks this). The polymorphic `Media` persists via a concrete-type discriminator + `TelegramMediaImage/File(decoder:)`,
  **not** `decodeRootObjectWithHash` (that needs the app-startup `declareEncodable` registry, empty in tests).
  **This applies to *every* raw enum, `String`-raw included:** a `RawRepresentable` enum's *synthesized* Codable
  uses a `singleValueContainer`, so each raw enum in `ChatInputContentModel.swift` carries a CUSTOM keyed Codable
  encoding its `.rawValue` under a `"raw"` key. `ChatInputMediaDisplayMode` (a `String`-raw enum) was missed and
  crashed at `AdaptedPostboxEncoder.swift:94` when a draft containing a `.media` block was persisted (it is
  encoded by `ChatInputMedia.encode(to:)`) — fixed by giving it the same custom keyed Codable.

`isEntityExpressible(options:)` is the routing switch: text / quote / collapsed-quote / code / mention / date /
custom-emoji-in-body are entity-expressible (normal text+entities path); heading / list / table / media are
not (→ structured `.instantPage` path). The `EntityExpressibleOptions` bag narrows this: with
`.quotesRequireRichContent`, a `.quote` paragraph and a `.collapsedQuote` are treated as NOT entity-expressible,
so quote-bearing content routes onto the rich path even though entities could represent it (opted into by the
send-options preview and the attachment-menu rich-editor send — see §5).

---

## 3. Composer ↔ editor wiring

- **Node selection** (`ChatTextInputPanelNode`): `richTextInputNode` is the native node
  (`RichTextEditorChatInputNode`, `usesNativeRichTextEngine == true`) under `debugRichText`, else the legacy
  `UITextView` node (`ChatRichTextInputNodeImpl`).
- **GET** (`inputTextState`): returns `ChatTextInputState(content: richTextInputNode.currentInputContent().content, …)`
  **directly** — no `NSAttributedString` round-trip, so native structural blocks survive. For the legacy node the
  content is always flat, so it's identical to the old path.
- **SET** (`setInputContent`): the chat layer routes content-set sites through the node. The native node lands
  structural blocks straight into the editor `Document` (registering media/emoji so a later GET resolves them);
  the **legacy node is a render-only lossy filter** — `attributedString(from:)` drops media/table and renders
  heading/list as plain text.
- **Legacy node owns its decoration:** `applyRenderingConfig(...)` + `setInputContent` + `currentInputContent`,
  per-keystroke `decorateAfterTextChange`, spoiler-reveal (`updateSpoilersRevealed`, 1.5 s hide + dust
  cross-fade), paste/plain-fragment (`decorateReplacementFragment`). The panel no longer calls
  `refreshTextInputAttributes` / `prepareForSpoilerReveal` etc. Theme-change re-color routes through
  `decorateAfterTextChange` (correct per-attribute colors + overlay rebuild — a naive full-range
  `foregroundColor` rewrite reveals custom-emoji / unrevealed-spoiler base glyphs).
- **Expand / collapse is routed through `ChatInterfaceState`, not the node** (`ChatControllerNode.openExpandedInput`):
  OUT converts the live `inputTextState.content` → `(Document, media, emojiFiles)` to seed
  `RichTextAttachmentScreen`; IN converts the editor's `(document, media, emojiFiles)` → `ChatTextInputState`
  applied via `updateChatPresentationInterfaceState` + `withUpdatedEffectiveInputState` (the `openAICompose`
  precedent — one value seen by undo/drafts/send/observers). Thin converters:
  `ChatRichTextEditorComposer/Sources/ComposerExpandedEditorBridge.swift`. Custom-emoji **files** (`[Int64:
  TelegramMediaFile]`) and media are threaded both ways (a fileId-only emoji ref renders blank).
- **OUT back-fills emoji files the composer content only holds by fileId.** A `ChatInputContent` custom-emoji
  run may carry the fileId **without** the `TelegramMediaFile` attached; the plain `documentMediaAndEmoji(...)`
  then returns an `emojiFiles` map missing those ids, seeding the editor's emoji store (and, on the initial
  `.edit`/`.standalone` seed, the keyboard's file set) empty — so the emoji renders blank and its file is dropped
  on collapse-back / send. The OUT path therefore uses the **async** `documentMediaAndEmojiAsync(engine:…)`
  (awaited inside `openExpandedInput`'s `Task { @MainActor }`), which resolves any fileId with no inline file from
  the **local** sticker cache (`engine.stickers.resolveInlineStickersLocal`, a postbox `getMedia` over
  `Namespaces.Media.CloudFile`). Local-only is deliberate — composer emoji are always already cached, so no
  network round-trip stalls the expand; a fileId absent even locally simply stays unresolved (renders blank, as
  before). Persisted **drafts** need no resolution (their `emojiFiles` are stored/decoded whole in
  `RichTextDraft`); the in-editor AI-insert paths still use the sync `documentMediaAndEmoji` (their
  completion closures are synchronous, and AI-generated content rarely carries custom emoji).

> **Invariant — the cycle constraint.** `InstantPageUI` transitively deps `ChatTextInputPanelNode`, so the
> panel/node **cannot** dep `InstantPageUI` / `RichTextEditorMediaView`. `TelegramUI` (above the cycle) builds
> the inline-media view (`RichTextEditorMediaView.MediaItemNodeView`) and **injects a `mediaItemViewFactory`
> closure** into the panel at its construction sites; media crosses the protocol as `EngineMedia` (keeping the
> node Postbox-free).

> **Invariant — the `Display.Window1.hitTest` "EditMenu" match** is load-bearing for the iOS-16 edit menu:
> without it the menu's taps fall through to content app-wide.

### Keyboard input language (`interfaceState.inputLanguage`)

The composer reports the active keyboard's primary language back into
`ChatInterfaceState.inputLanguage` (feeding emoji-keyword search at
`ChatInterfaceInputContexts.swift` and draft persistence), and pre-selects the
keyboard language when a draft is reopened. This rides the editor's first
responder, `DocumentCanvasView`, which carries a one-time `textInputMode`
override (a verbatim port of the legacy `ChatInputTextView` mechanism):
`RichTextEditorChatInputNode.primaryLanguage` →
`RichTextEditorView.inputPrimaryLanguage` → `canvas.textInputMode?.primaryLanguage`,
and `initialPrimaryLanguage` is seeded by `ChatTextInputPanelNode` →
`RichTextEditorView.initialInputPrimaryLanguage` → `canvas.initialPrimaryLanguage`.
The override is single-shot (UIKit's `becomeFirstResponder` query consumes the
pre-selection before any read-back), so the read path must not run before focus —
the panel already guards on `isInputFirstResponder`, falling back to
`storedInputLanguage` otherwise.

### Writing direction (RTL)

The editor auto-detects each paragraph's direction (RTL for Arabic/Hebrew/…) and lays it out accordingly, so RTL
typing "just works" in the composer; an empty message's caret follows the keyboard's input language and re-flips
live on a globe-key switch. The whole-document override (`RichTextEditorView.layoutDirectionOverride`) exists on the
façade (and has a UI control in `RichTextAttachmentScreen`) but is **not surfaced in the chat composer** this round —
auto-detect covers it. Editor-side architecture lives in the editor's own `CLAUDE.md` ("RTL / writing direction").

**Empty-input right inset.** `ChatTextInputPanelNode.calculateTextFieldRealInsets` reserves the action-control slot
on the field's right (`actionControlsWidth - 10`). The effective per-layout call (applied to the rich node) passes
that width **only when the send button is shown** (`inputHasText || hasMediaDraft || hasForward || isEditingMedia`);
when empty the send button is hidden (scaled to ~0), so the field insets only for the in-field accessory buttons (a
further 10pt is trimmed). Without this an empty field over-insets on the right.

---

## 4. Feature round-trips

All inline / structural features round-trip losslessly through the native composer; the markers live in shared
`TextFormat` codecs so live-edit, send, copy, and paste agree.

> **Document (file) blocks (added 2026-07-31).** A generic file attached in the article editor is a
> `MediaKind.document` block — a CAPTION-LESS atom (the audio shape: `nodeSize` 3, empty `leafRegions()`,
> gap-caret), rendered as a fixed **52pt** row that must stay in lockstep with `InstantPageV2Layout`'s
> `documentFrame`. It threads editor `Document` ↔ `ChatInputContent` (`ChatInputMediaKind.document`,
> raw **4**) ↔ `InstantPage` (`.document(id:caption:)`). Like `.audio`, the chat currency CARRIES a
> caption while the editor renders none — `MediaBlockBox` drops it at the boundary. Routing: everything
> picked that is not video/music/voice becomes a document, including an image-mime file from the Files
> tab (that tab's "send as file" meaning). Documents are permanently single-item and never grouped into
> a collage or slideshow. The host renderer dispatches on the editor's `MediaKind` (threaded through the
> media-view seam), NOT by sniffing the resolved `Media` — sniffing sent an image-mime file to the photo
> pool. A file carrying a preview renders its **thumbnail** in the row (editor and bubble share the node,
> so both get it at once). Recipient-side render, the thumbnail/status-colour traps, and tap-to-open live
> in `instantpage-richtext.md`. Runtime-verified 2026-07-31.

- **Formatting menu (iOS 16+):** the composer's **Format** submenu (Bold/Italic/Monospace/Link/Strikethrough/
  Underline/Quote/Spoiler/Date/Code, secret-chat gated) is spliced into the editor's edit menu via
  `RichTextEditorView.contextMenuItemsProvider`. Actions route to the native engine; **Link** through the host
  `openLinkEditing`; **Code** creates a first-class code block; **Date** is a deferred no-op (the editor lacks
  only a timestamp-creation UI).
- **Custom emoji / mention / date:** carried by `ComposerDocumentBridge` (live) + the direct bridge. Custom
  emoji = one `U+FFFC` with the alt-string on `EmojiRef.altText` (emitted **as the run text** under the entity on
  send — a bare `U+FFFC` otherwise reaches the wire). Mentions / dates encode into the shared `link` field via
  `tg://user?id=` / `tg://timestamp?t=` markers (`TextFormat/MentionDateMarkers.swift`:
  `mentionMarkdownURL` / `dateMarkdownURL` / `classifyChatLink` / `chatInputLinkAttribute`). **Accepted
  limitation:** a `textUrl` whose string equals a `tg://` marker (via markdown/paste/edit) is reinterpreted as a
  mention/date on round-trip — low-probability, documented in `MentionDateMarkers.swift`.
- **Code blocks:** first-class multi-line `Block.code` (Core `CodeBlock` + `CodeBlockBox`), reusing the
  newline-agnostic position model. Markers in `TextFormat/CodeBlockMarkers.swift`; entity-expressible (`.Pre`).
  Enter inserts an interior newline (exits on an empty trailing line), backspace in an empty block un-codes it.
  Multi-line quotes also emit **one contiguous blockquote** on send. **Deferred:** language picker (creation
  sets `language = nil`; incoming language round-trips), code in table cells, inline formatting inside code.
- **Inline media:** an attached image/video renders inline in the native composer and survives expand↔collapse
  + drafts, carried by `ChatInputContent.media`. The concrete view is the shared
  `RichTextEditorMediaView.MediaItemNodeView` (also used by the article editor), resolved via the injected
  factory (§3).
  **Multi-media containers (added 2026-07-08).** A media block now holds `items: [ChatInputMediaItem]`
  (one **or more** photos/videos) with a single shared caption — the editor's `MediaBlock` gained the
  matching `items: [MediaItem]`. The change is additive/back-compat: a convenience single-media
  initializer + get-only accessors reproduce the old API, and both `MediaBlock`/`ChatInputMedia` Codable
  decode a legacy flat single-media payload into `items: [one]`, so existing single-media messages/drafts/
  tests are unchanged. Grouping is **photo/video only** — `.audio`/`.location` stay permanently
  single-item. A container renders in-editor as a **mosaic** via the shared `MosaicLayout` engine (the
  same one grouped album messages use), with per-cell view reuse keyed by media identity so surviving
  cells aren't rebuilt/re-fetched on an add/remove. A container of `items.count >= 2` sends as an
  InstantPage **`.collage`** rich message (see `instantpage-richtext.md`); `count == 1` still sends the
  byte-identical `.image`/`.video` block. **Layout mode (added 2026-07-17).** A `MediaBlock`/`ChatInputMedia`
  now carries a `displayMode` (`.mosaic` default / `.slideshow`, Codable back-compat → `.mosaic`); a
  `count >= 2` container in `.slideshow` mode renders in-editor as a swipeable carousel + paging dots and
  **sends as InstantPage `.slideshow`** instead of `.collage` (both forward converters branch on it; the
  reverse recovers it on edit). The toggle button that flips the mode is **article-editor only** (left of
  "+"); the composer stays mosaic-only. Design + plan:
  `docs/superpowers/{specs,plans}/2026-07-17-richtext-media-layout-toggle*`. **Authoring is split:** per-cell
  delete-one is wired in both hosts; "Add another photo/video" and the layout toggle are wired in the
  **article editor**'s chrome only — the composer's in-place Add is a deferred follow-up (the composer
  already renders/edits multi-media from sent albums and drafts). Design + plan:
  `docs/superpowers/{specs,plans}/2026-07-08-richtext-multi-media-container*`.
  **Media spoilers (added 2026-07-08).** A photo/video can be marked a Telegram-style spoiler (dust-covered
  until tapped), per **item**: `MediaItem.isSpoiler` (editor Core) ↔ `ChatInputMediaItem.isSpoiler`
  (both additive, optional-Codable, absent ⇒ `false`, so all existing docs/drafts/messages decode
  unchanged) ↔ a `spoiler: Bool` associated value on `InstantPageBlock.image`/`.video`. **Authoring:**
  tap-select a single medium → the edit menu's **"Spoiler"** item (`imageSelectionMenu`, toggles via
  `toggleSelectedMediaSpoiler`); for an album, each cell's **"•••"** menu carries a per-cell "Spoiler"
  (threaded through `MediaControlRequest.isSpoiler`/`toggleSpoiler` → `MediaControlContext` → the panel's
  ContextUI menu). Both route to `RichTextEditorView.toggleMediaSpoiler(itemIndex:)` →
  `DocumentCanvasView.toggleMediaSpoiler(blockID:itemIndex:)` (one undo step, in-place `MediaBlockBox`
  rebuild like `deleteMediaItem`). **In-editor render is a NON-revealable authoring cover** — `MediaItemNodeView`
  hosts a `MediaDustNode` (via `InvisibleInkDustNode`) per spoiler cell, `revealOnTap = false`, non-interactive
  (taps fall through to selection); the flag reaches it through `MediaProviderItem.isSpoiler` and is folded into
  the `syncMediaItemViews` items-signature so a toggle re-provides the cell. **On the wire, no Api
  regeneration:** the server schema already defines `pageBlockPhoto#1759c560 spoiler:flags.1` /
  `pageBlockVideo#7c8fe7b6 spoiler:flags.2`, so the bit is read/OR'd purely in `ApiUtils/InstantPage.swift`
  (like `autoplay`/`loop`). The flag round-trips through Postbox Codable (`"sp"` key), the flatBuffers
  `InstantPageBlock` path (`Models/InstantPageBlock.fbs` + the hand-written encode/decode — so it survives every
  InstantPage persistence path, not just Postbox), and BOTH send converters (`ChatInputContentInstantPage`
  composer + `InstantPageBuilder` article). **Sent/received message render** (revealable dust with first-tap
  reveal → then gallery) is in `instantpage-richtext.md`. Design + plan:
  `docs/superpowers/{specs,plans}/2026-07-08-richtext-media-spoiler*`. **All sim tests run on the iPhone 17 Pro
  K3 sim.**
- **Location maps:** a picked location is a `Block.media` with **`MediaKind.location`** whose `mediaID` resolves to
  a `TelegramMediaMap`. A map is an **id-less** `Media`, so the host mints a deterministic `"map:lat:long"` key
  (not the usual `namespace:id`). It renders inline as a map snapshot through the same `MediaItemNodeView` seam —
  which, for a `.geo` `EngineMedia`, threads an `InstantPageMapAttribute` so `InstantPageImageNode` draws the
  snapshot + pin — and survives expand↔collapse + drafts via `ChatInputContent.media`. It **sends as an InstantPage
  `.map(lat, long, zoom:15, dimensions:600×300, caption)` block** (NO `pageMedia` entry — coordinates are inline).
  BOTH converters emit it — `InstantPageBuilder` (article editor) and `ChatInputContentInstantPage` (composer) —
  each **restructured so the id-less map isn't dropped by the `media.id` guard**; the reverse rebuilds a
  `TelegramMediaMap` (venue/zoom/dimensions aren't represented and canonicalize to defaults, like image
  size/alignment). **Authoring is the existing attachment menu, not a dedicated button:** the editor's single
  attach action opens `presentRichTextAttachmentMenu` (Gallery / Audio / **Location**); the `.location` result
  returns as **`RichTextAttachment.location(TelegramMediaMap)`** and is inserted with the venue **title** as its
  caption (a raw dropped pin → empty caption). The rendered map shows the theme `list.mediaPlaceholderColor` while
  the async `MKMapSnapshotter` fetch completes (see `instantpage-richtext.md`). **Deferred:** live location /
  heading / proximity, editing a placed location's coordinates, an interactive in-editor map.
- **Audio:** an attached music/voice file is a `Block.media` with **`MediaKind.audio`** (a **single** kind for both —
  the file's `.Audio(isVoice:)` attribute drives the music-vs-voice render, so no separate voice kind). It renders
  inline as a **fixed-height 44pt row** (matching the V2 `audioFrame` height, not aspect-scaled — the first
  non-aspect media kind, so `MediaBlockBox.imageAreaHeight`/`measuredHeight`/`mediaRect` all branch on `kind ==
  .audio`), via a new **playable** standalone view `StandaloneInstantPageAudioView` (`InstantPageUI`, sibling to
  `StandaloneInstantPageImageView`) resolved through the same `MediaItemNodeView` seam — it hosts the module-internal
  `InstantPageV2AudioContentNode` driven by a self-contained one-item `InstantPageMediaPlaylist` (no enclosing V2
  tree; `freeMediaFileInteractiveFetched(.standalone)` so an edit-loaded cloud audio plays with no message
  reference). **In the editor the row is themed to the editor's accent/text scheme** (not the outgoing-bubble
  palette the V2 audio node uses for sent messages): the node gained an additive, nil-default
  `InstantPageAudioColorOverride` (play button + progress ring → editor accent, title/duration → editor primary/
  secondary text) that each host fills from the **same source the table reads** — `chat.inputPanel.*` in the
  composer, `list.item*` on the attachment screen; nil leaves real message rendering byte-unchanged.
  **Audio is a caption-less atom** — unlike image/video/location it has **no caption** (not rendered, editable, or
  present in the position model): `DocumentTree` emits `mediaBlock([mediaAtom])` (nodeSize 3, no caption paragraph)
  and `MediaBlockBox` is dual-moded on `kind == .audio` (`textLength 0`, `leafRegions []`, no "Add caption" row);
  inserting audio lands the caret in a following body paragraph, and the select-all/covered-delete checks use an
  audio-aware `coverableContentEnd` (`nodeStart + 1`). It **sends as an InstantPage `.audio(id, caption)` block**
  with an **always-empty caption** (file registered in `page.media`), drawn by the existing V2 audio node, and
  survives expand↔collapse + drafts via `ChatInputContent.media` (concrete `TelegramMediaFile`). BOTH converters
  emit/parse it — `InstantPageBuilder` (article) and `ChatInputContentInstantPage` (composer, both directions,
  paralleling `.image`/`.video`). **Authoring is the attachment menu's existing Audio button** (a music-file picker →
  `RichTextAttachment.file`; the `.file` route now branches `isVideo` → video, `isMusic || isVoice` → audio, else
  drop). **Voice is round-trip-only** (no picker / no in-editor recording): it enters on **edit** of a rich message
  that already contains a voice note, and renders through the same node (the V2 audio node is music-styled —
  **waveform rendering deferred**, voice plays as a music-style row via the `.voice` player type). **Accepted
  limitation:** an incoming audio caption is dropped when the message is opened for edit (audio is caption-less).

---

## 5. Send / edit / pending display of rich messages

Rich content that the entity set can't express (heading/list/table/media, and structured combinations) is sent
as a **`RichTextMessageAttribute`** carrying an `InstantPage`, rendered by the V2 path (see
`instantpage-richtext.md`). The `ChatInputContent ↔ InstantPage` pair lives in
`TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift`.

> **Interactive checklists round-trip (added 2026-06-26).** `ChatInputListMarker` gained `.checklist` and
> `ChatInputListMembership` a `checked: Bool?` field (optional Codable → old drafts decode unchanged; this is the
> draft currency, so checked state persists in drafts for free). It threads: editor `Document` ↔ `ChatInputContent`
> (`DocumentChatInputContentBridge`, both directions) ↔ `InstantPage` (`ChatInputContentInstantPage`: forward emits
> per-item `checked`; reverse maps an item with `checked != nil` back to `.checklist` — so `checked:false` survives,
> not collapsing to bullet) → `InstantPageListItem.checked`. A checklist is a list ⇒ already non-entity-expressible
> ⇒ routes to the rich `.instantPage` send path with no change. Recipient checkboxes are display-only; the sender
> re-edits via the reverse bridge. The editor side (tappable checkbox, creation, geometry) is in
> `RichTextEditor/CLAUDE.md`.

- **Send** (`ChatControllerNode.sendCurrentMessage`): reads the structural `composeInputState.content`. When
  `editMessage == nil && !content.isEntityExpressible() && !content.isEmpty`, enqueues **one**
  `.message(text: "", attributes: [RichTextMessageAttribute(instantPage: instantPage(from: content), …)], …)`.
  Entity-expressible content keeps the existing `breakChatInputText` text+entities loop **byte-identical**. The
  custom-emoji premium-lock harvest + early-return stays **before** the branch.
- **Edit** (`ChatControllerLoadDisplayNode`): LOAD seeds `ChatTextInputState(content: chatInputContent(fromInstantPage:
  richTextAttribute.instantPage))` (structural, media preserved — *not* a markdown flatten); DONE routes by
  `isEntityExpressible()` — non-entity → rebuild `RichTextMessageAttribute` + pass `richText:` (so the backend
  uploads media), else demote to plain text+entities. Native path only (the legacy composer flattens structure
  on the first keystroke).
- **Attachment-menu rich editor** (`ChatControllerOpenAttachmentMenu`'s `.richText` send →
  `composeRichMessage(from:media:forSendPreview:)` in `RichTextEditorMessageConversion`): passes
  `forSendPreview: true`, so a **blockquote forces the rich (InstantPage) path here** even though a quote is
  entity-expressible (`documentNeedsRichLayout` honors the same flag at the editor-`Document` level). The composer
  Send / Edit gates above pass **default** options, so a quote sent from the composer is still plain text + a
  blockquote entity — a deliberate, localized divergence (this rich-editor send's long-press now opens
  send-options with no preview — see "Expanded-editor send-options" below; the composer's preview opts into the
  same quote-as-rich rule, below).
- **Pending edits display optimistically:** `ChatUpdatingMessageMedia` carries an optional `richText`; the
  bubble prefers `itemAttributes.updatingMedia.map(\.richText) ?? item.message.richText` (display `:360`,
  anchor `:1449`, "Show more" gate `:567` in `ChatMessageRichDataBubbleContentNode`). The render-cache key
  (`ensurePageView` / `currentPageLayout`) includes a **pending-edit discriminator**
  (`(updatingMedia?.richText).map { ObjectIdentifier($0) }`) because `stableVersion` doesn't bump during a
  pending edit; and `PendingUpdateMessageManager.add` **publishes immediately** (a media-bearing rich edit
  swallows upload progress, so the optimistic value must be visible before the upload finishes).

### Rich-message media on the wire

The media-less serializer `RichTextMessageAttribute.apiInputRichMessage()` (`photos:/documents: nil`) is **only
the fallback** (nil / secret-chat / empty-media / upload-failure). The real paths upload + assemble:

- `richMessageContentToUpload` → `assembleInputRichMessage` (`PendingMessageUploadedContent.swift`) fill
  `photos`/`documents` (already-cloud media short-circuits to cloud IDs); `uploadedRichMessage(...)` is the thin
  single-emission (`take(1)`) resolver.
- **Send** routes through `messageContentToUpload` → uploads. **Edit** sequences `uploadedRichMessage` before its
  media chain. **Incoming parse** (`SyncCore_RichTextMessageAttribute.swift`) reconstructs `media` from
  `photos`/`documents`.

### Send-options preview (long-press Send)

Long-pressing **Send** opens the send-options context screen (`ChatSendMessageContextScreen`), whose preview
bubble renders the message as it will be sent. For rich content the bubble shows the actual `InstantPage` via
`ChatSendMessageRichTextPreview` (wrapping an `InstantPageV2View` in the outgoing message theme), injected through
the `ChatSendMessageContextScreenRichTextPreview` protocol (mirroring the existing media-preview seam, since
`ChatSendMessageActionUI` cannot dep `InstantPageUI`).

- **Gating mirrors the real send paths**, built in `Chat/ChatMessageDisplaySendMessageOptions.swift` via the
  file-private `makeRichTextSendPreview(context:content:mediaPreview:)` (predicate: `mediaPreview == nil &&
  !content.isEmpty && !content.isEntityExpressible(options: [.quotesRequireRichContent])`). New-message branch feeds
  `composeInputState.content` (matching `ChatControllerNode`'s send gate; additionally skipped for
  `.customChatContents`); edit branch feeds `editMessage.inputState.content` (matching `ChatControllerLoadDisplayNode`'s
  edit gate). Plain / quote-free entity-expressible content keeps the flat-text morph. With the legacy composer,
  content is always flat → entity-expressible → no preview (so no `debugRichText` check is needed).
- **A blockquote previews as a rich bubble** (the `.quotesRequireRichContent` opt-in), even though the composer
  Send / Edit gates send a quote as plain text + a blockquote entity (they pass default options — see the
  divergence note above). So a quote-only message's preview bubble (InstantPage) renders through a different path
  than the eventually-sent message; align the two by passing `.quotesRequireRichContent` at those gates too if a
  pixel-faithful preview is wanted.
- **Morph (`MessageItemView`):** the plain-text path morphs a flat-text copy of the live field into the bubble.
  That copy can't represent rich structure (headings/lists/tables), so the rich path instead captures a **pixel
  snapshot** of the live input field on the source-state layout (before the screen hard-hides the field), positions
  it to overlay the field exactly (top-left at `(textInsets.left, 2.0)`, matching the screen's
  `sourceMessageItemFrame` math), and crossfades that snapshot into the `InstantPageV2View` as the bubble settles.
  Falls back to the flat-text crossfade if `snapshotView` returns nil.
- **Flat-copy text color is set per morph state**, keyed off `explicitBackgroundSize == nil` (`isSettled`): the
  extracted `textString` carries no base foreground color that renders correctly here (the preview node defaults it
  to **black**), so `MessageItemView` applies one explicitly and re-applies it whenever the state flips (tracked by
  `textNodeUsesOutgoingColor`). Settled (inside the outgoing bubble) → `chat.message.outgoing.primaryTextColor`;
  source / animate-out (the copy overlaying the live field) → `chat.inputPanel.inputTextColor`, so the copy matches
  the still-visible field. This is why a colored outgoing bubble shows the right color (e.g. white) instead of black,
  and why the dark-theme animate-out doesn't fall back to black. Link entities stay `outgoing.linkTextColor` in both
  states.
- **Clipping:** the page content is clipped to the bubble's inner corner radius (15pt, matching the real rich
  bubble's `image.defaultCornerRadius`) within the tail-excluded content rect `[1, width − 7]` (same as the text
  path), so images/tables round to the bubble and stay clear of the outgoing tail.

### Expanded-editor send-options (`RichTextAttachmentScreen`, no preview)

The **expanded** rich-text editor's own **Send** button (`RichTextAttachmentScreen`, the full-screen article
editor — *not* the chat composer's Send above) gained an optional long-press → send-options action (Send / Send
silently / Schedule / Send when online) via `makeChatSendMessageActionSheetController(params: .sendMessage(…
mediaPreview: nil …))` — **no message preview** (distinct from the composer's preview subsection above). It is
**caller-supplied**: the screen takes an optional `RichTextAttachmentScreenSendContextActions` (a module-local
type — `peerId` + `send`/`schedule` closures over the screen's native `(Document, [String: Media], [Int64:
TelegramMediaFile], withoutFormatting: Bool, SendMode, SendParameters?)` tuple; kept out of `AccountContext` because
that tuple's `RichTextEditorCoreDocument` must not pull `RichTextEditorCore` into `AccountContext`). When it is
`nil` the button is tap-only (feature off). The long-press is offered only when `sendContextActions != nil &&
isSendEnabled && !isSendRichFormattingLocked` — **suppressed while a non-premium formatting lock is active**, so the
tap path's remove-formatting alert can't be side-stepped (⇒ `withoutFormatting` is always `false` on this path). The
send button is wrapped in a `ContextExtractedContentContainingView` for the extract-out animation (mirrors
`TextProcessingScreen`'s `ActionButtonsComponent`). Screen side: `displayLongPressSendMenu` in
`RichTextAttachmentScreen.swift`.

Two callers supply the actions, gated identically on `editMessage == nil && chatLocation.peerId != nil`:

- **Composer handoff** (`ChatControllerNode.openExpandedInput`): `send`/`schedule` set the chat's effective input
  state from the editor content, then route through the **same `self.sendCurrentMessage(...)` the tap path uses**
  (`.generic`/`.silently`, `.whenOnline` → `scheduleTime: scheduleWhenOnlineTimestamp`) and
  `controllerInteraction?.scheduleCurrentMessage` — so tap-Send and long-press-Send stay identical.
- **Article route** (`ChatControllerOpenAttachmentMenu`'s `.richText` case, which sends by building an
  `EnqueueMessage` directly, not via `sendCurrentMessage`): shared `buildRichTextContent` + `performRichTextSend`
  locals feed `transformEnqueueMessages(silentPosting:scheduleTime:)` per mode (`.whenOnline` →
  `scheduleWhenOnlineTimestamp`) with `presentScheduleTimePicker` for Schedule, then
  `presentPaidMessageAlertIfNeeded` → `sendMessages`. Here message **effects are ignored** and **when-online just
  sends** (no scheduled-view navigation).

---

## 6. Draft persistence

Two layers (see `SyncCore_SynchronizeableChatInputState.swift`, `ChatInterfaceState.swift`):

- **Local** — `ChatTextInputState` persists `ChatInputContent` under the `"cm"` Codable key (back-compat-decoding
  the legacy `"at"` `ChatTextInputStateText`). So a rich draft (incl. media, via the concrete `Media`) survives an
  app restart on-device.
- **Cloud / cross-device** — `ChatInterfaceState.synchronizeableInputState` produces a
  `SynchronizeableChatInputState.Content`: `.textEntities(text,entities)` for entity-expressible content,
  `.instantPage(InstantPage)` otherwise. `ManagedSynchronizeChatInputStateOperations` builds `messages.saveDraft`.

> **Invariant — `ChatInterfaceState.parse` always overrides `composeInputState` from the flat synchronizeable
> form, but does NOT override `editMessage.inputState`.** So the `"cm"` local Codable is redundant-but-harmless
> for the composer yet load-bearing for the **edit-message** draft (preserves structure the fragmenting `"at"`
> round-trip would lose).

> **Invariant — `saveDraft` sends `message: ""` / no entities (clears the `1<<3` flag) when `richMessage` is
> set.** The InstantPage already carries the text; the receiver builds the draft **purely** from `richMessage`
> when present (`AccountStateManagementUtils` ignores `message`/`entities`), so sending the flat text duplicates
> it on the wire.

### Cross-device media sync

The cloud draft uploads its inline media (the last media-less path, now closed). Driven by the account's
**`MessageMediaPreuploadManager`, made lifecycle-aware**: `add(...)` returns a `Disposable` (a ref-counted
"need" reusing the existing `subscribers: Bag`); the last released need starts a **1 s grace timer** that
cancels + evicts the upload unless re-added; a live/in-grace context is reused, never restarted (this also
fixes a context leak — `LegacyLiveUploadInterface` holds its token until `deinit`). `synchronizeChatInputState`
resolves the rich message through `uploadedRichMessage`, so the bytes upload **once** and are shared with the
eventual send.

> Since **media pre-upload** (below) the per-peer need `updatePeerMediaNeeds` holds is **media-level** and
> covers every uploadable medium, not byte-level over `TelegramMediaFile`s with a `localIdForResource`. That
> older form silently excluded images entirely, and excluded videos and iCloud files (whose resources have no
> local id) — those were re-uploaded on every draft save *and* again at send.

## 6a. Media pre-upload

Media attached in the editor starts uploading **immediately**, and the client takes over the result at send,
at draft save, and across the editor being closed and reopened. Architecture and the full behavioural matrix
are in the design doc (kept on branch `feature/richtext-media-preupload`, not on master).

**One registry, two layers, on the existing `MessageMediaPreuploadManager`.** Its byte layer
(`uploadContexts: [Int64: …]`, keyed by `localIdForResource`) is unchanged. A new media layer
(`mediaContexts`, keyed by `MediaId`) parks a **cloud `EngineMedia`** and runs bytes →
`messages.uploadMedia` → cloud media via the shared `uploadMediaToCloud`. The media layer's byte step goes
through the manager's own `upload(...)`, so the two share one transfer wherever `localIdForResource`
resolves; where it does not — video, iCloud files — the media layer is the only dedup there is, which is
why it must key on `MediaId`. The ref-counting itself lives in a standalone, unit-tested module,
`submodules/MediaPreuploadRegistry` (21 tests).

**Two holders, both reconciling through the same `MediaPreuploadNeeds`:**

```
DURABLE    ManagedSynchronizeChatInputStateOperations.updatePeerMediaNeeds
           reconciles from the PERSISTED draft — survives closing the editor AND leaving the chat
TRANSIENT  RichTextAttachmentScreen  — from its live document, covering attach-before-first-save
           ChatControllerNode        — from composeInputState.content, covering the editor handoff
```

### Load-bearing invariants

- **Needs and subscribers are counted separately.** A *need* keeps an upload alive; an *observer* only
  watches. Grace fires when needs hit zero regardless of observers, so a passive UI subscriber can never
  pin an orphaned upload. `join` (the send path) holds a need for its subscription, which is what stops a
  send in flight being evicted when the editor that started it closes.
- **A context must never leave a subscriber waiting.** Every eviction path — failure, cancellation, grace
  expiry — notifies subscribers with a terminal state *before* removing the context. A subscriber that only
  ever sees `.progress` is a hang on Send, not a slow upload.
- **The promotion write-back is a map-value swap under the UNCHANGED key.** The editor addresses media by an
  opaque `mediaID` string (`resolveMedia: { media[mediaID] }`), so replacing the value promotes the medium
  everywhere downstream with no document mutation, no undo entry and no relayout. Re-deriving the key from
  the cloud media is a bug: promotion changes the `MediaId`, so the medium would silently vanish on
  read-back. `moveResourceData` points the local bytes at the cloud resource so nothing flashes a placeholder.
- **`isPreuploadableMedia` answers "is this worth pre-uploading?", NOT "can the send path use this?"** It
  returns `false` for already-cloud media. Gating the *send* on it fails every promoted medium outright —
  which is exactly what broke sending after a successful pre-upload. The send path asks
  `uploadedRichMedia(from:)` instead, which answers the second question, and handles image and file
  symmetrically.
- **`forceReupload` must bypass the whole registry**, evicting first. It is set by `PendingMessageManager`'s
  `FILEREF_INVALID` / `FILE_REFERENCE_*_EXPIRED` retry, so a parked result — or the already-cloud fast path —
  would resend the very reference the server just rejected, and only one retry is permitted. Residual gap: if
  the bytes are no longer on disk (fresh device, cache eviction), the forced re-upload still fails; the
  correct fix is reference revalidation.
- **Progress is owned by the media view, not pushed to it.** `syncMediaItemViews` re-invokes the media-view
  provider only when a block's `itemsSignature` changes, and upload progress is not — and cannot be — part of
  that signature. `RichTextMediaContentComponent.View` therefore subscribes to `mediaPreuploadState(id:)`
  itself and updates its status node **directly**, never via `state.updated()` (which re-enters `update`, and
  `update` re-issues the image fetch unconditionally).

### Re-login restore

On a fresh login the server delivers each chat's draft in the **dialog `draft` field** (`getDialogs`), not as an
`updateDraftMessage`. Drafts (rich included) restore via the shared parser
`_internal_synchronizeableChatInputState(accountPeerId:peerId:apiDraft:)` (`Sources/State/RestoreFetchedDrafts.swift`,
also called by the incremental `updateDraftMessage` path) + `_internal_applyFetchedChatInputStates`, wired into
`ResetState` (login) and `fetchChatListHole` (live session) after `updatePeers`.

> **Invariant — newer-wins, never-clear.** A fetched draft is applied only if there's no local draft OR its
> `date` is strictly newer than the local `synchronizeableInputState.timestamp` (so a live edit is never
> clobbered). Only non-empty `.draftMessage` drafts are collected (a fetch never clears; clearing stays with the
> real-time path). A pinned chat's draft appears in both the remote and pinned responses — the duplicate is
> deduped by the idempotent newer-wins guard, **not** explicitly, so don't drop the strict-`>` guard.

---

## 7. Markdown on paste (plain text → rich)

Pasting **plain text that parses as CommonMark markdown** inserts it as rich content instead of a literal
string — `**bold**` becomes bold, `# Heading` / `- list` / a `|`-table become real blocks. Clipboard paste
only (no drag-&-drop, programmatic insert, or share-extension prefill). Always-on; undo is the escape hatch.

**Pipeline (reuses the send-path parser).** `chatInputContentFromPastedMarkdown(context:plainText:)`
(`TelegramUI/Sources/PastedMarkdownConversion.swift`) runs the same CommonMark parser the rich-message *send*
path uses — `inputRichTextAttributeFromText` (`BrowserUI/BrowserMarkdown.swift`, Apple `NSAttributedString(markdown:)`
with default options) → `InstantPage` → `chatInputContent(fromInstantPage:)` → `ChatInputContent`. A pure gate
`pastedMarkdownContentIsRicherThanPlain(_:)` (`TextFormat/PastedMarkdownGate.swift`) returns nil when the parse
is nothing but unformatted `.body` paragraphs, so ordinary text (incl. multi-line) falls through to the default
plain paste; CommonMark's paired-delimiter rules mean a stray `*`/`-` never triggers.

**Self-referential links are stripped BEFORE that gate (load-bearing — a pasted URL must stay plain).** Apple's
`NSAttributedString(markdown:)` applies the **GFM autolink extension**, so a bare `https://…` — and also a bare
`www.…` host or an email address, each of which the parser *rewrites* into `http://www.…` / `mailto:…` — comes
back as a LINK run whose label is the URL itself. That entity alone made the gate answer "richer than plain", so
pasting a plain URL latched the field to the native editor and landed the URL as a **text link** (`textUrl`),
pinning a destination the plain URL already carries. `chatInputContentStrippingSelfReferentialLinks(_:)`
(`TextFormat/SelfReferentialLinks.swift`) clears every `.url` entity whose covered text IS its own URL, so a
URL-only paste now falls through to plain paste and the recipient's client detects the URL itself. A genuine
text link (`[label](url)`, a label that differs from its target) is untouched and still classifies as rich, as is
anything pasted from Telegram's own `private.telegramtext` / editor-fragment representations — those never go
through an importer. The predicate `chatInputLinkIsSelfReferential(text:url:)` tolerates exactly the
normalizations a producer applies (added `mailto:` / `http(s)://` scheme — the latter only when the text carries
no scheme of its own — percent-encoded path, trailing `/`); a `tg://` mention/date marker never matches its own
label, so those entities are unaffected. **The same rule is applied on the other import paths, not just markdown**:
`chatInputStateStringFromRTF` (legacy field, RTF/HTML paste — via the `NSAttributedString` form
`chatInputTextStrippingSelfReferentialLinks`), `legacyChatInputAttributedString(fromRTF:)`, and the editor's own
`RTFConversion.fragment(fromRTF:)` (which uses a **duplicate** of the predicate, `linkIsSelfReferential`, in
`RichTextEditorCore` — Core cannot import `TextFormat`; keep the two in step). The **copy** direction
(`storeAttributedTextInPasteboard`) is deliberately NOT touched: it keeps whatever entities the source message
carried.

**Why the monolith owns the parse.** `BrowserUI` already depends on `ChatRichTextEditorComposer`, so neither the
panel, the attachment screen, nor the `RichTextEditor` package may import it (cycle). The parse therefore lives in
the `TelegramUI` monolith (the one layer that can import `BrowserUI` + `AccountContext`) and is **injected downward
as a closure**. The `RichTextEditor` package stays markdown-free: it exposes a neutral
`plainTextFragmentTransformer: ((String) -> Document?)?` it calls without knowing what markdown is.

**Wiring.**
- Chat composer: `ChatTextInputPanelNode.pastedMarkdownParser` (set at panel construction — `ChatControllerNode`
  / `ChatInterfaceStateInputPanels`). It sets `ChatRichTextInputNode.pastedMarkdownFragmentParser` on the native
  node (→ `RichTextEditorView.plainTextFragmentTransformer`), and in `chatInputTextNodeShouldPaste()` (legacy
  field), **any** markdown latches to the native editor via `pasteRichFragmentFromPasteboard()`. So all markdown
  paste — inline or structural, legacy-surface or native — flows through the native editor uniformly.
- Article editor: `RichTextAttachmentScreen(pastedMarkdownParser:)` threads the closure to its `RichTextEditorView`.

**Two-step undo (load-bearing).** The native paste (`DocumentCanvasView.pasteMarkdownTwoStep`) inserts the **raw
markdown text** as step 1, then **replaces that range with the rich content** as step 2 — so one Cmd+Z / shake
reverts rich → plain and a second removes it. Step 2 is deferred to the **next run-loop cycle** on purpose: the
editor's private `UndoManager` uses the default `groupsByEvent`, which coalesces every registration made in one
run-loop event into a single undo group, so a synchronous step 2 would collapse both into one undo. To avoid a
visible flash of the raw markdown, step 1 sets `DocumentCanvasView.suppressHostChangeNotification`, which makes
`notifyContentSizeChanged()` (gated at its definition — `setBlocks` calls it too, not just `editing {}`) and the
`editing {}` trailing `refreshSelectionUI()`/`onSelectionChange()` no-op; the canvas has no `draw(_:)` and is
parent-driven, so with the host un-notified the intermediate state neither lays out nor moves the caret. Step 2
runs the normal, host-notifying edit, so only the rich result is drawn and the caret moves once (to its end).

**Nested lists.** `chatInputBlocks(fromInstantPageBlocks:)` recurses into `InstantPageListItem.blocks` items — a
list item that carries continuation paragraphs and/or a nested sub-list, which the markdown parser emits for an
indented sub-list — preserving indent via `ChatInputListMembership.level` (mapped on to the editor's
`ListMembership.level` by the bridge). Skipping `.blocks` used to silently drop a whole nested sub-list on paste.

**Accepted limitation.** The ChatInputContent → InstantPage *forward* (send) still coalesces list items to a flat
level (canonicalizes indent), so a pasted nested list **displays** nested in the composer/editor but may flatten
when the message is sent — a separate send-path change.

## 8. Accepted limitations & deferred work

- **Cross-device collapsed-quote fidelity (multi-block only):** drafts sync as
  `Api.InputRichMessage.inputRichMessage(blocks: [Api.PageBlock])`
  (`ManagedSynchronizeChatInputStateOperations.swift`), so a **single-paragraph** collapsed quote now
  keeps its collapsed state across devices — `pageBlockBlockquote` carries `collapsed:flags.0?true`.
  A quote with two or more blocks still serializes as `pageBlockBlockquoteBlocks`, which has no such
  flag, and arrives expanded. Closing that needs a server-side
  `pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true`.
- **Custom-emoji `enableAnimation`** has no `RichText` carrier, so it canonicalizes to `true` on the reverse
  (re-derived at decoration; pinned by `test_customEmoji_enableAnimationFalse`).
- **Forum/monoforum topic drafts** and **folder/archived dialog drafts** are not restored on the `fetchChatList`
  path (separate paths; archived drafts restore when that folder is fetched).
- **Date creation** in the composer is a no-op (preservation only — an incoming date round-trips).
- **Code blocks:** no language picker; no code inside table cells; no inline formatting inside code.
- The `SynchronizeableChatInputState.Content.instantPage` cloud branch is exercised today only by structural
  blocks; everything entity-expressible takes `.textEntities`.
- **Writing-direction override in the composer:** auto-detect handles RTL while typing, but a manual whole-document
  LTR/RTL toggle is not surfaced in the chat composer (it exists on the façade + the attachment screen). Gutter
  ornaments (list markers / quote bar / indents) and table columns are not yet mirrored for RTL.
- **Document blocks have no composer authoring affordance** — they enter the composer only via the edit
  round-trip; the article editor is the only place to attach one. There is likewise **no editor-side
  open/preview** of an attached document.
- **Markdown copy drops a document block** (`InstantPageToMarkdown` has no spelling for it), the same class of
  loss already accepted for inline buttons. Editing is unaffected — that path is structural.
- **`ChatInputMediaKind` raw `4` fails to decode on an older build** reading a cross-device-synced draft (its
  `init(from:)` rejects unknown raw values). Consistent with the `ChatInputListMarker.checklist` precedent.
- **File-reference refresh for an EXPIRED rich-message document is unverified.** The open path builds
  `FileMediaReference.message(…)`, but the file lives in the attribute rather than `message.media`.
  Freshly-received messages are unaffected; the fallback if it fails is a `.standalone(media:)` reference.

## Key files

| Concern | Path |
|---|---|
| value model + Codable | `TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift` |
| display-neutral conversion | `TextFormat/.../ChatInputContentConversion.swift` |
| `ChatInputContent ↔ InstantPage` | `TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift` |
| direct editor bridge | `Chat/ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift` |
| live / send / expand bridges | `ChatRichTextEditorComposer/Sources/{ComposerDocumentBridge,ComposerExpandedEditorBridge}.swift` |
| markers (mention/date, code) | `TextFormat/.../MentionDateMarkers.swift`, `CodeBlockMarkers.swift` |
| native node | `Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` |
| panel (GET/SET, node select) | `Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` |
| markdown-on-paste parse (monolith) | `TelegramUI/Sources/PastedMarkdownConversion.swift` |
| markdown-on-paste gate | `TextFormat/Sources/PastedMarkdownGate.swift` (`+ Tests/PastedMarkdownGateTests.swift`) |
| self-referential-link strip (paste) | `TextFormat/Sources/SelfReferentialLinks.swift` (`+ Tests/SelfReferentialLinkTests.swift`); editor-side duplicate `RichTextEditorCore/Model/SelfReferentialLinks.swift` |
| CommonMark → InstantPage (send + paste) | `BrowserUI/Sources/BrowserMarkdown.swift` (`inputRichTextAttributeFromText`) |
| two-step paste + neutral transformer hook | `RichTextEditor/.../Canvas/DocumentCanvasView+Clipboard.swift` (`pasteMarkdownTwoStep`), `DocumentCanvasView.swift` (`plainTextFragmentTransformer`, `suppressHostChangeNotification`) |
| state value-equality | `AccountContext/Sources/ChatController.swift` |
| send / edit | `TelegramUI/Sources/ChatControllerNode.swift`, `Chat/ChatControllerLoadDisplayNode.swift` |
| expanded-editor send-options | `RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift`; callers `ChatControllerNode.swift` (`openExpandedInput`), `ChatControllerOpenAttachmentMenu.swift` (`.richText`) |
| rich attribute + wire | `TelegramCore/Sources/SyncCore/SyncCore_RichTextMessageAttribute.swift` |
| upload + assemble | `TelegramCore/Sources/PendingMessages/PendingMessageUploadedContent.swift` |
| draft persistence | `TelegramCore/Sources/SyncCore/SyncCore_SynchronizeableChatInputState.swift`, `ChatInterfaceState/Sources/ChatInterfaceState.swift` |
| cloud draft sync + media | `TelegramCore/Sources/State/ManagedSynchronizeChatInputStateOperations.swift`, `State/MessageMediaPreuploadManager.swift` |
| re-login restore | `TelegramCore/Sources/State/RestoreFetchedDrafts.swift` |
