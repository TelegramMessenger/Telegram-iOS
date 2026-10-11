#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C11 — the NON-skip-gated coverage for Family 8's window-removal display-link teardown.
///
/// `IDTextEditorBackend.stopDisplayLinksForWindowRemoval(_:newWindow:)` — the static function
/// `hostWillMove(toWindow:)` (`+Responder.swift`) delegates to — takes an `IDDocumentCanvasView`
/// DIRECTLY, not through `isAttached`/`host`. `stopDragAutoScroll()`/`cancelFloatingCursor()` are
/// canvas-level, backend-agnostic mechanisms with no dependency on a successful kernel attach at
/// all, so a canvas built under the SAME reporter-guarded construction
/// `IDBackendContractSubclasses.swift`'s `makeIDContractHost` already uses (the self-attach inside
/// `IDDocumentCanvasView(inputBackend:)`'s `init` fails harmlessly today — see this file's own
/// guard comment) is enough to drive it for real. This is what makes it possible to genuinely
/// EXECUTE this coverage on a runtime where `isSupported()` is false — unlike
/// `IDBackendFamily8Tests.test_removeFromWindowWhileDragging_stopsEveryDisplayLink`, which needs
/// the full, successfully-attached fake-client harness and stays skip-gated until Task C14.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendWindowRemovalTests: XCTestCase {

    /// Mirrors `IDBackendContractSubclasses.swift`'s `makeIDContractHost` guard, verbatim in intent:
    /// `IDDocumentCanvasView(inputBackend:)`'s init self-attaches the backend and, on the EXPECTED
    /// rejection (`incomingCallbacks` still unaccepted on this runtime), routes the failure through
    /// `RichTextInputContractViolation.report(...)`, which `assertionFailure()`s — a hard process
    /// trap in DEBUG — with no reporter installed. The canvas itself is fully constructed regardless
    /// of whether the self-attach succeeded (the `catch` swallows the error and `init` continues), so
    /// swallowing this one, EXPECTED report is enough to get a live, gesture-capable canvas with no
    /// risk of masking a genuinely new failure — nothing else in this file installs a reporter.
    private func makeUnattachedCanvas() -> IDDocumentCanvasView {
        let previousReporter = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { _ in }
        let canvas = IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
        RichTextInputContractViolation.reporter = previousReporter
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        return canvas
    }

    /// `point.y == 0` sits inside `floatingAutoScrollStep`'s top edge-band unconditionally (needs no
    /// scroll-view content geometry), so both links start deterministically.
    private func startBothDisplayLinks(on canvas: IDDocumentCanvasView) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        scrollView.addSubview(canvas)
        canvas.updateDragAutoScroll(point: CGPoint(x: 0, y: 0), headInTable: false)
        canvas.updateFloatingAutoScroll(viewportY: 0)
    }

    func test_stopDisplayLinksForWindowRemoval_stopsBothLinks_whenTheNewWindowIsNil() {
        let canvas = makeUnattachedCanvas()
        startBothDisplayLinks(on: canvas)
        XCTAssertNotNil(canvas.dragAutoScrollLink,
                        "precondition: the drag auto-scroll link must be running before this test can prove anything")
        XCTAssertNotNil(canvas.floatingScrollLink,
                        "precondition: the floating-cursor auto-scroll link must be running before this test can prove anything")

        IDTextEditorBackend.stopDisplayLinksForWindowRemoval(canvas, newWindow: nil)

        XCTAssertNil(canvas.dragAutoScrollLink, "a nil new window must stop the drag auto-scroll link")
        XCTAssertNil(canvas.floatingScrollLink, "a nil new window must stop the floating-cursor auto-scroll link")
    }

    /// The complement: entering a REAL window (the one non-nil case UIKit actually announces —
    /// mirrors `LegacyRichTextInputBackend+Responder.swift`'s own note on `willMove(toWindow:)`'s
    /// branch) must NOT tear down an in-flight gesture's display links.
    func test_stopDisplayLinksForWindowRemoval_doesNothing_whenEnteringARealWindow() {
        let canvas = makeUnattachedCanvas()
        startBothDisplayLinks(on: canvas)
        XCTAssertNotNil(canvas.dragAutoScrollLink, "precondition")
        XCTAssertNotNil(canvas.floatingScrollLink, "precondition")

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        IDTextEditorBackend.stopDisplayLinksForWindowRemoval(canvas, newWindow: window)

        XCTAssertNotNil(canvas.dragAutoScrollLink, "entering a window must not clear an in-flight drag link")
        XCTAssertNotNil(canvas.floatingScrollLink, "entering a window must not clear an in-flight floating-cursor link")
        canvas.stopDragAutoScroll()
        canvas.cancelFloatingCursor()
    }
}
#endif
