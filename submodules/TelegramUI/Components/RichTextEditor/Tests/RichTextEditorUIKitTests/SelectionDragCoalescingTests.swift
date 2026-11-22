#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// During an interactive selection-handle drag, the per-touch-move selection setters MUST NOT drive the
/// system keyboard's autocorrect/candidate pipeline on every frame. Each `inputDelegate.selectionDidChange`
/// synchronously runs `-[_UIKeyboardStateManager updateForChangedSelection]` (clear-candidates + a
/// document-state sync that re-enters our `DocumentTokenizer`), which pegs the CPU during a drag and is
/// meaningless there — you can't accept a suggestion while dragging a handle. So the notifications are
/// COALESCED to the gesture's end: one bracket fires when the drag finishes. The `selectedTextRange` getter
/// stays live throughout, so the OS reads the correct value if it queries mid-drag — only the proactive
/// candidate recompute is deferred. (Reuses the shared `InputDelegateSpy` from MarkedTextTests.swift.)
final class SelectionDragCoalescingTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }
    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        v.installSelectionInteractions()
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    func test_handleDrag_coalescesInputDelegateNotificationsToGestureEnd() {
        let v = canvas(); _ = v.becomeFirstResponder()
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.beginCoalescedSelectionDrag()
        let baseWill = spy.selectionWillChangeCount, baseDid = spy.selectionDidChangeCount
        for i in 1...6 { v.setSelectionHead(global: v.boxes[0].textStart + i) }
        XCTAssertEqual(spy.selectionWillChangeCount, baseWill, "no per-frame selectionWillChange during the drag")
        XCTAssertEqual(spy.selectionDidChangeCount, baseDid, "no per-frame selectionDidChange during the drag")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 6, "the selection still tracks every move")
        v.endCoalescedSelectionDrag()
        XCTAssertEqual(spy.selectionWillChangeCount, baseWill + 1, "exactly one selectionWillChange when the drag ends")
        XCTAssertEqual(spy.selectionDidChangeCount, baseDid + 1, "exactly one selectionDidChange when the drag ends")
    }

    func test_setSelectionHead_outsideDrag_notifiesEveryCall() {
        // Regression guard: the coalescing is drag-scoped. A normal (non-drag) selection move still brackets
        // the input delegate per call — the load-bearing invariant for programmatic / arrow-key moves.
        let v = canvas(); _ = v.becomeFirstResponder()
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        let baseDid = spy.selectionDidChangeCount
        for i in 1...3 { v.setSelectionHead(global: v.boxes[0].textStart + i) }
        XCTAssertEqual(spy.selectionDidChangeCount, baseDid + 3, "each non-drag selection move brackets the input delegate")
    }

    func test_endCoalescedSelectionDrag_withoutBegin_isNoOp() {
        let v = canvas(); _ = v.becomeFirstResponder()
        let spy = InputDelegateSpy(); v.inputDelegate = spy
        let baseDid = spy.selectionDidChangeCount
        v.endCoalescedSelectionDrag()
        XCTAssertEqual(spy.selectionDidChangeCount, baseDid, "ending a drag that never coalesced fires nothing")
    }
}
#endif
