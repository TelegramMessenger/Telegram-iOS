import Foundation
import Postbox
import TelegramCore

enum ChatListNodeEntryId: Hashable {
    case Hole(Int64)
    case PeerId(Int64)
    case GroupId(PeerGroupId)
    
    var hashValue: Int {
        switch self {
            case let .Hole(peerId):
                return peerId.hashValue
            case let .PeerId(peerId):
                return peerId.hashValue
            case let .GroupId(groupId):
                return groupId.hashValue
        }
    }
    
    static func ==(lhs: ChatListNodeEntryId, rhs: ChatListNodeEntryId) -> Bool {
        switch lhs {
            case let .Hole(id):
                if case .Hole(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .PeerId(id):
                if case .PeerId(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .GroupId(groupId):
                if case .GroupId(groupId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ChatListNodeEntry: Comparable, Identifiable {
    case PeerEntry(index: ChatListIndex, presentationData: ChatListPresentationData, message: Message?, readState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, peer: RenderedPeer, summaryInfo: ChatListMessageTagSummaryInfo, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, inputActivities: [(Peer, PeerInputActivity)]?, isAd: Bool)
    case HoleEntry(ChatListHole, theme: PresentationTheme)
    //case GroupReferenceEntry(index: ChatListIndex, presentationData: ChatListPresentationData, groupId: PeerGroupId, message: Message?, topPeers: [Peer], counters: GroupReferenceUnreadCounters, editing: Bool)
    
    var index: ChatListIndex {
        switch self {
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole, _):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            /*case let .GroupReferenceEntry(index, _, _, _, _, _, _):
                return index*/
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
            case let .PeerEntry(index, _, _, _, _, _, _, _, _, _, _, _, _):
                return .PeerId(index.messageIndex.id.peerId.toInt64())
            case let .HoleEntry(hole, _):
                return .Hole(Int64(hole.index.id.id))
            /*case let .GroupReferenceEntry(_, _, groupId, _, _, _, _):
                return .GroupId(groupId)*/
        }
    }
    
    static func <(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        switch lhs {
            case let .PeerEntry(lhsIndex, lhsPresentationData, lhsMessage, lhsUnreadCount, lhsNotificationSettings, lhsEmbeddedState, lhsPeer, lhsSummaryInfo, lhsEditing, lhsHasRevealControls, lhsSelected, lhsInputActivities, lhsAd):
                switch rhs {
                    case let .PeerEntry(rhsIndex, rhsPresentationData, rhsMessage, rhsUnreadCount, rhsNotificationSettings, rhsEmbeddedState, rhsPeer, rhsSummaryInfo, rhsEditing, rhsHasRevealControls, rhsSelected, rhsInputActivities, rhsAd):
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
                        if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                            if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                                return false
                            }
                        } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
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
            /*case let .GroupReferenceEntry(lhsIndex, lhsPresentationData, lhsGroupId, lhsMessage, lhsTopPeers, lhsCounters, lhsEditing):
                if case let .GroupReferenceEntry(rhsIndex, rhsPresentationData, rhsGroupId, rhsMessage, rhsTopPeers, rhsCounters, rhsEditing) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsGroupId != rhsGroupId {
                        return false
                    }
                    if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                        return false
                    }
                    if lhsMessage?.id != rhsMessage?.id || lhsMessage?.flags != rhsMessage?.flags {
                        return false
                    }
                    if lhsTopPeers.count != rhsTopPeers.count {
                        return false
                    } else {
                        for i in 0 ..< lhsTopPeers.count {
                            if !arePeersEqual(lhsTopPeers[i], rhsTopPeers[i]) {
                                return false
                            }
                        }
                    }
                    if lhsCounters != rhsCounters {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    return true
                } else {
                    return false
                }*/
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

func chatListNodeEntriesForView(_ view: ChatListView, state: ChatListNodeState, savedMessagesPeer: Peer?, mode: ChatListNodeMode) -> (entries: [ChatListNodeEntry], loading: Bool) {
    var result: [ChatListNodeEntry] = []
    var pinnedIndexOffset: UInt16 = 0
    if view.laterIndex == nil && savedMessagesPeer == nil {
        pinnedIndexOffset = UInt16(view.additionalItemEntries.count)
    }
    
    loop: for entry in view.entries {
        switch entry {
            case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo):
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
                result.append(.PeerEntry(index: offsetPinnedIndex(index, offset: pinnedIndexOffset), presentationData: state.presentationData, message: updatedMessage, readState: updatedCombinedReadState, notificationSettings: notificationSettings, embeddedInterfaceState: embeddedState, peer: peer, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], isAd: false))
            case let .HoleEntry(hole):
                result.append(.HoleEntry(hole, theme: state.presentationData.theme))
            /*case let .GroupReferenceEntry(groupId, index, message, topPeers, counters):
                if case .chatList = mode {
                    result.append(.GroupReferenceEntry(index: index, presentationData: state.presentationData, groupId: groupId, message: message, topPeers: topPeers, counters: counters, editing: state.editing))
                }*/
        }
    }
    if view.laterIndex == nil {
        if let savedMessagesPeer = savedMessagesPeer {
            result.append(.PeerEntry(index: ChatListIndex.absoluteUpperBound.predecessor, presentationData: state.presentationData, message: nil, readState: nil, notificationSettings: nil, embeddedInterfaceState: nil, peer: RenderedPeer(peerId: savedMessagesPeer.id, peers: SimpleDictionary([savedMessagesPeer.id: savedMessagesPeer])), summaryInfo: ChatListMessageTagSummaryInfo(), editing: state.editing, hasActiveRevealControls: false, selected: false, inputActivities: nil, isAd: false))
        } else {
            if !view.additionalItemEntries.isEmpty {
                var pinningIndex: UInt16 = UInt16(view.additionalItemEntries.count - 1)
                for entry in view.additionalItemEntries.reversed() {
                    switch entry {
                        case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, summaryInfo):
                            result.append(.PeerEntry(index: ChatListIndex(pinningIndex: pinningIndex, messageIndex: index.messageIndex), presentationData: state.presentationData, message: message, readState: combinedReadState, notificationSettings: notificationSettings, embeddedInterfaceState: embeddedState, peer: peer, summaryInfo: summaryInfo, editing: state.editing, hasActiveRevealControls: index.messageIndex.id.peerId == state.peerIdWithRevealedOptions, selected: state.selectedPeerIds.contains(index.messageIndex.id.peerId), inputActivities: state.peerInputActivities?.activities[index.messageIndex.id.peerId], isAd: true))
                            if pinningIndex != 0 {
                                pinningIndex -= 1
                            }
                        default:
                            break
                    }
                }
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
