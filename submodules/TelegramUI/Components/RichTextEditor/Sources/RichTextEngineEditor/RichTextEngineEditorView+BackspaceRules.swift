#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// What a Backspace rule did — and, the half that has bitten this file twice, whether the consumer
/// has already been told.
@available(iOS 18.4, *)
internal enum BackspaceRuleOutcome {
    /// The rule declined. Ask the next one.
    case notHandled
    /// The rule consumed the keystroke and its own mutation reaches the consumer: an engine edit
    /// fires the change funnel, and a bare caret move is reported by the coalesced selection path.
    case handled
    /// The rule consumed the keystroke and NOTHING will report it — its `document =` set was
    /// swallowed by `isApplyingHostDocument`, or it rewrote roles without an edit at all. The DOOR
    /// owes the consumer a delivery.
    case handledOwingADelivery
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal typealias BackspaceRule =
        (name: StaticString, apply: (RichTextEngineEditorView, Int) -> BackspaceRuleOutcome)

    /// THE ordered Backspace rule table. Both doors walk this array, in this order; neither keeps a
    /// copy of the order or of the rules.
    ///
    /// **Why one array.** UIKit delivers a Backspace at a block's start two ways — as a collapsed
    /// caret there, or as the RANGE covering the join with the block above — and which one a device
    /// chooses is not ours to predict. While the order lived in two hand-written lists they drifted,
    /// three times: the boundary WALL reached the caret door only, so the same keystroke walled
    /// through one door and MERGED a details' first body child into its title through the other; the
    /// details-title rule was asked fifth at the gate and sixth at the caret door; and the dissolve
    /// was gated on the join at the gate but on nothing at the caret door, so a Backspace mid-way
    /// through a pull quote's author line dissolved the quote or deleted a character depending on
    /// the delivery. A rule added to this array is added to both doors; there is nowhere else to put
    /// one.
    ///
    /// **Every rule here fires at the START of the role it is given.** That is the one position with
    /// two deliveries, and it is the only precondition a door needs: `caret == flatOffset(ofRoleAt:
    /// i)` at the caret door is what `rangeIsTheJoinBefore(i, range:)` says at the gate. Each rule
    /// owns whatever ELSE it requires — a role kind, a list membership — so a door cannot forget a
    /// guard and the two cannot spell one differently.
    ///
    /// **Delivery is not here.** A rule returning `.handledOwingADelivery` tells the door it owes the
    /// consumer one; the caret door flushes, and the gate marks `structureTouchedThisEdit` for its
    /// veto path to flush. A delivery written INTO a rule instead lands beside the door's and the
    /// same keystroke notifies twice — measured at 2 on the boundary rule, 2026-09-08.
    internal static let backspaceJoinRules: [BackspaceRule] = [
        // ATOM UNITS first — media atoms and button rows alike: these rules SELECT rather than
        // delete, and must run before anything that might dissolve or merge, because a text-free
        // block has no text for the others to reason about.
        // The first two are mutually exclusive role kinds, so their relative order is immaterial.
        (name: "mediaCaptionSelectsItsAtom", apply: { view, index in
            guard view.currentRoles[index].secondaryKind == .mediaCaption,
                  let atom = view.atomUnitIndex(forRoleAt: index) else { return .notHandled }
            view.selectAtomUnit(at: atom)
            return .handled
        }),
        (name: "beforeAtomUnit", apply: { view, index in
            guard view.atomUnitIndex(forRoleAt: index) == index else { return .notHandled }
            return view.applyBackspaceBeforeAtomUnit(at: index) ? .handled : .notHandled
        }),
        (name: "afterAtomUnit", apply: { view, index in
            view.applyBackspaceAtStartOfBlockAfterAtomUnit(at: index) ? .handled : .notHandled
        }),
        // A TABLE is the other thing you cannot merge into. Backspace at the start of the block after
        // one selects the whole table, like legacy's `selectPrecedingTableOnBackspace` — so it belongs
        // with the rules above, which select rather than delete, and ahead of everything that merges.
        (name: "precedingTableSelects", apply: { view, index in
            view.applySelectPrecedingTableOnBackspace(at: index) ? .handled : .notHandled
        }),
        // DISSOLVE ahead of the rest: it fires only when the whole container is empty, where there is
        // nothing to protect — and an empty code block's caret usually sits in its equally empty
        // language line, so protecting the line first made such a block undeletable. The boundary
        // rule below is for a caret at the edge of a container that still HAS content.
        (name: "dissolveEmptyContainer", apply: { view, index in
            view.applyDissolveOfEmptyContainer(at: index, caret: view.flatOffset(ofRoleAt: index))
                ? .handledOwingADelivery : .notHandled
        }),
        // Ahead of the boundary rule and of the engine's own merge: at the start of a list item
        // Backspace outdents or ends the list rather than dragging its text into the block above.
        // Legacy gives the list branch the same priority.
        (name: "listItem", apply: { view, index in
            view.applyBackspaceAtStartOfListItem(at: index) ? .handled : .notHandled
        }),
        // A quote or pull quote with an AUTHOR is a wall at its first line's start, where the two
        // rules below would unwrap it: unwrapping deleted a block quote's author text and turned a pull
        // quote's author into a body line, from one Backspace on an invisible break (composer harness
        // p21, `HarnessSeparatorBeforeQuoteDeletionTests`). Ahead of both; it only moves the caret.
        (name: "authoredQuoteWall", apply: { view, index in
            view.applyBackspaceAtStartOfAuthoredQuote(at: index) ? .handledOwingADelivery : .notHandled
        }),
        // At the start of a quote's child: un-quote a lone child one level, lift out the first of
        // several, remove an empty first one (nesting design §6.2).
        (name: "quoteChild", apply: { view, index in
            view.applyBackspaceAtStartOfQuoteChild(at: index) ? .handled : .notHandled
        }),
        // At the start of a details' TITLE: unwrap one level, keeping the title as a paragraph
        // (details design §6.2). After the quote-child rule, whose units never include a container's
        // own line.
        (name: "detailsTitle", apply: { view, index in
            view.applyBackspaceAtStartOfDetailsTitle(at: index) ? .handled : .notHandled
        }),
        // At the start of a pull quote's body: unwrap it into body paragraphs in place. After the
        // quote-child rule, which lifts a pull quote that is its quote's first child out whole.
        // Its `document =` set is swallowed, so the door delivers.
        (name: "pullQuoteStart", apply: { view, index in
            view.applyBackspaceAtStartOfPullQuote(at: index) ? .handledOwingADelivery : .notHandled
        }),
        // At the start of a HEADING whose block above is an EMPTY paragraph: the empty paragraph
        // goes and the heading stays. The engine's own merge keeps the UPPER block, so Return at a
        // heading's start (which opens an empty body line above it) followed by Backspace demoted
        // the heading to body. A non-empty paragraph above still takes the heading's text, as
        // before. Returns `.handled`: the edit is an engine edit and reaches the funnel.
        (name: "headingAfterEmptyParagraph", apply: { view, index in
            view.applyBackspaceAtStartOfHeadingAfterEmptyParagraph(at: index) ? .handled : .notHandled
        }),
        // The WALL, last: the block after a container, and a container's own second line, do not
        // merge across. Both of its arms — the wall and the travel — only move the caret, so nothing
        // reports them but the door.
        (name: "regionBoundary", apply: { view, index in
            view.applyBackspaceAtARegionBoundary(at: index) ? .handledOwingADelivery : .notHandled
        }),
    ]

    // MARK: - The two doors

    /// The caret door: `tgid_deleteBackwardHandler`'s first refusal.
    ///
    /// One Backspace is NOT at a role start and therefore not in the table — a caret INSIDE a media
    /// atom, which selects it. That shape has no join counterpart BY CONSTRUCTION, since a join
    /// range ends at a role start, so handling it here is a property of the delivery rather than an
    /// exception carved to make the table fit.
    internal func consumeBackspaceAtACollapsedCaret() -> Bool {
        // A structural table selection is answered FIRST and is not in the rules array: those fire at
        // the start of a ROLE and are chosen by role index, while this one keys on the SELECTION and
        // applies wherever the caret happens to be parked.
        if deleteTableStructuralSelection() { return true }
        if consumeBackspaceInsideAnAtomUnit() { return true }
        let selection = engineSelectedRange
        guard selection.length == 0, let index = roleIndex(atFlatOffset: selection.location),
              selection.location == flatOffset(ofRoleAt: index) else { return false }
        for rule in Self.backspaceJoinRules {
            switch rule.apply(self, index) {
            case .notHandled:
                continue
            case .handled:
                return true
            case .handledOwingADelivery:
                deliverChangeNotificationNow()
                return true
            }
        }
        return false
    }

    /// The gate's door: the same keystroke delivered as the range covering the join before `index`.
    ///
    /// Marking `structureTouchedThisEdit` is this door's spelling of the caret door's flush — the
    /// veto path notifies exactly when structure changed, and a rule whose mutation was swallowed
    /// has to say so or the consumer is never told.
    internal func applyBackspaceJoinRules(at index: Int) -> Bool {
        for rule in Self.backspaceJoinRules {
            switch rule.apply(self, index) {
            case .notHandled:
                continue
            case .handled:
                return true
            case .handledOwingADelivery:
                structureTouchedThisEdit = true
                return true
            }
        }
        return false
    }

    /// `headingAfterEmptyParagraph`: removes the empty paragraph above a heading, keeping the
    /// heading's role and text, and parks the caret at the heading's start. Only between two
    /// standalone paragraphs of the same container, neither a list item, the upper one EMPTY.
    private func applyBackspaceAtStartOfHeadingAfterEmptyParagraph(at index: Int) -> Bool {
        guard index > 0, index < currentRoles.count else { return false }
        let role = currentRoles[index]
        let above = currentRoles[index - 1]
        guard case .standalone(.paragraph) = role.position,
              role.secondaryKind == nil, role.owningTable == nil,
              let paragraph = role.shape.paragraph, paragraph.list == nil,
              Self.backspaceHeadingStyles.contains(paragraph.style),
              case .standalone(.paragraph) = above.position,
              above.secondaryKind == nil, above.owningTable == nil,
              above.shape.paragraph?.list == nil,
              above.ancestry == role.ancestry,
              flatLength(ofRoleAt: index - 1) == 0 else { return false }
        let start = flatOffset(ofRoleAt: index)
        var plan = currentRoles
        plan.remove(at: index - 1)
        // The separator after the empty block is the one character between the two; deleting it
        // joins them, and the plan assigns the survivor the HEADING's role by position.
        performHostStructuralEdit { replaceFlat(NSRange(location: start - 1, length: 1), with: "", adopting: plan) }
        engineSelectedRange = NSRange(location: start - 1, length: 0)
        return true
    }

    private static let backspaceHeadingStyles: Set<ParagraphStyleName> = [.heading1, .heading2, .heading3,
                                                                          .heading4, .heading5, .heading6]

    /// A collapsed caret PAST the start of a media atom selects it — the first of the two steps
    /// §5.2 requires before the atom can be deleted.
    private func consumeBackspaceInsideAnAtomUnit() -> Bool {
        let selection = engineSelectedRange
        guard selection.length == 0, let index = roleIndex(atFlatOffset: selection.location),
              atomUnitIndex(forRoleAt: index) == index,
              selection.location > flatOffset(ofRoleAt: index) else { return false }
        selectAtomUnit(at: index)
        return true
    }
}
#endif
