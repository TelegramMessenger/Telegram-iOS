import UIKit

public final class ListViewScroller: UIScrollView, UIGestureRecognizerDelegate {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.scrollsToTop = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is ListViewTapGestureRecognizer {
            return true
        }
        return false
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, let gestureRecognizers = gestureRecognizer.view?.gestureRecognizers {
            for otherGestureRecognizer in gestureRecognizers {
                if otherGestureRecognizer !== gestureRecognizer, let panGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer, panGestureRecognizer.minimumNumberOfTouches == 2 {
                    return gestureRecognizer.numberOfTouches < 2
                }
            }
            
            if let view = gestureRecognizer.view?.hitTest(gestureRecognizer.location(in: gestureRecognizer.view), with: nil) as? UIControl {
                return !view.isTracking
            }
            
            return true
        } else {
            return true
        }
    }
    
    override public func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
}
