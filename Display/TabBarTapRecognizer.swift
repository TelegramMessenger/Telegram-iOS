import Foundation
import UIKit

final class TabBarTapRecognizer: UIGestureRecognizer {
    private let tap: (CGPoint) -> Void
    
    private var initialLocation: CGPoint?
    
    init(tap: @escaping (CGPoint) -> Void) {
        self.tap = tap
        
        super.init(target: nil, action: nil)
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let initialLocation = self.initialLocation {
            self.initialLocation = nil
            self.tap(initialLocation)
            self.state = .ended
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            let deltaX = initialLocation.x - location.x
            let deltaY = initialLocation.y - location.y
            if deltaX * deltaX + deltaY * deltaY > 4.0 {
                self.initialLocation = nil
                self.state = .failed
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        self.state = .failed
    }
}
