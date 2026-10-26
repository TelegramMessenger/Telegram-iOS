import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, undo does not give a code block's LANGUAGE back. Type
/// `swift` into the language line, move the caret away and back, delete the five characters, undo:
/// the language comes back as `s` — only the first character. A second undo then produces `swift`,
/// i.e. the steps come back in the wrong order and the first one restores a state the user never
/// had (the snapshot taken after the first keystroke).
///
///     language "" → type s,w,i,f,t → caret to the body → caret back to the end of "swift"
///     → Backspace ×5 (language "") → undo → "s" (expected "swift") → undo → "swift"
///
/// A related, milder symptom on the same line: typing `swift` is TWO undo steps (`swift` → `s` →
/// nothing), where typing a word in the body is one.
///
/// **How it was seen.** K1, engine, 2026-09-22, three times (`two-paragraphs` → select the second
/// paragraph → Format ▸ Code → tap the "Language" line), with `insertText:` / `deleteBackward` /
/// `undo` sent to the engine text view. Body-text runs round-trip correctly in the same session.
/// Legacy has no code blocks, so there is no control.
///
/// **Suspected cause.** The undo funnel's baseline (`lastSettledUndoSnapshot`,
/// `RichTextEngineEditorView+UndoStack.swift`) is not kept current for edits on the language line,
/// a secondary line that the first keystroke materialises through settle
/// (`settleLanguageLinePresence`, `+Settle.swift`): the step registered by the first Backspace
/// restores the baseline captured after the first typed character.
///
/// **Tier 1**: the language line is on the engine text view's own `UITextInput` axis (it is not on
/// the model's flat axis, so `node.selectedRange` cannot reach it); placing the caret there and
/// calling `insertText` / `deleteBackward` / `undo` is what the keyboard and system undo do.
final class HarnessCodeLanguageUndoTests: XCTestCase {
    private func language(_ node: ChatRichTextInputNode) -> String? {
        for block in node.currentInputContent().content.blocks {
            if case let .code(code) = block {
                return code.language
            }
        }
        return nil
    }

    private func placeCaret(_ input: UITextInput, atEngineOffset offset: Int) throws {
        let position = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: offset))
        input.selectedTextRange = input.textRange(from: position, to: position)
    }

    func testUndoingTheDeletionOfALanguageRestoresTheWholeLanguage() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        // Engine axis: "Intro" 0..<5, "\n", the (empty) language line at 6, "\n", the code body.
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        let input = try XCTUnwrap(textView as? (UITextInput & UIKeyInput))
        let undoManager = try XCTUnwrap(textView.undoManager, "precondition: the engine view has no undo manager")

        try self.placeCaret(input, atEngineOffset: 6)
        HarnessEngine.settle(root)
        for character in "swift" {
            input.insertText(String(character))
            HarnessEngine.settle(root, seconds: 0.15)
        }
        XCTAssertEqual(self.language(node), "swift", "precondition: typing did not reach the language line")

        // Away into the body and back to the end of the language, as a user who changed their mind.
        try self.placeCaret(input, atEngineOffset: 14)
        HarnessEngine.settle(root)
        try self.placeCaret(input, atEngineOffset: 11)
        HarnessEngine.settle(root)
        for _ in 0 ..< 5 {
            input.deleteBackward()
            HarnessEngine.settle(root, seconds: 0.15)
        }
        XCTAssertNil(self.language(node), "precondition: Backspace did not empty the language line")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(self.language(node), "swift",
                       "undoing the deletion restored a language the user never had")
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nlet x = 1",
                       "undo changed the code body")

        _ = node.resignInputFirstResponder()
    }
}
