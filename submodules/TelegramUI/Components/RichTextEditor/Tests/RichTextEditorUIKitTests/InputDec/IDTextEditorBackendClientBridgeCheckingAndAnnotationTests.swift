#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C14 — the NON-skip-gated coverage for Family 11's nine new
/// `IDTextEditorBackendClientBridge` methods (the seven annotation forwards + the two spellchecking
/// thunks' Swift halves).
///
/// **None of the tests below needs a live kernel, a canvas host, or a successful `attach(to:)`** —
/// `IDTextEditorBackendClientBridge` is a plain object constructible directly
/// (`init(host:backend:)`), and every method under test here is an ordinary Swift forward with no
/// dependency on `kernel`/`kernelInput`/`kernelInteraction` except
/// `setNativeContinuousSpellCheckingEnabled(_:)`, which guards its `kernelInput?.` access through
/// `TGRichTextInputDecPerform` and simply no-ops when `kernelInput` is nil (a never-attached
/// backend) — matching every other guarded kernel call in this package. This mirrors Task C13's own
/// `IDTextEditorBackendFloatingCursorSuppressionTests`: genuinely executable on a runtime where
/// `isSupported()` is false, unlike `IDBackendFamily11Tests`, which stays skip-gated.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendClientBridgeCheckingAndAnnotationTests: XCTestCase {

    /// `IDTextEditorBackendClientBridge.backend` is held `unowned` (never `weak`/`strong`) — a
    /// helper-local `IDTextEditorBackend()` with no other strong reference would be deallocated the
    /// instant the helper returns, turning the very next `unowned` access into a fatal trap. This
    /// property is what keeps it alive for the rest of the test.
    private var retainedBackend: IDTextEditorBackend?

    private func makeBridge() -> (bridge: IDTextEditorBackendClientBridge, host: FakeInputHost) {
        let log = RichTextInputEventLog()
        let host = FakeInputHost(log: log)
        let backend = IDTextEditorBackend()
        retainedBackend = backend
        let bridge = IDTextEditorBackendClientBridge(host: host, backend: backend)
        return (bridge, host)
    }

    // MARK: - The seven annotation forwards

    /// Proven capable of failing, not merely capable of passing: temporarily changing
    /// `annotatedSubstring(forRange:revision:)`'s body to `nil` (skipping the forward) makes this
    /// assertion fail with a real `XCTAssertEqual failed: ("0") is not equal to ("1")`, then
    /// reverted.
    func test_annotatedSubstring_forwardsToTheAnnotationClient() {
        let (bridge, host) = makeBridge()
        _ = bridge.annotatedSubstring(forRange: NSRange(location: 2, length: 4), revision: 7)
        XCTAssertEqual(host.fakeAnnotationClient.annotatedSubstringReadCount, 1)
    }

    func test_annotationValue_forwardsToTheAnnotationClient_withThePositionConverted() {
        let (bridge, host) = makeBridge()
        _ = bridge.annotationValue(forKey: "spelling", atPosition: 5, revision: 7)
        XCTAssertEqual(host.fakeAnnotationClient.annotationValueReadCount, 1)
    }

    func test_addAnnotationKey_forwardsToTheAnnotationClient_andReturnsItsResult() {
        let (bridge, host) = makeBridge()
        host.fakeAnnotationClient.addAnnotationResult = false
        let range = NSRange(location: 0, length: 3)
        let ok = bridge.addAnnotationKey("k", value: "v", range: range, revision: 3)
        XCTAssertFalse(ok, "the bridge must return the client's own result, not fabricate true")
        XCTAssertEqual(host.log.events, [.annotationAdd(range: range, revision: 3)])
    }

    func test_removeAnnotationKey_forwardsToTheAnnotationClient_andReturnsItsResult() {
        let (bridge, host) = makeBridge()
        host.fakeAnnotationClient.removeAnnotationResult = false
        let range = NSRange(location: 0, length: 3)
        let ok = bridge.removeAnnotationKey("k", range: range, revision: 3)
        XCTAssertFalse(ok)
        XCTAssertEqual(host.log.events, [.annotationRemove(range: range, revision: 3)])
    }

    func test_addRenderingAttributes_forwardsToTheAnnotationClient_andReturnsItsResult() {
        let (bridge, host) = makeBridge()
        host.fakeAnnotationClient.addRenderingAttributesResult = false
        let ok = bridge.addRenderingAttributes([:], range: NSRange(location: 0, length: 1), revision: 1)
        XCTAssertFalse(ok)
        XCTAssertEqual(host.fakeAnnotationClient.addRenderingAttributesCallCount, 1)
    }

    func test_removeRenderingAttributes_forwardsToTheAnnotationClient_andReturnsItsResult() {
        let (bridge, host) = makeBridge()
        host.fakeAnnotationClient.removeRenderingAttributesResult = false
        let ok = bridge.removeRenderingAttributes([], range: NSRange(location: 0, length: 1), revision: 1)
        XCTAssertFalse(ok)
        XCTAssertEqual(host.fakeAnnotationClient.removeRenderingAttributesCallCount, 1)
    }

    func test_invalidateTemporaryAttributes_forwardsToTheAnnotationClient_withTheRange() {
        let (bridge, host) = makeBridge()
        let range = NSRange(location: 4, length: 2)
        bridge.invalidateTemporaryAttributes(inRange: range, revision: 9)
        XCTAssertEqual(host.fakeAnnotationClient.invalidateTemporaryAttributesCallCount, 1)
        XCTAssertEqual(host.fakeAnnotationClient.lastInvalidatedRange, range)
    }

    /// A nil host must never crash — the same "inert without an attached host/bridge" discipline
    /// every canvas thunk in `TGRichTextInputDecCanvasCallbacks.m` follows, mirrored here at the
    /// Swift boundary via `guard let host else { ... }`.
    func test_annotationForwards_areInertWithNoHost() {
        let log = RichTextInputEventLog()
        var host: FakeInputHost? = FakeInputHost(log: log)
        let backend = IDTextEditorBackend()
        retainedBackend = backend
        let bridge = IDTextEditorBackendClientBridge(host: host!, backend: backend)
        host = nil   // the bridge holds `host` weakly
        XCTAssertNil(bridge.annotatedSubstring(forRange: NSRange(location: 0, length: 1), revision: 0))
        XCTAssertNil(bridge.annotationValue(forKey: "k", atPosition: 0, revision: 0))
        XCTAssertFalse(bridge.addAnnotationKey("k", value: "v", range: NSRange(location: 0, length: 1), revision: 0))
        XCTAssertFalse(bridge.removeAnnotationKey("k", range: NSRange(location: 0, length: 1), revision: 0))
        XCTAssertFalse(bridge.addRenderingAttributes([:], range: NSRange(location: 0, length: 1), revision: 0))
        XCTAssertFalse(bridge.removeRenderingAttributes([], range: NSRange(location: 0, length: 1), revision: 0))
        bridge.invalidateTemporaryAttributes(inRange: NSRange(location: 0, length: 1), revision: 0)   // must not crash
    }

    // MARK: - The two spellchecking thunks

    /// The setter reaches `canvas.isSpellCheckingEnabled` even with NO live kernel (`kernelInput`
    /// nil on a never-attached backend) — the guarded `kernelInput?.` access simply no-ops, and the
    /// canvas-state mirror still runs. Proven capable of failing: temporarily deleting the
    /// `(host?.hostInputView as? DocumentCanvasView)?.isSpellCheckingEnabled = enabled` line makes
    /// this assertion fail with a real `XCTAssertFalse failed`, then reverted.
    func test_setNativeContinuousSpellCheckingEnabled_reachesCanvasState_withNoLiveKernel() {
        let (bridge, host) = makeBridge()
        XCTAssertTrue((host.hostInputView as! DocumentCanvasView).isSpellCheckingEnabled,
                      "precondition: the default")
        bridge.setNativeContinuousSpellCheckingEnabled(false)
        XCTAssertFalse((host.hostInputView as! DocumentCanvasView).isSpellCheckingEnabled)
        XCTAssertFalse(bridge.isNativeContinuousSpellCheckingEnabled())
    }

    func test_isNativeContinuousSpellCheckingEnabled_readsCanvasState() {
        let (bridge, host) = makeBridge()
        (host.hostInputView as! DocumentCanvasView).isSpellCheckingEnabled = false
        XCTAssertFalse(bridge.isNativeContinuousSpellCheckingEnabled())
        (host.hostInputView as! DocumentCanvasView).isSpellCheckingEnabled = true
        XCTAssertTrue(bridge.isNativeContinuousSpellCheckingEnabled())
    }

    /// A nil host must never crash. `setNativeContinuousSpellCheckingEnabled(_:)` must not trap
    /// even though its guarded kernel call closes over `self.backend` (never `self.host`).
    func test_spellCheckingThunks_areInertWithNoHost() {
        let log = RichTextInputEventLog()
        var host: FakeInputHost? = FakeInputHost(log: log)
        let backend = IDTextEditorBackend()
        retainedBackend = backend
        let bridge = IDTextEditorBackendClientBridge(host: host!, backend: backend)
        host = nil
        bridge.setNativeContinuousSpellCheckingEnabled(true)   // must not crash
        XCTAssertFalse(bridge.isNativeContinuousSpellCheckingEnabled())
    }
}
#endif
