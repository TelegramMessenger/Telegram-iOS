import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
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
import TelegramAnimatedStickerNode
import ChatListSearchItemHeader
import PhoneNumberFormat
import InstantPageUI
import GalleryData
import AppBundle
import ShimmerEffect
import ChatListSearchRecentPeersNode
import UndoUI
import Postbox
import FetchManagerImpl

private enum ChatListRecentEntryStableId: Hashable {
    case topPeers
    case peerId(EnginePeer.Id)
}

private enum ChatListRecentEntry: Comparable, Identifiable {
    case topPeers([EnginePeer], PresentationTheme, PresentationStrings)
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
                    if lhsPeers != rhsPeers {
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
    
    func item(context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (EnginePeer) -> Void, disabledPeerSelected: @escaping (EnginePeer) -> Void, peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, deletePeer: @escaping (EnginePeer.Id) -> Void) -> ListViewItem {
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
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
                let maybeChatPeer = EnginePeer(peer.peer.peers[peer.peer.peerId]!)
                if let associatedPeerId = maybeChatPeer._asPeer().associatedPeerId, let associatedPeer = peer.peer.peers[associatedPeerId] {
                    primaryPeer = EnginePeer(associatedPeer)
                    chatPeer = maybeChatPeer
                } else {
                    primaryPeer = maybeChatPeer
                    chatPeer = maybeChatPeer
                }
                
                var enabled = true
                if filter.contains(.onlyWriteable) {
                    if let peer = chatPeer {
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = canSendMessagesToPeer(primaryPeer._asPeer())
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
                        switch peer {
                        case .user, .secretChat:
                            break
                        default:
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
                        } else {
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                
                if filter.contains(.excludeChannels) {
                    if case let .channel(channel) = primaryPeer, case .broadcast = channel.info {
                        enabled = false
                    }
                }
                
                let status: ContactsPeerItemStatus
                if primaryPeer.id.isReplies {
                    status = .none
                } else if case let .user(user) = primaryPeer {
                    let servicePeer = isServicePeer(primaryPeer._asPeer())
                    if user.flags.contains(.isSupport) && !servicePeer {
                        status = .custom(string: strings.Bot_GenericSupportStatus, multiline: false)
                    } else if let _ = user.botInfo {
                        status = .custom(string: strings.Bot_GenericBotStatus, multiline: false)
                    } else if user.id != context.account.peerId && !servicePeer {
                        let presence = peer.presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
                        status = .presence(EnginePeer.Presence(presence), timeFormat)
                    } else {
                        status = .none
                    }
                } else if case let .legacyGroup(group) = primaryPeer {
                    status = .custom(string: strings.GroupInfo_ParticipantCount(Int32(group.participantCount)), multiline: false)
                } else if case let .channel(channel) = primaryPeer {
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
                        peerSelected(EnginePeer(chatPeer))
                    }
                }, disabledAction: { _ in
                    if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                        disabledPeerSelected(EnginePeer(chatPeer))
                    }
                }, deletePeer: deletePeer, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        if let chatPeer = peer.peer.peers[peer.peer.peerId] {
                            peerContextAction(EnginePeer(chatPeer), .recentSearch, node, gesture)
                        } else {
                            gesture?.cancel()
                        }
                    }
                })
        }
    }
}

public enum ChatListSearchEntryStableId: Hashable {
    case localPeerId(EnginePeer.Id)
    case globalPeerId(EnginePeer.Id)
    case messageId(EngineMessage.Id, ChatListSearchEntry.MessageSection)
    case addContact
}

public enum ChatListSearchSectionExpandType {
    case none
    case expand
    case collapse
}

public enum ChatListSearchEntry: Comparable, Identifiable {
    public enum MessageOrderingKey: Comparable {
        case index(MessageIndex)
        case downloading(FetchManagerPriorityKey)
        case downloaded(timestamp: Int32, index: MessageIndex)
        
        public static func <(lhs: MessageOrderingKey, rhs: MessageOrderingKey) -> Bool {
            switch lhs {
            case let .index(lhsIndex):
                if case let .index(rhsIndex) = rhs {
                    return lhsIndex > rhsIndex
                } else {
                    return true
                }
            case let .downloading(lhsKey):
                switch rhs {
                case let .downloading(rhsKey):
                    return lhsKey < rhsKey
                case .index:
                    return false
                case .downloaded:
                    return true
                }
            case let .downloaded(lhsTimestamp, lhsIndex):
                switch rhs {
                case let .downloaded(rhsTimestamp, rhsIndex):
                    if lhsTimestamp != rhsTimestamp {
                        return lhsTimestamp > rhsTimestamp
                    } else {
                        return lhsIndex > rhsIndex
                    }
                case .downloading:
                    return false
                case .index:
                    return false
                }
            }
        }
    }
    
    public enum MessageSection: Hashable {
        case generic
        case downloading
        case recentlyDownloaded
    }
    
    case recentlySearchedPeer(EnginePeer, EnginePeer?, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder)
    case localPeer(EnginePeer, EnginePeer?, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType)
    case globalPeer(FoundPeer, (Int32, Bool)?, Int, PresentationTheme, PresentationStrings, PresentationPersonNameOrder, PresentationPersonNameOrder, ChatListSearchSectionExpandType)
    case message(EngineMessage, EngineRenderedPeer, EnginePeerReadCounters?, ChatListPresentationData, Int32, Bool?, Bool, MessageOrderingKey, (id: String, size: Int64, isFirstInList: Bool)?, MessageSection, Bool)
    case addContact(String, PresentationTheme, PresentationStrings)
    
    public var stableId: ChatListSearchEntryStableId {
        switch self {
        case let .recentlySearchedPeer(peer, _, _, _, _, _, _, _):
            return .localPeerId(peer.id)
        case let .localPeer(peer, _, _, _, _, _, _, _, _):
            return .localPeerId(peer.id)
        case let .globalPeer(peer, _, _, _, _, _, _, _):
            return .globalPeerId(peer.peer.id)
        case let .message(message, _, _, _, _, _, _, _, _, section, _):
            return .messageId(message.id, section)
        case .addContact:
            return .addContact
        }
    }
    
    public static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
        case let .recentlySearchedPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder):
            if case let .recentlySearchedPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder) = rhs, lhsPeer == rhsPeer && lhsAssociatedPeer == rhsAssociatedPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 {
                return true
            } else {
                return false
            }
        case let .localPeer(lhsPeer, lhsAssociatedPeer, lhsUnreadBadge, lhsIndex, lhsTheme, lhsStrings, lhsSortOrder, lhsDisplayOrder, lhsExpandType):
            if case let .localPeer(rhsPeer, rhsAssociatedPeer, rhsUnreadBadge, rhsIndex, rhsTheme, rhsStrings, rhsSortOrder, rhsDisplayOrder, rhsExpandType) = rhs, lhsPeer == rhsPeer && lhsAssociatedPeer == rhsAssociatedPeer && lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsStrings === rhsStrings && lhsSortOrder == rhsSortOrder && lhsDisplayOrder == rhsDisplayOrder && lhsUnreadBadge?.0 == rhsUnreadBadge?.0 && lhsUnreadBadge?.1 == rhsUnreadBadge?.1 && lhsExpandType == rhsExpandType {
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
        case let .message(lhsMessage, lhsPeer, lhsCombinedPeerReadState, lhsPresentationData, lhsTotalCount, lhsSelected, lhsDisplayCustomHeader, lhsKey, lhsResourceId, lhsSection, lhsAllPaused):
            if case let .message(rhsMessage, rhsPeer, rhsCombinedPeerReadState, rhsPresentationData, rhsTotalCount, rhsSelected, rhsDisplayCustomHeader, rhsKey, rhsResourceId, rhsSection, rhsAllPaused) = rhs {
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
                if lhsKey != rhsKey {
                    return false
                }
                if lhsResourceId?.0 != rhsResourceId?.0 {
                    return false
                }
                if lhsResourceId?.1 != rhsResourceId?.1 {
                    return false
                }
                if lhsSection != rhsSection {
                    return false
                }
                if lhsAllPaused != rhsAllPaused {
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
        case let .recentlySearchedPeer(_, _, _, lhsIndex, _, _, _, _):
            if case let .recentlySearchedPeer(_, _, _, rhsIndex, _, _, _, _) = rhs {
                return lhsIndex <= rhsIndex
            } else {
                return true
            }
        case let .localPeer(_, _, _, lhsIndex, _, _, _, _, _):
            switch rhs {
            case .recentlySearchedPeer:
                return false
            case let .localPeer(_, _, _, rhsIndex, _, _, _, _, _):
                return lhsIndex <= rhsIndex
            case .globalPeer, .message, .addContact:
                return true
            }
        case let .globalPeer(_, _, lhsIndex, _, _, _, _, _):
            switch rhs {
            case .recentlySearchedPeer, .localPeer:
                return false
            case let .globalPeer(_, _, rhsIndex, _, _, _, _, _):
                return lhsIndex <= rhsIndex
            case .message, .addContact:
                return true
            }
        case let .message(_, _, _, _, _, _, _, lhsKey, _, _, _):
            if case let .message(_, _, _, _, _, _, _, rhsKey, _, _, _) = rhs {
                return lhsKey < rhsKey
            } else if case .addContact = rhs {
                return true
            } else {
                return false
            }
        case .addContact:
            return false
        }
    }
    
    public func item(context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, key: ChatListSearchPaneKey, tagMask: EngineMessage.Tags?, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (EnginePeer) -> Void, searchQuery: String?, searchOptions: ChatListSearchOptions?, messageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int64, isFirstInList: Bool)?) -> Void)?, openClearRecentlyDownloaded: @escaping () -> Void, toggleAllPaused: @escaping () -> Void) -> ListViewItem {
        switch self {
            case let .recentlySearchedPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder):
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
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
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
                        switch peer {
                        case .user, .secretChat:
                            break
                        default:
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
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
                    let headerType: ChatListSearchItemHeaderType
                    if filter.contains(.onlyGroups) {
                        headerType = .chats
                    } else {
                        headerType = .recentPeers
                    }
                    header = ChatListSearchItemHeader(type: headerType, theme: theme, strings: strings, actionTitle: nil, action: nil)
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: .none, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { contactPeer in
                    if case let .peer(maybePeer, maybeChatPeer) = contactPeer, let peer = maybePeer, let chatPeer = maybeChatPeer {
                        interaction.peerSelected(chatPeer, peer, nil)
                    } else {
                        interaction.peerSelected(peer, nil, nil)
                    }
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        if let chatPeer = chatPeer, chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .search(nil), node, gesture)
                        } else {
                            gesture?.cancel()
                        }
                    }
                }, arrowAction: nil)
            case let .localPeer(peer, associatedPeer, unreadBadge, _, theme, strings, nameSortOrder, nameDisplayOrder, expandType):
                let primaryPeer: EnginePeer
                var chatPeer: EnginePeer?
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
                        enabled = canSendMessagesToPeer(peer._asPeer())
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyPrivateChats) {
                    if let peer = chatPeer {
                        switch peer {
                        case .user, .secretChat:
                            break
                        default:
                            enabled = false
                        }
                    } else {
                        enabled = false
                    }
                }
                if filter.contains(.onlyGroups) {
                    if let peer = chatPeer {
                        if case .legacyGroup = peer {
                        } else if case let .channel(peer) = peer, case .group = peer.info {
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
                    let headerType: ChatListSearchItemHeaderType
                    if filter.contains(.onlyGroups) {
                        headerType = .chats
                    } else {
                        headerType = .localPeers
                    }
                    header = ChatListSearchItemHeader(type: headerType, theme: theme, strings: strings, actionTitle: actionTitle, action: actionTitle == nil ? nil : {
                        toggleExpandLocalResults()
                    })
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: primaryPeer, chatPeer: chatPeer), status: .none, badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { contactPeer in
                    if case let .peer(maybePeer, maybeChatPeer) = contactPeer, let peer = maybePeer, let chatPeer = maybeChatPeer {
                        interaction.peerSelected(chatPeer, peer, nil)
                    } else {
                        interaction.peerSelected(peer, nil, nil)
                    }
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        if let chatPeer = chatPeer, chatPeer.id.namespace != Namespaces.Peer.SecretChat {
                            peerContextAction(chatPeer, .search(nil), node, gesture)
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
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: .generalSearch, peer: .peer(peer: EnginePeer(peer.peer), chatPeer: EnginePeer(peer.peer)), status: .addressName(suffixString), badge: badge, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction.peerSelected(EnginePeer(peer.peer), nil, nil)
                }, contextAction: peerContextAction.flatMap { peerContextAction in
                    return { node, gesture in
                        peerContextAction(EnginePeer(peer.peer), .search(nil), node, gesture)
                    }
                })
            case let .message(message, peer, readState, presentationData, _, selected, displayCustomHeader, orderingKey, _, _, allPaused):
                let header: ChatListSearchItemHeader
                switch orderingKey {
                case .downloading:
                    if allPaused {
                        header = ChatListSearchItemHeader(type: .downloading, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_ResumeAll, action: {
                            toggleAllPaused()
                        })
                    } else {
                        header = ChatListSearchItemHeader(type: .downloading, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_PauseAll, action: {
                            toggleAllPaused()
                        })
                    }
                case .downloaded:
                    header = ChatListSearchItemHeader(type: .recentDownloads, theme: presentationData.theme, strings: presentationData.strings, actionTitle: presentationData.strings.DownloadList_Clear, action: {
                        openClearRecentlyDownloaded()
                    })
                case .index:
                    header = ChatListSearchItemHeader(type: .messages, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                }
                let selection: ChatHistoryMessageSelection = selected.flatMap { .selectable(selected: $0) } ?? .none
                var isMedia = false
                if let tagMask = tagMask, tagMask != .photoOrVideo {
                    isMedia = true
                } else if key == .downloads {
                    isMedia = true
                }
                if isMedia {
                    return ListMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: .builtin(WallpaperSettings())), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), context: context, chatLocation: .peer(id: peer.peerId), interaction: listInteraction, message: message._asMessage(), selection: selection, displayHeader: enableHeaders && !displayCustomHeader, customHeader: key == .downloads ? header : nil, hintIsLink: tagMask == .webPage, isGlobalSearchResult: key != .downloads, isDownloadList: key == .downloads)
                } else {
                    return ChatListItem(presentationData: presentationData, context: context, peerGroupId: .root, filterData: nil, index: EngineChatList.Item.Index(pinningIndex: nil, messageIndex: message.index), content: .peer(messages: [message], peer: peer, combinedReadState: readState, isRemovedFromTotalUnreadCount: false, presence: nil, hasUnseenMentions: false, hasUnseenReactions: false, draftState: nil, inputActivities: nil, promoInfo: nil, ignoreUnreadBadge: true, displayAsMessage: false, hasFailedMessages: false), editing: false, hasActiveRevealControls: false, selected: false, header: tagMask == nil ? header : nil, enableContextActions: false, hiddenOffset: false, interaction: interaction)
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
    public let query: String?
    public var animated: Bool
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem], displayingResults: Bool, isEmpty: Bool, isLoading: Bool, query: String?, animated: Bool) {
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

private func chatListSearchContainerPreparedRecentTransition(from fromEntries: [ChatListRecentEntry], to toEntries: [ChatListRecentEntry], context: AccountContext, presentationData: ChatListPresentationData, filter: ChatListNodePeersFilter, peerSelected: @escaping (EnginePeer) -> Void, disabledPeerSelected: @escaping (EnginePeer) -> Void, peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, clearRecentlySearchedPeers: @escaping () -> Void, deletePeer: @escaping (EnginePeer.Id) -> Void) -> ChatListSearchContainerRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, filter: filter, peerSelected: peerSelected, disabledPeerSelected: disabledPeerSelected, peerContextAction: peerContextAction, clearRecentlySearchedPeers: clearRecentlySearchedPeers, deletePeer: deletePeer), directionHint: nil) }
    
    return ChatListSearchContainerRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], displayingResults: Bool, isEmpty: Bool, isLoading: Bool, animated: Bool, context: AccountContext, presentationData: PresentationData, enableHeaders: Bool, filter: ChatListNodePeersFilter, key: ChatListSearchPaneKey, tagMask: EngineMessage.Tags?, interaction: ChatListNodeInteraction, listInteraction: ListMessageItemInteraction, peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?, toggleExpandLocalResults: @escaping () -> Void, toggleExpandGlobalResults: @escaping () -> Void, searchPeer: @escaping (EnginePeer) -> Void, searchQuery: String?, searchOptions: ChatListSearchOptions?, messageContextAction: ((EngineMessage, ASDisplayNode?, CGRect?, UIGestureRecognizer?, ChatListSearchPaneKey, (id: String, size: Int64, isFirstInList: Bool)?) -> Void)?, openClearRecentlyDownloaded: @escaping () -> Void, toggleAllPaused: @escaping () -> Void) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, key: key, tagMask: tagMask, interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchQuery: searchQuery, searchOptions: searchOptions, messageContextAction: messageContextAction, openClearRecentlyDownloaded: openClearRecentlyDownloaded, toggleAllPaused: toggleAllPaused), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, enableHeaders: enableHeaders, filter: filter, key: key, tagMask: tagMask,  interaction: interaction, listInteraction: listInteraction, peerContextAction: peerContextAction, toggleExpandLocalResults: toggleExpandLocalResults, toggleExpandGlobalResults: toggleExpandGlobalResults, searchPeer: searchPeer, searchQuery: searchQuery, searchOptions: searchOptions, messageContextAction: messageContextAction, openClearRecentlyDownloaded: openClearRecentlyDownloaded, toggleAllPaused: toggleAllPaused), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, displayingResults: displayingResults, isEmpty: isEmpty, isLoading: isLoading, query: searchQuery, animated: animated)
}

private struct ChatListSearchListPaneNodeState: Equatable {
    var expandLocalSearch: Bool = false
    var expandGlobalSearch: Bool = false
    var deletedMessageIds = Set<EngineMessage.Id>()
    var deletedGlobalMessageIds = Set<Int32>()
}

private func doesPeerMatchFilter(peer: EnginePeer, filter: ChatListNodePeersFilter) -> Bool {
    var enabled = true
    if filter.contains(.onlyWriteable), !canSendMessagesToPeer(peer._asPeer()) {
        enabled = false
    }
    if filter.contains(.onlyPrivateChats) {
        switch peer {
        case .user, .secretChat:
            break
        default:
            enabled = false
        }
    }
    if filter.contains(.onlyGroups) {
        if case .legacyGroup = peer {
        } else if case let .channel(peer) = peer, case .group = peer.info {
        } else {
            enabled = false
        }
    }
    return enabled
}

private struct ChatListSearchMessagesResult {
    let query: String
    let messages: [EngineMessage]
    let readStates: [EnginePeer.Id: EnginePeerReadCounters]
    let hasMore: Bool
    let totalCount: Int32
    let state: SearchMessagesState
}

private struct ChatListSearchMessagesContext {
    let result: ChatListSearchMessagesResult
    let loadMoreIndex: EngineMessage.Index?
}

public enum ChatListSearchContextActionSource {
    case recentPeers
    case recentSearch
    case search(EngineMessage.Id?)
}

public struct ChatListSearchOptions {
    let peer: (EnginePeer.Id, Bool, String)?
    let date: (Int32?, Int32, String)?
    
    var isEmpty: Bool {
        return self.peer == nil && self.date == nil
    }
    
    func withUpdatedPeer(_ peerIdIsGroupAndName: (EnginePeer.Id, Bool, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: peerIdIsGroupAndName, date: self.date)
    }
    
    func withUpdatedDate(_ minDateMaxDateAndTitle: (Int32?, Int32, String)?) -> ChatListSearchOptions {
        return ChatListSearchOptions(peer: self.peer, date: minDateMaxDateAndTitle)
    }
}

private struct DownloadItem: Equatable {
    let resourceId: MediaResourceId
    let message: EngineMessage
    let priority: FetchManagerPriorityKey
    let isPaused: Bool
    
    static func ==(lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        if lhs.resourceId != rhs.resourceId {
            return false
        }
        if lhs.message.id != rhs.message.id {
            return false
        }
        if lhs.priority != rhs.priority {
            return false
        }
        if lhs.isPaused != rhs.isPaused {
            return false
        }
        return true
    }
}

final class ChatListSearchListPaneNode: ASDisplayNode, ChatListSearchPaneNode {
    private let context: AccountContext
    private let interaction: ChatListSearchInteraction
    private let peersFilter: ChatListNodePeersFilter
    private var presentationData: PresentationData
    private let key: ChatListSearchPaneKey
    private let tagMask: EngineMessage.Tags?
    private let groupId: EngineChatList.Group?
    private let navigationController: NavigationController?
    
    private let recentListNode: ListView
    private let shimmerNode: ChatListSearchShimmerNode
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
    var searchCurrentMessages: [EngineMessage]?
    var currentEntries: [ChatListSearchEntry]?
    
    private var deletedMessagesDisposable: Disposable?
    
    private var searchQueryValue: String?
    private var searchOptionsValue: ChatListSearchOptions?
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var mediaStatusDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    private var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var playlistLocation: SharedMediaPlaylistLocation?
    
    private var mediaAccessoryPanelContainer: PassthroughContainerNode
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    private var dismissingPanel: ASDisplayNode?
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    private let emptyResultsAnimationNode: AnimatedStickerNode
    private var emptyResultsAnimationSize: CGSize = CGSize()
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
        
    private let selectedMessagesPromise = Promise<Set<EngineMessage.Id>?>(nil)
    private var selectedMessages: Set<EngineMessage.Id>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private var hiddenMediaDisposable: Disposable?
  
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, interaction: ChatListSearchInteraction, key: ChatListSearchPaneKey, peersFilter: ChatListNodePeersFilter, groupId: EngineChatList.Group?, searchQuery: Signal<String?, NoError>, searchOptions: Signal<ChatListSearchOptions?, NoError>, navigationController: NavigationController?) {
        self.context = context
        self.interaction = interaction
        self.key = key
        self.peersFilter = peersFilter
        self.groupId = groupId
        self.navigationController = navigationController
        
        let tagMask: EngineMessage.Tags?
        switch key {
            case .chats:
                tagMask = nil
            case .media:
                tagMask = .photoOrVideo
            case .downloads:
                tagMask = nil
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
        
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)))
        
        self.searchStatePromise.set(self.searchStateValue)
        self.selectedMessages = interaction.getSelectedMessageIds()
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        self.recentListNode = ListView()
        self.recentListNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.recentListNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.shimmerNode = ChatListSearchShimmerNode(key: key)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
            
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
    
        var openMediaMessageImpl: ((EngineMessage, ChatControllerInteractionOpenMessageMode) -> Void)?
        var transitionNodeImpl: ((EngineMessage.Id, EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?)?
        var addToTransitionSurfaceImpl: ((UIView) -> Void)?
        
        self.mediaNode = ChatListSearchMediaNode(context: self.context, contentType: .photoOrVideo, openMessage: { message, mode in
            openMediaMessageImpl?(EngineMessage(message), mode)
        }, messageContextAction: { message, node, rect, gesture in
            interaction.mediaMessageContextAction(EngineMessage(message), node, rect, gesture)
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
             
        self.emptyResultsAnimationNode = DefaultAnimatedStickerNodeImpl()
        self.emptyResultsAnimationNode.isHidden = true
        
        super.init()
                
        self.emptyResultsAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "ChatListNoResults"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        self.emptyResultsAnimationSize = CGSize(width: 148.0, height: 148.0)
        
        self.addSubnode(self.recentListNode)
        self.addSubnode(self.listNode)
        self.addSubnode(self.mediaNode)
        
        self.addSubnode(self.emptyResultsAnimationNode)
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)

        self.addSubnode(self.shimmerNode)
        self.addSubnode(self.mediaAccessoryPanelContainer)
        
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
        
        let previousRecentlySearchedPeerOrder = Atomic<[EnginePeer.Id]>(value: [])
        let fixedRecentlySearchedPeers: Signal<[RecentlySearchedPeer], NoError>
        if case .chats = key {
            fixedRecentlySearchedPeers = context.engine.peers.recentlySearchedPeers()
            |> map { peers -> [RecentlySearchedPeer] in
                var result: [RecentlySearchedPeer] = []
                let _ = previousRecentlySearchedPeerOrder.modify { current in
                    var updated: [EnginePeer.Id] = []
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
        } else {
            fixedRecentlySearchedPeers = .single([])
        }
            
        let downloadItems: Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError>
        if key == .downloads {
            var firstTime = true
            downloadItems = combineLatest(queue: .mainQueue(), (context.fetchManager as! FetchManagerImpl).entriesSummary, recentDownloadItems(postbox: context.account.postbox))
            |> mapToSignal { entries, recentDownloadItems -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
                var itemSignals: [Signal<DownloadItem?, NoError>] = []
                
                for entry in entries {
                    switch entry.id.locationKey {
                    case let .messageId(id):
                        itemSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
                        |> map { message -> DownloadItem? in
                            if let message = message {
                                return DownloadItem(resourceId: entry.resourceReference.resource.id, message: message, priority: entry.priority, isPaused: entry.isPaused)
                            }
                            return nil
                        })
                    default:
                        break
                    }
                }
                
                return combineLatest(queue: .mainQueue(), itemSignals)
                |> map { items -> (inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]) in
                    return (items.compactMap { $0 }, recentDownloadItems)
                }
                |> mapToSignal { value -> Signal<(inProgressItems: [DownloadItem], doneItems: [RenderedRecentDownloadItem]), NoError> in
                    if firstTime {
                        firstTime = false
                        return .single(value)
                    } else {
                        return .single(value)
                        |> delay(0.1, queue: .mainQueue())
                    }
                }
            }
        } else {
            downloadItems = .single(([], []))
        }
        
        struct SearchedPeersState {
            var ids: [EnginePeer.Id] = []
            var query: String?
        }
        let previousRecentlySearchedPeersState = Atomic<SearchedPeersState?>(value: nil)
        
        let foundItems = combineLatest(queue: .mainQueue(), searchQuery, searchOptions, downloadItems)
        |> mapToSignal { [weak self] query, options, downloadItems -> Signal<([ChatListSearchEntry], Bool)?, NoError> in
            if query == nil && options == nil && key == .chats {
                let _ = currentRemotePeers.swap(nil)
                return .single(nil)
            }
            
            if key == .downloads {
                let queryTokens = stringIndexTokens(query ?? "", transliteration: .combined)
                
                func messageMatchesTokens(message: EngineMessage, tokens: [ValueBoxKey]) -> Bool {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            if let fileName = file.fileName {
                                if matchStringIndexTokens(stringIndexTokens(fileName, transliteration: .none), with: tokens) {
                                    return true
                                }
                            }
                        } else if let _ = media as? TelegramMediaImage {
                            if matchStringIndexTokens(stringIndexTokens("Photo Image", transliteration: .none), with: tokens) {
                                return true
                            }
                        }
                    }
                    return false
                }
                
                return combineLatest(queue: .mainQueue(), presentationDataPromise.get(), selectionPromise.get())
                |> map { presentationData, selectionState -> ([ChatListSearchEntry], Bool)? in
                    var entries: [ChatListSearchEntry] = []
                    var existingMessageIds = Set<MessageId>()
                    
                    var allPaused = true
                    for item in downloadItems.inProgressItems {
                        if !item.isPaused {
                            allPaused = false
                            break
                        }
                    }
                    
                    for item in downloadItems.inProgressItems.sorted(by: { $0.priority < $1.priority }) {
                        if existingMessageIds.contains(item.message.id) {
                            continue
                        }
                        existingMessageIds.insert(item.message.id)
                        
                        let message = item.message
                        
                        if !queryTokens.isEmpty {
                            if !messageMatchesTokens(message: message, tokens: queryTokens) {
                                continue
                            }
                        }
                        
                        var peer = EngineRenderedPeer(message: message)
                        if let group = item.message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                            }
                        }
                        
                        var resource: (id: String, size: Int64, isFirstInList: Bool)?
                        if let resourceValue = findMediaResourceById(message: item.message, resourceId: item.resourceId), let size = resourceValue.size {
                            resource = (resourceValue.id.stringRepresentation, size, entries.isEmpty)
                        }
                        
                        entries.append(.message(message, peer, nil, presentationData, 1, nil, false, .downloading(item.priority), resource, .downloading, allPaused))
                    }
                    for item in downloadItems.doneItems.sorted(by: { ChatListSearchEntry.MessageOrderingKey.downloaded(timestamp: $0.timestamp, index: $0.message.index) < ChatListSearchEntry.MessageOrderingKey.downloaded(timestamp: $1.timestamp, index: $1.message.index) }) {
                        if !item.isSeen {
                            Queue.mainQueue().async {
                                self?.scheduleMarkRecentDownloadsAsSeen()
                            }
                        }
                        if existingMessageIds.contains(item.message.id) {
                            continue
                        }
                        existingMessageIds.insert(item.message.id)
                        
                        let message = EngineMessage(item.message)
                        
                        if !queryTokens.isEmpty {
                            if !messageMatchesTokens(message: message, tokens: queryTokens) {
                                continue
                            }
                        }
                        
                        var peer = EngineRenderedPeer(message: message)
                        if let group = item.message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                            }
                        }
                        
                        entries.append(.message(message, peer, nil, presentationData, 1, selectionState?.contains(message.id), false, .downloaded(timestamp: item.timestamp, index: message.index), (item.resourceId, item.size, false), .recentlyDownloaded, false))
                    }
                    return (entries.sorted(), false)
                }
            }
            
            let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId) |> take(1)
            let foundLocalPeers: Signal<(peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>), NoError>
            if let query = query, case .chats = key {
                let fixedOrRemovedRecentlySearchedPeers = context.engine.peers.recentlySearchedPeers()
                |> map { peers -> [RecentlySearchedPeer] in
                    let allIds = peers.map(\.peer.peerId)
                    
                    let updatedState = previousRecentlySearchedPeersState.modify { current in
                        if var current = current, current.query == query {
                            current.ids = current.ids.filter { id in
                                allIds.contains(id)
                            }
                            
                            return current
                        } else {
                            var state = SearchedPeersState()
                            state.ids = allIds
                            state.query = query
                            return state
                        }
                    }
                    
                    var result: [RecentlySearchedPeer] = []
                    if let updatedState = updatedState {
                        for id in updatedState.ids {
                            for peer in peers {
                                if id == peer.peer.peerId {
                                    result.append(peer)
                                }
                            }
                        }
                    }
                    
                    return result
                }
                
                foundLocalPeers = combineLatest(
                    context.engine.contacts.searchLocalPeers(query: query.lowercased()),
                    fixedOrRemovedRecentlySearchedPeers
                )
                |> mapToSignal { local, allRecentlySearched -> Signal<([EnginePeer.Id: Optional<EnginePeer.NotificationSettings>], [EnginePeer.Id: Int], [EngineRenderedPeer], Set<EnginePeer.Id>), NoError> in
                    let recentlySearched = allRecentlySearched.filter { peer in
                        guard let peer = peer.peer.peer else {
                            return false
                        }
                        return peer.indexName.matchesByTokens(query)
                    }
                    
                    var peerIds = Set<EnginePeer.Id>()
                    
                    var peers: [EngineRenderedPeer] = []
                    for peer in recentlySearched {
                        if !peerIds.contains(peer.peer.peerId) {
                            peerIds.insert(peer.peer.peerId)
                            peers.append(EngineRenderedPeer(peer.peer))
                        }
                    }
                    for peer in local {
                        if !peerIds.contains(peer.peerId) {
                            peerIds.insert(peer.peerId)
                            peers.append(peer)
                        }
                    }
                    
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.NotificationSettings in
                                return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                            }
                        ),
                        EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerUnreadCount in
                                return TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId)
                            }
                        )
                    )
                    |> map { notificationSettings, unreadCounts in
                        return (notificationSettings, unreadCounts, peers, Set(recentlySearched.map(\.peer.peerId)))
                    }
                }
                |> map { notificationSettings, unreadCounts, peers, recentlySearchedPeerIds -> (peers: [EngineRenderedPeer], unread: [EnginePeer.Id: (Int32, Bool)], recentlySearchedPeerIds: Set<EnginePeer.Id>) in
                    var unread: [EnginePeer.Id: (Int32, Bool)] = [:]
                    for peer in peers {
                        var isMuted: Bool = false
                        if let nofiticationSettings = notificationSettings[peer.peerId] {
                            switch nofiticationSettings?.muteState {
                            case .muted:
                                isMuted = true
                            default:
                                break
                            }
                        }

                        let unreadCount = unreadCounts[peer.peerId]
                        if let unreadCount = unreadCount, unreadCount > 0 {
                            unread[peer.peerId] = (Int32(unreadCount), isMuted)
                        }
                    }
                    return (peers: peers, unread: unread, recentlySearchedPeerIds: recentlySearchedPeerIds)
                }
            } else {
                foundLocalPeers = .single((peers: [], unread: [:], recentlySearchedPeerIds: Set()))
                
                let _ = previousRecentlySearchedPeersState.swap(nil)
            }
            
            let foundRemotePeers: Signal<([FoundPeer], [FoundPeer], Bool), NoError>
            let currentRemotePeersValue: ([FoundPeer], [FoundPeer]) = currentRemotePeers.with { $0 } ?? ([], [])
            if let query = query, tagMask == nil {
                foundRemotePeers = (
                    .single((currentRemotePeersValue.0, currentRemotePeersValue.1, true))
                    |> then(
                        context.engine.contacts.searchRemotePeers(query: query)
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
                    location = .peer(peerId: peerId, fromId: nil, tags: tagMask, topMsgId: nil, minDate: options.date?.0, maxDate: options.date?.1)
                } else {
                    if let groupId = groupId {
                        location = .group(groupId: groupId._asGroup(), tags: tagMask, minDate: options.date?.0, maxDate: options.date?.1)
                    } else {
                        location = .general(tags: tagMask, minDate: options.date?.0, maxDate: options.date?.1)
                    }
                }
            } else {
                if let groupId = groupId {
                    location = .group(groupId: groupId._asGroup(), tags: tagMask, minDate: nil, maxDate: nil)
                } else {
                    location = .general(tags: tagMask, minDate: nil, maxDate: nil)
                }
            }
            
            let finalQuery = query ?? ""
            updateSearchContext { _ in
                return (nil, true)
            }
            let foundRemoteMessages: Signal<(([EngineMessage], [EnginePeer.Id: EnginePeerReadCounters], Int32), Bool), NoError>
            if peersFilter.contains(.doNotSearchMessages) {
                foundRemoteMessages = .single((([], [:], 0), false))
            } else {
                if !finalQuery.isEmpty {
                    addAppLogEvent(postbox: context.account.postbox, type: "search_global_query")
                }
                
                let searchSignal = context.engine.messages.searchMessages(location: location, query: finalQuery, state: nil, limit: 50)
                |> map { result, updatedState -> ChatListSearchMessagesResult in
                    return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.readStates.mapValues(EnginePeerReadCounters.init), hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                }
                
                let loadMore = searchContext.get()
                |> mapToSignal { searchContext -> Signal<(([EngineMessage], [EnginePeer.Id: EnginePeerReadCounters], Int32), Bool), NoError> in
                    if let searchContext = searchContext, searchContext.result.hasMore {
                        if let _ = searchContext.loadMoreIndex {
                            return context.engine.messages.searchMessages(location: location, query: finalQuery, state: searchContext.result.state, limit: 80)
                            |> map { result, updatedState -> ChatListSearchMessagesResult in
                                return ChatListSearchMessagesResult(query: finalQuery, messages: result.messages.map({ EngineMessage($0) }).sorted(by: { $0.index > $1.index }), readStates: result.readStates.mapValues(EnginePeerReadCounters.init), hasMore: !result.completed, totalCount: result.totalCount, state: updatedState)
                            }
                            |> mapToSignal { foundMessages -> Signal<(([EngineMessage], [EnginePeer.Id: EnginePeerReadCounters], Int32), Bool), NoError> in
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
                    |> map { foundMessages -> (([EngineMessage], [EnginePeer.Id: EnginePeerReadCounters], Int32), Bool) in
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
            |> then(context.sharedContext.resolveUrl(context: context, peerId: nil, url: finalQuery, skipUrlAuth: true)
            |> mapToSignal { resolvedUrl -> Signal<EngineMessage?, NoError> in
                if case let .channelMessage(_, messageId, _) = resolvedUrl {
                    return context.engine.messages.downloadMessage(messageId: messageId)
                    |> map { message -> EngineMessage? in
                        return message.flatMap(EngineMessage.init)
                    }
                } else {
                    return .single(nil)
                }
            })
            
            return combineLatest(accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationDataPromise.get(), searchStatePromise.get(), selectionPromise.get(), resolvedMessage, fixedRecentlySearchedPeers)
            |> map { accountPeer, foundLocalPeers, foundRemotePeers, foundRemoteMessages, presentationData, searchState, selectionState, resolvedMessage, recentPeers -> ([ChatListSearchEntry], Bool)? in
                let isSearching = foundRemotePeers.2 || foundRemoteMessages.1
                var entries: [ChatListSearchEntry] = []
                var index = 0
                
                var recentPeers = recentPeers
                if query != nil {
                    recentPeers = []
                }
                
                let _ = currentRemotePeers.swap((foundRemotePeers.0, foundRemotePeers.1))
                
                let filteredPeer: (EnginePeer, EnginePeer) -> Bool = { peer, accountPeer in
                    guard !peersFilter.contains(.excludeSavedMessages) || peer.id != accountPeer.id else { return false }
                    guard !peersFilter.contains(.excludeSecretChats) || peer.id.namespace != Namespaces.Peer.SecretChat else { return false }
                    guard !peersFilter.contains(.onlyPrivateChats) || peer.id.namespace == Namespaces.Peer.CloudUser else { return false }
                    
                    if peersFilter.contains(.onlyGroups) {
                        var isGroup: Bool = false
                        if case let .channel(peer) = peer, case .group = peer.info {
                            isGroup = true
                        } else if peer.id.namespace == Namespaces.Peer.CloudGroup {
                            isGroup = true
                        }
                        if !isGroup {
                            return false
                        }
                    }
                    
                    if peersFilter.contains(.onlyChannels) {
                        if case let .channel(peer) = peer, case .broadcast = peer.info {
                            return true
                        } else {
                            return false
                        }
                    }
                    
                    if peersFilter.contains(.excludeChannels) {
                        if case let .channel(peer) = peer, case .broadcast = peer.info {
                            return false
                        }
                    }
                    
                    return true
                }
                
                var existingPeerIds = Set<EnginePeer.Id>()
                
                var totalNumberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            totalNumberOfLocalPeers += 1
                        }
                    }
                }
                for peer in foundRemotePeers.0 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(peer.peer.id)
                        totalNumberOfLocalPeers += 1
                    }
                }
                
                var totalNumberOfGlobalPeers = 0
                for peer in foundRemotePeers.1 {
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
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
                    if !existingPeerIds.contains(accountPeer.id), filteredPeer(EnginePeer(accountPeer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(accountPeer.id)
                        entries.append(.localPeer(EnginePeer(accountPeer), nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
                        index += 1
                    }
                }
                
                for renderedPeer in foundLocalPeers.peers {
                    if !foundLocalPeers.recentlySearchedPeerIds.contains(renderedPeer.peerId) {
                        continue
                    }
                    
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            var associatedPeer: EnginePeer?
                            if case let .secretChat(secretChat) = peer, let associatedPeerId = secretChat.associatedPeerId {
                                associatedPeer = renderedPeer.peers[associatedPeerId]
                            }
                            
                            entries.append(.recentlySearchedPeer(peer, associatedPeer, foundLocalPeers.unread[peer.id], index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder))
                            
                            index += 1
                        }
                    }
                }
                
                if lowercasedQuery.count > 1 {
                    for peer in recentPeers {
                        if let peer = peer.peer.chatMainPeer, !existingPeerIds.contains(peer.id) {
                            let peer = EnginePeer(peer)
                            
                            var matches = false
                            if case let .user(user) = peer {
                                if let firstName = user.firstName, firstName.lowercased().hasPrefix(lowercasedQuery) {
                                    matches = true
                                } else if let lastName = user.lastName, lastName.lowercased().hasPrefix(lowercasedQuery) {
                                    matches = true
                                }
                            } else if peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).lowercased().hasPrefix(lowercasedQuery) {
                                matches = true
                            }
                            
                            if matches {
                                existingPeerIds.insert(peer.id)
                                entries.append(.localPeer(peer, nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
                            }
                        }
                    }
                }
                
                var numberOfLocalPeers = 0
                for renderedPeer in foundLocalPeers.peers {
                    if case .expand = localExpandType, numberOfLocalPeers >= 3 {
                        break
                    }
                    if foundLocalPeers.recentlySearchedPeerIds.contains(renderedPeer.peerId) {
                        continue
                    }
                    
                    if let peer = renderedPeer.peers[renderedPeer.peerId], peer.id != context.account.peerId, filteredPeer(peer, EnginePeer(accountPeer)) {
                        if !existingPeerIds.contains(peer.id) {
                            existingPeerIds.insert(peer.id)
                            var associatedPeer: EnginePeer?
                            if case let .secretChat(secretChat) = peer, let associatedPeerId = secretChat.associatedPeerId {
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
                    
                    if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                        existingPeerIds.insert(peer.peer.id)
                        entries.append(.localPeer(EnginePeer(peer.peer), nil, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, localExpandType))
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
                        
                        if !existingPeerIds.contains(peer.peer.id), filteredPeer(EnginePeer(peer.peer), EnginePeer(accountPeer)) {
                            existingPeerIds.insert(peer.peer.id)
                            entries.append(.globalPeer(peer, nil, index, presentationData.theme, presentationData.strings, presentationData.nameSortOrder, presentationData.nameDisplayOrder, globalExpandType))
                            index += 1
                            numberOfGlobalPeers += 1
                        }
                    }
                }
                
                if let message = resolvedMessage {
                    var peer = EngineRenderedPeer(message: message)
                    if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                        if let channelPeer = message.peers[migrationReference.peerId] {
                            peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                        }
                    }
                    entries.append(.message(message, peer, nil, presentationData, 1, nil, true, .index(message.index), nil, .generic, false))
                    index += 1
                }
                
                var firstHeaderId: Int64?
                if !foundRemotePeers.2 {
                    index = 0
                    for message in foundRemoteMessages.0.0 {
                        if searchState.deletedMessageIds.contains(message.id) {
                            continue
                        } else if message.id.namespace == Namespaces.Message.Cloud && searchState.deletedGlobalMessageIds.contains(message.id.id) {
                            continue
                        }
                        let headerId = listMessageDateHeaderId(timestamp: message.timestamp)
                        if firstHeaderId == nil {
                            firstHeaderId = headerId
                        }
                        var peer = EngineRenderedPeer(message: message)
                        if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                            if let channelPeer = message.peers[migrationReference.peerId] {
                                peer = EngineRenderedPeer(peer: EnginePeer(channelPeer))
                            }
                        }
                        entries.append(.message(message, peer, foundRemoteMessages.0.1[message.id.peerId], presentationData, foundRemoteMessages.0.2, selectionState?.contains(message.id), headerId == firstHeaderId, .index(message.index), nil, .generic, false))
                        index += 1
                    }
                }
                
                if tagMask == nil, !peersFilter.contains(.excludeRecent), isViablePhoneNumber(finalQuery) {
                    entries.append(.addContact(finalQuery, presentationData.theme, presentationData.strings))
                }
                
                return (entries, isSearching)
            }
        }
        
        let foundMessages = searchContext.get() |> map { searchContext -> ([EngineMessage], Int32, Bool) in
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
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a in
                interaction.present(c, a)
            }, transitionNode: { messageId, media in
                return transitionNodeImpl?(messageId, EngineMedia(media))
            }, addToTransitionSurface: { view in
                addToTransitionSurfaceImpl?(view)
            }, openUrl: { url in
                interaction.openUrl(url)
            }, openPeer: { _, _ in
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, gallerySource: .custom(messages: foundMessages |> map { message, a, b in
                return (message.map { $0._asMessage() }, a, b)
            }, messageId: message.id, loadMore: {
                loadMore()
            })))
        }
        
        transitionNodeImpl = { [weak self] messageId, media in
            if let strongSelf = self {
                return strongSelf.mediaNode.transitionNodeForGallery(messageId: messageId, media: media._asMedia())
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
        }, peerSelected: { [weak self] peer, chatPeer, _ in
            interaction.dismissInput()
            interaction.openPeer(peer, chatPeer, false)
            let _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).start()
            self?.listNode.clearHighlightAnimated(true)
        }, disabledPeerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, togglePeersSelection: { _, _ in
        }, additionalCategorySelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            interaction.dismissInput()
            if let strongSelf = self, let peer = message.peers[message.id.peerId] {
                interaction.openMessage(EnginePeer(peer), message.id, strongSelf.key == .chats)
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
            case let .peer(messages, peer, _, _, _, _, _, _, _, _, _, _, _):
                if let peer = peer.peer, let message = messages.first {
                    peerContextAction(peer, .search(message.id), node, gesture)
                }
            case .groupReference:
                gesture?.cancel()
            }
        }, present: { c in
            interaction.present(c, nil)
        })
        
        let listInteraction = ListMessageItemInteraction(openMessage: { [weak self] message, mode -> Bool in
            guard let strongSelf = self else {
                return false
            }
            interaction.dismissInput()
            
            let gallerySource: GalleryControllerItemSource
            
            if strongSelf.key == .downloads {
                gallerySource = .peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil))
            } else {
                gallerySource = .custom(messages: foundMessages |> map { message, a, b in
                    return (message.map { $0._asMessage() }, a, b)
                }, messageId: message.id, loadMore: {
                    loadMore()
                })
            }
            
            let playlistLocation: PeerMessagesPlaylistLocation?
            if strongSelf.key == .downloads {
                playlistLocation = nil
            } else {
                playlistLocation = .custom(messages: foundMessages |> map { message, a, b in
                    return (message.map { $0._asMessage() }, a, b)
                }, at: message.id, loadMore: {
                    loadMore()
                })
            }
            
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: true, mode: mode, navigationController: navigationController, dismissInput: {
                interaction.dismissInput()
            }, present: { c, a in
                interaction.present(c, a)
            }, transitionNode: { messageId, media in
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
            }, callPeer: { _, _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: playlistLocation, gallerySource: gallerySource))
        }, openMessageContextMenu: { [weak self] message, _, node, rect, gesture in
            guard let strongSelf = self, let currentEntries = strongSelf.currentEntries else {
                return
            }
            
            var fetchResourceId: (id: String, size: Int64, isFirstInList: Bool)?
            for entry in currentEntries {
                switch entry {
                case let .message(m, _, _, _, _, _, _, _, resource, _, _):
                    if m.id == message.id {
                        fetchResourceId = resource
                    }
                default:
                    break
                }
            }
            
            interaction.messageContextAction(EngineMessage(message), node, rect, gesture, key, fetchResourceId)
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
        let previousSelectedMessages = Atomic<Set<EngineMessage.Id>?>(value: nil)
        
        let _ = (searchQuery
        |> deliverOnMainQueue).start(next: { [weak self, weak listInteraction, weak chatListInteraction] query in
            self?.searchQueryValue = query
            listInteraction?.searchTextHighightState = query
            chatListInteraction?.searchTextHighightState = query
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
                    var entries: [ChatListSearchEntry]? = entriesAndFlags?.0 ?? []
                    if isSearching && (entries?.isEmpty ?? true) {
                        entries = nil
                    }
                    strongSelf.mediaNode.updateHistory(entries: entries, totalCount: 0, updateType: .Initial)
                }
                
                var entriesAndFlags = entriesAndFlags
                
                var peers: [EnginePeer] = []
                if let entries = entriesAndFlags?.0 {
                    var filteredEntries: [ChatListSearchEntry] = []
                    for entry in entries {
                        if case let .localPeer(peer, _, _, _, _, _, _, _, _) = entry {
                            peers.append(peer)
                        } else if case .globalPeer = entry {    
                        } else {
                            filteredEntries.append(entry)
                        }
                    }
                    
                    if strongSelf.tagMask != nil || strongSelf.searchOptionsValue?.date != nil || strongSelf.searchOptionsValue?.peer != nil {
                        entriesAndFlags?.0 = filteredEntries
                    }
                }
                
                let previousEntries = previousSearchItems.swap(entriesAndFlags?.0)
                let newEntries = entriesAndFlags?.0 ?? []
                
                let animated = (previousSelectedMessageIds == nil) != (strongSelf.selectedMessages == nil)
                let firstTime = previousEntries == nil
                var transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: newEntries, displayingResults: entriesAndFlags?.0 != nil, isEmpty: !isSearching && (entriesAndFlags?.0.isEmpty ?? false), isLoading: isSearching, animated: animated, context: context, presentationData: strongSelf.presentationData, enableHeaders: true, filter: peersFilter, key: strongSelf.key, tagMask: tagMask, interaction: chatListInteraction, listInteraction: listInteraction, peerContextAction: { message, node, rect, gesture in
                    interaction.peerContextAction?(message, node, rect, gesture)
                }, toggleExpandLocalResults: {
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
                }, searchQuery: strongSelf.searchQueryValue, searchOptions: strongSelf.searchOptionsValue, messageContextAction: { message, node, rect, gesture, paneKey, downloadResource in
                    interaction.messageContextAction(message, node, rect, gesture, paneKey, downloadResource)
                }, openClearRecentlyDownloaded: {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    
                    items.append(ActionSheetAnimationAndTextItem(title: strongSelf.presentationData.strings.DownloadList_ClearAlertTitle, text: strongSelf.presentationData.strings.DownloadList_ClearAlertText))
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DownloadList_OptionManageDeviceStorage, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.context.sharedContext.openStorageUsage(context: strongSelf.context)
                    }))
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DownloadList_ClearDownloadList, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = clearRecentDownloadList(postbox: strongSelf.context.account.postbox).start()
                    }))
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.interaction.dismissInput()
                    strongSelf.interaction.present(actionSheet, nil)
                }, toggleAllPaused: {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = ((strongSelf.context.fetchManager as! FetchManagerImpl).entriesSummary
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { entries in
                        guard let strongSelf = self, !entries.isEmpty else {
                            return
                        }
                        var allPaused = true
                        for entry in entries {
                            if !entry.isPaused {
                                allPaused = false
                                break
                            }
                        }
                        
                        for entry in entries {
                            strongSelf.context.fetchManager.toggleInteractiveFetchPaused(resourceId: entry.resourceReference.resource.id.stringRepresentation, isPaused: !allPaused)
                        }
                    })
                })
                strongSelf.currentEntries = newEntries
                if strongSelf.key == .downloads {
                    if !firstTime, !"".isEmpty {
                        transition.animated = true
                    }
                }
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
                
                var messages: [EngineMessage] = []
                for entry in newEntries {
                    if case let .message(message, _, _, _, _, _, _, _, _, _, _) = entry {
                        messages.append(message)
                    }
                }
                strongSelf.searchCurrentMessages = messages
            }
        }))
        
        let previousRecentItems = Atomic<[ChatListRecentEntry]?>(value: nil)
        let hasRecentPeers = context.engine.peers.recentPeers()
        |> map { value -> Bool in
            switch value {
                case let .peers(peers):
                    return !peers.isEmpty
                case .disabled:
                    return false
            }
        }
        |> distinctUntilChanged
        
        var recentItems = combineLatest(hasRecentPeers, fixedRecentlySearchedPeers, presentationDataPromise.get())
        |> mapToSignal { hasRecentPeers, peers, presentationData -> Signal<[ChatListRecentEntry], NoError> in
            var entries: [ChatListRecentEntry] = []
            if !peersFilter.contains(.onlyGroups) {
                if hasRecentPeers {
                    entries.append(.topPeers([], presentationData.theme, presentationData.strings))
                }
            }
            var peerIds = Set<EnginePeer.Id>()
            var index = 0
            loop: for searchedPeer in peers {
                if let peer = searchedPeer.peer.peers[searchedPeer.peer.peerId] {
                    if peerIds.contains(peer.id) {
                        continue loop
                    }
                    if !doesPeerMatchFilter(peer: EnginePeer(peer), filter: peersFilter) {
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
            self.updatedRecentPeersDisposable.set(context.engine.peers.managedUpdatedRecentPeers().start())
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
                    interaction.openPeer(peer, nil, true)
                    let _ = context.engine.peers.addRecentlySearchedPeer(peerId: peer.id).start()
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
                    let _ = context.engine.peers.removeRecentlySearchedPeer(peerId: peerId).start()
                })
                strongSelf.enqueueRecentTransition(transition, firstTime: firstTime)
            }
        }))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)))
                
                strongSelf.listNode.forEachItemHeaderNode({ itemHeaderNode in
                    if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                        itemHeaderNode.updateTheme(theme: presentationData.theme)
                    }
                })
                
                strongSelf.recentListNode.forEachItemHeaderNode({ itemHeaderNode in
                    if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                        itemHeaderNode.updateTheme(theme: presentationData.theme)
                    }
                })
            }
        })
                        
        self.recentListNode.beganInteractiveDragging = { _ in
            interaction.dismissInput()
        }
        
        self.listNode.beganInteractiveDragging = { _ in
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
        
        if [.file, .music, .voiceOrInstantVideo].contains(tagMask) || self.key == .downloads {
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
                                if tagMask != .music && self.key != .downloads {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .file:
                                if tagMask != .file {
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
                strongSelf.playlistLocation = playlistStateAndType?.1.playlistLocation
            })
        }
        
        self.deletedMessagesDisposable = (context.account.stateManager.deletedMessages
        |> deliverOnMainQueue).start(next: { [weak self] messageIds in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var state = state
                    var deletedMessageIds = state.deletedMessageIds
                    var deletedGlobalMessageIds = state.deletedGlobalMessageIds

                    for messageId in messageIds {
                        switch messageId {
                            case let .messageId(id):
                                deletedMessageIds.insert(id)
                            case let .global(id):
                                deletedGlobalMessageIds.insert(id)
                        }
                    }
                    
                    state.deletedMessageIds = deletedMessageIds
                    state.deletedGlobalMessageIds = deletedGlobalMessageIds
                    return state
                }
            }
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.searchDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
        self.recentDisposable.dispose()
        self.updatedRecentPeersDisposable.dispose()
        self.deletedMessagesDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.emptyResultsAnimationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.animationTapGesture(_:))))
        
        self.updateSelectedMessages(animated: false)
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
    
    func didBecomeFocused() {
        if self.key == .downloads {
            self.scheduleMarkRecentDownloadsAsSeen()
        }
    }
    
    private var scheduledMarkRecentDownloadsAsSeen: Bool = false
    
    func scheduleMarkRecentDownloadsAsSeen() {
        if !self.scheduledMarkRecentDownloadsAsSeen {
            self.scheduledMarkRecentDownloadsAsSeen = true
            Queue.mainQueue().after(0.1, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.scheduledMarkRecentDownloadsAsSeen = false
                let _ = markAllRecentDownloadItemsAsSeen(postbox: strongSelf.context.account.postbox).start()
            })
        }
    }
    
    func scrollToTop() -> Bool {
        if !self.mediaNode.isHidden {
            return self.mediaNode.scrollToTop()
        }
        let offset = self.listNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        }
    }
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.currentParams != nil
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
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context, presentationData: self.presentationData, displayBackground: true)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.getController = { [weak self] in
                    return self?.navigationController?.topViewController as? ViewController
                }
                mediaAccessoryPanel.presentInGlobalOverlay = { [weak self] c in
                    (self?.navigationController?.topViewController as? ViewController)?.presentInGlobalOverlay(c)
                }
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.setPlaylist(nil, type: type, control: SharedMediaPlayerControlAction.playback(.pause))
                    }
                }
                mediaAccessoryPanel.setRate = { [weak self] rate in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings)?.get(MusicPlaybackSettings.self) ?? MusicPlaybackSettings.defaultSettings
 
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return AccountManagerPreferencesEntry(settings.withUpdatedVoicePlaybackRate(rate))
                        })
                        return rate
                    }
                    |> deliverOnMainQueue).start(next: { baseRate in
                        guard let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType else {
                            return
                        }
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: type)
                        
                        if let controller = strongSelf.navigationController?.topViewController as? ViewController {
                            var hasTooltip = false
                            controller.forEachController({ controller in
                                if let controller = controller as? UndoOverlayController {
                                    hasTooltip = true
                                    controller.dismissWithCommitAction()
                                }
                                return true
                            })
                            
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let slowdown: Bool?
                            if baseRate == .x1 {
                                slowdown = true
                            } else if baseRate == .x2 {
                                slowdown = false
                            } else {
                                slowdown = nil
                            }
                            if let slowdown = slowdown {
                                controller.present(
                                    UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .audioRate(
                                            slowdown: slowdown,
                                            text: slowdown ? presentationData.strings.Conversation_AudioRateTooltipNormal : presentationData.strings.Conversation_AudioRateTooltipSpeedUp
                                        ),
                                        elevatedLayout: false,
                                        animateInAsReplacement: hasTooltip,
                                        action: { action in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            }
                        }
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
                            if let playlistLocation = strongSelf.playlistLocation as? PeerMessagesPlaylistLocation, case .custom = playlistLocation {
                                let controllerContext: AccountContext
                                if account.id == strongSelf.context.account.id {
                                    controllerContext = strongSelf.context
                                } else {
                                    controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                }
                                let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: playlistLocation, parentNavigationController: navigationController)
                                strongSelf.interaction.dismissInput()
                                strongSelf.interaction.present(controller, nil)
                            } else {
                                let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(location: .id(id.messageId), count: 60, highlight: true), id: 0), context: strongSelf.context, chatLocation: .peer(id: id.messageId.peerId), subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tagMask: EngineMessage.Tags.music)
                                
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
                                        let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: nil, parentNavigationController: navigationController)
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
        
        let topInset: CGFloat = topPanelHeight
        let overflowInset: CGFloat = 20.0
        let insets = UIEdgeInsets(top: topPanelHeight, left: sideInset, bottom: bottomInset, right: sideInset)
        
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: size.width - overflowInset * 2.0, height: size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: size.width - overflowInset * 2.0, height: size.height), presentationData: self.presentationData, key: !(self.searchQueryValue?.isEmpty ?? true) && self.key == .media ? .chats : self.key, hasSelection: self.selectedMessages != nil, transition: transition)
        
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
        
        let emptyAnimationHeight = self.emptyResultsAnimationSize.height
        let emptyAnimationSpacing: CGFloat = 8.0
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
        
        let textTransition = ContainedViewLayoutTransition.immediate
        textTransition.updateFrame(node: self.emptyResultsAnimationNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - self.emptyResultsAnimationSize.width) / 2.0, y: emptyAnimationY), size: self.emptyResultsAnimationSize))
        textTransition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing), size: emptyTitleSize))
        textTransition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: sideInset + padding + (size.width - sideInset * 2.0 - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyAnimationY + emptyAnimationHeight + emptyAnimationSpacing + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        self.emptyResultsAnimationNode.updateLayout(size: self.emptyResultsAnimationSize)
        
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
    
    func transitionNodeForGallery(messageId: EngineMessage.Id, media: EngineMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media._asMedia()) {
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
                options.insert(.PreferSynchronousResourceLoading)
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentListNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                if !strongSelf.didSetReady && !strongSelf.recentListNode.isHidden {
                    var ready: Signal<Bool, NoError>?
                    strongSelf.recentListNode.forEachItemNode { node in
                        if let node = node as? ChatListRecentPeersListItemNode {
                            ready = node.isReady
                        }
                    }
                    
                    if let ready = ready {
                        strongSelf.ready.set(ready)
                    } else {
                        strongSelf.ready.set(.single(true))
                    }
                    strongSelf.didSetReady = true
                }
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
        if let (transition, isFirstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if isFirstTime && self.key == .chats {
                options.insert(.PreferSynchronousDrawing)
                options.insert(.PreferSynchronousResourceLoading)
            } else if transition.animated {
                options.insert(.AnimateInsertion)
            }
            
            if self.key == .downloads {
                options.insert(.PreferSynchronousDrawing)
                options.insert(.PreferSynchronousResourceLoading)
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
                        if let query = transition.query, !query.isEmpty {
                            emptyResultsTitle = strongSelf.presentationData.strings.ChatList_Search_NoResults
                            emptyResultsText = strongSelf.presentationData.strings.ChatList_Search_NoResultsQueryDescription(query).string
                        } else {
                            if let searchOptions = searchOptions, searchOptions.date == nil && searchOptions.peer == nil {
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
                    
                    if strongSelf.key == .downloads {
                        strongSelf.emptyResultsAnimationNode.isHidden = true
                        strongSelf.emptyResultsTitleNode.isHidden = true
                        strongSelf.emptyResultsTextNode.isHidden = true
                        strongSelf.emptyResultsAnimationNode.visibility = false
                    } else {
                        strongSelf.emptyResultsAnimationNode.isHidden = !emptyResults
                        strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                        strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                        strongSelf.emptyResultsAnimationNode.visibility = emptyResults
                    }
                                             
                    var displayPlaceholder = transition.isLoading && (strongSelf.key != .chats || (strongSelf.currentEntries?.isEmpty ?? true))
                    if strongSelf.key == .downloads {
                        displayPlaceholder = false
                    }

                    let targetAlpha: CGFloat = displayPlaceholder ? 1.0 : 0.0
                    if strongSelf.shimmerNode.alpha != targetAlpha {
                        let transition: ContainedViewLayoutTransition = (displayPlaceholder || isFirstTime) ? .immediate : .animated(duration: 0.2, curve: .linear)
                        transition.updateAlpha(node: strongSelf.shimmerNode, alpha: targetAlpha, delay: 0.1)
                    }
           
                    strongSelf.recentListNode.isHidden = displayingResults || strongSelf.peersFilter.contains(.excludeRecent)
                    strongSelf.backgroundColor = !displayingResults && strongSelf.peersFilter.contains(.excludeRecent) ? nil : strongSelf.presentationData.theme.chatList.backgroundColor
                    
                    if !strongSelf.didSetReady && strongSelf.recentListNode.isHidden {
                        strongSelf.ready.set(.single(true))
                        strongSelf.didSetReady = true
                    }
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
                case let .peer(messages, peer, _, _, _, _, _, _, _, _, _, _, _):
                    return (selectedItemNode.view, bounds, messages.last?.id ?? peer.peerId)
                case let .groupReference(groupId, _, _, _, _):
                    return (selectedItemNode.view, bounds, groupId)
            }
        }
        return nil
    }
}

private final class ShimmerEffectNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.argb == backgroundColor.argb, let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.argb == foregroundColor.argb {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

private final class ChatListSearchShimmerNode: ASDisplayNode {
    private let backgroundColorNode: ASDisplayNode
    private let effectNode: ShimmerEffectNode
    private let maskNode: ASImageNode
    private var currentParams: (size: CGSize, presentationData: PresentationData, key: ChatListSearchPaneKey)?
    
    init(key: ChatListSearchPaneKey) {
        self.backgroundColorNode = ASDisplayNode()
        self.effectNode = ShimmerEffectNode()
        self.maskNode = ASImageNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundColorNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.maskNode)
    }
    
    func update(context: AccountContext, size: CGSize, presentationData: PresentationData, key: ChatListSearchPaneKey, hasSelection: Bool, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData || self.currentParams?.key != key {
            self.currentParams = (size, presentationData, key)
            
            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
            let timestamp1: Int32 = 100000
            var peers: [EnginePeer.Id: EnginePeer] = [:]
            peers[peer1.id] = peer1
            let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _, _, _ in }, disabledPeerSelected: { _ in }, togglePeerSelected: { _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, hidePsa: { _ in }, activateChatPreview: { _, _, gesture in
                gesture?.cancel()
            }, present: { _ in })
            
            let items = (0 ..< 2).compactMap { _ -> ListViewItem? in
                switch key {
                    case .chats, .downloads:
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: [],
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                        let readState = EnginePeerReadCounters()
                        return ChatListItem(presentationData: chatListPresentationData, context: context, peerGroupId: .root, filterData: nil, index: EngineChatList.Item.Index(pinningIndex: 0, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1)), content: .peer(messages: [message], peer: EngineRenderedPeer(peer: peer1), combinedReadState: readState, isRemovedFromTotalUnreadCount: false, presence: nil, hasUnseenMentions: false, hasUnseenReactions: false, draftState: nil, inputActivities: nil, promoInfo: nil, ignoreUnreadBadge: false, displayAsMessage: false, hasFailedMessages: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction)
                    case .media:
                        return nil
                    case .links:
                        var media: [EngineMedia] = []
                        media.append(.webpage(TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: "https://telegram.org", displayUrl: "https://telegram.org", hash: 0, type: nil, websiteName: "Telegram", title: "Telegram Telegram", text: "Telegram", embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, image: nil, file: nil, attributes: [], instantPage: nil)))))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: true, isGlobalSearchResult: true)
                    case .files:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: 0, attributes: [.FileName(fileName: "Text.txt")])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                    case .music:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: [.Audio(isVoice: false, duration: 0, title: nil, performer: nil, waveform: Data())])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                    case .voice:
                        var media: [EngineMedia] = []
                        media.append(.file(TelegramMediaFile(fileId: EngineMedia.Id(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: [.Audio(isVoice: true, duration: 0, title: nil, performer: nil, waveform: Data())])))
                        let message = EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp1,
                            flags: [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: peer1,
                            text: "Text",
                            attributes: [],
                            media: media,
                            peers: peers,
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                        
                        return ListMessageItem(presentationData: ChatPresentationData(presentationData: presentationData), context: context, chatLocation: .peer(id: peer1.id), interaction: ListMessageItemInteraction.default, message: message._asMessage(), selection: hasSelection ? .selectable(selected: false) : .none, displayHeader: false, customHeader: nil, hintIsLink: false, isGlobalSearchResult: true)
                }
            }
            
            var itemNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                items[i].nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 100.0), synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: (i == items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNodes.append(node)
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
            }
            
            self.backgroundColorNode.backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            
            self.maskNode.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(presentationData.theme.chatList.backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                if key == .media {
                    var currentY: CGFloat = 0.0
                    var rowIndex: Int = 0
                    
                    let itemSpacing: CGFloat = 1.0
                    let itemsInRow = max(3, min(6, Int(size.width / 140.0)))
                    let itemSize: CGFloat = floor(size.width / CGFloat(itemsInRow))
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    
                    while currentY < size.height {
                        for i in 0 ..< itemsInRow {
                            let itemOrigin = CGPoint(x: CGFloat(i) * (itemSize + itemSpacing), y: itemSpacing + CGFloat(rowIndex) * (itemSize + itemSpacing))
                            context.fill(CGRect(origin: itemOrigin, size: CGSize(width: itemSize, height: itemSize)))
                        }
                        currentY += itemSize
                        rowIndex += 1
                    }
                } else {
                    var currentY: CGFloat = 0.0
                    let fakeLabelPlaceholderHeight: CGFloat = 8.0
                    
                    func fillLabelPlaceholderRect(origin: CGPoint, width: CGFloat) {
                        let startPoint = origin
                        let diameter = fakeLabelPlaceholderHeight
                        context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                        context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                    }
                    
                    while currentY < size.height {
                        let sampleIndex = 0
                        let itemHeight: CGFloat = itemNodes[sampleIndex].contentSize.height
                        
                        context.setBlendMode(.copy)
                        context.setFillColor(UIColor.clear.cgColor)
                        
                        let selectionOffset: CGFloat = hasSelection ? 45.0 : 0.0
                        
                        if let itemNode = itemNodes[sampleIndex] as? ChatListItemNode {
                            context.fillEllipse(in: itemNode.avatarNode.frame.offsetBy(dx: 0.0, dy: currentY))
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                            
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: currentY + itemHeight - floor(itemNode.titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 60.0)
                            
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 120.0)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX + 120.0 + 10.0, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 60.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: floor(dateFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        } else if let itemNode = itemNodes[sampleIndex] as? ListMessageFileItemNode {
                            var isVoice = false
                            if let media = itemNode.currentMedia as? TelegramMediaFile {
                                isVoice = media.isVoice
                                if media.isMusic || media.isVoice {
                                    context.fillEllipse(in: CGRect(x: 12.0 + selectionOffset, y: currentY + 8.0, width: 40.0, height: 40.0))
                                } else {
                                    let path = UIBezierPath(roundedRect: CGRect(x: 12.0 + selectionOffset, y: currentY + 8.0, width: 40.0, height: 40.0), cornerRadius: 6.0)
                                    context.addPath(path.cgPath)
                                    context.fillPath()
                                }
                            }
                            
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: isVoice ? 240.0 : 60.0)
                            
                            let descriptionFrame = itemNode.descriptionNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: descriptionFrame.minX, y: floor(descriptionFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: isVoice ? 60.0 : 240.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: floor(dateFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        } else if let itemNode = itemNodes[sampleIndex] as? ListMessageSnippetItemNode {
                            let path = UIBezierPath(roundedRect: CGRect(x: 12.0 + selectionOffset, y: currentY + 12.0, width: 40.0, height: 40.0), cornerRadius: 6.0)
                            context.addPath(path.cgPath)
                            context.fillPath()
                            
                            let titleFrame = itemNode.titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 120.0)
                            
                            let linkFrame = itemNode.linkNode.frame.offsetBy(dx: 0.0, dy: currentY - 1.0)
                            fillLabelPlaceholderRect(origin: CGPoint(x: linkFrame.minX, y: floor(linkFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 240.0)
                            
                            let authorFrame = itemNode.authorNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: authorFrame.minX, y: floor(authorFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                            
                            let dateFrame = itemNode.dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                            fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: floor(dateFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 30.0)
                            
                            context.setBlendMode(.normal)
                            context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                            context.fill(itemNode.separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                        }
                        
                        currentY += itemHeight
                    }
                }
            })
            
            self.effectNode.update(backgroundColor: presentationData.theme.list.mediaPlaceholderColor, foregroundColor: presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(node: self.backgroundColorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}
