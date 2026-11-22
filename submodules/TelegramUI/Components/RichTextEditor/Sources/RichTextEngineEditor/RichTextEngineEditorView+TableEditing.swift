#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// How the keyboard behaves inside a table cell. The engine knows nothing of cells: Return splits
/// a block, backspace at a block's start merges it, a range replace merges across blocks. Each of
/// those is caught here — before the engine acts (backspace, through the first-refusal handler)
/// or after it (Return, paste, cross-cell replace, through the funnel's repairs).
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    internal var caretCellIndex: Int? {
        let selection = engineSelectedRange
        guard selection.length == 0, let index = roleIndex(atFlatOffset: selection.location),
              currentRoles[index].owningTable != nil else { return nil }
        return index
    }

    // MARK: - Caret travel

    internal func moveCaretToCell(after index: Int) {
        // The two questions this rule has always asked, now asked once and answered by the type: is
        // the next role another cell of MY table, and if not, is it a sibling of the table at all.
        //
        // Getting the second one wrong twice is why the type exists. A quote's AUTHOR line is not a
        // block after the table — it is the quote's own field — and the role after a table that is a
        // DETAILS' last body item is the block FOLLOWING the details, outside it entirely. Both were
        // "is there a next role", which cannot tell either from a sibling.
        switch neighbour(after: index) {
        case let .sameLeafContainer(next):
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: next), length: 0)
        case let .sibling(next):
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: next), length: 0)
        case .ownLineOfEnclosingContainer, .outsideContainer, .documentEdge:
            // A fresh paragraph where the table's own container ends. A controller edit, so it is
            // undoable like any typing, and a declared role. INSERTED at `index + 1` rather than
            // appended: inside a quote the end of the role list is past the author line, which would
            // put the new paragraph outside the quote.
            let end = flatOffset(ofRoleAt: index) + flatLength(ofRoleAt: index)
            var plan = currentRoles
            plan.insert(freshBodyRole(within: currentRoles[index].ancestry), at: index + 1)
            replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
            engineSelectedRange = NSRange(location: end + 1, length: 0)
        }
    }

    internal func moveCaretToCell(before index: Int) {
        switch neighbour(before: index) {
        case let .sameLeafContainer(previous), let .sibling(previous):
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: previous) + flatLength(ofRoleAt: previous), length: 0)
        case let .ownLineOfEnclosingContainer(line):
            // A details' TITLE is where the caret belongs when Backspace walks off its first body
            // child — the documented wall. A quote has no leading own line, so this arm is the
            // details case in practice.
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: line) + flatLength(ofRoleAt: line), length: 0)
        case let .outsideContainer(_, beyond):
            // DECIDED 2026-09-08: with no leading own line there is nothing INSIDE the container to
            // travel to, so the caret leaves it. A quote has no such line; a details has its TITLE,
            // which is the arm above. The two used to differ only because of where `index - 1`
            // happened to land — the same answer, arrived at by accident — and stating it as two
            // arms is what makes it a rule rather than a coincidence.
            guard let beyond else { return }
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: beyond) + flatLength(ofRoleAt: beyond), length: 0)
        case .documentEdge:
            return
        }
    }

    /// Tab. Past the last cell of a trailing table this appends a paragraph, which is a structural
    /// edit issued from OUTSIDE the gate — framed as one (`performHostStructuralEdit`) so the gate
    /// does not read its "\n" as a Return in a cell and decide it again.
    public func moveCaretToNextTableCell() {
        guard let cell = caretCellIndex else { return }
        performHostStructuralEdit { moveCaretToCell(after: cell) }
        deliverChangeNotificationNow()
    }

    public func moveCaretToPreviousTableCell() {
        guard let cell = caretCellIndex, case let .sameLeafContainer(previous) = neighbour(before: cell) else { return }
        engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: previous), length: 0)
        deliverChangeNotificationNow()
    }

    /// Shift+Return: a newline INSIDE the cell — the engine's line separator, through its own
    /// insert, so it is an ordinary undoable keystroke.
    public func insertTableCellNewline() {
        guard caretCellIndex != nil else { return }
        engine.insertText(EngineDocumentBridge.lineSeparator)
    }

    /// Tab means different things in the three places it means anything: it travels between CELLS in
    /// a table, nests a LIST item one level deeper, and steps OUT of a details — from its title into
    /// its body, and from its body to the block after the block. A caret in none of them leaves Tab
    /// to the system. Shift-Tab is deliberately not claimed inside a details: from the title there is
    /// nothing above to go to, and from the body the title is one Shift-Tab-shaped guess too many.
    public override var keyCommands: [UIKeyCommand]? {
        let commands = structuralKeyCommands + hardwareReturnKeyCommands
        return commands.isEmpty ? nil : commands
    }

    private var structuralKeyCommands: [UIKeyCommand] {
        if caretCellIndex != nil {
            let tab = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTableTab(_:)))
            let shiftTab = UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(handleTableShiftTab(_:)))
            let shiftReturn = UIKeyCommand(input: "\r", modifierFlags: .shift, action: #selector(handleTableShiftReturn(_:)))
            for command in [tab, shiftTab, shiftReturn] { command.wantsPriorityOverSystemBehavior = true }
            return [tab, shiftTab, shiftReturn]
        }
        if caretListItemIndex != nil {
            let tab = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleListTab(_:)))
            let shiftTab = UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(handleListShiftTab(_:)))
            for command in [tab, shiftTab] { command.wantsPriorityOverSystemBehavior = true }
            return [tab, shiftTab]
        }
        if caretIsInsideADetails {
            let tab = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleDetailsTab(_:)))
            tab.wantsPriorityOverSystemBehavior = true
            return [tab]
        }
        return []
    }

    /// A HARDWARE Return and ⌘-Return, claimed only when a host decides what Return means
    /// (`onHardwareReturn` — the chat composer's send-on-Enter / send-on-⌘-Enter setting). Mirrors the
    /// legacy composer's `ChatInputTextViewImpl` (`\r` and `⌘\r` → `handleReturn:` → `shouldReturn`).
    /// Without these nothing in the responder chain claimed Return, `onHardwareReturn` had no reader,
    /// and a hardware Return could only ever insert a paragraph break (`HarnessHardwareReturnTests`).
    /// A host that sets no handler (the article editor) keeps the system's Return untouched.
    private var hardwareReturnKeyCommands: [UIKeyCommand] {
        guard onHardwareReturn != nil else { return [] }
        return [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleHardwareReturn(_:))),
            UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(handleHardwareReturn(_:))),
        ]
    }

    /// The host decides first; when it declines (returns true: "insert a newline") the Return is typed
    /// exactly as the keyboard's would be — `insertText("\n")` on the gated surface — so a Return in a
    /// cell, a code body, a list item or a quote keeps every rule the surface gate applies to it. A
    /// Return while a composition is open commits it, as an IME's Return does, and neither sends nor
    /// breaks the line: the text is the IME's until it commits.
    @objc private func handleHardwareReturn(_ sender: UIKeyCommand) {
        if engine.markedTextRange != nil {
            finalizeComposerMarkedText()
            return
        }
        if onHardwareReturn?(sender.modifierFlags) ?? true {
            engine.insertText("\n")
        }
    }

    /// Whether the caret is anywhere inside a details — its title or its body. Checked LAST, so a
    /// cell or a list item inside a details keeps the table's and the list's meanings of Tab.
    private var caretIsInsideADetails: Bool {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location) else { return false }
        return currentRoles[index].innermostAncestor?.details != nil
    }

    @objc private func handleTableTab(_ sender: UIKeyCommand) { moveCaretToNextTableCell() }
    @objc private func handleTableShiftTab(_ sender: UIKeyCommand) { moveCaretToPreviousTableCell() }
    @objc private func handleTableShiftReturn(_ sender: UIKeyCommand) { insertTableCellNewline() }
    @objc private func handleListTab(_ sender: UIKeyCommand) { indent() }
    @objc private func handleListShiftTab(_ sender: UIKeyCommand) { outdent() }
    @objc private func handleDetailsTab(_ sender: UIKeyCommand) { moveCaretOutOfDetails() }
}
#endif
