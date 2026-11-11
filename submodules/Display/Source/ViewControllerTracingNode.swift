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
    
    override var accessibilityElements: [Any]? {
        get {
            if let node = self.asyncdisplaykit_node as? ViewControllerTracingNode, let elements = node.screenAccessibilityElements {
                return elements
            }
            return super.accessibilityElements
        } set(value) {
            super.accessibilityElements = value
        }
    }
}

open class ViewControllerTracingNode: ASDisplayNode {
    /// VoiceOver: an explicit order of the screen's top-level views, or nil for UIKit's own. This node's view is not an
    /// `_ASDisplayView`, so an `accessibilityElements` override on the node is never consulted; override this instead.
    open var screenAccessibilityElements: [Any]? {
        return nil
    }
    
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
