import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

enum ChatListItemContent {
    case peer(message: Message?, peer: RenderedPeer, combinedReadState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, summaryInfo: ChatListMessageTagSummaryInfo, embeddedState: PeerChatListEmbeddedInterfaceState?, inputActivities: [(Peer, PeerInputActivity)]?, isAd: Bool, ignoreUnreadBadge: Bool)
    case groupReference(groupId: PeerGroupId, message: Message?, topPeers: [Peer], counters: GroupReferenceUnreadCounters)
    
    var chatLocation: ChatLocation {
        switch self {
            case let .peer(_, peer, _, _, _, _, _, _, _):
                return .peer(peer.peerId)
            case let .groupReference(groupId, _, _, _):
                return .group(groupId)
        }
    }
}

class ChatListItem: ListViewItem {
    let presentationData: ChatListPresentationData
    let account: Account
    let peerGroupId: PeerGroupId?
    let index: ChatListIndex
    let content: ChatListItemContent
    let editing: Bool
    let hasActiveRevealControls: Bool
    let enableContextActions: Bool
    let interaction: ChatListNodeInteraction
    
    let selectable: Bool = true
    
    let header: ListViewItemHeader?
    
    init(presentationData: ChatListPresentationData, account: Account, peerGroupId: PeerGroupId?, index: ChatListIndex, content: ChatListItemContent, editing: Bool, hasActiveRevealControls: Bool, header: ListViewItemHeader?, enableContextActions: Bool, interaction: ChatListNodeInteraction) {
        self.presentationData = presentationData
        self.peerGroupId = peerGroupId
        self.account = account
        self.index = index
        self.content = content
        self.editing = editing
        self.hasActiveRevealControls = hasActiveRevealControls
        self.header = header
        self.enableContextActions = enableContextActions
        self.interaction = interaction
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ChatListItemNode()
            node.setupItem(item: self)
            let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            node.insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, first, last, firstWithHeader, nextIsPinned)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, {
                        apply(false)
                        node.updateIsHighlighted(transition: .immediate)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListItemNode)
            if let nodeValue = node() as? ChatListItemNode {
                nodeValue.setupItem(item: self)
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, nextIsPinned)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    func selected(listView: ListView) {
        switch self.content {
            case let .peer(message, peer, _, _, _, _, _, isAd, _):
                if let message = message {
                    self.interaction.messageSelected(message, isAd)
                } else if let peer = peer.peers[peer.peerId] {
                    self.interaction.peerSelected(peer)
                }
            case let .groupReference(groupId, _, _, _):
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

private let titleFont = Font.medium(16.0)
private let textFont = Font.regular(15.0)
private let dateFont = Font.regular(14.0)
private let badgeFont = Font.regular(14.0)

private let pinIcon = ItemListRevealOptionIcon.animation(animation: "anim_pin", keysToColor: nil)
private let unpinIcon = ItemListRevealOptionIcon.animation(animation: "anim_unpin", keysToColor: ["un Outlines.Group 1.Stroke 1"])
private let muteIcon = ItemListRevealOptionIcon.animation(animation: "anim_mute", keysToColor: ["un Outlines.Group 1.Stroke 1"])
private let unmuteIcon = ItemListRevealOptionIcon.animation(animation: "anim_unmute", keysToColor: nil)
private let deleteIcon = ItemListRevealOptionIcon.animation(animation: "anim_delete", keysToColor: nil)
private let groupIcon = ItemListRevealOptionIcon.animation(animation: "anim_group", keysToColor: nil)
private let ungroupIcon = ItemListRevealOptionIcon.animation(animation: "anim_ungroup", keysToColor: ["un Outlines.Group 1.Stroke 1"])
private let readIcon = ItemListRevealOptionIcon.animation(animation: "anim_read", keysToColor: nil)
private let unreadIcon = ItemListRevealOptionIcon.animation(animation: "anim_unread", keysToColor: ["Oval.Oval.Stroke 1"])

private enum RevealOptionKey: Int32 {
    case pin
    case unpin
    case mute
    case unmute
    case delete
    case group
    case ungroup
    case toggleMarkedUnread
}

private let itemHeight: CGFloat = 76.0

private func revealOptions(strings: PresentationStrings, theme: PresentationTheme, isPinned: Bool?, isMuted: Bool?, hasPeerGroupId: Bool?, canDelete: Bool, isEditing: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if let isPinned = isPinned {
            if isPinned {
                options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.neutral1.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.neutral1.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
            }
        }
        if let isMuted = isMuted {
            if isMuted {
                options.append(ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: strings.Conversation_Unmute, icon: unmuteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: strings.Conversation_Mute, icon: muteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            }
        }
        if let hasPeerGroupId = hasPeerGroupId {
            if hasPeerGroupId {
                options.append(ItemListRevealOption(key: RevealOptionKey.ungroup.rawValue, title: "Ungroup", icon: ungroupIcon, color: theme.list.itemAccentColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.group.rawValue, title: "Group", icon: groupIcon, color: theme.list.itemAccentColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            }
        }
    }
    if canDelete {
        options.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: strings.Common_Delete, icon: deleteIcon, color: theme.list.itemDisclosureActions.destructive.fillColor, textColor: theme.list.itemDisclosureActions.destructive.foregroundColor))
    }
    return options
}

private func leftRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isUnread: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if isUnread {
        options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Read, icon: readIcon, color: theme.list.itemDisclosureActions.neutral1.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
    } else {
        options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Unread, icon: unreadIcon, color: theme.list.itemDisclosureActions.accent.fillColor, textColor: theme.list.itemDisclosureActions.accent.foregroundColor))
    }
    return options
}

private let separatorHeight = 1.0 / UIScreen.main.scale

private let avatarFont: UIFont = UIFont(name: ".SFCompactRounded-Semibold", size: 26.0)!

class ChatListItemNode: ItemListRevealOptionsItemNode {
    var item: ChatListItem?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let avatarNode: AvatarNode
    var multipleAvatarsNode: MultipleAvatarsNode?
    let titleNode: TextNode
    let authorNode: TextNode
    let textNode: TextNode
    let inputActivitiesNode: ChatListInputActivitiesNode
    let dateNode: TextNode
    let statusNode: ASImageNode
    let separatorNode: ASDisplayNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: TextNode
    let mentionBadgeNode: ASImageNode
    var secretIconNode: ASImageNode?
    var verificationIconNode: ASImageNode?
    let mutedIconNode: ASImageNode
    
    var editableControlNode: ItemListEditableControlNode?
    var reorderControlNode: ItemListEditableReorderControlNode?
    
    var layoutParams: (ChatListItem, first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool, ListViewItemLayoutParams)?
    
    private var isHighlighted: Bool = false
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil {
            return false
        } else {
            return super.canBeSelected
        }
    }
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = true
        
        self.authorNode = TextNode()
        self.authorNode.isUserInteractionEnabled = false
        self.authorNode.displaysAsynchronously = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        self.inputActivitiesNode = ChatListInputActivitiesNode()
        self.inputActivitiesNode.isUserInteractionEnabled = false
        self.inputActivitiesNode.alpha = 0.0
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = true
        
        self.statusNode = ASImageNode()
        self.statusNode.displaysAsynchronously = false
        self.statusNode.displayWithoutProcessing = true
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        
        self.mentionBadgeNode = ASImageNode()
        self.mentionBadgeNode.isLayerBacked = true
        self.mentionBadgeNode.displaysAsynchronously = false
        self.mentionBadgeNode.displayWithoutProcessing = true
        
        self.badgeTextNode = TextNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = true
        
        self.mutedIconNode = ASImageNode()
        self.mutedIconNode.isLayerBacked = true
        self.mutedIconNode.displaysAsynchronously = false
        self.mutedIconNode.displayWithoutProcessing = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.authorNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.dateNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.mentionBadgeNode)
        self.addSubnode(self.badgeTextNode)
        self.addSubnode(self.mutedIconNode)
    }
    
    func setupItem(item: ChatListItem) {
        self.item = item
        
        var peer: Peer?
        switch item.content {
            case let .peer(message, peerValue, _, _, _, _, _, _, _):
                if let message = message {
                    peer = messageMainPeer(message)
                } else {
                    peer = peerValue.chatMainPeer
                }
            case .groupReference:
                break
        }
        
        if let peer = peer {
            var overrideImage: AvatarNodeImageOverride?
            if peer.id == item.account.peerId {
                overrideImage = .savedMessagesIcon
            }
            self.avatarNode.setPeer(account: item.account, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor)
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: item as! ChatListItem, previousItem: previousItem, nextItem: nextItem)
        let (nodeLayout, apply) = layout(item as! ChatListItem, params, first, last, firstWithHeader, nextIsPinned)
        apply(false)
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
    
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        var reallyHighlighted = self.isHighlighted
        if let item = self.item {
            let itemChatLocation = item.content.chatLocation
            if itemChatLocation == item.interaction.highlightedChatLocation?.location {
                reallyHighlighted = true
            }
        }
        
        if reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 1.0)
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 0.0, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    }
                })
            }
        }
    }
    
    func asyncLayout() -> (_ item: ChatListItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ nextIsPinned: Bool) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        let textLayout = TextNode.asyncLayout(self.textNode)
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let authorLayout = TextNode.asyncLayout(self.authorNode)
        let inputActivitiesLayout = self.inputActivitiesNode.asyncLayout()
        let badgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.layoutParams?.0
        
        let multipleAvatarsLayout = MultipleAvatarsNode.asyncLayout(self.multipleAvatarsNode)
        
        return { item, params, first, last, firstWithHeader, nextIsPinned in
            let account = item.account
            let message: Message?
            let itemPeer: RenderedPeer
            let combinedReadState: CombinedPeerReadState?
            let unreadCount: (count: Int32, unread: Bool, muted: Bool)
            let notificationSettings: PeerNotificationSettings?
            let embeddedState: PeerChatListEmbeddedInterfaceState?
            let summaryInfo: ChatListMessageTagSummaryInfo
            let inputActivities: [(Peer, PeerInputActivity)]?
            let isPeerGroup: Bool
            let isAd: Bool
            
            var multipleAvatarsApply: ((Bool) -> MultipleAvatarsNode)?
            
            switch item.content {
                case let .peer(messageValue, peerValue, combinedReadStateValue, notificationSettingsValue, summaryInfoValue, embeddedStateValue, inputActivitiesValue, isAdValue, ignoreUnreadBadge):
                    message = messageValue
                    itemPeer = peerValue
                    combinedReadState = combinedReadStateValue
                    if let combinedReadState = combinedReadState, !isAdValue && !ignoreUnreadBadge {
                        unreadCount = (combinedReadState.count, combinedReadState.isUnread, notificationSettingsValue?.isRemovedFromTotalUnreadCount ?? false)
                    } else {
                        unreadCount = (0, false, false)
                    }
                    if isAdValue {
                        notificationSettings = nil
                    } else {
                        notificationSettings = notificationSettingsValue
                    }
                    embeddedState = embeddedStateValue
                    summaryInfo = summaryInfoValue
                    inputActivities = inputActivitiesValue
                    isPeerGroup = false
                    isAd = isAdValue
                case let .groupReference(_, messageValue, topPeersValue, counters):
                    if let messageValue = messageValue {
                        itemPeer = RenderedPeer(message: messageValue)
                    } else {
                        itemPeer = RenderedPeer(peerId: item.index.messageIndex.id.peerId, peers: SimpleDictionary())
                    }
                    message = messageValue
                    combinedReadState = nil
                    notificationSettings = nil
                    embeddedState = nil
                    summaryInfo = ChatListMessageTagSummaryInfo()
                    inputActivities = nil
                    isPeerGroup = true
                    multipleAvatarsApply = multipleAvatarsLayout(item.account, topPeersValue, CGSize(width: 60.0, height: 60.0))
                    if counters.unreadCount > 0 {
                        let count = counters.unreadCount + counters.unreadMutedCount
                        unreadCount = (count, count > 0, false)
                    } else if counters.unreadMutedCount > 0 {
                        unreadCount = (counters.unreadMutedCount, counters.unreadMutedCount > 0, true)
                    } else{
                        unreadCount = (0, false, false)
                    }
                    isAd = false
            }
            
            let theme = item.presentationData.theme.chatList
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var authorAttributedString: NSAttributedString?
            var textAttributedString: NSAttributedString?
            var dateAttributedString: NSAttributedString?
            var titleAttributedString: NSAttributedString?
            var badgeAttributedString: NSAttributedString?
            
            var statusImage: UIImage?
            var currentBadgeBackgroundImage: UIImage?
            var currentMentionBadgeImage: UIImage?
            var currentMutedIconImage: UIImage?
            var currentVerificationIconImage: UIImage?
            var currentSecretIconImage: UIImage?
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            var reorderControlSizeAndApply: (CGSize, () -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            if item.editing {
                let sizeAndApply = editableControlLayout(itemHeight, item.presentationData.theme, isPeerGroup)
                if !isAd {
                    editableControlSizeAndApply = sizeAndApply
                }
                editingOffset = sizeAndApply.0.width
                
                if item.index.pinningIndex != nil && !isAd {
                    let sizeAndApply = reorderControlLayout(itemHeight, item.presentationData.theme)
                    reorderControlSizeAndApply = sizeAndApply
                    reorderInset = sizeAndApply.0.width
                }
            } else {
                editingOffset = 0.0
            }
            
            let leftInset: CGFloat = params.leftInset + 78.0
            
            let (peer, initialHideAuthor, messageText) = chatListItemStrings(strings: item.presentationData.strings, message: message, chatPeer: itemPeer, accountPeerId: item.account.peerId)
            var hideAuthor = initialHideAuthor
            if isPeerGroup {
                hideAuthor = false
            }
            
            let attributedText: NSAttributedString
            var hasDraft = false
            if let embeddedState = embeddedState as? ChatEmbeddedInterfaceState {
                hasDraft = true
                authorAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Draft, font: textFont, textColor: theme.messageDraftTextColor)
                
                attributedText = NSAttributedString(string: embeddedState.text.string, font: textFont, textColor: theme.messageTextColor)
            } else if let message = message {
                attributedText = NSAttributedString(string: messageText as String, font: textFont, textColor: theme.messageTextColor)
                
                var peerText: String?
                if let author = message.author as? TelegramUser, let peer = peer, !(peer is TelegramUser) {
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                    } else {
                        peerText = author.id == account.peerId ? item.presentationData.strings.DialogList_You : author.displayTitle(strings: item.presentationData.strings)
                    }
                } else if case .groupReference = item.content {
                    if let messagePeer = itemPeer.chatMainPeer {
                        peerText = messagePeer.displayTitle(strings: item.presentationData.strings)
                    }
                }
                
                if let peerText = peerText {
                    authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                }
            } else {
                attributedText = NSAttributedString(string: messageText as String, font: textFont, textColor: theme.messageTextColor)
            }
            
            switch item.content {
                case .peer:
                    if peer?.id == item.account.peerId {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleFont, textColor: theme.titleColor)
                    } else if let displayTitle = peer?.displayTitle(strings: item.presentationData.strings) {
                        titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: item.index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat ? theme.secretTitleColor : theme.titleColor)
                    }
                case .groupReference:
                    titleAttributedString = NSAttributedString(string: "Feed", font: titleFont, textColor: theme.titleColor)
            }
            
            textAttributedString = attributedText
            
            var t = Int(item.index.messageIndex.timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.index.messageIndex.timestamp, relativeTo: timestamp, dateTimeFormat: item.presentationData.dateTimeFormat)
            
            if isAd {
                dateAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_AdLabel, font: dateFont, textColor: theme.dateTextColor)
            } else {
                dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: theme.dateTextColor)
            }
            
            if let message = message, message.author?.id == account.peerId && !hasDraft {
                if message.flags.isSending && !message.isSentOrAcknowledged {
                    statusImage = PresentationResourcesChatList.pendingImage(item.presentationData.theme)
                } else {
                    if let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIndexRead(MessageIndex(message)) {
                        statusImage = PresentationResourcesChatList.doubleCheckImage(item.presentationData.theme)
                    } else {
                        statusImage = PresentationResourcesChatList.singleCheckImage(item.presentationData.theme)
                    }
                }
            }
            
            if unreadCount.unread {
                if let message = message, message.tags.contains(.unseenPersonalMessage), unreadCount.count == 1 {
                } else {
                    let badgeTextColor: UIColor
                    if unreadCount.muted {
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme)
                        badgeTextColor = theme.unreadBadgeInactiveTextColor
                    } else {
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme)
                        badgeTextColor = theme.unreadBadgeActiveTextColor
                    }
                    let unreadCountText: String
                    if unreadCount.count > 1000 {
                        unreadCountText = "\(unreadCount.count / 1000)K"
                    } else {
                        unreadCountText = "\(unreadCount.count)"
                    }
                    
                    badgeAttributedString = NSAttributedString(string: unreadCount.count > 0 ? unreadCountText : " ", font: badgeFont, textColor: badgeTextColor)
                }
            }
            
            let tagSummaryCount = summaryInfo.tagSummaryCount ?? 0
            let actionsSummaryCount = summaryInfo.actionsSummaryCount ?? 0
            let totalMentionCount = tagSummaryCount - actionsSummaryCount
            if totalMentionCount > 0 {
                currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundMention(item.presentationData.theme)
            } else if item.index.pinningIndex != nil && !isAd && currentBadgeBackgroundImage == nil {
                currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundPinned(item.presentationData.theme)
            }
            
            if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                    currentMutedIconImage = PresentationResourcesChatList.mutedIcon(item.presentationData.theme)
                }
            }
            
            let statusWidth = statusImage?.size.width ?? 0.0
            
            var titleIconsWidth: CGFloat = 0.0
            if let currentMutedIconImage = currentMutedIconImage {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                }
                titleIconsWidth += currentMutedIconImage.size.width
            }
            
            var isVerified = false
            let isSecret = item.index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat
            
            if case .peer = item.content {
                if let peer = itemPeer.chatMainPeer {
                    if let peer = peer as? TelegramUser {
                        isVerified = peer.flags.contains(.isVerified)
                    } else if let peer = peer as? TelegramChannel {
                        isVerified = peer.flags.contains(.isVerified)
                    }
                }
            }
            
            if isSecret {
                currentSecretIconImage = PresentationResourcesChatList.secretIcon(item.presentationData.theme)
            }
            
            if isVerified {
                currentVerificationIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
            }
            if let currentSecretIconImage = currentSecretIconImage {
                titleIconsWidth += currentSecretIconImage.size.width + 2.0
            }
            if let currentVerificationIconImage = currentVerificationIconImage {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                } else {
                    titleIconsWidth += 2.0
                }
                titleIconsWidth += currentVerificationIconImage.size.width
            }
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: 8.0), size: CGSize(width: params.width - leftInset - params.rightInset - 10.0 - 1.0 - editingOffset, height: itemHeight - 12.0 - 9.0))
            
            let (dateLayout, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentRect.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (badgeLayout, badgeApply) = badgeTextLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var badgeSize: CGFloat = 0.0
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                badgeSize += max(currentBadgeBackgroundImage.size.width, badgeLayout.size.width + 10.0) + 5.0
            }
            if let currentMentionBadgeImage = currentMentionBadgeImage {
                if !badgeSize.isZero {
                    badgeSize += currentMentionBadgeImage.size.width + 4.0
                } else {
                    badgeSize += currentMentionBadgeImage.size.width + 5.0
                }
            }
            
            badgeSize = max(badgeSize, reorderInset)
            
            let (authorLayout, authorApply) = authorLayout(TextNodeLayoutArguments(attributedString: hideAuthor ? nil : authorAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentRect.width - badgeSize, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: textAttributedString, backgroundColor: nil, maximumNumberOfLines: authorAttributedString == nil ? 2 : 1, truncationType: .end, constrainedSize: CGSize(width: rawContentRect.width - badgeSize, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            let titleRect = CGRect(origin: rawContentRect.origin, size: CGSize(width: rawContentRect.width - dateLayout.size.width - 10.0 - statusWidth - titleIconsWidth, height: rawContentRect.height))
            let (titleLayout, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRect.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
            var inputActivitiesSize: CGSize?
            var inputActivitiesApply: (() -> Void)?
            if let inputActivities = inputActivities, !inputActivities.isEmpty {
                let (size, apply) = inputActivitiesLayout(CGSize(width: rawContentRect.width - badgeSize, height: 40.0), item.presentationData.strings, item.presentationData.theme.chatList.messageTextColor, item.index.messageIndex.id.peerId, inputActivities)
                inputActivitiesSize = size
                inputActivitiesApply = apply
            }
            
            let insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: itemHeight), insets: insets)
            
            let peerRevealOptions: [ItemListRevealOption]
            let peerLeftRevealOptions: [ItemListRevealOption]
            switch item.content {
                case .peer:
                    var hasPeerGroupId: Bool?
                    if GlobalExperimentalSettings.enableFeed {
                        if let chatMainPeer = itemPeer.chatMainPeer as? TelegramChannel, case .broadcast = chatMainPeer.info {
                            hasPeerGroupId = item.peerGroupId != nil
                        }
                    }
                    
                    var isPinned: Bool?
                    if item.peerGroupId == nil {
                        isPinned = item.index.pinningIndex != nil
                    }
                    
                    if item.enableContextActions && !isAd {
                        peerRevealOptions = revealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isPinned: isPinned, isMuted: item.account.peerId != item.index.messageIndex.id.peerId ? (currentMutedIconImage != nil) : nil, hasPeerGroupId: hasPeerGroupId, canDelete: true, isEditing: item.editing)
                        if itemPeer.peerId != item.account.peerId {
                            peerLeftRevealOptions = leftRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isUnread: unreadCount.unread)
                        } else {
                            peerLeftRevealOptions = []
                        }
                    } else {
                        peerRevealOptions = []
                        peerLeftRevealOptions = []
                    }
                case .groupReference:
                    let isPinned = item.index.pinningIndex != nil
                    
                    if item.enableContextActions {
                        peerRevealOptions = revealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isPinned: isPinned, isMuted: nil, hasPeerGroupId: nil, canDelete: false, isEditing: item.editing)
                    } else {
                        peerRevealOptions = []
                    }
                    peerLeftRevealOptions = []
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, first, last, firstWithHeader, nextIsPinned, params)
                    
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
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        if strongSelf.editableControlNode == nil {
                            crossfadeContent = true
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.addSubnode(editableControlNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: -editableControlFrame.size.width / 2.0, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        }
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        crossfadeContent = true
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1()
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.addSubnode(reorderControlNode)
                            let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderControlSizeAndApply.0.width, y: 0.0), size: reorderControlSizeAndApply.0)
                            reorderControlNode.frame = reorderControlFrame
                            reorderControlNode.alpha = 0.0
                            transition.updateAlpha(node: reorderControlNode, alpha: 1.0)
                            
                            transition.updateAlpha(node: strongSelf.dateNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.badgeTextNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.badgeBackgroundNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.statusNode, alpha: 0.0)
                        }
                    } else if let reorderControlNode = strongSelf.reorderControlNode {
                        strongSelf.reorderControlNode = nil
                        transition.updateAlpha(node: reorderControlNode, alpha: 0.0, completion: { [weak reorderControlNode] _ in
                            reorderControlNode?.removeFromSupernode()
                        })
                        transition.updateAlpha(node: strongSelf.dateNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.badgeTextNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.badgeBackgroundNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.statusNode, alpha: 1.0)
                    }
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: leftInset - 78.0 + editingOffset + 10.0 + revealOffset, y: 7.0), size: CGSize(width: 60.0, height: 60.0))
                    transition.updateFrame(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    if let multipleAvatarsApply = multipleAvatarsApply {
                        strongSelf.avatarNode.isHidden = true
                        let multipleAvatarsNode = multipleAvatarsApply(animated && strongSelf.multipleAvatarsNode != nil)
                        if strongSelf.multipleAvatarsNode != multipleAvatarsNode {
                            strongSelf.multipleAvatarsNode?.removeFromSupernode()
                            strongSelf.multipleAvatarsNode = multipleAvatarsNode
                            strongSelf.addSubnode(multipleAvatarsNode)
                            multipleAvatarsNode.frame = avatarFrame
                        } else {
                            transition.updateFrame(node: multipleAvatarsNode, frame: avatarFrame)
                        }
                    } else if let multipleAvatarsNode = strongSelf.multipleAvatarsNode {
                        multipleAvatarsNode.removeFromSupernode()
                        strongSelf.avatarNode.isHidden = false
                    }
                    
                    let _ = dateApply()
                    let _ = textApply()
                    let _ = authorApply()
                    let _ = titleApply()
                    let _ = badgeApply()
                    
                    let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + revealOffset, dy: 0.0)
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size)
                    
                    if let statusImage = statusImage {
                        strongSelf.statusNode.image = statusImage
                        strongSelf.statusNode.isHidden = false
                        let statusSize = statusImage.size
                        strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width - 2.0 - statusSize.width, y: contentRect.origin.y + 2.0 + floor((dateLayout.size.height - statusSize.height) / 2.0)), size: statusSize)
                    } else {
                        strongSelf.statusNode.image = nil
                        strongSelf.statusNode.isHidden = true
                    }
                    
                    let badgeBackgroundWidth: CGFloat
                    if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                        strongSelf.badgeBackgroundNode.image = currentBadgeBackgroundImage
                        strongSelf.badgeBackgroundNode.isHidden = false
                        
                        badgeBackgroundWidth = max(badgeLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                        let badgeBackgroundFrame = CGRect(x: contentRect.maxX - badgeBackgroundWidth, y: contentRect.maxY - currentBadgeBackgroundImage.size.height - 2.0, width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                        let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 2.0), size: badgeLayout.size)
                        
                        strongSelf.badgeTextNode.frame = badgeTextFrame
                        strongSelf.badgeBackgroundNode.frame = badgeBackgroundFrame
                    } else {
                        badgeBackgroundWidth = 0.0
                        strongSelf.badgeBackgroundNode.image = nil
                        strongSelf.badgeBackgroundNode.isHidden = true
                    }
                    
                    if let currentMentionBadgeImage = currentMentionBadgeImage {
                        strongSelf.mentionBadgeNode.image = currentMentionBadgeImage
                        strongSelf.mentionBadgeNode.isHidden = false
                        
                        let mentionBadgeSize = currentMentionBadgeImage.size
                        let mentionBadgeOffset: CGFloat
                        if badgeBackgroundWidth.isZero {
                            mentionBadgeOffset = contentRect.maxX - mentionBadgeSize.width
                        } else {
                            mentionBadgeOffset = contentRect.maxX - badgeBackgroundWidth - 6.0 - mentionBadgeSize.width
                        }
                        
                        let badgeBackgroundWidth = mentionBadgeSize.width
                        let badgeBackgroundFrame = CGRect(x: mentionBadgeOffset, y: contentRect.maxY - mentionBadgeSize.height - 2.0, width: badgeBackgroundWidth, height: mentionBadgeSize.height)
                        
                        strongSelf.mentionBadgeNode.frame = badgeBackgroundFrame
                    } else {
                        strongSelf.mentionBadgeNode.image = nil
                        strongSelf.mentionBadgeNode.isHidden = true
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
                            strongSelf.addSubnode(iconNode)
                            strongSelf.secretIconNode = iconNode
                        }
                        iconNode.image = currentSecretIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y + 4.0), size: currentSecretIconImage.size))
                        titleOffset += currentSecretIconImage.size.width + 3.0
                    } else if let secretIconNode = strongSelf.secretIconNode {
                        strongSelf.secretIconNode = nil
                        secretIconNode.removeFromSupernode()
                    }
                    
                    var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleLayout.size.width + 3.0 + titleOffset
                    
                    if let currentVerificationIconImage = currentVerificationIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.verificationIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.addSubnode(iconNode)
                            strongSelf.verificationIconNode = iconNode
                        }
                        iconNode.image = currentVerificationIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: contentRect.origin.y + 3.0), size: currentVerificationIconImage.size))
                        nextTitleIconOrigin += currentVerificationIconImage.size.width + 5.0
                    } else if let verificationIconNode = strongSelf.verificationIconNode {
                        strongSelf.verificationIconNode = nil
                        verificationIconNode.removeFromSupernode()
                    }
                    
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        strongSelf.mutedIconNode.isHidden = false
                        transition.updateFrame(node: strongSelf.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: contentRect.origin.y + 6.0), size: currentMutedIconImage.size))
                        nextTitleIconOrigin += currentMutedIconImage.size.width + 3.0
                    } else {
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    let contentDeltaX = contentRect.origin.x - (strongSelf.titleNode.frame.minX - titleOffset)
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: contentRect.origin.y + UIScreenPixel), size: titleLayout.size)
                    let authorNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.minY + titleLayout.size.height), size: authorLayout.size)
                    strongSelf.authorNode.frame = authorNodeFrame
                    let textNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.minY + titleLayout.size.height - 1.0 + UIScreenPixel + (authorLayout.size.height.isZero ? 0.0 : (authorLayout.size.height - 3.0))), size: textLayout.size)
                    strongSelf.textNode.frame = textNodeFrame
                    
                    var animateInputActivitiesFrame = false
                    if let inputActivities = inputActivities, !inputActivities.isEmpty {
                        if strongSelf.inputActivitiesNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.inputActivitiesNode)
                        } else {
                            animateInputActivitiesFrame = true
                        }
                        
                        if strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 1.0
                            strongSelf.textNode.alpha = 0.0
                            strongSelf.authorNode.alpha = 0.0
                            
                            if animated {
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
                            if animated {
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
                    
                    if !contentDeltaX.isZero {
                        let titlePosition = strongSelf.titleNode.position
                        transition.animatePosition(node: strongSelf.titleNode, from: CGPoint(x: titlePosition.x - contentDeltaX, y: titlePosition.y))
                        
                        let textPosition = strongSelf.textNode.position
                        transition.animatePosition(node: strongSelf.textNode, from: CGPoint(x: textPosition.x - contentDeltaX, y: textPosition.y))
                        
                        let authorPosition = strongSelf.authorNode.position
                        transition.animatePosition(node: strongSelf.authorNode, from: CGPoint(x: authorPosition.x - contentDeltaX, y: authorPosition.y))
                    }
                    
                    let separatorInset: CGFloat
                    if (!nextIsPinned && item.index.pinningIndex != nil) || last {
                        separatorInset = 0.0
                    } else {
                        separatorInset = editingOffset + leftInset + rawContentRect.origin.x
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: itemHeight - separatorHeight), size: CGSize(width: params.width - separatorInset, height: separatorHeight)))
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    if item.index.pinningIndex != nil {
                        strongSelf.backgroundNode.backgroundColor = theme.pinnedItemBackgroundColor
                    } else {
                        strongSelf.backgroundNode.backgroundColor = theme.itemBackgroundColor
                    }
                    let topNegativeInset: CGFloat = 0.0
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -separatorHeight - topNegativeInset), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height + separatorHeight + topNegativeInset))
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.setRevealOptions((left: peerLeftRevealOptions, right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: true)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.clipsToBounds = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
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
        
        if let _ = self.item, let params = self.layoutParams?.5 {
            let editingOffset: CGFloat
            if let editableControlNode = self.editableControlNode {
                editingOffset = editableControlNode.bounds.size.width
                var editableControlFrame = editableControlNode.frame
                editableControlFrame.origin.x = params.leftInset + offset
                transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            if let reorderControlNode = self.reorderControlNode {
                var reorderControlFrame = reorderControlNode.frame
                reorderControlFrame.origin.x = params.width - params.rightInset - reorderControlFrame.size.width + offset
                transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
            }
            
            let leftInset: CGFloat = params.leftInset + 78.0
            
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: 8.0), size: CGSize(width: params.width - leftInset - params.rightInset - 10.0 - 1.0 - editingOffset, height: itemHeight - 12.0 - 9.0))
            
            let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + offset, dy: 0.0)
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = leftInset - 78.0 + editingOffset + 10.0 + offset
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            if let multipleAvatarsNode = self.multipleAvatarsNode {
                transition.updateFrame(node: multipleAvatarsNode, frame: avatarFrame)
            }
            
            var titleOffset: CGFloat = 0.0
            if let secretIconNode = self.secretIconNode, let image = secretIconNode.image {
                transition.updateFrame(node: secretIconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: secretIconNode.frame.minY), size: image.size))
                titleOffset += image.size.width + 3.0
            }
            
            let titleFrame = self.titleNode.frame
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: titleFrame.origin.y), size: titleFrame.size))
            
            let authorFrame = self.authorNode.frame
            transition.updateFrame(node: self.authorNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: authorFrame.origin.y), size: authorFrame.size))
            
            transition.updateFrame(node: self.inputActivitiesNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: self.inputActivitiesNode.frame.minY), size: self.inputActivitiesNode.bounds.size))
            
            let textFrame = self.textNode.frame
            transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: textFrame.origin.y), size: textFrame.size))
            
            let dateFrame = self.dateNode.frame
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width, y: dateFrame.minY), size: dateFrame.size))
            
            let statusFrame = self.statusNode.frame
            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width - 2.0 - statusFrame.size.width, y: statusFrame.minY), size: statusFrame.size))
            
            var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleFrame.size.width + 3.0 + titleOffset
            
            if let verificationIconNode = self.verificationIconNode {
                transition.updateFrame(node: verificationIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: verificationIconNode.frame.origin.y), size: verificationIconNode.bounds.size))
                nextTitleIconOrigin += verificationIconNode.bounds.size.width + 5.0
            }
            
            let mutedIconFrame = self.mutedIconNode.frame
            transition.updateFrame(node: self.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: contentRect.origin.y + 6.0), size: mutedIconFrame.size))
            nextTitleIconOrigin += mutedIconFrame.size.width + 3.0
            
            let badgeBackgroundFrame = self.badgeBackgroundNode.frame
            let updatedBadgeBackgroundFrame = CGRect(origin: CGPoint(x: contentRect.maxX - badgeBackgroundFrame.size.width, y: contentRect.maxY - badgeBackgroundFrame.size.height - 2.0), size: badgeBackgroundFrame.size)
            transition.updateFrame(node: self.badgeBackgroundNode, frame: updatedBadgeBackgroundFrame)
            
            if self.mentionBadgeNode.supernode != nil {
                let mentionBadgeSize = self.mentionBadgeNode.bounds.size
                let mentionBadgeOffset: CGFloat
                if updatedBadgeBackgroundFrame.size.width.isZero || self.badgeBackgroundNode.image == nil {
                    mentionBadgeOffset = contentRect.maxX - mentionBadgeSize.width
                } else {
                    mentionBadgeOffset = contentRect.maxX - updatedBadgeBackgroundFrame.size.width - 6.0 - mentionBadgeSize.width
                }
                
                let badgeBackgroundWidth = mentionBadgeSize.width
                let badgeBackgroundFrame = CGRect(x: mentionBadgeOffset, y: self.mentionBadgeNode.frame.origin.y, width: badgeBackgroundWidth, height: mentionBadgeSize.height)
                transition.updateFrame(node: self.mentionBadgeNode, frame: badgeBackgroundFrame)
            }
            
            let badgeTextFrame = self.badgeTextNode.frame
            transition.updateFrame(node: self.badgeTextNode, frame: CGRect(origin: CGPoint(x: updatedBadgeBackgroundFrame.midX - badgeTextFrame.size.width / 2.0, y: badgeTextFrame.minY), size: badgeTextFrame.size))
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
                    let itemId: PinnedItemId
                    switch item.content {
                        case .peer:
                            itemId = .peer(item.index.messageIndex.id.peerId)
                        case let .groupReference(groupId, _, _, _):
                            itemId = .group(groupId)
                    }
                    item.interaction.setItemPinned(itemId, true)
                case RevealOptionKey.unpin.rawValue:
                    let itemId: PinnedItemId
                    switch item.content {
                        case .peer:
                            itemId = .peer(item.index.messageIndex.id.peerId)
                        case let .groupReference(groupId, _, _, _):
                            itemId = .group(groupId)
                    }
                    item.interaction.setItemPinned(itemId, false)
                case RevealOptionKey.mute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, true)
                    close = false
                case RevealOptionKey.unmute.rawValue:
                    item.interaction.setPeerMuted(item.index.messageIndex.id.peerId, false)
                    close = false
                case RevealOptionKey.delete.rawValue:
                    item.interaction.deletePeer(item.index.messageIndex.id.peerId)
                case RevealOptionKey.group.rawValue:
                    item.interaction.updatePeerGrouping(item.index.messageIndex.id.peerId, true)
                case RevealOptionKey.ungroup.rawValue:
                    item.interaction.updatePeerGrouping(item.index.messageIndex.id.peerId, false)
                case RevealOptionKey.toggleMarkedUnread.rawValue:
                    item.interaction.togglePeerMarkedUnread(item.index.messageIndex.id.peerId, animated)
                    close = false
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
        self.highlightedBackgroundNode.layer.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: kCAMediaTimingFunctionEaseOut, duration: 0.3, delay: 0.7, completion: { [weak self] _ in
            self?.updateIsHighlighted(transition: .immediate)
        })
    }
}
