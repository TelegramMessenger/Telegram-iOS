import Foundation
import UIKit

class ChatSwipeToReplyRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    
    var shouldBegin: (() -> Bool)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        self.validatedGesture = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.firstLocation = touch.location(in: self.view)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        if !validatedGesture {
            if translation.x > 0.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationY > absTranslationX * 2.0 {
                self.state = .failed
            } else if absTranslationX > 2.0 && absTranslationY * 2.0 < absTranslationX {
                validatedGesture = true
            }
        }
        
        if validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}
