import UIKit
import AppBundle
import AsyncDisplayKit

enum NavigationTransition {
    case Push
    case Pop
}

/// When a catch takes effect on screen, biased late: the first frame after `now` the pipeline can present, plus one
/// frame of headroom (landing early costs a few milliseconds of the curve's own motion; landing late is the step).
func navigationTransitionCatchTime(now: Double, lastTargetTimestamp: Double?, frameDuration: Double) -> Double {
    var next = now + frameDuration
    if let last = lastTargetTimestamp, frameDuration > 0.0 {
        let frames = max(0.0, ((now - last) / frameDuration).rounded(.up))
        next = last + frames * frameDuration
        if next <= now {
            next += frameDuration
        }
    }
    return next + frameDuration
}


/// Where the screens, the dim and the bars are at one progress.
struct NavigationTransitionScreenLayout: Equatable {
    var topFrame: CGRect
    var bottomFrame: CGRect
    var dimFrame: CGRect
    var dimAlpha: CGFloat
    /// 0: the bottom bar, 1: the top one.
    var fraction: CGFloat
}

final class NavigationTransitionCoordinator {
    static let keyframeKeyPrefix = "navigationTransition."

    private var _progress: CGFloat = 0.0
    /// The progress now: read from its curve while the transition runs on the render server.
    var progress: CGFloat {
        if let curve = self.progressCurve, self.clock.isRunning {
            return curve.value(at: self.clock.animationTime())
        }
        return self._progress
    }
    
    private let container: NavigationContainer
    private let transition: NavigationTransition
    /// A swipe steers it: from the start (a swipe back), or since a swipe caught it (`catchBySwipe`).
    private(set) var isInteractive: Bool
    let isFlat: Bool
    let topNode: ASDisplayNode
    let bottomNode: ASDisplayNode
    private let topNavigationBar: NavigationBar?
    private let bottomNavigationBar: NavigationBar?
    private let topTransitionSource: NavigationBarTransitionSource?
    private let bottomTransitionSource: NavigationBarTransitionSource?
    /// While the two bars morph: their lifted contents and the renderer, above both screens.
    private(set) var navigationBarTransitionLayer: NavigationBarTransitionLayer?
    private let dimNode: ASDisplayNode
    /// The top card's shadow, under the top screen and above the dim (the screen clips, so it cannot cast its own).
    private let shadowNode: ASDisplayNode
    private var cardCornerRadius: CGFloat = 0.0
    var dimNodeForTesting: ASDisplayNode {
        return self.dimNode
    }
    var shadowNodeForTesting: ASDisplayNode {
        return self.shadowNode
    }
    
    private var topNodeInitialParameters: (clipsToBounds: Bool, cornerRadius: CGFloat, usesCornerRadii: Bool)?
    private var bottomNodeInitialParameters: (clipsToBounds: Bool, cornerRadius: CGFloat, usesCornerRadii: Bool)?
    
    private let inlineNavigationBarTransition: Bool
    
    private(set) var animatingCompletion = false
    private var currentCompletion: (() -> Void)?
    private var didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition, CGRect, CGRect) -> Void)?
    /// While the progress runs on the render server: the container bakes what it moves with it (the keyboard) and
    /// schedules what changes at a point on it (the status bar).
    private var didStartProgressAnimation: ((NavigationTransitionTimeline) -> Void)?
    
    private var frameRateLink: SharedDisplayLinkDriver.Link?
    /// Runs the progress on UIKit's springs, frame by frame, once the transition animates.
    private var progressDriver: NavigationTransitionProgressDriver?
    var progressDriverForTesting: NavigationTransitionProgressDriver? {
        return self.progressDriver
    }
    /// The clock the progress curve runs on once the transition animates on its own.
    private let clock: NavigationAnimationClock
    var clockForTesting: NavigationAnimationClock {
        return self.clock
    }
    /// The progress while it runs on the render server (animation time 0 at its bake).
    private var progressCurve: NavigationSpringCurve?
    /// Runs once the curve's deadline passes.
    private var curveCompletion: (() -> Void)?
    
    init(transition: NavigationTransition, isInteractive: Bool, isFlat: Bool, container: NavigationContainer, topNode: ASDisplayNode, topNavigationBar: NavigationBar?, topTransitionSource: NavigationBarTransitionSource?, bottomNode: ASDisplayNode, bottomNavigationBar: NavigationBar?, bottomTransitionSource: NavigationBarTransitionSource?, screenCornerRadii: CornerRadii, didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition, CGRect, CGRect) -> Void)? = nil, didStartProgressAnimation: ((NavigationTransitionTimeline) -> Void)? = nil) {
        self.transition = transition
        self.isInteractive = isInteractive
        self.isFlat = isFlat
        self.container = container
        self.didUpdateProgress = didUpdateProgress
        self.didStartProgressAnimation = didStartProgressAnimation
        self.topNode = topNode
        self.bottomNode = bottomNode
        self.topNavigationBar = topNavigationBar
        self.bottomNavigationBar = bottomNavigationBar
        self.topTransitionSource = topTransitionSource
        self.bottomTransitionSource = bottomTransitionSource
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black
        // Decoration only: a swipe's restrictions are read from the screen beneath it.
        self.dimNode.isUserInteractionEnabled = false
        // UIKit's card shadow (`_UIParallaxTransitionCardView`): black, radius 12, opacity 0.04, the default (0, -3)
        // offset, constant through the transition.
        self.shadowNode = ASDisplayNode()
        self.shadowNode.isUserInteractionEnabled = false
        self.shadowNode.layer.shadowColor = UIColor.black.cgColor
        self.shadowNode.layer.shadowOpacity = 0.04
        self.shadowNode.layer.shadowRadius = 12.0
        self.shadowNode.layer.shadowOffset = CGSize(width: 0.0, height: -3.0)
        self.clock = NavigationAnimationClock(hostView: container.view)
        
        if let topNavigationBar = topNavigationBar, let bottomNavigationBar = bottomNavigationBar {
            if !topNavigationBar.isHidden, !bottomNavigationBar.isHidden, topNavigationBar.canTransitionInline, bottomNavigationBar.canTransitionInline, topNavigationBar.item?.leftBarButtonItem == nil {
                var topFrame = topNavigationBar.view.convert(topNavigationBar.bounds, to: container.view)
                var bottomFrame = bottomNavigationBar.view.convert(bottomNavigationBar.bounds, to: container.view)
                topFrame.origin.x = 0.0
                bottomFrame.origin.x = 0.0
                self.inlineNavigationBarTransition = true
            } else {
                self.inlineNavigationBarTransition = false
            }
        } else {
            self.inlineNavigationBarTransition = false
        }
        
        switch transition {
        case .Push:
            self.container.addSubnode(topNode)
        case .Pop:
            if topNode.supernode == self.container {
                self.container.insertSubnode(bottomNode, belowSubnode: topNode)
            } else {
                self.container.addSubnode(topNode)
            }
        }
        
        if !self.isFlat {
            // UIKit: the dim between the two screens, the top card's shadow above it.
            self.container.insertSubnode(self.dimNode, belowSubnode: topNode)
            self.container.insertSubnode(self.shadowNode, belowSubnode: topNode)
            
            let maxScreenCornerRadius = max(max(screenCornerRadii.topLeft, screenCornerRadii.topRight), max(screenCornerRadii.bottomLeft, screenCornerRadii.bottomRight))
            if maxScreenCornerRadius > 0.0 {
                // Both screens become cards with the screen's corners, as UIKit's do. They differ per corner on iPhone
                // Duo's folded screen (8pt on the hinge side, 59pt outside), so there they get all four; elsewhere
                // they are uniform and the single radius applies.
                let usesCornerRadii = !screenCornerRadii.isUniform && CALayer.cornerRadiiSupported
                self.cardCornerRadius = maxScreenCornerRadius
                self.topNodeInitialParameters = (topNode.clipsToBounds, topNode.cornerRadius, usesCornerRadii)
                self.bottomNodeInitialParameters = (bottomNode.clipsToBounds, bottomNode.cornerRadius, usesCornerRadii)
                for node in [topNode, bottomNode] {
                    if #available(iOS 13.0, *) {
                        node.layer.cornerCurve = .continuous
                    }
                    node.clipsToBounds = true
                    if usesCornerRadii {
                        node.layer.setCornerRadii(screenCornerRadii)
                    } else {
                        node.cornerRadius = maxScreenCornerRadius
                    }
                }
            }
        }
        
        // The previous transition's glass hands over before this one takes the bars.
        container.endLingeringNavigationBarTransition()
        self.maybeCreateNavigationBarTransition()
        self.updateProgress(0.0, transition: .immediate, completion: {})
        self.navigationBarTransitionLayer?.beginTransition(isInteractive: self.isInteractive, toTop: self.transition == .Push)
        
        self.frameRateLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { _ in })
        self.clock.ended = { [weak self] in
            self?.progressCurveEnded()
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // A container dropped mid-transition (split ↔ flat, a dismissed modal) never runs the completion that ends the
        // morph; without this the lifted bars would never get their contents back.
        self.clock.stop()
        self.endNavigationBarTransition(lingering: false)
        // The screens outlive this coordinator, and the next container lays them out from their model frames (the
        // final ones); keyframes left on them would play this transition on to its end over that layout.
        let layers = self.progressLayers
        let owner = self.keyframeOwner
        let remove = {
            NavigationTransitionCoordinator.removeProgressKeyframes(from: layers, owner: owner)
        }
        if Thread.isMainThread {
            remove()
        } else {
            DispatchQueue.main.async(execute: remove)
        }
    }

    private static func removeProgressKeyframes(from layers: [CALayer], owner: Int) {
        for layer in layers {
            for keyPath in NavigationTransitionCoordinator.progressKeyPaths {
                removeNavigationKeyframes(from: layer, key: NavigationTransitionCoordinator.keyframeKeyPrefix + keyPath, owner: owner)
            }
        }
    }

    private func removeOwnedProgressKeyframes() {
        NavigationTransitionCoordinator.removeProgressKeyframes(from: self.progressLayers, owner: self.keyframeOwner)
    }

    private static var nextKeyframeOwner = 0
    /// Stamped on this coordinator's screen keyframes.
    private let keyframeOwner: Int = {
        NavigationTransitionCoordinator.nextKeyframeOwner += 1
        return NavigationTransitionCoordinator.nextKeyframeOwner
    }()
    private static let progressKeyPaths = ["position", "bounds", "opacity"]
    private var progressLayers: [CALayer] {
        return [self.topNode.layer, self.bottomNode.layer, self.shadowNode.layer, self.dimNode.layer]
    }

    func updateProgress(_ progress: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self._progress = progress
        self.applyScreenLayout(self.screenLayout(progress: progress), transition: transition, completion: completion)
    }

    /// Where the screens, the dim and the bars are at `progress`.
    func screenLayout(progress: CGFloat) -> NavigationTransitionScreenLayout {
        let position: CGFloat
        switch self.transition {
        case .Push:
            position = 1.0 - progress
        case .Pop:
            position = progress
        }
        
        var dimInset: CGFloat = 0.0
        // The dim stops at the bar only while the bars slide with their screens; morphing bars sit above it.
        if self.navigationBarTransitionLayer == nil, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            if self.bottomNavigationBar?.isBackdropVisible == false || self.topNavigationBar?.isBackdropVisible == false {
                
            } else {
                dimInset = bottomNavigationBar.frame.maxY
            }
        }
        
        let containerSize = self.container.bounds.size
        
        let topFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(position * containerSize.width), y: 0.0), size: containerSize)
        let bottomFrame = CGRect(origin: CGPoint(x: self.isFlat ? -floorToScreenPixels((1.0 - position) * containerSize.width) : ((position - 1.0) * containerSize.width * 0.3), y: 0.0), size: containerSize)
        let dimFrame = CGRect(origin: CGPoint(x: 0.0, y: dimInset), size: CGSize(width: max(0.0, topFrame.minX + self.container.overflowInset + 62.0), height: containerSize.height - dimInset))
        // UIKit: black at 0.1, linear in the progress.
        let dimAlpha = max(0.0, min(1.0, 1.0 - position)) * 0.1
        return NavigationTransitionScreenLayout(topFrame: topFrame, bottomFrame: bottomFrame, dimFrame: dimFrame, dimAlpha: dimAlpha, fraction: 1.0 - position)
    }

    /// Puts the screens, the dim and the shadow where `layout` has them; with `updatesBars` the bars and the container's
    /// observers hear of it too (a baked transition reaches them through its timeline instead).
    private func applyScreenLayout(_ layout: NavigationTransitionScreenLayout, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void, updatesBars: Bool = true) {
        var canInvokeCompletion = false
        var hadEarlyCompletion = false
        transition.updateFrame(node: self.topNode, frame: layout.topFrame, completion: { _ in
            if canInvokeCompletion {
                completion()
            } else {
                hadEarlyCompletion = true
            }
        })
        canInvokeCompletion = true
        transition.updateFrame(node: self.dimNode, frame: layout.dimFrame)
        transition.updateFrame(node: self.shadowNode, frame: layout.topFrame)
        if self.shadowNode.layer.shadowPath?.boundingBox.size != layout.topFrame.size {
            self.shadowNode.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: layout.topFrame.size), cornerRadius: self.cardCornerRadius).cgPath
        }
        transition.updateAlpha(node: self.dimNode, alpha: layout.dimAlpha)
        
        transition.updateFrame(node: self.bottomNode, frame: layout.bottomFrame)
        
        if updatesBars {
            self.navigationBarTransitionLayer?.update(fraction: layout.fraction, transition: transition)
            self.didUpdateProgress?(self.progress, transition, layout.topFrame, layout.bottomFrame)
        }
        
        if hadEarlyCompletion {
            completion()
        }
    }
    
    /// Lifts both bars' contents into a layer above the two screens when both take part and the app can render the
    /// morph; otherwise the bars slide with their screens.
    func maybeCreateNavigationBarTransition() {
        guard self.navigationBarTransitionLayer == nil, let bottomSource = self.bottomTransitionSource, let topSource = self.topTransitionSource, let makeRenderer = defaultNavigationBarTransitionRenderer else {
            return
        }
        guard let bottomInfo = bottomSource.takeView() else {
            return
        }
        guard let topInfo = topSource.takeView() else {
            bottomSource.putBack()
            return
        }
        guard let renderer = makeRenderer(bottomSource, topSource) else {
            bottomSource.putBack()
            topSource.putBack()
            return
        }
        let layer = NavigationBarTransitionLayer(renderer: renderer, bottom: (bottomSource, bottomInfo, self.bottomNode.view), top: (topSource, topInfo, self.topNode.view))
        layer.frame = self.container.bounds
        self.container.insertSubnode(layer, aboveSubnode: self.topNode)
        self.navigationBarTransitionLayer = layer
    }
    
    /// Ends the roles and returns both contents to their bars; runs before the transition's completion. Glass still
    /// animating stays above the bar the transition ended on until it settles (`lingering`), as UIKit's capsules
    /// outlive the screens' transition.
    func endNavigationBarTransition(lingering: Bool = true) {
        if let layer = self.navigationBarTransitionLayer {
            self.navigationBarTransitionLayer = nil
            if layer.putBack(lingering: lingering) {
                self.container.beginLingering(layer)
            } else {
                layer.removeFromSupernode()
            }
        }
    }
    
    /// Springs back to the start. A released swipe uses UIKit's interactive spring with the finger's `velocity`
    /// (progress per second); a swipe the system cancelled springs back from rest.
    func animateCancel(velocity: CGFloat, spring: NavigationTransitionSpring, _ completion: @escaping () -> ()) {
        self.currentCompletion = completion
        self.runningTarget = 0.0
        if self.isInteractive {
            self.navigationBarTransitionLayer?.endInteraction(towardTop: self.transition == .Pop)
        }
        
        self.releaseProgress(to: 0.0, spring: spring, velocity: velocity, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.transition {
            case .Push:
                strongSelf.topNode.removeFromSupernode()
            case .Pop:
                strongSelf.bottomNode.removeFromSupernode()
            }
            
            strongSelf.dimNode.removeFromSupernode()
            strongSelf.shadowNode.removeFromSupernode()
            
            
            strongSelf.endNavigationBarTransition()
            
            strongSelf.restoreTopNodeCorners()
            
            if let currentCompletion = strongSelf.currentCompletion {
                strongSelf.currentCompletion = nil
                currentCompletion()
            }
        })
    }
    
    /// The progress as a pop's: 0 shows the top screen, 1 the bottom one, whichever way the transition runs.
    var popProgress: CGFloat {
        return self.transition == .Push ? 1.0 - self.progress : self.progress
    }

    /// Where the progress runs on its own (nil: a swipe steers it, or it has not started or has ended).
    private var runningTarget: CGFloat?

    /// Whether a swipe back can take this transition over now, as UIKit's interruptible transitions allow: only while it
    /// runs on its own toward the top screen (a tap push, a caught push let go toward its end, or a pop springing back
    /// after a cancelled swipe). A pop running to the screen beneath is not taken over; UIKit starts a second pop
    /// alongside it instead, which this container does not do (measured on the iOS 27 simulator, 2026-10-14).
    var canBeCaughtBySwipe: Bool {
        guard let runningTarget = self.runningTarget else {
            return false
        }
        return runningTarget == (self.transition == .Push ? 1.0 : 0.0)
    }

    /// A swipe back takes the running transition over: from here it steers it toward `popTarget` (a pop's progress) on
    /// the tracking spring, starting where the transition is and at the speed it has. The ending that was to run (the
    /// push's own, or a cancelled swipe's) no longer runs on settling; the swipe's release replaces it. It stays the
    /// ending if the transition is completed at once meanwhile (`performCompletion`, a stack change under the finger).
    func catchBySwipe(popTarget: CGFloat) {
        self.isInteractive = true
        self.animatingCompletion = false
        self.navigationBarTransitionLayer?.beginInteraction()
        if let curve = self.progressCurve, self.clock.isRunning, let reinstall = self.clock.reinstallTiming {
            // A swap, not a removal: the keyframes run on to the frame the change can land on (plus one) and hold
            // there, and the finger's spring takes over from that instant (CoreList, "Stopping a render-server-played
            // flight is a SWAP").
            let frameTiming = self.frameTiming()
            let cutMediaTime = navigationTransitionCatchTime(now: self.clock.now(), lastTargetTimestamp: frameTiming.lastTargetTimestamp, frameDuration: frameTiming.frameDuration)
            let cut = self.clock.animationTime(at: cutMediaTime)
            let value = curve.value(at: cut)
            let velocity = curve.velocity(at: cut)
            self.clock.stop()
            self.progressCurve = nil
            self.curveCompletion = nil
            self.installProgressKeyframes(curve: curve, timing: reinstall.withDuration(cut))
            self._progress = value
            let driver = NavigationTransitionProgressDriver(value: value, update: { [weak self] value in
                self?.updateProgress(value, transition: .immediate, completion: {})
            })
            self.progressDriver = driver
            driver.animate(to: value, spring: .tracking, velocity: velocity, overshoots: false, settled: nil)
            driver.begin(atMediaTime: cutMediaTime)
        }
        self.trackInteractivePop(popTarget)
    }

    /// While a swipe drags: `target` as a pop's progress (see `popProgress`).
    func trackInteractivePop(_ target: CGFloat) {
        self.trackInteractiveProgress(self.transition == .Push ? 1.0 - target : target)
    }

    /// Runs the progress toward `target` on `spring`, frame by frame, as UIKit does; `velocity` (progress per second)
    /// replaces the current one when given.
    private func runProgress(to target: CGFloat, spring: NavigationTransitionSpring, velocity: CGFloat?, overshoots: Bool = true, completion: (() -> Void)?) {
        let driver: NavigationTransitionProgressDriver
        if let current = self.progressDriver {
            driver = current
        } else {
            driver = NavigationTransitionProgressDriver(value: self.progress, update: { [weak self] value in
                self?.updateProgress(value, transition: .immediate, completion: {})
            })
            self.progressDriver = driver
        }
        driver.animate(to: target, spring: spring, velocity: velocity, overshoots: overshoots, settled: completion)
    }

    var frameTiming: () -> (lastTargetTimestamp: Double?, frameDuration: Double) = {
        return (SharedDisplayLinkDriver.shared.lastTargetTimestamp, SharedDisplayLinkDriver.shared.frameDuration)
    }

    /// A dragging finger let go: the progress runs to `target` from where the drag has it now, at `velocity`, on the
    /// render server, beginning now.
    private func releaseProgress(to target: CGFloat, spring: NavigationTransitionSpring, velocity: CGFloat, completion: @escaping () -> Void) {
        if let driver = self.progressDriver {
            driver.displayLinkFrame(at: self.clock.now())
        }
        let curve = NavigationSpringCurve(from: self.progress, velocity: velocity, target: target, spring: spring, overshoots: false, rest: .progress)
        self.runProgressCurve(curve, continuing: true, completion: completion)
    }


    /// Runs the progress on `curve` on the render server: the screens, the dim, the shadow and the bars get keyframes
    /// sampled from it, and `completion` runs at its deadline. `continuing`: motion already on screen (a release, a
    /// retarget) goes on from now; otherwise it starts at the commit.
    private func runProgressCurve(_ curve: NavigationSpringCurve, continuing: Bool, completion: @escaping () -> Void) {
        self.progressDriver?.stop()
        self.progressDriver = nil
        self.curveCompletion = completion
        self.progressCurve = curve
        let timing = self.clock.start(duration: curve.restTime, continuing: continuing)
        self._progress = curve.target
        self.installProgressKeyframes(curve: curve, timing: timing)
    }

    /// Samples `curve` at `timing` and puts the keyframes on every layer that follows the progress; the model values are
    /// the last sample's.
    private func installProgressKeyframes(curve: NavigationSpringCurve, timing: NavigationKeyframeTiming) {
        let layouts = timing.sampleTimes.map { self.screenLayout(progress: curve.value(at: $0)) }
        guard let final = layouts.last else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.applyScreenLayout(final, transition: .immediate, completion: {}, updatesBars: false)
        CATransaction.commit()
        func add(_ layer: CALayer, _ keyPath: String, _ values: [Any]) {
            addNavigationKeyframes(to: layer, key: NavigationTransitionCoordinator.keyframeKeyPrefix + keyPath, keyPath: keyPath, values: values, timing: timing, owner: self.keyframeOwner)
        }
        func center(_ frame: CGRect) -> NSValue {
            return NSValue(cgPoint: CGPoint(x: frame.midX, y: frame.midY))
        }
        add(self.topNode.layer, "position", layouts.map { center($0.topFrame) })
        add(self.bottomNode.layer, "position", layouts.map { center($0.bottomFrame) })
        add(self.shadowNode.layer, "position", layouts.map { center($0.topFrame) })
        add(self.dimNode.layer, "position", layouts.map { center($0.dimFrame) })
        add(self.dimNode.layer, "bounds", layouts.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0.dimFrame.size)) })
        add(self.dimNode.layer, "opacity", layouts.map { NSNumber(value: Float($0.dimAlpha)) })
        let clock = self.clock
        let timeline = NavigationTransitionTimeline(
            timing: timing,
            fractions: layouts.map { $0.fraction },
            topFrames: layouts.map { $0.topFrame },
            bottomFrames: layouts.map { $0.bottomFrame },
            animationTime: { [weak clock] in
                return clock?.animationTime() ?? 0.0
            },
            reinstallTiming: { [weak clock] in
                return clock?.reinstallTiming
            },
            schedule: { [weak clock] time, action in
                clock?.schedule(atAnimationTime: time, action)
            }
        )
        self.navigationBarTransitionLayer?.animate(timeline: timeline)
        self.didStartProgressAnimation?(timeline)
    }

    private func removeProgressKeyframes() {
        for layer in self.progressLayers {
            for keyPath in NavigationTransitionCoordinator.progressKeyPaths {
                layer.removeAnimation(forKey: NavigationTransitionCoordinator.keyframeKeyPrefix + keyPath)
            }
        }
    }

    private func progressCurveEnded() {
        self.progressCurve = nil
        // At the group's own end its keyframes are already over; an end Core Animation forced (the clock's layer left
        // the screen with the container) would leave them playing on over the next layout.
        self.removeOwnedProgressKeyframes()
        let completion = self.curveCompletion
        self.curveCompletion = nil
        completion?()
    }

    /// How far `view` is drawn from its model frame now: a screen's model frame is its last keyframe's while the
    /// transition runs on the render server, so a hit test that must follow what is on screen (the swipe's restrictions)
    /// shifts by this.
    func presentedDisplacement(of view: UIView) -> CGPoint {
        guard self.progressCurve != nil, self.clock.isRunning else {
            return CGPoint()
        }
        let layout = self.screenLayout(progress: self.progress)
        if view === self.topNode.view {
            return CGPoint(x: layout.topFrame.minX - self.topNode.frame.minX, y: layout.topFrame.minY - self.topNode.frame.minY)
        } else if view === self.bottomNode.view {
            return CGPoint(x: layout.bottomFrame.minX - self.bottomNode.frame.minX, y: layout.bottomFrame.minY - self.bottomNode.frame.minY)
        }
        return CGPoint()
    }

    /// The container's size changed mid-transition (a rotation, a fold): the running keyframes go on, on their phase,
    /// for the new size.
    func containerSizeUpdated() {
        guard let curve = self.progressCurve, let timing = self.clock.reinstallTiming else {
            return
        }
        self.installProgressKeyframes(curve: curve, timing: timing)
    }


    /// While a swipe drags: the progress chases `target` (the translation over width) on UIKit's tracking spring rather
    /// than jumping to it. The swipe's springs stop at their target instead of overshooting it (a decision, 2026-10-14).
    func trackInteractiveProgress(_ target: CGFloat) {
        self.runningTarget = nil
        self.runProgress(to: target, spring: .tracking, velocity: nil, overshoots: false, completion: nil)
    }

    func complete() {
        self.clock.stop()
        self.progressCurve = nil
        self.curveCompletion = nil
        self.removeProgressKeyframes()
        self.progressDriver?.stop()
        self.runningTarget = nil
        self.animatingCompletion = true
        
        self._progress = 1.0
        
        self.dimNode.removeFromSupernode()
        self.shadowNode.removeFromSupernode()
        
        
        self.endNavigationBarTransition()
        
        self.restoreTopNodeCorners()
        
        if let currentCompletion = self.currentCompletion {
            self.currentCompletion = nil
            currentCompletion()
        }
    }
    
    func performCompletion(completion: @escaping () -> ()) {
        self.clock.stop()
        self.progressCurve = nil
        self.curveCompletion = nil
        self.removeProgressKeyframes()
        self.progressDriver?.stop()
        self.runningTarget = nil
        self.updateProgress(1.0, transition: .immediate, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.dimNode.removeFromSupernode()
                strongSelf.shadowNode.removeFromSupernode()
                
                
                strongSelf.endNavigationBarTransition()
                
                strongSelf.restoreTopNodeCorners()
                
                if let currentCompletion = strongSelf.currentCompletion {
                    strongSelf.currentCompletion = nil
                    currentCompletion()
                }
            }
            completion()
        })
    }
    
    func animateCompletion(_ velocity: CGFloat, completion: @escaping () -> ()) {
        self.animatingCompletion = true
        self.currentCompletion = completion
        self.runningTarget = 1.0
        let f = {
            self.dimNode.removeFromSupernode()
            self.shadowNode.removeFromSupernode()
            
            
            self.endNavigationBarTransition()
            
            self.restoreTopNodeCorners()
            
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
        
        if abs(velocity) < CGFloat.ulpOfOne && abs(self.progress) < CGFloat.ulpOfOne {
            // A tap push or pop: UIKit's critically damped spring, from rest, on the render server.
            self.runProgressCurve(NavigationSpringCurve(from: self.progress, target: 1.0, spring: .noninteractive, rest: .progress), continuing: false, completion: {
                f()
            })
        } else {
            // A released swipe: UIKit's interactive spring, starting at the finger's velocity (points per second here,
            // progress per second for the spring).
            self.navigationBarTransitionLayer?.endInteraction(towardTop: self.transition == .Push)
            self.releaseProgress(to: 1.0, spring: .interactive, velocity: velocity / max(1.0, self.container.bounds.size.width), completion: {
                f()
            })
        }
    }
    
    private func restoreTopNodeCorners() {
        for (node, parameters) in [(self.topNode, self.topNodeInitialParameters), (self.bottomNode, self.bottomNodeInitialParameters)] {
            guard let (clipsToBounds, cornerRadius, usesCornerRadii) = parameters else {
                continue
            }
            if #available(iOS 13.0, *) {
                node.layer.cornerCurve = .circular
            }
            if usesCornerRadii {
                node.layer.setCornerRadii(CornerRadii(uniform: cornerRadius))
            }
            node.clipsToBounds = clipsToBounds
            node.cornerRadius = cornerRadius
        }
        self.topNodeInitialParameters = nil
        self.bottomNodeInitialParameters = nil
    }
}
