import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

public class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    public var touchDown: (() -> Void)?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touchDown = self.touchDown {
            touchDown()
        }
    }
}
