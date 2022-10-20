import UIKit
import AsyncDisplayKit

private class GridNodeScrollerLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

public class GridNodeScrollerView: UIScrollView {
    override public class var layerClass: AnyClass {
        return GridNodeScrollerLayer.self
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    
    @objc private func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

open class GridNodeScroller: ASDisplayNode, UIGestureRecognizerDelegate {
    public var scrollView: UIScrollView {
        return self.view as! UIScrollView
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return GridNodeScrollerView(frame: CGRect())
        })
        
        self.scrollView.scrollsToTop = false
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
