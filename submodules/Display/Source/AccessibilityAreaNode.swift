import Foundation
import UIKit
import AsyncDisplayKit

public protocol AccessibilityFocusableNode {
    func accessibilityElementDidBecomeFocused()
}

public final class AccessibilityAreaNode: ASDisplayNode {
    public var activate: (() -> Bool)?
    public var focused: (() -> Void)?
    
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
    
    override public func accessibilityElementDidBecomeFocused() {
        if let focused = self.focused {
            focused()
        } else {
            var supernode = self.supernode
            while true {
                if let supernodeValue = supernode {
                    if let listItemNode = supernodeValue as? AccessibilityFocusableNode {
                        listItemNode.accessibilityElementDidBecomeFocused()
                        break
                    } else {
                        supernode = supernodeValue.supernode
                    }
                } else {
                    break
                }
            }
        }
    }
}
