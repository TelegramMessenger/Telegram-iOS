import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents
import SwiftSignalKit

private final class RadialCheckContentNodeParameters: NSObject {
    let color: UIColor
    let progress: CGFloat
    
    init(color: UIColor, progress: CGFloat) {
        self.color = color
        self.progress = progress
        
        super.init()
    }
}

final class RadialCheckContentNode: RadialStatusContentNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var animationCompletionTimer: SwiftSignalKit.Timer?
    
    private var isAnimatingProgress: Bool {
        return self.pop_animation(forKey: "progress") != nil || self.animationCompletionTimer != nil
    }
    
    private var enqueuedReadyForTransition: (() -> Void)?
    
    init(color: UIColor) {
        self.color = color
        
        super.init()
        
        self.displaysAsynchronously = true
        self.isOpaque = false
        self.isLayerBacked = true
    }
    
    func animateProgress(delay: Double) {
        self.animationCompletionTimer?.invalidate()
        self.animationCompletionTimer = nil
        let animation = POPBasicAnimation()
        animation.property = (POPAnimatableProperty.property(withName: "progress", initializer: { property in
            property?.readBlock = { node, values in
                values?.pointee = (node as! RadialCheckContentNode).effectiveProgress
            }
            property?.writeBlock = { node, values in
                (node as! RadialCheckContentNode).effectiveProgress = values!.pointee
            }
            property?.threshold = 0.01
        }) as! POPAnimatableProperty)
        animation.fromValue = 0.0 as NSNumber
        animation.toValue = 1.0 as NSNumber
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.25
        animation.beginTime = delay
        animation.completionBlock = { [weak self] _, _ in
            if let strongSelf = self {
                strongSelf.animationCompletionTimer?.invalidate()
                if let strongSelf = self {
                    strongSelf.animationCompletionTimer = nil
                    if let enqueuedReadyForTransition = strongSelf.enqueuedReadyForTransition {
                        strongSelf.enqueuedReadyForTransition = nil
                        enqueuedReadyForTransition()
                    }
                }
            }
        }
        self.pop_add(animation, forKey: "progress")
    }
    
    override func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        if self.isAnimatingProgress {
            self.enqueuedReadyForTransition = f
        } else {
            f()
        }
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialCheckContentNodeParameters(color: self.color, progress: self.effectiveProgress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialCheckContentNodeParameters {
            let diameter = bounds.size.width
            
            let progress = parameters.progress
            
            var pathLineWidth: CGFloat = 2.0

            if (abs(diameter - 37.0) < 0.1) {
                pathLineWidth = 2.5
            } else if (abs(diameter - 32.0) < 0.1) {
                pathLineWidth = 2.0
            } else {
                pathLineWidth = 2.5
            }
            
            let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)
            
            let factor: CGFloat = max(0.3, diameter / 50.0)
            
            context.setStrokeColor(parameters.color.cgColor)
            context.setLineWidth(max(1.7, pathLineWidth * factor))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setMiterLimit(10.0)
            
            let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
            
            var s = CGPoint(x: center.x - 10.0 * factor, y: center.y + 1.0 * factor)
            var p1 = CGPoint(x: 7.0 * factor, y: 7.0 * factor)
            var p2 = CGPoint(x: 13.0 * factor, y: -15.0 * factor)
            
            if diameter < 36.0 {
                s = CGPoint(x: center.x - 7.0 * factor, y: center.y + 1.0 * factor)
                p1 = CGPoint(x: 4.5 * factor, y: 4.5 * factor)
                p2 = CGPoint(x: 10.0 * factor, y: -11.0 * factor)
            }
            
            if !firstSegment.isZero {
                if firstSegment < 1.0 {
                    context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                    context.addLine(to: s)
                } else {
                    let secondSegment = (progress - 0.33) * 1.5
                    context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                    context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                    context.addLine(to: s)
                }
            }
            context.strokePath()
        }
    }
    
    private let duration: Double = 0.2
    
    override func animateOut(to: RadialStatusNodeState, completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.6, duration: duration, removeOnCompletion: false)
    }
    
    override func animateIn(from: RadialStatusNodeState, delay: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, delay: delay)
        self.layer.animateScale(from: 0.7, to: 1.0, duration: duration, delay: delay)
        self.animateProgress(delay: delay)
    }
}

