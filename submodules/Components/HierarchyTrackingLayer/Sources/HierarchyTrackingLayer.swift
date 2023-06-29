import UIKit

private final class NullActionClass: NSObject, CAAction {
    @objc public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private let nullAction = NullActionClass()

open class HierarchyTrackingLayer: CALayer {
    public var didEnterHierarchy: (() -> Void)?
    public var didExitHierarchy: (() -> Void)?
    public var isInHierarchyUpdated: ((Bool) -> Void)?
    
    public private(set) var isInHierarchy: Bool = false {
        didSet {
            if self.isInHierarchy != oldValue {
                self.isInHierarchyUpdated?(self.isInHierarchy)
            }
        }
    }
    
    override open func action(forKey event: String) -> CAAction? {
        if event == kCAOnOrderIn {
            self.isInHierarchy = true
            self.didEnterHierarchy?()
        } else if event == kCAOnOrderOut {
            self.isInHierarchy = false
            self.didExitHierarchy?()
        }
        return nullAction
    }
}
