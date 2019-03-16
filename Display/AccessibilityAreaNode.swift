import Foundation
import AsyncDisplayKit

public final class AccessibilityAreaNode: ASDisplayNode {
    public var activate: (() -> Bool)?
    
    override public init() {
        super.init()
        
        self.isAccessibilityElement = true
    }
    
    override public func accessibilityActivate() -> Bool {
        return self.activate?() ?? false
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}
