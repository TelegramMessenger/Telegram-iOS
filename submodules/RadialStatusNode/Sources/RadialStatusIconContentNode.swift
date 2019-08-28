import Foundation
import UIKit
import Display
import AsyncDisplayKit

enum RadialStatusIcon {
    case custom(UIImage)
    case play(UIColor)
    case pause(UIColor)
}

private final class RadialStatusIconContentNodeParameters: NSObject {
    let icon: RadialStatusIcon
    
    init(icon: RadialStatusIcon) {
        self.icon = icon
        
        super.init()
    }
}

final class RadialStatusIconContentNode: RadialStatusContentNode {
    private let icon: RadialStatusIcon
    
    init(icon: RadialStatusIcon, synchronous: Bool) {
        self.icon = icon
        
        super.init()
        
        self.displaysAsynchronously = !synchronous
        self.isLayerBacked = true
        self.isOpaque = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return RadialStatusIconContentNodeParameters(icon: self.icon)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        if let parameters = parameters as? RadialStatusIconContentNodeParameters {
            let diameter = min(bounds.size.width, bounds.size.height)
            switch parameters.icon {
                case let .play(color):
                    context.setFillColor(color.cgColor)
                    
                    let factor = diameter / 50.0
                    
                    let size = CGSize(width: 15.0, height: 18.0)
                    context.translateBy(x: (diameter - size.width) / 2.0 + 1.5, y: (diameter - size.height) / 2.0)
                    if (diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: factor, y: factor)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                    context.fillPath()
                    if (diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    context.translateBy(x: -(diameter - size.width) / 2.0 - 1.5, y: -(diameter - size.height) / 2.0)
                case let .pause(color):
                    context.setFillColor(color.cgColor)
                    
                    let factor = diameter / 50.0
                    
                    let size = CGSize(width: 15.0, height: 16.0)
                    context.translateBy(x: (diameter - size.width) / 2.0, y: (diameter - size.height) / 2.0)
                    if (diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: factor, y: factor)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
                    context.fillPath()
                    if (diameter < 40.0) {
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0 / 0.8, y: 1.0 / 0.8)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    }
                    context.translateBy(x: -(diameter - size.width) / 2.0, y: -(diameter - size.height) / 2.0)
                case let .custom(image):
                    image.draw(at: CGPoint(x: floor((diameter - image.size.width) / 2.0), y: floor((diameter - image.size.height) / 2.0)))
            }
        }
    }
}
