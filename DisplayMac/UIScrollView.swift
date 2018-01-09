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
    
    public var alwaysBoundsVertical: Bool = false
    public var alwaysBoundsHorizontal: Bool = false
}
