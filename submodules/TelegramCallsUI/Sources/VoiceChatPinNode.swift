import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let iconImage = generateTintedImage(image: UIImage(bundleImageName: "Call/Pin"), color: .white)

private final class VoiceChatPinNodeDrawingState: NSObject {
    let color: UIColor
    let transition: CGFloat
    let reverse: Bool
    
    init(color: UIColor, transition: CGFloat, reverse: Bool) {
        self.color = color
        self.transition = transition
        self.reverse = reverse
        
        super.init()
    }
}

final class VoiceChatPinNode: ASDisplayNode {
    class State: Equatable {
        let pinned: Bool
        let color: UIColor
    
        init(pinned: Bool, color: UIColor) {
            self.pinned = pinned
            self.color = color
        }
        
        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.pinned != rhs.pinned {
                return false
            }
            if lhs.color.argb != rhs.color.argb {
                return false
            }
            return true
        }
    }
    
    private class TransitionContext {
        let startTime: Double
        let duration: Double
        let previousState: State
        
        init(startTime: Double, duration: Double, previousState: State) {
            self.startTime = startTime
            self.duration = duration
            self.previousState = previousState
        }
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    
    private var hasState = false
    private var state: State = State(pinned: false, color: .black)
    private var transitionContext: TransitionContext?
    
    override init() {
        super.init()
        
        self.isOpaque = false
    }
    
    func update(state: State, animated: Bool) {
        var animated = animated
        if !self.hasState {
            self.hasState = true
            animated = false
        }
        
        if self.state != state {
            let previousState = self.state
            self.state = state
            
            if animated {
                self.transitionContext = TransitionContext(startTime: CACurrentMediaTime(), duration: 0.18, previousState: previousState)
            }
            
            self.updateAnimations()
            self.setNeedsDisplay()
        }
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        if let transitionContext = self.transitionContext {
            if transitionContext.startTime + transitionContext.duration < timestamp {
                self.transitionContext = nil
            } else {
                animate = true
            }
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
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        var transitionFraction: CGFloat = self.state.pinned ? 1.0 : 0.0
        var color = self.state.color
        
        var reverse = false
        if let transitionContext = self.transitionContext {
            let timestamp = CACurrentMediaTime()
            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
            t = min(1.0, max(0.0, t))
            
            if transitionContext.previousState.pinned != self.state.pinned {
                transitionFraction = self.state.pinned ? t : 1.0 - t
                
                reverse = transitionContext.previousState.pinned
            }
            
            if transitionContext.previousState.color.rgb != color.rgb {
                color = transitionContext.previousState.color.interpolateTo(color, fraction: t)!
            }
        }
        
        return VoiceChatPinNodeDrawingState(color: color, transition: transitionFraction, reverse: reverse)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? VoiceChatPinNodeDrawingState else {
            return
        }

        context.setFillColor(parameters.color.cgColor)
        
        let clearLineWidth: CGFloat = 2.0
        let lineWidth: CGFloat = 1.0 + UIScreenPixel
        if let iconImage = iconImage?.cgImage {
            context.saveGState()
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            context.draw(iconImage, in: CGRect(origin: CGPoint(), size: CGSize(width: 48.0, height: 48.0)))
            context.restoreGState()
        }
        
        if parameters.transition > 0.0 {
            let startPoint: CGPoint
            let endPoint: CGPoint
            
            let origin = CGPoint(x: 14.0, y: 16.0 - UIScreenPixel)
            let length: CGFloat = 17.0
        
            if parameters.reverse {
                startPoint = CGPoint(x: origin.x + length * (1.0 - parameters.transition), y: origin.y + length * (1.0 - parameters.transition)).offsetBy(dx: UIScreenPixel, dy: -UIScreenPixel)
                endPoint = CGPoint(x: origin.x + length, y: origin.y + length).offsetBy(dx: UIScreenPixel, dy: -UIScreenPixel)
            } else {
                startPoint = origin.offsetBy(dx: UIScreenPixel, dy: -UIScreenPixel)
                endPoint = CGPoint(x: origin.x + length * parameters.transition, y: origin.y + length * parameters.transition).offsetBy(dx: UIScreenPixel, dy: -UIScreenPixel)
            }
            
        
            context.setBlendMode(.clear)
            context.setLineWidth(clearLineWidth)
            
            context.move(to: startPoint.offsetBy(dx: 0.0, dy: 1.0 + UIScreenPixel))
            context.addLine(to: endPoint.offsetBy(dx: 0.0, dy: 1.0 + UIScreenPixel))
            context.strokePath()
        
            context.setBlendMode(.normal)
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }
}
