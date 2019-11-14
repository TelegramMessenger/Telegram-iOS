import Foundation
import UIKit
import SwiftSignalKit

final class TabBarTapRecognizer: UIGestureRecognizer {
    private let tap: (CGPoint) -> Void
    private let longTap: (CGPoint) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: SwiftSignalKit.Timer?
    
    init(tap: @escaping (CGPoint) -> Void, longTap: @escaping (CGPoint) -> Void) {
        self.tap = tap
        self.longTap = longTap
        
        super.init(target: nil, action: nil)
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.initialLocation == nil {
            self.initialLocation = touches.first?.location(in: self.view)
            let longTapTimer = SwiftSignalKit.Timer(timeout: 0.4, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let initialLocation = strongSelf.initialLocation {
                    strongSelf.initialLocation = nil
                    strongSelf.longTap(initialLocation)
                    strongSelf.state = .ended
                }
            }, queue: Queue.mainQueue())
            self.longTapTimer?.invalidate()
            self.longTapTimer = longTapTimer
            longTapTimer.start()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let initialLocation = self.initialLocation {
            self.initialLocation = nil
            self.longTapTimer?.invalidate()
            self.longTapTimer = nil
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
                self.longTapTimer?.invalidate()
                self.longTapTimer = nil
                self.initialLocation = nil
                self.state = .failed
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        self.state = .failed
    }
}
