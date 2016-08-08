import Foundation
import AsyncDisplayKit

class ASTransformLayer: CATransformLayer {
    override var contents: AnyObject? {
        get {
            return nil
        } set(value) {
            
        }
    }
    
    override var backgroundColor: CGColor? {
        get {
            return nil
        } set(value) {
            
        }
    }
    
    override func setNeedsLayout() {
    }
    
    override func layoutSublayers() {
    }
}

class ASTransformView: UIView {
    override class var layerClass: AnyClass {
        return ASTransformLayer.self
    }
}

public class ASTransformLayerNode: ASDisplayNode {
    public override init() {
        super.init(layerBlock: {
            return ASTransformLayer()
        }, didLoad: nil)
    }
}

public class ASTransformViewNode: ASDisplayNode {
    public override init() {
        super.init(viewBlock: {
            return ASTransformView()
        }, didLoad: nil)
    }
}

public class ASTransformNode: ASDisplayNode {
    public init(layerBacked: Bool = true) {
        if layerBacked {
            super.init(layerBlock: {
                return ASTransformLayer()
            }, didLoad: nil)
        } else {
            super.init(viewBlock: {
                return ASTransformView()
            }, didLoad: nil)
        }
    }
}
