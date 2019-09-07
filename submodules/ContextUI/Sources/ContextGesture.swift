import Foundation
import UIKit
import AsyncDisplayKit
import Display

public enum ContextGestureTransition {
    case begin
    case update
    case ended(CGFloat)
}

private class TimerTargetWrapper: NSObject {
    let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
    }
    
    @objc func timerEvent() {
        self.f()
    }
}

private let beginDelay: Double = 0.1

private func cancelParentGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
            recognizer.state = .failed
        }
    }
    if let node = (view as? ListViewBackingView)?.target {
        node.cancelSelection()
    }
    if let superview = view.superview {
        cancelParentGestures(view: superview)
    }
}

public final class ContextGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var currentProgress: CGFloat = 0.0
    private var delayTimer: Timer?
    private var isValidated: Bool = false
    
    public var activationProgress: ((CGFloat, ContextGestureTransition) -> Void)?
    public var activated: ((ContextGesture) -> Void)?
    public var externalUpdated: ((UIView?, CGPoint) -> Void)?
    public var externalEnded: (((UIView?, CGPoint)?) -> Void)?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    override public func reset() {
        super.reset()
        
        self.currentProgress = 0.0
        self.delayTimer?.invalidate()
        self.delayTimer = nil
        self.isValidated = false
        self.externalUpdated = nil
        self.externalEnded = nil
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.delayTimer == nil {
            let delayTimer = Timer(timeInterval: beginDelay, target: TimerTargetWrapper { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.delayTimer else {
                    return
                }
                strongSelf.isValidated = true
                strongSelf.activationProgress?(strongSelf.currentProgress, .begin)
            }, selector: #selector(TimerTargetWrapper.timerEvent), userInfo: nil, repeats: false)
            self.delayTimer = delayTimer
            RunLoop.main.add(delayTimer, forMode: .common)
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if let touch = touches.first {
            if #available(iOS 9.0, *) {
                let maxForce: CGFloat = min(3.0, touch.maximumPossibleForce)
                let progress = touch.force / maxForce
                self.currentProgress = progress
                if self.isValidated {
                    self.activationProgress?(progress, .update)
                }
                if touch.force >= maxForce {
                    switch self.state {
                    case .possible:
                        self.delayTimer?.invalidate()
                        self.activated?(self)
                        if let view = self.view?.superview {
                            cancelParentGestures(view: view)
                        }
                        self.state = .began
                    default:
                        break
                    }
                }
            }
            
            self.externalUpdated?(self.view, touch.location(in: self.view))
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let touch = touches.first {
            if !self.currentProgress.isZero, self.isValidated {
                if #available(iOS 9.0, *) {
                    self.activationProgress?(0.0, .ended(self.currentProgress))
                }
            }
            
            self.externalEnded?((self.view, touch.location(in: self.view)))
        }
        
        self.delayTimer?.invalidate()
        
        self.state = .failed
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let touch = touches.first, !self.currentProgress.isZero, self.isValidated {
            if #available(iOS 9.0, *) {
                self.activationProgress?(0.0, .ended(self.currentProgress))
            }
        }
        
        self.delayTimer?.invalidate()
        
        self.state = .failed
    }
    
    public func cancel() {
        if !self.currentProgress.isZero, self.isValidated {
            self.activationProgress?(0.0, .ended(self.currentProgress))
            
            self.delayTimer?.invalidate()
            self.state = .failed
        }
    }
    
    public func endPressedAppearance() {
        if !self.currentProgress.isZero, self.isValidated {
            let previousProgress = self.currentProgress
            self.currentProgress = 0.0
            self.delayTimer?.invalidate()
            self.isValidated = false
            self.activationProgress?(0.0, .ended(previousProgress))
        }
    }
}
