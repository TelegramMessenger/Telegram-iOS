import Foundation
import UIKit
import AsyncDisplayKit
import Display

private class RadialTimeoutNodeParameters: NSObject {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let value: CGFloat
    
    init(backgroundColor: UIColor, foregroundColor: UIColor, value: CGFloat) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.value = value
        
        super.init()
    }
}

private final class RadialTimeoutNodeTimer: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
        
        super.init()
    }
    
    @objc func event() {
        self.action()
    }
}

public final class RadialTimeoutNode: ASDisplayNode {
    private var nodeBackgroundColor: UIColor
    private var nodeForegroundColor: UIColor
    
    private var timeout: (Double, Double)?
    
    private var animationTimer: Timer?
    
    public init(backgroundColor: UIColor, foregroundColor: UIColor) {
        self.nodeBackgroundColor = backgroundColor
        self.nodeForegroundColor = foregroundColor
        
        super.init()
        
        self.isOpaque = false
    }
    
    public func updateTheme(backgroundColor: UIColor, foregroundColor: UIColor) {
        self.nodeBackgroundColor = backgroundColor
        self.nodeForegroundColor = foregroundColor
        
        self.setNeedsDisplay()
    }
    
    deinit {
        self.animationTimer?.invalidate()
    }
    
    public func setTimeout(beginTimestamp: Double, timeout: Double) {
        if self.timeout?.0 != beginTimestamp || self.timeout?.1 != timeout {
            self.animationTimer?.invalidate()
            self.timeout = (beginTimestamp, timeout)
            
            let animationTimer = Timer(timeInterval: 1.0 / 60.0, target: RadialTimeoutNodeTimer({ [weak self] in
                self?.setNeedsDisplay()
            }), selector: #selector(RadialTimeoutNodeTimer.event), userInfo: nil, repeats: true)
            self.animationTimer = animationTimer
            RunLoop.main.add(animationTimer, forMode: .common)
        }
    }
    
    public override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        var value: CGFloat = 0.0
        if let (beginTimestamp, timeout) = self.timeout {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            value = CGFloat(max(0.0, min(1.0, (timestamp - beginTimestamp) / timeout)))
        }
        return RadialTimeoutNodeParameters(backgroundColor: self.nodeBackgroundColor, foregroundColor: self.nodeForegroundColor, value: value)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialTimeoutNodeParameters {
            context.setFillColor(parameters.backgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: bounds.size.width, height: bounds.size.height)))
            
            context.setFillColor(parameters.foregroundColor.cgColor)
            //context.fill(CGRect(origin: CGPoint(), size: CGSize(width: bounds.size.width, height: bounds.size.height * parameters.value)))
            
            let radius = (bounds.size.width - 4.0) * 0.5
            
            let viewCenter = CGPoint(x: bounds.size.width * 0.5, y: bounds.size.height * 0.5)
            let startAngle = -CGFloat.pi * 0.5
            
            // update the end angle of the segment
            let endAngle = startAngle + 2.0 * CGFloat.pi * parameters.value
            
            // move to the center of the pie chart
            context.move(to: viewCenter)
            
            // add arc from the center for each segment (anticlockwise is specified for the arc, but as the view flips the context, it will produce a clockwise arc)
            context.addArc(center: viewCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            
            // fill segment
            context.fillPath()
        }
    }
}
