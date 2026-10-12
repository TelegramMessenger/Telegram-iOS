#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The canvas reveals the caret padded by 12pt above and below. In a field shorter than that band —
/// a composer capped at one or two lines with overflowing text — the band cannot fit, and revealing
/// it aligned one of ITS edges, which left the caret itself cut by the difference (and the next
/// reveal aligned the other edge). The padding now shrinks to what the visible height leaves, so the
/// caret is wholly shown and a second reveal moves nothing. Review of the squash, 2026-10-12.
final class ShortFieldCaretRevealTests: XCTestCase {
    private func shortField() -> (RichTextEditorView, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 30))
        window.makeKeyAndVisible()
        let editor = RichTextEditorView(frame: window.bounds)
        window.addSubview(editor)
        editor.document = Document(blocks: (0..<40).map {
            Block.paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        })
        editor.layoutIfNeeded()
        return (editor, window)
    }

    private func reveal(_ editor: RichTextEditorView) {
        editor.scrollCaretIntoView()
    }

    func test_inAFieldShorterThanTheBandTheCaretIsWhollyShownAndStaysPut() {
        let (editor, window) = shortField()
        defer { window.isHidden = true }
        XCTAssertTrue(editor.becomeFirstResponder())
        let box = editor.canvas.boxes[20]
        let end = DocumentTextPosition(box.textStart + box.textLength)
        editor.canvas.selectedTextRange = DocumentTextRange(end, end)
        editor.contentOffsetForTesting = .zero

        reveal(editor)
        let caret = editor.canvas.caretRect(atGlobal: editor.canvas.head)
        let visibleTop = editor.contentOffsetForTesting.y
        let visibleBottom = visibleTop + window.bounds.height
        XCTAssertGreaterThan(caret.height, 0, "precondition: a caret rect")
        XCTAssertLessThan(caret.height, window.bounds.height, "precondition: the caret itself fits the field")
        XCTAssertGreaterThanOrEqual(caret.minY, visibleTop - 0.5, "the caret's top is cut: \(caret) in \(visibleTop)…\(visibleBottom)")
        XCTAssertLessThanOrEqual(caret.maxY, visibleBottom + 0.5, "the caret's bottom is cut: \(caret) in \(visibleTop)…\(visibleBottom)")

        let settled = editor.contentOffsetForTesting.y
        reveal(editor)
        XCTAssertEqual(editor.contentOffsetForTesting.y, settled, accuracy: 0.5, "a second reveal moved the field")
    }
}
#endif
