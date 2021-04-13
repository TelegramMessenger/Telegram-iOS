import Foundation
import UIKit

public final class WindowPanRecognizer: UIGestureRecognizer {
    public var began: ((CGPoint) -> Void)?
    public var moved: ((CGPoint) -> Void)?
    public var ended: ((CGPoint, CGPoint?) -> Void)?
    
    private var previousPoints: [(CGPoint, Double)] = []
    
    override public func reset() {
        super.reset()
        
        self.previousPoints.removeAll()
    }

    public func cancel() {
        self.state = .cancelled
    }
    
    private func addPoint(_ point: CGPoint) {
        self.previousPoints.append((point, CACurrentMediaTime()))
        if self.previousPoints.count > 6 {
            self.previousPoints.removeFirst()
        }
    }
    
    private func estimateVerticalVelocity() -> CGFloat {
        let timestamp = CACurrentMediaTime()
        var sum: CGFloat = 0.0
        var count = 0
        if self.previousPoints.count > 1 {
            for i in 1 ..< self.previousPoints.count {
                if self.previousPoints[i].1 >= timestamp - 0.1 {
                    sum += (self.previousPoints[i].0.y - self.previousPoints[i - 1].0.y) / CGFloat(self.previousPoints[i].1 - self.previousPoints[i - 1].1)
                    count += 1
                }
            }
        }
        
        if count != 0 {
            return sum / CGFloat(count * 5)
        } else {
            return 0.0
        }
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            self.addPoint(location)
            self.began?(location)
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            self.addPoint(location)
            self.moved?(location)
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            self.addPoint(location)
            self.ended?(location, CGPoint(x: 0.0, y: self.estimateVerticalVelocity()))
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let touch = touches.first {
            self.ended?(touch.location(in: self.view), nil)
        }
    }
}
