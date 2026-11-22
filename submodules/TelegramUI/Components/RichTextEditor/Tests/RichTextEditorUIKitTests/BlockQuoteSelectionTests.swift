#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit
final class BlockQuoteSelectionTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView(); c.frame = CGRect(x:0,y:0,width:320,height:400)
        c.setBlocks(blocks, width: 320); c.simulateParentLayout(); return c
    }
    func test_caretInsideQuoteChild_resolvesToChildStack() {
        // quote holding two paragraphs; a caret in the SECOND child must resolve to the quote's child stack, not root.
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "aa")])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "bb")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        // a global pos inside the second child paragraph:
        let secondChild = box.children.boxes[1]
        let pos = secondChild.leafRegions().first!.globalStart + 1
        let hit = c.activeStack(at: pos)
        XCTAssertNotNil(hit)
        XCTAssertTrue(hit!.stack === box.children)          // resolved into the quote's child stack
        XCTAssertTrue(hit!.box === secondChild)
    }
    func test_caretInsideNestedQuote_resolvesToInnermostStack() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("ip"), runs: [TextRun(text: "zz")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [
            .paragraph(ParagraphBlock(id: BlockID("op"), runs: [TextRun(text: "aa")])),
            .blockQuote(inner)], collapsed: false)
        let c = canvas([.blockQuote(outer)])
        let outerBox = c.boxes.first as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let pos = innerBox.children.boxes[0].leafRegions().first!.globalStart + 1
        let hit = c.activeStack(at: pos)
        XCTAssertTrue(hit!.stack === innerBox.children)      // innermost (nested) stack
    }
}
#endif
