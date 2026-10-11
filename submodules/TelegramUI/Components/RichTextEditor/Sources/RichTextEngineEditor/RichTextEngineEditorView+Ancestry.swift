#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// Reads over the roles' ancestries (nesting design §3.3): the span an ancestor owns, the ancestry a
/// block outside it has, and the one spelling of a fresh paragraph at a depth.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The contiguous roles around `index` that are within the ancestor `id` — a quote's children,
    /// its nested containers and its author line together. `index` must itself be within `id`.
    /// Two runs of one id separated by another block are two spans, as the regroup treats them.
    internal func span(of id: BlockID, around index: Int) -> ClosedRange<Int> {
        var lower = index, upper = index
        while lower > 0, currentRoles[lower - 1].isWithin(id) { lower -= 1 }
        while upper + 1 < currentRoles.count, currentRoles[upper + 1].isWithin(id) { upper += 1 }
        return lower...upper
    }

    /// Every ancestor container's FIRST contiguous run of roles, in one walk — for each id, exactly
    /// what `span(of: id, around: i)` answers for any `i` inside that run. For a pass that asks about
    /// every container in the document: asked per container, each `span(of:around:)` re-tests every
    /// role's whole ancestry, which made a settle O(roles × depth²) in deeply nested quotes
    /// (`HarnessNestedQuoteKeystrokeScalingTests`). Two same-id containers separated by a block are
    /// two runs; only the first is recorded, so a caller asking about a role outside it must fall
    /// back to `span(of:around:)`.
    internal func ancestorFirstRunSpans() -> [BlockID: ClosedRange<Int>] {
        var spans: [BlockID: ClosedRange<Int>] = [:]
        var closed: Set<BlockID> = []
        for (index, role) in currentRoles.enumerated() {
            for ancestor in role.ancestry {
                let id = ancestor.id
                if let run = spans[id] {
                    guard !closed.contains(id) else { continue }
                    if run.upperBound == index - 1 { spans[id] = run.lowerBound...index } else { closed.insert(id) }
                } else {
                    spans[id] = index...index
                }
            }
        }
        return spans
    }

    /// The ancestry a block OUTSIDE the ancestor `id` has: everything above it. "After quote Q"
    /// means "with Q's parent ancestry", never top level (§6).
    internal func parentAncestry(of id: BlockID, at index: Int) -> [EngineAncestor] {
        Array(currentRoles[index].ancestry.prefix { $0.id != id })
    }

    /// The one spelling of "a fresh body paragraph at this depth". Every rule that mints one uses
    /// this, so a fresh block cannot come out declared differently depending on which rule minted it.
    internal func freshBodyRole(within ancestry: [EngineAncestor]) -> EngineBlockRole {
        .standalone(.paragraph(ParagraphShape(id: BlockID(UUID().uuidString))), within: ancestry)
    }

    /// The DIRECT children of quote `id` over its span, each as the roles it occupies: a paragraph or a
    /// leaf container (a code block and its language line, an atom and its caption, a table's cells) at
    /// the quote's child depth, or a nested quote as ONE unit. The quote's own author line is not a child.
    ///
    /// The Return and Backspace exits count CHILDREN, not roles: a nested quote or a code block is one
    /// child made of several roles, and counting roles made "the first of several" and "the lone child"
    /// answer differently at depth than they do at the top level.
    /// Whether the role at `index` is a line the container `id` OWNS — its author, its title —
    /// rather than part of a child.
    ///
    /// Keyed on `containerID`, never on the kind: a CHILD's own second line (a code block's language,
    /// whose container is the code block) belongs inside its child's unit, not to the container
    /// around it. This is the one spelling; `childUnits` skips these and `contents` collects them, so
    /// the two cannot disagree about what a child is.
    internal func roleIsOwnedLine(_ index: Int, of id: BlockID) -> Bool {
        currentRoles[index].isOwnedLine(of: id)
    }

    /// Whether the role at `index` is a line owned by one of the containers in `enclosing` — a
    /// quote's author line, when the thing you just walked past is that quote's last child.
    ///
    /// Such a line is the enclosing container's own FIELD and not somewhere to put a caret, and it is
    /// exactly the role that follows a container sitting last inside another. `moveCaretToCell(before:)`
    /// fell into the same trap for a quoted table.
    internal func roleIsOwnedLineOfAnEnclosingContainer(_ index: Int, enclosing: [EngineAncestor]) -> Bool {
        guard currentRoles[index].secondaryKind != nil else { return false }
        return enclosing.contains { $0.id == currentRoles[index].containerID }
    }

    /// The LAST role in `span` that is nobody's second line — where a container's text ends.
    ///
    /// Named because "the last primary" and "the span's last role" are different roles whenever the
    /// container owns a trailing line, and because reaching for the FIRST primary instead is a
    /// documented device defect: a quote opening with a table has a CELL as its first primary, the
    /// far side of the whole grid from where a removed author line's text belonged.
    internal func lastPrimaryRole(in span: ClosedRange<Int>) -> Int? {
        span.last { currentRoles[$0].secondaryKind == nil }
    }

    internal func childUnits(of id: BlockID, span: ClosedRange<Int>) -> [ChildUnit] {
        guard let level = currentRoles[span.lowerBound].ancestry.firstIndex(where: { $0.id == id }) else { return [] }
        let childDepth = level + 1
        var units: [ChildUnit] = []
        var index = span.lowerBound
        while index <= span.upperBound {
            let role = currentRoles[index]
            // The container's OWN lines are not children: a quote's author, a details' title.
            if roleIsOwnedLine(index, of: id) { index += 1; continue }
            var end = index
            if role.containerDepth > childDepth {
                let nested = role.ancestry[childDepth].id
                while end + 1 <= span.upperBound, currentRoles[end + 1].isWithin(nested) { end += 1 }
                units.append(.container(index...end))
            } else {
                while end + 1 <= span.upperBound, currentRoles[end + 1].containerDepth == childDepth,
                      currentRoles[end + 1].containerID == role.containerID { end += 1 }
                // A run of ONE role whose container is the block itself is a bare paragraph; anything
                // else — a code block and its language, an atom and its caption — is a container.
                units.append(index == end && role.containerID == role.blockID && role.secondaryKind == nil
                             ? .paragraph(index) : .container(index...end))
            }
            index = end + 1
        }
        return units
    }

    /// What a container holds, as CHILDREN — the only spelling.
    ///
    /// A rule that filters a span by `secondaryKind == nil` and treats each survivor as a child is
    /// asking about ROLES, and that is the single cause of four defects found on device in the
    /// R7-nesting rung: an empty code block counted as an empty child; a quote judged covered because
    /// its only child's atom was; a caret landing on the span's first primary, which was a table
    /// CELL; and a quote's author line taken for the block after a table.
    internal func contents(of id: BlockID, around index: Int) -> ContainerContents {
        contents(of: id, span: span(of: id, around: index))
    }

    /// The same, over a span the caller already has — a pass that judges every quote in the
    /// document (`authorLinePresenceThatIsWrong`) computes all their spans in one walk.
    internal func contents(of id: BlockID, span: ClosedRange<Int>) -> ContainerContents {
        let units = childUnits(of: id, span: span)
        let ownedLines = span.filter { roleIsOwnedLine($0, of: id) }
        let isEmpty = !units.isEmpty && units.allSatisfy { unit in
            guard case let .paragraph(role) = unit else { return false }
            let candidate = currentRoles[role]
            return candidate.owningTable == nil
                && candidate.shape.paragraph != nil
                && candidate.innermostAncestor?.id == id
                && flatLength(ofRoleAt: role) == 0
        }
        // A CHILD is content. So is a details' own TITLE — authored text (details decision 5), and
        // for a FOLDED details it is all there is on the engine's axis, its body living in the shape.
        // A quote's AUTHOR line is not: an attribution is metadata about a container rather than
        // content in it, which is why legacy un-quotes over one without asking.
        let holdsContent = !units.isEmpty
            || ownedLines.contains { currentRoles[$0].secondaryKind == .detailsTitle }
        let ownedLinesAreEmpty = !ownedLines.contains {
            currentRoles[$0].secondaryKind == .detailsTitle && flatLength(ofRoleAt: $0) > 0
        }
        return ContainerContents(containerID: id, span: span, units: units, ownedLines: ownedLines,
                                 isEmpty: isEmpty, holdsContent: holdsContent,
                                 ownedLinesAreEmpty: ownedLinesAreEmpty)
    }

    /// Quote `id` dissolves one level (nesting design §8.1 step 3, legacy's `unwrapBlockQuoteLevel`):
    /// everything within it loses the quote from its ancestry, and its author line goes. One structural
    /// change; the caret stays on the text it was on, or lands on the first lifted block if it was in
    /// the author line. Framed for the caret door; inside the gate or a command the frames pass through.
    ///
    /// `caretLanding` is where the caret should end up, for a caller that KNOWS it. The Backspace
    /// rules pass it and must: `engineSelectedRange` is a collapsed caret at one door and the join
    /// RANGE at the other, so reading the location out of it lands the caret a position apart
    /// depending on which delivery UIKit chose — the same keystroke leaving the caret at the start
    /// of the unwrapped title through one door and at the end of the block above through the other.
    /// The two COMMANDS pass nil and keep reading the live selection, which is what they mean.
    internal func unwrapContainer(_ id: BlockID, around index: Int, caretLanding: Int? = nil) {
        let span = span(of: id, around: index)
        let caret = caretLanding ?? engineSelectedRange.location
        let parent = { (role: EngineBlockRole) in role.within(role.ancestry.filter { $0.id != id }) }
        var plan = Array(currentRoles[..<span.lowerBound])
        var authorLine: Int?
        for owned in span {
            let role = currentRoles[owned]
            // The container's OWN lines, and the ONE place the two kinds part (details decision 5):
            // a quote's AUTHOR goes with the quote — an attribution is metadata about a container
            // that no longer exists — while a details' TITLE survives as an ordinary paragraph in
            // the parent, because it is the heading the user typed. Only those two kinds can be an
            // ancestor container's own line; a leaf's second line belongs to its own child unit.
            if roleIsOwnedLine(owned, of: id) {
                if role.secondaryKind == .detailsTitle {
                    plan.append(freshBodyRole(within: parent(role).ancestry))
                } else {
                    authorLine = owned
                }
                continue
            }
            plan.append(parent(role))
        }
        plan.append(contentsOf: currentRoles[(span.upperBound + 1)...])
        // The caret is set INSIDE the frame: `deliveringOneChangeNotification` marks the notification
        // owed before the body, so a caret restore inside it joins that one delivery instead of
        // scheduling a second a run-loop turn later.
        if let line = authorLine {
            let range = flatRange(ofRoleAt: line)
            // Defensive only: the author line is always the LAST role in its span (never the
            // first), so `range.location` reaching 0 here would mean a quote span whose only role
            // is its author line — which the bridge never produces (an empty quote always gets a
            // rescue child, see `EngineDocumentBridge.flatten`). Guarded anyway rather than trust
            // that invariant at a `- 1` subtraction.
            guard range.location > 0 else { return }
            let landing = caret >= range.location - 1 ? flatOffset(ofRoleAt: span.lowerBound) : caret
            performHostStructuralEdit {
                replaceFlat(NSRange(location: range.location - 1, length: range.length + 1), with: "", adopting: plan)
                engineSelectedRange = NSRange(location: landing, length: 0)
            }
        } else {
            performHostStructuralChange {
                adoptRolePlan(plan)
                engineSelectedRange = NSRange(location: caret, length: 0)
            }
        }
    }

    /// The longest common prefix of two ancestries, by id — where a survivor between two cut
    /// edges belongs (§6.3).
    internal static func commonAncestry(_ a: [EngineAncestor], _ b: [EngineAncestor]) -> [EngineAncestor] {
        var result: [EngineAncestor] = []
        for (x, y) in zip(a, b) {
            guard x.id == y.id else { break }
            result.append(x)
        }
        return result
    }
}

/// One DIRECT child of a container: a bare paragraph, or a container child spanning several roles.
internal enum ChildUnit: Equatable {
    case paragraph(Int)
    case container(ClosedRange<Int>)

    var span: ClosedRange<Int> {
        switch self {
        case let .paragraph(index): return index...index
        case let .container(span): return span
        }
    }
    var lowerBound: Int { span.lowerBound }
    var upperBound: Int { span.upperBound }
    var count: Int { span.count }
    func contains(_ index: Int) -> Bool { span.contains(index) }
}

/// The children of one container, with the questions rules actually ask.
internal struct ContainerContents {
    let containerID: BlockID
    let span: ClosedRange<Int>
    let units: [ChildUnit]
    /// The roles the CONTAINER ITSELF owns, in span order, and never children: a details' TITLE above
    /// its body, a quote's AUTHOR line below its children.
    ///
    /// This is the field whose absence was the bug class. `units` holds children only, so a rule
    /// reaching for "the span's first role" got a details' title and "the span's last role" got a
    /// quote's author line, and each read as a child. Ask `firstChildRole` / `lastChildRole` for a
    /// child and `leadingOwnedLine` / `trailingOwnedLine` for a line the container owns; a rule that
    /// indexes `span` directly is asking about ROLES and is how this went wrong six times.
    let ownedLines: [Int]
    /// Every child a bare EMPTY paragraph that is a DIRECT child. A container child is structure, not
    /// a blank line; and an empty NESTED container presents as one empty paragraph role too, which is
    /// why the direct-child test is part of this and not a caller's afterthought.
    let isEmpty: Bool
    /// Whether the container still holds anything a user would lose — see `contents(of:around:)`,
    /// which is the one place the answer is spelled.
    let holdsContent: Bool
    /// Whether the container's OWN lines hold nothing a user would lose.
    let ownedLinesAreEmpty: Bool

    var first: ChildUnit? { units.first }
    var last: ChildUnit? { units.last }
    func unit(containing index: Int) -> ChildUnit? { units.first { $0.contains(index) } }
    func position(of index: Int) -> Int? { units.firstIndex { $0.contains(index) } }

    /// The first / last role belonging to a CHILD — NOT `span.lowerBound` / `span.upperBound`, which
    /// are a details' title and a quote's author line respectively.
    var firstChildRole: Int? { units.first?.lowerBound }
    var lastChildRole: Int? { units.last?.upperBound }

    /// The container's own line ABOVE every child (a details' title), and the one BELOW every child
    /// (a quote's author). A container with no children at all has its single owned line reported as
    /// both, which is true of a folded details: its title is the whole of its span.
    var leadingOwnedLine: Int? {
        guard let line = ownedLines.first else { return nil }
        guard let child = firstChildRole else { return line }
        return line < child ? line : nil
    }
    var trailingOwnedLine: Int? {
        guard let line = ownedLines.last else { return nil }
        guard let child = lastChildRole else { return line }
        return line > child ? line : nil
    }
}

#endif
