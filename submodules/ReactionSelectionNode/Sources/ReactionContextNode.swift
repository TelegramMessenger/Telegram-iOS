import Foundation
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramAnimatedStickerNode

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
    public let applicationAnimation: TelegramMediaFile
    
    public init(
        reaction: ReactionContextItem.Reaction,
        appearAnimation: TelegramMediaFile,
        stillAnimation: TelegramMediaFile,
        listAnimation: TelegramMediaFile,
        applicationAnimation: TelegramMediaFile
    ) {
        self.reaction = reaction
        self.appearAnimation = appearAnimation
        self.stillAnimation = stillAnimation
        self.listAnimation = listAnimation
        self.applicationAnimation = applicationAnimation
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
    
    private var isExpanded: Bool = true
    private var highlightedReaction: ReactionContextItem.Reaction?
    private var validLayout: (CGSize, UIEdgeInsets, CGRect)?
    private var isLeftAligned: Bool = true
    
    public var reactionSelected: ((ReactionContextItem) -> Void)?
    
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
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.previewingItemContainer = ASDisplayNode()
        self.previewingItemContainer.isUserInteractionEnabled = false
        
        self.contentContainer = ASDisplayNode()
        self.contentContainer.clipsToBounds = true
        self.contentContainer.addSubnode(self.scrollNode)
        
        self.contentContainerMask = UIImageView()
        let maskGradientWidth: CGFloat = 10.0
        self.contentContainerMask.image = generateImage(CGSize(width: maskGradientWidth * 2.0 + 1.0, height: 8.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let shadowColor = UIColor.black

            let stepCount = 10
            var colors: [CGColor] = []
            var locations: [CGFloat] = []

            for i in 0 ... stepCount {
                let t = CGFloat(i) / CGFloat(stepCount)
                colors.append(shadowColor.withAlphaComponent(t * t).cgColor)
                locations.append(t)
            }

            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: maskGradientWidth, y: 0.0), options: CGGradientDrawingOptions())
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0.0), end: CGPoint(x: maskGradientWidth + 1.0, y: 0.0), options: CGGradientDrawingOptions())
            context.setFillColor(shadowColor.cgColor)
            context.fill(CGRect(origin: CGPoint(x: maskGradientWidth, y: 0.0), size: CGSize(width: 1.0, height: size.height)))
        })?.stretchableImage(withLeftCapWidth: Int(maskGradientWidth), topCapHeight: 0)
        self.contentContainer.view.mask = self.contentContainerMask
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.contentContainer)
        self.addSubnode(self.previewingItemContainer)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: transition, animateInFromAnchorRect: nil, animateOutToAnchorRect: nil)
    }
    
    public func updateIsIntersectingContent(isIntersectingContent: Bool, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.updateIsIntersectingContent(isIntersectingContent: isIntersectingContent, transition: transition)
    }
    
    private func calculateBackgroundFrame(containerSize: CGSize, insets: UIEdgeInsets, anchorRect: CGRect, contentSize: CGSize) -> (backgroundFrame: CGRect, isLeftAligned: Bool, cloudSourcePoint: CGFloat) {
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
        if rect.maxX > containerSize.width - sideInset {
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
        
        return (rect, isLeftAligned, cloudSourcePoint)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrolling(transition: .immediate)
    }
    
    private func updateScrolling(transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 11.0
        let itemSpacing: CGFloat = 9.0
        let itemSize: CGFloat = 40.0
        let verticalInset: CGFloat = 13.0
        let rowHeight: CGFloat = 30.0
        
        let visibleBounds = self.scrollNode.view.bounds
        self.previewingItemContainer.bounds = visibleBounds
        
        var validIndices = Set<Int>()
        for i in 0 ..< self.items.count {
            let columnIndex = i
            let column = CGFloat(columnIndex)
            
            let itemOffsetY: CGFloat = -1.0
            
            let baseItemFrame = CGRect(origin: CGPoint(x: sideInset + column * (itemSize + itemSpacing), y: verticalInset + floor((rowHeight - itemSize) / 2.0) + itemOffsetY), size: CGSize(width: itemSize, height: itemSize))
            if visibleBounds.intersects(baseItemFrame) {
                validIndices.insert(i)
                
                var itemFrame = baseItemFrame
                let isPreviewing = false
                if self.highlightedReaction == self.items[i].reaction {
                    itemFrame = itemFrame.insetBy(dx: -4.0, dy: -4.0).offsetBy(dx: 0.0, dy: 0.0)
                    //isPreviewing = true
                }
                
                var animateIn = false
                
                let itemNode: ReactionNode
                if let current = self.visibleItemNodes[i] {
                    itemNode = current
                } else {
                    animateIn = self.didAnimateIn
                    
                    itemNode = ReactionNode(context: self.context, theme: self.theme, item: self.items[i])
                    self.visibleItemNodes[i] = itemNode
                    self.scrollNode.addSubnode(itemNode)
                }
                
                if !itemNode.isExtracted {
                    if isPreviewing {
                        /*if itemNode.supernode !== self.previewingItemContainer {
                            self.previewingItemContainer.addSubnode(itemNode)
                        }*/
                    } else {
                        /*if itemNode.supernode !== self.scrollNode {
                            self.scrollNode.addSubnode(itemNode)
                        }*/
                    }
                    
                    transition.updateFrame(node: itemNode, frame: itemFrame, beginWithCurrentState: true)
                    itemNode.updateLayout(size: itemFrame.size, isExpanded: false, isPreviewing: isPreviewing, transition: transition)
                    
                    if animateIn {
                        itemNode.animateIn()
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
        
        let (backgroundFrame, isLeftAligned, cloudSourcePoint) = self.calculateBackgroundFrame(containerSize: CGSize(width: size.width, height: size.height), insets: backgroundInsets, anchorRect: anchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight))
        self.isLeftAligned = isLeftAligned
        
        transition.updateFrame(node: self.contentContainer, frame: backgroundFrame)
        transition.updateFrame(view: self.contentContainerMask, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.previewingItemContainer, frame: backgroundFrame)
        self.scrollNode.view.contentSize = CGSize(width: completeContentWidth, height: backgroundFrame.size.height)
        
        self.updateScrolling(transition: transition)
        
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(
            theme: self.theme,
            size: backgroundFrame.size,
            cloudSourcePoint: cloudSourcePoint - backgroundFrame.minX,
            isLeftAligned: isLeftAligned,
            transition: transition
        )
        
        if let animateInFromAnchorRect = animateInFromAnchorRect {
            let springDuration: Double = 0.42
            let springDamping: CGFloat = 104.0
            let springDelay: Double = 0.22
            
            let sourceBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateInFromAnchorRect, contentSize: CGSize(width: backgroundFrame.height, height: contentHeight)).0
            
            self.backgroundNode.animateInFromAnchorRect(size: backgroundFrame.size, sourceBackgroundFrame: sourceBackgroundFrame.offsetBy(dx: -backgroundFrame.minX, dy: -backgroundFrame.minY))
            
            self.contentContainer.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: sourceBackgroundFrame.midX - backgroundFrame.midX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping, additive: true)
            self.contentContainer.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: CGPoint(), size: sourceBackgroundFrame.size)), to: NSValue(cgRect: CGRect(origin: CGPoint(), size: backgroundFrame.size)), keyPath: "bounds", duration: springDuration, delay: springDelay, initialVelocity: 0.0, damping: springDamping)
        } else if let animateOutToAnchorRect = animateOutToAnchorRect {
            let targetBackgroundFrame = self.calculateBackgroundFrame(containerSize: size, insets: backgroundInsets, anchorRect: animateOutToAnchorRect, contentSize: CGSize(width: visibleContentWidth, height: contentHeight)).0
            
            let offset = CGPoint(x: -(targetBackgroundFrame.minX - backgroundFrame.minX), y: -(targetBackgroundFrame.minY - backgroundFrame.minY))
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
        let mainCircleDelay: Double = 0.1
        
        self.backgroundNode.animateIn()
        
        self.didAnimateIn = true
        
        for i in 0 ..< self.items.count {
            guard let itemNode = self.visibleItemNodes[i] else {
                continue
            }
            let itemDelay = mainCircleDelay + 0.1 + Double(i) * 0.035
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + itemDelay, execute: { [weak itemNode] in
                itemNode?.animateIn()
            })
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
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.isHidden = false
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
    
    public func animateOutToReaction(value: String, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.item.reaction.rawValue != value {
                continue
            }
            
            self.animationTargetView = targetView
            self.animationHideNode = hideNode
            
            /*let standaloneReactionAnimation = StandaloneReactionAnimation()
            self.standaloneReactionAnimation = standaloneReactionAnimation
            standaloneReactionAnimation.frame = self.bounds
            self.addSubnode(standaloneReactionAnimation)
            standaloneReactionAnimation.animateReactionSelection(context: itemNode.context, theme: self.theme, reaction: itemNode.item, targetView: targetView, currentItemNode: itemNode, hideNode: hideNode, completion: completion)
            
            return*/
            
            if hideNode {
                targetView.isHidden = true
            }
            
            itemNode.isExtracted = true
            let selfSourceRect = itemNode.view.convert(itemNode.view.bounds, to: self.view)
            let selfTargetRect = self.view.convert(targetView.bounds, from: targetView)
            
            let expandedScale: CGFloat = 4.0
            let expandedSize = CGSize(width: floor(selfSourceRect.width * expandedScale), height: floor(selfSourceRect.height * expandedScale))
            
            var expandedFrame = CGRect(origin: CGPoint(x: floor(selfTargetRect.midX - expandedSize.width / 2.0), y: floor(selfTargetRect.midY - expandedSize.height / 2.0)), size: expandedSize)
            if expandedFrame.minX < -floor(expandedFrame.width * 0.05) {
                expandedFrame.origin.x = -floor(expandedFrame.width * 0.05)
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
            
            self.addSubnode(itemNode)
            //itemNode.position = selfSourceRect.center
            itemNode.position = expandedFrame.center
            transition.updateBounds(node: itemNode, bounds: CGRect(origin: CGPoint(), size: expandedFrame.size))
            itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, isPreviewing: false, transition: transition)
            
            transition.animatePositionWithKeyframes(node: itemNode, keyframes: generateParabollicMotionKeyframes(from: selfSourceRect.center, to: expandedFrame.center, elevation: 30.0))
            
            let additionalAnimationNode = AnimatedStickerNode()
            let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
            let animationFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5)
                .offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
            
            additionalAnimationNode.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: itemNode.item.applicationAnimation.resource), width: Int(animationFrame.width * 2.0), height: Int(animationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: itemNode.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(itemNode.item.applicationAnimation.resource.id)))
            additionalAnimationNode.frame = animationFrame
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }
            additionalAnimationNode.updateLayout(size: animationFrame.size)
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
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1 * UIView.animationDurationFactor(), execute: {
                additionalAnimationNode.visibility = true
            })
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + min(5.0, 2.0 * UIView.animationDurationFactor()), execute: {
                self.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: hideNode, completion: {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                })
            })
            return
        }
        completion()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentPoint = self.contentContainer.view.convert(point, from: self.view)
        if self.contentContainer.bounds.contains(contentPoint) {
            return self.contentContainer.hitTest(contentPoint, with: event)
        }
        
        return nil
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let point = recognizer.location(in: self.view)
            if let reaction = self.reaction(at: point) {
                self.reactionSelected?(reaction)
            }
        }
    }
    
    public func highlightGestureMoved(location: CGPoint) {
        let highlightedReaction = self.reaction(at: location)?.reaction
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
        if let highlightedReaction = self.highlightedReaction {
            self.highlightedReaction = nil
            if performAction {
                self.performReactionSelection(reaction: highlightedReaction)
            } else {
                if let (size, insets, anchorRect) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
                }
            }
        }
    }
    
    public func reaction(at point: CGPoint) -> ReactionContextItem? {
        for i in 0 ..< 2 {
            let touchInset: CGFloat = i == 0 ? 0.0 : 8.0
            for (_, itemNode) in self.visibleItemNodes {
                if itemNode.supernode === self.scrollNode && !self.scrollNode.bounds.intersects(itemNode.frame) {
                    continue
                }
                let itemPoint = self.view.convert(point, to: itemNode.view)
                if itemNode.bounds.insetBy(dx: -touchInset, dy: -touchInset).contains(itemPoint) {
                    return itemNode.item
                }
            }
        }
        return nil
    }
    
    public func performReactionSelection(reaction: ReactionContextItem.Reaction) {
        for (_, itemNode) in self.visibleItemNodes {
            if itemNode.item.reaction == reaction {
                self.reactionSelected?(itemNode.item)
                break
            }
        }
    }
    
    public func cancelReactionAnimation() {
        self.standaloneReactionAnimation?.cancel()
        
        if let animationTargetView = self.animationTargetView, self.animationHideNode {
            animationTargetView.isHidden = false
        }
    }
    
    public func setHighlightedReaction(_ value: ReactionContextItem.Reaction?) {
        self.highlightedReaction = value
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.18, curve: .easeInOut), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
    
    @objc private func disclosurePressed() {
        self.isExpanded = true
        if let (size, insets, anchorRect) = self.validLayout {
            self.updateLayout(size: size, insets: insets, anchorRect: anchorRect, transition: .animated(duration: 0.3, curve: .spring), animateInFromAnchorRect: nil, animateOutToAnchorRect: nil, animateReactionHighlight: true)
        }
    }
}

public final class StandaloneReactionAnimation: ASDisplayNode {
    private var itemNode: ReactionNode? = nil
    private let hapticFeedback = HapticFeedback()
    private var isCancelled: Bool = false
    
    private weak var targetView: UIView?
    private var hideNode: Bool = false
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionSelection(context: AccountContext, theme: PresentationTheme, reaction: ReactionContextItem, targetView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
        self.animateReactionSelection(context: context, theme: theme, reaction: reaction, targetView: targetView, currentItemNode: nil, hideNode: hideNode, completion: completion)
    }
        
    func animateReactionSelection(context: AccountContext, theme: PresentationTheme, reaction: ReactionContextItem, targetView: UIView, currentItemNode: ReactionNode?, hideNode: Bool, completion: @escaping () -> Void) {
        guard let sourceSnapshotView = targetView.snapshotContentTree() else {
            completion()
            return
        }
        
        self.targetView = targetView
        self.hideNode = hideNode
        
        let itemNode: ReactionNode
        if let currentItemNode = currentItemNode {
            itemNode = currentItemNode
        } else {
            itemNode = ReactionNode(context: context, theme: theme, item: reaction)
        }
        self.itemNode = itemNode
        
        self.addSubnode(itemNode)
        
        if hideNode {
            targetView.isHidden = true
        }
        
        itemNode.isExtracted = true
        let sourceItemSize: CGFloat = 40.0
        let selfTargetRect = self.view.convert(targetView.bounds, from: targetView)
        
        let expandedScale: CGFloat = 3.0
        let expandedSize = CGSize(width: floor(sourceItemSize * expandedScale), height: floor(sourceItemSize * expandedScale))
        
        var expandedFrame = CGRect(origin: CGPoint(x: floor(selfTargetRect.midX - expandedSize.width / 2.0), y: floor(selfTargetRect.midY - expandedSize.height / 2.0)), size: expandedSize)
        if expandedFrame.minX < -floor(expandedFrame.width * 0.05) {
            expandedFrame.origin.x = -floor(expandedFrame.width * 0.05)
        }
        
        sourceSnapshotView.frame = selfTargetRect
        self.view.addSubview(sourceSnapshotView)
        sourceSnapshotView.alpha = 0.0
        sourceSnapshotView.layer.animateSpring(from: 1.0 as NSNumber, to: (expandedFrame.width / selfTargetRect.width) as NSNumber, keyPath: "transform.scale", duration: 0.4)
        sourceSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.08, completion: { [weak sourceSnapshotView] _ in
            sourceSnapshotView?.removeFromSuperview()
        })
        
        self.addSubnode(itemNode)
        itemNode.frame = expandedFrame
        itemNode.updateLayout(size: expandedFrame.size, isExpanded: true, isPreviewing: false, transition: .immediate)
        
        itemNode.layer.animateSpring(from: (selfTargetRect.width / expandedFrame.width) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
        itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.04)
        
        let additionalAnimationNode = AnimatedStickerNode()
        let incomingMessage: Bool = expandedFrame.midX < self.bounds.width / 2.0
        let animationFrame = expandedFrame.insetBy(dx: -expandedFrame.width * 0.5, dy: -expandedFrame.height * 0.5)
            .offsetBy(dx: incomingMessage ? (expandedFrame.width - 50.0) : (-expandedFrame.width + 50.0), dy: 0.0)
        
        additionalAnimationNode.setup(source: AnimatedStickerResourceSource(account: itemNode.context.account, resource: itemNode.item.applicationAnimation.resource), width: Int(animationFrame.width * 2.0), height: Int(animationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: itemNode.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(itemNode.item.applicationAnimation.resource.id)))
        additionalAnimationNode.frame = animationFrame
        if incomingMessage {
            additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        }
        additionalAnimationNode.updateLayout(size: animationFrame.size)
        self.addSubnode(additionalAnimationNode)
        
        additionalAnimationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
        
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
                strongSelf.animateFromItemNodeToReaction(itemNode: itemNode, targetView: targetView, hideNode: hideNode, completion: {
                    mainAnimationCompleted = true
                    intermediateCompletion()
                })
            }
        }
        
        additionalAnimationNode.completed = { _ in
            additionalAnimationCompleted = true
            intermediateCompletion()
            
            beginDismissAnimation()
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1 * UIView.animationDurationFactor(), execute: {
            additionalAnimationNode.visibility = true
        })
        
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
        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.8)
        targetSnapshotView.layer.animatePosition(from: sourceFrame.center, to: targetPosition, duration: duration, removeOnCompletion: false)
        targetSnapshotView.layer.animateScale(from: itemNode.bounds.width / targetSnapshotView.bounds.width, to: 1.0, duration: duration, removeOnCompletion: false, completion: { [weak targetSnapshotView] _ in
            completedTarget = true
            intermediateCompletion()
            
            targetSnapshotView?.isHidden = true
            
            if hideNode {
                targetView.isHidden = false
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
        
        if let targetView = self.targetView, self.hideNode {
            targetView.isHidden = false
        }
    }
}

public final class StandaloneDismissReactionAnimation: ASDisplayNode {
    private let hapticFeedback = HapticFeedback()
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = false
    }
    
    public func animateReactionDismiss(sourceView: UIView, hideNode: Bool, completion: @escaping () -> Void) {
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
        if sourceRect.midX > self.bounds.width / 2.0 {
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
