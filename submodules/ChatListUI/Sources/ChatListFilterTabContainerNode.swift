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
                context.setFillColor(theme.rootController.navigationBar.clearButtonBackgroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.rootController.navigationBar.clearButtonForegroundColor.cgColor)
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
    private let pressed: (Bool) -> Void
    private let requestedDeletion: () -> Void
    
    private let extractedContainerNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    
    private let extractedBackgroundNode: ASImageNode
    private let titleContainer: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let titleActiveNode: ImmediateTextNode
    private let shortTitleContainer: ASDisplayNode
    private let shortTitleNode: ImmediateTextNode
    private let shortTitleActiveNode: ImmediateTextNode
    private let badgeContainerNode: ASDisplayNode
    private let badgeTextNode: ImmediateTextNode
    private let badgeBackgroundActiveNode: ASImageNode
    private let badgeBackgroundInactiveNode: ASImageNode
    
    private var deleteButtonNode: ItemNodeDeleteButtonNode?
    private let buttonNode: HighlightTrackingButtonNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var selectionFraction: CGFloat = 0.0
    private(set) var unreadCount: Int = 0
    
    private var isReordering: Bool = false
    private var isEditing: Bool = false
    private var isDisabled: Bool = false
    
    private var theme: PresentationTheme?
    
    private var pointerInteraction: PointerInteraction?
    
    init(pressed: @escaping (Bool) -> Void, requestedDeletion: @escaping () -> Void, contextGesture: @escaping (ContextExtractedContentContainingNode, ContextGesture, Bool) -> Void) {
        self.pressed = pressed
        self.requestedDeletion = requestedDeletion
        
        self.extractedContainerNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundNode = ASImageNode()
        self.extractedBackgroundNode.alpha = 0.0
        
        let titleInset: CGFloat = 4.0
        
        self.titleContainer = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.titleActiveNode = ImmediateTextNode()
        self.titleActiveNode.displaysAsynchronously = false
        self.titleActiveNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        self.titleActiveNode.alpha = 0.0
        
        self.shortTitleContainer = ASDisplayNode()
        
        self.shortTitleNode = ImmediateTextNode()
        self.shortTitleNode.displaysAsynchronously = false
        self.shortTitleNode.alpha = 0.0
        self.shortTitleNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        
        self.shortTitleActiveNode = ImmediateTextNode()
        self.shortTitleActiveNode.displaysAsynchronously = false
        self.shortTitleActiveNode.alpha = 0.0
        self.shortTitleActiveNode.insets = UIEdgeInsets(top: titleInset, left: 0.0, bottom: titleInset, right: 0.0)
        self.shortTitleActiveNode.alpha = 0.0
        
        self.badgeContainerNode = ASDisplayNode()
        
        self.badgeTextNode = ImmediateTextNode()
        self.badgeTextNode.displaysAsynchronously = false
        
        self.badgeBackgroundActiveNode = ASImageNode()
        self.badgeBackgroundActiveNode.displaysAsynchronously = false
        self.badgeBackgroundActiveNode.displayWithoutProcessing = true
        
        self.badgeBackgroundInactiveNode = ASImageNode()
        self.badgeBackgroundInactiveNode.displaysAsynchronously = false
        self.badgeBackgroundInactiveNode.displayWithoutProcessing = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        self.isAccessibilityElement = true
        
        self.extractedContainerNode.contentNode.addSubnode(self.extractedBackgroundNode)
        self.extractedContainerNode.contentNode.addSubnode(self.titleContainer)
        self.titleContainer.addSubnode(self.titleNode)
        self.titleContainer.addSubnode(self.titleActiveNode)
        self.extractedContainerNode.contentNode.addSubnode(self.shortTitleContainer)
        self.shortTitleContainer.addSubnode(self.shortTitleNode)
        self.shortTitleContainer.addSubnode(self.shortTitleActiveNode)
        self.badgeContainerNode.addSubnode(self.badgeBackgroundInactiveNode)
        self.badgeContainerNode.addSubnode(self.badgeBackgroundActiveNode)
        self.badgeContainerNode.addSubnode(self.badgeTextNode)
        self.extractedContainerNode.contentNode.addSubnode(self.badgeContainerNode)
        self.extractedContainerNode.contentNode.addSubnode(self.buttonNode)
        
        self.containerNode.addSubnode(self.extractedContainerNode)
        self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
        self.addSubnode(self.containerNode)
    
        self.addSubnode(self.activateArea)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            contextGesture(strongSelf.extractedContainerNode, gesture, strongSelf.isDisabled)
        }
        
        self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self else {
                return
            }
            
            if isExtracted, let theme = strongSelf.theme {
                strongSelf.extractedBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.contextMenu.backgroundColor)
            }
            transition.updateAlpha(node: strongSelf.extractedBackgroundNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundNode.image = nil
                }
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.pointerInteraction = PointerInteraction(view: self.containerNode.view, customInteractionView: nil, style: .insetRectangle(-10.0, 4.0))
    }
    
    @objc private func buttonPressed() {
        self.pressed(self.isDisabled)
    }
    
    func updateText(strings: PresentationStrings, title: String, shortTitle: String, unreadCount: Int, unreadHasUnmuted: Bool, isNoFilter: Bool, selectionFraction: CGFloat, isEditing: Bool, isReordering: Bool, canReorderAllChats: Bool, isDisabled: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        self.isEditing = isEditing
        self.isDisabled = isDisabled
        
        if self.theme !== presentationData.theme {
            self.theme = presentationData.theme
            
            self.badgeBackgroundActiveNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.chatList.unreadBadgeActiveBackgroundColor)
            self.badgeBackgroundInactiveNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor)
        }
        
        self.activateArea.accessibilityLabel = title
        if unreadCount > 0 {
            self.activateArea.accessibilityValue = strings.VoiceOver_Chat_UnreadMessages(Int32(unreadCount))
        } else {
            self.activateArea.accessibilityValue = ""
        }
        
        self.containerNode.isGestureEnabled = !isEditing && !isReordering
        self.buttonNode.isUserInteractionEnabled = !isEditing && !isReordering
        
        self.selectionFraction = selectionFraction
        self.unreadCount = unreadCount
                
        if isReordering && !isNoFilter {
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
        
        transition.updateAlpha(node: self.badgeContainerNode, alpha: (isEditing || isDisabled || isReordering || unreadCount == 0) ? 0.0 : 1.0)
        
        let selectionAlpha: CGFloat = selectionFraction * selectionFraction
        let deselectionAlpha: CGFloat = isDisabled ? 0.5 : 1.0// - selectionFraction
        
        transition.updateAlpha(node: self.titleNode, alpha: deselectionAlpha)
        transition.updateAlpha(node: self.titleActiveNode, alpha: selectionAlpha)
        transition.updateAlpha(node: self.shortTitleNode, alpha: deselectionAlpha)
        transition.updateAlpha(node: self.shortTitleActiveNode, alpha: selectionAlpha)
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
        self.titleActiveNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: presentationData.theme.list.itemAccentColor)
        self.shortTitleNode.attributedText = NSAttributedString(string: shortTitle, font: Font.medium(14.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
        self.shortTitleActiveNode.attributedText = NSAttributedString(string: shortTitle, font: Font.medium(14.0), textColor: presentationData.theme.list.itemAccentColor)
        if unreadCount != 0 {
            self.badgeTextNode.attributedText = NSAttributedString(string: "\(unreadCount)", font: Font.regular(14.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
            let badgeSelectionFraction: CGFloat = unreadHasUnmuted ? 1.0 : selectionFraction
            
            let badgeSelectionAlpha: CGFloat = badgeSelectionFraction
            //let badgeDeselectionAlpha: CGFloat = 1.0 - badgeSelectionFraction
            
            transition.updateAlpha(node: self.badgeBackgroundActiveNode, alpha: badgeSelectionAlpha * badgeSelectionAlpha)
            //transition.updateAlpha(node: self.badgeBackgroundInactiveNode, alpha: badgeDeselectionAlpha)
            self.badgeBackgroundInactiveNode.alpha = 1.0
        }
        
        if self.isReordering != isReordering {
            self.isReordering = isReordering
            if self.isReordering {
                self.startShaking()
            } else {
                self.layer.removeAnimation(forKey: "shaking_position")
                self.layer.removeAnimation(forKey: "shaking_rotation")
            }
        }
    }
    
    func updateLayout(height: CGFloat, transition: ContainedViewLayoutTransition) -> (width: CGFloat, shortWidth: CGFloat) {
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let _ = self.titleActiveNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: -self.titleNode.insets.left, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        self.titleContainer.frame = titleFrame
        self.titleNode.frame = CGRect(origin: CGPoint(), size: titleFrame.size)
        self.titleActiveNode.frame = CGRect(origin: CGPoint(), size: titleFrame.size)
        
        let shortTitleSize = self.shortTitleNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let _ = self.shortTitleActiveNode.updateLayout(CGSize(width: 160.0, height: .greatestFiniteMagnitude))
        let shortTitleFrame = CGRect(origin: CGPoint(x: -self.shortTitleNode.insets.left, y: floor((height - shortTitleSize.height) / 2.0)), size: shortTitleSize)
        self.shortTitleContainer.frame = shortTitleFrame
        self.shortTitleNode.frame = CGRect(origin: CGPoint(), size: shortTitleFrame.size)
        self.shortTitleActiveNode.frame = CGRect(origin: CGPoint(), size: shortTitleFrame.size)
        
        if let deleteButtonNode = self.deleteButtonNode {
            if let theme = self.theme {
                let deleteButtonSize = deleteButtonNode.update(theme: theme)
                deleteButtonNode.frame = CGRect(origin: CGPoint(x: -deleteButtonSize.width + 3.0, y: 5.0), size: deleteButtonSize)
            }
        }
        
        let badgeSize = self.badgeTextNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        let badgeInset: CGFloat = 4.0
        let badgeBackgroundFrame = CGRect(origin: CGPoint(x: titleSize.width - self.titleNode.insets.left - self.titleNode.insets.right + 4.0, y: floor((height - 18.0) / 2.0)), size: CGSize(width: max(18.0, badgeSize.width + badgeInset * 2.0), height: 18.0))
        self.badgeContainerNode.frame = badgeBackgroundFrame
        self.badgeBackgroundActiveNode.frame = CGRect(origin: CGPoint(), size: badgeBackgroundFrame.size)
        self.badgeBackgroundInactiveNode.frame = CGRect(origin: CGPoint(), size: badgeBackgroundFrame.size)
        self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((badgeBackgroundFrame.width - badgeSize.width) / 2.0), y: floor((badgeBackgroundFrame.height - badgeSize.height) / 2.0)), size: badgeSize)
        
        let width: CGFloat
        if self.unreadCount == 0 || self.isReordering || self.isEditing || self.isDisabled {
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
        transition.updateAlpha(node: self.titleContainer, alpha: useShortTitle ? 0.0 : 1.0)
        transition.updateAlpha(node: self.shortTitleContainer, alpha: useShortTitle ? 1.0 : 0.0)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))
                
        self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: self.extractedBackgroundNode.frame.minX, y: 0.0), size: CGSize(width:self.extractedBackgroundNode.frame.width, height: size.height))
        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.activateArea.frame = CGRect(origin: CGPoint(), size: size)
        
        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -sideInset, bottom: 0.0, right: -sideInset)
        self.extractedContainerNode.hitTestSlop = self.hitTestSlop
        self.extractedContainerNode.contentNode.hitTestSlop = self.hitTestSlop
        self.containerNode.hitTestSlop = self.hitTestSlop
        
        let extractedBackgroundHeight: CGFloat = 36.0
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

enum ChatListFilterTabEntryId: Hashable {
    case all
    case filter(Int32)
}

struct ChatListFilterTabEntryUnreadCount: Equatable {
    let value: Int
    let hasUnmuted: Bool
}

enum ChatListFilterTabEntry: Equatable {
    case all(unreadCount: Int)
    case filter(id: Int32, text: String, unread: ChatListFilterTabEntryUnreadCount)
    
    var id: ChatListFilterTabEntryId {
        switch self {
        case .all:
            return .all
        case let .filter(id, _, _):
            return .filter(id)
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .all:
            return strings.ChatList_Tabs_AllChats
        case let .filter(_, text, _):
            return text
        }
    }
    
    func shortTitle(strings: PresentationStrings) -> String {
        switch self {
        case .all:
            return strings.ChatList_Tabs_All
        case let .filter(_, text, _):
            return text
        }
    }
}

final class ChatListFilterTabContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private let selectedLineNode: ASImageNode
    private var itemNodes: [ChatListFilterTabEntryId: ItemNode] = [:]
    
    var tabSelected: ((ChatListFilterTabEntryId, Bool) -> Void)?
    var tabRequestedDeletion: ((ChatListFilterTabEntryId) -> Void)?
    var addFilter: (() -> Void)?
    var contextGesture: ((Int32?, ContextExtractedContentContainingNode, ContextGesture, Bool) -> Void)?
    var presentPremiumTip: (() -> Void)?
    
    private var reorderingGesture: ReorderingGestureRecognizer?
    private var reorderingItem: ChatListFilterTabEntryId?
    private var reorderingItemPosition: (initial: CGFloat, offset: CGFloat)?
    private var reorderingAutoScrollAnimator: ConstantDisplayLinkAnimator?
    private var initialReorderedItemIds: [ChatListFilterTabEntryId]?
    private var reorderedItemIds: [ChatListFilterTabEntryId]?
    private lazy var hapticFeedback = { HapticFeedback() }()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, isReordering: Bool, isEditing: Bool, canReorderAllChats: Bool, filtersLimit: Int32?, transitionFraction: CGFloat, presentationData: PresentationData)?
    
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
    
    var filtersCount: Int32 {
        if let (_, _, filters, _, _, _, _, _, _, _) = self.currentParams {
            let filters = filters.filter { filter in
                if case .all = filter {
                    return false
                } else {
                    return true
                }
            }
            return Int32(filters.count)
        } else {
            return 0
        }
    }
    
    override init() {
        self.scrollNode = ASScrollNode()
        
        self.selectedLineNode = ASImageNode()
        self.selectedLineNode.displaysAsynchronously = false
        self.selectedLineNode.displayWithoutProcessing = true
        
        super.init()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.selectedLineNode)
        
        let reorderingGesture = ReorderingGestureRecognizer(shouldBegin: { [weak self] point in
            guard let strongSelf = self else {
                return false
            }
            for (_, itemNode) in strongSelf.itemNodes {
                if itemNode.view.convert(itemNode.bounds, to: strongSelf.view).contains(point) {
                    return true
                }
            }
            return false
        }, began: { [weak self] point in
            guard let strongSelf = self, let _ = strongSelf.currentParams else {
                return
            }
            strongSelf.initialReorderedItemIds = strongSelf.reorderedItemIds
            for (id, itemNode) in strongSelf.itemNodes {
                let itemFrame = itemNode.view.convert(itemNode.bounds, to: strongSelf.view)
                if itemFrame.contains(point) {
                    strongSelf.hapticFeedback.impact()
                    
                    strongSelf.reorderingItem = id
                    itemNode.frame = itemFrame
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
                    strongSelf.addSubnode(itemNode)
                    
                    strongSelf.reorderingItemPosition = (itemNode.frame.minX, 0.0)
                    if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, canReorderAllChats, filtersLimit, transitionFraction, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, canReorderAllChats: canReorderAllChats, filtersLimit: filtersLimit, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
                    }
                    return
                }
            }
        }, ended: { [weak self] in
            guard let strongSelf = self, let reorderingItem = strongSelf.reorderingItem else {
                return
            }
            if let itemNode = strongSelf.itemNodes[reorderingItem] {
                let projectedItemFrame = itemNode.view.convert(itemNode.bounds, to: strongSelf.scrollNode.view)
                itemNode.frame = projectedItemFrame
                strongSelf.scrollNode.addSubnode(itemNode)
            }
            
            if strongSelf.currentParams?.canReorderAllChats == false, let firstItem = strongSelf.reorderedItemIds?.first, case .filter = firstItem {
                strongSelf.reorderedItemIds = strongSelf.initialReorderedItemIds
                strongSelf.presentPremiumTip?()
            }
            
            strongSelf.reorderingItem = nil
            strongSelf.reorderingItemPosition = nil
            strongSelf.reorderingAutoScrollAnimator?.invalidate()
            strongSelf.reorderingAutoScrollAnimator = nil
            if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, canReorderAllChats, filtersLimit, transitionFraction, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, canReorderAllChats: canReorderAllChats, filtersLimit: filtersLimit, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
            }
        }, moved: { [weak self] offset in
            guard let strongSelf = self, let reorderingItem = strongSelf.reorderingItem else {
                return
            }
            
            let minIndex = 0
            if let reorderingItemNode = strongSelf.itemNodes[reorderingItem], let (initial, _) = strongSelf.reorderingItemPosition, let reorderedItemIds = strongSelf.reorderedItemIds, let currentItemIndex = reorderedItemIds.firstIndex(of: reorderingItem) {
                
                for (id, itemNode) in strongSelf.itemNodes {
                    guard let itemIndex = reorderedItemIds.firstIndex(of: id) else {
                        continue
                    }
                    if id != reorderingItem {
                        let itemFrame = itemNode.view.convert(itemNode.bounds, to: strongSelf.view)
                        if reorderingItemNode.frame.intersects(itemFrame) {
                            let targetIndex: Int
                            if reorderingItemNode.frame.midX < itemFrame.midX {
                                targetIndex = max(minIndex, itemIndex - 1)
                            } else {
                                targetIndex = max(minIndex, min(reorderedItemIds.count - 1, itemIndex))
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
                                if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, canReorderAllChats, filtersLimit, transitionFraction, presentationData) = strongSelf.currentParams {
                                    strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, canReorderAllChats: canReorderAllChats, filtersLimit: filtersLimit, transitionFraction: transitionFraction, presentationData: presentationData, transition: .animated(duration: 0.25, curve: .easeInOut))
                                }
                            }
                            break
                        }
                    }
                }
                
                strongSelf.reorderingItemPosition = (initial, offset)
            }
            if let (size, sideInset, filters, selectedFilter, isReordering, isEditing, canReorderAllChats, filtersLimit, transitionFraction, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering: isReordering, isEditing: isEditing, canReorderAllChats: canReorderAllChats, filtersLimit: filtersLimit, transitionFraction: transitionFraction, presentationData: presentationData, transition: .immediate)
            }
        })
        self.reorderingGesture = reorderingGesture
        self.view.addGestureRecognizer(reorderingGesture)
        reorderingGesture.isEnabled = false
    }
    
    private var previousSelectedAbsFrame: CGRect?
    private var previousSelectedFrame: CGRect?
    
    func cancelAnimations() {
        self.selectedLineNode.layer.removeAllAnimations()
        self.scrollNode.layer.removeAllAnimations()
    }
    
    func update(size: CGSize, sideInset: CGFloat, filters: [ChatListFilterTabEntry], selectedFilter: ChatListFilterTabEntryId?, isReordering: Bool, isEditing: Bool, canReorderAllChats: Bool, filtersLimit: Int32?, transitionFraction: CGFloat, presentationData: PresentationData, transition proposedTransition: ContainedViewLayoutTransition) {
        let isFirstTime = self.currentParams == nil
        let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : proposedTransition
        
        var isEditing = isEditing
        if isReordering {
            isEditing = false
        }
        
        var focusOnSelectedFilter = self.currentParams?.selectedFilter != selectedFilter
        let previousScrollBounds = self.scrollNode.bounds
        let previousContentWidth = self.scrollNode.view.contentSize.width
        
        if self.currentParams?.presentationData.theme !== presentationData.theme {
            self.selectedLineNode.image = generateImage(CGSize(width: 5.0, height: 3.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 4.0, height: 4.0)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 4.0, y: 0.0), size: CGSize(width: 4.0, height: 4.0)))
                context.fill(CGRect(x: 2.0, y: 0.0, width: size.width - 4.0, height: 4.0))
                context.fill(CGRect(x: 0.0, y: 2.0, width: size.width, height: 2.0))
            })?.resizableImage(withCapInsets: UIEdgeInsets(top: 3.0, left: 3.0, bottom: 0.0, right: 3.0), resizingMode: .stretch)
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
        
        self.currentParams = (size: size, sideInset: sideInset, filters: filters, selectedFilter: selectedFilter, isReordering, isEditing, canReorderAllChats, filtersLimit, transitionFraction, presentationData: presentationData)
        
        self.reorderingGesture?.isEnabled = isReordering
        
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
        
        var folderIndex = 0
        for i in 0 ..< reorderedFilters.count {
            let filter = reorderedFilters[i]
            
            let itemNode: ItemNode
            var itemNodeTransition = transition
            var wasAdded = false
            if let current = self.itemNodes[filter.id] {
                itemNode = current
            } else {
                itemNodeTransition = .immediate
                wasAdded = true
                itemNode = ItemNode(pressed: { [weak self] disabled in
                    self?.tabSelected?(filter.id, disabled)
                }, requestedDeletion: { [weak self] in
                    self?.tabRequestedDeletion?(filter.id)
                }, contextGesture: { [weak self] sourceNode, gesture, isDisabled in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = false
                    strongSelf.scrollNode.view.panGestureRecognizer.isEnabled = true
                    strongSelf.scrollNode.view.setContentOffset(strongSelf.scrollNode.view.contentOffset, animated: false)
                    switch filter {
                    case let .filter(id, _, _):
                        strongSelf.contextGesture?(id, sourceNode, gesture, isDisabled)
                    default:
                        strongSelf.contextGesture?(nil, sourceNode, gesture, isDisabled)
                    }
                })
                self.itemNodes[filter.id] = itemNode
            }
            let unreadCount: Int
            let unreadHasUnmuted: Bool
            var isNoFilter = false
            var isDisabled = false
            switch filter {
            case let .all(count):
                unreadCount = count
                unreadHasUnmuted = true
                isNoFilter = true
            case let .filter(_, _, unread):
                unreadCount = unread.value
                unreadHasUnmuted = unread.hasUnmuted
                
                if let filtersLimit = filtersLimit {
                    isDisabled = !canReorderAllChats && folderIndex >= filtersLimit
                }
                folderIndex += 1
            }
            if !wasAdded && (itemNode.unreadCount != 0) != (unreadCount != 0) {
                badgeAnimations[filter.id] = (unreadCount != 0) ? .in : .out
            }
            
            let selectionFraction: CGFloat
            if selectedFilter == filter.id {
                selectionFraction = 1.0 - abs(transitionFraction)
            } else if i != 0 && selectedFilter == reorderedFilters[i - 1].id {
                selectionFraction = max(0.0, -transitionFraction)
            } else if i != reorderedFilters.count - 1 && selectedFilter == reorderedFilters[i + 1].id {
                selectionFraction = max(0.0, transitionFraction)
            } else {
                selectionFraction = 0.0
            }
            
            itemNode.updateText(strings: presentationData.strings, title: filter.title(strings: presentationData.strings), shortTitle:  i == 0 ? filter.shortTitle(strings: presentationData.strings) : filter.title(strings: presentationData.strings), unreadCount: unreadCount, unreadHasUnmuted: unreadHasUnmuted, isNoFilter: isNoFilter, selectionFraction: selectionFraction, isEditing: isEditing, isReordering: isReordering, canReorderAllChats: canReorderAllChats, isDisabled: isDisabled, presentationData: presentationData, transition: itemNodeTransition)
        }
        var removeKeys: [ChatListFilterTabEntryId] = []
        for (id, _) in self.itemNodes {
            if !filters.contains(where: { $0.id == id }) {
                removeKeys.append(id)
            }
        }
        for id in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
                transition.updateTransformScale(node: itemNode, scale: 0.1)
            }
        }
        
        var tabSizes: [(ChatListFilterTabEntryId, CGSize, CGSize, ItemNode, Bool)] = []
        var totalRawTabSize: CGFloat = 0.0
        var selectionFrames: [CGRect] = []
        
        for filter in reorderedFilters {
            guard let itemNode = self.itemNodes[filter.id] else {
                continue
            }
            let wasAdded = itemNode.supernode == nil
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
                self.scrollNode.addSubnode(itemNode)
            }
            let (paneNodeWidth, paneNodeShortWidth) = itemNode.updateLayout(height: size.height, transition: itemNodeTransition)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            let paneNodeShortSize = CGSize(width: paneNodeShortWidth, height: size.height)
            tabSizes.append((filter.id, paneNodeSize, paneNodeShortSize, itemNode, wasAdded))
            totalRawTabSize += paneNodeSize.width
            
            if case .animated = transition, let badgeAnimation = badgeAnimations[filter.id] {
                switch badgeAnimation {
                case .in:
                    itemNode.animateBadgeIn()
                case .out:
                    itemNode.animateBadgeOut()
                }
            }
        }
        
        let minSpacing: CGFloat = 26.0
        
        let resolvedSideInset: CGFloat = 16.0 + sideInset
        var leftOffset: CGFloat = resolvedSideInset
        
        var longTitlesWidth: CGFloat = resolvedSideInset
        for i in 0 ..< tabSizes.count {
            let (_, paneNodeSize, _, _, _) = tabSizes[i]
            longTitlesWidth += paneNodeSize.width
            if i != tabSizes.count - 1 {
                longTitlesWidth += minSpacing
            }
        }
        longTitlesWidth += resolvedSideInset
        let useShortTitles = longTitlesWidth > size.width
        
        for i in 0 ..< tabSizes.count {
            let (itemId, paneNodeLongSize, paneNodeShortSize, paneNode, wasAdded) = tabSizes[i]
            var itemNodeTransition = transition
            if wasAdded {
                itemNodeTransition = .immediate
            }
            
            let useShortTitle = itemId == .all && useShortTitles
            let paneNodeSize = useShortTitle ? paneNodeShortSize : paneNodeLongSize
            
            let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
            
            if itemId == self.reorderingItem, let (initial, offset) = self.reorderingItemPosition {
                itemNodeTransition.updateSublayerTransformScale(node: paneNode, scale: 1.2)
                itemNodeTransition.updateAlpha(node: paneNode, alpha: 0.9)
                itemNodeTransition.updateFrameAdditive(node: paneNode, frame: CGRect(origin: CGPoint(x: initial + offset, y: paneFrame.minY), size: paneFrame.size))
            } else {
                itemNodeTransition.updateSublayerTransformScale(node: paneNode, scale: 1.0)
                itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
                if wasAdded {
                    paneNode.frame = paneFrame
                    paneNode.alpha = 0.0
                    itemNodeTransition.updateAlpha(node: paneNode, alpha: 1.0)
                } else {
                    itemNodeTransition.updateFrameAdditive(node: paneNode, frame: paneFrame)
                }
            }
            paneNode.updateArea(size: paneFrame.size, sideInset: minSpacing / 2.0, useShortTitle: useShortTitle, transition: itemNodeTransition)
            paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -minSpacing / 2.0, bottom: 0.0, right: -minSpacing / 2.0)
            
            selectionFrames.append(paneFrame)
            
            leftOffset += paneNodeSize.width + minSpacing
        }
        leftOffset -= minSpacing
        leftOffset += resolvedSideInset
        
        self.scrollNode.view.contentSize = CGSize(width: leftOffset, height: size.height)
        
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
        
        if let selectedFrame = selectedFrame {
            let wasAdded = self.selectedLineNode.isHidden
            self.selectedLineNode.isHidden = false
            let lineFrame = CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 3.0), size: CGSize(width: selectedFrame.width, height: 3.0))
            if wasAdded {
                self.selectedLineNode.frame = lineFrame
                self.selectedLineNode.alpha = 0.0
            } else {
                transition.updateFrame(node: self.selectedLineNode, frame: lineFrame)
            }
            
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
            self.selectedLineNode.isHidden = true
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
