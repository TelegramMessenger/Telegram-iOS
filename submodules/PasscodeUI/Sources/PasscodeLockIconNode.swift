import Foundation
import UIKit
import AsyncDisplayKit
import Display
import LegacyComponents

private final class PasscodeLockIconNodeParameters: NSObject {
    let unlockedColor: UIColor
    let lockedColor: UIColor
    let progress: CGFloat
    let fromScale: CGFloat
    let keepLockedColor: Bool
    
    init(unlockedColor: UIColor, lockedColor: UIColor, progress: CGFloat, fromScale: CGFloat, keepLockedColor: Bool) {
        self.unlockedColor = unlockedColor
        self.lockedColor = lockedColor
        self.progress = progress
        self.fromScale = fromScale
        self.keepLockedColor = keepLockedColor
        super.init()
    }
}

final class PasscodeLockIconNode: ASDisplayNode {
    var unlockedColor: UIColor = .black {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var fromScale: CGFloat = 1.0
    
    private var keepLockedColor = false
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = .clear
    }
    
    func animateIn(fromScale: CGFloat = 1.0) {
        self.fromScale = fromScale

        self.pop_removeAllAnimations()
        
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! PasscodeLockIconNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! PasscodeLockIconNode).effectiveProgress = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        animation.fromValue = 0.0 as NSNumber
        animation.toValue = 1.0 as NSNumber
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.55
        self.pop_add(animation, forKey: "progress")
    }
    
    func animateUnlock() {
        self.fromScale = 1.0
        self.keepLockedColor = true
        self.pop_removeAllAnimations()
        
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! PasscodeLockIconNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! PasscodeLockIconNode).effectiveProgress = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        animation.fromValue = 1.0 as NSNumber
        animation.toValue = 0.0 as NSNumber
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.75
        self.pop_add(animation, forKey: "progress")
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return PasscodeLockIconNodeParameters(unlockedColor: self.unlockedColor, lockedColor: .white, progress: self.effectiveProgress, fromScale: self.fromScale, keepLockedColor: self.keepLockedColor)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? PasscodeLockIconNodeParameters else {
            return
        }
        
        let progress = parameters.progress
        let fromScale = parameters.fromScale
        let lockSpan: CGFloat = parameters.keepLockedColor ? 0.5 : 0.85
        let lockProgress = min(1.0, progress / lockSpan)
        
        context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
        context.scaleBy(x: fromScale + (1.0 - fromScale) * lockProgress, y: fromScale + (1.0 - fromScale) * lockProgress)
        context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
        
        let color = parameters.keepLockedColor ? parameters.lockedColor : parameters.unlockedColor.mixedWith(parameters.lockedColor, alpha: progress)
        
        context.setStrokeColor(color.cgColor)
        
        let lineWidth: CGFloat = 3.0
        context.setLineWidth(lineWidth)
        
        var topRect: CGRect
        var topRadius: CGFloat
        var offset: CGFloat = 0.0
        if lockProgress < 0.5 {
            topRect = CGRect(x: 19.0, y: lineWidth / 2.0 + 1.0, width: 14.0 * (0.5 - lockProgress) / 0.5, height: 22.0)
            topRadius = 6.0 * (0.5 - lockProgress) * 2.0
        } else {
            let width = 14.0 * (lockProgress - 0.5) * 2.0
            topRect = CGRect(x: 19.0 - width, y: lineWidth / 2.0 + 1.0, width: width, height: 22.0)
            topRadius = 6.0 * (lockProgress - 0.5) * 2.0
        }
        if progress > lockSpan {
            let innerProgress = (progress - lockSpan) / (1.0 - lockSpan)
            if !parameters.keepLockedColor {
                if innerProgress < 0.6 {
                    offset = 2.0 * min(1.0, innerProgress / 0.6)
                } else {
                    offset = 2.0 * min(1.0, max(0.0, (1.0 - innerProgress) / 0.4))
                }
            }
            
            topRect.origin.y += 4.0 * min(1.0, max(0.0, innerProgress / 0.6)) + offset
        }
        let topPath = UIBezierPath(roundedRect: topRect, cornerRadius: topRadius)
        context.addPath(topPath.cgPath)
        context.strokePath()
        
        var clearRect: CGRect
        if lockProgress < 0.5 {
            clearRect = CGRect(x: topRect.minX + lineWidth, y: topRect.minY + 11.0, width: 14.0, height: 22.0)
        } else {
            clearRect = CGRect(x: topRect.maxX - 14.0 - lineWidth, y: topRect.minY + 11.0, width: 14.0, height: 22.0)
        }
        
        context.setBlendMode(.clear)
        context.clear(clearRect)
        context.setBlendMode(.normal)
        
        context.setFillColor(color.cgColor)
        
        let basePath = UIBezierPath(roundedRect: CGRect(x: 0.0, y: bounds.height - 21.0 + offset, width: 24.0, height: 19.0), cornerRadius: 3.5)
        context.addPath(basePath.cgPath)
        context.fillPath()
    }
}
