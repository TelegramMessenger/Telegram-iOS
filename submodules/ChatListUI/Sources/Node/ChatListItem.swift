import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import AccountContext
import PeerOnlineMarkerNode
import LocalizedPeerData
import PeerPresenceStatusManager
import PhotoResources
import ChatListSearchItemNode
import ContextUI

public enum ChatListItemContent {
    case peer(message: Message?, peer: RenderedPeer, combinedReadState: CombinedPeerReadState?, isRemovedFromTotalUnreadCount: Bool, presence: PeerPresence?, summaryInfo: ChatListMessageTagSummaryInfo, embeddedState: PeerChatListEmbeddedInterfaceState?, inputActivities: [(Peer, PeerInputActivity)]?, promoInfo: ChatListNodeEntryPromoInfo?, ignoreUnreadBadge: Bool, displayAsMessage: Bool, hasFailedMessages: Bool)
    case groupReference(groupId: PeerGroupId, peers: [ChatListGroupReferencePeer], message: Message?, unreadState: PeerGroupUnreadCountersCombinedSummary, hiddenByDefault: Bool)
    
    public var chatLocation: ChatLocation? {
        switch self {
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _):
                return .peer(peer.peerId)
            case .groupReference:
                return nil
        }
    }
}

public class ChatListItem: ListViewItem, ChatListSearchItemNeighbour {
    let presentationData: ChatListPresentationData
    let context: AccountContext
    let peerGroupId: PeerGroupId
    let filterData: ChatListItemFilterData?
    let index: ChatListIndex
    public let content: ChatListItemContent
    let editing: Bool
    let hasActiveRevealControls: Bool
    let selected: Bool
    let enableContextActions: Bool
    let hiddenOffset: Bool
    let interaction: ChatListNodeInteraction
    
    public let selectable: Bool = true
    
    public var approximateHeight: CGFloat {
        return self.hiddenOffset ? 0.0 : 44.0
    }
    
    let header: ListViewItemHeader?
    
    public var isPinned: Bool {
        return self.index.pinningIndex != nil
    }
    
    public init(presentationData: ChatListPresentationData, context: AccountContext, peerGroupId: PeerGroupId, filterData: ChatListItemFilterData?, index: ChatListIndex, content: ChatListItemContent, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, header: ListViewItemHeader?, enableContextActions: Bool, hiddenOffset: Bool, interaction: ChatListNodeInteraction) {
        self.presentationData = presentationData
        self.peerGroupId = peerGroupId
        self.filterData = filterData
        self.context = context
        self.index = index
        self.content = content
        self.editing = editing
        self.hasActiveRevealControls = hasActiveRevealControls
        self.selected = selected
        self.header = header
        self.enableContextActions = enableContextActions
        self.hiddenOffset = hiddenOffset
        self.interaction = interaction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListItemNode()
            let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            node.insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, first, last, firstWithHeader, nextIsPinned)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        node.setupItem(item: self, synchronousLoads: synchronousLoads)
                        apply(synchronousLoads, false)
                        node.updateIsHighlighted(transition: .immediate)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListItemNode)
            if let nodeValue = node() as? ChatListItemNode {
                nodeValue.setupItem(item: self, synchronousLoads: false)
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, nextIsPinned)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        switch self.content {
            case let .peer(message, peer, _, _, _, _, _, _, promoInfo, _, _, _):
                if let message = message, let peer = peer.peer {
                    self.interaction.messageSelected(peer, message, promoInfo)
                } else if let peer = peer.peer {
                    self.interaction.peerSelected(peer, promoInfo)
                } else if let peer = peer.peers[peer.peerId] {
                    self.interaction.peerSelected(peer, promoInfo)
                }
            case let .groupReference(groupId, _, _, _, _):
                self.interaction.groupSelected(groupId)
        }
    }
    
    static func mergeType(item: ChatListItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ChatListItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        var nextIsPinned = false
        if let nextItem = nextItem as? ChatListItem {
            if nextItem.index.pinningIndex != nil {
                nextIsPinned = true
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader, nextIsPinned)
    }
}

private let pinIcon = ItemListRevealOptionIcon.animation(animation: "anim_pin", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let unpinIcon = ItemListRevealOptionIcon.animation(animation: "anim_unpin", scale: 0.33333, offset: 0.0, keysToColor: ["un Outlines.Group 1.Stroke 1"], flip: false)
private let muteIcon = ItemListRevealOptionIcon.animation(animation: "anim_mute", scale: 0.33333, offset: 0.0, keysToColor: ["un Outlines.Group 1.Stroke 1"], flip: false)
private let unmuteIcon = ItemListRevealOptionIcon.animation(animation: "anim_unmute", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let deleteIcon = ItemListRevealOptionIcon.animation(animation: "anim_delete", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let groupIcon = ItemListRevealOptionIcon.animation(animation: "anim_group", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let ungroupIcon = ItemListRevealOptionIcon.animation(animation: "anim_ungroup", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let readIcon = ItemListRevealOptionIcon.animation(animation: "anim_read", scale: 0.33333, offset: 0.0, keysToColor: nil, flip: false)
private let unreadIcon = ItemListRevealOptionIcon.animation(animation: "anim_unread", scale: 0.33333, offset: 0.0, keysToColor: ["Oval.Oval.Stroke 1"], flip: false)
private let archiveIcon = ItemListRevealOptionIcon.animation(animation: "anim_archive", scale: 0.33333, offset: 2.0, keysToColor: ["box2.box2.Fill 1"], flip: false)
private let unarchiveIcon = ItemListRevealOptionIcon.animation(animation: "anim_unarchive", scale: 0.16214, offset: -9.0, keysToColor: ["box2.box2.Fill 1"], flip: false)
private let hideIcon = ItemListRevealOptionIcon.animation(animation: "anim_hide", scale: 0.33333, offset: 2.0, keysToColor: ["Path 2.Path 2.Fill 1"], flip: false)
private let unhideIcon = ItemListRevealOptionIcon.animation(animation: "anim_hide", scale: 0.33333, offset: -20.0, keysToColor: ["Path 2.Path 2.Fill 1"], flip: true)

private enum RevealOptionKey: Int32 {
    case pin
    case unpin
    case mute
    case unmute
    case delete
    case group
    case ungroup
    case toggleMarkedUnread
    case archive
    case unarchive
    case hide
    case unhide
    case hidePsa
}

private func canArchivePeer(id: PeerId, accountPeerId: PeerId) -> Bool {
    if id.namespace == Namespaces.Peer.CloudUser && id.id == 777000 {
        return false
    }
    if id == accountPeerId {
        return false
    }
    return true
}

public struct ChatListItemFilterData: Equatable {
    public var excludesArchived: Bool
    
    public init(excludesArchived: Bool) {
        self.excludesArchived = excludesArchived
    }
}

private func revealOptions(strings: PresentationStrings, theme: PresentationTheme, isPinned: Bool, isMuted: Bool?, groupId: PeerGroupId, peerId: PeerId, accountPeerId: PeerId, canDelete: Bool, isEditing: Bool, filterData: ChatListItemFilterData?) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if case .group = groupId {
            if isPinned {
                options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            }
        } else {
            if let isMuted = isMuted {
                if isMuted {
                    options.append(ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: strings.ChatList_Unmute, icon: unmuteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
                } else {
                    options.append(ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: strings.ChatList_Mute, icon: muteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
                }
            }
        }
    }
    if canDelete {
        options.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: strings.Common_Delete, icon: deleteIcon, color: theme.list.itemDisclosureActions.destructive.fillColor, textColor: theme.list.itemDisclosureActions.destructive.foregroundColor))
    }
    if !isEditing {
        var canArchive = false
        var canUnarchive = false
        if let filterData = filterData {
            if filterData.excludesArchived {
                canArchive = true
            }
        } else {
            if case .root = groupId {
                canArchive = true
            } else {
                canUnarchive = true
            }
        }
        if canArchive {
            if canArchivePeer(id: peerId, accountPeerId: accountPeerId) {
                options.append(ItemListRevealOption(key: RevealOptionKey.archive.rawValue, title: strings.ChatList_ArchiveAction, icon: archiveIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.inactive.foregroundColor))
            }
        } else if canUnarchive {
            options.append(ItemListRevealOption(key: RevealOptionKey.unarchive.rawValue, title: strings.ChatList_UnarchiveAction, icon: unarchiveIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.inactive.foregroundColor))
        }
    }
    return options
}

private func groupReferenceRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isEditing: Bool, hiddenByDefault: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if hiddenByDefault {
            options.append(ItemListRevealOption(key: RevealOptionKey.unhide.rawValue, title: strings.ChatList_UnhideAction, icon: unhideIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
        } else {
            options.append(ItemListRevealOption(key: RevealOptionKey.hide.rawValue, title: strings.ChatList_HideAction, icon: hideIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
        }
    }
    return options
}

private func leftRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isUnread: Bool, isEditing: Bool, isPinned: Bool, isSavedMessages: Bool, groupId: PeerGroupId, filterData: ChatListItemFilterData?) -> [ItemListRevealOption] {
    if case .group = groupId {
        return []
    }
    var options: [ItemListRevealOption] = []
    if isUnread {
        options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Read, icon: readIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
    } else {
        options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Unread, icon: unreadIcon, color: theme.list.itemDisclosureActions.accent.fillColor, textColor: theme.list.itemDisclosureActions.accent.foregroundColor))
    }
    if !isEditing {
        if isPinned {
            options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
        } else {
            options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
        }
    }
    return options
}

private final class ChatListItemAccessibilityCustomAction: UIAccessibilityCustomAction {
    let key: Int32
    
    init(name: String, target: Any?, selector: Selector, key: Int32) {
        self.key = key
        
        super.init(name: name, target: target, selector: selector)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

private final class CachedChatListSearchResult {
    let text: String
    let searchQuery: String
    let resultRanges: [Range<String.Index>]
    
    init(text: String, searchQuery: String, resultRanges: [Range<String.Index>]) {
        self.text = text
        self.searchQuery = searchQuery
        self.resultRanges = resultRanges
    }
    
    func matches(text: String, searchQuery: String) -> Bool {
        if self.text != text {
            return false
        }
        if self.searchQuery != searchQuery {
            return false
        }
        return true
    }
}

class ChatListItemNode: ItemListRevealOptionsItemNode {
    var item: ChatListItem?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let contextContainer: ContextControllerSourceNode
    
    let avatarNode: AvatarNode
    let titleNode: TextNode
    let authorNode: TextNode
    let measureNode: TextNode
    private var currentItemHeight: CGFloat?
    let textNode: TextNode
    let contentImageNode: TransformImageNode
    let inputActivitiesNode: ChatListInputActivitiesNode
    let dateNode: TextNode
    let separatorNode: ASDisplayNode
    let statusNode: ChatListStatusNode
    let badgeNode: ChatListBadgeNode
    let mentionBadgeNode: ChatListBadgeNode
    let onlineNode: PeerOnlineMarkerNode
    let pinnedIconNode: ASImageNode
    var secretIconNode: ASImageNode?
    var credibilityIconNode: ASImageNode?
    let mutedIconNode: ASImageNode
    
    var selectableControlNode: ItemListSelectableControlNode?
    var reorderControlNode: ItemListEditableReorderControlNode?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    
    private var cachedChatListText: (String, String)?
    private var cachedChatListSearchResult: CachedChatListSearchResult?
    
    var layoutParams: (ChatListItem, first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool, ListViewItemLayoutParams, countersSize: CGFloat)?
    private var contentImageMedia: Media?
    
    private var isHighlighted: Bool = false
    private var skipFadeout: Bool = false
    
    override var canBeSelected: Bool {
        if self.selectableControlNode != nil || self.item?.editing == true {
            return false
        } else {
            return super.canBeSelected
        }
    }
    
    override var defaultAccessibilityLabel: String? {
        get {
            return self.accessibilityLabel
        } set(value) {
        }
    }
    override var accessibilityAttributedLabel: NSAttributedString? {
        get {
            return self.accessibilityLabel.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    override var accessibilityAttributedValue: NSAttributedString? {
        get {
            return self.accessibilityValue.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    
    override var accessibilityLabel: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case .groupReference:
                    return nil
                case let .peer(peer):
                    guard let chatMainPeer = peer.peer.chatMainPeer else {
                        return nil
                    }
                    return chatMainPeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
            }
        } set(value) {
        }
    }
    
    override var accessibilityValue: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case .groupReference:
                    return nil
                case let .peer(peer):
                    if let message = peer.message {
                        var result = ""
                        if message.flags.contains(.Incoming) {
                            result += "Message"
                        } else {
                            result += "Outgoing message"
                        }
                        let (_, initialHideAuthor, messageText) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, message: peer.message, chatPeer: peer.peer, accountPeerId: item.context.account.peerId, isPeerGroup: false)
                        if message.flags.contains(.Incoming), !initialHideAuthor, let author = message.author, author is TelegramUser {
                            result += "\nFrom: \(author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder))"
                        }
                        if !message.flags.contains(.Incoming), let combinedReadState = peer.combinedReadState, combinedReadState.isOutgoingMessageIndexRead(message.index) {
                            result += "\nRead"
                        }
                        result += "\n\(messageText)"
                        return result
                    } else {
                        return "Empty"
                    }
            }
        } set(value) {
        }
    }
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.measureNode = TextNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = true
        
        self.authorNode = TextNode()
        self.authorNode.isUserInteractionEnabled = false
        self.authorNode.displaysAsynchronously = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        self.contentImageNode = TransformImageNode()
        self.contentImageNode.isHidden = true
        
        self.inputActivitiesNode = ChatListInputActivitiesNode()
        self.inputActivitiesNode.isUserInteractionEnabled = false
        self.inputActivitiesNode.alpha = 0.0
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = true
        
        self.statusNode = ChatListStatusNode()
        self.badgeNode = ChatListBadgeNode()
        self.mentionBadgeNode = ChatListBadgeNode()
        self.onlineNode = PeerOnlineMarkerNode()
        
        self.pinnedIconNode = ASImageNode()
        self.pinnedIconNode.isLayerBacked = true
        self.pinnedIconNode.displaysAsynchronously = false
        self.pinnedIconNode.displayWithoutProcessing = true
        
        self.mutedIconNode = ASImageNode()
        self.mutedIconNode.isLayerBacked = true
        self.mutedIconNode.displaysAsynchronously = false
        self.mutedIconNode.displayWithoutProcessing = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.contextContainer)
        
        self.contextContainer.addSubnode(self.avatarNode)
        self.contextContainer.addSubnode(self.onlineNode)
        
        self.contextContainer.addSubnode(self.titleNode)
        self.contextContainer.addSubnode(self.authorNode)
        self.contextContainer.addSubnode(self.textNode)
        self.contextContainer.addSubnode(self.contentImageNode)
        self.contextContainer.addSubnode(self.dateNode)
        self.contextContainer.addSubnode(self.statusNode)
        self.contextContainer.addSubnode(self.pinnedIconNode)
        self.contextContainer.addSubnode(self.badgeNode)
        self.contextContainer.addSubnode(self.mentionBadgeNode)
        self.contextContainer.addSubnode(self.mutedIconNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.5, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4)
                let _ = apply(false, false)
            }
        })
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.interaction.activateChatPreview(item, strongSelf.contextContainer, gesture)
        }
    }
    
    func setupItem(item: ChatListItem, synchronousLoads: Bool) {
        let previousItem = self.item
        self.item = item
        
        var peer: Peer?
        var displayAsMessage = false
        var enablePreview = true
        switch item.content {
            case let .peer(message, peerValue, _, _, _, _, _, _, _, _, displayAsMessageValue, _):
                displayAsMessage = displayAsMessageValue
                if displayAsMessage, let author = message?.author as? TelegramUser {
                    peer = author
                } else {
                    peer = peerValue.chatMainPeer
                }
                if peerValue.peerId.namespace == Namespaces.Peer.SecretChat {
                    enablePreview = false
                }
            case let .groupReference(groupReference):
                if let previousItem = previousItem, case let .groupReference(previousGroupReference) = previousItem.content, groupReference.hiddenByDefault != previousGroupReference.hiddenByDefault {
                    UIView.transition(with: self.avatarNode.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                }
                self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: .archivedChatsIcon(hiddenByDefault: groupReference.hiddenByDefault), emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
        }
        
        if let peer = peer {
            var overrideImage: AvatarNodeImageOverride?
            if peer.id == item.context.account.peerId && !displayAsMessage {
                overrideImage = .savedMessagesIcon
            } else if peer.isDeleted {
                overrideImage = .deletedIcon
            }
            self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: 60.0, height: 60.0))
        }
        
        self.contextContainer.isGestureEnabled = enablePreview
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: item as! ChatListItem, previousItem: previousItem, nextItem: nextItem)
        let (nodeLayout, apply) = layout(item as! ChatListItem, params, first, last, firstWithHeader, nextIsPinned)
        apply(false, false)
        self.contentSize = nodeLayout.contentSize
        self.insets = nodeLayout.insets
    }
    
    class func insets(first: Bool, last: Bool, firstWithHeader: Bool) -> UIEdgeInsets {
        return UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.isHighlighted = highlighted
        
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    var reallyHighlighted: Bool {
        var reallyHighlighted = self.isHighlighted
        if let item = self.item {
            if let itemChatLocation = item.content.chatLocation {
                if itemChatLocation == item.interaction.highlightedChatLocation?.location {
                    reallyHighlighted = true
                }
            }
        }
        return reallyHighlighted
    }
    
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        let highlightProgress: CGFloat = self.item?.interaction.highlightedChatLocation?.progress ?? 1.0
        
        if self.reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: highlightProgress)
            
            if let item = self.item {
                self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted))
            }
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
            
            if let item = self.item {
                let onlineIcon: UIImage?
                if item.index.pinningIndex != nil {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned)
                } else {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular)
                }
                self.onlineNode.setImage(onlineIcon)
            }
        }
    }
    
    override func tapped() {
        guard let item = self.item, item.editing else {
            return
        }
        if case let .peer(_, _, _, _, _, _, _, _, promoInfo, _, _, _) = item.content {
            if promoInfo == nil {
                item.interaction.togglePeerSelected(item.index.messageIndex.id.peerId)
            }
        }
    }
    
    func asyncLayout() -> (_ item: ChatListItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ nextIsPinned: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let authorLayout = TextNode.asyncLayout(self.authorNode)
        let makeMeasureLayout = TextNode.asyncLayout(self.measureNode)
        let inputActivitiesLayout = self.inputActivitiesNode.asyncLayout()
        let badgeLayout = self.badgeNode.asyncLayout()
        let mentionBadgeLayout = self.mentionBadgeNode.asyncLayout()
        let onlineLayout = self.onlineNode.asyncLayout()
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.layoutParams?.0
        let currentContentImageMedia = self.contentImageMedia
        let currentChatListText = self.cachedChatListText
        let currentChatListSearchResult = self.cachedChatListSearchResult
        
        return { item, params, first, last, firstWithHeader, nextIsPinned in
            let titleFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let badgeFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            let account = item.context.account
            var message: Message?
            enum ContentPeer {
                case chat(RenderedPeer)
                case group([ChatListGroupReferencePeer])
            }
            let contentPeer: ContentPeer
            let combinedReadState: CombinedPeerReadState?
            let unreadCount: (count: Int32, unread: Bool, muted: Bool, mutedCount: Int32?)
            let isRemovedFromTotalUnreadCount: Bool
            let peerPresence: PeerPresence?
            let embeddedState: PeerChatListEmbeddedInterfaceState?
            let summaryInfo: ChatListMessageTagSummaryInfo
            let inputActivities: [(Peer, PeerInputActivity)]?
            let isPeerGroup: Bool
            let promoInfo: ChatListNodeEntryPromoInfo?
            let displayAsMessage: Bool
            let hasFailedMessages: Bool
            
            var groupHiddenByDefault = false
            
            switch item.content {
                case let .peer(messageValue, peerValue, combinedReadStateValue, isRemovedFromTotalUnreadCountValue, peerPresenceValue, summaryInfoValue, embeddedStateValue, inputActivitiesValue, promoInfoValue, ignoreUnreadBadge, displayAsMessageValue, hasFailedMessagesValue):
                    message = messageValue
                    contentPeer = .chat(peerValue)
                    combinedReadState = combinedReadStateValue
                    if let combinedReadState = combinedReadState, promoInfoValue == nil && !ignoreUnreadBadge {
                        unreadCount = (combinedReadState.count, combinedReadState.isUnread, isRemovedFromTotalUnreadCountValue, nil)
                    } else {
                        unreadCount = (0, false, false, nil)
                    }
                    if let _ = promoInfoValue {
                        isRemovedFromTotalUnreadCount = false
                    } else {
                        isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCountValue
                    }
                    peerPresence = (peerPresenceValue as? TelegramUserPresence).flatMap { presence -> TelegramUserPresence in
                        TelegramUserPresence(status: presence.status, lastActivity: 0)
                    }
                    embeddedState = embeddedStateValue
                    summaryInfo = summaryInfoValue
                    inputActivities = inputActivitiesValue
                    isPeerGroup = false
                    promoInfo = promoInfoValue
                    displayAsMessage = displayAsMessageValue
                    hasFailedMessages = messageValue?.flags.contains(.Failed) ?? false // hasFailedMessagesValue
                case let .groupReference(_, peers, messageValue, unreadState, hiddenByDefault):
                    if let _ = messageValue, !peers.isEmpty {
                        contentPeer = .chat(peers[0].peer)
                    } else {
                        contentPeer = .group(peers)
                    }
                    message = messageValue
                    combinedReadState = nil
                    isRemovedFromTotalUnreadCount = false
                    embeddedState = nil
                    summaryInfo = ChatListMessageTagSummaryInfo()
                    inputActivities = nil
                    isPeerGroup = true
                    groupHiddenByDefault = hiddenByDefault
                    let allCount = unreadState.count(countingCategory: .chats, mutedCategory: .all)
                    unreadCount = (allCount, allCount != 0, true, nil)
                    peerPresence = nil
                    promoInfo = nil
                    displayAsMessage = false
                    hasFailedMessages = false
            }
            
            if let messageValue = message {
                for media in messageValue.media {
                    if let media = media as? TelegramMediaAction, case .historyCleared = media.action {
                        message = nil
                    }
                }
            }
            
            let theme = item.presentationData.theme.chatList
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var authorAttributedString: NSAttributedString?
            var textAttributedString: NSAttributedString?
            var textLeftCutout: CGFloat = 0.0
            var dateAttributedString: NSAttributedString?
            var titleAttributedString: NSAttributedString?
            var badgeContent = ChatListBadgeContent.none
            var mentionBadgeContent = ChatListBadgeContent.none
            var statusState = ChatListStatusNodeState.none
            
            var currentBadgeBackgroundImage: UIImage?
            var currentMentionBadgeImage: UIImage?
            var currentPinnedIconImage: UIImage?
            var currentMutedIconImage: UIImage?
            var currentCredibilityIconImage: UIImage?
            var currentSecretIconImage: UIImage?
            
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            if item.editing {
                let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, item.selected, true)
                if promoInfo == nil && !isPeerGroup {
                    selectableControlSizeAndApply = sizeAndApply
                }
                editingOffset = sizeAndApply.0
                
                if item.index.pinningIndex != nil && promoInfo == nil && !isPeerGroup {
                    let sizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = sizeAndApply
                    reorderInset = sizeAndApply.0
                }
            } else {
                editingOffset = 0.0
            }
            
            let enableChatListPhotos = item.context.sharedContext.immediateExperimentalUISettings.chatListPhotos
            
            let avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            let avatarLeftInset = 18.0 + avatarDiameter
            
            let badgeDiameter = floor(item.presentationData.fontSize.baseDisplaySize * 20.0 / 17.0)
            
            let leftInset: CGFloat = params.leftInset + avatarLeftInset
            
            enum ContentData {
                case chat(itemPeer: RenderedPeer, peer: Peer?, hideAuthor: Bool, messageText: String)
                case group(peers: [ChatListGroupReferencePeer])
            }
            
            let contentData: ContentData
            
            var hideAuthor = false
            switch contentPeer {
                case let .chat(itemPeer):
                    var (peer, initialHideAuthor, messageText) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, message: message, chatPeer: itemPeer, accountPeerId: item.context.account.peerId, enableMediaEmoji: !enableChatListPhotos, isPeerGroup: isPeerGroup)
                    
                    if case let .psa(_, maybePsaText) = promoInfo, let psaText = maybePsaText {
                        initialHideAuthor = true
                        messageText = psaText
                    }
                    
                    contentData = .chat(itemPeer: itemPeer, peer: peer, hideAuthor: hideAuthor, messageText: messageText)
                    hideAuthor = initialHideAuthor
                case let .group(groupPeers):
                    contentData = .group(peers: groupPeers)
                    hideAuthor = true
            }
            
            let attributedText: NSAttributedString
            var hasDraft = false
            
            var inlineAuthorPrefix: String?
            if case .groupReference = item.content {
                if let author = message?.author as? TelegramUser {
                    if author.id == item.context.account.peerId {
                        inlineAuthorPrefix = item.presentationData.strings.DialogList_You
                    } else if message?.id.peerId.namespace != Namespaces.Peer.CloudUser && message?.id.peerId.namespace != Namespaces.Peer.SecretChat {
                        inlineAuthorPrefix = author.compactDisplayTitle
                    }
                }
            }
            
            var contentImageMedia: Media?
            var chatListText: (String, String)?
            var chatListSearchResult: CachedChatListSearchResult?
            
            switch contentData {
                case let .chat(itemPeer, _, _, text):
                    var peerText: String?
                    if case .groupReference = item.content {
                        if let messagePeer = itemPeer.chatMainPeer {
                            peerText = messagePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                        }
                    } else if let message = message, let author = message.author as? TelegramUser, let peer = itemPeer.chatMainPeer, !(peer is TelegramUser) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        } else if !displayAsMessage {
                            peerText = author.id == account.peerId ? item.presentationData.strings.DialogList_You : author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                        }
                    }
                    
                    let messageText: String
                    if let currentChatListText = currentChatListText, currentChatListText.0 == text {
                        messageText = currentChatListText.1
                        chatListText = currentChatListText
                    } else {
                        messageText = foldLineBreaks(text)
                        chatListText = (text, messageText)
                    }
                    
                    if inlineAuthorPrefix == nil, let embeddedState = embeddedState as? ChatEmbeddedInterfaceState {
                        hasDraft = true
                        authorAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Draft, font: textFont, textColor: theme.messageDraftTextColor)
                        
                        attributedText = NSAttributedString(string: foldLineBreaks(embeddedState.text.string.replacingOccurrences(of: "\n\n", with: " ")), font: textFont, textColor: theme.messageTextColor)
                    } else if let message = message {
                        let composedString: NSMutableAttributedString
                        if let inlineAuthorPrefix = inlineAuthorPrefix {
                            composedString = NSMutableAttributedString()
                            composedString.append(NSAttributedString(string: "\(inlineAuthorPrefix): ", font: textFont, textColor: theme.titleColor))
                            composedString.append(NSAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor))
                        } else {
                            composedString = NSMutableAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                        }
                        
                        if let searchQuery = item.interaction.searchTextHighightState {
                            if let cached = currentChatListSearchResult, cached.matches(text: composedString.string, searchQuery: searchQuery) {
                                chatListSearchResult = cached
                            } else {
                                let (ranges, text) = findSubstringRanges(in: composedString.string, query: searchQuery)
                                chatListSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                            }
                        } else {
                            chatListSearchResult = nil
                        }
                        
                        if let chatListSearchResult = chatListSearchResult {
                            for range in chatListSearchResult.resultRanges {
                                let stringRange = NSRange(range, in: chatListSearchResult.text)
                                if stringRange.location >= 0 && stringRange.location + stringRange.length <= composedString.length {
                                    composedString.addAttribute(.foregroundColor, value: theme.messageHighlightedTextColor, range: stringRange)
                                }
                            }
                        }
                        
                        attributedText = composedString
                        
                        if let peerText = peerText {
                            authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                        }
                        
                        if enableChatListPhotos && !message.containsSecretMedia {
                            for media in message.media {
                                if let image = media as? TelegramMediaImage {
                                    textLeftCutout += 26.0
                                    contentImageMedia = image
                                    break
                                } else if let file = media as? TelegramMediaFile {
                                    if file.isVideo && !file.isInstantVideo {
                                        textLeftCutout += 26.0
                                        contentImageMedia = file
                                        break
                                    }
                                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                    if let image = content.image {
                                        textLeftCutout += 26.0
                                        contentImageMedia = image
                                        break
                                    } else if let file = content.file {
                                        if file.isVideo && !file.isInstantVideo {
                                            textLeftCutout += 26.0
                                            contentImageMedia = file
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        attributedText = NSAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                        
                        var peerText: String?
                        if case .groupReference = item.content {
                            if let messagePeer = itemPeer.chatMainPeer {
                                peerText = messagePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                            }
                        }
                        
                        if let peerText = peerText {
                            authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                        }
                    }
                case let .group(peers):
                    let textString = NSMutableAttributedString(string: "")
                    var isFirst = true
                    for peer in peers {
                        if let chatMainPeer = peer.peer.chatMainPeer {
                            let peerTitle = chatMainPeer.compactDisplayTitle
                            if !peerTitle.isEmpty {
                                if isFirst {
                                    isFirst = false
                                } else {
                                    textString.append(NSAttributedString(string: ", ", font: textFont, textColor: theme.messageTextColor))
                                }
                                textString.append(NSAttributedString(string: peerTitle, font: textFont, textColor: peer.isUnread ? theme.authorNameColor : theme.messageTextColor))
                            }
                        }
                    }
                    attributedText = textString
            }
            
            switch contentData {
                case let .chat(itemPeer, _, _, _):
                    if let message = message, let author = message.author as? TelegramUser, displayAsMessage {
                        titleAttributedString = NSAttributedString(string: author.id == account.peerId ? item.presentationData.strings.DialogList_You : author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: titleFont, textColor: theme.titleColor)
                    } else if isPeerGroup {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_ArchivedChatsTitle, font: titleFont, textColor: theme.titleColor)
                    } else if itemPeer.chatMainPeer?.id == item.context.account.peerId {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleFont, textColor: theme.titleColor)
                    } else if let displayTitle = itemPeer.chatMainPeer?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder) {
                        titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: item.index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat ? theme.secretTitleColor : theme.titleColor)
                    }
                case .group:
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_ArchivedChatsTitle, font: titleFont, textColor: theme.titleColor)
            }
            
            textAttributedString = attributedText
            
            var t = Int(item.index.messageIndex.timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.index.messageIndex.timestamp, relativeTo: timestamp, dateTimeFormat: item.presentationData.dateTimeFormat)
            
            if isPeerGroup {
                dateAttributedString = NSAttributedString(string: "", font: dateFont, textColor: theme.dateTextColor)
            } else if let promoInfo = promoInfo {
                switch promoInfo {
                case .proxy:
                    dateAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_AdLabel, font: dateFont, textColor: theme.dateTextColor)
                case let .psa(type, _):
                    var text = item.presentationData.strings.ChatList_GenericPsaLabel
                    let key = "ChatList.PsaLabel.\(type)"
                    if let string = item.presentationData.strings.primaryComponent.dict[key] {
                        text = string
                    } else if let string = item.presentationData.strings.secondaryComponent?.dict[key] {
                        text = string
                    }
                    dateAttributedString = NSAttributedString(string: text, font: dateFont, textColor: theme.dateTextColor)
                }
            } else {
                dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: theme.dateTextColor)
            }
            
            if !isPeerGroup, let message = message, message.author?.id == account.peerId && !hasDraft {
                if message.flags.isSending && !message.isSentOrAcknowledged {
                    statusState = .clock(PresentationResourcesChatList.clockFrameImage(item.presentationData.theme), PresentationResourcesChatList.clockMinImage(item.presentationData.theme))
                } else if message.id.peerId != account.peerId {
                    if hasFailedMessages {
                        statusState = .failed(item.presentationData.theme.chatList.failedFillColor, item.presentationData.theme.chatList.failedForegroundColor)
                    } else {
                        if let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIndexRead(message.index) {
                            statusState = .read(item.presentationData.theme.chatList.checkmarkColor)
                        } else {
                            statusState = .delivered(item.presentationData.theme.chatList.checkmarkColor)
                        }
                    }
                }
            }
            
            if unreadCount.unread {
                if !isPeerGroup, let message = message, message.tags.contains(.unseenPersonalMessage), unreadCount.count == 1 {
                } else {
                    let badgeTextColor: UIColor
                    if unreadCount.muted {
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: badgeDiameter)
                        badgeTextColor = theme.unreadBadgeInactiveTextColor
                    } else {
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: badgeDiameter)
                        badgeTextColor = theme.unreadBadgeActiveTextColor
                    }
                    let unreadCountText = compactNumericCountString(Int(unreadCount.count), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                    if unreadCount.count > 0 {
                        badgeContent = .text(NSAttributedString(string: unreadCountText, font: badgeFont, textColor: badgeTextColor))
                    } else if isPeerGroup {
                        badgeContent = .none
                    } else {
                        badgeContent = .blank
                    }
                    
                    if let mutedCount = unreadCount.mutedCount, mutedCount > 0 {
                        let mutedUnreadCountText = compactNumericCountString(Int(mutedCount), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: badgeDiameter)
                        mentionBadgeContent = .text(NSAttributedString(string: mutedUnreadCountText, font: badgeFont, textColor: theme.unreadBadgeInactiveTextColor))
                    }
                }
            }
            
            let tagSummaryCount = summaryInfo.tagSummaryCount ?? 0
            let actionsSummaryCount = summaryInfo.actionsSummaryCount ?? 0
            let totalMentionCount = tagSummaryCount - actionsSummaryCount
            if !isPeerGroup {
                if totalMentionCount > 0 {
                    if Namespaces.PeerGroup.archive == item.peerGroupId {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundInactiveMention(item.presentationData.theme, diameter: badgeDiameter)
                    } else {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundMention(item.presentationData.theme, diameter: badgeDiameter)
                    }
                    mentionBadgeContent = .mention
                } else if item.index.pinningIndex != nil && promoInfo == nil && currentBadgeBackgroundImage == nil {
                    currentPinnedIconImage = PresentationResourcesChatList.badgeBackgroundPinned(item.presentationData.theme, diameter: badgeDiameter)
                }
            }
            
            var isMuted = isRemovedFromTotalUnreadCount
            if isMuted {
                currentMutedIconImage = PresentationResourcesChatList.mutedIcon(item.presentationData.theme)
            }
            
            let statusWidth: CGFloat
            if case .none = statusState {
                statusWidth = 0.0
            } else {
                statusWidth = 24.0
            }
            
            var titleIconsWidth: CGFloat = 0.0
            if let currentMutedIconImage = currentMutedIconImage {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                }
                titleIconsWidth += currentMutedIconImage.size.width
            }
    
            let isSecret = !isPeerGroup && item.index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat
            if isSecret {
                currentSecretIconImage = PresentationResourcesChatList.secretIcon(item.presentationData.theme)
            }
            var credibilityIconOffset: CGFloat = 0.0
            if displayAsMessage {
                switch item.content {
                case let .peer(message, _, _, _, _, _, _, _, _, _, _, _):
                    if let peer = message?.author {
                        if peer.isScam {
                            currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, type: .regular)
                            credibilityIconOffset = 2.0
                        } else if peer.isVerified {
                            currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                            credibilityIconOffset = 3.0
                        }
                    }
                default:
                    break
                }
            } else if case let .chat(itemPeer) = contentPeer, let peer = itemPeer.chatMainPeer {
                if peer.isScam {
                    currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, type: .regular)
                    credibilityIconOffset = 2.0
                } else if peer.isVerified {
                    currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                    credibilityIconOffset = 3.0
                }
            }
            if let currentSecretIconImage = currentSecretIconImage {
                titleIconsWidth += currentSecretIconImage.size.width + 2.0
            }
            if let currentCredibilityIconImage = currentCredibilityIconImage {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                } else {
                    titleIconsWidth += 2.0
                }
                titleIconsWidth += currentCredibilityIconImage.size.width
            }
            
            let layoutOffset: CGFloat = 0.0
            
            let rawContentOriginX = 2.0
            let rawContentWidth = params.width - leftInset - params.rightInset - 10.0 - editingOffset
            
            let (dateLayout, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (badgeLayout, badgeApply) = badgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentBadgeBackgroundImage, badgeContent)
            
            let (mentionBadgeLayout, mentionBadgeApply) = mentionBadgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentMentionBadgeImage, mentionBadgeContent)
            
            var badgeSize: CGFloat = 0.0
            if !badgeLayout.width.isZero {
                badgeSize += badgeLayout.width + 5.0
            }
            if !mentionBadgeLayout.width.isZero {
                if !badgeSize.isZero {
                    badgeSize += mentionBadgeLayout.width + 4.0
                } else {
                    badgeSize += mentionBadgeLayout.width + 5.0
                }
            }
            let countersSize = badgeSize
            if let currentPinnedIconImage = currentPinnedIconImage {
                if !badgeSize.isZero {
                    badgeSize += 4.0
                } else {
                    badgeSize += 5.0
                }
                badgeSize += currentPinnedIconImage.size.width
            }
            badgeSize = max(badgeSize, reorderInset)
            
            let (authorLayout, authorApply) = authorLayout(TextNodeLayoutArguments(attributedString: hideAuthor ? nil : authorAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth - badgeSize, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            var textCutout: TextNodeCutout?
            if !textLeftCutout.isZero {
                textCutout = TextNodeCutout(topLeft: CGSize(width: textLeftCutout, height: 4.0), topRight: nil, bottomRight: nil)
            }
            let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: textAttributedString, backgroundColor: nil, maximumNumberOfLines: authorAttributedString == nil ? 2 : 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth - badgeSize, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: textCutout, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            let titleRectWidth = rawContentWidth - dateLayout.size.width - 10.0 - statusWidth - titleIconsWidth
            let (titleLayout, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
            var inputActivitiesSize: CGSize?
            var inputActivitiesApply: (() -> Void)?
            if let inputActivities = inputActivities, !inputActivities.isEmpty {
                let (size, apply) = inputActivitiesLayout(CGSize(width: rawContentWidth - badgeSize, height: 40.0), item.presentationData, item.presentationData.theme.chatList.messageTextColor, item.index.messageIndex.id.peerId, inputActivities)
                inputActivitiesSize = size
                inputActivitiesApply = apply
            }
            
            var online = false
            var animateOnline = false

            let peerRevealOptions: [ItemListRevealOption]
            let peerLeftRevealOptions: [ItemListRevealOption]
            switch item.content {
                case let .peer(_, renderedPeer, _, _, presence, _ ,_ ,_, _, _, displayAsMessage, _):
                    if !displayAsMessage, let peer = renderedPeer.peer as? TelegramUser, let presence = presence as? TelegramUserPresence, !isServicePeer(peer) && !peer.flags.contains(.isSupport) && peer.id != item.context.account.peerId  {
                        var updatedPresence = TelegramUserPresence(status: presence.status, lastActivity: 0)
                        let relativeStatus = relativeUserPresenceStatus(updatedPresence, relativeTo: timestamp)
                        if case .online = relativeStatus {
                            online = true
                        }
                        animateOnline = true
                    }
                    
                    let isPinned = item.index.pinningIndex != nil
                    
                    if item.enableContextActions {
                        if case .psa = promoInfo {
                            peerRevealOptions = [
                                ItemListRevealOption(key: RevealOptionKey.hidePsa.rawValue, title: item.presentationData.strings.ChatList_HideAction, icon: deleteIcon, color: item.presentationData.theme.list.itemDisclosureActions.inactive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.neutral1.foregroundColor)
                            ]
                            peerLeftRevealOptions = []
                        } else if promoInfo == nil {
                            peerRevealOptions = revealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isPinned: isPinned, isMuted: item.context.account.peerId != item.index.messageIndex.id.peerId ? (currentMutedIconImage != nil) : nil, groupId: item.peerGroupId, peerId: renderedPeer.peerId, accountPeerId: item.context.account.peerId, canDelete: true, isEditing: item.editing, filterData: item.filterData)
                            if case let .chat(itemPeer) = contentPeer {
                                peerLeftRevealOptions = leftRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isUnread: unreadCount.unread, isEditing: item.editing, isPinned: isPinned, isSavedMessages: itemPeer.peerId == item.context.account.peerId, groupId: item.peerGroupId, filterData: item.filterData)
                            } else {
                                peerLeftRevealOptions = []
                            }
                        } else {
                            peerRevealOptions = []
                            peerLeftRevealOptions = []
                        }
                    } else {
                        peerRevealOptions = []
                        peerLeftRevealOptions = []
                    }
                case .groupReference:
                    peerRevealOptions = groupReferenceRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isEditing: item.editing, hiddenByDefault: groupHiddenByDefault)
                    peerLeftRevealOptions = []
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let contentImageMedia = contentImageMedia {
                if let currentContentImageMedia = currentContentImageMedia, contentImageMedia.isSemanticallyEqual(to: currentContentImageMedia) {
                } else {
                    if let message = message {
                        if let image = contentImageMedia as? TelegramMediaImage {
                            updateImageSignal = mediaGridMessagePhoto(account: item.context.account, photoReference: .message(message: MessageReference(message), media: image))
                        } else if let file = contentImageMedia as? TelegramMediaFile {
                            updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: .message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true)
                        }
                    }
                }
            }
            
            let (onlineLayout, onlineApply) = onlineLayout(online)
            var animateContent = false
            if let currentItem = currentItem, currentItem.content.chatLocation == item.content.chatLocation {
                animateContent = true
            }
            
            let measureString = NSAttributedString(string: "A", font: titleFont, textColor: .black)
            let (measureLayout, measureApply) = makeMeasureLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = -1.0
            let authorSpacing: CGFloat = -3.0
            var itemHeight: CGFloat = 8.0 * 2.0 + 1.0
            itemHeight += measureLayout.size.height * 3.0
            itemHeight += titleSpacing
            itemHeight += authorSpacing
            
            /*if authorLayout.size.height.isZero {
                itemHeight += textLayout.size.height
            } else {
                itemHeight += authorLayout.size.height
                itemHeight += authorSpacing + textLayout.size.height
            }*/
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: layoutOffset + 8.0), size: CGSize(width: rawContentWidth, height: itemHeight - 12.0 - 9.0))
            
            let insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            var heightOffset: CGFloat = 0.0
            if item.hiddenOffset {
                heightOffset = -itemHeight
            }
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: max(0.0, itemHeight + heightOffset)), insets: insets)
            
            let contentImageSize = CGSize(width: 22.0, height: 22.0)
            
            var customActions: [ChatListItemAccessibilityCustomAction] = []
            for option in peerLeftRevealOptions {
                customActions.append(ChatListItemAccessibilityCustomAction(name: option.title, target: nil, selector: #selector(ChatListItemNode.performLocalAccessibilityCustomAction(_:)), key: option.key))
            }
            for option in peerRevealOptions {
                customActions.append(ChatListItemAccessibilityCustomAction(name: option.title, target: nil, selector: #selector(ChatListItemNode.performLocalAccessibilityCustomAction(_:)), key: option.key))
            }
            
            return (layout, { [weak self] synchronousLoads, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, first, last, firstWithHeader, nextIsPinned, params, countersSize)
                    strongSelf.currentItemHeight = itemHeight
                    strongSelf.contentImageMedia = contentImageMedia
                    strongSelf.cachedChatListText = chatListText
                    strongSelf.cachedChatListSearchResult = chatListSearchResult
                    
                    strongSelf.contextContainer.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    
                    var dimensions: CGSize?
                    if let contentImageMedia = contentImageMedia as? TelegramMediaImage {
                        dimensions = largestRepresentationForPhoto(contentImageMedia)?.dimensions.cgSize
                    } else if let contentImageMedia = contentImageMedia as? TelegramMediaFile {
                        dimensions = contentImageMedia.dimensions?.cgSize
                    }
                    
                    var contentImageNodeAppeared = false
                    if let dimensions = dimensions {
                        let makeImageLayout = strongSelf.contentImageNode.asyncLayout()
                        let imageSize = contentImageSize
                        
                        let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(radius: 2.0), imageSize: dimensions.aspectFilled(imageSize), boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
                        applyImageLayout()
                        
                        if let updateImageSignal = updateImageSignal {
                            strongSelf.contentImageNode.setSignal(updateImageSignal)
                            if currentContentImageMedia == nil {
                                strongSelf.contentImageNode.isHidden = false
                                contentImageNodeAppeared = true
                            }
                        }
                    } else {
                        if currentContentImageMedia != nil {
                            strongSelf.contentImageNode.removeFromSupernode()
                            strongSelf.contentImageNode.setSignal(.single({ _ in nil }))
                            strongSelf.contentImageNode.isHidden = true
                        }
                    }
                    
                    if case .groupReference = item.content {
                        strongSelf.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, layout.contentSize.height - itemHeight, 0.0)
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.presentationData.theme.chatList.itemSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.chatList.itemHighlightedBackgroundColor
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    var crossfadeContent = false
                    if let selectableControlSizeAndApply = selectableControlSizeAndApply {
                        let selectableControlSize = CGSize(width: selectableControlSizeAndApply.0, height: layout.contentSize.height)
                        let selectableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: layoutOffset), size: selectableControlSize)
                        if strongSelf.selectableControlNode == nil {
                            crossfadeContent = true
                            let selectableControlNode = selectableControlSizeAndApply.1(selectableControlSize, false)
                            strongSelf.selectableControlNode = selectableControlNode
                            strongSelf.addSubnode(selectableControlNode)
                            selectableControlNode.frame = selectableControlFrame
                            transition.animatePosition(node: selectableControlNode, from: CGPoint(x: -selectableControlFrame.size.width / 2.0, y: layoutOffset + selectableControlFrame.midY))
                            selectableControlNode.alpha = 0.0
                            transition.updateAlpha(node: selectableControlNode, alpha: 1.0)
                        } else if let selectableControlNode = strongSelf.selectableControlNode {
                            transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
                            let _ = selectableControlSizeAndApply.1(selectableControlSize, transition.isAnimated)
                        }
                    } else if let selectableControlNode = strongSelf.selectableControlNode {
                        crossfadeContent = true
                        var selectableControlFrame = selectableControlNode.frame
                        selectableControlFrame.origin.x = -selectableControlFrame.size.width
                        strongSelf.selectableControlNode = nil
                        transition.updateAlpha(node: selectableControlNode, alpha: 0.0)
                        transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame, completion: { [weak selectableControlNode] _ in
                            selectableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    var animateBadges = animateContent
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderControlSizeAndApply.0, y: layoutOffset), size: CGSize(width: reorderControlSizeAndApply.0, height: layout.contentSize.height))
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.addSubnode(reorderControlNode)
                            reorderControlNode.frame = reorderControlFrame
                            reorderControlNode.alpha = 0.0
                            transition.updateAlpha(node: reorderControlNode, alpha: 1.0)
                            
                            transition.updateAlpha(node: strongSelf.dateNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.badgeNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.pinnedIconNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.statusNode, alpha: 0.0)
                        } else if let reorderControlNode = strongSelf.reorderControlNode {
                            let _ = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
                        }
                    } else if let reorderControlNode = strongSelf.reorderControlNode {
                        animateBadges = false
                        strongSelf.reorderControlNode = nil
                        transition.updateAlpha(node: reorderControlNode, alpha: 0.0, completion: { [weak reorderControlNode] _ in
                            reorderControlNode?.removeFromSupernode()
                        })
                        transition.updateAlpha(node: strongSelf.dateNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.badgeNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.pinnedIconNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.statusNode, alpha: 1.0)
                    }
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: leftInset - avatarLeftInset + editingOffset + 10.0 + revealOffset, y: floor((itemHeight - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
                    transition.updateFrame(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    let onlineFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX - onlineLayout.width - 2.0, y: avatarFrame.maxY - onlineLayout.height - 2.0), size: onlineLayout)
                    transition.updateFrame(node: strongSelf.onlineNode, frame: onlineFrame)
                    
                    let onlineIcon: UIImage?
                    if strongSelf.reallyHighlighted {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted)
                    } else if item.index.pinningIndex != nil {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned)
                    } else {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular)
                    }
                    strongSelf.onlineNode.setImage(onlineIcon)
                                  
                    let _ = measureApply()
                    let _ = dateApply()
                    let _ = textApply()
                    let _ = authorApply()
                    let _ = titleApply()
                    let _ = badgeApply(animateBadges, !isMuted)
                    let _ = mentionBadgeApply(animateBadges, true)
                    let _ = onlineApply(animateContent && animateOnline)
                    
                    let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + revealOffset, dy: 0.0)
                    
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size))
                    
                    let statusSize = CGSize(width: 24.0, height: 24.0)
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width - statusSize.width, y: contentRect.origin.y + 2.0 - UIScreenPixel + floor((dateLayout.size.height - statusSize.height) / 2.0)), size: statusSize)
                    strongSelf.statusNode.fontSize = item.presentationData.fontSize.itemListBaseFontSize
                    let _ = strongSelf.statusNode.transitionToState(statusState, animated: animateContent)
                    
                    if let _ = currentBadgeBackgroundImage {
                        let badgeFrame = CGRect(x: contentRect.maxX - badgeLayout.width, y: contentRect.maxY - badgeLayout.height - 2.0, width: badgeLayout.width, height: badgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.badgeNode, frame: badgeFrame)
                    }
                    
                    if currentMentionBadgeImage != nil || currentBadgeBackgroundImage != nil {
                        let mentionBadgeOffset: CGFloat
                        if badgeLayout.width.isZero {
                            mentionBadgeOffset = contentRect.maxX - mentionBadgeLayout.width
                        } else {
                            mentionBadgeOffset = contentRect.maxX - badgeLayout.width - 6.0 - mentionBadgeLayout.width
                        }
                        
                        let badgeFrame = CGRect(x: mentionBadgeOffset, y: contentRect.maxY - mentionBadgeLayout.height - 2.0, width: mentionBadgeLayout.width, height: mentionBadgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.mentionBadgeNode, frame: badgeFrame)
                    }
                    
                    if let currentPinnedIconImage = currentPinnedIconImage {
                        strongSelf.pinnedIconNode.image = currentPinnedIconImage
                        strongSelf.pinnedIconNode.isHidden = false
                        
                        let pinnedIconSize = currentPinnedIconImage.size
                        let pinnedIconFrame = CGRect(x: contentRect.maxX - pinnedIconSize.width, y: contentRect.maxY - pinnedIconSize.height - 2.0, width: pinnedIconSize.width, height: pinnedIconSize.height)
                        
                        strongSelf.pinnedIconNode.frame = pinnedIconFrame
                    } else {
                        strongSelf.pinnedIconNode.image = nil
                        strongSelf.pinnedIconNode.isHidden = true
                    }
                    
                    var titleOffset: CGFloat = 0.0
                    if let currentSecretIconImage = currentSecretIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.secretIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.contextContainer.addSubnode(iconNode)
                            strongSelf.secretIconNode = iconNode
                        }
                        iconNode.image = currentSecretIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y + floor((titleLayout.size.height - currentSecretIconImage.size.height) / 2.0)), size: currentSecretIconImage.size))
                        titleOffset += currentSecretIconImage.size.width + 3.0
                    } else if let secretIconNode = strongSelf.secretIconNode {
                        strongSelf.secretIconNode = nil
                        secretIconNode.removeFromSupernode()
                    }
                    
                    var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleLayout.size.width + 3.0 + titleOffset
                    
                    if let currentCredibilityIconImage = currentCredibilityIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.credibilityIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.contextContainer.addSubnode(iconNode)
                            strongSelf.credibilityIconNode = iconNode
                        }
                        iconNode.image = currentCredibilityIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: contentRect.origin.y + credibilityIconOffset), size: currentCredibilityIconImage.size))
                        nextTitleIconOrigin += currentCredibilityIconImage.size.width + 5.0
                    } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                        strongSelf.credibilityIconNode = nil
                        credibilityIconNode.removeFromSupernode()
                    }
                    
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        strongSelf.mutedIconNode.isHidden = false
                        transition.updateFrame(node: strongSelf.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin - 4.0, y: contentRect.origin.y - 2.0), size: currentMutedIconImage.size))
                        nextTitleIconOrigin += currentMutedIconImage.size.width + 1.0
                    } else {
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    let contentDelta = CGPoint(x: contentRect.origin.x - (strongSelf.titleNode.frame.minX - titleOffset), y: contentRect.origin.y - (strongSelf.titleNode.frame.minY - UIScreenPixel))
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: contentRect.origin.y + UIScreenPixel), size: titleLayout.size)
                    let authorNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.minY + titleLayout.size.height), size: authorLayout.size)
                    strongSelf.authorNode.frame = authorNodeFrame
                    let textNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.minY + titleLayout.size.height - 1.0 + UIScreenPixel + (authorLayout.size.height.isZero ? 0.0 : (authorLayout.size.height - 3.0))), size: textLayout.size)
                    strongSelf.textNode.frame = textNodeFrame
                    let contentImageFrame = CGRect(origin: textNodeFrame.origin.offsetBy(dx: 1.0, dy: 0.0), size: contentImageSize)
                    if contentImageNodeAppeared {
                        strongSelf.contentImageNode.frame = contentImageFrame
                    } else {
                        transition.updateFrame(node: strongSelf.contentImageNode, frame: contentImageFrame)
                    }
                    
                    var animateInputActivitiesFrame = false
                    if let inputActivities = inputActivities, !inputActivities.isEmpty {
                        if strongSelf.inputActivitiesNode.supernode == nil {
                            strongSelf.contextContainer.addSubnode(strongSelf.inputActivitiesNode)
                        } else {
                            animateInputActivitiesFrame = true
                        }
                        
                        if strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 1.0
                            strongSelf.textNode.alpha = 0.0
                            strongSelf.authorNode.alpha = 0.0
                            
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                            }
                        }
                    } else {
                        if !strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 0.0
                            strongSelf.textNode.alpha = 1.0
                            strongSelf.authorNode.alpha = 1.0
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { value in
                                    if let strongSelf = self, value {
                                        strongSelf.inputActivitiesNode.removeFromSupernode()
                                    }
                                })
                                strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            } else {
                                strongSelf.inputActivitiesNode.removeFromSupernode()
                            }
                        }
                    }
                    if let inputActivitiesSize = inputActivitiesSize {
                        let inputActivitiesFrame = CGRect(origin: CGPoint(x: authorNodeFrame.minX + 1.0, y: authorNodeFrame.minY + UIScreenPixel), size: inputActivitiesSize)
                        if animateInputActivitiesFrame {
                            transition.updateFrame(node: strongSelf.inputActivitiesNode, frame: inputActivitiesFrame)
                        } else {
                            strongSelf.inputActivitiesNode.frame = inputActivitiesFrame
                        }
                    }
                    inputActivitiesApply?()
                    
                    if !contentDelta.x.isZero || !contentDelta.y.isZero {
                        let titlePosition = strongSelf.titleNode.position
                        transition.animatePosition(node: strongSelf.titleNode, from: CGPoint(x: titlePosition.x - contentDelta.x, y: titlePosition.y - contentDelta.y))
                        
                        transition.animatePositionAdditive(node: strongSelf.textNode, offset: CGPoint(x: -contentDelta.x, y: -contentDelta.y))
                        
                        let authorPosition = strongSelf.authorNode.position
                        transition.animatePosition(node: strongSelf.authorNode, from: CGPoint(x: authorPosition.x - contentDelta.x, y: authorPosition.y - contentDelta.y))
                    }
                    
                    if crossfadeContent {
                        strongSelf.authorNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.titleNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.textNode.recursivelyEnsureDisplaySynchronously(true)
                    }
                    
                    let separatorInset: CGFloat
                    if case let .groupReference(groupReference) = item.content, groupReference.hiddenByDefault {
                        separatorInset = 0.0
                    } else if (!nextIsPinned && item.index.pinningIndex != nil) || last {
                            separatorInset = 0.0
                    } else {
                        separatorInset = editingOffset + leftInset + rawContentRect.origin.x
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: layoutOffset + itemHeight - separatorHeight), size: CGSize(width: params.width - separatorInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.contentSize.width, height: itemHeight)))
                    let backgroundColor: UIColor
                    if item.selected {
                        backgroundColor = theme.itemSelectedBackgroundColor
                    } else if item.index.pinningIndex != nil {
                        if case let .groupReference(groupReference) = item.content, groupReference.hiddenByDefault {
                            backgroundColor = theme.itemBackgroundColor
                        } else {
                            backgroundColor = theme.pinnedItemBackgroundColor
                        }
                    } else {
                        backgroundColor = theme.itemBackgroundColor
                    }
                    if animated {
                        transition.updateBackgroundColor(node: strongSelf.backgroundNode, color: backgroundColor)
                    } else {
                        strongSelf.backgroundNode.backgroundColor = backgroundColor
                    }
                    let topNegativeInset: CGFloat = 0.0
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layoutOffset - separatorHeight - topNegativeInset), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height + separatorHeight + topNegativeInset))
                    
                    if let peerPresence = peerPresence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: TelegramUserPresence(status: peerPresence.status, lastActivity: 0))
                    }
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.editing {
                        strongSelf.setRevealOptions((left: [], right: []))
                    } else {
                        strongSelf.setRevealOptions((left: peerLeftRevealOptions, right: peerRevealOptions))
                    }
                    strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: true)
                    
                    strongSelf.view.accessibilityLabel = strongSelf.accessibilityLabel
                    strongSelf.view.accessibilityValue = strongSelf.accessibilityValue
                    
                    if !customActions.isEmpty {
                        strongSelf.view.accessibilityCustomActions = customActions.map({ action -> UIAccessibilityCustomAction in
                            return ChatListItemAccessibilityCustomAction(name: action.name, target: strongSelf, selector: #selector(strongSelf.performLocalAccessibilityCustomAction(_:)), key: action.key)
                        })
                    } else {
                        strongSelf.view.accessibilityCustomActions = nil
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.clipsToBounds = true
        if self.skipFadeout {
            self.skipFadeout = false
        } else {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.layoutParams?.0 {
            return item.header
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let item = self.item, let params = self.layoutParams?.5, let countersSize = self.layoutParams?.6 {
            let editingOffset: CGFloat
            if let selectableControlNode = self.selectableControlNode {
                editingOffset = selectableControlNode.bounds.size.width
                var selectableControlFrame = selectableControlNode.frame
                selectableControlFrame.origin.x = params.leftInset + offset
                transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            let layoutOffset: CGFloat = 0.0
            
            if let reorderControlNode = self.reorderControlNode {
                var reorderControlFrame = reorderControlNode.frame
                reorderControlFrame.origin.x = params.width - params.rightInset - reorderControlFrame.size.width + offset
                transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
            }
            
            let avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            let avatarLeftInset = 18.0 + avatarDiameter
            
            let leftInset: CGFloat = params.leftInset + avatarLeftInset
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: layoutOffset + 8.0), size: CGSize(width: params.width - leftInset - params.rightInset - 10.0 - editingOffset, height: self.bounds.size.height - 12.0 - 9.0))
            
            let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + offset, dy: 0.0)
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = leftInset - avatarLeftInset + editingOffset + 10.0 + offset
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var onlineFrame = self.onlineNode.frame
            onlineFrame.origin.x = avatarFrame.maxX - onlineFrame.width - 2.0
            transition.updateFrame(node: self.onlineNode, frame: onlineFrame)
            
            var titleOffset: CGFloat = 0.0
            if let secretIconNode = self.secretIconNode, let image = secretIconNode.image {
                transition.updateFrame(node: secretIconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: secretIconNode.frame.minY), size: image.size))
                titleOffset += image.size.width + 3.0
            }
            
            let titleFrame = self.titleNode.frame
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: titleFrame.origin.y), size: titleFrame.size))
            
            let authorFrame = self.authorNode.frame
            transition.updateFrame(node: self.authorNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: authorFrame.origin.y), size: authorFrame.size))
            
            transition.updateFrame(node: self.inputActivitiesNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: self.inputActivitiesNode.frame.minY), size: self.inputActivitiesNode.bounds.size))
            
            var textFrame = self.textNode.frame
            textFrame.origin.x = contentRect.origin.x
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            var contentImageFrame = self.contentImageNode.frame
            contentImageFrame.origin = textFrame.origin.offsetBy(dx: 1.0, dy: 0.0)
            transition.updateFrame(node: self.contentImageNode, frame: contentImageFrame)
            
            let dateFrame = self.dateNode.frame
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width, y: dateFrame.minY), size: dateFrame.size))
            
            let statusFrame = self.statusNode.frame
            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width - statusFrame.size.width, y: statusFrame.minY), size: statusFrame.size))
            
            var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleFrame.size.width + 3.0 + titleOffset
            
            if let credibilityIconNode = self.credibilityIconNode {
                transition.updateFrame(node: credibilityIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: credibilityIconNode.frame.origin.y), size: credibilityIconNode.bounds.size))
                nextTitleIconOrigin += credibilityIconNode.bounds.size.width + 5.0
            }
            
            let mutedIconFrame = self.mutedIconNode.frame
            transition.updateFrame(node: self.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin - 4.0, y: contentRect.origin.y - 2.0), size: mutedIconFrame.size))
            nextTitleIconOrigin += mutedIconFrame.size.width + 3.0
            
            let badgeFrame = self.badgeNode.frame
            let updatedBadgeFrame = CGRect(origin: CGPoint(x: contentRect.maxX - badgeFrame.size.width, y: contentRect.maxY - badgeFrame.size.height - 2.0), size: badgeFrame.size)
            transition.updateFrame(node: self.badgeNode, frame: updatedBadgeFrame)
            
            var mentionBadgeFrame = self.mentionBadgeNode.frame
            if updatedBadgeFrame.width.isZero || self.badgeNode.isHidden {
                mentionBadgeFrame.origin.x = updatedBadgeFrame.minX - mentionBadgeFrame.width
            } else {
                mentionBadgeFrame.origin.x = updatedBadgeFrame.minX - 6.0 - mentionBadgeFrame.width
            }
            transition.updateFrame(node: self.mentionBadgeNode, frame: mentionBadgeFrame)
            
            let pinnedIconSize = self.pinnedIconNode.bounds.size
            if pinnedIconSize != CGSize.zero {
                let badgeOffset: CGFloat
                if countersSize.isZero {
                    badgeOffset = contentRect.maxX - pinnedIconSize.width
                } else {
                    badgeOffset = contentRect.maxX - updatedBadgeFrame.size.width - 6.0 - pinnedIconSize.width
                }
                
                let badgeBackgroundWidth = pinnedIconSize.width
                let badgeBackgroundFrame = CGRect(x: badgeOffset, y: self.pinnedIconNode.frame.origin.y, width: badgeBackgroundWidth, height: pinnedIconSize.height)
                transition.updateFrame(node: self.pinnedIconNode, frame: badgeBackgroundFrame)
            }
        }
    }
    
    override func touchesToOtherItemsPrevented() {
        super.touchesToOtherItemsPrevented()
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(nil, nil)
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(item.index.messageIndex.id.peerId, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(nil, item.index.messageIndex.id.peerId)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        var close = true
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.pin.rawValue:
                    switch item.content {
                        case .peer:
                            let itemId: PinnedItemId = .peer(item.index.messageIndex.id.peerId)
                            item.interaction.setItemPinned(itemId, true)
                        case .groupReference:
                            break
                    }
                case RevealOptionKey.unpin.rawValue:
                    switch item.content {
                        case .peer:
                            let itemId: PinnedItemId = .peer(item.index.messageIndex.id.peerId)
                            item.interaction.setItemPinned(itemId, false)
                        case .groupReference:
                            break
                    }
                case RevealOptionKey.mute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, true)
                    close = false
                case RevealOptionKey.unmute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, false)
                    close = false
                case RevealOptionKey.delete.rawValue:
                    item.interaction.deletePeer(item.index.messageIndex.id.peerId)
                case RevealOptionKey.archive.rawValue:
                    item.interaction.updatePeerGrouping(item.index.messageIndex.id.peerId, true)
                    close = false
                    self.skipFadeout = true
                    self.animateRevealOptionsFill {
                        self.revealOptionsInteractivelyClosed()
                    }
                case RevealOptionKey.unarchive.rawValue:
                    item.interaction.updatePeerGrouping(item.index.messageIndex.id.peerId, false)
                    close = false
                    self.skipFadeout = true
                    self.animateRevealOptionsFill {
                        self.revealOptionsInteractivelyClosed()
                    }
                case RevealOptionKey.toggleMarkedUnread.rawValue:
                    item.interaction.togglePeerMarkedUnread(item.index.messageIndex.id.peerId, animated)
                    close = false
                case RevealOptionKey.hide.rawValue:
                    item.interaction.toggleArchivedFolderHiddenByDefault()
                    close = false
                    self.skipFadeout = true
                     self.animateRevealOptionsFill {
                        self.revealOptionsInteractivelyClosed()
                    }
                case RevealOptionKey.unhide.rawValue:
                    item.interaction.toggleArchivedFolderHiddenByDefault()
                    close = false
                case RevealOptionKey.hidePsa.rawValue:
                    if let item = self.item, case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _) = item.content {
                        item.interaction.hidePsa(peer.peerId)
                    }
                    close = false
                    self.skipFadeout = true
                    self.animateRevealOptionsFill {
                        self.revealOptionsInteractivelyClosed()
                    }
                default:
                    break
            }
        }
        if close {
            self.setRevealOptionsOpened(false, animated: true)
            self.revealOptionsInteractivelyClosed()
        }
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point) {
            return true
        }
        return false
    }
    
    func flashHighlight() {
        if self.highlightedBackgroundNode.supernode == nil {
            self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            self.highlightedBackgroundNode.alpha = 0.0
        }
        self.highlightedBackgroundNode.layer.removeAllAnimations()
        self.highlightedBackgroundNode.layer.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, delay: 0.7, completion: { [weak self] _ in
            self?.updateIsHighlighted(transition: .immediate)
        })
    }
    
    func playArchiveAnimation() {
        guard let item = self.item, case .groupReference = item.content else {
            return
        }
        self.avatarNode.playArchiveAnimation()
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let item = self.item {
            if case .groupReference = item.content {
                self.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, currentValue - (self.currentItemHeight ?? 0.0), 0.0)
            } else {
                var separatorFrame = self.separatorNode.frame
                separatorFrame.origin.y = currentValue - UIScreenPixel
                self.separatorNode.frame = separatorFrame
            }
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let action = action as? ChatListItemAccessibilityCustomAction {
            self.revealOptionSelected(ItemListRevealOption(key: action.key, title: "", icon: .none, color: .black, textColor: .white), animated: false)
        }
    }
    
    override func snapshotForReordering() -> UIView? {
        self.backgroundNode.alpha = 0.9
        let result = self.view.snapshotContentTree()
        self.backgroundNode.alpha = 1.0
        return result
    }
}

private func foldLineBreaks(_ text: String) -> String {
    let lines = text.split { $0.isNewline }
    var result = ""
    for line in lines {
        if line.isEmpty {
            continue
        }
        if result.isEmpty {
            result += line
        } else {
            result += " " + line
        }
    }
    return result
}
