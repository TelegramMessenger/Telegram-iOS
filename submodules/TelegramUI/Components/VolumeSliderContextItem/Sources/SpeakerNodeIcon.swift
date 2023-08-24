import Foundation
import UIKit
import AsyncDisplayKit
import Display

private final class VoiceChatSpeakerNodeDrawingState: NSObject {
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

private func generateWaveImage(color: UIColor, num: Int) -> UIImage? {
    return generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0 + UIScreenPixel)
        context.setLineCap(.round)
        
        context.translateBy(x: 6.0, y: 6.0)
        
        switch num {
            case 1:
                let _ = try? drawSvgPath(context, path: "M15,9 C15.6666667,9.95023099 16,10.9487504 16,11.9955581 C16,13.0423659 15.6666667,14.0438465 15,15 S ")
            case 2:
                let _ = try? drawSvgPath(context, path: "M17.5,6.5 C18.8724771,8.24209014 19.5587156,10.072709 19.5587156,11.9918565 C19.5587156,13.9110041 18.8724771,15.7470519 17.5,17.5 S ")
            case 3:
                let _ = try? drawSvgPath(context, path: "M20,3.5 C22,6.19232113 23,9.02145934 23,11.9874146 C23,14.9533699 22,17.7908984 20,20.5 S ")
            default:
                break
        }
    })
}

final class VoiceChatSpeakerNode: ASDisplayNode {
    class State: Equatable {
        enum Value: Equatable {
            case muted
            case low
            case medium
            case high
        }
        
        let value: Value
        let color: UIColor
        
        init(value: Value, color: UIColor) {
            self.value = value
            self.color = color
        }
        
        static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            if lhs.color.argb != rhs.color.argb {
                return false
            }
            return true
        }
    }
    
    private var hasState = false
    private var state: State = State(value: .medium, color: .black)
    
    private let iconNode: IconNode
    private let waveNode1: ASImageNode
    private let waveNode2: ASImageNode
    private let waveNode3: ASImageNode
    
    override init() {
        self.iconNode = IconNode()
        self.waveNode1 = ASImageNode()
        self.waveNode1.displaysAsynchronously = false
        self.waveNode1.displayWithoutProcessing = true
        
        self.waveNode2 = ASImageNode()
        self.waveNode2.displaysAsynchronously = false
        self.waveNode2.displayWithoutProcessing = true
        
        self.waveNode3 = ASImageNode()
        self.waveNode3.displaysAsynchronously = false
        self.waveNode3.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.waveNode1)
        self.addSubnode(self.waveNode2)
        self.addSubnode(self.waveNode3)
    }
    
    private var animating = false
    func update(state: State, animated: Bool, force: Bool = false) {
        var animated = animated
        if !self.hasState {
            self.hasState = true
            animated = false
        }
        
        if self.state != state || force {
            let previousState = self.state
            self.state = state
            
            if animated && self.animating {
                return
            }
            
            if previousState.color != state.color {
                self.waveNode1.image = generateWaveImage(color: state.color, num: 1)
                self.waveNode2.image = generateWaveImage(color: state.color, num: 2)
                self.waveNode3.image = generateWaveImage(color: state.color, num: 3)
            }
            
            self.update(transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, completion: {
                if self.state != state {
                    self.update(state: self.state, animated: animated, force: true)
                }
            })
        }
    }
    
    private func update(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        self.animating = transition.isAnimated
        
        self.iconNode.update(state: IconNode.State(muted: self.state.value == .muted, color: self.state.color), animated: transition.isAnimated)
        
        let bounds = self.bounds
        let center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
        
        self.iconNode.bounds = CGRect(origin: CGPoint(), size: bounds.size)
        self.waveNode1.bounds = CGRect(origin: CGPoint(), size: bounds.size)
        self.waveNode2.bounds = CGRect(origin: CGPoint(), size: bounds.size)
        self.waveNode3.bounds = CGRect(origin: CGPoint(), size: bounds.size)
        
        let iconPosition: CGPoint
        let wave1Position: CGPoint
        var wave1Alpha: CGFloat = 1.0
        let wave2Position: CGPoint
        var wave2Alpha: CGFloat = 1.0
        let wave3Position: CGPoint
        var wave3Alpha: CGFloat = 1.0
        switch self.state.value {
            case .muted:
                iconPosition = CGPoint(x: center.x, y: center.y)
                wave1Position = CGPoint(x: center.x + 4.0, y: center.y)
                wave2Position = CGPoint(x: center.x + 4.0, y: center.y)
                wave3Position = CGPoint(x: center.x + 4.0, y: center.y)
                
                wave1Alpha = 0.0
                wave2Alpha = 0.0
                wave3Alpha = 0.0
            case .low:
                iconPosition = CGPoint(x: center.x - 1.0, y: center.y)
                wave1Position = CGPoint(x: center.x + 3.0, y: center.y)
                wave2Position = CGPoint(x: center.x + 3.0, y: center.y)
                wave3Position = CGPoint(x: center.x + 3.0, y: center.y)
                
                wave2Alpha = 0.0
                wave3Alpha = 0.0
            case .medium:
                iconPosition = CGPoint(x: center.x - 3.0, y: center.y)
                wave1Position = CGPoint(x: center.x + 1.0, y: center.y)
                wave2Position = CGPoint(x: center.x + 1.0, y: center.y)
                wave3Position = CGPoint(x: center.x + 1.0, y: center.y)
                
                wave3Alpha = 0.0
            case .high:
                iconPosition = CGPoint(x: center.x - 4.0, y: center.y)
                wave1Position = CGPoint(x: center.x, y: center.y)
                wave2Position = CGPoint(x: center.x, y: center.y)
                wave3Position = CGPoint(x: center.x, y: center.y)
        }
        
        transition.updatePosition(node: self.iconNode, position: iconPosition) { _ in
            self.animating = false
            completion()
        }
        transition.updatePosition(node: self.waveNode1, position: wave1Position)
        transition.updatePosition(node: self.waveNode2, position: wave2Position)
        transition.updatePosition(node: self.waveNode3, position: wave3Position)
        
        transition.updateAlpha(node: self.waveNode1, alpha: wave1Alpha)
        transition.updateAlpha(node: self.waveNode2, alpha: wave2Alpha)
        transition.updateAlpha(node: self.waveNode3, alpha: wave3Alpha)
    }
}

private class IconNode: ASDisplayNode {
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
        
        return VoiceChatSpeakerNodeDrawingState(color: color, transition: transitionFraction, reverse: reverse)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? VoiceChatSpeakerNodeDrawingState else {
            return
        }

        let clearLineWidth: CGFloat = 4.0
        let lineWidth: CGFloat = 1.0 + UIScreenPixel
        
        context.setFillColor(parameters.color.cgColor)
        context.setStrokeColor(parameters.color.cgColor)
        context.setLineWidth(lineWidth)
        
        context.translateBy(x: 7.0, y: 6.0)
        
        let _ = try? drawSvgPath(context, path: "M7,9 L10,9 L13.6080479,5.03114726 C13.9052535,4.70422117 14.4112121,4.6801279 14.7381382,4.97733344 C14.9049178,5.12895118 15,5.34388952 15,5.5692855 L15,18.4307145 C15,18.8725423 14.6418278,19.2307145 14.2,19.2307145 C13.974604,19.2307145 13.7596657,19.1356323 13.6080479,18.9688527 L10,15 L7,15 C6.44771525,15 6,14.5522847 6,14 L6,10 C6,9.44771525 6.44771525,9 7,9 S ")

        context.translateBy(x: -7.0, y: -6.0)
                
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
