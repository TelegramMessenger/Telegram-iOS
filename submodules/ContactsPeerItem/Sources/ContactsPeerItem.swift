import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import CheckNode
import AvatarNode
import TelegramStringFormatting
import AccountContext
import PeerPresenceStatusManager
import ItemListPeerItem
import ContextUI
import AccountContext
import ComponentFlow
import AnimationCache
import MultiAnimationRenderer
import EmojiStatusComponent
import MoreButtonNode
import TextFormat
import TextNodeWithEntities

public final class ContactItemHighlighting {
    public var chatLocation: ChatLocation?
    public var progress: CGFloat = 1.0
    
    public init(chatLocation: ChatLocation? = nil) {
        self.chatLocation = chatLocation
    }
}

public enum ContactsPeerItemStatus {
    public enum Icon {
        case autoremove
    }
    
    case none
    case presence(EnginePeer.Presence, PresentationDateTimeFormat)
    case addressName(String)
    case custom(string: NSAttributedString, multiline: Bool, isActive: Bool, icon: Icon?)
}

public enum ContactsPeerItemSelection: Equatable {
    case none
    case selectable(selected: Bool)
}

public enum ContactsPeerItemSelectionPosition: Equatable {
    case left
    case right
}

public struct ContactsPeerItemEditing: Equatable {
    public var editable: Bool
    public var editing: Bool
    public var revealed: Bool
    
    public init(editable: Bool, editing: Bool, revealed: Bool) {
        self.editable = editable
        self.editing = editing
        self.revealed = revealed
    }
}

public enum ContactsPeerItemPeerMode: Equatable {
    case generalSearch(isSavedMessages: Bool)
    case peer
    case memberList
    case app(isPopular: Bool)
}

public enum ContactsPeerItemAliasHandling {
    case standard
    case treatSelfAsSaved
}

public enum ContactsPeerItemBadgeType {
    case active
    case inactive
}

public struct ContactsPeerItemBadge {
    public var count: Int32
    public var type: ContactsPeerItemBadgeType
    
    public init(count: Int32, type: ContactsPeerItemBadgeType) {
        self.count = count
        self.type = type
    }
}

public enum ContactsPeerItemActionIcon {
    case none
    case add
    case voiceCall
    case videoCall
    case more
}

public struct ContactsPeerItemAction {
    public let icon: ContactsPeerItemActionIcon
    public let action: ((ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(icon: ContactsPeerItemActionIcon, action: @escaping (ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void) {
        self.icon = icon
        self.action = action
    }
}

public struct ContactsPeerItemButtonAction {
    public let title: String
    public let action: ((ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(title: String, action: @escaping (ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void) {
        self.title = title
        self.action = action
    }
}

public enum ContactsPeerItemPeer: Equatable {
    case thread(peer: EnginePeer, title: String, icon: Int64?, color: Int32)
    case peer(peer: EnginePeer?, chatPeer: EnginePeer?)
    case deviceContact(stableId: DeviceContactStableId, contact: DeviceContactBasicData)
    
    public static func ==(lhs: ContactsPeerItemPeer, rhs: ContactsPeerItemPeer) -> Bool {
        switch lhs {
        case let .thread(lhsPeer, lhsTitle, lhsIcon, lhsColor):
            if case let .thread(rhsPeer, rhsTitle, rhsIcon, rhsColor) = rhs {
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsTitle != rhsTitle {
                    return false
                }
                if lhsIcon != rhsIcon {
                    return false
                }
                if lhsColor != rhsColor {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .peer(lhsPeer, lhsChatPeer):
            if case let .peer(rhsPeer, rhsChatPeer) = rhs {
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsChatPeer != rhsChatPeer {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .deviceContact(stableId, contact):
            if case .deviceContact(stableId, contact) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public class ContactsPeerItem: ItemListItem, ListViewItemWithHeader {
    public enum SortIndex {
        case firstNameFirst
        case lastNameFirst
    }

    let presentationData: ItemListPresentationData
    let style: ItemListStyle
    public let sectionId: ItemListSectionId
    let sortOrder: PresentationPersonNameOrder
    let displayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peerMode: ContactsPeerItemPeerMode
    let aliasHandling: ContactsPeerItemAliasHandling
    public let peer: ContactsPeerItemPeer
    let status: ContactsPeerItemStatus
    let badge: ContactsPeerItemBadge?
    let rightLabelText: String?
    let requiresPremiumForMessaging: Bool
    let enabled: Bool
    let selection: ContactsPeerItemSelection
    let selectionPosition: ContactsPeerItemSelectionPosition
    let editing: ContactsPeerItemEditing
    let options: [ItemListPeerItemRevealOption]
    let additionalActions: [ContactsPeerItemAction]
    let actionIcon: ContactsPeerItemActionIcon
    let buttonAction: ContactsPeerItemButtonAction?
    let searchQuery: String?
    let isAd: Bool
    let alwaysShowLastSeparator: Bool
    let action: ((ContactsPeerItemPeer) -> Void)?
    let disabledAction: ((ContactsPeerItemPeer) -> Void)?
    let setPeerIdWithRevealedOptions: ((EnginePeer.Id?, EnginePeer.Id?) -> Void)?
    let deletePeer: ((EnginePeer.Id) -> Void)?
    let itemHighlighting: ContactItemHighlighting?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let arrowAction: (() -> Void)?
    let animationCache: AnimationCache?
    let animationRenderer: MultiAnimationRenderer?
    let storyStats: (total: Int, unseen: Int, hasUnseenCloseFriends: Bool)?
    let openStories: ((ContactsPeerItemPeer, ASDisplayNode) -> Void)?
    let adButtonAction: ((ASDisplayNode) -> Void)?
    let visibilityUpdated: ((Bool) -> Void)?
    
    public let selectable: Bool
    
    public let headerAccessoryItem: ListViewAccessoryItem?
    
    public let header: ListViewItemHeader?
    
    public init(
        presentationData: ItemListPresentationData,
        style: ItemListStyle = .plain,
        sectionId: ItemListSectionId = 0,
        sortOrder: PresentationPersonNameOrder,
        displayOrder: PresentationPersonNameOrder,
        context: AccountContext,
        peerMode: ContactsPeerItemPeerMode,
        aliasHandling: ContactsPeerItemAliasHandling = .treatSelfAsSaved,
        peer: ContactsPeerItemPeer,
        status: ContactsPeerItemStatus,
        badge: ContactsPeerItemBadge? = nil,
        rightLabelText: String? = nil,
        requiresPremiumForMessaging: Bool = false,
        enabled: Bool,
        selection: ContactsPeerItemSelection,
        selectionPosition: ContactsPeerItemSelectionPosition = .right,
        editing: ContactsPeerItemEditing,
        options: [ItemListPeerItemRevealOption] = [],
        additionalActions: [ContactsPeerItemAction] = [],
        actionIcon: ContactsPeerItemActionIcon = .none,
        buttonAction: ContactsPeerItemButtonAction? = nil,
        index: SortIndex?,
        header: ListViewItemHeader?,
        searchQuery: String? = nil,
        isAd: Bool = false,
        alwaysShowLastSeparator: Bool = false,
        action: ((ContactsPeerItemPeer) -> Void)?,
        disabledAction: ((ContactsPeerItemPeer) -> Void)? = nil,
        setPeerIdWithRevealedOptions: ((EnginePeer.Id?, EnginePeer.Id?) -> Void)? = nil,
        deletePeer: ((EnginePeer.Id) -> Void)? = nil,
        itemHighlighting: ContactItemHighlighting? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil, arrowAction: (() -> Void)? = nil,
        animationCache: AnimationCache? = nil,
        animationRenderer: MultiAnimationRenderer? = nil,
        storyStats: (total: Int, unseen: Int, hasUnseenCloseFriends: Bool)? = nil,
        openStories: ((ContactsPeerItemPeer, ASDisplayNode) -> Void)? = nil,
        adButtonAction: ((ASDisplayNode) -> Void)? = nil,
        visibilityUpdated: ((Bool) -> Void)? = nil
    ) {
        self.presentationData = presentationData
        self.style = style
        self.sectionId = sectionId
        self.sortOrder = sortOrder
        self.displayOrder = displayOrder
        self.context = context
        self.peerMode = peerMode
        self.aliasHandling = aliasHandling
        self.peer = peer
        self.status = status
        self.badge = badge
        self.rightLabelText = rightLabelText
        self.requiresPremiumForMessaging = requiresPremiumForMessaging
        self.enabled = enabled
        self.selection = selection
        self.selectionPosition = selectionPosition
        self.editing = editing
        self.options = options
        self.additionalActions = additionalActions
        self.actionIcon = actionIcon
        self.buttonAction = buttonAction
        self.searchQuery = searchQuery
        self.isAd = isAd
        self.alwaysShowLastSeparator = alwaysShowLastSeparator
        self.action = action
        self.disabledAction = disabledAction
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.header = header
        self.itemHighlighting = itemHighlighting
        self.selectable = (enabled && action != nil) || disabledAction != nil
        self.contextAction = contextAction
        self.arrowAction = arrowAction
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.storyStats = storyStats
        self.openStories = openStories
        self.adButtonAction = adButtonAction
        self.visibilityUpdated = visibilityUpdated
        
        if let index = index {
            var letter: String = "#"
            switch peer {
                case let .thread(_, title, _, _):
                    letter = String(title.prefix(1)).uppercased()
                case let .peer(peer, _):
                    if case let .user(user) = peer {
                        switch index {
                            case .firstNameFirst:
                                if let firstName = user.firstName, !firstName.isEmpty {
                                    letter = String(firstName.prefix(1)).uppercased()
                                } else if let lastName = user.lastName, !lastName.isEmpty {
                                    letter = String(lastName.prefix(1)).uppercased()
                                }
                            case .lastNameFirst:
                                if let lastName = user.lastName, !lastName.isEmpty {
                                    letter = String(lastName.prefix(1)).uppercased()
                                } else if let firstName = user.firstName, !firstName.isEmpty {
                                    letter = String(firstName.prefix(1)).uppercased()
                                }
                        }
                    } else if case let .legacyGroup(group) = peer {
                        if !group.title.isEmpty {
                            letter = String(group.title.prefix(1)).uppercased()
                        }
                    } else if case let .channel(channel) = peer {
                        if !channel.title.isEmpty {
                            letter = String(channel.title.prefix(1)).uppercased()
                        }
                    }
                case let .deviceContact(_, contact):
                    switch index {
                        case .firstNameFirst:
                            if !contact.firstName.isEmpty {
                                letter = String(contact.firstName.prefix(1)).uppercased()
                            } else if !contact.lastName.isEmpty {
                                letter = String(contact.lastName.prefix(1)).uppercased()
                            }
                        case .lastNameFirst:
                            if !contact.lastName.isEmpty {
                                letter = String(contact.lastName.prefix(1)).uppercased()
                            } else if !contact.firstName.isEmpty {
                                letter = String(contact.firstName.prefix(1)).uppercased()
                            }
                    }
            }
            self.headerAccessoryItem = ContactsSectionHeaderAccessoryItem(sectionHeader: .letter(letter), theme: presentationData.theme)
        } else {
            self.headerAccessoryItem = nil
        }
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ContactsPeerItemNode()
            let makeLayout = node.asyncLayout()
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            let (nodeLayout, nodeApply) = makeLayout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    let (signal, apply) = nodeApply()
                    return (signal, { _ in
                        apply(false, synchronousLoads)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ContactsPeerItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply().1(animation.isAnimated, false)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        if self.enabled {
            self.action?(self.peer)
        } else {
            listView.clearHighlightAnimated(true)
            self.disabledAction?(self.peer)
        }
    }
    
    static func mergeType(item: ContactsPeerItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ListViewItemWithHeader {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        if let nextItem = nextItem {
            if let header = item.header {
                if let nextItem = nextItem as? ListViewItemWithHeader {
                    last = header.id != nextItem.header?.id
                } else {
                    last = true
                }
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader)
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

public class ContactsPeerItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    public let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let extractedBackgroundImageNode: ASImageNode

    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let offsetContainerNode: ASDisplayNode
    private let avatarNodeContainer: ASDisplayNode
    public let avatarNode: AvatarNode
    private var avatarBadgeBackground: UIImageView?
    private var avatarBadge: UIImageView?
    private var avatarIconView: ComponentHostView<Empty>?
    private var avatarIconComponent: EmojiStatusComponent?
    public let titleNode: TextNode
    private var credibilityIconView: ComponentHostView<Empty>?
    private var credibilityIconComponent: EmojiStatusComponent?
    private var verifiedIconView: ComponentHostView<Empty>?
    private var verifiedIconComponent: EmojiStatusComponent?
    public let statusNode: TextNodeWithEntities
    private var statusIconNode: ASImageNode?
    private var badgeBackgroundNode: ASImageNode?
    private var badgeTextNode: TextNode?
    private var selectionNode: CheckNode?
    private var actionButtonNodes: [HighlightableButtonNode]?
    private var moreButtonNode: MoreButtonNode?
    private var arrowButtonNode: HighlightableButtonNode?
    private var rightLabelTextNode: TextNode?
    
    private var adButton: HighlightableButtonNode?
    
    private var actionButtonNode: HighlightTrackingButtonNode?
    private var actionButtonTitleNode: TextNode?
    private var actionButtonBackgroundNode: ASImageNode?
    
    private var avatarTapRecognizer: UITapGestureRecognizer?
    
    private var isHighlighted: Bool = false

    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (ContactsPeerItem, ListViewItemLayoutParams, Bool, Bool, Bool, ItemListNeighbors)?
    public var chatPeer: EnginePeer? {
        if let peer = self.layoutParams?.0.peer {
            switch peer {
                case let .peer(peer, chatPeer):
                    return chatPeer ?? peer
                case .deviceContact:
                    return nil
                case .thread:
                    return nil
            }
        } else {
            return nil
        }
    }
    
    public var item: ContactsPeerItem? {
        return self.layoutParams?.0
    }
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = self.visibilityStatus
            let isVisible: Bool
            switch self.visibility {
                case let .visible(fraction, _):
                    isVisible = fraction > 0.01
                case .none:
                    isVisible = false
            }
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                if let credibilityIconView = self.credibilityIconView, let credibilityIconComponent = self.credibilityIconComponent {
                    let _ = credibilityIconView.update(
                        transition: .immediate,
                        component: AnyComponent(credibilityIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: credibilityIconView.bounds.size
                    )
                }
                if let verifiedIconView = self.verifiedIconView, let verifiedIconComponent = self.verifiedIconComponent {
                    let _ = verifiedIconView.update(
                        transition: .immediate,
                        component: AnyComponent(verifiedIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: verifiedIconView.bounds.size
                    )
                }
                if let avatarIconView = self.avatarIconView, let avatarIconComponent = self.avatarIconComponent {
                    let _ = avatarIconView.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: avatarIconView.bounds.size
                    )
                }
                self.statusNode.visibilityRect = self.visibilityStatus == false ? CGRect.zero : CGRect.infinite
                
                self.item?.visibilityUpdated?(self.visibilityStatus)
            }
        }
    }
        
    required public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.alpha = 0.0
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNodeContainer = ASDisplayNode()
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = false
        
        self.titleNode = TextNode()
        self.statusNode = TextNodeWithEntities()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        
        self.avatarNodeContainer.addSubnode(self.avatarNode)
        self.offsetContainerNode.addSubnode(self.avatarNodeContainer)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.statusNode.textNode)
        
        self.addSubnode(self.maskNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4, layoutParams.5)
                let _ = apply()
            }
        })
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.containerNode, gesture, nil)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            if let rightLabelTextNode = strongSelf.rightLabelTextNode {
                transition.updateTransform(node: rightLabelTextNode, transform: CGAffineTransformMakeTranslation(isExtracted ? -24.0 : 0.0, 0.0))
            }
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.updateEnableGestures()
    }
    
    private func updateEnableGestures() {
        if let item = self.layoutParams?.0, !item.options.isEmpty {
            self.view.disablesInteractiveTransitionGestureRecognizer = false
        } else {
            self.view.disablesInteractiveTransitionGestureRecognizer = false
        }
    }
    
    public override func secondaryAction(at point: CGPoint) {
        guard let item = self.item, let contextAction = item.contextAction else {
            return
        }
        contextAction(self.containerNode, nil, point)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let (item, _, _, _, _, _) = self.layoutParams {
            let (first, last, firstWithHeader) = ContactsPeerItem.mergeType(item: item, previousItem: previousItem, nextItem: nextItem)
            self.layoutParams = (item, params, first, last, firstWithHeader, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, first, last, firstWithHeader, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        if let item = self.item, case .selectable = item.selection {
            return
        }
        
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.isHighlighted = highlighted
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }

    
    public func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        var reallyHighlighted = self.isHighlighted
        if let item = self.item, !item.enabled {
            reallyHighlighted = false
        }
        let highlightProgress: CGFloat = self.item?.itemHighlighting?.progress ?? 1.0
        if let item = self.item {
            switch item.peer {
            case let .peer(_, chatPeer):
                if let peer = chatPeer {
                    if ChatLocation.peer(id: peer.id) == item.itemHighlighting?.chatLocation {
                        reallyHighlighted = true
                    }
                }
            default:
                break
            }
        }
        
        if let item = self.item, let avatarBadgeBackground = self.avatarBadgeBackground {
            transition.updateTintColor(layer: avatarBadgeBackground.layer, color: item.presentationData.theme.list.itemHighlightedBackgroundColor.mixedWith(item.presentationData.theme.list.plainBackgroundColor, alpha: reallyHighlighted ? 0.0 : 1.0))
        }
        
        if reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: highlightProgress)
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 1.0 - highlightProgress, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    }
                })
            }
        }
    }
    
    public func asyncLayout() -> (_ item: ContactsPeerItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (Bool, Bool) -> Void)) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNodeWithEntities.asyncLayout(self.statusNode)
        let currentSelectionNode = self.selectionNode
        
        let makeBadgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        let makeRightLabelTextLayout = TextNode.asyncLayout(self.rightLabelTextNode)
        
        let makeActionButtonTitleLayuout = TextNode.asyncLayout(self.actionButtonTitleNode)
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let titleBoldFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            
            let statusFontSize: CGFloat
            if case .app = item.peerMode {
                statusFontSize = 15.0
            } else {
                statusFontSize = 13.0
            }
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * statusFontSize / 17.0))
            
            let badgeFont = Font.regular(14.0)
            let avatarDiameter = min(40.0, floor(item.presentationData.fontSize.itemListBaseFontSize * 40.0 / 17.0))
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            var leftInset: CGFloat = 65.0 + params.leftInset
            var rightInset: CGFloat = 10.0 + params.rightInset
            
            if case .thread = item.peer {
                leftInset -= 13.0
            }
            
            let updatedSelectionNode: CheckNode?
            var isSelected = false
            switch item.selection {
            case .none:
                updatedSelectionNode = nil
            case let .selectable(selected):
                switch item.selectionPosition {
                    case .left:
                        leftInset += 38.0
                    case .right:
                        rightInset += 38.0
                }
                isSelected = selected
                
                let selectionNode: CheckNode
                if let current = currentSelectionNode {
                    selectionNode = current
                    updatedSelectionNode = selectionNode
                } else {
                    selectionNode = CheckNode(theme: CheckNodeTheme(theme: item.presentationData.theme, style: .plain))
                    selectionNode.isUserInteractionEnabled = false
                    updatedSelectionNode = selectionNode
                }
            }
            
            var rightLabelTextLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let rightLabelText = item.rightLabelText {
                let rightLabelTextLayoutAndApplyValue = makeRightLabelTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: rightLabelText, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 20.0, height: 100.0)))
                rightLabelTextLayoutAndApply = rightLabelTextLayoutAndApplyValue
                rightInset -= 6.0 + rightLabelTextLayoutAndApplyValue.0.size.width
            }
            
            var searchAdIcon: UIImage?
            if item.isAd, let icon = PresentationResourcesChatList.searchAdIcon(item.presentationData.theme, strings: item.presentationData.strings) {
                searchAdIcon = icon
                rightInset += icon.size.width + 12.0
            }
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            
            var credibilityIcon: EmojiStatusComponent.Content?
            var credibilityParticleColor: UIColor?
            var verifiedIcon: EmojiStatusComponent.Content?
            switch item.peer {
            case let .peer(peer, _):
                if let peer = peer, (peer.id != item.context.account.peerId || item.peerMode == .memberList || item.aliasHandling == .standard) {
                    if peer.isScam {
                        credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                    } else if peer.isFake {
                        credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                    } else if let emojiStatus = peer.emojiStatus {
                        credibilityIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                        if let color = emojiStatus.color {
                            credibilityParticleColor = UIColor(rgb: UInt32(bitPattern: color))
                        }
                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                        credibilityIcon = .premium(color: item.presentationData.theme.list.itemAccentColor)
                    }
                    
                    if peer.isVerified {
                        credibilityIcon = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                    }
                    if let verificationIconFileId = peer.verificationIconFileId {
                        verifiedIcon = .animation(content: .customEmoji(fileId: verificationIconFileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0))
                    }
                }
            case .deviceContact:
                break
            case .thread:
                break
            }
            
            var arrowButtonImage: UIImage?
            if let _ = item.arrowAction {
                arrowButtonImage = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Search/Arrow"), color: item.presentationData.theme.list.disclosureArrowColor)
            }
            
            var actionButtons: [ActionButton]?
            struct ActionButton {
                let type: ContactsPeerItemActionIcon
                let image: UIImage?
                let action: ((ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void)?
                
                init(theme: PresentationTheme, icon: ContactsPeerItemActionIcon, action: ((ContactsPeerItemPeer, ASDisplayNode, ContextGesture?) -> Void)?) {
                    let image: UIImage?
                    switch icon {
                        case .none:
                            image = nil
                        case .add:
                            image = PresentationResourcesItemList.plusIconImage(theme)
                        case .voiceCall:
                            image = PresentationResourcesItemList.voiceCallIcon(theme)
                        case .videoCall:
                            image = PresentationResourcesItemList.videoCallIcon(theme)
                        case .more:
                            image = PresentationResourcesItemList.videoCallIcon(theme)
                    }
                    self.type = icon
                    self.image = image
                    self.action = action
                }
            }
            
            if item.actionIcon != .none {
                actionButtons = [ActionButton(theme: item.presentationData.theme, icon: item.actionIcon, action: nil)]
            } else if !item.additionalActions.isEmpty {
                actionButtons = item.additionalActions.map { ActionButton(theme: item.presentationData.theme, icon: $0.icon, action: $0.action) }
            }
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            var statusIcon: ContactsPeerItemStatus.Icon?
            var statusIsActive: Bool = false
            var multilineStatus: Bool = false
            var userPresence: EnginePeer.Presence?
            
            switch item.peer {
            case let .thread(_, title, _, _):
                titleAttributedString = NSAttributedString(string: title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            case let .peer(peer, chatPeer):
                if let peer = peer {
                    let textColor: UIColor
                    if case .secretChat = chatPeer {
                        textColor = item.presentationData.theme.chatList.secretTitleColor
                    } else {
                        textColor = item.presentationData.theme.list.itemPrimaryTextColor
                    }
                    if case let .user(user) = peer {
                        if peer.id == item.context.account.peerId, case let .generalSearch(isSavedMessages) = item.peerMode, case .treatSelfAsSaved = item.aliasHandling {
                            if isSavedMessages {
                                titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_MyNotes, font: titleBoldFont, textColor: textColor)
                            } else {
                                titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleBoldFont, textColor: textColor)
                            }
                        } else if peer.id.isReplies {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Replies, font: titleBoldFont, textColor: textColor)
                        } else if peer.id.isAnonymousSavedMessages {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_AuthorHidden, font: titleBoldFont, textColor: textColor)
                        } else if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                            let string = NSMutableAttributedString()
                            switch item.displayOrder {
                            case .firstLast:
                                string.append(NSAttributedString(string: firstName, font: item.sortOrder == .firstLast ? titleBoldFont : titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: lastName, font: item.sortOrder == .firstLast ? titleFont : titleBoldFont, textColor: textColor))
                            case .lastFirst:
                                string.append(NSAttributedString(string: lastName, font: item.sortOrder == .firstLast ? titleFont : titleBoldFont, textColor: textColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                                string.append(NSAttributedString(string: firstName, font: item.sortOrder == .firstLast ? titleBoldFont : titleFont, textColor: textColor))
                            }
                            titleAttributedString = string
                        } else if let firstName = user.firstName, !firstName.isEmpty {
                            titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: textColor)
                        } else if let lastName = user.lastName, !lastName.isEmpty {
                            titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: textColor)
                        } else {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleBoldFont, textColor: textColor)
                        }
                    } else if case let .legacyGroup(group) = peer {
                        titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                    } else if case let .channel(channel) = peer {
                        if case let .channel(mainChannel) = chatPeer, mainChannel.isMonoForum {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.Monoforum_NameFormat(channel.title).string, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                        } else {
                            titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                        }
                    }
                    
                    switch item.status {
                    case .none:
                        break
                    case let .presence(presence, dateTimeFormat):
                        if case let .peer(peer, _) = item.peer, let peer, case let .user(user) = peer, user.botInfo != nil {
                            if let subscriberCount = user.subscriberCount {
                                statusAttributedString = NSAttributedString(string: item.presentationData.strings.Conversation_StatusBotSubscribers(subscriberCount), font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                            } else {
                                statusAttributedString = NSAttributedString(string: item.presentationData.strings.Bot_GenericBotStatus, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                            }
                        } else {
                            userPresence = presence
                            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                            let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                            statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
                        }
                    case let .addressName(suffix):
                        var addressName = peer.addressName
                        if let currentAddressName = addressName, let searchQuery = item.searchQuery?.lowercased(), !peer.usernames.isEmpty && !currentAddressName.lowercased().contains(searchQuery) {
                            for username in peer.usernames {
                                if username.username.lowercased().contains(searchQuery) {
                                    addressName = username.username
                                    break
                                }
                            }
                        }
                        if let addressName {
                            let addressNameString = NSAttributedString(string: "@" + addressName, font: statusFont, textColor: item.presentationData.theme.list.itemAccentColor)
                            if !suffix.isEmpty {
                                let suffixString = NSAttributedString(string: suffix, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                                let finalString = NSMutableAttributedString()
                                finalString.append(addressNameString)
                                finalString.append(suffixString)
                                statusAttributedString = finalString
                            } else {
                                statusAttributedString = addressNameString
                            }
                        } else if !suffix.isEmpty {
                            statusAttributedString = NSAttributedString(string: suffix, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                        }
                    case let .custom(text, multiline, isActive, icon):
                        let statusAttributedStringValue = NSMutableAttributedString(string: text.string)
                        statusAttributedStringValue.addAttribute(.font, value: statusFont, range: NSRange(location: 0, length: statusAttributedStringValue.length))
                        statusAttributedStringValue.addAttribute(.foregroundColor, value: isActive ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor, range: NSRange(location: 0, length: statusAttributedStringValue.length))
                        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), using: { attributes, range, _ in
                            for (key, value) in attributes {
                                if key == ChatTextInputAttributes.bold {
                                    statusAttributedStringValue.addAttribute(.font, value: Font.semibold(14.0), range: range)
                                } else if key == ChatTextInputAttributes.italic {
                                    statusAttributedStringValue.addAttribute(.font, value: Font.italic(14.0), range: range)
                                } else if key == ChatTextInputAttributes.monospace {
                                    statusAttributedStringValue.addAttribute(.font, value: Font.monospace(14.0), range: range)
                                } else {
                                    statusAttributedStringValue.addAttribute(key, value: value, range: range)
                                }
                            }
                        })
                        
                        statusAttributedString = statusAttributedStringValue
                        statusIcon = icon
                        statusIsActive = isActive
                        multilineStatus = multiline
                    }
                }
            case let .deviceContact(_, contact):
                let textColor: UIColor = item.presentationData.theme.list.itemPrimaryTextColor
                
                if !contact.firstName.isEmpty, !contact.lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: contact.firstName, font: titleFont, textColor: textColor))
                    string.append(NSAttributedString(string: " ", font: titleFont, textColor: textColor))
                    string.append(NSAttributedString(string: contact.lastName, font: titleBoldFont, textColor: textColor))
                    titleAttributedString = string
                } else if !contact.firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: contact.firstName, font: titleBoldFont, textColor: textColor)
                } else if !contact.lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: contact.lastName, font: titleBoldFont, textColor: textColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: titleBoldFont, textColor: textColor)
                }
                
                switch item.status {
                case let .custom(text, multiline, isActive, icon):
                    let statusAttributedStringValue = NSMutableAttributedString(string: "")
                    statusAttributedStringValue.addAttribute(.font, value: statusFont, range: NSRange(location: 0, length: text.length))
                    statusAttributedStringValue.addAttribute(.foregroundColor, value: isActive ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor, range: NSRange(location: 0, length: text.length))
                    text.enumerateAttributes(in: NSRange(location: 0, length: text.length), using: { attributes, range, _ in
                        for (key, value) in attributes {
                            if key == ChatTextInputAttributes.bold {
                                statusAttributedStringValue.addAttribute(.font, value: Font.semibold(14.0), range: range)
                            } else if key == ChatTextInputAttributes.italic {
                                statusAttributedStringValue.addAttribute(.font, value: Font.italic(14.0), range: range)
                            } else if key == ChatTextInputAttributes.monospace {
                                statusAttributedStringValue.addAttribute(.font, value: Font.monospace(14.0), range: range)
                            } else {
                                statusAttributedStringValue.addAttribute(key, value: value, range: range)
                            }
                        }
                    })
                    statusAttributedString = statusAttributedStringValue
                    multilineStatus = multiline
                    statusIsActive = isActive
                    statusIcon = icon
                default:
                    break
                }
            }
            
            var badgeTextLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            var currentBadgeBackgroundImage: UIImage?
            if let badge = item.badge {
                let badgeTextColor: UIColor
                switch badge.type {
                    case .inactive:
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: 20.0)
                        badgeTextColor = item.presentationData.theme.chatList.unreadBadgeInactiveTextColor
                    case .active:
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: 20.0)
                        badgeTextColor = item.presentationData.theme.chatList.unreadBadgeActiveTextColor
                }
                let badgeAttributedString = NSAttributedString(string: badge.count > 0 ? "\(badge.count)" : " ", font: badgeFont, textColor: badgeTextColor)
                badgeTextLayoutAndApply = makeBadgeTextLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            var badgeSize: CGFloat = 0.0
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage, let (badgeTextLayout, _) = badgeTextLayoutAndApply {
                badgeSize += max(currentBadgeBackgroundImage.size.width, badgeTextLayout.size.width + 10.0) + 5.0
            }
            
            var additionalTitleInset: CGFloat = 0.0
            if let verifiedIcon {
                additionalTitleInset += 3.0
                switch verifiedIcon {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    additionalTitleInset += floor(stringRect.width) + 11.0
                default:
                    additionalTitleInset += 16.0
                }
            }
            if let credibilityIcon {
                additionalTitleInset += 3.0
                switch credibilityIcon {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    additionalTitleInset += floor(stringRect.width) + 11.0
                default:
                    additionalTitleInset += 16.0
                }
            }
            if let actionButtons = actionButtons {
                additionalTitleInset += 3.0
                for actionButton in actionButtons {
                    if let image = actionButton.image {
                        additionalTitleInset += image.size.width + 12.0
                    }
                }
            }
            
            additionalTitleInset += badgeSize
            
            if let arrowButtonImage = arrowButtonImage {
                additionalTitleInset += arrowButtonImage.size.width + 4.0
            }
            
            var actionButtonTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let buttonAction = item.buttonAction {
                actionButtonTitleLayoutAndApply = makeActionButtonTitleLayuout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: buttonAction.title, font: Font.semibold(15.0), textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                if let (actionButtonTitleLayout, _) = actionButtonTitleLayoutAndApply {
                    additionalTitleInset += actionButtonTitleLayout.size.width + 32.0
                }
            }
            
            if let rightLabelTextLayoutAndApply {
                additionalTitleInset += rightLabelTextLayoutAndApply.0.size.width + 36.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset - additionalTitleInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var maxStatusWidth: CGFloat = params.width - leftInset - rightInset - badgeSize
            if let _ = statusIcon {
                maxStatusWidth -= 10.0
            }
            
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: multilineStatus ? 3 : 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, maxStatusWidth), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var statusIconImage: UIImage?
            if let statusIcon = statusIcon {
                switch statusIcon {
                case .autoremove:
                    statusIconImage = PresentationResourcesChatList.statusAutoremoveIcon(item.presentationData.theme, isActive: statusIsActive)
                }
            }
            
            var verticalInset: CGFloat = statusAttributedString == nil ? 13.0 : 6.0
            if case .app = item.peerMode {
                verticalInset += 2.0
            }
            
            let statusHeightComponent: CGFloat
            if statusAttributedString == nil {
                statusHeightComponent = 0.0
            } else {
                statusHeightComponent = -1.0 + statusLayout.size.height
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + statusHeightComponent), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame: CGRect
            if statusAttributedString != nil {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            if item.enabled {
                var mappedOptions: [ItemListRevealOption] = []
                var index: Int32 = 0
                for option in item.options {
                    let color: UIColor
                    let textColor: UIColor
                    switch option.type {
                        case .neutral:
                            color = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.constructive.foregroundColor
                        case .warning:
                            color = item.presentationData.theme.list.itemDisclosureActions.warning.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.warning.foregroundColor
                        case .destructive:
                            color = item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor
                        case .accent:
                            color = item.presentationData.theme.list.itemDisclosureActions.accent.fillColor
                            textColor = item.presentationData.theme.list.itemDisclosureActions.accent.foregroundColor
                    }
                    mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                    index += 1
                }
                peerRevealOptions = mappedOptions
            } else {
                peerRevealOptions = []
            }
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    return (.complete(), { [weak strongSelf] animated, synchronousLoads in
                        if let strongSelf = strongSelf {
                            strongSelf.layoutParams = (item, params, first, last, firstWithHeader, neighbors)
                            
                            strongSelf.accessibilityLabel = titleAttributedString?.string
                            strongSelf.accessibilityValue = statusAttributedString?.string
                            
                            strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                            strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                            
                            let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: nodeLayout.contentSize.width - 16.0, height: nodeLayout.contentSize.height))
                            let extractedRect = CGRect(origin: CGPoint(), size: nodeLayout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                            strongSelf.extractedRect = extractedRect
                            strongSelf.nonExtractedRect = nonExtractedRect
                            
                            if strongSelf.contextSourceNode.isExtractedToContextPreview {
                                strongSelf.extractedBackgroundImageNode.frame = extractedRect
                            } else {
                                strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                            }
                            strongSelf.contextSourceNode.contentRect = extractedRect
                            
                            switch item.peer {
                                case let .peer(peer, chatPeer):
                                    if let peer = peer {
                                        var overrideImage: AvatarNodeImageOverride?
                                        if peer.id == item.context.account.peerId, case let .generalSearch(isSavedMessages) = item.peerMode, case .treatSelfAsSaved = item.aliasHandling {
                                            if isSavedMessages {
                                                overrideImage = .myNotesIcon
                                            } else {
                                                overrideImage = .savedMessagesIcon
                                            }
                                        } else if peer.id.isReplies, case .generalSearch = item.peerMode {
                                            overrideImage = .repliesIcon
                                        } else if peer.id.isAnonymousSavedMessages, case .generalSearch = item.peerMode {
                                            overrideImage = .anonymousSavedMessagesIcon(isColored: true)
                                        } else if peer.isDeleted {
                                            overrideImage = .deletedIcon
                                        }
                                        
                                        var displayDimensions = CGSize(width: 60.0, height: 60.0)
                                        let clipStyle: AvatarNodeClipStyle
                                        if case .app(true) = item.peerMode {
                                            clipStyle = .roundedRect
                                            displayDimensions = CGSize(width: displayDimensions.width, height: displayDimensions.width * 1.2)
                                        } else if case let .channel(channel) = peer {
                                            if case let .channel(chatPeer) = chatPeer, chatPeer.isMonoForum {
                                                clipStyle = .bubble
                                            } else {
                                                if channel.isForum {
                                                    clipStyle = .roundedRect
                                                } else {
                                                    clipStyle = .round
                                                }
                                            }
                                        } else {
                                            clipStyle = .round
                                        }
                                        
                                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: clipStyle, synchronousLoad: synchronousLoads, displayDimensions: displayDimensions)
                                    }
                                case let .deviceContact(_, contact):
                                    let letters: [String]
                                    if !contact.firstName.isEmpty && !contact.lastName.isEmpty {
                                        letters = [contact.firstName[..<contact.firstName.index(after: contact.firstName.startIndex)].uppercased(), contact.lastName[..<contact.lastName.index(after: contact.lastName.startIndex)].uppercased()]
                                    } else if !contact.firstName.isEmpty {
                                        letters = [contact.firstName[..<contact.firstName.index(after: contact.firstName.startIndex)].uppercased()]
                                    } else if !contact.lastName.isEmpty {
                                        letters = [contact.lastName[..<contact.lastName.index(after: contact.lastName.startIndex)].uppercased()]
                                    } else {
                                        letters = [" "]
                                    }
                                    strongSelf.avatarNode.setCustomLetters(letters)
                                case .thread:
                                    break
                            }
                            
                            strongSelf.avatarNode.setStoryStats(
                                storyStats: item.storyStats.flatMap { stats in
                                    return AvatarNode.StoryStats(
                                        totalCount: stats.total,
                                        unseenCount: stats.unseen,
                                        hasUnseenCloseFriendsItems: stats.hasUnseenCloseFriends
                                    )
                                },
                                presentationParams: AvatarNode.StoryPresentationParams(
                                    colors: AvatarNode.Colors(theme: item.presentationData.theme),
                                    lineWidth: 1.33,
                                    inactiveLineWidth: 1.33
                                ),
                                transition: animated ? ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)) : .immediate
                            )
                            
                            if strongSelf.avatarTapRecognizer == nil {
                                let avatarTapRecognizer = UITapGestureRecognizer(target: strongSelf, action: #selector(strongSelf.avatarStoryTapGesture(_:)))
                                strongSelf.avatarTapRecognizer = avatarTapRecognizer
                                strongSelf.avatarNode.view.addGestureRecognizer(avatarTapRecognizer)
                            }
                            strongSelf.avatarNode.isUserInteractionEnabled = item.storyStats != nil
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            let revealOffset: CGFloat = 0.0
                            
                            if let _ = updatedTheme {
                                switch item.style {
                                case .plain:
                                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                                    strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                                case .blocks:
                                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                                    strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                                }
                                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                            }
                            
                            let hasCorners = itemListHasRoundedBlockLayout(params)
                            var hasTopCorners = false
                            var hasBottomCorners = false
                            switch item.style {
                            case .plain:
                                strongSelf.topSeparatorNode.isHidden = true
                            case .blocks:
                                switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topSeparatorNode.isHidden = true
                                default:
                                    hasTopCorners = true
                                    strongSelf.topSeparatorNode.isHidden = hasCorners
                                }
                                switch neighbors.bottom {
                                case .sameSection(false):
                                    strongSelf.separatorNode.isHidden = false
                                default:
                                    hasBottomCorners = true
                                    strongSelf.separatorNode.isHidden = hasCorners
                                }
                            }
                            
                            var avatarSize: CGSize
                            if case .app(true) = item.peerMode {
                                avatarSize = CGSize(width: avatarDiameter, height: avatarDiameter * 1.2)
                            } else {
                                avatarSize = CGSize(width: avatarDiameter, height: avatarDiameter)
                            }
                            
                            let avatarFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset - 50.0, y: floor((nodeLayout.contentSize.height - avatarSize.height) / 2.0)), size: avatarSize)
                            
                            strongSelf.avatarNode.frame = CGRect(origin: CGPoint(), size: avatarFrame.size)
                            
                            if item.requiresPremiumForMessaging {
                                let avatarBadgeBackground: UIImageView
                                if let current = strongSelf.avatarBadgeBackground {
                                    avatarBadgeBackground = current
                                } else {
                                    avatarBadgeBackground = UIImageView()
                                    avatarBadgeBackground.image = PresentationResourcesChatList.avatarPremiumLockBadgeBackground(item.presentationData.theme)
                                    avatarBadgeBackground.tintColor = item.presentationData.theme.list.itemHighlightedBackgroundColor.mixedWith(item.presentationData.theme.list.plainBackgroundColor, alpha: 1.0 - strongSelf.highlightedBackgroundNode.alpha)
                                    strongSelf.avatarBadgeBackground = avatarBadgeBackground
                                    strongSelf.avatarNode.view.addSubview(avatarBadgeBackground)
                                }
                                
                                let avatarBadge: UIImageView
                                if let current = strongSelf.avatarBadge {
                                    avatarBadge = current
                                } else {
                                    avatarBadge = UIImageView()
                                    avatarBadge.image = PresentationResourcesChatList.avatarPremiumLockBadge(item.presentationData.theme)
                                    strongSelf.avatarBadge = avatarBadge
                                    strongSelf.avatarNode.view.addSubview(avatarBadge)
                                }
                                
                                let badgeFrame = CGRect(origin: CGPoint(x: avatarFrame.width - 16.0, y: avatarFrame.height - 16.0), size: CGSize(width: 16.0, height: 16.0))
                                let badgeBackgroundFrame = badgeFrame.insetBy(dx: -1.0 - UIScreenPixel, dy: -1.0 - UIScreenPixel)
                                
                                avatarBadgeBackground.frame = badgeBackgroundFrame
                                avatarBadge.frame = badgeFrame
                            } else {
                                if let avatarBadgeBackground = strongSelf.avatarBadgeBackground {
                                    strongSelf.avatarBadgeBackground = nil
                                    avatarBadgeBackground.removeFromSuperview()
                                }
                                if let avatarBadge = strongSelf.avatarBadge {
                                    strongSelf.avatarBadge = nil
                                    avatarBadge.removeFromSuperview()
                                }
                            }
                            
                            transition.updatePosition(node: strongSelf.avatarNodeContainer, position: avatarFrame.center)
                            transition.updateBounds(node: strongSelf.avatarNodeContainer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                            
                            let avatarScale: CGFloat = 1.0
                            
                            transition.updateTransformScale(node: strongSelf.avatarNodeContainer, scale: CGPoint(x: avatarScale, y: avatarScale))
                            
                            if case let .thread(_, title, icon, color) = item.peer {
                                let animationCache = item.context.animationCache
                                let animationRenderer = item.context.animationRenderer

                                let avatarIconView: ComponentHostView<Empty>
                                if let current = strongSelf.avatarIconView {
                                    avatarIconView = current
                                } else {
                                    avatarIconView = ComponentHostView<Empty>()
                                    strongSelf.avatarIconView = avatarIconView
                                    strongSelf.offsetContainerNode.view.addSubview(avatarIconView)
                                }

                                let avatarIconContent: EmojiStatusComponent.Content
                                if let fileId = icon, fileId != 0 {
                                    avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0))
                                } else {
                                    avatarIconContent = .topic(title: String(title.prefix(1)), color: color, size: CGSize(width: 32.0, height: 32.0))
                                }

                                let avatarIconComponent = EmojiStatusComponent(
                                    context: item.context,
                                    animationCache: animationCache,
                                    animationRenderer: animationRenderer,
                                    content: avatarIconContent,
                                    isVisibleForAnimations: strongSelf.visibilityStatus,
                                    action: nil
                                )
                                strongSelf.avatarIconComponent = avatarIconComponent

                                let iconSize = avatarIconView.update(
                                    transition: .immediate,
                                    component: AnyComponent(avatarIconComponent),
                                    environment: {},
                                    containerSize: CGSize(width: 32.0, height: 32.0)
                                )
                                transition.updateFrame(view: avatarIconView, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 43.0, y: floor((nodeLayout.contentSize.height - iconSize.height) / 2.0)), size: iconSize))

                                strongSelf.avatarNodeContainer.isHidden = true
                            } else if let avatarIconView = strongSelf.avatarIconView {
                                strongSelf.avatarIconView = nil
                                avatarIconView.removeFromSuperview()

                                strongSelf.avatarNodeContainer.isHidden = false
                            }
                            
                            let _ = titleApply()
                            
                            var titleLeftOffset: CGFloat = 0.0
                            var nextIconX: CGFloat = titleFrame.maxX
                            if let verifiedIcon {
                                let animationCache = item.context.animationCache
                                let animationRenderer = item.context.animationRenderer
                                
                                let verifiedIconView: ComponentHostView<Empty>
                                if let current = strongSelf.verifiedIconView {
                                    verifiedIconView = current
                                } else {
                                    verifiedIconView = ComponentHostView<Empty>()
                                    strongSelf.offsetContainerNode.view.addSubview(verifiedIconView)
                                    strongSelf.verifiedIconView = verifiedIconView
                                }
                                
                                let verifiedIconComponent = EmojiStatusComponent(
                                    context: item.context,
                                    animationCache: animationCache,
                                    animationRenderer: animationRenderer,
                                    content: verifiedIcon,
                                    isVisibleForAnimations: strongSelf.visibilityStatus,
                                    action: nil,
                                    emojiFileUpdated: nil
                                )
                                strongSelf.verifiedIconComponent = verifiedIconComponent
                                                                
                                let containerSize = CGSize(width: 16.0, height: 16.0)
                                
                                let iconSize = verifiedIconView.update(
                                    transition: .immediate,
                                    component: AnyComponent(verifiedIconComponent),
                                    environment: {},
                                    containerSize: containerSize
                                )
                                
                                transition.updateFrame(view: verifiedIconView, frame: CGRect(origin: CGPoint(x: titleFrame.minX, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                                
                                titleLeftOffset += iconSize.width + 4.0
                                nextIconX += iconSize.width + 4.0
                            } else if let verifiedIconView = strongSelf.verifiedIconView {
                                strongSelf.verifiedIconView = nil
                                verifiedIconView.removeFromSuperview()
                            }
                            
                            let titleFrame = titleFrame.offsetBy(dx: revealOffset + titleLeftOffset, dy: 0.0)
                            transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                            
                            strongSelf.titleNode.alpha = item.enabled ? 1.0 : 0.4
                            strongSelf.statusNode.textNode.alpha = item.enabled ? 1.0 : 0.4
                            
                            strongSelf.statusNode.visibilityRect = strongSelf.visibilityStatus == false ? CGRect.zero : CGRect.infinite
                            let _ = statusApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.context.animationCache,
                                renderer: item.context.animationRenderer,
                                placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor,
                                attemptSynchronous: false
                            ))
                            var statusFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: strongSelf.titleNode.frame.maxY - 1.0), size: statusLayout.size)
                            if let statusIconImage {
                                statusFrame.origin.x += statusIconImage.size.width + 1.0
                            }
                            let previousStatusFrame = strongSelf.statusNode.textNode.frame
                            
                            strongSelf.statusNode.textNode.frame = statusFrame
                            transition.animatePositionAdditive(node: strongSelf.statusNode.textNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
                            
                            if let statusIconImage {
                                let statusIconNode: ASImageNode
                                if let current = strongSelf.statusIconNode {
                                    statusIconNode = current
                                } else {
                                    statusIconNode = ASImageNode()
                                    strongSelf.statusNode.textNode.addSubnode(statusIconNode)
                                }
                                statusIconNode.image = statusIconImage
                                statusIconNode.frame = CGRect(origin: CGPoint(x: -statusIconImage.size.width - 1.0, y: floor((statusFrame.height - statusIconImage.size.height) / 2.0) + 1.0), size: statusIconImage.size)
                            } else {
                                if let statusIconNode = strongSelf.statusIconNode {
                                    strongSelf.statusIconNode = nil
                                    statusIconNode.removeFromSupernode()
                                }
                            }
                            
                            if let credibilityIcon {
                                let animationCache = item.context.animationCache
                                let animationRenderer = item.context.animationRenderer
                                
                                let credibilityIconView: ComponentHostView<Empty>
                                if let current = strongSelf.credibilityIconView {
                                    credibilityIconView = current
                                } else {
                                    credibilityIconView = ComponentHostView<Empty>()
                                    strongSelf.offsetContainerNode.view.addSubview(credibilityIconView)
                                    strongSelf.credibilityIconView = credibilityIconView
                                }
                                
                                let credibilityIconComponent = EmojiStatusComponent(
                                    context: item.context,
                                    animationCache: animationCache,
                                    animationRenderer: animationRenderer,
                                    content: credibilityIcon,
                                    particleColor: credibilityParticleColor,
                                    isVisibleForAnimations: strongSelf.visibilityStatus,
                                    action: nil,
                                    emojiFileUpdated: nil
                                )
                                strongSelf.credibilityIconComponent = credibilityIconComponent
                                
                                let iconSize = credibilityIconView.update(
                                    transition: .immediate,
                                    component: AnyComponent(credibilityIconComponent),
                                    environment: {},
                                    containerSize: CGSize(width: 16.0, height: 16.0)
                                )
                                
                                nextIconX += 4.0
                                transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: nextIconX, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                                nextIconX += iconSize.width
                            } else if let credibilityIconView = strongSelf.credibilityIconView {
                                strongSelf.credibilityIconView = nil
                                credibilityIconView.removeFromSuperview()
                            }
                              
                            var additionalRightInset: CGFloat = 0.0
                            if let (titleLayout, titleApply) = actionButtonTitleLayoutAndApply {
                                let actionButtonTitleNode = titleApply()
                                let actionButtonBackgroundNode: ASImageNode
                                let actionButtonNode: HighlightTrackingButtonNode
                                if let currentBackgroundNode = strongSelf.actionButtonBackgroundNode, let currentButtonNode = strongSelf.actionButtonNode {
                                    actionButtonBackgroundNode = currentBackgroundNode
                                    actionButtonNode = currentButtonNode
                                } else {
                                    actionButtonBackgroundNode = ASImageNode()
                                    actionButtonBackgroundNode.displaysAsynchronously = false
                                    strongSelf.offsetContainerNode.addSubnode(actionButtonBackgroundNode)
                                    strongSelf.actionButtonBackgroundNode = actionButtonBackgroundNode
                                    
                                    actionButtonNode = HighlightTrackingButtonNode()
                                    actionButtonNode.highligthedChanged = { [weak self] highlighted in
                                        if let strongSelf = self {
                                            if highlighted {
                                                strongSelf.actionButtonTitleNode?.layer.removeAnimation(forKey: "opacity")
                                                strongSelf.actionButtonTitleNode?.alpha = 0.4
                                                strongSelf.actionButtonBackgroundNode?.layer.removeAnimation(forKey: "opacity")
                                                strongSelf.actionButtonBackgroundNode?.alpha = 0.4
                                            } else {
                                                strongSelf.actionButtonTitleNode?.alpha = 1.0
                                                strongSelf.actionButtonTitleNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                                strongSelf.actionButtonBackgroundNode?.alpha = 1.0
                                                strongSelf.actionButtonBackgroundNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                                            }
                                        }
                                    }
                                    actionButtonNode.addTarget(strongSelf, action: #selector(strongSelf.actionButtonPressed(_:)), forControlEvents: .touchUpInside)
                                    
                                    strongSelf.offsetContainerNode.addSubnode(actionButtonNode)
                                    strongSelf.actionButtonNode = actionButtonNode
                                }
                                if strongSelf.actionButtonTitleNode == nil {
                                    strongSelf.actionButtonTitleNode = actionButtonTitleNode
                                    strongSelf.offsetContainerNode.insertSubnode(actionButtonTitleNode, aboveSubnode: actionButtonBackgroundNode)
                                }
                                if updatedTheme != nil || actionButtonBackgroundNode.image == nil {
                                    actionButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.itemAccentColor)
                                }
                                
                                let actionButtonSize = CGSize(width: titleLayout.size.width + 13.0 * 2.0, height: 28.0)
                                let actionButtonFrame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 12.0 - actionButtonSize.width, y: floorToScreenPixels((nodeLayout.contentSize.height - actionButtonSize.height) / 2.0)), size: actionButtonSize)
                                actionButtonBackgroundNode.frame = actionButtonFrame
                                actionButtonNode.frame = actionButtonFrame
                                
                                let actionTitleFrame = CGRect(origin: CGPoint(x: actionButtonFrame.minX + 13.0, y: actionButtonFrame.minY + floorToScreenPixels((actionButtonFrame.height - titleLayout.size.height) / 2.0) + 1.0), size: titleLayout.size)
                                actionButtonTitleNode.frame = actionTitleFrame
                                
                                additionalRightInset += actionButtonSize.width + 16.0
                            } else {
                                if let actionButtonTitleNode = strongSelf.actionButtonTitleNode {
                                    strongSelf.actionButtonTitleNode = nil
                                    actionButtonTitleNode.removeFromSupernode()
                                }
                                if let actionButtonBackgroundNode = strongSelf.actionButtonBackgroundNode {
                                    strongSelf.actionButtonBackgroundNode = nil
                                    actionButtonBackgroundNode.removeFromSupernode()
                                }
                                if let actionButtonNode = strongSelf.actionButtonNode {
                                    strongSelf.actionButtonNode = nil
                                    actionButtonNode.removeFromSupernode()
                                }
                            }
                            
                            if let actionButtons, actionButtons.count == 1, let actionButton = actionButtons.first, case .more = actionButton.type {
                                let moreButtonNode: MoreButtonNode
                                if let current = strongSelf.moreButtonNode {
                                    moreButtonNode = current
                                } else {
                                    moreButtonNode = MoreButtonNode(theme: item.presentationData.theme)
                                    moreButtonNode.iconNode.enqueueState(.more, animated: false)
                                    moreButtonNode.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
                                    strongSelf.offsetContainerNode.addSubnode(moreButtonNode)
                                    strongSelf.moreButtonNode = moreButtonNode
                                }
                                moreButtonNode.action = { sourceNode, gesture in
                                    actionButton.action?(item.peer, sourceNode, gesture)
                                }
                                let moreButtonSize = moreButtonNode.measure(CGSize(width: 100.0, height: nodeLayout.contentSize.height))
                                moreButtonNode.frame = CGRect(origin: CGPoint(x: revealOffset + params.width - params.rightInset - 21.0 - moreButtonSize.width, y: floor((nodeLayout.contentSize.height - moreButtonSize.height) / 2.0)), size: moreButtonSize)
                            } else if let actionButtons = actionButtons {
                                if strongSelf.actionButtonNodes == nil {
                                    var actionButtonNodes: [HighlightableButtonNode] = []
                                    for action in actionButtons {
                                        let actionButtonNode = HighlightableButtonNode()
                                        actionButtonNode.isUserInteractionEnabled = action.action != nil
                                        actionButtonNode.addTarget(strongSelf, action: #selector(strongSelf.actionButtonPressed(_:)), forControlEvents: .touchUpInside)
                                        strongSelf.offsetContainerNode.addSubnode(actionButtonNode)
                                        
                                        actionButtonNodes.append(actionButtonNode)
                                    }
                                    strongSelf.actionButtonNodes = actionButtonNodes
                                }
                                if let actionButtonNodes = strongSelf.actionButtonNodes {
                                    var offset: CGFloat = 0.0
                                    if actionButtons.count > 1 {
                                        offset += 12.0
                                    }
                                    for (actionButtonNode, actionButton) in zip(actionButtonNodes, actionButtons).reversed() {
                                        guard let actionButtonImage = actionButton.image else {
                                            continue
                                        }
                                        actionButtonNode.setImage(actionButton.image, for: .normal)
                                        transition.updateFrame(node: actionButtonNode, frame: CGRect(origin: CGPoint(x: revealOffset + params.width - params.rightInset - 12.0 - actionButtonImage.size.width - offset, y: floor((nodeLayout.contentSize.height - actionButtonImage.size.height) / 2.0)), size: actionButtonImage.size))
                                        
                                        actionButtonNode.isEnabled = item.enabled
                                        actionButtonNode.alpha = item.enabled ? 1.0 : 0.4
                                        
                                        offset += actionButtonImage.size.width + 12.0
                                    }
                                }
                            } else if let actionButtonNodes = strongSelf.actionButtonNodes {
                                strongSelf.actionButtonNodes = nil
                                actionButtonNodes.forEach { $0.removeFromSupernode() }
                            }
                            
                            if let arrowButtonImage = arrowButtonImage {
                                if strongSelf.arrowButtonNode == nil {
                                    let arrowButtonNode = HighlightableButtonNode()
                                    arrowButtonNode.addTarget(self, action: #selector(strongSelf.arrowButtonPressed), forControlEvents: .touchUpInside)
                                    strongSelf.arrowButtonNode = arrowButtonNode
                                    strongSelf.offsetContainerNode.addSubnode(arrowButtonNode)
                                }
                                if let arrowButtonNode = strongSelf.arrowButtonNode {
                                    arrowButtonNode.setImage(arrowButtonImage, for: .normal)
                                    
                                    transition.updateFrame(node: arrowButtonNode, frame: CGRect(origin: CGPoint(x: params.width - params.rightInset - 12.0 - arrowButtonImage.size.width, y: floor((nodeLayout.contentSize.height - arrowButtonImage.size.height) / 2.0)), size: arrowButtonImage.size))
                                }
                            } else if let arrowButtonNode = strongSelf.arrowButtonNode {
                                strongSelf.arrowButtonNode = nil
                                arrowButtonNode.removeFromSupernode()
                            }
                            
                            let badgeBackgroundWidth: CGFloat
                            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage, let (badgeTextLayout, badgeTextApply) = badgeTextLayoutAndApply {
                                let badgeBackgroundNode: ASImageNode
                                let badgeTransition: ContainedViewLayoutTransition
                                if let current = strongSelf.badgeBackgroundNode {
                                    badgeBackgroundNode = current
                                    badgeTransition = transition
                                } else {
                                    badgeBackgroundNode = ASImageNode()
                                    badgeBackgroundNode.isLayerBacked = true
                                    badgeBackgroundNode.displaysAsynchronously = false
                                    badgeBackgroundNode.displayWithoutProcessing = true
                                    strongSelf.offsetContainerNode.addSubnode(badgeBackgroundNode)
                                    strongSelf.badgeBackgroundNode = badgeBackgroundNode
                                    badgeTransition = .immediate
                                }
                                
                                badgeBackgroundNode.image = currentBadgeBackgroundImage
                                
                                badgeBackgroundWidth = max(badgeTextLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                                var badgeBackgroundFrame = CGRect(x: revealOffset + params.width - params.rightInset - badgeBackgroundWidth - additionalRightInset - 6.0, y: floor((nodeLayout.contentSize.height - currentBadgeBackgroundImage.size.height) / 2.0), width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                                
                                if let arrowButtonImage = arrowButtonImage {
                                    badgeBackgroundFrame.origin.x -= arrowButtonImage.size.width + 6.0
                                }
                                
                                let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeTextLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 2.0), size: badgeTextLayout.size)
                                
                                let badgeTextNode = badgeTextApply()
                                if badgeTextNode !== strongSelf.badgeTextNode {
                                    strongSelf.badgeTextNode?.removeFromSupernode()
                                    strongSelf.offsetContainerNode.addSubnode(badgeTextNode)
                                    strongSelf.badgeTextNode = badgeTextNode
                                }
                                
                                badgeTransition.updateFrame(node: badgeBackgroundNode, frame: badgeBackgroundFrame)
                                badgeTransition.updateFrame(node: badgeTextNode, frame: badgeTextFrame)
                            } else {
                                badgeBackgroundWidth = 0.0
                                if let badgeBackgroundNode = strongSelf.badgeBackgroundNode {
                                    badgeBackgroundNode.removeFromSupernode()
                                    strongSelf.badgeBackgroundNode = nil
                                }
                                if let badgeTextNode = strongSelf.badgeTextNode {
                                    badgeTextNode.removeFromSupernode()
                                    strongSelf.badgeTextNode = badgeTextNode
                                }
                            }
                            
                            if let (rightLabelTextLayout, rightLabelTextApply) = rightLabelTextLayoutAndApply {
                                let rightLabelTextNode = rightLabelTextApply()
                                var rightLabelTextTransition = transition
                                if rightLabelTextNode !== strongSelf.rightLabelTextNode {
                                    strongSelf.rightLabelTextNode?.removeFromSupernode()
                                    strongSelf.rightLabelTextNode = rightLabelTextNode
                                    strongSelf.offsetContainerNode.addSubnode(rightLabelTextNode)
                                    rightLabelTextTransition = .immediate
                                }
                                
                                var rightLabelTextFrame = CGRect(x: revealOffset + params.width - params.rightInset - 8.0 - rightLabelTextLayout.size.width, y: floor((nodeLayout.contentSize.height - rightLabelTextLayout.size.height) / 2.0), width: rightLabelTextLayout.size.width, height: rightLabelTextLayout.size.height)
                                if let arrowButtonImage = arrowButtonImage {
                                    rightLabelTextFrame.origin.x -= arrowButtonImage.size.width + 6.0
                                }
                                
                                rightLabelTextNode.bounds = CGRect(origin: CGPoint(), size: rightLabelTextFrame.size)
                                rightLabelTextTransition.updatePosition(node: rightLabelTextNode, position: rightLabelTextFrame.center)
                            } else if let rightLabelTextNode = strongSelf.rightLabelTextNode {
                                strongSelf.rightLabelTextNode = nil
                                rightLabelTextNode.removeFromSupernode()
                            }
                            
                            if let updatedSelectionNode = updatedSelectionNode {
                                let hadSelectionNode = strongSelf.selectionNode != nil
                                if strongSelf.selectionNode !== updatedSelectionNode {
                                    strongSelf.selectionNode?.removeFromSupernode()
                                    strongSelf.selectionNode = updatedSelectionNode
                                    strongSelf.addSubnode(updatedSelectionNode)
                                }
                                updatedSelectionNode.setSelected(isSelected, animated: true)
                                
                                switch item.selectionPosition {
                                    case .left:
                                        updatedSelectionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 17.0, y: floor((nodeLayout.contentSize.height - 22.0) / 2.0)), size: CGSize(width: 22.0, height: 22.0))
                                    case .right:
                                        updatedSelectionNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - 22.0 - 17.0, y: floor((nodeLayout.contentSize.height - 22.0) / 2.0)), size: CGSize(width: 22.0, height: 22.0))
                                }
                                
                                if !hadSelectionNode {
                                    switch item.selectionPosition {
                                        case .left:
                                            transition.animateFrame(node: updatedSelectionNode, from: updatedSelectionNode.frame.offsetBy(dx: -38.0, dy: 0.0))
                                        case .right:
                                            transition.animateFrame(node: updatedSelectionNode, from: updatedSelectionNode.frame.offsetBy(dx: 38.0, dy: 0.0))
                                    }
                                }
                            } else if let selectionNode = strongSelf.selectionNode {
                                selectionNode.removeFromSupernode()
                                strongSelf.selectionNode = nil
                            }
                            
                            let separatorHeight = UIScreenPixel
                            
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                            
                            let topHighlightInset: CGFloat = (first || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                            strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(nodeLayout.insets.top, separatorHeight)), size: CGSize(width: nodeLayout.contentSize.width, height: separatorHeight))
                            strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - leftInset), height: separatorHeight))
                            if !item.alwaysShowLastSeparator {
                                strongSelf.separatorNode.isHidden = last
                            }
                            
                            if let userPresence = userPresence {
                                strongSelf.peerPresenceManager?.reset(presence: userPresence)
                            }
                            
                            strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                            
                            if item.editing.editable {
                                strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                                strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                            } else {
                                strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                                strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                            }
                            
                            if item.isAd {
                                let adButton: HighlightableButtonNode
                                if let current = strongSelf.adButton {
                                    adButton = current
                                } else {
                                    adButton = HighlightableButtonNode()
                                    strongSelf.addSubnode(adButton)
                                    strongSelf.adButton = adButton
                                    
                                    adButton.addTarget(strongSelf, action: #selector(strongSelf.adButtonPressed), forControlEvents: .touchUpInside)
                                }
                                if updatedTheme != nil || adButton.image(for: .normal) == nil {
                                    adButton.setImage(searchAdIcon, for: .normal)
                                }
                                if let icon = adButton.image(for: .normal) {
                                    adButton.frame = CGRect(origin: CGPoint(x: params.width - 20.0 - icon.size.width - 13.0, y: 11.0), size: icon.size).insetBy(dx: -11.0, dy: -11.0)
                                }
                            } else if let adButton = strongSelf.adButton {
                                strongSelf.adButton = nil
                                adButton.removeFromSupernode()
                            }
                            
                            strongSelf.updateEnableGestures()
                        }
                    })
                } else {
                    return (nil, { _, _ in
                    })
                }
            })
        }
    }
    
    @objc private func adButtonPressed() {
        guard let item = self.item, let button = self.adButton else {
            return
        }
        item.adButtonAction?(button)
    }
    
    @objc private func actionButtonPressed(_ sender: HighlightableButtonNode) {
        guard let item = self.item else {
            return
        }
        if let action = item.buttonAction {
            action.action?(item.peer, sender, nil)
            return
        }
        guard let actionButtonNodes = self.actionButtonNodes, let index = actionButtonNodes.firstIndex(of: sender), index < item.additionalActions.count else {
            return
        }
        item.additionalActions[index].action?(item.peer, sender, nil)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        var offsetContainerBounds = self.offsetContainerNode.bounds
        offsetContainerBounds.origin.x = -offset
        transition.updateBounds(node: self.offsetContainerNode, bounds: offsetContainerBounds)
    }
    
    override public func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            switch item.peer {
                case let .peer(peer, chatPeer):
                    if let peer = chatPeer ?? peer {
                        item.setPeerIdWithRevealedOptions?(peer.id, nil)
                    }
                case .deviceContact:
                    break
                case .thread:
                    break
            }
        }
    }
    
    override public func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            switch item.peer {
                case let .peer(peer, chatPeer):
                    if let peer = chatPeer ?? peer {
                        item.setPeerIdWithRevealedOptions?(nil, peer.id)
                    }
                case .deviceContact:
                    break
                case .thread:
                    break
            }
        }
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            if item.editing.editable {
                switch item.peer {
                    case let .peer(peer, chatPeer):
                        if let peer = chatPeer ?? peer {
                            item.deletePeer?(peer.id)
                        }
                    case .deviceContact:
                        break
                    case .thread:
                        break
                }
            } else {
                item.options[Int(option.key)].action()
            }
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
    
    override public func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.avatarNode.view.hitTest(self.view.convert(point, to: self.avatarNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let (item, _, _, _, _, _) = self.layoutParams {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    @objc func arrowButtonPressed() {
        if let (item, _, _, _, _, _) = self.layoutParams {
            item.arrowAction?()
        }
    }
    
    @objc private func avatarStoryTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (item, _, _, _, _, _) = self.layoutParams {
                item.openStories?(item.peer, self)
            }
        }
    }
}
