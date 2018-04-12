import Foundation
import AsyncDisplayKit

final class FormControllerScrollerNodeView: UIScrollView {
    var ignoreUpdateBounds = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if #available(iOSApplicationExtension 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
        
        self.alwaysBounceVertical = true
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if !self.ignoreUpdateBounds {
                super.bounds = value
            }
        }
    }
    
    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
    }
}

final class FormControllerScrollerNode: ASDisplayNode, UIScrollViewDelegate {
    override var view: FormControllerScrollerNodeView {
        return super.view as! FormControllerScrollerNodeView
    }
    
    weak var delegate: UIScrollViewDelegate?
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return FormControllerScrollerNodeView(frame: CGRect())
        })
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.delegate = self
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewDidScroll?(scrollView)
    }
}
