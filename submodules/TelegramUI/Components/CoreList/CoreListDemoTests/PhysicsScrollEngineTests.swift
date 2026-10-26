import XCTest
import UIKit
@testable import CoreListDemo

final class PhysicsScrollEngineTests: XCTestCase {

    func test_contentHost_isPlainView() {
        let engine = PhysicsScrollEngine()
        XCTAssertFalse(engine.contentHost is UIScrollView, "host is a plain UIView, not a UIScrollView")
    }

    func test_setOffset_writesOffset_doesNotFireOnScroll() {
        let engine = PhysicsScrollEngine()
        engine.contentHost.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.setOffset(140)
        XCTAssertEqual(engine.offset, 140, accuracy: 0.001)
        XCTAssertEqual(engine.contentHost.bounds.origin.y, 140, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic setOffset must not fire onScroll")
    }

    func test_applyShift_addsToOffset_doesNotFireOnScroll() {
        let engine = PhysicsScrollEngine()
        engine.contentHost.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        engine.setOffset(100)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.applyShift(25)
        XCTAssertEqual(engine.offset, 125, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty)
    }

    func test_decelerationMode_defaultsToStepped_andIsSelectable() {
        let engine = PhysicsScrollEngine()
        XCTAssertEqual(engine.decelerationMode, .stepped)
        engine.decelerationMode = .keyframe
        XCTAssertEqual(engine.decelerationMode, .keyframe)
    }

    func test_containerOrigin_delegatesToNaturalBase() {
        let engine = PhysicsScrollEngine()
        let h: CGFloat = 600
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), -h, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), -h / 2, accuracy: 0.001)
    }

    // MARK: - Gesture arbitration

    /// A fresh engine plus its host sized like a viewport, and the engine's own pan recognizer.
    private func makeArbitrationFixture() -> (engine: PhysicsScrollEngine, host: UIView, pan: UIGestureRecognizer) {
        let engine = PhysicsScrollEngine()
        let host = engine.contentHost
        host.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        let recognizers = host.gestureRecognizers ?? []
        precondition(recognizers.count == 1, "the engine attaches exactly one recognizer to its host")
        return (engine, host, recognizers[0])
    }

    /// A view under `host` carrying `recognizer` — the shape of any content recognizer in the list.
    @discardableResult
    private func addContentView(with recognizer: UIGestureRecognizer, under host: UIView) -> UIView {
        let content = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        content.addGestureRecognizer(recognizer)
        host.addSubview(content)
        return content
    }

    func test_simultaneity_deniedForNestedScrollViewPan() {
        let f = makeArbitrationFixture()
        let nested = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        f.host.addSubview(nested)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: nested.panGestureRecognizer),
            "an in-bubble scroll view competes for the same drag and must own it exclusively"
        )
    }

    func test_simultaneity_deniedForBareContentPan() {
        let f = makeArbitrationFixture()
        let contentPan = UIPanGestureRecognizer()
        addContentView(with: contentPan, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: contentPan),
            "chat's swipe-to-reply is a bare content pan and must own its drag exclusively"
        )
    }

    func test_simultaneity_deniedForContentTap() {
        let f = makeArbitrationFixture()
        let tap = UITapGestureRecognizer()
        addContentView(with: tap, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: tap),
            "exclusion is what absorbs the stopping tap; a grant here would need a failure dependency to claw it back"
        )
    }

    func test_simultaneity_deniedForPressAndHold() {
        let f = makeArbitrationFixture()
        // Stands in for Display's `ContextGesture` (a plain UIGestureRecognizer subclass), which
        // CoreList cannot import.
        let press = UIGestureRecognizer()
        addContentView(with: press, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: press),
            "granting a press-and-hold and then holding it with a failure dependency is the limbo bug"
        )
    }

    func test_simultaneity_doesNotOverrideAContentRecognizersOwnRefusal() {
        // The lesson of both arbitration bugs. UIKit takes EITHER delegate's yes, so a grant here
        // overrides a refusal that is written in a file this one never mentions — a nested scroll
        // view's UIKit default, or `ContextGesture`'s explicit `is UIPanGestureRecognizer -> false`.
        // Our pan IS a pan, so anything refusing pans is refusing us.
        let f = makeArbitrationFixture()
        let refuser = PanRefusingRecognizer(target: nil, action: nil)
        addContentView(with: refuser, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: refuser),
            "the engine must never grant simultaneity over a content recognizer's own refusal"
        )
    }

    func test_simultaneity_deniedOutsideHost() {
        let f = makeArbitrationFixture()
        let outside = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        let outsideTap = UITapGestureRecognizer()
        outside.addGestureRecognizer(outsideTap)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: outsideTap),
            "the grant is scoped to descendants of host; a sibling or ancestor recognizer gets nothing"
        )
    }

    func test_simultaneity_deniedWhenQueriedForSomeOtherRecognizer() {
        let f = makeArbitrationFixture()
        let tap = UITapGestureRecognizer()
        addContentView(with: tap, under: f.host)
        let unrelated = UIPanGestureRecognizer()

        XCTAssertFalse(
            f.engine.gestureRecognizer(unrelated, shouldRecognizeSimultaneouslyWith: tap),
            "the engine answers only for its own pan"
        )
    }

    func test_engine_declaresNoFailureDependency() {
        // A failure dependency HOLDS a content recognizer in `.possible` until the pan fails, and a
        // pan force-begun on moving content never fails until lift. `ContextGesture` drives its press
        // animation from its own timer + display link, independent of arbitration, so it animated
        // without ever activating. Exclusion fails the recognizer instead, promptly — and
        // `ListViewImpl` declares no such dependency anywhere. Re-adding one brings the limbo back.
        let engine = PhysicsScrollEngine()
        XCTAssertFalse(
            engine.responds(to: #selector(UIGestureRecognizerDelegate
                .gestureRecognizer(_:shouldBeRequiredToFailBy:))),
            "the engine must declare no failure dependency; see the limbo gotcha in CLAUDE.md"
        )
    }

    func test_shouldBegin_defersToATrackingControl() {
        let f = makeArbitrationFixture()
        // With no live touches `pan.location(in: host)` is the origin. The control fills the host, so
        // the hit test finds it wherever inside bounds that lands. If the precondition below ever
        // fails, the location convention changed — fix this geometry, not the implementation.
        let control = StubTrackingControl(frame: f.host.bounds)
        f.host.addSubview(control)
        XCTAssertTrue(f.host.hitTest(f.pan.location(in: f.host), with: nil) is StubTrackingControl,
                      "test geometry: the pan location must hit the stub control")

        control.isTrackingOverride = false
        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan),
                      "a control that is not tracking does not hold the touch")

        control.isTrackingOverride = true
        XCTAssertFalse(f.engine.gestureRecognizerShouldBegin(f.pan),
                       "a tracking UIControl keeps the touch; chat puts real UIButtons in the list")
    }

    func test_shouldBegin_twoTouchBranchPrecedesTheControlBranch() {
        // ListViewScroller checks for a two-touch pan on the same view FIRST and returns from that
        // branch, so a tracking control below is never consulted. `numberOfTouches` is read-only and
        // cannot be faked, so the touch-count answer itself is not assertable — but the ORDER is, and
        // getting it backwards would change behaviour whenever both are present.
        let f = makeArbitrationFixture()
        let control = StubTrackingControl(frame: f.host.bounds)
        control.isTrackingOverride = true
        f.host.addSubview(control)
        XCTAssertFalse(f.engine.gestureRecognizerShouldBegin(f.pan), "control branch alone")

        let twoFinger = UIPanGestureRecognizer()
        twoFinger.minimumNumberOfTouches = 2
        f.host.addGestureRecognizer(twoFinger)

        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan),
                      "the two-touch branch returns before the control branch is reached")
    }

    func test_shouldBegin_allowsByDefault() {
        let f = makeArbitrationFixture()
        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan))
    }

    func test_shouldBegin_allowsARecognizerThatIsNotOurPan() {
        let f = makeArbitrationFixture()
        let control = StubTrackingControl(frame: f.host.bounds)
        control.isTrackingOverride = true
        f.host.addSubview(control)
        let unrelated = UIPanGestureRecognizer()

        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(unrelated),
                      "the engine gates only its own pan")
    }

    // MARK: - Touch delivery

    func test_thePanDoesNotWithholdTouchUpFromTheViewsUnderIt() {
        // A fresh recognizer defaults to `delaysTouchesEnded == true`, which suspends every
        // `UITouchPhaseEnded` to the hit view until the pan resolves. `ListViewImpl` scrolls on
        // `UIScrollView.panGestureRecognizer`, where UIKit itself opts out — so keeping the default
        // here silently delays touch-up for `UIControl`s inside rows (chat's inline bot keyboards are
        // real `UIButton`s) relative to the backend this replaces.
        let f = makeArbitrationFixture()
        XCTAssertFalse(f.pan.delaysTouchesEnded,
                       "the list's pan must not delay touch-up to the views under it")

        // Control: the parity claim above, stated as an assertion rather than a comment. If UIKit ever
        // changes its own answer, this fails and the decision gets re-made instead of drifting.
        XCTAssertFalse(UIScrollView().panGestureRecognizer.delaysTouchesEnded,
                       "UIScrollView's own pan opts out; that is what makes this parity")
    }

    // MARK: - Touch-down catch

    /// An engine with a live `.stepped` deceleration and no window (so no link callbacks fire and the
    /// motion stays pending until something explicitly stops it).
    private func makeDeceleratingEngine() -> PhysicsScrollEngine {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .stepped
        engine.setEdges(min: nil, max: nil)
        engine.applyPanUpdate(state: .began, translation: CGPoint(x: 0, y: -40),
                              velocity: CGPoint(x: 0, y: -3000), forced: false, isIndirect: false)
        engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0, y: -40),
                              velocity: CGPoint(x: 0, y: -3000), forced: false, isIndirect: false)
        precondition(engine.isDecelerating, "fixture: the release must leave motion to catch")
        return engine
    }

    func test_touchDownCatchesMovingContent_withoutWaitingForTheRecognizerToBegin() {
        // The stop must not ride on `.began`. A recognizer's `.began` is arbitrated, and
        // `NavigationContainer` declares its interactive-pop pan "required to fail by" every other
        // `UIPanGestureRecognizer` — ours included — so the forced `.began` is held until that
        // recognizer fails, which for a dead-still finger is not until it LIFTS. Touch delivery cannot
        // be held, which is why the catch lives here and why UIScrollView catches in
        // `_beginTrackingWithEvent:` too.
        let engine = makeDeceleratingEngine()

        engine.noteTouchDown(at: CACurrentMediaTime())

        XCTAssertFalse(engine.isDecelerating,
                       "the finger landing stops the content, with no gesture state change involved")
    }

    func test_touchDownStillForcesTheImmediateBegin_afterItHasCaughtTheMotion() {
        // The trap that kept the catch on the `.began` path: `shouldBeginImmediately` used to re-read
        // live motion state, and by the time UIKit consults it the catch has already nulled that
        // motion — so a naive move of the catch reports "not moving", skips the forced begin, and loses
        // absorption (the tap falls through to the row as well as stopping the scroll). The captured
        // flag is what keeps both halves.
        let engine = makeDeceleratingEngine()
        let pan = (engine.contentHost.gestureRecognizers ?? []).first as? PhysicsPanGestureRecognizer
        XCTAssertNotNil(pan, "fixture: the engine attaches its own PhysicsPanGestureRecognizer")

        engine.noteTouchDown(at: CACurrentMediaTime())

        XCTAssertFalse(engine.isDecelerating, "precondition: the catch has already run")
        XCTAssertEqual(pan?.shouldBeginImmediately?(), true,
                       "a finger that landed on moving content still grabs the scroll, so the tap is absorbed")
    }

    func test_touchDownOnStillContentLeavesTheNormalHysteresisIntact() {
        // Non-vacuity control for the pair above: at rest the closure must answer false, or every tap
        // anywhere in the list would force a begin and fail the row's own recognizer by exclusion.
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.setEdges(min: nil, max: nil)
        let pan = (engine.contentHost.gestureRecognizers ?? []).first as? PhysicsPanGestureRecognizer

        engine.noteTouchDown(at: CACurrentMediaTime())

        XCTAssertFalse(engine.isDecelerating, "fixture: nothing was moving")
        XCTAssertEqual(pan?.shouldBeginImmediately?(), false,
                       "content at rest keeps the ~10pt pan hysteresis, so taps pass through to rows")
    }
}

/// A `UIControl` whose tracking state can be set, standing in for a chat inline-keyboard button
/// mid-press. `isTracking` is read-only on `UIControl` and cannot otherwise be driven without a
/// real touch stream.
private final class StubTrackingControl: UIControl {
    var isTrackingOverride = false
    override var isTracking: Bool { isTrackingOverride }
}

/// A recognizer whose OWN delegate refuses simultaneity with any pan — the shape of Display's
/// `ContextGesture` (`Display/Source/ContextGesture.swift:66`), which CoreList cannot import.
private final class PanRefusingRecognizer: UIGestureRecognizer {
    private final class RefusePans: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(other is UIPanGestureRecognizer)
        }
    }
    private let refusal = RefusePans()
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        self.delegate = refusal
    }
}
