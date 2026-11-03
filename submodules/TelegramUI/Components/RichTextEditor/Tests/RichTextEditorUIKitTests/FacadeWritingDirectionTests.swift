#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class FacadeWritingDirectionTests: XCTestCase {
    private func view() -> RichTextEditorView {
        let v = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        v.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"),
                                                                 runs: [TextRun(text: "Hi")]))])
        return v
    }

    func test_overrideProperty_isReflectedInDocument() {
        let v = view()
        v.layoutDirectionOverride = .rightToLeft
        XCTAssertEqual(v.layoutDirectionOverride, .rightToLeft)
        XCTAssertEqual(v.document.layoutDirection, .rightToLeft)
    }

    func test_settingDocument_appliesItsLayoutDirection() {
        let v = view()
        var doc = v.document
        doc.layoutDirection = .leftToRight
        v.document = doc
        XCTAssertEqual(v.layoutDirectionOverride, .leftToRight)
    }

    func test_default_isAuto() {
        XCTAssertEqual(view().layoutDirectionOverride, .auto)
    }
}
#endif
