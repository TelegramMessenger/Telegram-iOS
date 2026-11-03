import Foundation

public extension PositionResolver {
    struct TextPosition: Equatable {
        public let ref: TextNodeRef
        public let offset: Int   // UTF-16 offset within that text node
    }

    /// If `pos` lands inside a `.text` node, returns which model text node and the offset.
    /// Returns nil at structural boundaries (between blocks, before/after atoms).
    static func textPosition(at pos: Int, in root: DocNode) -> TextPosition? {
        // Walk like resolve, but return the text child the position falls within (inclusive of
        // both ends, so a caret at the very start/end of a text node maps into it).
        func walk(_ node: DocNode, _ contentStart: Int) -> TextPosition? {
            var acc = 0
            for child in node.children {
                let childStart = acc
                let childEnd = acc + child.nodeSize
                let offsetInContent = pos - contentStart
                if case .text(_, let ref) = child {
                    if offsetInContent >= childStart && offsetInContent <= childEnd {
                        return TextPosition(ref: ref, offset: offsetInContent - childStart)
                    }
                } else if !child.isLeaf {
                    let childContentStart = contentStart + childStart + 1
                    if pos >= childContentStart - 1 && pos <= childContentStart + childContentSize(child) + 1 {
                        if let found = walk(child, childContentStart) { return found }
                    }
                }
                acc = childEnd
            }
            return nil
        }
        return walk(root, 0)
    }

    /// Inverse: the global position for an offset within a model text node.
    static func globalPosition(of ref: TextNodeRef, offset: Int, in root: DocNode) -> Int? {
        func walk(_ node: DocNode, _ contentStart: Int) -> Int? {
            var acc = 0
            for child in node.children {
                let childStart = acc
                if case .text(_, let r) = child, r == ref {
                    return contentStart + childStart + offset
                } else if !child.isLeaf {
                    if let found = walk(child, contentStart + childStart + 1) { return found }
                }
                acc += child.nodeSize
            }
            return nil
        }
        return walk(root, 0)
    }

    private static func childContentSize(_ node: DocNode) -> Int {
        node.children.reduce(0) { $0 + $1.nodeSize }
    }
}

public extension PositionResolver {
    /// The `[start, end)` token span of the block `id` names, at any depth — the extent
    /// `Document.extractFragment` and `Document.replacingRange` measure a block by.
    ///
    /// Walks OUTERMOST-first and answers the first match, which is what makes it correct for the
    /// blocks whose container and children deliberately share one `BlockID`: a code block is a
    /// container of two paragraphs all carrying `cb.id`, and a media block's atom and caption carry
    /// `img.id`. The container is the block, so the outer node is the span.
    ///
    /// Used for a selection endpoint that landed on a block holding no text (a media atom, a button
    /// row, a collapsed quote), which has no `TextNodeRef` to measure into.
    static func blockSpan(ofBlockWithID id: BlockID, in root: DocNode) -> (start: Int, end: Int)? {
        func walk(_ node: DocNode, _ contentStart: Int) -> (start: Int, end: Int)? {
            var acc = 0
            for child in node.children {
                let childStart = contentStart + acc
                if case .text = child {
                    // A text leaf is never a block.
                } else if blockID(of: child) == id {
                    return (childStart, childStart + child.nodeSize)
                } else if !child.isLeaf, let found = walk(child, childStart + 1) {
                    return found
                }
                acc += child.nodeSize
            }
            return nil
        }
        return walk(root, 0)
    }

    private static func blockID(of node: DocNode) -> BlockID? {
        switch node {
        case .doc, .text: return nil
        case let .paragraph(id, _), let .mediaBlock(id, _), let .mediaAtom(id),
             let .table(id, _), let .row(id, _), let .cell(id, _),
             let .blockQuote(id, _), let .details(id, _):
            return id
        }
    }
}
