import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import RLottieBinding
import GZip
import AppBundle
import HierarchyTrackingLayer

public enum SemanticStatusNodeState: Equatable {
    public struct ProgressAppearance: Equatable {
        public var inset: CGFloat
        public var lineWidth: CGFloat
        
        public init(inset: CGFloat, lineWidth: CGFloat) {
            self.inset = inset
            self.lineWidth = lineWidth
        }
    }
    
    public struct CheckAppearance: Equatable {
        public var lineWidth: CGFloat
        
        public init(lineWidth: CGFloat) {
            self.lineWidth = lineWidth
        }
    }
    
    case none
    case download
    case play
    case pause
    case check(appearance: CheckAppearance?)
    case progress(value: CGFloat?, cancelEnabled: Bool, appearance: ProgressAppearance?, animateRotation: Bool)
    case secretTimeout(position: Double, duration: Double, generationTimestamp: Double, appearance: ProgressAppearance?)
    case customIcon(UIImage)
}

protocol SemanticStatusNodeStateDrawingState: NSObjectProtocol {
    func draw(context: CGContext, size: CGSize, foregroundColor: UIColor)
}

protocol SemanticStatusNodeStateContext: AnyObject {
    var isAnimating: Bool { get }
    var requestUpdate: () -> Void { get set }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState
}

enum SemanticStatusNodeIcon: Equatable {
    case none
    case download
    case play
    case pause
    case secretTimeout
    case custom(UIImage)
}

private func svgPath(_ path: StaticString, scale: CGPoint = CGPoint(x: 1.0, y: 1.0), offset: CGPoint = CGPoint()) throws -> UIBezierPath {
    var index: UnsafePointer<UInt8> = path.utf8Start
    let end = path.utf8Start.advanced(by: path.utf8CodeUnitCount)
    let path = UIBezierPath()
    while index < end {
        let c = index.pointee
        index = index.successor()
        
        if c == 77 { // M
            let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
            let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
            
            path.move(to: CGPoint(x: x, y: y))
        } else if c == 76 { // L
            let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
            let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
            
            path.addLine(to: CGPoint(x: x, y: y))
        } else if c == 67 { // C
            let x1 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
            let y1 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
            let x2 = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
            let y2 = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
            let x = try readCGFloat(&index, end: end, separator: 44) * scale.x + offset.x
            let y = try readCGFloat(&index, end: end, separator: 32) * scale.y + offset.y
            path.addCurve(to: CGPoint(x: x, y: y), controlPoint1: CGPoint(x: x1, y: y1), controlPoint2: CGPoint(x: x2, y: y2))
        } else if c == 32 { // space
            continue
        }
    }
    return path
}

private extension SemanticStatusNodeState {
    func context(current: SemanticStatusNodeStateContext?, animated: Bool) -> SemanticStatusNodeStateContext {
        switch self {
        case .none, .download, .play, .pause, .customIcon:
            let icon: SemanticStatusNodeIcon
            switch self {
            case .none:
                icon = .none
            case .download:
                icon = .download
            case .play:
                icon = .play
            case .pause:
                icon = .pause
            case let .customIcon(image):
                icon = .custom(image)
            case .secretTimeout:
                icon = .none
            default:
                preconditionFailure()
            }
            if let current = current as? SemanticStatusNodeIconContext {
                if current.icon == icon {
                    return current
                } else if (current.icon == .play && icon == .pause) || (current.icon == .pause && icon == .play) {
                    current.setIcon(icon: icon, animated: animated)
                    return current
                } else {
                    return SemanticStatusNodeIconContext(icon: icon)
                }
            } else {
                return SemanticStatusNodeIconContext(icon: icon)
            }
        case let .check(appearance):
            if let current = current as? SemanticStatusNodeCheckContext {
                return current
            } else {
                return SemanticStatusNodeCheckContext(value: 0.0, appearance: appearance)
            }
        case let .secretTimeout(position, duration, generationTimestamp, appearance):
            if let current = current as? SemanticStatusNodeSecretTimeoutContext {
                current.updateValue(position: position, duration: duration, generationTimestamp: generationTimestamp)
                return current
            } else {
                return SemanticStatusNodeSecretTimeoutContext(position: position, duration: duration, generationTimestamp: generationTimestamp, appearance: appearance)
            }
        case let .progress(value, cancelEnabled, appearance, animateRotation):
            if let current = current as? SemanticStatusNodeProgressContext, current.displayCancel == cancelEnabled {
                current.updateValue(value: value)
                return current
            } else {
                return SemanticStatusNodeProgressContext(value: value, displayCancel: cancelEnabled, appearance: appearance, animateRotation: animateRotation)
            }
        }
    }
}

private final class SemanticStatusNodeTransitionDrawingState {
    let transition: CGFloat
    let drawingState: SemanticStatusNodeStateDrawingState?
    let appearanceState: SemanticStatusNodeAppearanceDrawingState?
    
    init(transition: CGFloat, drawingState: SemanticStatusNodeStateDrawingState?, appearanceState: SemanticStatusNodeAppearanceDrawingState?) {
        self.transition = transition
        self.drawingState = drawingState
        self.appearanceState = appearanceState
    }
}

private final class SemanticStatusNodeAppearanceContext {
    let background: UIColor
    let foreground: UIColor
    let backgroundImage: UIImage?
    let overlayForeground: UIColor?
    let cutout: CGRect?
    
    init(background: UIColor, foreground: UIColor, backgroundImage: UIImage?, overlayForeground: UIColor?, cutout: CGRect?) {
        self.background = background
        self.foreground = foreground
        self.backgroundImage = backgroundImage
        self.overlayForeground = overlayForeground
        self.cutout = cutout
    }
    
    func drawingState(backgroundTransitionFraction: CGFloat, foregroundTransitionFraction: CGFloat) -> SemanticStatusNodeAppearanceDrawingState {
        return SemanticStatusNodeAppearanceDrawingState(backgroundTransitionFraction: backgroundTransitionFraction, foregroundTransitionFraction: foregroundTransitionFraction, background: self.background, foreground: self.foreground, backgroundImage: self.backgroundImage, overlayForeground: self.overlayForeground, cutout: self.cutout)
    }
    
    func withUpdatedBackground(_ background: UIColor) -> SemanticStatusNodeAppearanceContext {
        return SemanticStatusNodeAppearanceContext(background: background, foreground: self.foreground, backgroundImage: self.backgroundImage, overlayForeground: self.overlayForeground, cutout: cutout)
    }
    
    func withUpdatedForeground(_ foreground: UIColor) -> SemanticStatusNodeAppearanceContext {
        return SemanticStatusNodeAppearanceContext(background: self.background, foreground: foreground, backgroundImage: self.backgroundImage, overlayForeground: self.overlayForeground, cutout: cutout)
    }
    
    func withUpdatedBackgroundImage(_ backgroundImage: UIImage?) -> SemanticStatusNodeAppearanceContext {
        return SemanticStatusNodeAppearanceContext(background: self.background, foreground: self.foreground, backgroundImage: backgroundImage, overlayForeground: self.overlayForeground, cutout: cutout)
    }
    
    func withUpdatedOverlayForeground(_ overlayForeground: UIColor?) -> SemanticStatusNodeAppearanceContext {
        return SemanticStatusNodeAppearanceContext(background: self.background, foreground: self.foreground, backgroundImage: self.backgroundImage, overlayForeground: overlayForeground, cutout: cutout)
    }
    
    func withUpdatedCutout(_ cutout: CGRect?) -> SemanticStatusNodeAppearanceContext {
        return SemanticStatusNodeAppearanceContext(background: self.background, foreground: self.foreground, backgroundImage: self.backgroundImage, overlayForeground: self.overlayForeground, cutout: cutout)
    }
}

private final class SemanticStatusNodeAppearanceDrawingState {
    let backgroundTransitionFraction: CGFloat
    let foregroundTransitionFraction: CGFloat
    let background: UIColor
    let foreground: UIColor
    let backgroundImage: UIImage?
    let overlayForeground: UIColor?
    let cutout: CGRect?
    
    var effectiveForegroundColor: UIColor {
        if let _ = self.backgroundImage, let overlayForeground = self.overlayForeground {
            return overlayForeground
        } else {
            return self.foreground
        }
    }
    
    init(backgroundTransitionFraction: CGFloat, foregroundTransitionFraction: CGFloat, background: UIColor, foreground: UIColor, backgroundImage: UIImage?, overlayForeground: UIColor?, cutout: CGRect?) {
        self.backgroundTransitionFraction = backgroundTransitionFraction
        self.foregroundTransitionFraction = foregroundTransitionFraction
        self.background = background
        self.foreground = foreground
        self.backgroundImage = backgroundImage
        self.overlayForeground = overlayForeground
        self.cutout = cutout
    }
    
    func drawBackground(context: CGContext, size: CGSize) {
        let bounds = CGRect(origin: CGPoint(), size: size)
                
        context.setBlendMode(.normal)
        if let backgroundImage = self.backgroundImage?.cgImage {
            context.saveGState()
            context.translateBy(x: 0.0, y: bounds.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.setAlpha(self.backgroundTransitionFraction)
            context.draw(backgroundImage, in: bounds)
            context.restoreGState()
        } else {
            context.setFillColor(self.background.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: bounds.size))
        }
    }
    
    func drawForeground(context: CGContext, size: CGSize) {
        if let cutout = self.cutout {
            let size = CGSize(width: cutout.width * self.foregroundTransitionFraction, height: cutout.height * self.foregroundTransitionFraction)
            let rect = CGRect(origin: CGPoint(x: cutout.midX - size.width / 2.0, y: cutout.midY - size.height / 2.0), size: size)
            
            context.setBlendMode(.clear)
            context.fillEllipse(in: rect)
        }
    }
}

private final class SemanticStatusNodeDrawingState: NSObject {
    let transitionState: SemanticStatusNodeTransitionDrawingState?
    let drawingState: SemanticStatusNodeStateDrawingState
    let appearanceState: SemanticStatusNodeAppearanceDrawingState
    
    init(transitionState: SemanticStatusNodeTransitionDrawingState?, drawingState: SemanticStatusNodeStateDrawingState, appearanceState: SemanticStatusNodeAppearanceDrawingState) {
        self.transitionState = transitionState
        self.drawingState = drawingState
        self.appearanceState = appearanceState
        
        super.init()
    }
}

private final class SemanticStatusNodeTransitionContext {
    let startTime: Double
    let duration: Double
    let previousStateContext: SemanticStatusNodeStateContext?
    let previousAppearanceContext: SemanticStatusNodeAppearanceContext?
    let completion: () -> Void
    
    init(startTime: Double, duration: Double, previousStateContext: SemanticStatusNodeStateContext?, previousAppearanceContext: SemanticStatusNodeAppearanceContext?, completion: @escaping () -> Void) {
        self.startTime = startTime
        self.duration = duration
        self.previousStateContext = previousStateContext
        self.previousAppearanceContext = previousAppearanceContext
        self.completion = completion
    }
}

public final class SemanticStatusNode: ASControlNode {
    public var backgroundNodeColor: UIColor {
        get {
            return self.appearanceContext.background
        }
        set {
            if !self.appearanceContext.background.isEqual(newValue) {
                self.appearanceContext = self.appearanceContext.withUpdatedBackground(newValue)
                self.setNeedsDisplay()
            }
        }
    }
    
    public var foregroundNodeColor: UIColor {
        get {
            return self.appearanceContext.foreground
        }
        set {
            if !self.appearanceContext.foreground.isEqual(newValue) {
                self.appearanceContext = self.appearanceContext.withUpdatedForeground(newValue)
                self.setNeedsDisplay()
            }
        }
    }
    
    public var overlayForegroundNodeColor: UIColor? {
        get {
            return self.appearanceContext.overlayForeground
        }
        set {
            if !(self.appearanceContext.overlayForeground?.isEqual(newValue) ?? false) {
                self.appearanceContext = self.appearanceContext.withUpdatedOverlayForeground(newValue)
                self.setNeedsDisplay()
            }
        }
    }
    
    public var cutout: CGRect? {
        get {
            return self.appearanceContext.cutout
        }
        set {
            self.setCutout(newValue, animated: false)
        }
    }
    
    public func setCutout(_ cutout: CGRect?, animated: Bool) {
        guard cutout != self.appearanceContext.cutout else {
            return
        }
        if animated {
            self.transitionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.2, previousStateContext: nil, previousAppearanceContext: self.appearanceContext, completion: {})
            self.appearanceContext = self.appearanceContext.withUpdatedCutout(cutout)
            
            self.updateAnimations()
            self.setNeedsDisplay()
        } else {
            self.appearanceContext = self.appearanceContext.withUpdatedCutout(cutout)
            self.setNeedsDisplay()
        }
    }
    
    public func setBackgroundImage(_ image: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, size: CGSize) {
        let start = CACurrentMediaTime()
        let imageSignal: Signal<UIImage?, NoError> = image
        |> map { transform -> UIImage? in
            let context = transform(TransformImageArguments(corners: ImageCorners(radius: size.width / 2.0), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))
            return context?.generateImage()
        }
        self.disposable?.dispose()
        self.disposable = combineLatest(queue: Queue.mainQueue(), imageSignal, self.hasLayoutPromise.get()).startStrict(next: { [weak self] image, ready in
            guard let strongSelf = self, ready else {
                return
            }
            let previousAppearanceContext = strongSelf.appearanceContext
            strongSelf.appearanceContext = strongSelf.appearanceContext.withUpdatedBackgroundImage(image)
            
            if CACurrentMediaTime() - start > 0.3 {
                strongSelf.transitionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousStateContext: nil, previousAppearanceContext: previousAppearanceContext, completion: {})
                strongSelf.updateAnimations()
            }
            strongSelf.setNeedsDisplay()
        })
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    
    private var hasState: Bool = false
    public private(set) var state: SemanticStatusNodeState
    private var transitionContext: SemanticStatusNodeTransitionContext?
    private var stateContext: SemanticStatusNodeStateContext
    private var appearanceContext: SemanticStatusNodeAppearanceContext
    
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private var disposable: Disposable?
    private var backgroundNodeImage: UIImage?
    
    private let hasLayoutPromise = ValuePromise(false, ignoreRepeated: true)
    
    public override func layout() {
        super.layout()
        
        if !self.bounds.width.isZero {
            self.hasLayoutPromise.set(true)
        }
    }
    
    public init(backgroundNodeColor: UIColor, foregroundNodeColor: UIColor, image: Signal<(TransformImageArguments) -> DrawingContext?, NoError>? = nil, overlayForegroundNodeColor: UIColor? = nil, cutout: CGRect? = nil) {
        self.state = .none
        self.stateContext = self.state.context(current: nil, animated: false)
        self.appearanceContext = SemanticStatusNodeAppearanceContext(background: backgroundNodeColor, foreground: foregroundNodeColor, backgroundImage: nil, overlayForeground: overlayForegroundNodeColor, cutout: cutout)
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = false
        
        if let image {
            self.setBackgroundImage(image, size: CGSize(width: 44.0, height: 44.0))
        }
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        if let transitionContext = self.transitionContext {
            if transitionContext.startTime + transitionContext.duration < timestamp {
                self.transitionContext = nil
                transitionContext.completion()
            } else {
                animate = true
            }
        }
        if self.stateContext.isAnimating {
            animate = true
        }
        
        if animate {
            let animator: ConstantDisplayLinkAnimator
            if let current = self.animator {
                animator = current
            } else {
                animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimations()
                })
                self.animator = animator
            }
            animator.isPaused = false
        } else {
            self.animator?.isPaused = true
        }
        
        self.setNeedsDisplay()
    }
    
    public func transitionToState(_ state: SemanticStatusNodeState, animated: Bool = true, synchronous: Bool = false, cutout: CGRect? = nil, updateCutout: Bool = false, completion: @escaping () -> Void = {}) {
        var animated = animated
        if !self.hasState {
            self.hasState = true
            animated = false
        }
        if !self.hierarchyTrackingLayer.isInHierarchy {
            animated = false
        }
        if self.state != state || self.appearanceContext.cutout != cutout {
            self.state = state
            let previousStateContext = self.stateContext
            let previousAppearanceContext = updateCutout ? self.appearanceContext : nil
            
            self.stateContext = self.state.context(current: self.stateContext, animated: animated)
            self.stateContext.requestUpdate = { [weak self] in
                self?.setNeedsDisplay()
            }
            if updateCutout {
                self.appearanceContext = self.appearanceContext.withUpdatedCutout(cutout)
            }
            
            if animated && (previousStateContext !== self.stateContext || (updateCutout && previousAppearanceContext?.cutout != cutout)) {
                self.transitionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousStateContext: previousStateContext, previousAppearanceContext: previousAppearanceContext, completion: completion)
            } else {
                completion()
            }
            
            self.updateAnimations()
            self.setNeedsDisplay()
        } else {
            completion()
        }
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        var transitionState: SemanticStatusNodeTransitionDrawingState?
        var transitionFraction: CGFloat = 1.0
        var appearanceBackgroundTransitionFraction: CGFloat = 1.0
        var appearanceForegroundTransitionFraction: CGFloat = 1.0
        
        if let transitionContext = self.transitionContext {
            let timestamp = CACurrentMediaTime()
            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
            t = min(1.0, max(0.0, t))

            if let _ = transitionContext.previousStateContext {
                transitionFraction = t
            }
            var foregroundTransitionFraction: CGFloat = 1.0
            if let previousContext = transitionContext.previousAppearanceContext {
                if previousContext.backgroundImage != self.appearanceContext.backgroundImage {
                    appearanceBackgroundTransitionFraction = t
                }
                if previousContext.cutout != self.appearanceContext.cutout {
                    appearanceForegroundTransitionFraction = t
                    foregroundTransitionFraction = 1.0 - t
                }
            }
            transitionState = SemanticStatusNodeTransitionDrawingState(transition: t, drawingState: transitionContext.previousStateContext?.drawingState(transitionFraction: 1.0 - t), appearanceState: transitionContext.previousAppearanceContext?.drawingState(backgroundTransitionFraction: 1.0, foregroundTransitionFraction: foregroundTransitionFraction))
        }
        
        return SemanticStatusNodeDrawingState(transitionState: transitionState, drawingState: self.stateContext.drawingState(transitionFraction: transitionFraction), appearanceState: self.appearanceContext.drawingState(backgroundTransitionFraction: appearanceBackgroundTransitionFraction, foregroundTransitionFraction: appearanceForegroundTransitionFraction))
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? SemanticStatusNodeDrawingState else {
            return
        }
        
        if let transitionAppearanceState = parameters.transitionState?.appearanceState, transitionAppearanceState.background.alpha == 1.0 {
            transitionAppearanceState.drawBackground(context: context, size: bounds.size)
        }
        parameters.appearanceState.drawBackground(context: context, size: bounds.size)
        
        if let transitionDrawingState = parameters.transitionState?.drawingState {
            transitionDrawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.appearanceState.effectiveForegroundColor)
        }
        parameters.drawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.appearanceState.effectiveForegroundColor)

        if let transitionAppearanceState = parameters.transitionState?.appearanceState {
            transitionAppearanceState.drawForeground(context: context, size: bounds.size)
        }
        parameters.appearanceState.drawForeground(context: context, size: bounds.size)
    }
}
