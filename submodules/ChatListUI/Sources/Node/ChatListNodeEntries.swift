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
    case ContactId(EnginePeer.Id)
    case ArchiveIntro
    case EmptyIntro
    case SectionHeader
    case Notice
    case additionalCategory(Int)
}

enum ChatListNodeEntrySortIndex: Comparable {
    case index(EngineChatList.Item.Index)
    case additionalCategory(Int)
    case sectionHeader
    case contact(id: EnginePeer.Id, presence: EnginePeer.Presence)
    
    static func <(lhs: ChatListNodeEntrySortIndex, rhs: ChatListNodeEntrySortIndex) -> Bool {
        switch lhs {
        case let .index(lhsIndex):
            switch rhs {
            case let .index(rhsIndex):
                return lhsIndex < rhsIndex
            case .additionalCategory:
                return false
            case .sectionHeader:
                return true
            case .contact:
                return true
            }
        case let .additionalCategory(lhsIndex):
            switch rhs {
            case let .additionalCategory(rhsIndex):
                return lhsIndex < rhsIndex
            case .index:
                return true
            case .sectionHeader:
                return true
            case .contact:
                return true
            }
        case .sectionHeader:
            switch rhs {
            case .additionalCategory, .index, .sectionHeader:
                return false
            case .contact:
                return true
            }
        case let .contact(lhsId, lhsPresense):
            switch rhs {
            case .sectionHeader:
                return false
            case let .contact(rhsId, rhsPresense):
                if lhsPresense != rhsPresense {
                    return rhsPresense.status > rhsPresense.status
                } else {
                    return lhsId < rhsId
                }
            default:
                return false
            }
        }
    }
}

public enum ChatListNodeEntryPromoInfo: Equatable {
    case proxy
    case psa(type: String, message: String?)
}

enum ChatListNotice: Equatable {
    case clearStorage(sizeFraction: Double)
    case setupPassword
    case premiumUpgrade(discount: Int32)
    case premiumAnnualDiscount(discount: Int32)
    case premiumRestore(discount: Int32)
    case chatFolderUpdates(count: Int)
}

enum ChatListNodeEntry: Comparable, Identifiable {
    struct PeerEntryData: Equatable {
        var index: EngineChatList.Item.Index
        var presentationData: ChatListPresentationData
        var messages: [EngineMessage]
        var readState: EnginePeerReadCounters?
        var isRemovedFromTotalUnreadCount: Bool
        var draftState: ChatListItemContent.DraftState?
        var peer: EngineRenderedPeer
        var threadInfo: ChatListItemContent.ThreadInfo?
        var presence: EnginePeer.Presence?
        var hasUnseenMentions: Bool
        var hasUnseenReactions: Bool
        var editing: Bool
        var hasActiveRevealControls: Bool
        var selected: Bool
        var inputActivities: [(EnginePeer, PeerInputActivity)]?
        var promoInfo: ChatListNodeEntryPromoInfo?
        var hasFailedMessages: Bool
        var isContact: Bool
        var autoremoveTimeout: Int32?
        var forumTopicData: EngineChatList.ForumTopicData?
        var topForumTopicItems: [EngineChatList.ForumTopicData]
        var revealed: Bool
        
        init(
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
            autoremoveTimeout: Int32?,
            forumTopicData: EngineChatList.ForumTopicData?,
            topForumTopicItems: [EngineChatList.ForumTopicData],
            revealed: Bool
        ) {
            self.index = index
            self.presentationData = presentationData
            self.messages = messages
            self.readState = readState
            self.isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCount
            self.draftState = draftState
            self.peer = peer
            self.threadInfo = threadInfo
            self.presence = presence
            self.hasUnseenMentions = hasUnseenMentions
            self.hasUnseenReactions = hasUnseenReactions
            self.editing = editing
            self.hasActiveRevealControls = hasActiveRevealControls
            self.selected = selected
            self.inputActivities = inputActivities
            self.promoInfo = promoInfo
            self.hasFailedMessages = hasFailedMessages
            self.isContact = isContact
            self.autoremoveTimeout = autoremoveTimeout
            self.forumTopicData = forumTopicData
            self.topForumTopicItems = topForumTopicItems
            self.revealed = revealed
        }
        
        static func ==(lhs: PeerEntryData, rhs: PeerEntryData) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if lhs.presentationData !== rhs.presentationData {
                return false
            }
            if lhs.readState != rhs.readState {
                return false
            }
            if lhs.messages.count != rhs.messages.count {
                return false
            }
            for i in 0 ..< lhs.messages.count {
                if lhs.messages[i].stableVersion != rhs.messages[i].stableVersion {
                    return false
                }
                if lhs.messages[i].id != rhs.messages[i].id {
                    return false
                }
                if lhs.messages[i].associatedMessages.count != rhs.messages[i].associatedMessages.count {
                    return false
                }
                for (id, message) in lhs.messages[i].associatedMessages {
                    if let otherMessage = rhs.messages[i].associatedMessages[id] {
                        if message.stableVersion != otherMessage.stableVersion {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            if lhs.isRemovedFromTotalUnreadCount != rhs.isRemovedFromTotalUnreadCount {
                return false
            }
            if let lhsPeerPresence = lhs.presence, let rhsPeerPresence = rhs.presence {
                if lhsPeerPresence != rhsPeerPresence {
                    return false
                }
            } else if (lhs.presence != nil) != (rhs.presence != nil) {
                return false
            }
            if let lhsEmbeddedState = lhs.draftState, let rhsEmbeddedState = rhs.draftState {
                if lhsEmbeddedState != rhsEmbeddedState {
                    return false
                }
            } else if (lhs.draftState != nil) != (rhs.draftState != nil) {
                return false
            }
            if lhs.editing != rhs.editing {
                return false
            }
            if lhs.hasActiveRevealControls != rhs.hasActiveRevealControls {
                return false
            }
            if lhs.selected != rhs.selected {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.threadInfo != rhs.threadInfo {
                return false
            }
            if lhs.hasUnseenMentions != rhs.hasUnseenMentions {
                return false
            }
            if lhs.hasUnseenReactions != rhs.hasUnseenReactions {
                return false
            }
            if let lhsInputActivities = lhs.inputActivities, let rhsInputActivities = rhs.inputActivities {
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
            } else if (lhs.inputActivities != nil) != (rhs.inputActivities != nil) {
                return false
            }
            if lhs.promoInfo != rhs.promoInfo {
                return false
            }
            if lhs.hasFailedMessages != rhs.hasFailedMessages {
                return false
            }
            if lhs.isContact != rhs.isContact {
                return false
            }
            if lhs.autoremoveTimeout != rhs.autoremoveTimeout {
                return false
            }
            if lhs.forumTopicData != rhs.forumTopicData {
                return false
            }
            if lhs.topForumTopicItems != rhs.topForumTopicItems {
                return false
            }
            if lhs.revealed != rhs.revealed {
                return false
            }
            return true
        }
    }
    
    struct ContactEntryData: Equatable {
        var presentationData: ChatListPresentationData
        var peer: EnginePeer
        var presence: EnginePeer.Presence
        
        init(presentationData: ChatListPresentationData, peer: EnginePeer, presence: EnginePeer.Presence) {
            self.presentationData = presentationData
            self.peer = peer
            self.presence = presence
        }
        
        static func ==(lhs: ContactEntryData, rhs: ContactEntryData) -> Bool {
            if lhs.presentationData !== rhs.presentationData {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.presence != rhs.presence {
                return false
            }
            return true
        }
    }
    
    case HeaderEntry
    case PeerEntry(PeerEntryData)
    case HoleEntry(EngineMessage.Index, theme: PresentationTheme)
    case GroupReferenceEntry(index: EngineChatList.Item.Index, presentationData: ChatListPresentationData, groupId: EngineChatList.Group, peers: [EngineChatList.GroupItem.Item], message: EngineMessage?, editing: Bool, unreadCount: Int, revealed: Bool, hiddenByDefault: Bool)
    case ContactEntry(ContactEntryData)
    case ArchiveIntro(presentationData: ChatListPresentationData)
    case EmptyIntro(presentationData: ChatListPresentationData)
    case SectionHeader(presentationData: ChatListPresentationData, displayHide: Bool)
    case Notice(presentationData: ChatListPresentationData, notice: ChatListNotice)
    case AdditionalCategory(index: Int, id: Int, title: String, image: UIImage?, appearance: ChatListNodeAdditionalCategory.Appearance, selected: Bool, presentationData: ChatListPresentationData)
    
    var sortIndex: ChatListNodeEntrySortIndex {
        switch self {
        case .HeaderEntry:
            return .index(.chatList(.absoluteUpperBound))
        case let .PeerEntry(peerEntry):
            return .index(peerEntry.index)
        case let .HoleEntry(holeIndex, _):
            return .index(.chatList(EngineChatList.Item.Index.ChatList(pinningIndex: nil, messageIndex: holeIndex)))
        case let .GroupReferenceEntry(index, _, _, _, _, _, _, _, _):
            return .index(index)
        case let .ContactEntry(contactEntry):
            return .contact(id: contactEntry.peer.id, presence: contactEntry.presence)
        case .ArchiveIntro:
            return .index(.chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.successor))
        case .EmptyIntro:
            return .index(.chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.successor))
        case .SectionHeader:
            return .sectionHeader
        case .Notice:
            return .index(.chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.successor.successor))
        case let .AdditionalCategory(index, _, _, _, _, _, _):
            return .additionalCategory(index)
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
        case .HeaderEntry:
            return .Header
        case let .PeerEntry(peerEntry):
            switch peerEntry.index {
            case let .chatList(index):
                return .PeerId(index.messageIndex.id.peerId.toInt64())
            case let .forum(_, _, threadId, _, _):
                return .ThreadId(threadId)
            }
        case let .HoleEntry(holeIndex, _):
            return .Hole(Int64(holeIndex.id.id))
        case let .GroupReferenceEntry(_, _, groupId, _, _, _, _, _, _):
            return .GroupId(groupId)
        case let .ContactEntry(contactEntry):
            return .ContactId(contactEntry.peer.id)
        case .ArchiveIntro:
            return .ArchiveIntro
        case .EmptyIntro:
            return .EmptyIntro
        case .SectionHeader:
            return .SectionHeader
        case .Notice:
            return .Notice
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
            case let .PeerEntry(peerEntry):
                if case .PeerEntry(peerEntry) = rhs {
                    return true
                } else {
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
            case let .ContactEntry(contactEntry):
                if case .ContactEntry(contactEntry) = rhs {
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
            case let .EmptyIntro(lhsPresentationData):
                if case let .EmptyIntro(rhsPresentationData) = rhs {
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .SectionHeader(lhsPresentationData, lhsDisplayHide):
                if case let .SectionHeader(rhsPresentationData, rhsDisplayHide) = rhs {
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsDisplayHide != rhsDisplayHide {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .Notice(lhsPresentationData, lhsInfo):
                if case let .Notice(rhsPresentationData, rhsInfo) = rhs {
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsInfo != rhsInfo {
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

struct ChatListContactPeer {
    var peer: EnginePeer
    var presence: EnginePeer.Presence
    
    init(peer: EnginePeer, presence: EnginePeer.Presence) {
        self.peer = peer
        self.presence = presence
    }
}

func chatListNodeEntriesForView(_ view: EngineChatList, state: ChatListNodeState, savedMessagesPeer: EnginePeer?, foundPeers: [(EnginePeer, EnginePeer?)], hideArchivedFolderByDefault: Bool, displayArchiveIntro: Bool, notice: ChatListNotice?, mode: ChatListNodeMode, chatListLocation: ChatListControllerLocation, contacts: [ChatListContactPeer]) -> (entries: [ChatListNodeEntry], loading: Bool) {
    var result: [ChatListNodeEntry] = []
    
    if !view.hasEarlier {
        for contact in contacts {
            result.append(.ContactEntry(ChatListNodeEntry.ContactEntryData(
                presentationData: state.presentationData,
                peer: contact.peer,
                presence: contact.presence
            )))
        }
        if !contacts.isEmpty {
            result.append(.SectionHeader(presentationData: state.presentationData, displayHide: !view.items.isEmpty))
        }
    }
    
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
    
    var hiddenGeneralThread: ChatListNodeEntry?
    
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
            threadInfo = ChatListItemContent.ThreadInfo(id: threadId, info: threadData.info, isOwnedByMe: threadData.isOwnedByMe, isClosed: threadData.isClosed, isHidden: threadData.isHidden)
        }

        let entry: ChatListNodeEntry = .PeerEntry(ChatListNodeEntry.PeerEntryData(
            index: offsetPinnedIndex(entry.index, offset: pinnedIndexOffset),
            presentationData: state.presentationData,
            messages: updatedMessages,
            readState: updatedCombinedReadState,
            isRemovedFromTotalUnreadCount: entry.isMuted,
            draftState: draftState,
            peer: entry.renderedPeer,
            threadInfo: threadInfo,
            presence: entry.presence,
            hasUnseenMentions: entry.hasUnseenMentions,
            hasUnseenReactions: entry.hasUnseenReactions,
            editing: state.editing,
            hasActiveRevealControls: hasActiveRevealControls,
            selected: isSelected,
            inputActivities: inputActivities,
            promoInfo: nil,
            hasFailedMessages: entry.hasFailed,
            isContact: entry.isContact,
            autoremoveTimeout: entry.autoremoveTimeout,
            forumTopicData: entry.forumTopicData,
            topForumTopicItems: entry.topForumTopicItems,
            revealed: threadId == 1 && (state.hiddenItemShouldBeTemporaryRevealed || state.editing)
        ))
        
        if let threadInfo, threadInfo.isHidden {
            hiddenGeneralThread = entry
        } else {
            result.append(entry)
        }
    }
    
    if let hiddenGeneralThread {
        result.append(hiddenGeneralThread)
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
                    result.append(.PeerEntry(ChatListNodeEntry.PeerEntryData(
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
                        autoremoveTimeout: nil,
                        forumTopicData: nil,
                        topForumTopicItems: [],
                        revealed: false
                    )))
                    if foundPinningIndex != 0 {
                        foundPinningIndex -= 1
                    }
                }
            }
            
            result.append(.PeerEntry(ChatListNodeEntry.PeerEntryData(
                index: .chatList(EngineChatList.Item.Index.ChatList.absoluteUpperBound.predecessor),
                presentationData: state.presentationData,
                messages: [],
                readState: nil,
                isRemovedFromTotalUnreadCount: false,
                draftState: nil,
                peer: EngineRenderedPeer(peerId: savedMessagesPeer.id, peers: [savedMessagesPeer.id: savedMessagesPeer], associatedMedia: [:]),
                threadInfo: nil,
                presence: nil,
                hasUnseenMentions: false,
                hasUnseenReactions: false,
                editing: state.editing,
                hasActiveRevealControls: false,
                selected: state.selectedPeerIds.contains(savedMessagesPeer.id),
                inputActivities: nil,
                promoInfo: nil,
                hasFailedMessages: false,
                isContact: false,
                autoremoveTimeout: nil,
                forumTopicData: nil,
                topForumTopicItems: [],
                revealed: false
            )))
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
                    result.append(.PeerEntry(ChatListNodeEntry.PeerEntryData(
                        index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: pinningIndex, messageIndex: index.messageIndex)),
                        presentationData: state.presentationData,
                        messages: item.item.messages,
                        readState: item.item.readCounters,
                        isRemovedFromTotalUnreadCount: item.item.isMuted,
                        draftState: draftState,
                        peer: item.item.renderedPeer,
                        threadInfo: item.item.threadData.flatMap { ChatListItemContent.ThreadInfo(id: threadId, info: $0.info, isOwnedByMe: $0.isOwnedByMe, isClosed: $0.isClosed, isHidden: $0.isHidden) },
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
                        autoremoveTimeout: item.item.autoremoveTimeout,
                        forumTopicData: item.item.forumTopicData,
                        topForumTopicItems: item.item.topForumTopicItems,
                        revealed: state.hiddenItemShouldBeTemporaryRevealed || state.editing
                    )))
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
                    revealed: state.hiddenItemShouldBeTemporaryRevealed,
                    hiddenByDefault: hideArchivedFolderByDefault
                ))
                if pinningIndex != 0 {
                    pinningIndex -= 1
                }
            }
            
            if displayArchiveIntro {
                result.append(.ArchiveIntro(presentationData: state.presentationData))
            } else if !contacts.isEmpty && !result.contains(where: { entry in
                if case .PeerEntry = entry {
                    return true
                } else {
                    return false
                }
            }) {
                result.append(.EmptyIntro(presentationData: state.presentationData))
            }
            
            if let notice {
                result.append(.Notice(presentationData: state.presentationData, notice: notice))
            }
            
            result.append(.HeaderEntry)
        }
        
        if !view.hasLater {
            if case let .peers(_, _, additionalCategories, _, _) = mode {
                var index = 0
                for category in additionalCategories.reversed() {
                    result.append(.AdditionalCategory(index: index, id: category.id, title: category.title, image: category.icon, appearance: category.appearance, selected: state.selectedAdditionalCategoryIds.contains(category.id), presentationData: state.presentationData))
                    index += 1
                }
            } else if case let .peerType(types, hasCreate) = mode, !result.isEmpty && hasCreate {
                for type in types {
                    switch type {
                    case .group:
                        result.append(.AdditionalCategory(index: 0, id: 0, title: state.presentationData.strings.RequestPeer_CreateNewGroup, image: PresentationResourcesItemList.createGroupIcon(state.presentationData.theme), appearance: .action, selected: false, presentationData: state.presentationData))
                    case .channel:
                        result.append(.AdditionalCategory(index: 0, id: 0, title: state.presentationData.strings.RequestPeer_CreateNewChannel, image: PresentationResourcesItemList.createGroupIcon(state.presentationData.theme), appearance: .action, selected: false, presentationData: state.presentationData))
                    default:
                        break
                    }
                }
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
