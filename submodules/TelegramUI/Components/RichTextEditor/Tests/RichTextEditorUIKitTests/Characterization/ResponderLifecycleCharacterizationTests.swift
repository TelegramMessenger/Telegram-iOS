#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class ResponderLifecycleCharacterizationTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func hostedCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        v.installSelectionInteractions()
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    func test_becomeFirstResponder_firesTheHostHookExactlyOnceOnAGenuineTransition() {
        let v = hostedCanvas()
        var became = 0
        v.onBecameFirstResponder = { became += 1 }
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertEqual(became, 1)
        XCTAssertTrue(v.becomeFirstResponder())   // repeat while already focused
        XCTAssertEqual(became, 1, "a repeat call is not a transition")
    }

    func test_becomeFirstResponder_setsDidJustBecomeFirstResponder() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertTrue(v.didJustBecomeFirstResponder)
    }

    func test_becomeFirstResponder_seedsLastCheckedCaretFromTheHead() {
        let v = hostedCanvas()
        v.setCaret(global: v.boxes[0].textStart + 3)
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertEqual(v.lastCheckedCaret, v.head)
    }

    func test_resignFirstResponder_firesTheHostHookOnceAndClearsTheTransitionFlag() {
        let v = hostedCanvas()
        var resigned = 0
        v.onResignedFirstResponder = { resigned += 1 }
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertTrue(v.resignFirstResponder())
        XCTAssertEqual(resigned, 1)
        XCTAssertFalse(v.didJustBecomeFirstResponder)
        // Brief predicted `XCTAssertTrue` here; observed reality is `false` — `UIResponder.resignFirstResponder()`
        // returns false when the receiver is not the first responder to begin with (DocumentCanvasView.swift:730,
        // `super.resignFirstResponder()`). Corrected toward the observed behavior (see task-6-report.md).
        XCTAssertFalse(v.resignFirstResponder())
        XCTAssertEqual(resigned, 1, "resigning while not focused is not a transition")
    }

    func test_resignFirstResponder_commitsAnActiveComposition() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange)
        _ = v.resignFirstResponder()
        XCTAssertNil(v.markedRange)
    }

    func test_resignFirstResponder_breaksTheUndoCoalescingRun() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        v.setCaret(global: v.boxes[0].textStart)
        v.insertText("a")
        XCTAssertNotNil(v.openUndoRun)
        _ = v.resignFirstResponder()
        XCTAssertNil(v.openUndoRun)
    }

    func test_resignFirstResponder_cancelsAnActiveFloatingCursor() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(v.floatingCursorActive)
        _ = v.resignFirstResponder()
        XCTAssertFalse(v.floatingCursorActive)
    }

    // MARK: what resignFirstResponder deliberately does NOT tear down (deviation D18)

    func test_resignFirstResponder_leavesTheCoalescingFlagSet() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        v.beginCoalescedSelectionDrag()
        _ = v.resignFirstResponder()
        XCTAssertTrue(v.coalescingSelectionNotifications,
                      "today's teardown does NOT clear this; the seam must not fix it (D18)")
        v.endCoalescedSelectionDrag()
    }

    func test_resignFirstResponder_leavesAPendingSpellingMenuSet() {
        let v = hostedCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        v.pendingSpellingMenu = (range: NSRange(location: 0, length: 3), guesses: ["Alpha"], revertTo: nil)
        _ = v.resignFirstResponder()
        XCTAssertNotNil(v.pendingSpellingMenu, "not torn down today (D18)")
    }

    /// **TASK 32 NOTE — the NAME is now half stale, the ASSERTION is not.** A removal path exists as of
    /// Task 32: `legacyRemoveSelectionInteractions()` (`DocumentCanvasView+Interaction.swift`), reached
    /// only from `LegacyRichTextInputBackend.removeInteractions()`, which `performDetachSteps()` calls
    /// as step 4. **Deviation D18 keeps it out of `resignFirstResponder()`**, which is what this
    /// `Characterization/` suite is about — so every gap this file pins is untouched. What the test
    /// below actually asserts is that `installSelectionInteractions()` is IDEMPOTENT, and that is
    /// unchanged (and now exercised twice over: `DocumentCanvasView.init`'s `attach` installs, and
    /// `hostedCanvas()` calls the installer again before this test calls it a third time). The name is
    /// left alone deliberately — renaming a characterization test rewrites the record of what was
    /// observed when it was written.
    func test_installSelectionInteractions_isOneWay_thereIsNoRemovalPath() {
        let v = hostedCanvas()
        let before = v.gestureRecognizers?.count ?? 0
        v.installSelectionInteractions()   // guarded on `gestureRecognizers?.isEmpty` (+Interaction.swift:7):
        XCTAssertEqual(v.gestureRecognizers?.count ?? 0, before,
                       "the second call is a full no-op, not merely non-decreasing — pins the exact guard, and " +
                       "would catch a future remove-then-reinstall regression")
    }

    func test_canBecomeFirstResponder_isUnconditionallyTrue() {
        let v = hostedCanvas()
        XCTAssertTrue(v.canBecomeFirstResponder, "there is no edit policy gate today")
    }

    // MARK: canvas-hook vs facade responder-callback ordering (RichTextInputEventRecorder, Task 2)
    //
    // The two hooks above are exercised directly on the canvas. The façade (`RichTextEditorView`)
    // wires its own public `onBecameFirstResponder`/`onResignedFirstResponder` by forwarding
    // SYNCHRONOUSLY from the canvas hook (`RichTextEditorView.swift:274-275`), so the canvas-hook
    // event must always be recorded strictly before the facade event. This is exactly what
    // `RichTextInputEventRecorder` was built to observe (a single total ordinal across canvas-hook
    // and facade sources).

    private func hostedEditor() -> (RichTextEditorView, RichTextInputEventRecorder) {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])),
        ])
        window.addSubview(editor)
        editor.layoutIfNeeded()
        let recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: editor.canvasForTesting)
        recorder.attach(facade: editor)
        recorder.reset()
        return (editor, recorder)
    }

    func test_becomeFirstResponder_canvasHookFiresBeforeTheFacadeHook() {
        let (editor, recorder) = hostedEditor()
        XCTAssertTrue(editor.canvasForTesting.becomeFirstResponder())
        let canvasIndex = recorder.kinds.firstIndex(of: .canvasBecameFirstResponder)
        let facadeIndex = recorder.kinds.firstIndex(of: .facadeBecameFirstResponder)
        XCTAssertNotNil(canvasIndex); XCTAssertNotNil(facadeIndex)
        XCTAssertLessThan(canvasIndex!, facadeIndex!)
    }

    func test_resignFirstResponder_canvasHookFiresBeforeTheFacadeHook() {
        let (editor, recorder) = hostedEditor()
        XCTAssertTrue(editor.canvasForTesting.becomeFirstResponder())
        recorder.reset()
        XCTAssertTrue(editor.canvasForTesting.resignFirstResponder())
        let canvasIndex = recorder.kinds.firstIndex(of: .canvasResignedFirstResponder)
        let facadeIndex = recorder.kinds.firstIndex(of: .facadeResignedFirstResponder)
        XCTAssertNotNil(canvasIndex); XCTAssertNotNil(facadeIndex)
        XCTAssertLessThan(canvasIndex!, facadeIndex!)
    }

    /// A FAILED transition (a windowless view can't become first responder) must emit no callback at
    /// all on either side — the trap this suite is warned about: a windowless-view test would pin
    /// nothing (and often pass for the wrong reason), so this one deliberately keeps the view OUT of
    /// any window and asserts the negative on both hooks.
    func test_becomeFirstResponder_onAWindowlessView_failsAndFiresNoCallback() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        // Deliberately NOT added to `window`.
        var became = 0
        v.onBecameFirstResponder = { became += 1 }
        XCTAssertFalse(v.becomeFirstResponder(), "a windowless view cannot become first responder")
        XCTAssertEqual(became, 0, "a failed transition must fire no callback")
        XCTAssertFalse(v.didJustBecomeFirstResponder)
    }

    /// The mirror failure case: resigning when never focused is a no-op transition and must fire no
    /// callback, exactly like the repeat-call case above but from a completely fresh view.
    func test_resignFirstResponder_whenNeverFocused_isANoOpAndFiresNoCallback() {
        let v = hostedCanvas()
        var resigned = 0
        v.onResignedFirstResponder = { resigned += 1 }
        XCTAssertFalse(v.resignFirstResponder(), "UIResponder.resignFirstResponder() returns false when already not first responder")
        XCTAssertEqual(resigned, 0, "no genuine transition occurred; the hook must not fire")
    }
}
#endif
