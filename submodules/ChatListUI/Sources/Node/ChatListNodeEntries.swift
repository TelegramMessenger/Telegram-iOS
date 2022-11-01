import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import AccountContext

enum ChatListNodeEntryId: Hashable {
    case Header
    case Hole(Int64)
    case PeerId(Int64)
    case ThreadId(Int64)
    case GroupId(EngineChatList.Group)
    case ArchiveIntro
    case additionalCategory(Int)
}

enum ChatListNodeEntrySortIndex: Comparable {
    case index(EngineChatList.Item.Index)
    case additionalCategory(Int)
    
    static func <(lhs: ChatListNodeEntrySortIndex, rhs: ChatListNodeEntrySortIndex) -> Bool {
        switch lhs {
        case let .index(lhsIndex):
            switch rhs {
            case let .index(rhsIndex):
                return lhsIndex < rhsIndex
            case .additionalCategory:
                return false
            }
        case let .additionalCategory(lhsIndex):
            switch rhs {
            case let .additionalCategory(rhsIndex):
                return lhsIndex < rhsIndex
            case .index:
                return true
            }
        }
    }
}

public enum ChatListNodeEntryPromoInfo: Equatable {
    case proxy
    case psa(type: String, message: String?)
}

enum ChatListNodeEntry: Comparable, Identifiable {
    case HeaderEntry
    case PeerEntry(
        index: EngineChatList.Item.Index,
        presentationData: ChatListPresentationData,
        messages: [EngineMessage],
        readState: EnginePeerReadCounters?,
        isRemovedFromTotalUnreadCount: Bool,
        draftState: ChatListItemContent.DraftState?,
        peer: EngineRenderedPeer,
        threadInfo: ChatListItemContent.ThreadInfo?,
        presence: EnginePeer.Presence?,
        hasUnseenMentions: Bool,
        hasUnseenReactions: Bool,
        editing: Bool,
        hasActiveRevealControls: Bool,
        selected: Bool,
        inputActivities: [(EnginePeer, PeerInputActivity)]?,
        promoInfo: ChatListNodeEntryPromoInfo?,
        hasFailedMessages: Bool,
        isContact: Bool,
        forumTopicData: EngineChatList.ForumTopicData?
    )
    case HoleEntry(EngineMessage.Index, theme: PresentationTheme)
    case GroupReferenceEntry(index: EngineChatList.Item.Index, presentationData: ChatListPresentationData, groupId: EngineChatList.Group, peers: [EngineChatList.GroupItem.Item], message: EngineMessage?, editing: Bool, unreadCount: Int, revealed: Bool, hiddenByDefault: Bool)
    case ArchiveIntro(presentationData: ChatListPresentationData)
    case AdditionalCategory(index: Int, id: Int, title: String, image: UIImage?, appearance: ChatListNodeAdditionalCategory.Appearance, selected: Bool, presentationData: ChatListPresentationData)
    
    var sortIndex: ChatListNodeEntrySortIndex {
        switch self {
        case .HeaderEntry:
            return .index(.chatList(.absoluteUpperBound))
        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            return .index(index)
        case let .HoleEntry(holeIndex, _):
            return .index(.chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: holeIndex)))
        case let .GroupReferenceEntry(index, _, _, _, _, _, _, _, _):
            return .index(index)
        case .ArchiveIntro:
            return .index(.chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.successor))
        case let .AdditionalCategory(index, _, _, _, _, _, _):
            return .additionalCategory(index)
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
        case .HeaderEntry:
            return .Header
        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            switch index {
            case let .chatList(index):
                return .PeerId(index.messageIndex.id.peerId.toInt64())
            case let .forum(_, _, threadId, _, _):
                return .ThreadId(threadId)
            }
        case let .HoleEntry(holeIndex, _):
            return .Hole(Int64(holeIndex.id.id))
        case let .GroupReferenceEntry(_, _, groupId, _, _, _, _, _, _):
            return .GroupId(groupId)
        case .ArchiveIntro:
            return .ArchiveIntro
        case let .AdditionalCategory(_, id, _, _, _, _, _):
            return .additionalCategory(id)
        }
    }
    
    static func <(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    static func ==(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        switch lhs {
            case .HeaderEntry:
                if case .HeaderEntry = rhs {
                    return true
                } else {
                    return false
                }
            case let .PeerEntry(lhsIndex, lhsPresentationData, lhsMessages, lhsUnreadCount, lhsIsRemovedFromTotalUnreadCount, lhsEmbeddedState, lhsPeer, lhsThreadInfo, lhsPresence, lhsHasUnseenMentions, lhsHasUnseenReactions, lhsEditing, lhsHasRevealControls, lhsSelected, lhsInputActivities, lhsAd, lhsHasFailedMessages, lhsIsContact, lhsForumThreadTitle):
                switch rhs {
                    case let .PeerEntry(rhsIndex, rhsPresentationData, rhsMessages, rhsUnreadCount, rhsIsRemovedFromTotalUnreadCount, rhsEmbeddedState, rhsPeer, rhsThreadInfo, rhsPresence, rhsHasUnseenMentions, rhsHasUnseenReactions, rhsEditing, rhsHasRevealControls, rhsSelected, rhsInputActivities, rhsAd, rhsHasFailedMessages, rhsIsContact, rhsForumThreadTitle):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsUnreadCount != rhsUnreadCount {
                            return false
                        }
                        if lhsMessages.count != rhsMessages.count {
                            return false
                        }
                        for i in 0 ..< lhsMessages.count {
                            if lhsMessages[i].stableVersion != rhsMessages[i].stableVersion {
                                return false
                            }
                            if lhsMessages[i].id != rhsMessages[i].id {
                                return false
                            }
                            if lhsMessages[i].associatedMessages.count != rhsMessages[i].associatedMessages.count {
                                return false
                            }
                            for (id, message) in lhsMessages[i].associatedMessages {
                                if let otherMessage = rhsMessages[i].associatedMessages[id] {
                                    if message.stableVersion != otherMessage.stableVersion {
                                        return false
                                    }
                                } else {
                                    return false
                                }
                            }
                        }
                        if lhsIsRemovedFromTotalUnreadCount != rhsIsRemovedFromTotalUnreadCount {
                            return false
                        }
                        if let lhsPeerPresence = lhsPresence, let rhsPeerPresence = rhsPresence {
                            if lhsPeerPresence != rhsPeerPresence {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if lhsEmbeddedState != rhsEmbeddedState {
                                return false
                            }
                        } else if (lhsEmbeddedState != nil) != (rhsEmbeddedState != nil) {
                            return false
                        }
                        if lhsEditing != rhsEditing {
                            return false
                        }
                        if lhsHasRevealControls != rhsHasRevealControls {
                            return false
                        }
                        if lhsSelected != rhsSelected {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        if lhsThreadInfo != rhsThreadInfo {
                            return false
                        }
                        if lhsHasUnseenMentions != rhsHasUnseenMentions {
                            return false
                        }
                        if lhsHasUnseenReactions != rhsHasUnseenReactions {
                            return false
                        }
                        if let lhsInputActivities = lhsInputActivities, let rhsInputActivities = rhsInputActivities {
                            if lhsInputActivities.count != rhsInputActivities.count {
                                return false
                            }
                            for i in 0 ..< lhsInputActivities.count {
                                if lhsInputActivities[i].0 != rhsInputActivities[i].0 {
                                    return false
                                }
                                if lhsInputActivities[i].1 != rhsInputActivities[i].1 {
                                    return false
                                }
                            }
                        } else if (lhsInputActivities != nil) != (rhsInputActivities != nil) {
                            return false
                        }
                        if lhsAd != rhsAd {
                            return false
                        }
                        if lhsHasFailedMessages != rhsHasFailedMessages {
                            return false
                        }
                        if lhsIsContact != rhsIsContact {
                            return false
                        }
                        if lhsForumThreadTitle != rhsForumThreadTitle {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .HoleEntry(lhsHole, lhsTheme):
                switch rhs {
                    case let .HoleEntry(rhsHole, rhsTheme):
                        return lhsHole == rhsHole && lhsTheme === rhsTheme
                    default:
                        return false
                }
            case let .GroupReferenceEntry(lhsIndex, lhsPresentationData, lhsGroupId, lhsPeers, lhsMessage, lhsEditing, lhsUnreadState, lhsRevealed, lhsHiddenByDefault):
                if case let .GroupReferenceEntry(rhsIndex, rhsPresentationData, rhsGroupId, rhsPeers, rhsMessage, rhsEditing, rhsUnreadState, rhsRevealed, rhsHiddenByDefault) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsGroupId != rhsGroupId {
                        return false
                    }
                    if lhsPeers != rhsPeers {
                        return false
                    }
                    if lhsMessage?.stableId != rhsMessage?.stableId {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsUnreadState != rhsUnreadState {
                        return false
                    }
                    if lhsRevealed != rhsRevealed {
                        return false
                    }
                    if lhsHiddenByDefault != rhsHiddenByDefault {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .ArchiveIntro(lhsPresentationData):
                if case let .ArchiveIntro(rhsPresentationData) = rhs {
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .AdditionalCategory(lhsIndex, lhsId, lhsTitle, lhsImage, lhsAppearance, lhsSelected, lhsPresentationData):
                if case let .AdditionalCategory(rhsIndex, rhsId, rhsTitle, rhsImage, rhsAppearance, rhsSelected, rhsPresentationData) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsId != rhsId {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsImage !== rhsImage {
                        return false
                    }
                    if lhsAppearance != rhsAppearance {
                        return false
                    }
                    if lhsSelected != rhsSelected {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}

private func offsetPinnedIndex(_ index: EngineChatList.Item.Index, offset: UInt16) -> EngineChatList.Item.Index {
    if case let .chatList(index) = index, let pinningIndex = index.pinningIndex {
        return .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: pinningIndex + offset, messageIndex: index.messageIndex))
    } else {
        return index
    }
}

func chatListNodeEntriesForView(_ view: EngineChatList, state: ChatListNodeState, savedMessagesPeer: EnginePeer?, foundPeers: [(EnginePeer, EnginePeer?)], hideArchivedFolderByDefault: Bool, displayArchiveIntro: Bool, mode: ChatListNodeMode, chatListLocation: ChatListControllerLocation) -> (entries: [ChatListNodeEntry], loading: Bool) {
    var result: [ChatListNodeEntry] = []
    
    var pinnedIndexOffset: UInt16 = 0
    
    if !view.hasLater, case .chatList = mode {
        var groupEntryCount = 0
        for _ in view.groupItems {
            groupEntryCount += 1
        }
        pinnedIndexOffset += UInt16(groupEntryCount)
    }
    
    let filteredAdditionalItemEntries = view.additionalItems.filter { item -> Bool in
        return item.item.renderedPeer.peerId != state.hiddenPsaPeerId
    }
    
    var foundPeerIds = Set<EnginePeer.Id>()
    for peer in foundPeers {
        foundPeerIds.insert(peer.0.id)
    }
    
    if !view.hasLater && savedMessagesPeer == nil {
        pinnedIndexOffset += UInt16(filteredAdditionalItemEntries.count)
    }
    loop: for entry in view.items {
        var peerId: EnginePeer.Id?
        var threadId: Int64?
        var activityItemId: ChatListNodePeerInputActivities.ItemId?
        if case let .chatList(index) = entry.index {
            peerId = index.messageIndex.id.peerId
            activityItemId = ChatListNodePeerInputActivities.ItemId(peerId: index.messageIndex.id.peerId, threadId: nil)
        } else if case let .forum(_, _, threadIdValue, _, _) = entry.index, case let .forum(peerIdValue) = chatListLocation {
            peerId = peerIdValue
            activityItemId = ChatListNodePeerInputActivities.ItemId(peerId: peerIdValue, threadId: threadIdValue)
            threadId = threadIdValue
        }
        
        if let savedMessagesPeer = savedMessagesPeer, let peerId = peerId, savedMessagesPeer.id == peerId || foundPeerIds.contains(peerId) {
            continue loop
        }
        if let peerId = peerId, state.pendingRemovalItemIds.contains(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId)) {
            continue loop
        }
        var updatedMessages = entry.messages
        var updatedCombinedReadState = entry.readCounters
        if let peerId = peerId, state.pendingClearHistoryPeerIds.contains(ChatListNodeState.ItemId(peerId: peerId, threadId: threadId)) {
            updatedMessages = []
            updatedCombinedReadState = nil
        }

        var draftState: ChatListItemContent.DraftState?
        if let draft = entry.draft {
            draftState = ChatListItemContent.DraftState(draft: draft)
        }
        
        var hasActiveRevealControls = false
        if let peerId {
            hasActiveRevealControls = ChatListNodeState.ItemId(peerId: peerId, threadId: threadId) == state.peerIdWithRevealedOptions
        }
        var inputActivities: [(EnginePeer, PeerInputActivity)]?
        if let activityItemId {
            inputActivities = state.peerInputActivities?.activities[activityItemId]
        }
        
        var isSelected = false
        if let threadId, threadId != 0 {
            isSelected = state.selectedThreadIds.contains(threadId)
        } else if let peerId {
            isSelected = state.selectedPeerIds.contains(peerId)
        }
        
        var threadInfo: ChatListItemContent.ThreadInfo?
        if let threadData = entry.threadData, let threadId = threadId {
            threadInfo = ChatListItemContent.ThreadInfo(id: threadId, info: threadData.info, isOwnedByMe: threadData.isOwnedByMe, isClosed: threadData.isClosed)
        }

        result.append(.PeerEntry(index: offsetPinnedIndex(entry.index, offset: pinnedIndexOffset), presentationData: state.presentationData, messages: updatedMessages, readState: updatedCombinedReadState, isRemovedFromTotalUnreadCount: entry.isMuted, draftState: draftState, peer: entry.renderedPeer, threadInfo: threadInfo, presence: entry.presence, hasUnseenMentions: entry.hasUnseenMentions, hasUnseenReactions: entry.hasUnseenReactions, editing: state.editing, hasActiveRevealControls: hasActiveRevealControls, selected: isSelected, inputActivities: inputActivities, promoInfo: nil, hasFailedMessages: entry.hasFailed, isContact: entry.isContact, forumTopicData: entry.forumTopicData))
    }
    if !view.hasLater {
        var pinningIndex: UInt16 = UInt16(pinnedIndexOffset == 0 ? 0 : (pinnedIndexOffset - 1))
        
        if let savedMessagesPeer = savedMessagesPeer {
            if !foundPeers.isEmpty {
                var foundPinningIndex: UInt16 = UInt16(foundPeers.count)
                for peer in foundPeers.reversed() {
                    var peers: [EnginePeer.Id: EnginePeer] = [peer.0.id: peer.0]
                    if let chatPeer = peer.1 {
                        peers[chatPeer.id] = chatPeer
                    }
                    
                    let messageIndex = EngineMessage.Index(id: EngineMessage.Id(peerId: peer.0.id, namespace: 0, id: 0), timestamp: 1)
                    result.append(.PeerEntry(
                        index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: foundPinningIndex, messageIndex: messageIndex)),
                        presentationData: state.presentationData,
                        messages: [],
                        readState: nil,
                        isRemovedFromTotalUnreadCount: false,
                        draftState: nil,
                        peer: EngineRenderedPeer(peerId: peer.0.id, peers: peers, associatedMedia: [:]),
                        threadInfo: nil,
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        editing: state.editing,
                        hasActiveRevealControls: false,
                        selected: state.selectedPeerIds.contains(peer.0.id),
                        inputActivities: nil,
                        promoInfo: nil,
                        hasFailedMessages: false,
                        isContact: false,
                        forumTopicData: nil
                    ))
                    if foundPinningIndex != 0 {
                        foundPinningIndex -= 1
                    }
                }
            }
            
            result.append(.PeerEntry(index: .chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.predecessor), presentationData: state.presentationData, messages: [], readState: nil, isRemovedFromTotalUnreadCount: false, draftState: nil, peer: EngineRenderedPeer(peerId: savedMessagesPeer.id, peers: [savedMessagesPeer.id: savedMessagesPeer], associatedMedia: [:]), threadInfo: nil, presence: nil, hasUnseenMentions: false, hasUnseenReactions: false, editing: state.editing, hasActiveRevealControls: false, selected: state.selectedPeerIds.contains(savedMessagesPeer.id), inputActivities: nil, promoInfo: nil, hasFailedMessages: false, isContact: false, forumTopicData: nil))
        } else {
            if !filteredAdditionalItemEntries.isEmpty {
                for item in filteredAdditionalItemEntries.reversed() {
                    guard case let .chatList(index) = item.item.index else {
                        continue
                    }
                    
                    let promoInfo: ChatListNodeEntryPromoInfo
                    switch item.promoInfo.content {
                    case .proxy:
                        promoInfo = .proxy
                    case let .psa(type, message):
                        promoInfo = .psa(type: type, message: message)
                    }
                    let draftState = item.item.draft.flatMap(ChatListItemContent.DraftState.init)
                    
                    let peerId = index.messageIndex.id.peerId
                    let isSelected = state.selectedPeerIds.contains(peerId)
                    
                    var threadId: Int64 = 0
                    switch item.item.index {
                    case let .forum(_, _, threadIdValue, _, _):
                        threadId = threadIdValue
                    default:
                        break
                    }
                    
                    result.append(.PeerEntry(
                        index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: pinningIndex, messageIndex: index.messageIndex)),
                        presentationData: state.presentationData,
                        messages: item.item.messages,
                        readState: item.item.readCounters,
                        isRemovedFromTotalUnreadCount: item.item.isMuted,
                        draftState: draftState,
                        peer: item.item.renderedPeer,
                        threadInfo: item.item.threadData.flatMap { ChatListItemContent.ThreadInfo(id: threadId, info: $0.info, isOwnedByMe: $0.isOwnedByMe, isClosed: $0.isClosed) },
                        presence: item.item.presence,
                        hasUnseenMentions: item.item.hasUnseenMentions,
                        hasUnseenReactions: item.item.hasUnseenReactions,
                        editing: state.editing,
                        hasActiveRevealControls: ChatListNodeState.ItemId(peerId: peerId, threadId: threadId) == state.peerIdWithRevealedOptions,
                        selected: isSelected,
                        inputActivities: state.peerInputActivities?.activities[ChatListNodePeerInputActivities.ItemId(peerId: peerId, threadId: nil)],
                        promoInfo: promoInfo,
                        hasFailedMessages: item.item.hasFailed,
                        isContact: item.item.isContact,
                        forumTopicData: item.item.forumTopicData
                    ))
                    if pinningIndex != 0 {
                        pinningIndex -= 1
                    }
                }
            }
        }
        
        if !view.hasLater, case .chatList = mode {
            for groupReference in view.groupItems {
                let messageIndex = EngineMessage.Index(id: EngineMessage.Id(peerId: EnginePeer.Id(0), namespace: 0, id: 0), timestamp: 1)
                result.append(.GroupReferenceEntry(
                    index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: pinningIndex, messageIndex: messageIndex)),
                    presentationData: state.presentationData,
                    groupId: groupReference.id,
                    peers: groupReference.items,
                    message: groupReference.topMessage,
                    editing: state.editing,
                    unreadCount: groupReference.unreadCount,
                    revealed: state.archiveShouldBeTemporaryRevealed,
                    hiddenByDefault: hideArchivedFolderByDefault
                ))
                if pinningIndex != 0 {
                    pinningIndex -= 1
                }
            }
            
            if displayArchiveIntro {
                result.append(.ArchiveIntro(presentationData: state.presentationData))
            }
            
            result.append(.HeaderEntry)
        }
        
        if !view.hasLater, case let .peers(_, _, additionalCategories, _) = mode {
            var index = 0
            for category in additionalCategories.reversed(){
                result.append(.AdditionalCategory(index: index, id: category.id, title: category.title, image: category.icon, appearance: category.appearance, selected: state.selectedAdditionalCategoryIds.contains(category.id), presentationData: state.presentationData))
                index += 1
            }
        }
    }

    if result.count >= 1, case .HoleEntry = result[result.count - 1] {
        return ([.HeaderEntry], true)
    } else if result.count == 1, case .HoleEntry = result[0] {
        return ([.HeaderEntry], true)
    }
    return (result, view.isLoading)
}
