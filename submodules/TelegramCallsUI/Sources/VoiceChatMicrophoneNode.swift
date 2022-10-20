import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class VoiceChatMicrophoneNodeDrawingState: NSObject {
    let color: UIColor
    let filled: Bool
    let transition: CGFloat
    let reverse: Bool
    
    init(color: UIColor, filled: Bool, transition: CGFloat, reverse: Bool) {
        self.color = color
        self.filled = filled
        self.transition = transition
        self.reverse = reverse
        
        super.init()
    }
}

final class VoiceChatMicrophoneNode: ASDisplayNode {
    class State: Equatable {
        let muted: Bool
        let color: UIColor
        let filled: Bool
        
        init(muted: Bool, filled: Bool, color: UIColor) {
            self.muted = muted
            self.filled = filled
            self.color = color
        }
        
        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.muted != rhs.muted {
                return false
            }
            if lhs.color.argb != rhs.color.argb {
                return false
            }
            if lhs.filled != rhs.filled {
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
    private var state: State = State(muted: false, filled: false, color: .black)
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
        var transitionFraction: CGFloat = self.state.muted ? 1.0 : 0.0
        var color = self.state.color
        
        var reverse = false
        if let transitionContext = self.transitionContext {
            let timestamp = CACurrentMediaTime()
            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
            t = min(1.0, max(0.0, t))
            
            if transitionContext.previousState.muted != self.state.muted {
                transitionFraction = self.state.muted ? t : 1.0 - t
                
                reverse = transitionContext.previousState.muted
            }
            
            if transitionContext.previousState.color.rgb != color.rgb {
                color = transitionContext.previousState.color.interpolateTo(color, fraction: t)!
            }
        }
        
        return VoiceChatMicrophoneNodeDrawingState(color: color, filled: self.state.filled, transition: transitionFraction, reverse: reverse)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? VoiceChatMicrophoneNodeDrawingState else {
            return
        }

        context.setFillColor(parameters.color.cgColor)
        
        var clearLineWidth: CGFloat = 2.0
        var lineWidth: CGFloat = 1.0 + UIScreenPixel
        if bounds.size.width > 36.0 {
            context.scaleBy(x: 2.0, y: 2.0)
        } else if bounds.size.width < 30.0 {
            clearLineWidth = 2.0
            lineWidth = 1.0
        }
        
        if bounds.width < 30.0 {
            context.translateBy(x: 4.0, y: 3.0)
            let _ = try? drawSvgPath(context, path: "M14,8.335 C14.36727,8.335 14.665,8.632731 14.665,9 C14.665,11.903515 12.48064,14.296846 9.665603,14.626311 L9.665,16 C9.665,16.367269 9.367269,16.665 9,16.665 C8.666119,16.665 8.389708,16.418942 8.34221,16.098269 L8.335,16 L8.3354,14.626428 C5.519879,14.297415 3.335,11.90386 3.335,9 C3.335,8.632731 3.632731,8.335 4,8.335 C4.367269,8.335 4.665,8.632731 4.665,9 C4.665,11.394154 6.605846,13.335 9,13.335 C11.39415,13.335 13.335,11.394154 13.335,9 C13.335,8.632731 13.63273,8.335 14,8.335 Z ")
        } else {
            context.translateBy(x: 17.0, y: 18.0)
            let _ = try? drawSvgPath(context, path: "M-0.004000000189989805,-9.86400032043457 C2.2960000038146973,-9.86400032043457 4.165999889373779,-8.053999900817871 4.25600004196167,-5.77400016784668 C4.25600004196167,-5.77400016784668 4.265999794006348,-5.604000091552734 4.265999794006348,-5.604000091552734 C4.265999794006348,-5.604000091552734 4.265999794006348,-0.8040000200271606 4.265999794006348,-0.8040000200271606 C4.265999794006348,1.555999994277954 2.3559999465942383,3.4660000801086426 -0.004000000189989805,3.4660000801086426 C-2.2939999103546143,3.4660000801086426 -4.164000034332275,1.6460000276565552 -4.263999938964844,-0.6240000128746033 C-4.263999938964844,-0.6240000128746033 -4.263999938964844,-0.8040000200271606 -4.263999938964844,-0.8040000200271606 C-4.263999938964844,-0.8040000200271606 -4.263999938964844,-5.604000091552734 -4.263999938964844,-5.604000091552734 C-4.263999938964844,-7.953999996185303 -2.3540000915527344,-9.86400032043457 -0.004000000189989805,-9.86400032043457 Z ")
        }
        if bounds.width > 30.0 && !parameters.filled {
            context.setBlendMode(.clear)
        
            let _ = try? drawSvgPath(context, path: "M0.004000000189989805,-8.53600025177002 C-1.565999984741211,-8.53600025177002 -2.8459999561309814,-7.306000232696533 -2.936000108718872,-5.75600004196167 C-2.936000108718872,-5.75600004196167 -2.936000108718872,-5.5960001945495605 -2.936000108718872,-5.5960001945495605 C-2.936000108718872,-5.5960001945495605 -2.936000108718872,-0.7960000038146973 -2.936000108718872,-0.7960000038146973 C-2.936000108718872,0.8240000009536743 -1.6260000467300415,2.134000062942505 0.004000000189989805,2.134000062942505 C1.5740000009536743,2.134000062942505 2.8540000915527344,0.9039999842643738 2.934000015258789,-0.6460000276565552 C2.934000015258789,-0.6460000276565552 2.934000015258789,-0.7960000038146973 2.934000015258789,-0.7960000038146973 C2.934000015258789,-0.7960000038146973 2.934000015258789,-5.5960001945495605 2.934000015258789,-5.5960001945495605 C2.934000015258789,-7.22599983215332 1.6239999532699585,-8.53600025177002 0.004000000189989805,-8.53600025177002 Z ")
            
            context.setBlendMode(.normal)
        }
        
        if bounds.width < 30.0 {
            let _ = try? drawSvgPath(context, path: "M9,2.5 C10.38071,2.5 11.5,3.61929 11.5,5 L11.5,9 C11.5,10.380712 10.38071,11.5 9,11.5 C7.619288,11.5 6.5,10.380712 6.5,9 L6.5,5 C6.5,3.61929 7.619288,2.5 9,2.5 Z ")
            
            context.translateBy(x: -4.0, y: -3.0)
        } else {
            let _ = try? drawSvgPath(context, path: "M6.796000003814697,-1.4639999866485596 C7.165999889373779,-1.4639999866485596 7.466000080108643,-1.1640000343322754 7.466000080108643,-0.8040000200271606 C7.466000080108643,3.0959999561309814 4.47599983215332,6.296000003814697 0.6660000085830688,6.636000156402588 C0.6660000085830688,6.636000156402588 0.6660000085830688,9.196000099182129 0.6660000085830688,9.196000099182129 C0.6660000085830688,9.565999984741211 0.3659999966621399,9.866000175476074 -0.004000000189989805,9.866000175476074 C-0.33399999141693115,9.866000175476074 -0.6140000224113464,9.605999946594238 -0.6539999842643738,9.28600025177002 C-0.6539999842643738,9.28600025177002 -0.6639999747276306,9.196000099182129 -0.6639999747276306,9.196000099182129 C-0.6639999747276306,9.196000099182129 -0.6639999747276306,6.636000156402588 -0.6639999747276306,6.636000156402588 C-4.473999977111816,6.296000003814697 -7.464000225067139,3.0959999561309814 -7.464000225067139,-0.8040000200271606 C-7.464000225067139,-1.1640000343322754 -7.164000034332275,-1.4639999866485596 -6.803999900817871,-1.4639999866485596 C-6.434000015258789,-1.4639999866485596 -6.133999824523926,-1.1640000343322754 -6.133999824523926,-0.8040000200271606 C-6.133999824523926,2.5859999656677246 -3.384000062942505,5.335999965667725 -0.004000000189989805,5.335999965667725 C3.385999917984009,5.335999965667725 6.136000156402588,2.5859999656677246 6.136000156402588,-0.8040000200271606 C6.136000156402588,-1.1640000343322754 6.435999870300293,-1.4639999866485596 6.796000003814697,-1.4639999866485596 Z ")
            
            context.translateBy(x: -18.0, y: -18.0)
        }
                
        if parameters.transition > 0.0 {
            let startPoint: CGPoint
            let endPoint: CGPoint
            
            let origin: CGPoint
            let length: CGFloat
            if bounds.width > 30.0 {
                origin = CGPoint(x: 9.0, y: 10.0 - UIScreenPixel)
                length = 17.0
            } else {
                origin = CGPoint(x: 5.0 + UIScreenPixel, y: 4.0 + UIScreenPixel)
                length = 15.0
            }
            
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
