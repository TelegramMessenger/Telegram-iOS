import UIKit

public final class NullActionClass: NSObject, CAAction {
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

public let nullAction = NullActionClass()

open class SimpleLayer: CALayer {
    override open func action(forKey event: String) -> CAAction? {
        return nullAction
    }
    
    override public init() {
        super.init()
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class SimpleShapeLayer: CAShapeLayer {
    override open func action(forKey event: String) -> CAAction? {
        return nullAction
    }
    
    override public init() {
        super.init()
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
