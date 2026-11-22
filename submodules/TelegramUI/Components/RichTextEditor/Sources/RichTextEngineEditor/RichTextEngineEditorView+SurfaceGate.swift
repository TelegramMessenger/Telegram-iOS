#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The surface gate (surface-gate spec §3.1): text arriving at the host view's UITextInput surface
/// is decided BEFORE the controller edits. A decision forwards text (the same or a transform) or
/// vetoes after issuing the host's own top-level edits. The host never edits while the controller
/// is mid-edit, which is what made every nested correction fragile (spec §1).
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    internal enum SurfaceDecision {
        case forward(String)
        case veto
    }

    internal func installTextInputGate() {
        engine.tgid_textInputGate = { [weak self] range, text in
            guard let self else { return text }
            // The host's own edits (`replaceFlat`, `restyleFlat`) reach this surface too, issued by
            // the gate, by settle, or by a host command (`performHostStructuralEdit`). They are not
            // keystrokes and pass untouched — the gate decides a keystroke, and an edit issued by a
            // rule has already been decided and carries its plan.
            guard !self.isDecidingAtGate, !self.isSettling, !self.isIssuingHostEdit else { return text }
            self.rolesBeforeEdit = self.currentRoles
            self.undoStepRegistrationCountAtGateEntry = self.undoStepRegistrationCount
            self.isDecidingAtGate = true
            let decision = self.decideTextInput(range: range, text: text)
            self.isDecidingAtGate = false
            switch decision {
            case let .forward(forwarded):
                return forwarded
            case .veto:
                // Nothing is forwarded, so no post-edit callback follows: settle now.
                //
                // A veto that changed STRUCTURE also owes the consumer a notification, and nothing
                // else was going to send one: the funnel only fires for an EDIT, and a rule that
                // rewrites roles alone makes none. A veto that merely moved the caret (Return in a
                // cell) still owes nothing, which is why this asks whether structure changed rather
                // than notifying unconditionally.
                let changedStructure = self.structureTouchedThisEdit
                self.settleAfterEdit()
                self.endHostDecidedKeystroke()
                if changedStructure { self.deliverChangeNotificationNow() }
                return nil
            }
        }
    }

    /// The decision for `text` replacing `range` (engine axis). Only a text containing a newline or
    /// a range across blocks can be structural; everything else is forwarded unread.
    internal func decideTextInput(range: NSRange, text: String) -> SurfaceDecision {
        let hasNewline = text.contains("\n")
        // The gate's half of the structural-selection Backspace. Asked here, before any range
        // reasoning, because the selection is what decides it — not where the range happens to fall.
        // One function, asked at both doors; see `deleteTableStructuralSelection`.
        if text.isEmpty, deleteTableStructuralSelection() { return .veto }
        if let cells = cellRange(range), cells.first != cells.last, !coversWholeTable(range, cells: cells) {
            return replaceAcrossCells(cells, range: range, text: text)
        }
        guard let index = roleIndex(atFlatOffset: range.location) else { return .forward(text) }
        if range.length > 0, let last = roleIndex(atFlatOffset: NSMaxRange(range)), last != index {
            // A Backspace at a block's START reaches the gate in this shape — the RANGE covering
            // the join with the block above — whenever UIKit chose that delivery over a collapsed
            // caret. It is the same keystroke and takes the same rules, in the same order, from the
            // same array the caret door walks (`backspaceJoinRules`). Two hand-written lists stood
            // here and there instead, and drifted three times; the array's doc comment records what
            // each drift cost.
            // NOT for the selection a composition starts over: that arrives as an empty replacement
            // too, but it is a REPLACEMENT, and typing over the same join forwards to the cross-block
            // rule below. Read as a Backspace it removed an empty paragraph after a code block that
            // typing keeps (composer harness, 2026-09-24, found reducing fuzz seed 63,
            // `HarnessCompositionUndoResidualTests`).
            if text.isEmpty, !engine.tgid_isResolvingCompositionSelection,
               rangeIsTheJoinBefore(last, range: range), applyBackspaceJoinRules(at: last) {
                return .veto
            }
            return replaceAcrossBlocks(range, text: text, first: index, last: last)
        }
        // ATOM UNITS: a keystroke landing on one mints a paragraph beside it and never types INTO
        // it. A folded quote takes the CAPTIONLESS path already in that function — before the atom
        // mints a paragraph above, past it one below — so it needs no arm of its own.
        //
        // A BUTTON ROW is an atom unit too, and takes the caption-less path: text at its leading
        // stop opens a body paragraph above it, at its trailing stop one below. It used to fall
        // through to `.forward(text)` and type INTO the row's line — a block whose shape ignores its
        // runs — so the model never saw the text (lost on send) while the engine showed it, and at
        // the leading stop the row stopped being drawn (composer harness p13,
        // `HarnessButtonRowStopTypingTests`).
        switch currentRoles[index].position {
        case .standalone(.media), .standalone(.collapsedQuote), .standalone(.buttonRow):
            return decideTextInputAtAnAtomUnit(index: index, range: range, text: text)
        default:
            break
        }
        // A ONE-LINE field takes no line break of ANY kind — `U+2028`, `U+2029`, CR, NEL, CRLF typed,
        // composed or inserted by the chat — not only "\n" (which the arms below handle with the Return
        // key's meanings). Forwarded unread, a `U+2028` read back as "\n" and the next render split the
        // line into two engine blocks: "N engine blocks against N-1 roles" (composer harness p23,
        // `HarnessNewlineInOneLineFieldCrashTests`); the others were sent as typed.
        if !hasNewline, currentRoles[index].isOneLineField, text.contains(where: { $0.isNewline }) {
            return .forward(Self.oneLineFieldText(text))
        }
        guard hasNewline else { return .forward(text) }
        // A newline that arrives WITH text in one delivery — dictation's "new line …" (handed to
        // `insertText:` whole), a text replacement, a multi-character hardware insert — at a heading's
        // start is Return and then the rest, decided exactly as the two keystrokes are: the Return by
        // every rule a lone "\n" meets there (a quote's exits, then the heading's line above), the rest
        // typed at the caret that leaves. Forwarded whole, the engine split the heading at its start and
        // the heading's text became the BODY tail (composer harness, p12,
        // `HarnessMultiLineInsertAtHeadingStartTests`) — row 36 through another door.
        if range.length == 0, text.hasPrefix("\n"), text != "\n",
           isAtStartOfNonEmptyHeading(index: index, caret: range.location) {
            typeAtCaret(deciding: "\n", at: range)
            let rest = String(text.dropFirst())
            typeAtCaret(deciding: rest, at: NSRange(location: engineSelectedRange.location, length: 0))
            return .veto
        }
        let role = currentRoles[index]
        if role.owningTable != nil {
            // A cell is one paragraph. Return moves to the next cell (a caret move, no undo step);
            // a paste keeps its newlines as line separators.
            if text == "\n" && range.length == 0 {
                moveCaretToCell(after: index)
                return .veto
            }
            return .forward(EngineDocumentBridge.engineText(text))
        }
        if role.secondaryKind == .codeLanguage {
            // One line, always: Return moves into the code (a caret move).
            if text == "\n" && range.length == 0 {
                if let code = flatOffsetOfPrimaryRegion(ofContainerWithID: role.containerID) {
                    engineSelectedRange = NSRange(location: code, length: 0)
                }
                return .veto
            }
            // A Return over a selection keeps its rule (it deletes the selection); delivered text
            // keeps its word boundaries.
            return .forward(text == "\n" ? "" : Self.oneLineFieldText(text))
        }
        if role.secondaryKind == .detailsTitle {
            // A language line's Return, exactly: one line always, and Return moves OUT of the field
            // rather than splitting it — into the body when the details is expanded, onto the block
            // after it when it is folded (§6.1, amended by the K3 pass 2026-09-08). It used to UNFOLD
            // a folded details and put the caret in the body it had just revealed, which is a
            // different request from the one the user made.
            if text == "\n" && range.length == 0 {
                moveCaretOutOfDetailsTitle()
                return .veto
            }
            // A Return over a selection keeps its rule (it deletes the selection); delivered text
            // keeps its word boundaries.
            return .forward(text == "\n" ? "" : Self.oneLineFieldText(text))
        }
        if role.secondaryKind == .pullQuoteAuthor || role.secondaryKind == .blockQuoteAuthor {
            // A Return splits the author line and the tail is a body paragraph: settle declares it.
            // Any other text joins its lines: the author is one line.
            return text == "\n" ? .forward(text) : .forward(Self.oneLineFieldText(text))
        }
        // Before the quote and leaf branches: a list item can be either, and ending the list is the
        // first step out of both (legacy ends the list before it leaves the quote — two Returns).
        if text == "\n", range.length == 0, role.shape.paragraph?.list != nil,
           decideReturnInListItem(index: index, caret: range.location) {
            return .veto
        }
        // BEFORE the quote branch, and this order is load-bearing: a leaf body inside a quote reports
        // that quote as its innermost, so with the quote branch first a Return in a nested code block
        // or pull quote fell through `decideReturnInQuoteChild` to a raw "\n" — the engine split the
        // body in two and settle's rejoin put a line separator back, so the RESULT looked right while
        // legacy's double-Return exits did not exist at depth at all. The same key with a non-empty
        // selection already reached this branch and forwarded U+2028, so the two shapes of one
        // keystroke disagreed. `decideReturnInLeafBody` is depth-correct on its own — it mints
        // `freshBodyRole(within: ancestry)` and calls `unmakeContainer(…, within:)` — so the order is
        // the whole of it. A leaf body is never a quote CHILD in the sense §6.1 means: its exits are
        // its own, and a quote's exits act on paragraphs.
        if case let .standalone(shape) = role.position, isLeafBody(shape) {
            if text == "\n" && range.length == 0 { return decideReturnInLeafBody(index: index, caret: range.location) }
            return .forward(EngineDocumentBridge.engineText(text))
        }
        if let container = role.innermostAncestor, text == "\n", range.length == 0 {
            if decideReturnInQuoteChild(containerID: container.id, child: index, caret: range.location) { return .veto }
            // After the quote's exits: a second Return at the heading's start, with the empty line
            // this left above it, is the quote's leading exit and must still reach it.
            if decideReturnAtStartOfHeading(index: index, caret: range.location) { return .veto }
            return .forward(text)   // a new child: settle declares it
        }
        if text == "\n", range.length == 0, decideReturnAtStartOfHeading(index: index, caret: range.location) {
            return .veto
        }
        return .forward(text)
    }

    /// Text with newlines, as a ONE-LINE field takes it (a code block's language, a details title, a
    /// quote's author): every run of whitespace that contains a newline becomes one space, which is
    /// what a stock `UITextField` does with a newline — so "123 Main St⏎City" from a text replacement,
    /// or dictation's "new line", keeps its word boundary. These used to DELETE the newline and glue
    /// the words ("123 Main StCity"; composer harness, p12, `HarnessSingleLineFieldNewlineTests`).
    ///
    /// Only for a delivery with text around its newlines. A lone "\n" is the Return KEY, and each of
    /// these fields gives it a meaning of its own before this is reached (the language line and the
    /// details title move the caret out; the author line splits) — a keystroke is a command there,
    /// where a newline inside delivered text is a line break the field cannot hold. A run collapses to
    /// ONE space (where `UITextField` maps each newline separately) because a blank line or an
    /// indented continuation is layout of the text it came from, not two word boundaries.
    ///
    /// The rule itself is the bridge's (`EngineDocumentBridge.oneLineText`), shared with the render, so a
    /// field reads the same however the text got there.
    internal static func oneLineFieldText(_ text: String) -> String {
        EngineDocumentBridge.oneLineText(text)
    }

    // MARK: - Headings: Return at the start opens a line above

    /// Return at offset 0 of a NON-EMPTY heading inserts an empty BODY paragraph above it and leaves
    /// the heading — text, style and identity — where it is, the caret still at its start.
    ///
    /// The documented split rule makes the tail of a split heading a body paragraph, which is right
    /// for a Return at its end or in its middle; at its start the "tail" is the whole heading, and the
    /// engine's split left an empty heading above and demoted the text to body (composer harness,
    /// 2026-09-23, `HarnessHeadingReturnAtStartTests`). An empty heading, a list item (the list rules
    /// own Return there) and any secondary line or cell are left to the rules they already have.
    private func decideReturnAtStartOfHeading(index: Int, caret: Int) -> Bool {
        guard isAtStartOfNonEmptyHeading(index: index, caret: caret) else { return false }
        let role = currentRoles[index]
        let start = flatOffset(ofRoleAt: index)
        var plan = currentRoles
        plan.insert(freshBodyRole(within: role.ancestry), at: index)
        // Split at the heading's own start, whatever sits above it (a container's last line must not
        // be the block that is split). The plan assigns the roles by POSITION: the empty upper half
        // is the fresh body paragraph, the half holding the text keeps the heading's role.
        replaceFlat(NSRange(location: start, length: 0), with: "\n", adopting: plan)
        engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index + 1), length: 0)
        return true
    }

    /// Where `decideReturnAtStartOfHeading` applies: offset 0 of a non-empty, non-list heading that
    /// is a block of its own (not a secondary line, not a cell).
    private func isAtStartOfNonEmptyHeading(index: Int, caret: Int) -> Bool {
        let role = currentRoles[index]
        guard case .standalone(.paragraph) = role.position,
              role.secondaryKind == nil, role.owningTable == nil,
              let paragraph = role.shape.paragraph, paragraph.list == nil,
              Self.headingStyles.contains(paragraph.style),
              flatLength(ofRoleAt: index) > 0 else { return false }
        return caret == flatOffset(ofRoleAt: index)
    }

    /// `text` at the collapsed `caret`, decided as the keystroke it is and issued inside the current
    /// one — the second half of a delivery the gate splits (see `replaceAcrossBlocks`'s newline arm).
    private func typeAtCaret(deciding text: String, at caret: NSRange) {
        guard !text.isEmpty else { return }
        switch decideTextInput(range: caret, text: text) {
        case .veto:
            break
        case let .forward(forwarded):
            replaceFlat(caret, with: forwarded)
            engineSelectedRange = NSRange(location: caret.location + forwarded.utf16.count, length: 0)
        }
    }

    private static let headingStyles: Set<ParagraphStyleName> = [.heading1, .heading2, .heading3,
                                                                 .heading4, .heading5, .heading6]

    // MARK: - Leaf bodies: newlines and legacy's double Return

    internal func isLeafBody(_ shape: EngineBlockShape) -> Bool {
        switch shape {
        case .pullQuote, .code: return true
        // A button row owns NO text, so there is no body for a newline to land in. A FOLDED
        // quote is the same case: its body is off the axis entirely, so there is nothing to land in
        // — the atom rules decide what a keystroke there does instead.
        case .paragraph, .media, .buttonRow, .collapsedQuote: return false
        }
    }

    private static let lineSeparator = EngineDocumentBridge.lineSeparator
    private static let lineSeparatorUnit: unichar = 0x2028

    /// Legacy's `pullQuoteDoubleReturnExit` / `codeBlockDoubleReturnExit`, read off the body as it
    /// stands: an empty body takes the newline (a blank two-line body); a body of nothing but blank
    /// lines un-makes; a caret at the end after a blank last line leaves after the container; a caret
    /// on or right after a blank first line leaves before it; anything else is a newline inside.
    private func decideReturnInLeafBody(index: Int, caret: Int) -> SurfaceDecision {
        let bodyStart = flatOffset(ofRoleAt: index)
        let units = Array(engine.attributedBlocks[index].string.utf16)
        let local = caret - bodyStart
        let isBlank = !units.isEmpty && units.allSatisfy { $0 == Self.lineSeparatorUnit }
        let endsBlank = local == units.count && units.last == Self.lineSeparatorUnit
        let startsBlank = units.first == Self.lineSeparatorUnit && local <= 1
        if units.isEmpty || (!isBlank && !endsBlank && !startsBlank) {
            return .forward(Self.lineSeparator)
        }
        let container = currentRoles[index].containerID
        let first = currentRoles.firstIndex { $0.containerID == container } ?? index
        let lastOwned = currentRoles.lastIndex { $0.containerID == container } ?? index
        let paragraph = freshBodyRole(within: currentRoles[index].ancestry)
        if isBlank {
            unmakeContainer(first: first, lastOwned: lastOwned, within: currentRoles[index].ancestry)
            return .veto
        }
        if endsBlank {
            // The blank last line goes; a body paragraph opens after the container's last block.
            let containerEnd = flatOffset(ofRoleAt: lastOwned) + flatLength(ofRoleAt: lastOwned) - 1
            var plan = currentRoles
            plan.insert(paragraph, at: lastOwned + 1)
            replaceFlat(NSRange(location: caret - 1, length: 1), with: "")
            replaceFlat(NSRange(location: containerEnd, length: 0), with: "\n", adopting: plan)
            engineSelectedRange = NSRange(location: containerEnd + 1, length: 0)
            return .veto
        }
        // The blank first line goes; a body paragraph opens before the container.
        let containerStart = flatOffset(ofRoleAt: first)
        var plan = currentRoles
        plan.insert(paragraph, at: first)
        replaceFlat(NSRange(location: bodyStart, length: 1), with: "")
        replaceFlat(NSRange(location: max(containerStart - 1, 0), length: 0), with: "\n", adopting: plan)
        engineSelectedRange = NSRange(location: containerStart, length: 0)
        return .veto
    }

    // MARK: - Block quotes: legacy's double Return

    /// Legacy's `blockQuoteEmptyTrailingChildExit` / `blockQuoteEmptyLeadingChildExit`, read before
    /// the edit: on an EMPTY last child of two or more, leave after the quote (a quote of nothing but
    /// empty children un-quotes); at the start of the content right after an empty leading child, or
    /// on that child, leave before it. Returns whether it acted.
    ///
    /// Over the quote's CHILD UNITS, not its primary roles (§6.1): a nested quote or a code block is
    /// one child made of several roles, so counting roles read a quote holding one nested quote as
    /// holding two children and offered an exit that has no meaning there.
    private func decideReturnInQuoteChild(containerID: BlockID, child: Int, caret: Int) -> Bool {
        let contents = contents(of: containerID, around: child)
        let span = contents.span
        let units = contents.units
        // A PRIMARY paragraph, spelled the way `applyBackspaceAtStartOfQuoteChild` spells it.
        // `shape` is not that test on its own: it answers `.paragraph` for a secondary line and for a
        // cell too, because both ARE paragraphs. `decideTextInput` filters cells, language lines and
        // both author lines out ahead of here, but NOT a media caption — whose role carries the quote
        // in its ancestry and whose index `units.firstIndex(where:)` finds inside the media unit, where
        // the old `children.firstIndex(of:)` over primaries declined. Left admitted, a Return in a
        // caption inside a quote took the quote's trailing exit: the caption's role was removed, its
        // text merged into the atom's block, and a paragraph minted after the author line.
        guard units.count >= 2, let position = units.firstIndex(where: { $0.contains(child) }),
              currentRoles[child].secondaryKind == nil, currentRoles[child].owningTable == nil,
              currentRoles[child].shape.paragraph != nil else { return false }
        let parent = parentAncestry(of: containerID, at: child)
        let childStart = flatOffset(ofRoleAt: child)
        let childEmpty = flatLength(ofRoleAt: child) == 0
        let atStart = caret == childStart
        let unitIsEmpty: (ChildUnit) -> Bool = { unit in unit.span.allSatisfy { self.flatLength(ofRoleAt: $0) == 0 } }
        // The CANONICAL emptiness, which requires every unit to be an empty direct-child PARAGRAPH —
        // not merely "every role in it has zero length". A table of blank cells satisfies the second
        // and is content by any reading of the first: with it, a Return on the empty paragraph after
        // a details' only table un-made the whole block (K3, 2026-09-08), the same shape as the empty
        // code block that once counted as an empty child.
        let allEmpty = contents.isEmpty
        let lastOwned = span.upperBound
        if position == units.count - 1, childEmpty {
            if allEmpty {
                unmakeContainer(first: span.lowerBound, lastOwned: lastOwned, within: parent)
            } else if lastOwned > child {
                // The empty child leaves from before the author line and comes back after it.
                let authorEnd = flatOffset(ofRoleAt: lastOwned) + flatLength(ofRoleAt: lastOwned)
                var plan = currentRoles
                plan.remove(at: child)
                plan.insert(freshBodyRole(within: parent), at: lastOwned)
                replaceFlat(NSRange(location: childStart - 1, length: 1), with: "")
                replaceFlat(NSRange(location: authorEnd - 1, length: 0), with: "\n", adopting: plan)
                engineSelectedRange = NSRange(location: authorEnd, length: 0)
            } else {
                // Nothing of the quote after it: the empty child IS the paragraph after the quote.
                var plan = currentRoles
                plan[child] = freshBodyRole(within: parent)
                adoptRolePlan(plan)
            }
            return true
        }
        let leading = units[0].lowerBound
        if position <= 1, atStart, case .paragraph = units[0], unitIsEmpty(units[0]),
           currentRoles[leading].secondaryKind == nil, currentRoles[leading].owningTable == nil,
           currentRoles[leading].shape.paragraph != nil, !allEmpty {
            // The empty leading child becomes the paragraph before the container. Only a single empty
            // PARAGRAPH leaves this way — a leading nested quote or code block is a child of its own,
            // and declaring one of its roles a paragraph would tear it in half.
            var plan = currentRoles
            if span.lowerBound == leading {
                // A quote: its span STARTS with this child, so re-declaring the role is enough and the
                // regroup opens the quote after it. A declaration, no edit.
                plan[leading] = freshBodyRole(within: parent)
                adoptRolePlan(plan)
                engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: leading), length: 0)
            } else {
                // A DETAILS: its span starts with the TITLE, so the leading child sits BELOW a role the
                // container owns. Declared a paragraph in place it would sit between the title and the
                // rest of the body, and the regroup — which closes a container the moment a role is not
                // within it — would close the details there and reopen it after: the block torn in two,
                // its contents spilling into what follows (K3, 2026-09-08). It has to MOVE above the
                // container's first role, which is an edit and not a declaration.
                let containerStart = flatOffset(ofRoleAt: span.lowerBound)
                let leadingStart = flatOffset(ofRoleAt: leading)
                plan.remove(at: leading)
                plan.insert(freshBodyRole(within: parent), at: span.lowerBound)
                replaceFlat(NSRange(location: leadingStart - 1, length: 1), with: "")
                replaceFlat(NSRange(location: containerStart, length: 0), with: "\n", adopting: plan)
                engineSelectedRange = NSRange(location: containerStart, length: 0)
            }
            return true
        }
        return false
    }

    /// The whole container becomes one empty body paragraph at `ancestry`'s depth, caret in it
    /// (legacy's un-make, un-code, un-quote of a wholly blank container).
    internal func unmakeContainer(first: Int, lastOwned: Int, within ancestry: [EngineAncestor]) {
        let start = flatOffset(ofRoleAt: first)
        let end = flatOffset(ofRoleAt: lastOwned) + flatLength(ofRoleAt: lastOwned)
        var plan = Array(currentRoles[..<first])
        plan.append(freshBodyRole(within: ancestry))
        plan.append(contentsOf: currentRoles[(lastOwned + 1)...])
        replaceFlat(NSRange(location: start, length: end - start), with: "", adopting: plan)
        engineSelectedRange = NSRange(location: start, length: 0)
    }

    /// Every cell of the table from its first character to its last: a select-all over the table,
    /// which drops it like any wholly covered container rather than emptying its cells.
    private func coversWholeTable(_ range: NSRange, cells: (table: BlockID, first: Int, last: Int)) -> Bool {
        let span = containerSpan(containing: cells.first)
        return cells.first == span.lowerBound && cells.last == span.upperBound
            && range.location == flatOffset(ofRoleAt: cells.first)
            && NSMaxRange(range) == flatOffset(ofRoleAt: cells.last) + flatLength(ofRoleAt: cells.last)
    }

    /// Both ends of `range` in cells of one table: the table and the cells' role indices.
    internal func cellRange(_ range: NSRange) -> (table: BlockID, first: Int, last: Int)? {
        guard range.length > 0,
              let first = roleIndex(atFlatOffset: range.location),
              let last = roleIndex(atFlatOffset: NSMaxRange(range)),
              let table = currentRoles[first].owningTable,
              currentRoles[last].containerID == table.id else { return nil }
        return (table.id, first, last)
    }

    /// Legacy's rule for a replacement across cells: the first cell keeps its head plus the text,
    /// the cells between are emptied, the last keeps its tail. Issued as one edit INSIDE each cell,
    /// last to first so the earlier offsets hold, never across a cell's separator: the structure is
    /// unchanged, every cell keeps its identity, and the text a cell keeps is never touched.
    ///
    /// It used to be ONE edit over the whole span re-inserting each cell's kept text as a PLAIN
    /// string (`texts.joined(separator: "\n")`), which dropped every attribute on the text it kept
    /// and left a kept custom emoji as a bare `U+FFFC` with no attachment — sent as a literal
    /// character (composer harness p16, fuzz seed 56, `HarnessAtomFlatteningTests`).
    private func replaceAcrossCells(_ cells: (table: BlockID, first: Int, last: Int), range: NSRange, text: String) -> SurfaceDecision {
        let inserted = EngineDocumentBridge.engineText(text)
        var edits: [NSRange] = []
        for index in cells.first...cells.last {
            let cell = flatRange(ofRoleAt: index)
            let lower = index == cells.first ? max(cell.location, range.location) : cell.location
            let upper = index == cells.last ? min(NSMaxRange(cell), NSMaxRange(range)) : NSMaxRange(cell)
            edits.append(NSRange(location: lower, length: max(0, upper - lower)))
        }
        for (position, edit) in edits.enumerated().reversed() {
            let insert = position == 0 ? inserted : ""
            guard edit.length > 0 || !insert.isEmpty else { continue }
            // The text takes the attributes where the range STARTS (see `truncateAroundMediaUnits`):
            // the later cells' cuts left the controller's caret in them.
            if !insert.isEmpty { engineSelectedRange = edit }
            replaceFlat(edit, with: insert)
        }
        engineSelectedRange = NSRange(location: range.location + inserted.utf16.count, length: 0)
        return .veto
    }

    // MARK: - Replacements across blocks: legacy's one rule

    /// Legacy's `applyReplaceOutcome` for a range across blocks, decided BEFORE the edit and carried
    /// as one plan. A container (code, pull quote, block quote) whose primary blocks lie wholly
    /// inside the range is dropped, second lines included — a select-all takes a block quote with it
    /// like every other block, author line and all, even when the composer's axis left that line
    /// out of the selection; every block between the endpoints is dropped; the survivor keeps the
    /// start block's role when the start is not a dropped container, else the end block's, else it
    /// is a fresh body paragraph (a quote child between two children of one quote). A LEAF container
    /// covered only in part keeps its remainder as its own block — the start keeps its head plus the
    /// text, the end keeps its tail (legacy's truncate branch) — and settle restores the language
    /// line the range swallowed; a block quote covered in part keeps the endpoint child, which
    /// merges like a paragraph. A table wholly inside the range is dropped like any container; a
    /// range with an endpoint inside a table it covers only in part is refused, as legacy refuses a
    /// range across stacks (device, 2026-09-04: select all with a trailing table did nothing).
    /// Selection deletions reach this through the host view's `deleteBackward` and `cut:`, which
    /// are replacements with empty text.
    ///
    /// Before this, a replacement across blocks was forwarded unread, the engine kept the first
    /// block's identity, and every kind needed its own after-the-fact rule (device, 2026-09-04:
    /// select all and Backspace kept a code block's language field, then a quote's band).
    /// The refusal half of the rule below, stated once: a range with an endpoint inside a table it
    /// covers only in part changes nothing. Typing asks it through `replaceAcrossBlocks`; a PASTE asks
    /// it through `rangeCoversATableOnlyInPart(_:)`, because a paste replaces the selection by the
    /// engine's own storage edit (or `Document.replacingRange`), which never reaches this gate.
    private func endpointIsInATableCoveredOnlyInPart(first: Int, last: Int,
                                                     startCovered: Bool, endCovered: Bool) -> Bool {
        (currentRoles[first].owningTable != nil && !startCovered)
            || (currentRoles[last].owningTable != nil && !endCovered)
    }

    /// Whether a replacement over `range` is one the gate REFUSES because it covers a table only in
    /// part — asked by the paste paths, which must obey the rule typing obeys (composer harness,
    /// 2026-09-23, `HarnessPasteOverPartialTableSelectionTests`). A range inside ONE table is not
    /// this question: across cells it is re-issued per cell, and one covering the whole grid drops it.
    internal func rangeCoversATableOnlyInPart(_ range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        if cellRange(range) != nil { return false }
        guard let first = roleIndex(atFlatOffset: range.location),
              let last = roleIndex(atFlatOffset: NSMaxRange(range)), first != last else { return false }
        let headKept = range.location - flatOffset(ofRoleAt: first)
        let tailKept = flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last) - NSMaxRange(range)
        let startCovered = coveredUnit(at: first, first: first, last: last, headKept: headKept, tailKept: tailKept).covered
        let endCovered = coveredUnit(at: last, first: first, last: last, headKept: headKept, tailKept: tailKept).covered
        return endpointIsInATableCoveredOnlyInPart(first: first, last: last,
                                                   startCovered: startCovered, endCovered: endCovered)
    }

    internal func replaceAcrossBlocks(_ range: NSRange, text: String, first: Int, last: Int) -> SurfaceDecision {
        let inserted = EngineDocumentBridge.engineText(text)
        let headKept = range.location - flatOffset(ofRoleAt: first)
        let tailKept = flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last) - NSMaxRange(range)
        let (startSpan, startCovered, startHolder) = coveredUnit(at: first, first: first, last: last, headKept: headKept, tailKept: tailKept)
        let (endSpan, endCovered, endHolder) = coveredUnit(at: last, first: first, last: last, headKept: headKept, tailKept: tailKept)
        let startIsLeaf = isLeafContainer(currentRoles[first])
        // A range that ENTERS a details at its title — from a block before the details into the
        // title line, the details not covered — truncates like a leaf container: the title keeps
        // its tail AS the title and the start block keeps its head. Merged instead (the title role
        // dropped as a covered end), the title line left the engine while the details stayed in the
        // model with an empty title, and nothing re-mints a details' title (composer harness,
        // 2026-09-23, fuzz seeds 21 and 38, `HarnessDetailsTitleCrossDeleteTests`). The title is the
        // details' content, never a merge partner for the text above it — the same reason
        // Backspace at the start of its first body child is a wall.
        //
        // A block quote's AUTHOR line as the end is the same: a range from the quote's body into its
        // author deletes the covered author text and the author keeps its remainder AS the author —
        // the pull quote's answer (its author is in a leaf container) and the details title's. Merged
        // as an end leaf, the author's remainder became BODY text and the author was left empty, while
        // the copy carried the author slice as an author: Cut + Paste moved text out of the
        // attribution and a move into another field lost it (composer harness p22,
        // `HarnessQuoteBodyIntoAuthorRangeTests`). A range covering the quote's body whole still drops
        // the quote, author included (`containerIsCovered`; the copy is widened to match, p19).
        let endIsLeaf = isLeafContainer(currentRoles[last])
            || (currentRoles[last].secondaryKind == .detailsTitle && !endCovered)
            || (currentRoles[last].secondaryKind == .blockQuoteAuthor && !endCovered)
        if endpointIsInATableCoveredOnlyInPart(first: first, last: last,
                                               startCovered: startCovered, endCovered: endCovered) { return .veto }

        // A media unit entered but not covered keeps its atom and truncates its caption (§5.3).
        let startInMedia = mediaAtomIndex(forRoleAt: first) != nil
        let endInMedia = mediaAtomIndex(forRoleAt: last) != nil
        // A replacement carrying a NEWLINE is two things: the cross-block deletion, then that text
        // typed at the caret the deletion leaves. The second half is a keystroke like any other and
        // takes the gate's own rules for where it lands — a Return in a paragraph splits it, in a
        // code or pull-quote body it is a line separator, in a list item it continues the list.
        // Spliced into the survivor through `engineText` instead, every newline became a U+2028 and
        // Return over a two-paragraph selection left ONE paragraph with a soft break, where a stock
        // text view and the legacy composer leave two (composer harness, 2026-09-23,
        // `HarnessReturnOverCrossBlockSelectionTests`). When an endpoint is a leaf or a medium the
        // range only ENTERS, the deletion keeps both endpoints and the separator between them — and
        // that separator is already the text's last newline, so one is dropped: Return there leaves
        // the two truncated blocks and nothing more. Both halves are issued inside this keystroke.
        if text.contains("\n") {
            // A truncate keeps both endpoints only when NEITHER endpoint's unit is dropped whole; with
            // one dropped, the other endpoint absorbs the range (below) and no separator is left.
            let keepsTheSeparator = (startInMedia && !startCovered) || (endInMedia && !endCovered)
                || (((startIsLeaf && !startCovered) || (endIsLeaf && !endCovered)) && !startCovered && !endCovered)
            _ = replaceAcrossBlocks(range, text: "", first: first, last: last)
            let typed = keepsTheSeparator && text.hasSuffix("\n") ? String(text.dropLast()) : text
            guard !typed.isEmpty else { return .veto }
            let caret = NSRange(location: engineSelectedRange.location, length: 0)
            switch decideTextInput(range: caret, text: typed) {
            case .veto:
                break
            case let .forward(forwarded):
                replaceFlat(caret, with: forwarded)
                engineSelectedRange = NSRange(location: caret.location + forwarded.utf16.count, length: 0)
            }
            return .veto
        }
        if deletesWholeLinesBefore(last, range: range, text: inserted, first: first, headKept: headKept,
                                   startCovered: startCovered, endCovered: endCovered) {
            // WHOLE LINES deleted: the range runs from the first block's start to the last block's
            // start, holding every character of the blocks before `last` and none of `last`'s. Those
            // blocks go and `last` survives as it is — role, identity and text. The merge below kept
            // the FIRST block's role on the survivor, so the line after a deleted line took the
            // deleted line's role: a heading became body, a body line became a heading, a quote or a
            // checked item lost its structure, and a code block kept a blank line above it (composer
            // harness p16, `HarnessWholeLineDeletionTests`). A stock `UITextView` keeps the next
            // paragraph's own style. TYPING over the same range still takes the first line's role
            // (stock does too: the typed text starts in the replaced paragraph), so this is for a
            // deletion only.
            var plan = Array(currentRoles[..<first])
            plan.append(contentsOf: currentRoles[last...])
            replaceFlat(range, with: "", adopting: plan)
            engineSelectedRange = NSRange(location: range.location, length: 0)
            return .veto
        }
        if (startInMedia && !startCovered) || (endInMedia && !endCovered) {
            return truncateAroundMediaUnits(range, text: inserted, first: first, last: last)
        }

        if (startIsLeaf && !startCovered) || (endIsLeaf && !endCovered) {
            // One endpoint's unit is dropped WHOLE — a table, a code block, a quote the range covers —
            // while the other is a leaf (or a details title) it only enters. The dropped unit goes
            // with everything between, and the entered endpoint absorbs the text: at its start when
            // the START was dropped, after its head when the END was. Truncating instead kept the
            // dropped unit's endpoint ROLE on the merged block: over a whole table up to a details
            // title or a code block's language line, the first CELL's role survived on one engine
            // line, so the model kept a table the engine had collapsed — model and engine split
            // (composer harness p15, fuzz seed 33, `HarnessWholeTableEditIntoSecondaryLineTests`).
            if startCovered, startSpan.upperBound < last {
                let editFirst = startSpan.lowerBound
                let editStart = flatOffset(ofRoleAt: editFirst)
                var plan = Array(currentRoles[..<editFirst])
                plan.append(contentsOf: currentRoles[last...])
                replaceFlat(NSRange(location: editStart, length: NSMaxRange(range) - editStart), with: inserted, adopting: plan)
                engineSelectedRange = NSRange(location: editStart + inserted.utf16.count, length: 0)
                return .veto
            }
            if endCovered, endSpan.lowerBound > first {
                let editLast = endSpan.upperBound
                let editEnd = flatOffset(ofRoleAt: editLast) + flatLength(ofRoleAt: editLast)
                var plan = Array(currentRoles[...first])
                plan.append(contentsOf: currentRoles[(editLast + 1)...])
                replaceFlat(NSRange(location: range.location, length: editEnd - range.location), with: inserted, adopting: plan)
                engineSelectedRange = NSRange(location: range.location + inserted.utf16.count, length: 0)
                return .veto
            }
            // Truncate: both endpoints stay their own blocks, the separator kept as the "\n".
            var plan = Array(currentRoles[..<first])
            plan.append(currentRoles[first])
            plan.append(currentRoles[last])
            plan.append(contentsOf: currentRoles[(last + 1)...])
            replaceFlat(range, with: inserted + "\n", adopting: plan)
            engineSelectedRange = NSRange(location: range.location + inserted.utf16.count, length: 0)
            return .veto
        }

        // Merge: one block survives, everything from the first dropped role to the last is gone.
        let editFirst = startCovered ? startSpan.lowerBound : first
        let editLast = endCovered ? endSpan.upperBound : last
        let editStart = startCovered ? flatOffset(ofRoleAt: editFirst) : range.location
        let editEnd = endCovered ? flatOffset(ofRoleAt: editLast) + flatLength(ofRoleAt: editLast) : NSMaxRange(range)
        let survivor: EngineBlockRole
        if !startCovered {
            survivor = currentRoles[first]
        } else if !endCovered {
            survivor = currentRoles[last]
        } else {
            // A MISSING neighbour is no constraint, not a top-level one. Spelt `[]`, the document's
            // first or last role dragged the common ancestry to empty and the survivor came out at
            // top level — so deleting the only photo in a quote replaced it with a TOP-LEVEL
            // paragraph and the quote, left with nothing of its own, collapsed too (device, K3
            // 2026-09-08). The neutral element is the ancestry of whatever HELD the dropped unit:
            // the quote around a dropped child, the PARENT of a dropped quote — which is what keeps
            // select-all over a quote leaving one empty top-level paragraph.
            let previous = editFirst > 0 ? currentRoles[editFirst - 1].ancestry : startHolder
            let next = editLast + 1 < currentRoles.count ? currentRoles[editLast + 1].ancestry : endHolder
            survivor = freshBodyRole(within: Self.commonAncestry(previous, next))
        }
        var plan = Array(currentRoles[..<editFirst])
        plan.append(survivor)
        plan.append(contentsOf: currentRoles[(editLast + 1)...])
        // The text arrives with the first block's face; settle's `normalisePresentation` gives the
        // survivor its own.
        replaceFlat(NSRange(location: editStart, length: editEnd - editStart), with: inserted, adopting: plan)
        engineSelectedRange = NSRange(location: editStart + inserted.utf16.count, length: 0)
        return .veto
    }

    /// Whether a DELETION over `range` removes whole lines and nothing of `last`: it starts at the
    /// first block's offset 0 and ends at `last`'s offset 0. Only for plain lines at the start (a
    /// paragraph of any style or list membership, not a container's second line, a caption or a
    /// cell) and a `last` that is not an atom unit — those keep the rules they have — and whose unit
    /// the range does not drop whole (ending at a quote's AUTHOR line after covering its children
    /// drops the quote, author included, as before).
    ///
    /// Not for the deletion a COMPOSITION starts with: a composition over a selection is typing
    /// (p11), and typing over whole lines takes the first line's role, so the two would disagree on
    /// the same keystroke (fuzz seed 63, p16 fix wave).
    private func deletesWholeLinesBefore(_ last: Int, range: NSRange, text: String, first: Int, headKept: Int,
                                         startCovered: Bool, endCovered: Bool) -> Bool {
        guard text.isEmpty, headKept == 0, !startCovered, !endCovered, first < last,
              !engine.tgid_isResolvingCompositionSelection,
              NSMaxRange(range) == flatOffset(ofRoleAt: last) else { return false }
        guard case .standalone(.paragraph) = currentRoles[first].position else { return false }
        return atomUnitIndex(forRoleAt: last) == nil && currentRoles[last].owningTable == nil
    }

    /// Legacy's keep-and-truncate for media: the range is re-issued as its part OUTSIDE the units it
    /// only enters, plus its part inside each such caption; the atoms are never touched. Segments
    /// are applied last to first so earlier offsets hold; the text goes into the first segment.
    private func truncateAroundMediaUnits(_ range: NSRange, text: String, first: Int, last: Int) -> SurfaceDecision {
        struct Segment { let range: NSRange; let across: (first: Int, last: Int)? }
        var segments: [Segment] = []
        var outsideStart: (offset: Int, index: Int)? = nil
        func closeOutside(before index: Int, at end: Int) {
            guard let open = outsideStart else { return }
            let clipped = NSRange(location: open.offset, length: max(0, end - open.offset))
            segments.append(Segment(range: clipped, across: open.index <= index - 1 ? (open.index, index - 1) : nil))
            outsideStart = nil
        }
        var index = first
        while index <= last {
            if let atom = mediaAtomIndex(forRoleAt: index) {
                let span = containerSpan(containing: atom)
                let headKept = max(0, range.location - flatOffset(ofRoleAt: first))
                let tailKept = max(0, flatOffset(ofRoleAt: last) + flatLength(ofRoleAt: last) - NSMaxRange(range))
                if containerIsCovered(span, first: first, last: last, headKept: headKept, tailKept: tailKept) {
                    // A covered unit belongs to the outside stretch: it is dropped with it.
                    if outsideStart == nil { outsideStart = (max(range.location, flatOffset(ofRoleAt: span.lowerBound)), span.lowerBound) }
                    index = span.upperBound + 1
                    continue
                }
                // Partly covered: close the outside stretch before the unit, clip the caption.
                closeOutside(before: span.lowerBound, at: flatOffset(ofRoleAt: span.lowerBound) - 1)
                if let caption = captionIndex(ofMediaAtomAt: atom), caption >= first, caption <= last {
                    let captionRange = flatRange(ofRoleAt: caption)
                    let clip = NSIntersectionRange(range, captionRange)
                    if clip.length > 0 { segments.append(Segment(range: clip, across: nil)) }
                }
                index = span.upperBound + 1
                continue
            }
            if outsideStart == nil { outsideStart = (max(range.location, flatOffset(ofRoleAt: index)), index) }
            index += 1
        }
        closeOutside(before: last + 1, at: NSMaxRange(range))
        segments.sort { $0.range.location < $1.range.location }
        guard let head = segments.first else { return .veto }
        for segment in segments.reversed() {
            let insert = segment.range.location == head.range.location ? text : ""
            // The text takes the attributes of the range's START, as a replacement between paragraphs
            // and a composition over the same selection do (a stock text view's rule). The segments
            // after the head were cut first, and each cut left the controller's caret — and so the
            // typing attributes the replacement inherits — at ITS end, in the caption: typing across a
            // media unit took the END's formatting (composer harness p15, fuzz seeds 74 and 82,
            // `HarnessTypingIntoCaptionFormattingTests`). Selecting the head segment again puts them
            // back where the user's selection began.
            if !insert.isEmpty {
                engineSelectedRange = segment.range
            } else if segment.range.location == head.range.location, engine.tgid_isResolvingCompositionSelection {
                // A COMPOSITION over the same selection asks with empty text and then types where the
                // head segment was: it must start with the attributes typing gets here, not with the
                // selection's own start, which is an atom or a separator and carries none (composer
                // harness p21, `HarnessCompositionFromMediaStopTests`). Selected the same way, the
                // controller's typing attributes are recorded for the composition to take.
                engineSelectedRange = segment.range
                engine.tgid_noteCompositionTypingAttributesOfSelection()
            }
            if let across = segment.across, across.first != across.last {
                _ = replaceAcrossBlocks(segment.range, text: insert, first: across.first, last: across.last)
            } else if segment.range.length > 0 || !insert.isEmpty {
                replaceFlat(segment.range, with: insert)
            }
        }
        engineSelectedRange = NSRange(location: head.range.location + text.utf16.count, length: 0)
        return .veto
    }

    /// The contiguous roles of the container the role at `index` belongs to.
    internal func containerSpan(containing index: Int) -> ClosedRange<Int> {
        let id = currentRoles[index].containerID
        var lower = index, upper = index
        while lower > 0, currentRoles[lower - 1].containerID == id { lower -= 1 }
        while upper + 1 < currentRoles.count, currentRoles[upper + 1].containerID == id { upper += 1 }
        return lower...upper
    }

    /// The unit a replacement drops at `index`: the OUTERMOST ancestor whose whole span lies inside the
    /// range, else the leaf container (§6.3). A quote wholly inside a selection goes as one thing,
    /// author line and nested containers included, at any depth.
    private func coveredUnit(at index: Int, first: Int, last: Int, headKept: Int, tailKept: Int)
        -> (span: ClosedRange<Int>, covered: Bool, holder: [EngineAncestor]) {
        // The LEAF is asked FIRST when it is a CHILD container — a media unit, a code block, a pull
        // quote, a table. Such a child holds the quote's only primary text, so emptying it also
        // empties the quote by `containerIsCovered`'s test, and an ancestry-first walk judged the
        // QUOTE covered and dropped it along with the child: deleting the only photo in a quote took
        // the quote with it (device, K3 2026-09-08). One level per action — the child goes, the
        // quote stays and keeps an empty paragraph, and a second press dissolves the quote.
        //
        // A quote is NOT asked first: a range that covers a quote's text really should drop the
        // quote, which is what the ancestry walk below decides (§6.3).
        // A line owned by an ANCESTOR container spans that container, not itself: `containerSpan`
        // groups roles sharing a `containerID`, and a details' children carry their OWN ids, so a
        // title's "leaf" came back as just the title. The details then looked partly covered while
        // the quote around it looked wholly covered, and a range over a quoted details dropped the
        // QUOTE.
        let leaf = currentRoles[index].isOwnedByAnAncestorContainer
            ? span(of: currentRoles[index].containerID, around: index)
            : containerSpan(containing: index)
        let leafIsAChildContainer: Bool
        switch currentRoles[index].container {
        case .block(.code), .block(.pullQuote), .block(.media), .block(.buttonRow),
             .block(.collapsedQuote), .table:
            // A button row is a leaf child container exactly as a media atom is: a CHILD of whatever
            // holds it, so a range that empties it must not be read as emptying its parent. A FOLDED
            // quote joins them: it is an atom that is a child of whatever holds it. Note this is NOT
            // the same answer as `.blockQuote` below — that case is an OPEN quote's own line, where
            // the container IS the parent.
            leafIsAChildContainer = true
        // A details is asked first for the same reason the others are: it is a CHILD of the container
        // around it, so emptying it must not be read as emptying its parent.
        case .details: leafIsAChildContainer = true
        case .block(.paragraph), .blockQuote: leafIsAChildContainer = false
        }
        //
        // `holder` is the ancestry of whatever HELD the dropped unit — where a survivor replacing it
        // belongs. Dropping a child container leaves the survivor in the quote around it; dropping
        // the QUOTE leaves it in the quote's parent.
        if leafIsAChildContainer,
           containerIsCovered(leaf, first: first, last: last, headKept: headKept, tailKept: tailKept) {
            // The HOLDER is where a survivor replacing this unit belongs. For a leaf child container
            // (a code block, a media unit) that is the role's own ancestry — the container is not in
            // it. For an ancestor-owned line the container IS in the ancestry, so drop it.
            let holder = currentRoles[index].isOwnedByAnAncestorContainer
                ? Array(currentRoles[index].ancestry.dropLast())
                : currentRoles[index].ancestry
            return (leaf, true, holder)
        }
        // A DETAILS in the ancestry is checked INNERMOST-first, and before any quote outside it,
        // because a details is a CHILD container of whatever holds it — the same reason the leaf is
        // asked first above. The leaf test cannot catch it: the range's edge sits in a PARAGRAPH that
        // is the details' child, so the leaf is that paragraph, and the outermost-first walk below
        // then found the enclosing quote and dropped it too.
        //
        // Restricted to `.details` deliberately. Quote-in-quote keeps outermost-first, where a range
        // covering a nested quote's content drops the outer one as well — shipped and K3-verified, and
        // not this rung's to change.
        for ancestor in currentRoles[index].ancestry.reversed() where ancestor.details != nil {
            let span = span(of: ancestor.id, around: index)
            if containerIsCovered(span, first: first, last: last, headKept: headKept, tailKept: tailKept) {
                let parent = Array(currentRoles[index].ancestry.prefix { $0.id != ancestor.id })
                return (span, true, parent)
            }
        }
        for ancestor in currentRoles[index].ancestry {
            let span = span(of: ancestor.id, around: index)
            if containerIsCovered(span, first: first, last: last, headKept: headKept, tailKept: tailKept) {
                let parent = Array(currentRoles[index].ancestry.prefix { $0.id != ancestor.id })
                return (span, true, parent)
            }
        }
        return (leaf, false, currentRoles[index].ancestry)
    }

    private func isLeafContainer(_ role: EngineBlockRole) -> Bool {
        if case let .block(shape) = role.container { return isLeafBody(shape) }
        return false
    }

    /// A code block, a pull quote, a media atom, a button row, a block quote, a details or a table —
    /// what a range can drop whole. A paragraph is its own survivor.
    ///
    /// A button row needs no branch in `containerIsCovered` below, unlike media: its span is a single
    /// role, so the generic path's `head >= first && tail <= last` plus the two kept-guards is already
    /// the caption-less atom's rule. Media's branch exists for its CAPTION, which a row does not have.
    /// A FOLDED quote is the row's case exactly — one role, no companion line — so it needs no branch
    /// there either.
    private func isContainer(_ role: EngineBlockRole) -> Bool {
        switch role.container {
        case .block(.code), .block(.pullQuote), .block(.media), .block(.buttonRow),
             .block(.collapsedQuote), .blockQuote, .details, .table: return true
        case .block(.paragraph): return false
        }
    }

    /// Whether the container loses everything the range can take from it. For every container but
    /// media that is its PRIMARY blocks losing all their text. For media it is the atom being inside
    /// the range AND no caption text surviving — a range that stops short of the caption's end, or
    /// starts after its beginning, keeps the unit and truncates the caption instead (§5.3).
    internal func containerIsCovered(_ span: ClosedRange<Int>, first: Int, last: Int, headKept: Int, tailKept: Int) -> Bool {
        if case .block(.media) = currentRoles[span.lowerBound].container, span == containerSpan(containing: span.lowerBound) {
            let atom = span.lowerBound
            guard atom >= first, atom <= last else { return false }
            if atom == first, headKept > 0 { return false }
            if atom == last, tailKept > 0 { return false }
            if let caption = captionIndex(ofMediaAtomAt: atom), caption >= first, caption <= last {
                if caption == first, headKept > 0 { return false }
                if caption == last, tailKept > 0 { return false }
            }
            return true
        }
        // A quote's AUTHOR and a code block's LANGUAGE are fields: they do not keep their container
        // alive, so they are not counted. A details' TITLE is authored content (decision 5) and IS —
        // counted only as primaries, a range over the body alone reported the whole details covered
        // and took a title the selection never reached. It is also the only role a FOLDED details
        // has, so without it such a details reported itself never covered and survived Select All
        // with its hidden body still in the model.
        let counted = span.filter {
            currentRoles[$0].secondaryKind == nil || currentRoles[$0].secondaryKind == .detailsTitle
        }
        guard let head = counted.first, let tail = counted.last, head >= first, tail <= last else { return false }
        if head == first, headKept > 0 { return false }
        if tail == last, tailKept > 0 { return false }
        return true
    }

    /// Installs a positional role plan WITHOUT an edit (a fresh block declared a quote child, an
    /// empty leading child declared a paragraph). An edit that changes structure carries its plan
    /// instead (`replaceFlat(_:with:adopting:)`). A count that does not match the engine's is a
    /// programming error in a rule — asserted in debug, a rebuild by identity with a log in
    /// release. Every identity is recorded, so a later rebuild by identity reproduces the plan.
    internal func adoptRolePlan(_ plan: [EngineBlockRole]) {
        let identifiers = engine.tgid_blockIdentifiers
        let before = currentRoles
        if plan.count == identifiers.count {
            currentRoles = plan
        } else {
            assertionFailure("RichTextEngineEditor: role plan expected \(plan.count) blocks, engine has \(identifiers.count)")
            NSLog("RichTextEngineEditor: role plan expected %ld blocks, engine has %ld — rebuilt by identity", plan.count, identifiers.count)
            currentRoles = bridge.roles(for: identifiers, reusingStructureOf: structureByEngineIdentityForResolver)
        }
        recordBlockIdentitiesForResolver(identifiers)
        for identifier in identifiers { freshSinceSettle.remove(identifier) }
        // PRESENTATION IS DERIVED FROM THE ROLE, so a role that changed here has a presentation that
        // is now stale, and marking it is this function's job rather than each caller's.
        //
        // It was each caller's, and they upheld it by four different accidents: the block was empty
        // and rendered by the empty-line providers; the field that changed did not affect the style;
        // the block happened to be in `touchedSinceSettle` from the edit anyway. The first call site
        // where none of them applied shipped a list item whose bullet outdented and whose text did
        // not (device, 2026-09-05). A rule that can only be followed by remembering is not a rule.
        // A role that changed here has a presentation that is now stale, so mark it: the next
        // `normalisePresentation` re-derives it.
        //
        // MEASURED NOT LOAD-BEARING TODAY, and recorded as such rather than dressed up. With this
        // removed the suite is still green and the derived-presentation check still reports zero
        // drift, because every path that changes a role now SETTLES (`performHostStructuralChange`)
        // and the blocks involved are already marked by the funnel for other reasons. It is kept
        // because that is a property of today's call sites, not of this function: marking here is
        // what makes "a changed role has a stale presentation" true at the one place roles change,
        // instead of true only while every caller happens to be covered by something else.
        for (index, identifier) in identifiers.enumerated() where index < currentRoles.count {
            if index >= before.count || before[index] != currentRoles[index] {
                touchedSinceSettle.insert(identifier)
            }
        }

        syncTableFrames()
        syncContainerBlockInsets()
        structureTouchedThisEdit = true
    }
}
#endif
