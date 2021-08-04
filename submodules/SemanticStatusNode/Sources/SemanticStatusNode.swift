import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import RLottieBinding
import GZip
import AppBundle
import ManagedAnimationNode

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
    case progress(value: CGFloat?, cancelEnabled: Bool, appearance: ProgressAppearance?)
    case customIcon(UIImage)
}

private protocol SemanticStatusNodeStateDrawingState: NSObjectProtocol {
    func draw(context: CGContext, size: CGSize, foregroundColor: UIColor)
}

private protocol SemanticStatusNodeStateContext: AnyObject {
    var isAnimating: Bool { get }
    var requestUpdate: () -> Void { get set }
    
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
        let iconImage: UIImage?
        let iconOffset: CGFloat
        
        init(transitionFraction: CGFloat, icon: SemanticStatusNodeIcon, iconImage: UIImage?, iconOffset: CGFloat) {
            self.transitionFraction = transitionFraction
            self.icon = icon
            self.iconImage = iconImage
            self.iconOffset = iconOffset
            
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
               
                let size: CGSize
                var offset: CGFloat = 0.0
                if let iconImage = self.iconImage {
                    size = iconImage.size
                    offset = self.iconOffset
                } else {
                    offset = 1.5
                    size = CGSize(width: 15.0, height: 18.0)
                }
                context.translateBy(x: (diameter - size.width) / 2.0 + offset, y: (diameter - size.height) / 2.0)
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: factor, y: factor)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                if let iconImage = self.iconImage {
                    context.saveGState()
                    let iconRect = CGRect(origin: CGPoint(), size: iconImage.size)
                    context.clip(to: iconRect, mask: iconImage.cgImage!)
                    context.fill(iconRect)
                    context.restoreGState()
                } else {
                    let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                    context.fillPath()
                }
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                context.translateBy(x: -(diameter - size.width) / 2.0 - offset, y: -(diameter - size.height) / 2.0)
            case .pause:
                let diameter = size.width
                let factor = diameter / 50.0
                
                let size: CGSize
                let offset: CGFloat
                if let iconImage = self.iconImage {
                    size = iconImage.size
                    offset = self.iconOffset
                } else {
                    size = CGSize(width: 15.0, height: 16.0)
                    offset = 0.0
                }
                context.translateBy(x: (diameter - size.width) / 2.0 + offset, y: (diameter - size.height) / 2.0)
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: factor, y: factor)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                if let iconImage = self.iconImage {
                    context.saveGState()
                    let iconRect = CGRect(origin: CGPoint(), size: iconImage.size)
                    context.clip(to: iconRect, mask: iconImage.cgImage!)
                    context.fill(iconRect)
                    context.restoreGState()
                } else {
                    let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
                    context.fillPath()
                }
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
    
    var icon: SemanticStatusNodeIcon {
        didSet {
            self.animationNode?.enqueueState(self.icon == .play ? .play : .pause, animated: self.iconImage != nil)
        }
    }

    var animationNode: PlayPauseIconNode?
    var iconImage: UIImage?
    var iconOffset: CGFloat = 0.0
    
    init(icon: SemanticStatusNodeIcon) {
        self.icon = icon
        
        if [.play, .pause].contains(icon) {
            self.animationNode = PlayPauseIconNode()
            self.animationNode?.imageUpdated = { [weak self] image in
                if let strongSelf = self {
                    strongSelf.iconImage = image
                    if var position = strongSelf.animationNode?.state?.position {
                        position = position * 2.0
                        if position > 1.0 {
                            position = 2.0 - position
                        }
                        strongSelf.iconOffset = (1.0 - position) * 1.5
                    }
                    strongSelf.requestUpdate()
                }
            }
            self.animationNode?.enqueueState(self.icon == .play ? .play : .pause, animated: false)
            self.iconImage = self.animationNode?.image
            self.iconOffset = 1.5
        }
    }
    
    var isAnimating: Bool {
        return false
    }
    
    var requestUpdate: () -> Void = {}
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        return DrawingState(transitionFraction: transitionFraction, icon: self.icon, iconImage: self.iconImage, iconOffset: self.iconOffset)
    }
}

private final class SemanticStatusNodeProgressTransition {
    let beginTime: Double
    let initialValue: CGFloat
    
    init(beginTime: Double, initialValue: CGFloat) {
        self.beginTime = beginTime
        self.initialValue = initialValue
    }
    
    func valueAt(timestamp: Double, actualValue: CGFloat) -> (CGFloat, Bool) {
        let duration = 0.2
        var t = CGFloat((timestamp - self.beginTime) / duration)
        t = min(1.0, max(0.0, t))
        return (t * actualValue + (1.0 - t) * self.initialValue, t >= 1.0 - 0.001)
    }
}

private final class SemanticStatusNodeProgressContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let value: CGFloat?
        let displayCancel: Bool
        let appearance: SemanticStatusNodeState.ProgressAppearance?
        let timestamp: Double
        
        init(transitionFraction: CGFloat, value: CGFloat?, displayCancel: Bool, appearance: SemanticStatusNodeState.ProgressAppearance?, timestamp: Double) {
            self.transitionFraction = transitionFraction
            self.value = value
            self.displayCancel = displayCancel
            self.appearance = appearance
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
            
            var progress: CGFloat
            var startAngle: CGFloat
            var endAngle: CGFloat
            if let value = self.value {
                progress = value
                startAngle = -CGFloat.pi / 2.0
                endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
                
                if progress > 1.0 {
                    progress = 2.0 - progress
                    let tmp = startAngle
                    startAngle = endAngle
                    endAngle = tmp
                }
                progress = min(1.0, progress)
            } else {
                progress = CGFloat(1.0 + self.timestamp.remainder(dividingBy: 2.0))
                
                startAngle = -CGFloat.pi / 2.0
                endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
                
                if progress > 1.0 {
                    progress = 2.0 - progress
                    let tmp = startAngle
                    startAngle = endAngle
                    endAngle = tmp
                }
                progress = min(1.0, progress)
            }
            
            let lineWidth: CGFloat
            if let appearance = self.appearance {
                lineWidth = appearance.lineWidth
            } else {
                lineWidth = max(1.6, 2.25 * factor)
            }
            
            let pathDiameter: CGFloat
            if let appearance = self.appearance {
                pathDiameter = diameter - lineWidth - appearance.inset * 2.0
            } else {
                pathDiameter = diameter - lineWidth - 2.5 * 2.0
            }
            
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
    let appearance: SemanticStatusNodeState.ProgressAppearance?
    var transition: SemanticStatusNodeProgressTransition?
    
    var isAnimating: Bool {
        return true
    }
    
    var requestUpdate: () -> Void = {}
    
    init(value: CGFloat?, displayCancel: Bool, appearance: SemanticStatusNodeState.ProgressAppearance?) {
        self.value = value
        self.displayCancel = displayCancel
        self.appearance = appearance
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        let timestamp = CACurrentMediaTime()
        
        let resolvedValue: CGFloat?
        if let value = self.value {
            if let transition = self.transition {
                let (v, isCompleted) = transition.valueAt(timestamp: timestamp, actualValue: value)
                resolvedValue = v
                if isCompleted {
                    self.transition = nil
                }
            } else {
                resolvedValue = value
            }
        } else {
            resolvedValue = nil
        }
        return DrawingState(transitionFraction: transitionFraction, value: resolvedValue, displayCancel: self.displayCancel, appearance: self.appearance, timestamp: timestamp)
    }
    
    func maskView() -> UIView? {
        return nil
    }
    
    func updateValue(value: CGFloat?) {
        if value != self.value {
            let previousValue = self.value
            self.value = value
            let timestamp = CACurrentMediaTime()
            if let _ = value, let previousValue = previousValue {
                if let transition = self.transition {
                    self.transition = SemanticStatusNodeProgressTransition(beginTime: timestamp, initialValue: transition.valueAt(timestamp: timestamp, actualValue: previousValue).0)
                } else {
                    self.transition = SemanticStatusNodeProgressTransition(beginTime: timestamp, initialValue: previousValue)
                }
            } else {
                self.transition = nil
            }
        }
    }
}

private final class SemanticStatusNodeCheckContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let value: CGFloat
        let appearance: SemanticStatusNodeState.CheckAppearance?
        
        init(transitionFraction: CGFloat, value: CGFloat, appearance: SemanticStatusNodeState.CheckAppearance?) {
            self.transitionFraction = transitionFraction
            self.value = value
            self.appearance = appearance
            
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
            
            let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
            
            let lineWidth: CGFloat
            if let appearance = self.appearance {
                lineWidth = appearance.lineWidth
            } else {
                lineWidth = max(1.6, 2.25 * factor)
            }
        
            context.setLineWidth(max(1.7, lineWidth * factor))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setMiterLimit(10.0)
            
            let progress = self.value
            let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
            
            var s = CGPoint(x: center.x - 10.0 * factor, y: center.y + 1.0 * factor)
            var p1 = CGPoint(x: 7.0 * factor, y: 7.0 * factor)
            var p2 = CGPoint(x: 13.0 * factor, y: -15.0 * factor)
            
            if diameter < 36.0 {
                s = CGPoint(x: center.x - 7.0 * factor, y: center.y + 1.0 * factor)
                p1 = CGPoint(x: 4.5 * factor, y: 4.5 * factor)
                p2 = CGPoint(x: 10.0 * factor, y: -11.0 * factor)
            }
            
            if !firstSegment.isZero {
                if firstSegment < 1.0 {
                    context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                    context.addLine(to: s)
                } else {
                    let secondSegment = (progress - 0.33) * 1.5
                    context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                    context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                    context.addLine(to: s)
                }
            }
            context.strokePath()
        }
    }
    
    var value: CGFloat
    let appearance: SemanticStatusNodeState.CheckAppearance?
    var transition: SemanticStatusNodeProgressTransition?
    
    var isAnimating: Bool {
        return true
    }
    
    var requestUpdate: () -> Void = {}
    
    init(value: CGFloat, appearance: SemanticStatusNodeState.CheckAppearance?) {
        self.value = value
        self.appearance = appearance
        
        self.animate()
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        let timestamp = CACurrentMediaTime()
        
        let resolvedValue: CGFloat
        if let transition = self.transition {
            let (v, isCompleted) = transition.valueAt(timestamp: timestamp, actualValue: value)
            resolvedValue = v
            if isCompleted {
                self.transition = nil
            }
        } else {
            resolvedValue = value
        }
        return DrawingState(transitionFraction: transitionFraction, value: resolvedValue, appearance: self.appearance)
    }
    
    func maskView() -> UIView? {
        return nil
    }
    
    func animate() {
        guard self.value < 1.0 else {
            return
        }
        let timestamp = CACurrentMediaTime()
        self.value = 1.0
        self.transition = SemanticStatusNodeProgressTransition(beginTime: timestamp, initialValue: 0.0)
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
            if let current = current as? SemanticStatusNodeIconContext {
                if current.icon == icon {
                    return current
                } else if (current.icon == .play && icon == .pause) || (current.icon == .pause && icon == .play) {
                    current.icon = icon
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
        case let .progress(value, cancelEnabled, appearance):
            if let current = current as? SemanticStatusNodeProgressContext, current.displayCancel == cancelEnabled {
                current.updateValue(value: value)
                return current
            } else {
                return SemanticStatusNodeProgressContext(value: value, displayCancel: cancelEnabled, appearance: appearance)
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
    
    private var animator: ConstantDisplayLinkAnimator?
    
    private var hasState: Bool = false
    public private(set) var state: SemanticStatusNodeState
    private var transitionContext: SemanticStatusNodeTransitionContext?
    private var stateContext: SemanticStatusNodeStateContext
    private var appearanceContext: SemanticStatusNodeAppearanceContext
    
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
        self.stateContext = self.state.context(current: nil)
        self.appearanceContext = SemanticStatusNodeAppearanceContext(background: backgroundNodeColor, foreground: foregroundNodeColor, backgroundImage: nil, overlayForeground: overlayForegroundNodeColor, cutout: cutout)
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
        
        if let image = image {
            let start = CACurrentMediaTime()
            self.disposable = combineLatest(queue: Queue.mainQueue(), image, self.hasLayoutPromise.get()).start(next: { [weak self] transform, ready in
                guard let strongSelf = self, ready else {
                    return
                }
                let context = transform(TransformImageArguments(corners: ImageCorners(radius: strongSelf.bounds.width / 2.0), imageSize: strongSelf.bounds.size, boundingSize: strongSelf.bounds.size, intrinsicInsets: UIEdgeInsets()))
                
                let previousAppearanceContext = strongSelf.appearanceContext
                strongSelf.appearanceContext = strongSelf.appearanceContext.withUpdatedBackgroundImage(context?.generateImage())
                
                if CACurrentMediaTime() - start > 0.3 {
                    strongSelf.transitionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousStateContext: nil, previousAppearanceContext: previousAppearanceContext, completion: {})
                    strongSelf.updateAnimations()
                }
                strongSelf.setNeedsDisplay()
            })
        }
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
    
    public func transitionToState(_ state: SemanticStatusNodeState, animated: Bool = true, synchronous: Bool = false, completion: @escaping () -> Void = {}) {
        var animated = animated
        if !self.hasState {
            self.hasState = true
            animated = false
        }
        if self.state != state || self.appearanceContext.cutout != cutout {
            self.state = state
            let previousStateContext = self.stateContext
            self.stateContext = self.state.context(current: self.stateContext)
            self.stateContext.requestUpdate = { [weak self] in
                self?.setNeedsDisplay()
            }
            
            if animated && previousStateContext !== self.stateContext {
                self.transitionContext = SemanticStatusNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousStateContext: previousStateContext, previousAppearanceContext: nil, completion: completion)
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
        
        if let transitionAppearanceState = parameters.transitionState?.appearanceState {
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

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .play
    
    init() {
        super.init(size: CGSize(width: 36.0, height: 36.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}
