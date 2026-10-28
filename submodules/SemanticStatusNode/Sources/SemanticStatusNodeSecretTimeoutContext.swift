import Foundation
import UIKit
import Display
import ManagedAnimationNode

final class SemanticStatusNodeSecretTimeoutContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let value: CGFloat
        let appearance: SemanticStatusNodeState.ProgressAppearance?
        let iconImage: UIImage?
        fileprivate let particles: [ContentParticle]
        
        fileprivate init(transitionFraction: CGFloat, value: CGFloat, appearance: SemanticStatusNodeState.ProgressAppearance?, iconImage: UIImage?, particles: [ContentParticle]) {
            self.transitionFraction = transitionFraction
            self.value = value
            self.appearance = appearance
            self.iconImage = iconImage
            self.particles = particles
    
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
            
            var progress = self.value
            progress = min(1.0, progress)
            let endAngle = -CGFloat.pi / 2.0
            let startAngle = CGFloat(progress) * 2.0 * CGFloat.pi + endAngle
                
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
            
            let path = UIBezierPath(arcCenter: CGPoint(x: diameter / 2.0, y: diameter / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
            
            if let iconImage = self.iconImage {
                context.saveGState()
                let iconRect = CGRect(origin: CGPoint(), size: iconImage.size)
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.translateBy(x: 6.0, y: 8.0)
                context.clip(to: iconRect, mask: iconImage.cgImage!)
                context.fill(iconRect)
                context.restoreGState()
            }
            
            for particle in self.particles {
                let size: CGFloat = 1.3
                context.setAlpha(particle.alpha)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
            }
            
            context.restoreGState()
        }
    }
    
    var position: Double
    var duration: Double
    var generationTimestamp: Double
    
    let appearance: SemanticStatusNodeState.ProgressAppearance?
    fileprivate var particles: [ContentParticle] = []
    
    private var animationNode: FireIconNode?
    private var iconImage: UIImage?
    
    var isAnimating: Bool {
        return true
    }
    
    var requestUpdate: () -> Void = {}
    
    init(position: Double, duration: Double, generationTimestamp: Double, appearance: SemanticStatusNodeState.ProgressAppearance?) {
        self.position = position
        self.duration = duration
        self.generationTimestamp = generationTimestamp
        self.appearance = appearance
        
        self.animationNode = FireIconNode()
        self.animationNode?.imageUpdated = { [weak self] image in
            if let strongSelf = self {
                strongSelf.iconImage = image
                strongSelf.requestUpdate()
            }
        }
        self.iconImage = self.animationNode?.image
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        let timestamp = CACurrentMediaTime()
        let position = self.position + (timestamp - self.generationTimestamp)
        let resolvedValue: CGFloat
        if self.duration > 0.0 {
            resolvedValue = position / self.duration
        } else {
            resolvedValue = 0.0
        }

        let size = CGSize(width: 44.0, height: 44.0)
        
        
        let lineWidth: CGFloat
        let lineInset: CGFloat
        if let appearance = self.appearance {
            lineWidth = appearance.lineWidth
            lineInset = appearance.inset
        } else {
            lineWidth = 2.0
            lineInset = 1.0
        }
        
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let radius: CGFloat = (size.width - lineWidth - lineInset * 2.0) * 0.5
        
        let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * resolvedValue
        
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
            let degrees: CGFloat = CGFloat(arc4random_uniform(140)) - 70.0
            let angle: CGFloat = degrees * CGFloat.pi / 180.0
            
            let direction = CGPoint(x: v.x * cos(angle) - v.y * sin(angle), y: v.x * sin(angle) + v.y * cos(angle))
            let velocity = (20.0 + (CGFloat(arc4random()) / CGFloat(UINT32_MAX)) * 4.0) * 0.5
            
            let lifetime = Double(0.4 + CGFloat(arc4random_uniform(100)) * 0.01)
            
            let particle = ContentParticle(position: c, direction: direction, velocity: velocity, alpha: 1.0, lifetime: lifetime, beginTime: timestamp)
            self.particles.append(particle)
        }
        
        return DrawingState(transitionFraction: transitionFraction, value: resolvedValue, appearance: self.appearance, iconImage: self.iconImage, particles: self.particles)
    }
    
    func maskView() -> UIView? {
        return nil
    }
    
    func updateValue(position: Double, duration: Double, generationTimestamp: Double) {
        self.position = position
        self.duration = duration
        self.generationTimestamp = generationTimestamp
    }
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

private final class FireIconNode: ManagedAnimationNode {
    init() {
        super.init(size: CGSize(width: 32.0, height: 32.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_flame_1"), frames: .range(startFrame: 0, endFrame: 60), duration: 1.5))
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_flame_2"), frames: .range(startFrame: 0, endFrame: 120), duration: 2.0, loop: true))
    }
}
