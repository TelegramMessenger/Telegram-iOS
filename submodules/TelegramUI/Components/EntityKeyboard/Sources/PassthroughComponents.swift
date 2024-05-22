import Foundation
import UIKit
import Display
import ComponentFlow

public class PassthroughLayer: CALayer {
    public var mirrorLayer: CALayer?
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var position: CGPoint {
        get {
            return super.position
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.position = value
            }
            super.position = value
        }
    }
    
    override public var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override public var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.opacity = value
            }
            super.opacity = value
        }
    }
    
    override public var sublayerTransform: CATransform3D {
        get {
            return super.sublayerTransform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.sublayerTransform = value
            }
            super.sublayerTransform = value
        }
    }
    
    override public var transform: CATransform3D {
        get {
            return super.transform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.transform = value
            }
            super.transform = value
        }
    }
    
    override public func add(_ animation: CAAnimation, forKey key: String?) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        
        super.add(animation, forKey: key)
    }
    
    override public func removeAllAnimations() {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAllAnimations()
        }
        
        super.removeAllAnimations()
    }
    
    override public func removeAnimation(forKey: String) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        
        super.removeAnimation(forKey: forKey)
    }
}

open class PassthroughView: UIView {
    override public static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    public let passthroughView: UIView
    
    override public init(frame: CGRect) {
        self.passthroughView = UIView()
        
        super.init(frame: frame)
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.passthroughView.layer
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PassthroughShapeLayer: CAShapeLayer {
    var mirrorLayer: CAShapeLayer?
    
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
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.position = value
            }
            super.position = value
        }
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.bounds = value
            }
            super.bounds = value
        }
    }
    
    override var opacity: Float {
        get {
            return super.opacity
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.opacity = value
            }
            super.opacity = value
        }
    }
    
    override var sublayerTransform: CATransform3D {
        get {
            return super.sublayerTransform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.sublayerTransform = value
            }
            super.sublayerTransform = value
        }
    }
    
    override var transform: CATransform3D {
        get {
            return super.transform
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.transform = value
            }
            super.transform = value
        }
    }
    
    override var path: CGPath? {
        get {
            return super.path
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.path = value
            }
            super.path = value
        }
    }
    
    override var fillColor: CGColor? {
        get {
            return super.fillColor
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.fillColor = value
            }
            super.fillColor = value
        }
    }
    
    override var fillRule: CAShapeLayerFillRule {
        get {
            return super.fillRule
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.fillRule = value
            }
            super.fillRule = value
        }
    }
    
    override var strokeColor: CGColor? {
        get {
            return super.strokeColor
        } set(value) {
            /*if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeColor = value
            }*/
            super.strokeColor = value
        }
    }
    
    override var strokeStart: CGFloat {
        get {
            return super.strokeStart
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeStart = value
            }
            super.strokeStart = value
        }
    }
    
    override var strokeEnd: CGFloat {
        get {
            return super.strokeEnd
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.strokeEnd = value
            }
            super.strokeEnd = value
        }
    }
    
    override var lineWidth: CGFloat {
        get {
            return super.lineWidth
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineWidth = value
            }
            super.lineWidth = value
        }
    }
    
    override var miterLimit: CGFloat {
        get {
            return super.miterLimit
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.miterLimit = value
            }
            super.miterLimit = value
        }
    }
    
    override var lineCap: CAShapeLayerLineCap {
        get {
            return super.lineCap
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineCap = value
            }
            super.lineCap = value
        }
    }
    
    override var lineJoin: CAShapeLayerLineJoin {
        get {
            return super.lineJoin
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineJoin = value
            }
            super.lineJoin = value
        }
    }
    
    override var lineDashPhase: CGFloat {
        get {
            return super.lineDashPhase
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineDashPhase = value
            }
            super.lineDashPhase = value
        }
    }
    
    override var lineDashPattern: [NSNumber]? {
        get {
            return super.lineDashPattern
        } set(value) {
            if let mirrorLayer = self.mirrorLayer {
                mirrorLayer.lineDashPattern = value
            }
            super.lineDashPattern = value
        }
    }
    
    override func add(_ animation: CAAnimation, forKey key: String?) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.add(animation, forKey: key)
        }
        
        super.add(animation, forKey: key)
    }
    
    override func removeAllAnimations() {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAllAnimations()
        }
        
        super.removeAllAnimations()
    }
    
    override func removeAnimation(forKey: String) {
        if let mirrorLayer = self.mirrorLayer {
            mirrorLayer.removeAnimation(forKey: forKey)
        }
        
        super.removeAnimation(forKey: forKey)
    }
}
