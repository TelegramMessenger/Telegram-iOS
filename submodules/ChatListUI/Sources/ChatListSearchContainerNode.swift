import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ContactsPeerItem
import ChatListSearchItemHeader
import ContactListUI
import ContextUI
import PhoneNumberFormat
import ItemListUI
import SearchBarNode
import ListMessageItem
import TelegramBaseController
import OverlayStatusController
import UniversalMediaPlayer
import PresentationDataUtils
import AnimatedStickerNode
import AppBundle
import GalleryData
import InstantPageUI
import ChatInterfaceState
import ShareController

private final class PassthroughContainerNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let result = subnode.view.hitTest(self.view.convert(point, to: subnode.view), with: event) {
                    return result
                }
            }
        }
        return nil
    }
}

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
}

private enum ChatListTokenId: Int32 {
    case filter
    case peer
    case date
}

private enum ChatListRecentEntry: Comparable, Identifiable {
    case topPeers([Peer], PresentationTheme, PresentationStrings)
    case peer(index: Int, peer: RecentlySearchedPeer, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, Bool)
    
    var stableId: ChatListRecentEntryStableId {
        switch self {
            case .topPeers:
                return .topPeers
            case let .peer(_, peer, _, _, _, _, _, _):
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
            case let .peer(lhsIndex, lhsPeer, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder, lhsHasRevealControls):
                if case let .peer(rhsIndex, rhsPeer, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder, rhsHasRevealControls) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings && lhsTimeFormat == rhsTimeFormat && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsHasRevealControls == rhsHasRevealControls {
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
            case let .peer(lhsIndex, _, _, _, _, _, _, _):
                switch rhs {
                    case .topPeers:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _):
                        return lhsIndex <= rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, disaledPeerSelected: @escaping (Peer) -> Void, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ListViewItem {
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
            case let .peer(_, peer, theme, strings, timeFormat, nameSortOrder, nameDisplayOrder, hasRevealControls):
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
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: status, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: true, editing: false, revealed: hasRevealControls), index: nil, header: ChatListSearchItemHeader(type: .recentPeers, theme: theme, strings: strings, actionTitle: strings.WebSearch_RecentSectionClear, action: {
                    clearRecentlySearchedPeers()
                }), action: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        peerSelected(chatPeer)
                    }
                }, disabledAction: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        disaledPeerSelected(chatPeer)
                    }
                }, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer, contextAction: peerContextAction.flatMap { peerContextAction in
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
    
    public func item(context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (Peer) -> Void, searchResults: [Message], searchOptions: ChatListSearchOptions?, messageContextAction: ((Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)?) -> ListViewItem {
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
                if let tags = searchOptions?.messageTags, tags != .photoOrVideo {
                    return ListMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .builtin(WallpaperSettings())), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), context: context, chatLocation: .peer(peer.peerId), interaction: listInteraction, message: message, selection: selection, displayHeader: enableHeaders && !displayCustomHeader, customHeader: nil, hintIsLink: tags == .webPage, isGlobalSearchResult: true)
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
    public let query: String
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem], displayingResults: Bool, isEmpty: Bool, query: String) {
        self.deletions = deletions
        self.insertions = insertions
        self.updates = updates
        self.displayingResults = displayingResults
        self.isEmpty = isEmpty
        self.query = query
    }
}

private func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, disaledPeerSelected: @escaping (Peer) -> Void, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disaledPeerSelected: disaledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disaledPeerSelected: disaledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, isEmpty: Bool, searchQuery: String, context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (Peer) -> Void, searchResults: [Message], searchOptions: ChatListSearchOptions?, messageContextAction: ((Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)?) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchResults: searchResults, searchOptions: searchOptions, messageContextAction: messageContextAction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchResults: searchResults, searchOptions: searchOptions, messageContextAction: messageContextAction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults, isEmpty: isEmpty, query: searchQuery)
}

private struct ChatListSearchContainerNodeState: Equatable {
    let peerIdWithRevealedOptions: PeerId?
    
    
    init(peerIdWithRevealedOptions: PeerId? = nil) {
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
    }
    
    static func ==(lhs: ChatListSearchContainerNodeState, rhs: ChatListSearchContainerNodeState) -> Bool {
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        return true
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChatListSearchContainerNodeState {
        return ChatListSearchContainerNodeState(peerIdWithRevealedOptions: peerIdWithRevealedOptions)
    }
}

private struct ChatListSearchContainerNodeSearchState: Equatable {
    var expandLocalSearch: Bool = false
    var expandGlobalSearch: Bool = false
    var selectedMessageIds: Set<MessageId>?
    
    func withUpdatedSelectedMessageIds(_ selectedMessageIds: Set<MessageId>?) -> ChatListSearchContainerNodeSearchState {
        return ChatListSearchContainerNodeSearchState(expandLocalSearch: self.expandLocalSearch, expandGlobalSearch: self.expandGlobalSearch, selectedMessageIds: selectedMessageIds)
    }
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
    let peerId: PeerId?
    let peerName: String?
    let minDate: Int32?
    let maxDate: Int32?
    let messageTags: MessageTags?
    
    func withUpdatedPeerId(_ peerId: PeerId?, peerName: String?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peerId: peerId, peerName: peerName, minDate: self.minDate, maxDate: self.maxDate, messageTags: self.messageTags)
    }
    
    func withUpdatedMinDate(_ minDate: Int32?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peerId: self.peerId, peerName: self.peerName, minDate: minDate, maxDate: self.maxDate, messageTags: self.messageTags)
    }

    func withUpdatedMaxDate(_ maxDate: Int32?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peerId: self.peerId, peerName: self.peerName, minDate: self.minDate, maxDate: maxDate, messageTags: self.messageTags)
    }
    
    func withUpdatedMessageTags(_ messageTags: MessageTags?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peerId: self.peerId, peerName: self.peerName, minDate: self.minDate, maxDate: self.maxDate, messageTags: messageTags)
    }
}

public final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    private let peersFilter: ChatListNodePeersFilter
    private var interaction: ChatListNodeInteraction?
    private let openMessage: (Peer, MessageId) -> Void
    private let navigationController: NavigationController?
    
    let filterContainerNode: ChatListSearchFiltersContainerNode
    private var selectionPanelNode: ChatListSearchMessageSelectionPanelNode?
    private let recentListNode: ListView
    private let listNode: ListView
    private let mediaNode: ChatListSearchMediaNode
    private let dimNode: ASDisplayNode
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var present: ((ViewController, Any?) -> Void)?
    private var presentInGlobalOverlay: ((ViewController, Any?) -> Void)?
    
    private let activeActionDisposable = MetaDisposable()
    
    private let recentDisposable = MetaDisposable()
    private let updatedRecentPeersDisposable = MetaDisposable()
    
    private var searchQueryValue: String?
    private let searchQuery = Promise<String?>(nil)
    private var searchOptionsValue: ChatListSearchOptions?
    private let searchOptions = Promise<ChatListSearchOptions?>(nil)
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    private var stateValue = ChatListSearchContainerNodeState()
    private let statePromise: ValuePromise<ChatListSearchContainerNodeState>
    private var searchStateValue = ChatListSearchContainerNodeSearchState()
    private let searchStatePromise: ValuePromise<ChatListSearchContainerNodeSearchState>
    private let searchContextValue = Atomic<ChatListSearchMessagesContext?>(value: nil)
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override public var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var mediaStatusDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    private var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var mediaAccessoryPanelContainer: PassthroughContainerNode
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    private var dismissingPanel: ASDisplayNode?
    
    private let updatedSearchOptions: ((ChatListSearchOptions?, Bool) -> Void)?
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    private let emptyResultsAnimationNode: AnimatedStickerNode
    private var animationSize: CGSize = CGSize()
    
    public init(context: AccountContext, filter: ChatListNodePeersFilter, groupId: PeerGroupId, openPeer originalOpenPeer: @escaping (Peer, Bool) -> Void, openDisabledPeer: @escaping (Peer) -> Void, openRecentPeerOptions: @escaping (Peer) -> Void, openMessage originalOpenMessage: @escaping (Peer, MessageId) -> Void, addContact: ((String) -> Void)?, peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, present: @escaping (ViewController, Any?) -> Void, presentInGlobalOverlay: @escaping (ViewController, Any?) -> Void, navigationController: NavigationController?, updatedSearchOptions: ((ChatListSearchOptions?, Bool) -> Void)? = nil) {
        self.context = context
        self.peersFilter = filter
        self.dimNode = ASDisplayNode()
        self.navigationController = navigationController
        self.updatedSearchOptions = updatedSearchOptions
        
        self.present = present
        self.presentInGlobalOverlay = presentInGlobalOverlay
        
        self.openMessage = originalOpenMessage
    
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations))
        
        self.filterContainerNode = ChatListSearchFiltersContainerNode()
        
        self.recentListNode = ListView()
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        var openMediaMessageImpl: ((Message, ChatControllerInteractionOpenMessageMode) -> Void)?
        var messageContextActionImpl: ((Message, ASDisplayNode?, CGRect?, UIGestureRecognizer?) -> Void)?
        var toggleMessageSelectionImpl: ((MessageId, Bool) -> Void)?
        var transitionNodeImpl: ((MessageId, Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?)?
        var addToTransitionSurfaceImpl: ((UIView) -> Void)?
        
        self.mediaNode = ChatListSearchMediaNode(context: self.context, contentType: .photoOrVideo, openMessage: { message, mode in
            openMediaMessageImpl?(message, mode)
        }, messageContextAction: { message, sourceNode, sourceRect, gesture in
            messageContextActionImpl?(message, sourceNode, sourceRect, gesture)
        }, toggleMessageSelection: { messageId, selected in
            toggleMessageSelectionImpl?(messageId, selected)
        })
    
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        self.statePromise = ValuePromise(self.stateValue, ignoreRepeated: true)
        self.searchStatePromise = ValuePromise(self.searchStateValue, ignoreRepeated: true)
        
        self.mediaAccessoryPanelContainer = PassthroughContainerNode()
        self.mediaAccessoryPanelContainer.clipsToBounds = true
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
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
        
        self.dimNode.backgroundColor = filter.contains(.excludeRecent) ? UIColor.black.withAlphaComponent(0.5) : self.presentationData.theme.chatList.backgroundColor

        self.backgroundColor = filter.contains(.excludeRecent) ? nil : self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        self.addSubnode(self.mediaNode)
        
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
        self.recentListNode.isHidden = filter.contains(.excludeRecent)
            
        let currentRemotePeers = Atomic<([FoundPeer], [FoundPeer])?>(value: nil)
        let presentationDataPromise = self.presentationDataPromise
        let searchStatePromise = self.searchStatePromise
        let foundItems = combineLatest(self.searchQuery.get(), self.searchOptions.get())
        |> mapToSignal { query, options -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
            if query == nil && options == nil {
                let _ = currentRemotePeers.swap(nil)
                return .single(nil)
            }
            
            let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> take(1)
            
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
                if let peerId = options.peerId {
                    location = .peer(peerId: peerId, fromId: nil, tags: options.messageTags, topMsgId: nil, minDate: options.minDate, maxDate: options.maxDate)
                } else {
                    
                    location = .general(tags: options.messageTags, minDate: options.minDate, maxDate: options.maxDate)
                }
            } else {
                location = .general(tags: nil, minDate: nil, maxDate: nil)
            }
            
            let finalQuery = query ?? ""
            updateSearchContext { _ in
                return (nil, true)
            }
            let foundRemoteMessages: Signal<(([Message], [PeerId: CombinedPeerReadState], Int32), Bool), NoError>
            if filter.contains(.doNotSearchMessages) {
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
                    if let searchContext = searchContext {
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
            
            return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationDataPromise.get(), searchStatePromise.get(), resolvedMessage)
            |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationData, searchState, resolvedMessage -> ([ChatListSearchEntry], Bool)? in
                let isSearching = foundRemotePeers.2 || foundRemoteMessages.1
                var entries: [ChatListSearchEntry] = []
                var index = 0
                
                let _ = currentRemotePeers.swap((foundRemotePeers.0, foundRemotePeers.1))
                
                let filteredPeer:(Peer, Peer) -> Bool = { peer, accountPeer in
                    guard !filter.contains(.excludeSavedMessages) || peer.id != accountPeer.id else { return false }
                    guard !filter.contains(.excludeSecretChats) || peer.id.namespace != Namespaces.Peer.SecretChat else { return false }
                    guard !filter.contains(.onlyPrivateChats) || peer.id.namespace == Namespaces.Peer.CloudUser else { return false }
                    
                    if filter.contains(.onlyGroups) {
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
                    
                    if filter.contains(.onlyChannels) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            return true
                        } else {
                            return false
                        }
                    }
                    
                    if filter.contains(.excludeChannels) {
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
                
                let localExpandType: ChatListSearchSectionExpandType
                if let _ = options?.messageTags {
                    if totalNumberOfLocalPeers > 3 {
                        localExpandType = searchState.expandLocalSearch ? .collapse : .expand
                    } else {
                        localExpandType = .none
                    }
                } else {
                    localExpandType = .none
                }
                let globalExpandType: ChatListSearchSectionExpandType
                if totalNumberOfGlobalPeers > 3 {
                    globalExpandType = searchState.expandGlobalSearch ? .collapse : .expand
                } else {
                    globalExpandType = .none
                }
                
                if options?.messageTags != nil || options?.maxDate != nil || options?.peerId != nil {
                } else {
                    let lowercasedQuery = finalQuery.lowercased()
                    if lowercasedQuery.count > 1 && presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery) {
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
                    if let _ = options?.messageTags {
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
                        entries.append(.message(message, peer, foundRemoteMessages.0.1[message.id.peerId], presentationData, foundRemoteMessages.0.2, searchState.selectedMessageIds?.contains(message.id), headerId == firstHeaderId))
                        index += 1
                    }
                }
                
                if let _ = addContact, isViablePhoneNumber(finalQuery) {
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
        
        let openUrlImpl: (String) -> Void = { url in
            openUserGeneratedUrl(context: context, url: url, concealed: false, present: { c in
                present(c, nil)
            }, openResolved: { [weak self] resolved in
                context.sharedContext.openResolvedUrl(resolved, context: context, urlContext: .generic, navigationController: navigationController, openPeer: { peerId, navigation in
                    //                            self?.openPeer(peerId: peerId, navigation: navigation)
                }, sendFile: nil,
                   sendSticker: nil,
                   present: { c, a in
                    present(c, a)
                }, dismissInput: {
                    self?.dismissInput()
                }, contentContext: nil)
            })
        }
        
        openMediaMessageImpl = { [weak self] message, mode in
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                self?.dismissInput()
            }, present: { c, a in
                present(c, a)
            }, transitionNode: { messageId, media in
                return transitionNodeImpl?(messageId, media)
            }, addToTransitionSurface: { view in
                addToTransitionSurfaceImpl?(view)
            }, openUrl: { url in
               openUrlImpl(url)
            }, openPeer: { peer, navigation in
                //self?.openPeer(peerId: peer.id, navigation: navigation)
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, gallerySource: .custom(messages: foundMessages, messageId: message.id, loadMore: {
                loadMore()
            })))
        }
        
        messageContextActionImpl = { [weak self] message, sourceNode, sourceRect, gesture in
            if let strongSelf = self {
                strongSelf.messageContextActions(message, node: sourceNode, rect: sourceRect, gesture: gesture)
            }
        }
        
        toggleMessageSelectionImpl = { [weak self] messageId, selected in
            if let strongSelf = self {
                strongSelf.updateSearchState { state in
                    var selectedMessageIds = state.selectedMessageIds ?? Set()
                    if selected {
                        selectedMessageIds.insert(messageId)
                    } else {
                        selectedMessageIds.remove(messageId)
                    }
                    return state.withUpdatedSelectedMessageIds(selectedMessageIds)
                }
            }
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
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        
        let openPeer: (Peer, Bool) -> Void = { peer, value in
            originalOpenPeer(peer, value)
            
            if peer.id.namespace != Namespaces.Peer.SecretChat {
                addAppLogEvent(postbox: context.account.postbox, type: "search_global_open_peer", peerId: peer.id)
            }
        }
        
        let openMessage: (Peer, MessageId) -> Void = { peer, messageId in
            originalOpenMessage(peer, messageId)
            
            if peer.id.namespace != Namespaces.Peer.SecretChat {
                addAppLogEvent(postbox: context.account.postbox, type: "search_global_open_message", peerId: peer.id, data: .dictionary(["msg_id": .number(Double(messageId.id))]))
            }
        }
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { [weak self] peer, _ in
            self?.dismissInput()
            openPeer(peer, false)
            let _ = addRecentlySearchedPeer(postbox: context.account.postbox, peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, disabledPeerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            self?.dismissInput()
            if let peer = message.peers[message.id.peerId] {
                openMessage(peer, message.id)
            }
            self?.listNode.clearHighlightAnimated(true)
        }, groupSelected: { _ in 
        }, addContact: { [weak self] phoneNumber in
            self?.dismissInput()
            addContact?(phoneNumber)
            self?.listNode.clearHighlightAnimated(true)
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                        return state.withUpdatedPeerIdWithRevealedOptions(peerId)
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _, _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, hidePsa: { _ in
        }, activateChatPreview: { item, node, gesture in
            guard let peerContextAction = peerContextAction else {
                gesture?.cancel()
                return
            }
            switch item.content {
            case let .peer(peer):
                if let peer = peer.peer.peer {
                    peerContextAction(peer, .search, node, gesture)
                }
            case .groupReference:
                gesture?.cancel()
            }
        }, present: { c in
            present(c, nil)
        })
        self.interaction = interaction
        
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
        
        var recentItems = combineLatest(hasRecentPeers, fixedRecentlySearchedPeers, presentationDataPromise.get(), self.statePromise.get())
        |> mapToSignal { hasRecentPeers, peers, presentationData, state -> Signal<[ChatListRecentEntry], NoError> in
            var entries: [ChatListRecentEntry] = []
            if !filter.contains(.onlyGroups) {
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
                    if !doesPeerMatchFilter(peer: peer, filter: filter) {
                        continue
                    }
                    peerIds.insert(peer.id)
                    
                    entries.append(.peer(index: index, peer: searchedPeer, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameSortOrder, presentationData.nameDisplayOrder, state.peerIdWithRevealedOptions == peer.id))
                    index += 1
                }
            }
           
            return .single(entries)
        }
        
        if filter.contains(.excludeRecent) {
            recentItems = .single([])
        }
        
        self.updatedRecentPeersDisposable.set(managedUpdatedRecentPeers(accountPeerId: context.account.peerId, postbox: context.account.postbox, network: context.account.network).start())
        
        self.recentDisposable.set((combineLatest(queue: .mainQueue(),
            presentationDataPromise.get(),
            recentItems
        )
        |> deliverOnMainQueue).start(next: { [weak self] presentationData, entries in
            if let strongSelf = self {
                let previousEntries = previousRecentItems.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, context: context, presentationData: presentationData, filter: filter, peerSelected: { peer in
                    openPeer(peer, true)
                    let _ = addRecentlySearchedPeer(postbox: context.account.postbox, peerId: peer.id).start()
                    self?.recentListNode.clearHighlightAnimated(true)
                }, disaledPeerSelected: { peer in
                    openDisabledPeer(peer)
                }, peerContextAction: peerContextAction,
                clearRecentlySearchedPeers: {
                    self?.clearRecentSearch()
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, deletePeer: { peerId in
                    if let strongSelf = self {
                        let _ = removeRecentlySearchedPeer(postbox: strongSelf.context.account.postbox, peerId: peerId).start()
                    }
                })
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        let listInteraction = ListMessageItemInteraction(openMessage: { [weak self] message, mode -> Bool in
            self?.dismissInput()
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: { [weak self] in
                self?.dismissInput()
            }, present: { c, a in
                present(c, a)
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
                self?.view.addSubview(view)
            }, openUrl: { url in
                openUrlImpl(url)
            }, openPeer: { peer, navigation in
                //                                   self?.openPeer(peerId: peer.id, navigation: navigation)
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: .custom(messages: foundMessages, at: message.id, loadMore: {
                loadMore()
            }), gallerySource: .custom(messages: foundMessages, messageId: message.id, loadMore: {
                loadMore()
            })))
        }, openMessageContextMenu: { [weak self] message, bool, node, rect, gesture in
            self?.messageContextAction(message, node: node, rect: rect, gesture: gesture)
        }, toggleMessagesSelection: { messageId, selected in
            if let messageId = messageId.first {
                toggleMessageSelectionImpl?(messageId, selected)
            }
        }, openUrl: { url, _, _, message in
            openUrlImpl(url)
        }, openInstantPage: { message, data in
            if let (webpage, anchor) = instantPageAndAnchor(message: message) {
                let pageController = InstantPageController(context: context, webPage: webpage, sourcePeerType: .channel, anchor: anchor)
                navigationController?.pushViewController(pageController)
            }
        }, longTap: { action, message in
        }, getHiddenMedia: {
            return [:]
        })
        
        self.searchDisposable.set((foundItems
        |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags in
            if let strongSelf = self {
                let isSearching = entriesAndFlags?.1 ?? false
                strongSelf._isSearching.set(isSearching)
                
                if strongSelf.searchOptionsValue?.messageTags == .photoOrVideo {
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
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                let newEntries = entriesAndFlags?.0 ?? []
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: newEntries, displayingResults: entriesAndFlags?.0 != nil, isEmpty: !isSearching && (entriesAndFlags?.0.isEmpty ?? false), searchQuery: strongSelf.searchQueryValue ?? "", context: context, presentationData: strongSelf.presentationData, enableHeaders: true, filter: filter, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction,
                toggleExpandLocalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateSearchState { state in
                        var state = state
                        state.expandLocalSearch = !state.expandLocalSearch
                        return state
                    }
                }, toggleExpandGlobalResults: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateSearchState { state in
                        var state = state
                        state.expandGlobalSearch = !state.expandGlobalSearch
                        return state
                    }
                }, searchPeer: { peer in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateSearchOptions(strongSelf.currentSearchOptions.withUpdatedPeerId(peer.id, peerName: peer.compactDisplayTitle), clearQuery: true)
                    strongSelf.dismissInput?()
                }, searchResults: newEntries.compactMap { entry -> Message? in
                    if case let .message(message, _, _, _, _, _, _) = entry {
                        return message
                    } else {
                        return nil
                    }
                }, searchOptions: strongSelf.searchOptionsValue, messageContextAction: { message, node, rect, gesture in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.messageContextAction(message, node: node, rect: rect, gesture: gesture)
                })
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)))
                
                if previousTheme !== presentationData.theme {
                    strongSelf.updateTheme(theme: presentationData.theme)
                }
            }
        })
        
        self.recentListNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
        
        self.mediaNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
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
        
        self.filterContainerNode.filterPressed = { [weak self] filter in
            guard let strongSelf = self else {
                return
            }
            var messageTags: MessageTags? = strongSelf.currentSearchOptions.messageTags
            var maxDate: Int32? = strongSelf.currentSearchOptions.maxDate
            var peerId: PeerId? = strongSelf.currentSearchOptions.peerId
            var peerName: String? = strongSelf.currentSearchOptions.peerName
            var clearQuery: Bool = false
            switch filter {
                case .media:
                    messageTags = .photoOrVideo
                case .links:
                    messageTags = .webPage
                case .files:
                    messageTags = .file
                case .music:
                    messageTags = .music
                case .voice:
                    messageTags = .voiceOrInstantVideo
                case let .date(date, _):
                    maxDate = date
                    clearQuery = true
                case let .peer(id, name):
                    peerId = id
                    peerName = name
                    clearQuery = true
            }
            strongSelf.updateSearchOptions(strongSelf.currentSearchOptions.withUpdatedMessageTags(messageTags).withUpdatedMaxDate(maxDate).withUpdatedPeerId(peerId, peerName: peerName), clearQuery: clearQuery)
        }
        
        self.mediaStatusDisposable = (combineLatest(context.sharedContext.mediaManager.globalMediaPlayerState, self.searchOptions.get())
        |> mapToSignal { playlistStateAndType, searchOptions -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
            if let (account, state, type) = playlistStateAndType {
                switch state {
                    case let .state(state):
                        if let playlistId = state.playlistId as? PeerMessagesMediaPlaylistId, case .custom = playlistId {
                            if case .music = type, searchOptions?.messageTags == .music {
                                return .single((account, state, type))
                            } else if case .voice = type, searchOptions?.messageTags == .voiceOrInstantVideo {
                                return .single((account, state, type))
                            } else {
                                return .single(nil) |> delay(0.1, queue: .mainQueue())
                            }
                        } else {
                            return .single(nil) |> delay(0.1, queue: .mainQueue())
                    }
                    case .loading:
                        return .single(nil) |> delay(0.1, queue: .mainQueue())
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
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        })
    }
    
    deinit {
        self.activeActionDisposable.dispose()
        self.updatedRecentPeersDisposable.dispose()
        self.recentDisposable.dispose()
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
    }
    
    override public func didLoad() {
        super.didLoad()
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }

    private var currentSearchOptions: ChatListSearchOptions {
        return self.searchOptionsValue ?? ChatListSearchOptions(peerId: nil, peerName: nil, minDate: nil, maxDate: nil, messageTags: nil)
    }
    
    public override func searchTokensUpdated(tokens: [SearchBarToken]) {
        var updatedOptions = self.searchOptionsValue
        var tokensIdSet = Set<AnyHashable>()
        for token in tokens {
            tokensIdSet.insert(token.id)
        }
        if !tokensIdSet.contains(ChatListTokenId.filter.rawValue) && updatedOptions?.messageTags != nil {
            updatedOptions = updatedOptions?.withUpdatedMessageTags(nil)
        }
        if !tokensIdSet.contains(ChatListTokenId.date.rawValue) && updatedOptions?.maxDate != nil {
             updatedOptions = updatedOptions?.withUpdatedMaxDate(nil)
        }
        if !tokensIdSet.contains(ChatListTokenId.peer.rawValue) && updatedOptions?.peerId != nil {
             updatedOptions = updatedOptions?.withUpdatedPeerId(nil, peerName: nil)
        }
        self.updateSearchOptions(updatedOptions)
    }
    
    private func updateSearchOptions(_ options: ChatListSearchOptions?, clearQuery: Bool = false) {
        self.searchOptionsValue = options
        self.searchOptions.set(.single(options))
        
        var tokens: [SearchBarToken] = []
        if let messageTags = options?.messageTags {
            var title: String?
            var icon: UIImage?
            if messageTags == .photoOrVideo {
                title = self.presentationData.strings.ChatList_Search_FilterMedia
                icon = UIImage(bundleImageName: "Chat List/Search/Media")
            } else if messageTags == .webPage {
                title = self.presentationData.strings.ChatList_Search_FilterLinks
                icon = UIImage(bundleImageName: "Chat List/Search/Links")
            } else if messageTags == .file {
                title = self.presentationData.strings.ChatList_Search_FilterFiles
                icon = UIImage(bundleImageName: "Chat List/Search/Files")
            } else if messageTags == .music {
                title = self.presentationData.strings.ChatList_Search_FilterMusic
                icon = UIImage(bundleImageName: "Chat List/Search/Music")
            } else if messageTags == .voiceOrInstantVideo {
                title = self.presentationData.strings.ChatList_Search_FilterVoice
                icon = UIImage(bundleImageName: "Chat List/Search/Voice")
            }
            
            if let title = title {
                tokens.append(SearchBarToken(id: ChatListTokenId.filter.rawValue, icon: icon, title: title))
            }
        }
        
        if let _ = options?.peerId, let peerName = options?.peerName {
            tokens.append(SearchBarToken(id: ChatListTokenId.peer.rawValue, icon: UIImage(bundleImageName: "Chat List/Search/User"), title: peerName))
        }
        
        if let maxDate = options?.maxDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateStyle = .medium
            let title = formatter.string(from: Date(timeIntervalSince1970: Double(maxDate)))
            tokens.append(SearchBarToken(id: ChatListTokenId.date.rawValue, icon: UIImage(bundleImageName: "Chat List/Search/Calendar"), title: title))
            
            self.possibleDate = nil
        }
        
        if clearQuery {
            self.setQuery?(nil, tokens, "")
        } else {
            self.setQuery?(nil, tokens, self.searchQueryValue ?? "")
        }
        
        self.updatedSearchOptions?(options, self.possibleDate != nil)
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = self.peersFilter.contains(.excludeRecent) ? nil : theme.chatList.backgroundColor
        self.dimNode.backgroundColor = self.peersFilter.contains(.excludeRecent) ? UIColor.black.withAlphaComponent(0.5) : theme.chatList.backgroundColor
        self.recentListNode.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
        self.listNode.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
        
        self.listNode.forEachItemHeaderNode({ itemHeaderNode in
            if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                itemHeaderNode.updateTheme(theme: theme)
            }
        })
        self.recentListNode.forEachItemHeaderNode({ itemHeaderNode in
            if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                itemHeaderNode.updateTheme(theme: theme)
            }
        })
    }
    
    private func updateState(_ f: (ChatListSearchContainerNodeState) -> ChatListSearchContainerNodeState) {
        let state = f(self.stateValue)
        if state != self.stateValue {
            self.stateValue = state
            self.statePromise.set(state)
        }
    }
    
    private func updateSearchState(_ f: (ChatListSearchContainerNodeSearchState) -> ChatListSearchContainerNodeSearchState) {
        let state = f(self.searchStateValue)
        if state != self.searchStateValue {
            self.searchStateValue = state
            self.searchStatePromise.set(state)
        }
        self.mediaNode.selectedMessageIds = self.searchStateValue.selectedMessageIds
        self.mediaNode.updateSelectedMessages(animated: true)
        self.selectionPanelNode?.selectedMessages = self.searchStateValue.selectedMessageIds ?? []
    }
    
    var possibleDate: Date?
    override public func searchTextUpdated(text: String) {
        let searchQuery: String? = !text.isEmpty ? text : nil
        self.interaction?.searchTextHighightState = searchQuery
        self.searchQuery.set(.single(searchQuery))
        self.searchQueryValue = searchQuery
        
        let previousPossibleDate = self.possibleDate
        do {
            let dd = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            if let match = dd.firstMatch(in: text, options: [], range: NSMakeRange(0, text.utf16.count)) {
                self.possibleDate = match.date
            } else {
                self.possibleDate = nil
            }
        }
        catch {
            self.possibleDate = nil
        }
        
        if previousPossibleDate != self.possibleDate {
            self.updatedSearchOptions?(self.searchOptionsValue, self.possibleDate != nil)
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
        
        if text.isEmpty {
            self.updateSearchState { state in
                var state = state
                state.expandLocalSearch = false
                return state
            }
        }
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        self.enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
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
        
        if self.validLayout != nil {
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
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    let searchOptions = strongSelf.searchOptionsValue
                    strongSelf.listNode.isHidden = searchOptions?.messageTags == .photoOrVideo && (strongSelf.searchQueryValue ?? "").isEmpty
                    strongSelf.mediaNode.isHidden = !strongSelf.listNode.isHidden
                    if !displayingResults {
                        strongSelf.listNode.isHidden = true
                        strongSelf.mediaNode.isHidden = true
                    }
                    
                    let emptyResultsTitle: String
                    let emptyResultsText: String
                    if !transition.query.isEmpty {
                        emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                        emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(transition.query).0
                    } else {
                        if let searchOptions = searchOptions, searchOptions.messageTags != nil && searchOptions.minDate == nil && searchOptions.maxDate == nil && searchOptions.peerId == nil {
                            emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResultsFilter
                            if searchOptions.messageTags == .photoOrVideo {
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMedia
                            } else if searchOptions.messageTags == .webPage {
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerLinks
                            } else if searchOptions.messageTags == .file {
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerFiles
                            } else if searchOptions.messageTags == .music {
                                emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsFitlerMusic
                            } else if searchOptions.messageTags == .voiceOrInstantVideo {
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
                    
                    let emptyResults = displayingResults && transition.isEmpty
                    strongSelf.emptyResultsAnimationNode.isHidden = !emptyResults
                    strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                    strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                    strongSelf.emptyResultsAnimationNode.visibility = emptyResults
                    
                    strongSelf.recentListNode.isHidden = displayingResults || strongSelf.peersFilter.contains(.excludeRecent)
                    strongSelf.dimNode.isHidden = displayingResults
                    strongSelf.backgroundColor = !displayingResults && strongSelf.peersFilter.contains(.excludeRecent) ? nil : strongSelf.presentationData.theme.chatList.backgroundColor
                    
                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                }
            })
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        var topInset = navigationBarHeight
                
        var topPanelHeight: CGFloat = 0.0
        if let (item, previousItem, nextItem, order, type, _) = self.playlistStateAndType {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            topPanelHeight = panelHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
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
                    guard let strongSelf = self, let (state, _, _, order, type, account) = strongSelf.playlistStateAndType else {
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
                                self?.interaction?.present(controller)
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
                                    let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, isGlobalSearch: true, parentNavigationController: strongSelf.navigationController)
                                    strongSelf.dismissInput()
                                    strongSelf.interaction?.present(controller)
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
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate)
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
        
        transition.updateFrame(node: self.mediaAccessoryPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: MediaNavigationAccessoryHeaderNode.minimizedHeight)))
        topInset += topPanelHeight
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        transition.updateFrame(node: self.filterContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight + 6.0), size: CGSize(width: layout.size.width, height: 37.0)))
        
        let filters: [ChatListSearchFilter]
        if let possibleDate = self.possibleDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateStyle = .medium
            let title = formatter.string(from: possibleDate)
            filters = [.date(Int32(possibleDate.timeIntervalSince1970), title)]
        } else {
            filters = [.media, .links, .files, .music, .voice]
        }
        
        self.filterContainerNode.update(size: CGSize(width: layout.size.width, height: 37.0), sideInset: layout.safeInsets.left, filters: filters.map { .filter($0) }, presentationData: self.presentationData, transition: .animated(duration: 0.4, curve: .spring))
        
        
        if let selectedMessageIds = self.searchStateValue.selectedMessageIds {
            var wasAdded = false
            let selectionPanelNode: ChatListSearchMessageSelectionPanelNode
            if let current = self.selectionPanelNode {
                selectionPanelNode = current
            } else {
                wasAdded = true
                selectionPanelNode = ChatListSearchMessageSelectionPanelNode(context: self.context, deleteMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.deleteMessages(messageIds: nil)
                }, shareMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.searchStateValue.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                        var messages: [Message] = []
                        for id in messageIds {
                            if let message = transaction.getMessage(id) {
                                messages.append(message)
                            }
                        }
                        return messages
                    }
                    |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            })), externalShare: true, immediateExternalShare: true)
                            strongSelf.dismissInput()
                            strongSelf.present?(shareController, nil)
                        }
                    })
                }, forwardMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.forwardMessages(messageIds: nil)
                })
                self.selectionPanelNode = selectionPanelNode
                self.addSubnode(selectionPanelNode)
            }
            selectionPanelNode.selectedMessages = selectedMessageIds
            let panelHeight = selectionPanelNode.update(layout: layout, presentationData: self.presentationData, transition: wasAdded ? .immediate : transition)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if wasAdded {
                selectionPanelNode.frame = panelFrame
                transition.animatePositionAdditive(node: selectionPanelNode, offset: CGPoint(x: 0.0, y: panelHeight))
            } else {
                transition.updateFrame(node: selectionPanelNode, frame: panelFrame)
            }
        } else if let selectionPanelNode = self.selectionPanelNode {
            self.selectionPanelNode = nil
            transition.updateFrame(node: selectionPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: selectionPanelNode.bounds.size), completion: { [weak selectionPanelNode] _ in
                selectionPanelNode?.removeFromSupernode()
            })
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.mediaNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        self.mediaNode.update(size: layout.size, sideInset: layout.safeInsets.left, bottomInset: layout.insets(options: [.input]).bottom, visibleHeight: layout.size.height - navigationBarHeight, isScrollingLockedAtTop: false, expandProgress: 1.0, presentationData: self.presentationData, synchronous: true, transition: transition)
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let insets = layout.insets(options: [.input])
        let emptyAnimationSpacing: CGFloat = 8.0
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = self.animationSize.height + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyAnimationY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsAnimationNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - self.animationSize.width) / 2.0, y: emptyAnimationY), size: self.animationSize))
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyAnimationY + self.animationSize.height + emptyAnimationSpacing), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyAnimationY + self.animationSize.height + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
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
    
    override public func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
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
    
    private func clearRecentSearch() {
        let presentationData = self.presentationData
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.WebSearch_RecentSectionClear, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                guard let strongSelf = self else {
                    return
                }
                let _ = (clearRecentlySearchedPeers(postbox: strongSelf.context.account.postbox)
                |> deliverOnMainQueue).start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.dismissInput()
        self.interaction?.present(actionSheet)
    }
    
    override public func scrollToTop() {
        if !self.listNode.isHidden {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        } else {
            self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    func messageContextActions(_ message: Message, node: ASDisplayNode?, rect: CGRect?, gesture anyRecognizer: UIGestureRecognizer?) {
        let gesture: ContextGesture? = anyRecognizer as? ContextGesture
        let _ = (chatMediaListPreviewControllerData(context: self.context, chatLocation: .peer(message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: self.navigationController)
            |> deliverOnMainQueue).start(next: { [weak self] previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
//                    let items = chatAvailableMessageActionsImpl(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
//                        |> map { actions -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = []
                    
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        c.dismiss(completion: {
                            self?.openMessage(message.peers[message.id.peerId]!, message.id)
                        })
                    })))
                    
                    items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        c.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.forwardMessages(messageIds: [message.id])
                            }
                        })
                    })))
                    
                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuMore, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        if let strongSelf = self {
                            strongSelf.dismissInput()
                            
                            strongSelf.updateSearchState { state in
                                return state.withUpdatedSelectedMessageIds([message.id])
                            }
                            
                            if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                            }
                        }
                        
                        f(.default)
                    })))
                    
                    switch previewData {
                        case let .gallery(gallery):
                            gallery.setHintWillBePresentedInPreviewingContext(true)
                            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
                            strongSelf.presentInGlobalOverlay?(contextController, nil)
                        case .instantPage:
                            break
                    }
                }
            })
    }
    
    func messageContextAction(_ message: Message, node: ASDisplayNode?, rect: CGRect?, gesture anyRecognizer: UIGestureRecognizer?) {
        guard let node = node as? ContextExtractedContentContainingNode else {
            return
        }
        let _ = storedMessageFromSearch(account: self.context.account, message: message).start()
        
        var linkForCopying: String?
        var currentSupernode: ASDisplayNode? = node
        while true {
            if currentSupernode == nil {
                break
            } else if let currentSupernode = currentSupernode as? ListMessageSnippetItemNode {
                linkForCopying = currentSupernode.currentPrimaryUrl
                break
            } else {
                currentSupernode = currentSupernode?.supernode
            }
        }
        
        let gesture: ContextGesture? = anyRecognizer as? ContextGesture
        var items: [ContextMenuItem] = []
        
        if let linkForCopying = linkForCopying {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c.dismiss(completion: {})
                UIPasteboard.general.string = linkForCopying
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c.dismiss(completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.forwardMessages(messageIds: Set([message.id]))
                }
            })
        })))
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c.dismiss(completion: { [weak self] in
                self?.openMessage(message.peers[message.id.peerId]!, message.id)
            })
        })))
        
        items.append(.separator)
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuMore, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c.dismiss(completion: {
                if let strongSelf = self {
                    strongSelf.dismissInput()
                    
                    strongSelf.updateSearchState { state in
                        return state.withUpdatedSelectedMessageIds([message.id])
                    }
                    
                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                }
            })
        })))
        
        let controller = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(items), reactionItems: [], recognizer: nil, gesture: gesture)
        self.presentInGlobalOverlay?(controller, nil)
    }
    
    public override func searchTextClearTokens() {
        self.updateSearchOptions(nil)
        self.setQuery?(nil, [], self.searchQueryValue ?? "")
    }
    func deleteMessages(messageIds: Set<MessageId>?) {
        let messageIds = messageIds ?? self.searchStateValue.selectedMessageIds
    }
    
    func forwardMessages(messageIds: Set<MessageId>?) {
        let messageIds = messageIds ?? self.searchStateValue.selectedMessageIds
        if let messageIds = messageIds, !messageIds.isEmpty {
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.onlyWriteable, .excludeDisabled]))
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peerId in
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, grouping: .auto, attributes: [])
                        })
                        |> deliverOnMainQueue).start(next: { [weak self] messageIds in
                            if let strongSelf = self {
                                let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                    guard let id = id else {
                                        return nil
                                    }
                                    return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                        |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                            if status != nil {
                                                return .never()
                                            } else {
                                                return .single(true)
                                            }
                                        }
                                        |> take(1)
                                })
                                strongSelf.activeActionDisposable.set((combineLatest(signals)
                                    |> deliverOnMainQueue).start(completed: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.present?(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), nil)
                                    }))
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }
                        
                        strongSelf.updateSearchState { state in
                            return state.withUpdatedSelectedMessageIds(nil)
                        }
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    } else {
                        let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                            transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                if let currentState = currentState as? ChatInterfaceState {
                                    return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                                } else {
                                    return ChatInterfaceState().withUpdatedForwardMessageIds(Array(messageIds))
                                }
                            })
                        }) |> deliverOnMainQueue).start(completed: {
                            if let strongSelf = self {
//                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)

                                let controller = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
                                strongSelf.navigationController?.pushViewController(controller, animated: false, completion: {
                                    if let peerSelectionController = peerSelectionController {
                                        peerSelectionController.dismiss()
                                    }
                                })
                                
                                strongSelf.updateSearchState { state in
                                    return state.withUpdatedSelectedMessageIds(nil)
                                }
                                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                }
                            }
                        })
                    }
                }
            }
            self.navigationController?.pushViewController(peerSelectionController)
        }
    }
    
    private func dismissInput() {
        self.view.window?.endEditing(true)
    }
}

private final class MessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode) {
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        self.controller.didAppearInContextPreview()
    }
}
