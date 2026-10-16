import XCTest
import UIKit
import AsyncDisplayKit
@testable import Display

/// A screen that records its appearance calls; with `nodeView` its display node is view-backed by that view.
private final class SteeringController: ViewController {
    var events: [String] = []
    var barSource: NavigationBarTransitionSource?
    var nodeView: UIView?

    override var navigationBarTransitionSource: NavigationBarTransitionSource? {
        return self.barSource
    }

    init() {
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        if let nodeView = self.nodeView {
            self.displayNode = ASDisplayNode(viewBlock: { nodeView }, didLoad: nil)
        } else {
            super.loadDisplayNode()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.events.append("willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.events.append("didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.events.append("willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.events.append("didDisappear")
    }
}

/// A bar that takes no part in the morph and reports where its back button is.
private final class SteeringBarSource: NavigationBarTransitionSource {
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    var backFrame: CGRect?

    func takeView() -> NavigationBarTransitionTakeViewInfo? {
        return nil
    }

    func putBack() {
    }

    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    func backButtonFrame(in view: UIView) -> CGRect? {
        return self.backFrame
    }
}

/// Reports itself first responder without a window (a logic test has no key window to make a real one).
private final class FirstResponderStandIn: UIView {
    override var isFirstResponder: Bool {
        return true
    }
}

/// A screen's view that counts the editing ends asked of it.
private final class EndEditingRecordingView: UIView {
    var endEditingCalls = 0

    override func endEditing(_ force: Bool) -> Bool {
        self.endEditingCalls += 1
        return super.endEditing(force)
    }
}

private struct NoKeyboardHost: StatusBarHost {
    var statusBarFrame: CGRect {
        return CGRect()
    }
    var keyboardWindow: UIWindow? {
        return nil
    }
    var keyboardView: UIView? {
        return nil
    }
    var isApplicationInForeground: Bool {
        return true
    }
}

/// The navigation controller's half of a removal: `controllerRemoved` drops the screen from the stack and updates the
/// container at once, as `NavigationController.filterController` does.
final class FilteringStack {
    let container: NavigationContainer
    let layout: ContainerViewLayout
    private(set) var controllers: [ViewController] = []
    private(set) var removed: [ViewController] = []

    init(container: NavigationContainer, layout: ContainerViewLayout) {
        self.container = container
        self.layout = layout
        container.controllerRemoved = { [weak self] controller in
            self?.remove(controller)
        }
    }

    func set(_ controllers: [ViewController], animated: Bool) {
        self.controllers = controllers
        self.container.update(layout: self.layout, canBeClosed: false, controllers: controllers, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
    }

    private func remove(_ controller: ViewController) {
        self.removed.append(controller)
        let filtered = self.controllers.filter { $0 !== controller }
        if filtered.count != self.controllers.count {
            self.set(filtered, animated: false)
        }
    }
}

/// Steering any push (spec: docs/superpowers/specs/2026-10-16-steerable-navigation-transitions-design.md): touches
/// reach the screen a transition is heading to from 0.25 s; back turns a push back at any moment.
final class NavigationTransitionSteeringTests: XCTestCase {
    private let size = CGSize(width: 390.0, height: 844.0)
    private let time = ManualAnimationTime()

    private var layout: ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhone13, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    override func setUp() {
        super.setUp()
        self.time.attach()
    }

    override func tearDown() {
        self.time.detach()
        super.tearDown()
    }

    private func makeContainer(removed: @escaping (ViewController) -> Void = { _ in }) -> NavigationContainer {
        let container = NavigationContainer(isFlat: false, controllerRemoved: removed)
        container.frame = CGRect(origin: CGPoint(), size: self.size)
        return container
    }

    /// Frames of 1/240 s: a dragging finger's spring steps, and the transition's clock moves on.
    private func tick(_ container: NavigationContainer, seconds: CGFloat) {
        let steps = Int((seconds * 240.0).rounded())
        for _ in 0 ..< steps {
            container.transitionCoordinatorForTesting?.progressDriverForTesting?.tick(dt: 1.0 / 240.0)
            self.time.advance(by: 1.0 / 240.0)
        }
    }

    private func push(_ container: NavigationContainer, _ a: ViewController, _ b: ViewController) {
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
    }

    private func hits(_ view: UIView?, _ screen: ViewController) -> Bool {
        return view?.isDescendant(of: screen.displayNode.view) ?? false
    }

    // Before 0.25 s a push takes no touch; from then the pushed screen gets it while the push still runs.
    func test_push_touchesReachThePushedScreenFrom025s() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        let point = CGPoint(x: 300.0, y: 400.0)
        self.tick(container, seconds: 0.2)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(container.hitTest(point, with: nil) === container.view)
        self.tick(container, seconds: 0.06)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "still running: the gate, not the end, lets it through")
        XCTAssertTrue(self.hits(container.hitTest(point, with: nil), b))
    }

    // A pop's touches go to the screen it reveals, never the leaving one.
    func test_pop_touchesReachTheRevealedScreenFrom025s() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        let point = CGPoint(x: 300.0, y: 400.0)
        self.tick(container, seconds: 0.2)
        XCTAssertTrue(container.hitTest(point, with: nil) === container.view)
        self.tick(container, seconds: 0.06)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(self.hits(container.hitTest(point, with: nil), a))
    }

    // While a finger steers, nothing else is taken.
    func test_fingerSteering_swallowsTouches() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 60.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.5)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(container.hitTest(CGPoint(x: 300.0, y: 400.0), with: nil) === container.view)
    }

    // A swipe's release starts the 0.25 s again: let go short, the screen springing back gets touches from 0.25 s after
    // the release. (The system's cancel springs back from rest on the critically damped spring, which is still running at
    // 0.26 s; a finger's release toward the start on the interactive spring stops where it first reaches it, by ~0.2 s.)
    func test_swipeRelease_closesTheGateFor025s() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 150.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.4)
        container.interactivePopEnded(translation: 150.0, velocity: 0.0, isCancelled: true, time: 0.2)
        let point = CGPoint(x: 300.0, y: 400.0)
        self.tick(container, seconds: 0.2)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(container.hitTest(point, with: nil) === container.view)
        self.tick(container, seconds: 0.06)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(self.hits(container.hitTest(point, with: nil), b))
    }

    // Review Focus 2: a touch lands where the moving screen is drawn, not at its model frame. Early in a push the pushed
    // screen is drawn right of its model frame (x = 0): a point just inside its drawn left edge hits it, a point left of
    // that does not.
    func test_push_touchFollowsTheDrawnScreen() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.26)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            return XCTFail("no push")
        }
        let drawnMinX = coordinator.screenLayout(progress: coordinator.progress).topFrame.minX
        XCTAssertGreaterThan(drawnMinX, 2.0, "the pushed screen is still moving at 0.26 s")
        XCTAssertTrue(self.hits(container.hitTest(CGPoint(x: drawnMinX + 1.0, y: 400.0), with: nil), b))
        XCTAssertTrue(container.hitTest(CGPoint(x: drawnMinX - 1.0, y: 400.0), with: nil) === container.view)
    }

    // Back during a slide push turns it back from where it is: the same transition, run back to the screen beneath;
    // the pushed screen goes, the screen beneath appears, and the 0.25 s gate starts again.
    func test_slidePush_back_turnsItBack() {
        let a = SteeringController()
        let b = SteeringController()
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        self.push(container, a, b)
        self.tick(container, seconds: 0.1)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            return XCTFail("no push")
        }
        a.events = []
        b.events = []
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertTrue(container.transitionCoordinatorForTesting === coordinator, "the same transition, turned back")
        XCTAssertTrue(coordinator.headingNode === a.displayNode)
        self.tick(container, seconds: 0.2)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(container.hitTest(CGPoint(x: 300.0, y: 400.0), with: nil) === container.view, "the gate closed again")
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertNil(b.displayNode.supernode)
        XCTAssertTrue(container.topControllerForTesting === a)
        XCTAssertEqual(a.events, ["willAppear", "didAppear"])
        XCTAssertEqual(b.events, ["willDisappear", "didDisappear"])
        XCTAssertTrue(removed.isEmpty, "the stack already dropped it")
    }

    // Review Focus 1: a pushed screen holding the keyboard, turned back: the keyboard rides with it (not with the screen
    // beneath, which is the stack's top again), and its editing ends when the reversal lands.
    func test_slidePush_back_keyboardLeavesWithTheReversedScreen() {
        let a = SteeringController()
        let b = SteeringController()
        let view = EndEditingRecordingView()
        view.addSubview(FirstResponderStandIn())
        b.nodeView = view
        let container = self.makeContainer()
        container.keyboardViewManager = KeyboardViewManager(host: NoKeyboardHost())
        self.push(container, a, b)
        self.tick(container, seconds: 0.1)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        guard let leftEdge = container.keyboardLeftEdgeForTesting else {
            return XCTFail("the keyboard stays")
        }
        let gone = CGRect(x: 390.0, y: 0.0, width: 390.0, height: 844.0)
        let beneath = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        XCTAssertEqual(leftEdge(gone, beneath), 390.0, "it rides the reversed screen out")
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(view.endEditingCalls, 1)
    }

    // Every push has a back-button hole, at the incoming bar's back button, while it can be turned back. A bar outside
    // the morph is drawn with its screen, ahead of the screen's model frame, and the hole follows it there. The hole
    // renders transparent contents (a layer that renders nothing gets no real touches on iOS 26/27) and goes with the
    // push.
    func test_slidePush_backHole() {
        let a = SteeringController()
        let b = SteeringController()
        let bar = SteeringBarSource()
        bar.backFrame = CGRect(x: 8.0, y: 54.0, width: 44.0, height: 44.0)
        b.barSource = bar
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.15)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            return XCTFail("no push")
        }
        let shift = coordinator.presentedDisplacement(of: b.displayNode.view)
        XCTAssertGreaterThan(shift.x, 10.0)
        XCTAssertLessThan(shift.x, 340.0)
        XCTAssertTrue(container.hitTest(CGPoint(x: 30.0, y: 76.0), with: nil) === container.view, "not where the button will be")
        guard let hole = container.hitTest(CGPoint(x: 30.0 + shift.x, y: 76.0), with: nil) else {
            return XCTFail("no hole")
        }
        XCTAssertFalse(hole === container.view)
        XCTAssertFalse(self.hits(hole, b))
        XCTAssertNotNil(hole.layer.contents)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertNil(hole.superview, "the hole goes with the transition")
    }

    // A new push while back turns a push back lands the reversal — the pushed screen where it was heading, off the
    // screen — not the push (which would draw it full-screen for a frame).
    func test_slidePush_back_newPush_landsTheReversal() {
        let a = SteeringController()
        let b = SteeringController()
        let c = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.1)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.05)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, c], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertNil(b.displayNode.supernode)
        XCTAssertEqual(b.displayNode.frame.minX, 390.0, accuracy: 0.5)
    }

    /// Settled: no transition, and the container holds exactly the top screen (no node, dim, shadow or back hole left).
    private func assertSettled(_ container: NavigationContainer, top: ViewController, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(container.transitionCoordinatorForTesting, file: file, line: line)
        XCTAssertTrue(container.topControllerForTesting === top, file: file, line: line)
        XCTAssertEqual(container.subnodes?.count, 1, file: file, line: line)
        XCTAssertTrue(container.subnodes?.first === top.displayNode, file: file, line: line)
        XCTAssertEqual(container.view.subviews.count, 1, file: file, line: line)
    }

    func test_invariant_reversalThenSizeChange() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.1)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.05)
        let wider = self.layout.withUpdatedSize(CGSize(width: 420.0, height: 844.0))
        container.update(layout: wider, canBeClosed: false, controllers: [a], transition: .immediate)
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: a)
        XCTAssertNil(b.displayNode.supernode)
    }

    func test_invariant_reversalThenNewPush() {
        let a = SteeringController()
        let b = SteeringController()
        let c = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.1)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.05)
        a.events = []
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, c], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: c)
        XCTAssertNil(b.displayNode.supernode)
        // The landed reversal's screen appears once, before it leaves; the pushed one appears after it is told it will.
        XCTAssertEqual(a.events, ["didAppear", "willDisappear", "didDisappear"])
        XCTAssertEqual(c.events, ["willAppear", "didAppear"])
    }

    // A push arriving while one runs (a tap from 0.25 s that pushes) lands the running one on its own screen: that screen
    // appears once, then leaves; the new one is told it will appear before it does.
    func test_pushDuringPush_appearanceInOrder() {
        let a = SteeringController()
        let b = SteeringController()
        let c = SteeringController()
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b, c], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: c)
        XCTAssertEqual(b.events, ["willAppear", "didAppear", "willDisappear", "didDisappear"])
        XCTAssertEqual(c.events, ["willAppear", "didAppear"])
    }

    // The hole, once touched, leaves with a reversal too.
    func test_invariant_backHoleThenReversal() {
        let a = SteeringController()
        let b = SteeringController()
        let bar = SteeringBarSource()
        bar.backFrame = CGRect(x: 8.0, y: 54.0, width: 44.0, height: 44.0)
        b.barSource = bar
        let container = self.makeContainer()
        self.push(container, a, b)
        self.tick(container, seconds: 0.15)
        let shift = container.transitionCoordinatorForTesting?.presentedDisplacement(of: b.displayNode.view) ?? CGPoint()
        let hole = container.hitTest(CGPoint(x: 30.0 + shift.x, y: 76.0), with: nil)
        XCTAssertFalse(hole === container.view || hole == nil, "touched the hole")
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: a)
    }

    private func filtering(_ controllers: [ViewController]) -> FilteringStack {
        let stack = FilteringStack(container: self.makeContainer(), layout: self.layout)
        stack.set(controllers, animated: false)
        return stack
    }

    /// A swipe back from b to a, committed by a flick.
    private func swipeBackCommitted(_ container: NavigationContainer) {
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 300.0, velocity: 1500.0, time: 0.1)
        container.interactivePopChanged(translation: 330.0, velocity: 1500.0, time: 0.12)
        container.interactivePopChanged(translation: 360.0, velocity: 1500.0, time: 0.14)
        container.interactivePopEnded(translation: 360.0, velocity: 1500.0, isCancelled: false, time: 0.15)
    }

    // A swipe back committed: the swiped screen leaves the stack at the release, as UIKit's does, and the pop runs on to
    // the screen beneath, which is the container's top from then on; it lands with each screen told once.
    func test_swipeBackCommit_dropsTheScreenAtTheRelease() {
        let a = SteeringController()
        let b = SteeringController()
        let stack = self.filtering([a, b])
        let container = stack.container
        a.events = []
        b.events = []
        self.swipeBackCommitted(container)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertTrue(stack.removed.first === b)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "the pop runs on")
        XCTAssertTrue(container.topControllerForTesting === a)
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: a)
        XCTAssertNil(b.displayNode.supernode)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertEqual(a.events, ["willAppear", "didAppear"])
        XCTAssertEqual(b.events, ["willDisappear", "didDisappear"])
    }

    // A push from the revealed screen while the committed swipe runs on (a tap from 0.25 s after the release): the pop
    // lands first, on the revealed screen, and the push runs from it; the swiped screen leaves once.
    func test_swipeBackCommit_pushFromTheRevealedScreen() {
        let a = SteeringController()
        let b = SteeringController()
        let c = SteeringController()
        let stack = self.filtering([a, b])
        let container = stack.container
        a.events = []
        b.events = []
        self.swipeBackCommitted(container)
        self.tick(container, seconds: 0.1)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        stack.set([a, c], animated: true)
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: c)
        XCTAssertNil(b.displayNode.supernode)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertEqual(a.events, ["willAppear", "didAppear", "willDisappear", "didDisappear"])
        XCTAssertEqual(b.events, ["willDisappear", "didDisappear"])
        XCTAssertEqual(c.events, ["willAppear", "didAppear"])
    }

    // A push a swipe caught and let go toward the screen beneath: the pushed screen leaves the stack at the release too.
    func test_caughtPushCommit_dropsTheScreenAtTheRelease() {
        let a = SteeringController()
        let b = SteeringController()
        let stack = self.filtering([a])
        let container = stack.container
        stack.set([a, b], animated: true)
        self.tick(container, seconds: 0.05)
        a.events = []
        b.events = []
        self.swipeBackCommitted(container)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertTrue(stack.removed.first === b)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "the push runs back")
        XCTAssertTrue(container.topControllerForTesting === a)
        self.tick(container, seconds: 2.0)
        self.assertSettled(container, top: a)
        XCTAssertNil(b.displayNode.supernode)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertEqual(a.events, ["willAppear", "didAppear"])
        XCTAssertEqual(b.events, ["willDisappear", "didDisappear"])
    }

    // Focus follows the screen a transition heads to once the stack drops the other: back mid-push and a committed swipe.
    func test_focusMovesToTheScreenBeneath() {
        let a = SteeringController()
        let b = SteeringController()
        let container = self.makeContainer()
        container.isInFocus = true
        self.push(container, a, b)
        XCTAssertTrue(b.isInFocus)
        XCTAssertFalse(a.isInFocus)
        self.tick(container, seconds: 0.1)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertTrue(a.isInFocus, "back mid-push")
        XCTAssertFalse(b.isInFocus)

        let c = SteeringController()
        let d = SteeringController()
        let stack = self.filtering([c, d])
        stack.container.isInFocus = true
        XCTAssertTrue(d.isInFocus)
        self.swipeBackCommitted(stack.container)
        XCTAssertTrue(c.isInFocus, "a committed swipe")
        XCTAssertFalse(d.isInFocus)
    }
}
