import Foundation
import UIKit

class InteractiveTransitionGestureRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    
    override init(target: AnyObject?, action: Selector) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        validatedGesture = false
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
        super.touchesBegan(touches, withEvent: event)
        
        self.firstLocation = touches.first!.locationInView(self.view)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
        let location = touches.first!.locationInView(self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        if !validatedGesture {
            if translation.x < 0.0 {
                self.state = .Failed
            } else if abs(translation.y) >= 2.0 {
                self.state = .Failed
            } else if translation.x >= 3.0 && translation.x / 3.0 > translation.y {
                validatedGesture = true
            }
        }
        
        if validatedGesture {
            super.touchesMoved(touches, withEvent: event)
        }
    }
}
