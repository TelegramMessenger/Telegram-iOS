import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

private func traceScrollView(view: UIView, point: CGPoint) -> UIScrollView? {
    for subview in view.subviews {
        let subviewPoint = view.convert(point, to: subview)
        if subview.frame.contains(point), let result = traceScrollView(view: subview, point: subviewPoint) {
            return result
        }
    }
    if let scrollView = view as? UIScrollView {
        return scrollView
    }
    return nil
}

public class SwipeToDismissGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var beginPosition = CGPoint()
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    override public func reset() {
        super.reset()
        
        self.state = .possible
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, let view = self.view else {
            self.state = .failed
            return
        }
        
        var found = false
        let point = touch.location(in: self.view)
        if let scrollView = traceScrollView(view: view, point: point) {
            let contentOffset = scrollView.contentOffset
            let contentInset = scrollView.contentInset
            if contentOffset.y.isLessThanOrEqualTo(contentInset.top) {
                found = true
            }
        }
        if found {
            self.beginPosition = point
        } else {
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first, let view = self.view else {
            self.state = .failed
            return
        }
        
        let point = touch.location(in: self.view)
        
        let translation = CGPoint(x: point.x - self.beginPosition.x, y: point.y - self.beginPosition.y)
        
        if self.state == .possible {
            if abs(translation.x) > 5.0 {
                self.state = .failed
                return
            }
            var lockDown = false
            let point = touch.location(in: self.view)
            if let scrollView = traceScrollView(view: view, point: point) {
                let contentOffset = scrollView.contentOffset
                let contentInset = scrollView.contentInset
                if contentOffset.y.isLessThanOrEqualTo(contentInset.top) {
                    lockDown = true
                }
            }
            if lockDown {
                if translation.y > 2.0 {
                    self.state = .began
                }
            } else {
                self.state = .failed
            }
        } else {
            self.state = .changed
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.state = .failed
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
