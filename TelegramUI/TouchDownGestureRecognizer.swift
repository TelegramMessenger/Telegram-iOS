import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var touchDown: (() -> Void)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touchDown = self.touchDown {
            touchDown()
        }
    }
}
