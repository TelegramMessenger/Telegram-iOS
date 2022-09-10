import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

var testSpringFrictionLimits: (CGFloat, CGFloat) = (3.0, 60.0)
var testSpringFriction: CGFloat = 31.8211269378662

var testSpringConstantLimits: (CGFloat, CGFloat) = (3.0, 450.0)
var testSpringConstant: CGFloat = 443.704223632812

var testSpringResistanceFreeLimits: (CGFloat, CGFloat) = (0.05, 1.0)
var testSpringFreeResistance: CGFloat = 0.676197171211243

var testSpringResistanceScrollingLimits: (CGFloat, CGFloat) = (0.1, 1.0)
var testSpringScrollingResistance: CGFloat = 0.6721

struct ListViewItemSpring {
    let stiffness: CGFloat
    let damping: CGFloat
    let mass: CGFloat
    var velocity: CGFloat = 0.0
    
    init(stiffness: CGFloat, damping: CGFloat, mass: CGFloat) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
    }
}

public struct ListViewItemNodeLayout {
    public let contentSize: CGSize
    public let insets: UIEdgeInsets
    
    public init() {
        self.contentSize = CGSize()
        self.insets = UIEdgeInsets()
    }
    
    public init(contentSize: CGSize, insets: UIEdgeInsets) {
        self.contentSize = contentSize
        self.insets = insets
    }
    
    public var size: CGSize {
        return CGSize(width: self.contentSize.width + self.insets.left + self.insets.right, height: self.contentSize.height + self.insets.top + self.insets.bottom)
    }
}

public enum ListViewItemNodeVisibility: Equatable {
    case none
    case visible(CGFloat, CGRect)
}

public struct ListViewItemLayoutParams {
    public let width: CGFloat
    public let leftInset: CGFloat
    public let rightInset: CGFloat
    public let availableHeight: CGFloat
    
    public init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, availableHeight: CGFloat) {
        self.width = width
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.availableHeight = availableHeight
    }
}

private final class ControlledTransitionContext {
    let transition: ControlledTransition
    let beginAt: Double
    
    init(transition: ControlledTransition, beginAt: Double) {
        self.transition = transition
        self.beginAt = beginAt
    }
}

open class ListViewItemNode: ASDisplayNode, AccessibilityFocusableNode {
    public struct HeaderId: Hashable {
        public var space: AnyHashable
        public var id: AnyHashable

        public init(space: AnyHashable, id: AnyHashable) {
            self.space = space
            self.id = id
        }
    }

    let rotated: Bool
    final var index: Int?
    
    public var isHighlightedInOverlay: Bool = false
    
    public private(set) var accessoryItemNode: ListViewAccessoryItemNode?

    func setAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode?, leftInset: CGFloat, rightInset: CGFloat) {
        self.accessoryItemNode = accessoryItemNode
        if let accessoryItemNode = accessoryItemNode {
            self.layoutAccessoryItemNode(accessoryItemNode, leftInset: leftInset, rightInset: rightInset)
        }
    }
    
    open func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.addSubnode(accessoryItemNode)
    }
    
    final var headerAccessoryItemNode: ListViewAccessoryItemNode? {
        didSet {
            if let headerAccessoryItemNode = self.headerAccessoryItemNode {
                self.layoutHeaderAccessoryItemNode(headerAccessoryItemNode)
            }
        }
    }
    
    open var extractedBackgroundNode: ASDisplayNode? {
        return nil
    }
    
    private final var spring: ListViewItemSpring?
    private final var animations: [(String, ListViewAnimation)] = []
    private final var pendingControlledTransitions: [ControlledTransition] = []
    private final var controlledTransitions: [ControlledTransitionContext] = []

    final var tempHeaderSpaceAffinities: [ListViewItemNode.HeaderId: Int] = [:]
    final var headerSpaceAffinities: [ListViewItemNode.HeaderId: Int] = [:]

    public internal(set) var attachedHeaderNodes: [ListViewItemHeaderNode] = []

    open func attachedHeaderNodesUpdated() {
    }
    
    final let wantsScrollDynamics: Bool
    
    open var preferredAnimationCurve: (CGFloat) -> CGFloat {
        return listViewAnimationCurveSystem
    }
    
    public final var wantsTrailingItemSpaceUpdates: Bool = false
    
    public final var scrollPositioningInsets: UIEdgeInsets = UIEdgeInsets()
    
    public final var canBeUsedAsScrollToItemAnchor: Bool = true
    
    open var visibility: ListViewItemNodeVisibility = .none
    
    open var canBeSelected: Bool {
        return true
    }
    
    open var canBeLongTapped: Bool {
        return false
    }
    
    open var preventsTouchesToOtherItems: Bool {
        return false
    }
    
    open func touchesToOtherItemsPrevented() {
        
    }
    
    open func tapped() {
    }
    
    open func longTapped() {
    }
    
    public final var insets: UIEdgeInsets = UIEdgeInsets() {
        didSet {
            let effectiveInsets = self.insets
            self.frame = CGRect(origin: self.frame.origin, size: CGSize(width: self.contentSize.width, height: self.contentSize.height + effectiveInsets.top + effectiveInsets.bottom))
            let bounds = self.bounds
            self.bounds = CGRect(origin: CGPoint(x: bounds.origin.x, y: -effectiveInsets.top + self.contentOffset + self.transitionOffset), size: bounds.size)
        }
    }

    private final var _contentSize: CGSize = CGSize()
    public final var contentSize: CGSize {
        get {
            return self._contentSize
        } set(value) {
            let effectiveInsets = self.insets
            self.frame = CGRect(origin: self.frame.origin, size: CGSize(width: value.width, height: value.height + effectiveInsets.top + effectiveInsets.bottom))
        }
    }
    
    private var contentOffset: CGFloat = 0.0 {
        didSet {
            let effectiveInsets = self.insets
            let bounds = self.bounds
            self.bounds = CGRect(origin: CGPoint(x: bounds.origin.x, y: -effectiveInsets.top + self.contentOffset + self.transitionOffset), size: bounds.size)
        }
    }
    
    public var transitionOffset: CGFloat = 0.0 {
        didSet {
            let effectiveInsets = self.insets
            let bounds = self.bounds
            self.bounds = CGRect(origin: CGPoint(x: bounds.origin.x, y: -effectiveInsets.top + self.contentOffset + self.transitionOffset), size: bounds.size)
        }
    }
    
    public var layout: ListViewItemNodeLayout {
        var insets = self.insets
        var contentSize = self.contentSize
        
        if let animation = self.animationForKey("insets") {
            insets = animation.to as! UIEdgeInsets
        }
        
        if let animation = self.animationForKey("apparentHeight") {
            contentSize.height = (animation.to as! CGFloat) - insets.top - insets.bottom
        }
        
        return ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
    }
    
    public var displayResourcesReady: Signal<Void, NoError> {
        return .complete()
    }
    
    public init(layerBacked: Bool, dynamicBounce: Bool = true, rotated: Bool = false, seeThrough: Bool = false) {
        if dynamicBounce {
            self.spring = ListViewItemSpring(stiffness: -280.0, damping: -24.0, mass: 0.85)
        }
        self.wantsScrollDynamics = dynamicBounce
        
        self.rotated = rotated
        
        super.init()
        
        self.isLayerBacked = layerBacked
    }
    
    var apparentHeight: CGFloat = 0.0
    public private(set) var apparentHeightTransition: (CGFloat, CGFloat)?
    private var _bounds: CGRect = CGRect()
    private var _position: CGPoint = CGPoint()
    
    open override var frame: CGRect {
        get {
            return CGRect(origin: CGPoint(x: self._position.x - self._bounds.width / 2.0, y: self._position.y - self._bounds.height / 2.0), size: self._bounds.size)
        } set(value) {
            let previousSize = self._bounds.size
            
            super.frame = value
            self._bounds.size = value.size
            self._position = CGPoint(x: value.midX, y: value.midY)
            let effectiveInsets = self.insets
            self._contentSize = CGSize(width: value.size.width, height: value.size.height - effectiveInsets.top - effectiveInsets.bottom)
            
            if previousSize != value.size {
                if let headerAccessoryItemNode = self.headerAccessoryItemNode {
                    self.layoutHeaderAccessoryItemNode(headerAccessoryItemNode)
                }
            }
        }
    }
    
    open override var bounds: CGRect {
        get {
            return self._bounds
        } set(value) {
            let previousSize = self._bounds.size
            
            super.bounds = value
            self._bounds = value
            let effectiveInsets = self.insets
            self._contentSize = CGSize(width: value.size.width, height: value.size.height - effectiveInsets.top - effectiveInsets.bottom)
            
            if previousSize != value.size {
                if let headerAccessoryItemNode = self.headerAccessoryItemNode {
                    self.layoutHeaderAccessoryItemNode(headerAccessoryItemNode)
                }
            }
        }
    }
    
    public var contentBounds: CGRect {
        let bounds = self.bounds
        let effectiveInsets = self.insets
        return CGRect(origin: CGPoint(x: 0.0, y: bounds.origin.y + effectiveInsets.top), size: CGSize(width: bounds.size.width, height: bounds.size.height - effectiveInsets.top - effectiveInsets.bottom))
    }
    
    open override var position: CGPoint {
        get {
            return self._position
        } set(value) {
            super.position = value
            self._position = value
        }
    }
    
    public final var apparentFrame: CGRect {
        var frame = self.frame
        frame.size.height = self.apparentHeight
        return frame
    }
    
    public final var apparentContentFrame: CGRect {
        var frame = self.frame
        let insets = self.insets
        frame.origin.y += insets.top
        frame.size.height = self.apparentHeight - insets.top - insets.bottom
        return frame
    }
    
    public final var apparentBounds: CGRect {
        var bounds = self.bounds
        bounds.size.height = self.apparentHeight
        return bounds
    }
    
    open func layoutAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode, leftInset: CGFloat, rightInset: CGFloat) {
    }
    
    open func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
    }
    
    open func reuse() {
    }
    
    final func addScrollingOffset(_ scrollingOffset: CGFloat) {
        if self.spring != nil {
            self.contentOffset += scrollingOffset
        }
    }
    
    func initializeDynamicsFromSibling(_ itemView: ListViewItemNode, additionalOffset: CGFloat) {
        if let itemViewSpring = itemView.spring {
            self.contentOffset = itemView.contentOffset + additionalOffset
            self.spring?.velocity = itemViewSpring.velocity
        }
    }
    
    public func animate(timestamp: Double, invertOffsetDirection: inout Bool) -> Bool {
        var continueAnimations = false
        
        if let _ = self.spring {
            var offset = self.contentOffset
            
            let frictionConstant: CGFloat = testSpringFriction
            let springConstant: CGFloat = testSpringConstant
            let time: CGFloat = 1.0 / 60.0
            
            // friction force = velocity * friction constant
            let frictionForce = self.spring!.velocity * frictionConstant
            // spring force = (target point - current position) * spring constant
            let springForce = -self.contentOffset * springConstant
            // force = spring force - friction force
            let force = springForce - frictionForce
            
            // velocity = current velocity + force * time / mass
            self.spring!.velocity = self.spring!.velocity + force * time
            // position = current position + velocity * time
            offset = self.contentOffset + self.spring!.velocity * time
            
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
            self.contentOffset = offset
        }
        
        var i = 0
        var animationCount = self.animations.count
        while i < animationCount {
            let (_, animation) = self.animations[i]
            animation.applyAt(timestamp)
            
            if animation.invertOffsetDirection {
                invertOffsetDirection = true
            }
            
            if animation.completeAt(timestamp) {
                self.animations.remove(at: i)
                animationCount -= 1
                i -= 1
            } else {
                continueAnimations = true
            }
            
            i += 1
        }
        
        i = 0
        var transitionCount = self.controlledTransitions.count
        while i < transitionCount {
            let transition = self.controlledTransitions[i]
            var fraction = (timestamp - transition.beginAt) / transition.transition.animator.duration
            fraction = max(0.0, min(1.0, fraction))
            transition.transition.animator.setAnimationProgress(CGFloat(fraction))
            
            if timestamp >= transition.beginAt + transition.transition.animator.duration {
                transition.transition.animator.finishAnimation()
                self.controlledTransitions.remove(at: i)
                transitionCount -= 1
                i -= 1
            } else {
                continueAnimations = true
            }
            
            i += 1
        }
        
        if let accessoryItemNode = self.accessoryItemNode {
            if (accessoryItemNode.animate(timestamp)) {
                continueAnimations = true
            }
        }
        
        return continueAnimations
    }
    
    open func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
    }
    
    public func animationForKey(_ key: String) -> ListViewAnimation? {
        for (animationKey, animation) in self.animations {
            if animationKey == key {
                return animation
            }
        }
        return nil
    }
    
    public final func setAnimationForKey(_ key: String, animation: ListViewAnimation?) {
        for i in 0 ..< self.animations.count {
            let (currentKey, currentAnimation) = self.animations[i]
            if currentKey == key {
                self.animations.remove(at: i)
                currentAnimation.cancel()
                break
            }
        }
        if let animation = animation {
            self.animations.append((key, animation))
        }
    }
    
    public final func removeAllAnimations() {
        let previousAnimations = self.animations
        self.animations.removeAll()
        
        for (_, animation) in previousAnimations {
            animation.cancel()
        }
        
        self.accessoryItemNode?.removeAllAnimations()
        
        for transition in self.controlledTransitions {
            transition.transition.animator.finishAnimation()
        }
        self.controlledTransitions.removeAll()
    }
    
    func addPendingControlledTransition(transition: ControlledTransition) {
        self.pendingControlledTransitions.append(transition)
    }
    
    func beginPendingControlledTransitions(beginAt: Double, forceRestart: Bool) {
        for transition in self.pendingControlledTransitions {
            self.addControlledTransition(transition: transition, beginAt: beginAt, forceRestart: forceRestart)
        }
        self.pendingControlledTransitions.removeAll()
    }
    
    func addControlledTransition(transition: ControlledTransition, beginAt: Double, forceRestart: Bool) {
        for controlledTransition in self.controlledTransitions {
            transition.merge(with: controlledTransition.transition, forceRestart: forceRestart)
        }
        self.controlledTransitions.append(ControlledTransitionContext(transition: transition, beginAt: beginAt))
    }
    
    public func addInsetsAnimationToValue(_ value: UIEdgeInsets, duration: Double, beginAt: Double) {
        let animation = ListViewAnimation(from: self.insets, to: value, duration: duration, curve: self.preferredAnimationCurve, beginAt: beginAt, update: { [weak self] _, currentValue in
            if let strongSelf = self {
                strongSelf.insets = currentValue
            }
        })
        self.setAnimationForKey("insets", animation: animation)
    }
    
    public func addHeightAnimation(_ value: CGFloat, duration: Double, beginAt: Double, update: ((CGFloat, CGFloat) -> Void)? = nil) {
        let animation = ListViewAnimation(from: self.bounds.height, to: value, duration: duration, curve: self.preferredAnimationCurve, beginAt: beginAt, update: { [weak self] progress, currentValue in
            if let strongSelf = self {
                let frame = strongSelf.frame
                strongSelf.frame = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: currentValue))
                if let update = update {
                    update(progress, currentValue)
                }
            }
        })
        self.setAnimationForKey("height", animation: animation)
    }
    
    func copyHeightAndApparentHeightAnimations(to otherNode: ListViewItemNode) {
        if let animation = self.animationForKey("apparentHeight") {
            let updatedAnimation = ListViewAnimation(copying: animation, update: { [weak otherNode] (progress: CGFloat, currentValue: CGFloat) -> Void in
                if let strongSelf = otherNode {
                    let frame = strongSelf.frame
                    strongSelf.frame = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: currentValue))
                }
            })
            otherNode.setAnimationForKey("height", animation: updatedAnimation)
        }
        
        if let animation = self.animationForKey("apparentHeight") {
            let updatedAnimation = ListViewAnimation(copying: animation, update: { [weak otherNode] (progress: CGFloat, currentValue: CGFloat) -> Void in
                if let strongSelf = otherNode {
                    strongSelf.apparentHeight = currentValue
                }
            })
            otherNode.setAnimationForKey("apparentHeight", animation: updatedAnimation)
        }
    }
    
    public func addApparentHeightAnimation(_ value: CGFloat, duration: Double, beginAt: Double, invertOffsetDirection: Bool = false, update: ((CGFloat, CGFloat) -> Void)? = nil) {
        self.apparentHeightTransition = (self.apparentHeight, value)
        let animation = ListViewAnimation(from: self.apparentHeight, to: value, duration: duration, invertOffsetDirection: invertOffsetDirection, curve: self.preferredAnimationCurve, beginAt: beginAt, update: { [weak self] progress, currentValue in
            if let strongSelf = self {
                strongSelf.apparentHeight = currentValue
                if let update = update {
                    update(progress, currentValue)
                }
                if progress == 1.0 {
                    strongSelf.apparentHeightTransition = nil
                }
            }
        })
        self.setAnimationForKey("apparentHeight", animation: animation)
    }
    
    public func modifyApparentHeightAnimation(_ value: CGFloat, beginAt: Double) {
        if let previousAnimation = self.animationForKey("apparentHeight") {
            var duration = previousAnimation.startTime + previousAnimation.duration - beginAt
            if abs(self.apparentHeight - value) < CGFloat.ulpOfOne {
                duration = 0.0
            }
            
            let animation = ListViewAnimation(from: self.apparentHeight, to: value, duration: duration, curve: self.preferredAnimationCurve, beginAt: beginAt, update: { [weak self] _, currentValue in
                if let strongSelf = self {
                    strongSelf.apparentHeight = currentValue
                }
            })
            
            self.setAnimationForKey("apparentHeight", animation: animation)
        }
    }
    
    public func removeApparentHeightAnimation() {
        self.setAnimationForKey("apparentHeight", animation: nil)
    }
    
    public func addTransitionOffsetAnimation(_ value: CGFloat, duration: Double, beginAt: Double) {
        let animation = ListViewAnimation(from: self.transitionOffset, to: value, duration: duration, curve: self.preferredAnimationCurve, beginAt: beginAt, update: { [weak self] _, currentValue in
            if let strongSelf = self {
                strongSelf.transitionOffset = currentValue
            }
        })
        self.setAnimationForKey("transitionOffset", animation: animation)
    }
    
    open func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
    }
    
    open func animateAdded(_ currentTimestamp: Double, duration: Double) {
    }
    
    open func animateRemoved(_ currentTimestamp: Double, duration: Double) {
    }
    
    open func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
    }
    
    open func selected() {
    }
    
    open func secondaryAction(at point: CGPoint) {
    }
    
    open func isReorderable(at point: CGPoint) -> Bool {
        return false
    }
    
    open func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        
    }
    
    open func shouldAnimateHorizontalFrameTransition() -> Bool {
        return false
    }
    
    open func headers() -> [ListViewItemHeader]? {
        return nil
    }
    
    open func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
    
    override open func accessibilityElementDidBecomeFocused() {
        (self.supernode as? ListView)?.ensureItemNodeVisible(self, animated: false, overflow: 22.0, allowIntersection: true)
    }
    
    public func updateFrame(_ frame: CGRect, within containerSize: CGSize, updateFrame: Bool = true) {
        if updateFrame {
            self.frame = frame
        }
        if frame.maxY < 0.0 || frame.minY > containerSize.height {
        } else {
            self.updateAbsoluteRect(frame, within: containerSize)
        }
        if let extractedBackgroundNode = self.extractedBackgroundNode {
            extractedBackgroundNode.frame = frame.offsetBy(dx: 0.0, dy: -self.insets.top)
        }
    }
    
    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
    }
    
    open func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let extractedBackgroundNode = self.extractedBackgroundNode {
            let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: animationCurve)
            transition.animatePositionAdditive(node: extractedBackgroundNode, offset: CGPoint(x: -value.x, y: -value.y))
        }
    }
    
    open func snapshotForReordering() -> UIView? {
        return self.view.snapshotContentTree(keepTransform: true)
    }
}
