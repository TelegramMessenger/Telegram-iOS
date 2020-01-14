import Foundation
import UIKit

public class DirectionalPanGestureRecognizer: UIPanGestureRecognizer {
    private var validatedGesture = false
    private var firstLocation: CGPoint = CGPoint()
    
    public var shouldBegin: ((CGPoint) -> Bool)?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        let point = touch.location(in: self.view)
        if let shouldBegin = self.shouldBegin, !shouldBegin(point) {
            self.state = .failed
            return
        }
        
        self.firstLocation = point
        
        if let target = self.view?.hitTest(self.firstLocation, with: event) {
            if target == self.view {
                self.validatedGesture = true
            }
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        if !self.validatedGesture {
            if absTranslationX > 4.0 && absTranslationX > absTranslationY * 2.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationX * 2.0 < absTranslationY {
                self.validatedGesture = true
            }
        }
        
        if self.validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}

