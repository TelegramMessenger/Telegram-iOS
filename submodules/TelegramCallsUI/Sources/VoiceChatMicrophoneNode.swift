import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class VoiceChatMicrophoneNodeDrawingState: NSObject {
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

final class VoiceChatMicrophoneNode: ASDisplayNode {
    class State: Equatable {
        let muted: Bool
        let color: UIColor
        
        init(muted: Bool, color: UIColor) {
            self.muted = muted
            self.color = color
        }
        
        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.muted != rhs.muted {
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
    private var state: State = State(muted: false, color: .black)
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
        
        return VoiceChatMicrophoneNodeDrawingState(color: color, transition: transitionFraction, reverse: reverse)
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
        
        if bounds.size.width > 36.0 {
            context.scaleBy(x: 2.5, y: 2.5)
        }
        context.translateBy(x: 18.0, y: 18.0)
        
        let _ = try? drawSvgPath(context, path: "M-0.004000000189989805,-9.86400032043457 C2.2960000038146973,-9.86400032043457 4.165999889373779,-8.053999900817871 4.25600004196167,-5.77400016784668 C4.25600004196167,-5.77400016784668 4.265999794006348,-5.604000091552734 4.265999794006348,-5.604000091552734 C4.265999794006348,-5.604000091552734 4.265999794006348,-0.8040000200271606 4.265999794006348,-0.8040000200271606 C4.265999794006348,1.555999994277954 2.3559999465942383,3.4660000801086426 -0.004000000189989805,3.4660000801086426 C-2.2939999103546143,3.4660000801086426 -4.164000034332275,1.6460000276565552 -4.263999938964844,-0.6240000128746033 C-4.263999938964844,-0.6240000128746033 -4.263999938964844,-0.8040000200271606 -4.263999938964844,-0.8040000200271606 C-4.263999938964844,-0.8040000200271606 -4.263999938964844,-5.604000091552734 -4.263999938964844,-5.604000091552734 C-4.263999938964844,-7.953999996185303 -2.3540000915527344,-9.86400032043457 -0.004000000189989805,-9.86400032043457 Z ")
        
        context.setBlendMode(.clear)
    
        let _ = try? drawSvgPath(context, path: "M0.004000000189989805,-8.53600025177002 C-1.565999984741211,-8.53600025177002 -2.8459999561309814,-7.306000232696533 -2.936000108718872,-5.75600004196167 C-2.936000108718872,-5.75600004196167 -2.936000108718872,-5.5960001945495605 -2.936000108718872,-5.5960001945495605 C-2.936000108718872,-5.5960001945495605 -2.936000108718872,-0.7960000038146973 -2.936000108718872,-0.7960000038146973 C-2.936000108718872,0.8240000009536743 -1.6260000467300415,2.134000062942505 0.004000000189989805,2.134000062942505 C1.5740000009536743,2.134000062942505 2.8540000915527344,0.9039999842643738 2.934000015258789,-0.6460000276565552 C2.934000015258789,-0.6460000276565552 2.934000015258789,-0.7960000038146973 2.934000015258789,-0.7960000038146973 C2.934000015258789,-0.7960000038146973 2.934000015258789,-5.5960001945495605 2.934000015258789,-5.5960001945495605 C2.934000015258789,-7.22599983215332 1.6239999532699585,-8.53600025177002 0.004000000189989805,-8.53600025177002 Z ")
        
        context.setBlendMode(.normal)
        
        let _ = try? drawSvgPath(context, path: "M6.796000003814697,-1.4639999866485596 C7.165999889373779,-1.4639999866485596 7.466000080108643,-1.1640000343322754 7.466000080108643,-0.8040000200271606 C7.466000080108643,3.0959999561309814 4.47599983215332,6.296000003814697 0.6660000085830688,6.636000156402588 C0.6660000085830688,6.636000156402588 0.6660000085830688,9.196000099182129 0.6660000085830688,9.196000099182129 C0.6660000085830688,9.565999984741211 0.3659999966621399,9.866000175476074 -0.004000000189989805,9.866000175476074 C-0.33399999141693115,9.866000175476074 -0.6140000224113464,9.605999946594238 -0.6539999842643738,9.28600025177002 C-0.6539999842643738,9.28600025177002 -0.6639999747276306,9.196000099182129 -0.6639999747276306,9.196000099182129 C-0.6639999747276306,9.196000099182129 -0.6639999747276306,6.636000156402588 -0.6639999747276306,6.636000156402588 C-4.473999977111816,6.296000003814697 -7.464000225067139,3.0959999561309814 -7.464000225067139,-0.8040000200271606 C-7.464000225067139,-1.1640000343322754 -7.164000034332275,-1.4639999866485596 -6.803999900817871,-1.4639999866485596 C-6.434000015258789,-1.4639999866485596 -6.133999824523926,-1.1640000343322754 -6.133999824523926,-0.8040000200271606 C-6.133999824523926,2.5859999656677246 -3.384000062942505,5.335999965667725 -0.004000000189989805,5.335999965667725 C3.385999917984009,5.335999965667725 6.136000156402588,2.5859999656677246 6.136000156402588,-0.8040000200271606 C6.136000156402588,-1.1640000343322754 6.435999870300293,-1.4639999866485596 6.796000003814697,-1.4639999866485596 Z ")
        
        context.translateBy(x: -18.0, y: -18.0)
        
        if parameters.transition > 0.0 {
            let startPoint: CGPoint
            let endPoint: CGPoint
            if parameters.reverse {
                startPoint = CGPoint(x: 9.0 + 17.0 * (1.0 - parameters.transition), y: 10.0 - UIScreenPixel + 17.0 * (1.0 - parameters.transition))
                endPoint = CGPoint(x: 26.0, y: 27.0 - UIScreenPixel)
            } else {
                startPoint = CGPoint(x: 9.0, y: 10.0 - UIScreenPixel)
                endPoint = CGPoint(x: 9.0 + 17.0 * parameters.transition, y: 10.0 - UIScreenPixel + 17.0 * parameters.transition)
            }
        
            context.setBlendMode(.clear)
            context.setLineWidth(4.0)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        
            context.setBlendMode(.normal)
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineWidth(1.0 + UIScreenPixel)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
    }
}
