import Foundation
import UIKit

final class ListViewReorderingGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> Bool
    private let ended: () -> Void
    private let moved: (CGFloat) -> Void
    
    private var initialLocation: CGPoint?
    
    init(shouldBegin: @escaping (CGPoint) -> Bool, ended: @escaping () -> Void, moved: @escaping (CGFloat) -> Void) {
        self.shouldBegin = shouldBegin
        self.ended = ended
        self.moved = moved
        
        super.init(target: nil, action: nil)
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.state = .failed
            self.ended()
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view), self.shouldBegin(location) {
                self.initialLocation = location
                self.state = .began
            } else {
                self.state = .failed
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if self.state == .began || self.state == .changed {
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if self.state == .began || self.state == .changed {
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            let offset = location.y - initialLocation.y
            self.moved(offset)
        }
    }
}
