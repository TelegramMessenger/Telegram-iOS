#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class WritingDirectionStyleTests: XCTestCase {
    func test_paragraphStyle_appliesExplicitBaseWritingDirection() {
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: .default,
                                                   baseWritingDirection: .rightToLeft)
        XCTAssertEqual(ps.baseWritingDirection, .rightToLeft)
    }

    func test_paragraphStyle_defaultsToNatural() {
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: .default)
        XCTAssertEqual(ps.baseWritingDirection, .natural)
    }

    func test_naturalAlignment_mapsToNSTextAlignmentNatural() {
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: .default) // .default = .natural
        XCTAssertEqual(ps.alignment, .natural)
    }

    func test_mapper_defaultBaseWritingDirection_isNatural() {
        XCTAssertEqual(AttributedStringMapper().baseWritingDirection, .natural)
    }

    func test_tableCellVariant_preservesBaseWritingDirection() {
        var m = AttributedStringMapper()
        m.baseWritingDirection = .rightToLeft
        XCTAssertEqual(m.tableCellVariant().baseWritingDirection, .rightToLeft)
    }
}
#endif
