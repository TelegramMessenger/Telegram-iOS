import Foundation
import UIKit

private func hasHorizontalGestures(_ view: UIView) -> Bool {
    if let view = view as? ListViewBackingView {
        let transform = view.transform
        let angle = Double(atan2f(Float(transform.b), Float(transform.a)))
        if abs(angle - M_PI / 2.0) < 0.001 || abs(angle + M_PI / 2.0) < 0.001 || abs(angle - M_PI * 3.0 / 2.0) < 0.001 {
            return true
        }
    }
    
    if let superview = view.superview {
        return hasHorizontalGestures(superview)
    } else {
        return false
    }
}

class InteractiveTransitionGestureRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        validatedGesture = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
        
        if let target = self.view?.hitTest(self.firstLocation, with: event) {
            if hasHorizontalGestures(target) {
                self.state = .cancelled
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        if !validatedGesture {
            if self.firstLocation.x < 16.0 {
                validatedGesture = true
            } else if translation.x < 0.0 {
                self.state = .failed
            } else if abs(translation.y) > 2.0 && abs(translation.y) > abs(translation.x) * 2.0 {
                self.state = .failed
            } else if abs(translation.x) > 2.0 && abs(translation.y) * 2.0 < abs(translation.x) {
                validatedGesture = true
            }
        }
        
        if validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}
