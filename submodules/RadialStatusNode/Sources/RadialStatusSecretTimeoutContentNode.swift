import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

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

private final class RadialStatusSecretTimeoutContentNodeParameters: NSObject {
    let color: UIColor
    let icon: UIImage?
    let progress: CGFloat
    let sparks: Bool
    let particles: [ContentParticle]
    
    init(color: UIColor, icon: UIImage?, progress: CGFloat, sparks: Bool, particles: [ContentParticle]) {
        self.color = color
        self.icon = icon
        self.progress = progress
        self.sparks = sparks
        self.particles = particles
    }
}

final class RadialStatusSecretTimeoutContentNode: RadialStatusContentNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private let beginTime: Double
    private let timeout: Double
    private let icon: UIImage?
    private let sparks: Bool
    
    private var progress: CGFloat = 0.0
    private var particles: [ContentParticle] = []
    
    private var displayLink: CADisplayLink?
    
    init(color: UIColor, beginTime: Double, timeout: Double, icon: UIImage?, sparks: Bool) {
        self.color = color
        self.beginTime = beginTime
        self.timeout = timeout
        self.icon = icon
        self.sparks = sparks
        
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
        
        class DisplayLinkProxy: NSObject {
            weak var target: RadialStatusSecretTimeoutContentNode?
            init(target: RadialStatusSecretTimeoutContentNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink?.isPaused = true
        self.displayLink?.add(to: RunLoop.main, forMode: .common)
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    override func layout() {
        super.layout()
    }
    
    override func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func animateIn(from: RadialStatusNodeState, delay: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        self.displayLink?.isPaused = false
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        self.displayLink?.isPaused = true
    }
    
    private func displayLinkEvent() {
        let bounds = self.bounds
        if bounds.width.isZero {
            return
        }
        
        let absoluteTimestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        self.progress = min(1.0, CGFloat((absoluteTimestamp - self.beginTime) / self.timeout))
        
        if self.sparks {
            let lineWidth: CGFloat = 1.75
            let center = bounds.center
            let radius: CGFloat = (bounds.size.width - lineWidth - 2.5 * 2.0) * 0.5
            
            let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * self.progress
            
            let v = CGPoint(x: sin(endAngle), y: -cos(endAngle))
            let c = CGPoint(x: -v.y * radius + center.x, y: v.x * radius + center.y)
            
            let timestamp = CACurrentMediaTime()
            
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
        }
        
        self.setNeedsDisplay()
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialStatusSecretTimeoutContentNodeParameters(color: self.color, icon: self.icon, progress: self.progress, sparks: self.sparks, particles: self.particles)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialStatusSecretTimeoutContentNodeParameters {
            if let icon = parameters.icon, let iconImage = icon.cgImage {
                let imageRect = CGRect(origin: CGPoint(x: floor((bounds.size.width - icon.size.width) / 2.0), y: floor((bounds.size.height - icon.size.height) / 2.0)), size: icon.size)
                context.saveGState()
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                context.draw(iconImage, in: imageRect)
                context.restoreGState()
            }
            
            let lineWidth: CGFloat
            if parameters.sparks {
                lineWidth = 1.75
            } else {
                lineWidth = 1.75
            }
            
            context.setFillColor(parameters.color.cgColor)
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.miter)
            context.setMiterLimit(10.0)
            
            let center = bounds.center
            let radius: CGFloat = (bounds.size.width - lineWidth - 2.5 * 2.0) * 0.5
            
            let startAngle: CGFloat = -CGFloat.pi / 2.0
            let endAngle: CGFloat = -CGFloat.pi / 2.0 + 2.0 * CGFloat.pi * parameters.progress
            
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            context.addPath(path)
            context.strokePath()
            
            for particle in parameters.particles {
                let size: CGFloat = 1.3
                context.setAlpha(particle.alpha)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: particle.position.x - size / 2.0, y: particle.position.y - size / 2.0), size: CGSize(width: size, height: size)))
            }
        }
    }
}

