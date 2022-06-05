import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramNotices
import ContactsPeerItem
import ContextUI
import ItemListUI
import SearchUI
import ChatListSearchItemHeader
import PremiumUI

public enum ChatListNodeMode {
    case chatList
    case peers(filter: ChatListNodePeersFilter, isSelecting: Bool, additionalCategories: [ChatListNodeAdditionalCategory], chatListFilters: [ChatListFilter]?)
}

struct ChatListNodeListViewTransition {
    let chatListView: ChatListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertItems: [ListViewInsertItem]
    let updateItems: [ListViewUpdateItem]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let adjustScrollToFirstItem: Bool
    let animateCrossfade: Bool
}

final class ChatListHighlightedLocation {
    let location: ChatLocation
    let progress: CGFloat
    
    init(location: ChatLocation, progress: CGFloat) {
        self.location = location
        self.progress = progress
    }
    
    func withUpdatedProgress(_ progress: CGFloat) -> ChatListHighlightedLocation {
        return ChatListHighlightedLocation(location: location, progress: progress)
    }
}

public final class ChatListNodeInteraction {
    public enum PeerEntry {
        case peerId(EnginePeer.Id)
        case peer(EnginePeer)
    }
    
    let activateSearch: () -> Void
    let peerSelected: (EnginePeer, EnginePeer?, ChatListNodeEntryPromoInfo?) -> Void
    let disabledPeerSelected: (EnginePeer) -> Void
    let togglePeerSelected: (EnginePeer) -> Void
    let togglePeersSelection: ([PeerEntry], Bool) -> Void
    let additionalCategorySelected: (Int) -> Void
    let messageSelected: (EnginePeer, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void
    let groupSelected: (EngineChatList.Group) -> Void
    let addContact: (String) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let setItemPinned: (EngineChatList.PinnedItem.Id, Bool) -> Void
    let setPeerMuted: (EnginePeer.Id, Bool) -> Void
    let deletePeer: (EnginePeer.Id, Bool) -> Void
    let updatePeerGrouping: (EnginePeer.Id, Bool) -> Void
    let togglePeerMarkedUnread: (EnginePeer.Id, Bool) -> Void
    let toggleArchivedFolderHiddenByDefault: () -> Void
    let hidePsa: (EnginePeer.Id) -> Void
    let activateChatPreview: (ChatListItem, ASDisplayNode, ContextGesture?) -> Void
    let present: (ViewController) -> Void
    
    public var searchTextHighightState: String?
    var highlightedChatLocation: ChatListHighlightedLocation?
    
    public init(activateSearch: @escaping () -> Void, peerSelected: @escaping (EnginePeer, EnginePeer?, ChatListNodeEntryPromoInfo?) -> Void, disabledPeerSelected: @escaping (EnginePeer) -> Void, togglePeerSelected: @escaping (EnginePeer) -> Void, togglePeersSelection: @escaping ([PeerEntry], Bool) -> Void, additionalCategorySelected: @escaping (Int) -> Void, messageSelected: @escaping (EnginePeer, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void, groupSelected: @escaping (EngineChatList.Group) -> Void, addContact: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, setItemPinned: @escaping (EngineChatList.PinnedItem.Id, Bool) -> Void, setPeerMuted: @escaping (EnginePeer.Id, Bool) -> Void, deletePeer: @escaping (EnginePeer.Id, Bool) -> Void, updatePeerGrouping: @escaping (EnginePeer.Id, Bool) -> Void, togglePeerMarkedUnread: @escaping (EnginePeer.Id, Bool) -> Void, toggleArchivedFolderHiddenByDefault: @escaping () -> Void, hidePsa: @escaping (EnginePeer.Id) -> Void, activateChatPreview: @escaping (ChatListItem, ASDisplayNode, ContextGesture?) -> Void, present: @escaping (ViewController) -> Void) {
        self.activateSearch = activateSearch
        self.peerSelected = peerSelected
        self.disabledPeerSelected = disabledPeerSelected
        self.togglePeerSelected = togglePeerSelected
        self.togglePeersSelection = togglePeersSelection
        self.additionalCategorySelected = additionalCategorySelected
        self.messageSelected = messageSelected
        self.groupSelected = groupSelected
        self.addContact = addContact
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setItemPinned = setItemPinned
        self.setPeerMuted = setPeerMuted
        self.deletePeer = deletePeer
        self.updatePeerGrouping = updatePeerGrouping
        self.togglePeerMarkedUnread = togglePeerMarkedUnread
        self.toggleArchivedFolderHiddenByDefault = toggleArchivedFolderHiddenByDefault
        self.hidePsa = hidePsa
        self.activateChatPreview = activateChatPreview
        self.present = present
    }
}

public final class ChatListNodePeerInputActivities {
    public let activities: [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]]
    
    public init(activities: [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]]) {
        self.activities = activities
    }
}

private func areFoundPeerArraysEqual(_ lhs: [(EnginePeer, EnginePeer?)], _ rhs: [(EnginePeer, EnginePeer?)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].0 != rhs[i].0 || lhs[i].1 != rhs[i].1 {
            return false
        }
    }
    return true
}

public struct ChatListNodeState: Equatable {
    public var presentationData: ChatListPresentationData
    public var editing: Bool
    public var peerIdWithRevealedOptions: EnginePeer.Id?
    public var selectedPeerIds: Set<EnginePeer.Id>
    public var peerInputActivities: ChatListNodePeerInputActivities?
    public var pendingRemovalPeerIds: Set<EnginePeer.Id>
    public var pendingClearHistoryPeerIds: Set<EnginePeer.Id>
    public var archiveShouldBeTemporaryRevealed: Bool
    public var selectedAdditionalCategoryIds: Set<Int>
    public var hiddenPsaPeerId: EnginePeer.Id?
    public var foundPeers: [(EnginePeer, EnginePeer?)]
    public var selectedPeerMap: [EnginePeer.Id: EnginePeer]
    
    public init(presentationData: ChatListPresentationData, editing: Bool, peerIdWithRevealedOptions: EnginePeer.Id?, selectedPeerIds: Set<EnginePeer.Id>, foundPeers: [(EnginePeer, EnginePeer?)], selectedPeerMap: [EnginePeer.Id: EnginePeer], selectedAdditionalCategoryIds: Set<Int>, peerInputActivities: ChatListNodePeerInputActivities?, pendingRemovalPeerIds: Set<EnginePeer.Id>, pendingClearHistoryPeerIds: Set<EnginePeer.Id>, archiveShouldBeTemporaryRevealed: Bool, hiddenPsaPeerId: EnginePeer.Id?) {
        self.presentationData = presentationData
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.selectedPeerIds = selectedPeerIds
        self.selectedAdditionalCategoryIds = selectedAdditionalCategoryIds
        self.foundPeers = foundPeers
        self.selectedPeerMap = selectedPeerMap
        self.peerInputActivities = peerInputActivities
        self.pendingRemovalPeerIds = pendingRemovalPeerIds
        self.pendingClearHistoryPeerIds = pendingClearHistoryPeerIds
        self.archiveShouldBeTemporaryRevealed = archiveShouldBeTemporaryRevealed
        self.hiddenPsaPeerId = hiddenPsaPeerId
    }
    
    public static func ==(lhs: ChatListNodeState, rhs: ChatListNodeState) -> Bool {
        if lhs.presentationData !== rhs.presentationData {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.selectedPeerIds != rhs.selectedPeerIds {
            return false
        }
        if areFoundPeerArraysEqual(lhs.foundPeers, rhs.foundPeers) {
            return false
        }
        if lhs.selectedPeerMap != rhs.selectedPeerMap {
            return false
        }
        if lhs.selectedAdditionalCategoryIds != rhs.selectedAdditionalCategoryIds {
            return false
        }
        if lhs.peerInputActivities !== rhs.peerInputActivities {
            return false
        }
        if lhs.pendingRemovalPeerIds != rhs.pendingRemovalPeerIds {
            return false
        }
        if lhs.pendingClearHistoryPeerIds != rhs.pendingClearHistoryPeerIds {
            return false
        }
        if lhs.archiveShouldBeTemporaryRevealed != rhs.archiveShouldBeTemporaryRevealed {
            return false
        }
        if lhs.hiddenPsaPeerId != rhs.hiddenPsaPeerId {
            return false
        }
        return true
    }
}

private func mappedInsertEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: EngineChatList.Group, filterData: ChatListItemFilterData?, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionInsertEntry]) -> [ListViewInsertItem] {
    return entries.map { entry -> ListViewInsertItem in
        switch entry.entry {
            case .HeaderEntry:
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyHeaderItem(), directionHint: entry.directionHint)
            case let .AdditionalCategory(_, id, title, image, appearance, selected, presentationData):
                var header: ChatListSearchItemHeader?
                if case .action = appearance {
                    // TODO: hack, generalize
                    header = ChatListSearchItemHeader(type: .orImportIntoAnExistingGroup, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                }
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListAdditionalCategoryItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings),
                    context: context,
                    title: title,
                    image: image,
                    appearance: appearance,
                    isSelected: selected,
                    header: header,
                    action: {
                        nodeInteraction.additionalCategorySelected(id)
                    }
                ), directionHint: entry.directionHint)
            case let .PeerEntry(index, presentationData, messages, combinedReadState, isRemovedFromTotalUnreadCount, draftState, peer, presence, hasUnseenMentions, hasUnseenReactions, editing, hasActiveRevealControls, selected, inputActivities, promoInfo, hasFailedMessages, isContact):
                switch mode {
                    case .chatList:
                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                            presentationData: presentationData,
                            context: context,
                            peerGroupId: peerGroupId,
                            filterData: filterData,
                            index: index,
                            content: .peer(
                                messages: messages,
                                peer: peer,
                                combinedReadState: combinedReadState,
                                isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                                presence: presence,
                                hasUnseenMentions: hasUnseenMentions,
                                hasUnseenReactions: hasUnseenReactions,
                                draftState: draftState,
                                inputActivities: inputActivities,
                                promoInfo: promoInfo,
                                ignoreUnreadBadge: false,
                                displayAsMessage: false,
                                hasFailedMessages: hasFailedMessages
                            ),
                            editing: editing,
                            hasActiveRevealControls: hasActiveRevealControls,
                            selected: selected,
                            header: nil,
                            enableContextActions: true,
                            hiddenOffset: false,
                            interaction: nodeInteraction
                        ), directionHint: entry.directionHint)
                    case let .peers(filter, isSelecting, _, filters):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: EnginePeer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if filter.contains(.onlyWriteable) {
                            if let peer = peer.peers[peer.peerId] {
                                if !canSendMessagesToPeer(peer._asPeer()) {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.onlyPrivateChats) {
                            if let peer = peer.peers[peer.peerId] {
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
                            if let peer = peer.peers[peer.peerId] {
                                if case .legacyGroup = peer {
                                } else if case let .channel(peer) = peer, case .group = peer.info {
                                } else {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.onlyManageable) {
                            if let peer = peer.peers[peer.peerId] {
                                var canManage = false
                                if case let .legacyGroup(peer) = peer {
                                    switch peer.role {
                                        case .creator, .admin:
                                            canManage = true
                                        default:
                                            break
                                    }
                                }
                                
                                if canManage {
                                } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.inviteMembers) {
                                } else {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.excludeChannels) {
                            if let peer = peer.peers[peer.peerId] {
                                if case let .channel(peer) = peer, case .broadcast = peer.info {
                                    enabled = false
                                }
                            }
                        }
                        
                        var header: ChatListSearchItemHeader?
                        switch mode {
                        case let .peers(_, _, additionalCategories, _):
                            if !additionalCategories.isEmpty {
                                let headerType: ChatListSearchItemHeaderType
                                if case .action = additionalCategories[0].appearance {
                                    // TODO: hack, generalize
                                    headerType = .orImportIntoAnExistingGroup
                                } else {
                                    headerType = .chats
                                }
                                header = ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                            }
                        default:
                            break
                        }
                        
                        var status: ContactsPeerItemStatus = .none
                        if isSelecting, let itemPeer = itemPeer {
                            if let (string, multiline) = statusStringForPeerType(accountPeerId: context.account.peerId, strings: presentationData.strings, peer: itemPeer, isMuted: isRemovedFromTotalUnreadCount, isUnread: combinedReadState?.isUnread ?? false, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: filters) {
                                status = .custom(string: string, multiline: multiline)
                            } else {
                                status = .none
                            }
                        }

                        return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                            presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings),
                            sortOrder: presentationData.nameSortOrder,
                            displayOrder: presentationData.nameDisplayOrder,
                            context: context,
                            peerMode: .generalSearch,
                            peer: .peer(peer: itemPeer, chatPeer: chatPeer),
                            status: status,
                            enabled: enabled,
                            selection: editing ? .selectable(selected: selected) : .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: header,
                            action: { _ in
                                if let chatPeer = chatPeer {
                                    if editing {
                                        nodeInteraction.togglePeerSelected(chatPeer)
                                    } else {
                                        nodeInteraction.peerSelected(chatPeer, nil, nil)
                                    }
                                }
                            }, disabledAction: { _ in
                                if let chatPeer = chatPeer {
                                    nodeInteraction.disabledPeerSelected(chatPeer)
                                }
                            }
                        ), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, peers, message, editing, unreadCount, revealed, hiddenByDefault):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                    presentationData: presentationData,
                    context: context,
                    peerGroupId: peerGroupId,
                    filterData: filterData,
                    index: index,
                    content: .groupReference(
                        groupId: groupId,
                        peers: peers,
                        message: message,
                        unreadCount: unreadCount,
                        hiddenByDefault: hiddenByDefault
                    ),
                    editing: editing,
                    hasActiveRevealControls: false,
                    selected: false,
                    header: nil,
                    enableContextActions: true,
                    hiddenOffset: hiddenByDefault && !revealed,
                    interaction: nodeInteraction
                ), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewInsertItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
        }
    }
}

private func mappedUpdateEntries(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: EngineChatList.Group, filterData: ChatListItemFilterData?, mode: ChatListNodeMode, entries: [ChatListNodeViewTransitionUpdateEntry]) -> [ListViewUpdateItem] {
    return entries.map { entry -> ListViewUpdateItem in
        switch entry.entry {
            case let .PeerEntry(index, presentationData, messages, combinedReadState, isRemovedFromTotalUnreadCount, draftState, peer, presence, hasUnseenMentions, hasUnseenReactions, editing, hasActiveRevealControls, selected, inputActivities, promoInfo, hasFailedMessages, isContact):
                switch mode {
                    case .chatList:
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                            presentationData: presentationData,
                            context: context,
                            peerGroupId: peerGroupId,
                            filterData: filterData,
                            index: index,
                            content: .peer(
                                messages: messages,
                                peer: peer,
                                combinedReadState: combinedReadState,
                                isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount,
                                presence: presence,
                                hasUnseenMentions: hasUnseenMentions,
                                hasUnseenReactions: hasUnseenReactions,
                                draftState: draftState,
                                inputActivities: inputActivities,
                                promoInfo: promoInfo,
                                ignoreUnreadBadge: false,
                                displayAsMessage: false,
                                hasFailedMessages: hasFailedMessages
                            ),
                            editing: editing,
                            hasActiveRevealControls: hasActiveRevealControls,
                            selected: selected,
                            header: nil,
                            enableContextActions: true,
                            hiddenOffset: false,
                            interaction: nodeInteraction
                    ), directionHint: entry.directionHint)
                    case let .peers(filter, isSelecting, _, filters):
                        let itemPeer = peer.chatMainPeer
                        var chatPeer: EnginePeer?
                        if let peer = peer.peers[peer.peerId] {
                            chatPeer = peer
                        }
                        var enabled = true
                        if filter.contains(.onlyWriteable) {
                            if let peer = peer.peers[peer.peerId] {
                                if !canSendMessagesToPeer(peer._asPeer()) {
                                    enabled = false
                                }
                            } else {
                                enabled = false
                            }
                        }
                        if filter.contains(.excludeChannels) {
                            if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                                enabled = false
                            }
                        }
                        var header: ChatListSearchItemHeader?
                        switch mode {
                        case let .peers(_, _, additionalCategories, _):
                            if !additionalCategories.isEmpty {
                                let headerType: ChatListSearchItemHeaderType
                                if case .action = additionalCategories[0].appearance {
                                    // TODO: hack, generalize
                                    headerType = .orImportIntoAnExistingGroup
                                } else {
                                    headerType = .chats
                                }
                                header = ChatListSearchItemHeader(type: headerType, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                            }
                        default:
                            break
                        }
                        
                        var status: ContactsPeerItemStatus = .none
                        if isSelecting, let itemPeer = itemPeer {
                            if let (string, multiline) = statusStringForPeerType(accountPeerId: context.account.peerId, strings: presentationData.strings, peer: itemPeer, isMuted: isRemovedFromTotalUnreadCount, isUnread: combinedReadState?.isUnread ?? false, isContact: isContact, hasUnseenMentions: hasUnseenMentions, chatListFilters: filters) {
                                status = .custom(string: string, multiline: multiline)
                            } else {
                                status = .none
                            }
                        }
                        
                        return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ContactsPeerItem(
                            presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings),
                            sortOrder: presentationData.nameSortOrder,
                            displayOrder: presentationData.nameDisplayOrder,
                            context: context,
                            peerMode: .generalSearch,
                            peer: .peer(peer: itemPeer, chatPeer: chatPeer),
                            status: status,
                            enabled: enabled,
                            selection: editing ? .selectable(selected: selected) : .none,
                            editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                            index: nil,
                            header: header,
                            action: { _ in
                                if let chatPeer = chatPeer {
                                    if editing {
                                        nodeInteraction.togglePeerSelected(chatPeer)
                                    } else {
                                        nodeInteraction.peerSelected(chatPeer, nil, nil)
                                    }
                                }
                            }, disabledAction: { _ in
                                if let chatPeer = chatPeer {
                                    nodeInteraction.disabledPeerSelected(chatPeer)
                                }
                            }
                    ), directionHint: entry.directionHint)
                }
            case let .HoleEntry(_, theme):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListHoleItem(theme: theme), directionHint: entry.directionHint)
            case let .GroupReferenceEntry(index, presentationData, groupId, peers, message, editing, unreadCount, revealed, hiddenByDefault):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListItem(
                        presentationData: presentationData,
                        context: context,
                        peerGroupId: peerGroupId,
                        filterData: filterData,
                        index: index,
                        content: .groupReference(
                            groupId: groupId,
                            peers: peers,
                            message: message,
                            unreadCount: unreadCount,
                            hiddenByDefault: hiddenByDefault
                        ),
                        editing: editing,
                        hasActiveRevealControls: false,
                        selected: false,
                        header: nil,
                        enableContextActions: true,
                        hiddenOffset: hiddenByDefault && !revealed,
                        interaction: nodeInteraction
                ), directionHint: entry.directionHint)
            case let .ArchiveIntro(presentationData):
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListArchiveInfoItem(theme: presentationData.theme, strings: presentationData.strings), directionHint: entry.directionHint)
            case .HeaderEntry:
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListEmptyHeaderItem(), directionHint: entry.directionHint)
            case let .AdditionalCategory(index: _, id, title, image, appearance, selected, presentationData):
                var header: ChatListSearchItemHeader?
                if case .action = appearance {
                    // TODO: hack, generalize
                    header = ChatListSearchItemHeader(type: .orImportIntoAnExistingGroup, theme: presentationData.theme, strings: presentationData.strings, actionTitle: nil, action: nil)
                }
                return ListViewUpdateItem(index: entry.index, previousIndex: entry.previousIndex, item: ChatListAdditionalCategoryItem(
                    presentationData: ItemListPresentationData(theme: presentationData.theme, fontSize: presentationData.fontSize, strings: presentationData.strings),
                    context: context,
                    title: title,
                    image: image,
                    appearance: appearance,
                    isSelected: selected,
                    header: header,
                    action: {
                        nodeInteraction.additionalCategorySelected(id)
                    }
                ), directionHint: entry.directionHint)
        }
    }
}

private func mappedChatListNodeViewListTransition(context: AccountContext, nodeInteraction: ChatListNodeInteraction, peerGroupId: EngineChatList.Group, filterData: ChatListItemFilterData?, mode: ChatListNodeMode, transition: ChatListNodeViewTransition) -> ChatListNodeListViewTransition {
    return ChatListNodeListViewTransition(chatListView: transition.chatListView, deleteItems: transition.deleteItems, insertItems: mappedInsertEntries(context: context, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, filterData: filterData, mode: mode, entries: transition.insertEntries), updateItems: mappedUpdateEntries(context: context, nodeInteraction: nodeInteraction, peerGroupId: peerGroupId, filterData: filterData, mode: mode, entries: transition.updateEntries), options: transition.options, scrollToItem: transition.scrollToItem, stationaryItemRange: transition.stationaryItemRange, adjustScrollToFirstItem: transition.adjustScrollToFirstItem, animateCrossfade: transition.animateCrossfade)
}

private final class ChatListOpaqueTransactionState {
    let chatListView: ChatListNodeView
    
    init(chatListView: ChatListNodeView) {
        self.chatListView = chatListView
    }
}

public enum ChatListSelectionOption {
    case previous(unread: Bool)
    case next(unread: Bool)
    case peerId(EnginePeer.Id)
    case index(Int)
}

public enum ChatListGlobalScrollOption {
    case none
    case top
    case unread
}

public enum ChatListNodeScrollPosition {
    case top
}

public enum ChatListNodeEmptyState: Equatable {
    case notEmpty(containsChats: Bool)
    case empty(isLoading: Bool, hasArchiveInfo: Bool)
}

public final class ChatListNode: ListView {
    private let fillPreloadItems: Bool
    private let context: AccountContext
    private let groupId: EngineChatList.Group
    private let mode: ChatListNodeMode
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    public var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private let _contentsReady = ValuePromise<Bool>()
    private var didSetContentsReady = false
    public var contentsReady: Signal<Bool, NoError> {
        return _contentsReady.get()
    }
    
    public var peerSelected: ((EnginePeer, Bool, Bool, ChatListNodeEntryPromoInfo?) -> Void)?
    public var disabledPeerSelected: ((EnginePeer) -> Void)?
    public var additionalCategorySelected: ((Int) -> Void)?
    public var groupSelected: ((EngineChatList.Group) -> Void)?
    public var addContact: ((String) -> Void)?
    public var activateSearch: (() -> Void)?
    public var deletePeerChat: ((EnginePeer.Id, Bool) -> Void)?
    public var updatePeerGrouping: ((EnginePeer.Id, Bool) -> Void)?
    public var presentAlert: ((String) -> Void)?
    public var present: ((ViewController) -> Void)?
    public var push: ((ViewController) -> Void)?
    public var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    public var hidePsa: ((EnginePeer.Id) -> Void)?
    public var activateChatPreview: ((ChatListItem, ASDisplayNode, ContextGesture?) -> Void)?
    
    private var theme: PresentationTheme
    
    private let viewProcessingQueue = Queue()
    private var chatListView: ChatListNodeView?
    var entriesCount: Int {
        if let chatListView = self.chatListView {
            return chatListView.filteredEntries.count
        } else {
            return 0
        }
    }
    private var interaction: ChatListNodeInteraction?
    
    private var dequeuedInitialTransitionOnLayout = false
    private var enqueuedTransition: (ChatListNodeListViewTransition, () -> Void)?
    
    public private(set) var currentState: ChatListNodeState
    private let statePromise: ValuePromise<ChatListNodeState>
    public var state: Signal<ChatListNodeState, NoError> {
        return self.statePromise.get()
    }
    
    private var currentLocation: ChatListNodeLocation?
    private(set) var chatListFilter: ChatListFilter? {
        didSet {
            self.chatListFilterValue.set(.single(self.chatListFilter))
            
            if self.chatListFilter != oldValue {
                self.setChatListLocation(.initial(count: 50, filter: self.chatListFilter))
            }
        }
    }
    private let updatedFilterDisposable = MetaDisposable()
    private let chatListFilterValue = Promise<ChatListFilter?>()
    var chatListFilterSignal: Signal<ChatListFilter?, NoError> {
        return self.chatListFilterValue.get()
    }
    private var hasUpdatedAppliedChatListFilterValueOnce = false
    private var currentAppliedChatListFilterValue: ChatListFilter?
    private let appliedChatListFilterValue = Promise<ChatListFilter?>()
    var appliedChatListFilterSignal: Signal<ChatListFilter?, NoError> {
        return self.appliedChatListFilterValue.get()
    }
    private let chatListLocation = ValuePromise<ChatListNodeLocation>()
    private let chatListDisposable = MetaDisposable()
    private var activityStatusesDisposable: Disposable?
    
    private let scrollToTopOptionPromise = Promise<ChatListGlobalScrollOption>(.none)
    public var scrollToTopOption: Signal<ChatListGlobalScrollOption, NoError> {
        return self.scrollToTopOptionPromise.get()
    }
    
    private let scrolledAtTop = ValuePromise<Bool>(true)
    private var scrolledAtTopValue: Bool = true {
        didSet {
            if self.scrolledAtTopValue != oldValue {
                self.scrolledAtTop.set(self.scrolledAtTopValue)
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    
    var isEmptyUpdated: ((ChatListNodeEmptyState, Bool, ContainedViewLayoutTransition) -> Void)?
    private var currentIsEmptyState: ChatListNodeEmptyState?
    
    public var addedVisibleChatsWithPeerIds: (([EnginePeer.Id]) -> Void)?
    
    private let currentRemovingPeerId = Atomic<EnginePeer.Id?>(value: nil)
    public func setCurrentRemovingPeerId(_ peerId: EnginePeer.Id?) {
        let _ = self.currentRemovingPeerId.swap(peerId)
    }
    
    private var hapticFeedback: HapticFeedback?
    
    let preloadItems = Promise<[ChatHistoryPreloadItem]>([])
    
    var didBeginSelectingChats: (() -> Void)?
    public var selectionCountChanged: ((Int) -> Void)?
    
    var isSelectionGestureEnabled = true
    
    public var selectionLimit: Int32 = 100
    public var reachedSelectionLimit: ((Int32) -> Void)?
    
    public init(context: AccountContext, groupId: EngineChatList.Group, chatListFilter: ChatListFilter? = nil, previewing: Bool, fillPreloadItems: Bool, mode: ChatListNodeMode, theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.context = context
        self.groupId = groupId
        self.chatListFilter = chatListFilter
        self.chatListFilterValue.set(.single(chatListFilter))
        self.fillPreloadItems = fillPreloadItems
        self.mode = mode
        
        var isSelecting = false
        if case .peers(_, true, _, _) = mode {
            isSelecting = true
        }
        
        self.currentState = ChatListNodeState(presentationData: ChatListPresentationData(theme: theme, fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations), editing: isSelecting, peerIdWithRevealedOptions: nil, selectedPeerIds: Set(), foundPeers: [], selectedPeerMap: [:], selectedAdditionalCategoryIds: Set(), peerInputActivities: nil, pendingRemovalPeerIds: Set(), pendingClearHistoryPeerIds: Set(), archiveShouldBeTemporaryRevealed: false, hiddenPsaPeerId: nil)
        self.statePromise = ValuePromise(self.currentState, ignoreRepeated: true)
        
        self.theme = theme
        
        super.init()
        
        self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
        self.verticalScrollIndicatorFollowsOverscroll = true
        
        self.keepMinimalScrollHeightWithTopInset = navigationBarSearchContentHeight
        
        let nodeInteraction = ChatListNodeInteraction(activateSearch: { [weak self] in
            if let strongSelf = self, let activateSearch = strongSelf.activateSearch {
                activateSearch()
            }
        }, peerSelected: { [weak self] peer, _, promoInfo in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peer, true, true, promoInfo)
            }
        }, disabledPeerSelected: { [weak self] peer in
            if let strongSelf = self, let disabledPeerSelected = strongSelf.disabledPeerSelected {
                disabledPeerSelected(peer)
            }
        }, togglePeerSelected: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            var didBeginSelecting = false
            var count = 0
            strongSelf.updateState { [weak self] state in
                var state = state
                if state.selectedPeerIds.contains(peer.id) {
                    state.selectedPeerIds.remove(peer.id)
                } else {
                    if state.selectedPeerIds.count < strongSelf.selectionLimit {
                        if state.selectedPeerIds.isEmpty {
                            didBeginSelecting = true
                        }
                        state.selectedPeerIds.insert(peer.id)
                        state.selectedPeerMap[peer.id] = peer
                    } else {
                        self?.reachedSelectionLimit?(Int32(state.selectedPeerIds.count))
                    }
                }
                count = state.selectedPeerIds.count
                return state
            }
            strongSelf.selectionCountChanged?(count)
            if didBeginSelecting {
                strongSelf.didBeginSelectingChats?()
            }
        }, togglePeersSelection: { [weak self] peers, selected in
            self?.updateState { state in
                var state = state
                if selected {
                    for peerEntry in peers {
                        switch peerEntry {
                            case let .peer(peer):
                                state.selectedPeerIds.insert(peer.id)
                                state.selectedPeerMap[peer.id] = peer
                            case let .peerId(peerId):
                                state.selectedPeerIds.insert(peerId)
                        }
                    }
                } else {
                    for peerEntry in peers {
                        switch peerEntry {
                            case let .peer(peer):
                                state.selectedPeerIds.remove(peer.id)
                            case let .peerId(peerId):
                                state.selectedPeerIds.remove(peerId)
                        }
                    }
                }
                return state
            }
            if selected && !peers.isEmpty {
                self?.didBeginSelectingChats?()
            }
        }, additionalCategorySelected: { [weak self] id in
            self?.additionalCategorySelected?(id)
        }, messageSelected: { [weak self] peer, message, promoInfo in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                var activateInput = false
                for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                            case .peerJoined, .groupCreated, .channelMigratedFromGroup, .historyCleared:
                                activateInput = true
                            default:
                                break
                        }
                    }
                }
                peerSelected(peer, true, activateInput, promoInfo)
            }
        }, groupSelected: { [weak self] groupId in
            if let strongSelf = self, let groupSelected = strongSelf.groupSelected {
                groupSelected(groupId)
            }
        }, addContact: { _ in
        }, setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) || (peerId == nil && fromPeerId == nil) {
                        var state = state
                        state.peerIdWithRevealedOptions = peerId
                        return state
                    } else {
                        return state
                    }
                }
            }
        }, setItemPinned: { [weak self] itemId, _ in
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                let isPremium = peer?.isPremium ?? false
                let location: TogglePeerChatPinnedLocation
                if let chatListFilter = chatListFilter {
                    location = .filter(chatListFilter.id)
                } else {
                    location = .group(groupId._asGroup())
                }
                let _ = (context.engine.peers.toggleItemPinned(location: location, itemId: itemId)
                |> deliverOnMainQueue).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                        case .done:
                            break
                        case let .limitExceeded(count, _):
                            if isPremium {
                                let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {})
                                strongSelf.push?(controller)
                            } else {
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = PremiumLimitScreen(context: context, subject: .pins, count: Int32(count), action: {
                                    let premiumScreen = PremiumIntroScreen(context: context, source: .pinnedChats)
                                    replaceImpl?(premiumScreen)
                                })
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                strongSelf.push?(controller)
                            }
                        }
                    }
                })
            })
        }, setPeerMuted: { [weak self] peerId, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setCurrentRemovingPeerId(peerId)
            let _ = (context.engine.peers.togglePeerMuted(peerId: peerId)
            |> deliverOnMainQueue).start(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
                self?.setCurrentRemovingPeerId(nil)
            })
        }, deletePeer: { [weak self] peerId, joined in
            self?.deletePeerChat?(peerId, joined)
        }, updatePeerGrouping: { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        }, togglePeerMarkedUnread: { [weak self, weak context] peerId, animated in
            guard let context = context else {
                return
            }
            self?.setCurrentRemovingPeerId(peerId)
            let _ = (context.engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: nil)
            |> deliverOnMainQueue).start(completed: {
                self?.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
                self?.setCurrentRemovingPeerId(nil)
            })
        }, toggleArchivedFolderHiddenByDefault: { [weak self] in
            self?.toggleArchivedFolderHiddenByDefault?()
        }, hidePsa: { [weak self] id in
            self?.hidePsa?(id)
        }, activateChatPreview: { [weak self] item, node, gesture in
            guard let strongSelf = self else {
                return
            }
            if let activateChatPreview = strongSelf.activateChatPreview {
                activateChatPreview(item, node, gesture)
            } else {
                gesture?.cancel()
            }
        }, present: { [weak self] c in
            self?.present?(c)
        })
        
        let viewProcessingQueue = self.viewProcessingQueue
        
        let chatListViewUpdate = self.chatListLocation.get()
        |> distinctUntilChanged
        |> mapToSignal { location -> Signal<(ChatListNodeViewUpdate, ChatListFilter?), NoError> in
            return chatListViewForLocation(groupId: groupId._asGroup(), location: location, account: context.account)
            |> map { update in
                return (update, location.filter)
            }
        }
        
        let previousState = Atomic<ChatListNodeState>(value: self.currentState)
        let previousView = Atomic<ChatListNodeView?>(value: nil)
        let previousHideArchivedFolderByDefault = Atomic<Bool?>(value: nil)
        let currentRemovingPeerId = self.currentRemovingPeerId
        
        let savedMessagesPeer: Signal<EnginePeer?, NoError>
        if case let .peers(filter, _, _, _) = mode, filter.contains(.onlyWriteable) {
            savedMessagesPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map(Optional.init)
            |> map { peer in
                return peer.flatMap(EnginePeer.init)
            }
        } else {
            savedMessagesPeer = .single(nil)
        }
        
        let hideArchivedFolderByDefault = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatArchiveSettings])
        |> map { view -> Bool in
            let settings: ChatArchiveSettings = view.values[ApplicationSpecificPreferencesKeys.chatArchiveSettings]?.get(ChatArchiveSettings.self) ?? .default
            return settings.isHiddenByDefault
        }
        |> distinctUntilChanged
        
        let displayArchiveIntro: Signal<Bool, NoError>
        if case .archive = groupId {
            displayArchiveIntro = context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.archiveIntroDismissedKey())
            |> map { entry -> Bool in
                if let value = entry.value?.get(ApplicationSpecificVariantNotice.self) {
                    return !value.value
                } else {
                    return true
                }
            }
            |> take(1)
            |> afterNext { value in
                Queue.mainQueue().async {
                    if value {
                        let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
                            ApplicationSpecificNotice.setArchiveIntroDismissed(transaction: transaction, value: true)
                        }).start()
                    }
                }
            }
        } else {
            displayArchiveIntro = .single(false)
        }
        
        let currentPeerId: EnginePeer.Id = context.account.peerId
        
        let chatListNodeViewTransition = combineLatest(queue: viewProcessingQueue, hideArchivedFolderByDefault, displayArchiveIntro, savedMessagesPeer, chatListViewUpdate, self.statePromise.get())
        |> mapToQueue { (hideArchivedFolderByDefault, displayArchiveIntro, savedMessagesPeer, updateAndFilter, state) -> Signal<ChatListNodeListViewTransition, NoError> in
            let (update, filter) = updateAndFilter
            
            let previousHideArchivedFolderByDefaultValue = previousHideArchivedFolderByDefault.swap(hideArchivedFolderByDefault)
            
            let (rawEntries, isLoading) = chatListNodeEntriesForView(EngineChatList(update.view), state: state, savedMessagesPeer: savedMessagesPeer, foundPeers: state.foundPeers, hideArchivedFolderByDefault: hideArchivedFolderByDefault, displayArchiveIntro: displayArchiveIntro, mode: mode)
            let entries = rawEntries.filter { entry in
                switch entry {
                case let .PeerEntry(_, _, _, _, _, _, peer, _, _, _, _, _, _, _, _, _, _):
                    switch mode {
                        case .chatList:
                            return true
                        case let .peers(filter, _, _, _):
                            guard !filter.contains(.excludeSavedMessages) || peer.peerId != currentPeerId else { return false }
                            guard !filter.contains(.excludeSavedMessages) || !peer.peerId.isReplies else { return false }
                            guard !filter.contains(.excludeSecretChats) || peer.peerId.namespace != Namespaces.Peer.SecretChat else { return false }
                            guard !filter.contains(.onlyPrivateChats) || peer.peerId.namespace == Namespaces.Peer.CloudUser else { return false }
                        
                            if let peer = peer.peer {
                                switch peer {
                                    case let .user(user):
                                        if user.botInfo != nil {
                                            if filter.contains(.excludeBots) {
                                                return false
                                            }
                                        } else {
                                            if filter.contains(.excludeUsers) {
                                                return false
                                            }
                                        }
                                    case .legacyGroup:
                                        if filter.contains(.excludeGroups) {
                                            return false
                                        }
                                    case let .channel(channel):
                                        switch channel.info {
                                            case .broadcast:
                                                if filter.contains(.excludeChannels) {
                                                    return false
                                                }
                                            case .group:
                                                if filter.contains(.excludeGroups) {
                                                    return false
                                                }
                                        }
                                    default:
                                        break
                                }
                            }
                                                
                            if filter.contains(.onlyGroupsAndChannels) {
                                if case .channel = peer.chatMainPeer {
                                } else if case .legacyGroup = peer.chatMainPeer {
                                } else {
                                    return false
                                }
                            } else {
                                if filter.contains(.onlyGroups) {
                                    var isGroup: Bool = false
                                    if case let .channel(peer) = peer.chatMainPeer, case .group = peer.info {
                                        isGroup = true
                                    } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup {
                                        isGroup = true
                                    }
                                    if !isGroup {
                                        return false
                                    }
                                }
                                
                                if filter.contains(.onlyChannels) {
                                    if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                                    } else {
                                        return false
                                    }
                                }
                            }
                            
                            if filter.contains(.excludeChannels) {
                                if case let .channel(peer) = peer.chatMainPeer, case .broadcast = peer.info {
                                }
                            }
                            
                            if filter.contains(.onlyWriteable) && filter.contains(.excludeDisabled) {
                                if let peer = peer.peers[peer.peerId] {
                                    if !canSendMessagesToPeer(peer._asPeer()) {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                        
                            if filter.contains(.onlyManageable) && filter.contains(.excludeDisabled) {
                                if let peer = peer.peers[peer.peerId] {
                                    var canManage = false
                                    if case let .legacyGroup(peer) = peer {
                                        switch peer.role {
                                            case .creator, .admin:
                                                canManage = true
                                            default:
                                                break
                                        }
                                    }
                                    
                                    if canManage {
                                    } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.inviteMembers) {
                                    } else {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                            
                            return true
                        }
                    default:
                        return true
                }
            }
            
            let processedView = ChatListNodeView(originalView: update.view, filteredEntries: entries, isLoading: isLoading, filter: filter)
            let previousView = previousView.swap(processedView)
            let previousState = previousState.swap(state)
            
            let reason: ChatListNodeViewTransitionReason
            var prepareOnMainQueue = false
            
            var previousWasEmptyOrSingleHole = false
            if let previous = previousView {
                if previous.filteredEntries.count == 1 {
                    if case .HoleEntry = previous.filteredEntries[0] {
                        previousWasEmptyOrSingleHole = true
                    }
                } else if previous.filteredEntries.isEmpty && previous.isLoading {
                    previousWasEmptyOrSingleHole = true
                }
            } else {
                previousWasEmptyOrSingleHole = true
            }
            
            var updatedScrollPosition = update.scrollPosition
            
            if previousWasEmptyOrSingleHole {
                reason = .initial
                if previousView == nil {
                    prepareOnMainQueue = true
                }
            } else {
                if previousView?.originalView === update.view {
                    reason = .interactiveChanges
                    updatedScrollPosition = nil
                } else {
                    switch update.type {
                        case .InitialUnread, .Initial:
                            reason = .initial
                            prepareOnMainQueue = true
                        case .Generic:
                            reason = .interactiveChanges
                        case .UpdateVisible:
                            reason = .reload
                        case .FillHole:
                            reason = .reload
                    }
                }
            }
            
            let removingPeerId = currentRemovingPeerId.with { $0 }
            
            var disableAnimations = true
            if previousState.editing != state.editing {
                disableAnimations = false
            } else {
                var previousPinnedChats: [EnginePeer.Id] = []
                var updatedPinnedChats: [EnginePeer.Id] = []
                
                var didIncludeRemovingPeerId = false
                var didIncludeHiddenByDefaultArchive = false
                if let previous = previousView {
                    for entry in previous.filteredEntries {
                        if case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = entry {
                            if index.pinningIndex != nil {
                                previousPinnedChats.append(index.messageIndex.id.peerId)
                            }
                            if index.messageIndex.id.peerId == removingPeerId {
                                didIncludeRemovingPeerId = true
                            }
                        } else if case let .GroupReferenceEntry(_, _, _, _, _, _, _, _, hiddenByDefault) = entry {
                            didIncludeHiddenByDefaultArchive = hiddenByDefault
                        }
                    }
                }
                var doesIncludeRemovingPeerId = false
                var doesIncludeArchive = false
                var doesIncludeHiddenByDefaultArchive = false
                for entry in processedView.filteredEntries {
                    if case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = entry {
                        if index.pinningIndex != nil {
                            updatedPinnedChats.append(index.messageIndex.id.peerId)
                        }
                        if index.messageIndex.id.peerId == removingPeerId {
                            doesIncludeRemovingPeerId = true
                        }
                    } else if case let .GroupReferenceEntry(_, _, _, _, _, _, _, _, hiddenByDefault) = entry {
                        doesIncludeArchive = true
                        doesIncludeHiddenByDefaultArchive = hiddenByDefault
                    }
                }
                if previousPinnedChats != updatedPinnedChats {
                    disableAnimations = false
                }
                if previousState.selectedPeerIds != state.selectedPeerIds {
                    disableAnimations = false
                }
                if previousState.selectedAdditionalCategoryIds != state.selectedAdditionalCategoryIds {
                    disableAnimations = false
                }
                if doesIncludeRemovingPeerId != didIncludeRemovingPeerId {
                    disableAnimations = false
                }
                if hideArchivedFolderByDefault && previousState.archiveShouldBeTemporaryRevealed != state.archiveShouldBeTemporaryRevealed && doesIncludeArchive {
                    disableAnimations = false
                }
                if didIncludeHiddenByDefaultArchive != doesIncludeHiddenByDefaultArchive {
                    disableAnimations = false
                }
            }
            
            if let _ = previousHideArchivedFolderByDefaultValue, previousHideArchivedFolderByDefaultValue != hideArchivedFolderByDefault {
                disableAnimations = false
            }
            
            var searchMode = false
            if case .peers = mode {
                searchMode = true
            }
            
            if filter != previousView?.filter {
                disableAnimations = true
                updatedScrollPosition = nil
            }
            
            let filterData = filter.flatMap { filter -> ChatListItemFilterData? in
                if case let .filter(_, _, _, data) = filter {
                    return ChatListItemFilterData(excludesArchived: data.excludeArchived)
                } else {
                    return nil
                }
            }
            
            return preparedChatListNodeViewTransition(from: previousView, to: processedView, reason: reason, previewing: previewing, disableAnimations: disableAnimations, account: context.account, scrollPosition: updatedScrollPosition, searchMode: searchMode)
            |> map({ mappedChatListNodeViewListTransition(context: context, nodeInteraction: nodeInteraction, peerGroupId: groupId, filterData: filterData, mode: mode, transition: $0) })
            |> runOn(prepareOnMainQueue ? Queue.mainQueue() : viewProcessingQueue)
        }
        
        let appliedTransition = chatListNodeViewTransition |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            if let strongSelf = self {
                return strongSelf.enqueueTransition(transition)
            }
            return .complete()
        }
        
        self.displayedItemRangeChanged = { [weak self] range, transactionOpaqueState in
            if let strongSelf = self, let chatListView = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView {
                let originalView = chatListView.originalView
                if let range = range.loadedRange {
                    var location: ChatListNodeLocation?
                    if range.firstIndex < 5, let laterIndex = originalView.laterIndex {
                        location = .navigation(index: laterIndex, filter: strongSelf.chatListFilter)
                    } else if range.firstIndex >= 5, range.lastIndex >= originalView.entries.count - 5, let earlierIndex = originalView.earlierIndex {
                        location = .navigation(index: earlierIndex, filter: strongSelf.chatListFilter)
                    }
                    
                    if let location = location, location != strongSelf.currentLocation {
                        strongSelf.setChatListLocation(location)
                    }
                    
                    strongSelf.enqueueHistoryPreloadUpdate()
                }
                
                var archiveVisible = false
                if let range = range.visibleRange {
                    let entryCount = chatListView.filteredEntries.count
                    for i in range.firstIndex ..< range.lastIndex {
                        if i < 0 || i >= entryCount {
                            assertionFailure()
                            continue
                        }
                        switch chatListView.filteredEntries[entryCount - i - 1] {
                            case .PeerEntry:
                                break
                            case .GroupReferenceEntry:
                                archiveVisible = true
                            default:
                                break
                        }
                    }
                }
                if !archiveVisible && strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                    strongSelf.updateState { state in
                        var state = state
                        state.archiveShouldBeTemporaryRevealed = false
                        return state
                    }
                }
            }
        }
        
        self.interaction = nodeInteraction
        
        self.chatListDisposable.set(appliedTransition.start())
        
        let initialLocation: ChatListNodeLocation
        switch mode {
        case .chatList:
            initialLocation = .initial(count: 50, filter: self.chatListFilter)
        case .peers:
            initialLocation = .initial(count: 200, filter: self.chatListFilter)
        }
        self.setChatListLocation(initialLocation)
        
        let engine = context.engine
        let previousPeerCache = Atomic<[EnginePeer.Id: EnginePeer]>(value: [:])
        let previousActivities = Atomic<ChatListNodePeerInputActivities?>(value: nil)
        self.activityStatusesDisposable = (context.account.allPeerInputActivities()
        |> mapToSignal { activitiesByPeerId -> Signal<[EnginePeer.Id: [(EnginePeer, PeerInputActivity)]], NoError> in
            var activitiesByPeerId = activitiesByPeerId
            for key in activitiesByPeerId.keys {
                activitiesByPeerId[key]?.removeAll(where: { _, activity in
                    switch activity {
                    case .interactingWithEmoji:
                        return true
                    default:
                        return false
                    }
                })
            }
            
            var foundAllPeers = true
            var cachedResult: [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]] = [:]
            previousPeerCache.with { dict -> Void in
                for (chatPeerId, activities) in activitiesByPeerId {
                    guard case .global = chatPeerId.category else {
                        continue
                    }
                    var cachedChatResult: [(EnginePeer, PeerInputActivity)] = []
                    for (peerId, activity) in activities {
                        if let peer = dict[peerId] {
                            cachedChatResult.append((peer, activity))
                        } else {
                            foundAllPeers = false
                            break
                        }
                        cachedResult[chatPeerId.peerId] = cachedChatResult
                    }
                }
            }
            if foundAllPeers {
                return .single(cachedResult)
            } else {
                return engine.data.get(EngineDataMap(
                    activitiesByPeerId.keys.filter { key in
                        if case .global = key.category {
                            return false
                        } else {
                            return true
                        }
                    }.map { key in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: key.peerId)
                    }
                ))
                |> map { peerMap -> [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]] in
                    var result: [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]] = [:]
                    var peerCache: [EnginePeer.Id: EnginePeer] = [:]
                    for (chatPeerId, activities) in activitiesByPeerId {
                        guard case .global = chatPeerId.category else {
                            continue
                        }
                        var chatResult: [(EnginePeer, PeerInputActivity)] = []
                        
                        for (peerId, activity) in activities {
                            if let maybePeer = peerMap[peerId], let peer = maybePeer {
                                chatResult.append((peer, activity))
                                peerCache[peerId] = peer
                            }
                        }
                        
                        result[chatPeerId.peerId] = chatResult
                    }
                    let _ = previousPeerCache.swap(peerCache)
                    return result
                }
            }
        }
        |> map { activities -> ChatListNodePeerInputActivities? in
            return previousActivities.modify { current in
                var updated = false
                let currentList: [EnginePeer.Id: [(EnginePeer, PeerInputActivity)]] = current?.activities ?? [:]
                if currentList.count != activities.count {
                    updated = true
                } else {
                    outer: for (peerId, currentValue) in currentList {
                        if let value = activities[peerId] {
                            if currentValue.count != value.count {
                                updated = true
                                break outer
                            } else {
                                for i in 0 ..< currentValue.count {
                                    if currentValue[i].0 != value[i].0 {
                                        updated = true
                                        break outer
                                    }
                                    if currentValue[i].1 != value[i].1 {
                                        updated = true
                                        break outer
                                    }
                                }
                            }
                        } else {
                            updated = true
                            break outer
                        }
                    }
                }
                if updated {
                    if activities.isEmpty {
                        return nil
                    } else {
                        return ChatListNodePeerInputActivities(activities: activities)
                    }
                } else {
                    return current
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] activities in
            if let strongSelf = self {
                strongSelf.updateState { state in
                    var state = state
                    state.peerInputActivities = activities
                    return state
                }
            }
        })
        
        self.reorderItem = { [weak self] fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
            if let strongSelf = self, let filteredEntries = (transactionOpaqueState as? ChatListOpaqueTransactionState)?.chatListView.filteredEntries {
                if fromIndex >= 0 && fromIndex < filteredEntries.count && toIndex >= 0 && toIndex < filteredEntries.count {
                    let fromEntry = filteredEntries[filteredEntries.count - 1 - fromIndex]
                    let toEntry = filteredEntries[filteredEntries.count - 1 - toIndex]
                    
                    var referenceId: EngineChatList.PinnedItem.Id?
                    var beforeAll = false
                    switch toEntry {
                    case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, promoInfo, _, _):
                        if promoInfo != nil {
                            beforeAll = true
                        } else {
                            referenceId = .peer(index.messageIndex.id.peerId)
                        }
                        default:
                            break
                    }
                    
                    if case let .index(index) = fromEntry.sortIndex, let _ = index.pinningIndex {
                        let location: TogglePeerChatPinnedLocation
                        if let chatListFilter = chatListFilter {
                            location = .filter(chatListFilter.id)
                        } else {
                            location = .group(groupId._asGroup())
                        }

                        let engine = strongSelf.context.engine
                        return engine.peers.getPinnedItemIds(location: location)
                        |> mapToSignal { itemIds -> Signal<Bool, NoError> in
                            var itemIds = itemIds

                            var itemId: EngineChatList.PinnedItem.Id?
                            switch fromEntry {
                            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                                itemId = .peer(index.messageIndex.id.peerId)
                            default:
                                break
                            }

                            if let itemId = itemId {
                                itemIds = itemIds.filter({ $0 != itemId })
                                if let referenceId = referenceId {
                                    var inserted = false
                                    for i in 0 ..< itemIds.count {
                                        if itemIds[i] == referenceId {
                                            if fromIndex < toIndex {
                                                itemIds.insert(itemId, at: i + 1)
                                            } else {
                                                itemIds.insert(itemId, at: i)
                                            }
                                            inserted = true
                                            break
                                        }
                                    }
                                    if !inserted {
                                        itemIds.append(itemId)
                                    }
                                } else if beforeAll {
                                    itemIds.insert(itemId, at: 0)
                                } else {
                                    itemIds.append(itemId)
                                }
                                return engine.peers.reorderPinnedItemIds(location: location, itemIds: itemIds)
                            } else {
                                return .single(false)
                            }
                        }
                    }
                }
            }
            return .single(false)
        }
        var startedScrollingAtUpperBound = false
        
        self.beganInteractiveDragging = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.visibleContentOffset() {
                case .none, .unknown:
                    startedScrollingAtUpperBound = false
                case let .known(value):
                    startedScrollingAtUpperBound = value <= 0.0
            }
            if strongSelf.currentState.peerIdWithRevealedOptions != nil {
                strongSelf.updateState { state in
                    var state = state
                    state.peerIdWithRevealedOptions = nil
                    return state
                }
            }
        }
        
        self.didEndScrolling = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            startedScrollingAtUpperBound = false
            let _ = strongSelf.contentScrollingEnded?(strongSelf)
            let revealHiddenItems: Bool
            switch strongSelf.visibleContentOffset() {
                case .none, .unknown:
                    revealHiddenItems = false
                case let .known(value):
                    revealHiddenItems = value <= 54.0
            }
            if !revealHiddenItems && strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                strongSelf.updateState { state in
                    var state = state
                    state.archiveShouldBeTemporaryRevealed = false
                    return state
                }
            }
        }
        
        self.scrollToTopOptionPromise.set(combineLatest(
            renderedTotalUnreadCount(accountManager: self.context.sharedContext.accountManager, engine: self.context.engine) |> deliverOnMainQueue,
            self.scrolledAtTop.get()
        ) |> map { badge, scrolledAtTop -> ChatListGlobalScrollOption in
            if scrolledAtTop {
                return .none
            } else {
                return .top
            }
        })
        
        self.visibleContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            let atTop: Bool
            var revealHiddenItems: Bool = false
            switch offset {
                case .none, .unknown:
                    atTop = false
                case let .known(value):
                    atTop = value <= 0.0
                    if startedScrollingAtUpperBound && strongSelf.isTracking {
                        revealHiddenItems = value <= -60.0
                    }
            }
            strongSelf.scrolledAtTopValue = atTop
            strongSelf.contentOffsetChanged?(offset)
            if revealHiddenItems && !strongSelf.currentState.archiveShouldBeTemporaryRevealed {
                var isHiddenArchiveVisible = false
                strongSelf.forEachItemNode({ itemNode in
                    if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                        if case let .groupReference(_, _, _, _, hiddenByDefault) = item.content {
                            if hiddenByDefault {
                                isHiddenArchiveVisible = true
                            }
                        }
                    }
                })
                if isHiddenArchiveVisible {
                    if strongSelf.hapticFeedback == nil {
                        strongSelf.hapticFeedback = HapticFeedback()
                    }
                    strongSelf.hapticFeedback?.impact(.medium)
                    strongSelf.updateState { state in
                        var state = state
                        state.archiveShouldBeTemporaryRevealed = true
                        return state
                    }
                }
            }
        }
        
        self.resetFilter()
        
        let selectionRecognizer = ChatHistoryListSelectionRecognizer(target: self, action: #selector(self.selectionPanGesture(_:)))
        selectionRecognizer.shouldBegin = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.isSelectionGestureEnabled
        }
        self.view.addGestureRecognizer(selectionRecognizer)
    }
    
    deinit {
        self.chatListDisposable.dispose()
        self.activityStatusesDisposable?.dispose()
        self.updatedFilterDisposable.dispose()
    }
    
    func updateFilter(_ filter: ChatListFilter?) {
        if filter?.id != self.chatListFilter?.id {
            self.chatListFilter = filter
            self.resetFilter()
        }
    }
    
    private func resetFilter() {
        if let chatListFilter = self.chatListFilter {
            self.updatedFilterDisposable.set((self.context.engine.peers.updatedChatListFilters()
            |> map { filters -> ChatListFilter? in
                for filter in filters {
                    if filter.id == chatListFilter.id {
                        return filter
                    }
                }
                return nil
            }
            |> deliverOnMainQueue).start(next: { [weak self] updatedFilter in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.chatListFilter != updatedFilter {
                    strongSelf.chatListFilter = updatedFilter
                }
            }))
        } else {
            self.updatedFilterDisposable.set(nil)
        }
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        if theme !== self.currentState.presentationData.theme || strings !== self.currentState.presentationData.strings || dateTimeFormat != self.currentState.presentationData.dateTimeFormat {
            self.theme = theme
            if self.keepTopItemOverscrollBackground != nil {
                self.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color:  theme.chatList.pinnedItemBackgroundColor, direction: true)
            }
            self.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            
            self.updateState { state in
                var state = state
                state.presentationData = ChatListPresentationData(theme: theme, fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations)
                return state
            }
        }
    }
    
    public func updateState(_ f: (ChatListNodeState) -> ChatListNodeState) {
        let state = f(self.currentState)
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
    }
    
    private func enqueueTransition(_ transition: ChatListNodeListViewTransition) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if let _ = strongSelf.enqueuedTransition {
                    preconditionFailure()
                }
                
                strongSelf.enqueuedTransition = (transition, {
                    subscriber.putCompletion()
                })
                
                if strongSelf.isNodeLoaded, strongSelf.dequeuedInitialTransitionOnLayout {
                    strongSelf.dequeueTransition()
                } else {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                }
            } else {
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        } |> runOn(Queue.mainQueue())
    }
    
    private func dequeueTransition() {
        if let (transition, completion) = self.enqueuedTransition {
            self.enqueuedTransition = nil
            
            let completion: (ListViewDisplayedItemRange) -> Void = { [weak self] visibleRange in
                if let strongSelf = self {
                    strongSelf.chatListView = transition.chatListView
                    
                    if strongSelf.fillPreloadItems {
                        let filteredEntries = transition.chatListView.filteredEntries
                        var preloadItems: [ChatHistoryPreloadItem] = []
                        if transition.chatListView.originalView.laterIndex == nil {
                            for entry in filteredEntries.reversed() {
                                switch entry {
                                case let .PeerEntry(index, _, _, combinedReadState, isMuted, _, _, _, _, _, _, _, _, _, promoInfo, _, _):
                                    if promoInfo == nil {
                                        var hasUnread = false
                                        if let combinedReadState = combinedReadState {
                                            hasUnread = combinedReadState.count > 0
                                        }
                                        preloadItems.append(ChatHistoryPreloadItem(index: index, isMuted: isMuted, hasUnread: hasUnread))
                                    }
                                default:
                                    break
                                }
                                if preloadItems.count >= 30 {
                                    break
                                }
                            }
                        }
                        strongSelf.preloadItems.set(.single(preloadItems))
                    }
                    
                    var pinnedOverscroll = false
                    if case .chatList = strongSelf.mode {
                        let entryCount = transition.chatListView.filteredEntries.count
                        if entryCount >= 1 {
                            if case let .index(index) = transition.chatListView.filteredEntries[entryCount - 1].sortIndex, index.pinningIndex != nil {
                                pinnedOverscroll = true
                            }
                        }
                    }
                    
                    if pinnedOverscroll != (strongSelf.keepTopItemOverscrollBackground != nil) {
                        if pinnedOverscroll {
                            strongSelf.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: strongSelf.theme.chatList.pinnedItemBackgroundColor, direction: true)
                        } else {
                            strongSelf.keepTopItemOverscrollBackground = nil
                        }
                    }
                    
                    if let scrollToItem = transition.scrollToItem, case .center = scrollToItem.position {
                        if let itemNode = strongSelf.itemNodeAtIndex(scrollToItem.index) as? ChatListItemNode {
                            itemNode.flashHighlight()
                        }
                    }
                    
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(true)
                    }
                    if !strongSelf.didSetContentsReady {
                        strongSelf.didSetContentsReady = true
                        strongSelf._contentsReady.set(true)
                    }
                    
                    var isEmpty = false
                    var isLoading = false
                    var hasArchiveInfo = false
                    if transition.chatListView.filteredEntries.isEmpty {
                        isEmpty = true
                    } else {
                        if transition.chatListView.filteredEntries.count <= 2 {
                            isEmpty = true
                            loop1: for entry in transition.chatListView.filteredEntries {
                                switch entry {
                                case .GroupReferenceEntry, .HeaderEntry, .HoleEntry:
                                    break
                                default:
                                    if case .ArchiveIntro = entry {
                                        hasArchiveInfo = true
                                    }
                                    isEmpty = false
                                    break loop1
                                }
                            }
                            isLoading = true
                            var hasHoles = false
                            loop2: for entry in transition.chatListView.filteredEntries {
                                switch entry {
                                case .HoleEntry:
                                    hasHoles = true
                                case .HeaderEntry:
                                    break
                                default:
                                    isLoading = false
                                    break loop2
                                }
                            }
                            if !hasHoles {
                                isLoading = false
                            }
                        } else {
                            for entry in transition.chatListView.filteredEntries.reversed().prefix(2) {
                                if case .ArchiveIntro = entry {
                                    hasArchiveInfo = true
                                    break
                                }
                            }
                        }
                    }
                
                    let isEmptyState: ChatListNodeEmptyState
                    if transition.chatListView.isLoading {
                        isEmptyState = .empty(isLoading: true, hasArchiveInfo: hasArchiveInfo)
                    } else if isEmpty {
                        isEmptyState = .empty(isLoading: isLoading, hasArchiveInfo: false)
                    } else {
                        var containsChats = false
                        loop: for entry in transition.chatListView.filteredEntries {
                            switch entry {
                            case .GroupReferenceEntry, .HoleEntry, .PeerEntry:
                                containsChats = true
                                break loop
                            case .ArchiveIntro, .HeaderEntry, .AdditionalCategory:
                                break
                            }
                        }
                        isEmptyState = .notEmpty(containsChats: containsChats)
                    }
                    
                    var insertedPeerIds: [EnginePeer.Id] = []
                    for item in transition.insertItems {
                        if let item = item.item as? ChatListItem {
                            switch item.content {
                                case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _, _):
                                    insertedPeerIds.append(peer.peerId)
                                case .groupReference:
                                    break
                            }
                        }
                    }
                    if !insertedPeerIds.isEmpty {
                        strongSelf.addedVisibleChatsWithPeerIds?(insertedPeerIds)
                    }
                    
                    var isEmptyUpdate: ContainedViewLayoutTransition = .immediate
                    if transition.options.contains(.AnimateInsertion) || transition.animateCrossfade {
                        isEmptyUpdate = .animated(duration: 0.25, curve: .easeInOut)
                    }
                    
                    if strongSelf.currentIsEmptyState != isEmptyState {
                        strongSelf.currentIsEmptyState = isEmptyState
                        strongSelf.isEmptyUpdated?(isEmptyState, transition.chatListView.filter != nil, isEmptyUpdate)
                    }
                    
                    if !strongSelf.hasUpdatedAppliedChatListFilterValueOnce || transition.chatListView.filter != strongSelf.currentAppliedChatListFilterValue {
                        strongSelf.currentAppliedChatListFilterValue = transition.chatListView.filter
                        strongSelf.appliedChatListFilterValue.set(.single(transition.chatListView.filter))
                    }
                    
                    completion()
                }
            }
            
            var options = transition.options
            if self.view.window != nil {
                if !options.contains(.AnimateInsertion) {
                    options.insert(.PreferSynchronousDrawing)
                    options.insert(.PreferSynchronousResourceLoading)
                }
                if options.contains(.AnimateCrossfade) && !self.isDeceleratingAfterTracking {
                    options.insert(.PreferSynchronousDrawing)
                }
            }
            
            var scrollToItem = transition.scrollToItem
            if transition.adjustScrollToFirstItem {
                var offset: CGFloat = 0.0
                switch self.visibleContentOffset() {
                case let .known(value) where abs(value) < .ulpOfOne:
                    offset = 0.0
                default:
                    offset = -navigationBarSearchContentHeight
                }
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(offset), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
            
            self.transaction(deleteIndices: transition.deleteItems, insertIndicesAndItems: transition.insertItems, updateIndicesAndItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: transition.stationaryItemRange, updateOpaqueState: ChatListOpaqueTransactionState(chatListView: transition.chatListView), completion: completion)
        }
    }
    
    var isNavigationHidden: Bool {
        switch self.visibleContentOffset() {
        case let .known(value) where abs(value) < navigationBarSearchContentHeight - 1.0:
            return false
        default:
            return true
        }
    }
    
    var isNavigationInAFinalState: Bool {
        switch self.visibleContentOffset() {
        case let .known(value):
            if value < navigationBarSearchContentHeight - 1.0 {
                if abs(value - 0.0) < 1.0 {
                    return true
                }
                if abs(value - navigationBarSearchContentHeight) < 1.0 {
                    return true
                }
                return false
            } else {
                return true
            }
        default:
            return true
        }
    }
    
    func adjustScrollOffsetForNavigation(isNavigationHidden: Bool) {
        if self.isNavigationHidden == isNavigationHidden {
            return
        }
        var scrollToItem: ListViewScrollToItem?
        switch self.visibleContentOffset() {
        case let .known(value) where abs(value) < navigationBarSearchContentHeight - 1.0:
            if isNavigationHidden {
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
        default:
            if !isNavigationHidden {
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
            }
        }
        if let scrollToItem = scrollToItem {
            self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: scrollToItem, updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets) {
        self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueTransition()
        }
    }
    
    public func scrollToPosition(_ position: ChatListNodeScrollPosition) {
        if let view = self.chatListView?.originalView {
            if view.laterIndex == nil {
                self.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            } else {
                let location: ChatListNodeLocation = .scroll(index: .absoluteUpperBound, sourceIndex: .absoluteLowerBound, scrollPosition: .top(0.0), animated: true, filter: self.chatListFilter)
                self.setChatListLocation(location)
            }
        } else {
            let location: ChatListNodeLocation = .scroll(index: .absoluteUpperBound, sourceIndex: .absoluteLowerBound
                , scrollPosition: .top(0.0), animated: true, filter: self.chatListFilter)
            self.setChatListLocation(location)
        }
    }
    
    private func setChatListLocation(_ location: ChatListNodeLocation) {
        self.currentLocation = location
        self.chatListLocation.set(location)
    }
    
    private func relativeUnreadChatListIndex(position: EngineChatList.RelativePosition) -> Signal<EngineChatList.Item.Index?, NoError> {
        let groupId = self.groupId
        let engine = self.context.engine
        return self.context.sharedContext.accountManager.transaction { transaction -> Signal<EngineChatList.Item.Index?, NoError> in
            var filter = true
            if let inAppNotificationSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings)?.get(InAppNotificationSettings.self) {
                switch inAppNotificationSettings.totalUnreadCountDisplayStyle {
                    case .filtered:
                        filter = true
                }
            }
            return engine.messages.getRelativeUnreadChatListIndex(filtered: filter, position: position, groupId: groupId)
        }
        |> switchToLatest
    }
    
    public func selectChat(_ option: ChatListSelectionOption) {
        guard let interaction = self.interaction else {
            return
        }
        
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return
        }
        
        guard let range = self.displayedItemRange.loadedRange else {
            return
        }
        
        let entryCount = chatListView.filteredEntries.count
        var current: (EngineChatList.Item.Index, EnginePeer, Int)? = nil
        var previous: (EngineChatList.Item.Index, EnginePeer)? = nil
        var next: (EngineChatList.Item.Index, EnginePeer)? = nil
        
        outer: for i in range.firstIndex ..< range.lastIndex {
            if i < 0 || i >= entryCount {
                assertionFailure()
                continue
            }
            switch chatListView.filteredEntries[entryCount - i - 1] {
                case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _, _, _, _):
                    if interaction.highlightedChatLocation?.location == ChatLocation.peer(id: peer.peerId) {
                        current = (index, peer.peer!, entryCount - i - 1)
                        break outer
                    }
                default:
                    break
            }
        }
        
        switch option {
            case .previous(unread: true), .next(unread: true):
                let position: EngineChatList.RelativePosition
                if let current = current {
                    if case .previous = option {
                        position = .earlier(than: current.0)
                    } else {
                        position = .later(than: current.0)
                    }
                } else {
                    position = .later(than: nil)
                }
                let engine = self.context.engine
                let _ = (relativeUnreadChatListIndex(position: position)
                |> mapToSignal { index -> Signal<(EngineChatList.Item.Index, EnginePeer)?, NoError> in
                    if let index = index {
                        return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: index.messageIndex.id.peerId))
                        |> map { peer -> (EngineChatList.Item.Index, EnginePeer)? in
                            return peer.flatMap { peer -> (EngineChatList.Item.Index, EnginePeer)? in
                                (index, peer)
                            }
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] indexAndPeer in
                    guard let strongSelf = self, let (index, peer) = indexAndPeer else {
                        return
                    }
                    let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: strongSelf.currentlyVisibleLatestChatListIndex() ?? .absoluteUpperBound, scrollPosition: .center(.top), animated: true, filter: strongSelf.chatListFilter)
                    strongSelf.setChatListLocation(location)
                    strongSelf.peerSelected?(peer, false, false, nil)
                })
            case .previous(unread: false), .next(unread: false):
                var target: (EngineChatList.Item.Index, EnginePeer)? = nil
                if let current = current, entryCount > 1 {
                    if current.2 > 0, case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _, _, _, _) = chatListView.filteredEntries[current.2 - 1] {
                        next = (index, peer.peer!)
                    }
                    if current.2 <= entryCount - 2, case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _, _, _, _) = chatListView.filteredEntries[current.2 + 1] {
                        previous = (index, peer.peer!)
                    }
                    if case .previous = option {
                        target = previous
                    } else {
                        target = next
                    }
                } else if entryCount > 0 {
                    if case let .PeerEntry(index, _, _, _, _, _, peer, _, _, _, _, _, _, _, _, _, _) = chatListView.filteredEntries[entryCount - 1] {
                        target = (index, peer.peer!)
                    }
                }
                if let target = target {
                    let location: ChatListNodeLocation = .scroll(index: target.0, sourceIndex: .absoluteLowerBound, scrollPosition: .center(.top), animated: true, filter: self.chatListFilter)
                    self.setChatListLocation(location)
                    self.peerSelected?(target.1, false, false, nil)
                }
            case let .peerId(peerId):
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let strongSelf = self, let peer = peer else {
                        return
                    }
                    strongSelf.peerSelected?(peer, false, false, nil)
                })
            case let .index(index):
                guard index < 10 else {
                    return
                }
                let _ = (self.chatListFilterValue.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] filter in
                    guard let self = self else {
                        return
                    }
                    let _ = (chatListViewForLocation(groupId: self.groupId._asGroup(), location: .initial(count: 10, filter: filter), account: self.context.account)
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { update in
                        let entries = update.view.entries
                        if entries.count > index, case let .MessageEntry(index, _, _, _, _, renderedPeer, _, _, _, _) = entries[10 - index - 1] {
                            let location: ChatListNodeLocation = .scroll(index: index, sourceIndex: .absoluteLowerBound, scrollPosition: .center(.top), animated: true, filter: filter)
                            self.setChatListLocation(location)
                            self.peerSelected?(EnginePeer(renderedPeer.peer!), false, false, nil)
                        }
                    })
                })
        }
    }
    
    private func enqueueHistoryPreloadUpdate() {
    }
    
    public func updateSelectedChatLocation(_ chatLocation: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let interaction = self.interaction else {
            return
        }
        
        if let chatLocation = chatLocation {
            interaction.highlightedChatLocation = ChatListHighlightedLocation(location: chatLocation, progress: progress)
        } else {
            interaction.highlightedChatLocation = nil
        }
        
        self.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListItemNode {
                itemNode.updateIsHighlighted(transition: transition)
            }
        }
    }
    
    private func currentlyVisibleLatestChatListIndex() -> EngineChatList.Item.Index? {
        guard let chatListView = (self.opaqueTransactionState as? ChatListOpaqueTransactionState)?.chatListView else {
            return nil
        }
        if let range = self.displayedItemRange.visibleRange {
            let entryCount = chatListView.filteredEntries.count
            for i in range.firstIndex ..< range.lastIndex {
                if i < 0 || i >= entryCount {
                    assertionFailure()
                    continue
                }
                switch chatListView.filteredEntries[entryCount - i - 1] {
                    case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        return index
                    default:
                        break
                }
            }
        }
        return nil
    }
    
    private func peerAtPoint(_ point: CGPoint) -> EnginePeer? {
        var resultPeer: EnginePeer?
        self.forEachVisibleItemNode { itemNode in
            if resultPeer == nil, let itemNode = itemNode as? ListViewItemNode, itemNode.frame.contains(point) {
                if let itemNode = itemNode as? ChatListItemNode, let item = itemNode.item {
                    switch item.content {
                        case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _, _):
                            resultPeer = peer.peer
                        default:
                            break
                    }
                }
            }
        }
        return resultPeer
    }
    
    private var selectionPanState: (selecting: Bool, initialPeerId: EnginePeer.Id, toggledPeerIds: [[EnginePeer.Id]])?
    private var selectionScrollActivationTimer: SwiftSignalKit.Timer?
    private var selectionScrollDisplayLink: ConstantDisplayLinkAnimator?
    private var selectionScrollDelta: CGFloat?
    private var selectionLastLocation: CGPoint?
    
    @objc private func selectionPanGesture(_ recognizer: UIGestureRecognizer) -> Void {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .began:
                if let peer = self.peerAtPoint(location) {
                    let selecting = !self.currentState.selectedPeerIds.contains(peer.id)
                    self.selectionPanState = (selecting, peer.id, [])
                    self.interaction?.togglePeersSelection([.peer(peer)], selecting)
                }
            case .changed:
                self.handlePanSelection(location: location)
                self.selectionLastLocation = location
            case .ended, .failed, .cancelled:
                self.selectionPanState = nil
                self.selectionScrollDisplayLink = nil
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
                self.selectionScrollDelta = nil
                self.selectionLastLocation = nil
                self.selectionScrollSkipUpdate = false
            case .possible:
                break
            @unknown default:
                fatalError()
        }
    }
    
    private func handlePanSelection(location: CGPoint) {
        var location = location
        if location.y < self.insets.top {
            location.y = self.insets.top + 5.0
        } else if location.y > self.frame.height - self.insets.bottom {
            location.y = self.frame.height - self.insets.bottom - 5.0
        }
        
        if let state = self.selectionPanState {
            if let peer = self.peerAtPoint(location) {
                if peer.id == state.initialPeerId {
                    if !state.toggledPeerIds.isEmpty {
                        self.interaction?.togglePeersSelection(state.toggledPeerIds.flatMap { $0.compactMap({ .peerId($0) }) }, !state.selecting)
                        self.selectionPanState = (state.selecting, state.initialPeerId, [])
                    }
                } else if state.toggledPeerIds.last?.first != peer.id {
                    var updatedToggledPeerIds: [[EnginePeer.Id]] = []
                    var previouslyToggled = false
                    for i in (0 ..< state.toggledPeerIds.count) {
                        if let peerId = state.toggledPeerIds[i].first {
                            if peerId == peer.id {
                                previouslyToggled = true
                                updatedToggledPeerIds = Array(state.toggledPeerIds.prefix(i + 1))
                                
                                let peerIdsToToggle = Array(state.toggledPeerIds.suffix(state.toggledPeerIds.count - i - 1)).flatMap { $0 }
                                self.interaction?.togglePeersSelection(peerIdsToToggle.compactMap { .peerId($0) }, !state.selecting)
                                break
                            }
                        }
                    }
                    
                    if !previouslyToggled {
                        updatedToggledPeerIds = state.toggledPeerIds
                        let isSelected = self.currentState.selectedPeerIds.contains(peer.id)
                        if state.selecting != isSelected {
                            updatedToggledPeerIds.append([peer.id])
                            self.interaction?.togglePeersSelection([.peer(peer)], state.selecting)
                        }
                    }
                    
                    self.selectionPanState = (state.selecting, state.initialPeerId, updatedToggledPeerIds)
                }
            }
        
            let scrollingAreaHeight: CGFloat = 50.0
            if location.y < scrollingAreaHeight + self.insets.top || location.y > self.frame.height - scrollingAreaHeight - self.insets.bottom {
                if location.y < self.frame.height / 2.0 {
                    self.selectionScrollDelta = (scrollingAreaHeight - (location.y - self.insets.top)) / scrollingAreaHeight
                } else {
                    self.selectionScrollDelta = -(scrollingAreaHeight - min(scrollingAreaHeight, max(0.0, (self.frame.height - self.insets.bottom - location.y)))) / scrollingAreaHeight
                }
                if let displayLink = self.selectionScrollDisplayLink {
                    displayLink.isPaused = false
                } else {
                    if let _ = self.selectionScrollActivationTimer {
                    } else {
                        let timer = SwiftSignalKit.Timer(timeout: 0.45, repeat: false, completion: { [weak self] in
                            self?.setupSelectionScrolling()
                        }, queue: .mainQueue())
                        timer.start()
                        self.selectionScrollActivationTimer = timer
                    }
                }
            } else {
                self.selectionScrollDisplayLink?.isPaused = true
                self.selectionScrollActivationTimer?.invalidate()
                self.selectionScrollActivationTimer = nil
            }
        }
    }
    
    private var selectionScrollSkipUpdate = false
    private func setupSelectionScrolling() {
        self.selectionScrollDisplayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.selectionScrollActivationTimer = nil
            if let strongSelf = self, let delta = strongSelf.selectionScrollDelta {
                let distance: CGFloat = 15.0 * min(1.0, 0.15 + abs(delta * delta))
                let direction: ListViewScrollDirection = delta > 0.0 ? .up : .down
                let _ = strongSelf.scrollWithDirection(direction, distance: distance)
                
                if let location = strongSelf.selectionLastLocation {
                    if !strongSelf.selectionScrollSkipUpdate {
                        strongSelf.handlePanSelection(location: location)
                    }
                    strongSelf.selectionScrollSkipUpdate = !strongSelf.selectionScrollSkipUpdate
                }
            }
        })
        self.selectionScrollDisplayLink?.isPaused = false
    }
}

private func statusStringForPeerType(accountPeerId: EnginePeer.Id, strings: PresentationStrings, peer: EnginePeer, isMuted: Bool, isUnread: Bool, isContact: Bool, hasUnseenMentions: Bool, chatListFilters: [ChatListFilter]?) -> (String, Bool)? {
    if accountPeerId == peer.id {
        return nil
    }
    
    if let chatListFilters = chatListFilters {
        var result = ""
        for case let .filter(_, title, _, data) in chatListFilters {
            let predicate = chatListFilterPredicate(filter: data)
            if predicate.includes(peer: peer._asPeer(), groupId: .root, isRemovedFromTotalUnreadCount: isMuted, isUnread: isUnread, isContact: isContact, messageTagSummaryResult: hasUnseenMentions) {
                if !result.isEmpty {
                    result.append(", ")
                }
                result.append(title)
            }
        }
        
        if result.isEmpty {
            return nil
        } else {
            return (result, true)
        }
    }
    
    if peer.id.isReplies {
        return nil
    } else if case let .user(user) = peer {
        if user.botInfo != nil || user.flags.contains(.isSupport) {
            return (strings.ChatList_PeerTypeBot, false)
        } else if isContact {
            return (strings.ChatList_PeerTypeContact, false)
        } else {
            return (strings.ChatList_PeerTypeNonContact, false)
        }
    } else if case .secretChat = peer {
        if isContact {
            return (strings.ChatList_PeerTypeContact, false)
        } else {
            return (strings.ChatList_PeerTypeNonContact, false)
        }
    } else if case .legacyGroup = peer {
        return (strings.ChatList_PeerTypeGroup, false)
    } else if case let .channel(channel) = peer {
        if case .group = channel.info {
            return (strings.ChatList_PeerTypeGroup, false)
        } else {
            return (strings.ChatList_PeerTypeChannel, false)
        }
    }
    return (strings.ChatList_PeerTypeNonContact, false)
}

public class ChatHistoryListSelectionRecognizer: UIPanGestureRecognizer {
    private let selectionGestureActivationThreshold: CGFloat = 5.0
    
    var recognized: Bool? = nil
    var initialLocation: CGPoint = CGPoint()
    
    public var shouldBegin: (() -> Bool)?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.minimumNumberOfTouches = 2
        self.maximumNumberOfTouches = 2
    }
    
    public override func reset() {
        super.reset()
        
        self.recognized = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let shouldBegin = self.shouldBegin, !shouldBegin() {
            self.state = .failed
        } else {
            let touch = touches.first!
            self.initialLocation = touch.location(in: self.view)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = location.offsetBy(dx: -self.initialLocation.x, dy: -self.initialLocation.y)
        
        let touchesArray = Array(touches)
        if self.recognized == nil, touchesArray.count == 2 {
            if let firstTouch = touchesArray.first, let secondTouch = touchesArray.last {
                let firstLocation = firstTouch.location(in: self.view)
                let secondLocation = secondTouch.location(in: self.view)
                
                func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
                    let dx = v1.x - v2.x
                    let dy = v1.y - v2.y
                    return sqrt(dx * dx + dy * dy)
                }
                if distance(firstLocation, secondLocation) > 200.0 {
                    self.state = .failed
                }
            }
            if self.state != .failed && (abs(translation.y) >= selectionGestureActivationThreshold) {
                self.recognized = true
            }
        }
        
        if let recognized = self.recognized, recognized {
            super.touchesMoved(touches, with: event)
        }
    }
}
