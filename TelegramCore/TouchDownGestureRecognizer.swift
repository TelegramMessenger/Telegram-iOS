import Foundation
import UIKit.UIGestureRecognizerSubclass

private class TouchDownGestureRecognizerTimerTarget: NSObject {
    weak var target: TouchDownGestureRecognizer?
    
    init(target: TouchDownGestureRecognizer) {
        self.target = target
        
        super.init()
    }
    
    @objc func event() {
        self.target?.timerEvent()
    }
}

class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var touchLocation = CGPoint()
    private var timer: Foundation.Timer?
    
    override init(target: AnyObject?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    override func reset() {
        self.timer?.invalidate()
        self.timer = nil
        
        super.reset()
    }
    
    func timerEvent() {
        self.state = .began
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            self.touchLocation = touch.location(in: self.view)
        }
        
        self.timer?.invalidate()
        self.timer = Timer(timeInterval: 0.08, target: TouchDownGestureRecognizerTimerTarget(target: self), selector: #selector(TouchDownGestureRecognizerTimerTarget.event), userInfo: nil, repeats: false)
        
        if let timer = self.timer {
            RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            let distance = CGPoint(x: location.x - self.touchLocation.x, y: location.y - self.touchLocation.y)
            if distance.x * distance.x + distance.y * distance.y > 4.0 {
                self.state = .cancelled
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .ended
    }
}
