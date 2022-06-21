import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import AsyncDisplayKit

private func cancelScrollViewGestures(view: UIView?) {
    if let view = view {
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if let recognizer = recognizer as? UIPanGestureRecognizer {
                    switch recognizer.state {
                    case .began, .possible:
                        recognizer.state = .ended
                    default:
                        break
                    }
                }
            }
        }
        cancelScrollViewGestures(view: view.superview)
    }
}

private func cancelOtherGestures(gesture: TapLongTapOrDoubleTapGestureRecognizer, view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
            if let recognizer = recognizer as? TapLongTapOrDoubleTapGestureRecognizer, recognizer !== gesture {
                recognizer.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelOtherGestures(gesture: gesture, view: subview)
    }
}

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
    
    @objc func holdEvent() {
        self.target?.holdEvent()
    }
}

public enum TapLongTapOrDoubleTapGesture {
    case tap
    case doubleTap
    case longTap
    case hold
}

public enum TapLongTapOrDoubleTapGestureRecognizerAction {
    case waitForDoubleTap
    case waitForSingleTap
    case waitForHold(timeout: Double, acceptTap: Bool)
    case fail
    case keepWithSingleTap
}

public final class TapLongTapOrDoubleTapGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var touchLocationAndTimestamp: (CGPoint, Double)?
    private var touchCount: Int = 0
    private var tapCount: Int = 0
    
    private var timer: Foundation.Timer?
    public private(set) var lastRecognizedGestureAndLocation: (TapLongTapOrDoubleTapGesture, CGPoint)?
    
    public var tapActionAtPoint: ((CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction)?
    public var longTap: ((CGPoint, TapLongTapOrDoubleTapGestureRecognizer) -> Void)?
    private var recognizedLongTap: Bool = false
    public var externalUpdated: ((UIView?, CGPoint) -> Void)?
    public var externalEnded: (((UIView?, CGPoint)?) -> Void)?
    public var highlight: ((CGPoint?) -> Void)?
    
    public var hapticFeedback: HapticFeedback?
    
    private var highlightPoint: CGPoint?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return false
    }
    
    override public func reset() {
        self.timer?.invalidate()
        self.timer = nil
        self.touchLocationAndTimestamp = nil
        self.tapCount = 0
        self.touchCount = 0
        self.hapticFeedback = nil
        self.recognizedLongTap = false
        
        if self.highlightPoint != nil {
            self.highlightPoint = nil
            self.highlight?(nil)
        }
        
        self.externalUpdated = nil
        self.externalEnded = nil
        
        super.reset()
    }
    
    public func cancel() {
        self.state = .cancelled
    }
    
    fileprivate func longTapEvent() {
        self.timer?.invalidate()
        self.timer = nil
        if let (location, _) = self.touchLocationAndTimestamp {
            self.lastRecognizedGestureAndLocation = (.longTap, location)
            if let longTap = self.longTap {
                if let window = self.view?.window {
                    cancelOtherGestures(gesture: self, view: window)
                }
                self.recognizedLongTap = true
                self.state = .began
                longTap(location, self)
                cancelScrollViewGestures(view: self.view?.superview)
                return
            }
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
    
    fileprivate func holdEvent() {
        self.timer?.invalidate()
        self.timer = nil
        if let (location, _) = self.touchLocationAndTimestamp {
            self.hapticFeedback?.tap()
            self.lastRecognizedGestureAndLocation = (.hold, location)
        } else {
            self.lastRecognizedGestureAndLocation = nil
        }
        self.state = .began
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.lastRecognizedGestureAndLocation = nil
        
        super.touchesBegan(touches, with: event)
        
        self.touchCount += touches.count
        
        if let touch = touches.first {
            let touchLocation = touch.location(in: self.view)
            
            if self.highlightPoint != touchLocation {
                self.highlightPoint = touchLocation
                self.highlight?(touchLocation)
            }
            
            if let hitResult = self.view?.hitTest(touch.location(in: self.view), with: event), let _ = hitResult as? UIButton {
                self.state = .failed
                return
            }
            
            self.tapCount += 1
            if self.tapCount == 2 && self.touchCount == 1 {
                self.timer?.invalidate()
                self.timer = nil
                self.lastRecognizedGestureAndLocation = (.doubleTap, self.location(in: self.view))
                self.state = .ended
            } else {
                let touchLocationAndTimestamp = (touch.location(in: self.view), CACurrentMediaTime())
                self.touchLocationAndTimestamp = touchLocationAndTimestamp
                
                var tapAction: TapLongTapOrDoubleTapGestureRecognizerAction = .waitForDoubleTap
                if let tapActionAtPoint = self.tapActionAtPoint {
                    tapAction = tapActionAtPoint(touchLocationAndTimestamp.0)
                }
                
                switch tapAction {
                    case .keepWithSingleTap:
                        break
                    case .waitForSingleTap, .waitForDoubleTap:
                        self.timer?.invalidate()
                        let timer = Timer(timeInterval: 0.3, target: TapLongTapOrDoubleTapGestureRecognizerTimerTarget(target: self), selector: #selector(TapLongTapOrDoubleTapGestureRecognizerTimerTarget.longTapEvent), userInfo: nil, repeats: false)
                        self.timer = timer
                        RunLoop.main.add(timer, forMode: .common)
                    case let .waitForHold(timeout, _):
                        self.hapticFeedback = HapticFeedback()
                        self.hapticFeedback?.prepareTap()
                        let timer = Timer(timeInterval: timeout, target: TapLongTapOrDoubleTapGestureRecognizerTimerTarget(target: self), selector: #selector(TapLongTapOrDoubleTapGestureRecognizerTimerTarget.holdEvent), userInfo: nil, repeats: false)
                        self.timer = timer
                        RunLoop.main.add(timer, forMode: .common)
                    case .fail:
                        self.state = .failed
                }
            }
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else {
            return
        }
        
        if let (gesture, _) = self.lastRecognizedGestureAndLocation, case .hold = gesture {
            let location = touch.location(in: self.view)
            self.lastRecognizedGestureAndLocation = (.hold, location)
            self.state = .changed
            return
        }
        
        if self.recognizedLongTap, let externalUpdated = self.externalUpdated {
            let location = touch.location(in: self.view)
            externalUpdated(self.view, location)
            return
        }
        
        if let touch = touches.first, let (touchLocation, _) = self.touchLocationAndTimestamp {
            let location = touch.location(in: self.view)
            let distance = CGPoint(x: location.x - touchLocation.x, y: location.y - touchLocation.y)
            if distance.x * distance.x + distance.y * distance.y > 4.0 {
                self.state = .cancelled
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.touchCount -= touches.count
        
        if self.highlightPoint != nil {
            self.highlightPoint = nil
            self.highlight?(nil)
        }
        
        self.timer?.invalidate()
        
        if let (gesture, location) = self.lastRecognizedGestureAndLocation, case .hold = gesture {
            self.lastRecognizedGestureAndLocation = (.hold, location)
            self.state = .ended
            return
        }
        
        if let (gesture, location) = self.lastRecognizedGestureAndLocation, case .longTap = gesture, self.recognizedLongTap {
            self.externalEnded?((self.view, location))
            self.state = .cancelled
            return
        }
        
        if self.tapCount == 1 {
            var tapAction: TapLongTapOrDoubleTapGestureRecognizerAction = .waitForDoubleTap
            if let tapActionAtPoint = self.tapActionAtPoint, let (touchLocation, _) = self.touchLocationAndTimestamp {
                tapAction = tapActionAtPoint(touchLocation)
            }
            
            switch tapAction {
                case .waitForSingleTap, .keepWithSingleTap:
                    if let (touchLocation, _) = self.touchLocationAndTimestamp {
                        self.lastRecognizedGestureAndLocation = (.tap, touchLocation)
                    }
                    self.state = .ended
                case .waitForDoubleTap:
                    self.state = .began
                    let timer = Timer(timeInterval: 0.16, target: TapLongTapOrDoubleTapGestureRecognizerTimerTarget(target: self), selector: #selector(TapLongTapOrDoubleTapGestureRecognizerTimerTarget.tapEvent), userInfo: nil, repeats: false)
                    self.timer = timer
                    RunLoop.main.add(timer, forMode: .common)
                case let .waitForHold(_, acceptTap):
                    if let (touchLocation, _) = self.touchLocationAndTimestamp, acceptTap {
                        if self.state != .began {
                            self.lastRecognizedGestureAndLocation = (.tap, touchLocation)
                            self.state = .began
                        }
                    }
                    self.state = .ended
                case .fail:
                    self.state = .failed
            }
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.touchCount -= touches.count
        
        if self.highlightPoint != nil {
            self.highlightPoint = nil
            self.highlight?(nil)
        }
        
        self.externalEnded?(nil)
        
        self.state = .cancelled
    }
}
