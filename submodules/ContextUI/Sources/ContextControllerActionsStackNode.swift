import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import TelegramCore
import SwiftSignalKit
import AccountContext
import ReactionSelectionNode

public protocol ContextControllerActionsStackItemNode: ASDisplayNode {
    func update(
        presentationData: PresentationData,
        constrainedSize: CGSize,
        standardMinWidth: CGFloat,
        standardMaxWidth: CGFloat,
        transition: ContainedViewLayoutTransition
    ) -> (size: CGSize, apparentHeight: CGFloat)
    
    func highlightGestureMoved(location: CGPoint)
    func highlightGestureFinished(performAction: Bool)
}

public protocol ContextControllerActionsStackItem: AnyObject {
    func node(
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode
    
    var tip: ContextController.Tip? { get }
    var reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])? { get }
}

protocol ContextControllerActionsListItemNode: ASDisplayNode {
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void)
    
    func canBeHighlighted() -> Bool
    func updateIsHighlighted(isHighlighted: Bool)
    func performAction()
}

private final class ContextControllerActionsListActionItemNode: HighlightTrackingButtonNode, ContextControllerActionsListItemNode {
    private let getController: () -> ContextControllerProtocol?
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestUpdateAction: (AnyHashable, ContextMenuActionItem) -> Void
    private let item: ContextMenuActionItem
    
    private let highlightBackgroundNode: ASDisplayNode
    private let titleLabelNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let iconNode: ASImageNode
    
    private var iconDisposable: Disposable?
    
    init(
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdateAction: @escaping (AnyHashable, ContextMenuActionItem) -> Void,
        item: ContextMenuActionItem
    ) {
        self.getController = getController
        self.requestDismiss = requestDismiss
        self.requestUpdateAction = requestUpdateAction
        self.item = item
        
        self.highlightBackgroundNode = ASDisplayNode()
        self.highlightBackgroundNode.isAccessibilityElement = false
        self.highlightBackgroundNode.isUserInteractionEnabled = false
        self.highlightBackgroundNode.alpha = 0.0
        
        self.titleLabelNode = ImmediateTextNode()
        self.titleLabelNode.isAccessibilityElement = false
        self.titleLabelNode.displaysAsynchronously = false
        self.titleLabelNode.isUserInteractionEnabled = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.isAccessibilityElement = false
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isAccessibilityElement = false
        self.iconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityLabel = item.text
        
        self.addSubnode(self.highlightBackgroundNode)
        self.addSubnode(self.titleLabelNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.iconNode)
        
        self.isEnabled = self.canBeHighlighted()
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.highlightBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightBackgroundNode.alpha = 0.0
            }
        }
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.iconDisposable?.dispose()
    }
    
    @objc private func pressed() {
        guard let controller = self.getController() else {
            return
        }
        
        self.item.action?(ContextMenuActionItem.Action(
            controller: controller,
            dismissWithResult: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestDismiss(result)
            },
            updateAction: { [weak self] id, updatedAction in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdateAction(id, updatedAction)
            }
        ))
    }
    
    func canBeHighlighted() -> Bool {
        return self.item.action != nil
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.highlightBackgroundNode.alpha = isHighlighted ? 1.0 : 0.0
    }
    
    func performAction() {
        self.pressed()
    }
    
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let verticalInset: CGFloat = 11.0
        let titleSubtitleSpacing: CGFloat = 1.0
        let iconSideInset: CGFloat = 12.0
        let standardIconWidth: CGFloat = 32.0
        let iconSpacing: CGFloat = 8.0
        
        self.highlightBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        var subtitle: String?
        switch self.item.textLayout {
        case .singleLine:
            self.titleLabelNode.maximumNumberOfLines = 1
        case .twoLinesMax:
            self.titleLabelNode.maximumNumberOfLines = 2
        case let .secondLineWithValue(subtitleValue):
            self.titleLabelNode.maximumNumberOfLines = 1
            subtitle = subtitleValue
        case .multiline:
            self.titleLabelNode.maximumNumberOfLines = 0
        }
        
        let titleFont: UIFont
        switch self.item.textFont {
        case let .custom(font):
            titleFont = font
        case .small:
            let smallTextFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))
            titleFont = smallTextFont
        case .regular:
            titleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        }
        
        let subtitleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
        let subtitleColor = presentationData.theme.contextMenu.secondaryColor
        
        let titleColor: UIColor
        switch self.item.textColor {
        case .primary:
            titleColor = presentationData.theme.contextMenu.primaryColor
        case .destructive:
            titleColor = presentationData.theme.contextMenu.destructiveColor
        case .disabled:
            titleColor = presentationData.theme.contextMenu.primaryColor.withMultipliedAlpha(0.4)
        }
        
        self.titleLabelNode.attributedText = NSAttributedString(
            string: self.item.text,
            font: titleFont,
            textColor: titleColor
        )
        
        self.subtitleNode.attributedText = subtitle.flatMap { subtitle in
            return NSAttributedString(
                string: self.item.text,
                font: subtitleFont,
                textColor: subtitleColor
            )
        }
        
        let iconSize: CGSize?
        if let iconSource = self.item.iconSource {
            iconSize = iconSource.size
            if self.iconDisposable == nil {
                self.iconDisposable = (iconSource.signal |> deliverOnMainQueue).start(next: { [weak self] image in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.iconNode.image = image
                })
            }
        } else if let image = self.iconNode.image {
            iconSize = image.size
        } else {
            let iconImage = self.item.icon(presentationData.theme)
            self.iconNode.image = iconImage
            iconSize = iconImage?.size
        }
        
        var maxTextWidth: CGFloat = constrainedSize.width
        maxTextWidth -= sideInset
        if let iconSize = iconSize {
            maxTextWidth -= max(standardIconWidth, iconSize.width)
            maxTextWidth -= iconSpacing
        } else {
            maxTextWidth -= sideInset
        }
        maxTextWidth = max(1.0, maxTextWidth)
        
        let titleSize = self.titleLabelNode.updateLayout(CGSize(width: maxTextWidth, height: 1000.0))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: maxTextWidth, height: 1000.0))
        
        var minSize = CGSize()
        minSize.width += sideInset
        minSize.width += max(titleSize.width, subtitleSize.width)
        if let iconSize = iconSize {
            minSize.width += max(standardIconWidth, iconSize.width)
            minSize.width += iconSideInset
            minSize.width += iconSpacing
        } else {
            minSize.width += sideInset
        }
        minSize.height += verticalInset * 2.0
        minSize.height += titleSize.height
        if subtitle != nil {
            minSize.height += titleSubtitleSpacing
            minSize.height += subtitleSize.height
        }
        
        return (minSize: minSize, apply: { size, transition in
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: sideInset, y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
            
            transition.updateFrame(node: self.highlightBackgroundNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            transition.updateFrameAdditive(node: self.titleLabelNode, frame: titleFrame)
            transition.updateFrameAdditive(node: self.subtitleNode, frame: subtitleFrame)
            
            if let iconSize = iconSize {
                let iconWidth = max(standardIconWidth, iconSize.width)
                let iconFrame = CGRect(origin: CGPoint(x: size.width - iconSideInset - iconWidth + floor((iconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
                transition.updateFrame(node: self.iconNode, frame: iconFrame, beginWithCurrentState: true)
            }
        })
    }
}

private final class ContextControllerActionsListSeparatorItemNode: ASDisplayNode, ContextControllerActionsListItemNode {
    func canBeHighlighted() -> Bool {
        return false
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
    }
    
    func performAction() {
    }
    
    override init() {
        super.init()
    }
    
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        return (minSize: CGSize(width: 0.0, height: 7.0), apply: { _, _ in
            self.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
        })
    }
}

private final class ContextControllerActionsListCustomItemNode: ASDisplayNode, ContextControllerActionsListItemNode {
    func canBeHighlighted() -> Bool {
        if let itemNode = self.itemNode {
            return itemNode.canBeHighlighted()
        } else {
            return false
        }
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        if let itemNode = self.itemNode {
            itemNode.updateIsHighlighted(isHighlighted: isHighlighted)
        }
    }
    
    func performAction() {
        if let itemNode = self.itemNode {
            itemNode.performAction()
        }
    }
    
    private let getController: () -> ContextControllerProtocol?
    private let item: ContextMenuCustomItem
    
    private var presentationData: PresentationData?
    private var itemNode: ContextMenuCustomNode?
    
    init(
        getController: @escaping () -> ContextControllerProtocol?,
        item: ContextMenuCustomItem
    ) {
        self.getController = getController
        self.item = item
        
        super.init()
    }
    
    func update(presentationData: PresentationData, constrainedSize: CGSize) -> (minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void) {
        if self.presentationData?.theme !== presentationData.theme {
            if let itemNode = self.itemNode {
                itemNode.updateTheme(presentationData: presentationData)
            }
        }
        self.presentationData = presentationData
        
        let itemNode: ContextMenuCustomNode
        if let current = self.itemNode {
            itemNode = current
        } else {
            itemNode = self.item.node(
                presentationData: presentationData,
                getController: self.getController,
                actionSelected: { result in
                    let _ = result
                }
            )
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
        
        let itemLayoutAndApply = itemNode.updateLayout(constrainedWidth: constrainedSize.width, constrainedHeight: constrainedSize.height)
        
        return (minSize: itemLayoutAndApply.0, apply: { size, transition in
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            itemLayoutAndApply.1(size, transition)
        })
    }
}

final class ContextControllerActionsListStackItem: ContextControllerActionsStackItem {
    private final class Node: ASDisplayNode, ContextControllerActionsStackItemNode {
        private final class Item {
            let node: ContextControllerActionsListItemNode
            let separatorNode: ASDisplayNode?
            
            init(node: ContextControllerActionsListItemNode, separatorNode: ASDisplayNode?) {
                self.node = node
                self.separatorNode = separatorNode
            }
        }
        
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private var items: [ContextMenuItem]
        private var itemNodes: [Item]
        
        private var hapticFeedback: HapticFeedback?
        private var highlightedItemNode: Item?
        
        init(
            getController: @escaping () -> ContextControllerProtocol?,
            requestDismiss: @escaping (ContextMenuActionResult) -> Void,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            items: [ContextMenuItem]
        ) {
            self.requestUpdate = requestUpdate
            self.items = items
            
            var requestUpdateAction: ((AnyHashable, ContextMenuActionItem) -> Void)?
            self.itemNodes = items.map { item -> Item in
                switch item {
                case let .action(actionItem):
                    return Item(
                        node: ContextControllerActionsListActionItemNode(
                            getController: getController,
                            requestDismiss: requestDismiss,
                            requestUpdateAction: { id, action in
                                requestUpdateAction?(id, action)
                            },
                            item: actionItem
                        ),
                        separatorNode: ASDisplayNode()
                    )
                case .separator:
                    return Item(
                        node: ContextControllerActionsListSeparatorItemNode(),
                        separatorNode: nil
                    )
                case let .custom(customItem, _):
                    return Item(
                        node: ContextControllerActionsListCustomItemNode(
                            getController: getController,
                            item: customItem
                        ),
                        separatorNode: ASDisplayNode()
                    )
                }
            }
            
            super.init()
            
            for item in self.itemNodes {
                if let separatorNode = item.separatorNode {
                    self.addSubnode(separatorNode)
                }
            }
            for item in self.itemNodes {
                self.addSubnode(item.node)
            }
            
            requestUpdateAction = { [weak self] id, action in
                guard let strongSelf = self else {
                    return
                }
                loop: for i in 0 ..< strongSelf.items.count {
                    switch strongSelf.items[i] {
                    case let .action(currentAction):
                        if currentAction.id == id {
                            let previousNode = strongSelf.itemNodes[i]
                            previousNode.node.removeFromSupernode()
                            previousNode.separatorNode?.removeFromSupernode()
                            
                            let addedNode = Item(
                                node: ContextControllerActionsListActionItemNode(
                                    getController: getController,
                                    requestDismiss: requestDismiss,
                                    requestUpdateAction: { id, action in
                                        requestUpdateAction?(id, action)
                                    },
                                    item: action
                                ),
                                separatorNode: ASDisplayNode()
                            )
                            strongSelf.itemNodes[i] = addedNode
                            if let separatorNode = addedNode.separatorNode {
                                strongSelf.insertSubnode(separatorNode, at: 0)
                            }
                            strongSelf.addSubnode(addedNode.node)
                            
                            strongSelf.requestUpdate(.immediate)
                            
                            break loop
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            var itemNodeLayouts: [(minSize: CGSize, apply: (_ size: CGSize, _ transition: ContainedViewLayoutTransition) -> Void)] = []
            var combinedSize = CGSize()
            for item in self.itemNodes {
                item.separatorNode?.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                
                let itemNodeLayout = item.node.update(
                    presentationData: presentationData,
                    constrainedSize: CGSize(width: standardMaxWidth, height: constrainedSize.height)
                )
                itemNodeLayouts.append(itemNodeLayout)
                combinedSize.width = max(combinedSize.width, itemNodeLayout.minSize.width)
                combinedSize.height += itemNodeLayout.minSize.height
            }
            combinedSize.width = max(combinedSize.width, standardMinWidth)
            
            var nextItemOrigin = CGPoint()
            for i in 0 ..< self.itemNodes.count {
                let item = self.itemNodes[i]
                let itemNodeLayout = itemNodeLayouts[i]
                
                var itemTransition = transition
                if item.node.frame.isEmpty {
                    itemTransition = .immediate
                }
                
                let itemSize = CGSize(width: combinedSize.width, height: itemNodeLayout.minSize.height)
                let itemFrame = CGRect(origin: nextItemOrigin, size: itemSize)
                itemTransition.updateFrame(node: item.node, frame: itemFrame, beginWithCurrentState: true)
                
                if let separatorNode = item.separatorNode {
                    itemTransition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: itemFrame.minX, y: itemFrame.maxY), size: CGSize(width: itemFrame.width, height: UIScreenPixel)), beginWithCurrentState: true)
                    if i != self.itemNodes.count - 1 {
                        switch self.items[i + 1] {
                        case .separator:
                            separatorNode.isHidden = true
                        case .action:
                            separatorNode.isHidden = false
                        case .custom:
                            separatorNode.isHidden = false
                        }
                    } else {
                        separatorNode.isHidden = true
                    }
                }
                
                itemNodeLayout.apply(itemSize, itemTransition)
                nextItemOrigin.y += itemSize.height
            }
            
            return (combinedSize, combinedSize.height)
        }
        
        func highlightGestureMoved(location: CGPoint) {
            var highlightedItemNode: Item?
            for itemNode in self.itemNodes {
                if itemNode.node.frame.contains(location) {
                    if itemNode.node.canBeHighlighted() {
                        highlightedItemNode = itemNode
                    }
                    break
                }
            }
            if self.highlightedItemNode !== highlightedItemNode {
                self.highlightedItemNode?.node.updateIsHighlighted(isHighlighted: false)
                highlightedItemNode?.node.updateIsHighlighted(isHighlighted: true)
                
                self.highlightedItemNode = highlightedItemNode
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                self.hapticFeedback?.tap()
            }
        }
        
        func highlightGestureFinished(performAction: Bool) {
            if let highlightedItemNode = self.highlightedItemNode {
                self.highlightedItemNode = nil
                highlightedItemNode.node.updateIsHighlighted(isHighlighted: false)
                if performAction {
                    highlightedItemNode.node.performAction()
                }
            }
        }
    }
    
    private let items: [ContextMenuItem]
    let reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?
    let tip: ContextController.Tip?
    
    init(
        items: [ContextMenuItem],
        reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?,
        tip: ContextController.Tip?
    ) {
        self.items = items
        self.reactionItems = reactionItems
        self.tip = tip
    }
    
    func node(
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode {
        return Node(
            getController: getController,
            requestDismiss: requestDismiss,
            requestUpdate: requestUpdate,
            items: self.items
        )
    }
}

final class ContextControllerActionsCustomStackItem: ContextControllerActionsStackItem {
    private final class Node: ASDisplayNode, ContextControllerActionsStackItemNode {
        private let requestUpdate: (ContainedViewLayoutTransition) -> Void
        private let contentNode: ContextControllerItemsNode
        
        init(
            content: ContextControllerItemsContent,
            getController: @escaping () -> ContextControllerProtocol?,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
        ) {
            self.requestUpdate = requestUpdate
            self.contentNode = content.node(requestUpdate: { transition in
                requestUpdate(transition)
            }, requestUpdateApparentHeight: { transition in
                requestUpdateApparentHeight(transition)
            })
            
            super.init()
            
            self.addSubnode(self.contentNode)
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            let contentLayout = self.contentNode.update(
                presentationData: presentationData,
                constrainedWidth: constrainedSize.width,
                maxHeight: constrainedSize.height,
                bottomInset: 0.0,
                transition: transition
            )
            transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: contentLayout.cleanSize), beginWithCurrentState: true)
            
            return (contentLayout.cleanSize, contentLayout.apparentHeight)
        }
        
        func highlightGestureMoved(location: CGPoint) {
        }
        
        func highlightGestureFinished(performAction: Bool) {
        }
    }
    
    private let content: ContextControllerItemsContent
    let reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?
    let tip: ContextController.Tip?
    
    init(
        content: ContextControllerItemsContent,
        reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?,
        tip: ContextController.Tip?
    ) {
        self.content = content
        self.reactionItems = reactionItems
        self.tip = tip
    }
    
    func node(
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
        requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void
    ) -> ContextControllerActionsStackItemNode {
        return Node(
            content: self.content,
            getController: getController,
            requestUpdate: requestUpdate,
            requestUpdateApparentHeight: requestUpdateApparentHeight
        )
    }
}

func makeContextControllerActionsStackItem(items: ContextController.Items) -> ContextControllerActionsStackItem {
    var reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?
    if let context = items.context, !items.reactionItems.isEmpty {
        reactionItems = (context, items.reactionItems)
    }
    switch items.content {
    case let .list(listItems):
        return ContextControllerActionsListStackItem(items: listItems, reactionItems: reactionItems, tip: items.tip)
    case let .custom(customContent):
        return ContextControllerActionsCustomStackItem(content: customContent, reactionItems: reactionItems, tip: items.tip)
    }
}

final class ContextControllerActionsStackNode: ASDisplayNode {
    enum Presentation {
        case modal
        case inline
    }
    
    final class NavigationContainer: ASDisplayNode, UIGestureRecognizerDelegate {
        let backgroundNode: NavigationBackgroundNode
        let parentShadowNode: ASImageNode
        
        var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
        var requestPop: (() -> Void)?
        var transitionFraction: CGFloat = 0.0
        
        private var panRecognizer: InteractiveTransitionGestureRecognizer?
        
        var isNavigationEnabled: Bool = false {
            didSet {
                self.panRecognizer?.isEnabled = self.isNavigationEnabled
            }
        }
        
        override init() {
            self.backgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: false)
            self.parentShadowNode = ASImageNode()
            self.parentShadowNode.image = UIImage(bundleImageName: "Components/Context Menu/Shadow")?.stretchableImage(withLeftCapWidth: 60, topCapHeight: 48)
            
            super.init()
            
            self.addSubnode(self.backgroundNode)
            
            self.clipsToBounds = true
            self.cornerRadius = 14.0
            
            let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] point in
                guard let strongSelf = self else {
                    return []
                }
                let _ = strongSelf
                return [.right]
            })
            panRecognizer.delegate = self
            self.view.addGestureRecognizer(panRecognizer)
            self.panRecognizer = panRecognizer
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
                return false
            }
            if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.transitionFraction = 0.0
            case .changed:
                let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
                let transitionFraction = max(0.0, min(1.0, distanceFactor))
                if self.transitionFraction != transitionFraction {
                    self.transitionFraction = transitionFraction
                    self.requestUpdate?(.immediate)
                }
            case .ended, .cancelled:
                let distanceFactor: CGFloat = recognizer.translation(in: self.view).x / self.bounds.width
                let transitionFraction = max(0.0, min(1.0, distanceFactor))
                if transitionFraction > 0.2 {
                    self.transitionFraction = 0.0
                    self.requestPop?()
                } else {
                    self.transitionFraction = 0.0
                    self.requestUpdate?(.animated(duration: 0.45, curve: .spring))
                }
            default:
                break
            }
        }
        
        func update(presentationData: PresentationData, presentation: Presentation, size: CGSize, transition: ContainedViewLayoutTransition) {
            switch presentation {
            case .modal:
                self.backgroundNode.updateColor(color: presentationData.theme.contextMenu.backgroundColor, enableBlur: false, forceKeepBlur: false, transition: transition)
                self.parentShadowNode.isHidden = true
            case .inline:
                self.backgroundNode.updateColor(color: presentationData.theme.contextMenu.backgroundColor, enableBlur: true, forceKeepBlur: true, transition: transition)
                self.parentShadowNode.isHidden = false
            }
            self.backgroundNode.update(size: size, transition: transition)
        }
    }
    
    final class ItemContainer: ASDisplayNode {
        let requestUpdate: (ContainedViewLayoutTransition) -> Void
        let node: ContextControllerActionsStackItemNode
        let dimNode: ASDisplayNode
        let tip: ContextController.Tip?
        var tipNode: InnerTextSelectionTipContainerNode?
        let reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?
        var storedScrollingState: CGFloat?
        let positionLock: CGFloat?
        
        init(
            getController: @escaping () -> ContextControllerProtocol?,
            requestDismiss: @escaping (ContextMenuActionResult) -> Void,
            requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void,
            requestUpdateApparentHeight: @escaping (ContainedViewLayoutTransition) -> Void,
            item: ContextControllerActionsStackItem,
            tip: ContextController.Tip?,
            reactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])?,
            positionLock: CGFloat?
        ) {
            self.requestUpdate = requestUpdate
            self.node = item.node(
                getController: getController,
                requestDismiss: requestDismiss,
                requestUpdate: requestUpdate,
                requestUpdateApparentHeight: requestUpdateApparentHeight
            )
            
            self.dimNode = ASDisplayNode()
            self.dimNode.isUserInteractionEnabled = false
            self.dimNode.alpha = 0.0
            
            self.reactionItems = reactionItems
            self.positionLock = positionLock
            
            self.tip = tip
            
            super.init()
            
            self.clipsToBounds = true
            
            self.addSubnode(self.node)
            self.addSubnode(self.dimNode)
        }
        
        func update(
            presentationData: PresentationData,
            constrainedSize: CGSize,
            standardMinWidth: CGFloat,
            standardMaxWidth: CGFloat,
            transitionFraction: CGFloat,
            transition: ContainedViewLayoutTransition
        ) -> (size: CGSize, apparentHeight: CGFloat) {
            let (size, apparentHeight) = self.node.update(
                presentationData: presentationData,
                constrainedSize: constrainedSize,
                standardMinWidth: standardMinWidth,
                standardMaxWidth: standardMaxWidth,
                transition: transition
            )
            
            let maxScaleOffset: CGFloat = 10.0
            let scaleOffset: CGFloat = 0.0 * transitionFraction + maxScaleOffset * (1.0 - transitionFraction)
            let scale: CGFloat = (size.width - scaleOffset) / size.width
            let yOffset: CGFloat = size.height * (1.0 - scale)
            let transitionOffset = (1.0 - transitionFraction) * size.width / 2.0
            transition.updatePosition(node: self.node, position: CGPoint(x: size.width / 2.0 + scaleOffset / 2.0 + transitionOffset, y: size.height / 2.0 - yOffset / 2.0), beginWithCurrentState: true)
            transition.updateBounds(node: self.node, bounds: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            transition.updateTransformScale(node: self.node, scale: scale, beginWithCurrentState: true)
            
            return (size, apparentHeight)
        }
        
        func updateTip(presentationData: PresentationData, width: CGFloat, transition: ContainedViewLayoutTransition) -> (node: ASDisplayNode, height: CGFloat)? {
            if let tip = self.tip {
                var updatedTransition = transition
                if self.tipNode == nil {
                    updatedTransition = .immediate
                    let tipNode = InnerTextSelectionTipContainerNode(presentationData: presentationData, tip: tip)
                    tipNode.isUserInteractionEnabled = false
                    self.tipNode = tipNode
                }
                
                if let tipNode = self.tipNode {
                    let size = tipNode.updateLayout(widthClass: .compact, width: width, transition: updatedTransition)
                    return (tipNode, size.height)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        func updateDimNode(presentationData: PresentationData, size: CGSize, transitionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
            self.dimNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
            
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
            transition.updateAlpha(node: self.dimNode, alpha: 1.0 - transitionFraction, beginWithCurrentState: true)
        }
        
        func highlightGestureMoved(location: CGPoint) {
            self.node.highlightGestureMoved(location: self.view.convert(location, to: self.node.view))
        }
        
        func highlightGestureFinished(performAction: Bool) {
            self.node.highlightGestureFinished(performAction: performAction)
        }
    }
    
    private let getController: () -> ContextControllerProtocol?
    private let requestDismiss: (ContextMenuActionResult) -> Void
    private let requestUpdate: (ContainedViewLayoutTransition) -> Void
    
    private let navigationContainer: NavigationContainer
    private var itemContainers: [ItemContainer] = []
    private var dismissingItemContainers: [(container: ItemContainer, isPopped: Bool)] = []
    
    private var selectionPanGesture: UIPanGestureRecognizer?
    
    var topReactionItems: (context: AccountContext, reactionItems: [ReactionContextItem])? {
        return self.itemContainers.last?.reactionItems
    }
    
    var topPositionLock: CGFloat? {
        return self.itemContainers.last?.positionLock
    }
    
    var storedScrollingState: CGFloat? {
        return self.itemContainers.last?.storedScrollingState
    }
    
    init(
        getController: @escaping () -> ContextControllerProtocol?,
        requestDismiss: @escaping (ContextMenuActionResult) -> Void,
        requestUpdate: @escaping (ContainedViewLayoutTransition) -> Void
    ) {
        self.getController = getController
        self.requestDismiss = requestDismiss
        self.requestUpdate = requestUpdate
        
        self.navigationContainer = NavigationContainer()
        
        super.init()
        
        self.addSubnode(self.navigationContainer.parentShadowNode)
        self.addSubnode(self.navigationContainer)
        
        self.navigationContainer.requestUpdate = { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.requestUpdate(transition)
        }
        
        self.navigationContainer.requestPop = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pop()
        }
        
        let selectionPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.selectionPanGesture = selectionPanGesture
        self.view.addGestureRecognizer(selectionPanGesture)
        selectionPanGesture.isEnabled = false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            let location = recognizer.location(in: self.view)
            self.highlightGestureMoved(location: location)
        case .ended:
            self.highlightGestureFinished(performAction: true)
        case .cancelled:
            self.highlightGestureFinished(performAction: false)
        default:
            break
        }
    }
    
    func replace(item: ContextControllerActionsStackItem, animated: Bool) {
        for itemContainer in self.itemContainers {
            if animated {
                self.dismissingItemContainers.append((itemContainer, false))
            } else {
                itemContainer.removeFromSupernode()
            }
        }
        self.itemContainers.removeAll()
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        self.push(item: item, currentScrollingState: nil, positionLock: nil, animated: animated)
    }
    
    func push(item: ContextControllerActionsStackItem, currentScrollingState: CGFloat?, positionLock: CGFloat?, animated: Bool) {
        if let itemContainer = self.itemContainers.last {
            itemContainer.storedScrollingState = currentScrollingState
        }
        let itemContainer = ItemContainer(
            getController: self.getController,
            requestDismiss: self.requestDismiss,
            requestUpdate: self.requestUpdate,
            requestUpdateApparentHeight: { [weak self] transition in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestUpdate(transition)
            },
            item: item,
            tip: item.tip,
            reactionItems: item.reactionItems,
            positionLock: positionLock
        )
        self.itemContainers.append(itemContainer)
        self.navigationContainer.addSubnode(itemContainer)
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration:  self.itemContainers.count == 1 ? 0.3 : 0.45, curve: .spring)
        } else {
            transition = .immediate
        }
        self.requestUpdate(transition)
    }
    
    func clearStoredScrollingState() {
        self.itemContainers.last?.storedScrollingState = nil
    }
    
    func pop() {
        if self.itemContainers.count == 1 {
            //dismiss
        } else {
            let itemContainer = self.itemContainers[self.itemContainers.count - 1]
            self.itemContainers.remove(at: self.itemContainers.count - 1)
            self.dismissingItemContainers.append((itemContainer, true))
        }
        
        self.navigationContainer.isNavigationEnabled = self.itemContainers.count > 1
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
        self.requestUpdate(transition)
    }
    
    func update(
        presentationData: PresentationData,
        constrainedSize: CGSize,
        presentation: Presentation,
        transition: ContainedViewLayoutTransition
    ) -> CGSize {
        let tipSpacing: CGFloat = 10.0
        
        let animateAppearingContainers = transition.isAnimated && !self.dismissingItemContainers.isEmpty
        
        struct ItemLayout {
            var size: CGSize
            var apparentHeight: CGFloat
            var transitionFraction: CGFloat
            var alphaTransitionFraction: CGFloat
            var itemTransition: ContainedViewLayoutTransition
            var animateAppearingContainer: Bool
        }
        
        var topItemSize = CGSize()
        var itemLayouts: [ItemLayout] = []
        for i in 0 ..< self.itemContainers.count {
            let itemContainer = self.itemContainers[i]
            
            var animateAppearingContainer = false
            var itemContainerTransition = transition
            if itemContainer.bounds.isEmpty {
                itemContainerTransition = .immediate
                animateAppearingContainer = i == self.itemContainers.count - 1 && animateAppearingContainers || self.itemContainers.count > 1
            }
            
            let itemConstrainedHeight: CGFloat = constrainedSize.height
            
            let transitionFraction: CGFloat
            let alphaTransitionFraction: CGFloat
            if i == self.itemContainers.count - 1 {
                transitionFraction = self.navigationContainer.transitionFraction
                alphaTransitionFraction = 1.0
            } else if i == self.itemContainers.count - 2 {
                transitionFraction = self.navigationContainer.transitionFraction - 1.0
                alphaTransitionFraction = self.navigationContainer.transitionFraction
            } else {
                transitionFraction = 0.0
                alphaTransitionFraction = 0.0
            }
            
            let itemSize = itemContainer.update(
                presentationData: presentationData,
                constrainedSize: CGSize(width: constrainedSize.width, height: itemConstrainedHeight),
                standardMinWidth: 220.0,
                standardMaxWidth: 240.0,
                transitionFraction: alphaTransitionFraction,
                transition: itemContainerTransition
            )
            if i == self.itemContainers.count - 1 {
                topItemSize = itemSize.size
            }
            
            itemLayouts.append(ItemLayout(
                size: itemSize.size,
                apparentHeight: itemSize.apparentHeight,
                transitionFraction: transitionFraction,
                alphaTransitionFraction: alphaTransitionFraction,
                itemTransition: itemContainerTransition,
                animateAppearingContainer: animateAppearingContainer
            ))
        }
        
        let topItemApparentHeight: CGFloat
        let topItemWidth: CGFloat
        if itemLayouts.isEmpty {
            topItemApparentHeight = 0.0
            topItemWidth = 0.0
        } else if itemLayouts.count == 1 {
            topItemApparentHeight = itemLayouts[0].apparentHeight
            topItemWidth = itemLayouts[0].size.width
        } else {
            let lastItemLayout = itemLayouts[itemLayouts.count - 1]
            let previousItemLayout = itemLayouts[itemLayouts.count - 2]
            let transitionFraction = self.navigationContainer.transitionFraction
            
            topItemApparentHeight = lastItemLayout.apparentHeight * (1.0 - transitionFraction) + previousItemLayout.apparentHeight * transitionFraction
            topItemWidth = lastItemLayout.size.width * (1.0 - transitionFraction) + previousItemLayout.size.width * transitionFraction
        }
        
        let navigationContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: topItemWidth, height: max(14 * 2.0, topItemApparentHeight)))
        transition.updateFrame(node: self.navigationContainer, frame: navigationContainerFrame, beginWithCurrentState: true)
        self.navigationContainer.update(presentationData: presentationData, presentation: presentation, size: navigationContainerFrame.size, transition: transition)
        
        let navigationContainerShadowFrame = navigationContainerFrame.insetBy(dx: -30.0, dy: -30.0)
        transition.updateFrame(node: self.navigationContainer.parentShadowNode, frame: navigationContainerShadowFrame, beginWithCurrentState: true)
        
        for i in 0 ..< self.itemContainers.count {
            let xOffset: CGFloat
            if itemLayouts[i].transitionFraction < 0.0 {
                xOffset = itemLayouts[i].transitionFraction * itemLayouts[i].size.width
            } else {
                if i != 0 {
                    xOffset = itemLayouts[i].transitionFraction * itemLayouts[i - 1].size.width
                } else {
                    xOffset = itemLayouts[i].transitionFraction * topItemWidth
                }
            }
            let itemFrame = CGRect(origin: CGPoint(x: xOffset, y: 0.0), size: CGSize(width: itemLayouts[i].size.width, height: navigationContainerFrame.height))
            
            itemLayouts[i].itemTransition.updateFrame(node: self.itemContainers[i], frame: itemFrame, beginWithCurrentState: true)
            if itemLayouts[i].animateAppearingContainer {
                transition.animatePositionAdditive(node: self.itemContainers[i], offset: CGPoint(x: itemFrame.width, y: 0.0))
            }
            
            self.itemContainers[i].updateDimNode(presentationData: presentationData, size: CGSize(width: itemLayouts[i].size.width, height: navigationContainerFrame.size.height), transitionFraction: itemLayouts[i].alphaTransitionFraction, transition: transition)
            
            if let (tipNode, tipHeight) = self.itemContainers[i].updateTip(presentationData: presentationData, width: itemLayouts[i].size.width, transition: transition) {
                var tipTransition = transition
                if tipNode.supernode == nil {
                    tipTransition = .immediate
                    self.addSubnode(tipNode)
                }
                
                let tipAlpha: CGFloat = itemLayouts[i].alphaTransitionFraction
                
                tipTransition.updateFrame(node: tipNode, frame: CGRect(origin: CGPoint(x: navigationContainerFrame.minX, y: navigationContainerFrame.maxY + tipSpacing), size: CGSize(width: itemLayouts[i].size.width, height: tipHeight)), beginWithCurrentState: true)
                tipTransition.updateAlpha(node: tipNode, alpha: tipAlpha, beginWithCurrentState: true)
                
                if i == self.itemContainers.count - 1 {
                    topItemSize.height += tipSpacing + tipHeight
                }
            }
        }
        
        for (itemContainer, isPopped) in self.dismissingItemContainers {
            var position = itemContainer.position
            if isPopped {
                position.x = itemContainer.bounds.width / 2.0 + topItemWidth
            } else {
                position.x = itemContainer.bounds.width / 2.0 - topItemWidth
            }
            transition.updatePosition(node: itemContainer, position: position, completion: { [weak itemContainer] _ in
                itemContainer?.removeFromSupernode()
            })
            if let tipNode = itemContainer.tipNode {
                transition.updateAlpha(node: tipNode, alpha: 0.0, completion: { [weak tipNode] _ in
                    tipNode?.removeFromSupernode()
                })
            }
        }
        self.dismissingItemContainers.removeAll()
        
        return CGSize(width: topItemWidth, height: topItemSize.height)
    }
    
    func highlightGestureMoved(location: CGPoint) {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.highlightGestureMoved(location: self.view.convert(location, to: topItemContainer.view))
        }
    }
    
    func highlightGestureFinished(performAction: Bool) {
        if let topItemContainer = self.itemContainers.last {
            topItemContainer.highlightGestureFinished(performAction: performAction)
        }
    }
    
    func updatePanSelection(isEnabled: Bool) {
        if let selectionPanGesture = self.selectionPanGesture {
            selectionPanGesture.isEnabled = isEnabled
        }
    }
    
    func animateIn() {
        for itemContainer in self.itemContainers {
            if let tipNode = itemContainer.tipNode {
                tipNode.animateIn()
            }
        }
    }
}
