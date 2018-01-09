import Foundation

open class ASDisplayNode: NSObject {
    var layer: CALayer {
        preconditionFailure()
    }
    
    var view: UIView {
        preconditionFailure()
    }
    
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
    
    open var position: CGPoint {
        get {
            return self.layer.position
        } set(value) {
            self.layer.position = value
        }
    }
    
    var alpha: CGFloat {
        get {
            return CGFloat(self.layer.opacity)
        } set(value) {
            self.layer.opacity = Float(value)
        }
    }
    
    var backgroundColor: UIColor? {
        get {
            if let backgroundColor = self.layer.backgroundColor {
                return UIColor(cgColor: backgroundColor)
            } else {
                return nil
            }
        } set(value) {
            self.layer.backgroundColor = value?.cgColor
        }
    }
    
    var isLayerBacked: Bool = false
    
    override init() {
        super.init()
    }
    
    func setLayerBlock(_ f: @escaping () -> CALayer) {
        
    }
    
    func setViewBlock(_ f: @escaping () -> UIView) {
        
    }
    
    open func layout() {
    }
    
    open func addSubnode(_ subnode: ASDisplayNode) {
        
    }
    
    open func insertSubnode(belowSubnode: ASDisplayNode) {
        
    }
    
    open func insertSubnode(aboveSubnode: ASDisplayNode) {
        
    }
}
