import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, deleting or typing over a selection that starts in a
/// paragraph and ends inside (or at the start of) a following BLOCK QUOTE leaves the caret at the END
/// of the text instead of at the edit. The next keystroke therefore lands in the wrong place:
///
///     [p "First paragraph."] [quote "Second paragraph."]
///     select 5..<25 → type "X" → type "Q"
///       engine: "FirstXaragraph.Q", caret 16       legacy: caret after X, "FirstXQaragraph."
///     select 5..<25 → Backspace   engine caret 14 (end)   legacy caret 5
///     select 5..<17 → Backspace   engine caret 22 (end)   legacy caret 5
///
/// The same selections ending in a CODE block or a PULL QUOTE, and across two plain paragraphs, leave
/// the caret at 5 (controls below). The text itself is right since the cross-delete fix
/// (`HarnessQuoteCrossDeleteTests`); only the caret is wrong.
///
/// **How it was seen.** K1, 2026-09-23, fifth roam (regression sweep of the cross-delete fix): the
/// quote made with Format ▸ Quote, the selection and the edit sent to the engine text view's
/// `UITextInput`/`UIKeyInput` through lldb. Seen for 5..<25 Backspace ×2, 5..<17 Backspace ×1,
/// 5..<25 typing ×1 (then a second keystroke appended at the end). A screenshot shows the caret
/// after "Firstaragraph.". Legacy control (its own `formatAttributesQuote:`, same selection,
/// Backspace): caret 5.
///
/// **Suspected cause.** A side effect of the cross-delete fix: `settleOrphanedSecondaryLines` removes
/// the dissolved quote's empty author line with its separator after the edit has placed the caret,
/// and the selection is not mapped through that removal (it is clamped to the end of the document).
///
/// **Tier 1**: the selection and the edit are the calls the keyboard makes, and the caret is readable
/// in-process.
final class HarnessQuoteCrossDeleteCaretTests: XCTestCase {
    private enum Container {
        case quote, code, pullQuote, paragraph
    }

    private func second(_ container: Container) -> ChatInputBlock {
        switch container {
        case .quote:
            return .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [HarnessEngine.paragraph("Second paragraph.")]),
                collapsed: false))
        case .code:
            return .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "Second paragraph.")]))
        case .pullQuote:
            return .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Second paragraph.")]))
        case .paragraph:
            return HarnessEngine.paragraph("Second paragraph.")
        }
    }

    /// Arranges `[p "First paragraph."] [container "Second paragraph."]`, selects `selection`, and
    /// applies each edit in turn (nil = Backspace). Returns the plain text and the caret afterwards.
    private func edit(_ container: Container, selection: NSRange, _ edits: [String?]) throws -> (text: String, caret: NSRange) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(ChatInputContent(blocks: [HarnessEngine.paragraph("First paragraph."), self.second(container)]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = selection
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, selection, "precondition: the selection did not land")

        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        for edit in edits {
            if let edit {
                keyInput.insertText(edit)
            } else {
                keyInput.deleteBackward()
            }
            HarnessEngine.settle(root)
        }
        let text = node.currentInputContent().content.plainText.replacingOccurrences(of: "\n", with: "")
        let caret = node.selectedRange
        _ = node.resignInputFirstResponder()
        return (text, caret)
    }

    func testBackspaceOverASelectionEndingInsideAQuoteLeavesTheCaretAtTheEdit() throws {
        let result = try self.edit(.quote, selection: NSRange(location: 5, length: 20), [nil])
        XCTAssertEqual(result.text, "Firstaragraph.", "precondition: the edit removed the wrong text")
        XCTAssertEqual(result.caret, NSRange(location: 5, length: 0), "the caret jumped away from the deletion")
    }

    func testBackspaceOverASelectionEndingAtTheQuoteStartLeavesTheCaretAtTheEdit() throws {
        let result = try self.edit(.quote, selection: NSRange(location: 5, length: 12), [nil])
        XCTAssertEqual(result.text, "FirstSecond paragraph.", "precondition: the edit removed the wrong text")
        XCTAssertEqual(result.caret, NSRange(location: 5, length: 0), "the caret jumped away from the deletion")
    }

    func testTheNextKeystrokeAfterTypingOverASelectionEndingInsideAQuoteLandsAtTheCaret() throws {
        let result = try self.edit(.quote, selection: NSRange(location: 5, length: 20), ["X", "Q"])
        XCTAssertEqual(result.text, "FirstXQaragraph.", "the second keystroke did not land after the first")
        XCTAssertEqual(result.caret, NSRange(location: 7, length: 0))
    }

    /// Controls: the same deletion ending in the other containers, or in a plain paragraph.
    func testControlBackspaceIntoACodeBlockPullQuoteOrParagraphLeavesTheCaretAtTheEdit() throws {
        for container in [Container.code, .pullQuote, .paragraph] {
            let result = try self.edit(container, selection: NSRange(location: 5, length: 20), [nil])
            XCTAssertEqual(result.caret, NSRange(location: 5, length: 0), "control \(container): caret moved")
        }
    }
}
