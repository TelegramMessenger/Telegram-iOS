#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task H1 — the private `UITextInputController`'s delegate, and the three notification thunks that
/// depended on it.
///
/// ## What was wrong, and why nothing caught it
///
/// The port installed `textInputDidChange:`, `textInputDidChangeSelection:` and
/// `textInput:shouldChangeCharactersInRanges:replacementText:` on `IDDocumentCanvasView` — all three
/// declared in the private `UITextInputControllerDelegate` — while handing the controller the client
/// BRIDGE as its `delegate:`. The bridge spells its own members `delegateTextInputDidChange` &c. and
/// answers `respondsToSelector:` NO for every one of the real selectors, so the controller asked
/// once, cached NO, and never sent them again. Three thunks, a bridge method each, a backend relay
/// each, and a `TGRichTextInputDecClientBridging` protocol group — none of it ever ran, and the
/// whole tree compiled and passed.
///
/// The reason it was invisible from source is the caching: `-setDelegate:` interrogates the incoming
/// delegate about 17 selectors ONCE, at assignment, and re-queries none of them afterwards. So there
/// is no later moment at which a wrong delegate looks wrong — no failed dispatch, no exception, no
/// `respondsToSelector:` traffic to notice. The only way to see it is to ask the controller who its
/// delegate is, which is what `test_thePrivateControllerDelegateIsTheHostCanvas` does.
///
/// ## What these tests assert, and why in this shape
///
/// Every assertion below reads a value CAPTURED before the assertion runs, never a live/derived one
/// re-read inside `XCTAssert`. That is deliberate: this programme has repeatedly produced false
/// greens from assertions that re-derived the thing they were supposed to be pinning.
@available(iOS 17.0, *)
@MainActor
final class IDControllerDelegateWiringTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    private func privateController(_ backend: IDTextEditorBackend) throws -> AnyObject {
        let kernelInput = try XCTUnwrap(backend.kernelInput, "no input-controller capability")
        return kernelInput.privateController as AnyObject
    }

    private func delegate(of controller: AnyObject) -> AnyObject? {
        controller.perform(NSSelectorFromString("delegate"))?.takeUnretainedValue()
    }

    /// Writes a selection into the kernel that DIFFERS from the one the private controller currently
    /// caches, and returns whether the write itself succeeded.
    ///
    /// The difference is load-bearing and cost a red run to learn: the controller notifies its
    /// delegate on a genuine selection CHANGE, so handing it the selection it already holds — which
    /// `mintKernelSelectedTextRange()` does on a freshly attached backend, where both sides sit at
    /// offset 0 — produces no notification at all and makes every assertion downstream vacuous.
    @discardableResult
    private func writeAChangedKernelSelection(_ h: IDFakeClientHarness) throws -> Bool {
        let kernelInput = try XCTUnwrap(h.idBackend.kernelInput)
        h.backend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
            reason: .programmatic)
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            kernelInput.selectedTextRange = h.idBackend.mintKernelSelectedTextRange()
        }, &error)
        XCTAssertNil(error, "the kernel selection write itself failed")
        return error == nil
    }

    // MARK: - The wiring itself

    /// **The pin for this task.** Upstream makes the host view the controller's delegate on every
    /// construction path (`IDBlockTextView.m`'s `delegate:self`, the reference path, and both
    /// private factories) — which is exactly why its delegate implementations are a category ON THE
    /// VIEW. Before the fix this read `IDTextEditorBackendClientBridge`.
    func test_thePrivateControllerDelegateIsTheHostCanvas() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let controller = try privateController(h.idBackend)
        let installed = delegate(of: controller)
        let bridge = TGRichTextInputDecAttachedBridge(h.canvas) as AnyObject?

        // Capture everything the failure message needs BEFORE asserting.
        let isCanvas = installed === h.canvas
        let isBridge = installed === bridge
        let installedClass = installed.map { NSStringFromClass(type(of: $0)) } ?? "(nil)"

        XCTAssertTrue(isCanvas,
                      "the private controller's delegate must be the host canvas, as upstream's "
                      + "host is for its own view; it is \(installedClass)")
        XCTAssertFalse(isBridge,
                       "the client bridge answers none of the UITextInputControllerDelegate "
                       + "selectors, so handing it the delegate slot silences every one of them")
    }

    /// The instrument behind this whole file, pinned so it cannot rot silently: the controller
    /// decides ONCE, at `-setDelegate:`, which delegate callbacks it will ever send, and the three
    /// selectors this port installs on the canvas are among the ones it asks about. If a future OS
    /// stops asking about them, the thunks are decoration again and this test says so.
    func test_theControllerAsksItsDelegateAboutTheThreeSelectorsThisPortInstalls() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let controller = try privateController(h.idBackend)
        let real = delegate(of: controller)

        let recorder = DelegateSelectorRecorder(forwardingTo: real)
        controller.perform(NSSelectorFromString("setDelegate:"), with: recorder)
        let asked = Set(recorder.queriedSelectors)
        controller.perform(NSSelectorFromString("setDelegate:"), with: real)

        for selector in ["textInputDidChange:",
                         "textInputDidChangeSelection:",
                         "textInput:shouldChangeCharactersInRanges:replacementText:"] {
            XCTAssertTrue(asked.contains(selector),
                          "the controller never asks its delegate about \(selector) — installing it "
                          + "on the canvas cannot do anything. It asked about: \(asked.sorted())")
        }
    }

    /// The canvas must be the object that answers them. Asserting the canvas responds is not enough
    /// on its own (it always did); asserting the BRIDGE does not is what makes the delegate identity
    /// above load-bearing rather than cosmetic.
    func test_theCanvasAnswersTheDelegateSelectorsAndTheBridgeDoesNot() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let bridge = TGRichTextInputDecAttachedBridge(h.canvas) as AnyObject?
        var canvasAnswers: [String] = []
        var bridgeAnswers: [String] = []
        for name in ["textInputDidChange:",
                     "textInputDidChangeSelection:",
                     "textInput:shouldChangeCharactersInRanges:replacementText:"] {
            let selector = NSSelectorFromString(name)
            if h.canvas.responds(to: selector) { canvasAnswers.append(name) }
            if bridge?.responds(to: selector) ?? false { bridgeAnswers.append(name) }
        }
        XCTAssertEqual(canvasAnswers.count, 3, "the canvas must answer all three: \(canvasAnswers)")
        XCTAssertEqual(bridgeAnswers, [],
                       "the bridge answers \(bridgeAnswers) — if it ever starts answering these, "
                       + "the delegate identity stops being the thing that decides delivery")
    }

    // MARK: - Delivery

    /// End to end: a delete the KERNEL performs must reach the canvas thunks. Before the fix the
    /// receipts were unchanged by any amount of kernel-driven editing.
    func test_aKernelDrivenDeleteReachesTheCanvasNotificationThunks() {
        let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
        h.backend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
            reason: .programmatic)
        let before = h.idBackend.controllerNotificationReceipts
        h.canvas.deleteBackward()
        let after = h.idBackend.controllerNotificationReceipts

        XCTAssertGreaterThan(after.textDidChange, before.textDidChange,
                             "textInputDidChange: never reached the canvas for a kernel-driven "
                             + "delete (before \(before), after \(after))")
        XCTAssertGreaterThan(after.selectionDidChange, before.selectionDidChange,
                             "textInputDidChangeSelection: never reached the canvas for a "
                             + "kernel-driven delete (before \(before), after \(after))")
    }

    /// A selection write with no document mutation isolates the selection notification from the
    /// mutation transaction's own brackets — the transaction is what makes a delete's delegate
    /// traffic ambiguous, and this path has none.
    func test_aKernelSelectionWriteDeliversExactlyOneSelectionNotification() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let before = h.idBackend.controllerNotificationReceipts
        try writeAChangedKernelSelection(h)
        let after = h.idBackend.controllerNotificationReceipts

        XCTAssertEqual(after.selectionDidChange, before.selectionDidChange + 1,
                       "expected exactly one textInputDidChangeSelection: "
                       + "(before \(before), after \(after))")
        XCTAssertEqual(after.textDidChange, before.textDidChange,
                       "a pure selection write must not report a document change")
    }

    // MARK: - Direction

    /// **The direction half, and it only became testable once the wiring was fixed.** These are
    /// INCOMING reports. `inputDelegate?.selectionDidChange(_:)` is UIKit's "an external agent moved
    /// the selection behind your back" signal, so sending it from inside the controller's own
    /// selection-change notification tells the keyboard to discard the session that produced it.
    /// Task F4 read that off the upstream source; the code kept doing it because it never ran.
    ///
    /// Isolated on the pure-selection-write path deliberately: a delete would also emit the mutation
    /// transaction's own legitimate brackets, and this test would then be asserting about a mixture.
    func test_theControllerSelectionNotificationSendsNoOutwardInputDelegateNotification() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        // `setSelection` publishes, so install the recorder and reset the log AFTER the selection is
        // already where this test wants it — otherwise the log carries that call's own publication
        // and the assertions below would be reading someone else's traffic.
        h.backend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(3), head: .downstream(3)),
            reason: .programmatic)
        let kernelInput = try XCTUnwrap(h.idBackend.kernelInput)
        h.backend.inputDelegate = RecordingInputDelegate(log: h.log)
        h.log.reset()

        var error: NSError?
        _ = TGRichTextInputDecPerform({
            kernelInput.selectedTextRange = h.idBackend.mintKernelSelectedTextRange()
        }, &error)
        XCTAssertNil(error, "the kernel selection write itself failed")
        let kinds = h.log.kinds
        let receipts = h.idBackend.controllerNotificationReceipts

        XCTAssertGreaterThan(receipts.selectionDidChange, 0,
                             "the notification never arrived, so this test proves nothing about "
                             + "what it does: \(receipts)")
        XCTAssertFalse(kinds.contains("delegateSelectionDidChange"),
                       "textInputDidChangeSelection: is an INCOMING report and must not be relayed "
                       + "back out to UIKit as selectionDidChange: \(kinds)")
        XCTAssertFalse(kinds.contains("delegateTextDidChange"),
                       "a selection notification must not report a text change either: \(kinds)")
        // The SAME write also delivers `keyboardInputChangedSelection:` to the canvas — measured, and
        // the reason this test's assertions cover both callbacks rather than one: whichever of the
        // two relayed back out to UIKit, the same log entry would appear above. Pinned so that if
        // that second delivery ever stops, this test says so instead of quietly covering less.
        XCTAssertGreaterThan(receipts.keyboardInputChangedSelection, 0,
                             "keyboardInputChangedSelection: no longer arrives on this path, so the "
                             + "assertions above no longer cover it: \(receipts)")
    }

    /// Upstream's `textInputDidChangeSelection:` calls `[self.id_interactionCapability
    /// selectionChanged]`; before this task that kernel call had no caller anywhere in the port.
    /// A raised/rejected kernel call lands in `witnessFailures` rather than trapping, so an empty
    /// `witnessFailures` alongside a non-zero forward count is the readable evidence that the call
    /// both happened and was accepted.
    func test_theSelectionNotificationForwardsToTheKernelInteractionAssistant() throws {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        try writeAChangedKernelSelection(h)
        let receipts = h.idBackend.controllerNotificationReceipts
        let failures = h.idBackend.witnessFailures

        XCTAssertGreaterThan(receipts.forwardedSelectionChangedToKernel, 0,
                             "nothing forwarded the controller's selection change to the kernel's "
                             + "interaction assistant: \(receipts)")
        XCTAssertEqual(failures, [],
                       "the forwarded kernel call failed: \(failures)")
    }
}

/// Records every `respondsToSelector:` question the private controller asks, and forwards every
/// actual message to the delegate it replaced, so installing it does not change behaviour while it
/// is in place.
private final class DelegateSelectorRecorder: NSObject {
    private let target: AnyObject?
    private(set) var queriedSelectors: [String] = []

    init(forwardingTo target: AnyObject?) { self.target = target }

    override func responds(to aSelector: Selector!) -> Bool {
        if let aSelector { queriedSelectors.append(NSStringFromSelector(aSelector)) }
        if super.responds(to: aSelector) { return true }
        return target?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let target, target.responds(to: aSelector) else { return nil }
        return target
    }
}
#endif
