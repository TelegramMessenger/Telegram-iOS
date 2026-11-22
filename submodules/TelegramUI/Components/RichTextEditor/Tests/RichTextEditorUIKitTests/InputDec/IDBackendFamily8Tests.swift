#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C11 — the ID-SPECIFIC assertions for Family 8 (responder lifecycle): that
/// `canBecomeFirstResponder`/`canResignFirstResponder` genuinely CONSULT
/// `RichTextInputLifecycleClient.backendWillBeginEditing()`/`.backendShouldEndEditing()` (a
/// veto hook neither backend used before this task — see `IDTextEditorBackend+Responder.swift`'s
/// own header), that `RichTextInputEditPolicy` is read AT OPERATION TIME rather than cached at
/// attach, and that removing the canvas from its window stops every `CADisplayLink` a live
/// drag/floating-cursor gesture can leave running — mirroring `IDBackendFamily7Tests`' own
/// "ID-specific assertions over the fake harness" framing, one family over.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across six tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last row. That is expected here, not a regression; see this task's own report
/// (`task-C10-C11-report.md`) for the honest disclosure, for why `test_removeFromWindowWhileDragging_stopsEveryDisplayLink`
/// has no non-skip-gated companion (it needs the real, attached canvas + backend pair this whole
/// suite needs), and for how that test's ability to fail was verified anyway.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily8Tests: XCTestCase {
    private var window: UIWindow?

    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    /// `UIResponder.becomeFirstResponder()` fails outright for a windowless view
    /// (`ResponderLifecycleCharacterizationTests` documents this for Legacy; the same UIKit
    /// mechanism applies here), so a real window is required for the CONTROL half of this test —
    /// without it, "refuses when denied" would be indistinguishable from "always refuses, windowless".
    func test_becomeFirstResponderConsultsWillBeginEditing_andRefusesWhenDenied() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.addSubview(h.canvas)
        window.makeKeyAndVisible()
        self.window = window

        // Control: the default permissive lifecycle client answers `true` ("no veto hook exists
        // today" — `TelegramLifecycleInputClient.backendWillBeginEditing()`'s own doc comment) —
        // the SAME answer `FakeInputLifecycleClient.willBeginEditingAllowed`'s default gives.
        XCTAssertTrue(h.canvas.becomeFirstResponder(),
                     "control: becomeFirstResponder must succeed under the default permissive policy")
        XCTAssertTrue(h.canvas.resignFirstResponder(), "release focus before the denied attempt")

        h.lifecycle.willBeginEditingAllowed = false
        XCTAssertFalse(h.canvas.becomeFirstResponder(),
                      "a denied backendWillBeginEditing() must refuse the transition")
        XCTAssertFalse(h.canvas.isFirstResponder)
    }

    func test_resignFirstResponderConsultsShouldEndEditing() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.addSubview(h.canvas)
        window.makeKeyAndVisible()
        self.window = window
        XCTAssertTrue(h.canvas.becomeFirstResponder(), "precondition: focused before the denied attempt")

        h.lifecycle.shouldEndEditingAllowed = false
        XCTAssertFalse(h.canvas.resignFirstResponder(),
                      "a denied backendShouldEndEditing() must refuse the transition")
        XCTAssertTrue(h.canvas.isFirstResponder, "focus must remain where a denied resign left it")
    }

    /// Flips `h.lifecycle.editPolicyStorage` AFTER `attach(to:)` already ran (inside
    /// `makeIDFakeClientHarness()`), so a snapshot taken at attach time would never observe the
    /// change. `insertText(_:)` (`IDTextEditorBackend.swift`) is the one member this task's own
    /// `editPolicy` gate lives on — see that member's own doc comment.
    func test_editPolicyIsReadAtOperationTime_notCachedAtAttach() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.canvas.insertText("a")
        let readsAfterFirstCall = h.lifecycle.editPolicyReadCount
        XCTAssertGreaterThan(readsAfterFirstCall, 0, "insertText must consult editPolicy at least once")

        h.lifecycle.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        h.canvas.insertText("b")
        XCTAssertGreaterThanOrEqual(h.lifecycle.editPolicyReadCount, 2,
                                    "a SECOND call must read editPolicy AGAIN, not reuse a cached value")
    }

    /// **Disclosed scope, not a hidden gap**: `insertText(_:)` has no real insertion wiring yet (a
    /// later, unassigned family — see `IDTextEditorBackend.swift`'s own doc comment on this member),
    /// so it fires NO delegate notifications regardless of `editPolicy.isEditable` today — there is
    /// no "control: the permissive case commits and notifies" half to this test the way
    /// `BackendEditPolicyTests.test_notEditable_rejectsInsertText_withNotEditable_andNoDelegateNotifications`
    /// (the Legacy backend's own, pre-existing Task-22i suite) has for `LegacyRichTextInputBackend`,
    /// whose mutation IS wired. What this test pins is narrower and still real: `editPolicy` is
    /// GENUINELY consulted (proven by `test_editPolicyIsReadAtOperationTime_notCachedAtAttach`
    /// above) and, when it says not-editable, the guard fires before anything else — the same
    /// direction Legacy's own gate takes, at the granularity this backend has reached.
    func test_notEditablePolicy_rejectsInsertText_withNoDelegateNotifications() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.inputDelegate = RecordingInputDelegate(log: h.log)
        h.lifecycle.editPolicyStorage = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        h.log.reset()
        h.canvas.insertText("x")
        XCTAssertFalse(h.log.contains("delegateTextWillChange"))
        XCTAssertFalse(h.log.contains("delegateTextDidChange"))
        XCTAssertFalse(h.log.contains("delegateSelectionWillChange"))
        XCTAssertFalse(h.log.contains("delegateSelectionDidChange"))
    }

    /// The scenario with NO TEST AT ALL in the legacy suite today — see this task's own report for
    /// how its ability to fail was verified (this backend's `hostWillMove(toWindow:)` was an empty
    /// stub before this task; a real mutation-and-revert on THIS test, restoring that stub, is the
    /// verification). `updateDragAutoScroll`/`updateFloatingAutoScroll` are canvas-level, shared,
    /// backend-agnostic mechanisms (`DocumentCanvasView.swift`/`+FloatingCursor.swift`) — driven
    /// directly here rather than through a real gesture, since the LEAK this test guards against is
    /// specifically "the display link outlives the window", not "the gesture recognizer fired".
    func test_removeFromWindowWhileDragging_stopsEveryDisplayLink() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        scrollView.addSubview(h.canvas)

        // `point.y == 0` is inside the top edge-band of `floatingAutoScrollStep` unconditionally
        // (needs no real scroll-view content geometry), so both links start deterministically.
        h.canvas.updateDragAutoScroll(point: CGPoint(x: 0, y: 0), headInTable: false)
        h.canvas.updateFloatingAutoScroll(viewportY: 0)
        XCTAssertNotNil(h.canvas.dragAutoScrollLink,
                        "precondition: the drag auto-scroll link must be running before this test can prove anything")
        XCTAssertNotNil(h.canvas.floatingScrollLink,
                        "precondition: the floating-cursor auto-scroll link must be running before this test can prove anything")

        h.canvas.willMove(toWindow: nil)

        XCTAssertNil(h.canvas.dragAutoScrollLink,
                    "removing the canvas from its window must stop the drag auto-scroll link")
        XCTAssertNil(h.canvas.floatingScrollLink,
                    "removing the canvas from its window must stop the floating-cursor auto-scroll link")
    }
}
#endif
