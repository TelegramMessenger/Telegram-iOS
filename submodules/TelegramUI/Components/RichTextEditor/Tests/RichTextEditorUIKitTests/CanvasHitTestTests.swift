#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class CanvasHitTestTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        return v
    }

    func test_pointSelectionAcrossBlocks() {
        let v = canvas()
        // Point hit-test → cross-block selection (the primitives behind handle-drag / programmatic selection;
        // a one-finger drag no longer selects — it scrolls). Caret in Alpha, head far into Beta.
        v.setCaret(global: v.closestGlobalPosition(to: CGPoint(x: 0, y: v.boxes[0].frame.midY)))        // in Alpha
        v.setSelectionHead(global: v.closestGlobalPosition(to: CGPoint(x: 9999, y: v.boxes[1].frame.midY)))  // far into Beta
        XCTAssertNotEqual(v.selFrom, v.selTo)
        XCTAssertEqual(v.box(containingGlobal: v.selFrom)!.box.id, BlockID("a"))
        XCTAssertEqual(v.box(containingGlobal: v.selTo)!.box.id, BlockID("b"))
    }

    func test_doesNotInstallSelectionDisplayInteraction() {
        // The canvas draws ALL of its own selection visuals (caret/wash/handles), so it must NOT add a
        // `UITextSelectionDisplayInteraction`. On iOS 18+ that interaction installs its own default selection
        // chrome (lollipops/highlight/cursor) which a custom no-draw `handleViews` no longer suppresses — the
        // default handle knobs leak at the container origin. Not creating it removes that leak at the source.
        let v = canvas()
        v.installSelectionInteractions()
        if #available(iOS 17.0, *) {   // the type itself is iOS 17+ (it's what we assert we DON'T install)
            XCTAssertFalse(v.interactions.contains { $0 is UITextSelectionDisplayInteraction },
                           "the canvas must not attach a UITextSelectionDisplayInteraction (it would leak OS handle chrome)")
        }
        // The edit-menu interaction IS still installed (selection still works end-to-end).
        XCTAssertTrue(v.interactions.contains { $0 is UIEditMenuInteraction })
    }
}
#endif
