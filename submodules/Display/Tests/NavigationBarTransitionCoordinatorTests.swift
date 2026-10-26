import XCTest
import UIKit
import AsyncDisplayKit
@testable import Display

private final class FakeSource: NavigationBarTransitionSource {
    let containingView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    let contentView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 100.0))
    /// A search field inside the content, which is the content's like the rest of it.
    var searchView: UIView?
    var updates: [(NavigationBarTransitionRole?, CGFloat)] = []
    var putBackCount = 0
    var transitionContentFrameUpdated: ((CGRect) -> Void)?
    var holds: [Bool] = []
    var interrupted: (() -> Void)?
    /// Lays itself out while put back and finds its content changed (the chat-list header applies the scroll it held):
    /// it interrupts the hold it was just given.
    var interruptsHoldOnPutBack = false

    init(hasSearchField: Bool = false) {
        self.containingView.addSubview(self.contentView)
        if hasSearchField {
            let searchView = UIView(frame: CGRect(x: 0.0, y: 60.0, width: 390.0, height: 36.0))
            self.contentView.addSubview(searchView)
            self.searchView = searchView
        }
    }

    func takeView() -> NavigationBarTransitionTakeViewInfo? {
        return NavigationBarTransitionTakeViewInfo(containingView: self.containingView, contentView: self.contentView)
    }

    func putBack() {
        self.putBackCount += 1
        self.containingView.addSubview(self.contentView)
        if self.interruptsHoldOnPutBack, let interrupted = self.interrupted {
            self.interrupted = nil
            interrupted()
        }
    }

    func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updates.append((role, fraction))
    }

    func holdGlass(_ held: Bool, interrupted: (() -> Void)?) -> Bool {
        self.holds.append(held)
        self.interrupted = interrupted
        return true
    }
}

private final class FakeRenderer: NavigationBarTransitionRenderer {
    let backdropView = UIView()
    let rowView = UIView()
    var fractions: [CGFloat] = []
    var begins: [(isInteractive: Bool, toTop: Bool)] = []
    var interactionEnds: [Bool] = []
    var interactionBegins = 0
    var isGlassAnimating = false
    var glassSettled: (() -> Void)?
    var timelines: [NavigationTransitionTimeline] = []
    var endCount = 0

    func update(size: CGSize, fraction: CGFloat, bottomFrame: CGRect, topFrame: CGRect, transition: ContainedViewLayoutTransition) {
        self.fractions.append(fraction)
    }

    func end() {
        self.endCount += 1
    }

    func animate(size: CGSize, timeline: NavigationTransitionTimeline, bottomFrame: CGRect, topFrame: CGRect) {
        self.timelines.append(timeline)
    }

    func beginTransition(isInteractive: Bool, toTop: Bool) {
        self.begins.append((isInteractive, toTop))
    }

    func endInteraction(towardTop: Bool) {
        self.interactionEnds.append(towardTop)
    }

    func beginInteraction() {
        self.interactionBegins += 1
    }
}

final class NavigationBarTransitionCoordinatorTests: XCTestCase {
    private var renderer: FakeRenderer?
    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
        defaultNavigationBarTransitionRenderer = { [weak self] _, _ in
            let renderer = FakeRenderer()
            self?.renderer = renderer
            return renderer
        }
    }

    override func tearDown() {
        defaultNavigationBarTransitionRenderer = nil
        self.renderer = nil
        self.time.detach()
        super.tearDown()
    }

    /// One frame: a dragging finger's spring steps, and the transition's clock moves on (running any deadline due).
    private func step(_ coordinator: NavigationTransitionCoordinator, _ dt: CGFloat) {
        coordinator.progressDriverForTesting?.tick(dt: dt)
        self.time.advance(by: Double(dt))
    }

    // A tap push puts each lifted bar's clip on keyframes that follow its screen, and hands the renderer the timeline;
    // nothing samples per frame.
    func test_tapPush_liftedContentsRideTheirScreens_onKeyframes() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.animateCompletion(0.0, completion: {})
            guard let topClip = top.contentView.superview, let animation = topClip.layer.animation(forKey: navigationBarTransitionKeyframeKeyPrefix + "position") as? CAKeyframeAnimation else {
                XCTFail("no clip keyframes")
                return
            }
            let first = (animation.values?.first as? NSValue)?.cgPointValue.x ?? 0.0
            XCTAssertEqual(first, 390.0 + 195.0, accuracy: 1.0, "starts with its screen off to the right")
            XCTAssertEqual(self.renderer?.timelines.count, 1)
        }
    }

    // A screen re-laying out its bar mid-push moves its lifted content at once and keeps the rest on the phase.
    func test_relayoutDuringPush_reinstallsOnThePhase() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.animateCompletion(0.0, completion: {})
            self.time.advance(by: 0.1)
            top.transitionContentFrameUpdated?(CGRect(x: 0.0, y: 10.0, width: 390.0, height: 100.0))
            // The content moves at once (it rides its clip, which carries the motion).
            XCTAssertEqual(top.contentView.frame.minY, 10.0, accuracy: 0.5)
            guard let clip = top.contentView.superview, let animation = clip.layer.animation(forKey: navigationBarTransitionKeyframeKeyPrefix + "position") as? CAKeyframeAnimation else {
                XCTFail("no clip keyframes")
                return
            }
            XCTAssertEqual(animation.beginTime, clip.layer.convertTime(self.time.now - 0.1, from: nil), accuracy: 1e-6)
        }
    }


    // A released swipe springs on from where the drag has it, at the finger's velocity, on the render server and
    // explicitly from now (CoreList: a baked release adds no one-frame hand-off).
    func test_release_bakesFromTheDragsState_atNow() {
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
        withExtendedLifetime(coordinator) {
            coordinator.trackInteractiveProgress(0.4)
            for _ in 0 ..< 60 {
                coordinator.progressDriverForTesting?.tick(dt: 1.0 / 120.0)
            }
            let progress = coordinator.progress
            var completed = false
            coordinator.animateCompletion(800.0, completion: {
                completed = true
            })
            XCTAssertNil(coordinator.progressDriverForTesting)
            guard let position = coordinator.topNode.layer.animation(forKey: NavigationTransitionCoordinator.keyframeKeyPrefix + "position") as? CAKeyframeAnimation else {
                XCTFail("no keyframes")
                return
            }
            XCTAssertEqual(position.beginTime, coordinator.topNode.layer.convertTime(self.time.now, from: nil), accuracy: 1e-9)
            XCTAssertEqual(coordinator.progress, progress, accuracy: 1e-6)
            let curve = NavigationSpringCurve(from: progress, velocity: 800.0 / 390.0, target: 1.0, spring: .interactive, overshoots: false, rest: .progress)
            self.time.advance(by: 0.05)
            XCTAssertEqual(coordinator.progress, curve.value(at: 0.05), accuracy: 1e-6)
            self.time.advance(by: 1.0)
            XCTAssertTrue(completed)
        }
    }

    // Review focus: a swipe let go exactly at its end has nothing to animate; it completes on the next turn.
    func test_releaseAtTheTarget_completesWithoutAnimating() {
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
        withExtendedLifetime(coordinator) {
            coordinator.trackInteractiveProgress(1.0)
            for _ in 0 ..< 240 {
                coordinator.progressDriverForTesting?.tick(dt: 1.0 / 120.0)
            }
            var completions = 0
            coordinator.animateCompletion(0.0001, completion: {
                completions += 1
            })
            XCTAssertNil(coordinator.topNode.layer.animation(forKey: NavigationTransitionCoordinator.keyframeKeyPrefix + "position"))
            self.time.advance(by: 0.001)
            XCTAssertEqual(completions, 1)
            XCTAssertFalse(coordinator.clockForTesting.isRunning)
        }
    }

    // A catch is a swap (CoreList, "Stopping a render-server-played flight is a SWAP"): the keyframes run on to the next
    // frame plus one of headroom and hold there; the finger's spring starts at that instant from that state.
    func test_catch_isASwap_atTheNextFramePlusHeadroom() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.frameTiming = { (lastTargetTimestamp: nil, frameDuration: 1.0 / 120.0) }
            coordinator.animateCompletion(0.0, completion: {})
            self.time.advance(by: 0.05)
            let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
            let cut = 0.05 + 2.0 / 120.0
            coordinator.catchBySwipe(popTarget: 0.0)
            guard let position = coordinator.topNode.layer.animation(forKey: NavigationTransitionCoordinator.keyframeKeyPrefix + "position") as? CAKeyframeAnimation else {
                XCTFail("no truncated keyframes")
                return
            }
            XCTAssertEqual(position.duration, cut, accuracy: 1e-6)
            XCTAssertEqual(coordinator.progress, curve.value(at: cut), accuracy: 1e-6)
            XCTAssertEqual(coordinator.progressDriverForTesting?.velocity ?? 0.0, curve.velocity(at: cut), accuracy: 1e-6)
        }
    }

    func test_catchTime_isTheNextFramePlusOne() {
        XCTAssertEqual(navigationTransitionCatchTime(now: 10.0, lastTargetTimestamp: nil, frameDuration: 0.01), 10.02, accuracy: 1e-12)
        XCTAssertEqual(navigationTransitionCatchTime(now: 10.0, lastTargetTimestamp: 9.996, frameDuration: 0.01), 10.016, accuracy: 1e-12)
        XCTAssertEqual(navigationTransitionCatchTime(now: 10.0, lastTargetTimestamp: 10.004, frameDuration: 0.01), 10.014, accuracy: 1e-12)
    }


    private func keyframes(_ layer: CALayer, _ keyPath: String) -> CAKeyframeAnimation? {
        return layer.animation(forKey: NavigationTransitionCoordinator.keyframeKeyPrefix + keyPath) as? CAKeyframeAnimation
    }

    // A tap push runs on UIKit's critically damped spring (response 0.3 s) on the render server: the top screen's
    // position is one keyframe animation sampled from the curve, beginning at the commit; its model frame is the end.
    func test_tapPush_runsOnUIKitsSpring_onTheRenderServer() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            var completed = false
            coordinator.animateCompletion(0.0, completion: {
                completed = true
            })
            XCTAssertNil(coordinator.progressDriverForTesting, "no display link")
            guard let position = self.keyframes(coordinator.topNode.layer, "position") else {
                XCTFail("no keyframes")
                return
            }
            XCTAssertEqual(position.beginTime, 0.0)
            let omegaT: CGFloat = 2.0 * .pi / 0.3 * 0.1
            let expected = 1.0 - (1.0 + omegaT) * exp(-omegaT)
            let sampled = (position.values?[12] as? NSValue)?.cgPointValue.x ?? 0.0
            XCTAssertEqual(sampled, floor(390.0 * (1.0 - expected)) + 195.0, accuracy: 1.0)
            XCTAssertEqual(coordinator.topNode.frame.minX, 0.0)
            self.time.advance(by: 0.1)
            XCTAssertEqual(coordinator.progress, expected, accuracy: 1e-6)
            XCTAssertFalse(completed)
            self.time.advance(by: 1.0)
            XCTAssertTrue(completed)
            XCTAssertEqual(coordinator.progress, 1.0)
        }
    }

    // The dim and the shadow follow the same curve.
    func test_tapPush_dimAndShadow_followTheCurve() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.animateCompletion(0.0, completion: {})
            XCTAssertNotNil(self.keyframes(coordinator.dimNodeForTesting.layer, "opacity"))
            XCTAssertNotNil(self.keyframes(coordinator.dimNodeForTesting.layer, "bounds"))
            XCTAssertNotNil(self.keyframes(coordinator.shadowNodeForTesting.layer, "position"))
            XCTAssertNotNil(self.keyframes(coordinator.bottomNode.layer, "position"))
        }
    }

    // A container dropped mid-transition (split <-> flat re-hosts the screens) ends a completing transition through its
    // clock: Core Animation completes the clock's animation at once when its layer leaves the screen. However the group
    // ends, the screens' keyframes go with it, or they would play the transition on over the next container's layout.
    // (Tests end the group at its deadline, where nothing removes the keyframes but the coordinator.)
    func test_groupEnd_removesTheScreensKeyframes() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.animateCompletion(0.0, completion: {})
            XCTAssertNotNil(self.keyframes(coordinator.topNode.layer, "position"))
            self.time.advance(by: 1.0)
            XCTAssertNil(self.keyframes(coordinator.topNode.layer, "position"))
            XCTAssertNil(self.keyframes(coordinator.bottomNode.layer, "position"))
            XCTAssertNil(self.keyframes(coordinator.dimNodeForTesting.layer, "opacity"))
        }
    }

    // A cancelling swipe holds its coordinator weakly, so a container dropped while it springs back releases the
    // coordinator mid-curve; the screens it leaves behind carry none of its keyframes.
    func test_coordinatorReleasedMidCancel_removesItsKeyframes() {
        var topNode: ASDisplayNode?
        var bottomNode: ASDisplayNode?
        weak var weakCoordinator: NavigationTransitionCoordinator?
        autoreleasepool {
            let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource(), isInteractive: true)
            coordinator.updateProgress(0.5, transition: .immediate, completion: {})
            coordinator.animateCancel(velocity: 0.0, spring: .interactive, {})
            XCTAssertNotNil(self.keyframes(coordinator.topNode.layer, "position"))
            topNode = coordinator.topNode
            bottomNode = coordinator.bottomNode
            weakCoordinator = coordinator
        }
        XCTAssertNil(weakCoordinator)
        XCTAssertNil(topNode.flatMap { self.keyframes($0.layer, "position") })
        XCTAssertNil(bottomNode.flatMap { self.keyframes($0.layer, "position") })
    }

    // A screen passed on to the next transition keeps that transition's keyframes when the old coordinator goes.
    func test_releasedCoordinator_leavesTheNextTransitionsKeyframes() {
        let topNode = ASDisplayNode()
        let layer = topNode.layer
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.3, factor: 1.0)
        addNavigationKeyframes(to: layer, key: NavigationTransitionCoordinator.keyframeKeyPrefix + "position", keyPath: "position", values: [NSValue(cgPoint: CGPoint()), NSValue(cgPoint: CGPoint(x: 1.0, y: 0.0))], timing: timing, owner: 1)
        removeNavigationKeyframes(from: layer, key: NavigationTransitionCoordinator.keyframeKeyPrefix + "position", owner: 2)
        XCTAssertNotNil(self.keyframes(layer, "position"))
        removeNavigationKeyframes(from: layer, key: NavigationTransitionCoordinator.keyframeKeyPrefix + "position", owner: 1)
        XCTAssertNil(self.keyframes(layer, "position"))
    }

    // An immediate keyboard edge (a forced ending lays the screens out at their end) replaces the transition's keyboard
    // keyframes instead of leaving them running on the old curve.
    func test_immediateKeyboardEdge_removesTheTransitionsKeyframes() {
        let layer = CALayer()
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.3, factor: 1.0)
        applyNavigationKeyboardLeftEdges(layer: layer, leftEdges: timing.sampleTimes.map { CGFloat($0) * 100.0 }, timing: timing)
        XCTAssertNotNil(layer.animation(forKey: navigationKeyboardTransitionKey))
        applyNavigationKeyboardLeftEdge(layer: layer, leftEdge: 0.0, transition: .immediate)
        XCTAssertNil(layer.animation(forKey: navigationKeyboardTransitionKey))
        XCTAssertEqual(layer.sublayerTransform.m41, 0.0)
    }

    // The commit resolves the push's origin after the new screen's layout: the model adopts it.
    func test_tapPush_adoptsTheCommitsOrigin() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            let start = self.time.now
            coordinator.animateCompletion(0.0, completion: {})
            self.time.resolveOrigin(of: coordinator.clockForTesting, at: start + 0.05)
            self.time.advance(by: 0.15)
            let omegaT: CGFloat = 2.0 * .pi / 0.3 * 0.1
            XCTAssertEqual(coordinator.progress, 1.0 - (1.0 + omegaT) * exp(-omegaT), accuracy: 1e-6)
        }
    }

    // A rotation or a fold mid-push re-installs the screens' keyframes on the same phase for the new width.
    func test_containerResize_midPush_rebakesOnThePhase() {
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.animateCompletion(0.0, completion: {})
            self.time.advance(by: 0.1)
            container.frame = CGRect(x: 0.0, y: 0.0, width: 500.0, height: 844.0)
            coordinator.containerSizeUpdated()
            guard let position = self.keyframes(coordinator.topNode.layer, "position") else {
                XCTFail("no keyframes")
                return
            }
            XCTAssertEqual(position.beginTime, coordinator.topNode.layer.convertTime(self.time.now - 0.1, from: nil), accuracy: 1e-6)
            let first = (position.values?.first as? NSValue)?.cgPointValue.x ?? 0.0
            XCTAssertEqual(first, 500.0 + 250.0, accuracy: 1.0)
        }
    }

    // A stack change mid-push ends it at once: the keyframes go and no deadline runs the completion again.
    func test_performCompletion_removesTheKeyframes() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            var completions = 0
            coordinator.animateCompletion(0.0, completion: {
                completions += 1
            })
            self.time.advance(by: 0.05)
            coordinator.performCompletion(completion: {})
            XCTAssertNil(self.keyframes(coordinator.topNode.layer, "position"))
            XCTAssertEqual(completions, 1)
            self.time.advance(by: 1.0)
            XCTAssertEqual(completions, 1)
        }
    }


    private func makeCoordinator(_ transition: NavigationTransition, bottom: FakeSource?, top: FakeSource?, screenCornerRadius: CGFloat = 0.0, isInteractive: Bool = true) -> (NavigationTransitionCoordinator, NavigationContainer) {
        let container = NavigationContainer(isFlat: false, controllerRemoved: { _ in })
        container.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        let bottomNode = ASDisplayNode()
        bottomNode.frame = container.bounds
        let topNode = ASDisplayNode()
        topNode.frame = container.bounds
        if let bottom {
            bottomNode.view.addSubview(bottom.containingView)
        }
        if let top {
            topNode.view.addSubview(top.containingView)
        }
        container.addSubnode(bottomNode)
        let coordinator = NavigationTransitionCoordinator(transition: transition, isInteractive: isInteractive, isFlat: false, container: container, topNode: topNode, topNavigationBar: nil, topTransitionSource: top, bottomNode: bottomNode, bottomNavigationBar: nil, bottomTransitionSource: bottom, screenCornerRadii: CornerRadii(uniform: screenCornerRadius))
        return (coordinator, container)
    }

    func test_push_liftsBothContentsAboveTheScreens() {
        let bottom = FakeSource()
        let top = FakeSource()
        // The container holds its coordinator for the transition; releasing it ends the morph.
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top)
        withExtendedLifetime(coordinator) {
            XCTAssertTrue(bottom.contentView.superview !== bottom.containingView)
            XCTAssertTrue(top.contentView.superview !== top.containingView)
            XCTAssertTrue(top.contentView.isDescendant(of: container.view))
            XCTAssertEqual(bottom.updates.last?.0, .bottom)
            XCTAssertEqual(top.updates.last?.0, .top)
            XCTAssertEqual(self.renderer?.fractions.last, 0.0)
        }
    }

    func test_progress_reachesSourcesAndRenderer() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: bottom, top: top)
        coordinator.updateProgress(0.5, transition: .immediate, completion: {})
        XCTAssertEqual(top.updates.last?.1 ?? -1.0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(self.renderer?.fractions.last ?? -1.0, 0.5, accuracy: 0.0001)
    }

    // A pop is a push played backwards: at a quarter of the pop the top bar is still three quarters shown.
    func test_pop_fractionRunsDown() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: bottom, top: top)
        coordinator.updateProgress(0.25, transition: .immediate, completion: {})
        XCTAssertEqual(top.updates.last?.1 ?? -1.0, 0.75, accuracy: 0.0001)
    }

    func test_complete_putsBothBack() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top)
        coordinator.complete()
        XCTAssertEqual(bottom.putBackCount, 1)
        XCTAssertEqual(top.putBackCount, 1)
        XCTAssertTrue(top.contentView.superview === top.containingView)
        XCTAssertNil(bottom.updates.last?.0)
        XCTAssertFalse(container.subnodes?.contains(where: { $0 is NavigationBarTransitionLayer }) ?? false)
    }

    // An interactive pop cancelled halfway ends through the same path (`animateCancel`'s completion calls
    // `endNavigationBarTransition`); a windowless test process cannot wait for that animation, so this ends it
    // directly after partial progress.
    func test_cancel_putsBothBack() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: bottom, top: top)
        coordinator.updateProgress(0.5, transition: .immediate, completion: {})
        coordinator.endNavigationBarTransition()
        XCTAssertEqual(top.putBackCount, 1)
        XCTAssertTrue(bottom.contentView.superview === bottom.containingView)
        XCTAssertNil(top.updates.last?.0)
    }

    func test_missingSource_slides() {
        let bottom = FakeSource()
        let (_, _) = self.makeCoordinator(.Push, bottom: bottom, top: nil)
        XCTAssertTrue(bottom.contentView.superview === bottom.containingView)
        XCTAssertNil(self.renderer)
    }

    func test_rendererDeclining_putsBothBack() {
        defaultNavigationBarTransitionRenderer = { _, _ in
            return nil
        }
        let bottom = FakeSource()
        let top = FakeSource()
        let (_, _) = self.makeCoordinator(.Push, bottom: bottom, top: top)
        XCTAssertTrue(bottom.contentView.superview === bottom.containingView)
        XCTAssertTrue(top.contentView.superview === top.containingView)
    }

    // A container dropped mid-transition (split ↔ flat on an iPad resize or an iPhone Duo fold, a dismissed modal)
    // releases its coordinator without running the completion that ends the morph; the bars still get their contents
    // back.
    func test_coordinatorReleasedMidTransition_putsBothBack() {
        let bottom = FakeSource()
        let top = FakeSource()
        weak var weakCoordinator: NavigationTransitionCoordinator?
        var container: NavigationContainer?
        autoreleasepool {
            let (coordinator, coordinatorContainer) = self.makeCoordinator(.Push, bottom: bottom, top: top)
            coordinator.updateProgress(0.5, transition: .immediate, completion: {})
            weakCoordinator = coordinator
            container = coordinatorContainer
        }
        XCTAssertNil(weakCoordinator)
        XCTAssertNotNil(container)
        XCTAssertEqual(bottom.putBackCount, 1)
        XCTAssertEqual(top.putBackCount, 1)
        XCTAssertTrue(top.contentView.superview === top.containingView)
        XCTAssertFalse(container?.subnodes?.contains(where: { $0 is NavigationBarTransitionLayer }) ?? false)
    }

    // Each lifted bar rides its own screen, clipped the way UIKit clips its matching views: the bottom bar between its
    // screen's leading edge and the top screen's, the top bar to its own screen. A push at 0.5 has the top screen at
    // 0.5 W and the bottom one at -0.3 W * 0.5.
    func test_liftedContents_rideTheirScreens_clippedAtTheTopScreensEdge() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top)
        withExtendedLifetime(coordinator) {
            coordinator.updateProgress(0.5, transition: .immediate, completion: {})
            guard let topClip = top.contentView.superview, let bottomClip = bottom.contentView.superview else {
                XCTFail("not lifted")
                return
            }
            XCTAssertTrue(topClip.clipsToBounds)
            XCTAssertTrue(bottomClip.clipsToBounds)
            XCTAssertEqual(top.contentView.convert(top.contentView.bounds, to: container.view).minX, 195.0, accuracy: 0.5)
            XCTAssertEqual(bottom.contentView.convert(bottom.contentView.bounds, to: container.view).minX, -58.5, accuracy: 0.5)
            let topClipFrame = topClip.convert(topClip.bounds, to: container.view)
            XCTAssertEqual(topClipFrame.minX, 195.0, accuracy: 0.5)
            XCTAssertEqual(topClipFrame.width, 390.0, accuracy: 0.5)
            let bottomClipFrame = bottomClip.convert(bottomClip.bounds, to: container.view)
            XCTAssertEqual(bottomClipFrame.minX, -58.5, accuracy: 0.5)
            XCTAssertEqual(bottomClipFrame.maxX, 195.0, accuracy: 0.5)
        }
    }

    // A swipe: the progress chases the finger on UIKit's tracking spring, then a release springs on the interactive spring
    // starting at the finger's velocity (points per second over the width).
    func test_swipe_tracksOnTheTrackingSpring_andReleasesWithTheFingersVelocity() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: bottom, top: top)
        withExtendedLifetime(coordinator) {
            coordinator.trackInteractiveProgress(0.3)
            guard let driver = coordinator.progressDriverForTesting else {
                XCTFail("no driver")
                return
            }
            XCTAssertEqual(driver.spring, .tracking)
            driver.tick(dt: 0.016)
            XCTAssertGreaterThan(coordinator.progress, 0.0)
            XCTAssertLessThan(coordinator.progress, 0.3)
            driver.tick(dt: 0.5)
            XCTAssertEqual(coordinator.progress, 0.3, accuracy: 0.001)

            let start = coordinator.progress
            var completed = false
            coordinator.animateCompletion(780.0, completion: {
                completed = true
            })
            XCTAssertNil(coordinator.progressDriverForTesting, "the release runs on the render server")
            let curve = NavigationSpringCurve(from: start, velocity: 2.0, target: 1.0, spring: .interactive, overshoots: false, rest: .progress)
            self.time.advance(by: 0.05)
            XCTAssertEqual(coordinator.progress, curve.value(at: 0.05), accuracy: 1e-6)
            self.time.advance(by: 2.0)
            XCTAssertTrue(completed)
            XCTAssertEqual(coordinator.progress, 1.0)
        }
    }

    func test_swipeCancel_springsBack() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Pop, bottom: bottom, top: top)
        withExtendedLifetime(coordinator) {
            coordinator.trackInteractiveProgress(0.2)
            guard let driver = coordinator.progressDriverForTesting else {
                XCTFail("no driver")
                return
            }
            driver.tick(dt: 0.5)
            let start = coordinator.progress
            var completed = false
            coordinator.animateCancel(velocity: -1.0, spring: .interactive, {
                completed = true
            })
            XCTAssertNil(coordinator.progressDriverForTesting, "the release runs on the render server")
            let curve = NavigationSpringCurve(from: start, velocity: -1.0, target: 0.0, spring: .interactive, overshoots: false, rest: .progress)
            self.time.advance(by: 0.05)
            XCTAssertEqual(coordinator.progress, curve.value(at: 0.05), accuracy: 1e-6)
            self.time.advance(by: 2.0)
            XCTAssertTrue(completed)
            XCTAssertEqual(coordinator.progress, 0.0)
        }
    }

    // The swipe never carries the screens past either end (a decision, 2026-10-14): tracking a finger at the end, a fast
    // release that finishes and a fast one that cancels all stop at the end instead of overshooting it, as UIKit's
    // underdamped interactive springs (damping 0.85) would.
    func test_swipe_neverOvershootsEitherEnd() {
        do {
            let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
            withExtendedLifetime(coordinator) {
                coordinator.trackInteractiveProgress(1.0)
                guard let driver = coordinator.progressDriverForTesting else {
                    XCTFail("no driver")
                    return
                }
                var maxProgress: CGFloat = 0.0
                for _ in 0 ..< 240 {
                    driver.tick(dt: 1.0 / 240.0)
                    maxProgress = max(maxProgress, coordinator.progress)
                }
                XCTAssertLessThanOrEqual(maxProgress, 1.0)
            }
        }
        do {
            let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
            withExtendedLifetime(coordinator) {
                coordinator.trackInteractiveProgress(0.6)
                guard let driver = coordinator.progressDriverForTesting else {
                    XCTFail("no driver")
                    return
                }
                driver.tick(dt: 0.5)
                var completed = false
                coordinator.animateCompletion(3000.0, completion: {
                    completed = true
                })
                var maxProgress: CGFloat = 0.0
                for _ in 0 ..< 480 {
                    self.time.advance(by: 1.0 / 240.0)
                    maxProgress = max(maxProgress, coordinator.progress)
                }
                XCTAssertTrue(completed)
                XCTAssertLessThanOrEqual(maxProgress, 1.0)
                XCTAssertEqual(coordinator.progress, 1.0)
            }
        }
        do {
            let (coordinator, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
            withExtendedLifetime(coordinator) {
                coordinator.trackInteractiveProgress(0.4)
                guard let driver = coordinator.progressDriverForTesting else {
                    XCTFail("no driver")
                    return
                }
                driver.tick(dt: 0.5)
                var completed = false
                coordinator.animateCancel(velocity: -6.0, spring: .interactive, {
                    completed = true
                })
                var minProgress: CGFloat = 1.0
                for _ in 0 ..< 480 {
                    self.time.advance(by: 1.0 / 240.0)
                    minProgress = min(minProgress, coordinator.progress)
                }
                XCTAssertTrue(completed)
                XCTAssertGreaterThanOrEqual(minProgress, 0.0)
                XCTAssertEqual(coordinator.progress, 0.0)
            }
        }
    }

    // A swipe back takes a running tap push over where it is and at the speed it has (measured against the native
    // reference app): the progress keeps its value and velocity and chases the swipe's target on the tracking spring,
    // the glass is told, and the push's own ending never runs. The swipe's target is a pop's progress.
    func test_catchBySwipe_takesARunningPushOverWhereItIs() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(coordinator) {
            coordinator.frameTiming = { (lastTargetTimestamp: nil, frameDuration: 1.0 / 120.0) }
            var pushCompleted = false
            coordinator.animateCompletion(0.0, completion: {
                pushCompleted = true
            })
            self.time.advance(by: 0.05)
            let curve = NavigationSpringCurve(from: 0.0, target: 1.0, spring: .noninteractive, rest: .progress)
            // Taken over where it will be when the swap lands: the next frame plus one of headroom.
            let cut = 0.05 + 2.0 / 120.0
            XCTAssertGreaterThan(curve.velocity(at: cut), 0.0)
            XCTAssertTrue(coordinator.canBeCaughtBySwipe)

            coordinator.catchBySwipe(popTarget: 0.0)
            guard let driver = coordinator.progressDriverForTesting else {
                XCTFail("no driver")
                return
            }
            XCTAssertTrue(coordinator.isInteractive)
            XCTAssertFalse(coordinator.animatingCompletion)
            XCTAssertFalse(coordinator.canBeCaughtBySwipe, "a swipe steers it now")
            XCTAssertEqual(self.renderer?.interactionBegins, 1)
            XCTAssertEqual(coordinator.progress, curve.value(at: cut), accuracy: 1e-6)
            XCTAssertEqual(driver.velocity, curve.velocity(at: cut), accuracy: 1e-6)
            XCTAssertEqual(driver.spring, .tracking)
            XCTAssertEqual(driver.target, 1.0)

            coordinator.trackInteractivePop(0.25)
            for _ in 0 ..< 240 {
                driver.tick(dt: 1.0 / 240.0)
            }
            self.time.advance(by: 1.0)
            XCTAssertEqual(coordinator.popProgress, 0.25, accuracy: 0.001)
            XCTAssertEqual(coordinator.progress, 0.75, accuracy: 0.001)
            XCTAssertFalse(pushCompleted)
        }
    }

    // Only a transition running on its own toward the top screen can be taken over: a tap push, or a pop springing back
    // after a cancelled swipe. A tap pop, a released swipe that finishes, and a swipe still steering cannot.
    func test_canBeCaughtBySwipe_onlyWhileRunningTowardTheTopScreen() {
        let (tapPop, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(tapPop) {
            tapPop.animateCompletion(0.0, completion: {})
            XCTAssertFalse(tapPop.canBeCaughtBySwipe)
        }
        let (swipe, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
        withExtendedLifetime(swipe) {
            swipe.trackInteractiveProgress(0.3)
            XCTAssertFalse(swipe.canBeCaughtBySwipe)
            swipe.animateCancel(velocity: 0.0, spring: .interactive, {})
            XCTAssertTrue(swipe.canBeCaughtBySwipe)
            swipe.catchBySwipe(popTarget: swipe.popProgress)
            XCTAssertFalse(swipe.canBeCaughtBySwipe)
            swipe.animateCompletion(500.0, completion: {})
            XCTAssertFalse(swipe.canBeCaughtBySwipe)
        }
        let (push, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(push) {
            push.animateCompletion(0.0, completion: {})
            self.step(push, 0.05)
            push.catchBySwipe(popTarget: 0.0)
            // Let go as a pop: the push runs back to its start, toward the bottom screen.
            push.animateCancel(velocity: 0.0, spring: .interactive, {})
            XCTAssertFalse(push.canBeCaughtBySwipe)
            XCTAssertEqual(self.renderer?.interactionEnds.last, false)
        }
    }

    // The renderer hosts the bars' own screen nodes in its capsules; it is told when its glass is gone, so that they go
    // back: at the transition's end when nothing lingers...
    func test_renderer_isEndedWhenTheTransitionEnds() {
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        guard let renderer = self.renderer else {
            XCTFail("no renderer")
            return
        }
        var completed = false
        coordinator.animateCompletion(0.0, completion: {
            completed = true
        })
        XCTAssertEqual(renderer.endCount, 0)
        for _ in 0 ..< 240 {
            self.step(coordinator, 1.0 / 120.0)
        }
        XCTAssertTrue(completed)
        XCTAssertEqual(renderer.endCount, 1)
    }

    // ...and at the end of its linger, not before.
    func test_renderer_isEndedWhenItsLingerEnds() {
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        guard let renderer = self.renderer else {
            XCTFail("no renderer")
            return
        }
        renderer.isGlassAnimating = true
        coordinator.animateCompletion(0.0, completion: {})
        for _ in 0 ..< 240 {
            self.step(coordinator, 1.0 / 120.0)
        }
        XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
        XCTAssertEqual(renderer.endCount, 0)
        renderer.glassSettled?()
        XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
        XCTAssertEqual(renderer.endCount, 1)
    }

    // The user's correction (2026-10-15): a bar's search field goes with its screen whether its bar leaves or arrives,
    // rather than holding its place and fading as UIKit's leaving field does. It stays in its bar's content (which rides
    // its screen, clipped by the other screen's edge) at its own opacity, with nothing animating it.
    func test_aSearchField_ridesItsScreenAtItsOwnOpacity() {
        let bottom = FakeSource(hasSearchField: true)
        let (push, _) = self.makeCoordinator(.Push, bottom: bottom, top: FakeSource(), isInteractive: false)
        withExtendedLifetime(push) {
            push.animateCompletion(0.0, completion: {})
            XCTAssertTrue(bottom.searchView?.superview === bottom.contentView)
            XCTAssertNil(bottom.searchView?.layer.animationKeys())
            XCTAssertEqual(bottom.searchView?.layer.opacity ?? -1.0, 1.0)
        }
        for leaving in [true, false] {
            let bottom = FakeSource(hasSearchField: !leaving)
            let top = FakeSource(hasSearchField: leaving)
            let field = leaving ? top : bottom
            let (pop, _) = self.makeCoordinator(.Pop, bottom: bottom, top: top, isInteractive: true)
            withExtendedLifetime(pop) {
                pop.updateProgress(0.4, transition: .immediate, completion: {})
                XCTAssertTrue(field.searchView?.superview === field.contentView, "leaving \(leaving)")
                XCTAssertEqual(field.searchView?.layer.opacity ?? -1.0, 1.0, "leaving \(leaving)")
            }
        }
    }

    // A bar that lays itself out while put back and interrupts the hold it was just given ends the linger before it
    // began: nothing is left registered as lingering.
    func test_aHoldInterruptedDuringPutBack_leavesNoLinger() {
        let top = FakeSource()
        top.interruptsHoldOnPutBack = true
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: FakeSource(), top: top, isInteractive: false)
        guard let renderer = self.renderer else {
            XCTFail("no renderer")
            return
        }
        renderer.isGlassAnimating = true
        coordinator.animateCompletion(0.0, completion: {})
        for _ in 0 ..< 240 {
            self.step(coordinator, 1.0 / 120.0)
        }
        XCTAssertEqual(top.holds, [true, false])
        XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
        XCTAssertFalse(container.subnodes?.contains(where: { $0 is NavigationBarTransitionLayer }) ?? false)
    }

    // UIKit's capsules run on their own clock and outlive the screens' transition (measured: a swipe let go near the edge
    // morphs them for ~0.5 s after the screens settle). Glass still animating at the end stays above the bar the
    // transition ended on, which keeps its own glass hidden, until it settles; the other bar is put back as before.
    func test_glassStillAnimatingAtTheEnd_lingersAboveTheDestinationBar() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
        guard let renderer = self.renderer else {
            XCTFail("no renderer")
            return
        }
        renderer.isGlassAnimating = true
        var completed = false
        coordinator.animateCompletion(0.0, completion: {
            completed = true
        })
        for _ in 0 ..< 240 {
            self.step(coordinator, 1.0 / 120.0)
        }
        XCTAssertTrue(completed)
        XCTAssertNil(coordinator.navigationBarTransitionLayer)
        guard let lingering = container.lingeringNavigationBarTransitionLayerForTesting else {
            XCTFail("no lingering glass")
            return
        }
        XCTAssertTrue(lingering.supernode === container)
        XCTAssertNotNil(renderer.rowView.superview)
        XCTAssertNil(renderer.backdropView.superview)
        XCTAssertEqual(top.holds, [true])
        XCTAssertEqual(top.putBackCount, 1)
        XCTAssertEqual(bottom.holds, [])
        XCTAssertEqual(bottom.putBackCount, 1)

        renderer.glassSettled?()
        XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
        XCTAssertNil(lingering.supernode)
        XCTAssertNil(renderer.rowView.superview)
        XCTAssertEqual(top.holds, [true, false])
    }

    // A linger nobody ends (the glass never reports settling) ends by itself after 1.5 s of animation time: on the
    // transition's own clock, so Slow Animations stretch it as they stretch the glass.
    func test_lingeringGlass_endsByItselfAfterItsCap_inAnimationTime() {
        for factor in [1.0, 2.0] {
            self.time.factor = factor
            let bottom = FakeSource()
            let top = FakeSource()
            let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
            self.renderer?.isGlassAnimating = true
            var ended = false
            coordinator.animateCompletion(0.0, completion: {
                ended = true
            })
            // To the push's end, where the linger starts.
            while !ended {
                self.time.advance(by: 1.0 / 120.0)
            }
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
            self.time.advance(by: 1.45 * factor)
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting, "factor \(factor)")
            self.time.advance(by: 0.1 * factor)
            XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting, "factor \(factor)")
            XCTAssertEqual(top.holds, [true, false])
        }
    }

    // A touch on the bar (or a change of its content) hands the glass over at once; so does a new transition.
    func test_lingeringGlass_handsOverWhenInterruptedOrAnotherTransitionStarts() {
        do {
            let bottom = FakeSource()
            let top = FakeSource()
            let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
            self.renderer?.isGlassAnimating = true
            coordinator.animateCompletion(0.0, completion: {})
            for _ in 0 ..< 240 {
                self.step(coordinator, 1.0 / 120.0)
            }
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
            top.interrupted?()
            XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
            XCTAssertEqual(top.holds, [true, false])
        }
        do {
            let bottom = FakeSource()
            let top = FakeSource()
            let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
            self.renderer?.isGlassAnimating = true
            coordinator.animateCompletion(0.0, completion: {})
            for _ in 0 ..< 240 {
                self.step(coordinator, 1.0 / 120.0)
            }
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
            let next = NavigationTransitionCoordinator(transition: .Push, isInteractive: false, isFlat: false, container: container, topNode: ASDisplayNode(), topNavigationBar: nil, topTransitionSource: nil, bottomNode: ASDisplayNode(), bottomNavigationBar: nil, bottomTransitionSource: nil, screenCornerRadii: CornerRadii(uniform: 0.0))
            withExtendedLifetime(next) {
                XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
                XCTAssertEqual(top.holds, [true, false])
            }
        }
    }

    // Settled glass, and a cancelled swipe: the bar it ends on is the top one.
    func test_lingeringGlass_onlyWhileAnimating_andOverTheBarTheTransitionEndsOn() {
        do {
            let bottom = FakeSource()
            let top = FakeSource()
            let (coordinator, container) = self.makeCoordinator(.Push, bottom: bottom, top: top, isInteractive: false)
            coordinator.animateCompletion(0.0, completion: {})
            for _ in 0 ..< 240 {
                self.step(coordinator, 1.0 / 120.0)
            }
            XCTAssertNil(container.lingeringNavigationBarTransitionLayerForTesting)
            XCTAssertEqual(top.holds, [])
        }
        do {
            let bottom = FakeSource()
            let top = FakeSource()
            let (coordinator, container) = self.makeCoordinator(.Pop, bottom: bottom, top: top)
            self.renderer?.isGlassAnimating = true
            coordinator.trackInteractiveProgress(0.3)
            self.step(coordinator, 0.5)
            coordinator.animateCancel(velocity: 0.0, spring: .interactive, {})
            // To the cancel's end, inside the linger's 1.5 s cap.
            for _ in 0 ..< 120 {
                self.step(coordinator, 1.0 / 120.0)
            }
            XCTAssertNotNil(container.lingeringNavigationBarTransitionLayerForTesting)
            XCTAssertEqual(top.holds, [true])
            XCTAssertEqual(bottom.holds, [])
        }
    }

    // UIKit's screen visuals: a black dim at 0.1 x progress over the lower screen, both screens as cards with the display's
    // corners, and the top card's shadow (radius 12, opacity 0.04, offset (0, -3)) constant through the transition.
    func test_screens_areUIKitsCards_overItsDim() {
        let bottom = FakeSource()
        let top = FakeSource()
        let (coordinator, _) = self.makeCoordinator(.Push, bottom: bottom, top: top, screenCornerRadius: 55.0)
        withExtendedLifetime(coordinator) {
            coordinator.updateProgress(0.5, transition: .immediate, completion: {})
            XCTAssertEqual(coordinator.dimNodeForTesting.alpha, 0.05, accuracy: 0.0001)
            XCTAssertEqual(coordinator.topNode.cornerRadius, 55.0)
            XCTAssertEqual(coordinator.bottomNode.cornerRadius, 55.0)
            XCTAssertTrue(coordinator.bottomNode.clipsToBounds)
            let shadow = coordinator.shadowNodeForTesting.layer
            XCTAssertEqual(shadow.shadowRadius, 12.0)
            XCTAssertEqual(shadow.shadowOpacity, 0.04, accuracy: 0.0001)
            XCTAssertEqual(shadow.shadowOffset, CGSize(width: 0.0, height: -3.0))
            XCTAssertEqual(coordinator.shadowNodeForTesting.alpha, 1.0)
            XCTAssertEqual(coordinator.shadowNodeForTesting.frame, coordinator.topNode.frame)
            XCTAssertEqual(shadow.shadowPath?.boundingBox.size, coordinator.topNode.frame.size)
            coordinator.complete()
            XCTAssertEqual(coordinator.bottomNode.cornerRadius, 0.0)
            XCTAssertFalse(coordinator.bottomNode.clipsToBounds)
        }
    }

    // The renderer's capsules run on their own springs from the start of a tap push (iOS 27 hands the destination
    // capsules over at once), and a swipe tells it where it ends: a finished pop on the bottom bar, a cancelled one on
    // the top bar.
    func test_renderer_hearsTheStart_andTheSwipesEnd() {
        let (push, _) = self.makeCoordinator(.Push, bottom: FakeSource(), top: FakeSource(), isInteractive: false)
        withExtendedLifetime(push) {
            XCTAssertEqual(self.renderer?.begins.count, 1)
            XCTAssertEqual(self.renderer?.begins.first?.isInteractive, false)
            XCTAssertEqual(self.renderer?.begins.first?.toTop, true)
        }

        let (cancelled, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
        withExtendedLifetime(cancelled) {
            XCTAssertEqual(self.renderer?.begins.first?.isInteractive, true)
            XCTAssertEqual(self.renderer?.begins.first?.toTop, false)
            cancelled.animateCancel(velocity: 0.0, spring: .interactive, {})
            XCTAssertEqual(self.renderer?.interactionEnds, [true])
        }

        let (finished, _) = self.makeCoordinator(.Pop, bottom: FakeSource(), top: FakeSource())
        withExtendedLifetime(finished) {
            finished.animateCompletion(500.0, completion: {})
            XCTAssertEqual(self.renderer?.interactionEnds, [false])
        }
    }
}
