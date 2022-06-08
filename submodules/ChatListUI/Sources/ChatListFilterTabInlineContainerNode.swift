import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData

private final class ItemNodeDeleteButtonNode: HighlightableButtonNode {
    private let pressed: () -> Void
    
    private let contentImageNode: ASImageNode
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.contentImageNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.contentImageNode)
        
        self.addTarget(self, action: #selector(self.pressedEvent), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressedEvent() {
        self.pressed()
    }
    
    func update(theme: PresentationTheme) -> CGSize {
        let size = CGSize(width: 18.0, height: 18.0)
        if self.theme !== theme {
            self.theme = theme
            self.contentImageNode.image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor(rgb: 0xbbbbbb).cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(UIColor(rgb: 0xffffff).cgColor)
                context.setLineWidth(1.5)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 6.38, y: 6.38))
                context.addLine(to: CGPoint(x: 11.63, y: 11.63))
                context.strokePath()
                context.move(to: CGPoint(x: 6.38, y: 11.63))
                context.addLine(to: CGPoint(x: 11.63, y: 6.38))
                context.strokePath()
            })
        }
        
        self.contentImageNode.frame = CGRect(origin: CGPoint(), size: size)
        
        return size
    }
}

private final class ItemNode: ASDisplayNode {
    private let pressed: () -> Void
    private let requestedDeletion: () -> Void
    
    private let extractedContainerNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    
    private let extractedBackgroundNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let shortTitleNode: ImmediateTextNode
    private let badgeContainerNode: ASDisplayNode
    private let badgeTextNode: ImmediateTextNode
    private let badgeBackgroundActiveNode: ASImageNode
    private let badgeBackgroundInactiveNode: ASImageNode
    
    private var deleteButtonNode: ItemNodeDeleteButtonNode?
    private let buttonNode: HighlightTrackingButtonNode
    
    private var isSelected: Bool = false
    private(set) var unreadCount: Int = 0
    
    private var isReordering: Bool = false
    
    private var theme: PresentationTheme?
    
    init(pressed: @escaping () -> Void, requestedDeletion: @escaping () -> Void, contextGesture: @escaping (ContextExtractedContentContainingNode, ContextGesture) -> Void) {
        self.pressed = pressed
        self.requestedDeletion = requestedDeletion
        
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundNode = ASImageNode()
        self.extractedBackgroundNode.alpha = 0.0
        
        let titleInset: CGFloat = 4.0
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.shortTitleNode = ImmediateTextNode()
        self.shortTitleNode.displaysAsynchronously = false
        self.shortTitleNode.alpha = 0.0
        self.shortTitleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.badgeContainerNode = ASDisplayNode()
        
        self.badgeTextNode = ImmediateTextNode()
        self.badgeTextNode.displaysAsynchronously = false
        
        self.badgeBackgroundActiveNode = ASImageNode()
        self.badgeBackgroundActiveNode.displaysAsynchronously = false
        self.badgeBackgroundActiveNode.displayWithoutProcessing = true
        
        self.badgeBackgroundInactiveNode = ASImageNode()
        self.badgeBackgroundInactiveNode.displaysAsynchronously = false
        self.badgeBackgroundInactiveNode.displayWithoutProcessing = true
        self.badgeBackgroundInactiveNode.isHidden = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.extractedContainerNode.contentNode.addSubnode(self.extractedBackgroundNode)
        self.extractedContainerNode.contentNode.addSubnode(self.titleNode)
        self.extractedContainerNode.contentNode.addSubnode(self.shortTitleNode)
        self.badgeContainerNode.addSubnode(self.badgeBackgroundActiveNode)
        self.badgeContainerNode.addSubnode(self.badgeBackgroundInactiveNode)
        self.badgeContainerNode.addSubnode(self.badgeTextNode)
        self.extractedContainerNode.contentNode.addSubnode(self.badgeContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.buttonNode)
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            contextGesture(strongSelf.extractedContainerNode, gesture)
        }
        
        self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 32.0, color: strongSelf.isSelected ? UIColor(rgb: 0xbbbbbb) : UIColor(rgb: 0xf1f1f1))
            }
            transition.updateAlpha(node: strongSelf.extractedBackgroundNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundNode.image = nil
                }
            })
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateText(title: String, shortTitle: String, unreadCount: Int, unreadHasUnmuted: Bool, isNoFilter: Bool, isSelected: Bool, isEditing: Bool, isAllChats: Bool, isReordering: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.badgeBackgroundActiveNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.chatList.unreadBadgeActiveBackgroundColor)
            self.badgeBackgroundInactiveNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor)
        }
        
        self.containerNode.isGestureEnabled = !isEditing && !isReordering
        self.buttonNode.isUserInteractionEnabled = !isEditing && !isReordering
        
        self.isSelected = isSelected
        self.unreadCount = unreadCount
        
        transition.updateAlpha(node: self.containerNode, alpha: isReordering && isAllChats ? 0.5 : 1.0)
        
        if isReordering && !isAllChats {
            if self.deleteButtonNode == nil {
                let deleteButtonNode = ItemNodeDeleteButtonNode(pressed: { [weak self] in
                    self?.requestedDeletion()
                })
                self.extractedContainerNode.contentNode.addSubnode(deleteButtonNode)
                self.deleteButtonNode = deleteButtonNode
                if case .animated = transition {
                    deleteButtonNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.25)
                    deleteButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            }
        } else if let deleteButtonNode = self.deleteButtonNode {
            self.deleteButtonNode = nil
            transition.updateTransformScale(node: deleteButtonNode, scale: 0.1)
            transition.updateAlpha(node: deleteButtonNode, alpha: 0.0, completion: { [weak deleteButtonNode] _ in
                deleteButtonNode?.removeFromSupernode()
            })
        }
        
        transition.updateAlpha(node: self.badgeContainerNode, alpha: (isReordering || unreadCount == 0) ? 0.0 : 1.0)
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: isSelected ? presentationData.theme.contextMenu.badgeForegroundColor : presentationData.theme.list.itemSecondaryTextColor)
        self.shortTitleNode.attributedText = NSAttributedString(string: shortTitle, font: Font.bold(17.0), textColor: isSelected ? presentationData.theme.contextMenu.badgeForegroundColor : presentationData.theme.list.itemSecondaryTextColor)
        if unreadCount != 0 {
            self.badgeTextNode.attributedText = NSAttributedString(string: "\(unreadCount)", font: Font.regular(14.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
            self.badgeBackgroundActiveNode.isHidden = !isSelected && !unreadHasUnmuted
            self.badgeBackgroundInactiveNode.isHidden = isSelected || unreadHasUnmuted
        }
        
        if self.isReordering != isReordering {
            self.isReordering = isReordering
            if self.isReordering && !isAllChats {
                self.startShaking()
            } else {
                self.layer.removeAnimation(forKey: "shaking_position")
                self.layer.removeAnimation(forKey: "shaking_rotation")
            }
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> (width: CGFloat, shortWidth: CGFloat) {
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: -self.titleNode.insets.left, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        
        let shortTitleSize = self.shortTitleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        self.shortTitleNode.frame = CGRect(origin: CGPoint(x: -self.shortTitleNode.insets.left, y: floor((height - shortTitleSize.height) / 2.0)), size: shortTitleSize)
        
        if let deleteButtonNode = self.deleteButtonNode {
            if let theme = self.theme {
                let deleteButtonSize = deleteButtonNode.update(theme: theme)
                deleteButtonNode.frame = CGRect(origin: CGPoint(x: -deleteButtonSize.width + 7.0, y: 5.0), size: deleteButtonSize)
            }
        }
        
        let badgeSize = self.badgeTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        let badgeInset: CGFloat = 4.0
        let badgeBackgroundFrame = CGRect(origin: CGPoint(x: titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right + 5.0, y: floor((height - 18.0) / 2.0)), size: CGSize(width: max(18.0, badgeSize.width + badgeInset * 2.0), height: 18.0))
        self.badgeContainerNode.frame = badgeBackgroundFrame
        self.badgeBackgroundActiveNode.frame = CGRect(origin: CGPoint(), size: badgeBackgroundFrame.size)
        self.badgeBackgroundInactiveNode.frame = CGRect(origin: CGPoint(), size: badgeBackgroundFrame.size)
        self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((badgeBackgroundFrame.width - badgeSize.width) / 2.0), y: floor((badgeBackgroundFrame.height - badgeSize.height) / 2.0)), size: badgeSize)
        
        let width: CGFloat
        if self.unreadCount == 0 || self.isReordering {
            if !self.isReordering {
                self.badgeContainerNode.alpha = 0.0
            }
            width = titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right
        } else {
            if !self.isReordering {
                self.badgeContainerNode.alpha = 1.0
            }
            width = badgeBackgroundFrame.maxX
        }
        
        return (width, shortTitleSize.width - self.shortTitleNode.insets.left - self.shortTitleNode.insets.right)
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat, useShortTitle: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.titleNode, alpha: useShortTitle ? 0.0 : 1.0)
        transition.updateAlpha(node: self.shortTitleNode, alpha: useShortTitle ? 1.0 : 0.0)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))
        
        self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: self.extractedBackgroundNode.frame.minX, y: 0.0), size: CGSize(width: self.extractedBackgroundNode.frame.width, height: size.height))
        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        
        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -sideInset, bottom: 0.0, right: -sideInset)
        self.extractedContainerNode.hitTestSlop = self.hitTestSlop
        self.extractedContainerNode.contentNode.hitTestSlop = self.hitTestSlop
        self.containerNode.hitTestSlop = self.hitTestSlop
        
        let extractedBackgroundHeight: CGFloat = 32.0
        let extractedBackgroundInset: CGFloat = 14.0
        self.extractedBackgroundNode.frame = CGRect(origin: CGPoint(x: -extractedBackgroundInset, y: floor((size.height - extractedBackgroundHeight) / 2.0)), size: CGSize(width: size.width + extractedBackgroundInset * 2.0, height: extractedBackgroundHeight))
    }
    
    func animateBadgeIn() {
        if !self.isReordering {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
            self.badgeContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            ContainedViewLayoutTransition.immediate.updateSublayerTransformScale(node: self.badgeContainerNode, scale: 0.1)
            transition.updateSublayerTransformScale(node: self.badgeContainerNode, scale: 1.0)
        }
    }
    
    func animateBadgeOut() {
        if !self.isReordering {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
            self.badgeContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
            ContainedViewLayoutTransition.immediate.updateSublayerTransformScale(node: self.badgeContainerNode, scale: 1.0)
            transition.updateSublayerTransformScale(node: self.badgeContainerNode, scale: 0.1)
        }
    }
    
    private func startShaking() {
        func degreesToRadians(_ x: CGFloat) -> CGFloat {
            return .pi * x / 180.0
        }

        let duration: Double = 0.4
        let displacement: CGFloat = 1.0
        let degreesRotation: CGFloat = 2.0
        
        let negativeDisplacement = -1.0 * displacement
        let position = CAKeyframeAnimation.init(keyPath: "position")
        position.beginTime = 0.8
        position.duration = duration
        position.values = [
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement)),
            NSValue(cgPoint: CGPoint(x: 0, y: 0)),
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: 0)),
            NSValue(cgPoint: CGPoint(x: 0, y: negativeDisplacement)),
            NSValue(cgPoint: CGPoint(x: negativeDisplacement, y: negativeDisplacement))
        ]
        position.calculationMode = .linear
        position.isRemovedOnCompletion = false
        position.repeatCount = Float.greatestFiniteMagnitude
        position.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))
        position.isAdditive = true

        let transform = CAKeyframeAnimation.init(keyPath: "transform")
        transform.beginTime = 2.6
        transform.duration = 0.3
        transform.valueFunction = CAValueFunction(name: CAValueFunctionName.rotateZ)
        transform.values = [
            degreesToRadians(-1.0 * degreesRotation),
            degreesToRadians(degreesRotation),
            degreesToRadians(-1.0 * degreesRotation)
        ]
        transform.calculationMode = .linear
        transform.isRemovedOnCompletion = false
        transform.repeatCount = Float.greatestFiniteMagnitude
        transform.isAdditive = true
        transform.beginTime = CFTimeInterval(Float(arc4random()).truncatingRemainder(dividingBy: Float(25)) / Float(100))

        self.layer.add(position, forKey: "shaking_position")
        self.layer.add(transform, forKey: "shaking_rotation")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let deleteButtonNode = self.deleteButtonNode {
            if deleteButtonNode.frame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                return deleteButtonNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
}

private final class ItemNodePair {
    let regular: ItemNode
    let highlighted: ItemNode
    
    init(regular: ItemNode, highlighted: ItemNode) {
        self.regular = regular
        self.highlighted = highlighted
    }
}

final class ChatListFilterTabInlineContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private let itemsBackgroundView: UIVisualEffectView
    private let itemsBackgroundTintNode: ASImageNode
    
    private let selectedBackgroundNode: ASImageNode
    private var itemNodePairs: [ChatListFilterTabEntryId: ItemNodePair] = [:]
    private var itemsContainer: ASDisplayNode
    private var highlightedItemsClippingContainer: ASDisplayNode
    private var highlightedItemsContainer: ASDisplayNode
    
    var tabSelected: ((ChatListFilterTabEntryId) -> Void)?
    var tabRequestedDeletion: ((ChatListFilterTabEntryId) -> Void)?
    var addFilter: (() -> Void)?
    var contextGesture: ((Int32?, ContextExtractedContentContainingNode, ContextGesture, Bool) -> Void)?
    
    private var reorderingGesture: ReorderingGestureRecognizer?
    private var reorderingItem: ChatListFilterTabEntryId?
    private var reorderingItemPosition: (initial: CGFloat, offset: CGFloat)?
    private var reorderingAutoScrollAnimator: ConstantDisplayLinkAnimator?
    private var reorderedItemIds: [ChatListFilterTabEntryId]?
    private lazy var hapticFeedback = { HapticFeedback() }()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, isReordering: Bool, isEditing: Bool, transitionFraction: CGFloat, presentationData: PresentationData)?
    
    var reorderedFilterIds: [Int32]? {
        return self.reorderedItemIds.flatMap {
            $0.compactMap {
                switch $0 {
                case .all:
                    return 0
                case let .filter(id):
                    return id
                }
            }
        }
    }
    
    override init() {
        self.scrollNode = ASScrollNode()
        
        self.itemsBackgroundView = UIVisualEffectView()
        self.itemsBackgroundView.clipsToBounds = true
        self.itemsBackgroundView.layer.cornerRadius = 20.0
        
        self.itemsBackgroundTintNode = ASImageNode()
        self.itemsBackgroundTintNode.displaysAsynchronously = false
        self.itemsBackgroundTintNode.displayWithoutProcessing = true
        
        self.selectedBackgroundNode = ASImageNode()
        self.selectedBackgroundNode.displaysAsynchronously = false
        self.selectedBackgroundNode.displayWithoutProcessing = true
        
        self.itemsContainer = ASDisplayNode()
        
        self.highlightedItemsClippingContainer = ASDisplayNode()
        self.highlightedItemsClippingContainer.clipsToBounds = true
        self.highlightedItemsClippingContainer.layer.cornerRadius = 16.0
        
        self.highlightedItemsContainer = ASDisplayNode()
        
        super.init()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.view.addSubview(self.itemsBackgroundView)
        self.scrollNode.addSubnode(self.itemsBackgroundTintNode)
        self.scrollNode.addSubnode(self.itemsContainer)
        self.scrollNode.addSubnode(self.selectedBackgroundNode)
        self.scrollNode.addSubnode(self.highlightedItemsClippingContainer)
        self.highlightedItemsClippingContainer.addSubnode(self.highlightedItemsContainer)
        
        let reorderingGesture = ReorderingGestureRecognizer(shouldBegin: { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            for (id, itemNodePair) in strongSelf.itemNodePairs {
                if itemNodePair.regular.view.convert(itemNodePair.regular.bounds, to: strongSelf.view).contains(point) {
                    if case .all = id {
                        return false
                    }
                    return true
                }
            }
            return false
        }, began: { [weak self] point in
            guard let strongSelf = self, let _ = strongSelf.currentParams else {
                return
            }
            for (id, itemNodePair) in strongSelf.itemNodePairs {
                let itemFrame = itemNodePair.regular.view.convert(itemNodePair.regular.bounds, to: strongSelf.view)
                if itemFrame.contains(point) {
                    strongSelf.hapticFeedback.impact()
                    
                    strongSelf.reorderingItem = id
                    itemNodePair.regular.frame = itemFrame
                    strongSelf.reorderingAutoScrollAnimator = ConstantDisplayLinkAnimator(update: {
                        guard let strongSelf = self, let currentLocation = strongSelf.reorderingGesture?.currentLocation else {
                            return
                        }
                        let edgeWidth: CGFloat = 20.0
                        if currentLocation.x <= edgeWidth {
                            var contentOffset = strongSelf.scrollNode.view.contentOffset
                            contentOffset.x = max(0.0, contentOffset.x - 3.0)
                            strongSelf.scrollNode.view.setContentOffset(contentOffset, animated: false)
                        } else if currentLocation.x >= strongSelf.bounds.width - edgeWidth {
                            var contentOffset = strongSelf.scrollNode.view.contentOffset
                            contentOffset.x = max(0.0, min(strongSelf.scrollNode.view.contentSize.width - strongSelf.scrollNode.bounds.width, contentOffset.x + 3.0))
                            strongSelf.scrollNode.view.setContentOffset(contentOffset, animated: false)
                        }
                    })
                    strongSelf.reorderingAutoScrollAnimator?.isPaused = false
                    strongSelf.addSubnode(itemNodePair.regular)
                    
                    strongSelf.reorderingItemPosition = (itemNodePair.regular.frame.minX, 0.0)
                    if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, transitionFraction, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                    return
                }
            }
        }, ended: { [weak self] in
            guard let strongSelf = self, let reorderingItem = strongSelf.reorderingItem else {
                return
            }
            if let itemNodePair = strongSelf.itemNodePairs[reorderingItem] {
                let projectedItemFrame = itemNodePair.regular.view.convert(itemNodePair.regular.bounds, to: strongSelf.scrollNode.view)
                itemNodePair.regular.frame = projectedItemFrame
                strongSelf.itemsContainer.addSubnode(itemNodePair.regular)
            }
            
            strongSelf.reorderingItem = nil
            strongSelf.reorderingItemPosition = nil
            strongSelf.reorderingAutoScrollAnimator?.invalidate()
            strongSelf.reorderingAutoScrollAnimator = nil
            if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, transitionFraction, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
            }
        }, moved: { [weak self] offset in
            guard let strongSelf = self, let reorderingItem = strongSelf.reorderingItem else {
                return
            }
            if let reorderingItemNodePair = strongSelf.itemNodePairs[reorderingItem], let (initial, _) = strongSelf.reorderingItemPosition, let reorderedItemIds = strongSelf.reorderedItemIds, let currentItemIndex = reorderedItemIds.firstIndex(of: reorderingItem) {
                
                for (id, itemNodePair) in strongSelf.itemNodePairs {
                    guard let itemIndex = reorderedItemIds.firstIndex(of: id) else {
                        continue
                    }
                    if id != reorderingItem {
                        let itemFrame = itemNodePair.regular.view.convert(itemNodePair.regular.bounds, to: strongSelf.view)
                        if reorderingItemNodePair.regular.frame.intersects(itemFrame) {
                            let targetIndex: Int
                            if reorderingItemNodePair.regular.frame.midX < itemFrame.midX {
                                targetIndex = max(1, itemIndex - 1)
                            } else {
                                targetIndex = max(1, min(reorderedItemIds.count - 1, itemIndex))
                            }
                            if targetIndex != currentItemIndex {
                                strongSelf.hapticFeedback.tap()
                                
                                var updatedReorderedItemIds = reorderedItemIds
                                if targetIndex > currentItemIndex {
                                    updatedReorderedItemIds.insert(reorderingItem, at: targetIndex + 1)
                                    updatedReorderedItemIds.remove(at: currentItemIndex)
                                } else {
                                    updatedReorderedItemIds.remove(at: currentItemIndex)
                                    updatedReorderedItemIds.insert(reorderingItem, at: targetIndex)
                                }
                                strongSelf.reorderedItemIds = updatedReorderedItemIds
                                if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, transitionFraction, presentationData) = strongSelf.currentParams {
                                    strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
                                }
                            }
                            break
                        }
                    }
                }
                
                strongSelf.reorderingItemPosition = (initial, offset)
            }
            if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, transitionFraction, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, transitionFraction: transitionFraction, presentationData: presentationData, transition: .immediate)
            }
        })
        self.reorderingGesture = reorderingGesture
        self.view.addGestureRecognizer(reorderingGesture)
        reorderingGesture.isEnabled = false
    }
    
    private var previousSelectedAbsFrame: CGRect?
    private var previousSelectedFrame: CGRect?
    
    func cancelAnimations() {
        self.selectedBackgroundNode.layer.removeAllAnimations()
        self.scrollNode.layer.removeAllAnimations()
        self.highlightedItemsContainer.layer.removeAllAnimations()
        self.highlightedItemsClippingContainer.layer.removeAllAnimations()
    }
    
    func update(size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, isReordering: Bool, isEditing: Bool, transitionFraction: CGFloat, presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        let isFirstTime = self.currentParams == nil
        let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : proposedTransition
        
        var focusOnSelectedFilter = self.currentParams?.selectedFilter != selectedFilter
        let previousScrollBounds = self.scrollNode.bounds
        let previousContentWidth = self.scrollNode.view.contentSize.width
        
        if self.currentParams?.presentationData.theme !== presentationData.theme {
            if presentationData.theme.rootController.keyboardColor == .dark {
                self.itemsBackgroundView.effect = UIBlurEffect(style: .dark)
            } else {
                self.itemsBackgroundView.effect = UIBlurEffect(style: .light)
            }
            
            self.itemsBackgroundTintNode.image = generateStretchableFilledCircleImage(diameter: 40.0, color: UIColor(rgb: 0xf1f1f1))
            
            self.selectedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 32.0, color: UIColor(rgb: 0xbbbbbb))
        }
        
        if isReordering {
            if let reorderedItemIds = self.reorderedItemIds {
                let currentIds = Set(reorderedItemIds)
                if currentIds != Set(filters.map { $0.id }) {
                    var updatedReorderedItemIds = reorderedItemIds.filter { id in
                        return filters.contains(where: { $0.id == id })
                    }
                    for filter in filters {
                        if !currentIds.contains(filter.id) {
                            updatedReorderedItemIds.append(filter.id)
                        }
                    }
                    self.reorderedItemIds = updatedReorderedItemIds
                }
            } else {
                self.reorderedItemIds = filters.map { $0.id }
            }
        } else if self.reorderedItemIds != nil {
            self.reorderedItemIds = nil
        }
        
        self.currentParams = (size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering, isEditing, transitionFraction, presentationData: presentationData)
        
        self.reorderingGesture?.isEnabled = isEditing || isReordering
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        enum BadgeAnimation {
            case `in`
            case out
        }
        
        var badgeAnimations: [ChatListFilterTabEntryId: BadgeAnimation] = [:]
        
        var reorderedFilters: [ChatListFilterTabEntry] = filters
        if let reorderedItemIds = self.reorderedItemIds {
            reorderedFilters = reorderedItemIds.compactMap { id -> ChatListFilterTabEntry? in
                if let index = filters.firstIndex(where: { $0.id == id }) {
                    return filters[index]
                } else {
                    return nil
                }
            }
        }
        
        for filter in reorderedFilters {
            let itemNodePair: ItemNodePair
            var itemNodeTransition = transition
            var wasAdded = false
            if let current = self.itemNodePairs[filter.id] {
                itemNodePair = current
            } else {
                itemNodeTransition = .immediate
                wasAdded = true
                itemNodePair = ItemNodePair(regular: ItemNode(pressed: { [weak self] in
                    self?.tabSelected?(filter.id)
                }, requestedDeletion: { [weak self] in
                    self?.tabRequestedDeletion?(filter.id)
                }, contextGesture: { [weak self] sourceNode, gesture in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = false
                    strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = true
                    strongSelf.scrollNode.view.setContentOffset(strongSelf.scrollNode.view.contentOffset, animated: false)
                    switch filter {
                    case let .filter(id, _, _):
                        strongSelf.contextGesture?(id, sourceNode, gesture, false)
                    default:
                        strongSelf.contextGesture?(nil, sourceNode, gesture, false)
                    }
                }), highlighted: ItemNode(pressed: { [weak self] in
                    self?.tabSelected?(filter.id)
                }, requestedDeletion: { [weak self] in
                    self?.tabRequestedDeletion?(filter.id)
                }, contextGesture: { [weak self] sourceNode, gesture in
                    guard let strongSelf = self else {
                        return
                    }
                    switch filter {
                    case let .filter(id, _, _):
                        strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = false
                        strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = true
                        strongSelf.scrollNode.view.setContentOffset(strongSelf.scrollNode.view.contentOffset, animated: false)
                        strongSelf.contextGesture?(id, sourceNode, gesture, false)
                    default:
                        strongSelf.contextGesture?(nil, sourceNode, gesture, false)
                    }
                }))
                self.itemNodePairs[filter.id] = itemNodePair
            }
            let unreadCount: Int
            let unreadHasUnmuted: Bool
            var isNoFilter: Bool = false
            switch filter {
            case let .all(count):
                unreadCount = count
                unreadHasUnmuted = true
                isNoFilter = true
            case let .filter(_, _, unread):
                unreadCount = unread.value
                unreadHasUnmuted = unread.hasUnmuted
            }
            if !wasAdded && (itemNodePair.regular.unreadCount != 0) != (unreadCount != 0) {
                badgeAnimations[filter.id] = (unreadCount != 0) ? .in : .out
            }
            itemNodePair.regular.updateText(title: filter.title(strings: presentationData.strings), shortTitle: filter.shortTitle(strings: presentationData.strings), unreadCount: unreadCount, unreadHasUnmuted: unreadHasUnmuted, isNoFilter: isNoFilter, isSelected: false, isEditing: false, isAllChats: isNoFilter, isReordering: isEditing || isReordering, presentationData: presentationData, transition: itemNodeTransition)
            itemNodePair.highlighted.updateText(title: filter.title(strings: presentationData.strings), shortTitle: filter.shortTitle(strings: presentationData.strings), unreadCount: unreadCount, unreadHasUnmuted: unreadHasUnmuted, isNoFilter: isNoFilter, isSelected: true, isEditing: false, isAllChats: isNoFilter, isReordering: isEditing || isReordering, presentationData: presentationData, transition: itemNodeTransition)
        }
        var removeKeys: [ChatListFilterTabEntryId] = []
        for (id, _) in self.itemNodePairs {
            if !filters.contains(where: { $0.id == id }) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNodePair = self.itemNodePairs.removeValue(forKey: id) {
                let regular = itemNodePair.regular
                let highlighted = itemNodePair.highlighted
                transition.updateAlpha(node: regular, alpha: 0.0, completion: { [weak regular] _ in
                    regular?.removeFromSupernode()
                })
                transition.updateTransformScale(node: regular, scale: 0.1)
                transition.updateAlpha(node: highlighted, alpha: 0.0, completion: { [weak highlighted] _ in
                    highlighted?.removeFromSupernode()
                })
                transition.updateTransformScale(node: highlighted, scale: 0.1)
            }
        }
        
        var tabSizes: [(ChatListFilterTabEntryId, CGSize, CGSize, ItemNodePair, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        var selectionFrames: [CGRect] = []
        
        for filter in reorderedFilters {
            guard let itemNodePair = self.itemNodePairs[filter.id] else {
                continue
            }
            let wasAdded = itemNodePair.regular.supernode == nil
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
                self.itemsContainer.addSubnode(itemNodePair.regular)
                self.highlightedItemsContainer.addSubnode(itemNodePair.highlighted)
            }
            let (paneNodeWidth, paneNodeShortWidth) = itemNodePair.regular.updateLayout(height: size.height, transition: itemNodeTransition)
            let _ = itemNodePair.highlighted.updateLayout(height: size.height, transition: itemNodeTransition)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            let paneNodeShortSize = CGSize(width: paneNodeShortWidth, height: size.height)
            tabSizes.append((filter.id, paneNodeSize, paneNodeShortSize, itemNodePair, wasAdded))
            totalRawTabSize += paneNodeSize.width
            
            if case .animated = transition, let badgeAnimation = badgeAnimations[filter.id] {
                switch badgeAnimation {
                case .in:
                    itemNodePair.regular.animateBadgeIn()
                    itemNodePair.highlighted.animateBadgeIn()
                case .out:
                    itemNodePair.regular.animateBadgeOut()
                    itemNodePair.highlighted.animateBadgeOut()
                }
            }
        }
        
        let minSpacing: CGFloat = 30.0
        
        let resolvedInitialSideInset: CGFloat = 8.0 + 14.0 + 4.0 + sideInset
        
        var longTitlesWidth: CGFloat = 0.0
        var shortTitlesWidth: CGFloat = 0.0
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, paneNodeShortSize, _, _) = tabSizes[i]
            longTitlesWidth += paneNodeSize.width
            shortTitlesWidth += paneNodeShortSize.width
        }
        let totalSpacing = CGFloat(tabSizes.count - 1) * minSpacing
        let useShortTitles = (longTitlesWidth + totalSpacing + resolvedInitialSideInset * 2.0) > size.width
        
        var rawContentWidth = useShortTitles ? shortTitlesWidth : longTitlesWidth
        rawContentWidth += totalSpacing
        
        let resolvedSideInset = max(resolvedInitialSideInset, floor((size.width - rawContentWidth) / 2.0))
        
        var leftOffset: CGFloat = resolvedSideInset
        
        let itemsBackgroundLeftX = leftOffset - 14.0 - 4.0
        
        for i in 0 ..< tabSizes.count {
            let (itemId, paneNodeLongSize, paneNodeShortSize, itemNodePair, wasAdded) = tabSizes[i]
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
            }
            
            let useShortTitle = itemId == .all && useShortTitles
            let paneNodeSize = useShortTitle ? paneNodeShortSize : paneNodeLongSize
            
            let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
            
            if itemId == self.reorderingItem, let (initial, offset) = self.reorderingItemPosition {
                itemNodeTransition.updateSublayerTransformScale(node: itemNodePair.regular, scale: 1.2)
                itemNodeTransition.updateAlpha(node: itemNodePair.regular, alpha: 0.9)
                let offsetFrame = CGRect(origin: CGPoint(x: initial + offset, y: paneFrame.minY), size: paneFrame.size)
                itemNodeTransition.updateFrameAdditive(node: itemNodePair.regular, frame: offsetFrame)
                selectionFrames.append(offsetFrame)
            } else {
                itemNodeTransition.updateSublayerTransformScale(node: itemNodePair.regular, scale: 1.0)
                itemNodeTransition.updateAlpha(node: itemNodePair.regular, alpha: 1.0)
                if wasAdded {
                    itemNodePair.regular.frame = paneFrame
                    itemNodePair.regular.alpha = 0.0
                    itemNodeTransition.updateAlpha(node: itemNodePair.regular, alpha: 1.0)
                } else {
                    itemNodeTransition.updateFrameAdditive(node: itemNodePair.regular, frame: paneFrame)
                }
                selectionFrames.append(paneFrame)
            }
            
            if wasAdded {
                itemNodePair.highlighted.frame = paneFrame
                itemNodePair.highlighted.alpha = 0.0
                itemNodeTransition.updateAlpha(node: itemNodePair.highlighted, alpha: 1.0)
            } else {
                itemNodeTransition.updateFrameAdditive(node: itemNodePair.highlighted, frame: paneFrame)
            }
            
            itemNodePair.regular.updateArea(size: paneFrame.size, sideInset: minSpacing / 2.0, useShortTitle: useShortTitle, transition: itemNodeTransition)
            itemNodePair.regular.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing / 2.0, bottom: 0.0, right: -minSpacing / 2.0)
            
            itemNodePair.highlighted.updateArea(size: paneFrame.size, sideInset: minSpacing / 2.0, useShortTitle: useShortTitle, transition: itemNodeTransition)
            itemNodePair.highlighted.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing / 2.0, bottom: 0.0, right: -minSpacing / 2.0)
            
            leftOffset += paneNodeSize.width + minSpacing
        }
        leftOffset -= minSpacing
        let itemsBackgroundRightX = leftOffset + 14.0 + 4.0
        
        leftOffset += resolvedSideInset
        
        let backgroundFrame = CGRect(origin: CGPoint(x: itemsBackgroundLeftX, y: 0.0), size: CGSize(width: itemsBackgroundRightX - itemsBackgroundLeftX, height: size.height))
        transition.updateFrame(view: self.itemsBackgroundView, frame: backgroundFrame)
        transition.updateFrame(node: self.itemsBackgroundTintNode, frame: backgroundFrame)
        
        self.scrollNode.view.contentSize = CGSize(width: itemsBackgroundRightX + 8.0, height: size.height)

        var selectedFrame: CGRect?
        if let selectedFilter = selectedFilter, let currentIndex = reorderedFilters.firstIndex(where: { $0.id == selectedFilter }) {
            func interpolateFrame(from fromValue: CGRect, to toValue: CGRect, t: CGFloat) -> CGRect {
                return CGRect(x: floorToScreenPixels(toValue.origin.x * t + fromValue.origin.x * (1.0 - t)), y: floorToScreenPixels(toValue.origin.y * t + fromValue.origin.y * (1.0 - t)), width: floorToScreenPixels(toValue.size.width * t + fromValue.size.width * (1.0 - t)), height: floorToScreenPixels(toValue.size.height * t + fromValue.size.height * (1.0 - t)))
            }
            
            if currentIndex != 0 && transitionFraction > 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex - 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else if currentIndex != filters.count - 1 && transitionFraction < 0.0 {
                let currentFrame = selectionFrames[currentIndex]
                let previousFrame = selectionFrames[currentIndex + 1]
                selectedFrame = interpolateFrame(from: currentFrame, to: previousFrame, t: abs(transitionFraction))
            } else {
                selectedFrame = selectionFrames[currentIndex]
            }
        }
        
        transition.updateFrame(node: self.itemsContainer, frame: CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize))
        
        if let selectedFrame = selectedFrame {
            let wasAdded = self.selectedBackgroundNode.isHidden
            self.selectedBackgroundNode.isHidden = false
            let lineFrame = CGRect(origin: CGPoint(x: selectedFrame.minX - 14.0, y: floor((size.height - 32.0) / 2.0)), size: CGSize(width: selectedFrame.width + 14.0 * 2.0, height: 32.0))
            if wasAdded {
                self.selectedBackgroundNode.frame = lineFrame
                self.selectedBackgroundNode.alpha = 0.0
            } else {
                transition.updateFrame(node: self.selectedBackgroundNode, frame: lineFrame)
            }
            transition.updateFrame(node: self.highlightedItemsClippingContainer, frame: lineFrame)
            transition.updateFrame(node: self.highlightedItemsContainer, frame: CGRect(origin: CGPoint(x: -lineFrame.minX, y: -lineFrame.minY), size: self.scrollNode.view.contentSize))
            transition.updateAlpha(node: self.selectedBackgroundNode, alpha: isReordering ? 0.0 : 1.0)
            transition.updateAlpha(node: self.highlightedItemsClippingContainer, alpha: isReordering ? 0.0 : 1.0)
            
            if let previousSelectedFrame = self.previousSelectedFrame {
                let previousContentOffsetX = max(0.0, min(previousContentWidth - previousScrollBounds.width, floor(previousSelectedFrame.midX - previousScrollBounds.width / 2.0)))
                if abs(previousContentOffsetX - previousScrollBounds.minX) < 1.0 {
                    focusOnSelectedFilter = true
                }
            }
            
            if focusOnSelectedFilter && self.reorderingItem == nil {
                let updatedBounds: CGRect
                if transitionFraction.isZero && selectedFilter == reorderedFilters.first?.id {
                    updatedBounds = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
                } else if transitionFraction.isZero && selectedFilter == reorderedFilters.last?.id {
                    updatedBounds = CGRect(origin: CGPoint(x: max(0.0, self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width), y: 0.0), size: self.scrollNode.bounds.size)
                } else {
                    let contentOffsetX = max(0.0, min(self.scrollNode.view.contentSize.width - self.scrollNode.bounds.width, floor(selectedFrame.midX - self.scrollNode.bounds.width / 2.0)))
                    updatedBounds = CGRect(origin: CGPoint(x: contentOffsetX, y: 0.0), size: self.scrollNode.bounds.size)
                }
                self.scrollNode.bounds = updatedBounds
            }
            transition.animateHorizontalOffsetAdditive(node: self.scrollNode, offset: previousScrollBounds.minX - self.scrollNode.bounds.minX)
            
            self.previousSelectedAbsFrame = selectedFrame.offsetBy(dx: -self.scrollNode.bounds.minX, dy: 0.0)
            self.previousSelectedFrame = selectedFrame
        } else {
            self.selectedBackgroundNode.isHidden = true
            self.previousSelectedAbsFrame = nil
            self.previousSelectedFrame = nil
        }
    }
}

private class ReorderingGestureRecognizerTimerTarget: NSObject {
    private let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
        
        super.init()
    }
    
    @objc func timerEvent() {
        self.f()
    }
}

private final class ReorderingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let shouldBegin: (CGPoint) -> Bool
    private let began: (CGPoint) -> Void
    private let ended: () -> Void
    private let moved: (CGFloat) -> Void
    
    private var initialLocation: CGPoint?
    private var delayTimer: Foundation.Timer?
    
    var currentLocation: CGPoint?
    
    init(shouldBegin: @escaping (CGPoint) -> Bool, began: @escaping (CGPoint) -> Void, ended: @escaping () -> Void, moved: @escaping (CGFloat) -> Void) {
        self.shouldBegin = shouldBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        
        super.init(target: nil, action: nil)
        
        self.delegate = self
    }
    
    override func reset() {
        super.reset()
        
        self.initialLocation = nil
        self.delayTimer?.invalidate()
        self.delayTimer = nil
        self.currentLocation = nil
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        } else {
            return false
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard let location = touches.first?.location(in: self.view) else {
            self.state = .failed
            return
        }
        
        if self.state == .possible {
            if self.delayTimer == nil {
                if !self.shouldBegin(location) {
                    self.state = .failed
                    return
                }
                self.initialLocation = location
                let timer = Foundation.Timer(timeInterval: 0.2, target: ReorderingGestureRecognizerTimerTarget { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.delayTimer = nil
                    strongSelf.state = .began
                    strongSelf.began(location)
                }, selector: #selector(ReorderingGestureRecognizerTimerTarget.timerEvent), userInfo: nil, repeats: false)
                self.delayTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            } else {
                self.state = .failed
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.delayTimer?.invalidate()
        
        if self.state == .began || self.state == .changed {
            self.ended()
        }
        
        self.state = .failed
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if self.state == .began || self.state == .changed {
            self.delayTimer?.invalidate()
            self.ended()
            self.state = .failed
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) else {
            return
        }
        let offset = location.x - initialLocation.x
        self.currentLocation = location
        
        if self.delayTimer != nil {
            if abs(offset) > 4.0 {
                self.delayTimer?.invalidate()
                self.state = .failed
                return
            }
        } else {
            if self.state == .began || self.state == .changed {
                self.state = .changed
                self.moved(offset)
            }
        }
    }
}
