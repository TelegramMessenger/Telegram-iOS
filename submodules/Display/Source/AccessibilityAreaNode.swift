import Foundation
import UIKit
import AsyncDisplayKit

public protocol AccessibilityFocusableNode {
    func accessibilityElementDidBecomeFocused()
}

public final class AccessibilityAreaNode: ASDisplayNode {
    public var activate: (() -> Bool)? {
        didSet {
            self.updateRespondsToUserInteraction()
        }
    }
    public var increment: (() -> Void)? {
        didSet {
            self.updateRespondsToUserInteraction()
        }
    }
    public var decrement: (() -> Void)? {
        didSet {
            self.updateRespondsToUserInteraction()
        }
    }
    public var focused: (() -> Void)?
    
    override public init() {
        super.init()
        
        self.isAccessibilityElement = true
    }

    override public func didLoad() {
        super.didLoad()

        self.updateRespondsToUserInteraction()
    }

    private func updateRespondsToUserInteraction() {
        if self.isNodeLoaded {
            self.view.accessibilityRespondsToUserInteraction = self.activate != nil
                || self.increment != nil
                || self.decrement != nil
                || self.accessibilityTraits.contains(.button)
                || self.accessibilityTraits.contains(.link)
                || self.accessibilityTraits.contains(.adjustable)
        }
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
