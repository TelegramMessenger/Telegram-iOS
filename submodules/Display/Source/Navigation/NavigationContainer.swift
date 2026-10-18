import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public final class NavigationContainer: ASDisplayNode, ASGestureRecognizerDelegate {
    private final class Child {
        let value: ViewController
        var layout: ContainerViewLayout
        
        init(value: ViewController, layout: ContainerViewLayout) {
            self.value = value
            self.layout = layout
        }
    }
    
    private final class PendingChild {
        enum TransitionType {
            case push
            case pop
        }
        
        let value: Child
        let transitionType: TransitionType
        let transition: ContainedViewLayoutTransition
        let disposable: MetaDisposable = MetaDisposable()
        var isReady: Bool = false
        
        init(value: Child, transitionType: TransitionType, transition: ContainedViewLayoutTransition, update: @escaping (PendingChild) -> Void) {
            self.value = value
            self.transitionType = transitionType
            self.transition = transition
            var localIsReady: Bool?
            self.disposable.set((value.value.ready.get()
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                if localIsReady == nil {
                    localIsReady = true
                } else if let strongSelf = self {
                    update(strongSelf)
                }
            }))
            if let _ = localIsReady {
                self.isReady = true
            } else {
                localIsReady = false
            }
        }
        
        deinit {
            self.disposable.dispose()
        }
    }
    
    private final class TopTransition {
        let type: PendingChild.TransitionType
        let previous: Child
        let coordinator: NavigationTransitionCoordinator
        /// A push a swipe back caught: its screens were told the top one is leaving and the previous one coming back.
        var isSteeredBack = false
        /// The screen this transition appears when it lands (the stack's top when it began; the screen beneath once back
        /// turns a push back). Its endings read this, not the stack's top, which a push landing it has already replaced.
        var destination: Child
        /// A swipe committed toward the screen beneath: the top screen it removes from the stack at the commit, and
        /// whether the stack has dropped it (then the transition lands on the screen beneath itself).
        var committedTop: ViewController?
        var committedTopLeftStack = false
        
        init(type: PendingChild.TransitionType, previous: Child, destination: Child, coordinator: NavigationTransitionCoordinator) {
            self.type = type
            self.previous = previous
            self.destination = destination
            self.coordinator = coordinator
        }
    }
    
    private struct State {
        var layout: ContainerViewLayout?
        var canBeClosed: Bool?
        var top: Child?
        var transition: TopTransition?
        var pending: PendingChild?
    }
    
    private let isFlat: Bool
    public private(set) var controllers: [ViewController] = []
    private var state: State = State(layout: nil, canBeClosed: nil, top: nil, transition: nil, pending: nil)
    
    weak var minimizedContainer: MinimizedContainer?
    
    private var ignoreInputHeight: Bool = false
    
    public private(set) var isReady: Bool = false
    public var isReadyUpdated: (() -> Void)?
    public var controllerRemoved: (ViewController) -> Void
    public var requestFilterController: (ViewController) -> Void = { _ in }
    public var keyboardViewManager: KeyboardViewManager? {
        didSet {
        }
    }
    
    public var canHaveKeyboardFocus: Bool = false {
        didSet {
            if self.canHaveKeyboardFocus != oldValue {
                if !self.canHaveKeyboardFocus {
                    self.view.endEditing(true)
                    self.performUpdate(transition: .animated(duration: 0.5, curve: .spring))
                }
            }
        }
    }
    
    public var isInFocus: Bool = false {
        didSet {
            if self.isInFocus != oldValue {
                self.inFocusUpdated(isInFocus: self.isInFocus)
            }
        }
    }
    
    public func inFocusUpdated(isInFocus: Bool) {
        self.state.top?.value.isInFocus = isInFocus
    }
    
    public var overflowInset: CGFloat = 0.0
    
    private var currentKeyboardLeftEdge: CGFloat = 0.0
    private var additionalKeyboardLeftEdgeOffset: CGFloat = 0.0
    
    var statusBarStyle: StatusBarStyle = .Ignore {
        didSet {
        }
    }
    var statusBarStyleUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    /// The swipe back steering the transition, while it does: its statistics (UIKit's rules,
    /// `NavigationInteractivePopTracker`), the pop progress its translation counts from, and its last target.
    private struct InteractivePop {
        /// The transition the swipe started or caught: a stack change that replaces it ends the swipe's hold.
        let transition: TopTransition
        var tracker: NavigationInteractivePopTracker
        var base: CGFloat
        var target: CGFloat
        /// Where the finger began (an expansion's card shrinks around it).
        var anchor: CGPoint = CGPoint()
        /// A caught expanding push: whether the status bar had turned to the pushed screen's (then it follows the fade).
        var expansionStatusBarTurned: Bool = true
        var isVertical: Bool = false
    }
    private var interactivePop: InteractivePop?

    public func beginVerticalExpansionPop(anchor: CGPoint) -> Bool {
        guard self.interactivePop == nil else {
            return false
        }
        self.interactivePopBegan(translation: 0.0, velocity: 0.0, anchor: anchor)
        guard var pop = self.interactivePop else {
            return false
        }
        if !pop.transition.coordinator.isExpansion {
            self.interactivePopEnded(translation: 0.0, velocity: 0.0, isCancelled: true)
            return false
        }
        pop.isVertical = true
        self.interactivePop = pop
        return true
    }

    public func updateVerticalExpansionPop(translation: CGPoint) {
        guard let pop = self.interactivePop, pop.isVertical else {
            return
        }
        self.interactivePopChanged(translation: translation.x, velocity: 0.0, translationY: translation.y)
    }

    public func endVerticalExpansionPop(translation: CGPoint, velocity: CGPoint, isCancelled: Bool) {
        guard let pop = self.interactivePop, pop.isVertical else {
            return
        }
        self.interactivePopEnded(translation: translation.x, velocity: velocity.x, isCancelled: isCancelled, translationY: translation.y, velocityY: velocity.y)
    }
    
    public init(isFlat: Bool, controllerRemoved: @escaping (ViewController) -> Void) {
        self.isFlat = isFlat
        self.controllerRemoved = controllerRemoved
        
        super.init()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, strongSelf.controllers.count > 1 else {
                return []
            }
            return .right
        })
        /*panRecognizer.dynamicEdgeWidth = { [weak self] _ in
            guard let self, let controller = self.controllers.last, let value = controller.interactiveNavivationGestureEdgeWidth else {
                return .constant(16.0)
            }
            return value
        }*/
        if #available(iOS 13.4, *) {
            panRecognizer.allowedScrollTypesMask = .continuous
        }
        panRecognizer.gestureRestrictionsHitTest = { [weak self] point, event in
            return self?.gestureRestrictionsHitTest(point, with: event)
        }
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
        
        /*self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if strongSelf.state.transition != nil {
                return true
            }
            return false
        }*/
    }
    
    func hasNonReadyControllers() -> Bool {
        if let pending = self.state.pending, !pending.isReady {
            return true
        }
        return false
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.panRecognizer, let gestureRecognizer = self.panRecognizer, gestureRecognizer.numberOfTouches == 0 {
            let translation = gestureRecognizer.velocity(in: gestureRecognizer.view)
            if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                return false
            }
            if translation.x < 4.0 {
                return false
            }
            if self.controllers.count == 1 {
                return false
            }
            return true
        } else {
            return true
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self.view)
        let velocity = recognizer.velocity(in: self.view)
        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: self.view)
            self.interactivePopBegan(translation: translation.x, velocity: velocity.x, translationY: translation.y, anchor: CGPoint(x: location.x - translation.x, y: location.y - translation.y))
        case .changed:
            self.interactivePopChanged(translation: translation.x, velocity: velocity.x, translationY: translation.y)
        case .ended, .cancelled:
            self.interactivePopEnded(translation: translation.x, velocity: velocity.x, isCancelled: recognizer.state == .cancelled, translationY: translation.y)
        default:
            break
        }
    }

    /// A swipe back begins (`translation` and `velocity` along the pop, in points and points per second).
    func interactivePopBegan(translation: CGFloat, velocity: CGFloat, time: Double = CACurrentMediaTime(), translationY: CGFloat = 0.0, anchor: CGPoint = CGPoint()) {
        guard let layout = self.state.layout else {
            return
        }
        if let transition = self.state.transition {
            self.catchTransitionBySwipe(transition, translation: translation, velocity: velocity, time: time, anchor: anchor)
            return
        }
        guard self.controllers.count > 1 else {
            return
        }
        let topController = self.controllers[self.controllers.count - 1]
        let bottomController = self.controllers[self.controllers.count - 2]
        
        if !topController.attemptNavigation({ [weak self, weak topController] in
            if let self, let topController {
                self.requestFilterController(topController)
            }
        }) {
            return
        }
        
        topController.viewWillDisappear(true)
        let topNode = topController.displayNode
        var bottomControllerLayout = layout
        if bottomController.view.disableAutomaticKeyboardHandling.isEmpty {
            if let minimizedContainer = self.minimizedContainer, (bottomControllerLayout.inputHeight ?? 0.0) > 0.0 {
                var updatedSize = bottomControllerLayout.size
                var updatedIntrinsicInsets = bottomControllerLayout.intrinsicInsets
                updatedSize.height -= minimizedContainer.collapsedHeight(layout: layout)
                updatedIntrinsicInsets.bottom = 0.0
                bottomControllerLayout = bottomControllerLayout.withUpdatedSize(updatedSize).withUpdatedIntrinsicInsets(updatedIntrinsicInsets)
            }
            bottomControllerLayout = bottomControllerLayout.withUpdatedInputHeight(nil)
        }
        bottomController.containerLayoutUpdated(bottomControllerLayout, transition: .immediate)
        bottomController.viewWillAppear(true)
        let bottomNode = bottomController.displayNode
        
        let screenCornerRadii = self.minimizedContainer == nil && self.state.canBeClosed != true ? layout.screenCornerRadii : CornerRadii(uniform: 0.0)
        let style = navigationTransitionStyle(top: topController, bottom: bottomController, operation: .interactivePop, isFlat: self.isFlat, layout: layout, reduceMotion: UIAccessibility.isReduceMotionEnabled)
        let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, isInteractive: true, isFlat: self.isFlat, container: self, topNode: topNode, topNavigationBar: topController.transitionNavigationBar, topTransitionSource: topController.navigationBarTransitionSource, bottomNode: bottomNode, bottomNavigationBar: bottomController.transitionNavigationBar, bottomTransitionSource: bottomController.navigationBarTransitionSource, screenCornerRadii: screenCornerRadii, didUpdateProgress: { [weak self, weak topController, weak bottomController] progress, transition, topFrame, bottomFrame in
            if let strongSelf = self {
                if let topController {
                    strongSelf.syncKeyboard(leftEdge: topController.displayNode.frame.minX, transition: transition)
                    strongSelf.updateSwipeStatusBarStyle(top: topController, beneath: bottomController ?? topController, popProgress: progress)
                }
            }
        }, didStartProgressAnimation: { [weak self, weak topController, weak bottomController] timeline in
            guard let self, let topController else {
                return
            }
            self.animateKeyboard(timeline: timeline, leftEdge: { topFrame, _ in
                return topFrame.minX
            })
            if let bottomController {
                self.scheduleSwipeStatusBarStyle(timeline: timeline, top: topController, beneath: bottomController)
            }
        }, style: style)
        bottomController.displayNode.recursivelyEnsureDisplaySynchronously(true)
        let transition = TopTransition(type: .pop, previous: Child(value: bottomController, layout: layout), destination: self.state.top ?? Child(value: topController, layout: layout), coordinator: navigationTransitionCoordinator)
        self.state.transition = transition

        var tracker = NavigationInteractivePopTracker(totalDistance: self.view.bounds.width)
        tracker.addSample(time: time, translation: translation, velocity: velocity, isChange: false)
        self.interactivePop = InteractivePop(transition: transition, tracker: tracker, base: 0.0, target: 0.0, anchor: anchor)
    }

    /// A swipe back that begins while a transition runs takes it over where UIKit's interruptible transitions do
    /// (`NavigationTransitionCoordinator.canBeCaughtBySwipe`; measured against the native reference app, 2026-10-14).
    private func catchTransitionBySwipe(_ transition: TopTransition, translation: CGFloat, velocity: CGFloat, time: Double, anchor: CGPoint) {
        let coordinator = transition.coordinator
        guard coordinator.canBeCaughtBySwipe, let top = self.state.top else {
            return
        }
        let topController = top.value
        // Only when the screen the swipe would show is the one beneath in the stack: a push that replaced the top (or
        // pushed several screens at once) came from a screen that is no longer there.
        guard self.controllers.count >= 2, self.controllers[self.controllers.count - 1] === topController, self.controllers[self.controllers.count - 2] === transition.previous.value else {
            return
        }
        if !topController.attemptNavigation({ [weak self, weak topController] in
            if let self, let topController {
                self.requestFilterController(topController)
            }
        }) {
            return
        }
        let base: CGFloat
        switch transition.type {
        case .push:
            // UIKit pre-empts the push with a pop whose progress counts from 0: the pushed screen's card goes on toward
            // where it was heading at the speed it had, then follows the finger.
            base = 0.0
            if !transition.isSteeredBack {
                transition.isSteeredBack = true
                topController.viewWillDisappear(true)
                transition.previous.value.viewWillAppear(true)
            }
        case .pop:
            // A pop springing back is paused where it is (RE §1.2). Its screens are still leaving and coming back.
            base = coordinator.popProgress
        }
        var statusBarTurned = true
        if coordinator.isExpansion {
            // The status bar now follows the finger, not the push's clock.
            statusBarTurned = self.expansionStatusBar?.turned ?? true
            self.expansionStatusBar = nil
            coordinator.catchExpansionBySwipe()
        } else {
            coordinator.catchBySwipe(popTarget: base)
        }
        var tracker = NavigationInteractivePopTracker(totalDistance: self.view.bounds.width)
        tracker.addSample(time: time, translation: translation, velocity: velocity, isChange: false)
        self.interactivePop = InteractivePop(transition: transition, tracker: tracker, base: base, target: base, anchor: anchor, expansionStatusBarTurned: statusBarTurned)
    }

    func interactivePopChanged(translation: CGFloat, velocity: CGFloat, time: Double = CACurrentMediaTime(), translationY: CGFloat = 0.0) {
        guard var pop = self.interactivePop, let transition = self.state.transition, transition === pop.transition else {
            self.interactivePop = nil
            return
        }
        if transition.coordinator.isExpansion {
            if pop.isVertical {
                let dy = translationY >= 0.0 ? translationY : 0.25 * translationY
                transition.coordinator.trackExpansionPose(NavigationExpansionCardPose(dx: translation, dy: dy, anchor: pop.anchor, weight: 1.0, isVertical: true))
                self.interactivePop = pop
                return
            }
            let dx = translation >= 0.0 ? translation : 0.25 * translation
            transition.coordinator.trackExpansionPose(NavigationExpansionCardPose(dx: dx, dy: translationY, anchor: pop.anchor, weight: 1.0))
            self.interactivePop = pop
            return
        }
        let coordinator = transition.coordinator
        // Translation over width from where the swipe took over, chased by the tracking spring. UIKit rubber-bands it
        // past either end; it stops at them here (a decision, 2026-10-14).
        pop.target = NavigationInteractivePopTracker.targetProgress(pop.base + translation / max(1.0, self.view.bounds.width))
        pop.tracker.addSample(time: time, translation: translation, velocity: velocity, isChange: true)
        self.interactivePop = pop
        coordinator.trackInteractivePop(pop.target)
    }

    func interactivePopEnded(translation: CGFloat, velocity: CGFloat, isCancelled: Bool, time: Double = CACurrentMediaTime(), translationY: CGFloat = 0.0, velocityY: CGFloat = 0.0) {
        guard var pop = self.interactivePop, let transition = self.state.transition, transition === pop.transition else {
            self.interactivePop = nil
            return
        }
        self.interactivePop = nil
        let travel = pop.isVertical ? translationY : translation
        let travelVelocity = pop.isVertical ? velocityY : velocity
        if transition.coordinator.isExpansion, case .push = transition.type {
            // A caught expanding push: the swipe turns it back, or it runs on to the pushed screen.
            let width = max(1.0, self.view.bounds.width)
            if !isCancelled && navigationExpansionCommits(dx: travel, velocity: travelVelocity, width: width) {
                let leaving = self.state.top?.value
                if let leaving {
                    // Heading for the chat: its status bar at once.
                    self.updateSwipeStatusBarStyle(top: leaving, beneath: transition.previous.value, popProgress: 1.0)
                    leaving.viewWillLeaveNavigation()
                }
                transition.coordinator.commitExpansionPose(completion: { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition, let leaving = transition.committedTop else {
                        return
                    }
                    strongSelf.endCommittedSwipe(transition, leaving: leaving)
                })
                if let leaving {
                    self.commitSwipe(transition, leaving: leaving)
                }
            } else {
                // Heading for the profile: its status bar turns when the card covers it again.
                self.expansionStatusBar = (transition, false)
                transition.coordinator.cancelExpansionPose(completion: { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition else {
                        return
                    }
                    strongSelf.completeTopTransition(transition)
                })
            }
            return
        }
        if transition.coordinator.isExpansion, case .pop = transition.type {
            let width = max(1.0, self.view.bounds.width)
            if !isCancelled && navigationExpansionCommits(dx: travel, velocity: travelVelocity, width: width) {
                let leaving = self.state.top?.value
                leaving?.viewWillLeaveNavigation()
                transition.coordinator.commitExpansionPose(completion: { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition, let leaving = transition.committedTop else {
                        return
                    }
                    strongSelf.endCommittedSwipe(transition, leaving: leaving)
                })
                if let leaving {
                    self.commitSwipe(transition, leaving: leaving)
                }
            } else {
                transition.coordinator.cancelExpansionPose(completion: { [weak self] in
                    guard let strongSelf = self, let transition = strongSelf.state.transition else {
                        return
                    }
                    strongSelf.state.transition = nil
                    transition.destination.value.viewDidAppear(true)
                    transition.previous.value.viewDidDisappear(true)
                })
            }
            return
        }
        let navigationTransitionCoordinator = transition.coordinator
        pop.tracker.addSample(time: time, translation: translation, velocity: velocity, isChange: false)
        // UIKit's decision; a swipe the system cancelled springs back from rest.
        let decision = isCancelled ? (finish: false, velocity: 0.0) : pop.tracker.release(percent: pop.target, velocity: velocity)
        
        switch transition.type {
        case .pop:
            if decision.finish {
                let leaving = self.state.top?.value
                leaving?.viewWillLeaveNavigation()
                navigationTransitionCoordinator.animateCompletion(decision.velocity, completion: { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition, let leaving = transition.committedTop else {
                        return
                    }
                    strongSelf.endCommittedSwipe(transition, leaving: leaving)
                })
                if let leaving {
                    self.commitSwipe(transition, leaving: leaving)
                }
            } else {
                let spring: NavigationTransitionSpring = isCancelled ? .noninteractive : .interactive
                navigationTransitionCoordinator.animateCancel(velocity: decision.velocity / max(1.0, self.view.bounds.width), spring: spring, { [weak self] in
                    guard let strongSelf = self, let transition = strongSelf.state.transition else {
                        return
                    }
                    strongSelf.state.transition = nil
                    
                    transition.destination.value.viewDidAppear(true)
                    transition.previous.value.viewDidDisappear(true)
                })
            }
        case .push:
            // A push a swipe caught: the pop it became finishes by running the push back to its start, or the push runs
            // on to its end. Velocities are along the pop.
            let width = max(1.0, self.view.bounds.width)
            if decision.finish {
                let leaving = self.state.top?.value
                leaving?.viewWillLeaveNavigation()
                navigationTransitionCoordinator.animateCancel(velocity: -decision.velocity / width, spring: .interactive, { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition, let leaving = transition.committedTop else {
                        return
                    }
                    strongSelf.endCommittedSwipe(transition, leaving: leaving)
                })
                if let leaving {
                    self.commitSwipe(transition, leaving: leaving)
                }
            } else {
                navigationTransitionCoordinator.animateCompletion(-decision.velocity, completion: { [weak self, weak transition] in
                    guard let strongSelf = self, let transition, strongSelf.state.transition === transition else {
                        return
                    }
                    strongSelf.completeTopTransition(transition)
                })
            }
        }
    }
    
    public func update(layout: ContainerViewLayout, canBeClosed: Bool, controllers: [ViewController], transition: ContainedViewLayoutTransition) {
        let previousLayout = self.state.layout
        self.state.layout = layout
        self.state.canBeClosed = canBeClosed
        if let previousLayout, previousLayout.size != layout.size, let transition = self.state.transition {
            if transition.coordinator.isExpansion {
                // An expansion was measured for the old size: it jumps to its end (every ending returns everything).
                transition.coordinator.performCompletion(completion: {})
            } else {
                // A rotation or a fold mid-transition: its keyframes go on, on their phase, for the new size.
                transition.coordinator.containerSizeUpdated()
            }
        }
        
        var controllersUpdated = false
        if self.controllers.count != controllers.count {
            controllersUpdated = true
        } else {
            for i in 0 ..< controllers.count {
                if self.controllers[i] !== controllers[i] {
                    controllersUpdated = true
                    break
                }
            }
        }
        if controllersUpdated {
            let previousControllers = self.controllers
            self.controllers = controllers
            
            for i in 0 ..< controllers.count {
                if i == 0 {
                    if canBeClosed {
                        controllers[i].transitionNavigationBar?.previousItem = .close
                        controllers[i].previousItem = .close
                    } else {
                        controllers[i].transitionNavigationBar?.previousItem = nil
                        controllers[i].previousItem = nil
                    }
                } else {
                    controllers[i].transitionNavigationBar?.previousItem = .item(controllers[i - 1].navigationItem)
                    controllers[i].previousItem = .item(controllers[i - 1].navigationItem)
                }
            }
        
            // Back mid-push: the screen beneath a push is on top again while the push runs — the push runs back instead
            // of a pop starting over it.
            if let transition = self.state.transition, transition.type == .push, transition.coordinator.canReverse, controllers.last === transition.previous.value, let top = self.state.top {
                let reversed = top.value
                if !transition.isSteeredBack {
                    // A push a swipe caught and let go on has had these already.
                    reversed.viewWillDisappear(true)
                    transition.previous.value.viewWillAppear(true)
                }
                transition.isSteeredBack = true
                transition.coordinator.topLeftStack = true
                reversed.isInFocus = false
                self.state.top = transition.previous
                self.state.top?.value.isInFocus = self.isInFocus
                transition.destination = transition.previous
                self.state.pending = nil
                transition.coordinator.reverse(completion: { [weak self, weak transition] in
                    guard let self, let transition, self.state.transition === transition else {
                        return
                    }
                    self.landOnScreenBeneath(transition, leaving: reversed)
                })
            }
            
            // A swipe committed toward the screen beneath: the stack dropped its top at the commit. The transition runs on
            // to the screen beneath, the container's top from now on, and lands there itself (`endCommittedSwipe`).
            if let transition = self.state.transition, let committed = transition.committedTop, !transition.committedTopLeftStack, self.state.top?.value === committed, controllers.last === transition.previous.value {
                transition.committedTopLeftStack = true
                transition.coordinator.topLeftStack = true
                committed.isInFocus = false
                self.state.top = transition.previous
                self.state.top?.value.isInFocus = self.isInFocus
                self.state.pending = nil
            }

            if controllers.last !== self.state.top?.value {
                self.state.top?.value.statusBar.alphaUpdated = nil
                if let controller = controllers.last {
                    controller.statusBar.alphaUpdated = { [weak self, weak controller] transition in
                        guard let strongSelf = self, let controller = controller else {
                            return
                        }
                        if strongSelf.state.top?.value === controller && strongSelf.state.transition == nil {
                            strongSelf.statusBarStyleUpdated?(transition)
                        }
                    }
                }
                
                if controllers.last !== self.state.pending?.value.value {
                    self.state.pending = nil
                    if let last = controllers.last {
                        let transitionType: PendingChild.TransitionType
                        if !previousControllers.contains(where: { $0 === last }) {
                            transitionType = .push
                        } else {
                            transitionType = .pop
                        }
                        var updatedLayout = layout
                        if last.view.disableAutomaticKeyboardHandling.isEmpty {
                            updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                        }
                        self.state.pending = PendingChild(value: self.makeChild(layout: updatedLayout, value: last), transitionType: transitionType, transition: transition, update: { [weak self] pendingChild in
                            self?.pendingChildIsReady(pendingChild)
                        })
                    }
                }
            }
        }
        
        var statusBarTransition = transition
        
        var ignoreInputHeight = false
        if let pending = self.state.pending {
            if pending.isReady {
                self.state.pending = nil
                let previous = self.state.top
                previous?.value.isInFocus = false
                self.state.top = pending.value
                var updatedLayout = layout
                if pending.value.value.view.disableAutomaticKeyboardHandling.isEmpty {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
                if case .regular = layout.metrics.widthClass, pending.value.layout.inputHeight == nil {
                    ignoreInputHeight = true
                }
                self.topTransition(from: previous, to: pending.value, transitionType: pending.transitionType, layout: updatedLayout, transition: pending.transition)
                self.state.top?.value.isInFocus = self.isInFocus
                statusBarTransition = pending.transition
                if !self.isReady {
                    self.isReady = true
                    self.isReadyUpdated?()
                }
            }
        }
        
        if controllers.isEmpty && self.state.top != nil {
            let previous = self.state.top
            previous?.value.isInFocus = false
            self.state.top = nil
            self.topTransition(from: previous, to: nil, transitionType: .pop, layout: layout, transition: .immediate)
        }
        
        var updatedStatusBarStyle = self.statusBarStyle
        if let top = self.state.top {
            var updatedLayout = layout
            if let _ = self.state.transition, top.value.view.disableAutomaticKeyboardHandling.isEmpty {
                if !viewTreeContainsFirstResponder(view: top.value.view) {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
            if ignoreInputHeight {
                updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
            }
            self.applyLayout(layout: updatedLayout, to: top, isMaster: true, transition: transition)
            if let childTransition = self.state.transition, childTransition.coordinator.isInteractive {
                switch childTransition.type {
                case .push:
                    // A push a swipe caught, steered as a pop. The swiped screen is the transition's (a commit drops it
                    // from the stack before it lands).
                    if childTransition.coordinator.isExpansion {
                        // A caught expansion sets its status bar itself: from the card's fade while the finger holds it,
                        // the chat's at a release toward it, the profile's once the card covers it again otherwise. Its
                        // pop progress is the card's clock, which has not moved when a release is decided, so this rule
                        // put the profile's back over the chat until the next navigation.
                        updatedStatusBarStyle = self.statusBarStyle
                    } else if childTransition.coordinator.popProgress >= 0.3 {
                        updatedStatusBarStyle = childTransition.previous.value.statusBar.statusBarStyle
                    } else {
                        updatedStatusBarStyle = childTransition.destination.value.statusBar.statusBarStyle
                    }
                case .pop:
                    if childTransition.coordinator.progress >= 0.3 {
                        updatedStatusBarStyle = childTransition.previous.value.statusBar.statusBarStyle
                    } else {
                        updatedStatusBarStyle = childTransition.destination.value.statusBar.statusBarStyle
                    }
                }
            } else if let expansion = self.expansionStatusBar, expansion.transition === self.state.transition, !expansion.turned {
                updatedStatusBarStyle = expansion.transition.previous.value.statusBar.statusBarStyle
            } else {
                updatedStatusBarStyle = top.value.statusBar.statusBarStyle
            }
        } else {
            updatedStatusBarStyle = .Ignore
        }
        if self.statusBarStyle != updatedStatusBarStyle {
            self.statusBarStyle = updatedStatusBarStyle
            self.statusBarStyleUpdated?(statusBarTransition)
        }
    }
    
    public var shouldAnimateDisappearance: Bool = false
    
    private func topTransition(from fromValue: Child?, to toValue: Child?, transitionType: PendingChild.TransitionType, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if case .animated = transition, let fromValue = fromValue, let toValue = toValue {
            if let currentTransition = self.state.transition {
                // A finger steering it lets go of it: the new transition runs on its own.
                self.interactivePop = nil
                currentTransition.coordinator.performCompletion(completion: {
                })
            }
            
            fromValue.value.viewWillLeaveNavigation()
            fromValue.value.viewWillDisappear(true)
            toValue.value.viewWillAppear(true)
            toValue.value.setIgnoreAppearanceMethodInvocations(true)
            if let layout = self.state.layout {
                toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            }
            let mappedTransitionType: NavigationTransition
            let topController: ViewController
            let bottomController: ViewController
            switch transitionType {
            case .push:
                mappedTransitionType = .Push
                self.addSubnode(toValue.value.displayNode)
                topController = toValue.value
                bottomController = fromValue.value
            case .pop:
                mappedTransitionType = .Pop
                self.insertSubnode(toValue.value.displayNode, belowSubnode: fromValue.value.displayNode)
                topController = fromValue.value
                bottomController = toValue.value
            }
            toValue.value.setIgnoreAppearanceMethodInvocations(false)
            
            let screenCornerRadii = self.minimizedContainer == nil && self.state.canBeClosed != true ? layout.screenCornerRadii : CornerRadii(uniform: 0.0)
            let style = navigationTransitionStyle(top: topController, bottom: bottomController, operation: transitionType == .push ? .push : .pop, isFlat: self.isFlat, layout: layout, reduceMotion: UIAccessibility.isReduceMotionEnabled)
            var isExpansion = false
            if case .expand = style {
                isExpansion = true
                // No app window covers the keyboard: on an expanding push it goes down on the system's own animation
                // instead of riding the (still) screens.
                if transitionType == .push {
                    bottomController.view.endEditing(true)
                }
            }
            // Where the keyboard's left edge goes with the screens (nil: it stays).
            // Where the keyboard goes for a pair of screen frames (nil: it stays). Decided once per use: the question walks
            // the top screen's view tree, and a bake's samples share one answer.
            let keyboardLeftEdge: () -> ((CGRect, CGRect) -> CGFloat)? = { [weak self] in
                guard let self else {
                    return nil
                }
                if isExpansion {
                    return nil
                }
                switch transitionType {
                case .push:
                    // The pushed screen's keyboard rides with it, also when back turns the push back (the screen beneath
                    // is then the stack's top, the pushed screen still the transition's).
                    if let transition = self.state.transition, viewTreeContainsFirstResponder(view: transition.coordinator.topNode.view) {
                        return { topFrame, _ in topFrame.minX }
                    } else if let hasActiveInput = self.state.top?.value.hasActiveInput, hasActiveInput {
                        return nil
                    } else {
                        return { topFrame, bottomFrame in topFrame.minX - bottomFrame.width }
                    }
                case .pop:
                    return { topFrame, _ in topFrame.minX }
                }
            }
            let topTransition = TopTransition(type: transitionType, previous: fromValue, destination: toValue, coordinator: NavigationTransitionCoordinator(transition: mappedTransitionType, isInteractive: false, isFlat: self.isFlat, container: self, topNode: topController.displayNode, topNavigationBar: topController.transitionNavigationBar, topTransitionSource: topController.navigationBarTransitionSource, bottomNode: bottomController.displayNode, bottomNavigationBar: bottomController.transitionNavigationBar, bottomTransitionSource: bottomController.navigationBarTransitionSource, screenCornerRadii: screenCornerRadii, didUpdateProgress: { [weak self] progress, transition, topFrame, bottomFrame in
                guard let strongSelf = self else {
                    return
                }
                if transitionType == .push, let currentTransition = strongSelf.state.transition, currentTransition.type == .push, currentTransition.coordinator.isInteractive {
                    let top = currentTransition.destination
                    if currentTransition.coordinator.isExpansion {
                        // A caught expanding push reports the card's fade: the status bar follows it once it had turned
                        // to the pushed screen's, else the chat's stays.
                        if let pop = strongSelf.interactivePop, pop.transition === currentTransition {
                            strongSelf.updateSwipeStatusBarStyle(top: top.value, beneath: currentTransition.previous.value, popProgress: pop.expansionStatusBarTurned ? progress : 1.0)
                        }
                    } else {
                        // A push a swipe caught: the status bar follows it as a swipe back's does.
                        strongSelf.updateSwipeStatusBarStyle(top: top.value, beneath: currentTransition.previous.value, popProgress: currentTransition.coordinator.popProgress)
                    }
                }
                if let leftEdge = keyboardLeftEdge() {
                    strongSelf.syncKeyboard(leftEdge: leftEdge(topFrame, bottomFrame), transition: transition)
                }
            }, didStartProgressAnimation: { [weak self] timeline in
                guard let self else {
                    return
                }
                self.animateKeyboard(timeline: timeline, leftEdge: keyboardLeftEdge())
                if let expansion = self.expansionStatusBar, expansion.transition === self.state.transition, !expansion.turned, let top = self.state.top {
                    // The status bar turns when the card has covered it: at 0.3 of the spring toward light, 0.45 toward
                    // dark (the prototype's `RootView.run`).
                    let target = top.value.statusBar.statusBarStyle
                    let fraction: Double = target == .White ? 0.3 : 0.45
                    let duration = Double(transitionType == .push ? (style.expansionOpenResponse ?? 0.55) : (style.expansionCloseResponse ?? 0.5))
                    timeline.schedule(duration * fraction, { [weak self] in
                        guard let self, var current = self.expansionStatusBar, current.transition === self.state.transition else {
                            return
                        }
                        current.turned = true
                        self.expansionStatusBar = current
                        if self.statusBarStyle != target {
                            self.statusBarStyle = target
                            self.statusBarStyleUpdated?(.animated(duration: 0.3, curve: .easeInOut))
                        }
                    })
                }
                // An expansion's timeline fractions are its bars', and its release sets the status bar itself.
                if transitionType == .push, let currentTransition = self.state.transition, currentTransition.type == .push, currentTransition.coordinator.isInteractive, !currentTransition.coordinator.isExpansion {
                    self.scheduleSwipeStatusBarStyle(timeline: timeline, top: currentTransition.destination.value, beneath: currentTransition.previous.value)
                }
            }, style: style))
            self.transitionKeyboardLeftEdge = keyboardLeftEdge
            if transitionType == .push {
                topTransition.coordinator.backTapped = { [weak topController] in
                    let _ = topController?.navigationBar?.executeBack()
                }
            }
            self.state.transition = topTransition
            if topTransition.coordinator.isExpansion {
                self.expansionStatusBar = (topTransition, false)
            }
            
            topTransition.coordinator.animateCompletion(0.0, completion: { [weak self, weak topTransition] in
                guard let strongSelf = self, let topTransition = topTransition, strongSelf.state.transition === topTransition else {
                    return
                }
                strongSelf.completeTopTransition(topTransition)
            })
        } else {
            if let fromValue = fromValue {
                if viewTreeContainsFirstResponder(view: fromValue.value.view) {
                    self.ignoreInputHeight = true
                }
                
                fromValue.value.viewWillLeaveNavigation()
                fromValue.value.viewWillDisappear(false)
                
                self.keyboardViewManager?.dismissEditingWithoutAnimation(view: fromValue.value.view)
                
                fromValue.value.setIgnoreAppearanceMethodInvocations(true)
                fromValue.value.displayNode.removeFromSupernode()
                fromValue.value.setIgnoreAppearanceMethodInvocations(false)
                fromValue.value.viewDidDisappear(false)
            }
            if let toValue = toValue {
                self.applyLayout(layout: layout, to: toValue, isMaster: true, transition: .immediate)
                toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                toValue.value.viewWillAppear(false)
                toValue.value.setIgnoreAppearanceMethodInvocations(true)
                self.addSubnode(toValue.value.displayNode)
                toValue.value.setIgnoreAppearanceMethodInvocations(false)
                toValue.value.displayNode.recursivelyEnsureDisplaySynchronously(true)
                toValue.value.viewDidAppear(false)
            }
            if let lingering = self.lingeringNavigationBarTransitionLayer {
                if let toValue, lingering.isLingering(above: toValue.value.navigationBarTransitionSource) {
                    // A finished swipe back ends here, adding the screen beneath again, which brings it to the front:
                    // the glass still animating above its bar goes back over it.
                    self.addSubnode(lingering)
                } else {
                    self.endLingeringNavigationBarTransition()
                }
            }
            self.ignoreInputHeight = false
        }
    }
    
    /// A swipe committed toward the screen beneath: the top screen leaves the stack now, as UIKit's does at the commit
    /// (`NavigationController.filterController`), and the transition runs on to the screen beneath (`update`).
    private func commitSwipe(_ transition: TopTransition, leaving: ViewController) {
        transition.committedTop = leaving
        self.controllerRemoved(leaving)
    }

    /// The ending of a swipe committed toward the screen beneath. The stack dropped its top at the commit (a laid-out
    /// navigation controller always does); if it kept it, the transition just ends and the stack's next update lays the
    /// container out, since the removal is not repeated.
    private func endCommittedSwipe(_ transition: TopTransition, leaving: ViewController) {
        if transition.committedTopLeftStack {
            self.landOnScreenBeneath(transition, leaving: leaving)
        } else {
            if viewTreeContainsFirstResponder(view: leaving.view) {
                self.ignoreInputHeight = true
            }
            self.keyboardViewManager?.dismissEditingWithoutAnimation(view: leaving.view)
            self.state.transition = nil
            self.ignoreInputHeight = false
        }
    }

    /// A transition heading to the screen beneath, whose top the stack has dropped, lands: the top screen leaves and the
    /// screen beneath appears, laid out as the container's top.
    private func landOnScreenBeneath(_ transition: TopTransition, leaving: ViewController) {
        self.state.transition = nil
        self.expansionStatusBar = nil
        if viewTreeContainsFirstResponder(view: leaving.view) {
            self.ignoreInputHeight = true
        }
        self.keyboardViewManager?.dismissEditingWithoutAnimation(view: leaving.view)
        leaving.setIgnoreAppearanceMethodInvocations(true)
        leaving.displayNode.removeFromSupernode()
        leaving.setIgnoreAppearanceMethodInvocations(false)
        leaving.viewDidDisappear(true)
        let destination = transition.previous
        if let layout = self.state.layout, destination.value.displayNode.supernode === self {
            destination.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            self.applyLayout(layout: layout, to: destination, isMaster: true, transition: .immediate)
            destination.value.viewDidAppear(true)
        }
        self.ignoreInputHeight = false
    }
    
    /// A tap push or pop has run to its end (or a push a swipe caught was let go and ran on to it): the previous screen
    /// leaves.
    private func completeTopTransition(_ topTransition: TopTransition) {
        self.expansionStatusBar = nil
        if viewTreeContainsFirstResponder(view: topTransition.previous.value.view) {
            self.ignoreInputHeight = true
        }
        self.keyboardViewManager?.dismissEditingWithoutAnimation(view: topTransition.previous.value.view)
        self.state.transition = nil
        
        if self.shouldAnimateDisappearance {
            let displayNode = topTransition.previous.value.displayNode
            displayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak displayNode] _ in
                displayNode?.removeFromSupernode()
                displayNode?.layer.removeAllAnimations()
            })
        } else {
            topTransition.previous.value.setIgnoreAppearanceMethodInvocations(true)
            topTransition.previous.value.displayNode.removeFromSupernode()
            topTransition.previous.value.setIgnoreAppearanceMethodInvocations(false)
        }
        topTransition.previous.value.viewDidDisappear(true)
        // The screen this transition lands on, which a push landing it has already replaced as the stack's top (and an
        // immediate replacement may have removed).
        let toValue = topTransition.destination
        if let layout = self.state.layout, toValue.value.displayNode.supernode === self {
            toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            self.applyLayout(layout: layout, to: toValue, isMaster: true, transition: .immediate)
            toValue.value.viewDidAppear(true)
        }
        
        self.ignoreInputHeight = false
    }
    
    private func makeChild(layout: ContainerViewLayout, value: ViewController) -> Child {
        var updatedLayout = layout
        if value.view.disableAutomaticKeyboardHandling.isEmpty {
            updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
        }
        value.containerLayoutUpdated(updatedLayout, transition: .immediate)
        return Child(value: value, layout: updatedLayout)
    }
    
    private func applyLayout(layout: ContainerViewLayout, to child: Child, isMaster: Bool, transition: ContainedViewLayoutTransition) {
        var childFrame = CGRect(origin: CGPoint(), size: layout.size)
        
        var updatedLayout = layout
        
        var shouldSyncKeyboard = false
        if let transition = self.state.transition {
            childFrame.origin.x = child.value.displayNode.frame.origin.x
            switch transition.type {
            case .pop:
                if transition.previous.value === child.value {
                    shouldSyncKeyboard = true
                }
            case .push:
                break
            }
            if updatedLayout.inputHeight != nil {
                if !self.canHaveKeyboardFocus && child.value.view.disableAutomaticKeyboardHandling.isEmpty {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
        } else {
            if isMaster {
                shouldSyncKeyboard = true
            }
            
            if updatedLayout.inputHeight != nil && child.value.view.disableAutomaticKeyboardHandling.isEmpty {
                if !self.canHaveKeyboardFocus || self.ignoreInputHeight {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
        }
        if child.value.displayNode.frame != childFrame {
            transition.updateFrame(node: child.value.displayNode, frame: childFrame)
        }
        if shouldSyncKeyboard && isMaster {
            self.syncKeyboard(leftEdge: childFrame.minX, transition: transition)
        }
        if child.layout != updatedLayout {
            child.layout = updatedLayout
            child.value.containerLayoutUpdated(updatedLayout, transition: transition)
        }
    }
    
    public func updateAdditionalKeyboardLeftEdgeOffset(_ offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.additionalKeyboardLeftEdgeOffset = offset
        self.syncKeyboard(leftEdge: self.currentKeyboardLeftEdge, transition: transition)
    }
    
    private func syncKeyboard(leftEdge: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentKeyboardLeftEdge = leftEdge
        self.keyboardViewManager?.update(leftEdge: self.additionalKeyboardLeftEdgeOffset + leftEdge, transition: transition)
    }
    
    private func pendingChildIsReady(_ child: PendingChild) {
        if let pending = self.state.pending, pending === child {
            pending.isReady = true
            self.performUpdate(transition: .immediate)
        }
    }
    
    private func performUpdate(transition: ContainedViewLayoutTransition) {
        if let layout = self.state.layout, let canBeClosed = self.state.canBeClosed {
            self.update(layout: layout, canBeClosed: canBeClosed, controllers: self.controllers, transition: transition)
        }
    }
    
    var isTransitioning: Bool {
        return self.state.transition != nil
    }

    /// The view a swipe's restrictions are read from: the one under `point` in the screens, as `hitTest` finds it when no
    /// transition runs. During a transition the container takes every touch itself, so a swipe that begins then would
    /// otherwise skip the restrictions of the screen under the finger (horizontal content, a screen that disables it).
    func gestureRestrictionsHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        // UIView's own search over the subviews: `super.hitTest` cannot be used from here, because AsyncDisplayKit sends
        // a view's hit test back through the node (`_ASDisplayView`), which would land in the override that takes every
        // touch.
        for subview in self.view.subviews.reversed() {
            // A screen running on keyframes is drawn away from its model frame: follow where it is drawn.
            let displacement = self.state.transition?.coordinator.presentedDisplacement(of: subview) ?? CGPoint()
            var subviewPoint = self.view.convert(point, to: subview)
            subviewPoint.x -= displacement.x
            subviewPoint.y -= displacement.y
            if let result = subview.hitTest(subviewPoint, with: event) {
                return result
            }
        }
        return self.view
    }

    /// While a swipe steers a transition the status bar is the leaving screen's until 0.3 of the way, then the one coming
    /// back's.
    private func updateSwipeStatusBarStyle(top: ViewController, beneath: ViewController, popProgress: CGFloat) {
        let updatedStatusBarStyle = popProgress >= 0.3 ? beneath.statusBar.statusBarStyle : top.statusBar.statusBarStyle
        if self.statusBarStyle != updatedStatusBarStyle {
            self.statusBarStyle = updatedStatusBarStyle
            self.statusBarStyleUpdated?(.animated(duration: 0.3, curve: .easeInOut))
        }
    }

    /// A swipe was let go and the transition runs on the render server: the status bar flips where its timeline crosses
    /// 0.3 of the pop (`popProgress = 1 - fraction`), scheduled on the transition's clock.
    private func scheduleSwipeStatusBarStyle(timeline: NavigationTransitionTimeline, top: ViewController, beneath: ViewController) {
        let showsBeneathAtStart = 1.0 - (timeline.fractions.first ?? 0.0) >= 0.3
        guard let index = timeline.fractions.firstIndex(where: { (1.0 - $0 >= 0.3) != showsBeneathAtStart }) else {
            return
        }
        let popProgress = 1.0 - timeline.fractions[index]
        timeline.schedule(timeline.timing.sampleTimes[index], { [weak self, weak top, weak beneath] in
            guard let self, let top, let beneath else {
                return
            }
            self.updateSwipeStatusBarStyle(top: top, beneath: beneath, popProgress: popProgress)
        })
    }

    /// The keyboard follows the screens on the render server, along `timeline`; `leftEdge` gives its edge for a pair of
    /// screen frames (nil: the keyboard stays where it is).
    private func animateKeyboard(timeline: NavigationTransitionTimeline, leftEdge: ((CGRect, CGRect) -> CGFloat)?) {
        guard let leftEdge else {
            return
        }
        let edges = zip(timeline.topFrames, timeline.bottomFrames).map { leftEdge($0, $1) }
        guard let last = edges.last else {
            return
        }
        self.currentKeyboardLeftEdge = last
        self.keyboardViewManager?.animate(leftEdges: edges.map { self.additionalKeyboardLeftEdgeOffset + $0 }, timing: timeline.timing)
    }

    /// The transition glass still animating above the bar a finished transition ended on
    /// (`NavigationBarTransitionLayer.putBack(lingering:)`).
    private var lingeringNavigationBarTransitionLayer: NavigationBarTransitionLayer?

    func beginLingering(_ layer: NavigationBarTransitionLayer) {
        self.endLingeringNavigationBarTransition()
        self.lingeringNavigationBarTransitionLayer = layer
        layer.lingerEnded = { [weak self, weak layer] in
            guard let self, let layer, self.lingeringNavigationBarTransitionLayer === layer else {
                return
            }
            self.lingeringNavigationBarTransitionLayer = nil
        }
    }

    /// The lingering glass hands over to its bar at once.
    func endLingeringNavigationBarTransition() {
        if let layer = self.lingeringNavigationBarTransitionLayer {
            self.lingeringNavigationBarTransitionLayer = nil
            layer.endLingering()
        }
    }

    var lingeringNavigationBarTransitionLayerForTesting: NavigationBarTransitionLayer? {
        return self.lingeringNavigationBarTransitionLayer
    }

    /// An expanding tap push or pop: the status bar keeps the starting screen's style until its moment on the clock.
    private var expansionStatusBar: (transition: TopTransition, turned: Bool)?

    /// The running tap transition's keyboard edge rule (tests).
    private var transitionKeyboardLeftEdge: (() -> ((CGRect, CGRect) -> CGFloat)?)?
    var keyboardLeftEdgeForTesting: ((CGRect, CGRect) -> CGFloat)? {
        return self.transitionKeyboardLeftEdge?()
    }

    // Tests.
    var transitionCoordinatorForTesting: NavigationTransitionCoordinator? {
        return self.state.transition?.coordinator
    }
    var topControllerForTesting: ViewController? {
        return self.state.top?.value
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if let transition = self.state.transition {
            let coordinator = transition.coordinator
            if let hole = coordinator.backHole(at: point, in: self.view) {
                return hole
            }
            // From 0.25 s into a transition running on its own, touches reach the screen it is heading to, where it is
            // drawn; the leaving screen never gets them, nor does anything while a finger steers.
            if self.interactivePop == nil, coordinator.acceptsTouches {
                let heading = coordinator.headingNode
                if heading.supernode === self {
                    let displacement = coordinator.presentedDisplacement(of: heading.view)
                    var local = self.view.convert(point, to: heading.view)
                    local.x -= displacement.x
                    local.y -= displacement.y
                    // A screen drawn through a mask (an expansion's card) takes touches only inside it, where it is drawn
                    // now (`-hitTest:` ignores masks): around the card the screen beneath is still what is seen.
                    if let mask = heading.layer.mask, !(mask.presentation() ?? mask).frame.contains(local) {
                        return self.view
                    }
                    if let hit = heading.view.hitTest(local, with: event) {
                        return hit
                    }
                }
            }
            return self.view
        }
        return super.hitTest(point, with: event)
    }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        if let controller = self.controllers.last {
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        if let transition = self.state.transition {
            let controller = transition.previous.value
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        return supportedOrientations
    }
}
