import Foundation

public enum UIGestureRecognizerState : Int {
    case possible
    case began
    case changed
    case ended
    case cancelled
    case failed
}
open class UIGestureRecognizer: NSObject {
    public init(target: Any?, action: Selector?) {
        super.init()
    }
    
    open var state: UIGestureRecognizerState = .possible {
        didSet {
            
        }
    }
    
    weak open var delegate: UIGestureRecognizerDelegate?
    
    open var isEnabled: Bool = true

    open var view: UIView? {
        return nil
    }
    
    open var cancelsTouchesInView: Bool = true
    open var delaysTouchesBegan: Bool = false
    open var delaysTouchesEnded: Bool = true
    
    open func location(in view: UIView?) -> CGPoint {
        return CGPoint()
    }
    
    open var numberOfTouches: Int {
        return 0
    }
}

@objc public protocol UIGestureRecognizerDelegate : NSObjectProtocol {
    @objc optional func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    @objc optional func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    @objc optional func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
}
