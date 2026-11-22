#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpoilerToggleTests: XCTestCase {
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        return v
    }
    func runs(_ v: DocumentCanvasView, _ id: String) -> [TextRun] {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.runs } }
        return []
    }
    /// Concatenated text of paragraph `id`'s runs whose attributes satisfy `pred`.
    func text(_ v: DocumentCanvasView, _ id: String, matching pred: (CharacterAttributes) -> Bool) -> String {
        runs(v, id).filter { pred($0.attributes) }.map { $0.text }.joined()
    }
    func selectParagraph(_ v: DocumentCanvasView, _ id: String, _ lo: Int, _ hi: Int) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart + lo, head: r.globalStart + hi)
    }

    func test_toggleSpoiler_setsMarkerOnSelection() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4)                      // "ell" of "Hello"
        v.toggleSpoiler()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "ell")
        XCTAssertEqual(text(v, "h") { !$0.spoiler }, "Ho")
    }

    func test_toggleSpoiler_isAToggle() {
        let v = canvas()
        selectParagraph(v, "h", 0, 5); v.toggleSpoiler()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "Hello")
        selectParagraph(v, "h", 0, 5); v.toggleSpoiler()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "")
    }

    func test_toggleSpoiler_collapsedCaretIsNoOp() {
        let v = canvas()
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("h")) }!
        v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)
        v.toggleSpoiler()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "", "a collapsed caret toggles nothing")
    }

    func test_toggleSpoiler_isOneUndoStep() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        selectParagraph(v, "h", 0, 5)
        um.beginUndoGrouping(); v.toggleSpoiler(); um.endUndoGrouping()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "Hello")
        um.undo()
        XCTAssertEqual(text(v, "h") { $0.spoiler }, "")
    }

    func test_facade_toggleSpoiler_reflectsInDocument() {
        let e = RichTextEditorView()
        e.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        e.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        e.layoutIfNeeded()
        e.selectAll(); e.toggleSpoiler()
        let allSpoiler = e.document.blocks.contains { b in
            if case .paragraph(let p) = b { return !p.runs.isEmpty && p.runs.allSatisfy { $0.attributes.spoiler } }
            return false
        }
        XCTAssertTrue(allSpoiler)
    }
}
#endif
