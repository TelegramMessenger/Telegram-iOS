import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// The lens's resting selection, as UIKit's `_UITabSelectionView` draws it on iOS 27 (its `updateBackground` when the
/// platform metrics give no selection color, as the glass tab bar's do): the backdrop captured at a quarter of the
/// resolution, in a backdrop group of its own, blurred by 2 with normalized edges, then through a color matrix.
private final class RestingBackgroundView: UIVisualEffectView {
    var isDark: Bool?

    /// `_ColorMatrix.YCC(black:white:saturation:hue:).colorMatrix` (DesignLibrary), as `currentColorMatrixValue`
    /// builds it: light YCC(-0.2, 0.93, 1.2, 0), dark YCC(-0.07, 0.8, 1.2, 0), computed by calling DesignLibrary in
    /// the iOS 27 simulator.
    static func colorMatrix(isDark: Bool) -> [Float32] {
        if isDark {
            return [1.1298, -0.2361, -0.0237, 0.0, -0.07, -0.0701, 0.964, -0.0238, 0.0, -0.07, -0.0702, -0.236, 1.1762, 0.0, -0.07, 0.0, 0.0, 0.0, 1.0, 0.0]
        } else {
            return [1.1851, -0.0502, -0.005, 0.0, -0.2, -0.0149, 1.1499, -0.0051, 0.0, -0.2, -0.0149, -0.05, 1.1949, 0.0, -0.2, 0.0, 0.0, 0.0, 1.0, 0.0]
        }
    }

    init() {
        let effect = UIBlurEffect(style: .light)
        super.init(effect: effect)
        
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        self.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isDark: Bool) {
        if self.isDark == isDark {
            return
        }
        self.isDark = isDark
        
        if let sublayer = self.layer.sublayers?[0], let _ = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false

            if let blurFilter = CALayer.blur(), let colorMatrixFilter = CALayer.colorMatrix() {
                blurFilter.setValue(2.0 as NSNumber, forKey: "inputRadius")
                blurFilter.setValue(true as NSNumber, forKey: "inputNormalizeEdges")
                var matrix: [Float32] = RestingBackgroundView.colorMatrix(isDark: isDark)
                colorMatrixFilter.setValue(NSValue(bytes: &matrix, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
                sublayer.filters = [blurFilter, colorMatrixFilter]
                sublayer.setValue(0.25, forKey: "scale")
                sublayer.setValue("RestingBackgroundView-\(UInt(bitPattern: ObjectIdentifier(self)))", forKey: "groupName")
            }
        }
    }
}

/// `-[_UILiquidLensView _lifted]`, nil when the lens has no such method.
private func lensViewIsLifted(_ lensView: UIView) -> Bool? {
    let selector = NSSelectorFromString("_lifted")
    guard lensView.responds(to: selector), let method = lensView.method(for: selector) else {
        return nil
    }
    typealias ObjCMethod = @convention(c) (AnyObject, Selector) -> Bool
    let function = unsafeBitCast(method, to: ObjCMethod.self)
    return function(lensView, selector)
}

/// The duration and curve of a move animated with `animation`, as `CALayer.animate(from:to:keyPath:duration:delay:
/// curve:...)` draws it (`CALayer.makeAnimation` in Display): the part of the move done at a fraction of the duration.
/// `.spring` is a real spring only at Display's two native durations and a bezier otherwise.
private func lensMoveCurve(_ animation: ComponentTransition.Animation) -> (duration: Double, progress: (Double) -> CGFloat)? {
    guard case let .curve(duration, curve) = animation, duration > 0.0 else {
        return nil
    }
    switch curve {
    case .spring:
        var isSpringAnimation = duration == 0.5
        if #available(iOS 26.0, *), abs(duration - 0.3832) <= 0.0001 {
            isSpringAnimation = true
        }
        if isSpringAnimation {
            let spring = makeSpringAnimation("position", duration: duration)
            return (duration, { springAnimationValueAt(spring, CGFloat($0)) })
        } else {
            return (duration, { liquidLensBezierProgress(0.380, 0.700, 0.125, 1.000, $0) })
        }
    case .easeInOut:
        return (duration, { liquidLensBezierProgress(0.42, 0.0, 0.58, 1.0, $0) })
    case .easeIn:
        return (duration, { liquidLensBezierProgress(0.42, 0.0, 1.0, 1.0, $0) })
    case .linear:
        return (duration, { CGFloat($0) })
    case let .custom(c1x, c1y, c2x, c2y):
        return (duration, { liquidLensBezierProgress(Double(c1x), Double(c1y), Double(c2x), Double(c2y), $0) })
    case let .bounce(stiffness, damping):
        let spring = makeSpringBounceAnimation("position", 0.0, damping)
        spring.stiffness = stiffness
        return (duration, { springAnimationValueAt(spring, CGFloat($0)) })
    }
}

/// Keyframes a frame apart, played from `beginTime` at the speed Display plays its animations at.
private func makeLensKeyframeAnimation(keyPath: String, values: [Any], times: [Double], duration: Double, beginTime: Double, timeScale: Double) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = times.map { NSNumber(value: min(1.0, max(0.0, $0 / duration))) }
    animation.calculationMode = .linear
    animation.duration = duration
    animation.beginTime = beginTime
    animation.speed = Float(1.0 / timeScale)
    animation.fillMode = .both
    animation.isRemovedOnCompletion = true
    if #available(iOS 15.0, *) {
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        if maxFps > 61.0 {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: maxFps, preferred: maxFps)
        }
    }
    return animation
}

public final class LiquidLensView: UIView {
    public enum Kind {
        case externalContainer
        case builtinContainer
        case noContainer
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var cornerRadius: CGFloat?
        var selectionOrigin: CGPoint
        var selectionSize: CGSize
        var inset: CGFloat
        var liftedInset: CGFloat
        var isDark: Bool
        var isLifted: Bool
        var isCollapsed: Bool

        init(size: CGSize, cornerRadius: CGFloat?, selectionOrigin: CGPoint, selectionSize: CGSize, inset: CGFloat, liftedInset: CGFloat, isDark: Bool, isLifted: Bool, isCollapsed: Bool) {
            self.size = size
            self.cornerRadius = cornerRadius
            self.selectionOrigin = selectionOrigin
            self.selectionSize = selectionSize
            self.inset = inset
            self.liftedInset = liftedInset
            self.isLifted = isLifted
            self.isDark = isDark
            self.isCollapsed = isCollapsed
        }
    }

    private struct LensParams: Equatable {
        var baseFrame: CGRect
        var inset: CGFloat
        var liftedInset: CGFloat
        var isLifted: Bool

        init(baseFrame: CGRect, inset: CGFloat, liftedInset: CGFloat, isLifted: Bool) {
            self.baseFrame = baseFrame
            self.inset = inset
            self.liftedInset = liftedInset
            self.isLifted = isLifted
        }
    }

    private let containerView: UIView
    private let backgroundTintColor: GlassBackgroundView.TintColor
    private let backgroundContainer: GlassBackgroundContainerView?
    private let genericBackgroundContainer: UIView?
    private let backgroundView: GlassBackgroundView?
    private var lensView: UIView?
    private let liftedContainerView: UIView
    public let contentView: UIView
    private let restingBackgroundView: RestingBackgroundView
    /// Cuts `contentView` where the lens is, so that what lies under the glass shows only as the lens's lifted content.
    /// UIKit's own punch-out follows the lens layer's rect through a match-move animation, not the glass UIKit lays out
    /// inside the lens; this one gets the lens's own bounds and animations, so it stays on the glass however it moves.
    private let punchoutView: UIView
    /// UIKit puts its punch-out next to the lens's `overridePunchoutView`: this view, in a hidden container, where it
    /// cuts nothing.
    private let uikitPunchoutTargetView: UIView
    private let uikitPunchoutSinkView: UIView
    
    private var legacySelectionView: GlassBackgroundView.ContentImageView?
    private var legacyContentMaskView: UIView?
    private var legacyContentMaskBlobView: UIImageView?
    private var legacyLiftedContentBlobMaskView: UIImageView?

    public var selectedContentView: UIView {
        return self.liftedContainerView
    }

    /// `_UILiquidLensViewLargeVariantSpec` (the lens's style 1): how long a lens stays lifted at least, and the response
    /// of its lift and unlift springs (damping ratio 1).
    private static let lensHangTime: Double = 0.22
    private static let liftSpringResponse: Double = 0.25
    /// The finger's velocity is its displacement over the immediate updates of this long before the move starts; a
    /// longer window than one touch event, because events arrive in bursts after the main thread stalls.
    private static let immediateVelocityWindow: Double = 0.1
    private static let minImmediateVelocityInterval: Double = 0.03
    private static let maxCarriedSpeed: CGFloat = 3000.0

    private var params: Params?
    private var appliedLensParams: LensParams?

    /// Whether the UIKit lens is lifted: after an unlift is requested it stays lifted for the rest of its hang time.
    private var isLensLifted: Bool = false
    private var liftTimestamp: Double = 0.0
    private var unliftTimer: Foundation.Timer?
    private var pendingUnliftTransition: ComponentTransition?
    private var lensAnimationCount: Int = 0

    /// The lens's position and flex are worked out ahead (`LiquidLensMotionPlan`) and played as keyframe animations;
    /// a change replans from where the current plan is.
    private var isFlexActive: Bool = false
    private var lensSegment: LiquidLensPositionSegment?
    private var lensPlan: LiquidLensMotionPlan?
    private var isLensMoving: Bool = false
    private var lensMoveID: Int = 0
    /// The lens's recent immediate positions (the finger's), newest last.
    private var immediateLensPositions: [(time: Double, position: CGPoint)] = []

    public var selectionOrigin: CGPoint? {
        return self.params?.selectionOrigin
    }

    public var selectionSize: CGSize? {
        return self.params?.selectionSize
    }
    
    public private(set) var isAnimating: Bool = false {
        didSet {
            if self.isAnimating != oldValue {
                self.onUpdatedIsAnimating?(self.isAnimating)
            }
        }
    }
    public var onUpdatedIsAnimating: ((Bool) -> Void)?
    public var isLiftedAnimationCompleted: (() -> Void)?

    /// `backgroundTintColor` tints the glass behind the items, when the kind has one.
    public init(kind: Kind, backgroundTintColor: GlassBackgroundView.TintColor = GlassBackgroundView.TintColor(kind: .panel)) {
        self.containerView = UIView()
        self.backgroundTintColor = backgroundTintColor

        switch kind {
        case .builtinContainer:
            self.backgroundContainer = GlassBackgroundContainerView()
            self.genericBackgroundContainer = nil
        case .externalContainer, .noContainer:
            self.backgroundContainer = nil
            self.genericBackgroundContainer = UIView()
        }
        
        if case .noContainer = kind {
            self.backgroundView = nil
        } else {
            self.backgroundView = GlassBackgroundView()
        }
        
        self.contentView = UIView()
        self.liftedContainerView = UIView()

        self.restingBackgroundView = RestingBackgroundView()
        
        self.punchoutView = UIView()
        self.uikitPunchoutTargetView = UIView()
        self.uikitPunchoutSinkView = UIView()

        super.init(frame: CGRect())
        
        if let backgroundContainer = self.backgroundContainer {
            self.addSubview(backgroundContainer)
            if let backgroundView = self.backgroundView {
                backgroundContainer.contentView.addSubview(backgroundView)
                backgroundView.contentView.addSubview(self.containerView)
            }
        } else if let genericBackgroundContainer = self.genericBackgroundContainer {
            self.addSubview(genericBackgroundContainer)
            if let backgroundView = self.backgroundView {
                genericBackgroundContainer.addSubview(backgroundView)
                backgroundView.contentView.addSubview(self.containerView)
            } else {
                genericBackgroundContainer.addSubview(self.containerView)
            }
        }
        self.containerView.isUserInteractionEnabled = false
        
        if #available(iOS 26.0, *) {
            if let viewClass = NSClassFromString("_UILiquidLensView") as AnyObject as? NSObjectProtocol {
                let allocSelector = NSSelectorFromString("alloc")
                let initSelector = NSSelectorFromString("initWithRestingBackground:")
                let objcAlloc = viewClass.perform(allocSelector).takeUnretainedValue()
                let instance = objcAlloc.perform(initSelector, with: UIView()).takeUnretainedValue()
                self.lensView = instance as? UIView
            }
        }
        
        if let lensView = self.lensView {
            if let backgroundContainer = self.backgroundContainer {
                backgroundContainer.layer.zPosition = 1
            } else if let genericBackgroundContainer = self.genericBackgroundContainer{
                genericBackgroundContainer.layer.zPosition = 1
            }
            lensView.layer.zPosition = 10.0
            
            self.liftedContainerView.addSubview(self.restingBackgroundView)
            
            self.punchoutView.isUserInteractionEnabled = false
            self.punchoutView.backgroundColor = .black
            self.punchoutView.layer.compositingFilter = "destOut"
            
            self.uikitPunchoutSinkView.isHidden = true
            self.uikitPunchoutSinkView.isUserInteractionEnabled = false
            self.uikitPunchoutSinkView.addSubview(self.uikitPunchoutTargetView)
            
            self.containerView.addSubview(self.liftedContainerView)
            self.containerView.addSubview(lensView)
            self.containerView.addSubview(self.contentView)
            self.containerView.addSubview(self.punchoutView)
            self.containerView.addSubview(self.uikitPunchoutSinkView)
            
            if let backgroundContainer = self.backgroundContainer {
                lensView.perform(NSSelectorFromString("setLiftedContainerView:"), with: backgroundContainer.contentView)
            } else if let genericBackgroundContainer = self.genericBackgroundContainer {
                lensView.perform(NSSelectorFromString("setLiftedContainerView:"), with: genericBackgroundContainer)
            }
            lensView.perform(NSSelectorFromString("setLiftedContentView:"), with: self.liftedContainerView)
            lensView.perform(NSSelectorFromString("setOverridePunchoutView:"), with: self.uikitPunchoutTargetView)
            
            do {
                let selector = NSSelectorFromString("setLiftedContentMode:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setStyle:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Int32) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, 1)
                }
            }
            
            do {
                let selector = NSSelectorFromString("setWarpsContentBelow:")
                if let method = lensView.method(for: selector) {
                    typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let function = unsafeBitCast(method, to: ObjCMethod.self)
                    function(lensView, selector, true)
                }
            }

            // The lens's flex is `LiquidLensFlex`, planned with its position. UIKit's, which guesses the lens's motion by
            // sampling it, stays attached (the lens activates and deactivates it as it lifts) with nothing to flex from.
            if lensView.responds(to: NSSelectorFromString("flexInteraction")), let flexInteraction = lensView.value(forKey: "flexInteraction") as? NSObject, flexInteraction.responds(to: NSSelectorFromString("setPreferredFlexSources:")) {
                flexInteraction.setValue(0 as NSNumber, forKey: "preferredFlexSources")
            }
        } else {
            let legacySelectionView = GlassBackgroundView.ContentImageView()
            self.legacySelectionView = legacySelectionView
            if let backgroundView = self.backgroundView {
                backgroundView.contentView.insertSubview(legacySelectionView, at: 0)
            } else {
                self.containerView.insertSubview(legacySelectionView, at: 0)
            }
            
            let legacyContentMaskView = UIView()
            legacyContentMaskView.backgroundColor = .white
            self.legacyContentMaskView = legacyContentMaskView
            self.contentView.mask = legacyContentMaskView
            
            if let filter = CALayer.luminanceToAlpha() {
                legacyContentMaskView.layer.filters = [filter]
            }
            
            let legacyContentMaskBlobView = UIImageView()
            self.legacyContentMaskBlobView = legacyContentMaskBlobView
            legacyContentMaskView.addSubview(legacyContentMaskBlobView)
            
            self.containerView.addSubview(self.contentView)
            
            let legacyLiftedContentBlobMaskView = UIImageView()
            self.legacyLiftedContentBlobMaskView = legacyLiftedContentBlobMaskView
            self.liftedContainerView.mask = legacyLiftedContentBlobMaskView
            
            self.containerView.addSubview(self.liftedContainerView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.unliftTimer?.invalidate()
    }

    public func setLiftedContainer(view: UIView) {
        guard let lensView = self.lensView else {
            return
        }
        lensView.perform(NSSelectorFromString("setLiftedContainerView:"), with: view)
    }

    public func update(size: CGSize, cornerRadius: CGFloat? = nil, selectionOrigin: CGPoint, selectionSize: CGSize, inset: CGFloat, liftedInset: CGFloat = 4.0, isDark: Bool, isLifted: Bool, isCollapsed: Bool = false, transition: ComponentTransition) {
        let params = Params(size: size, cornerRadius: cornerRadius, selectionOrigin: selectionOrigin, selectionSize: selectionSize, inset: inset, liftedInset: liftedInset, isDark: isDark, isLifted: isLifted, isCollapsed: isCollapsed)
        if self.params == params {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func update(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        self.update(params: params, transition: transition)
    }

    private func lensBounds(params: LensParams, isLifted: Bool) -> CGRect {
        let inset: CGFloat = isLifted ? params.liftedInset : (-params.inset)
        return CGRect(origin: CGPoint(), size: CGSize(width: params.baseFrame.width + inset * 2.0, height: params.baseFrame.height + inset * 2.0))
    }

    /// The lens's size, and the punch-out's with it: inside a view animation, both animate along with the glass that
    /// UIKit lays out inside the lens.
    private func setLensBounds(_ bounds: CGRect) {
        guard let lensView = self.lensView else {
            return
        }
        lensView.bounds = bounds
        self.punchoutView.bounds = bounds
        self.punchoutView.layer.cornerRadius = min(bounds.width, bounds.height) * 0.5
    }

    private func updateLens(params: LensParams, transition: ComponentTransition) {
        guard self.lensView != nil else {
            return
        }
        self.appliedLensParams = params

        if params.isLifted {
            self.cancelPendingUnlift()
            if !self.isLensLifted {
                self.setLensLifted(true, params: params, transition: transition)
                return
            }
        } else if self.isLensLifted {
            // UIKit keeps a lens lifted for at least its hang time, so that a tap shows the lift. It is timed here
            // instead of by UIKit's own unlift timer, which would also hold back the lens's frame until it fires.
            let remainingHangTime = self.liftTimestamp + LiquidLensView.lensHangTime * UIView.animationDurationFactor() - CACurrentMediaTime()
            if !transition.animation.isImmediate && remainingHangTime > 0.0 {
                self.scheduleUnlift(after: remainingHangTime, transition: transition)
            } else {
                self.cancelPendingUnlift()
                self.setLensLifted(false, params: params, transition: transition)
                return
            }
        }
        self.moveLens(params: params, transition: transition)
    }

    /// UIKit animates the lens's material into and out of the lifted state; its size and position are animated here,
    /// with UIKit's lift spring for the size. UIKit's `alongsideAnimations` would run them inside its own spring, or,
    /// for an unlift within the hang time, only once its timer fires.
    private func setLensLifted(_ isLifted: Bool, params: LensParams, transition: ComponentTransition) {
        guard let lensView = self.lensView else {
            return
        }
        let animated = !transition.animation.isImmediate
        self.isLensLifted = isLifted
        var resetsMotion = false
        if isLifted {
            self.liftTimestamp = CACurrentMediaTime()
            if !self.isFlexActive {
                self.isFlexActive = true
                resetsMotion = true
            }
        }

        self.beginLensAnimation()
        let completion: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            // UIKit deactivates the lens's flex when the unlift completes.
            if !self.isLensLifted {
                self.setFlexActive(false)
            }
            self.endLensAnimation()
            self.isLiftedAnimationCompleted?()
        }
        let selector = NSSelectorFromString("setLifted:animated:alongsideAnimations:completion:")
        if lensViewIsLifted(lensView) != isLifted, let method = lensView.method(for: selector) {
            typealias ObjCMethod = @convention(c) (AnyObject, Selector, Bool, Bool, (@convention(block) () -> Void)?, (@convention(block) () -> Void)?) -> Void
            let function = unsafeBitCast(method, to: ObjCMethod.self)
            function(lensView, selector, isLifted, animated, nil, completion)
        } else {
            // Already in that state (UIKit unlifts a lens that leaves its window); UIKit would not call the completion.
            completion()
        }

        let lensBounds = self.lensBounds(params: params, isLifted: isLifted)
        if animated {
            // Inside a view animation the lens lays its glass out along with its bounds.
            if #available(iOS 17.0, *) {
                UIView.animate(springDuration: LiquidLensView.liftSpringResponse, bounce: 0.0, initialSpringVelocity: 0.0, delay: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                    self.setLensBounds(lensBounds)
                })
            } else {
                UIView.animate(withDuration: LiquidLensView.liftSpringResponse, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                    self.setLensBounds(lensBounds)
                })
            }
        } else {
            self.setLensBounds(lensBounds)
        }
        let resetsFlex = !animated && !isLifted
        if resetsFlex {
            self.isFlexActive = false
        }
        // The flex depends on the lens's size, so it is planned again also when the lens stays where it is.
        self.setLensPosition(CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY), transition: transition, replans: true, resetsMotion: resetsMotion, resetsFlex: resetsFlex)
        self.updateRestingBackgroundAlpha(transition: transition)
    }

    private func scheduleUnlift(after delay: Double, transition: ComponentTransition) {
        self.pendingUnliftTransition = transition
        if self.unliftTimer != nil {
            return
        }
        // A frame later than the hang time, so that UIKit, which measures it from its own lift timestamp, unlifts at once.
        let timer = Foundation.Timer(timeInterval: delay + 1.0 / 120.0, repeats: false, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.unliftTimer = nil
            let transition = self.pendingUnliftTransition ?? .spring(duration: 0.4)
            self.pendingUnliftTransition = nil
            guard let params = self.appliedLensParams, !params.isLifted, self.isLensLifted else {
                return
            }
            self.setLensLifted(false, params: params, transition: transition)
        })
        RunLoop.main.add(timer, forMode: .common)
        self.unliftTimer = timer
    }

    private func cancelPendingUnlift() {
        self.unliftTimer?.invalidate()
        self.unliftTimer = nil
        self.pendingUnliftTransition = nil
    }

    private func moveLens(params: LensParams, transition: ComponentTransition) {
        guard let lensView = self.lensView else {
            return
        }
        let lensBounds = self.lensBounds(params: params, isLifted: self.isLensLifted)
        let lensCenter = CGPoint(x: params.baseFrame.midX, y: params.baseFrame.midY)

        let previousBounds: CGRect = lensView.bounds
        if previousBounds != lensBounds {
            // The lens lays its glass out inside this animation, so the lens, its glass and the punch-out change size
            // together, centred on the lens's path. Snapping the lens's bounds instead left the glass growing from the
            // lens's left edge, off the path, while the punch-out took the new size at once.
            transition.animateView {
                self.setLensBounds(lensBounds)
            }
        }
        self.setLensPosition(lensCenter, transition: transition, replans: previousBounds != lensBounds)
    }

    private func beginLensAnimation() {
        self.lensAnimationCount += 1
        self.isAnimating = true
    }

    private func endLensAnimation() {
        self.lensAnimationCount = max(0, self.lensAnimationCount - 1)
        if self.lensAnimationCount == 0 {
            self.isAnimating = false
        }
    }

    /// A move counts as one lens animation, from its start until its segment ends or another replaces it.
    private func updateIsLensMoving(segment: LiquidLensPositionSegment, now: Double) {
        self.lensMoveID += 1
        if self.isLensMoving {
            self.isLensMoving = false
            self.endLensAnimation()
        }
        if segment.endTime > now {
            self.isLensMoving = true
            self.beginLensAnimation()
            let moveID = self.lensMoveID
            DispatchQueue.main.asyncAfter(deadline: .now() + (segment.endTime - now) * self.lensTimeScale(), execute: { [weak self] in
                guard let self, self.lensMoveID == moveID, self.isLensMoving else {
                    return
                }
                self.isLensMoving = false
                self.endLensAnimation()
            })
        }
    }

    /// The lens flexes from lift until its unlift completes, and then settles back.
    private func setFlexActive(_ isActive: Bool) {
        if self.isFlexActive == isActive {
            return
        }
        self.isFlexActive = isActive
        self.replanLens(now: self.lensTime(), resetsMotion: isActive)
    }

    /// Animation time scaled the way Display scales its animations' durations (slow animations in the simulator), in
    /// which the plans are made; Core Animation plays them at `1 / lensTimeScale()`.
    private func lensTimeScale() -> Double {
        return max(0.01, UIView.animationDurationFactor())
    }

    private func lensTime() -> Double {
        return CACurrentMediaTime() / self.lensTimeScale()
    }

    /// Moves the lens's glass to `center` from where it is now, along `transition`'s curve as `CALayer.animate` draws
    /// it, so that it stays in step with content animated with the same transition, and plans the flex of that move.
    /// An interrupted move continues from its current position (as a Core Animation `from: presentation` animation
    /// does) and the flex from its current state.
    private func setLensPosition(_ center: CGPoint, transition: ComponentTransition, replans: Bool, resetsMotion: Bool = false, resetsFlex: Bool = false) {
        guard let lensView = self.lensView else {
            return
        }
        let now = self.lensTime()
        var movesLens = false
        if self.lensSegment?.to != center {
            let current = self.lensSegment?.position(at: now) ?? lensView.center
            let segment: LiquidLensPositionSegment
            if let curve = lensMoveCurve(transition.animation), current != center {
                segment = LiquidLensPositionSegment(from: current, to: center, startTime: now, duration: curve.duration, progress: curve.progress, initialVelocity: self.lensVelocity(at: now))
                self.immediateLensPositions.removeAll()
            } else {
                segment = .resting(at: center, time: now)
                self.immediateLensPositions.append((now, center))
                self.immediateLensPositions.removeAll(where: { now - $0.time > LiquidLensView.immediateVelocityWindow })
            }
            self.lensSegment = segment
            UIView.performWithoutAnimation {
                lensView.center = center
                self.punchoutView.center = center
            }
            movesLens = true
            self.updateIsLensMoving(segment: segment, now: now)
        }
        if movesLens || replans {
            self.replanLens(now: now, resetsMotion: resetsMotion, resetsFlex: resetsFlex)
        }
    }

    /// How fast the lens moves at `time`: along its current move, or, right after it followed the finger (immediate
    /// updates), as fast as the finger moved it. A new move starts with this velocity.
    private func lensVelocity(at time: Double) -> CGPoint {
        var velocity = CGPoint()
        if let segment = self.lensSegment, time < segment.endTime {
            velocity = segment.velocity(at: time)
        } else {
            let recent = self.immediateLensPositions.filter { time - $0.time <= LiquidLensView.immediateVelocityWindow }
            if let first = recent.first, let last = recent.last, time - last.time <= LiquidLensView.immediateVelocityWindow * 0.5 {
                // Over at least a few frames, so that a lone jump (a relayout) or a burst of events is not a speed.
                let interval = max(last.time - first.time, LiquidLensView.minImmediateVelocityInterval)
                if recent.count > 1 {
                    velocity = CGPoint(x: (last.position.x - first.position.x) / CGFloat(interval), y: (last.position.y - first.position.y) / CGFloat(interval))
                }
            }
        }
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if speed > LiquidLensView.maxCarriedSpeed {
            velocity = CGPoint(x: velocity.x * LiquidLensView.maxCarriedSpeed / speed, y: velocity.y * LiquidLensView.maxCarriedSpeed / speed)
        }
        return velocity
    }

    private func replanLens(now: Double, resetsMotion: Bool = false, resetsFlex: Bool = false) {
        guard let lensView = self.lensView else {
            return
        }
        let segment = self.lensSegment ?? .resting(at: lensView.center, time: now)
        var start = self.lensPlan?.state(at: now) ?? LiquidLensMotionState(time: now)
        start.time = now
        if resetsMotion {
            start.motion = LiquidLensMotion()
        }
        if resetsFlex {
            start.animator.reset()
        }
        let plan = LiquidLensMotionPlan(start: start, segment: segment, isFlexActive: self.isFlexActive, size: lensView.bounds.size)
        self.lensPlan = plan

        let timeScale = self.lensTimeScale()
        let positionKeyframes = plan.positionKeyframes
        // The punch-out moves and flexes with the lens.
        for layer in [lensView.layer, self.punchoutView.layer] {
            let beginTime = layer.convertTime(plan.startTime * timeScale, from: nil)

            if positionKeyframes.count > 1, let duration = positionKeyframes.last?.time, duration > 0.0 {
                let animation = makeLensKeyframeAnimation(keyPath: "position", values: positionKeyframes.map { NSValue(cgPoint: $0.position) }, times: positionKeyframes.map { $0.time }, duration: duration, beginTime: beginTime, timeScale: timeScale)
                layer.add(animation, forKey: "liquidLensPosition")
            } else {
                layer.removeAnimation(forKey: "liquidLensPosition")
            }

            if plan.hasFlex, plan.endTime > plan.startTime {
                let animation = makeLensKeyframeAnimation(keyPath: "transform", values: plan.states.map { NSValue(caTransform3D: $0.animator.flex.transform) }, times: plan.states.map { $0.time - plan.startTime }, duration: plan.endTime - plan.startTime, beginTime: beginTime, timeScale: timeScale)
                layer.add(animation, forKey: "liquidLensFlex")
            } else {
                layer.removeAnimation(forKey: "liquidLensFlex")
            }
        }
    }

    private func update(params: Params, transition: ComponentTransition) {
        let isFirstTime = self.params == nil
        let transition: ComponentTransition = isFirstTime ? .immediate : transition

        self.params = params

        transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: params.size))

        if let backgroundContainer = self.backgroundContainer {
            transition.setFrame(view: backgroundContainer, frame: CGRect(origin: CGPoint(), size: params.size))
            backgroundContainer.update(size: params.size, isDark: params.isDark, transition: transition)
        } else if let genericBackgroundContainer = self.genericBackgroundContainer {
            transition.setFrame(view: genericBackgroundContainer, frame: CGRect(origin: CGPoint(), size: params.size))
        }
        
        if let backgroundView = self.backgroundView {
            transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
            backgroundView.update(size: params.size, cornerRadius: params.cornerRadius ?? (params.size.height * 0.5), isDark: params.isDark, tintColor: self.backgroundTintColor, isInteractive: true, transition: transition)
        }
        
        if self.contentView.bounds.size != params.size {
            self.contentView.clipsToBounds = true
            transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: params.size), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                self.contentView.clipsToBounds = false
            })
            transition.setCornerRadius(layer: self.contentView.layer, cornerRadius: params.cornerRadius ?? (params.size.height * 0.5))

            self.liftedContainerView.clipsToBounds = true
            transition.setFrame(view: self.liftedContainerView, frame: CGRect(origin: CGPoint(), size: params.size), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                self.liftedContainerView.clipsToBounds = false
            })
            transition.setCornerRadius(layer: self.liftedContainerView.layer, cornerRadius: params.cornerRadius ?? (params.size.height * 0.5))
        }

        
        let baseLensFrame = CGRect(origin: params.selectionOrigin, size: params.selectionSize)
        self.updateLens(params: LensParams(baseFrame: baseLensFrame, inset: params.inset, liftedInset: params.liftedInset, isLifted: params.isLifted), transition: transition)
        
        if let legacyContentMaskView = self.legacyContentMaskView {
            transition.setFrame(view: legacyContentMaskView, frame: CGRect(origin: CGPoint(), size: params.size))
        }
        if let legacyContentMaskBlobView = self.legacyContentMaskBlobView, let legacyLiftedContentBlobMaskView = self.legacyLiftedContentBlobMaskView, let legacySelectionView = self.legacySelectionView {
            let lensFrame = baseLensFrame.insetBy(dx: params.inset, dy: params.inset)
            let effectiveLensFrame = lensFrame.insetBy(dx: params.isLifted ? -2.0 : 0.0, dy: params.isLifted ? -2.0 : 0.0)
            
            if legacyContentMaskBlobView.image?.size.height != lensFrame.height {
                legacyContentMaskBlobView.image = generateStretchableFilledCircleImage(diameter: lensFrame.height, color: .black)
                legacyLiftedContentBlobMaskView.image = legacyContentMaskBlobView.image
                legacySelectionView.image = generateStretchableFilledCircleImage(diameter: lensFrame.height, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            transition.setFrame(view: legacyContentMaskBlobView, frame: effectiveLensFrame)
            transition.setFrame(view: legacyLiftedContentBlobMaskView, frame: effectiveLensFrame)
            
            legacySelectionView.tintColor = UIColor(white: params.isDark ? 1.0 : 0.0, alpha: params.isDark ? 0.1 : 0.075)
            transition.setFrame(view: legacySelectionView, frame: effectiveLensFrame)
            transition.setAlpha(view: legacySelectionView, alpha: params.isCollapsed ? 0.0 : 1.0)
        }

        transition.setFrame(view: self.restingBackgroundView, frame: CGRect(origin: CGPoint(), size: params.size))
        self.restingBackgroundView.update(isDark: params.isDark)
        self.updateRestingBackgroundAlpha(transition: transition)
    }

    /// The resting selection shows while the lens rests: hidden while it is lifted, which on iOS 26 and later lasts
    /// until the lens actually unlifts, after its hang time.
    private func updateRestingBackgroundAlpha(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        let isLifted = self.lensView != nil ? self.isLensLifted : params.isLifted
        transition.setAlpha(view: self.restingBackgroundView, alpha: (isLifted || params.isCollapsed) ? 0.0 : 1.0)
    }
}
