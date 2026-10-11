#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// PHASE 3b — **`acquireFirstResponder()` / `relinquishFirstResponder()`, from the SHIPPING side.**
///
/// The pair was added for the InputDec port: that backend's editing surface is a separate `UIView`
/// inside the host, and phase 3 measured that UIKit raises no keyboard and binds no `inputDelegate`
/// unless that view holds the first-responder role. `IDUpstreamResponderModelTests` is the evidence
/// and the instrument for that half.
///
/// **This file is the other half, and it is the one that matters for production**: a member added to
/// a shared contract is a member `LegacyRichTextInputBackend` — the backend the app actually runs —
/// must now implement. The phase's hard constraint was that Legacy's observable behaviour does not
/// change, so these tests are shaped as the two questions that could falsify it:
///
///  1. does Legacy answer the case that means "I did nothing"? and
///  2. does it in fact do nothing — is the responder chain provably untouched in every state, and
///     does no host focus callback fire?
///
/// (2) is not pedantry. The tempting implementation of this member for a host-editing backend is
/// `host.hostInputView.becomeFirstResponder()`, which is correct-looking, passes an "it answers
/// something sensible" test, and is an infinite recursion the day a host adopts the member the way
/// the contract documents — `DocumentCanvasView.becomeFirstResponder()` would call
/// `acquireFirstResponder()`, which would call `DocumentCanvasView.becomeFirstResponder()`. The
/// `.hostOwnsTheRole` case exists precisely so the host keeps its own `super` call, and the property
/// that makes that safe is "the backend does not enter the responder chain at all".
///
/// **Nothing in `Sources/` calls either member yet** — `DocumentCanvasView`'s responder overrides are
/// untouched by phase 3b — which is the strongest statement available about production being
/// unmoved, and it is pinned from the source by
/// `InputBackendSourceBoundaryTests.test_theResponderHandOffHasNoProductionCallSiteYet_R23`.
@MainActor
@available(iOS 16.0, *)
final class ResponderHandOffTests: XCTestCase {

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// A REAL window and a laid-out canvas: `UIResponder.becomeFirstResponder()` fails outright for a
    /// windowless view, so the focused half of every test below needs one.
    private func realCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    /// Everything is CAPTURED into this before anything is asserted, so a failure reports the state
    /// the responder chain was actually in rather than one re-derived afterwards.
    private struct ChainReading: Equatable {
        var canvasIsFirstResponder = false
        var windowHasFirstResponder = false
    }

    private func read(_ canvas: DocumentCanvasView) -> ChainReading {
        ChainReading(canvasIsFirstResponder: canvas.isFirstResponder,
                     windowHasFirstResponder: window.firstResponder != nil)
    }

    // MARK: - 1. The shipping backend answers "the role is the host's"

    /// Both members, in both attachment states, in both focus states — a constant `.hostOwnsTheRole`
    /// is the *correct* answer here, so the test's job is to pin that it is answered EVERYWHERE
    /// rather than in the one state someone happened to try.
    ///
    /// The two directions must agree: the contract requires a conformer to answer the same case from
    /// acquire and relinquish, because "who owns the role" is a property of the backend and not of
    /// the direction of travel. A backend that claimed the role on acquire and disclaimed it on
    /// relinquish would strand the role wherever it last landed.
    func test_theShippingBackendAnswersHostOwnsTheRoleInEveryState() {
        let canvas = realCanvas()
        var answers: [String: RichTextInputResponderTransition] = [:]

        answers["unfocused.acquire"] = canvas.inputBackend.acquireFirstResponder()
        answers["unfocused.relinquish"] = canvas.inputBackend.relinquishFirstResponder()

        XCTAssertTrue(canvas.becomeFirstResponder(), "the canvas must be able to take focus at all")
        answers["focused.acquire"] = canvas.inputBackend.acquireFirstResponder()
        answers["focused.relinquish"] = canvas.inputBackend.relinquishFirstResponder()

        let detached = LegacyRichTextInputBackend()
        answers["detached.acquire"] = detached.acquireFirstResponder()
        answers["detached.relinquish"] = detached.relinquishFirstResponder()

        XCTAssertEqual(answers, ["unfocused.acquire": .hostOwnsTheRole,
                                 "unfocused.relinquish": .hostOwnsTheRole,
                                 "focused.acquire": .hostOwnsTheRole,
                                 "focused.relinquish": .hostOwnsTheRole,
                                 "detached.acquire": .hostOwnsTheRole,
                                 "detached.relinquish": .hostOwnsTheRole],
                      "the shipping backend's editing surface IS the host, so the role stays there in "
                      + "every state — including detached, where it still has no surface of its own "
                      + "to hand the role to")
    }

    /// ANTI-VACUITY for the test above: the enum has another case, and a conformer really can answer
    /// it — so `XCTAssertEqual(…, .hostOwnsTheRole)` is a claim that can fail rather than a tautology
    /// about a single-valued type. (The production conformer that answers `.performedByBackend` is
    /// `IDUpstreamInputBackend`; `IDUpstreamResponderModelTests` drives it against the real ported
    /// engine. This file deliberately stays on the shipping side of the boundary.)
    func test_theOtherCaseIsReachable_soTheAssertionAboveCanFail() {
        let spy = SpyRichTextInputBackend()
        spy.stubbedResponderTransition = .performedByBackend(succeeded: true)
        XCTAssertEqual(spy.acquireFirstResponder(), .performedByBackend(succeeded: true))
        XCTAssertNotEqual(spy.acquireFirstResponder(), .hostOwnsTheRole)
        XCTAssertNotEqual(RichTextInputResponderTransition.performedByBackend(succeeded: true),
                          .performedByBackend(succeeded: false),
                          "the outcome must travel INSIDE the case: measured wiring W2 is exactly the "
                          + "confusion of 'took the role and failed' with 'never claimed it'")
    }

    // MARK: - 2. …and it provably does nothing, which is what makes the pair recursion-proof

    /// **The property that matters, stated as a measurement rather than as a promise.** Calling
    /// either member must leave the responder chain exactly as it found it — nobody focused, nobody
    /// defocused, no `becomeFirstResponder()` reaching the canvas.
    ///
    /// Driven many times, in both focus states, because the failure this guards against
    /// (`host.hostInputView.becomeFirstResponder()` as the body) would show up as a state CHANGE on
    /// the unfocused leg and as unbounded recursion only once a host adopts the member. A state
    /// assertion catches it here, before any host does.
    func test_theShippingBackendNeverEntersTheResponderChain() {
        let canvas = realCanvas()

        let beforeUnfocused = read(canvas)
        for _ in 0..<8 {
            _ = canvas.inputBackend.acquireFirstResponder()
            _ = canvas.inputBackend.relinquishFirstResponder()
        }
        let afterUnfocused = read(canvas)

        XCTAssertTrue(canvas.becomeFirstResponder())
        let beforeFocused = read(canvas)
        for _ in 0..<8 {
            _ = canvas.inputBackend.acquireFirstResponder()
            _ = canvas.inputBackend.relinquishFirstResponder()
        }
        let afterFocused = read(canvas)

        XCTAssertEqual(beforeUnfocused, ChainReading(canvasIsFirstResponder: false,
                                                     windowHasFirstResponder: false))
        XCTAssertEqual(afterUnfocused, beforeUnfocused,
                       "acquireFirstResponder() FOCUSED the canvas — the shipping backend entered the "
                       + "responder chain, which is the body that recurses once a host adopts the "
                       + "member the way the contract documents")
        XCTAssertEqual(beforeFocused, ChainReading(canvasIsFirstResponder: true,
                                                   windowHasFirstResponder: true))
        XCTAssertEqual(afterFocused, beforeFocused,
                       "relinquishFirstResponder() DEFOCUSED the canvas — same defect, other direction")
    }

    /// The same property from the other side: the six `host…FirstResponder` notifications belong to
    /// the `.hostOwnsTheRole` arm, and calling the hand-off pair must not fire any of them. A backend
    /// that ran the host bracket from inside `acquireFirstResponder()` would double every
    /// `backendDidBeginEditing()` the day a host adopts the member.
    ///
    /// # FIX ROUND 1 — this test previously COULD NOT FAIL, and it was framed as a guarantee about
    /// the shipping backend
    ///
    /// It built a canvas over `SpyRichTextInputBackend` and then called
    /// `canvas.inputBackend.acquireFirstResponder()` — i.e. called the SPY, with the canvas out of the
    /// path entirely. The spy's body is `note(…); return stub`, so the assertion held by construction
    /// of the double, for every conformer, forever. That is this programme's signature failure shape
    /// (the F1 boundary hole, the parity harness's anchored vacuity guard, a manifest that passed by
    /// having nothing to check) reproduced inside the fix round for it.
    ///
    /// It now drives **`LegacyRichTextInputBackend` itself**, and observes the effect a reader
    /// actually cares about: `backendDidBeginEditing()` / `backendDidEndEditing()` reach the host as
    /// `DocumentCanvasView.onBecameFirstResponder` / `onResignedFirstResponder`
    /// (`TelegramLifecycleInputClient`), which is the chat composer's focus callback. **The control is
    /// the half that makes it able to fail**: the same two closures are shown firing for a genuine
    /// `becomeFirstResponder()` / `resignFirstResponder()` on the same canvas, in the same test, so
    /// "no callback" is a measurement rather than an absence of wiring.
    func test_theHandOffPairFiresNoHostFocusCallbackOnTheShippingBackend() {
        let canvas = realCanvas()
        var events: [String] = []
        canvas.onBecameFirstResponder = { events.append("became") }
        canvas.onResignedFirstResponder = { events.append("resigned") }

        for _ in 0..<4 {
            _ = canvas.inputBackend.acquireFirstResponder()
            _ = canvas.inputBackend.relinquishFirstResponder()
        }
        let afterHandOff = events

        // THE CONTROL. Without it, `[]` above is equally consistent with a canvas whose callbacks are
        // never wired at all, which is precisely how the previous version of this test passed.
        events = []
        XCTAssertTrue(canvas.becomeFirstResponder())
        XCTAssertTrue(canvas.resignFirstResponder())
        let afterRealTransitions = events

        XCTAssertEqual(afterHandOff, [],
                       "the hand-off pair drove a host focus callback on the SHIPPING backend — a "
                       + "backend that ran the host bracket from inside acquireFirstResponder() "
                       + "would double every backendDidBeginEditing() once a host adopts the member")
        XCTAssertEqual(afterRealTransitions, ["became", "resigned"],
                       "the control failed: this canvas does not deliver focus callbacks at all, so "
                       + "the empty result above proves nothing")
    }

    /// The routing half, kept separate from the test above now that that one drives the real backend:
    /// the pair must REACH the backend (otherwise every assertion here is about a member nobody
    /// called), and must reach it without dragging a host notification along. Read through a spy,
    /// which is the only way to observe "which backend member was called".
    ///
    /// **This one is about the CALL, not about Legacy** — that distinction is what the previous
    /// version of the test above got wrong, so it is stated in the name.
    func test_theHandOffPairReachesTheBackendAndNothingElseDoes() {
        let spy = SpyRichTextInputBackend()
        let canvas = DocumentCanvasView(inputBackend: spy)
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])],
                             width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        window.addSubview(canvas)
        canvas.layoutIfNeeded()
        spy.reset()

        _ = canvas.inputBackend.acquireFirstResponder()
        _ = canvas.inputBackend.relinquishFirstResponder()
        let calls = spy.calls.map(\.member)

        XCTAssertEqual(calls, ["acquireFirstResponder()", "relinquishFirstResponder()"],
                       "the pair must reach the backend, and nothing else may ride along: \(calls)")
    }
}

/// The window's current first responder, found by walking the view tree. `UIWindow` has no public
/// accessor and the private `firstResponder` selector is banned in this package
/// (`InputBackendSourceBoundaryTests` R1), so this is the ordinary tree walk.
@available(iOS 13.0, *)
private extension UIWindow {
    var firstResponder: UIResponder? { Self.firstResponder(in: self) }

    static func firstResponder(in view: UIView) -> UIResponder? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }
}
#endif
