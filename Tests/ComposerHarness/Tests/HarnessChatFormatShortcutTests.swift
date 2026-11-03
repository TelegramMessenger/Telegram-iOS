import XCTest
import UIKit
import TelegramCore
import AccountContext
import ChatInputTextNode
import ChatPresentationInterfaceState
import TextFormat
@testable import ComposerHarnessLib

/// **What broke.** With the engine composer focused, the chat's hardware-keyboard format shortcuts —
/// ⌘B, ⌘I, ⌘U, ⇧⌘M (monospace), ⇧⌘X (strikethrough), ⇧⌘P (spoiler) and ⇧⌘N (clear formatting) —
/// rebuild the WHOLE composer through the `NSAttributedString` compat currency, which has no
/// vocabulary for most of what the engine holds:
///
///     [h1 "Title"] [p "body text"], select "body", ⌘B   → [p "Title"] [p [b]"body" " text"]
///     [bullet "one"] [bullet "two"], select "one", ⌘B    → [p [b]"one"] [p "two"]        (list gone)
///     [p "Intro"] [pull "Pulled" author "Ann"], ⌘B       → [p [b]"Intro"] [quote "Pulled"] (author gone)
///     [p "T"] [table …] [p "after"], select "T", ⌘B      → [p [b]"T"] [p "after"]        (TABLE deleted)
///     [p "D"] [details "Sum" / "body"] [p "after"], ⌘B    → [p [b]"D"] [p "after"]        (details deleted)
///
/// The edit is also not an undo step of its own: type "x", ⌘B, ⌘Z → both the bold AND the "x" are
/// gone, because the result arrives as a host document set (a new baseline) and one undo then
/// reverts to the snapshot before the typing. The Format menu's Bold on the same selections keeps
/// every block and undoes by itself (control).
///
/// **How it was seen.** p11 roam, 2026-09-24, reading the key-command surface: the engine view
/// declares no format key commands (`RichTextEngineEditorView+TableEditing.swift`, `keyCommands`:
/// Tab / Shift-Tab / Shift-Return only; `toggleBoldface:` & co. are not implemented either), so a
/// hardware ⌘B reaches `KeyShortcutsController` and the chat's own shortcut. The harness has no
/// `ChatController`, so this test runs that shortcut's action verbatim through the panel's
/// `updateTextInputStateAndMode` (what `ChatControllerKeyShortcuts.swift` does) — the chat half is
/// reproduced, the composer half is real.
///
/// **Suspected cause.** `ChatControllerKeyShortcuts.swift:29-83` applies
/// `chatTextInputAddFormattingAttribute(current, …)` / `chatTextInputClearFormattingAttributes`,
/// which read `state.inputText` and rebuild with `ChatTextInputState(inputText:selectionRange:)` —
/// the round trip `ChatTextInputState.inputText`'s own doc comment says destroys block structure.
/// The legacy rich canvas had its own ⌘B/⌘I/⌘U/⇧⌘X/⇧⌘M key commands (`DocumentCanvasView.swift`,
/// `keyToggleBold` …) that went through the editor's commands; the engine has none, and the
/// chat does not route the shortcuts to `performFormatAction` for a native node.
///
/// **Fixed (2026-09-24).** Each format shortcut now asks the panel first
/// (`ChatTextInputPanelNode.performNativeFormatShortcut`), which on the native engine runs the
/// Format menu's own command (`performFormatAction`; ⇧⌘N is `.clearFormatting`,
/// `RichTextEngineEditorView.clearInlineFormatting`) and returns true; the legacy backend returns
/// false and keeps the input-state path unchanged. The mirrors below were updated to the new
/// shortcut actions verbatim.
///
/// **Tier 1**: the shortcut's action is plain Swift; the panel and composer are the real ones.
final class HarnessChatFormatShortcutTests: XCTestCase {
    private func setUp(_ content: ChatInputContent, select range: NSRange) throws -> (HarnessRootViewController, HarnessPanelHost, ChatRichTextInputNode) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(content)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        node.selectedRange = range
        HarnessEngine.settle(root)
        XCTAssertEqual(host.interfaceState.interfaceState.effectiveInputState.selectionRange, range.location ..< NSMaxRange(range),
                       "precondition: the chat's copy of the selection is not the composer's")
        return (root, host, node)
    }

    /// Exactly the ⌘B `KeyShortcut` action in `ChatControllerKeyShortcuts.swift` (`chatDisplayNode.
    /// textInputPanelNode` is the harness's `host.panel`). The panel is asked first; the input-state
    /// closure below it is the legacy backend's path, unchanged.
    private func commandB(_ host: HarnessPanelHost, _ root: HarnessRootViewController) {
        defer { HarnessEngine.settle(root) }
        if host.panel.performNativeFormatShortcut(.bold) == true {
            return
        }
        host.panel.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.bold, value: nil), inputMode)
        }
    }

    /// Exactly the ⇧⌘N (clear formatting) `KeyShortcut` action in `ChatControllerKeyShortcuts.swift`.
    private func shiftCommandN(_ host: HarnessPanelHost, _ root: HarnessRootViewController) {
        defer { HarnessEngine.settle(root) }
        if host.panel.performNativeFormatShortcut(.clearFormatting) == true {
            return
        }
        host.panel.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputClearFormattingAttributes(current), inputMode)
        }
    }

    private func headingDocument() -> ChatInputContent {
        return ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")])),
            HarnessEngine.paragraph("body text"),
        ])
    }

    func testCommandBKeepsAHeading() throws {
        let (root, host, node) = try self.setUp(self.headingDocument(), select: NSRange(location: 6, length: 4))
        defer { _ = node.resignInputFirstResponder() }
        self.commandB(host, root)
        let content = node.currentInputContent().content
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "body", "precondition: ⌘B did not bold the selection: \(FuzzModel.describe(content))")
        guard case let .paragraph(first)? = content.blocks.first else { return XCTFail("no first block: \(FuzzModel.describe(content))") }
        XCTAssertEqual(first.style, .heading1, "⌘B elsewhere demoted the heading to body: \(FuzzModel.describe(content))")
    }

    func testCommandBKeepsATable() throws {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("T"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Val")]),
                ChatInputTableRow(cells: [cell("a"), cell("1")]),
            ])),
            HarnessEngine.paragraph("after"),
        ])
        let (root, host, node) = try self.setUp(start, select: NSRange(location: 0, length: 1))
        defer { _ = node.resignInputFirstResponder() }
        self.commandB(host, root)
        let content = node.currentInputContent().content
        XCTAssertTrue(content.blocks.contains { if case .table = $0 { return true } else { return false } },
                      "⌘B on the paragraph above deleted the table: \(FuzzModel.describe(content))")
    }

    func testCommandBKeepsAListAndAPullQuoteAuthor() throws {
        let list = ChatInputListMembership(marker: .bullet, level: 0)
        let start = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: list, runs: [ChatInputRun(text: "one")])),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Pulled")], author: [ChatInputRun(text: "Ann")])),
        ])
        let (root, host, node) = try self.setUp(start, select: NSRange(location: 0, length: 3))
        defer { _ = node.resignInputFirstResponder() }
        self.commandB(host, root)
        let content = node.currentInputContent().content
        guard case let .paragraph(first)? = content.blocks.first else { return XCTFail("no first block: \(FuzzModel.describe(content))") }
        XCTAssertEqual(first.list, list, "⌘B on a list item took it out of the list: \(FuzzModel.describe(content))")
        guard content.blocks.count == 2, case let .pullQuote(quote) = content.blocks[1] else {
            return XCTFail("⌘B elsewhere turned the pull quote into something else: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Ann", "⌘B elsewhere dropped the pull quote's author: \(FuzzModel.describe(content))")
    }

    func testCommandBIsAnUndoStepOfItsOwn() throws {
        let (root, host, node) = try self.setUp(HarnessContent.plainText("First paragraph."), select: NSRange(location: 16, length: 0))
        defer { _ = node.resignInputFirstResponder() }
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        view.undoManager?.removeAllActions()
        view.insertText("x")
        HarnessEngine.settle(root)
        node.selectedRange = NSRange(location: 0, length: 5)
        HarnessEngine.settle(root)
        self.commandB(host, root)
        XCTAssertEqual(HarnessLegacy.text(in: node.currentInputContent().content, where: { $0.bold }), "First", "precondition: ⌘B did not bold")
        view.undoManager?.undo()
        HarnessEngine.settle(root)
        let content = node.currentInputContent().content
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "", "undo did not revert ⌘B")
        XCTAssertEqual(content.plainText, "First paragraph.x", "one undo after ⌘B also took back the typing before it")
    }

    /// ⇧⌘N on the engine clears the selection's inline marks, keeps the heading and the table after it,
    /// and is one undo step. Written with the fix (2026-09-24): before it, ⇧⌘N took the same
    /// input-state rebuild as ⌘B above.
    func testShiftCommandNClearsMarksKeepsBlocksAndIsOneStep() throws {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let marked = ChatInputInlineAttributes(bold: true, italic: true, monospace: true, strikethrough: true, underline: true, spoiler: true)
        let start = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")])),
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "body", attributes: marked), ChatInputRun(text: " text")])),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Val")]),
                ChatInputTableRow(cells: [cell("a"), cell("1")]),
            ])),
        ])
        let (root, host, node) = try self.setUp(start, select: NSRange(location: 6, length: 4))
        defer { _ = node.resignInputFirstResponder() }
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        view.undoManager?.removeAllActions()
        let before = node.currentInputContent().content
        self.shiftCommandN(host, root)
        let content = node.currentInputContent().content
        let described = FuzzModel.describe(content)
        guard case let .paragraph(first)? = content.blocks.first else { return XCTFail("no first block: \(described)") }
        XCTAssertEqual(first.style, .heading1, "⇧⌘N demoted the heading: \(described)")
        XCTAssertTrue(content.blocks.contains { if case .table = $0 { return true } else { return false } }, "⇧⌘N deleted the table: \(described)")
        guard content.blocks.count > 1, case let .paragraph(body) = content.blocks[1] else { return XCTFail("no body paragraph: \(described)") }
        XCTAssertEqual(body.runs.map(\.text).joined(), "body text", described)
        XCTAssertTrue(body.runs.allSatisfy { $0.attributes == ChatInputInlineAttributes() }, "⇧⌘N left a mark: \(described)")
        view.undoManager?.undo()
        HarnessEngine.settle(root)
        let undone = node.currentInputContent().content
        XCTAssertEqual(undone, before, "one undo did not restore the marks: \(FuzzModel.describe(undone))")
    }

    /// Control: the Format menu's Bold on the same heading document keeps the heading.
    func testControlFormatMenuBoldKeepsAHeading() throws {
        let (root, _, node) = try self.setUp(self.headingDocument(), select: NSRange(location: 6, length: 4))
        defer { _ = node.resignInputFirstResponder() }
        node.performFormatAction(.bold)
        HarnessEngine.settle(root)
        let content = node.currentInputContent().content
        guard case let .paragraph(first)? = content.blocks.first else { return XCTFail("no first block") }
        XCTAssertEqual(first.style, .heading1, "control: \(FuzzModel.describe(content))")
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "body", "control: \(FuzzModel.describe(content))")
    }
}
