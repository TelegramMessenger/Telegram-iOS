import Foundation
import UIKit
import AsyncDisplayKit

public enum ListViewItemHeaderStickDirection {
    case top
    case topEdge
    case bottom
}

public protocol ListViewItemHeader: AnyObject {
    var id: ListViewItemNode.HeaderId { get }
    var stackingId: ListViewItemNode.HeaderId? { get }
    var stickDirection: ListViewItemHeaderStickDirection { get }
    var isSticky: Bool { get }
    var height: CGFloat { get }
    var stickOverInsets: Bool { get }

    func combinesWith(other: ListViewItemHeader) -> Bool
    
    func node(synchronousLoad: Bool) -> ListViewItemHeaderNode
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?)
}

public extension ListViewItemHeader {
    var isSticky: Bool {
        return true
    }
}

open class ListViewItemHeaderNode: ASDisplayNode {
    let isRotated: Bool
    final private(set) var internalStickLocationDistanceFactor: CGFloat = 0.0
    final var internalStickLocationDistance: CGFloat = 0.0
    private var isFlashingOnScrolling = false
    weak var attachedToItemNode: ListViewItemNode?
    public var contributesToEdgeEffect: Bool = false
    
    var offsetByHeaderNodeId: ListViewItemNode.HeaderId?
    var naturalOriginY: CGFloat?
    
    public var item: ListViewItemHeader?
    
    func updateInternalStickLocationDistanceFactor(_ factor: CGFloat, animated: Bool) {
        self.internalStickLocationDistanceFactor = factor
    }
    
    final func updateFlashingOnScrollingInternal(_ isFlashingOnScrolling: Bool, animated: Bool) {
        if self.isFlashingOnScrolling != isFlashingOnScrolling {
            self.isFlashingOnScrolling = isFlashingOnScrolling
            self.updateFlashingOnScrolling(isFlashingOnScrolling, animated: animated)
        }
    }
    
    open func updateFlashingOnScrolling(_ isFlashingOnScrolling: Bool, animated: Bool) {
    }
    
    open func getEffectiveAlpha() -> CGFloat {
        return self.alpha
    }
    
    public init(layerBacked: Bool = false, isRotated: Bool = false, seeThrough: Bool = false) {
        self.isRotated = isRotated
        
        super.init()
            
        self.isLayerBacked = layerBacked
    }
    
    open func updateStickDistanceFactor(_ factor: CGFloat, distance: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    final func addScrollingOffset(_ scrollingOffset: CGFloat) {
    }
    
    public func animate(_ timestamp: Double) -> Bool {
        return false
    }
    
    open func animateRemoved(duration: Double) {
        self.alpha = 0.0
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        self.layer.animateScale(from: 1.0, to: 0.2, duration: duration, removeOnCompletion: false)
    }

    open func animateAdded(duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: self.alpha, duration: 0.2)
        self.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
    }
    
    private var cachedLayout: (CGSize, CGFloat, CGFloat)?
    
    public func updateLayoutInternal(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var update = false
        if let cachedLayout = self.cachedLayout {
            if cachedLayout.0 != size || cachedLayout.1 != leftInset || cachedLayout.2 != rightInset {
                update = true
            }
        } else {
            update = true
        }
        if update {
            self.cachedLayout = (size, leftInset, rightInset)
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
        }
    }
    
    open func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
    }
    
    public func updateFrame(_ frame: CGRect, within containerSize: CGSize, updateFrame: Bool = true) {
        if updateFrame {
            self.frame = frame
        }
        if frame.maxY < 0.0 || frame.minY > containerSize.height {
        } else {
            self.updateAbsoluteRect(frame, within: containerSize)
        }
    }
}
