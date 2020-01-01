import Foundation
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import MergeLists

enum ChatListNodeEntryId: Hashable {
    case Hole(Int64)
    case PeerId(Int64)
    case GroupId(PeerGroupId)
    case ArchiveIntro
}

enum ChatListNodeEntry: Comparable, Identifiable {
    case PeerEntry(index: ChatListIndex, presentationData: ChatListPresentationData, message: Message?, readState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, peer: RenderedPeer, presence: PeerPresence?, summaryInfo: ChatListMessageTagSummaryInfo, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, inputActivities: [(Peer, PeerInputActivity)]?, isAd: Bool, hasFailedMessages: Bool)
    case HoleEntry(ChatListHole, theme: PresentationTheme)
    case GroupReferenceEntry(index: ChatListIndex, presentationData: ChatListPresentationData, groupId: PeerGroupId, peers: [ChatListGroupReferencePeer], message: Message?, editing: Bool, unreadState: PeerGroupUnreadCountersCombinedSummary, revealed: Bool, hiddenByDefault: Bool)
    case ArchiveIntro(presentationData: ChatListPresentationData)
    
    var sortIndex: ChatListIndex {
        switch self {
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole, _):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .GroupReferenceEntry(index, _, _, _, _, _, _, _, _):
                return index
            case .ArchiveIntro:
                return ChatListIndex.absoluteUpperBound
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return .PeerId(index.messageIndex.id.peerId.toInt64())
            case let .HoleEntry(hole, _):
                return .Hole(Int64(hole.index.id.id))
            case let .GroupReferenceEntry(_, _, groupId, _, _, _, _, _, _):
                return .GroupId(groupId)
            case .ArchiveIntro:
                return .ArchiveIntro
        }
    }
    
    static func <(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    static func ==(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        switch lhs {
            case let .PeerEntry(lhsIndex, lhsPresentationData, lhsMessage, lhsUnreadCount, lhsNotificationSettings, lhsEmbeddedState, lhsPeer, lhsPresence, lhsSummaryInfo, lhsEditing, lhsHasRevealControls, lhsSelected, lhsInputActivities, lhsAd, lhsHasFailedMessages):
                switch rhs {
                    case let .PeerEntry(rhsIndex, rhsPresentationData, rhsMessage, rhsUnreadCount, rhsNotificationSettings, rhsEmbeddedState, rhsPeer, rhsPresence, rhsSummaryInfo, rhsEditing, rhsHasRevealControls, rhsSelected, rhsInputActivities, rhsAd, rhsHasFailedMessages):
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
                        if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                            if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                                return false
                            }
                        } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
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
        for groupReference in view.groupEntries {
            groupEntryCount += 1
        }
        pinnedIndexOffset += UInt16(groupEntryCount)
    }
    
    if view.laterIndex == nil && savedMessagesPeer == nil {
        pinnedIndexOffset += UInt16(view.additionalItemEntries.count)
    }
    loop: for entry in view.entries {
        switch entry {
            case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, peerPresence, summaryInfo, hasFailed):
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
                result.append(.PeerEntry(index: offsetPinnedIndex(index, offset: pinnedIndexOffset), presentationData: state.presentationData, message: updatedMessage, readState: updatedCombinedReadState, notificationSettings: notificationSettings, embeddedInterfaceState: embeddedState, peer: peer, presence: peerPresence, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], isAd: false, hasFailedMessages: hasFailed))
            case let .HoleEntry(hole):
                if hole.index.timestamp == Int32.max - 1 {
                    return ([], true)
                }
                result.append(.HoleEntry(hole, theme: state.presentationData.theme))
        }
    }
    if view.laterIndex == nil {
        var pinningIndex: UInt16 = UInt16(pinnedIndexOffset == 0 ? 0 : (pinnedIndexOffset - 1))
        
        if let savedMessagesPeer = savedMessagesPeer {
            result.append(.PeerEntry(index: ChatListIndex.absoluteUpperBound.predecessor, presentationData: state.presentationData, message: nil, readState: nil, notificationSettings: nil, embeddedInterfaceState: nil, peer: RenderedPeer(peerId: savedMessagesPeer.id, peers: SimpleDictionary([savedMessagesPeer.id: savedMessagesPeer])), presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(), editing: state.editing, hasActiveRevealControls: false, selected: false, inputActivities: nil, isAd: false, hasFailedMessages: false))
        } else {
            if !view.additionalItemEntries.isEmpty {
                for entry in view.additionalItemEntries.reversed() {
                    switch entry {
                        case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, peerPresence, summaryInfo, hasFailed):
                            result.append(.PeerEntry(index: ChatListIndex(pinningIndex: pinningIndex, messageIndex: index.messageIndex), presentationData: state.presentationData, message: message, readState: combinedReadState, notificationSettings: notificationSettings, embeddedInterfaceState: embeddedState, peer: peer, presence: peerPresence, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], isAd: true, hasFailedMessages: hasFailed))
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
        }
    }

    if result.count >= 1, case .HoleEntry = result[result.count - 1] {
        return ([], true)
    } else if result.count == 1, case .HoleEntry = result[0] {
        return ([], true)
    }
    return (result, false)
}
