import Foundation
import UIKit
import AsyncDisplayKit

final class FormControllerScrollerNodeView: UIScrollView {
    weak var target: FormControllerScrollerNode?
    var ignoreUpdateBounds = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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
    
    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        return self.target?.touchesShouldBegin(touches, with: event) ?? super.touchesShouldBegin(touches, with: event, in: view)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.target?.touchesShouldBegin(touches, with: event) ?? true {
            super.touchesBegan(touches, with: event)
        }
    }
}

final class FormControllerScrollerNode: ASDisplayNode, UIScrollViewDelegate {
    override var view: FormControllerScrollerNodeView {
        return super.view as! FormControllerScrollerNodeView
    }
    
    weak var delegate: UIScrollViewDelegate?
    
    var touchesPrevented: ((CGPoint) -> Bool)?
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return FormControllerScrollerNodeView(frame: CGRect())
        })
        self.view.target = self
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.delegate = self
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.scrollViewDidScroll?(scrollView)
    }
    
    func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?) -> Bool {
        let touchesPosition = touches.first!.location(in: self.view)
        
        if let touchesPrevented = self.touchesPrevented {
            if touchesPrevented(touchesPosition) {
                return false
            }
        }
        
        return true
    }
}
