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
    
    #if os(iOS)
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    #endif
}
