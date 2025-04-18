import Foundation
import UIKit
import ObjectiveC
import AsyncDisplayKit

private var ASGestureRecognizerDelegateKey: Int?
private var ASScrollViewDelegateKey: Int?

private final class WrappedGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    private weak var target: ASGestureRecognizerDelegate?
    
    init(target: ASGestureRecognizerDelegate) {
        self.target = target
        
        super.init()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let target = self.target else {
            return true
        }
        return target.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let target = self.target else {
            return false
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let target = self.target else {
            return false
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let target = self.target else {
            return false
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer) ?? false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let target = self.target else {
            return true
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        guard let target = self.target else {
            return true
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldReceive: press) ?? true
    }

    @available(iOS 13.4, *)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        guard let target = self.target else {
            return true
        }
        return target.gestureRecognizer?(gestureRecognizer, shouldReceive: event) ?? true
    }
}

public extension ASGestureRecognizerDelegate {
    var wrappedGestureRecognizerDelegate: UIGestureRecognizerDelegate {
        if let delegate = objc_getAssociatedObject(self, &ASGestureRecognizerDelegateKey) as? WrappedGestureRecognizerDelegate {
            return delegate
        } else {
            let delegate = WrappedGestureRecognizerDelegate(target: self)
            objc_setAssociatedObject(self, &ASGestureRecognizerDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return delegate
        }
    }
}

private final class WrappedScrollViewDelegate: NSObject, UIScrollViewDelegate, UIScrollViewAccessibilityDelegate {
    private weak var target: ASScrollViewDelegate?
    
    init(target: ASScrollViewDelegate) {
        self.target = target
        
        super.init()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidScroll?(scrollView)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidZoom?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let target = self.target else {
            return
        }
        target.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewWillBeginDecelerating?(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidEndDecelerating?(scrollView)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidEndScrollingAnimation?(scrollView)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        guard let target = self.target else {
            return nil
        }
        return target.viewForZooming?(in: scrollView)
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        guard let target = self.target else {
            return
        }
        target.scrollViewWillBeginZooming?(scrollView, with: view)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidEndZooming?(scrollView, with: view, atScale: scale)
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        guard let target = self.target else {
            return true
        }
        return target.scrollViewShouldScroll?(toTop: scrollView) ?? true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidScroll?(toTop: scrollView)
    }
    
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        guard let target = self.target else {
            return
        }
        target.scrollViewDidChangeAdjustedContentInset?(scrollView)
    }
    
    func accessibilityScrollStatus(for scrollView: UIScrollView) -> String? {
        guard let target = self.target else {
            return nil
        }
        return target.accessibilityScrollStatus?(for: scrollView)
    }
    
    func accessibilityAttributedScrollStatus(for scrollView: UIScrollView) -> NSAttributedString? {
        guard let target = self.target else {
            return nil
        }
        return target.accessibilityAttributedScrollStatus?(for: scrollView)
    }
}

public extension ASScrollViewDelegate {
    var wrappedScrollViewDelegate: UIScrollViewDelegate & UIScrollViewAccessibilityDelegate {
        if let delegate = objc_getAssociatedObject(self, &ASScrollViewDelegateKey) as? WrappedScrollViewDelegate {
            return delegate
        } else {
            let delegate = WrappedScrollViewDelegate(target: self)
            objc_setAssociatedObject(self, &ASScrollViewDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return delegate
        }
    }
}
