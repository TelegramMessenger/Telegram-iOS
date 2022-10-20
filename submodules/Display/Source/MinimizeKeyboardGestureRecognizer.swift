import Foundation
import UIKit

final class MinimizeKeyboardGestureRecognizer: UISwipeGestureRecognizer, UIGestureRecognizerDelegate {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
        self.delegate = self
        
        self.direction = [.left, .right]
        self.numberOfTouchesRequired = 2
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
