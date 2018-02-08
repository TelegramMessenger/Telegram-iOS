import Foundation
import QuartzCore

public protocol UIScrollViewDelegate {
}

open class UIScrollView: UIView {
    public var contentOffset: CGPoint {
        get {
            return self.bounds.origin
        } set(value) {
            self.bounds.origin = value
        }
    }
    
    public var contentSize: CGSize = CGSize() {
        didSet {
            
        }
    }
    
    public var alwaysBounceVertical: Bool = false
    public var alwaysBounceHorizontal: Bool = false
    
    public func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        self.contentOffset = contentOffset
    }
}
