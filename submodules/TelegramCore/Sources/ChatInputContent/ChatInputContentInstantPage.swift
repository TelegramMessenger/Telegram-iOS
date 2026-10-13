import Foundation
import Postbox

// A lossless, bidirectional converter between the `ChatInputContent` value model and `InstantPage`.
//
// The invariant guaranteed (and unit-tested in `//submodules/TextFormat:TextFormatTests`):
//
//     chatInputContent(fromInstantPage: instantPage(from: c)) == c   for every `c`.
//
// This is a fresh, separate pair from the lossy `RichTextEditorMessageConversion` converter — do not
// conflate them. The round-trip is identity, so the reverse must invert the forward EXACTLY, in
// particular preserving run boundaries (one top-level `RichText` part ⇄ exactly one run; no merging).
// `.blockQuote` is the sole quote path — the old flat-`.quote` paragraph and `.collapsedQuote` block
// are retired; old persisted drafts degrade via the lenient `ChatInputContent.init(from:)` decoder.

// MARK: - Forward: ChatInputContent -> InstantPage

public func instantPage(from content: ChatInputContent) -> InstantPage {
    // Collect the concrete media referenced by `.media` blocks: the InstantPage carries `Media` out-of-band in its
    // `media: [MediaId: Media]` dict and the image/video block holds only the `MediaId`. The reverse re-resolves the
    // `Media` from this dict, so the round-trip preserves the exact `Media` instance (identity), not a copy.
    var media: [MediaId: Media] = [:]
    let blocks = instantPageBlocks(from: content, collectingMediaInto: &media)
    return InstantPage(blocks: blocks, media: media, isComplete: true, rtl: false, url: "", views: nil)
}

func instantPageBlocks(from content: ChatInputContent, collectingMediaInto media: inout [MediaId: Media]) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    var i = 0
    while i < content.blocks.count {
        switch content.blocks[i] {
        case let .paragraph(p):
            if let latex = standaloneFormulaLatex(from: p) {
                result.append(.formula(latex: latex))
            } else if let list = p.list, case .body = p.style {
                // Coalesce a maximal run of consecutive BODY-styled list paragraphs with the SAME marker into one
                // `.list`. (Adjacent paragraphs with different markers — a bullet list followed by an ordered list —
                // stay separate `.list` blocks.) `InstantPageListItem` has no indent-level field, so the per-paragraph
                // `level` is NOT representable: level 0 round-trips exactly, and level > 0 is CANONICALIZED to 0 (the
                // InstantPage list projection is flat). This mirrors the collapsed-quote/customEmoji canonicalizations.
                //
                // The `case .body = p.style` guard is LOAD-BEARING: it must match the inner `while`'s `.body` check. A
                // non-body paragraph that also carries a list (e.g. a degenerate heading+list — the editor's heading /
                // quote styles and list membership are mutually exclusive in practice) would otherwise enter this
                // branch, fail the inner `while` on its first iteration, never advance `i`, and `continue` past the
                // `i += 1` → an infinite loop / main-thread hang on the draft-save path. With the guard it falls
                // through to the style switch and canonicalizes to its style (the list is dropped) — consistent with
                // quote-before-list precedence above.
                let marker = list.marker
                var items: [InstantPageListItem] = []
                while i < content.blocks.count, case let .paragraph(q) = content.blocks[i], let qList = q.list, qList.marker == marker, case .body = q.style {
                    items.append(.text(richText(from: q.runs), nil, qList.checked))
                    i += 1
                }
                result.append(.list(items: items, ordered: marker == .ordered))
                continue
            } else {
                switch p.style {
                case .heading1:
                    result.append(.heading(text: richText(from: p.runs), level: 1))
                case .heading2:
                    result.append(.heading(text: richText(from: p.runs), level: 2))
                case .heading3:
                    result.append(.heading(text: richText(from: p.runs), level: 3))
                case .body:
                    result.append(.paragraph(richText(from: p.runs)))
                }
            }
        case let .code(c):
            result.append(.preformatted(text: richText(from: c.runs), language: c.language))
        case let .pullQuote(pq):
            result.append(.pullQuote(text: richText(from: pq.runs), caption: authorCaptionRichText(pq.author, italic: true)))
        case let .blockQuote(bq):
            // Recursive structured blockquote: forward the inner content unchanged. `collapsed` maps 1:1.
            result.append(.blockQuote(blocks: instantPageBlocks(from: bq.content, collectingMediaInto: &media),
                                      caption: authorCaptionRichText(bq.author), collapsed: bq.collapsed))
        case let .media(m):
            let caption = InstantPageCaption(text: richText(from: m.caption), credit: .empty)
            if m.items.count >= 2 {
                // Multi-item photo/video container → one .collage block; each inner .image/.video references
                // a MediaId stored in the page media dict. Inner captions are empty (the container caption is
                // on the collage). Items with a nil id or a non-image/video kind are skipped defensively.
                var innerBlocks: [InstantPageBlock] = []
                for item in m.items {
                    guard let mediaId = item.media.id else { continue }
                    media[mediaId] = item.media
                    switch item.kind {
                    case .image:
                        innerBlocks.append(.image(id: mediaId, caption: InstantPageCaption(text: .empty, credit: .empty), url: nil, webpageId: nil, spoiler: item.isSpoiler))
                    case .video:
                        innerBlocks.append(.video(id: mediaId, caption: InstantPageCaption(text: .empty, credit: .empty), autoplay: false, loop: false, spoiler: item.isSpoiler))
                    default:
                        // audio / location are never grouped into a collage (single-item only); skip defensively.
                        continue
                    }
                }
                switch m.displayMode {
                case .mosaic:    result.append(.collage(items: innerBlocks, caption: caption))
                case .slideshow: result.append(.slideshow(items: innerBlocks, caption: caption))
                }
                break
            }
            // Single item: byte-identical to the pre-container output.
            let item = m.items[0]
            switch item.kind {
            case .image, .video, .audio, .document:
                // Stash the Media in the page's `media` dict, keyed by its own MediaId; the block carries only the id.
                // image/video/audio/document are always a concrete TelegramMediaImage/TelegramMediaFile with an id;
                // a nil-id medium is dropped (it could not be resolved back from the dict anyway).
                guard let mediaId = item.media.id else {
                    break
                }
                media[mediaId] = item.media
                switch item.kind {
                case .image:
                    result.append(.image(id: mediaId, caption: caption, url: nil, webpageId: nil, spoiler: item.isSpoiler))
                case .audio:
                    // music & voice both serialize as `.audio`; the file's `.Audio(isVoice:)` attribute (carried on
                    // the stored Media) drives the music-vs-voice render. No size/alignment is representable.
                    result.append(.audio(id: mediaId, caption: caption))
                case .document:
                    // A caption-less block, so `caption` is .empty for editor-authored content; the field is
                    // carried anyway because the wire block has one.
                    result.append(.document(id: mediaId, caption: caption))
                default:
                    result.append(.video(id: mediaId, caption: caption, autoplay: false, loop: false, spoiler: item.isSpoiler))
                }
            case .location:
                // A location is a `TelegramMediaMap` (id-less): the InstantPage `.map` block carries its coordinates
                // inline, so nothing goes in the page `media` dict. zoom/dimensions are render hints (15 / 600x300
                // fallback). venue is not representable here — the caption already carries the venue title.
                if let map = item.media as? TelegramMediaMap {
                    let dimensions: PixelDimensions
                    if item.naturalSize.width > 0, item.naturalSize.height > 0 {
                        dimensions = PixelDimensions(width: Int32(item.naturalSize.width), height: Int32(item.naturalSize.height))
                    } else {
                        dimensions = PixelDimensions(width: 600, height: 300)
                    }
                    result.append(.map(latitude: map.latitude, longitude: map.longitude, zoom: 15, dimensions: dimensions, caption: caption))
                }
            }
        case let .table(t):
            // `naturalSize`/`displayWidth`/`alignment` of media and `width`/cell-background of a table are NOT
            // representable in the InstantPage projection (see the reverse for the documented defaults the
            // round-trip restores). Forward each cell's own per-cell H+V alignment (the editor's `justified` has
            // no InstantPage equivalent → CANONICALIZED to `.left`), per-cell header flag, colspan/rowspan, and
            // runs. `header` is carried PER CELL (not derived from the row), so a partial-header row (some
            // cells header, some not) round-trips exactly. `colspan`/`rowspan` are `Int` (chat currency, default
            // 1) forwarded as `Int32` (InstantPage's `0`/`1` = no span, `>1` = real span).
            let rows = t.rows.map { row -> InstantPageTableRow in
                let cells = row.cells.map { cell -> InstantPageTableCell in
                    let alignment: TableHorizontalAlignment
                    switch cell.horizontalAlignment {
                    case .left, .justified:
                        alignment = .left
                    case .center:
                        alignment = .center
                    case .right:
                        alignment = .right
                    }
                    let vAlignment: TableVerticalAlignment
                    switch cell.verticalAlignment {
                    case .top:
                        vAlignment = .top
                    case .middle:
                        vAlignment = .middle
                    case .bottom:
                        vAlignment = .bottom
                    }
                    return InstantPageTableCell(text: richText(from: cell.runs), header: cell.isHeader, alignment: alignment, verticalAlignment: vAlignment, colspan: Int32(cell.colspan), rowspan: Int32(cell.rowspan))
                }
                return InstantPageTableRow(cells: cells)
            }
            // TODO: `striped` (and `title`) are the last unmodelled `pageBlockTable` fields — a server
            // table with `striped: true` keeps its borders through this round-trip but loses its stripes.
            // Deliberate, not an oversight: modelling them needs an editor affordance too.
            result.append(.table(title: .empty, rows: rows, bordered: t.bordered, striped: false, compact: t.compact))
        case let .details(d):
            // Recursive detail (folding) block → InstantPage `.details`. Forward the title as RichText and the
            // inner content unchanged; `expanded` maps 1:1 (the inverse of a block-quote's `collapsed`).
            result.append(.details(title: richText(from: d.title),
                                   blocks: instantPageBlocks(from: d.content, collectingMediaInto: &media),
                                   expanded: d.expanded))
        case let .buttonRow(row):
            result.append(.buttonRow(
                alignment: row.alignment,
                buttons: row.buttons.map {
                    InstantPageButton(text: richText(from: $0.label), action: $0.action, color: $0.color, isLink: $0.isLink)
                }
            ))
        }
        i += 1
    }
    return result
}

func richText(from runs: [ChatInputRun]) -> RichText {
    if runs.isEmpty {
        return .empty // an empty paragraph round-trips to/from .empty
    }
    let parts = runs.map { run -> RichText in
        var rt: RichText
        // The entity becomes the leaf/innermost (customEmoji is itself the leaf carrying the run text as alt).
        if let formula = run.attributes.formula {
            rt = .formula(latex: formula)
        } else {
            switch run.attributes.entity {
            case let .customEmoji(fileId, _, _):
                rt = .textCustomEmoji(fileId: fileId, alt: run.text)
            case let .mention(peerId):
                rt = .textMentionName(text: .plain(run.text), peerId: peerId.toInt64())
            case let .url(url):
                rt = .url(text: .plain(run.text), url: url, webpageId: nil)
            case let .date(date):
                rt = .textDate(text: .plain(run.text), date: date, format: nil)
            case let .button(button):
                // The carrying run's text is a bare `U+FFFC` and is deliberately NOT emitted — a
                // button's label lives inside the button. The reverse restores the `U+FFFC`.
                rt = .textButton(InstantPageButton(text: richText(from: button.label), action: button.action, color: button.color, isLink: button.isLink))
            case nil:
                rt = .plain(run.text)
            }
        }
        if run.attributes.bold { rt = .bold(rt) }
        if run.attributes.italic { rt = .italic(rt) }
        if run.attributes.monospace { rt = .fixed(rt) }
        if run.attributes.strikethrough { rt = .strikethrough(rt) }
        if run.attributes.underline { rt = .underline(rt) }
        if run.attributes.spoiler { rt = .textSpoiler(text: rt) }
        return rt
    }
    return parts.count == 1 ? parts[0] : .concat(parts)
}

/// Force bold (and, when `italic` is set — pull quotes only — italic too) on each author run for the
/// emitted InstantPage caption (both are ambient — not in the model — but must render that way on the
/// recipient). Empty stays empty (→ `.empty`, no bold/italic wrapper).
private func authorCaptionRichText(_ author: [ChatInputRun], italic: Bool = false) -> RichText {
    richText(from: author.map { var r = $0; r.attributes.bold = true; if italic { r.attributes.italic = true }; return r })
}
/// Strip the ambient bold (and, when `italic` is set, the ambient italic) from a decoded quote caption so
/// `author` matches the model (bold/italic-free).
private func authorRuns(fromCaption rt: RichText, italic: Bool = false) -> [ChatInputRun] {
    chatInputRuns(fromRichText: rt).map { var r = $0; r.attributes.bold = false; if italic { r.attributes.italic = false }; return r }
}

// MARK: - Reverse: InstantPage -> ChatInputContent

public func chatInputContent(fromInstantPage page: InstantPage) -> ChatInputContent {
    return ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: page.blocks, media: page.media))
}

/// Recover a media block's natural size (aspect) from the resolved `Media`. The InstantPage image/video block
/// carries no size field, so the dimensions live only on the `Media` itself — an image's largest representation
/// (`.last`, the convention), or a video/image file's `.Video`/`.ImageSize` attribute (`TelegramMediaFile.dimensions`).
/// This mirrors the size the editor derives at insertion (`RichTextAttachmentScreen`), so a
/// `Document → InstantPage → Document` round-trip preserves the aspect instead of collapsing to the editor's 16:9
/// fallback (`MediaBlockBox.imageDisplaySize`). Falls back to `.zero` when the media carries no dimensions.
private func chatInputNaturalSize(fromMedia media: Media) -> ChatInputSize {
    let dimensions: PixelDimensions?
    if let image = media as? TelegramMediaImage {
        dimensions = image.representations.last?.dimensions
    } else if let file = media as? TelegramMediaFile {
        dimensions = file.dimensions
    } else {
        dimensions = nil
    }
    guard let dimensions else {
        return ChatInputSize(width: 0.0, height: 0.0)
    }
    return ChatInputSize(width: Double(dimensions.width), height: Double(dimensions.height))
}

/// Shared by the `.collage` (mosaic) and `.slideshow` reverse arms: resolve each inner `.image`/`.video` block's
/// `Media` from the page dict and recover its `naturalSize`/`isSpoiler`, exactly as the single-item `.image`/`.video`
/// arms do. The two container kinds differ ONLY in the resulting `ChatInputMedia.displayMode` (set by the caller),
/// not in how their inner items are resolved.
private func chatInputMediaItems(fromInnerBlocks innerBlocks: [InstantPageBlock], media: [MediaId: Media]) -> [ChatInputMediaItem] {
    var items: [ChatInputMediaItem] = []
    for inner in innerBlocks {
        switch inner {
        case let .image(id, _, _, _, spoiler):
            if let m = media[id] {
                items.append(ChatInputMediaItem(media: m, kind: .image, naturalSize: chatInputNaturalSize(fromMedia: m), isSpoiler: spoiler))
            }
        case let .video(id, _, _, _, spoiler):
            if let m = media[id] {
                items.append(ChatInputMediaItem(media: m, kind: .video, naturalSize: chatInputNaturalSize(fromMedia: m), isSpoiler: spoiler))
            }
        default:
            break   // collage/slideshow only ever carry image/video from the forward
        }
    }
    return items
}

/// Flattens InstantPage list items into `ChatInputContent` list paragraphs, recursing into `.blocks` items (a
/// list item carrying continuation paragraphs and/or a nested sub-list) and preserving indent depth via the
/// paragraph's `ChatInputListMembership.level`. Without the recursion a nested sub-list (carried as an item's
/// `.blocks` payload — what the markdown parser emits) would be dropped entirely.
private func appendChatInputListParagraphs(_ items: [InstantPageListItem], ordered: Bool, level: Int32, media: [MediaId: Media], into result: inout [ChatInputBlock]) {
    func marker(_ checked: Bool?) -> ChatInputListMarker {
        return checked != nil ? .checklist : (ordered ? .ordered : .bullet)
    }
    for item in items {
        switch item {
        case let .text(rt, _, checked):
            result.append(.paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker(checked), level: level, checked: checked), runs: chatInputRuns(fromRichText: rt))))
        case let .blocks(blocks, _, checked):
            var isFirstParagraph = true
            for inner in blocks {
                switch inner {
                case let .paragraph(rt):
                    let paragraphChecked = isFirstParagraph ? checked : nil
                    result.append(.paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker(paragraphChecked), level: level, checked: paragraphChecked), runs: chatInputRuns(fromRichText: rt))))
                    isFirstParagraph = false
                case let .list(subItems, subOrdered):
                    appendChatInputListParagraphs(subItems, ordered: subOrdered, level: level + 1, media: media, into: &result)
                default:
                    // A non-paragraph, non-list block inside a list item (e.g. a nested quote/code — rare from
                    // markdown). Flatten via the general mapper so its content is not lost.
                    result.append(contentsOf: chatInputBlocks(fromInstantPageBlocks: [inner], media: media))
                }
            }
        case .unknown:
            break
        }
    }
}

func chatInputBlocks(fromInstantPageBlocks blocks: [InstantPageBlock], media: [MediaId: Media] = [:]) -> [ChatInputBlock] {
    var result: [ChatInputBlock] = []
    for block in blocks {
        switch block {
        case let .paragraph(rt):
            result.append(.paragraph(ChatInputParagraph(style: .body, runs: chatInputRuns(fromRichText: rt))))
        case let .heading(rt, level):
            // Clamp an out-of-range heading level into the editor's 1...3 band; the forward only emits 1/2/3, but a
            // cloud-received heading may carry any level (InstantPage's default is 3 — see the decoder's `orElse: 3`).
            let style: ChatInputParagraphStyle
            switch max(1, min(3, level)) {
            case 1: style = .heading1
            case 2: style = .heading2
            default: style = .heading3
            }
            result.append(.paragraph(ChatInputParagraph(style: style, runs: chatInputRuns(fromRichText: rt))))
        case let .list(items, ordered):
            // One body list paragraph per item. `.text` items are a single paragraph; a `.blocks` item — which
            // the markdown parser produces for a list item that carries continuation paragraphs and/or a NESTED
            // sub-list — is flattened recursively (its own paragraph(s) at this level, a nested `.list` one level
            // deeper), preserving indent via `ChatInputListMembership.level`. A non-nil `checked` selects the
            // `.checklist` marker (the forward threads `checked` from `ChatInputListMembership`); otherwise
            // `.ordered` / `.bullet` per the `ordered` flag. (Skipping `.blocks` used to silently drop a whole
            // nested sub-list on paste.)
            appendChatInputListParagraphs(items, ordered: ordered, level: 0, media: media, into: &result)
        case let .preformatted(rt, language):
            result.append(.code(ChatInputCode(language: language, runs: chatInputRuns(fromRichText: rt))))
        case let .pullQuote(rt, caption):
            result.append(.pullQuote(ChatInputPullQuote(runs: chatInputRuns(fromRichText: rt),
                                                        author: authorRuns(fromCaption: caption, italic: true))))
        case let .blockQuote(innerBlocks, caption, collapsed):
            // Recursive structured blockquote: map back to `ChatInputBlock.blockQuote` with the same `collapsed`
            // flag. Nil (cloud-received wire, no collapsed field) is treated as `false` (visible, non-collapsed).
            // This is the symmetric inverse of the forward `.blockQuote(bq)` arm. Old flat-`.quote` paragraphs
            // and `.collapsedQuote` blocks are no longer produced by the forward (Task 16b removed them).
            result.append(.blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: innerBlocks, media: media)),
                collapsed: collapsed == true,
                author: authorRuns(fromCaption: caption))))
        case let .details(title, innerBlocks, expanded):
            // Recursive detail (folding) block → `ChatInputBlock.details`. Symmetric inverse of the forward
            // `.details` arm; `expanded` maps 1:1 (the inverse of a block-quote's `collapsed`).
            result.append(.details(ChatInputDetails(
                content: ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: innerBlocks, media: media)),
                title: chatInputRuns(fromRichText: title),
                expanded: expanded)))
        case let .formula(latex):
            var attributes = ChatInputInlineAttributes()
            attributes.formula = latex
            result.append(.paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: latex, attributes: attributes)
            ])))
        case let .image(id, caption, _, _, spoiler):
            // Resolve the concrete `Media` from the page's `media` dict; a missing entry (the forward always stores it,
            // so this is defensive against a malformed page) drops the block. The InstantPage image block carries no
            // size, so `naturalSize` is recovered from the `Media` itself (`chatInputNaturalSize(fromMedia:)`) — the
            // dimensions the editor also derives at insertion, so the aspect survives the round-trip. `displayWidth`
            // (a user resize) and `alignment` are genuinely not representable, so they canonicalize to `nil` / `.center`
            // (the editor's `ChatInputMedia` default; a documented limitation, pinned by the media tests). `spoiler`
            // threads through onto the item's `isSpoiler`.
            if let media = media[id] {
                let item = ChatInputMediaItem(media: media, kind: .image, naturalSize: chatInputNaturalSize(fromMedia: media), isSpoiler: spoiler)
                result.append(.media(ChatInputMedia(items: [item], displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .video(id, caption, _, _, spoiler):
            // Same as `.image` (see above): `naturalSize` recovered from the file's `.Video`/`.ImageSize` dimensions,
            // `displayWidth`/`alignment` canonicalized to the defaults, `spoiler` threads through onto `isSpoiler`.
            if let media = media[id] {
                let item = ChatInputMediaItem(media: media, kind: .video, naturalSize: chatInputNaturalSize(fromMedia: media), isSpoiler: spoiler)
                result.append(.media(ChatInputMedia(items: [item], displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .collage(innerBlocks, caption):
            // Rebuild a multi-item container. Each inner .image/.video resolves its Media from the page dict;
            // naturalSize is recovered from the resolved Media (as for single .image/.video). displayWidth /
            // alignment canonicalize to nil / .center (not representable — same as the single case). `.collage`
            // is the mosaic-mode wire representation (see `.slideshow` below for the slideshow-mode twin).
            let items = chatInputMediaItems(fromInnerBlocks: innerBlocks, media: media)
            if !items.isEmpty {
                result.append(.media(ChatInputMedia(items: items, displayWidth: nil, alignment: .center,
                                                    displayMode: .mosaic,
                                                    caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .slideshow(innerBlocks, caption):
            // Mirror of `.collage` above — the ONLY difference is `displayMode: .slideshow`. Shares the inner
            // .image/.video → [ChatInputMediaItem] resolution via `chatInputMediaItems(fromInnerBlocks:media:)`.
            let items = chatInputMediaItems(fromInnerBlocks: innerBlocks, media: media)
            if !items.isEmpty {
                result.append(.media(ChatInputMedia(items: items, displayWidth: nil, alignment: .center,
                                                    displayMode: .slideshow,
                                                    caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .audio(id, caption):
            // Resolve the concrete `TelegramMediaFile` from the page `media` dict (the forward always stores it).
            // naturalSize/displayWidth/alignment restore the editor's media defaults, matching .image/.video.
            // Music vs voice is intrinsic to the file (`.Audio(isVoice:)`), so a single `.audio` kind suffices.
            if let media = media[id] {
                result.append(.media(ChatInputMedia(media: media, kind: .audio, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .document(id, caption):
            // Mirror of `.audio`: resolve the concrete `TelegramMediaFile` from the page `media` dict (the
            // forward always stores it). naturalSize/displayWidth/alignment restore the editor's media
            // defaults; the caption rides the chat currency even though the editor renders none (a document
            // is caption-less on screen — `MediaBlockBox` drops it at that boundary).
            if let media = media[id] {
                result.append(.media(ChatInputMedia(media: media, kind: .document, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .map(latitude, longitude, _, _, caption):
            // Reconstruct a `TelegramMediaMap` from the inline coordinates (no media-dict lookup — a `.map` block
            // stores none). zoom/dimensions are render-only and dropped; venue is not in the block (the caption
            // carried the title forward). naturalSize/displayWidth/alignment restore the editor's media defaults,
            // matching the .image/.video canonicalization above.
            let map = TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, venue: nil)
            result.append(.media(ChatInputMedia(media: map, kind: .location, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
        case let .table(_, rows, bordered, _, compact):
            // Rebuild the `ChatInputTable`. Columns are inferred from the widest row's SPANNED cell count (each
            // cell occupies `max(1, colspan)` grid columns, so a colspanning first cell no longer under-counts
            // — a plain, no-span table still infers from the raw cell count, matching the prior behavior); column
            // `width` is NOT representable in InstantPage cells → restored as the DEFAULT `0.0`. The table
            // `title` and cell `background` are likewise not in the editor model → dropped/fixed (title unused;
            // background `nil`). Per-cell H+V alignment, per-cell `header`, AND per-cell `colspan`/`rowspan` DO
            // round-trip (restored onto each `ChatInputTableCell` below — no row-level derivation). `colspan`/
            // `rowspan` are InstantPage `Int32` (`0`/`1` = no span) normalized back to the chat currency's `Int`
            // (default 1): a span `> 1` is preserved, anything else canonicalizes to `1`. Identity therefore
            // holds for a table whose columns use width `0.0` and whose cells use `background: nil` (the values
            // the reverse yields).
            let columnCount = rows.map { row in row.cells.reduce(0) { $0 + max(1, Int($1.colspan)) } }.max() ?? 0
            let columns: [ChatInputColumnSpec] = Array(repeating: ChatInputColumnSpec(width: 0.0), count: columnCount)
            let outRows = rows.map { row -> ChatInputTableRow in
                let cells = row.cells.map { cell -> ChatInputTableCell in
                    let alignment: ChatInputTextAlignment
                    switch cell.alignment {
                    case .left: alignment = .left
                    case .center: alignment = .center
                    case .right: alignment = .right
                    }
                    let vAlignment: ChatInputTableVerticalAlignment
                    switch cell.verticalAlignment {
                    case .top: vAlignment = .top
                    case .middle: vAlignment = .middle
                    case .bottom: vAlignment = .bottom
                    }
                    return ChatInputTableCell(runs: chatInputRuns(fromRichText: cell.text ?? .empty), background: nil, horizontalAlignment: alignment, verticalAlignment: vAlignment, isHeader: cell.header, colspan: cell.colspan > 1 ? Int(cell.colspan) : 1, rowspan: cell.rowspan > 1 ? Int(cell.rowspan) : 1)
                }
                return ChatInputTableRow(height: nil, cells: cells)
            }
            result.append(.table(ChatInputTable(columns: columns, rows: outRows, compact: compact, bordered: bordered)))
        case let .buttonRow(alignment, buttons):
            result.append(.buttonRow(ChatInputButtonRow(
                buttons: buttons.map {
                    ChatInputButton(label: chatInputRuns(fromRichText: $0.text), action: $0.action, color: $0.color, isLink: $0.isLink)
                },
                alignment: alignment
            )))
        default:
            break // Non-text InstantPage blocks have no ChatInputContent representation (drafts never carry them).
        }
    }
    return result
}

/// Top-level: split a paragraph's RichText into one run per concat part (no merging); `.empty` -> `[]` runs.
func chatInputRuns(fromRichText rt: RichText) -> [ChatInputRun] {
    switch rt {
    case .empty:
        return []
    case let .concat(parts):
        return parts.flatMap { chatInputRuns(fromRichText: $0) } // parts are never .concat from forward; flatMap is defensive
    default:
        return [chatInputRun(fromSinglePart: rt, attributes: ChatInputInlineAttributes())]
    }
}

/// Unwrap a wrapper chain into one run, accumulating attributes; leaves are `.plain` / `.textCustomEmoji`.
func chatInputRun(fromSinglePart rt: RichText, attributes: ChatInputInlineAttributes) -> ChatInputRun {
    var attributes = attributes
    switch rt {
    case let .plain(s):
        return ChatInputRun(text: s, attributes: attributes)
    case let .formula(latex):
        attributes.formula = latex
        return ChatInputRun(text: latex, attributes: attributes)
    case let .textCustomEmoji(fileId, alt):
        // `enableAnimation` is canonicalized to `true` (and `file` to nil): `RichText.textCustomEmoji` carries
        // neither. This MATCHES the production `.textEntities` draft path — `MessageTextEntityType.CustomEmoji` has
        // no animation field either, so a draft already loses `enableAnimation` on save and re-derives it (default
        // `true`) at decoration. So the round-trip is identity over the persisted fidelity, canonicalizing this
        // render-time flag. (Pinned by `test_customEmoji_enableAnimationFalse`.)
        attributes.entity = .customEmoji(fileId: fileId, file: nil, enableAnimation: true)
        return ChatInputRun(text: alt, attributes: attributes)
    case let .bold(inner):
        attributes.bold = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .italic(inner):
        attributes.italic = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .fixed(inner):
        attributes.monospace = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .strikethrough(inner):
        attributes.strikethrough = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .underline(inner):
        attributes.underline = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textSpoiler(inner):
        attributes.spoiler = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textMentionName(inner, peerId):
        attributes.entity = .mention(EnginePeer.Id(peerId))
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .url(inner, url, _):
        attributes.entity = .url(url)
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textDate(inner, date, _):
        attributes.entity = .date(date)
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case .empty:
        return ChatInputRun(text: "", attributes: attributes)
    case let .textButton(button):
        // A button is an atom: its run text is a bare `U+FFFC`, mirroring the custom-emoji and formula
        // invariants. The label lives INSIDE the button, not in the run — falling through to the
        // `default:` below would flatten the pill to its label text and destroy the button.
        attributes.entity = .button(ChatInputButton(label: chatInputRuns(fromRichText: button.text), action: button.action, color: button.color, isLink: button.isLink))
        return ChatInputRun(text: "\u{FFFC}", attributes: attributes)
    default:
        // Defensive for wire-only RichText cases that the forward never produces.
        return ChatInputRun(text: rt.plainText, attributes: attributes)
    }
}

private func standaloneFormulaLatex(from paragraph: ChatInputParagraph) -> String? {
    guard paragraph.style == .body, paragraph.list == nil, paragraph.runs.count == 1 else {
        return nil
    }
    guard let latex = paragraph.runs[0].attributes.formula, !latex.isEmpty else {
        return nil
    }
    return latex
}
