import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore
import TextFormat
import RichTextEditorMessageConversion

/// A DIRECT, structure-preserving bridge between the RichTextEditor `Document` and TelegramCore's
/// `ChatInputContent` value model — the draft currency for the native composer node.
///
/// This bypasses the `NSAttributedString` hop (`ComposerDocumentBridge`), which silently drops the
/// structural blocks the `NSAttributedString` vocabulary can't carry (`.media` / `.table`, plus
/// heading/list information). The mapping is a 1:1 block tree + inline-run transcode that reuses the
/// existing inline rules (link classification via `TextFormat`'s `classifyChatLink` / `mentionMarkdownURL`
/// / `dateMarkdownURL`; custom emoji ↔ `EmojiRef`; spoiler/bold/italic/mono/strike/underline) so the two
/// converters can't drift. The non-chat-representable character attributes (`fontFamily` / `fontSize` /
/// `foreground` / `highlight` / `baselineOffset`) are dropped, matching what the chat layer can express.
/// An editor `EmojiRef`'s `altText` / `instanceID` are also dropped — `ChatInputContent`'s
/// `customEmoji(fileId:file:enableAnimation:)` has no slot for them, so the emoji placeholder text degrades to a
/// bare `U+FFFC` on a `Document → ChatInputContent → Document` round-trip (an inherent model limitation; `altText`
/// is otherwise load-bearing on the send path). `enableAnimation` is canonicalized to `true` (no editor field).
///
/// The two media/emoji indirections are threaded as closures so the node (Task #44) supplies its own
/// host resolvers:
/// - `resolveEmoji` maps an editor `EmojiRef` to the chat layer's `(fileId, file)`; nil ⇒ the run degrades
///   to plain text (no representable emoji), matching `ComposerDocumentBridge`'s non-numeric-id fallback.
/// - `resolveMedia` maps the editor's opaque `MediaBlock.mediaID` to a concrete `Media`; nil ⇒ the media
///   block is dropped (an unresolved medium has no `ChatInputMedia` representation).
/// - `registerEmoji` / `registerMedia` are the reverse: they hand the chat-layer identity back to the host
///   and return the editor-side ref/key for it.

// MARK: - Document → ChatInputContent

/// Convert the editor's live `Document` to the chat-layer `ChatInputContent` value model.
/// `resolveEmoji` and `resolveMedia` map the editor's opaque host keys to concrete chat-layer values; an
/// unresolvable emoji degrades to plain text and an unresolvable medium is dropped (see the type doc).
public func chatInputContent(
    fromDocument document: Document,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?,
    resolveMedia: (String) -> Media?
) -> ChatInputContent {
    var blocks: [ChatInputBlock] = []
    for block in document.blocks {
        switch block {
        case let .paragraph(paragraph):
            blocks.append(.paragraph(ChatInputParagraph(
                style: chatInputStyle(fromParagraphStyle: paragraph.style),
                list: paragraph.list.map(chatInputList(fromList:)),
                runs: chatInputRuns(fromRuns: paragraph.runs, resolveEmoji: resolveEmoji)
            )))
        case let .code(code):
            blocks.append(.code(ChatInputCode(
                language: code.language,
                runs: chatInputRuns(fromRuns: code.runs, resolveEmoji: resolveEmoji)
            )))
        case let .pullQuote(pq):
            blocks.append(.pullQuote(ChatInputPullQuote(
                runs: chatInputRuns(fromRuns: pq.runs, resolveEmoji: resolveEmoji),
                author: chatInputRuns(fromRuns: pq.author, resolveEmoji: resolveEmoji))))
        case let .media(media):
            // Resolve each item's Media; drop unresolvable items. A container with no resolvable items is dropped.
            let resolvedItems: [ChatInputMediaItem] = media.items.compactMap { item in
                guard let resolved = resolveMedia(item.mediaID) else { return nil }
                return ChatInputMediaItem(
                    media: resolved,
                    kind: chatInputMediaKind(fromKind: item.kind),
                    naturalSize: ChatInputSize(width: item.naturalSize.width, height: item.naturalSize.height),
                    isSpoiler: item.isSpoiler)
            }
            guard !resolvedItems.isEmpty else { continue }
            blocks.append(.media(ChatInputMedia(
                items: resolvedItems,
                displayWidth: media.displayWidth,
                alignment: chatInputMediaAlignment(fromAlignment: media.alignment),
                displayMode: media.displayMode == .slideshow ? .slideshow : .mosaic,
                caption: chatInputRuns(fromRuns: media.caption, resolveEmoji: resolveEmoji)
            )))
        case let .table(table):
            blocks.append(.table(chatInputTable(fromTable: table, resolveEmoji: resolveEmoji)))
        case let .blockQuote(bq):
            // Editor block-quote container → currency .blockQuote, recursing its children as a sub-document.
            let inner = chatInputContent(fromDocument: Document(blocks: bq.children),
                                         resolveEmoji: resolveEmoji, resolveMedia: resolveMedia)
            blocks.append(.blockQuote(ChatInputBlockQuote(
                content: inner, collapsed: bq.collapsed,
                author: chatInputRuns(fromRuns: bq.author, resolveEmoji: resolveEmoji))))
        case let .buttonRow(row):
            blocks.append(.buttonRow(ChatInputButtonRow(
                buttons: row.buttons.map(chatInputButton(fromButtonRef:)),
                alignment: instantPageRowAlignment(from: row.alignment)
            )))
        case let .details(d):
            // Editor detail (folding) container → currency .details, recursing its children as a sub-document.
            let inner = chatInputContent(fromDocument: Document(blocks: d.children),
                                         resolveEmoji: resolveEmoji, resolveMedia: resolveMedia)
            blocks.append(.details(ChatInputDetails(
                content: inner,
                title: chatInputRuns(fromRuns: d.title, resolveEmoji: resolveEmoji),
                expanded: d.expanded)))
        }
    }
    return ChatInputContent(blocks: blocks)
}

private func chatInputStyle(fromParagraphStyle style: ParagraphStyleName) -> ChatInputParagraphStyle {
    switch style {
    case .body:
        return .body
    case .heading1:
        return .heading1
    case .heading2:
        return .heading2
    case .heading3:
        return .heading3
    case .heading4, .heading5, .heading6:
        // ChatInputContent (the composer model) only models H1–H3; fold deeper editor headings to H3.
        return .heading3
    case .caption:
        // `caption` is a render-only style (only ever appears in a media block's caption runs, handled
        // there). A `caption`-styled top-level paragraph should not exist, but map it to `.body` defensively.
        return .body
    case .pullQuote:
        // `pullQuote` is a render-only style (only ever appears as a Block.pullQuote; never persists as
        // a top-level paragraph style). Map defensively to `.body`.
        return .body
    }
}

private func chatInputList(fromList list: ListMembership) -> ChatInputListMembership {
    let marker: ChatInputListMarker
    switch list.marker {
    case .bullet:
        marker = .bullet
    case .ordered:
        marker = .ordered
    case .checklist:
        marker = .checklist
    }
    return ChatInputListMembership(marker: marker, level: Int32(list.level), checked: list.checked)
}

private func chatInputMediaKind(fromKind kind: MediaKind) -> ChatInputMediaKind {
    switch kind {
    case .image:
        return .image
    case .video:
        return .video
    case .location:
        return .location
    case .audio:
        return .audio
    case .document:
        return .document
    }
}

private func chatInputMediaAlignment(fromAlignment alignment: MediaAlignment) -> ChatInputMediaAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    }
}

private func chatInputTextAlignment(fromAlignment alignment: TextAlignment) -> ChatInputTextAlignment {
    switch alignment {
    case .left, .natural:
        // `.natural` is leading (left in LTR); the chat input content has no natural case, and its
        // default is `.left`, so natural maps to left. Chat-side text rendering re-detects RTL anyway.
        return .left
    case .center:
        return .center
    case .right:
        return .right
    case .justified:
        return .justified
    }
}

private func chatInputColor(fromColor color: RGBAColor) -> ChatInputColor {
    return ChatInputColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
}

private func chatInputTableVerticalAlignment(fromCore alignment: VerticalAlignment) -> ChatInputTableVerticalAlignment {
    switch alignment {
    case .top:
        return .top
    case .middle:
        return .middle
    case .bottom:
        return .bottom
    }
}

private func chatInputTable(
    fromTable table: TableBlock,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> ChatInputTable {
    let columns = table.columns.map { column in
        ChatInputColumnSpec(width: column.width)
    }
    let rows = table.rows.map { row -> ChatInputTableRow in
        let cells = row.cells.map { cell -> ChatInputTableCell in
            // A `ChatInputTableCell` is inline-only (a flat run list). A well-formed editor cell holds a
            // single `.paragraph`; defensively flatten ANY cell content to runs (a non-paragraph block —
            // media/table/code — contributes its text only, ignoring structure the cell can't carry).
            ChatInputTableCell(
                runs: chatInputRuns(fromRuns: cellRuns(fromBlocks: cell.blocks), resolveEmoji: resolveEmoji),
                background: cell.background.map(chatInputColor(fromColor:)),
                horizontalAlignment: chatInputTextAlignment(fromAlignment: cell.horizontalAlignment),
                verticalAlignment: chatInputTableVerticalAlignment(fromCore: cell.verticalAlignment),
                isHeader: cell.isHeader,
                colspan: cell.colspan,
                rowspan: cell.rowspan
            )
        }
        return ChatInputTableRow(height: row.height, cells: cells)
    }
    return ChatInputTable(columns: columns, rows: rows, compact: table.compact, bordered: table.bordered)
}

/// Flatten a table cell's blocks to a single run list. A paragraph contributes its runs verbatim; any other
/// block type contributes a plain-text run of its text (its structure is not representable inline). Blocks
/// are concatenated with no separator (cells are conceptually single-paragraph).
private func cellRuns(fromBlocks blocks: [Block]) -> [TextRun] {
    var runs: [TextRun] = []
    for block in blocks {
        switch block {
        case let .paragraph(paragraph):
            runs.append(contentsOf: paragraph.runs)
        case let .code(code):
            runs.append(contentsOf: code.runs)
        case let .pullQuote(pq):
            runs.append(contentsOf: pq.runs)
            runs.append(contentsOf: pq.author)
        case let .media(media):
            // No inline text for the medium itself; keep only its caption text.
            runs.append(contentsOf: media.caption)
        case .table:
            // A nested table has no flat-run form; contribute nothing.
            break
        case .buttonRow:
            // A table cell is a flat run list and a button row has no inline form; contribute nothing.
            // Its label is button chrome, not document text, so leaking it into the cell would be wrong.
            break
        case let .blockQuote(bq):
            // A table cell is inline-only; block-quote structure is not representable inside a cell.
            // Flatten the quote's children's runs inline.
            for child in bq.children {
                runs.append(contentsOf: cellRuns(fromBlocks: [child]))
            }
            runs.append(contentsOf: bq.author)
        case let .details(d):
            // A table cell is inline-only; detail-block structure is not representable inside a cell.
            // Flatten the title then the children's runs inline.
            runs.append(contentsOf: d.title)
            for child in d.children {
                runs.append(contentsOf: cellRuns(fromBlocks: [child]))
            }
        }
    }
    return runs
}

private func chatInputRuns(
    fromRuns runs: [TextRun],
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> [ChatInputRun] {
    return runs.map { run in
        let attributes = chatInputInlineAttributes(fromCharacterAttributes: run.attributes, resolveEmoji: resolveEmoji)
        // A custom emoji is a single `U+FFFC` in the editor `Document`, with its placeholder/alt text on the
        // `EmojiRef`. The chat currency instead carries that alt text AS the run text under the custom-emoji
        // entity (matching `chatInputContent(from:)` / `ComposerDocumentBridge`), so the SENT message's text +
        // entity length are the emoji, not a bare `U+FFFC`. Substitute it when this resolved to a custom emoji.
        // A button run's text stays the bare `U+FFFC` — unlike a custom emoji, whose alt text is
        // substituted, a pill's label lives inside the button and is never document text.
        if run.attributes.button != nil {
            return ChatInputRun(text: "\u{FFFC}", attributes: attributes)
        }
        if case .customEmoji? = attributes.entity, let altText = run.attributes.emoji?.altText, !altText.isEmpty {
            return ChatInputRun(text: altText, attributes: attributes)
        }
        if let formula = run.attributes.formula {
            return ChatInputRun(text: formula, attributes: attributes)
        }
        return ChatInputRun(text: run.text, attributes: attributes)
    }
}

private func chatInputInlineAttributes(
    fromCharacterAttributes attributes: CharacterAttributes,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> ChatInputInlineAttributes {
    // The entity slot is mutually exclusive (one of mention/url/date/customEmoji). Prefer the emoji over a
    // link when a run improbably carries both — matching `ComposerDocumentBridge`, which short-circuits on
    // a custom-emoji run before reading any other attribute.
    var entity: ChatInputInlineEntity?
    if let button = attributes.button {
        entity = .button(chatInputButton(fromButtonRef: button))
    } else if let emoji = attributes.emoji, let resolved = resolveEmoji(emoji) {
        entity = .customEmoji(fileId: resolved.fileId, file: resolved.file, enableAnimation: true)
    } else if let link = attributes.link {
        switch classifyChatLink(link) {
        case let .mention(peerId):
            entity = .mention(peerId)
        case let .date(timestamp):
            entity = .date(timestamp)
        case let .url(url):
            entity = .url(url)
        }
    }
    return ChatInputInlineAttributes(
        bold: attributes.bold,
        italic: attributes.italic,
        monospace: attributes.inlineCode,
        strikethrough: attributes.strikethrough,
        underline: attributes.underline,
        spoiler: attributes.spoiler,
        formula: attributes.formula,
        entity: entity
    )
}

// MARK: - ChatInputContent → Document

/// Convert the chat-layer `ChatInputContent` value model back to an editor `Document`. `registerEmoji` and
/// `registerMedia` hand the chat-layer identity back to the host and return the editor-side ref/key for it.
/// `.blockQuote` is the sole quote path (Task 16b).
public func document(
    fromChatInputContent content: ChatInputContent,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef,
    registerMedia: (Media) -> String
) -> Document {
    var blocks: [Block] = []
    for block in content.blocks {
        blocks.append(contentsOf: documentBlocks(fromChatInputBlock: block, registerEmoji: registerEmoji, registerMedia: registerMedia))
    }
    return Document(blocks: blocks)
}

/// One chat-input block maps to one or more editor blocks.
private func documentBlocks(
    fromChatInputBlock block: ChatInputBlock,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef,
    registerMedia: (Media) -> String
) -> [Block] {
    switch block {
    case let .paragraph(paragraph):
        return [.paragraph(ParagraphBlock(
            id: BlockID.generate(),
            style: paragraphStyle(fromChatInputStyle: paragraph.style),
            list: paragraph.list.map(list(fromChatInputList:)),
            runs: runs(fromChatInputRuns: paragraph.runs, registerEmoji: registerEmoji)
        ))]
    case let .code(code):
        return [.code(CodeBlock(
            id: BlockID.generate(),
            language: code.language,
            runs: runs(fromChatInputRuns: code.runs, registerEmoji: registerEmoji)
        ))]
    case let .pullQuote(pq):
        return [.pullQuote(PullQuote(
            id: BlockID.generate(),
            runs: runs(fromChatInputRuns: pq.runs, registerEmoji: registerEmoji),
            author: runs(fromChatInputRuns: pq.author, registerEmoji: registerEmoji)))]
    case let .media(media):
        return [.media(MediaBlock(
            id: BlockID.generate(),
            items: media.items.map { item in
                MediaItem(
                    mediaID: registerMedia(item.media),
                    kind: mediaKind(fromChatInputKind: item.kind),
                    naturalSize: Size2D(width: item.naturalSize.width, height: item.naturalSize.height),
                    isSpoiler: item.isSpoiler)
            },
            displayWidth: media.displayWidth,
            alignment: mediaAlignment(fromChatInputAlignment: media.alignment),
            displayMode: media.displayMode == .slideshow ? .slideshow : .mosaic,
            caption: runs(fromChatInputRuns: media.caption, registerEmoji: registerEmoji)
        ))]
    case let .table(table):
        return [.table(tableBlock(fromChatInputTable: table, registerEmoji: registerEmoji))]
    case let .blockQuote(bq):
        // Currency .blockQuote → a real editor Block.blockQuote, recursing the inner ChatInputContent
        // back to editor blocks.
        let children = bq.content.blocks.flatMap {
            documentBlocks(fromChatInputBlock: $0, registerEmoji: registerEmoji, registerMedia: registerMedia)
        }
        return [.blockQuote(BlockQuote(id: BlockID.generate(), children: children, collapsed: bq.collapsed,
                                       author: runs(fromChatInputRuns: bq.author, registerEmoji: registerEmoji)))]
    case let .buttonRow(row):
        return [.buttonRow(ButtonRowBlock(
            id: BlockID.generate(),
            buttons: row.buttons.map(buttonRef(fromChatInputButton:)),
            alignment: buttonRowAlignment(from: row.alignment)
        ))]
    case let .details(d):
        // Currency .details → a real editor Block.details, recursing the inner ChatInputContent back to
        // editor blocks. `expanded` maps 1:1.
        let children = d.content.blocks.flatMap {
            documentBlocks(fromChatInputBlock: $0, registerEmoji: registerEmoji, registerMedia: registerMedia)
        }
        return [.details(DetailsBlock(id: BlockID.generate(),
                                      title: runs(fromChatInputRuns: d.title, registerEmoji: registerEmoji),
                                      children: children, expanded: d.expanded))]
    }
}

private func paragraphStyle(fromChatInputStyle style: ChatInputParagraphStyle) -> ParagraphStyleName {
    switch style {
    case .body:
        return .body
    case .heading1:
        return .heading1
    case .heading2:
        return .heading2
    case .heading3:
        return .heading3
    }
}

private func list(fromChatInputList list: ChatInputListMembership) -> ListMembership {
    let marker: ListMarker
    switch list.marker {
    case .bullet:
        marker = .bullet
    case .ordered:
        marker = .ordered
    case .checklist:
        marker = .checklist
    }
    return ListMembership(marker: marker, level: Int(list.level), checked: list.checked)
}

private func mediaKind(fromChatInputKind kind: ChatInputMediaKind) -> MediaKind {
    switch kind {
    case .image:
        return .image
    case .video:
        return .video
    case .location:
        return .location
    case .audio:
        return .audio
    case .document:
        return .document
    }
}

private func mediaAlignment(fromChatInputAlignment alignment: ChatInputMediaAlignment) -> MediaAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    }
}

private func textAlignment(fromChatInputAlignment alignment: ChatInputTextAlignment) -> TextAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    case .justified:
        return .justified
    }
}

private func color(fromChatInputColor color: ChatInputColor) -> RGBAColor {
    return RGBAColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
}

private func verticalAlignment(fromChatInput alignment: ChatInputTableVerticalAlignment) -> VerticalAlignment {
    switch alignment {
    case .top:
        return .top
    case .middle:
        return .middle
    case .bottom:
        return .bottom
    }
}

private func tableBlock(
    fromChatInputTable table: ChatInputTable,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> TableBlock {
    let columns = table.columns.map { column in
        ColumnSpec(width: column.width)
    }
    let rows = table.rows.map { row -> Row in
        let cells = row.cells.map { cell -> Cell in
            // A `ChatInputTableCell` is a flat run list; wrap it back into the editor's expected single
            // body paragraph per cell.
            Cell(
                id: BlockID.generate(),
                blocks: [.paragraph(ParagraphBlock(
                    id: BlockID.generate(),
                    style: .body,
                    runs: runs(fromChatInputRuns: cell.runs, registerEmoji: registerEmoji)
                ))],
                background: cell.background.map(color(fromChatInputColor:)),
                horizontalAlignment: textAlignment(fromChatInputAlignment: cell.horizontalAlignment),
                verticalAlignment: verticalAlignment(fromChatInput: cell.verticalAlignment),
                isHeader: cell.isHeader,
                colspan: cell.colspan,
                rowspan: cell.rowspan
            )
        }
        return Row(id: BlockID.generate(), height: row.height, cells: cells)
    }
    return TableBlock(id: BlockID.generate(), columns: columns, rows: rows, compact: table.compact, bordered: table.bordered)
}

private func runs(
    fromChatInputRuns runs: [ChatInputRun],
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> [TextRun] {
    return runs.map { run in
        var attributes = characterAttributes(fromChatInputInlineAttributes: run.attributes, registerEmoji: registerEmoji)
        // The reverse of the forward `chatInputRuns` substitution: a custom emoji must be a single `U+FFFC`
        // in the editor `Document` (the editor's emoji invariant), with the chat-currency run text preserved
        // as the `EmojiRef.altText` so a later forward pass re-emits it verbatim (and the editor's
        // `insertEmoji` altText round-trips). `registerEmoji` mints the ref with a nil altText; fill it here.
        if case .customEmoji? = run.attributes.entity, var emoji = attributes.emoji {
            emoji.altText = run.text
            attributes.emoji = emoji
            return TextRun(text: "\u{FFFC}", attributes: attributes)
        }
        if attributes.formula != nil || attributes.button != nil {
            return TextRun(text: "\u{FFFC}", attributes: attributes)
        }
        return TextRun(text: run.text, attributes: attributes)
    }
}

private func characterAttributes(
    fromChatInputInlineAttributes attributes: ChatInputInlineAttributes,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> CharacterAttributes {
    var result = CharacterAttributes.plain
    result.bold = attributes.bold
    result.italic = attributes.italic
    result.inlineCode = attributes.monospace
    result.strikethrough = attributes.strikethrough
    result.underline = attributes.underline
    result.spoiler = attributes.spoiler
    result.formula = attributes.formula
    // The entity slot is mutually exclusive — emoji lands in `emoji`, mention/date/url in the shared `link`
    // field as a `tg://` marker (mention/date) or the raw URL, symmetric with the forward classifier.
    if let entity = attributes.entity {
        switch entity {
        case let .customEmoji(fileId, file, _):
            result.emoji = registerEmoji(fileId, file)
        case let .mention(peerId):
            result.link = mentionMarkdownURL(peerId: peerId)
        case let .date(timestamp):
            result.link = dateMarkdownURL(timestamp: timestamp)
        case let .url(url):
            result.link = url
        case let .button(button):
            result.button = buttonRef(fromChatInputButton: button)
        }
    }
    return result
}

/// True when pasted RTF carries a block the legacy input can't render even as text — a TABLE or MEDIA — and
/// should therefore latch the composer to the native editor. Lists, headings, code and quotes are deliberately
/// EXCLUDED: they have a linear text form, so they stay in the legacy field (a list renders its markers as text
/// via `legacyChatInputAttributedString`). Returns false when the data isn't parseable as RTF.
public func rtfRequiresNativeRichInput(_ data: Data) -> Bool {
    guard let document = RTFImport.document(fromRTF: data) else { return false }
    return documentRequiresNativeRichInput(document)
}

/// The block predicate behind `rtfRequiresNativeRichInput`, split out so it can be tested without
/// round-tripping through RTF bytes.
func documentRequiresNativeRichInput(_ document: Document) -> Bool {
    return document.blocks.contains { block in
        switch block {
        case .table, .media, .details, .buttonRow:
            // A button row has no linear text form at all — the legacy field cannot render it even
            // as text, so its presence must latch the composer to the native editor.
            return true
        case .paragraph, .code, .pullQuote, .blockQuote:
            return false
        }
    }
}

/// Legacy-input paste of external RTF that carries a LIST. iOS's own `NSAttributedString(rtf:)` flattens block
/// structure (no `NSTextList`), so `chatInputStateStringFromRTF` drops list markers entirely. This path instead
/// parses the RTF with the structure-preserving `RTFImport`, then renders each list item's marker (•, 1., …) as
/// LITERAL TEXT via `attributedString(from:renderListMarkers:)`, preserving inline formatting. Returns nil when
/// the RTF has no list (or doesn't parse) so the caller keeps its existing inline-preserving conversion.
public func legacyChatInputAttributedString(fromRTF data: Data) -> NSAttributedString? {
    guard let document = RTFImport.document(fromRTF: data) else { return nil }
    let hasList = document.blocks.contains { block in
        if case .paragraph(let paragraph) = block, paragraph.list != nil { return true }
        return false
    }
    guard hasList else { return nil }
    let content = chatInputContent(fromDocument: document, resolveEmoji: { _ in nil }, resolveMedia: { _ in nil })
    // Paste direction: an imported link whose label IS its own URL pastes as plain text (see
    // `chatInputContentStrippingSelfReferentialLinks`), matching the `chatInputStateStringFromRTF` path.
    return attributedString(from: chatInputContentStrippingSelfReferentialLinks(content), renderListMarkers: true)
}
