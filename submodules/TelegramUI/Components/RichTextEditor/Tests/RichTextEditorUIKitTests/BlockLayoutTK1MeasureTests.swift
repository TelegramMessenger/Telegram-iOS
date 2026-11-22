#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class BlockLayoutTK1MeasureTests: XCTestCase {
    private func layout(_ s: String, width: CGFloat = 300) -> BlockLayoutTK1 {
        BlockLayoutTK1(attributedString: NSAttributedString(string: s,
            attributes: [.font: UIFont.systemFont(ofSize: 16)]), width: width)
    }
    private let wrapping = "For decades they were just math. Now we photograph them, again and again."

    func test_measure_matchesFreshEngineAtThatWidth() {
        XCTAssertEqual(layout(wrapping, width: 300).boundingHeight(forWidth: 120),
                       layout(wrapping, width: 120).boundingHeight, accuracy: 0.5)
    }
    func test_measure_liveWidthEqualsBoundingHeight() {
        let l = layout(wrapping, width: 300)
        XCTAssertEqual(l.boundingHeight(forWidth: 300), l.boundingHeight, accuracy: 0.5)
    }
    func test_measure_doesNotMutateLiveLayout() {
        let l = layout(wrapping, width: 300)
        let before = l.boundingHeight
        _ = l.boundingHeight(forWidth: 80)
        XCTAssertEqual(l.boundingHeight, before, accuracy: 0.001)
        XCTAssertEqual(l.containerWidth, 300, accuracy: 0.001)
    }
    func test_measure_memoInvalidatesAfterEdit() {
        let l = layout("Short", width: 300)
        let h1 = l.boundingHeight(forWidth: 100)
        l.replace(start: 5, end: 5, with: NSAttributedString(string: " and now much much much much longer so it wraps",
            attributes: [.font: UIFont.systemFont(ofSize: 16)]))
        XCTAssertGreaterThan(l.boundingHeight(forWidth: 100), h1)
    }
}
#endif
