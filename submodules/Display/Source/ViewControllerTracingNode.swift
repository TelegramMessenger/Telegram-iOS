import Foundation
import UIKit
import AsyncDisplayKit

private final class ViewControllerTracingNodeView: UITracingLayerView {
    private var inHitTest = false
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.inHitTest {
            return super.hitTest(point, with: event)
        } else {
            self.inHitTest = true
            let result = self.hitTestImpl?(point, event)
            self.inHitTest = false
            return result
        }
    }
}

open class ViewControllerTracingNode: ASDisplayNode {
    override public init() {
        super.init()
        
        self.setViewBlock({
            return ViewControllerTracingNodeView()
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        (self.view as! ViewControllerTracingNodeView).hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
    }
}
