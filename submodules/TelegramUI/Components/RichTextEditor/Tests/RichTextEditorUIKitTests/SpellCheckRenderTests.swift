#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpellCheckRenderTests: XCTestCase {
    private func makeCanvas(_ text: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: text)]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }

    func test_underlineRects_nonEmptyOverFlaggedWord() {
        let v = makeCanvas("hello wrold today")
        let base = v.boxes[0].textStart
        v.applyNativeAnnotations(global: NSRange(location: base + 6, length: 5), style: .spelling)   // "wrold"
        let rects = v.spellingUnderlineRects()
        XCTAssertFalse(rects.isEmpty)
        // Each rect is a thin baseline line (height ~1pt) and sits inside the canvas.
        for r in rects { XCTAssertLessThanOrEqual(r.rect.height, 3); XCTAssertGreaterThan(r.rect.width, 0) }
    }

    func test_underlineRects_emptyWhenNothingFlagged() {
        let v = makeCanvas("all good words")
        XCTAssertTrue(v.spellingUnderlineRects().isEmpty)
    }

    func test_themeDefault_misspellingIsSystemRed() {
        XCTAssertEqual(RichTextEditorTheme.default.misspellingUnderline, .systemRed)
    }
}
#endif
