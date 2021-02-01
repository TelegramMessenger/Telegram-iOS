import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class ZoomWheelNodeDrawingState: NSObject {
    let transition: CGFloat
    let reverse: Bool
    
    init(transition: CGFloat, reverse: Bool) {
        self.transition = transition
        self.reverse = reverse
        
        super.init()
    }
}

final class ZoomWheelNode: ASDisplayNode {
    class State: Equatable {
        let active: Bool
        
        init(active: Bool) {
            self.active = active
        }
        
        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.active != rhs.active {
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
    private var state: State = State(active: false)
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
        var transitionFraction: CGFloat = self.state.active ? 1.0 : 0.0
        
        var reverse = false
        if let transitionContext = self.transitionContext {
            let timestamp = CACurrentMediaTime()
            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
            t = min(1.0, max(0.0, t))
            
            if transitionContext.previousState.active != self.state.active {
                transitionFraction = self.state.active ? t : 1.0 - t
                
                reverse = transitionContext.previousState.active
            }
        }
        
        return ZoomWheelNodeDrawingState(transition: transitionFraction, reverse: reverse)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? ZoomWheelNodeDrawingState else {
            return
        }

        let color = UIColor(rgb: 0xffffff)
        context.setFillColor(color.cgColor)
        
        let clearLineWidth: CGFloat = 4.0
        let lineWidth: CGFloat = 1.0 + UIScreenPixel
            
        context.scaleBy(x: 2.5, y: 2.5)
        
        context.translateBy(x: 4.0, y: 3.0)
        let _ = try? drawSvgPath(context, path: "M14,8.335 C14.36727,8.335 14.665,8.632731 14.665,9 C14.665,11.903515 12.48064,14.296846 9.665603,14.626311 L9.665,16 C9.665,16.367269 9.367269,16.665 9,16.665 C8.666119,16.665 8.389708,16.418942 8.34221,16.098269 L8.335,16 L8.3354,14.626428 C5.519879,14.297415 3.335,11.90386 3.335,9 C3.335,8.632731 3.632731,8.335 4,8.335 C4.367269,8.335 4.665,8.632731 4.665,9 C4.665,11.394154 6.605846,13.335 9,13.335 C11.39415,13.335 13.335,11.394154 13.335,9 C13.335,8.632731 13.63273,8.335 14,8.335 Z ")
        
        let _ = try? drawSvgPath(context, path: "M9,2.5 C10.38071,2.5 11.5,3.61929 11.5,5 L11.5,9 C11.5,10.380712 10.38071,11.5 9,11.5 C7.619288,11.5 6.5,10.380712 6.5,9 L6.5,5 C6.5,3.61929 7.619288,2.5 9,2.5 Z ")
            
        context.translateBy(x: -4.0, y: -3.0)
                
        if parameters.transition > 0.0 {
            let startPoint: CGPoint
            let endPoint: CGPoint
            
            let origin = CGPoint(x: 9.0, y: 10.0 - UIScreenPixel)
            let length: CGFloat = 17.0
    
            if parameters.reverse {
                startPoint = CGPoint(x: origin.x + length * (1.0 - parameters.transition), y: origin.y + length * (1.0 - parameters.transition))
                endPoint = CGPoint(x: origin.x + length, y: origin.y + length)
            } else {
                startPoint = origin
                endPoint = CGPoint(x: origin.x + length * parameters.transition, y: origin.y + length * parameters.transition)
            }
        
            context.setBlendMode(.clear)
            context.setLineWidth(clearLineWidth)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        
            context.setBlendMode(.normal)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }
}

private class ButtonNode: HighlightTrackingButtonNode {
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
        
    init() {
        self.backgroundNode = ASDisplayNode()
        self.textNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlight in
            if let strongSelf = self {
                
            }
        }
    }
    
    func update() {
        
    }
}

final class CameraZoomNode: ASDisplayNode {
    private let wheelNode: ZoomWheelNode
    
    private let backgroundNode: ASDisplayNode
    
    override init() {
        self.wheelNode = ZoomWheelNode()
        self.backgroundNode = ASDisplayNode()
        super.init()
        
        self.addSubnode(self.wheelNode)
    }
}
