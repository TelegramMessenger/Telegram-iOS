import Foundation
import UIKit

private func hasHorizontalGestures(_ view: UIView, point: CGPoint?) -> Bool {
    if view.disablesInteractiveTransitionGestureRecognizer {
        return true
    }
    if let disablesInteractiveTransitionGestureRecognizerNow = view.disablesInteractiveTransitionGestureRecognizerNow, disablesInteractiveTransitionGestureRecognizerNow() {
        return true
    }
    
    if let point = point, let test = view.interactiveTransitionGestureRecognizerTest, test(point) {
        return true
    }
    
    if let view = view as? ListViewBackingView {
        let transform = view.transform
        let angle: Double = Double(atan2f(Float(transform.b), Float(transform.a)))
        let term1: Double = abs(angle - Double.pi / 2.0)
        let term2: Double = abs(angle + Double.pi / 2.0)
        let term3: Double = abs(angle - Double.pi * 3.0 / 2.0)
        if term1 < 0.001 || term2 < 0.001 || term3 < 0.001 {
            return true
        }
    }
    
    if let superview = view.superview {
        return hasHorizontalGestures(superview, point: point != nil ? view.convert(point!, to: superview) : nil)
    } else {
        return false
    }
}

class InteractiveTransitionGestureRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    private let canBegin: () -> Bool
    
    init(target: Any?, action: Selector?, canBegin: @escaping () -> Bool) {
        self.canBegin = canBegin
        
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        validatedGesture = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if !self.canBegin() {
            self.state = .failed
            return
        }
        
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
        
        if let target = self.view?.hitTest(self.firstLocation, with: event) {
            if hasHorizontalGestures(target, point: self.view?.convert(self.firstLocation, to: target)) {
                self.state = .cancelled
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        if !validatedGesture {
            if self.firstLocation.x < 16.0 {
                validatedGesture = true
            } else if translation.x < 0.0 {
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
