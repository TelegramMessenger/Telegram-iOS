import Foundation
import UIKit
import AsyncDisplayKit

public protocol AccessibilityFocusableNode {
    func accessibilityElementDidBecomeFocused()
}

public final class AccessibilityAreaNode: ASDisplayNode {
    public var activate: (() -> Bool)?
    public var increment: (() -> Void)?
    public var decrement: (() -> Void)?
    public var focused: (() -> Void)?
    
    /// `applyAccessibilityText` state: the text last applied and the current link handler.
    var appliedAccessibilityText: (text: NSAttributedString, hasOpen: Bool)?
    var accessibilityTextOpen: ((Any) -> Void)?
    
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

    override public func accessibilityIncrement() {
        self.increment?()
    }
    
    override public func accessibilityDecrement() {
        self.decrement?()
    }
}
