#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// Recursive reads and replacements over a `Document`, for the rules that act on a block wherever it
/// sits: inside a quote, inside a details, inside either of those inside the other. A table's cells
/// hold paragraphs only, so the walk enters them for lookup but never nests a container there.
extension Block {
    /// The blocks this container holds on the ANCESTRY axis — the children an `EngineAncestor`
    /// encloses — or nil for a block that is not an ancestor container.
    ///
    /// This pairing is what keeps the four walks below from each growing their own list of
    /// container cases: adding the next `EngineAncestor` is these two switches and nothing else.
    /// A table's cells are deliberately NOT here: a cell's role names the TABLE as its container, so
    /// a block inside a cell is never one of the `EngineBlockRole.containerID`s these walks are
    /// handed, and a rule that anchors in a cell must land beside the table rather than in it.
    internal var ancestryChildren: [Block]? {
        switch self {
        case let .blockQuote(quote): return quote.children
        case let .details(details): return details.children
        case .paragraph, .code, .pullQuote, .media, .table, .buttonRow: return nil
        }
    }

    /// `self` holding `children` instead, for the container kinds `ancestryChildren` answers; any
    /// other block is returned unchanged.
    internal func replacingAncestryChildren(_ children: [Block]) -> Block {
        switch self {
        case var .blockQuote(quote): quote.children = children; return .blockQuote(quote)
        case var .details(details): details.children = children; return .details(details)
        case .paragraph, .code, .pullQuote, .media, .table, .buttonRow: return self
        }
    }

    /// This block and every block nested in it, depth first.
    ///
    /// A FOLDED details' children are included, even though none of them is on the engine's axis:
    /// the walk is over the MODEL, and its callers key on ids that come from live roles, so a hidden
    /// child's id is simply never asked for. Reaching them costs nothing and keeps this walk from
    /// having to know about the fold at all.
    internal var descendantsAndSelf: [Block] {
        if let children = ancestryChildren { return [self] + children.flatMap(\.descendantsAndSelf) }
        if case let .table(table) = self {
            return [self] + table.rows.flatMap { $0.cells.flatMap { $0.blocks.flatMap(\.descendantsAndSelf) } }
        }
        return [self]
    }

    /// `self` with the block `id` replaced by `replacement` wherever it sits in a container, or
    /// unchanged.
    internal func replacingBlock(withID id: BlockID, with replacement: Block) -> Block {
        if self.id == id { return replacement }
        guard let children = ancestryChildren else { return self }
        return replacingAncestryChildren(children.map { $0.replacingBlock(withID: id, with: replacement) })
    }

    /// The index range of the sibling run `first...last` in `siblings`, or nil when either is absent
    /// or they are out of order.
    internal static func siblingRange(in siblings: [Block], from first: BlockID, to last: BlockID) -> ClosedRange<Int>? {
        guard let lower = siblings.firstIndex(where: { $0.id == first }),
              let upper = siblings.firstIndex(where: { $0.id == last }), lower <= upper else { return nil }
        return lower...upper
    }

    /// `self` with the sibling run `first...last` replaced wherever it sits in a container, or nil
    /// when this subtree does not hold them as siblings.
    internal func replacingSiblings(from first: BlockID, to last: BlockID, with replacement: [Block]) -> Block? {
        guard var children = ancestryChildren else { return nil }
        if let range = Block.siblingRange(in: children, from: first, to: last) {
            children.replaceSubrange(range, with: replacement)
            return replacingAncestryChildren(children)
        }
        for (index, child) in children.enumerated() {
            if let changed = child.replacingSiblings(from: first, to: last, with: replacement) {
                children[index] = changed
                return replacingAncestryChildren(children)
            }
        }
        return nil
    }

    /// `self` with `insertion` placed directly after the block `id` wherever it sits in a container,
    /// or unchanged.
    internal func insertingBlock(_ insertion: Block, after id: BlockID) -> Block {
        guard var children = ancestryChildren else { return self }
        if let at = children.firstIndex(where: { $0.id == id }) {
            children.insert(insertion, at: at + 1)
            return replacingAncestryChildren(children)
        }
        return replacingAncestryChildren(children.map { $0.insertingBlock(insertion, after: id) })
    }
}

extension Document {
    /// Every block at any depth, by id. The first wins on a duplicate, as `touchedContainers` chose.
    internal var blocksByID: [BlockID: Block] {
        Dictionary(blocks.flatMap(\.descendantsAndSelf).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The document with one block replaced wherever it sits. `schemaVersion` and `layoutDirection`
    /// travel with it: a replacement is not a new document.
    internal func replacingBlock(withID id: BlockID, with replacement: Block) -> Document {
        var updated = self
        updated.blocks = blocks.map { $0.replacingBlock(withID: id, with: replacement) }
        return updated
    }

    /// The document with the sibling run `first...last` replaced by `replacement`, wherever those
    /// two sit — the top level or any container's children. Nil when no single parent holds BOTH as
    /// siblings, which is the honest answer for a range spanning a quote's child and a block outside
    /// it: there is no one container for a command to act in, and the caller refuses.
    ///
    /// `schemaVersion` and `layoutDirection` travel with it, as for a replacement.
    internal func replacingSiblings(from first: BlockID, to last: BlockID, with replacement: [Block]) -> Document? {
        var updated = self
        if let range = Block.siblingRange(in: blocks, from: first, to: last) {
            updated.blocks.replaceSubrange(range, with: replacement)
            return updated
        }
        for (index, block) in blocks.enumerated() {
            if let changed = block.replacingSiblings(from: first, to: last, with: replacement) {
                updated.blocks[index] = changed
                return updated
            }
        }
        return nil
    }

    /// The document with `insertion` placed directly after the block `id` wherever it sits —
    /// appended when `id` names no block at all. `schemaVersion` and `layoutDirection` travel with
    /// it, as for a replacement.
    ///
    /// The top-level case is tried first and separately, then the descent — NOT a top-level-only
    /// lookup: `Block.insertingBlock` can only descend into a container's children, so it would never
    /// place a block beside a top-level one. Every id this is handed is found wherever it lives.
    internal func insertingBlock(_ insertion: Block, after id: BlockID) -> Document {
        var updated = self
        if let at = blocks.firstIndex(where: { $0.id == id }) {
            updated.blocks.insert(insertion, at: at + 1)
        } else if blocksByID[id] != nil {
            updated.blocks = blocks.map { $0.insertingBlock(insertion, after: id) }
        } else {
            updated.blocks.append(insertion)
        }
        return updated
    }
}
#endif
