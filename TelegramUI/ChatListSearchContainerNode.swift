import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(PeerId)
    
    static func ==(lhs: ChatListRecentEntryStableId, rhs: ChatListRecentEntryStableId) -> Bool {
        switch lhs {
            case .topPeers:
                if case .topPeers = rhs {
                    return true
                } else {
                    return false
            }
            case let .peerId(peerId):
                if case .peerId(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .topPeers:
                return 0
            case let .peerId(peerId):
                return peerId.hashValue
        }
    }
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
    
    func item(account: Account, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, peerLongTapped: @escaping (Peer) -> Void, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ListViewItem {
        switch self {
            case let .topPeers(peers, theme, strings):
                return ChatListRecentPeersListItem(theme: theme, strings: strings, account: account, peers: peers, peerSelected: { peer in
                    peerSelected(peer)
                }, peerLongTapped: { peer in
                    peerLongTapped(peer)
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
                
                let status: ContactsPeerItemStatus
                if let user = primaryPeer as? TelegramUser {
                    if let _ = user.botInfo {
                        status = .custom(strings.Bot_GenericBotStatus)
                    } else if user.id != account.peerId {
                        let presence = peer.presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
                        status = .presence(presence, timeFormat)
                    } else {
                        status = .none
                    }
                } else if let group = primaryPeer as? TelegramGroup {
                    status = .custom(strings.GroupInfo_ParticipantCount(Int32(group.participantCount)))
                } else if let channel = primaryPeer as? TelegramChannel {
                    if case .group = channel.info {
                        if let count = peer.subpeerSummary?.count {
                            status = .custom(strings.GroupInfo_ParticipantCount(Int32(count)))
                        } else {
                            status = .custom(strings.Group_Status)
                        }
                    } else {
                        if let count = peer.subpeerSummary?.count {
                            status = .custom(strings.Conversation_StatusSubscribers(Int32(count)))
                        } else {
                            status = .custom(strings.Channel_Status)
                        }
                    }
                } else {
                    status = .none
                }
                
                var isMuted = false
                if let notificationSettings = peer.notificationSettings {
                    isMuted = notificationSettings.isRemovedFromTotalUnreadCount
                }
                var badge: ContactsPeerItemBadge?
                if peer.unreadCount > 0 {
                    badge = ContactsPeerItemBadge(count: peer.unreadCount, type: isMuted ? .inactive : .active)
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: status, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: true, editing: false, revealed: hasRevealControls), index: nil, header: ChatListSearchItemHeader(type: .recentPeers, theme: theme, strings: strings, actionTitle: strings.WebSearch_RecentSectionClear.uppercased(), action: {
                    clearRecentlySearchedPeers()
                }), action: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        peerSelected(chatPeer)
                    }
                }, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer)
        }
    }
}

enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(PeerId)
    case globalPeerId(PeerId)
    case messageId(MessageId)
    case addContact
    
    static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
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
    
    var hashValue: Int {
        switch self {
            case let .localPeerId(peerId):
                return peerId.hashValue
            case let .globalPeerId(peerId):
                return peerId.hashValue
            case let .messageId(messageId):
                return messageId.hashValue
            case .addContact:
                return 0
        }
    }
}


enum ChatListSearchEntry: Comparable, Identifiable {
    case localPeer(Peer, Peer?, UnreadSearchBadge?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder)
    case globalPeer(FoundPeer, UnreadSearchBadge?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder)
    case message(Message, CombinedPeerReadState?, ChatListPresentationData)
    case addContact(String, PresentationTheme, PresentationStrings)
    
    var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .localPeer(peer, _, _, _, _, _, _, _):
                return .localPeerId(peer.id)
            case let .globalPeer(peer, _, _, _, _, _, _):
                return .globalPeerId(peer.peer.id)
            case let .message(message, _, _):
                return .messageId(message.id)
            case .addContact:
                return .addContact
        }
    }
    
    static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder):
                if case let .localPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder) = rhs, lhsPeer.isEqual(rhsPeer) && arePeersEqual(lhsAssociatedPeer, rhsAssociatedPeer) && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge == rhsUnreadBadge {
                    return true
                } else {
                    return false
                }
            case let .globalPeer(lhsPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder):
                if case let .globalPeer(rhsPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder) = rhs, lhsPeer == rhsPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge == rhsUnreadBadge {
                    return true
                } else {
                    return false
                }
            case let .message(lhsMessage, lhsCombinedPeerReadState, lhsPresentationData):
                if case let .message(rhsMessage, rhsCombinedPeerReadState, rhsPresentationData) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsCombinedPeerReadState != rhsCombinedPeerReadState {
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
        
    static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .localPeer(_, _, _, lhsIndex, _, _, _, _):
                if case let .localPeer(_, _, _, rhsIndex, _, _, _, _) = rhs {
                    return lhsIndex <= rhsIndex
                } else {
                    return true
                }
            case let .globalPeer(_, _, lhsIndex, _, _, _, _):
                switch rhs {
                    case .localPeer:
                        return false
                    case let .globalPeer(_, _, rhsIndex, _, _, _, _):
                        return lhsIndex <= rhsIndex
                    case .message, .addContact:
                        return true
                }
            case let .message(lhsMessage, _, _):
                if case let .message(rhsMessage, _, _) = rhs {
                    return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
                } else if case .addContact = rhs {
                    return true
                } else {
                    return false
                }
            case .addContact:
                return false
        }
    }
    
    func item(account: Account, enableHeaders: Bool, filter: ChatListNodePeersFilter, interaction: ChatListNodeInteraction) -> ListViewItem {
        switch self {
            case let .localPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder):
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
                    badge = ContactsPeerItemBadge(count: unreadBadge.count, type: unreadBadge.isMuted ? .inactive : .active)
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: .none, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .localPeers, theme: theme, strings: strings, actionTitle: nil, action: nil), action: { _ in
                    interaction.peerSelected(peer)
                })
            case let .globalPeer(peer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder):
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
                    badge = ContactsPeerItemBadge(count: unreadBadge.count, type: unreadBadge.isMuted ? .inactive : .active)
                }
                
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .generalSearch, peer: .peer(peer: peer.peer, chatPeer: peer.peer), status: .addressName(suffixString), badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: ChatListSearchItemHeader(type: .globalPeers, theme: theme, strings: strings, actionTitle: nil, action: nil), action: { _ in
                    interaction.peerSelected(peer.peer)
                })
            case let .message(message, readState, presentationData):
                return ChatListItem(presentationData: presentationData, account: account, peerGroupId: nil, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(message)), content: .peer(message: message, peer: RenderedPeer(message: message), combinedReadState: readState, notificationSettings: nil, summaryInfo: ChatListMessageTagSummaryInfo(), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: true), editing: false, hasActiveRevealControls: false, header: enableHeaders ? ChatListSearchItemHeader(type: .messages, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil) : nil, enableContextActions: false, interaction: interaction)
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

struct ChatListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let displayingResults: Bool
}

private func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], account: Account, filter: ChatListNodePeersFilter, peerSelected: @escaping (Peer) -> Void, peerLongTapped: @escaping (Peer) -> Void, clearRecentlySearchedPeers: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, deletePeer: @escaping (PeerId) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, filter: filter, peerSelected: peerSelected, peerLongTapped: peerLongTapped, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, filter: filter, peerSelected: peerSelected, peerLongTapped: peerLongTapped, clearRecentlySearchedPeers: clearRecentlySearchedPeers, setPeerIdWithRevealedOptions: setPeerIdWithRevealedOptions, deletePeer: deletePeer), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, account: Account, enableHeaders: Bool, filter: ChatListNodePeersFilter, interaction: ChatListNodeInteraction) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, filter: filter, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, enableHeaders: enableHeaders, filter: filter, interaction: interaction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults)
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

final class ChatListSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    
    private let recentListNode: ListView
    private let listNode: ListView
    private let dimNode: ASDisplayNode
    private var enqueuedRecentTransitions: [(ChatListSearchContainerRecentTransition, Bool)] = []
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var validLayout: ContainerViewLayout?
    
    private let recentDisposable = MetaDisposable()
    private let updatedRecentPeersDisposable = MetaDisposable()
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    private var stateValue = ChatListSearchContainerNodeState()
    private let statePromise: ValuePromise<ChatListSearchContainerNodeState>
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private let filter: ChatListNodePeersFilter
    
    init(account: Account, filter: ChatListNodePeersFilter, groupId: PeerGroupId?, openPeer: @escaping (Peer, Bool) -> Void, openRecentPeerOptions: @escaping (Peer) -> Void, openMessage: @escaping (Peer, MessageId) -> Void, addContact: ((String) -> Void)?) {
        self.account = account
        self.filter = filter
        self.dimNode = ASDisplayNode()
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations))
        
        self.recentListNode = ListView()
        self.listNode = ListView()
        
        self.statePromise = ValuePromise(self.stateValue, ignoreRepeated: true)
        
        super.init()
        
        self.dimNode.backgroundColor = filter.contains(.excludeRecent) ? UIColor.black.withAlphaComponent(0.5) : self.presentationData.theme.chatList.backgroundColor

        
        self.backgroundColor = filter.contains(.excludeRecent) ? nil : self.presentationData.theme.chatList.backgroundColor

        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        self.recentListNode.isHidden = filter.contains(.excludeRecent)
    
        let presentationDataPromise = self.presentationDataPromise
        let foundItems = searchQuery.get()
            |> mapToSignal { query -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
                if let query = query, !query.isEmpty {
                    let accountPeer = account.postbox.loadedPeerWithId(account.peerId)
                    |> take(1)
                    
                    let foundLocalPeers = account.postbox.searchPeers(query: query.lowercased(), groupId: groupId)
                    |> mapToSignal { local -> Signal<([PeerView], [RenderedPeer]), NoError> in
                        return combineLatest(local.map {account.postbox.peerView(id: $0.peerId)}) |> map { views in
                            return (views, local)
                        }
                    }
                    |> mapToSignal{ viewsAndPeers -> Signal<(peers: [RenderedPeer], unread: [PeerId : UnreadSearchBadge]), NoError> in
                        return account.postbox.unreadMessageCountsView(items: viewsAndPeers.0.map {.peer($0.peerId)}) |> map { values in
                            var unread:[PeerId: UnreadSearchBadge] = [:]
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
                                    unread[peerView.peerId] = isMuted ? .muted(unreadCount) : .unmuted(unreadCount)
                                }
                            }
                            return (peers: viewsAndPeers.1, unread: unread)
                        }
                    }
                    
                    let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], Bool), NoError>
                    if groupId == nil {
                        foundRemotePeers = (.single(([], [], true)) |> then(searchPeers(account: account, query: query) |> map { ($0.0, $0.1, false) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())))
                    } else {
                        foundRemotePeers = .single(([], [], false))
                    }
                    let location: SearchMessagesLocation
                    if let groupId = groupId {
                        location = .group(groupId)
                    } else {
                        location = .general
                    }
                    
                    let foundRemoteMessages: Signal<(([Message], [PeerId : CombinedPeerReadState], Int32), Bool), NoError>
                    if filter.contains(.doNotSearchMessages) {
                        foundRemoteMessages = .single((([], [:], 0), false))
                    } else {
                        foundRemoteMessages = .single((([], [:], 0), true)) |> then(searchMessages(account: account, location: location, query: query)
                            |> map { ($0, false) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue()))
                    }
                    
                    
                    
                    return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationDataPromise.get())
                        |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationData -> ([ChatListSearchEntry], Bool)? in
                            var entries: [ChatListSearchEntry] = []
                            let isSearching = foundRemotePeers.2 || foundRemoteMessages.1
                            var index = 0
                            
                            
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
                                
                                return true
                            }
                            
                            var existingPeerIds = Set<PeerId>()
                            
                            if presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(query.lowercased()) {
                                if !existingPeerIds.contains(accountPeer.id), filteredPeer(accountPeer, accountPeer) {
                                    existingPeerIds.insert(accountPeer.id)
                                    entries.append(.localPeer(accountPeer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                                    index += 1
                                }
                            }
                            
                            for renderedPeer in foundLocalPeers.peers {
                                if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != account.peerId, filteredPeer(peer, accountPeer) {
                                    if !existingPeerIds.contains(peer.id) {
                                        existingPeerIds.insert(peer.id)
                                        var associatedPeer: Peer?
                                        if let associatedPeerId = peer.associatedPeerId {
                                            associatedPeer = renderedPeer.peers[associatedPeerId]
                                        }
                                        entries.append(.localPeer(peer, associatedPeer, foundLocalPeers.unread[peer.id], index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                                        index += 1
                                    }
                                }
                            }
                            
                            for peer in foundRemotePeers.0 {
                                if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                                    existingPeerIds.insert(peer.peer.id)
                                    entries.append(.localPeer(peer.peer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                                    index += 1
                                }
                            }

                            index = 0
                            for peer in foundRemotePeers.1 {
                                if !existingPeerIds.contains(peer.peer.id), filteredPeer(peer.peer, accountPeer) {
                                    existingPeerIds.insert(peer.peer.id)
                                    entries.append(.globalPeer(peer, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                                    index += 1
                                }
                            }
                            
                            if !foundRemotePeers.2 {
                                index = 0
                                for message in foundRemoteMessages.0.0 {
                                    entries.append(.message(message, foundRemoteMessages.0.1[message.id.peerId], presentationData))
                                    index += 1
                                }
                            }
                            
                            if addContact != nil && isViablePhoneNumber(query) {
                                entries.append(.addContact(query, presentationData.theme, presentationData.strings))
                            }
                            
                            return (entries, isSearching)
                        }
                } else {
                    return .single(nil)
                }
            }
        
        let previousSearchItems = Atomic<[ChatListSearchEntry]?>(value: nil)
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { [weak self] peer in
            openPeer(peer, false)
            let _ = addRecentlySearchedPeer(postbox: account.postbox, peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, messageSelected: { [weak self] message, _ in
            if let peer = message.peers[message.id.peerId] {
                openMessage(peer, message.id)
            }
            self?.listNode.clearHighlightAnimated(true)
        }, groupSelected: { _ in 
        }, addContact: { [weak self] phoneNumber in
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
        }, deletePeer: { _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        })
        
        let previousRecentItems = Atomic<[ChatListRecentEntry]?>(value: nil)
        let hasRecentPeers = recentPeers(account: account)
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
        let fixedRecentlySearchedPeers = recentlySearchedPeers(postbox: account.postbox)
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
        
        var recentItemsTransition = combineLatest(hasRecentPeers, fixedRecentlySearchedPeers, presentationDataPromise.get(), self.statePromise.get())
            |> mapToSignal { [weak self] hasRecentPeers, peers, presentationData, state -> Signal<(ChatListSearchContainerRecentTransition, Bool), NoError> in
                var entries: [ChatListRecentEntry] = []
                if !filter.contains(.onlyGroups) {
                    if groupId == nil, hasRecentPeers {
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
                let previousEntries = previousRecentItems.swap(entries)
                
                let transition = chatListSearchContainerPreparedRecentTransition(from: previousEntries ?? [], to: entries, account: account, filter: filter, peerSelected: { peer in
                    openPeer(peer, true)
                    let _ = addRecentlySearchedPeer(postbox: account.postbox, peerId: peer.id).start()
                    self?.recentListNode.clearHighlightAnimated(true)
                }, peerLongTapped: { peer in
                    openRecentPeerOptions(peer)
                }, clearRecentlySearchedPeers: {
                    self?.clearRecentSearch()
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    interaction.setPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, deletePeer: { peerId in
                    if let strongSelf = self {
                        let _ = removeRecentlySearchedPeer(postbox: strongSelf.account.postbox, peerId: peerId).start()
                    }
                })
                return .single((transition, previousEntries == nil))
        }
        
        if filter.contains(.excludeRecent) {
            recentItemsTransition = .single((ChatListSearchContainerRecentTransition(deletions: [], insertions: [], updates: []), true))
        }
        
        self.updatedRecentPeersDisposable.set(managedUpdatedRecentPeers(accountPeerId: account.peerId, postbox: account.postbox, network: account.network).start())
        
        self.recentDisposable.set((recentItemsTransition |> deliverOnMainQueue).start(next: { [weak self] (transition, firstTime) in
            if let strongSelf = self {
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.searchDisposable.set((foundItems
            |> deliverOnMainQueue).start(next: { [weak self] entriesAndFlags in
                if let strongSelf = self {
                    strongSelf._isSearching.set(entriesAndFlags?.1 ?? false)
                    
                    let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                    
                    let firstTime = previousEntries == nil
                    let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entriesAndFlags?.0 ?? [], displayingResults: entriesAndFlags?.0 != nil, account: account, enableHeaders: true, filter: filter, interaction: interaction)
                    strongSelf.enqueueTransition(transition, firstTime: firstTime)
                }
            }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    //let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
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
    }
    
    override func didLoad() {
        super.didLoad()
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    deinit {
        self.updatedRecentPeersDisposable.dispose()
        self.recentDisposable.dispose()
        self.searchDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateTheme(theme: PresentationTheme) {
        self.backgroundColor = theme.chatList.backgroundColor
    }
    
    private func updateState(_ f: (ChatListSearchContainerNodeState) -> ChatListSearchContainerNodeState) {
        let state = f(self.stateValue)
        if state != self.stateValue {
            self.stateValue = state
            self.statePromise.set(state)
        }
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    private func enqueueRecentTransition(_ transition: ChatListSearchContainerRecentTransition, firstTime: Bool) {
        enqueuedRecentTransitions.append((transition, firstTime))
        
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
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            if firstTime {
            } else {
                //options.insert(.AnimateAlpha)
            }
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.listNode.isHidden = !displayingResults
                    strongSelf.recentListNode.isHidden = displayingResults || strongSelf.filter.contains(.excludeRecent)
                    strongSelf.dimNode.isHidden = displayingResults
                    strongSelf.backgroundColor = !displayingResults && strongSelf.filter.contains(.excludeRecent) ? nil : strongSelf.presentationData.theme.chatList.backgroundColor

                }
            })
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.validLayout != nil
        self.validLayout = layout
        
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                case .easeInOut:
                    break
                case .spring:
                    curve = 7
                }
        }
        
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        self.recentListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentListNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    override func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, Any)? {
        var selectedItemNode: ASDisplayNode?
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
                return (result.0, result.1)
            }
        } else if let selectedItemNode = selectedItemNode as? ContactsPeerItemNode, let peer = selectedItemNode.chatPeer {
            return (selectedItemNode.view, peer.id)
        } else if let selectedItemNode = selectedItemNode as? ChatListItemNode, let item = selectedItemNode.item {
            switch item.content {
                case let .peer(message, peer, _, _, _, _, _, _, _):
                    return (selectedItemNode.view, message?.id ?? peer.peerId)
                case let .groupReference(groupId, _, _, _):
                    return (selectedItemNode.view, groupId)
            }
        }
        return nil
    }
    
    private func clearRecentSearch() {
        let _ = (clearRecentlySearchedPeers(postbox: self.account.postbox) |> deliverOnMainQueue).start()
    }
    
    func removePeerFromTopPeers(_ peerId: PeerId) {
        self.recentListNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListRecentPeersListItemNode {
                itemNode.removePeer(peerId)
            }
        }
    }
}
