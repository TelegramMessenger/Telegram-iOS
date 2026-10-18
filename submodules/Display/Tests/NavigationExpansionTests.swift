import XCTest
import UIKit
import AsyncDisplayKit
@testable import Display

final class FakeExpansionSource: NavigationExpansionSource {}
final class FakeExpansionDestination: NavigationExpansionDestination {}

/// Records what the coordinator asks of it.
final class FakeExpansionRenderer: NavigationExpansionRenderer {
    let openSpring = NavigationTransitionSpring(duration: 0.55, bounce: 0.28)
    let closeSpring = NavigationTransitionSpring(duration: 0.5, bounce: 0.22)
    let view = UIView()
    let underView = UIView()
    var barExclusions = NavigationBarTransitionExclusions.none
    let barGlassStart: CGFloat = 0.25
    var backButtonFrame: CGRect? = CGRect(x: 16.0, y: 64.0, width: 44.0, height: 44.0)
    var begins: [(time: CGFloat, isOpening: Bool)] = []
    var updates: [(time: CGFloat, isOpening: Bool, pose: NavigationExpansionCardPose)] = []
    var timelines: [NavigationExpansionTimeline] = []
    var ends: [Bool] = []

    /// The upper screen, which the real renderer transforms into the swipe's card.
    private weak var topView: UIView?

    func begin(topView: UIView, bottomView: UIView, size: CGSize, time: CGFloat, isOpening: Bool) {
        self.begins.append((time, isOpening))
        self.topView = topView
    }

    func update(time: CGFloat, isOpening: Bool, pose: NavigationExpansionCardPose) {
        self.updates.append((time, isOpening, pose))
        self.topView?.transform = pose.isActive ? CGAffineTransform(scaleX: 0.5, y: 0.5) : .identity
    }

    func animate(timeline: NavigationExpansionTimeline) {
        self.timelines.append(timeline)
    }

    func barFraction(time: CGFloat, isOpening: Bool) -> CGFloat {
        return min(max(time, 0.0), 1.0)
    }

    func end(atTop: Bool) {
        self.ends.append(atTop)
        self.events?.append("expansion ends")
    }

    /// Shared with the bar fakes to order what happens at an ending.
    var events: EventLog?
}

final class EventLog {
    var entries: [String] = []

    func append(_ entry: String) {
        self.entries.append(entry)
    }
}

/// A bar whose glass is still moving when the transition ends: it holds its glass while the transition's lingers.
final class LingeringBarSource: NavigationBarTransitionSource {
    let containingView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    let contentView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    let name: String
    let events: EventLog

    init(name: String, events: EventLog) {
        self.name = name
        self.events = events
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
        self.events.append("\(self.name) holds \(held)")
        return true
    }
}

final class LingeringBarRenderer: NavigationBarTransitionRenderer {
    let backdropView = UIView()
    let rowView = UIView()
    var isGlassAnimating = true
    var glassSettled: (() -> Void)?

    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition) {
    }

    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect) {
    }
}

/// A bar taking part in a transition, its content liftable.
final class ExpansionBarSource: NavigationBarTransitionSource {
    let containingView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    let contentView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    var transitionContentFrameUpdated: ((CGRect) -> Void)?

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
}

/// Records the exclusions it is told and when its glass begins.
final class ExpansionBarRenderer: NavigationBarTransitionRenderer {
    let backdropView = UIView()
    let rowView = UIView()
    var exclusions: NavigationBarTransitionExclusions?
    var begins: [Bool] = []
    var beginsInteractive: [Bool] = []
    var interactionEnds: [Bool] = []

    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition) {
    }

    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect) {
    }

    func beginTransition(isInteractive: Bool, toTop: Bool) {
        self.begins.append(toTop)
        self.beginsInteractive.append(isInteractive)
    }

    func updateExclusions(bottom: NavigationBarTransitionExclusions) {
        self.exclusions = bottom
    }

    func endInteraction(towardTop: Bool) {
        self.interactionEnds.append(towardTop)
    }
}

/// A screen that expands out of the one below it (the profile), or provides the origin (the chat).
final class ExpansionController: ViewController {
    var source: FakeExpansionSource?
    var destination: FakeExpansionDestination?
    var asked: [NavigationExpansionOperation] = []
    var barSource: NavigationBarTransitionSource?

    override var navigationBarTransitionSource: NavigationBarTransitionSource? {
        return self.barSource
    }

    /// A view-backed display node, like the app's screens: a frame set on it goes to the view (UIKit's frame).
    var viewBackedNode = false
    /// Its appearance calls, in order.
    var events: [String] = []

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

    init() {
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        if self.viewBackedNode {
            self.displayNode = ASDisplayNode(viewBlock: { UIView() }, didLoad: nil)
        } else {
            super.loadDisplayNode()
        }
    }

    override func navigationExpansionSource(above controller: ViewController, operation: NavigationExpansionOperation) -> NavigationExpansionSource? {
        return self.source
    }

    override func navigationExpansionDestination(below controller: ViewController, operation: NavigationExpansionOperation) -> NavigationExpansionDestination? {
        self.asked.append(operation)
        return self.destination
    }
}

func makeExpansionLayout(width: CGFloat = 390.0, widthClass: ContainerViewLayoutSizeClass = .compact, formSheet: Bool = false) -> ContainerViewLayout {
    return ContainerViewLayout(size: CGSize(width: width, height: 844.0), metrics: LayoutMetrics(widthClass: widthClass, heightClass: .regular, orientation: nil), deviceMetrics: .iPhone13, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: formSheet)
}

final class NavigationExpansionTests: XCTestCase {
    override func tearDown() {
        defaultNavigationExpansionRenderer = nil
        self.time.detach()
        super.tearDown()
    }

    private func pair() -> (top: ExpansionController, bottom: ExpansionController) {
        let top = ExpansionController()
        top.destination = FakeExpansionDestination()
        let bottom = ExpansionController()
        bottom.source = FakeExpansionSource()
        return (top, bottom)
    }

    func test_styleResolution_expandsWhenBothSidesAndARendererAnswer() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        guard case let .expand(resolved) = navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(), reduceMotion: false) else {
            XCTFail("slide")
            return
        }
        XCTAssertTrue(resolved === renderer)
        XCTAssertEqual(top.asked, [.push])
    }

    // Review Focus 5: Reduce Motion, a regular-width (iPad) layout, a form sheet, a flat (split) container, a missing
    // side or no renderer all give the slide.
    func test_styleResolution_fallsBackToSlide() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        func isSlide(_ style: NavigationTransitionStyle) -> Bool {
            if case .slide = style {
                return true
            }
            return false
        }
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(), reduceMotion: true)))
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(width: 1024.0, widthClass: .regular), reduceMotion: false)))
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(formSheet: true), reduceMotion: false)))
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: true, layout: makeExpansionLayout(), reduceMotion: false)))
        bottom.source = nil
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(), reduceMotion: false)))
        bottom.source = FakeExpansionSource()
        defaultNavigationExpansionRenderer = nil
        XCTAssertTrue(isSlide(navigationTransitionStyle(top: top, bottom: bottom, operation: .push, isFlat: false, layout: makeExpansionLayout(), reduceMotion: false)))
    }

    // The card pose (`CardPose`, SwipeBack.swift): scale 1 − 0.7·dx/width down to 0.45, around the touch point.
    func test_cardPose_scalesAroundTheTouch() {
        let pose = NavigationExpansionCardPose(dx: 117.0, dy: 20.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0)
        XCTAssertEqual(pose.scale(width: 390.0), 1.0 - 0.7 * 117.0 / 390.0, accuracy: 1e-9)
        XCTAssertEqual(NavigationExpansionCardPose(dx: 390.0, dy: 0.0, anchor: .zero, weight: 1.0).scale(width: 390.0), 0.45, accuracy: 1e-9)
        let moved = CGPoint(x: 40.0, y: 520.0).applying(pose.transform(width: 390.0))
        XCTAssertEqual(moved.x, 40.0 + 117.0, accuracy: 1e-9, "the touch point stays under the finger")
        XCTAssertEqual(moved.y, 520.0 + 20.0, accuracy: 1e-9)
        XCTAssertEqual(pose.fade(width: 390.0), 117.0 / (390.0 * 0.35), accuracy: 1e-9)
        XCTAssertEqual(pose.released(0.0).transform(width: 390.0), .identity)
        XCTAssertEqual(NavigationExpansionCardPose.releasedWeight(time: 1.0), 1.0)
        XCTAssertEqual(NavigationExpansionCardPose.releasedWeight(time: 0.5), 0.75, accuracy: 1e-9)
        XCTAssertEqual(NavigationExpansionCardPose.releasedWeight(time: 0.0), 0.0)
    }

    // Commit past 0.3 of the width, or flung: projected past half the width at over 300 pt/s.
    func test_swipeDecision() {
        XCTAssertTrue(navigationExpansionCommits(dx: 120.0, velocity: 0.0, width: 390.0))
        XCTAssertFalse(navigationExpansionCommits(dx: 110.0, velocity: 0.0, width: 390.0))
        XCTAssertTrue(navigationExpansionCommits(dx: 40.0, velocity: 400.0, width: 390.0))
        XCTAssertFalse(navigationExpansionCommits(dx: 40.0, velocity: 250.0, width: 390.0))
    }

    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
    }


    private func makeContainer(removed: @escaping (ViewController) -> Void = { _ in }) -> NavigationContainer {
        let container = NavigationContainer(isFlat: false, controllerRemoved: removed)
        container.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        return container
    }

    private func tick(_ container: NavigationContainer, seconds: CGFloat) {
        let steps = Int((seconds * 240.0).rounded())
        for _ in 0 ..< steps {
            container.transitionCoordinatorForTesting?.progressDriverForTesting?.tick(dt: 1.0 / 240.0)
            self.time.advance(by: 1.0 / 240.0)
        }
    }

    private func expandingPush() -> (NavigationContainer, top: ExpansionController, bottom: ExpansionController, renderer: FakeExpansionRenderer) {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        return (container, top, bottom, renderer)
    }

    // A tap push in the expand style: neither screen slides, the renderer begins at 0 in the opening windows and gets
    // a timeline that overshoots past 1 on the open spring; it ends on the top once.
    func test_expandPush_stillScreens_overshootingTimeline_endsOnce() {
        let (container, top, bottom, renderer) = self.expandingPush()
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        XCTAssertTrue(coordinator.isExpansion)
        XCTAssertEqual(renderer.begins.first?.time, 0.0)
        XCTAssertEqual(renderer.begins.first?.isOpening, true)
        XCTAssertEqual(top.displayNode.frame.minX, 0.0)
        XCTAssertEqual(bottom.displayNode.frame.minX, 0.0)
        guard let timeline = renderer.timelines.first else {
            XCTFail("no timeline")
            return
        }
        XCTAssertTrue(timeline.isOpening)
        XCTAssertGreaterThan(timeline.times.max() ?? 0.0, 1.0, "the open spring overshoots")
        XCTAssertEqual(timeline.times.last ?? 0.0, 1.0, accuracy: 0.0005)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [true])
        XCTAssertNil(renderer.view.superview)
        XCTAssertNil(renderer.underView.superview)
    }

    // Review Focus 2: a stack change mid-expansion completes it at once; the renderer ends exactly once.
    func test_expandPush_stackChangeMidway_endsTheRendererOnce() {
        let (container, _, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        let other = ExpansionController()
        // Another push arriving (animated, as pushes are) pre-empts the running one through `performCompletion`.
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, other], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(renderer.ends, [true])
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(renderer.ends, [true])
    }

    // Review Focus 3: a size change mid-expansion completes it at once (its geometry was measured for the old size).
    func test_expandPush_sizeChange_completesAtOnce() {
        let (container, _, _, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        container.update(layout: makeExpansionLayout(width: 420.0), canBeClosed: false, controllers: container.controllers, transition: .immediate)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [true])
    }

    // A swipe can catch an expanding push (pushes only), and the screens are where they are drawn.
    func test_expandPush_caughtBySwipe_noDisplacement() {
        let (container, top, _, _) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        XCTAssertTrue(coordinator.canBeCaughtBySwipe)
        XCTAssertEqual(coordinator.presentedDisplacement(of: top.displayNode.view), CGPoint())
    }

    // A swipe catches an expanding push mid-open: the clock freezes where it is, and the finger's pose carries the card
    // from there (the renderer is updated at that time, with the pose).
    func test_expandPush_caughtBySwipe_freezesTheClock() {
        let (container, _, _, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            return XCTFail("no push")
        }
        let at = coordinator.expansionTime(progress: coordinator.progress)
        XCTAssertGreaterThan(at, 0.05)
        XCTAssertLessThan(at, 0.95)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        XCTAssertTrue(container.transitionCoordinatorForTesting === coordinator, "caught, not replaced")
        XCTAssertTrue(coordinator.isInteractive)
        container.interactivePopChanged(translation: 80.0, velocity: 300.0, time: 0.1, translationY: 12.0)
        guard let update = renderer.updates.last else {
            return XCTFail("no update")
        }
        XCTAssertEqual(update.time, at, accuracy: 0.02)
        XCTAssertTrue(update.isOpening, "the opening's windows")
        XCTAssertEqual(update.pose, NavigationExpansionCardPose(dx: 80.0, dy: 12.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0))
        let count = renderer.updates.count
        self.tick(container, seconds: 1.0)
        XCTAssertEqual(renderer.updates.count, count, "the clock stays frozen while the finger holds")
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
    }

    // Released past the threshold: the push turns back from the frozen time on the close spring, the released pose letting
    // go as the clock falls from there (t(2 − t) of the time over the frozen time); the pushed screen leaves the stack.
    func test_expandPush_caught_commit_turnsItBack() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.1)
        let at = container.transitionCoordinatorForTesting.map { $0.expansionTime(progress: $0.progress) } ?? 0.0
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        renderer.timelines = []
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        guard let timeline = renderer.timelines.last else {
            return XCTFail("no close")
        }
        XCTAssertTrue(timeline.isOpening, "the opening's windows, played back")
        XCTAssertEqual(timeline.times.first ?? 0.0, at, accuracy: 0.02)
        XCTAssertLessThan(timeline.times.min() ?? 1.0, 0.0, "the close spring lands past 0")
        XCTAssertEqual(timeline.poses.first?.dx, 160.0)
        for (time, pose) in zip(timeline.times, timeline.poses) {
            XCTAssertEqual(pose.weight, NavigationExpansionCardPose.releasedWeight(time: time / at), accuracy: 1e-6)
        }
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(removed.first === top)
    }

    // Released short: the push runs on to the profile from the frozen time on the open spring, the pose springing back in
    // the same timeline; the screen beneath leaves as a finished push's does.
    func test_expandPush_caught_cancel_landsOnThePushedScreen() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        let at = container.transitionCoordinatorForTesting.map { $0.expansionTime(progress: $0.progress) } ?? 0.0
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 40.0, velocity: 50.0, time: 0.1, translationY: 0.0)
        renderer.timelines = []
        container.interactivePopEnded(translation: 40.0, velocity: 50.0, isCancelled: false, time: 0.2, translationY: 0.0)
        guard let timeline = renderer.timelines.last else {
            return XCTFail("no landing")
        }
        XCTAssertTrue(timeline.isOpening)
        XCTAssertEqual(timeline.times.first ?? 0.0, at, accuracy: 0.02)
        XCTAssertGreaterThan(timeline.times.max() ?? 0.0, 1.0, "the open spring lands past 1")
        XCTAssertEqual(timeline.poses.first?.dx, 40.0)
        XCTAssertEqual(timeline.poses.first?.weight ?? 0.0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(timeline.poses.last?.weight ?? 1.0, 0.0, accuracy: 0.001)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [true])
        XCTAssertTrue(container.topControllerForTesting === top)
        XCTAssertNil(bottom.displayNode.supernode)
    }

    // Caught again while it runs on after a short release: the second release starts from the second drag's pose, not
    // the first one's spring-back.
    func test_expandPush_caughtAgain_commitsFromTheNewPose() {
        let (container, top, _, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 40.0, velocity: 50.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 40.0, velocity: 50.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 0.05)
        XCTAssertTrue(container.transitionCoordinatorForTesting?.canBeCaughtBySwipe ?? false)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 1.0, translationY: 0.0, anchor: CGPoint(x: 60.0, y: 400.0))
        container.interactivePopChanged(translation: 170.0, velocity: 300.0, time: 1.1, translationY: 0.0)
        renderer.timelines = []
        container.interactivePopEnded(translation: 170.0, velocity: 300.0, isCancelled: false, time: 1.2, translationY: 0.0)
        guard let timeline = renderer.timelines.last else {
            return XCTFail("no close")
        }
        XCTAssertEqual(timeline.poses.first?.dx, 170.0)
        XCTAssertEqual(timeline.poses.first?.anchor, CGPoint(x: 60.0, y: 400.0))
        XCTAssertEqual(timeline.poses.first?.weight ?? 0.0, 1.0, accuracy: 1e-6)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
    }

    // Pops are never kept: a swipe during an expanding pop is ignored and the close finishes.
    func test_expandPop_swipeIsIgnored() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 2.0)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 80.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        XCTAssertFalse(container.transitionCoordinatorForTesting?.isInteractive ?? true)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [true, false])
        XCTAssertNil(top.displayNode.supernode)
    }

    private func statusBarPush() -> (NavigationContainer, top: ExpansionController, bottom: ExpansionController) {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.statusBar.statusBarStyle = .White
        bottom.statusBar.statusBarStyle = .Black
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        return (container, top, bottom)
    }

    // Review Focus 4: caught after the status bar turned to the profile's, it follows the card's fade (the chat's from
    // 0.3), as the swipe from the profile does; a commit gives the chat's at once.
    func test_expandPush_caughtAfterTheTurn_statusBarFollowsTheFade() {
        let (container, _, _) = self.statusBarPush()
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(container.statusBarStyle, .White)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 20.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .White)
        container.interactivePopChanged(translation: 120.0, velocity: 300.0, time: 0.2, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopChanged(translation: 20.0, velocity: -300.0, time: 0.3, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .White)
        // A flick commits (projected past half the width).
        container.interactivePopEnded(translation: 20.0, velocity: 1500.0, isCancelled: false, time: 0.35, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .Black)
    }

    // Review Focus 4: caught before it turned, the chat's status bar stays through the drag; let go short, it turns to
    // the profile's when the card covers it again (0.3 of the open spring after the release).
    func test_expandPush_caughtBeforeTheTurn_keepsTheChatsStatusBar() {
        let (container, _, _) = self.statusBarPush()
        self.tick(container, seconds: 0.1)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 20.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopChanged(translation: 120.0, velocity: 300.0, time: 0.2, translationY: 0.0)
        container.interactivePopChanged(translation: 20.0, velocity: -300.0, time: 0.3, translationY: 0.0)
        XCTAssertEqual(container.statusBarStyle, .Black)
        container.interactivePopEnded(translation: 20.0, velocity: -100.0, isCancelled: false, time: 0.35, translationY: 0.0)
        self.tick(container, seconds: 0.1)
        XCTAssertEqual(container.statusBarStyle, .Black)
        self.tick(container, seconds: 0.1)
        XCTAssertEqual(container.statusBarStyle, .White)
    }

    // A tap pop from an expanded screen runs the close windows from 1 and ends on the bottom.
    func test_expandPop_closesFromOne_endsOnTheBottom() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 2.0)
        renderer.timelines = []
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(top.asked.last, .pop)
        guard let timeline = renderer.timelines.first else {
            XCTFail("no close")
            return
        }
        XCTAssertFalse(timeline.isOpening)
        XCTAssertEqual(timeline.times.first ?? 0.0, 1.0, accuracy: 1e-6)
        XCTAssertLessThan(timeline.times.min() ?? 1.0, 0.0, "the close spring lands past 0")
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(renderer.ends, [true, false])
    }

    // An expanding push leaves the keyboard to the system: no keyboard edge follows the still screens.
    func test_expandPush_keyboardDoesNotRideTheScreens() {
        let (container, _, _, _) = self.expandingPush()
        XCTAssertNil(container.keyboardLeftEdgeForTesting)
    }

    // Back mid-open: the push runs back to 0 from where it is on the close spring, keeping the opening windows; the
    // pushed screen goes, the one beneath stays; the push's own ending never runs.
    func test_backMidOpen_reverses() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.15)
        guard let coordinator = container.transitionCoordinatorForTesting else {
            XCTFail("no push")
            return
        }
        let at = coordinator.expansionTime(progress: coordinator.progress)
        XCTAssertGreaterThan(at, 0.2)
        renderer.timelines = []
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertTrue(container.transitionCoordinatorForTesting === coordinator, "the same transition, reversed")
        guard let timeline = renderer.timelines.first else {
            XCTFail("no reversal")
            return
        }
        XCTAssertTrue(timeline.isOpening, "the opening's windows, played back")
        XCTAssertEqual(timeline.times.first ?? 0.0, at, accuracy: 0.05)
        XCTAssertEqual(timeline.times.last ?? 1.0, 0.0, accuracy: 0.0005)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertTrue(container.topControllerForTesting === bottom)
    }

    // A size change (rotation, Duo fold) while back mid-open runs: the reversal lands where it was heading — the screen
    // beneath on top, the reversed screen gone, the transition over — instead of jumping to the push's end with the
    // transition never cleared (every touch swallowed, the profile left on screen).
    func test_backMidOpen_sizeChange_landsTheReversal() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.15)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.1)
        container.update(layout: makeExpansionLayout(width: 420.0), canBeClosed: false, controllers: container.controllers, transition: .immediate)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertTrue(container.topControllerForTesting === bottom)
    }

    // A push arriving while back mid-open runs: the reversal lands first (the reversed screen leaves), then the new
    // screen is pushed over the one beneath.
    func test_backMidOpen_newPush_landsTheReversalFirst() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.15)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.1)
        let next = ExpansionController()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, next], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertTrue(container.topControllerForTesting === next)
    }

    // Back before the bars' morph window: the bars, holding the chat's capsules since the push began, settle on them;
    // the window then does not release them toward the profile.
    func test_backBeforeTheBarsGlassWindow_beginsTheBarsOnTheChat() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        var barRenderer: ExpansionBarRenderer?
        defaultNavigationBarTransitionRenderer = { _, _ in
            let r = ExpansionBarRenderer()
            barRenderer = r
            return r
        }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let (top, bottom) = self.pair()
        top.barSource = ExpansionBarSource()
        bottom.barSource = ExpansionBarSource()
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 0.03)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [])
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(barRenderer?.begins ?? [], [true], "begun once, from the chat's capsules")
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [false])
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [false], "the push's window does not release them toward the profile")
    }

    // During an expanding push the back button's frame alone reaches anything.
    func test_hitTest_duringExpandPush_reachesOnlyTheBackHole() {
        let (container, _, _, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.05)
        let back = renderer.backButtonFrame!
        let hit = container.hitTest(CGPoint(x: back.midX, y: back.midY), with: nil)
        XCTAssertNotNil(hit)
        XCTAssertFalse(hit === container.view)
        XCTAssertTrue(container.hitTest(CGPoint(x: 200.0, y: 400.0), with: nil) === container.view)
    }

    // From 0.25 s an expanding push's touches reach the profile only inside its card (the mask it is drawn through):
    // around the card the chat is still what is seen, and the profile's invisible content there must not take the tap.
    func test_hitTest_expandPush_touchesInsideTheCardOnly() {
        let (container, top, _, _) = self.expandingPush()
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting)
        let card = CALayer()
        card.frame = CGRect(x: 100.0, y: 200.0, width: 150.0, height: 150.0)
        top.displayNode.layer.mask = card
        XCTAssertTrue(container.hitTest(CGPoint(x: 170.0, y: 270.0), with: nil)?.isDescendant(of: top.displayNode.view) ?? false)
        XCTAssertTrue(container.hitTest(CGPoint(x: 300.0, y: 600.0), with: nil) === container.view)
    }

    // A pop running takes no touch before 0.25 s, the back button's frame included (pops are never kept).
    func test_hitTest_duringExpandPop_blocksTouches() {
        let (container, _, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 2.0)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        let back = renderer.backButtonFrame!
        XCTAssertTrue(container.hitTest(CGPoint(x: back.midX, y: back.midY), with: nil) === container.view)
    }

    private var lastBottom: ExpansionController?

    private func expanded() -> (NavigationContainer, top: ExpansionController, bottom: ExpansionController, renderer: FakeExpansionRenderer, removed: () -> [ViewController]) {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        self.lastBottom = bottom
        var removed: [ViewController] = []
        let container = self.makeContainer(removed: { removed.append($0) })
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .immediate)
        return (container, top, bottom, renderer, { removed })
    }

    // The finger moves the card: the renderer gets the pose per change (leftward travel at a quarter), the clock stays
    // at 1, the screens stay still.
    func test_swipe_movesTheCard() {
        let (container, top, _, renderer, _) = self.expanded()
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 80.0, velocity: 300.0, time: 0.1, translationY: 12.0)
        XCTAssertEqual(renderer.updates.last?.time, 1.0)
        XCTAssertEqual(renderer.updates.last?.pose, NavigationExpansionCardPose(dx: 80.0, dy: 12.0, anchor: CGPoint(x: 40.0, y: 520.0), weight: 1.0))
        container.interactivePopChanged(translation: -40.0, velocity: -300.0, time: 0.2, translationY: 0.0)
        XCTAssertEqual(renderer.updates.last?.pose.dx ?? 0.0, -10.0, accuracy: 1e-9)
        XCTAssertEqual(top.displayNode.frame.minX, 0.0)
    }

    // Released past a third: the close runs from the released pose, its weight t(2 − t), and the screen is removed.
    func test_swipe_commit_closesFromThePose() {
        let (container, top, _, renderer, removed) = self.expanded()
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        guard let timeline = renderer.timelines.last else {
            XCTFail("no close")
            return
        }
        XCTAssertFalse(timeline.isOpening)
        XCTAssertEqual(timeline.poses.first?.dx, 160.0)
        for (time, pose) in zip(timeline.times, timeline.poses) {
            XCTAssertEqual(pose.weight, NavigationExpansionCardPose.releasedWeight(time: time), accuracy: 1e-9)
        }
        self.tick(container, seconds: 2.0)
        XCTAssertTrue(removed().first === top)
        XCTAssertEqual(renderer.ends, [false])
    }

    // The renderer transforms the upper screen into the swipe's card. Released, the close runs the screens' layout on
    // its clock, and a frame set on a transformed view moves and resizes it: the profile jumped to the top left and
    // grew. An expansion's screens stay where they are, transformed or not.
    func test_swipeCommit_leavesTheTransformedScreenWhereItIs() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.viewBackedNode = true
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        XCTAssertNotEqual(top.displayNode.view.transform, .identity)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 0.1)
        XCTAssertEqual(top.displayNode.view.bounds.size, CGSize(width: 390.0, height: 844.0))
        XCTAssertEqual(top.displayNode.view.center, CGPoint(x: 195.0, y: 422.0))
    }

    // Released short: the pose springs back; the clock never leaves 1; the screen stays.
    func test_swipe_cancel_springsTheCardBack() {
        let (container, top, _, renderer, removed) = self.expanded()
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 60.0, velocity: 100.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 60.0, velocity: 100.0, isCancelled: false, time: 0.2, translationY: 0.0)
        guard let timeline = renderer.timelines.last else {
            XCTFail("no spring back")
            return
        }
        XCTAssertTrue(timeline.times.allSatisfy { $0 == 1.0 })
        XCTAssertEqual(timeline.poses.first?.weight ?? 0.0, 1.0, accuracy: 1e-6)
        XCTAssertEqual(timeline.poses.last?.weight ?? 1.0, 0.0, accuracy: 0.0005)
        self.tick(container, seconds: 2.0)
        XCTAssertTrue(removed().isEmpty)
        XCTAssertEqual(renderer.ends, [true])
        XCTAssertTrue(container.topControllerForTesting === top)
        // As the slide's cancel does: the screen beneath leaves the hierarchy.
        XCTAssertNil(self.lastBottom?.displayNode.supernode)
    }

    // A size change while a cancelled swipe springs back: it lands where it was heading (the profile stays, the
    // transition is over) instead of finishing the pop under a screen that is still on top.
    func test_swipeCancel_sizeChange_landsTheCancel() {
        let (container, top, bottom, renderer, removed) = self.expanded()
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        XCTAssertNotNil(bottom.displayNode.supernode, "the chat is beneath while the finger is down")
        container.interactivePopChanged(translation: 60.0, velocity: 100.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 60.0, velocity: 100.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 0.1)
        container.update(layout: makeExpansionLayout(width: 420.0), canBeClosed: false, controllers: container.controllers, transition: .immediate)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertTrue(removed().isEmpty)
        XCTAssertEqual(renderer.ends, [true])
        XCTAssertTrue(container.topControllerForTesting === top)
        XCTAssertNil(bottom.displayNode.supernode)
    }

    // Back stays and takes the chat's look by the card's fade (spec, swipe back). The capsules run on their own springs (a
    // dragging finger does not move them), so the bar hands them to the lower screen once the fade passes the status
    // bar's moment (0.3), and takes them back below it.
    func test_swipe_barTakesTheLowerLook_pastTheStatusBarsMoment() {
        var barRenderer: ExpansionBarRenderer?
        defaultNavigationBarTransitionRenderer = { _, _ in
            let r = ExpansionBarRenderer()
            barRenderer = r
            return r
        }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.barSource = ExpansionBarSource()
        bottom.barSource = ExpansionBarSource()
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        XCTAssertNotNil(barRenderer)
        // The fade is dx over 0.35 of the width (136.5 pt here).
        container.interactivePopChanged(translation: 30.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [])
        container.interactivePopChanged(translation: 60.0, velocity: 300.0, time: 0.2, translationY: 0.0)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [false])
        container.interactivePopChanged(translation: 70.0, velocity: 300.0, time: 0.25, translationY: 0.0)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [false])
        container.interactivePopChanged(translation: 20.0, velocity: -300.0, time: 0.3, translationY: 0.0)
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [false, true])
    }

    // The bars' glass can still be moving when the close lands; it then lingers above the chat's bar, which holds its own
    // glass meanwhile, and the lingering glass leaves out what the expansion drew (the pill, the avatar's capsule). So
    // the expansion stays until the linger ends and ends right after the chat's bar takes its glass back, in the same
    // turn: before, the pill and the avatar were missing for the linger (~0.33 s, measured).
    func test_expandPop_endsWithTheBarsLinger() {
        let events = EventLog()
        var barRenderers: [LingeringBarRenderer] = []
        defaultNavigationBarTransitionRenderer = { _, _ in
            let r = LingeringBarRenderer()
            barRenderers.append(r)
            return r
        }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let renderer = FakeExpansionRenderer()
        renderer.events = events
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.barSource = LingeringBarSource(name: "profile", events: events)
        bottom.barSource = LingeringBarSource(name: "chat", events: events)
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        barRenderers.last?.glassSettled?()
        XCTAssertEqual(renderer.ends, [true])
        events.entries = []

        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(renderer.ends, [true], "the expansion stays while the bars' glass lingers above the chat")
        XCTAssertEqual(events.entries, ["chat holds true"])
        barRenderers.last?.glassSettled?()
        XCTAssertEqual(renderer.ends, [true, false])
        XCTAssertEqual(events.entries, ["chat holds true", "chat holds false", "expansion ends"])
    }

    // A transition starting while the glass lingers takes the bars at once; the expansion ends with the linger, before it.
    func test_expandPop_lingerEndedByTheNextTransition_endsTheExpansionFirst() {
        let events = EventLog()
        defaultNavigationBarTransitionRenderer = { _, _ in LingeringBarRenderer() }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let renderer = FakeExpansionRenderer()
        renderer.events = events
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.barSource = LingeringBarSource(name: "profile", events: events)
        bottom.barSource = LingeringBarSource(name: "chat", events: events)
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .animated(duration: 0.5, curve: .spring))
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(renderer.ends, [])
        let next = ExpansionController()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, next], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(renderer.ends, [false])
    }

    // A swipe released past the threshold closes like back: the expansion ends with the bars' linger too.
    func test_swipeCommit_endsWithTheBarsLinger() {
        let events = EventLog()
        var barRenderers: [LingeringBarRenderer] = []
        defaultNavigationBarTransitionRenderer = { _, _ in
            let r = LingeringBarRenderer()
            barRenderers.append(r)
            return r
        }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let renderer = FakeExpansionRenderer()
        renderer.events = events
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.barSource = LingeringBarSource(name: "profile", events: events)
        bottom.barSource = LingeringBarSource(name: "chat", events: events)
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .immediate)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 2.0)
        XCTAssertEqual(renderer.ends, [])
        barRenderers.last?.glassSettled?()
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertEqual(Array(events.entries.suffix(2)), ["chat holds false", "expansion ends"])
    }

    // In an expansion both bars stay whole (nothing slides to cut them), the renderer is told what the expansion took,
    // and the bars' glass starts at the expansion's window.
    func test_expandPush_barsUnclipped_exclusionsPassed_glassAtItsWindow() {
        let renderer = FakeExpansionRenderer()
        let node = ASDisplayNode()
        renderer.barExclusions = NavigationBarTransitionExclusions(titlePill: true, nodes: [node])
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        var barRenderer: ExpansionBarRenderer?
        defaultNavigationBarTransitionRenderer = { _, _ in
            let r = ExpansionBarRenderer()
            barRenderer = r
            return r
        }
        defer { defaultNavigationBarTransitionRenderer = nil }
        let (top, bottom) = self.pair()
        let topBar = ExpansionBarSource()
        let bottomBar = ExpansionBarSource()
        top.barSource = topBar
        bottom.barSource = bottomBar
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(bottomBar.contentView.superview?.bounds.width, 390.0, "the lower bar is not cut by the still upper screen")
        XCTAssertEqual(barRenderer?.exclusions?.titlePill, true)
        XCTAssertTrue(barRenderer?.exclusions?.nodes.first === node)
        // The bars take the chat's capsules at once and hold them as they are (they no longer draw them themselves);
        // the morph toward the profile's starts at its window. Begun only at the window, the chat's back capsule and
        // the bars' other glass were missing until then (~0.13 s, measured).
        XCTAssertEqual(barRenderer?.begins ?? [], [true])
        XCTAssertEqual(barRenderer?.beginsInteractive ?? [], [true])
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [], "not yet: the morph starts at its window")
        self.tick(container, seconds: 0.2)
        XCTAssertEqual(barRenderer?.begins ?? [], [true])
        XCTAssertEqual(barRenderer?.interactionEnds ?? [], [true])
    }

    // The status bar turns when the card has covered it, not at the tap: at 0.45 of the open spring toward dark, 0.3
    // toward light (`RootView.run`, ProfileApp.swift:814).
    func test_expandPush_statusBarTurnsAtItsMoment() {
        let renderer = FakeExpansionRenderer()
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let (top, bottom) = self.pair()
        top.statusBar.statusBarStyle = .White
        bottom.statusBar.statusBarStyle = .Black
        let container = self.makeContainer()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom], transition: .immediate)
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top], transition: .animated(duration: 0.5, curve: .spring))
        XCTAssertEqual(container.statusBarStyle, .Black)
        self.tick(container, seconds: 0.55 * 0.3 - 0.02)
        XCTAssertEqual(container.statusBarStyle, .Black)
        self.tick(container, seconds: 0.04)
        XCTAssertEqual(container.statusBarStyle, .White)
    }

    // Review Focus 3: the stack changing under a finger holding a caught expanding push: it lands once, the next push runs.
    func test_invariant_caughtExpansion_stackChangeUnderTheFinger() {
        let (container, top, bottom, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 60.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        let next = ExpansionController()
        container.update(layout: makeExpansionLayout(), canBeClosed: false, controllers: [bottom, top, next], transition: .animated(duration: 0.5, curve: .spring))
        container.interactivePopChanged(translation: 80.0, velocity: 300.0, time: 0.2, translationY: 0.0)
        container.interactivePopEnded(translation: 80.0, velocity: 300.0, isCancelled: false, time: 0.3, translationY: 0.0)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends.count, 1)
        XCTAssertTrue(container.topControllerForTesting === next)
        XCTAssertEqual(container.subnodes?.count, 1)
        XCTAssertNil(renderer.view.superview)
        // The landed push's screen appears once, before it leaves; the next one appears after it is told it will.
        XCTAssertEqual(next.events, ["willAppear", "didAppear"])
        XCTAssertEqual(top.events.filter { $0 == "didAppear" }.count, 1)
        XCTAssertEqual(Array(top.events.suffix(3)), ["didAppear", "willDisappear", "didDisappear"])
    }

    // A swipe committed toward the chat whose profile the stack has not dropped (the removal here only records it): a
    // push from the chat meanwhile would stack on top of the profile, so that tail takes no touch.
    func test_hitTest_committedSwipeTail_takesNoTouch() {
        let (container, _, _, _, _) = self.expanded()
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "still in the tail")
        XCTAssertTrue(container.hitTest(CGPoint(x: 200.0, y: 600.0), with: nil) === container.view)
    }

    // The same for a caught expanding push committed back to the chat, its profile still in the stack.
    func test_hitTest_caughtPushCommitTail_takesNoTouch() {
        let (container, _, _, _) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "still in the tail")
        XCTAssertTrue(container.hitTest(CGPoint(x: 200.0, y: 600.0), with: nil) === container.view)
    }

    func test_invariant_caughtExpansion_sizeChange() {
        let (container, top, _, renderer) = self.expandingPush()
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.update(layout: makeExpansionLayout(width: 420.0), canBeClosed: false, controllers: container.controllers, transition: .immediate)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [true])
        XCTAssertTrue(container.topControllerForTesting === top)
        XCTAssertEqual(container.subnodes?.count, 1)
    }

    private func expandingStack(_ controllers: [ViewController], renderer: FakeExpansionRenderer) -> FilteringStack {
        defaultNavigationExpansionRenderer = { _, _, _ in renderer }
        let container = NavigationContainer(isFlat: false, controllerRemoved: { _ in })
        container.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        let stack = FilteringStack(container: container, layout: makeExpansionLayout())
        stack.set(controllers, animated: false)
        return stack
    }

    // A swipe from the profile committed toward the chat: the profile leaves the stack at the release, and from 0.25 s
    // after it the chat takes touches while the close still runs.
    func test_swipeCommit_dropsTheProfileAtTheRelease_chatTakesTouches() {
        let renderer = FakeExpansionRenderer()
        let (top, bottom) = self.pair()
        let stack = self.expandingStack([bottom, top], renderer: renderer)
        let container = stack.container
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertTrue(stack.removed.first === top)
        XCTAssertTrue(container.topControllerForTesting === bottom)
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "still in the tail")
        XCTAssertTrue(container.hitTest(CGPoint(x: 200.0, y: 600.0), with: nil)?.isDescendant(of: bottom.displayNode.view) ?? false)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertEqual(container.subnodes?.count, 1)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertEqual(bottom.events.filter { $0 == "didAppear" }.count, 1)
    }

    // Measured in the app (2026-10-18): a caught expanding push let go toward the chat left the profile's light status
    // bar over the chat until the next navigation. The release gives the chat's, and the container's updates right after
    // it (the commit drops the profile from the stack; the status bar's change lays the containers out again) took the
    // pop progress, which for an expansion is the card's clock and has not moved at the release, and put the profile's
    // back.
    func test_caughtExpansionCommit_keepsTheChatsStatusBar_throughTheStacksUpdates() {
        let renderer = FakeExpansionRenderer()
        let (top, bottom) = self.pair()
        top.statusBar.statusBarStyle = .White
        bottom.statusBar.statusBarStyle = .Black
        let stack = self.expandingStack([bottom], renderer: renderer)
        let container = stack.container
        // The navigation controller lays its containers out again when one's status bar changes.
        container.statusBarStyleUpdated = { [weak stack] _ in
            guard let stack else {
                return
            }
            stack.set(stack.controllers, animated: false)
        }
        stack.set([bottom, top], animated: true)
        self.tick(container, seconds: 0.3)
        XCTAssertEqual(container.statusBarStyle, .White, "turned to the profile's")
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        XCTAssertTrue(stack.removed.first === top)
        XCTAssertEqual(container.statusBarStyle, .Black)
        self.tick(container, seconds: 0.1)
        XCTAssertEqual(container.statusBarStyle, .Black)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(container.statusBarStyle, .Black)
    }

    // A caught expanding push committed back to the chat: the profile leaves the stack at the release too.
    func test_caughtExpansionCommit_dropsTheProfileAtTheRelease() {
        let renderer = FakeExpansionRenderer()
        let (top, bottom) = self.pair()
        let stack = self.expandingStack([bottom], renderer: renderer)
        let container = stack.container
        stack.set([bottom, top], animated: true)
        self.tick(container, seconds: 0.1)
        container.interactivePopBegan(translation: 0.0, velocity: 300.0, time: 0.0, translationY: 0.0, anchor: CGPoint(x: 40.0, y: 520.0))
        container.interactivePopChanged(translation: 160.0, velocity: 300.0, time: 0.1, translationY: 0.0)
        container.interactivePopEnded(translation: 160.0, velocity: 300.0, isCancelled: false, time: 0.2, translationY: 0.0)
        XCTAssertEqual(stack.removed.count, 1)
        XCTAssertTrue(stack.removed.first === top)
        XCTAssertTrue(container.topControllerForTesting === bottom)
        self.tick(container, seconds: 0.3)
        XCTAssertNotNil(container.transitionCoordinatorForTesting, "still in the tail")
        XCTAssertTrue(container.hitTest(CGPoint(x: 200.0, y: 600.0), with: nil)?.isDescendant(of: bottom.displayNode.view) ?? false)
        self.tick(container, seconds: 2.0)
        XCTAssertNil(container.transitionCoordinatorForTesting)
        XCTAssertEqual(renderer.ends, [false])
        XCTAssertNil(top.displayNode.supernode)
        XCTAssertEqual(container.subnodes?.count, 1)
        XCTAssertEqual(stack.removed.count, 1)
    }
}
