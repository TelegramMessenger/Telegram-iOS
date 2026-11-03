#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpellCheckToggleTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello wrold")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func test_disabled_clearsResultsAndReportsTraitNo() {
        let v = makeCanvas()
        v.applyNativeAnnotations(global: NSRange(location: v.boxes[0].textStart + 6, length: 5), style: .spelling)
        XCTAssertFalse(v.spellResults.isEmpty)
        v.isSpellCheckingEnabled = false
        XCTAssertTrue(v.spellResults.isEmpty)                 // cleared
        XCTAssertEqual(v.spellCheckingType, .no)
        XCTAssertTrue(v.spellingUnderlineRects().isEmpty)     // nothing to draw
    }
    func test_enabled_reportsTraitYes() {
        let v = makeCanvas()
        XCTAssertEqual(v.spellCheckingType, .yes)
    }
    func test_disabled_tapDoesNotSelectWord() {
        let v = makeCanvas()
        v.applyNativeAnnotations(global: NSRange(location: v.boxes[0].textStart + 6, length: 5), style: .spelling)
        v.isSpellCheckingEnabled = false
        XCTAssertFalse(v.beginSpellingCorrection(at: CGPoint(x: 40, y: 8)))
    }
}
#endif
