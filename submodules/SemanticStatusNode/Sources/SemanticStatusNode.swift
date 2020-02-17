import Foundation
import UIKit
import AsyncDisplayKit
import Display

public enum SemanticStatusNodeState: Equatable {
    case none
    case download
    case play
    case pause
    case progress(value: CGFloat?, cancelEnabled: Bool)
    case customIcon(UIImage)
}

private protocol SemanticStatusNodeStateDrawingState: NSObjectProtocol {
    func draw(context: CGContext, size: CGSize, foregroundColor: UIColor)
}

private protocol SemanticStatusNodeStateContext: class {
    var isAnimating: Bool { get }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState
}

private enum SemanticStatusNodeIcon: Equatable {
    case none
    case download
    case play
    case pause
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

private final class SemanticStatusNodeIconContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let icon: SemanticStatusNodeIcon
        
        init(transitionFraction: CGFloat, icon: SemanticStatusNodeIcon) {
            self.transitionFraction = transitionFraction
            self.icon = icon
            
            super.init()
        }
        
        func draw(context: CGContext, size: CGSize, foregroundColor: UIColor) {
            context.saveGState()
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: max(0.01, self.transitionFraction), y: max(0.01, self.transitionFraction))
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            if foregroundColor.alpha.isZero {
                context.setBlendMode(.destinationOut)
                context.setFillColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
                context.setStrokeColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
            } else {
                context.setBlendMode(.normal)
                context.setFillColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
                context.setStrokeColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
            }
            
            switch self.icon {
            case .none:
                break
            case .play:
                let diameter = size.width
                
                let factor = diameter / 50.0
                
                let size = CGSize(width: 15.0, height: 18.0)
                context.translateBy(x: (diameter - size.width) / 2.0 + 1.5, y: (diameter - size.height) / 2.0)
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: factor, y: factor)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                context.fillPath()
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                context.translateBy(x: -(diameter - size.width) / 2.0 - 1.5, y: -(diameter - size.height) / 2.0)
            case .pause:
                let diameter = size.width
                
                let factor = diameter / 50.0
                
                let size = CGSize(width: 15.0, height: 16.0)
                context.translateBy(x: (diameter - size.width) / 2.0, y: (diameter - size.height) / 2.0)
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: factor, y: factor)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
                context.fillPath()
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                context.translateBy(x: -(diameter - size.width) / 2.0, y: -(diameter - size.height) / 2.0)
            case let .custom(image):
                let diameter = size.width
                
                let imageRect = CGRect(origin: CGPoint(x: floor((diameter - image.size.width) / 2.0), y: floor((diameter - image.size.height) / 2.0)), size: image.size)
                
                context.saveGState()
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                context.clip(to: imageRect, mask: image.cgImage!)
                context.fill(imageRect)
                context.restoreGState()
            case .download:
                let diameter = size.width
                let factor = diameter / 50.0
                let lineWidth: CGFloat = max(1.6, 2.25 * factor)
                
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                let arrowHeadSize: CGFloat = 15.0 * factor
                let arrowLength: CGFloat = 18.0 * factor
                let arrowHeadOffset: CGFloat = 1.0 * factor

                let leftPath = UIBezierPath()
                leftPath.lineWidth = lineWidth
                leftPath.lineCapStyle = .round
                leftPath.lineJoinStyle = .round
                leftPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
                leftPath.addLine(to: CGPoint(x: diameter / 2.0 - arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                leftPath.stroke()
                
                let rightPath = UIBezierPath()
                rightPath.lineWidth = lineWidth
                rightPath.lineCapStyle = .round
                rightPath.lineJoinStyle = .round
                rightPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
                rightPath.addLine(to: CGPoint(x: diameter / 2.0 + arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                rightPath.stroke()
                
                let bodyPath = UIBezierPath()
                bodyPath.lineWidth = lineWidth
                bodyPath.lineCapStyle = .round
                bodyPath.lineJoinStyle = .round
                bodyPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 - arrowLength / 2.0))
                bodyPath.addLine(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0))
                bodyPath.stroke()
            }
            context.restoreGState()
        }
    }
    
    let icon: SemanticStatusNodeIcon
    
    init(icon: SemanticStatusNodeIcon) {
        self.icon = icon
    }
    
    var isAnimating: Bool {
        return false
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        return DrawingState(transitionFraction: transitionFraction, icon: self.icon)
    }
}

private final class SemanticStatusNodeProgressTransition {
    let beginTime: Double
    let initialValue: CGFloat
    
    init(beginTime: Double, initialValue: CGFloat) {
        self.beginTime = beginTime
        self.initialValue = initialValue
    }
    
    func valueAt(timestamp: Double, actualValue: CGFloat) -> CGFloat {
        let duration = 0.2
        var t = CGFloat((timestamp - self.beginTime) / duration)
        t = min(1.0, max(0.0, t))
        return t * actualValue + (1.0 - t) * self.initialValue
    }
}

private final class SemanticStatusNodeProgressContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let value: CGFloat?
        let displayCancel: Bool
        let timestamp: Double
        
        init(transitionFraction: CGFloat, value: CGFloat?, displayCancel: Bool, timestamp: Double) {
            self.transitionFraction = transitionFraction
            self.value = value
            self.displayCancel = displayCancel
            self.timestamp = timestamp
            
            super.init()
        }
        
        func draw(context: CGContext, size: CGSize, foregroundColor: UIColor) {
            let diameter = size.width
            
            let factor = diameter / 50.0
            
            context.saveGState()
            
            if foregroundColor.alpha.isZero {
                context.setBlendMode(.destinationOut)
                context.setFillColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
                context.setStrokeColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
            } else {
                context.setBlendMode(.normal)
                context.setFillColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
                context.setStrokeColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
            }
            
            var progress = self.value ?? 0.1
            var startAngle = -CGFloat.pi / 2.0
            var endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            if progress > 1.0 {
                progress = 2.0 - progress
                let tmp = startAngle
                startAngle = endAngle
                endAngle = tmp
            }
            progress = min(1.0, progress)
            
            let lineWidth: CGFloat = max(1.6, 2.25 * factor)
            
            let pathDiameter: CGFloat
            pathDiameter = diameter - lineWidth - 2.5 * 2.0
            
            var angle = self.timestamp.truncatingRemainder(dividingBy: Double.pi * 2.0)
            angle *= 4.0
            
            context.translateBy(x: diameter / 2.0, y: diameter / 2.0)
            context.rotate(by: CGFloat(angle.truncatingRemainder(dividingBy: Double.pi * 2.0)))
            context.translateBy(x: -diameter / 2.0, y: -diameter / 2.0)
            
            let path = UIBezierPath(arcCenter: CGPoint(x: diameter / 2.0, y: diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
            
            context.restoreGState()
            
            if self.displayCancel {
                if foregroundColor.alpha.isZero {
                    context.setBlendMode(.destinationOut)
                    context.setFillColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
                    context.setStrokeColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
                } else {
                    context.setBlendMode(.normal)
                    context.setFillColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
                    context.setStrokeColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
                }
                
                context.saveGState()
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: max(0.01, self.transitionFraction), y: max(0.01, self.transitionFraction))
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                context.setLineWidth(max(1.3, 2.0 * factor))
                context.setLineCap(.round)
                
                let crossSize: CGFloat = 14.0 * factor
                context.move(to: CGPoint(x: diameter / 2.0 - crossSize / 2.0, y: diameter / 2.0 - crossSize / 2.0))
                context.addLine(to: CGPoint(x: diameter / 2.0 + crossSize / 2.0, y: diameter / 2.0 + crossSize / 2.0))
                context.strokePath()
                context.move(to: CGPoint(x: diameter / 2.0 + crossSize / 2.0, y: diameter / 2.0 - crossSize / 2.0))
                context.addLine(to: CGPoint(x: diameter / 2.0 - crossSize / 2.0, y: diameter / 2.0 + crossSize / 2.0))
                context.strokePath()
                
                context.restoreGState()
            }
        }
    }
    
    var value: CGFloat?
    let displayCancel: Bool
    var transition: SemanticStatusNodeProgressTransition?
    
    var isAnimating: Bool {
        return true
    }
    
    init(value: CGFloat?, displayCancel: Bool) {
        self.value = value
        self.displayCancel = displayCancel
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        let timestamp = CACurrentMediaTime()
        
        let resolvedValue: CGFloat?
        if let value = self.value {
            if let transition = self.transition {
                resolvedValue = transition.valueAt(timestamp: timestamp, actualValue: value)
            } else {
                resolvedValue = value
            }
        } else {
            resolvedValue = nil
        }
        return DrawingState(transitionFraction: transitionFraction, value: resolvedValue, displayCancel: self.displayCancel, timestamp: timestamp)
    }
    
    func updateValue(value: CGFloat?) {
        if value != self.value {
            let previousValue = value
            self.value = value
            let timestamp = CACurrentMediaTime()
            if let value = value, let previousValue = previousValue {
                if let transition = self.transition {
                    self.transition = SemanticStatusNodeProgressTransition(beginTime: timestamp, initialValue: transition.valueAt(timestamp: timestamp, actualValue: previousValue))
                } else {
                    self.transition = SemanticStatusNodeProgressTransition(beginTime: timestamp, initialValue: previousValue)
                }
            } else {
                self.transition = nil
            }
        }
    }
}

private extension SemanticStatusNodeState {
    func context(current: SemanticStatusNodeStateContext?) -> SemanticStatusNodeStateContext {
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
            default:
                preconditionFailure()
            }
            if let current = current as? SemanticStatusNodeIconContext, current.icon == icon {
                return current
            } else {
                return SemanticStatusNodeIconContext(icon: icon)
            }
        case let .progress(value, cancelEnabled):
            if let current = current as? SemanticStatusNodeProgressContext, current.displayCancel == cancelEnabled {
                current.updateValue(value: value)
                return current
            } else {
                return SemanticStatusNodeProgressContext(value: value, displayCancel: cancelEnabled)
            }
        }
    }
}

private final class SemanticStatusNodeTransitionDrawingState {
    let transition: CGFloat
    let drawingState: SemanticStatusNodeStateDrawingState
    
    init(transition: CGFloat, drawingState: SemanticStatusNodeStateDrawingState) {
        self.transition = transition
        self.drawingState = drawingState
    }
}

private final class SemanticStatusNodeDrawingState: NSObject {
    let background: UIColor
    let foreground: UIColor
    let transitionState: SemanticStatusNodeTransitionDrawingState?
    let drawingState: SemanticStatusNodeStateDrawingState
    
    init(background: UIColor, foreground: UIColor, transitionState: SemanticStatusNodeTransitionDrawingState?, drawingState: SemanticStatusNodeStateDrawingState) {
        self.background = background
        self.foreground = foreground
        self.transitionState = transitionState
        self.drawingState = drawingState
        
        super.init()
    }
}

private final class SemanticStatusNodeTransitionContext {
    let startTime: Double
    let duration: Double
    let previousStateContext: SemanticStatusNodeStateContext
    let completion: () -> Void
    
    init(startTime: Double, duration: Double, previousStateContext: SemanticStatusNodeStateContext, completion: @escaping () -> Void) {
        self.startTime = startTime
        self.duration = duration
        self.previousStateContext = previousStateContext
        self.completion = completion
    }
}

public final class SemanticStatusNode: ASControlNode {
    public var backgroundNodeColor: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    public var foregroundNodeColor: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    
    public private(set) var state: SemanticStatusNodeState
    private var transtionContext: SemanticStatusNodeTransitionContext?
    private var stateContext: SemanticStatusNodeStateContext
    
    public init(backgroundNodeColor: UIColor, foregroundNodeColor: UIColor) {
        self.backgroundNodeColor = backgroundNodeColor
        self.foregroundNodeColor = foregroundNodeColor
        self.state = .none
        self.stateContext = self.state.context(current: nil)
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        if let transtionContext = self.transtionContext {
            if transtionContext.startTime + transtionContext.duration < timestamp {
                self.transtionContext = nil
                transtionContext.completion()
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
    
    public func transitionToState(_ state: SemanticStatusNodeState, animated: Bool = true, synchronous: Bool = false, completion: @escaping () -> Void = {}) {
        var animated = animated
        if self.state != state {
            let fromState = self.state
            self.state = state
            let previousStateContext = self.stateContext
            self.stateContext = self.state.context(current: self.stateContext)
            
            if animated && previousStateContext !== self.stateContext {
                self.transtionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousStateContext: previousStateContext, completion: completion)
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
        if let transitionContext = self.transtionContext {
            let timestamp = CACurrentMediaTime()
            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
            t = min(1.0, max(0.0, t))
            transitionFraction = t
            transitionState = SemanticStatusNodeTransitionDrawingState(transition: t, drawingState: transitionContext.previousStateContext.drawingState(transitionFraction: 1.0 - t))
        }
        
        return SemanticStatusNodeDrawingState(background: self.backgroundNodeColor, foreground: self.foregroundNodeColor, transitionState: transitionState, drawingState: self.stateContext.drawingState(transitionFraction: transitionFraction))
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
        
        context.setFillColor(parameters.background.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: bounds.size))
        if let transitionState = parameters.transitionState {
            transitionState.drawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.foreground)
        }
        parameters.drawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.foreground)
    }
}
