import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

public class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    public var touchDown: (() -> Void)?
    
    private var touchLocation: CGPoint?
    public var waitForTouchUp = false
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.waitForTouchUp {
            if let touch = touches.first {
                self.touchLocation = touch.location(in: self.view)
            }
        } else if let touchDown = self.touchDown {
            touchDown()
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else {
            return
        }
        
        if let touchLocation = self.touchLocation {
            let location = touch.location(in: self.view)
            let distance = CGPoint(x: location.x - touchLocation.x, y: location.y - touchLocation.y)
            if distance.x * distance.x + distance.y * distance.y > 4.0 {
                self.state = .cancelled
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touchDown = self.touchDown, self.waitForTouchUp {
            touchDown()
        }
    }
    
    override public func reset() {
        self.touchLocation = nil
        
        super.reset()
    }
}
