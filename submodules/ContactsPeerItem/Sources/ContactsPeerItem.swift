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

public final class ContactItemHighlighting {
    public var chatLocation: ChatLocation?
    public var progress: CGFloat = 1.0
    
    public init(chatLocation: ChatLocation? = nil) {
        self.chatLocation = chatLocation
    }
}

public enum ContactsPeerItemStatus {
    case none
    case presence(EnginePeer.Presence, PresentationDateTimeFormat)
    case addressName(String)
    case custom(string: String, multiline: Bool)
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

public enum ContactsPeerItemPeerMode {
    case generalSearch
    case peer
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
}

public struct ContactsPeerItemAction {
    public let icon: ContactsPeerItemActionIcon
    public let action: ((ContactsPeerItemPeer) -> Void)?
    
    public init(icon: ContactsPeerItemActionIcon, action: @escaping (ContactsPeerItemPeer) -> Void) {
        self.icon = icon
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
    public let peer: ContactsPeerItemPeer
    let status: ContactsPeerItemStatus
    let badge: ContactsPeerItemBadge?
    let enabled: Bool
    let selection: ContactsPeerItemSelection
    let selectionPosition: ContactsPeerItemSelectionPosition
    let editing: ContactsPeerItemEditing
    let options: [ItemListPeerItemRevealOption]
    let additionalActions: [ContactsPeerItemAction]
    let actionIcon: ContactsPeerItemActionIcon
    let action: (ContactsPeerItemPeer) -> Void
    let disabledAction: ((ContactsPeerItemPeer) -> Void)?
    let setPeerIdWithRevealedOptions: ((EnginePeer.Id?, EnginePeer.Id?) -> Void)?
    let deletePeer: ((EnginePeer.Id) -> Void)?
    let itemHighlighting: ContactItemHighlighting?
    let contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let arrowAction: (() -> Void)?
    let animationCache: AnimationCache?
    let animationRenderer: MultiAnimationRenderer?
    
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
        peer: ContactsPeerItemPeer,
        status: ContactsPeerItemStatus,
        badge: ContactsPeerItemBadge? = nil,
        enabled: Bool,
        selection: ContactsPeerItemSelection,
        selectionPosition: ContactsPeerItemSelectionPosition = .right,
        editing: ContactsPeerItemEditing,
        options: [ItemListPeerItemRevealOption] = [],
        additionalActions: [ContactsPeerItemAction] = [],
        actionIcon: ContactsPeerItemActionIcon = .none,
        index: SortIndex?,
        header: ListViewItemHeader?,
        action: @escaping (ContactsPeerItemPeer) -> Void,
        disabledAction: ((ContactsPeerItemPeer) -> Void)? = nil,
        setPeerIdWithRevealedOptions: ((EnginePeer.Id?, EnginePeer.Id?) -> Void)? = nil,
        deletePeer: ((EnginePeer.Id) -> Void)? = nil,
        itemHighlighting: ContactItemHighlighting? = nil,
        contextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil, arrowAction: (() -> Void)? = nil,
        animationCache: AnimationCache? = nil,
        animationRenderer: MultiAnimationRenderer? = nil
    ) {
        self.presentationData = presentationData
        self.style = style
        self.sectionId = sectionId
        self.sortOrder = sortOrder
        self.displayOrder = displayOrder
        self.context = context
        self.peerMode = peerMode
        self.peer = peer
        self.status = status
        self.badge = badge
        self.enabled = enabled
        self.selection = selection
        self.selectionPosition = selectionPosition
        self.editing = editing
        self.options = options
        self.additionalActions = additionalActions
        self.actionIcon = actionIcon
        self.action = action
        self.disabledAction = disabledAction
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.deletePeer = deletePeer
        self.header = header
        self.itemHighlighting = itemHighlighting
        self.selectable = enabled || disabledAction != nil
        self.contextAction = contextAction
        self.arrowAction = arrowAction
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
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
            self.action(self.peer)
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
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let extractedBackgroundImageNode: ASImageNode

    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let offsetContainerNode: ASDisplayNode
    
    private let avatarNode: AvatarNode
    private var avatarIconView: ComponentHostView<Empty>?
    private var avatarIconComponent: EmojiStatusComponent?
    private let titleNode: TextNode
    private var credibilityIconView: ComponentHostView<Empty>?
    private var credibilityIconComponent: EmojiStatusComponent?
    private let statusNode: TextNode
    private var badgeBackgroundNode: ASImageNode?
    private var badgeTextNode: TextNode?
    private var selectionNode: CheckNode?
    private var actionButtonNodes: [HighlightableButtonNode]?
    private var arrowButtonNode: HighlightableButtonNode?
    
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
                if let avatarIconView = self.avatarIconView, let avatarIconComponent = self.avatarIconComponent {
                    let _ = avatarIconView.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: avatarIconView.bounds.size
                    )
                }
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
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        
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
        
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.statusNode)
        
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
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
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
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let currentSelectionNode = self.selectionNode
        
        let makeBadgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        
        let currentItem = self.layoutParams?.0
        
        return { [weak self] item, params, first, last, firstWithHeader, neighbors in
            var updatedTheme: PresentationTheme?
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let titleBoldFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let statusFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
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
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            
            var credibilityIcon: EmojiStatusComponent.Content?
            switch item.peer {
            case let .peer(peer, _):
                if let peer = peer, peer.id != item.context.account.peerId {
                    if peer.isScam {
                        credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                    } else if peer.isFake {
                        credibilityIcon = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                    } else if case let .user(user) = peer, let emojiStatus = user.emojiStatus {
                        credibilityIcon = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                    } else if peer.isVerified {
                        credibilityIcon = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                        credibilityIcon = .premium(color: item.presentationData.theme.list.itemAccentColor)
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
                let image: UIImage?
                let action: ((ContactsPeerItemPeer) -> Void)?
                
                init(theme: PresentationTheme, icon: ContactsPeerItemActionIcon, action: ((ContactsPeerItemPeer) -> Void)?) {
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
                    }
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
                        if peer.id == item.context.account.peerId, case .generalSearch = item.peerMode {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleBoldFont, textColor: textColor)
                        } else if peer.id.isReplies {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Replies, font: titleBoldFont, textColor: textColor)
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
                        titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
                    }
                    
                    switch item.status {
                    case .none:
                        break
                    case let .presence(presence, dateTimeFormat):
                        userPresence = presence
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        let (string, activity) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                        statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: activity ? item.presentationData.theme.list.itemAccentColor : item.presentationData.theme.list.itemSecondaryTextColor)
                    case let .addressName(suffix):
                        if let addressName = peer.addressName {
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
                    case let .custom(text, multiline):
                        statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
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
                case let .custom(text, multiline):
                    statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                    multilineStatus = multiline
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
            if let credibilityIcon = credibilityIcon {
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
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset - additionalTitleInset), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: multilineStatus ? 3 : 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, params.width - leftInset - rightInset - badgeSize), height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleVerticalInset: CGFloat = statusAttributedString == nil ? 13.0 : 6.0
            let verticalInset: CGFloat = statusAttributedString == nil ? 13.0 : 6.0
            
            let statusHeightComponent: CGFloat
            if statusAttributedString == nil {
                statusHeightComponent = 0.0
            } else {
                statusHeightComponent = -1.0 + statusLayout.size.height
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.size.height + statusHeightComponent), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            let titleFrame: CGRect
            if statusAttributedString != nil {
                titleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleVerticalInset), size: titleLayout.size)
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
                                case let .peer(peer, _):
                                    if let peer = peer {
                                        var overrideImage: AvatarNodeImageOverride?
                                        if peer.id == item.context.account.peerId, case .generalSearch = item.peerMode {
                                            overrideImage = .savedMessagesIcon
                                        } else if peer.id.isReplies, case .generalSearch = item.peerMode {
                                            overrideImage = .repliesIcon
                                        } else if peer.isDeleted {
                                            overrideImage = .deletedIcon
                                        }
                                        let clipStyle: AvatarNodeClipStyle
                                        if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                                            clipStyle = .roundedRect
                                        } else {
                                            clipStyle = .round
                                        }
                                        
                                        strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: clipStyle, synchronousLoad: synchronousLoads)
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
                            
                            let transition: ContainedViewLayoutTransition
                            if animated {
                                transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                            } else {
                                transition = .immediate
                            }
                            
                            let revealOffset = strongSelf.revealOffset
                            
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
                            
                            transition.updateFrame(node: strongSelf.avatarNode, frame: CGRect(origin: CGPoint(x: revealOffset + leftInset - 50.0, y: floor((nodeLayout.contentSize.height - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter)))
                            
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
                                    avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .forever)
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

                                strongSelf.avatarNode.isHidden = true
                            } else if let avatarIconView = strongSelf.avatarIconView {
                                strongSelf.avatarIconView = nil
                                avatarIconView.removeFromSuperview()

                                strongSelf.avatarNode.isHidden = false
                            }
                            
                            let _ = titleApply()
                            let titleFrame = titleFrame.offsetBy(dx: revealOffset, dy: 0.0)
                            transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                            
                            strongSelf.titleNode.alpha = item.enabled ? 1.0 : 0.4
                            strongSelf.statusNode.alpha = item.enabled ? 1.0 : 1.0
                            
                            let _ = statusApply()
                            let statusFrame = CGRect(origin: CGPoint(x: revealOffset + leftInset, y: strongSelf.titleNode.frame.maxY - 1.0), size: statusLayout.size)
                            let previousStatusFrame = strongSelf.statusNode.frame
                            
                            strongSelf.statusNode.frame = statusFrame
                            transition.animatePositionAdditive(node: strongSelf.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
                            
                            if let credibilityIcon = credibilityIcon {
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
                                    isVisibleForAnimations: strongSelf.visibilityStatus,
                                    action: nil,
                                    emojiFileUpdated: nil
                                )
                                strongSelf.credibilityIconComponent = credibilityIconComponent
                                
                                let iconSize = credibilityIconView.update(
                                    transition: .immediate,
                                    component: AnyComponent(credibilityIconComponent),
                                    environment: {},
                                    containerSize: CGSize(width: 20.0, height: 20.0)
                                )
                                
                                transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0)), size: iconSize))
                            } else if let credibilityIconView = strongSelf.credibilityIconView {
                                strongSelf.credibilityIconView = nil
                                credibilityIconView.removeFromSuperview()
                            }
                            
                            if let actionButtons = actionButtons {
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
                                var badgeBackgroundFrame = CGRect(x: revealOffset + params.width - params.rightInset - badgeBackgroundWidth - 6.0, y: floor((nodeLayout.contentSize.height - currentBadgeBackgroundImage.size.height) / 2.0), width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                                
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
                            strongSelf.separatorNode.isHidden = last
                            
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
                        }
                    })
                } else {
                    return (nil, { _, _ in
                    })
                }
            })
        }
    }
    
    @objc private func actionButtonPressed(_ sender: HighlightableButtonNode) {
        guard let actionButtonNodes = self.actionButtonNodes, let index = actionButtonNodes.firstIndex(of: sender), let item = self.item, index < item.additionalActions.count else {
            return
        }
        item.additionalActions[index].action?(item.peer)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let item = self.item, let params = self.layoutParams?.1 {
            var leftInset: CGFloat = 65.0 + params.leftInset
            
            switch item.selection {
                case .none:
                    break
                case .selectable:
                    leftInset += 28.0
            }
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = offset + leftInset - 50.0
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var statusFrame = self.statusNode.frame
            let previousStatusFrame = statusFrame
            statusFrame.origin.x = leftInset + offset
            self.statusNode.frame = statusFrame
            transition.animatePositionAdditive(node: self.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
            
            if let credibilityIconView = self.credibilityIconView {
                var iconFrame = credibilityIconView.frame
                iconFrame.origin.x = titleFrame.maxX + 4.0
                transition.updateFrame(view: credibilityIconView, frame: iconFrame)
            }
            
            if let badgeBackgroundNode = self.badgeBackgroundNode, let badgeTextNode = self.badgeTextNode {
                var badgeBackgroundFrame = badgeBackgroundNode.frame
                badgeBackgroundFrame.origin.x = offset + params.width - params.rightInset - badgeBackgroundFrame.width - 6.0
                var badgeTextFrame = badgeTextNode.frame
                badgeTextFrame.origin.x = badgeBackgroundFrame.midX - badgeTextFrame.width / 2.0
                    
                transition.updateFrame(node: badgeBackgroundNode, frame: badgeBackgroundFrame)
                transition.updateFrame(node: badgeTextNode, frame: badgeTextFrame)
            }
        }
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
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
}
