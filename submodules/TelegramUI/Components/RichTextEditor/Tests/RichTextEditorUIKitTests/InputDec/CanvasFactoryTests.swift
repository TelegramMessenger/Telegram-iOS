#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `@MainActor`: `RichTextInputCanvasFactory.make(_:)` and `IDTextEditorBackend` are main-actor
/// isolated (see `RichTextInputCanvasFactory.swift`'s own doc comment on the same point) — an
/// XCTestCase's test methods are nonisolated by default, so this class-level annotation is
/// required to call either from a test body. Matches the existing convention in
/// `Tests/RichTextEditorUIKitTests/InputBackend/BackendAttachmentTests.swift`.
@MainActor
final class CanvasFactoryTests: XCTestCase {
    override func tearDown() {
        RichTextInputContractViolation.reporter = nil
        super.tearDown()
    }

    func test_legacyPreference_makesTheLegacyClassExactly() {
        let canvas = RichTextInputCanvasFactory.make(.legacy)
        XCTAssertTrue(type(of: canvas) == DocumentCanvasView.self,
                      "the legacy preference must never produce a subclass")
    }

    /// Stage B: TG_RICHTEXT_INPUTDEC_ENABLED is not yet defined, so isSupported() is false and
    /// the factory silently falls back. The flag is turned on in Task B6; this test is written
    /// to be correct in BOTH states so it never needs rewriting.
    func test_inputDecIfSupported_fallsBackWhenUnsupported() {
        let canvas = RichTextInputCanvasFactory.make(.inputDecIfSupported)
        if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
            XCTAssertTrue(canvas is IDDocumentCanvasView)
        } else {
            XCTAssertTrue(type(of: canvas) == DocumentCanvasView.self)
        }
    }

    func test_defaultEditorViewStillUsesTheLegacyCanvas() {
        let editor = RichTextEditorView()
        XCTAssertTrue(type(of: editor.canvas) == DocumentCanvasView.self,
                      "the default facade path must be unchanged by the factory")
    }

    /// ANTI-VACUITY (Task B3 supplement, "assert both arms"): the three tests above are one-sided —
    /// none of them ever observes `.legacy`/`.inputDecIfSupported` actually returning an
    /// `IDDocumentCanvasView`, because `IDTextEditorBackend.isSupported()` is unconditionally `false`
    /// until Task B6 flips `TG_RICHTEXT_INPUTDEC_ENABLED` on. A factory that ignored its argument and
    /// always returned `IDDocumentCanvasView()` would still pass all three above by accident (the
    /// `.legacy` test would simply start failing instead — so the ONE thing genuinely unverified by
    /// them is the positive "ID arm produces an ID canvas" claim.
    ///
    /// This test constructs the ID arm's exact call shape directly
    /// (`IDDocumentCanvasView(inputBackend: IDTextEditorBackend())`, as `RichTextInputCanvasFactory`
    /// does in both its `.inputDecIfSupported`/`.inputDecRequired` branches) rather than going through
    /// `RichTextInputCanvasFactory.make`, since the flag makes that arm unreachable in Stage B. It is
    /// also the ONE test in this file that would catch the brief's own named failure mode — a bare
    /// `IDDocumentCanvasView()` silently attaching `LegacyRichTextInputBackend()` (the initializer's
    /// `inputBackend ?? LegacyRichTextInputBackend()` default): checking only the CANVAS type (`canvas
    /// is IDDocumentCanvasView`) would still pass under that mistake, because the canvas class is
    /// right even when the attached backend is wrong. Asserting `canvas.inputBackend is
    /// IDTextEditorBackend` (and NOT `LegacyRichTextInputBackend`) is what actually distinguishes the
    /// two.
    ///
    /// R1 — UPDATED, was stale since Task C0. This assertion pinned "`attach(to:)` unconditionally
    /// throws until Task C0" — that comment was already nine tasks stale by the time Task C14
    /// (Family 11) opened the capability gate: `isSupported()` now answers `true` on a certified
    /// runtime, all 47 manifest rows resolve, and `IDBackendAttachAtomicityTests
    /// .test_attachSucceedsOnTheIDCanvas_andPublishesInitialState` independently confirms attach
    /// genuinely SUCCEEDS through this exact call shape today — measured directly (a real run
    /// against this file's OLD assertion failed with `XCTAssertTrue failed - … a silent success
    /// here would mean the placeholder started lying`, i.e. attach silently succeeded), not assumed.
    /// This is the one test-expectation change R1 is permitted to make (per its own brief): the
    /// condition being pinned was deliberately removed by other, already-landed work, so keeping the
    /// old assertion does not protect anything — it only asserts a regression back to a state the
    /// programme intentionally left behind.
    ///
    /// Still gated on `IDTextEditorBackend.isSupported()`, matching this file's own established idiom
    /// (`test_inputDecIfSupported_fallsBackWhenUnsupported()` above) and `IsSupportedTests`/
    /// `IDBackendAttachAtomicityTests`' "transition-safe" pattern: on an uncertified runtime attach
    /// is still expected to throw (the mandatory `incomingCallbacks` capability is rejected before any
    /// kernel construction is attempted), so the test stays correct in both states rather than
    /// hard-coding today's one measured runtime.
    @available(iOS 17.0, *)
    func test_idDocumentCanvasView_attachesTheGivenBackend_notTheLegacyDefault() {
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        let canvas = IDDocumentCanvasView(inputBackend: IDTextEditorBackend())

        XCTAssertTrue(type(of: canvas) == IDDocumentCanvasView.self)
        XCTAssertTrue(canvas.inputBackend is IDTextEditorBackend,
                      "a bare IDDocumentCanvasView() would silently attach LegacyRichTextInputBackend() " +
                      "instead — this must observe the INJECTED backend, not just the canvas's own type")
        XCTAssertFalse(canvas.inputBackend is LegacyRichTextInputBackend)
        if IDTextEditorBackend.isSupported() {
            XCTAssertFalse(reported.contains { $0.contains("backend attach failed") },
                          "IDTextEditorBackend.attach(to:) is expected to SUCCEED on a supported " +
                          "runtime now that Task C14 opened the capability gate — a report here " +
                          "would mean attach regressed")
        } else {
            XCTAssertTrue(reported.contains { $0.contains("backend attach failed") },
                         "on an unsupported runtime attach(to:) is still expected to throw (the " +
                         "mandatory incomingCallbacks capability is rejected)")
        }
    }
}
#endif
