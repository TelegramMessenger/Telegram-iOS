import Foundation

public enum PositionResolver {
    /// Resolves a global position into its parent node, depth, and offset.
    /// Precondition: 0 ≤ pos ≤ documentSize.
    public static func resolve(_ pos: Int, in root: DocNode) -> ResolvedPos {
        precondition(pos >= 0 && pos <= root.nodeSize, "position out of range")
        var path: [ResolvedPos.Ancestor] = []
        var node = root
        var contentStart = 0   // doc content starts at global 0

        while true {
            let offsetInContent = pos - contentStart
            var acc = 0
            var descended = false

            for (index, child) in node.children.enumerated() {
                let childStart = acc
                let childEnd = acc + child.nodeSize

                if offsetInContent == childStart {
                    // "Between" position in `node` just before this child.
                    path.append(.init(node: node, contentStart: contentStart, indexInParent: index))
                    return ResolvedPos(pos: pos, path: path, parentOffset: offsetInContent)
                }
                if offsetInContent > childStart && offsetInContent < childEnd {
                    if child.isLeaf {
                        // Inside a .text node: parent is `node`, offset indexes into content.
                        path.append(.init(node: node, contentStart: contentStart, indexInParent: index))
                        return ResolvedPos(pos: pos, path: path, parentOffset: offsetInContent)
                    } else {
                        // Descend into a non-leaf child; +1 for its open token.
                        path.append(.init(node: node, contentStart: contentStart, indexInParent: index))
                        node = child
                        contentStart = contentStart + childStart + 1
                        descended = true
                        break
                    }
                }
                acc = childEnd
            }

            if !descended {
                // Position is at the end boundary of `node`'s content.
                path.append(.init(node: node, contentStart: contentStart,
                                  indexInParent: node.children.count))
                return ResolvedPos(pos: pos, path: path, parentOffset: pos - contentStart)
            }
        }
    }
}
