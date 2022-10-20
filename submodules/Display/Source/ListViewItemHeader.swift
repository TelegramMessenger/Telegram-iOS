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
    var stickDirection: ListViewItemHeaderStickDirection { get }
    var height: CGFloat { get }
    var stickOverInsets: Bool { get }

    func combinesWith(other: ListViewItemHeader) -> Bool
    
    func node(synchronousLoad: Bool) -> ListViewItemHeaderNode
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?)
}

open class ListViewItemHeaderNode: ASDisplayNode {
    private final var spring: ListViewItemSpring?
    let wantsScrollDynamics: Bool
    let isRotated: Bool
    final private(set) var internalStickLocationDistanceFactor: CGFloat = 0.0
    final var internalStickLocationDistance: CGFloat = 0.0
    private var isFlashingOnScrolling = false
    weak var attachedToItemNode: ListViewItemNode?
    
    var item: ListViewItemHeader?
    
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
    
    public init(layerBacked: Bool = false, dynamicBounce: Bool = false, isRotated: Bool = false, seeThrough: Bool = false) {
        self.wantsScrollDynamics = dynamicBounce
        self.isRotated = isRotated
        if dynamicBounce {
            self.spring = ListViewItemSpring(stiffness: -280.0, damping: -24.0, mass: 0.85)
        }
        
        super.init()
            
        self.isLayerBacked = layerBacked
    }
    
    open func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    final func addScrollingOffset(_ scrollingOffset: CGFloat) {
        if self.spring != nil && internalStickLocationDistanceFactor.isZero {
            let bounds = self.bounds
            self.bounds = CGRect(origin: CGPoint(x: 0.0, y: bounds.origin.y + scrollingOffset), size: bounds.size)
        }
    }
    
    public func animate(_ timestamp: Double) -> Bool {
        var continueAnimations = false
        
        if let _ = self.spring {
            let bounds = self.bounds
            var offset = bounds.origin.y
            let currentOffset = offset
            
            let frictionConstant: CGFloat = testSpringFriction
            let springConstant: CGFloat = testSpringConstant
            let time: CGFloat = 1.0 / 60.0
            
            // friction force = velocity * friction constant
            let frictionForce = self.spring!.velocity * frictionConstant
            // spring force = (target point - current position) * spring constant
            let springForce = -currentOffset * springConstant
            // force = spring force - friction force
            let force = springForce - frictionForce
            
            // velocity = current velocity + force * time / mass
            self.spring!.velocity = self.spring!.velocity + force * time
            // position = current position + velocity * time
            offset = currentOffset + self.spring!.velocity * time
            
            offset = offset.isNaN ? 0.0 : offset
            
            let epsilon: CGFloat = 0.1
            if abs(offset) < epsilon && abs(self.spring!.velocity) < epsilon {
                offset = 0.0
                self.spring!.velocity = 0.0
            } else {
                continueAnimations = true
            }
            
            if abs(offset) > 250.0 {
                offset = offset < 0.0 ? -250.0 : 250.0
            }
            
            self.bounds = CGRect(origin: CGPoint(x: 0.0, y: offset), size: bounds.size)
        }
        
        return continueAnimations
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
    
    func updateLayoutInternal(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
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
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset)
        }
    }
    
    open func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
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
