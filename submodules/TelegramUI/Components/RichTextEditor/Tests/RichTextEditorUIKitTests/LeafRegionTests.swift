#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class LeafRegionTests: XCTestCase {
    func test_paragraphBox_yieldsOneLeafRegion_atItsTextSpan() {
        let p = ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")])
        let box = BlockBox(paragraph: p, mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 1
        box.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].globalStart, 1)
        XCTAssertEqual(regions[0].length, 5)
        XCTAssertEqual(regions[0].ref, .paragraph(BlockID("p")))
    }

    func test_imageBox_yieldsOneCaptionRegion_atNodeStartPlus2() {
        let img = MediaBlock(id: BlockID("i"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10),
                             caption: [TextRun(text: "Cap")])
        let box = MediaBlockBox(media: img, mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 5
        box.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].globalStart, 7)        // nodeStart + 2
        XCTAssertEqual(regions[0].ref, .caption(BlockID("i")))
    }
}
#endif
