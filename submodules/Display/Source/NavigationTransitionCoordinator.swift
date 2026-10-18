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

    /// The expand style's renderer; nil: the slide.
    private let expansion: NavigationExpansionRenderer?
    var isExpansion: Bool {
        return self.expansion != nil
    }
    /// Which windows the expansion's clock runs: the opening's for a push (kept when back reverses it), else the
    /// closing's.
    private var expansionIsOpening: Bool
    /// A swipe's card pose: under the finger, then released into the close.
    private var expansionPose: NavigationExpansionCardPose = .none
    private var releasedExpansionPose: NavigationExpansionCardPose?
    /// A caught expanding push: the expansion time its clock froze at.
    private var expansionFrozenTime: CGFloat?
    /// A caught expanding push whose bars still held the chat's capsules: they stay there through the drag.
    private var expansionCaughtBeforeBars = false
    /// The expansion time a released pose lets go from (1 for a swipe from the settled profile).
    private var releasedExpansionFrom: CGFloat = 1.0
    /// A caught push let go short: the pose springing back while the push runs on.
    private var springingBackPose: (pose: NavigationExpansionCardPose, weight: NavigationSpringCurve)?
    /// The bars' glass this transition left lingering above the bar it ended on.
    private weak var lingeringBarLayer: NavigationBarTransitionLayer?
    /// Whether a swipe has handed the bars' capsules to the lower screen.
    private var expansionBarShowsLower = false
    private var expansionEnded = false
    /// An expanding push's bars: their release toward the profile's capsules is scheduled at its window, and has run
    /// (or a reversal settled them on the chat's first).
    private var expansionBarMorphScheduled = false
    private var expansionBarMorphReleased = false

    /// The expansion's clock at a progress: a push runs it 0 → 1, a pop 1 → 0.
    func expansionTime(progress: CGFloat) -> CGFloat {
        return self.transition == .Push ? progress : 1.0 - progress
    }
    
    init(transition: NavigationTransition, isInteractive: Bool, isFlat: Bool, container: NavigationContainer, topNode: ASDisplayNode, topNavigationBar: NavigationBar?, topTransitionSource: NavigationBarTransitionSource?, bottomNode: ASDisplayNode, bottomNavigationBar: NavigationBar?, bottomTransitionSource: NavigationBarTransitionSource?, screenCornerRadii: CornerRadii, didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition, CGRect, CGRect) -> Void)? = nil, didStartProgressAnimation: ((NavigationTransitionTimeline) -> Void)? = nil, style: NavigationTransitionStyle = .slide) {
        self.transition = transition
        if case let .expand(renderer) = style {
            self.expansion = renderer
        } else {
            self.expansion = nil
        }
        self.expansionIsOpening = transition == .Push
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
        
        // An expansion's screens stay still; its renderer draws the card.
        if self.expansion == nil, !self.isFlat {
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
        if let expansion = self.expansion {
            expansion.view.frame = container.bounds
            container.view.insertSubview(expansion.view, aboveSubview: topNode.view)
            expansion.underView.frame = container.bounds
            container.view.insertSubview(expansion.underView, belowSubview: topNode.view)
            expansion.begin(topView: topNode.view, bottomView: bottomNode.view, size: container.bounds.size, time: self.expansionTime(progress: 0.0), isOpening: self.expansionIsOpening)
        }
        self.updateProgress(0.0, transition: .immediate, completion: {})
        // The bars take the screens' bars now and draw their glass from now on (the bars no longer draw it themselves).
        // An expanding push holds the chat's capsules as they are and releases them toward the profile's at its window
        // (`barGlassStart`, scheduled on the clock).
        if self.expansion != nil && self.transition == .Push {
            self.navigationBarTransitionLayer?.beginTransition(isInteractive: true, toTop: true)
        } else {
            self.expansionBarMorphScheduled = true
            self.expansionBarMorphReleased = true
            self.navigationBarTransitionLayer?.beginTransition(isInteractive: self.isInteractive, toTop: self.transition == .Push)
        }
        
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
        if let expansion = self.expansion, !self.expansionEnded {
            let atTop = (self.transition == .Push) == (self._progress >= 0.5)
            let end = {
                expansion.end(atTop: atTop)
                expansion.view.removeFromSuperview()
                expansion.underView.removeFromSuperview()
            }
            if Thread.isMainThread {
                end()
            } else {
                DispatchQueue.main.async(execute: end)
            }
        }
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

    /// A screen's frame as bounds and position, whatever transform it has.
    private func updateStill(node: ASDisplayNode, frame: CGRect, transition: ContainedViewLayoutTransition, completion: ((Bool) -> Void)? = nil) {
        transition.updateBounds(node: node, bounds: CGRect(origin: node.bounds.origin, size: frame.size))
        transition.updatePosition(node: node, position: CGPoint(x: frame.minX + frame.width * node.anchorPoint.x, y: frame.minY + frame.height * node.anchorPoint.y), completion: completion)
    }

    /// Where the screens, the dim and the bars are at `progress`.
    func screenLayout(progress: CGFloat) -> NavigationTransitionScreenLayout {
        if let expansion = self.expansion {
            let bounds = CGRect(origin: CGPoint(), size: self.container.bounds.size)
            return NavigationTransitionScreenLayout(topFrame: bounds, bottomFrame: bounds, dimFrame: bounds, dimAlpha: 0.0, fraction: expansion.barFraction(time: self.expansionTime(progress: progress), isOpening: self.expansionIsOpening))
        }
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
        let topCompletion: (Bool) -> Void = { _ in
            if canInvokeCompletion {
                completion()
            } else {
                hadEarlyCompletion = true
            }
        }
        if self.expansion != nil {
            // An expansion's screens stay where they are, and its renderer transforms the upper one into the swipe's
            // card: a frame set on a transformed view resizes it (UIKit defines frame only untransformed), so the
            // screens get their bounds and position.
            self.updateStill(node: self.bottomNode, frame: layout.bottomFrame, transition: transition)
            self.updateStill(node: self.topNode, frame: layout.topFrame, transition: transition, completion: topCompletion)
        } else {
            transition.updateFrame(node: self.topNode, frame: layout.topFrame, completion: topCompletion)
        }
        canInvokeCompletion = true
        transition.updateFrame(node: self.dimNode, frame: layout.dimFrame)
        transition.updateFrame(node: self.shadowNode, frame: layout.topFrame)
        if self.shadowNode.layer.shadowPath?.boundingBox.size != layout.topFrame.size {
            self.shadowNode.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: layout.topFrame.size), cornerRadius: self.cardCornerRadius).cgPath
        }
        transition.updateAlpha(node: self.dimNode, alpha: layout.dimAlpha)
        
        if self.expansion == nil {
            transition.updateFrame(node: self.bottomNode, frame: layout.bottomFrame)
        }
        
        if updatesBars {
            self.expansion?.update(time: self.expansionTime(progress: self.progress), isOpening: self.expansionIsOpening, pose: self.expansionPose)
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
        if let expansion = self.expansion {
            renderer.updateExclusions(bottom: expansion.barExclusions)
        }
        let layer = NavigationBarTransitionLayer(renderer: renderer, bottom: (bottomSource, bottomInfo, self.bottomNode.view), top: (topSource, topInfo, self.topNode.view), clipsToScreens: self.expansion == nil)
        layer.frame = self.container.bounds
        self.container.insertSubnode(layer, aboveSubnode: self.topNode)
        self.navigationBarTransitionLayer = layer
    }
    
    /// Ends the roles and returns both contents to their bars; runs before the transition's completion. Glass still
    /// animating stays above the bar the transition ended on until it settles (`lingering`), as UIKit's capsules
    /// outlive the screens' transition.
    func endNavigationBarTransition(lingering: Bool = true) {
        self.backHoleView?.removeFromSuperview()
        if let layer = self.navigationBarTransitionLayer {
            self.navigationBarTransitionLayer = nil
            if layer.putBack(lingering: lingering) {
                self.container.beginLingering(layer)
                self.lingeringBarLayer = layer
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
            strongSelf.endExpansion(finished: false)
            
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

    /// From this long after a transition starts running on its own (its start, a reversal, a swipe's release), touches
    /// reach the screen it is heading to (a decision, 2026-10-16).
    static let touchDelay: Double = 0.25
    /// When the progress last started running on its own; nil while a finger steers it.
    private var runningSince: Double?

    /// The stack has dropped the top screen of this transition, which runs on to the screen beneath (a swipe's commit,
    /// back mid-push): the screen beneath is the stack's top.
    var topLeftStack = false

    /// Whether touches may reach the screen the transition is heading to now. Not while a swipe's commit runs toward the
    /// screen beneath with its top still in the stack: a push from the screen beneath would stack on the leaving one.
    var acceptsTouches: Bool {
        guard let runningSince = self.runningSince else {
            return false
        }
        if self.isInteractive && self.headingNode === self.bottomNode && !self.topLeftStack {
            return false
        }
        return self.clock.now() - runningSince >= NavigationTransitionCoordinator.touchDelay
    }

    /// The screen the transition is heading to: the top screen of a push running on or a pop springing back, the screen
    /// beneath for a pop or a push turned back.
    var headingNode: ASDisplayNode {
        let target = self.runningTarget ?? self._progress
        let towardTop = self.transition == .Push ? target >= 0.5 : target < 0.5
        return towardTop ? self.topNode : self.bottomNode
    }

    /// Whether a swipe back can take this transition over now, as UIKit's interruptible transitions allow: only while it
    /// runs on its own toward the top screen (a tap push, a caught push let go toward its end, or a pop springing back
    /// after a cancelled swipe). A pop running to the screen beneath is not taken over; UIKit starts a second pop
    /// alongside it instead, which this container does not do (measured on the iOS 27 simulator, 2026-10-14).
    /// An expansion is caught only on its way open (a push): pops are never kept.
    var canBeCaughtBySwipe: Bool {
        guard let runningTarget = self.runningTarget else {
            return false
        }
        if self.expansion != nil {
            return self.transition == .Push && runningTarget == 1.0
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

    /// A swipe takes an expanding push mid-flight: its clock freezes at the expansion time it has now, and the finger's
    /// card pose carries the card from there (`trackExpansionPose`). The ending that was to run stays the ending if the
    /// transition is completed at once meanwhile (`performCompletion`).
    func catchExpansionBySwipe() {
        guard let expansion = self.expansion, let curve = self.progressCurve, self.clock.isRunning else {
            return
        }
        let value = curve.value(at: self.clock.animationTime())
        self.clock.stop()
        self.progressCurve = nil
        self.curveCompletion = nil
        self.removeProgressKeyframes()
        self.isInteractive = true
        self.animatingCompletion = false
        self.runningTarget = nil
        self.runningSince = nil
        self._progress = value
        // Caught again while running on after a short release: the pose that was springing back is the finger's now.
        self.springingBackPose = nil
        self.releasedExpansionPose = nil
        let time = self.expansionTime(progress: value)
        self.expansionFrozenTime = time
        if self.expansionBarMorphReleased {
            self.navigationBarTransitionLayer?.beginInteraction()
            self.expansionCaughtBeforeBars = false
            self.expansionBarShowsLower = false
        } else {
            // Before the bars' window: they hold the chat's capsules, and keep them until the release.
            self.expansionBarMorphReleased = true
            self.expansionCaughtBeforeBars = true
            self.expansionBarShowsLower = true
        }
        expansion.update(time: time, isOpening: self.expansionIsOpening, pose: .none)
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
        self.runningSince = self.clock.now()
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
        if let expansion = self.expansion {
            let times = timing.sampleTimes.map { self.expansionTime(progress: curve.value(at: $0)) }
            let poses = zip(timing.sampleTimes, times).map { sampleTime, time -> NavigationExpansionCardPose in
                if let springing = self.springingBackPose {
                    return springing.pose.released(springing.weight.value(at: sampleTime))
                }
                guard let released = self.releasedExpansionPose else {
                    return self.expansionPose
                }
                return released.released(NavigationExpansionCardPose.releasedWeight(time: time / max(self.releasedExpansionFrom, 0.0001)))
            }
            expansion.animate(timeline: NavigationExpansionTimeline(timing: timing, times: times, isOpening: self.expansionIsOpening, poses: poses, animationTime: timeline.animationTime, reinstallTiming: timeline.reinstallTiming, schedule: timeline.schedule))
            if !self.expansionBarMorphScheduled, let index = times.firstIndex(where: { $0 >= expansion.barGlassStart }) {
                self.expansionBarMorphScheduled = true
                timeline.schedule(timing.sampleTimes[index], { [weak self] in
                    guard let self, !self.expansionBarMorphReleased else {
                        return
                    }
                    self.expansionBarMorphReleased = true
                    self.navigationBarTransitionLayer?.endInteraction(towardTop: true)
                })
            }
        }
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
        guard self.expansion == nil, self.progressCurve != nil, self.clock.isRunning else {
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
        self.runningSince = nil
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
        self.endExpansion(finished: true)
        
        if let currentCompletion = self.currentCompletion {
            self.currentCompletion = nil
            currentCompletion()
        }
    }
    
    func performCompletion(completion: @escaping () -> ()) {
        // A transition lands where it is heading: back mid-push and a cancelled swipe head for 0, their endings kept in
        // `currentCompletion`; a finger holding it (no target) lands it at its end, as before.
        let target: CGFloat = self.runningTarget ?? 1.0
        self.clock.stop()
        self.progressCurve = nil
        self.curveCompletion = nil
        self.removeProgressKeyframes()
        self.progressDriver?.stop()
        self.runningTarget = nil
        self.updateProgress(target, transition: .immediate, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.dimNode.removeFromSupernode()
                strongSelf.shadowNode.removeFromSupernode()
                
                
                strongSelf.endNavigationBarTransition()
                
                strongSelf.restoreTopNodeCorners()
                if target < 0.5 && strongSelf.transition == .Pop {
                    // A cancelled pop: the screen beneath leaves, as the slide's cancel does.
                    strongSelf.bottomNode.removeFromSupernode()
                }
                strongSelf.endExpansion(finished: target >= 0.5)
                
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
            self.endExpansion(finished: true)
            
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
        
        if abs(velocity) < CGFloat.ulpOfOne && abs(self.progress) < CGFloat.ulpOfOne {
            // A tap push or pop: UIKit's critically damped spring, from rest, on the render server; an expansion's own
            // spring, overshooting (its landings live past 0 and 1).
            let spring: NavigationTransitionSpring
            let rest: NavigationSpringRest
            if let expansion = self.expansion {
                spring = self.transition == .Push ? expansion.openSpring : expansion.closeSpring
                rest = .expansion
            } else {
                spring = .noninteractive
                rest = .progress
            }
            self.runProgressCurve(NavigationSpringCurve(from: self.progress, target: 1.0, spring: spring, overshoots: true, rest: rest), continuing: false, completion: {
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
    
    /// A push running toward its top screen on its own can be turned back (back, at any moment).
    var canReverse: Bool {
        return self.transition == .Push && self.runningTarget == 1.0 && self.progressCurve != nil && self.clock.isRunning
    }

    /// Back mid-push: the push runs back to its start from where it is, at its speed — the slide on its tap spring, an
    /// expansion on its close spring in the opening's windows (changing windows mid-way would jump the colours). The
    /// push's own ending does not run; `completion` does, once the screen beneath is back.
    func reverse(completion: @escaping () -> Void) {
        guard self.canReverse, let running = self.progressCurve else {
            return
        }
        let now = self.clock.animationTime()
        let value = running.value(at: now)
        let velocity = running.velocity(at: now)
        self.clock.stop()
        self.progressCurve = nil
        self.curveCompletion = nil
        // Kept where `performCompletion` finds it: a size change or a new push lands the reversal, not the push.
        self.currentCompletion = completion
        self.runningTarget = 0.0
        self._progress = value
        if self.expansionBarMorphReleased {
            self.navigationBarTransitionLayer?.beginInteraction()
        } else {
            // Before the bars' window they still hold the chat's capsules: they settle there, and the window does nothing.
            self.expansionBarMorphReleased = true
        }
        self.navigationBarTransitionLayer?.endInteraction(towardTop: false)
        let curve: NavigationSpringCurve
        if let expansion = self.expansion {
            curve = NavigationSpringCurve(from: value, velocity: velocity, target: 0.0, spring: expansion.closeSpring, overshoots: true, rest: .expansion)
        } else {
            curve = NavigationSpringCurve(from: value, velocity: velocity, target: 0.0, spring: .noninteractive, overshoots: false, rest: .progress)
        }
        self.runProgressCurve(curve, continuing: true, completion: { [weak self] in
            guard let self else {
                return
            }
            self.dimNode.removeFromSupernode()
            self.shadowNode.removeFromSupernode()
            self.endNavigationBarTransition()
            self.restoreTopNodeCorners()
            self.endExpansion(finished: false)
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        })
    }

    /// The back-button hole while a push can be turned back: made on its first touch, in the container's view.
    private var backHoleView: UIView?
    /// Run when the back hole is tapped (the container pops through the screen's own back).
    var backTapped: (() -> Void)?

    /// During a push that can be turned back, the view a touch at `point` (in `view`) reaches on the incoming bar's back
    /// button: the hole, else nil. The button itself is drawn by the bars' transition, which takes no touches.
    func backHole(at point: CGPoint, in view: UIView) -> UIView? {
        guard self.canReverse else {
            return nil
        }
        let host = self.container.view
        let frame: CGRect?
        if let expansion = self.expansion {
            frame = expansion.backButtonFrame.map { expansion.view.convert($0, to: host) }
        } else if let barFrame = self.topTransitionSource?.backButtonFrame(in: host) {
            if self.navigationBarTransitionLayer == nil {
                // A bar outside the morph is drawn with its screen, ahead of the screen's model frame.
                let shift = self.presentedDisplacement(of: self.topNode.view)
                frame = barFrame.offsetBy(dx: shift.x, dy: shift.y)
            } else {
                frame = barFrame
            }
        } else {
            frame = nil
        }
        guard let frame, frame.contains(host.convert(point, from: view)) else {
            return nil
        }
        let hole: UIView
        if let current = self.backHoleView {
            hole = current
        } else {
            hole = UIView()
            // A layer that renders nothing gets no real touches on iOS 26/27 though -hitTest: returns it: transparent
            // contents (docs/ios27-windows-and-touches.md).
            hole.layer.contents = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
            })?.cgImage
            let target = NavigationExpansionBackHoleTarget(action: { [weak self] in
                self?.backTapped?()
            })
            self.backHoleTarget = target
            hole.addGestureRecognizer(UITapGestureRecognizer(target: target, action: #selector(NavigationExpansionBackHoleTarget.tapped)))
            self.backHoleView = hole
        }
        if hole.superview !== host {
            host.addSubview(hole)
        }
        hole.frame = frame
        return hole
    }

    private var backHoleTarget: NavigationExpansionBackHoleTarget?

    var expansionPoseForTesting: NavigationExpansionCardPose {
        return self.expansionPose
    }

    /// The finger moved the card: one frame, set directly; the bars follow its fade.
    func trackExpansionPose(_ pose: NavigationExpansionCardPose) {
        guard let expansion = self.expansion else {
            return
        }
        self.expansionPose = pose
        let width = self.container.bounds.width
        // The clock where it is: 1 for a swipe from the settled profile, frozen where a swipe caught a push.
        let time = self.expansionFrozenTime ?? 1.0
        expansion.update(time: time, isOpening: self.expansionIsOpening, pose: pose)
        let barFraction = self.expansionFrozenTime == nil ? 1.0 : expansion.barFraction(time: time, isOpening: self.expansionIsOpening)
        self.navigationBarTransitionLayer?.update(fraction: barFraction * (1.0 - pose.fade(width: width)), transition: .immediate)
        // Back takes the lower screen's look by the fade. The capsules run on their own springs (a dragging finger does
        // not move them), so they are handed over at the status bar's moment and handed back below it; caught before
        // the bars' window, they stay on the chat's.
        let showsLower = self.expansionCaughtBeforeBars || pose.fade(width: width) >= 0.3
        if showsLower != self.expansionBarShowsLower {
            self.expansionBarShowsLower = showsLower
            self.navigationBarTransitionLayer?.endInteraction(towardTop: !showsLower)
        }
        self.didUpdateProgress?(pose.fade(width: width), .immediate, self.topNode.frame, self.bottomNode.frame)
    }

    /// Released far enough: the close runs from the released pose, which lets go as the clock falls from where it was
    /// (1 from the settled profile, the frozen time of a caught push); a caught push turns back to the screen beneath.
    func commitExpansionPose(completion: @escaping () -> Void) {
        guard let expansion = self.expansion else {
            return
        }
        self.releasedExpansionPose = self.expansionPose
        self.releasedExpansionFrom = self.expansionFrozenTime ?? 1.0
        self.expansionPose = .none
        self.expansionFrozenTime = nil
        self.currentCompletion = completion
        let target: CGFloat = self.transition == .Push ? 0.0 : 1.0
        self.runningTarget = target
        self.navigationBarTransitionLayer?.endInteraction(towardTop: false)
        self.runProgressCurve(NavigationSpringCurve(from: self.progress, target: target, spring: expansion.closeSpring, overshoots: true, rest: .expansion), continuing: true, completion: { [weak self] in
            guard let self else {
                return
            }
            self.endNavigationBarTransition()
            if self.transition == .Push {
                // A push turned back by the swipe: the pushed screen leaves, as the slide's does.
                self.topNode.removeFromSupernode()
            }
            self.endExpansion(finished: self.transition == .Pop)
            self.restoreTopNodeCorners()
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        })
    }

    /// Released short: the pose springs back to rest (0.4 s, bounce 0.12) on the render server; the clock stays at 1.
    func cancelExpansionPose(completion: @escaping () -> Void) {
        guard let expansion = self.expansion else {
            return
        }
        if self.transition == .Push, self.expansionFrozenTime != nil {
            // A caught push let go short: it runs on to the profile from the frozen time on the open spring, the pose
            // springing back (0.4 s, bounce 0.12) in the same timeline.
            let weight = NavigationSpringCurve(from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.4, bounce: 0.12), overshoots: true, rest: .expansion)
            self.springingBackPose = (self.expansionPose, weight)
            self.expansionPose = .none
            self.expansionFrozenTime = nil
            self.runningTarget = 1.0
            self.currentCompletion = completion
            self.navigationBarTransitionLayer?.endInteraction(towardTop: true)
            self.runProgressCurve(NavigationSpringCurve(from: self.progress, target: 1.0, spring: expansion.openSpring, overshoots: true, rest: .expansion), continuing: true, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.springingBackPose = nil
                self.endNavigationBarTransition()
                self.restoreTopNodeCorners()
                self.endExpansion(finished: true)
                if let currentCompletion = self.currentCompletion {
                    self.currentCompletion = nil
                    currentCompletion()
                }
            })
            return
        }
        let pose = self.expansionPose
        let weight = NavigationSpringCurve(from: 1.0, target: 0.0, spring: NavigationTransitionSpring(duration: 0.4, bounce: 0.12), overshoots: true, rest: .expansion)
        self.expansionPose = .none
        // Heading back to the start of the pop; kept where `performCompletion` finds it.
        self.runningTarget = 0.0
        self.currentCompletion = completion
        self.navigationBarTransitionLayer?.endInteraction(towardTop: true)
        let timing = self.clock.start(duration: weight.restTime, continuing: true)
        self.runningSince = self.clock.now()
        let clock = self.clock
        expansion.animate(timeline: NavigationExpansionTimeline(timing: timing, times: timing.sampleTimes.map { _ in 1.0 }, isOpening: false, poses: timing.sampleTimes.map { pose.released(weight.value(at: $0)) }, animationTime: { [weak clock] in clock?.animationTime() ?? 0.0 }, reinstallTiming: { [weak clock] in clock?.reinstallTiming }, schedule: { [weak clock] time, action in clock?.schedule(atAnimationTime: time, action) }))
        self.curveCompletion = { [weak self] in
            guard let self else {
                return
            }
            self.runningTarget = nil
            self.endNavigationBarTransition()
            // The screen beneath leaves, as the slide's cancel does.
            self.bottomNode.removeFromSupernode()
            self.endExpansion(finished: false)
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
    }

    /// Ends the expansion once: its renderer returns what it lent and its views go. `finished`: the transition reached
    /// its end (a push on the top screen, a pop on the bottom one).
    private func endExpansion(finished: Bool) {
        guard let expansion = self.expansion, !self.expansionEnded else {
            return
        }
        self.expansionEnded = true
        let atTop = (self.transition == .Push) == finished
        let end = {
            expansion.end(atTop: atTop)
            expansion.view.removeFromSuperview()
            expansion.underView.removeFromSuperview()
        }
        // Ending on the chat while the bars' glass lingers above its bar: that glass leaves out what the expansion drew
        // (`barExclusions`) and the bar holds its own meanwhile, so the expansion stays, at rest, until the bar takes its
        // glass back, and ends in that same turn.
        if !atTop, let layer = self.lingeringBarLayer, layer.isLingering(above: self.bottomTransitionSource) {
            layer.addLingerHandover(end)
            return
        }
        end()
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

/// The back hole's tap target (a gesture recognizer needs an Objective-C object).
private final class NavigationExpansionBackHoleTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }

    @objc func tapped() {
        self.action()
    }
}
