import Foundation
import QuartzCore

open class UIView: NSObject {
    public let layer: CALayer
    
    open var frame: CGRect {
        get {
            return self.layer.frame
        } set(value) {
            self.layer.frame = value
        }
    }
    
    open var bounds: CGRect {
        get {
            return self.layer.bounds
        } set(value) {
            self.layer.bounds = value
        }
    }
    
    open var center: CGPoint {
        get {
            return self.layer.position
        } set(value) {
            self.layer.position = value
        }
    }
    
    init(frame: CGRect) {
        self.layer = CALayer()
        self.layer.frame = frame
        
        super.init()
    }
    
    convenience override init() {
        self.init(frame: CGRect())
    }
    
    static func animationDurationFactor() -> Double {
        return 1.0
    }
    
    public func bringSubview(toFront: UIView) {
        
    }
}
