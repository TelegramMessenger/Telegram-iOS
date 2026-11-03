import Foundation
import UIKit
import Display

final class MirroringLayer: SimpleLayer {
    var targetLayer: CALayer?
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var position: CGPoint {
        get {
            return super.position
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.position = value
            }
            super.position = value
        }
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override var anchorPoint: CGPoint {
        get {
            return super.anchorPoint
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.anchorPoint = value
            }
            super.anchorPoint = value
        }
    }
    
    override var anchorPointZ: CGFloat {
        get {
            return super.anchorPointZ
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.anchorPointZ = value
            }
            super.anchorPointZ = value
        }
    }
    
    override var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.opacity = value
            }
            super.opacity = value
        }
    }
    
    override public var sublayerTransform: CATransform3D {
        get {
            return super.sublayerTransform
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.sublayerTransform = value
            }
            super.sublayerTransform = value
        }
    }
    
    override public var transform: CATransform3D {
        get {
            return super.transform
        } set(value) {
            if let targetLayer = self.targetLayer {
                targetLayer.transform = value
            }
            super.transform = value
        }
    }
    
    override public func add(_ animation: CAAnimation, forKey key: String?) {
        if let targetLayer = self.targetLayer {
            targetLayer.add(animation, forKey: key)
        }
        
        super.add(animation, forKey: key)
    }
    
    override public func removeAllAnimations() {
        if let targetLayer = self.targetLayer {
            targetLayer.removeAllAnimations()
        }
        
        super.removeAllAnimations()
    }
    
    override public func removeAnimation(forKey: String) {
        if let targetLayer = self.targetLayer {
            targetLayer.removeAnimation(forKey: forKey)
        }
        
        super.removeAnimation(forKey: forKey)
    }
}
