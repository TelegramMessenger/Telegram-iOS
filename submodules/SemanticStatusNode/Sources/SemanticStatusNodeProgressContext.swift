import Foundation
import UIKit
import Display

final class SemanticStatusNodeProgressTransition {
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

final class SemanticStatusNodeProgressContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let value: CGFloat?
        let displayCancel: Bool
        let appearance: SemanticStatusNodeState.ProgressAppearance?
        let animateRotation: Bool
        let timestamp: Double
        
        init(transitionFraction: CGFloat, value: CGFloat?, displayCancel: Bool, appearance: SemanticStatusNodeState.ProgressAppearance?, animateRotation: Bool, timestamp: Double) {
            self.transitionFraction = transitionFraction
            self.value = value
            self.displayCancel = displayCancel
            self.appearance = appearance
            self.animateRotation = animateRotation
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
                if !self.animateRotation {
                    progress = 1.0 - progress
                }
                
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
            
            if self.animateRotation {
                var angle = self.timestamp.truncatingRemainder(dividingBy: Double.pi * 2.0)
                angle *= 4.0
                
                context.translateBy(x: diameter / 2.0, y: diameter / 2.0)
                context.rotate(by: CGFloat(angle.truncatingRemainder(dividingBy: Double.pi * 2.0)))
                context.translateBy(x: -diameter / 2.0, y: -diameter / 2.0)
            }
            
            let path = UIBezierPath(arcCenter: CGPoint(x: diameter / 2.0, y: diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: self.animateRotation)
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
    let animateRotation: Bool
    var transition: SemanticStatusNodeProgressTransition?
    
    var isAnimating: Bool {
        return true
    }
    
    var requestUpdate: () -> Void = {}
    
    init(value: CGFloat?, displayCancel: Bool, appearance: SemanticStatusNodeState.ProgressAppearance?, animateRotation: Bool) {
        self.value = value
        self.displayCancel = displayCancel
        self.appearance = appearance
        self.animateRotation = animateRotation
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
        return DrawingState(transitionFraction: transitionFraction, value: resolvedValue, displayCancel: self.displayCancel, appearance: self.appearance, animateRotation: self.animateRotation, timestamp: timestamp)
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
