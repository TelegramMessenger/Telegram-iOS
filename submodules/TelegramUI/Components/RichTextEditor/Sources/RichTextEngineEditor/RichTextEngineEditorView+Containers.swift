#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// R7 slice 3 — the Format-menu commands that CREATE a container.
///
/// Semantics are the legacy editor's (`DocumentCanvasView+ParagraphFormat`) deliberately and exactly:
/// both composers drive the same Format menu, so a user switching editors must not get different
/// results from the same menu item. Toggle ON joins every touched block into ONE container separated
/// by "\n"; toggle OFF splits it back on "\n"; a selection covering a block with no text
/// representation is REFUSED.
///
/// **The refusal runs before the edit, not inside it** — also legacy's rule. Deciding inside would
/// register an undo step for an edit that then does nothing, so the user's next undo would appear to
/// do nothing too.
///
/// **The code/pull-quote asymmetry is intentional and is the thing a shared helper erases**: a code
/// block flattens to PLAIN text (formatting inside a fence would be sent as literal markup), while a
/// pull quote PRESERVES runs. So the two commands share the block-range and rebuild machinery below
/// but supply their own gather and split.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    public func makeCodeBlock() {
        applyContainerCommand(
            isAlreadyTheContainer: { if case .code = $0 { return true }; return false },
            gather: { block in
                // PLAIN text, and nil for anything without one — as CODE holds it (`runsPlainText`):
                // an inline atom is its text, a custom emoji its alt text, not its attachment
                // character. `.text` left a custom emoji as a bare `U+FFFC` in the code, sent as a
                // literal character (composer harness p16, `HarnessAtomFlatteningTests`).
                switch block {
                case let .paragraph(paragraph): return [TextRun(text: runsPlainText(paragraph.runs))]
                case let .code(code): return [TextRun(text: code.text)]
                case let .pullQuote(quote): return [TextRun(text: runsPlainText(quote.runs))]
                case .media, .table, .blockQuote, .details, .buttonRow: return nil
                }
            },
            build: { runs in
                .code(CodeBlock(id: BlockID(UUID().uuidString), language: nil,
                                runs: [TextRun(text: runs.map(\.text).joined())]))
            },
            split: { block in
                guard case let .code(code) = block else { return nil }
                return code.text.components(separatedBy: "\n").map { line in
                    .paragraph(ParagraphBlock(id: BlockID(UUID().uuidString), style: .body,
                                              runs: line.isEmpty ? [] : [TextRun(text: line)]))
                }
            })
    }

    public func makePullQuote() {
        applyContainerCommand(
            isAlreadyTheContainer: { if case .pullQuote = $0 { return true }; return false },
            gather: { block in
                // RUNS, so bold/italic/link survive — the documented difference from code.
                switch block {
                case let .paragraph(paragraph): return paragraph.runs
                case let .pullQuote(quote): return quote.runs
                // A code block is refused rather than absorbed: its text is plain by definition, and
                // flattening it into a quote would silently drop its codeness.
                case .code, .media, .table, .blockQuote, .details, .buttonRow: return nil
                }
            },
            build: { runs in .pullQuote(PullQuote(id: BlockID(UUID().uuidString), runs: runs)) },
            split: { block in
                guard case let .pullQuote(quote) = block else { return nil }
                return Self.runsSplitByNewline(quote.runs).map { runs in
                    .paragraph(ParagraphBlock(id: BlockID(UUID().uuidString), style: .body, runs: runs))
                }
            })
    }

    /// The Quote command toggles (nesting design §8.1). If every touched block shares one deepest
    /// enclosing quote, that quote is dissolved one level (`unwrapQuote`); otherwise the touched
    /// TOP-LEVEL units — a quote's whole span, a leaf container's span — become the children of one
    /// new quote, so a selection across a quote and a neighbour nests the quote. Refused when either
    /// endpoint sits in a table cell (legacy's rule). A wrap is a model rebuild through the document
    /// setter, as it was; an unwrap is the same routine Backspace uses.
    public func wrapInBlockQuote() {
        let touched = touchedBlockIndices(for: engineSelectedRange)
        guard let first = touched.first, let last = touched.last else { return }
        guard currentRoles[first].owningTable == nil, currentRoles[last].owningTable == nil else { return }
        let common = touched.dropFirst().reduce(currentRoles[first].ancestry) { Self.commonAncestry($0, currentRoles[$1].ancestry) }
        // The innermost QUOTE the touched blocks share, skipping any container nested inside it.
        // `common.last?.quote` is the `ancestry.last?.quote` shape §3.3 exists to eliminate, and it
        // survived here: inside a quoted details it read nil, fell into the WRAP branch below and
        // nested the enclosing quote in a new one — so there was no way to un-quote from inside a
        // details at all.
        if let quote = common.last(where: { $0.quote != nil })?.quote {
            deliveringOneChangeNotification { unwrapContainer(quote.id, around: first) }
            return
        }
        // Captured BEFORE the rebuild: a wrap changes STRUCTURE and no text, so the engine's own undo
        // has nothing to replay it from — see `recordUndoStepForStructuralChange`.
        let documentBeforeTheWrap = document
        let selectionBeforeTheWrap = engineSelectedRange
        let lower = topLevelUnit(containing: first).lowerBound
        let upper = topLevelUnit(containing: last).upperBound
        // The top-level BLOCK each end belongs to: its outermost ancestor, else its own container.
        func topLevelID(_ index: Int) -> BlockID { currentRoles[index].ancestry.first?.id ?? currentRoles[index].containerID }
        // A DELIBERATE top-level lookup, unlike the one this file's `applyContainerCommand` used to
        // do: the wrap acts on whole TOP-LEVEL units by spec §8.1 (a selection across a quote and its
        // neighbour nests the quote), so `topLevelID` has already lifted each end to its outermost
        // ancestor and these ids are top level by construction. A miss here is a real inconsistency,
        // not a caret sitting deeper than the lookup can see.
        var blocks = document.blocks
        guard let from = blocks.firstIndex(where: { $0.id == topLevelID(lower) }),
              let to = blocks.firstIndex(where: { $0.id == topLevelID(upper) }), from <= to else { return }
        let firstChildID = blocks[from].id
        let quote = BlockQuote(id: BlockID(UUID().uuidString), children: Array(blocks[from...to]))
        blocks.replaceSubrange(from...to, with: [.blockQuote(quote)])
        // Marked owed BEFORE the set (like every other `deliveringOneChangeNotification` frame),
        // not delivered after it (`deliverChangeNotificationNow()`): the document setter's own edit
        // is swallowed by its `isApplyingHostDocument` guard and schedules nothing, but the caret
        // restore below is a REAL selection set once the setter has returned, and reaches
        // `engineDidChangeSelection` like any other caret move. Left to schedule its own delivery it
        // fires a SECOND `onChange` a run-loop turn behind this one.
        deliveringOneChangeNotification {
            document = Document(blocks: blocks)
            // Caret at the start of the first wrapped block's primary region, resolved from the
            // rebuilt roles (a wrapped code block's language line now precedes its body). The
            // primary lookup misses when the first wrapped TOP-LEVEL unit is itself a quote — a
            // quote is never a role's `blockID` (it lives in `ancestry`), and its only role whose
            // `containerID` is the quote is its author line, excluded by `secondaryKind == nil` —
            // so the fallback finds any role now WITHIN the new outer quote instead (its own first
            // child, at any depth).
            if let caret = currentRoles.firstIndex(where: { $0.blockID == firstChildID || ($0.containerID == firstChildID && $0.secondaryKind == nil) })
                ?? currentRoles.firstIndex(where: { $0.isWithin(quote.id) }) {
                engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: caret), length: 0)
            }
            recordUndoStepForStructuralChange(restoring: documentBeforeTheWrap, selection: selectionBeforeTheWrap)
        }
    }

    /// The whole top-level unit the role at `index` belongs to: the span of its outermost ancestor,
    /// else its leaf container's span.
    private func topLevelUnit(containing index: Int) -> ClosedRange<Int> {
        if let outermost = currentRoles[index].ancestry.first { return span(of: outermost.id, around: index) }
        return containerSpan(containing: index)
    }

    /// "None" in the article host: the caret's innermost quote dissolves one level (§8.2). A no-op at
    /// depth 0.
    public func unwrapBlockQuoteLevel() {
        // The innermost QUOTE, not the innermost container: fed `innermostAncestor`, choosing
        // "None" with the caret in a details' body un-detailed the block.
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location),
              let quote = currentRoles[index].innermostEnclosingQuote else { return }
        deliveringOneChangeNotification { unwrapContainer(quote.id, around: index) }
    }

    /// Whether a container command may act over these blocks — every one must have a text
    /// representation. Gates `makeCodeBlock` and `makePullQuote` only: `wrapInBlockQuote` does not
    /// flatten its contents to text (see its own doc comment above), so it never consults this.
    /// `internal static` so the refusal is testable on its own: the documents that exercise it
    /// contain blocks the bridge still traps on, so they cannot be SET on an editor, and a test that
    /// could only reach this through `document =` could not cover the case at all.
    internal static func containerCommandIsAllowed(over blocks: [Block]) -> Bool {
        blocks.allSatisfy { block in
            switch block {
            case .paragraph, .code, .pullQuote: return true
            case .media, .table, .blockQuote, .details, .buttonRow: return false
            }
        }
    }

    /// The shape both commands share: resolve the touched range, decide toggle direction, rebuild the
    /// document, and put the caret where legacy puts it.
    private func applyContainerCommand(
        isAlreadyTheContainer: (Block) -> Bool,
        gather: (Block) -> [TextRun]?,
        build: ([TextRun]) -> Block,
        split: (Block) -> [Block]?
    ) {
        // In CONTAINER space, not engine space. A container can own several engine blocks — a code
        // block and its language line — and a command acts on the whole thing: gathering the engine
        // blocks would fold the language line in as a paragraph and splitting would leave it behind.
        guard let containers = touchedContainers(for: engineSelectedRange),
              let firstContainer = containers.first, let lastContainer = containers.last else {
            return
        }
        // Captured BEFORE the rebuild, for the same reason `wrapInBlockQuote` captures it: a container
        // command rebuilds through the document setter, whose edit `isApplyingHostDocument` swallows,
        // so settle never runs and no replay snapshot is registered. See
        // `recordUndoStepForStructuralChange`.
        let documentBeforeTheCommand = document
        let selectionBeforeTheCommand = engineSelectedRange

        let replacement: [Block]
        if containers.count == 1, isAlreadyTheContainer(firstContainer),
           let restored = split(firstContainer) {
            replacement = restored
        } else {
            // Refused BEFORE any mutation — see this file's header.
            guard Self.containerCommandIsAllowed(over: containers) else { return }
            var joined: [TextRun] = []
            for (position, container) in containers.enumerated() {
                if position > 0 { joined.append(TextRun(text: "\n")) }
                joined.append(contentsOf: gather(container) ?? [])
            }
            replacement = [build(joined)]
        }

        // Spliced where the containers actually LIVE — the top level or any quote's children.
        // Resolved in the top-level list, as it was, a container inside a quote matched nothing and
        // the command returned before mutating: Format ▸ Code and Format ▸ Pull quote were dead menu
        // items anywhere inside a quote, silently, and in exactly the state this rung makes common.
        //
        // Nil means no single parent holds both endpoints as siblings — a range across a quote's
        // boundary — and that is a refusal, not a fallback: there is no one container to act in.
        guard let updated = document.replacingSiblings(from: firstContainer.id, to: lastContainer.id,
                                                       with: replacement) else { return }
        // Roles are rebuilt from scratch here rather than mapped: these commands change the block
        // COUNT, so there is no position-for-position correspondence to preserve.
        // Caret at the START of what was produced, which is where legacy leaves a toggle-off and is
        // the only position that is meaningful for both directions: a toggle-on's "end of the new
        // container" has no counterpart when the result is several paragraphs.
        let produced = replacement.first?.id
        document = updated
        // Resolved AFTER the document is applied, from the rebuilt roles: a produced code block gains
        // a language line, which occupies flat space ahead of its code, and no offset computed over
        // the model's blocks can know that.
        if let produced, let caret = flatOffsetOfPrimaryRegion(ofContainerWithID: produced) {
            engineSelectedRange = NSRange(location: caret, length: 0)
        }
        recordUndoStepForStructuralChange(restoring: documentBeforeTheCommand, selection: selectionBeforeTheCommand)
        deliverChangeNotificationNow()
    }

    /// The distinct CONTAINERS a flat range touches, in order, each once — expanded so that touching
    /// any of a container's engine blocks selects the whole container.
    internal func touchedContainers(for range: NSRange) -> [Block]? {
        let touched = touchedBlockIndices(for: range)
        guard var first = touched.first, var last = touched.last else { return nil }
        while first > 0,
              currentRoles[first - 1].containerID == currentRoles[first].containerID { first -= 1 }
        while last + 1 < currentRoles.count,
              currentRoles[last + 1].containerID == currentRoles[last].containerID { last += 1 }

        // Materialised from the engine: a role is structure only and holds no text to read. By id at
        // ANY depth: a quote's child, and a container nested inside a quote, are containers of their
        // own — looked up in `document.blocks` alone they resolved to NOTHING, so a command over a
        // quote child and a top-level paragraph silently acted on the paragraph alone.
        let live = document.blocksByID
        var containers: [Block] = []
        for index in first...last where containers.last?.id != currentRoles[index].containerID {
            if let block = live[currentRoles[index].containerID] { containers.append(block) }
        }
        return containers
    }

    /// Where a container's PRIMARY region starts, in flat coordinates, per the current roles.
    internal func flatOffsetOfPrimaryRegion(ofContainerWithID id: BlockID) -> Int? {
        currentRoles.firstIndex { $0.containerID == id && $0.secondaryKind == nil }.map { flatOffset(ofRoleAt: $0) }
    }

    /// Backspace inside an EMPTY container dissolves it into a plain paragraph — the legacy editor's
    /// rule (`uncodeEmptyCodeBlock`), and the other half of making a container deletable.
    ///
    /// The funnel's "an emptied container reverts" rule cannot cover this one: nothing emptied the
    /// block. `makeCodeBlock` created it empty to type into, which is legacy's behaviour and worth
    /// keeping, so the container arrives already empty and the engine — with no text to delete and, as
    /// the first block, nothing to merge into — correctly does nothing and reports no change. With a
    /// preceding paragraph the engine merges it away and the funnel rule finishes the job; it is
    /// specifically the FIRST-block case that was stuck, verified both ways by test.
    ///
    /// Returns true when it consumed the keystroke.
    /// Makes a structural change undoable, as ONE step back to before the edit that provoked it.
    ///
    /// **It no longer CLEARS the history, and that was the whole of its old cost.** While the stack
    /// held UIKit's text operations, a change applied out of band through the `document` setter left
    /// entries describing text that no longer existed — undo after a Return inside a pull quote
    /// spliced the AUTHOR into the body, wearing the author's font — so every entry had to be thrown
    /// away and replaced by one that restored the whole pre-edit document. Every table insert, quote
    /// wrap and paste paid for that with the user's entire history.
    ///
    /// A snapshot has no such problem: it restores a `Document`, and the setter derives the roles
    /// from it. So this is now an ordinary step among others, and the history before it survives.
    internal func recordUndoStepForStructuralChange(restoring document: Document,
                                                 selection: NSRange) {
        recordUndoStepForCommand(restoring: EngineUndoSnapshot(document: document,
                                                               selection: selection))
    }

    /// A container whose author line's PRESENCE no longer matches what it holds: which container,
    /// which kind of line, the roles it owns, and the ancestry its line carries (a block quote's line
    /// sits inside the quote, a pull quote's beside its body).
    internal struct AuthorLinePresence {
        let owner: EngineContainerShape
        let kind: SecondaryRegionKind
        let span: ClosedRange<Int>
        let ancestry: [EngineAncestor]
    }

    /// `shouldShowAuthor` is decided when the document is rendered, but what it depends on — whether
    /// anything is quoted — changes by EDITING, and a quote now survives being emptied. Each quote in
    /// any ancestry and each pull quote is checked once, over the roles within it (§7.2).
    internal func authorLinePresenceThatIsWrong() -> AuthorLinePresence? {
        var seen: Set<BlockID> = []
        // Every quote's span in ONE walk (`ancestorFirstRunSpans`), not one `span(of:around:)` per
        // quote: that walk re-tested every role's whole ancestry, the depth-squared half of the cost.
        let quoteSpans = ancestorFirstRunSpans()
        for (index, role) in currentRoles.enumerated() {
            // `seen` is asked BEFORE a candidate is built, because building one walks the quote's
            // whole span. Built first and filtered after, every role paid that walk for every quote
            // enclosing it — O(roles × depth × span) per settle — and a keystroke in 150 quoted
            // paragraphs nested 16 deep cost 4-6x the same paragraphs two deep; the fuzz's 64-deep
            // self-pasted document took seconds per keystroke (composer harness, 2026-09-23, seed 51,
            // `HarnessNestedQuoteKeystrokeScalingTests`). Each quote is now judged once, from the
            // first role inside it.
            var candidates: [AuthorLinePresence] = []
            for (level, ancestor) in role.ancestry.enumerated() {
                guard case let .blockQuote(quote) = ancestor, seen.insert(quote.id).inserted else { continue }
                candidates.append(AuthorLinePresence(owner: .blockQuote(quote), kind: .blockQuoteAuthor,
                                                     span: quoteSpans[quote.id] ?? span(of: quote.id, around: index),
                                                     ancestry: Array(role.ancestry.prefix(level + 1))))
            }
            if case .block(.pullQuote) = role.container, seen.insert(role.container.id).inserted {
                candidates.append(AuthorLinePresence(owner: role.container, kind: .pullQuoteAuthor,
                                                     span: containerSpan(containing: index), ancestry: role.ancestry))
            }
            for candidate in candidates {
                let lines = candidate.span.filter {
                    currentRoles[$0].isOwnedLine(candidate.kind, of: candidate.owner.id)
                }
                let hasLine = !lines.isEmpty
                let authored = lines.contains { flatLength(ofRoleAt: $0) > 0 }
                // A block quote holds CHILDREN, so what it holds is a child and not text. The only
                // block that may be internally empty is a body paragraph; a table, a code block, a
                // media atom, a nested quote are structure the user put there and are never
                // "nothing", however empty their own text is. `ContainerContents.isEmpty` is where
                // that rule lives — reading text lengths here was a second and narrower answer, and
                // a quote whose only child was an empty TABLE read as empty and never got its
                // author line (K3, 2026-09-11). Its model-side twin, which decides the same thing
                // on a document SET (settle never runs for one), is
                // `EngineDocumentBridge.isEmptyBodyParagraph`.
                //
                // A PULL quote holds TEXT — its body is one engine block, it has no children at all
                // — so its author line follows that block's own length, which is what
                // `PullQuoteBox.shouldShowAuthor` and the forward pass both ask. Asked the
                // container question it would answer "holds content" for an empty pull quote (a
                // `.pullQuote` shape is not a paragraph shape) and settle would mint an author line
                // the forward pass does not.
                let quoted: Bool
                if case .blockQuote = candidate.owner {
                    quoted = !contents(of: candidate.owner.id, span: candidate.span).isEmpty
                } else {
                    quoted = candidate.span.contains {
                        currentRoles[$0].secondaryKind == nil && flatLength(ofRoleAt: $0) > 0
                    }
                }
                if hasLine != (authored || quoted) { return candidate }
            }
        }
        return nil
    }

    /// Whether the quote `id` holds nothing but empty PARAGRAPHS — the only shape for which
    /// dissolving the whole quote in one keystroke loses nothing.
    ///
    /// Asked of a CHILD UNIT, never of a role. A container child is structure, not a blank line: an
    /// empty code block, pull quote, media atom, table or nested quote must dissolve one level of
    /// its own first (the container arm below, or its own rules), and only once every child is a
    /// bare empty paragraph is the quote itself empty. Read per-role instead — "every primary block
    /// within the quote is empty" — it answered TRUE for a quote whose lone child was an EMPTY code
    /// block, because a code block's only primary role is its (empty) body and its language line is
    /// secondary. `unmakeContainer` then replaced the quote's whole span with one paragraph, so a
    /// Backspace at the start of a fresh quoted code block destroyed the code block AND the quote in
    /// one keystroke (device, K3 2026-09-08). Every test of the container arm at depth gave the
    /// quote a NON-EMPTY sibling, which is exactly the shape that hid it.
    ///
    /// Superseded by `ContainerContents.isEmpty` (`+Ancestry.swift`), which asks the same question of
    /// the same child units and is the only spelling. The reasoning that made this correct lives on
    /// that type: a single-role unit is not enough and neither is its shape — a captionless media
    /// atom and a one-cell table are one role each — and an empty NESTED container presents as one
    /// empty paragraph role too, so the unit must also be a DIRECT child.

    /// Whether every engine block a container owns is empty, per the CURRENT roles.
    internal func isWhollyEmpty(containerWithID id: BlockID) -> Bool {
        let owned = currentRoles.indices.filter { currentRoles[$0].containerID == id }
        return !owned.isEmpty && owned.allSatisfy { flatLength(ofRoleAt: $0) == 0 }
    }

    /// Whether removing the role at `index` would leave its container holding no children at all.
    ///
    /// A container must keep a body. For a details, losing its last child leaves a span that is its
    /// TITLE alone, and the bridge mints a rescue child on the next flatten anyway — so removing it
    /// is churn at best. Before settle learned to count a title as content it was destruction: the
    /// title was collected as an orphan and the whole block became a paragraph.
    private func isTheOnlyChildOfItsContainer(at index: Int) -> Bool {
        guard let container = currentRoles[index].innermostAncestor else { return false }
        return contents(of: container.id, around: index).units.count <= 1
    }

    /// Backspace at the start of the role at `index`, reached from BOTH doors — one function taking
    /// an index, like every other rule with two. Delivered as the join range the same keystroke used
    /// to fall through to `replaceAcrossBlocks`, which MERGES: a details' first body child was pulled
    /// up into its TITLE, and when that child was the details' only one and empty the container was
    /// left with no children at all.
    ///
    /// Both of its arms only move the caret, so it notifies nothing itself: it is registered
    /// `.handledOwingADelivery` in `backspaceJoinRules`, and the DOOR delivers.
    @discardableResult
    internal func applyBackspaceAtARegionBoundary(at index: Int) -> Bool {
        guard index < currentRoles.count else { return false }
        let offset = flatOffset(ofRoleAt: index)
        let role = currentRoles[index]
        if role.owningTable != nil {
            // A cell start is a wall for CONTENT, not for the caret: travel, never merge.
            guard index > 0 else { return false }
            moveCaretToCell(before: index)
            return true
        }
        guard index > 0 else { return false }
        let previous = currentRoles[index - 1]
        let isSecondLine = role.secondaryKind != nil
        let followsAContainer: Bool = {
            // The typed question first: my own container ENDS above me, so `previous` is not a block
            // I may merge into. The ancestry test below is kept because it asks a DIFFERENT thing —
            // whether `previous` sits in a container `role` is not in, which is the mirror case where
            // the two ancestries diverge rather than one simply ending.
            if case .outsideContainer = neighbour(before: index) { return true }
            if let container = previous.innermostAncestor, !role.isWithin(container.id) { return true }
            guard previous.containerID != role.containerID else { return false }
            switch previous.container {
            // A details is a wall like the others: the block after one must not merge up into
            // its last child, and at the START of its body the block above is the TITLE, which
            // is a field and not text to merge into (R7-details spec §6.2).
            case .block(.code), .block(.pullQuote), .blockQuote, .details: return true
            // A button row answers as a media atom does. Neither is a wall here because the ATOM
            // rules sit above this one in `backspaceJoinRules` and reach a caret at the start of the
            // block after an atom first; this arm is never the one that fires for them. A FOLDED
            // quote is in that set too, and this answer is only correct BECAUSE it is: it depends on
            // `atomUnitIndex` answering for `.collapsedQuote`, which is what puts the atom rules
            // ahead of this one. `EngineQuoteCollapseTests`
            // .test_backspaceAtTheStartOfTheBlockAfterAFoldedQuoteSelectsIt is what holds the pair
            // together — break the first half and that case goes red here rather than silently
            // merging a caret into the atom.
            case .block(.paragraph), .block(.media), .block(.buttonRow), .block(.collapsedQuote),
                 .table: return false
            }
        }()
        guard isSecondLine || followsAContainer else { return false }

        if followsAContainer, flatLength(ofRoleAt: index) == 0, case .standalone(.paragraph) = role.position,
           !isTheOnlyChildOfItsContainer(at: index) {
            // A plan-carrying edit rather than a top-level `document.blocks` removal, which could
            // not name a NESTED block at all: the empty paragraph after a quote INSIDE a quote
            // stayed put and only the caret moved.
            var plan = currentRoles
            plan.remove(at: index)
            performHostStructuralEdit { replaceFlat(NSRange(location: offset - 1, length: 1), with: "", adopting: plan) }
        }
        engineSelectedRange = NSRange(location: max(0, offset - 1), length: 0)
        return true
    }

    // MARK: - Backspace at the start of a quote's child (nesting design §6.2)

    /// Backspace at the start of a CHILD of its innermost quote Q, reached from both doors.
    /// A lone child un-quotes Q one level (legacy's whole-quote un-quote); the first of several is
    /// lifted out before Q (an empty one is removed instead); a non-first child is left to the join and
    /// the boundary rules — a paragraph merges, a container is a wall. A list item took the list rule
    /// first. Returns whether it acted.
    ///
    /// The child is a CHILD UNIT, not a role, and that is what makes the rule kind-agnostic. A code
    /// block, a pull quote and a media atom each own SEVERAL engine blocks, so the exit belongs to the
    /// whole unit: it fires only at the unit's FIRST role — which for a code block is its
    /// always-visible language line, not its body — and the lift moves every role of the unit at once.
    /// Gated on the role's own shape being a paragraph, as it was, it fired for one child kind in four
    /// and the boundary rule admitted the keystroke instead: at the start of a quoted code block the
    /// caret stepped out of the quote and nothing else happened.
    ///
    /// Two kinds still decline, both by the unit test rather than by a kind test. A CELL is excluded
    /// outright — a table's child exits are the table's own. And a second line that is not its unit's
    /// first (a pull quote's author, a media caption) is INSIDE its child, never its start; so is Q's
    /// own author line, which belongs to no unit at all and stays a wall.
    ///
    /// By INDEX, like the list rule, because UIKit delivers the same keystroke either as a collapsed
    /// caret at the child's start or as the RANGE covering the join with the block above, and the host
    /// view routes a non-empty selection to the gate. One function, both doors.
    @discardableResult
    internal func applyBackspaceAtStartOfQuoteChild(at index: Int) -> Bool {
        guard index < currentRoles.count else { return false }
        let role = currentRoles[index]
        guard let container = role.innermostAncestor, role.owningTable == nil,
              role.shape.paragraph?.list == nil else { return false }
        // A DETAILS declines outright. Its exits belong to its TITLE: the block above its first body
        // child is that title, so lifting the child out would place it BEFORE its own heading, and
        // un-detailing from the body would discard the heading the user typed. Backspace there is a
        // wall (§6.2) — the boundary rule below travels the caret to the title's end — and the title's
        // own Backspace unwraps (`applyBackspaceAtStartOfDetailsTitle`).
        guard container.details == nil else { return false }
        let contents = contents(of: container.id, around: index)
        guard let position = contents.position(of: index),
              contents.units[position].lowerBound == index else { return false }
        let unit = contents.units[position]
        if contents.units.count == 1 {
            unwrapContainer(container.id, around: index, caretLanding: flatOffset(ofRoleAt: index))
            return true
        }
        guard position == 0 else { return false }
        let parent = parentAncestry(of: container.id, at: index)
        // "Empty" is a child of ONE engine block holding nothing. A CONTAINER child is never removed
        // here even when every line of it is blank: an empty one dissolves into a paragraph first
        // (`applyDissolveOfEmptyContainer`, which both doors ask before this rule), and taking one
        // role of it away would tear a code block's language line off its body.
        if case .paragraph = unit, flatLength(ofRoleAt: index) == 0 {
            let start = flatOffset(ofRoleAt: index)
            var plan = currentRoles
            plan.remove(at: index)
            performHostStructuralEdit { replaceFlat(NSRange(location: start, length: 1), with: "", adopting: plan) }
            engineSelectedRange = NSRange(location: start, length: 0)
            return true
        }
        // Lifted out WHOLE: Q's preceding sibling in the parent. A declaration, no edit; the text
        // stays put — so the offsets below survive the plan unchanged.
        //
        // The CARET has to be collapsed explicitly even though nothing moved. At the caret door the
        // selection is already a collapsed caret at this role's start and leaving it alone looks
        // right; at the gate the selection IS the join range, and a rule that only declares roles
        // never touches it — so the same keystroke left a live one-character SELECTION straddling
        // the join, which reads on a device as a Backspace that selected a character instead of
        // deleting one. Set inside the frame, so the restore joins that one delivery.
        let landing = flatOffset(ofRoleAt: index)
        var plan = currentRoles
        for owned in unit.span { plan[owned] = currentRoles[owned].within(parent) }
        performHostStructuralChange {
            adoptRolePlan(plan)
            engineSelectedRange = NSRange(location: landing, length: 0)
        }
        return true
    }

    // MARK: - Backspace at the start of an authored quote

    /// Backspace at the start of a quote's LONE child, or of a pull quote's body, when the quote has
    /// an AUTHOR with text — reached from both doors. Those are the two positions where Backspace
    /// unwraps the container (`applyBackspaceAtStartOfQuoteChild`, `applyBackspaceAtStartOfPullQuote`),
    /// and an unwrap has nowhere to keep an attribution: a block quote's author text was deleted with
    /// its line, a pull quote's became a body paragraph. Selecting the invisible break before such a
    /// quote and pressing Backspace or Cut (a drag-move of it too) did exactly that, because the gate
    /// reads that range as Backspace at the quote's start (composer harness p21,
    /// `HarnessSeparatorBeforeQuoteDeletionTests`).
    ///
    /// **Decision: the authored quote is a WALL there**, as a details' first body child is (its title
    /// is content the container owns). The caret travels to the end of the block above, the
    /// boundary rule's travel; nothing else changes. A quote without an author unwraps as before, the
    /// first of several children is still lifted out (the author stays with the rest), a quote whose
    /// children are all EMPTY still dissolves (`applyDissolveOfEmptyContainer`, asked first), and the
    /// Quote / Pull Quote commands still unwrap an authored quote — they are the way to remove one, or
    /// empty its author line first.
    @discardableResult
    internal func applyBackspaceAtStartOfAuthoredQuote(at index: Int) -> Bool {
        guard index < currentRoles.count else { return false }
        let role = currentRoles[index]
        let walls: Bool
        if case let .standalone(.pullQuote(id)) = role.position {
            guard case let .pullQuote(quote)? = document.blocksByID[id] else { return false }
            let pullQuoteIsAuthored = quote.author.contains { !$0.text.isEmpty }
            // Inside a block quote the quote-child rule is asked first: a LONE child unwraps the
            // QUOTE around it (the pull quote survives; the quote's author would not), the first of
            // several is lifted out whole. Only a later child reaches the pull quote's own unwrap.
            if let container = role.innermostAncestor, container.quote != nil {
                let contents = contents(of: container.id, around: index)
                if contents.units.count == 1 {
                    walls = !quoteAuthorLineIsEmpty(container.id, contents)
                } else if contents.position(of: index) == 0 {
                    return false
                } else {
                    walls = pullQuoteIsAuthored
                }
            } else {
                walls = pullQuoteIsAuthored
            }
        } else {
            // The quote-child rule's own preconditions for its UNWRAP arm: a lone child unit, starting
            // here, of the innermost container, which is a quote.
            guard let container = role.innermostAncestor, container.quote != nil, role.owningTable == nil,
                  role.shape.paragraph?.list == nil else { return false }
            let contents = contents(of: container.id, around: index)
            guard contents.units.count == 1, let position = contents.position(of: index),
                  contents.units[position].lowerBound == index else { return false }
            walls = !quoteAuthorLineIsEmpty(container.id, contents)
        }
        guard walls else { return false }
        // At the document's start there is nowhere to travel: the keystroke does nothing.
        engineSelectedRange = NSRange(location: max(0, flatOffset(ofRoleAt: index) - 1), length: 0)
        return true
    }

    /// Whether quote `id`'s author line is absent or holds no text.
    private func quoteAuthorLineIsEmpty(_ id: BlockID, _ contents: ContainerContents) -> Bool {
        !contents.ownedLines.contains {
            currentRoles[$0].secondaryKind == .blockQuoteAuthor && flatLength(ofRoleAt: $0) > 0
        }
    }

    // MARK: - Backspace at the start of a pull quote

    /// Backspace at the start of a pull quote's BODY, reached from both doors: the quote unwraps into
    /// body paragraphs in place, as a block quote's lone child and a code block do on the same key.
    ///
    /// Without it nothing claimed the position and the engine merged the body into the block above:
    /// the merged text kept the ITALIC the pull quote's presentation draws, which then read back as
    /// the user's own italic and would have been sent, and the author line, its container gone,
    /// survived as a stray empty paragraph (composer harness, 2026-09-22). Rebuilding from the MODEL
    /// quote carries no presentation at all — the bridge strips it on read-back — so nothing ambient
    /// can be baked in.
    ///
    /// The body splits on its line breaks like the Format menu's toggle-off (`makePullQuote`). A pull
    /// quote with an AUTHOR never reaches here: it is a wall (`applyBackspaceAtStartOfAuthoredQuote`,
    /// asked first; until p21 the author became a body paragraph). An EMPTY pull quote never reaches
    /// here either: the dissolve rule runs first. Neither does a pull quote that is its quote's first child: the quote-child rule
    /// lifts it out first. The caret lands at the start of the first paragraph produced, and the
    /// undo step restores the caret at the quote's start, so both doors agree.
    @discardableResult
    internal func applyBackspaceAtStartOfPullQuote(at index: Int) -> Bool {
        guard index < currentRoles.count, case let .standalone(.pullQuote(id)) = currentRoles[index].position,
              case let .pullQuote(quote)? = document.blocksByID[id] else { return false }
        let paragraphs: [Block] = Self.runsSplitByNewline(quote.runs).enumerated().map { position, runs in
            // The first keeps the quote's identity, so the caret below can find it by id.
            .paragraph(ParagraphBlock(id: position == 0 ? quote.id : BlockID(UUID().uuidString),
                                      style: .body, runs: runs))
        }
        // An author with no text is nothing to keep; one with text walled this keystroke already
        // (`applyBackspaceAtStartOfAuthoredQuote`), so this only declines as a backstop.
        guard !quote.author.contains(where: { !$0.text.isEmpty }) else { return false }
        let documentBefore = document
        let caretBefore = NSRange(location: flatOffset(ofRoleAt: index), length: 0)
        guard let updated = document.replacingSiblings(from: quote.id, to: quote.id, with: paragraphs) else {
            return false
        }
        document = updated
        if let landing = flatOffsetOfPrimaryRegion(ofContainerWithID: quote.id) {
            engineSelectedRange = NSRange(location: landing, length: 0)
        }
        recordUndoStepForStructuralChange(restoring: documentBefore, selection: caretBefore)
        return true
    }

    /// Backspace inside an EMPTY container, reached from both doors — `at` is the role the caret is
    /// in, `caret` its flat offset. Like the list and quote-child rules it is ONE function taking an
    /// index, because UIKit delivers the same keystroke either as a collapsed caret or as the range
    /// covering the join with the block above. It was reachable from the caret door alone, so the
    /// same Backspace produced two different documents depending on which delivery UIKit chose: a
    /// quote whose children were all empty dissolved through one door and merely merged two of those
    /// children through the other, keeping a quote the user had just emptied.
    @discardableResult
    internal func applyDissolveOfEmptyContainer(at caretIndex: Int, caret: Int) -> Bool {
        guard caretIndex < currentRoles.count else { return false }
        let selection = NSRange(location: caret, length: 0)
        // A quote's emptiness belongs to its CHILDREN: every one of them empty. One empty child among
        // filled ones is a blank line inside a quote, which is content. The author line is a field,
        // not content, and does not keep an emptied quote alive — legacy's lone-empty-child rule
        // un-quotes whatever the author says (device, 2026-09-04). The innermost quote goes, one
        // level: its span becomes one paragraph in its parent.
        if let container = currentRoles[caretIndex].innermostAncestor,
           currentRoles[caretIndex].secondaryKind != .blockQuoteAuthor {
            let contents = contents(of: container.id, around: caretIndex)
            // A container goes only when it holds nothing a user would lose: every CHILD an empty
            // bare paragraph, AND its own lines empty too — a details with a typed title is not
            // empty however empty its body. Both questions are the contents', not a caller's.
            if contents.ownedLinesAreEmpty, contents.isEmpty {
                let parent = parentAncestry(of: container.id, at: caretIndex)
                performHostStructuralEdit {
                    unmakeContainer(first: contents.span.lowerBound,
                                    lastOwned: contents.span.upperBound, within: parent)
                }
                return true
            }
        }
        guard let containers = touchedContainers(for: selection), containers.count == 1,
              let container = containers.first else { return false }

        let replacement: Block
        switch container {
        // Legacy's rule (`startsEmptyContainer`): Backspace in an EMPTY code body un-codes, whatever
        // the language line holds — the language is a field, not code. From the language line only
        // at its start, and then the language text survives as the paragraph's rather than vanish.
        case let .code(code) where code.text.isEmpty:
            if currentRoles[caretIndex].secondaryKind == .codeLanguage {
                guard caret == flatOffset(ofRoleAt: caretIndex) else { return false }
                let language = code.language ?? ""
                replacement = .paragraph(ParagraphBlock(id: code.id, style: .body,
                                                        runs: language.isEmpty ? [] : [TextRun(text: language)]))
            } else {
                replacement = .paragraph(ParagraphBlock(id: code.id, style: .body))
            }
        case let .pullQuote(quote) where quote.text.isEmpty:
            replacement = .paragraph(ParagraphBlock(id: quote.id, style: .body))
        case let .table(table) where isWhollyEmpty(containerWithID: table.id):
            replacement = .paragraph(ParagraphBlock(id: table.id, style: .body))
        default:
            return false
        }

        // In place at any depth: a code block, pull quote or table inside a quote dissolves into a
        // paragraph of THAT quote. A top-level lookup found no such container at all and the rule
        // simply did not fire (an empty nested code block could not be un-coded).
        //
        // The set only moves the undo BASELINE, so the step is registered here, restoring the caret
        // at the container's start for both doors — `applyBackspaceAtStartOfPullQuote`'s rule.
        // Without it the dissolve had no step of its own: one ⌘Z took it back together with the
        // edit before it, and with nothing before it the dissolve could not be undone at all
        // (`EngineEmptyContainerDissolveUndoTests`).
        let documentBefore = document
        document = document.replacingBlock(withID: container.id, with: replacement)
        if let landing = flatOffsetOfPrimaryRegion(ofContainerWithID: replacement.id) {
            engineSelectedRange = NSRange(location: landing, length: 0)
        }
        recordUndoStepForStructuralChange(restoring: documentBefore, selection: selection)
        return true
    }

    /// Which blocks the flat range touches. Named for BLOCKS, not paragraphs: a container command's
    /// whole job is acting on blocks that are not paragraphs.
    ///
    /// `NSString.paragraphRange(for:)`'s rule: a NON-EMPTY range touches a block when it holds one of
    /// its characters, its paragraph break included, so its end is exclusive — a range ending exactly
    /// at a block's start (what ⇧↓ from a line's start selects, or the break alone) does not touch
    /// that block. A CARET touches the block it is in, at either edge. With `hi >= start` for both, a
    /// block command over "First⏎" also quoted, coded or indented the next line (composer harness
    /// p16, `HarnessBlockCommandSelectionEndTests`).
    internal func touchedBlockIndices(for range: NSRange) -> [Int] {
        var result: [Int] = []
        var start = 0
        let lo = range.location, hi = range.location + range.length
        for (index, block) in engine.attributedBlocks.enumerated() where index < currentRoles.count {
            let end = start + block.length
            if lo <= end && (range.length > 0 ? hi > start : hi >= start) { result.append(index) }
            start = end + 1
        }
        return result
    }

    /// Splits runs at every "\n", preserving each run's attributes. An empty trailing segment is a
    /// real empty paragraph and is kept — "a\n" is two lines, the second blank.
    private static func runsSplitByNewline(_ runs: [TextRun]) -> [[TextRun]] {
        var result: [[TextRun]] = [[]]
        for run in runs {
            let pieces = run.text.components(separatedBy: "\n")
            for (offset, piece) in pieces.enumerated() {
                if offset > 0 { result.append([]) }
                if !piece.isEmpty {
                    result[result.count - 1].append(TextRun(text: piece, attributes: run.attributes))
                }
            }
        }
        return result
    }
}
#endif
