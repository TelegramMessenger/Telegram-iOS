#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class BaseDirectionTests: XCTestCase {
    private func layout(_ s: String) -> BlockLayoutEngine {
        makeBlockLayout(attributedString: NSAttributedString(
            string: s, attributes: [.font: UIFont.systemFont(ofSize: 17)]), width: 200)
    }

    func test_arabic_isRTL() {
        XCTAssertEqual(layout("مرحبا بالعالم").baseDirection(atOffset: 0), .rightToLeft)
    }

    func test_hebrew_isRTL() {
        XCTAssertEqual(layout("שלום עולם").baseDirection(atOffset: 0), .rightToLeft)
    }

    func test_latin_isLTR() {
        XCTAssertEqual(layout("Hello world").baseDirection(atOffset: 0), .leftToRight)
    }

    func test_empty_isNil() {
        XCTAssertNil(layout("").baseDirection(atOffset: 0))
    }
}
#endif
