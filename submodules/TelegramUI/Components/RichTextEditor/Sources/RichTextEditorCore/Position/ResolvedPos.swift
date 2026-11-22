import Foundation

public struct ResolvedPos: Equatable {
    public struct Ancestor: Equatable {
        public let node: DocNode
        /// Global position of the first content position inside `node`.
        public let contentStart: Int
        /// Index of the descended child within `node` (or insertion index for a between-pos).
        public let indexInParent: Int
    }

    public let pos: Int
    /// path[0] is the doc; path[depth] is the immediate parent.
    public let path: [Ancestor]
    /// Token offset of `pos` within the parent's content.
    public let parentOffset: Int

    public var depth: Int { path.count - 1 }
    public var parent: DocNode { path[depth].node }

    /// First content position inside the ancestor at `depth`.
    public func start(_ depth: Int) -> Int { path[depth].contentStart }
    /// Last content position inside the ancestor at `depth`.
    public func end(_ depth: Int) -> Int { path[depth].contentStart + contentSize(of: path[depth].node) }

    /// Position directly before the ancestor node at `depth` (its open-token boundary).
    /// Meaningful for depth ≥ 1; depth 0 is the doc, which has no "before".
    public func before(_ depth: Int) -> Int { path[depth].contentStart - 1 }
    /// Position directly after the ancestor node at `depth`.
    public func after(_ depth: Int) -> Int { end(depth) + 1 }

    /// The child node ending exactly at the resolved boundary, or nil if `pos` is inside a text node.
    public var nodeBefore: DocNode? {
        var acc = 0
        for child in parent.children {
            acc += child.nodeSize
            if acc == parentOffset { return child }
        }
        return nil
    }

    /// The child node starting exactly at the resolved boundary, or nil if `pos` is inside a text node.
    public var nodeAfter: DocNode? {
        var acc = 0
        for child in parent.children {
            if acc == parentOffset { return child }
            acc += child.nodeSize
        }
        return nil
    }

    private func contentSize(of node: DocNode) -> Int { node.children.reduce(0) { $0 + $1.nodeSize } }
}
