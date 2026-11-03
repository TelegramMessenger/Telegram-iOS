#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Native UITextView dismisses the edit (context) menu the moment the text or the caret/selection
/// changes. The canvas owns its own `UIEditMenuInteraction`, which (once presented) does NOT
/// self-dismiss on a selection change — it repositions via `targetRectFor` — so the canvas must call
/// `dismissMenu()` itself from every selection/text mutation choke point.
///
/// The dismiss is UNCONDITIONAL (not gated on `editMenuVisible`): the system flips that flag to false
/// on a touch-down BEFORE the gesture's setter runs, so gating on it would skip the dismiss exactly
/// when the user moves the cursor. `dismissMenu()` on a non-presented interaction is a harmless no-op.
/// Observed via `dismissEditMenuCountForTesting` — a presented `UIEditMenuInteraction` can't be driven
/// in a unit test, so we assert on the dismiss call, not on the visibility flag.
@available(iOS 16.0, *)
final class EditMenuAutoDismissTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func start(_ v: DocumentCanvasView) -> Int { v.boxes[0].textStart }

    func test_insertText_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v) + 5, head: start(v) + 5)
        let before = v.dismissEditMenuCountForTesting
        v.insertText("X")
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "typing dismisses the menu")
    }

    func test_deleteBackward_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v) + 5, head: start(v) + 5)
        let before = v.dismissEditMenuCountForTesting
        v.deleteBackward()
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "deleting dismisses the menu")
    }

    func test_setCaret_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v), head: start(v))
        let before = v.dismissEditMenuCountForTesting
        v.setCaret(global: start(v) + 3)
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "moving the caret dismisses the menu")
    }

    func test_setSelectionHead_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v), head: start(v) + 2)
        let before = v.dismissEditMenuCountForTesting
        v.setSelectionHead(global: start(v) + 5)
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "extending the selection dismisses the menu")
    }

    func test_setSelectionAnchor_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v) + 5, head: start(v) + 5)
        let before = v.dismissEditMenuCountForTesting
        v.setSelectionAnchor(global: start(v) + 1)
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "moving the anchor dismisses the menu")
    }

    /// The system path: the keyboard cursor-drag / autocorrect / predictive text move the caret by
    /// writing the UITextInput `selectedTextRange` setter (NOT a gesture). It must dismiss too.
    func test_selectedTextRangeSetter_dismissesMenu() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v), head: start(v))
        let before = v.dismissEditMenuCountForTesting
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(start(v) + 4), DocumentTextPosition(start(v) + 4))
        XCTAssertGreaterThan(v.dismissEditMenuCountForTesting, before, "a system-driven caret move dismisses the menu")
    }

    /// The guard: the present-after-change flows (Select / Select All / double-/triple-tap) change the
    /// selection via `applySelection`, which is deliberately NOT a dismiss point — so the menu they are
    /// about to present is not dismissed out from under them.
    func test_selectAllThenPresent_doesNotSelfDismiss() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v) + 2, head: start(v) + 2)
        let before = v.dismissEditMenuCountForTesting
        v.selectAllText()          // the Select-All path: changes the selection, then the caller presents
        XCTAssertEqual(v.dismissEditMenuCountForTesting, before, "Select All must not dismiss the menu it is about to present")
    }

    func test_selectWordThenPresent_doesNotSelfDismiss() {
        let v = canvas()
        v.setSelectionForTesting(anchor: start(v) + 2, head: start(v) + 2)
        let before = v.dismissEditMenuCountForTesting
        v.selectWord(at: start(v) + 2)   // double-tap path: select then present
        XCTAssertEqual(v.dismissEditMenuCountForTesting, before, "Select word must not dismiss the menu it is about to present")
    }
}
#endif
