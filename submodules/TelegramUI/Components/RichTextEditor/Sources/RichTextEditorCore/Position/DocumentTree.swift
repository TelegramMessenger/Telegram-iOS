import Foundation

/// True when a block quote's body has content that keeps its author line visible: any child that is NOT a
/// text-less, list-less paragraph (a blank line). Structural children — tables, sub-quotes, pull quotes,
/// media, code — count even when empty; an empty list item counts (it is structure the user created).
func quoteBodyHasContent(_ children: [Block]) -> Bool {
    children.contains { block in
        if case let .paragraph(p) = block { return p.utf16Count > 0 || p.list != nil }
        return true
    }
}

public enum DocumentTree {
    /// Builds the `.doc` root node for a document.
    public static func build(from document: Document) -> DocNode {
        .doc(children: document.blocks.map(node(for:)))
    }

    private static func node(for block: Block) -> DocNode {
        switch block {
        case .paragraph(let p):
            return .paragraph(id: p.id,
                              children: [.text(length: p.utf16Count, ref: .paragraph(p.id))])
        case .media(let img):
            if img.kind.isCaptionless {
                // Audio and document are caption-less atoms — no caption paragraph node
                // (nodeSize = 1 atom + 2 wrapper = 3).
                return .mediaBlock(id: img.id, children: [.mediaAtom(id: img.id)])
            }
            return .mediaBlock(id: img.id, children: [
                .mediaAtom(id: img.id),
                .paragraph(id: img.id,
                           children: [.text(length: img.captionUTF16Count, ref: .caption(img.id))]),
            ])
        case .table(let t):
            return .table(id: t.id, children: t.rows.map { row in
                .row(id: row.id, children: row.cells.map { cell in
                    .cell(id: cell.id, children: cell.blocks.map(node(for:)))
                })
            })
        case .code(let cb):
            // A code block is a CONTAINER of two paragraph children: the always-present language line and
            // the code text. `.blockQuote` is reused purely as a TOKEN SHAPE (`PositionMapping` /
            // `PositionResolver` are generic over `children`/`nodeSize`/`isLeaf` and special-case only
            // `.text`), exactly as `.pullQuote` reuses it for [text, author]. Canvas-side
            // `isInsideBlockQuote(_:)` tests `box is BlockQuoteBox`, so this does NOT make code positions
            // read as "inside a block quote".
            // The language child is NEVER content-gated — unlike a quote author, which appears only once
            // its quote has content. The field is always visible, so it is always on the axis, and the
            // code text's offset therefore does not shift when a language is added or cleared.
            return .blockQuote(id: cb.id, children: [
                .paragraph(id: cb.id, children: [.text(length: cb.languageUTF16Count, ref: .codeLanguage(cb.id))]),
                .paragraph(id: cb.id, children: [.text(length: cb.utf16Count, ref: .code(cb.id))]),
            ])
        case .pullQuote(let pq):
            // Always a `.blockQuote` container so the pull text stays at nodeStart+1 whether the author is
            // shown or hidden. The trailing author paragraph is present only when the quote has content
            // (author text OR pull text) — else the author region is absent (no tokens, no caret target).
            var children: [DocNode] = [
                .paragraph(id: pq.id, children: [.text(length: pq.utf16Count, ref: .pullQuote(pq.id))]),
            ]
            if pq.authorUTF16Count > 0 || pq.utf16Count > 0 {   // authorUTF16Count>0 mirrors PullQuoteBox.authorLength>0 exactly
                children.append(.paragraph(id: pq.id, children: [.text(length: pq.authorUTF16Count, ref: .quoteAuthor(pq.id))]))
            }
            return .blockQuote(id: pq.id, children: children)
        case .blockQuote(let bq):
            if bq.collapsed {
                // Folded → a caption-less atom, off the editable axis (nodeSize 3), like the old collapsedQuote.
                return .mediaBlock(id: bq.id, children: [.mediaAtom(id: bq.id)])
            }
            // Expanded → recursive container. The trailing author paragraph is present only when the quote
            // has content (author text OR body content — see `quoteBodyHasContent`); else the author region
            // is absent. Children are before the author, so their positions are unaffected either way.
            var children = bq.children.map(node(for:))
            if bq.authorUTF16Count > 0 || quoteBodyHasContent(bq.children) {   // authorUTF16Count>0 mirrors BlockQuoteBox.authorLength>0 exactly
                children.append(.paragraph(id: bq.id, children: [.text(length: bq.authorUTF16Count, ref: .quoteAuthor(bq.id))]))
            }
            return .blockQuote(id: bq.id, children: children)
        case .details(let d):
            // Title is ALWAYS a leading, editable paragraph child (unlike the content-gated block-quote author).
            // Body children are on the editable axis only when expanded; when folded they are preserved in the
            // Block model but OFF the position axis (the title stays a caret target either way).
            var children: [DocNode] = [
                .paragraph(id: d.id, children: [.text(length: d.titleUTF16Count, ref: .detailsTitle(d.id))]),
            ]
            if d.expanded {
                children.append(contentsOf: d.children.map(node(for:)))
            }
            return .details(id: d.id, children: children)
        case .buttonRow(let r):
            // A text-free block. Reuses `.mediaBlock` + `.mediaAtom` exactly as a COLLAPSED block
            // quote already does (see the `bq.collapsed` arm above and `BlockQuoteBox`'s comment):
            // `PositionMapping` / `PositionResolver` are generic over `children`/`nodeSize`/`isLeaf`
            // and special-case only `.text`, so a container of bare atoms needs no new DocNode case.
            // One atom per pill gives the caret a stop per pill; an EMPTY row still gets one atom so
            // it remains selectable and deletable (a zero-child container would have nodeSize 2 with
            // no interior position to place a caret at).
            let atomCount = max(1, r.buttons.count)
            return .mediaBlock(id: r.id, children: Array(repeating: .mediaAtom(id: r.id), count: atomCount))
        }
    }

    /// Maximum valid position (size of the document's content).
    public static func documentSize(_ document: Document) -> Int {
        build(from: document).nodeSize
    }
}
