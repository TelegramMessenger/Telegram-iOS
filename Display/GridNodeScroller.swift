import UIKit

private class GridNodeScrollerView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    
    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

open class GridNodeScroller: ASDisplayNode, UIGestureRecognizerDelegate {
    var scrollView: UIScrollView {
        return self.view as! UIScrollView
    }
    
    override init() {
        super.init(viewBlock: {
            return GridNodeScrollerView()
        }, didLoad: nil)
        
        self.scrollView.scrollsToTop = false
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
