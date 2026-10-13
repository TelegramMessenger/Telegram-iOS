import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore

/// Build a chat rich-message `InstantPage` from already-normalized blocks (media blocks resolved via the supplied map).
func buildInstantPage(from blocks: [Block], media: [String: Media]) -> InstantPage {
    var pageBlocks: [InstantPageBlock] = []
    var pageMedia: [MediaId: Media] = [:]
    var index = 0
    while index < blocks.count {
        let block = blocks[index]
        switch block {
        case let .paragraph(paragraph):
            if let latex = paragraph.standaloneFormulaLatex {
                pageBlocks.append(.formula(latex: latex))
                index += 1
            } else if paragraph.list != nil {
                var run: [ParagraphBlock] = []
                while index < blocks.count, case let .paragraph(next) = blocks[index], next.list != nil {
                    run.append(next)
                    index += 1
                }
                pageBlocks.append(contentsOf: buildListBlocks(from: run[...]))
                continue
            } else {
                pageBlocks.append(headingOrParagraphBlock(paragraph))
                index += 1
            }
        case let .table(table):
            pageBlocks.append(tableBlock(table))
            index += 1
        case let .code(code):
            // Code blocks are entity-expressible (.Pre); in the rich (InstantPage) path they render as a
            // preformatted block. Reached only when OTHER content (heading/list/table/media) forced rich layout.
            pageBlocks.append(.preformatted(text: richText(from: code.runs), language: code.language))
            index += 1
        case let .pullQuote(pq):
            pageBlocks.append(.pullQuote(text: richText(from: pq.runs), caption: authorCaption(pq.author, italic: true)))
            index += 1
        case let .media(mediaBlock):
            let caption = InstantPageCaption(text: richText(from: mediaBlock.caption), credit: .empty)
            if mediaBlock.items.count >= 2 {
                // A multi-item media container → one `.collage` block wrapping an `.image`/`.video` per item.
                // The container's own caption becomes the collage's caption; inner items carry no caption
                // (mirrors `ChatInputContentInstantPage`, the composer's already-fixed forward converter).
                var innerBlocks: [InstantPageBlock] = []
                for item in mediaBlock.items {
                    guard let resolved = media[item.mediaID], let mediaId = resolved.id else { continue }
                    pageMedia[mediaId] = resolved // idempotent if the same mediaID appears in multiple blocks
                    switch item.kind {
                    case .image:
                        innerBlocks.append(.image(id: mediaId, caption: InstantPageCaption(text: .empty, credit: .empty), url: nil, webpageId: nil, spoiler: item.isSpoiler))
                    case .video:
                        innerBlocks.append(.video(id: mediaId, caption: InstantPageCaption(text: .empty, credit: .empty), autoplay: false, loop: false, spoiler: item.isSpoiler))
                    case .audio, .location, .document:
                        // Audio/location/document are permanently single-item; never grouped into a collage.
                        continue
                    }
                }
                switch mediaBlock.displayMode {
                case .mosaic:    pageBlocks.append(.collage(items: innerBlocks, caption: caption))
                case .slideshow: pageBlocks.append(.slideshow(items: innerBlocks, caption: caption))
                }
            } else if let resolved = media[mediaBlock.mediaID] {
                switch mediaBlock.kind {
                case .image, .video, .audio, .document:
                    // Media.id is optional on the protocol; real TelegramMedia* image/video/audio/document
                    // always return non-nil.
                    if let mediaId = resolved.id {
                        pageMedia[mediaId] = resolved // idempotent if the same mediaID appears in multiple blocks
                        // The single-item convenience accessors (`mediaBlock.mediaID`/`.kind`) resolve to `items.first`;
                        // read the spoiler flag from the same source item (mirrors ChatInputContentInstantPage's single path).
                        let spoiler = mediaBlock.items.first?.isSpoiler ?? false
                        switch mediaBlock.kind {
                        case .image:
                            pageBlocks.append(.image(id: mediaId, caption: caption, url: nil, webpageId: nil, spoiler: spoiler))
                        case .audio:
                            // music & voice both → `.audio`; the file's `.Audio(isVoice:)` attribute drives the render.
                            pageBlocks.append(.audio(id: mediaId, caption: caption))
                        case .document:
                            // A caption-less block, so `caption` is always .empty here — the field is
                            // carried anyway because the wire block has one.
                            pageBlocks.append(.document(id: mediaId, caption: caption))
                        default:
                            pageBlocks.append(.video(id: mediaId, caption: caption, autoplay: false, loop: false, spoiler: spoiler))
                        }
                    }
                case .location:
                    // A location resolves to a `TelegramMediaMap` (id-less); emit a `.map` block with the coordinates
                    // inline. No `pageMedia` entry (the block carries no MediaId). See ChatInputContentInstantPage.
                    if let map = resolved as? TelegramMediaMap {
                        let dimensions: PixelDimensions
                        if mediaBlock.naturalSize.width > 0, mediaBlock.naturalSize.height > 0 {
                            dimensions = PixelDimensions(width: Int32(mediaBlock.naturalSize.width), height: Int32(mediaBlock.naturalSize.height))
                        } else {
                            dimensions = PixelDimensions(width: 600, height: 300)
                        }
                        pageBlocks.append(.map(latitude: map.latitude, longitude: map.longitude, zoom: 15, dimensions: dimensions, caption: caption))
                    }
                }
            }
            index += 1
        case let .blockQuote(bq):
            // A block quote → a structured InstantPage blockQuote. Recurse the children through the same
            // builder; merge child media into the page-level dict so media inside a quote renders correctly.
            let innerPage = buildInstantPage(from: bq.children, media: media)
            for (id, m) in innerPage.media { pageMedia[id] = m }
            pageBlocks.append(.blockQuote(blocks: innerPage.blocks, caption: authorCaption(bq.author), collapsed: bq.collapsed))
            index += 1
        case let .details(d):
            // A detail (folding) block → an InstantPage `.details`. Recurse children through the same builder;
            // merge child media into the page dict. The title becomes the details title RichText; `expanded`
            // maps straight across (it is the inverse of a block-quote's `collapsed`).
            let innerPage = buildInstantPage(from: d.children, media: media)
            for (id, m) in innerPage.media { pageMedia[id] = m }
            pageBlocks.append(.details(title: richText(from: d.title), blocks: innerPage.blocks, expanded: d.expanded))
            index += 1
        case let .buttonRow(row):
            pageBlocks.append(.buttonRow(
                alignment: instantPageRowAlignment(from: row.alignment),
                buttons: row.buttons.map {
                    InstantPageButton(
                        text: richText(from: $0.label),
                        action: replyMarkupButtonAction(from: $0.action),
                        color: replyMarkupColor(from: $0.color),
                        isLink: $0.isLink
                    )
                }
            ))
            index += 1
        }
    }
    return InstantPage(blocks: pageBlocks, media: pageMedia, isComplete: true, rtl: false, url: "", views: nil)
}

/// Emit a quote author as a bold (and, when `italic` is set — pull quotes only — ALSO italic) InstantPage
/// caption (both are ambient — not in the model — but must render that way on the recipient). Empty author
/// -> `.empty` (byte-identical to the prior output). Mirrors `authorCaptionRichText` in
/// `TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift` (the composer's already-fixed
/// forward converter) using THIS module's `richText(from:)`.
private func authorCaption(_ author: [TextRun], italic: Bool = false) -> RichText {
    richText(from: author.map { var r = $0; r.attributes.bold = true; if italic { r.attributes.italic = true }; return r })
}

/// A non-list, non-quote paragraph → a heading or a paragraph block.
private func headingOrParagraphBlock(_ paragraph: ParagraphBlock) -> InstantPageBlock {
    if let latex = paragraph.standaloneFormulaLatex {
        return .formula(latex: latex)
    }
    let text = richText(from: paragraph.runs)
    switch paragraph.style {
    case .heading1:
        return .heading(text: text, level: 1)
    case .heading2:
        return .heading(text: text, level: 2)
    case .heading3:
        return .heading(text: text, level: 3)
    case .heading4:
        return .heading(text: text, level: 4)
    case .heading5:
        return .heading(text: text, level: 5)
    case .heading6:
        return .heading(text: text, level: 6)
    case .body, .caption:
        return .paragraph(text)
    case .pullQuote:
        // A `Block.paragraph` with `.pullQuote` style is render-only and unreachable here
        // (pull quotes arrive as `Block.pullQuote`, handled by the `buildInstantPage` switch).
        // Map defensively to an InstantPage pull-quote block.
        return .pullQuote(text: text, caption: .empty)
    }
}

/// Recursively build `.list` blocks from a consecutive run of list paragraphs.
/// Items at the same level + marker are siblings; deeper-level runs nest under the preceding item.
private func buildListBlocks(from paragraphs: ArraySlice<ParagraphBlock>) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    var index = paragraphs.startIndex
    while index < paragraphs.endIndex {
        let baseLevel = paragraphs[index].list?.level ?? 0
        let baseMarker = paragraphs[index].list?.marker ?? .bullet
        var items: [InstantPageListItem] = []
        while index < paragraphs.endIndex,
              (paragraphs[index].list?.level ?? 0) == baseLevel,
              (paragraphs[index].list?.marker ?? .bullet) == baseMarker {
            let text = richText(from: paragraphs[index].runs)
            let checked = paragraphs[index].list?.checked
            index += 1
            let childStart = index
            while index < paragraphs.endIndex, (paragraphs[index].list?.level ?? 0) > baseLevel {
                index += 1
            }
            if index > childStart {
                let nested = buildListBlocks(from: paragraphs[childStart ..< index])
                items.append(.blocks([.paragraph(text)] + nested, nil, checked))
            } else {
                items.append(.text(text, nil, checked))
            }
        }
        result.append(.list(items: items, ordered: baseMarker == .ordered))
    }
    return result
}

/// A table block → `.table`, mapping each cell's own per-cell H+V alignment, per-cell header flag, and
/// per-cell colspan/rowspan (editor `Int`, default 1, forwarded as InstantPage `Int32`).
private func tableBlock(_ table: TableBlock) -> InstantPageBlock {
    let rows = table.rows.map { row -> InstantPageTableRow in
        let cells = row.cells.map { cell -> InstantPageTableCell in
            let alignment: TableHorizontalAlignment
            switch cell.horizontalAlignment {
            case .left, .justified, .natural:
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
            return InstantPageTableCell(
                text: cellRichText(cell),
                header: cell.isHeader,
                alignment: alignment,
                verticalAlignment: vAlignment,
                colspan: Int32(cell.colspan),
                rowspan: Int32(cell.rowspan)
            )
        }
        return InstantPageTableRow(cells: cells)
    }
    return .table(title: .empty, rows: rows, bordered: table.bordered, striped: false, compact: table.compact)
}

/// Concatenate a cell's paragraph blocks into one `RichText` (newline-joined). Images in cells dropped.
private func cellRichText(_ cell: Cell) -> RichText {
    let paragraphs = cell.blocks.compactMap { block -> RichText? in
        if case let .paragraph(paragraph) = block {
            return richText(from: paragraph.runs)
        }
        return nil
    }
    if paragraphs.isEmpty {
        return .empty
    }
    if paragraphs.count == 1 {
        return paragraphs[0]
    }
    var joined: [RichText] = []
    for (offset, text) in paragraphs.enumerated() {
        if offset > 0 {
            joined.append(.plain("\n"))
        }
        joined.append(text)
    }
    return .concat(joined)
}
