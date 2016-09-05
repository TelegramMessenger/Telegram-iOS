import Foundation
import UIKit.UIGestureRecognizerSubclass

private class TapLongTapOrDoubleTapGestureRecognizerTimerTarget: NSObject {
    weak var target: TapLongTapOrDoubleTapGestureRecognizer?
    
    init(target: TapLongTapOrDoubleTapGestureRecognizer) {
        self.target = target
        
        super.init()
    }
    
    @objc func longTapEvent() {
        self.target?.longTapEvent()
    }
    
    @objc func tapEvent() {
        self.target?.tapEvent()
    }
}

enum TapLongTapOrDoubleTapGesture {
    case tap
    case doubleTap
    case longTap
}

final class TapLongTapOrDoubleTapGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var touchLocationAndTimestamp: (CGPoint, Double)?
    private var tapCount: Int = 0
    
    private var timer: Foundation.Timer?
    private(set) var lastRecognizedGestureAndLocation: (TapLongTapOrDoubleTapGesture, CGPoint)?
    
    var doNotWaitForDoubleTapAtPoint: ((CGPoint) -> Bool)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return false
    }
    
    override func reset() {
        self.timer?.invalidate()
        self.timer = nil
        self.touchLocationAndTimestamp = nil
        self.tapCount = 0
        
        super.reset()
    }
    
    fileprivate func longTapEvent() {
        self.timer?.invalidate()
        self.timer = nil
        if let (location, _) = self.touchLocationAndTimestamp {
            self.lastRecognizedGestureAndLocation = (.longTap, location)
        } else {
            self.lastRecognizedGestureAndLocation = nil
        }
        self.state = .ended
    }
    
    fileprivate func tapEvent() {
        self.timer?.invalidate()
        self.timer = nil
        if let (location, _) = self.touchLocationAndTimestamp {
            self.lastRecognizedGestureAndLocation = (.tap, location)
        } else {
            self.lastRecognizedGestureAndLocation = nil
        }
        self.state = .ended
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            self.tapCount += 1
            if self.tapCount == 2 {
                self.timer?.invalidate()
                self.timer = nil
                self.lastRecognizedGestureAndLocation = (.doubleTap, self.location(in: self.view))
                self.state = .ended
            } else {
                self.touchLocationAndTimestamp = (touch.location(in: self.view), CACurrentMediaTime())
                
                self.timer?.invalidate()
                let timer = Timer(timeInterval: 0.3, target: TapLongTapOrDoubleTapGestureRecognizerTimerTarget(target: self), selector: #selector(TapLongTapOrDoubleTapGestureRecognizerTimerTarget.longTapEvent), userInfo: nil, repeats: false)
                self.timer = timer
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touches.first, let (touchLocation, _) = self.touchLocationAndTimestamp {
            let location = touch.location(in: self.view)
            let distance = CGPoint(x: location.x - touchLocation.x, y: location.y - touchLocation.y)
            if distance.x * distance.x + distance.y * distance.y > 4.0 {
                self.state = .cancelled
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.timer?.invalidate()
        
        if self.tapCount == 1 {
            if let doNotWaitForDoubleTapAtPoint = self.doNotWaitForDoubleTapAtPoint, let (touchLocation, _) = self.touchLocationAndTimestamp, doNotWaitForDoubleTapAtPoint(touchLocation) {
                self.lastRecognizedGestureAndLocation = (.tap, touchLocation)
                self.state = .ended
            } else {
                self.state = .began
                let timer = Timer(timeInterval: 0.2, target: TapLongTapOrDoubleTapGestureRecognizerTimerTarget(target: self), selector: #selector(TapLongTapOrDoubleTapGestureRecognizerTimerTarget.tapEvent), userInfo: nil, repeats: false)
                self.timer = timer
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
}
