import XCTest
import UIKit
import TelegramCore
import HarnessAppContext
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend a HARDWARE-keyboard Return (or ⌘-Return with "Send with
/// ⌘-Enter") can never send the message: it always inserts a paragraph break. The composer wires the
/// decision — `RichTextEditorChatInputNode` sets `editorView.onHardwareReturn` to the panel's
/// `chatInputTextNodeShouldReturn(modifierFlags:)` — but the engine never consults it: nothing in
/// the responder chain from the engine's text view offers a Return key command, and
/// `onHardwareReturn` is stored in `composerHostState` and read by nobody.
///
/// Legacy offers `\r` and `⌘\r` key commands on `ChatInputTextViewImpl` (`handleReturn:` →
/// `shouldReturn`), and the previous rich canvas had its own (`DocumentCanvasView.performHardwareReturn`
/// → `onHardwareReturn`); the node's comment ("Without this a hardware Return just inserted a
/// paragraph break and never sent") describes exactly what the engine does today.
///
/// **How it was seen.** p11 roam, 2026-09-24: enumerating `keyCommands` up the engine view's
/// responder chain (only the list/table/details Tab commands, and none at all in a paragraph), then
/// `grep onHardwareReturn` in `RichTextEngineEditor` (definitions only). XCUITest `typeKey(.return)`
/// is not a usable oracle in the harness (it delivered nothing observable on either backend).
///
/// **Suspected cause.** `RichTextEngineEditorView.keyCommands` (`+TableEditing.swift`) has no Return
/// command, and `onHardwareReturn` (`+ComposerHost.swift`) has no reader.
///
/// **Tier 1**: a hardware Return is delivered to the first key command in the responder chain that
/// claims it; the test finds and performs it exactly as UIKit would.
@available(iOS 18.4, *)
final class HarnessHardwareReturnTests: XCTestCase {
    /// The first responder in the chain (text view upward, stopping at the window) that offers a
    /// key command for `\r` with `modifiers`, and that command.
    private func returnCommand(from view: UIView, modifiers: UIKeyModifierFlags) -> (UIResponder, UIKeyCommand)? {
        var responder: UIResponder? = view
        while let current = responder, !(current is UIWindow) {
            if let command = current.keyCommands?.first(where: { $0.input == "\r" && $0.modifierFlags == modifiers }) {
                return (current, command)
            }
            responder = current.next
        }
        return nil
    }

    func testAHardwareReturnReachesTheComposersSendDecision() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText("hello"))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        var editorView: UIView? = textView
        while let candidate = editorView, !(candidate is RichTextEngineEditorView) { editorView = candidate.superview }
        let editor = try XCTUnwrap(editorView as? RichTextEngineEditorView)
        XCTAssertNotNil(editor.onHardwareReturn, "precondition: the composer no longer wires onHardwareReturn")

        let saved = editor.onHardwareReturn
        var consulted: [UIKeyModifierFlags] = []
        editor.onHardwareReturn = { flags in
            consulted.append(flags)
            return true
        }
        defer { editor.onHardwareReturn = saved }

        for modifiers: UIKeyModifierFlags in [[], .command] {
            guard let (responder, command) = self.returnCommand(from: textView, modifiers: modifiers) else {
                XCTFail("nothing in the engine's responder chain claims a hardware Return (modifiers \(modifiers.rawValue)), so it can never send")
                continue
            }
            _ = responder.perform(try XCTUnwrap(command.action), with: command)
            HarnessEngine.settle(root)
        }
        XCTAssertEqual(consulted, [[], .command], "a hardware Return did not consult onHardwareReturn")
    }

    /// When the composer declines to send (its handler answers "insert a newline"), the hardware
    /// Return is typed exactly as the keyboard's Return: in a paragraph, in a table cell (a caret move
    /// between cells) and in a code block, the model after the key command equals the model after
    /// `insertText("\n")` from the same state. Written with the fix (2026-09-24).
    func testADeclinedHardwareReturnTypesTheKeyboardsReturn() throws {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Top line"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Val")]),
                ChatInputTableRow(cells: [cell("a"), cell("1")]),
            ])),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x")])),
        ])
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let flatLength = { () -> Int in
            host.setInputContent(start)
            HarnessEngine.settle(root)
            return (node.currentInputContent().content.plainText as NSString).length
        }()
        for caret in [3, 8, 11, 14, flatLength - 1] {
            var results: [String] = []
            for viaKeyCommand in [true, false] {
                host.setInputContent(start)
                HarnessEngine.settle(root)
                node.selectedRange = NSRange(location: caret, length: 0)
                HarnessEngine.settle(root)
                let textView = try HarnessEngine.textView(in: root)
                if viaKeyCommand {
                    var editorView: UIView? = textView
                    while let candidate = editorView, !(candidate is RichTextEngineEditorView) { editorView = candidate.superview }
                    let editor = try XCTUnwrap(editorView as? RichTextEngineEditorView)
                    let saved = editor.onHardwareReturn
                    editor.onHardwareReturn = { _ in true }
                    defer { editor.onHardwareReturn = saved }
                    let (responder, command) = try XCTUnwrap(self.returnCommand(from: textView, modifiers: []), "no Return key command at caret \(caret)")
                    _ = responder.perform(try XCTUnwrap(command.action), with: command)
                } else {
                    (textView as? UITextInput)?.insertText("\n")
                }
                HarnessEngine.settle(root)
                let content = node.currentInputContent()
                results.append("\(FuzzModel.describe(content.content)) sel=\(node.selectedRange)")
            }
            XCTAssertEqual(results[0], results[1], "caret \(caret): a declined hardware Return did not type the keyboard's Return")
        }
    }

    /// Control: the legacy composer's text view claims both Returns.
    func testControlLegacyClaimsTheHardwareReturn() throws {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        let host = try XCTUnwrap(root.panelHost)
        let node = try XCTUnwrap(host.panel.richTextInputNode)
        host.setInputContent(HarnessContent.plainText("hello"))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        var textView: UITextView?
        func find(_ view: UIView) {
            if textView == nil, let candidate = view as? UITextView { textView = candidate }
            view.subviews.forEach(find)
        }
        find(host.panel.view)
        let legacyView = try XCTUnwrap(textView, "precondition: no legacy text view")
        XCTAssertNotNil(self.returnCommand(from: legacyView, modifiers: []), "control: legacy no longer claims Return")
        XCTAssertNotNil(self.returnCommand(from: legacyView, modifiers: .command), "control: legacy no longer claims ⌘-Return")
    }
}
