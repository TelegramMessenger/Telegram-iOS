import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents

private final class RadialCloudProgressContentCancelNodeParameters: NSObject {
    let color: UIColor
    
    init(color: UIColor) {
        self.color = color
    }
}

private final class RadialCloudProgressContentSpinnerNodeParameters: NSObject {
    let color: UIColor
    let backgroundStrokeColor: UIColor
    let progress: CGFloat
    let lineWidth: CGFloat?
    
    init(color: UIColor, backgroundStrokeColor: UIColor, progress: CGFloat, lineWidth: CGFloat?) {
        self.color = color
        self.backgroundStrokeColor = backgroundStrokeColor
        self.progress = progress
        self.lineWidth = lineWidth
    }
}

private final class RadialCloudProgressContentSpinnerNode: ASDisplayNode {
    var progressAnimationCompleted: (() -> Void)?
    
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var backgroundStrokeColor: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var progress: CGFloat? {
        didSet {
            self.pop_removeAnimation(forKey: "progress")
            if let progress = self.progress {
                self.pop_removeAnimation(forKey: "indefiniteProgress")
                
                let animation = POPBasicAnimation()
                animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = (node as! RadialCloudProgressContentSpinnerNode).effectiveProgress
                    }
                    property?.writeBlock = { node, values in
                        (node as! RadialCloudProgressContentSpinnerNode).effectiveProgress = values!.pointee
                    }
                    property?.threshold = 0.01
                }) as! POPAnimatableProperty)
                animation.fromValue = CGFloat(self.effectiveProgress) as NSNumber
                animation.toValue = CGFloat(progress) as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.duration = 0.2
                animation.completionBlock = { [weak self] _, _ in
                    self?.progressAnimationCompleted?()
                }
                self.pop_add(animation, forKey: "progress")
            } else if self.pop_animation(forKey: "indefiniteProgress") == nil {
                let animation = POPBasicAnimation()
                animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
                    property?.readBlock = { node, values in
                        values?.pointee = (node as! RadialCloudProgressContentSpinnerNode).effectiveProgress
                    }
                    property?.writeBlock = { node, values in
                        (node as! RadialCloudProgressContentSpinnerNode).effectiveProgress = values!.pointee
                    }
                    property?.threshold = 0.01
                }) as! POPAnimatableProperty)
                animation.fromValue = CGFloat(0.0) as NSNumber
                animation.toValue = CGFloat(2.0) as NSNumber
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                animation.duration = 2.5
                animation.repeatForever = true
                self.pop_add(animation, forKey: "indefiniteProgress")
            }
        }
    }
    
    var isAnimatingProgress: Bool {
        return self.pop_animation(forKey: "progress") != nil
    }
    
    let lineWidth: CGFloat?
    
    init(color: UIColor, backgroundStrokeColor: UIColor, lineWidth: CGFloat?) {
        self.color = color
        self.backgroundStrokeColor = backgroundStrokeColor
        self.lineWidth = lineWidth
        
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = true
        self.isOpaque = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialCloudProgressContentSpinnerNodeParameters(color: self.color, backgroundStrokeColor: self.backgroundStrokeColor, progress: self.effectiveProgress, lineWidth: self.lineWidth)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialCloudProgressContentSpinnerNodeParameters {
            let factor = bounds.size.width / 50.0
            
            var progress = parameters.progress
            var startAngle = -CGFloat.pi / 2.0
            var endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
            
            if progress > 1.0 {
                progress = 2.0 - progress
                let tmp = startAngle
                startAngle = endAngle
                endAngle = tmp
            }
            progress = min(1.0, progress)
            
            let lineWidth: CGFloat = parameters.lineWidth ?? max(1.6, 2.25 * factor)
            
            let pathDiameter: CGFloat
            if parameters.lineWidth != nil {
                pathDiameter = bounds.size.width - lineWidth
            } else {
                pathDiameter = bounds.size.width - lineWidth - 2.5 * 2.0
            }
            
            context.setStrokeColor(parameters.backgroundStrokeColor.cgColor)
            let backgroundPath = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: 0.0, endAngle: 2.0 * CGFloat.pi, clockwise:true)
            backgroundPath.lineWidth = lineWidth
            backgroundPath.stroke()
            
            context.setStrokeColor(parameters.color.cgColor)
            let path = UIBezierPath(arcCenter: CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0), radius: pathDiameter / 2.0, startAngle: startAngle, endAngle: endAngle, clockwise:true)
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
        }
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        basicAnimation.duration = 2.0
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        basicAnimation.beginTime = 1.0
        
        self.layer.add(basicAnimation, forKey: "progressRotation")
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.layer.removeAnimation(forKey: "progressRotation")
    }
}

private final class RadialCloudProgressContentCancelNode: ASDisplayNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.isLayerBacked = true
        self.displaysAsynchronously = true
        self.isOpaque = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialCloudProgressContentCancelNodeParameters(color: self.color)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialCloudProgressContentCancelNodeParameters {
            let size: CGFloat = 8.0
            context.setFillColor(parameters.color.cgColor)
            let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: floor((bounds.size.width - size) / 2.0), y: floor((bounds.size.height - size) / 2.0)), size: CGSize(width: size, height: size)), cornerRadius: 2.0)
            path.fill()
        }
    }
}

final class RadialCloudProgressContentNode: RadialStatusContentNode {
    private let spinnerNode: RadialCloudProgressContentSpinnerNode
    private let cancelNode: RadialCloudProgressContentCancelNode
    
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
            self.spinnerNode.color = self.color
        }
    }
    
    var backgroundStrokeColor: UIColor {
        didSet {
            self.setNeedsDisplay()
            self.spinnerNode.backgroundStrokeColor = self.backgroundStrokeColor
        }
    }
    
    var progress: CGFloat? = 0.0 {
        didSet {
            self.spinnerNode.progress = self.progress
        }
    }
    
    private var enqueuedReadyForTransition: (() -> Void)?
    
    init(color: UIColor, backgroundStrokeColor: UIColor, lineWidth: CGFloat?) {
        self.color = color
        self.backgroundStrokeColor = backgroundStrokeColor
        
        self.spinnerNode = RadialCloudProgressContentSpinnerNode(color: color, backgroundStrokeColor: backgroundStrokeColor, lineWidth: lineWidth)
        self.cancelNode = RadialCloudProgressContentCancelNode(color: color)
        
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.spinnerNode)
        self.addSubnode(self.cancelNode)
        
        self.spinnerNode.progressAnimationCompleted = { [weak self] in
            if let strongSelf = self {
                if let enqueuedReadyForTransition = strongSelf.enqueuedReadyForTransition {
                    strongSelf.enqueuedReadyForTransition = nil
                    enqueuedReadyForTransition()
                }
            }
        }
    }
    
    override func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        if self.spinnerNode.isAnimatingProgress && self.progress == 1.0 {
            self.enqueuedReadyForTransition = f
        } else {
            f()
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.spinnerNode.bounds = bounds
        self.spinnerNode.position = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
        self.cancelNode.frame = bounds
    }
    
    override func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.cancelNode.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
    }
    
    override func animateIn(from: RadialStatusNodeState, delay: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
        self.cancelNode.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, delay: delay)
    }
}
