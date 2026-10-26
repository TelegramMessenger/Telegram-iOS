import Foundation

/// Read-only positionable tree derived from a `Document`. `.doc` is the root.
public indirect enum DocNode: Equatable {
    case doc(children: [DocNode])
    case paragraph(id: BlockID, children: [DocNode])      // children: exactly one .text
    case text(length: Int, ref: TextNodeRef)              // inline content (UTF-16 length)
    case mediaBlock(id: BlockID, children: [DocNode])     // [.mediaAtom, caption paragraph]
    case mediaAtom(id: BlockID)                           // leaf atom
    case table(id: BlockID, children: [DocNode])          // children: rows
    case row(id: BlockID, children: [DocNode])            // children: cells
    case cell(id: BlockID, children: [DocNode])           // children: cell blocks
    case blockQuote(id: BlockID, children: [DocNode])     // recursive container (Σchildren + 2)
    case details(id: BlockID, children: [DocNode])        // recursive container (Σchildren + 2)

    public var children: [DocNode] {
        switch self {
        case .doc(let c), .paragraph(_, let c), .mediaBlock(_, let c),
             .table(_, let c), .row(_, let c), .cell(_, let c),
             .blockQuote(_, let c), .details(_, let c):
            return c
        case .text, .mediaAtom:
            return []
        }
    }

    public var isLeaf: Bool {
        switch self {
        case .text, .mediaAtom: return true
        default: return false
        }
    }

    /// Size in position tokens.
    public var nodeSize: Int {
        switch self {
        case .text(let length, _): return length
        case .mediaAtom: return 1
        case .doc(let c): return c.reduce(0) { $0 + $1.nodeSize }        // doc: no +2
        case .paragraph(_, let c), .mediaBlock(_, let c), .table(_, let c),
             .row(_, let c), .cell(_, let c), .blockQuote(_, let c), .details(_, let c):
            return c.reduce(0) { $0 + $1.nodeSize } + 2
        }
    }
}
