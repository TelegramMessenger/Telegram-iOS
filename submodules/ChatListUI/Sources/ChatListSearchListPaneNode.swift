import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import MergeLists
import ItemListUI
import ContextUI
import ContactListUI
import ContactsPeerItem
import PhotoResources
import TelegramUIPreferences
import UniversalMediaPlayer
import TelegramBaseController
import OverlayStatusController
import ListMessageItem
import AnimatedStickerNode
import ChatListSearchItemHeader
import PhoneNumberFormat
import InstantPageUI
import GalleryData
import AppBundle

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
}

private enum ChatListRecentEntry: Comparable, Identifiable {
    case topPeers([Peer], PresentationTheme, PresentationStrings)
    case peer(index: Int, peer: RecentlySearchedPeer, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder)
    
    var stableId: ChatListRecentEntryStableId {
        switch self {
            case .topPeers:
                return .topPeers
            case let .peer(_, peer, _, _, _, _, _):
                return .peerId(peer.peer.peerId)
        }
    }
    
    static func ==(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case let .topPeers(lhsPeers, lhsTheme, lhsStrings):
                if case let .topPeers(rhsPeers, rhsTheme, rhsStrings) = rhs {
                    if lhsPeers.count != rhsPeers.count {
                        return false
                    }
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder):
                if case let .peer(rhsIndex, rhsPeer, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings && lhsTimeFormat == rhsTimeFormat && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatListRecentEntry, rhs: ChatListRecentEntry) -> Bool {
        switch lhs {
            case .topPeers:
                return true
            case let .peer(lhsIndex, _, _, _, _, _, _):
                switch rhs {
                    case .topPeers:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, disabledPeerSelected: @escaping (Peer) -> Void, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, deletePeer: @escaping (PeerId) -> Void) -> ListViewItem {
        switch self {
            case let .topPeers(peers, theme, strings):
                return ChatListRecentPeersListItem(theme: theme, strings: strings, context: context, peers: peers, peerSelected: { peer in
                    peerSelected(peer)
                }, peerContextAction: { peer, node, gesture in
                    if let peerContextAction = peerContextAction {
                        peerContextAction(peer, .recentPeers, node, gesture)
                    } else {
                        gesture?.cancel()
                    }
                })
            case let .peer(_, peer, theme, strings, timeFormat, nameSortOrder, nameDisplayOrder):
                let primaryPeer: Peer
                var chatPeer: Peer?
                let maybeChatPeer = peer.peer.peers[peer.peer.peerId]!
                if let associatedPeerId = maybeChatPeer.associatedPeerId, let associatedPeer = peer.peer.peers[associatedPeerId] {
                    primaryPeer = associatedPeer
                    chatPeer = maybeChatPeer
                } else {
                    primaryPeer = maybeChatPeer
                    chatPeer = maybeChatPeer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer)
                    } else {
                        enabled = canSendMessagesToPeer(primaryPeer)
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
                        if !(peer is TelegramUser || peer is TelegramSecretChat) {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let peer = chatPeer {
                        if let _ = peer as? TelegramGroup {
                        } else if let peer = peer as? TelegramChannel, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                if filter.contains(.excludeChannels) {
                    if let channel = primaryPeer as? TelegramChannel, case .broadcast = channel.info {
                        enabled = false
                    }
                }
                
                let status: ContactsPeerItemStatus
                if let user = primaryPeer as? TelegramUser {
                    let servicePeer = isServicePeer(primaryPeer)
                    if user.flags.contains(.isSupport) && !servicePeer {
                        status = .custom(string: strings.Bot_GenericSupportStatus, multiline: false)
                    } else if let _ = user.botInfo {
                        status = .custom(string: strings.Bot_GenericBotStatus, multiline: false)
                    } else if user.id != context.account.peerId && !servicePeer {
                        let presence = peer.presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
                        status = .presence(presence, timeFormat)
                    } else {
                        status = .none
                    }
                } else if let group = primaryPeer as? TelegramGroup {
                    status = .custom(string: strings.GroupInfo_ParticipantCount(Int32(group.participantCount)), multiline: false)
                } else if let channel = primaryPeer as? TelegramChannel {
                    if case .group = channel.info {
                        if let count = peer.subpeerSummary?.count {
                            status = .custom(string: strings.GroupInfo_ParticipantCount(Int32(count)), multiline: false)
                        } else {
                            status = .custom(string: strings.Group_Status, multiline: false)
                        }
                    } else {
                        if let count = peer.subpeerSummary?.count {
                            status = .custom(string: strings.Conversation_StatusSubscribers(Int32(count)), multiline: false)
                        } else {
                            status = .custom(string: strings.Channel_Status, multiline: false)
                        }
                    }
                } else {
                    status = .none
                }
                
                var isMuted = false
                if let notificationSettings = peer.notificationSettings {
                    isMuted = notificationSettings.isRemovedFromTotalUnreadCount(default: false)
                }
                var badge: ContactsPeerItemBadge?
                if peer.unreadCount > 0 {
                    badge = ContactsPeerItemBadge(count: peer.unreadCount, type: isMuted ? .inactive : .active)
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: status, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .recentPeers, theme: theme, strings: strings, actionTitle: strings.WebSearch_RecentSectionClear, action: {
                    clearRecentlySearchedPeers()
                }), action: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        peerSelected(chatPeer)
                    }
                }, disabledAction: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        disabledPeerSelected(chatPeer)
                    }
                }, deletePeer: deletePeer, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        if let chatPeer = peer.peer.peers[peer.peer.peerId], chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .recentSearch, node, gesture)
                        } else {
                            gesture?.cancel()
                        }
                    }
                })
        }
    }
}

public enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    case addContact
    
    public static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
            case let .localPeerId(peerId):
                if case .localPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .globalPeerId(peerId):
                if case .globalPeerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageId(messageId):
                if case .messageId(messageId) = rhs {
                    return true
                } else {
                    return false
                }
            case .addContact:
                if case .addContact = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatListSearchSectionExpandType {
    case none
    case expand
    case collapse
}

public enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Peer?, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType)
    case globalPeer(FoundPeer, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType)
    case message(Message, RenderedPeer, CombinedPeerReadState?, ChatListPresentationData, Int32, Bool?, Bool)
    case addContact(String, PresentationTheme, PresentationStrings)
    
    public var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .localPeer(peer, _, _, _, _, _, _, _, _):
                return .localPeerId(peer.id)
            case let .globalPeer(peer, _, _, _, _, _, _, _):
                return .globalPeerId(peer.peer.id)
            case let .message(message, _, _, _, _, _, _):
                return .messageId(message.id)
            case .addContact:
                return .addContact
        }
    }
    
    public static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType):
                if case let .localPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsExpandType == rhsExpandType {
                    return true
                } else {
                    return false
                }
            case let .globalPeer(lhsPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType):
                if case let .globalPeer(rhsPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsExpandType == rhsExpandType {
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage, lhsPeer, lhsCombinedPeerReadState, lhsPresentationData, lhsTotalCount, lhsSelected, lhsDisplayCustomHeader):
                if case let .message(rhsMessage, rhsPeer, rhsCombinedPeerReadState, rhsPresentationData, rhsTotalCount, rhsSelected, rhsDisplayCustomHeader) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsPeer != rhsPeer {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsCombinedPeerReadState != rhsCombinedPeerReadState {
                        return false
                    }
                    if lhsTotalCount != rhsTotalCount {
                        return false
                    }
                    if lhsSelected != rhsSelected {
                        return false
                    }
                    if lhsDisplayCustomHeader != rhsDisplayCustomHeader {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .addContact(lhsPhoneNumber, lhsTheme, lhsStrings):
                if case let .addContact(rhsPhoneNumber, rhsTheme, rhsStrings) = rhs {
                    if lhsPhoneNumber != rhsPhoneNumber {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
        
    public static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(_, _, _, lhsIndex, _, _, _, _, _):
                if case let .localPeer(_, _, _, rhsIndex, _, _, _, _, _) = rhs {
                    return lhsIndex <= rhsIndex
                } else {
                    return true
                }
            case let .globalPeer(_, _, lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .localPeer:
                        return false
                    case let .globalPeer(_, _, rhsIndex, _, _, _, _, _):
                        return lhsIndex <= rhsIndex
                    case .message, .addContact:
                        return true
                }
            case let .message(lhsMessage, _, _, _, _, _, _):
                if case let .message(rhsMessage, _, _, _, _, _, _) = rhs {
                    return lhsMessage.index < rhsMessage.index
                } else if case .addContact = rhs {
                    return true
                } else {
                    return false
                }
            case .addContact:
                return false
        }
    }
    
    public func item(context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, tagMask: MessageTags?, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (Peer) -> Void, searchResults: [Message], searchOptions: ChatListSearchOptions?, messageContextAction: ((Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)?) -> ListViewItem {
        switch self {
            case let .localPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType):
                let primaryPeer: Peer
                var chatPeer: Peer?
                if let associatedPeer = associatedPeer {
                    primaryPeer = associatedPeer
                    chatPeer = peer
                } else {
                    primaryPeer = peer
                    chatPeer = peer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer)
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
                        if !(peer is TelegramUser || peer is TelegramSecretChat) {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let peer = chatPeer {
                        if let _ = peer as? TelegramGroup {
                        } else if let peer = peer as? TelegramChannel, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if let unreadBadge = unreadBadge {
                    badge = ContactsPeerItemBadge(count: unreadBadge.0, type: unreadBadge.1 ? .inactive : .active)
                }
                
                let header: ChatListSearchItemHeader?
                if filter.contains(.removeSearchHeader) {
                    header = nil
                } else {
                    let actionTitle: String?
                    switch expandType {
                    case .none:
                        actionTitle = nil
                    case .expand:
                        actionTitle = strings.ChatList_Search_ShowMore
                    case .collapse:
                        actionTitle = strings.ChatList_Search_ShowLess
                    }
                    header = ChatListSearchItemHeader(type: .localPeers, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : {
                        toggleExpandLocalResults()
                    })
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: .none, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction.peerSelected(peer, nil)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        if let chatPeer = chatPeer, chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .search, node, gesture)
                        } else {
                            gesture?.cancel()
                        }
                    }
                }, arrowAction: nil)
            case let .globalPeer(peer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType):
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    enabled = canSendMessagesToPeer(peer.peer)
                }
                if filter.contains(.onlyPrivateChats) {
                    if !(peer.peer is TelegramUser || peer.peer is TelegramSecretChat) {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let _ = peer.peer as? TelegramGroup {
                    } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                    } else {
                        enabled = false
                    }
                }
                
                var suffixString = ""
                if let subscribers = peer.subscribers, subscribers != 0 {
                    if peer.peer is TelegramUser {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                        suffixString = ", \(strings.Conversation_StatusSubscribers(subscribers))"
                    } else {
                        suffixString = ", \(strings.Conversation_StatusMembers(subscribers))"
                    }
                }
                
                var badge: ContactsPeerItemBadge?
                if let unreadBadge = unreadBadge {
                    badge = ContactsPeerItemBadge(count: unreadBadge.0, type: unreadBadge.1 ? .inactive : .active)
                }
                
                let header: ChatListSearchItemHeader?
                if filter.contains(.removeSearchHeader) {
                    header = nil
                } else {
                    let actionTitle: String?
                    switch expandType {
                    case .none:
                        actionTitle = nil
                    case .expand:
                        actionTitle = strings.ChatList_Search_ShowMore
                    case .collapse:
                        actionTitle = strings.ChatList_Search_ShowLess
                    }
                    header = ChatListSearchItemHeader(type: .globalPeers, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : {
                        toggleExpandGlobalResults()
                    })
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: peer.peer, chatPeer: peer.peer), status: .addressName(suffixString), badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction.peerSelected(peer.peer, nil)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        peerContextAction(peer.peer, .search, node, gesture)
                    }
                })
            case let .message(message, peer, readState, presentationData, totalCount, selected, displayCustomHeader):
                let header = ChatListSearchItemHeader(type: .messages(totalCount), theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                let selection: ChatHistoryMessageSelection = selected.flatMap { .selectable(selected: $0) } ?? .none
                if let tagMask = tagMask, tagMask != .photoOrVideo {
                    return ListMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .builtin(WallpaperSettings())), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), context: context, chatLocation: .peer(peer.peerId), interaction: listInteraction, message: message, selection: selection, displayHeader: enableHeaders && !displayCustomHeader, customHeader: nil, hintIsLink: tagMask == .webPage, isGlobalSearchResult: true)
                } else {
                    return ChatListItem(presentationData: presentationData, context: context, peerGroupId: .root, filterData: nil, index: ChatListIndex(pinningIndex: nil, messageIndex: message.index), content: .peer(messages: [message], peer: peer, combinedReadState: readState, isRemovedFromTotalUnreadCount: false, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(), embeddedState: nil, inputActivities: nil, promoInfo: nil, ignoreUnreadBadge: true, displayAsMessage: false, hasFailedMessages: false), editing: false, hasActiveRevealControls: false, selected: false, header: header, enableContextActions: false, hiddenOffset: false, interaction: interaction)
                }
            case let .addContact(phoneNumber, theme, strings):
                return ContactsAddItem(theme: theme, strings: strings, phoneNumber: phoneNumber, header: ChatListSearchItemHeader(type: .phoneNumber, theme: theme, strings: strings, actionTitle: nil, action: nil), action: {
                    interaction.addContact(phoneNumber)
                })
        }
    }
}

private struct ChatListSearchContainerRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

public struct ChatListSearchContainerTransition {
    public let deletions: [ListViewDeleteItem]
    public let insertions: [ListViewInsertItem]
    public let updates: [ListViewUpdateItem]
    public let displayingResults: Bool
    public let isEmpty: Bool
    public let isLoading: Bool
    public let query: String
    public let animated: Bool
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem], displayingResults: Bool, isEmpty: Bool, isLoading: Bool, query: String, animated: Bool) {
        self.deletions = deletions
        self.insertions = insertions
        self.updates = updates
        self.displayingResults = displayingResults
        self.isEmpty = isEmpty
        self.isLoading = isLoading
        self.query = query
        self.animated = animated
    }
}

private func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, disabledPeerSelected: @escaping (Peer) -> Void, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, deletePeer: @escaping (PeerId) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, isEmpty: Bool, isLoading: Bool, animated: Bool, searchQuery: String, context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, tagMask: MessageTags?, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (Peer) -> Void, searchResults: [Message], searchOptions: ChatListSearchOptions?, messageContextAction: ((Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)?) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, tagMask: tagMask, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchResults: searchResults, searchOptions: searchOptions, messageContextAction: messageContextAction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, tagMask: tagMask,  interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchResults: searchResults, searchOptions: searchOptions, messageContextAction: messageContextAction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults, isEmpty: isEmpty, isLoading: isLoading, query: searchQuery, animated: animated)
}

private struct ChatListSearchListPaneNodeState: Equatable {
    var expandLocalSearch: Bool = false
    var expandGlobalSearch: Bool = false
}

private func doesPeerMatchFilter(peer: Peer, filter: ChatListNodePeersFilter) -> Bool {
    var enabled = true
    if filter.contains(.onlyWriteable), !canSendMessagesToPeer(peer) {
        enabled = false
    }
    if filter.contains(.onlyPrivateChats), !(peer is TelegramUser || peer is TelegramSecretChat) {
        enabled = false
    }
    if filter.contains(.onlyGroups) {
        if let _ = peer as? TelegramGroup {
        } else if let peer = peer as? TelegramChannel, case .group = peer.info {
        } else {
            enabled = false
        }
    }
    return enabled
}

private struct ChatListSearchMessagesResult {
    let query: String
    let messages: [Message]
    let readStates: [PeerId: CombinedPeerReadState]
    let hasMore: Bool
    let totalCount: Int32
    let state: SearchMessagesState
}

private struct ChatListSearchMessagesContext {
    let result: ChatListSearchMessagesResult
    let loadMoreIndex: MessageIndex?
}

public enum ChatListSearchContextActionSource {
    case recentPeers
    case recentSearch
    case search
}

public struct ChatListSearchOptions {
    let peer: (PeerId, Bool, String)?
    let minDate: (Int32, String)?
    let maxDate: (Int32, String)?
    
    var isEmpty: Bool {
        return self.peer == nil && self.minDate == nil && self.maxDate == nil
    }
    
    func withUpdatedPeer(_ peerIdIsGroupAndName: (PeerId, Bool, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: peerIdIsGroupAndName, minDate: self.minDate, maxDate: self.maxDate)
    }
    
    func withUpdatedMinDate(_ minDateAndTitle: (Int32, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: self.peer, minDate: minDateAndTitle, maxDate: self.maxDate)
    }

    func withUpdatedMaxDate(_ maxDateAndTitle: (Int32, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: self.peer, minDate: self.minDate, maxDate: maxDateAndTitle)
    }
}

final class ChatListSearchListPaneNode: ASDisplayNode, ChatListSearchPaneNode {
    private let context: AccountContext
    private let interaction: ChatListSearchInteraction
    private let peersFilter: ChatListNodePeersFilter
    private var presentationData: PresentationData
    private let key: ChatListSearchPaneKey
    private let tagMask: MessageTags?
    private let navigationController: NavigationController?
    
    private let recentListNode: ListView
    private let loadingNode: ASImageNode
    private let listNode: ListView
    private let mediaNode: ChatListSearchMediaNode
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    
    private var presentationDataDisposable: Disposable?
    private let updatedRecentPeersDisposable = MetaDisposable()
    private let recentDisposable = MetaDisposable()
    
    private let searchDisposable = MetaDisposable()
    private let presentationDataPromise = Promise<ChatListPresentationData>()
    private var searchStateValue = ChatListSearchListPaneNodeState()
    private let searchStatePromise = ValuePromise<ChatListSearchListPaneNodeState>()
    private let searchContextValue = Atomic<ChatListSearchMessagesContext?>(value: nil)
    var searchCurrentMessages: [Message]?
    
    private var searchQueryValue: String?
    private var searchOptionsValue: ChatListSearchOptions?
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var mediaStatusDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    private var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var mediaAccessoryPanelContainer: PassthroughContainerNode
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    private var dismissingPanel: ASDisplayNode?
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    private let emptyResultsAnimationNode: AnimatedStickerNode
    private var animationSize: CGSize = CGSize()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
        
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    private var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private var hiddenMediaDisposable: Disposable?
  
    init(context: AccountContext, interaction: ChatListSearchInteraction, key: ChatListSearchPaneKey, peersFilter: ChatListNodePeersFilter, searchQuery: Signal<String?, NoError>, searchOptions: Signal<ChatListSearchOptions?, NoError>, navigationController: NavigationController?) {
        self.context = context
        self.interaction = interaction
        self.key = key
        self.peersFilter = peersFilter
        self.navigationController = navigationController
        
        let tagMask: MessageTags?
        switch key {
            case .chats:
                tagMask = nil
            case .media:
                tagMask = .photoOrVideo
            case .links:
                tagMask = .webPage
            case .files:
                tagMask = .file
            case .music:
                tagMask = .music
            case .voice:
                tagMask = .voiceOrInstantVideo
        }
        self.tagMask = tagMask
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationDataPromise.set(.single(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)))
        
        self.searchStatePromise.set(self.searchStateValue)
        self.selectedMessages = interaction.getSelectedMessageIds()
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        self.recentListNode = ListView()
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        self.loadingNode = ASImageNode()
    
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        var openMediaMessageImpl: ((Message, ChatControllerInteractionOpenMessageMode) -> Void)?
        var transitionNodeImpl: ((MessageId, Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?)?
        var addToTransitionSurfaceImpl: ((UIView) -> Void)?
        
        self.mediaNode = ChatListSearchMediaNode(context: self.context, contentType: .photoOrVideo, openMessage: { message, mode in
            openMediaMessageImpl?(message, mode)
        }, messageContextAction: { message, node, rect, gesture in
            interaction.mediaMessageContextAction(message, node, rect, gesture)
        }, toggleMessageSelection: { messageId, selected in
            interaction.toggleMessageSelection(messageId, selected)
        })
        
        self.mediaAccessoryPanelContainer = PassthroughContainerNode()
        self.mediaAccessoryPanelContainer.clipsToBounds = true
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.displaysAsynchronously = false
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.displaysAsynchronously = false
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
             
        self.emptyResultsAnimationNode = AnimatedStickerNode()
        self.emptyResultsAnimationNode.isHidden = true
        
        super.init()
                
        if let path = getAppBundle().path(forResource: "ChatListNoResults", ofType: "tgs") {
            self.emptyResultsAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 124.0, height: 124.0)
        }
        
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        self.addSubnode(self.mediaNode)
        self.addSubnode(self.loadingNode)
        self.addSubnode(self.mediaAccessoryPanelContainer)
        
        self.addSubnode(self.emptyResultsAnimationNode)
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)

        let searchContext = Promise<ChatListSearchMessagesContext?>(nil)
        let searchContextValue = self.searchContextValue
        let updateSearchContext: ((ChatListSearchMessagesContext?) -> (ChatListSearchMessagesContext?, Bool)) -> Void = { f in
            var shouldUpdate = false
            let updated = searchContextValue.modify { current in
                let (u, s) = f(current)
                shouldUpdate = s
                if s {
                    return u
                } else {
                    return current
                }
            }
            if shouldUpdate {
                searchContext.set(.single(updated))
            }
        }
        
        self.listNode.isHidden = true
        self.mediaNode.isHidden = true
        self.recentListNode.isHidden = peersFilter.contains(.excludeRecent)
        
        let currentRemotePeers = Atomic<([FoundPeer], [FoundPeer])?>(value: nil)
        let presentationDataPromise = self.presentationDataPromise
        let searchStatePromise = self.searchStatePromise
        let selectionPromise = self.selectedMessagesPromise
        let foundItems = combineLatest(searchQuery, searchOptions)
        |> mapToSignal { query, options -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
            if query == nil && options == nil && tagMask == nil {
                let _ = currentRemotePeers.swap(nil)
                return .single(nil)
            }
            
            let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId) |> take(1)

            let foundLocalPeers: Signal<(peers: [RenderedPeer], unread: [PeerId: (Int32, Bool)]), NoError>

            if let query = query {
                foundLocalPeers = context.account.postbox.searchPeers(query: query.lowercased())
                |> mapToSignal { local -> Signal<([PeerView], [RenderedPeer]), NoError> in
                    return combineLatest(local.map { context.account.postbox.peerView(id: $0.peerId) }) |> map { views in
                        return (views, local)
                    }
                }
                |> mapToSignal { viewsAndPeers -> Signal<(peers: [RenderedPeer], unread: [PeerId: (Int32, Bool)]), NoError> in
                    return context.account.postbox.unreadMessageCountsView(items: viewsAndPeers.0.map {.peer($0.peerId)}) |> map { values in
                        var unread: [PeerId: (Int32, Bool)] = [:]
                        for peerView in viewsAndPeers.0 {
                            var isMuted: Bool = false
                            if let nofiticationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                                switch nofiticationSettings.muteState {
                                case .muted:
                                    isMuted = true
                                default:
                                    break
                                }
                            }
                            
                            let unreadCount = values.count(for: .peer(peerView.peerId))
                            if let unreadCount = unreadCount, unreadCount > 0 {
                                unread[peerView.peerId] = (unreadCount, isMuted)
                            }
                        }
                        return (peers: viewsAndPeers.1, unread: unread)
                    }
                }
            } else {
                foundLocalPeers = .single((peers: [], unread: [:]))
            }
            
            let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], Bool), NoError>
            let currentRemotePeersValue = currentRemotePeers.with { $0 } ?? ([], [])
            if let query = query {
                foundRemotePeers = (
                    .single((currentRemotePeersValue.0, currentRemotePeersValue.1, true))
                    |> then(
                        searchPeers(account: context.account, query: query)
                        |> map { ($0.0, $0.1, false) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    )
                )
            } else {
                foundRemotePeers = .single(([], [], false))
            }
            let location: SearchMessagesLocation
            if let options = options {
                if let (peerId, _, _) = options.peer {
                    location = .peer(peerId: peerId, fromId: nil, tags: self.tagMask, topMsgId: nil, minDate: options.minDate?.0, maxDate: options.maxDate?.0)
                } else {
                    
                    location = .general(tags: self.tagMask, minDate: options.minDate?.0, maxDate: options.maxDate?.0)
                }
            } else {
                location = .general(tags: self.tagMask, minDate: nil, maxDate: nil)
            }
            
            let finalQuery = query ?? ""
            updateSearchContext { _ in
                return (nil, true)
            }
            let foundRemoteMessages: Signal<(([Message], [PeerId: CombinedPeerReadState], Int32), Bool), NoError>
            if peersFilter.contains(.doNotSearchMessages) {
                foundRemoteMessages = .single((([], [:], 0), false))
            } else {
                if !finalQuery.isEmpty {
                    addAppLogEvent(postbox: context.account.postbox, type: "search_global_query")
                }
                
                let searchSignal = searchMessages(account: context.account, location: location, query: finalQuery, state: nil, limit: 50)
                |> map { result, updatedState -> ChatListSearchMessagesResult in
                    return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.sorted(by: { $0.index > $1.index }), readStates: result.readStates, hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                }
                
                let loadMore = searchContext.get()
                |> mapToSignal { searchContext -> Signal<(([Message], [PeerId: CombinedPeerReadState], Int32), Bool), NoError> in
                    if let searchContext = searchContext, searchContext.result.hasMore {
                        if let _ = searchContext.loadMoreIndex {
                            return searchMessages(account: context.account, location: location, query: finalQuery, state: searchContext.result.state, limit: 80)
                            |> map { result, updatedState -> ChatListSearchMessagesResult in
                                return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.sorted(by: { $0.index > $1.index }), readStates: result.readStates, hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                            }
                            |> mapToSignal { foundMessages -> Signal<(([Message], [PeerId: CombinedPeerReadState], Int32), Bool), NoError> in
                                updateSearchContext { previous in
                                    let updated = ChatListSearchMessagesContext(result: foundMessages, loadMoreIndex: nil)
                                    return (updated, true)
                                }
                                return .complete()
                            }
                        } else {
                            return .single(((searchContext.result.messages, searchContext.result.readStates, searchContext.result.totalCount), false))
                        }
                    } else {
                        return .complete()
                    }
                }
                
                foundRemoteMessages = .single((([], [:], 0), true))
                |> then(
                    searchSignal
                    |> map { foundMessages -> (([Message], [PeerId: CombinedPeerReadState], Int32), Bool) in
                        updateSearchContext { _ in
                            return (ChatListSearchMessagesContext(result: foundMessages, loadMoreIndex: nil), true)
                        }
                        return ((foundMessages.messages, foundMessages.readStates, foundMessages.totalCount), false)
                    }
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    |> then(loadMore)
                )
            }
            
            let resolvedMessage = .single(nil)
            |> then(context.sharedContext.resolveUrl(account: context.account, url: finalQuery)
            |> mapToSignal { resolvedUrl -> Signal<Message?, NoError> in
                if case let .channelMessage(_, messageId) = resolvedUrl {
                    return downloadMessage(postbox: context.account.postbox, network: context.account.network, messageId: messageId)
                } else {
                    return .single(nil)
                }
            })
            
            return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationDataPromise.get(), searchStatePromise.get(), selectionPromise.get(), resolvedMessage)
            |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationData, searchState, selectionState, resolvedMessage -> ([ChatListSearchEntry], Bool)? in
                let isSearching = foundRemotePeers.2 || foundRemoteMessages.1
                var entries: [ChatListSearchEntry] = []
                var index = 0
                
                let _ = currentRemotePeers.swap((foundRemotePeers.0, foundRemotePeers.1))
                
                let filteredPeer:(Peer, Peer) -> Bool = { peer, accountPeer in
                    guard !peersFilter.contains(.excludeSavedMessages) || peer.id != accountPeer.id else { return false }
                    guard !peersFilter.contains(.excludeSecretChats) || peer.id.namespace != Namespaces.Peer.SecretChat else { return false }
                    guard !peersFilter.contains(.onlyPrivateChats) || peer.id.namespace == Namespaces.Peer.CloudUser else { return false }
                    
                    if peersFilter.contains(.onlyGroups) {
                        var isGroup: Bool = false
                        if let peer = peer as? TelegramChannel, case .group = peer.info {
                            isGroup = true
                        } else if peer.id.namespace == Namespaces.Peer.CloudGroup {
                            isGroup = true
                        }
                        if !isGroup {
                            return false
                        }
                    }
                    
                    if peersFilter.contains(.onlyChannels) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            return true
                        } else {
                            return false
                        }
                    }
                    
                    if peersFilter.contains(.excludeChannels) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            return false
                        }
                    }
                    
                    return true
                }
                
                var existingPeerIds = Set<PeerId>()
                
                var totalNumberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, accountPeer) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            totalNumberOfLocalPeers += 1
                        }
                    }
                }
                for peer in foundRemotePeers.0 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                        existingPeerIds.insert(peer.peer.id)
                        totalNumberOfLocalPeers += 1
                    }
                }
                
                var totalNumberOfGlobalPeers = 0
                for peer in foundRemotePeers.1 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                        totalNumberOfGlobalPeers += 1
                    }
                }
                
                existingPeerIds.removeAll()
                
                let localExpandType: ChatListSearchSectionExpandType = .none
                let globalExpandType: ChatListSearchSectionExpandType
                if totalNumberOfGlobalPeers > 3 {
                    globalExpandType = searchState.expandGlobalSearch ? .collapse : .expand
                } else {
                    globalExpandType = .none
                }
                
                let lowercasedQuery = finalQuery.lowercased()
                if lowercasedQuery.count > 1 && (presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery)) {
                    if !existingPeerIds.contains(accountPeer.id), filteredPeer(accountPeer, accountPeer) {
                        existingPeerIds.insert(accountPeer.id)
                        entries.append(.localPeer(accountPeer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
                        index += 1
                    }
                }
                
                var numberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if case .expand = localExpandType, numberOfLocalPeers >= 3 {
                        break
                    }
                    
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, accountPeer) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            var associatedPeer: Peer?
                            if let associatedPeerId = peer.associatedPeerId {
                                associatedPeer = renderedPeer.peers[associatedPeerId]
                            }
                            entries.append(.localPeer(peer, associatedPeer, foundLocalPeers.unread[peer.id], index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
                            index += 1
                            numberOfLocalPeers += 1
                        }
                    }
                }
                
                for peer in foundRemotePeers.0 {
                    if case .expand = localExpandType, numberOfLocalPeers >= 3 {
                        break
                    }
                    
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                        existingPeerIds.insert(peer.peer.id)
                        entries.append(.localPeer(peer.peer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
                        index += 1
                        numberOfLocalPeers += 1
                    }
                }

                var numberOfGlobalPeers = 0
                index = 0
                if let _ = tagMask {
                } else {
                    for peer in foundRemotePeers.1 {
                        if case .expand = globalExpandType, numberOfGlobalPeers >= 3 {
                            break
                        }
                        
                        if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                            existingPeerIds.insert(peer.peer.id)
                            entries.append(.globalPeer(peer, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, globalExpandType))
                            index += 1
                            numberOfGlobalPeers += 1
                        }
                    }
                }
                
                if let message = resolvedMessage {
                    var peer = RenderedPeer(message: message)
                    if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                        if let channelPeer = message.peers[migrationReference.peerId] {
                            peer = RenderedPeer(peer: channelPeer)
                        }
                    }
                    entries.append(.message(message, peer, nil, presentationData, 1, nil, true))
                    index += 1
                }
                
                var firstHeaderId: Int64?
                if !foundRemotePeers.2 {
                    index = 0
                    for message in foundRemoteMessages.0.0 {
                        let headerId = listMessageDateHeaderId(timestamp: message.timestamp)
                        if firstHeaderId == nil {
                            firstHeaderId = headerId
                        }
                        var peer = RenderedPeer(message: message)
                        if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = RenderedPeer(peer: channelPeer)
                            }
                        }
                        entries.append(.message(message, peer, foundRemoteMessages.0.1[message.id.peerId], presentationData, foundRemoteMessages.0.2, selectionState?.contains(message.id), headerId == firstHeaderId))
                        index += 1
                    }
                }
                
                if tagMask == nil, !peersFilter.contains(.excludeRecent), isViablePhoneNumber(finalQuery) {
                    entries.append(.addContact(finalQuery, presentationData.theme, presentationData.strings))
                }
                
                return (entries, isSearching)
            }
        }
        
        let foundMessages = searchContext.get() |> map { searchContext -> ([Message], Int32, Bool) in
            if let result = searchContext?.result {
                return (result.messages, result.totalCount, result.hasMore)
            } else {
                return ([], 0, false)
            }
        }
        
        let loadMore = {
            updateSearchContext { previous in
                guard let previous = previous else {
                    return (nil, false)
                }
                if previous.loadMoreIndex != nil {
                    return (previous, false)
                }
                guard let last = previous.result.messages.last else {
                    return (previous, false)
                }
                return (ChatListSearchMessagesContext(result: previous.result, loadMoreIndex: last.index), true)
            }
        }
        
        openMediaMessageImpl = { message, mode in
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a in
                interaction.present(c, a)
            }, transitionNode: { messageId, media in
                return transitionNodeImpl?(messageId, media)
            }, addToTransitionSurface: { view in
                addToTransitionSurfaceImpl?(view)
            }, openUrl: { url in
                interaction.openUrl(url)
            }, openPeer: { peer, navigation in
                //self?.openPeer(peerId: peer.id, navigation: navigation)
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, gallerySource: .custom(messages: foundMessages, messageId: message.id, loadMore: {
                loadMore()
            })))
        }
        
        transitionNodeImpl = { [weak self] messageId, media in
            if let strongSelf = self {
                return strongSelf.mediaNode.transitionNodeForGallery(messageId: messageId, media: media)
            } else {
                return nil
            }
        }
        
        addToTransitionSurfaceImpl = { [weak self] view in
            if let strongSelf = self {
                strongSelf.mediaNode.addToTransitionSurface(view: view)
            }
        }
        
        let chatListInteraction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { [weak self] peer, _ in
            interaction.dismissInput()
            interaction.openPeer(peer, false)
            let _ = addRecentlySearchedPeer(postbox: context.account.postbox, peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, disabledPeerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            interaction.dismissInput()
            if let peer = message.peers[message.id.peerId] {
                interaction.openMessage(peer, message.id)
            }
            self?.listNode.clearHighlightAnimated(true)
        }, groupSelected: { _ in
        }, addContact: { [weak self] phoneNumber in
            interaction.dismissInput()
            interaction.addContact(phoneNumber)
            self?.listNode.clearHighlightAnimated(true)
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _, _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, hidePsa: { _ in
        }, activateChatPreview: { item, node, gesture in
            guard let peerContextAction = interaction.peerContextAction else {
                gesture?.cancel()
                return
            }
            switch item.content {
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _):
                if let peer = peer.peer {
                    peerContextAction(peer, .search, node, gesture)
                }
            case .groupReference:
                gesture?.cancel()
            }
        }, present: { c in
            interaction.present(c, nil)
        })
        
        let listInteraction = ListMessageItemInteraction(openMessage: { [weak self] message, mode -> Bool in
            interaction.dismissInput()
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a in
                interaction.present(c, a)
            }, transitionNode: { [weak self] messageId, media in
                var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                if let strongSelf = self {
                    strongSelf.listNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ListMessageNode {
                            if let result = itemNode.transitionNode(id: messageId, media: media) {
                                transitionNode = result
                            }
                        }
                    }
                }
                return transitionNode
            }, addToTransitionSurface: { view in
                self?.addToTransitionSurface(view: view)
            }, openUrl: { url in
                interaction.openUrl(url)
            }, openPeer: { peer, navigation in
//                interaction.openPeer(peer.id, navigation)
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: .custom(messages: foundMessages, at: message.id, loadMore: {
                loadMore()
            }), gallerySource: .custom(messages: foundMessages, messageId: message.id, loadMore: {
                loadMore()
            })))
        }, openMessageContextMenu: { message, _, node, rect, gesture in
            interaction.messageContextAction(message, node, rect, gesture)
        }, toggleMessagesSelection: { messageId, selected in
            if let messageId = messageId.first {
                interaction.toggleMessageSelection(messageId, selected)
            }
        }, openUrl: { url, _, _, message in
            interaction.openUrl(url)
        }, openInstantPage: { [weak self] message, data in
            if let (webpage, anchor) = instantPageAndAnchor(message: message) {
                let pageController = InstantPageController(context: context, webPage: webpage, sourcePeerType: .channel, anchor: anchor)
                self?.navigationController?.pushViewController(pageController)
            }
        }, longTap: { action, message in
        }, getHiddenMedia: {
            return [:]
        })
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        let previousSelectedMessages = Atomic<Set<MessageId>?>(value: nil)
        
        let _ = (searchQuery
        |> deliverOnMainQueue).start(next: { [weak self] query in
            self?.searchQueryValue = query
        })
        
        let _ = (searchOptions
        |> deliverOnMainQueue).start(next: { [weak self] options in
            self?.searchOptionsValue = options
        })

        self.searchDisposable.set((foundItems
        |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags in
            if let strongSelf = self {
                let previousSelectedMessageIds = previousSelectedMessages.swap(strongSelf.selectedMessages)
                
                let isSearching = entriesAndFlags?.1 ?? false
                strongSelf._isSearching.set(isSearching)
                
                if strongSelf.tagMask == .photoOrVideo {
                    var totalCount: Int32 = 0
                    if let entries = entriesAndFlags?.0 {
                        for entry in entries {
                            if case let .message(_, _, _, _, count, _, _) = entry {
                                totalCount = count
                                break
                            }
                        }
                    }
                    var entries: [ChatListSearchEntry]? = entriesAndFlags?.0 ?? []
                    if isSearching && (entries?.isEmpty ?? true) {
                        entries = nil
                    }
                    strongSelf.mediaNode.updateHistory(entries: entries, totalCount: totalCount, updateType: .Initial)
                }
                
                var entriesAndFlags = entriesAndFlags
                
                var peers: [Peer] = []
                if let entries = entriesAndFlags?.0 {
                    var filteredEntries: [ChatListSearchEntry] = []
                    for entry in entries {
                        if case let .localPeer(peer, _, _, _, _, _, _, _, _) = entry {
                            peers.append(peer)
                        } else {
                            filteredEntries.append(entry)
                        }
                    }
                    
                    if strongSelf.tagMask != nil || strongSelf.searchOptionsValue?.maxDate != nil || strongSelf.searchOptionsValue?.peer != nil {
                        entriesAndFlags?.0 = filteredEntries
                    }
                }
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                let newEntries = entriesAndFlags?.0 ?? []
                
                let animated = (previousSelectedMessageIds == nil) != (strongSelf.selectedMessages == nil)
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: newEntries, displayingResults: entriesAndFlags?.0 != nil, isEmpty: !isSearching && (entriesAndFlags?.0.isEmpty ?? false), isLoading: isSearching, animated: animated, searchQuery: strongSelf.searchQueryValue ?? "", context: context, presentationData: strongSelf.presentationData, enableHeaders: true, filter: peersFilter, tagMask: tagMask, interaction: chatListInteraction, listInteraction: listInteraction, peerContextAction: { _, _, _, _ in }, toggleExpandLocalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateState { state in
                        var state = state
                        state.expandLocalSearch = !state.expandLocalSearch
                        return state
                    }
                }, toggleExpandGlobalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateState { state in
                        var state = state
                        state.expandGlobalSearch = !state.expandGlobalSearch
                        return state
                    }
                }, searchPeer: { peer in
                }, searchResults: newEntries.compactMap { entry -> Message? in
                    if case let .message(message, _, _, _, _, _, _) = entry {
                        return message
                    } else {
                        return nil
                    }
                }, searchOptions: strongSelf.searchOptionsValue, messageContextAction: { message, node, rect, gesture in
                    interaction.messageContextAction(message, node, rect, gesture)
                })
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
                
                var messages: [Message] = []
                for entry in newEntries {
                    if case let .message(message, _, _, _, _, _, _) = entry {
                        messages.append(message)
                    }
                }
                strongSelf.searchCurrentMessages = messages
                
                if !strongSelf.didSetReady {
                    strongSelf.ready.set(.single(true))
                    strongSelf.didSetReady = true
                } else if tagMask != nil {
                    interaction.updateSuggestedPeers(Array(peers.prefix(8)), strongSelf.key)
                }
            }
        }))
        
        let previousRecentItems = Atomic<[ChatListRecentEntry]?>(value: nil)
        let hasRecentPeers = recentPeers(account: context.account)
        |> map { value -> Bool in
            switch value {
                case let .peers(peers):
                    return !peers.isEmpty
                case .disabled:
                    return false
            }
        }
        |> distinctUntilChanged
        
        let previousRecentlySearchedPeerOrder = Atomic<[PeerId]>(value: [])
        let fixedRecentlySearchedPeers = recentlySearchedPeers(postbox: context.account.postbox)
        |> map { peers -> [RecentlySearchedPeer] in
            var result: [RecentlySearchedPeer] = []
            let _ = previousRecentlySearchedPeerOrder.modify { current in
                var updated: [PeerId] = []
                for id in current {
                    inner: for peer in peers {
                        if peer.peer.peerId == id {
                            updated.append(id)
                            result.append(peer)
                            break inner
                        }
                    }
                }
                for peer in peers.reversed() {
                    if !updated.contains(peer.peer.peerId) {
                        updated.insert(peer.peer.peerId, at: 0)
                        result.insert(peer, at: 0)
                    }
                }
                return updated
            }
            return result
        }
        
        var recentItems = combineLatest(hasRecentPeers, fixedRecentlySearchedPeers, presentationDataPromise.get())
        |> mapToSignal { hasRecentPeers, peers, presentationData -> Signal<[ChatListRecentEntry], NoError> in
            var entries: [ChatListRecentEntry] = []
            if !peersFilter.contains(.onlyGroups) {
                if hasRecentPeers {
                    entries.append(.topPeers([], presentationData.theme, presentationData.strings))
                }
            }
            var peerIds = Set<PeerId>()
            var index = 0
            loop: for searchedPeer in peers {
                if let peer = searchedPeer.peer.peers[searchedPeer.peer.peerId] {
                    if peerIds.contains(peer.id) {
                        continue loop
                    }
                    if !doesPeerMatchFilter(peer: peer, filter: peersFilter) {
                        continue
                    }
                    peerIds.insert(peer.id)
                    
                    entries.append(.peer(index: index, peer: searchedPeer, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                    index += 1
                }
            }
           
            return .single(entries)
        }
        
        if peersFilter.contains(.excludeRecent) {
            recentItems = .single([])
        }
        
        if tagMask == nil && !peersFilter.contains(.excludeRecent) {
            self.updatedRecentPeersDisposable.set(managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network).start())
        }
        
        self.recentDisposable.set((combineLatest(queue: .mainQueue(),
            presentationDataPromise.get(),
            recentItems
        )
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, entries in
            if let strongSelf = self {
                let previousEntries = previousRecentItems.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, context: context, presentationData: presentationData, filter: peersFilter, peerSelected: { peer in
                    interaction.openPeer(peer, true)
                    let _ = addRecentlySearchedPeer(postbox: context.account.postbox, peerId: peer.id).start()
                    self?.recentListNode.clearHighlightAnimated(true)
                }, disabledPeerSelected: { peer in
                    interaction.openDisabledPeer(peer)
                }, peerContextAction: { peer, source, node, gesture in
                    if let peerContextAction = interaction.peerContextAction {
                        peerContextAction(peer, source, node, gesture)
                    } else {
                        gesture?.cancel()
                    }
                }, clearRecentlySearchedPeers: {
                    interaction.clearRecentSearch()
                }, deletePeer: { peerId in
                    if let strongSelf = self {
                        let _ = removeRecentlySearchedPeer(postbox: strongSelf.context.account.postbox, peerId: peerId).start()
                    }
                })
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)))

                if previousTheme !== presentationData.theme {
//                    strongSelf.updateTheme(theme: presentationData.theme)
                }
            }
        })
                        
        self.recentListNode.beganInteractiveDragging = {
            interaction.dismissInput()
        }
        
        self.listNode.beganInteractiveDragging = {
            interaction.dismissInput()
        }
        
        self.mediaNode.beganInteractiveDragging = {
            interaction.dismissInput()
        }
        
        self.listNode.visibleBottomContentOffsetChanged = { offset in
            guard case let .known(value) = offset, value < 160.0 else {
                return
            }
            loadMore()
        }
        
        self.mediaNode.loadMore = {
            loadMore()
        }
        
        if tagMask == .music || tagMask == .voiceOrInstantVideo {
            self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
            |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                if let (account, state, type) = playlistStateAndType {
                    switch state {
                    case let .state(state):
                        if let playlistId = state.playlistId as? PeerMessagesMediaPlaylistId, case .custom = playlistId {
                            switch type {
                            case .voice:
                                if tagMask != .voiceOrInstantVideo {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .music:
                                if tagMask != .music {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            }
                            return .single((account, state, type))
                        } else {
                            return .single(nil) |> delay(0.2, queue: .mainQueue())
                        }
                    case .loading:
                        return .single(nil) |> delay(0.2, queue: .mainQueue())
                    }
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                guard let strongSelf = self else {
                    return
                }
                if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.1.item) ||
                    !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.1, playlistStateAndType?.1.previousItem) ||
                    !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.2, playlistStateAndType?.1.nextItem) ||
                    strongSelf.playlistStateAndType?.3 != playlistStateAndType?.1.order || strongSelf.playlistStateAndType?.4 != playlistStateAndType?.2 {
                    
                    if let playlistStateAndType = playlistStateAndType {
                        strongSelf.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0)
                    } else {
                        strongSelf.playlistStateAndType = nil
                    }
                    
                    if let (size, sideInset, bottomInset, visibleHeight, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.searchDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
        self.recentDisposable.dispose()
        self.updatedRecentPeersDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.emptyResultsAnimationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
    }
    
    private func updateState(_ f: (ChatListSearchListPaneNodeState) -> ChatListSearchListPaneNodeState) {
        let state = f(self.searchStateValue)
        if state != self.searchStateValue {
            self.searchStateValue = state
            self.searchStatePromise.set(state)
        }
    }
    
    @objc private func animationTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, !self.emptyResultsAnimationNode.isPlaying {
            let _ = self.emptyResultsAnimationNode.playIfNeeded()
        }
    }
    
    func scrollToTop() -> Bool {
        let offset = self.listNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
//            self.listNode.scrollto
            return true
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        var hadValidLayout = self.currentParams != nil
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, presentationData)
        
        var topPanelHeight: CGFloat = 0.0
        if let (item, previousItem, nextItem, order, type, _) = self.playlistStateAndType {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            topPanelHeight = panelHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - panelHeight), size: CGSize(width: size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, transition: transition)
                switch order {
                case .regular:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                case .reversed:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                case .random:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                let delayedStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
                    guard let value = value else {
                        return .single(nil)
                    }
                    switch value.1 {
                        case .state:
                            return .single(value)
                        case .loading:
                            return .single(value) |> delay(0.1, queue: .mainQueue())
                    }
                }
                
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = delayedStatus
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
            } else {
                if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
                    self.mediaAccessoryPanel = nil
                    self.dismissingPanel = mediaAccessoryPanel
                    mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                        mediaAccessoryPanel?.removeFromSupernode()
                        if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                            strongSelf.dismissingPanel = nil
                        }
                    })
                }
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.setPlaylist(nil, type: type, control: SharedMediaPlayerControlAction.playback(.pause))
                    }
                }
                mediaAccessoryPanel.toggleRate = {
                    [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings) as? MusicPlaybackSettings ?? MusicPlaybackSettings.defaultSettings
                        
                        let nextRate: AudioPlaybackRate
                        switch settings.voicePlaybackRate {
                            case .x1:
                                nextRate = .x2
                            case .x2:
                                nextRate = .x1
                        }
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return settings.withUpdatedVoicePlaybackRate(nextRate)
                        })
                        return nextRate
                    }
                    |> deliverOnMainQueue).start(next: { baseRate in
                        guard let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType else {
                            return
                        }
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: type)
                    })
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                    }
                }
                mediaAccessoryPanel.playPrevious = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.next, type: type)
                    }
                }
                mediaAccessoryPanel.playNext = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.previous, type: type)
                    }
                }
                mediaAccessoryPanel.tapAction = { [weak self] in
                    guard let strongSelf = self, let navigationController = strongSelf.navigationController, let (state, _, _, order, type, account) = strongSelf.playlistStateAndType else {
                        return
                    }
                    if let id = state.id as? PeerMessagesMediaPlaylistItemId {
                        if type == .music {
                            let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(location: .id(id.messageId), count: 60), id: 0), context: strongSelf.context, chatLocation: .peer(id.messageId.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tagMask: MessageTags.music)
                            
                            var cancelImpl: (() -> Void)?
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let progressSignal = Signal<Never, NoError> { subscriber in
                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                    cancelImpl?()
                                }))
                                self?.interaction.present(controller, nil)
                                return ActionDisposable { [weak controller] in
                                    Queue.mainQueue().async() {
                                        controller?.dismiss()
                                    }
                                }
                            }
                            |> runOn(Queue.mainQueue())
                            |> delay(0.15, queue: Queue.mainQueue())
                            let progressDisposable = MetaDisposable()
                            var progressStarted = false
                            strongSelf.playlistPreloadDisposable?.dispose()
                            strongSelf.playlistPreloadDisposable = (signal
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    progressDisposable.dispose()
                                }
                            }
                            |> deliverOnMainQueue).start(next: { index in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let _ = index.0 {
                                    let controllerContext: AccountContext
                                    if account.id == strongSelf.context.account.id {
                                        controllerContext = strongSelf.context
                                    } else {
                                        controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                    }
                                    let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, isGlobalSearch: false, parentNavigationController: navigationController)
                                    strongSelf.view.window?.endEditing(true)
                                    strongSelf.interaction.dismissInput()
                                    strongSelf.interaction.present(controller, nil)
                                } else if index.1 {
                                    if !progressStarted {
                                        progressStarted = true
                                        progressDisposable.set(progressSignal.start())
                                    }
                                }
                            }, completed: {
                            })
                            cancelImpl = {
                                self?.playlistPreloadDisposable?.dispose()
                            }
                        } else {
                            strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: id.messageId.peerId, messageId: id.messageId)
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.mediaAccessoryPanelContainer.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else {
                    self.mediaAccessoryPanelContainer.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, transition: .immediate)
                switch order {
                    case .regular:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                    case .reversed:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                    case .random:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
                mediaAccessoryPanel.animateIn(transition: transition)
            }
        } else if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
            self.mediaAccessoryPanel = nil
            self.dismissingPanel = mediaAccessoryPanel
            mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                mediaAccessoryPanel?.removeFromSupernode()
                if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                    strongSelf.dismissingPanel = nil
                }
            })
        }
        
        transition.updateFrame(node: self.mediaAccessoryPanelContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: MediaNavigationAccessoryHeaderNode.minimizedHeight)))
        
        var topInset: CGFloat = 0.0
        let navigationBarHeight: CGFloat = 0.0
        let insets = UIEdgeInsets(top: topPanelHeight, left: sideInset, bottom: bottomInset, right: sideInset)
        
        self.loadingNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: 422.0))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.mediaNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: size.height))
        self.mediaNode.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: false, expandProgress: 1.0, presentationData: self.presentationData, synchronous: true, transition: transition)
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: size.width - sideInset * 2.0 - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var emptyAnimationHeight = self.animationSize.height
        var emptyAnimationSpacing: CGFloat = 8.0
//        if case .landscape = layout.orientation, case .compact = layout.metrics.widthClass {
//            emptyAnimationHeight = 0.0
//            emptyAnimationSpacing = 0.0
//        }
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyAnimationY = navigationBarHeight + floorToScreenPixels((visibleHeight - navigationBarHeight - bottomInset - emptyTotalHeight) / 2.0)
        
        let textTransition = ContainedViewLayoutTransition.immediate
        textTransition.updateFrame(node: self.emptyResultsAnimationNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - self.animationSize.width) / 2.0, y: emptyAnimationY), size: self.animationSize))
        textTransition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTitleSize))
        textTransition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        self.emptyResultsAnimationNode.updateLayout(size: self.animationSize)
        
        if !hadValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    func updateHiddenMedia() {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
    
    func addToTransitionSurface(view: UIView) {
        self.view.addSubview(view)
    }
    
    func updateSelectedMessages(animated: Bool) {
        self.selectedMessages = self.interaction.getSelectedMessageIds()
        self.mediaNode.selectedMessageIds = self.selectedMessages
        self.mediaNode.updateSelectedMessages(animated: animated)
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.currentParams != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.currentParams != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            if transition.animated {
                options.insert(.AnimateInsertion)
            }
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    let searchOptions = strongSelf.searchOptionsValue
                    strongSelf.listNode.isHidden = strongSelf.tagMask == .photoOrVideo && (strongSelf.searchQueryValue ?? "").isEmpty
                    strongSelf.mediaNode.isHidden = !strongSelf.listNode.isHidden
                    
                    let displayingResults = transition.displayingResults
                    if !displayingResults {
                        strongSelf.listNode.isHidden = true
                        strongSelf.mediaNode.isHidden = true
                    }
                    
                    let emptyResults = displayingResults && transition.isEmpty
                    if emptyResults {
                        let emptyResultsTitle: String
                        let emptyResultsText: String
                        if !transition.query.isEmpty {
                            emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                            emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(transition.query).0
                        } else {
                            if let searchOptions = searchOptions, searchOptions.minDate == nil && searchOptions.maxDate == nil && searchOptions.peer == nil {
                                emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResultsFilter
                                if strongSelf.tagMask == .photoOrVideo {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMedia
                                } else if strongSelf.tagMask == .webPage {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerLinks
                                } else if strongSelf.tagMask == .file {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerFiles
                                } else if strongSelf.tagMask == .music {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMusic
                                } else if strongSelf.tagMask == .voiceOrInstantVideo {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerVoice
                                } else {
                                    emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsDescription
                                }
                            } else {
                                emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsDescription
                            }
                        }
                        
                        strongSelf.emptyResultsTitleNode.attributedText = NSAttributedString(string: emptyResultsTitle, font: Font.semibold(17.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                        strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: emptyResultsText, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                    }

                    if let (size, sideInset, bottomInset, visibleHeight, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                    
                    strongSelf.emptyResultsAnimationNode.isHidden = !emptyResults
                    strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                    strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                    strongSelf.emptyResultsAnimationNode.visibility = emptyResults
                         
                    if strongSelf.tagMask == .webPage {
                        strongSelf.loadingNode.image = UIImage(bundleImageName: "Chat List/Search/M_Links")
                    } else if strongSelf.tagMask == .file {
                        strongSelf.loadingNode.image = UIImage(bundleImageName: "Chat List/Search/M_Files")
                    } else if strongSelf.tagMask == .music || strongSelf.tagMask == .voiceOrInstantVideo {
                        strongSelf.loadingNode.image = UIImage(bundleImageName: "Chat List/Search/M_Music")
                    }
                    
                    strongSelf.loadingNode.isHidden = !transition.isLoading
           
                    strongSelf.recentListNode.isHidden = displayingResults || strongSelf.peersFilter.contains(.excludeRecent)
//                    strongSelf.dimNode.isHidden = displayingResults
                    strongSelf.backgroundColor = !displayingResults && strongSelf.peersFilter.contains(.excludeRecent) ? nil : strongSelf.presentationData.theme.chatList.backgroundColor
                }
            })
        }
    }
    
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        var selectedItemNode: ASDisplayNode?
        var bounds: CGRect
        if !self.recentListNode.isHidden {
            let adjustedLocation = self.convert(location, to: self.recentListNode)
            self.recentListNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        } else {
            let adjustedLocation = self.convert(location, to: self.listNode)
            self.listNode.forEachItemNode { itemNode in
                if itemNode.frame.contains(adjustedLocation) {
                    selectedItemNode = itemNode
                }
            }
        }
        if let selectedItemNode = selectedItemNode as? ChatListRecentPeersListItemNode {
            if let result = selectedItemNode.viewAndPeerAtPoint(self.convert(location, to: selectedItemNode)) {
                return (result.0, result.0.bounds, result.1)
            }
        } else if let selectedItemNode = selectedItemNode as? ContactsPeerItemNode, let peer = selectedItemNode.chatPeer {
            if selectedItemNode.frame.height > 50.0 {
                bounds = CGRect(x: 0.0, y: selectedItemNode.frame.height - 50.0, width: selectedItemNode.frame.width, height: 50.0)
            } else {
                bounds = selectedItemNode.bounds
            }
            return (selectedItemNode.view, bounds, peer.id)
        } else if let selectedItemNode = selectedItemNode as? ChatListItemNode, let item = selectedItemNode.item {
            if selectedItemNode.frame.height > 76.0 {
                bounds = CGRect(x: 0.0, y: selectedItemNode.frame.height - 76.0, width: selectedItemNode.frame.width, height: 76.0)
            } else {
                bounds = selectedItemNode.bounds
            }
            switch item.content {
                case let .peer(messages, peer, _, _, _, _, _, _, _, _, _, _):
                    return (selectedItemNode.view, bounds, messages.last?.id ?? peer.peerId)
                case let .groupReference(groupId, _, _, _, _):
                    return (selectedItemNode.view, bounds, groupId)
            }
        }
        return nil
    }
}
