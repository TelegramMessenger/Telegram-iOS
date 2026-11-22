#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasWritingDirectionTests: XCTestCase {
    private func canvas(_ text: String, override: DocumentLayoutDirection = .auto) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyWritingDirectionOverride(override)
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: text)])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        return v
    }

    func test_baseWritingDirection_reportsRTLForArabic() {
        let v = canvas("مرحبا")
        let pos = DocumentTextPosition(v.boxes[0].textStart)
        XCTAssertEqual(v.baseWritingDirection(for: pos, in: .forward), .rightToLeft)
    }

    func test_baseWritingDirection_reportsLTRForLatin() {
        let v = canvas("Hello")
        let pos = DocumentTextPosition(v.boxes[0].textStart)
        XCTAssertEqual(v.baseWritingDirection(for: pos, in: .forward), .leftToRight)
    }

    func test_forcedLTROverride_winsOverArabicContent() {
        let v = canvas("مرحبا", override: .leftToRight)
        let pos = DocumentTextPosition(v.boxes[0].textStart)
        XCTAssertEqual(v.baseWritingDirection(for: pos, in: .forward), .leftToRight)
    }

    func test_languageCodeMapping() {
        XCTAssertEqual(DocumentCanvasView.writingDirection(forPrimaryLanguage: "ar"), .rightToLeft)
        XCTAssertEqual(DocumentCanvasView.writingDirection(forPrimaryLanguage: "he"), .rightToLeft)
        XCTAssertEqual(DocumentCanvasView.writingDirection(forPrimaryLanguage: "fa"), .rightToLeft)
        XCTAssertEqual(DocumentCanvasView.writingDirection(forPrimaryLanguage: "en"), .leftToRight)
        XCTAssertNil(DocumentCanvasView.writingDirection(forPrimaryLanguage: nil))
    }
}
#endif
