import Foundation
import UIKit
import AsyncDisplayKit

open class SparseNode: ASDisplayNode {
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        for view in self.view.subviews.reversed() {
            if let result = view.hitTest(self.view.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }
        
        if !self.bounds.inset(by: self.hitTestSlop).contains(point) {
            return nil
        }
        
        let result = super.hitTest(point, with: event)
        if result != self.view {
            return result
        } else {
            return nil
        }
    }
}

open class SparseContainerView: UIView {
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        for view in self.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }
        
        let result = super.hitTest(point, with: event)
        if result != self {
            return result
        } else {
            return nil
        }
    }
}

open class TransparentHitView: UIView {
    public var onTap: (() -> Void)?
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                self.onTap?()
                return nil
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
