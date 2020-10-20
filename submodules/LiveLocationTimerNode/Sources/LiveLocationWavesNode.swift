import Foundation
import UIKit
import Display
import AsyncDisplayKit

private final class LiveLocationWavesNodeParams: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
        
        super.init()
    }
}

private func degToRad(_ degrees: CGFloat) -> CGFloat {
    return degrees * CGFloat.pi / 180.0
}

public final class LiveLocationWavesNode: ASDisplayNode {
    public var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var animator: ConstantDisplayLinkAnimator?
    
    public init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isLayerBacked = true
        self.isOpaque = false
    }
    
    deinit {
        self.animator?.invalidate()
    }
    
    private var previousAnimationStart: Double?
    private func updateAnimations(inHierarchy: Bool) {
        let timestamp = CACurrentMediaTime()
        
        let animating: Bool
        
        if inHierarchy {
            animating = true
            
            let animator: ConstantDisplayLinkAnimator
            if let current = self.animator {
                animator = current
            } else {
                animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimations(inHierarchy: true)
                })
                self.animator = animator
            }
            animator.isPaused = false
        } else {
            animating = false
            self.animator?.isPaused = true
            self.previousAnimationStart = nil
        }
        
        if animating {
            let animationDuration: Double = 2.5
            if var startTimestamp = self.previousAnimationStart {
                if timestamp > startTimestamp + animationDuration {
                    while timestamp > startTimestamp + animationDuration {
                        startTimestamp += animationDuration
                    }
                    startTimestamp -= animationDuration
                }
                
                let t = min(1.0, max(0.0, (timestamp - startTimestamp) / animationDuration))
                self.effectiveProgress = CGFloat(t)
            } else {
                self.previousAnimationStart = timestamp
            }
        }
    }
    
    public override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.updateAnimations(inHierarchy: true)
    }
    
    public override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.updateAnimations(inHierarchy: false)
    }
    
    public override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        let t = CACurrentMediaTime()
        let value: CGFloat = CGFloat(t.truncatingRemainder(dividingBy: 2.0)) / 2.0
        return LiveLocationWavesNodeParams(color: self.color, progress: value)
    }
    
    @objc public override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? LiveLocationWavesNodeParams {
            let center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
            let length: CGFloat = 9.0
            
            context.setFillColor(parameters.color.cgColor)
            
            let draw: (CGContext, CGFloat, Bool) -> Void = { context, pos, right in
                let path = CGMutablePath()
                
                path.addArc(center: center, radius: length * pos + 7.0, startAngle: right ? degToRad(-26.0) : degToRad(154.0), endAngle: right ? degToRad(26.0) : degToRad(206.0), clockwise: false)
                
                let strokedArc = path.copy(strokingWithWidth: 1.65, lineCap: .round, lineJoin: .miter, miterLimit: 10.0)
                
                context.addPath(strokedArc)
                
                context.fillPath()
            }
            
            let position = parameters.progress
            var alpha = position / 0.5
            if alpha > 1.0 {
                alpha = 2.0 - alpha
            }
            context.setAlpha(alpha * 0.7)
            
            draw(context, position, false)
            draw(context, position, true)
            
            var progress = parameters.progress + 0.5
            if progress > 1.0 {
                progress = progress - 1.0
            }
            
            let largerPos = progress
            var largerAlpha = largerPos / 0.5
            if largerAlpha > 1.0 {
                largerAlpha = 2.0 - largerAlpha
            }
            context.setAlpha(largerAlpha * 0.7)
            
            draw(context, largerPos, false)
            draw(context, largerPos, true)
        }
    }
}
