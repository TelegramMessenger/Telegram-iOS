#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// What sits next to a role, in STRUCTURAL terms.
///
/// `currentRoles[i ± 1]` answers what is STORED next to a role. Every navigation rule wants what is
/// next to it in the document's STRUCTURE, and the two differ at exactly one place — a container
/// edge. Six defects across three rungs were that difference, every one found by a person rather
/// than a test, because the omission is valid code that behaves correctly on every shape its author
/// tried.
///
/// **A `switch` over this must never carry a `default`.** The exhaustiveness IS the instrument: a
/// rule that forgets a container edge fails to build instead of misbehaving on one document shape,
/// and a future container kind breaks every call site until each has decided what it means. A
/// `default:` arm gives all of that back.
@available(iOS 18.4, *)
internal enum RoleNeighbour {
    /// Inside my own LEAF container: the next cell of my table, a code block's body after its
    /// language line, an atom's caption.
    case sameLeafContainer(Int)
    /// A different child of the same enclosing container — a real sibling block.
    case sibling(Int)
    /// A line the enclosing container OWNS: a quote's author, a details' title. A field, not
    /// content, and forgetting it is three of the six defects.
    case ownLineOfEnclosingContainer(Int)
    /// My innermost enclosing container ENDS here. `beyond` is the first role outside it, or nil at
    /// the document's edge — the container is reported either way, because a rule minting a sibling
    /// needs to know which container it is minting into.
    case outsideContainer(EngineAncestor, beyond: Int?)
    /// The document ends here AND there is no enclosing container to report. Only a top-level role
    /// reaches this.
    case documentEdge
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal func neighbour(after index: Int) -> RoleNeighbour {
        neighbour(of: index, at: index + 1)
    }

    internal func neighbour(before index: Int) -> RoleNeighbour {
        neighbour(of: index, at: index - 1)
    }

    /// Derived from `currentRoles`, never stored: the indices are valid for one pass and must not be
    /// held across an edit. One step only — a caller crossing two container edges asks again from
    /// `beyond`, deliberately, because no current site needs a walk and a type that did one would be
    /// answering a question nobody asked.
    private func neighbour(of index: Int, at other: Int) -> RoleNeighbour {
        let role = currentRoles[index]
        guard other >= 0, other < currentRoles.count else {
            if let container = role.innermostAncestor { return .outsideContainer(container, beyond: nil) }
            return .documentEdge
        }
        let candidate = currentRoles[other]
        // The LEAF container first: two cells of one table, a code block's language line and its
        // body, an atom and its caption. A top-level paragraph's container is its own block, so two
        // paragraphs never match here and fall through to the ancestor question below.
        if candidate.containerID == role.containerID { return .sameLeafContainer(other) }
        guard let container = role.innermostAncestor else { return .sibling(other) }
        guard candidate.isWithin(container.id) else { return .outsideContainer(container, beyond: other) }
        if candidate.isOwnedLine(of: container.id) { return .ownLineOfEnclosingContainer(other) }
        return .sibling(other)
    }
}
#endif
