import Foundation
import UIKit
import AsyncDisplayKit

open class GridItemNode: ASDisplayNode {
    open var isVisibleInGrid = false
    open var isGridScrolling = false
    
    final var cachedFrame: CGRect = CGRect()
    override open var frame: CGRect {
        get {
            return self.cachedFrame
        } set(value) {
            self.cachedFrame = value
            super.frame = value
        }
    }
    
    open func updateLayout(item: GridItem, size: CGSize, isVisible: Bool, synchronousLoads: Bool) {
    }
    
    open func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
    }
}
