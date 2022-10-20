import Foundation
import UIKit
import AsyncDisplayKit
import Display

private func textForTimeout(value: Int) -> String {
    //TODO: localize
    if value > 60 * 60 {
        let hours = value / (60 * 60)
        return "\(hours)h"
    } else {
        let minutes = value / 60
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(minutes):\(secondsPadding)\(seconds)"
    }
}

private enum ContentState: Equatable {
    case clock(UIColor)
    case timeout(UIColor, CGFloat)
}

private struct ContentParticle {
    var position: CGPoint
    var direction: CGPoint
    var velocity: CGFloat
    var alpha: CGFloat
    var lifetime: Double
    var beginTime: Double
    
    init(position: CGPoint, direction: CGPoint, velocity: CGFloat, alpha: CGFloat, lifetime: Double, beginTime: Double) {
        self.position = position
        self.direction = direction
        self.velocity = velocity
        self.alpha = alpha
        self.lifetime = lifetime
        self.beginTime = beginTime
    }
}

final class PollBubbleTimerNode: ASDisplayNode {
    private struct Params: Equatable {
        var regularColor: UIColor
        var proximityColor: UIColor
        var timeout: Int32
        var deadlineTimestamp: Int32?
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var inHierarchyValue: Bool = false
    
    private var animator: ConstantDisplayLinkAnimator?
    private let textNode: ImmediateTextNode
    private let contentNode: ASDisplayNode
    private var currentContentState: ContentState?
    private var particles: [ContentParticle] = []
    
    private var currentParams: Params?
    
    var reachedTimeout: (() -> Void)?
    
    override init() {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        self.contentNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.contentNode)
        
        updateInHierarchy = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inHierarchyValue = value
            strongSelf.animator?.isPaused = value
        }
    }
    
    deinit {
        self.animator?.invalidate()
    }
    
    func update(regularColor: UIColor, proximityColor: UIColor, timeout: Int32, deadlineTimestamp: Int32?) {
        let params = Params(
            regularColor: regularColor,
            proximityColor: proximityColor,
            timeout: timeout,
            deadlineTimestamp: deadlineTimestamp
        )
        self.currentParams = params
        
        self.updateValues()
    }
    
    private func updateValues() {
        guard let params = self.currentParams else {
            return
        }
        
        let fractionalTimeout: Double
        
        if let deadlineTimestamp = params.deadlineTimestamp {
            let fractionalTimestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            fractionalTimeout = min(Double(params.timeout), max(0.0, Double(deadlineTimestamp) + 1.0 - fractionalTimestamp))
        } else {
            fractionalTimeout = Double(params.timeout)
        }
        
        let timeout = Int(round(fractionalTimeout))
        
        let proximityInterval: Double = 5.0
        let timerInterval: Double = 60.0
        
        let isProximity = timeout <= Int(proximityInterval)
        let isTimer = timeout <= Int(timerInterval)
        
        let color = isProximity ? params.proximityColor : params.regularColor
        self.textNode.attributedText = NSAttributedString(string: textForTimeout(value: timeout), font: Font.regular(14.0), textColor: color)
        let textSize = textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: -22.0 - textSize.width, y: 0.0), size: textSize)
        
        let contentState: ContentState
        if isTimer {
            var fraction: CGFloat = 1.0
            if fractionalTimeout <= timerInterval {
                fraction = CGFloat(fractionalTimeout) / min(CGFloat(timerInterval), CGFloat(params.timeout))
            }
            fraction = max(0.0, min(0.99, fraction))
            contentState = .timeout(color, 1.0 - fraction)
        } else {
            contentState = .clock(color)
        }
        
        if self.currentContentState != contentState {
            self.currentContentState = contentState
            let image: UIImage?
            
            let diameter: CGFloat = 14.0
            let inset: CGFloat = 8.0
            let lineWidth: CGFloat = 1.2
            
            switch contentState {
            case let .clock(color):
                image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(lineWidth)
                    context.setLineCap(.round)
                    
                    let clockFrame = CGRect(origin: CGPoint(x: (size.width - diameter) / 2.0, y: (size.height - diameter) / 2.0), size: CGSize(width: diameter, height: diameter))
                    context.strokeEllipse(in: clockFrame.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
                    
                    context.move(to: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0, y: clockFrame.minY + 4.0))
                    context.strokePath()
                    
                    let topWidth: CGFloat = 4.0
                    context.move(to: CGPoint(x: size.width / 2.0 - topWidth / 2.0, y: clockFrame.minY - 2.0))
                    context.addLine(to: CGPoint(x: size.width / 2.0 + topWidth / 2.0, y: clockFrame.minY - 2.0))
                    context.strokePath()
                })
            case let .timeout(color, fraction):
                let timestamp = CACurrentMediaTime()
                
                let center = CGPoint(x: (diameter + inset) / 2.0, y: (diameter + inset) / 2.0)
                let radius: CGFloat = (diameter - lineWidth / 2.0) / 2.0
                
                let startAngle: CGFloat = -CGFloat.pi / 2.0
                let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * fraction
                
                let v = CGPoint(x: sin(endAngle), y: -cos(endAngle))
                let c = CGPoint(x: -v.y * radius + center.x, y: v.x * radius + center.y)
                
                let dt: CGFloat = 1.0 / 60.0
                var removeIndices: [Int] = []
                for i in 0 ..< self.particles.count {
                    let currentTime = timestamp - self.particles[i].beginTime
                    if currentTime > self.particles[i].lifetime {
                        removeIndices.append(i)
                    } else {
                        let input: CGFloat = CGFloat(currentTime / self.particles[i].lifetime)
                        let decelerated: CGFloat = (1.0 - (1.0 - input) * (1.0 - input))
                        self.particles[i].alpha = 1.0 - decelerated
                        
                        var p = self.particles[i].position
                        let d = self.particles[i].direction
                        let v = self.particles[i].velocity
                        p = CGPoint(x: p.x + d.x * v * dt, y: p.y + d.y * v * dt)
                        self.particles[i].position = p
                    }
                }
                
                for i in removeIndices.reversed() {
                    self.particles.remove(at: i)
                }
                
                let newParticleCount = 1
                for _ in 0 ..< newParticleCount {
                    let degrees: CGFloat = CGFloat(arc4random_uniform(140)) - 40.0
                    let angle: CGFloat = degrees * CGFloat.pi / 180.0
                    
                    let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
                    let velocity = (20.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.3
                    
                    let lifetime = Double(0.4 + CGFloat(arc4random_uniform(100)) * 0.01)
                    
                    let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
                    self.particles.append(particle)
                }
                
                image = generateImage(CGSize(width: diameter + inset, height: diameter + inset), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(color.cgColor)
                    context.setFillColor(color.cgColor)
                    context.setLineWidth(lineWidth)
                    context.setLineCap(.round)
                    
                    let path = CGMutablePath()
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                    context.addPath(path)
                    context.strokePath()
                    
                    for particle in self.particles {
                        let size: CGFloat = 1.15
                        context.setAlpha(particle.alpha)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
                    }
                })
            }
            
            self.contentNode.contents = image?.cgImage
            if let image = image {
                self.contentNode.frame = CGRect(origin: CGPoint(x: -image.size.width, y: -3.0), size: image.size)
            }
        }
        
        if let reachedTimeout = self.reachedTimeout, fractionalTimeout <= .ulpOfOne {
            reachedTimeout()
        }
        
        if fractionalTimeout <= .ulpOfOne {
            self.animator?.invalidate()
            self.animator = nil
        } else {
            if self.animator == nil {
                let animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateValues()
                })
                self.animator = animator
                animator.isPaused = self.inHierarchyValue
            }
        }
    }
}
