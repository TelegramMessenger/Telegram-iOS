import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, an edit over a selection that runs from a plain paragraph
/// INTO the quote or code block after it merges the paragraph into the block (legacy's rule, as the
/// engine's oracle rows note), but UNDO then restores the text and not the structure: the paragraph
/// stays quoted / code.
///
///     [p "Intro line."] [quote "Quoted text here."] → select 4..<15 ("o line.\nQuo") → type "X"
///       → [quote "IntrXted text here."] → Undo
///       legacy: [quote "Intro line."] [quote "Quoted text here."]      (text right, "Intro line." quoted)
///       expected: [p "Intro line."] [quote "Quoted text here."]
///     the same with Backspace over the selection, and with a code block after the paragraph
///     control, the same edit inside one paragraph: undo restores the start exactly
///
/// This is the unfixed sibling of the seventh-wave row "Backspace at the start of a quote … undo
/// restores the break but both lines stay quoted": the Backspace-at-a-caret case was fixed by the
/// unquote hook; a selection edit across the boundary still leaves both lines in the block after undo.
///
/// **How it was seen.** `HarnessComposerFuzzTests` (legacy undo mix), seeds 30 and 56 of 1-60,
/// 2026-09-23: undo-all ended with the first paragraph quoted / code.
///
/// **Suspected cause.** The merged line's state is pushed back by the chat (`updateInputTextState`),
/// quoting the whole line; UIKit's typing undo then restores the replaced characters with the
/// attributes the storage has around them, and nothing restores the paragraph's own (absent) block
/// attribute.
///
/// **Tier 1**: `insertText` / `deleteBackward` and the view's `undoManager` are the keyboard's and
/// ⌘Z's entry points.
final class HarnessLegacyCrossBlockEditUndoTests: XCTestCase {
    private func editThenUndo(_ start: ChatInputContent, select: NSRange, edit: (UITextView) -> Void) throws -> (edited: ChatInputContent, undone: ChatInputContent, startModel: ChatInputContent) {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(start)
        arranged = value
        let undoManager = try XCTUnwrap(value.textView.undoManager)
        undoManager.removeAllActions()
        let startModel = FuzzModel.normalized(value.node.currentInputContent().content)
        HarnessLegacy.select(value, select)
        edit(value.textView)
        HarnessEngine.settle(value.root)
        let edited = FuzzModel.normalized(value.node.currentInputContent().content)
        XCTAssertTrue(undoManager.canUndo, "precondition: the edit registered no undo step")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        return (edited, FuzzModel.normalized(value.node.currentInputContent().content), startModel)
    }

    private static let quote = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Intro line."),
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
    ])
    private static let code = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Code below:"),
        .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
    ])

    func testUndoingTypingOverAParagraphIntoAQuoteRestoresTheParagraph() throws {
        let result = try self.editThenUndo(Self.quote, select: NSRange(location: 4, length: 11), edit: { $0.insertText("X") })
        XCTAssertEqual(result.undone, result.startModel, "undo left the paragraph quoted: \(FuzzModel.describe(result.undone)) (edited: \(FuzzModel.describe(result.edited)))")
    }

    func testUndoingBackspaceOverAParagraphIntoAQuoteRestoresTheParagraph() throws {
        let result = try self.editThenUndo(Self.quote, select: NSRange(location: 4, length: 11), edit: { $0.deleteBackward() })
        XCTAssertEqual(result.undone, result.startModel, "undo left the paragraph quoted: \(FuzzModel.describe(result.undone)) (edited: \(FuzzModel.describe(result.edited)))")
    }

    func testUndoingTypingOverAParagraphIntoACodeBlockRestoresTheParagraph() throws {
        let result = try self.editThenUndo(Self.code, select: NSRange(location: 4, length: 11), edit: { $0.insertText("X") })
        XCTAssertEqual(result.undone, result.startModel, "undo left the paragraph as code: \(FuzzModel.describe(result.undone)) (edited: \(FuzzModel.describe(result.edited)))")
    }

    /// Control: the same edit inside one paragraph undoes exactly.
    func testControlInsideOneParagraph() throws {
        let result = try self.editThenUndo(Self.quote, select: NSRange(location: 2, length: 5), edit: { $0.insertText("X") })
        XCTAssertEqual(result.undone, result.startModel, "control: undo inside a paragraph did not restore the start")
    }
}
