import Foundation
import UIKit

public class ChatSwipeToReplyRecognizer: UIPanGestureRecognizer {
    public var validatedGesture = false
    public var firstLocation: CGPoint = CGPoint()
    public var allowBothDirections: Bool = true
    
    public var shouldBegin: (() -> Bool)?
    
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
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.firstLocation = touch.location(in: self.view)
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        if !self.validatedGesture {
            if !self.allowBothDirections && translation.x > 0.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationY > absTranslationX * 2.0 {
                self.state = .failed
            } else if absTranslationX > 2.0 && absTranslationY * 2.0 < absTranslationX {
                self.validatedGesture = true
            }
        }
        
        if self.validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}
