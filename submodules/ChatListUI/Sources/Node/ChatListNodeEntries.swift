import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import MergeLists

enum ChatListNodeEntryId: Hashable {
    case Header
    case Hole(Int64)
    case PeerId(Int64)
    case GroupId(PeerGroupId)
    case ArchiveIntro
    case additionalCategory(Int)
}

enum ChatListNodeEntrySortIndex: Comparable {
    case index(ChatListIndex)
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
    case PeerEntry(index: ChatListIndex, presentationData: ChatListPresentationData, message: Message?, readState: CombinedPeerReadState?, isRemovedFromTotalUnreadCount: Bool, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, peer: RenderedPeer, presence: PeerPresence?, summaryInfo: ChatListMessageTagSummaryInfo, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, inputActivities: [(Peer, PeerInputActivity)]?, promoInfo: ChatListNodeEntryPromoInfo?, hasFailedMessages: Bool, isContact: Bool)
    case HoleEntry(ChatListHole, theme: PresentationTheme)
    case GroupReferenceEntry(index: ChatListIndex, presentationData: ChatListPresentationData, groupId: PeerGroupId, peers: [ChatListGroupReferencePeer], message: Message?, editing: Bool, unreadState: PeerGroupUnreadCountersCombinedSummary, revealed: Bool, hiddenByDefault: Bool)
    case ArchiveIntro(presentationData: ChatListPresentationData)
    case AdditionalCategory(index: Int, id: Int, title: String, image: UIImage?, selected: Bool, presentationData: ChatListPresentationData)
    
    var sortIndex: ChatListNodeEntrySortIndex {
        switch self {
        case .HeaderEntry:
            return .index(ChatListIndex.absoluteUpperBound)
        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            return .index(index)
        case let .HoleEntry(hole, _):
            return .index(ChatListIndex(pinningIndex: nil, messageIndex: hole.index))
        case let .GroupReferenceEntry(index, _, _, _, _, _, _, _, _):
            return .index(index)
        case .ArchiveIntro:
            return .index(ChatListIndex.absoluteUpperBound.successor)
        case let .AdditionalCategory(additionalCategory):
            return .additionalCategory(additionalCategory.index)
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
        case .HeaderEntry:
            return .Header
        case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            return .PeerId(index.messageIndex.id.peerId.toInt64())
        case let .HoleEntry(hole, _):
            return .Hole(Int64(hole.index.id.id))
        case let .GroupReferenceEntry(_, _, groupId, _, _, _, _, _, _):
            return .GroupId(groupId)
        case .ArchiveIntro:
            return .ArchiveIntro
        case let .AdditionalCategory(additionalCategory):
            return .additionalCategory(additionalCategory.id)
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
            case let .PeerEntry(lhsIndex, lhsPresentationData, lhsMessage, lhsUnreadCount, lhsIsRemovedFromTotalUnreadCount, lhsEmbeddedState, lhsPeer, lhsPresence, lhsSummaryInfo, lhsEditing, lhsHasRevealControls, lhsSelected, lhsInputActivities, lhsAd, lhsHasFailedMessages, lhsIsContact):
                switch rhs {
                    case let .PeerEntry(rhsIndex, rhsPresentationData, rhsMessage, rhsUnreadCount, rhsIsRemovedFromTotalUnreadCount, rhsEmbeddedState, rhsPeer, rhsPresence, rhsSummaryInfo, rhsEditing, rhsHasRevealControls, rhsSelected, rhsInputActivities, rhsAd, rhsHasFailedMessages, rhsIsContact):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsPresentationData !== rhsPresentationData {
                            return false
                        }
                        if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                            return false
                        }
                        if lhsMessage?.id != rhsMessage?.id || lhsMessage?.flags != rhsMessage?.flags || lhsUnreadCount != rhsUnreadCount {
                            return false
                        }
                        if let lhsMessage = lhsMessage, let rhsMessage = rhsMessage {
                            if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
                                return false
                            }
                            for (id, message) in lhsMessage.associatedMessages {
                                if let otherMessage = rhsMessage.associatedMessages[id] {
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
                            if !lhsPeerPresence.isEqual(to: rhsPeerPresence) {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if !lhsEmbeddedState.isEqual(to: rhsEmbeddedState) {
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
                        if lhsSummaryInfo != rhsSummaryInfo {
                            return false
                        }
                        if let lhsInputActivities = lhsInputActivities, let rhsInputActivities = rhsInputActivities {
                            if lhsInputActivities.count != rhsInputActivities.count {
                                return false
                            }
                            for i in 0 ..< lhsInputActivities.count {
                                if !arePeersEqual(lhsInputActivities[i].0, rhsInputActivities[i].0) {
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
            case let .AdditionalCategory(lhsIndex, lhsId, lhsTitle, lhsImage, lhsSelected, lhsPresentationData):
                if case let .AdditionalCategory(rhsIndex, rhsId, rhsTitle, rhsImage, rhsSelected, rhsPresentationData) = rhs {
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

private func offsetPinnedIndex(_ index: ChatListIndex, offset: UInt16) -> ChatListIndex {
    if let pinningIndex = index.pinningIndex {
        return ChatListIndex(pinningIndex: pinningIndex + offset, messageIndex: index.messageIndex)
    } else {
        return index
    }
}

func chatListNodeEntriesForView(_ view: ChatListView, state: ChatListNodeState, savedMessagesPeer: Peer?, hideArchivedFolderByDefault: Bool, displayArchiveIntro: Bool, mode: ChatListNodeMode) -> (entries: [ChatListNodeEntry], loading: Bool) {
    var result: [ChatListNodeEntry] = []
    
    var pinnedIndexOffset: UInt16 = 0
    
    if view.laterIndex == nil, case .chatList = mode {
        var groupEntryCount = 0
        for _ in view.groupEntries {
            groupEntryCount += 1
        }
        pinnedIndexOffset += UInt16(groupEntryCount)
    }
    
    let filteredAdditionalItemEntries = view.additionalItemEntries.filter { item -> Bool in
        return item.info.peerId != state.hiddenPsaPeerId
    }
    
    if view.laterIndex == nil && savedMessagesPeer == nil {
        pinnedIndexOffset += UInt16(filteredAdditionalItemEntries.count)
    }
    var filterAfterHole = false
    loop: for entry in view.entries {
        switch entry {
            case let .MessageEntry(index, message, combinedReadState, isRemovedFromTotalUnreadCount, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                if let savedMessagesPeer = savedMessagesPeer, savedMessagesPeer.id == index.messageIndex.id.peerId {
                    continue loop
                }
                if state.pendingRemovalPeerIds.contains(index.messageIndex.id.peerId) {
                    continue loop
                }
                var updatedMessage = message
                var updatedCombinedReadState = combinedReadState
                if state.pendingClearHistoryPeerIds.contains(index.messageIndex.id.peerId) {
                    updatedMessage = nil
                    updatedCombinedReadState = nil
                }
                result.append(.PeerEntry(index: offsetPinnedIndex(index, offset: pinnedIndexOffset), presentationData: state.presentationData, message: updatedMessage, readState: updatedCombinedReadState, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: embeddedState, peer: peer, presence: peerPresence, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], promoInfo: nil, hasFailedMessages: hasFailed, isContact: isContact))
            case let .HoleEntry(hole):
                if hole.index.timestamp == Int32.max - 1 {
                    //return ([.HeaderEntry], true)
                }
                filterAfterHole = true
                result.append(.HoleEntry(hole, theme: state.presentationData.theme))
        }
    }
    if view.laterIndex == nil {
        var pinningIndex: UInt16 = UInt16(pinnedIndexOffset == 0 ? 0 : (pinnedIndexOffset - 1))
        
        if let savedMessagesPeer = savedMessagesPeer {
            result.append(.PeerEntry(index: ChatListIndex.absoluteUpperBound.predecessor, presentationData: state.presentationData, message: nil, readState: nil, isRemovedFromTotalUnreadCount: false, embeddedInterfaceState: nil, peer: RenderedPeer(peerId: savedMessagesPeer.id, peers: SimpleDictionary([savedMessagesPeer.id: savedMessagesPeer])), presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(), editing: state.editing, hasActiveRevealControls: false, selected: false, inputActivities: nil, promoInfo: nil, hasFailedMessages: false, isContact: false))
        } else {
            if !filteredAdditionalItemEntries.isEmpty {
                for item in filteredAdditionalItemEntries.reversed() {
                    guard let info = item.info as? PromoChatListItem else {
                        continue
                    }
                    let promoInfo: ChatListNodeEntryPromoInfo
                    switch info.kind {
                    case .proxy:
                        promoInfo = .proxy
                    case let .psa(type, message):
                        promoInfo = .psa(type: type, message: message)
                    }
                    switch item.entry {
                        case let .MessageEntry(index, message, combinedReadState, isRemovedFromTotalUnreadCount, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                            result.append(.PeerEntry(index: ChatListIndex(pinningIndex: pinningIndex, messageIndex: index.messageIndex), presentationData: state.presentationData, message: message, readState: combinedReadState, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: embeddedState, peer: peer, presence: peerPresence, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], promoInfo: promoInfo, hasFailedMessages: hasFailed, isContact: isContact))
                            if pinningIndex != 0 {
                                pinningIndex -= 1
                            }
                        default:
                            break
                    }
                }
            }
        }
        
        if view.laterIndex == nil, case .chatList = mode {
            for groupReference in view.groupEntries {
                let messageIndex = MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 1)
                result.append(.GroupReferenceEntry(index: ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex), presentationData: state.presentationData, groupId: groupReference.groupId, peers: groupReference.renderedPeers, message: groupReference.message, editing: state.editing, unreadState: groupReference.unreadState, revealed: state.archiveShouldBeTemporaryRevealed, hiddenByDefault: hideArchivedFolderByDefault))
                if pinningIndex != 0 {
                    pinningIndex -= 1
                }
            }
            
            if displayArchiveIntro {
                result.append(.ArchiveIntro(presentationData: state.presentationData))
            }
            
            result.append(.HeaderEntry)
        }
        
        if view.laterIndex == nil, case let .peers(_, _, additionalCategories) = mode {
            var index = 0
            for category in additionalCategories.reversed(){
                result.append(.AdditionalCategory(index: index, id: category.id, title: category.title, image: category.icon, selected: state.selectedAdditionalCategoryIds.contains(category.id), presentationData: state.presentationData))
                index += 1
            }
        }
    }
    
    var isLoading: Bool = false
    
    if filterAfterHole {
        var seenHole = false
        for i in (0 ..< result.count).reversed() {
            if seenHole {
                result.remove(at: i)
            } else {
                switch result[i] {
                case .HeaderEntry:
                    break
                case .ArchiveIntro, .AdditionalCategory, .GroupReferenceEntry:
                    break
                case .PeerEntry:
                    break
                case .HoleEntry:
                    isLoading = true
                    seenHole = true
                    result.remove(at: i)
                }
            }
        }
    }

    if result.count >= 1, case .HoleEntry = result[result.count - 1] {
        return ([.HeaderEntry], true)
    } else if result.count == 1, case .HoleEntry = result[0] {
        return ([.HeaderEntry], true)
    }
    return (result, isLoading)
}
