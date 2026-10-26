#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// An inline button asked for inside a code block. A code block holds plain text only (its runs are
/// plain by construction and `currentCode()` reads the plain string back), so a pill there cannot
/// exist: its `U+FFFC` atom was read back as a raw character in the code and the button was lost.
/// `insertFormula` already types its LaTeX as plain text in a code block; the inline button now types
/// its label the same way, and the selection-to-pill conversion (the composer's edit menu) refuses.
/// Found in review of the squash (2026-10-12); the article editor's Add ▸ Button ▸ Inline reaches it
/// from a collapsed caret.
final class InlineButtonInCodeTests: XCTestCase {
    private func editor(_ blocks: [Block]) -> RichTextEditorView {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        editor.document = Document(blocks: blocks)
        editor.layoutIfNeeded()
        return editor
    }

    private func placeCaret(_ editor: RichTextEditorView, atEndOfBoxAt index: Int) {
        let box = editor.canvas.boxes[index]
        let end = DocumentTextPosition(box.textStart + box.textLength)
        editor.canvas.selectedTextRange = DocumentTextRange(end, end)
    }

    private let button = ButtonRef(label: [TextRun(text: "Go")], action: .url("https://telegram.org"))

    func test_anInlineButtonInACodeBlockIsTypedAsItsLabel() {
        let editor = editor([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x")]))])
        placeCaret(editor, atEndOfBoxAt: 0)
        editor.insertInlineButton(button)

        guard case let .code(code) = editor.document.blocks.first else { return XCTFail("the code block went away") }
        let text = code.runs.map(\.text).joined()
        XCTAssertFalse(text.contains("\u{FFFC}"), "an object-replacement character landed in the code: \(text.debugDescription)")
        XCTAssertEqual(text, "let xGo")
        XCTAssertFalse(code.runs.contains { $0.attributes.button != nil }, "a pill landed in a code block")
    }

    /// The other door: the composer's edit menu turns a selection into a pill.
    func test_aSelectionInACodeBlockIsNotTurnedIntoAPill() {
        let editor = editor([.code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x")]))])
        let box = editor.canvas.boxes[0]
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(box.textStart), DocumentTextPosition(box.textStart + 3))
        editor.canvas.makeSelectionInlineButton()

        guard case let .code(code) = editor.document.blocks.first else { return XCTFail("the code block went away") }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x")
    }

    /// Control: in a body paragraph the pill is made.
    func test_anInlineButtonInAParagraphIsAPill() {
        let editor = editor([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Tap ")]))])
        placeCaret(editor, atEndOfBoxAt: 0)
        editor.insertInlineButton(button)

        guard case let .paragraph(paragraph) = editor.document.blocks.first else { return XCTFail() }
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.button != nil }, "no pill: \(paragraph.runs)")
    }
}
#endif
