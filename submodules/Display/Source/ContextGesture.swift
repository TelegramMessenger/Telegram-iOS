import Foundation
import UIKit
import AsyncDisplayKit

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

public func cancelParentGestures(view: UIView, ignore: [UIGestureRecognizer] = []) {
    if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
            if ignore.contains(where: { $0 === recognizer }) {
                continue
            }
            recognizer.state = .failed
        }
    }
    if let node = (view as? ListViewBackingView)?.target {
        node.cancelSelection()
    }
    if let node = view.asyncdisplaykit_node as? HighlightTrackingButtonNode {
        node.highligthedChanged(false)
    }
    if let superview = view.superview {
        cancelParentGestures(view: superview, ignore: ignore)
    }
}

private func cancelOtherGestures(gesture: ContextGesture, view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for recognizer in gestureRecognizers {
            if let recognizer = recognizer as? ContextGesture, recognizer !== gesture {
                recognizer.cancel()
            } else if let recognizer = recognizer as? ListViewTapGestureRecognizer {
                recognizer.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelOtherGestures(gesture: gesture, view: subview)
    }
}

public final class ContextGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
    public var beginDelay: Double = 0.12
    public var activateOnTap: Bool = false
    private var currentProgress: CGFloat = 0.0
    private var delayTimer: Timer?
    private var animator: DisplayLinkAnimator?
    private var isValidated: Bool = false
    private var wasActivated: Bool = false
    
    public var shouldBegin: ((CGPoint) -> Bool)?
    public var activationProgress: ((CGFloat, ContextGestureTransition) -> Void)?
    public var activated: ((ContextGesture, CGPoint) -> Void)?
    public var externalUpdated: ((UIView?, CGPoint) -> Void)?
    public var externalEnded: (((UIView?, CGPoint)?) -> Void)?
    public var activatedAfterCompletion: ((CGPoint, Bool) -> Void)?
    public var cancelGesturesOnActivation: (() -> Void)?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    override public func reset() {
        super.reset()
        
        self.endPressedAppearance()
        
        self.currentProgress = 0.0
        self.delayTimer?.invalidate()
        self.delayTimer = nil
        self.isValidated = false
        self.externalUpdated = nil
        self.externalEnded = nil
        self.animator?.invalidate()
        self.animator = nil
        self.wasActivated = false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else {
            return
        }
        let location = touch.location(in: self.view)
        
        if let shouldBegin = self.shouldBegin {
            if !shouldBegin(location) {
                self.state = .failed
                return
            }
        }
        
        let windowLocation = touch.location(in: nil)
        if windowLocation.x < 8.0 {
            self.state = .failed
            return
        }
        
        if self.delayTimer == nil {
            let delayTimer = Timer(timeInterval: self.beginDelay, target: TimerTargetWrapper { [weak self] in
                guard let strongSelf = self, let _ = strongSelf.delayTimer else {
                    return
                }
                strongSelf.isValidated = true
                if strongSelf.animator == nil {
                    strongSelf.animator = DisplayLinkAnimator(duration: 0.2, from: 0.0, to: 1.0, update: { value in
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.isValidated {
                            strongSelf.currentProgress = value
                            strongSelf.activationProgress?(value, .update)
                        }
                    }, completion: {
                        guard let strongSelf = self else {
                            return
                        }
                        switch strongSelf.state {
                        case .possible:
                            strongSelf.delayTimer?.invalidate()
                            strongSelf.animator?.invalidate()
                            strongSelf.activated?(strongSelf, location)
                            strongSelf.wasActivated = true
                            if let view = strongSelf.view {
                                if let window = view.window {
                                    cancelOtherGestures(gesture: strongSelf, view: window)
                                }
                                strongSelf.cancelGesturesOnActivation?()
                                cancelParentGestures(view: view, ignore: [strongSelf])
                            }
                            strongSelf.state = .began
                        default:
                            break
                        }
                    })
                }
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
                let maxForce: CGFloat = max(2.5, min(3.0, touch.maximumPossibleForce))
                if touch.force >= maxForce {
                    if !self.isValidated {
                        self.isValidated = true
                    }
                    
                    switch self.state {
                    case .possible:
                        self.delayTimer?.invalidate()
                        self.animator?.invalidate()
                        self.activated?(self, touch.location(in: self.view))
                        self.wasActivated = true
                        if let view = self.view?.superview {
                            if let window = view.window {
                                cancelOtherGestures(gesture: self, view: window)
                            }
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
                self.currentProgress = 0.0
                self.activationProgress?(0.0, .ended(self.currentProgress))
                if self.wasActivated {
                    self.activatedAfterCompletion?(touch.location(in: self.view), false)
                }
            } else {
                self.currentProgress = 0.0
                if !self.wasActivated && self.activateOnTap {
                    self.activatedAfterCompletion?(touch.location(in: self.view), true)
                }
            }
            
            self.externalEnded?((self.view, touch.location(in: self.view)))
        }
        
        self.delayTimer?.invalidate()
        self.animator?.invalidate()
        
        self.state = .failed
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if let _ = touches.first, !self.currentProgress.isZero, self.isValidated {
            let previousProgress = self.currentProgress
            self.currentProgress = 0.0
            self.activationProgress?(0.0, .ended(previousProgress))
        }
        
        self.delayTimer?.invalidate()
        self.animator?.invalidate()
        
        self.state = .failed
    }
    
    public func cancel() {
        if !self.currentProgress.isZero, self.isValidated {
            let previousProgress = self.currentProgress
            self.currentProgress = 0.0
            self.activationProgress?(0.0, .ended(previousProgress))
            
            self.delayTimer?.invalidate()
            self.animator?.invalidate()
            self.state = .failed
        } else {
            self.state = .failed
        }
    }
    
    public func endPressedAppearance() {
        if !self.currentProgress.isZero, self.isValidated {
            let previousProgress = self.currentProgress
            self.currentProgress = 0.0
            self.delayTimer?.invalidate()
            self.animator?.invalidate()
            self.isValidated = false
            self.activationProgress?(0.0, .ended(previousProgress))
        }
    }
}
