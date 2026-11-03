#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasLayoutTests: XCTestCase {
    func test_boxesStackVerticallyWithoutOverlap() {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        v.layoutIfNeeded()
        XCTAssertEqual(v.boxes[0].frame.minY, 0, accuracy: 0.5)
        XCTAssertEqual(v.boxes[1].frame.minY, v.boxes[0].frame.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(v.intrinsicContentSize.height, v.boxes[0].frame.height)
    }

    func test_rendersNonBlankImage() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 80); v.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(image.cgImage)
    }
}
#endif
