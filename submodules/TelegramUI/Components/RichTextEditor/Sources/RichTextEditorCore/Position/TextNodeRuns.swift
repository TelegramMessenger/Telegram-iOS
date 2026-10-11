import Foundation

public extension Document {
    /// The model runs of the text node `ref` names, at any depth — the inverse of the lookup
    /// `DocumentTree.build(from:)` performs when it stamps a `TextNodeRef` onto each `.text` leaf.
    ///
    /// Every case maps onto a stored `[TextRun]` except `.codeLanguage`, which the model holds as a
    /// plain `String?`; it answers a single unattributed run, so a caller can walk any region the
    /// same way. Its `utf16Count` sum equals the `length` `DocumentTree` gives that leaf, which is
    /// what makes the two safe to use together — a walk keyed on this and a position keyed on the
    /// tree cannot disagree about how long a region is.
    ///
    /// `nil` means no such text node: a ref naming a block that is gone, a `.caption` on a
    /// caption-less kind, or a `.quoteAuthor` on a quote whose author region the tree does not emit.
    /// That is deliberately distinct from `[]`, an empty region that DOES exist.
    func runs(for ref: TextNodeRef) -> [TextRun]? {
        func walk(_ blocks: [Block]) -> [TextRun]? {
            for block in blocks {
                switch block {
                case let .paragraph(p):
                    if case .paragraph(p.id) = ref { return p.runs }
                case let .media(m):
                    if case .caption(m.id) = ref, !m.kind.isCaptionless { return m.caption }
                case let .code(c):
                    if case .code(c.id) = ref { return c.runs }
                    // The language is block metadata rather than runs; a single plain run gives it
                    // the same shape as every other region without inventing attributes for it.
                    if case .codeLanguage(c.id) = ref {
                        let language = c.language ?? ""
                        return language.isEmpty ? [] : [TextRun(text: language)]
                    }
                case let .pullQuote(pq):
                    if case .pullQuote(pq.id) = ref { return pq.runs }
                    if case .quoteAuthor(pq.id) = ref { return pq.author }
                case let .blockQuote(bq):
                    if case .quoteAuthor(bq.id) = ref { return bq.author }
                    // A COLLAPSED quote's children are off the position axis entirely — the tree
                    // emits a bare atom for it — so they must not be searched, or a ref would
                    // resolve to a region `PositionMapping` cannot give a position for.
                    if !bq.collapsed, let found = walk(bq.children) { return found }
                case let .details(d):
                    if case .detailsTitle(d.id) = ref { return d.title }
                    // Likewise a FOLDED details: `foldedChildren` holds the body off the axis.
                    if d.expanded, let found = walk(d.children) { return found }
                case let .table(t):
                    for row in t.rows {
                        for cell in row.cells {
                            if let found = walk(cell.blocks) { return found }
                        }
                    }
                case .buttonRow:
                    continue
                }
            }
            return nil
        }
        return walk(blocks)
    }
}
