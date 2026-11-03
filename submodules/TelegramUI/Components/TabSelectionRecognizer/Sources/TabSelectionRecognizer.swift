import Foundation
import UIKit

public final class TabSelectionRecognizer: UIGestureRecognizer {
    private var initialLocation: CGPoint?
    private var currentLocation: CGPoint?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
    }
    
    public override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
        self.currentLocation = self.initialLocation
        
        self.state = .began
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        self.currentLocation = touches.first?.location(in: self.view)
        
        self.state = .changed
    }
    
    public func translation(in: UIView?) -> CGPoint {
        if let initialLocation = self.initialLocation, let currentLocation = self.currentLocation {
            return CGPoint(x: currentLocation.x - initialLocation.x, y: currentLocation.y - initialLocation.y)
        }
        return CGPoint()
    }
}
