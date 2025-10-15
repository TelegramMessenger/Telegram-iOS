import Foundation
import UIKit
import Display

final class SemanticStatusNodeCheckContext: SemanticStatusNodeStateContext {
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
