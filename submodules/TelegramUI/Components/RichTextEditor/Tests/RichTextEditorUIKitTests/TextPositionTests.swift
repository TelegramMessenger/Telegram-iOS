#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class TextPositionTests: XCTestCase {
    func test_range_exposesStartEndAndEmptiness() {
        let r = DocumentTextRange(DocumentTextPosition(2), DocumentTextPosition(5))
        XCTAssertEqual((r.start as! DocumentTextPosition).offset, 2)
        XCTAssertEqual((r.end as! DocumentTextPosition).offset, 5)
        XCTAssertFalse(r.isEmpty)
        XCTAssertTrue(DocumentTextRange(DocumentTextPosition(3), DocumentTextPosition(3)).isEmpty)
    }

    func test_selectionRect_exposesValues() {
        let sr = DocumentSelectionRect(rect: CGRect(x: 1, y: 2, width: 3, height: 4),
                                       containsStart: true, containsEnd: false)
        XCTAssertEqual(sr.rect, CGRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertTrue(sr.containsStart)
        XCTAssertFalse(sr.containsEnd)
        XCTAssertFalse(sr.isVertical)
    }
}
#endif
