import UIKit

class ListViewScroller: UIScrollView, UIGestureRecognizerDelegate {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        #if os(iOS)
        self.scrollsToTop = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        #endif
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is ListViewTapGestureRecognizer {
            return true
        }
        return false
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, let gestureRecognizers = gestureRecognizer.view?.gestureRecognizers {
            for otherGestureRecognizer in gestureRecognizers {
                if otherGestureRecognizer !== gestureRecognizer, let panGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer, panGestureRecognizer.minimumNumberOfTouches == 2 {
                    return gestureRecognizer.numberOfTouches < 2
                }
            }
            return true
        } else {
            return true
        }
    }
    
    #if os(iOS)
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    #endif
}
