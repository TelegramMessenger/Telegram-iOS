#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class SelectionFillDirectionTests: XCTestCase {
    private func layout() -> BlockLayoutEngine {
        // Short single-line content so there is exactly one selection segment.
        makeBlockLayout(attributedString: NSAttributedString(
            string: "abcd", attributes: [.font: UIFont.systemFont(ofSize: 17)]), width: 200)
    }

    func test_ltr_coveredFromStart_fillsToLeftEdge_notRight() {
        let l = layout()
        let r = l.selectionFillRects(start: 0, end: 4, fillTrailingLine: false, isRTL: false)
        XCTAssertEqual(r.count, 1)
        XCTAssertLessThan(r[0].maxX, l.containerWidth - 5, "LTR leading fills left, stops at glyph end")
    }

    func test_rtl_coveredFromStart_fillsToRightEdge() {
        let l = layout()
        let r = l.selectionFillRects(start: 0, end: 4, fillTrailingLine: false, isRTL: true)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].maxX, l.containerWidth, accuracy: 1, "RTL leading fills to the right edge")
    }
}
#endif
