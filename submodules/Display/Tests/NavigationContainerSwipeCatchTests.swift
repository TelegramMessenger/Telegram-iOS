import XCTest
import UIKit
import AsyncDisplayKit
@testable import Display

/// A bar that takes part in transitions and can hold its glass.
private final class HoldingSource: NavigationBarTransitionSource {
    let containingView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    let contentView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    var holds: [Bool] = []

    init() {
        self.containingView.addSubview(self.contentView)
    }

    func takeView() -> NavigationBarTransitionTakeViewInfo? {
        return NavigationBarTransitionTakeViewInfo(containingView: self.containingView, contentView: self.contentView)
    }

    func putBack() {
        self.containingView.addSubview(self.contentView)
    }

    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        self.holds.append(held)
        return true
    }
}

/// Glass that is always still animating when the screens' transition ends.
private final class AnimatingGlassRenderer: NavigationBarTransitionRenderer {
    let backdropView = UIView()
    let rowView = UIView()
    var isGlassAnimating = true
    var glassSettled: (() -> Void)?

    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition) {
    }

    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect) {
    }
}

private final class RecordingController: ViewController {
    var events: [String] = []
    var source: HoldingSource?

    override var navigationBarTransitionSource: NavigationBarTransitionSource? {
        return self.source
    }

    init(name: String) {
        super.init(navigationBarPresentationData: nil)
        self.title = name
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

/// A swipe back that begins while a transition runs, as UIKit's interruptible navigation transitions take it (measured
/// on the iOS 27 simulator against the native reference app, 2026-10-14):
/// - a running push is taken over: the pushed screen's card goes on from where it is, at the speed it has, and the
///   finger then steers a pop whose progress counts from 0 (the pushed screen on screen);
/// - a pop springing back after a cancelled swipe is taken over from the progress it has (RE §1.2: paused at its
///   percent);
/// - a pop running to the screen beneath is not (UIKit starts a second pop alongside it instead).
final class NavigationContainerSwipeCatchTests: XCTestCase {
    private let size = CGSize(width: 390.0, height: 844.0)

    private var layout: ContainerViewLayout {
        return ContainerViewLayout(size: self.size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhone13, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private func makeContainer(removed: @escaping (ViewController) -> Void = { _ in }) -> NavigationContainer {
        let container = NavigationContainer(isFlat: false, controllerRemoved: removed)
        container.frame = CGRect(origin: CGPoint(), size: self.size)
        return container
    }

    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
    }

    override func tearDown() {
        self.time.detach()
        super.tearDown()
    }

    /// Frames of 1/240 s: a dragging finger's spring steps, and the transition's clock moves on (running any deadline
    /// due).
    private func tick(_ container: NavigationContainer, seconds: CGFloat) {
        let steps = Int((seconds * 240.0).rounded())
        for _ in 0 ..< steps {
            container.transitionCoordinatorForTesting?.progressDriverForTesting?.tick(dt: 1.0 / 240.0)
            self.time.advance(by: 1.0 / 240.0)
        }
    }

    func test_swipe_catchesARunningPush_andPopsItWhenLetGo() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        coordinator.frameTiming = { (lastTargetTimestamp: nil, frameDuration: 1.0 / 120.0) }
        self.tick(container, seconds: 0.05)
        let caughtAt = coordinator.popProgress
        XCTAssertGreaterThan(caughtAt, 0.1)
        XCTAssertLessThan(caughtAt, 0.9)
        a.events = []
        b.events = []

        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        XCTAssertTrue(container.transitionCoordinatorForTesting === coordinator, "the push itself is taken over")
        XCTAssertTrue(coordinator.isInteractive)
        // Taken over where it is when the swap lands: the next frame plus one of headroom.
        let push = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
        XCTAssertEqual(coordinator.popProgress, 1.0 - push.value(at: 0.05 + 2.0 / 120.0), accuracy: 0.0001, "taken over where it is")
        XCTAssertEqual(b.events, ["willDisappear"])
        XCTAssertEqual(a.events, ["willAppear"])

        // The finger steers a pop whose progress counts from 0.
        container.interactivePopChanged(translation: 39.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.5)
        XCTAssertEqual(coordinator.popProgress, 0.1, accuracy: 0.002)
        XCTAssertEqual(coordinator.topNode.frame.minX, 39.0, accuracy: 1.0)

        container.interactivePopChanged(translation: 300.0, velocity: 1500.0, time: 0.2)
        container.interactivePopChanged(translation: 330.0, velocity: 1500.0, time: 0.22)
        container.interactivePopChanged(translation: 360.0, velocity: 1500.0, time: 0.24)
        container.interactivePopEnded(translation: 360.0, velocity: 1500.0, isCancelled: false, time: 0.25)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(removed.first === b)
        XCTAssertNil(coordinator.topNode.supernode)
        // The push's own ending never ran: b never appeared, a never left.
        XCTAssertFalse(b.events.contains("didAppear"))
        XCTAssertFalse(a.events.contains("didDisappear"))
    }

    func test_swipe_catchesARunningPush_andLetsItFinish() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        self.tick(container, seconds: 0.05)
        container.interactivePopBegan(translation: 0.0, velocity: 100.0, time: 0.0)
        container.interactivePopChanged(translation: 10.0, velocity: 50.0, time: 0.1)
        container.interactivePopChanged(translation: 12.0, velocity: -50.0, time: 0.2)
        container.interactivePopChanged(translation: 8.0, velocity: -100.0, time: 0.3)
        container.interactivePopEnded(translation: 8.0, velocity: -100.0, isCancelled: false, time: 0.31)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(container.topControllerForTesting === b)
        XCTAssertEqual(coordinator.progress, 1.0)
        XCTAssertNil(a.displayNode.supernode)
        XCTAssertEqual(b.events.last, "didAppear")
        XCTAssertEqual(a.events.last, "didDisappear")
    }

    func test_swipe_catchesAPopSpringingBack_fromWhereItIs() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 117.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.5)
        container.interactivePopEnded(translation: 117.0, velocity: -200.0, isCancelled: false, time: 0.2)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no pop")
            return
        }
        self.tick(container, seconds: 0.04)
        let caughtAt = coordinator.popProgress
        XCTAssertGreaterThan(caughtAt, 0.05)
        XCTAssertLessThan(caughtAt, 0.3)
        let willDisappearCount = b.events.filter({ $0 == "willDisappear" }).count

        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 1.0)
        XCTAssertTrue(container.transitionCoordinatorForTesting === coordinator)
        XCTAssertTrue(coordinator.isInteractive)
        container.interactivePopChanged(translation: 39.0, velocity: 300.0, time: 1.1)
        self.tick(container, seconds: 0.5)
        XCTAssertEqual(coordinator.popProgress, caughtAt + 0.1, accuracy: 0.002, "counted from where it was caught")
        XCTAssertEqual(b.events.filter({ $0 == "willDisappear" }).count, willDisappearCount, "nothing new appears or disappears")

        container.interactivePopChanged(translation: 300.0, velocity: 1500.0, time: 1.2)
        container.interactivePopChanged(translation: 330.0, velocity: 1500.0, time: 1.22)
        container.interactivePopChanged(translation: 360.0, velocity: 1500.0, time: 1.24)
        container.interactivePopEnded(translation: 360.0, velocity: 1500.0, isCancelled: false, time: 1.25)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(removed.first === b)
    }

    func test_swipe_doesNotCatchAPopRunningToTheScreenBeneath() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .animated(duration: 0.5, curve: .spring))
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no pop")
            return
        }
        self.tick(container, seconds: 0.05)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 20.0, velocity: 300.0, time: 0.1)
        XCTAssertFalse(coordinator.isInteractive)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(container.topControllerForTesting === a)
    }

    // Review finding 1: the stack changing under a finger (another push, a screen closing itself) ends the swipe's hold on
    // the transition. The new transition runs on its own, and the one the finger had caught is completed as a push cut
    // short is.
    func test_stackChangeWhileASwipeSteers_endsTheSwipe() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        let c = RecordingController(name: "c")
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
        guard let caught = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        self.tick(container, seconds: 0.05)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 39.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.1)
        XCTAssertTrue(caught.isInteractive)

        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b, c], transition: .animated(duration: 0.5, curve: .spring))
        guard let next = container.transitionCoordinatorForTesting, next !== caught else {
            XCTFail("no second push")
            return
        }
        XCTAssertNil(a.displayNode.supernode, "the caught push was completed")
        container.interactivePopChanged(translation: 300.0, velocity: 1500.0, time: 0.2)
        container.interactivePopChanged(translation: 330.0, velocity: 1500.0, time: 0.22)
        container.interactivePopEnded(translation: 360.0, velocity: 1500.0, isCancelled: false, time: 0.25)
        XCTAssertFalse(next.isInteractive)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(container.topControllerForTesting === c)
        XCTAssertEqual(next.progress, 1.0)
    }

    // Review finding 2: a push whose screen beneath is not the previous top (a replace) is not caught: the swipe would
    // show a screen that has left the stack.
    func test_swipe_doesNotCatchAPushThatReplacedTheTop() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        let c = RecordingController(name: "c")
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, c], transition: .animated(duration: 0.5, curve: .spring))
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        self.tick(container, seconds: 0.05)
        b.events = []
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        XCTAssertFalse(coordinator.isInteractive)
        XCTAssertFalse(b.events.contains("willAppear"))
    }

    // Review finding 4: while a swipe steers a caught push the status bar follows it as a swipe back's does, switching to
    // the screen beneath's at 0.3 of the way.
    func test_caughtPush_statusBarFollowsTheSwipe() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        a.statusBar.statusBarStyle = .Black
        b.statusBar.statusBarStyle = .White
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.05)
        XCTAssertEqual(container.statusBarStyle, .White)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 200.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.5)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopChanged(translation: 40.0, velocity: -300.0, time: 0.2)
        self.tick(container, seconds: 0.5)
        XCTAssertEqual(container.statusBarStyle, .White)
    }

    // Review finding 5: a swipe that begins during a transition is held to the restrictions of the screen under the
    // finger, though the container takes every touch then.
    func test_swipeRestrictions_comeFromTheScreenUnderTheFinger() {
        let a = RecordingController(name: "a")
        let b = RecordingController(name: "b")
        let container = self.makeContainer()
        container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.05)
        let onTop = CGPoint(x: 389.0, y: 400.0)
        XCTAssertTrue(container.hitTest(onTop, with: nil) === container.view, "touches still go to the container")
        let target = container.gestureRestrictionsHitTest(onTop, with: nil)
        XCTAssertTrue(target?.isDescendant(of: b.displayNode.view) ?? false, "\(String(describing: target)); b \(b.displayNode.view) at \(b.displayNode.frame), in \(String(describing: b.displayNode.view.superview))")
        let beneath = CGPoint(x: 10.0, y: 400.0)
        let targetBeneath = container.gestureRestrictionsHitTest(beneath, with: nil)
        XCTAssertTrue(targetBeneath?.isDescendant(of: a.displayNode.view) ?? false, "\(String(describing: targetBeneath)); a \(a.displayNode.view) at \(a.displayNode.frame)")
    }

    // After a swipe is let go the status bar flips when the curve crosses 0.3 of the pop, scheduled on the transition's
    // clock rather than read per frame.
    func test_releasedSwipe_flipsTheStatusBarAtTheCrossing() {
        let container = self.makeContainer()
        let a = RecordingController(name: "a")
        a.statusBar.statusBarStyle = .White
        let b = RecordingController(name: "b")
        b.statusBar.statusBarStyle = .Black
        container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
        container.interactivePopChanged(translation: 40.0, velocity: 300.0, time: 0.1)
        self.tick(container, seconds: 0.3)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopEnded(translation: 200.0, velocity: 1500.0, isCancelled: false, time: 0.2)
        self.tick(container, seconds: 0.5)
        XCTAssertEqual(container.statusBarStyle, .White)
    }


    private func withAnimatingGlass(_ body: () -> Void) {
        defaultNavigationBarTransitionRenderer = { _, _ in
            return AnimatingGlassRenderer()
        }
        body()
        defaultNavigationBarTransitionRenderer = nil
    }

    private func makeBarredController(_ name: String) -> RecordingController {
        let controller = RecordingController(name: name)
        let source = HoldingSource()
        controller.source = source
        controller.displayNode.view.addSubview(source.containingView)
        return controller
    }

    // A finished swipe back ends in an immediate stack update that adds the screen beneath to the container again,
    // which brings it to the front: the glass still animating above that screen's bar is raised back over it.
    func test_lingeringGlass_staysAboveTheScreenAfterAFinishedSwipe() {
        self.withAnimatingGlass {
            let a = self.makeBarredController("a")
            let b = self.makeBarredController("b")
            var removed: [ViewController] = []
            let container = self.makeContainer(removed: { removed.append($0) })
            container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .immediate)
            container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0)
            container.interactivePopChanged(translation: 300.0, velocity: 1500.0, time: 0.1)
            container.interactivePopChanged(translation: 330.0, velocity: 1500.0, time: 0.12)
            container.interactivePopChanged(translation: 360.0, velocity: 1500.0, time: 0.14)
            container.interactivePopEnded(translation: 360.0, velocity: 1500.0, isCancelled: false, time: 0.15)
            // To the swipe's end, inside the linger's 1.5 s cap.
            self.tick(container, seconds: 1.0)
            XCTAssertTrue(removed.first === b)
            container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
            guard let lingering = container.lingeringNavigationBarTransitionLayerForTesting else {
                XCTFail("no lingering glass")
                return
            }
            XCTAssertTrue(container.subnodes?.last === lingering, "the glass is above the screen")
            XCTAssertEqual(a.source?.holds, [true])
        }
    }

    // An immediate stack change to a screen whose bar does not hold the glass ends the linger.
    func test_lingeringGlass_endsOnAnUnrelatedImmediateChange() {
        self.withAnimatingGlass {
            let a = self.makeBarredController("a")
            let b = self.makeBarredController("b")
            let c = self.makeBarredController("c")
            let container = self.makeContainer()
            container.update(layout: self.layout, canBeClosed: false, controllers: [a], transition: .immediate)
            container.update(layout: self.layout, canBeClosed: false, controllers: [a, b], transition: .animated(duration: 0.5, curve: .spring))
            self.tick(container, seconds: 2.0)
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
            XCTAssertEqual(b.source?.holds, [true])
            container.update(layout: self.layout, canBeClosed: false, controllers: [a, b, c], transition: .immediate)
            XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
            XCTAssertEqual(b.source?.holds, [true, false])
        }
    }
}

