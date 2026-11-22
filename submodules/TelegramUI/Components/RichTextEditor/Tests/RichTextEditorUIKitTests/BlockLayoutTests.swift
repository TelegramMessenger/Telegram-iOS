#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

@available(iOS 16.0, *)
final class BlockLayoutTests: XCTestCase {
    private func layout(_ s: String) -> BlockLayout {
        BlockLayout(attributedString: NSAttributedString(string: s,
            attributes: [.font: UIFont.systemFont(ofSize: 16)]), width: 300)
    }

    func test_lengthAndHeight() {
        let l = layout("Hello")
        XCTAssertEqual(l.length, 5)
        XCTAssertGreaterThan(l.boundingHeight, 0)
    }

    func test_caretAdvancesWithOffset() {
        let l = layout("Hello")
        XCTAssertLessThan(l.caretRect(atOffset: 0).minX, l.caretRect(atOffset: 5).minX)
    }

    func test_selectionRectsNonEmptyForRange() {
        let l = layout("Hello")
        XCTAssertFalse(l.selectionRects(start: 0, end: 5).isEmpty)
    }

    func test_closestOffset_nearStartIsZero() {
        let l = layout("Hello")
        XCTAssertEqual(l.closestOffset(toPoint: CGPoint(x: -50, y: 5)), 0)
    }

    func test_closestOffset_tapRightOfShortLastLine_landsAtLineEnd() {
        // Wraps to a long first line + a short last line at width 300.
        let l = layout("For decades they were just math. Now we photograph them.")
        let endCaret = l.caretRect(atOffset: l.length)
        XCTAssertGreaterThan(endCaret.midY, l.caretRect(atOffset: 0).midY)   // sanity: it wrapped past line 1
        // Tap in the free space to the RIGHT of the short last line, on that line's row.
        let offset = l.closestOffset(toPoint: CGPoint(x: 5000, y: endCaret.midY))
        XCTAssertEqual(offset, l.length)   // end of the last line — not the longer line above it
    }

    func test_replaceUpdatesText() {
        let l = layout("Hello")
        l.replace(start: 5, end: 5, with: NSAttributedString(string: "!"))
        XCTAssertEqual(l.length, 6)
    }

    func test_firstLineBaselineFromTop_nilForEmptyText() {
        XCTAssertNil(layout("").firstLineBaselineFromTop)
    }

    private func baselineLayout(multiple: CGFloat) -> BlockLayout {
        let ps = NSMutableParagraphStyle(); ps.lineHeightMultiple = multiple
        return BlockLayout(attributedString: NSAttributedString(string: "Hi",
            attributes: [.font: UIFont.systemFont(ofSize: 16), .paragraphStyle: ps]), width: 300)
    }

    func test_firstLineBaselineFromTop_growsWithLineHeightMultiple() {
        // A larger line-height multiple pushes the first line's baseline further below the top — this is
        // exactly the shift that the list marker must follow to stay aligned with the text.
        let plain = baselineLayout(multiple: 1.0).firstLineBaselineFromTop ?? 0
        let tall  = baselineLayout(multiple: 1.5).firstLineBaselineFromTop ?? 0
        XCTAssertGreaterThan(tall, plain)
    }
}
#endif
