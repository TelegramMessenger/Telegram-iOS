import Foundation
import UIKit
import AsyncDisplayKit

private final class RadialStatusBackgroundNodeParameters: NSObject {
    let color: UIColor
    
    init(color: UIColor) {
        self.color = color
    }
}

final class RadialStatusBackgroundNode: ASDisplayNode {
    var color: UIColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    init(color: UIColor, synchronous: Bool) {
        self.color = color
        
        super.init()
        
        self.displaysAsynchronously = !synchronous
        self.isLayerBacked = true
        self.isOpaque = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialStatusBackgroundNodeParameters(color: self.color)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialStatusBackgroundNodeParameters {
            context.setFillColor(parameters.color.cgColor)
            context.fillEllipse(in: bounds)
        }
    }
}
