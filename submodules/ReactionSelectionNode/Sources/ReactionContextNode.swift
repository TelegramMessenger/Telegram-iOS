import Foundation
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramAnimatedStickerNode
import ReactionButtonListComponent
import SwiftSignalKit
import Lottie
import AppBundle
import AvatarNode

public final class ReactionContextItem {
    public struct Reaction: Equatable {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    public let reaction: ReactionContextItem.Reaction
    public let appearAnimation: TelegramMediaFile
    public let stillAnimation: TelegramMediaFile
    public let listAnimation: TelegramMediaFile
    public let largeListAnimation: TelegramMediaFile
    public let applicationAnimation: TelegramMediaFile
    public let largeApplicationAnimation: TelegramMediaFile
    
    public init(
        reaction: ReactionContextItem.Reaction,
        appearAnimation: TelegramMediaFile,
        stillAnimation: TelegramMediaFile,
        listAnimation: TelegramMediaFile,
        largeListAnimation: TelegramMediaFile,
        applicationAnimation: TelegramMediaFile,
        largeApplicationAnimation: TelegramMediaFile
    ) {
        self.reaction = reaction
        self.appearAnimation = appearAnimation
        self.stillAnimation = stillAnimation
        self.listAnimation = listAnimation
        self.largeListAnimation = largeListAnimation
        self.applicationAnimation = applicationAnimation
        self.largeApplicationAnimation = largeApplicationAnimation
    }
}

private let largeCircleSize: CGFloat = 16.0
private let smallCircleSize: CGFloat = 8.0

public final class ReactionContextNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let items: [ReactionContextItem]
    
    private let backgroundNode: ReactionContextBackgroundNode
    
    private let contentContainer: ASDisplayNode
    private let contentContainerMask: UIImageView
    private let scrollNode: ASScrollNode
    private let previewingItemContainer: ASDisplayNode
    private var visibleItemNodes: [Int: ReactionNode] = [:]
    
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var highlightedReaction: ReactionContextItem.Reaction?
    private var didTriggerExpandedReaction: Bool = false
    private var continuousHaptic: Any?
    private var validLayout: (CGSize, UIEdgeInsets, CGRect)?
    private var isLeftAligned: Bool = true
    
    public var reactionSelected: ((ReactionContextItem, Bool) -> Void)?
    
    private var hapticFeedback: HapticFeedback?
    private var standaloneReactionAnimation: StandaloneReactionAnimation?
    
    private weak var animationTargetView: UIView?
    private var animationHideNode: Bool = false
    
    private var didAnimateIn: Bool = false
    
    public init(context: AccountContext, theme: PresentationTheme, items: [ReactionContextItem]) {
        self.context = context
        self.theme = theme
        self.items = items
        
        self.backgroundNode = ReactionContextBackgroundNode(largeCircleSize: largeCircleSize, smallCircleSize: smallCircleSize)
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        self.scrollNode.clipsToBounds = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.previewingItemContainer = ASDisplayNode()
        self.previewingItemContainer.isUserInteractionEnabled = false
        
        self.contentContainer = ASDisplayNode()
        self.contentContainer.clipsToBounds = true
        self.contentContainer.addSubnode(self.scrollNode)
        
        self.contentContainerMask = UIImageView()
        self.contentContainerMask.image = generateImage(CGSize(width: 52.0, height: 52.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: 1.1)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            let shadowColor = UIColor.black

            let stepCount = 10
            var colors: [CGColor] = []
            var locations: [CGFloat] = []

            for i in 0 ... stepCount {
                let t = CGFloat(i) / CGFloat(stepCount)
                colors.append(shadowColor.withAlphaComponent(t).cgColor)
                locations.append(t)
            }

            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let gradientWidth = 6.0
            context.drawRadialGradient(gradient, startCenter: center, startRadius: size.width / 2.0, endCenter: center, endRadius: size.width / 2.0 - gradientWidth, options: [])
            
            context.setFillColor(shadowColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: gradientWidth - 1.0, dy: gradientWidth - 1.0))
        })?.stretchableImage(withLeftCapWidth: Int(52.0 / 2.0), topCapHeight: Int(52.0 / 2.0))
        self.contentContainer.view.mask = self.contentContainerMask
        //self.contentContainer.view.addSubview(self.contentContainerMask)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.contentContainer)
        self.addSubnode(self.previewingItemContainer)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
        longPressRecognizer.minimumPressDuration = 0.2
        self.longPressRecognizer = longPressRecognizer
        self.view.addGestureRecognizer(longPressRecognizer)
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: transition, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
    }
    
    public func updateIsIntersectingContent(isIntersectingContent: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.updateIsIntersectingContent(isIntersectingContent: isIntersectingContent, transition: transition)
    }
    
    private func calculateBackgroundFrame(containerSize: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, contentSize: CGSize) -> (backgroundFrame: CGRect, visualBackgroundFrame: CGRect, isLeftAligned: Bool, cloudSourcePoint: CGFloat) {
        var contentSize = contentSize
        contentSize.width = max(52.0, contentSize.width)
        contentSize.height = 52.0
        
        let sideInset: CGFloat = 11.0
        let backgroundOffset: CGPoint = CGPoint(x: 22.0, y: -7.0)
        
        var rect: CGRect
        let isLeftAligned: Bool
        if anchorRect.minX < containerSize.width - anchorRect.maxX {
            rect = CGRect(origin: CGPoint(x: anchorRect.maxX - contentSize.width + backgroundOffset.x, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = true
        } else {
            rect = CGRect(origin: CGPoint(x: anchorRect.minX - backgroundOffset.x - 4.0, y: anchorRect.minY - contentSize.height + backgroundOffset.y), size: contentSize)
            isLeftAligned = false
        }
        rect.origin.x = max(sideInset, rect.origin.x)
        rect.origin.y = max(insets.top + sideInset, rect.origin.y)
        rect.origin.x = min(containerSize.width - contentSize.width - sideInset, rect.origin.x)
        
        let rightEdge = containerSize.width - sideInset
        if rect.maxX > rightEdge {
            rect.origin.x = containerSize.width - sideInset - rect.width
        }
        if rect.minX < sideInset {
            rect.origin.x = sideInset
        }
        
        let cloudSourcePoint: CGFloat
        if isLeftAligned {
            cloudSourcePoint = min(rect.maxX - rect.height / 2.0, anchorRect.maxX - 4.0)
        } else {
            cloudSourcePoint = max(rect.minX + rect.height / 2.0, anchorRect.minX)
        }
        
        let visualRect = rect
        
        /*if self.highlightedReaction != nil {
            visualRect.origin.x -= 4.0
            visualRect.size.width += 8.0
        }*/
        
        return (rect, visualRect, isLeftAligned, cloudSourcePoint)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(transition: .immediate)
    }
    
    private func updateScrolling(transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 11.0
        let itemSpacing: CGFloat = 9.0
        let itemSize: CGFloat = 40.0
        
        let containerHeight: CGFloat = 52.0
        var contentHeight: CGFloat = containerHeight
        if self.highlightedReaction != nil {
            contentHeight = floor(contentHeight * 0.9)
        }
        
        //let highlightItemOffset: CGFloat = floor(itemSize * 0.8 / 2.0 * 0.5)
        let totalVisibleCount: CGFloat = CGFloat(self.items.count)//7.0
        let totalVisibleWidth: CGFloat = totalVisibleCount * itemSize + (totalVisibleCount - 1.0) * itemSpacing
        
        //width = count * itemSize + (count - 1) * spacing
        //count * itemSize = width - (count - 1) * spacing
        //itemSize = (width - (count - 1) * spacing) / count
        
        let selectedItemSize = floor(itemSize * 1.5)
        let remainingVisibleWidth = totalVisibleWidth - selectedItemSize
        let remainingVisibleCount = totalVisibleCount - 1.0
        let remainingItemSize = floor((remainingVisibleWidth - (remainingVisibleCount - 1.0) * itemSpacing) / remainingVisibleCount)
        
        let highlightItemSpacing: CGFloat = floor(itemSize * 0.2)
        _ = highlightItemSpacing
        
        //print("self.highlightedReaction = \(String(describing: self.highlightedReaction))")
        
        var visibleBounds = self.scrollNode.view.bounds
        self.previewingItemContainer.bounds = visibleBounds
        if self.highlightedReaction != nil {
            visibleBounds = visibleBounds.insetBy(dx: remainingItemSize - selectedItemSize, dy: 0.0)
        }
        let appearBounds = visibleBounds.insetBy(dx: 16.0, dy: 0.0)
        
        let highlightedReactionIndex = self.items.firstIndex(where: { $0.reaction == self.highlightedReaction })
        
        var validIndices = Set<Int>()
        var nextX: CGFloat = sideInset
        for i in 0 ..< self.items.count {
            var currentItemSize = itemSize
            if let highlightedReactionIndex = highlightedReactionIndex {
                if highlightedReactionIndex == i {
                    currentItemSize = selectedItemSize
                } else {
                    currentItemSize = remainingItemSize
                }
            }
            
            var baseItemFrame = CGRect(origin: CGPoint(x: nextX, y: containerHeight - contentHeight + floor((contentHeight - currentItemSize) / 2.0)), size: CGSize(width: currentItemSize, height: currentItemSize))
            if highlightedReactionIndex == i {
                let updatedSize = floor(itemSize * 2.0)
                baseItemFrame = baseItemFrame.insetBy(dx: (baseItemFrame.width - updatedSize) / 2.0, dy: (baseItemFrame.height - updatedSize) / 2.0)
                
                baseItemFrame.origin.y = containerHeight - contentHeight + floor((contentHeight - itemSize) / 2.0) + itemSize + 4.0 - updatedSize
            }
            nextX += currentItemSize + itemSpacing
            
            /*if let highlightedReactionIndex = highlightedReactionIndex {
                let indexDistance = i - highlightedReactionIndex
                _ = indexDistance
                if i > highlightedReactionIndex {
                    baseItemFrame.origin.x += highlightItemOffset// - highlightItemSpacing * CGFloat(indexDistance)
                } else if i == highlightedReactionIndex {
                    //baseItemFrame.origin.x += highlightItemOffset * 0.5
                } else {
                    baseItemFrame.origin.x -= highlightItemOffset// - highlightItemSpacing * CGFloat(indexDistance)
                }
            }*/
            
            if appearBounds.intersects(baseItemFrame) || (self.visibleItemNodes[i] != nil && visibleBounds.intersects(baseItemFrame)) {
                validIndices.insert(i)
                
                let itemFrame = baseItemFrame
                var isPreviewing = false
                if self.highlightedReaction == self.items[i].reaction {
                    //let updatedSize = CGSize(width: floor(itemFrame.width * 2.5), height: floor(itemFrame.height * 2.5))
                    //itemFrame = CGRect(origin: CGPoint(x: itemFrame.midX - updatedSize.width / 2.0, y: itemFrame.maxY + 4.0 - updatedSize.height), size: updatedSize)
                    isPreviewing = true
                } else if self.highlightedReaction != nil {
                    //let updatedSize = CGSize(width: floor(itemFrame.width * 0.8), height: floor(itemFrame.height * 0.8))
                    //itemFrame = CGRect(origin: CGPoint(x: itemFrame.midX - updatedSize.width / 2.0, y: itemFrame.midY - updatedSize.height / 2.0), size: updatedSize)
                }
                
                var animateIn = false
                
                let itemNode: ReactionNode
                var itemTransition = transition
                if let current = self.visibleItemNodes[i] {
                    itemNode = current
                } else {
                    animateIn = self.didAnimateIn
                    itemTransition = .immediate
                    
                    itemNode = ReactionNode(context: self.context, theme: self.theme, item: self.items[i])
                    self.visibleItemNodes[i] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                
                if !itemNode.isExtracted {
                    if isPreviewing {
                        if itemNode.supernode !== self.previewingItemContainer {
                            self.previewingItemContainer.addSubnode(itemNode)
                        }
                    }
                    
                    itemTransition.updateFrame(node: itemNode, frame: itemFrame, beginWithCurrentState: true, completion: { [weak self, weak itemNode] completed in
                        guard let strongSelf = self, let itemNode = itemNode else {
                            return
                        }
                        if !completed {
                            return
                        }
                        if !isPreviewing {
                            if itemNode.supernode !== strongSelf.scrollNode {
                                strongSelf.scrollNode.addSubnode(itemNode)
                            }
                        }
                    })
                    itemNode.updateLayout(size: itemFrame.size, isExpanded: false, largeExpanded: false, isPreviewing: isPreviewing, transition: itemTransition)
                    
                    if animateIn {
                        itemNode.appear(animated: !self.context.sharedContext.currentPresentationData.with({ $0 }).reduceMotion)
                    }
                }
            }
        }
        
        var removedIndices: [Int] = []
        for (index, itemNode) in self.visibleItemNodes {
            if !validIndices.contains(index) {
                removedIndices.append(index)
                itemNode.removeFromSupernode()
            }
        }
        for index in removedIndices {
            self.visibleItemNodes.removeValue(forKey: index)
        }
    }
    
    private func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition, animateInFromAnchorRect: CGRect?, animateOutToAnchorRect: CGRect?, animateReactionHighlight: Bool = false) {
        self.validLayout = (size, insets, anchorRect)
        
        let sideInset: CGFloat = 11.0
        let itemSpacing: CGFloat = 9.0
        let itemSize: CGFloat = 40.0
        let verticalInset: CGFloat = 13.0
        let rowHeight: CGFloat = 30.0
        
        let completeContentWidth = CGFloat(self.items.count) * itemSize + (CGFloat(self.items.count) - 1.0) * itemSpacing + sideInset * 2.0
        let minVisibleItemCount: CGFloat = min(CGFloat(self.items.count), 6.5)
        var visibleContentWidth = floor(minVisibleItemCount * itemSize + (minVisibleItemCount - 1.0) * itemSpacing + sideInset * 2.0)
        if visibleContentWidth > size.width - sideInset * 2.0 {
            visibleContentWidth = size.width - sideInset * 2.0
        }
        
        let contentHeight = verticalInset * 2.0 + rowHeight
        
        var backgroundInsets = insets
        backgroundInsets.left += sideInset
        backgroundInsets.right += sideInset
        
        let (actualBackgroundFrame, visualBackgroundFrame, isLeftAligned, cloudSourcePoint) = self.calculateBackgroundFrame(containerSize: CGSize(width: size.width, height: size.height), insets: backgroundInsets, anchorRect: anchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight))
        self.isLeftAligned = isLeftAligned
        
        transition.updateFrame(node: self.contentContainer, frame: visualBackgroundFrame, beginWithCurrentState: true)
        transition.updateFrame(view: self.contentContainerMask, frame: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size), beginWithCurrentState: true)
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: actualBackgroundFrame.size), beginWithCurrentState: true)
        transition.updateFrame(node: self.previewingItemContainer, frame: visualBackgroundFrame, beginWithCurrentState: true)
        self.scrollNode.view.contentSize = CGSize(width: completeContentWidth, height: visualBackgroundFrame.size.height)
        
        self.updateScrolling(transition: transition)
        
        transition.updateFrame(node: self.backgroundNode, frame: visualBackgroundFrame, beginWithCurrentState: true)
        self.backgroundNode.update(
            theme: self.theme,
            size: visualBackgroundFrame.size,
            cloudSourcePoint: cloudSourcePoint - visualBackgroundFrame.minX,
            isLeftAligned: isLeftAligned,
            isMinimized: self.highlightedReaction != nil,
            transition: transition
        )
        
        if let animateInFromAnchorRect = animateInFromAnchorRect {
            let springDuration: Double = 0.3
            let springDamping: CGFloat = 104.0
            let springDelay: Double = 0.05
            
            let sourceBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateInFromAnchorRect, contentSize: CGSize(width: visualBackgroundFrame.height, height: contentHeight)).0
            
            self.backgroundNode.animateInFromAnchorRect(size: visualBackgroundFrame.size, sourceBackgroundFrame: sourceBackgroundFrame.offsetBy(dx: -visualBackgroundFrame.minX, dy: -visualBackgroundFrame.minY))
            
            self.contentContainer.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.midX - visualBackgroundFrame.midX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.contentContainer.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: visualBackgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        } else if let animateOutToAnchorRect = animateOutToAnchorRect {
            let targetBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateOutToAnchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight)).0
            
            let offset = CGPoint(x: -(targetBackgroundFrame.minX - visualBackgroundFrame.minX), y: -(targetBackgroundFrame.minY - visualBackgroundFrame.minY))
            self.position = CGPoint(x: self.position.x - offset.x, y: self.position.y - offset.y)
            self.layer.animatePosition(from: offset, to: CGPoint(), duration: 0.2, removeOnCompletion: true, additive: true)
        }
    }
    
    public func animateIn(from sourceAnchorRect: CGRect) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: sourceAnchorRect, animateOutToAnchorRect: nil)
        }
        
        //let mainCircleDuration: Double = 0.5
        let mainCircleDelay: Double = 0.01
        
        self.backgroundNode.animateIn()
        
        self.didAnimateIn = true
        
        if !self.context.sharedContext.currentPresentationData.with({ $0 }).reduceMotion {
            for i in 0 ..< self.items.count {
                guard let itemNode = self.visibleItemNodes[i] else {
                    continue
                }
                let itemDelay = mainCircleDelay + Double(i) * 0.06
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + itemDelay, execute: { [weak itemNode] in
                    itemNode?.appear(animated: true)
                })
            }
        } else {
            for i in 0 ..< self.items.count {
                guard let itemNode = self.visibleItemNodes[i] else {
                    continue
                }
                itemNode.appear(animated: false)
            }
        }
    }
    
    public func animateOut(to targetAnchorRect: CGRect?, animatingOutToReaction: Bool) {
        self.backgroundNode.animateOut()
        
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.isExtracted {
                continue
            }
            itemNode.layer.animateAlpha(from: itemNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        
        if let targetAnchorRect = targetAnchorRect, let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .immediate, animateInFromAnchorRect: nil, animateOutToAnchorRect: targetAnchorRect)
        }
    }
    
    private func animateFromItemNodeToReaction(itemNode: ReactionNode, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        guard let targetSnapshotView = targetView.snapshotContentTree(unhide: true) else {
            completion()
            return
        }
        
        let sourceFrame = itemNode.view.convert(itemNode.bounds, to: self.view)
        let targetFrame = self.view.convert(targetView.convert(targetView.bounds, to: nil), from: nil)
        
        targetSnapshotView.frame = targetFrame
        self.view.insertSubview(targetSnapshotView, belowSubview: itemNode.view)
        
        var completedTarget = false
        var targetScaleCompleted = false
        let intermediateCompletion: () -> Void = {
            if completedTarget && targetScaleCompleted {
                completion()
            }
        }
        
        let targetPosition = targetFrame.center
        let duration: Double = 0.16
        
        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.9, removeOnCompletion: false)
        itemNode.layer.animatePosition(from: itemNode.layer.position, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.alpha = 1.0
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.alpha = 1.0
                targetView.isHidden = false
                if let targetView = targetView as? ReactionIconView {
                    targetView.imageView.alpha = 1.0
                }
                targetSnapshotView?.isHidden = true
                targetScaleCompleted = true
                intermediateCompletion()
            } else {
                targetScaleCompleted = true
                intermediateCompletion()
            }
        })
        
        itemNode.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 1.0) / itemNode.bounds.width, duration: duration, removeOnCompletion: false)
    }
    
    public func willAnimateOutToReaction(value: String) {
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.item.reaction.rawValue != value {
                continue
            }
            itemNode.isExtracted = true
        }
    }
    
    public func animateOutToReaction(value: String, targetView: UIView, hideNode: Bool, animateTargetContainer: UIView?, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, completion: @escaping () -> Void) {
        var foundItemNode: ReactionNode?
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.item.reaction.rawValue == value {
                foundItemNode = itemNode
                break
            }
        }
        guard let itemNode = foundItemNode else {
            completion()
            return
        }
        
        self.animationTargetView = targetView
        self.animationHideNode = hideNode
        
        if hideNode {
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = true
                targetView.isHidden = true
            } else {
                targetView.alpha = 0.0
                targetView.layer.animateAlpha(from: targetView.alpha, to: 0.0, duration: 0.2, completion: { [weak targetView] completed in
                    if completed {
                        targetView?.isHidden = true
                    }
                })
            }
        }
        
        itemNode.isExtracted = true
        let selfSourceRect = itemNode.view.convert(itemNode.view.bounds, to: self.view)
        let selfTargetRect = self.view.convert(targetView.bounds, from: targetView)
        
        var expandedSize: CGSize = selfTargetRect.size
        if self.didTriggerExpandedReaction {
            expandedSize = CGSize(width: 120.0, height: 120.0)
        }
        
        let expandedFrame = CGRect(origin: CGPoint(x: selfTargetRect.midX - expandedSize.width / 2.0, y: selfTargetRect.midY - expandedSize.height / 2.0), size: expandedSize)
        
        let effectFrame: CGRect
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        if self.didTriggerExpandedReaction {
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5).offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        } else {
            effectFrame = expandedFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
        
        self.addSubnode(itemNode)
        itemNode.position = expandedFrame.center
        transition.updateBounds(node: itemNode, bounds: CGRect(origin: CGPoint(), size: expandedFrame.size))
        itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, largeExpanded: self.didTriggerExpandedReaction, isPreviewing: false, transition: transition)
        
        let additionalAnimationNode = AnimatedStickerNode()
        
        let additionalAnimation: TelegramMediaFile
        if self.didTriggerExpandedReaction {
            additionalAnimation = itemNode.item.largeApplicationAnimation
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }
        } else {
            additionalAnimation = itemNode.item.applicationAnimation
        }
        
        additionalAnimationNode.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: additionalAnimation.resource), width: Int(effectFrame.width * 2.0), height: Int(effectFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: itemNode.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(additionalAnimation.resource.id)))
        additionalAnimationNode.frame = effectFrame
        additionalAnimationNode.updateLayout(size: effectFrame.size)
        self.addSubnode(additionalAnimationNode)
        
        var mainAnimationCompleted = false
        var additionalAnimationCompleted = false
        let intermediateCompletion: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                completion()
            }
        }
        
        additionalAnimationNode.completed = { _ in
            additionalAnimationCompleted = true
            intermediateCompletion()
        }
        
        transition.animatePositionWithKeyframes(node: itemNode, keyframes: generateParabollicMotionKeyframes(from: selfSourceRect.center, to: expandedFrame.center, elevation: 30.0), completion: { [weak self, weak itemNode, weak targetView, weak animateTargetContainer] _ in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.didTriggerExpandedReaction {
                    return
                }
                guard let itemNode = itemNode else {
                    return
                }
                guard let targetView = targetView as? ReactionIconView else {
                    return
                }
                if let animateTargetContainer = animateTargetContainer {
                    animateTargetContainer.isHidden = false
                }
                targetView.isHidden = false
                targetView.alpha = 1.0
                targetView.imageView.alpha = 0.0
                targetView.addSubnode(itemNode)
                itemNode.frame = targetView.bounds
                
                if strongSelf.hapticFeedback == nil {
                    strongSelf.hapticFeedback = HapticFeedback()
                }
                strongSelf.hapticFeedback?.tap()
            })
        })
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15 * UIView.animationDurationFactor(), execute: {
            additionalAnimationNode.visibility = true
            if let animateTargetContainer = animateTargetContainer {
                animateTargetContainer.isHidden = false
                animateTargetContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                animateTargetContainer.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + min(5.0, 2.0 * UIView.animationDurationFactor()), execute: {
            if self.didTriggerExpandedReaction {
                self.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: hideNode, completion: { [weak self] in
                    if let strongSelf = self, strongSelf.didTriggerExpandedReaction, let addStandaloneReactionAnimation = addStandaloneReactionAnimation {
                        let standaloneReactionAnimation = StandaloneReactionAnimation()
                        
                        addStandaloneReactionAnimation(standaloneReactionAnimation)
                        
                        standaloneReactionAnimation.animateReactionSelection(
                            context: strongSelf.context,
                            theme: strongSelf.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                            reaction: itemNode.item,
                            avatarPeers: [],
                            playHaptic: false,
                            isLarge: false,
                            targetView: targetView,
                            addStandaloneReactionAnimation: nil,
                            completion: { [weak standaloneReactionAnimation] in
                                standaloneReactionAnimation?.removeFromSupernode()
                            }
                        )
                    }
                    
                    mainAnimationCompleted = true
                    intermediateCompletion()
                })
            } else {
                if hideNode {
                    targetView.alpha = 1.0
                    targetView.isHidden = false
                    if let targetView = targetView as? ReactionIconView {
                        targetView.imageView.alpha = 1.0
                        itemNode.removeFromSupernode()
                    }
                }
                mainAnimationCompleted = true
                intermediateCompletion()
            }
        })
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        if self.contentContainer.bounds.contains(contentPoint) {
            return self.contentContainer.hitTest(contentPoint, with: event)
        }
        
        return nil
    }
    
    private let longPressDuration: Double = 1.5
    @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point = recognizer.location(in: self.view)
            if let itemNode = self.reactionItemNode(at: point) {
                self.highlightedReaction = itemNode.item.reaction
                if #available(iOS 13.0, *) {
                    self.continuousHaptic = try? ContinuousHaptic(duration: longPressDuration)
                }
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                
                if let (size, insets, anchorRect) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: longPressDuration, curve: .linear), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
                }
                
                self.longPressTimer?.invalidate()
                self.longPressTimer = SwiftSignalKit.Timer(timeout: longPressDuration, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.longPressRecognizer?.state = .ended
                }, queue: .mainQueue())
                self.longPressTimer?.start()
            }
        case .changed:
            let point = recognizer.location(in: self.view)
            var shouldCancel = false
            if let itemNode = self.reactionItemNode(at: point) {
                if self.highlightedReaction != itemNode.item.reaction {
                    shouldCancel = true
                }
            } else {
                shouldCancel = true
            }
            if shouldCancel {
                self.longPressRecognizer?.state = .cancelled
            }
        case .cancelled:
            self.longPressTimer?.invalidate()
            self.continuousHaptic = nil
            
            self.highlightedReaction = nil
            if let (size, insets, anchorRect) = self.validLayout {
                self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.3, curve: .spring), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
            }
        case .ended:
            self.longPressTimer?.invalidate()
            self.continuousHaptic = nil
            self.didTriggerExpandedReaction = true
            self.highlightGestureFinished(performAction: true, isLarge: true)
        default:
            break
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            let point = recognizer.location(in: self.view)
            if let reaction = self.reaction(at: point) {
                self.reactionSelected?(reaction, false)
            }
        default:
            break
        }
    }
    
    public func highlightGestureMoved(location: CGPoint) {
        let highlightedReaction = self.previewReaction(at: location)?.reaction
        if self.highlightedReaction != highlightedReaction {
            self.highlightedReaction = highlightedReaction
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.tap()
            
            if let (size, insets, anchorRect) = self.validLayout {
                self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
            }
        }
    }
    
    public func highlightGestureFinished(performAction: Bool) {
        self.highlightGestureFinished(performAction: performAction, isLarge: false)
    }
    
    private func highlightGestureFinished(performAction: Bool, isLarge: Bool) {
        if let highlightedReaction = self.highlightedReaction {
            self.highlightedReaction = nil
            if performAction {
                self.performReactionSelection(reaction: highlightedReaction, isLarge: isLarge)
            } else {
                if let (size, insets, anchorRect) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
                }
            }
        }
    }
    
    private func previewReaction(at point: CGPoint) -> ReactionContextItem? {
        let scrollPoint = self.view.convert(point, to: self.scrollNode.view)
        if !self.scrollNode.bounds.contains(scrollPoint) {
            return nil
        }
        
        let itemSize: CGFloat = 40.0
        
        var closestItem: (index: Int, distance: CGFloat)?
        
        for (index, itemNode) in self.visibleItemNodes {
            let intersectionItemFrame = CGRect(origin: CGPoint(x: itemNode.position.x - itemSize / 2.0, y: itemNode.position.y - 1.0), size: CGSize(width: itemSize, height: 2.0))
            
            if !self.scrollNode.bounds.contains(intersectionItemFrame) {
                continue
            }
            
            let distance = abs(scrollPoint.x - intersectionItemFrame.midX)
            if let (_, currentDistance) = closestItem {
                if currentDistance > distance {
                    closestItem = (index, distance)
                }
            } else {
                closestItem = (index, distance)
            }
        }
        if let closestItem = closestItem {
            return self.visibleItemNodes[closestItem.index]?.item
        }
        return nil
    }
    
    private func reactionItemNode(at point: CGPoint) -> ReactionNode? {
        for i in 0 ..< 2 {
            let touchInset: CGFloat = i == 0 ? 0.0 : 8.0
            for (_, itemNode) in self.visibleItemNodes {
                if itemNode.supernode === self.scrollNode && !self.scrollNode.bounds.intersects(itemNode.frame) {
                    continue
                }
                let itemPoint = self.view.convert(point, to: itemNode.view)
                if itemNode.bounds.insetBy(dx: -touchInset, dy: -touchInset).contains(itemPoint) {
                    return itemNode
                }
            }
        }
        return nil
    }
    
    public func reaction(at point: CGPoint) -> ReactionContextItem? {
        return self.reactionItemNode(at: point)?.item
    }
    
    public func performReactionSelection(reaction: ReactionContextItem.Reaction, isLarge: Bool) {
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.item.reaction == reaction {
                self.reactionSelected?(itemNode.item, isLarge)
                break
            }
        }
    }
    
    public func cancelReactionAnimation() {
        self.standaloneReactionAnimation?.cancel()
        
        if let animationTargetView = self.animationTargetView, self.animationHideNode {
            animationTargetView.alpha = 1.0
            animationTargetView.isHidden = false
        }
    }
    
    public func setHighlightedReaction(_ value: ReactionContextItem.Reaction?) {
        self.highlightedReaction = value
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
}

public final class StandaloneReactionAnimation: ASDisplayNode {
    private var itemNode: ReactionNode? = nil
    private var itemNodeIsEmbedded: Bool = false
    private let hapticFeedback = HapticFeedback()
    private var isCancelled: Bool = false
    
    private weak var targetView: UIView?
    
    private var colorCallbacks: [LOTColorValueCallback] = []
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionSelection(context: AccountContext, theme: PresentationTheme, reaction: ReactionContextItem, avatarPeers: [EnginePeer], playHaptic: Bool, isLarge: Bool, targetView: UIView, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, completion: @escaping () -> Void) {
        self.animateReactionSelection(context: context, theme: theme, reaction: reaction, avatarPeers: avatarPeers, playHaptic: playHaptic, isLarge: isLarge, targetView: targetView, addStandaloneReactionAnimation: addStandaloneReactionAnimation, currentItemNode: nil, completion: completion)
    }
        
    func animateReactionSelection(context: AccountContext, theme: PresentationTheme, reaction: ReactionContextItem, avatarPeers: [EnginePeer], playHaptic: Bool,  isLarge: Bool, targetView: UIView, addStandaloneReactionAnimation: ((StandaloneReactionAnimation) -> Void)?, currentItemNode: ReactionNode?, completion: @escaping () -> Void) {
        guard let sourceSnapshotView = targetView.snapshotContentTree() else {
            completion()
            return
        }
        
        if playHaptic {
            self.hapticFeedback.tap()
        }
        
        self.targetView = targetView
        
        let itemNode: ReactionNode
        if let currentItemNode = currentItemNode {
            itemNode = currentItemNode
        } else {
            itemNode = ReactionNode(context: context, theme: theme, item: reaction)
        }
        self.itemNode = itemNode
        
        if let targetView = targetView as? ReactionIconView, !isLarge {
            self.itemNodeIsEmbedded = true
            targetView.addSubnode(itemNode)
        } else {
            self.addSubnode(itemNode)
        }
        
        itemNode.expandedAnimationDidBegin = { [weak self, weak targetView] in
            guard let strongSelf = self, let targetView = targetView else {
                return
            }
            if let targetView = targetView as? ReactionIconView, !isLarge {
                strongSelf.itemNodeIsEmbedded = true
                
                targetView.imageView.isHidden = true
            } else {
                targetView.isHidden = true
            }
        }
        
        itemNode.isExtracted = true
        let selfTargetRect = self.view.convert(targetView.bounds, from: targetView)
        
        var expandedSize: CGSize = selfTargetRect.size
        if isLarge {
            expandedSize = CGSize(width: 120.0, height: 120.0)
        }
        
        let expandedFrame = CGRect(origin: CGPoint(x: selfTargetRect.midX - expandedSize.width / 2.0, y: selfTargetRect.midY - expandedSize.height / 2.0), size: expandedSize)
        
        let effectFrame: CGRect
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        if isLarge {
            effectFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5).offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        } else {
            effectFrame = expandedFrame.insetBy(dx: -expandedSize.width, dy: -expandedSize.height)
        }
        
        if !self.itemNodeIsEmbedded {
            sourceSnapshotView.frame = selfTargetRect
            self.view.addSubview(sourceSnapshotView)
            sourceSnapshotView.alpha = 0.0
            sourceSnapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (expandedFrame.width / selfTargetRect.width) as NSNumber, keyPath: "transform.scale", duration: 0.7)
            sourceSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.01, completion: { [weak sourceSnapshotView] _ in
                sourceSnapshotView?.removeFromSuperview()
            })
        }
        
        if self.itemNodeIsEmbedded {
            itemNode.frame = targetView.bounds
        } else {
            itemNode.frame = expandedFrame
            
            itemNode.layer.animateSpring(from: (selfTargetRect.width / expandedFrame.width) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.7)
        }
        
        itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, largeExpanded: isLarge, isPreviewing: false, transition: .immediate)
        
        let additionalAnimationNode = AnimatedStickerNode()
        
        let additionalAnimation: TelegramMediaFile
        if isLarge {
            additionalAnimation = itemNode.item.largeApplicationAnimation
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }
        } else {
            additionalAnimation = itemNode.item.applicationAnimation
        }
        
        additionalAnimationNode.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: additionalAnimation.resource), width: Int(effectFrame.width * 2.0), height: Int(effectFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: itemNode.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(additionalAnimation.resource.id)))
        additionalAnimationNode.frame = effectFrame
        additionalAnimationNode.updateLayout(size: effectFrame.size)
        self.addSubnode(additionalAnimationNode)
        
        if !isLarge, !avatarPeers.isEmpty, let url = getAppBundle().url(forResource: "effectavatar", withExtension: "json"), let composition = LOTComposition(filePath: url.path) {
            let view = LOTAnimationView(model: composition, in: getAppBundle())
            view.animationSpeed = 1.0
            view.backgroundColor = nil
            view.isOpaque = false
            
            var avatarIndex = 0
            
            let keypathIndices: [Int] = Array((1 ... 3).map({ $0 }).shuffled())
            for i in keypathIndices {
                var peer: EnginePeer?
                if avatarIndex < avatarPeers.count {
                    peer = avatarPeers[avatarIndex]
                }
                avatarIndex += 1
                
                if let peer = peer {
                    let avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
                    
                    let avatarContainer = UIView(frame: CGRect(origin: CGPoint(x: -100.0, y: -100.0), size: CGSize(width: 200.0, height: 200.0)))
                    
                    avatarNode.frame = CGRect(origin: CGPoint(x: floor((200.0 - 40.0) / 2.0), y: floor((200.0 - 40.0) / 2.0)), size: CGSize(width: 40.0, height: 40.0))
                    avatarNode.setPeer(context: context, theme: context.sharedContext.currentPresentationData.with({ $0 }).theme, peer: peer)
                    avatarNode.transform = CATransform3DMakeScale(200.0 / 40.0, 200.0 / 40.0, 1.0)
                    avatarContainer.addSubnode(avatarNode)
                    
                    view.addSubview(avatarContainer, toKeypathLayer: LOTKeypath(string: "Avatar \(i).Ellipse 1"))
                }
                
                let colorCallback = LOTColorValueCallback(color: UIColor.clear.cgColor)
                self.colorCallbacks.append(colorCallback)
                view.setValueDelegate(colorCallback, for: LOTKeypath(string: "Avatar \(i).Ellipse 1.Fill 1.Color"))
            }
            
            view.frame = additionalAnimationNode.bounds
            additionalAnimationNode.view.addSubview(view)
            view.play()
        }
        
        var mainAnimationCompleted = false
        var additionalAnimationCompleted = false
        let intermediateCompletion: () -> Void = {
            if mainAnimationCompleted && additionalAnimationCompleted {
                completion()
            }
        }
        
        var didBeginDismissAnimation = false
        let beginDismissAnimation: () -> Void = { [weak self] in
            if !didBeginDismissAnimation {
                didBeginDismissAnimation = true
            
                guard let strongSelf = self else {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                    return
                }
                
                if isLarge {
                    strongSelf.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: true, completion: {
                        if let addStandaloneReactionAnimation = addStandaloneReactionAnimation {
                            let standaloneReactionAnimation = StandaloneReactionAnimation()
                            
                            addStandaloneReactionAnimation(standaloneReactionAnimation)
                            
                            standaloneReactionAnimation.animateReactionSelection(
                                context: itemNode.context,
                                theme: itemNode.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                                reaction: itemNode.item,
                                avatarPeers: avatarPeers,
                                playHaptic: false,
                                isLarge: false,
                                targetView: targetView,
                                addStandaloneReactionAnimation: nil,
                                completion: { [weak standaloneReactionAnimation] in
                                    standaloneReactionAnimation?.removeFromSupernode()
                                }
                            )
                        }
                        
                        mainAnimationCompleted = true
                        intermediateCompletion()
                    })
                } else {
                    if let targetView = strongSelf.targetView {
                        if let targetView = targetView as? ReactionIconView, !isLarge {
                            targetView.imageView.isHidden = false
                        } else {
                            targetView.alpha = 1.0
                            targetView.isHidden = false
                        }
                    }
                    
                    if strongSelf.itemNodeIsEmbedded {
                        strongSelf.itemNode?.removeFromSupernode()
                    }
                    
                    mainAnimationCompleted = true
                    intermediateCompletion()
                }
            }
        }
        
        additionalAnimationNode.completed = { _ in
            additionalAnimationCompleted = true
            intermediateCompletion()
            beginDismissAnimation()
        }
        
        additionalAnimationNode.visibility = true
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: {
            beginDismissAnimation()
        })
    }
    
    private func animateFromItemNodeToReaction(itemNode: ReactionNode, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        guard let targetSnapshotView = targetView.snapshotContentTree(unhide: true) else {
            completion()
            return
        }
        
        let sourceFrame = itemNode.view.convert(itemNode.bounds, to: self.view)
        let targetFrame = self.view.convert(targetView.convert(targetView.bounds, to: nil), from: nil)
        
        targetSnapshotView.frame = targetFrame
        self.view.insertSubview(targetSnapshotView, belowSubview: itemNode.view)
        
        var completedTarget = false
        var targetScaleCompleted = false
        let intermediateCompletion: () -> Void = {
            if completedTarget && targetScaleCompleted {
                completion()
            }
        }
        
        let targetPosition = targetFrame.center
        let duration: Double = 0.16
        
        itemNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.9, removeOnCompletion: false)
        itemNode.layer.animatePosition(from: itemNode.layer.position, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.alpha = 1.0
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.alpha = 1.0
                targetView.isHidden = false
                if let targetView = targetView as? ReactionIconView {
                    targetView.imageView.alpha = 1.0
                }
                targetSnapshotView?.isHidden = true
                targetScaleCompleted = true
                intermediateCompletion()
            } else {
                targetScaleCompleted = true
                intermediateCompletion()
            }
        })
        
        itemNode.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 1.0) / itemNode.bounds.width, duration: duration, removeOnCompletion: false)
    }
    
    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: offset.y)
        transition.animateOffsetAdditive(node: self, offset: -offset.y)
    }
    
    public func cancel() {
        self.isCancelled = true
        
        if let targetView = self.targetView {
            if let targetView = targetView as? ReactionIconView, self.itemNodeIsEmbedded {
                targetView.imageView.isHidden = false
            } else {
                targetView.alpha = 1.0
                targetView.isHidden = false
            }
        }
        
        if self.itemNodeIsEmbedded {
            self.itemNode?.removeFromSupernode()
        }
    }
}

public final class StandaloneDismissReactionAnimation: ASDisplayNode {
    private let hapticFeedback = HapticFeedback()
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionDismiss(sourceView: UIView, hideNode: Bool, isIncoming: Bool, completion: @escaping () -> Void) {
        guard let sourceSnapshotView = sourceView.snapshotContentTree() else {
            completion()
            return
        }
        if hideNode {
            sourceView.isHidden = true
        }
        
        let sourceRect = self.view.convert(sourceView.bounds, from: sourceView)
        sourceSnapshotView.frame = sourceRect
        self.view.addSubview(sourceSnapshotView)
        
        var targetOffset: CGFloat = 120.0
        if !isIncoming {
            targetOffset = -targetOffset
        }
        let targetPoint = CGPoint(x: sourceRect.midX + targetOffset, y: sourceRect.midY)
        
        let hapticFeedback = self.hapticFeedback
        hapticFeedback.prepareImpact(.soft)
        
        let keyframes = generateParabollicMotionKeyframes(from: sourceRect.center, to: targetPoint, elevation: 25.0)
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .easeInOut)
        sourceSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.04, delay: 0.18 - 0.04, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak sourceSnapshotView, weak hapticFeedback] _ in
            sourceSnapshotView?.removeFromSuperview()
            hapticFeedback?.impact(.soft)
            completion()
        })
        transition.animatePositionWithKeyframes(layer: sourceSnapshotView.layer, keyframes: keyframes, removeOnCompletion: false)
    }
    
    public func addRelativeContentOffset(_ offset: CGPoint, transition: ContainedViewLayoutTransition) {
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: offset.y)
        transition.animateOffsetAdditive(node: self, offset: -offset.y)
    }
}

private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}
