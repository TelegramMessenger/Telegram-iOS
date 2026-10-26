import Foundation

public enum UnreadMessageCountsItem: Equatable {
    case total(ValueBoxKey?)
    case totalInGroup(PeerGroupId)
    case peer(id: PeerId, handleThreads: Bool)
}

private enum MutableUnreadMessageCountsItemEntry: Equatable {
    case total((ValueBoxKey, PreferencesEntry?)?, ChatListTotalUnreadState)
    case totalInGroup(PeerGroupId, ChatListTotalUnreadState)
    case peer(PeerId, Bool, CombinedPeerReadState?)

    static func ==(lhs: MutableUnreadMessageCountsItemEntry, rhs: MutableUnreadMessageCountsItemEntry) -> Bool {
        switch lhs {
        case let .total(lhsKeyAndEntry, lhsUnreadState):
            if case let .total(rhsKeyAndEntry, rhsUnreadState) = rhs {
                if lhsKeyAndEntry?.0 != rhsKeyAndEntry?.0 {
                    return false
                }
                if lhsKeyAndEntry?.1 != rhsKeyAndEntry?.1 {
                    return false
                }
                if lhsUnreadState != rhsUnreadState {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .totalInGroup(groupId, state):
            if case .totalInGroup(groupId, state) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(peerId, handleThreads, readState):
            if case .peer(peerId, handleThreads, readState) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum UnreadMessageCountsItemEntry {
    case total(PreferencesEntry?, ChatListTotalUnreadState)
    case totalInGroup(PeerGroupId, ChatListTotalUnreadState)
    case peer(PeerId, CombinedPeerReadState?)
}

/// The read state a `.peer` item reports. A thread-based peer (a forum) has no meaningful
/// read state of its own: its counter is the number of topics with unread messages among
/// its most recent ones (the peer-threads summary looks at twenty), wrapped in a synthetic
/// state.
private func peerCombinedReadState(postbox: PostboxImpl, peerId: PeerId, handleThreads: Bool) -> CombinedPeerReadState? {
    if handleThreads, let peer = postbox.peerTable.get(peerId), postbox.seedConfiguration.peerSummaryIsThreadBased(peer, peer.associatedPeerId.flatMap(postbox.peerTable.get)).value {
        var count: Int32 = 0
        if let summary = postbox.peerThreadsSummaryTable.get(peerId: peerId) {
            count = summary.totalUnreadCount
        }
        return CombinedPeerReadState(states: [(0, .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 1, count: count, markedUnread: false))])
    } else {
        return postbox.readStateTable.getCombinedState(peerId)
    }
}

/// Whether `transaction` may have changed what `peerCombinedReadState` returns for `peerId`:
/// its read state, and when threads are handled also its threads summary (recomputed
/// whenever a topic's thread info changes, which is all that reading a topic touches) and
/// the peer record itself or its associated peer, which decide between the two counters.
private func peerCombinedReadStateMayHaveChanged(postbox: PostboxImpl, peerId: PeerId, handleThreads: Bool, transaction: PostboxTransaction) -> Bool {
    if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
        return true
    }
    if !handleThreads {
        return false
    }
    if transaction.updatedPeerThreadsSummaries.contains(peerId) {
        return true
    }
    if !transaction.currentUpdatedPeers.isEmpty {
        if transaction.currentUpdatedPeers[peerId] != nil {
            return true
        }
        if let associatedPeerId = postbox.peerTable.get(peerId)?.associatedPeerId, transaction.currentUpdatedPeers[associatedPeerId] != nil {
            return true
        }
    }
    return false
}

final class MutableUnreadMessageCountsView: MutablePostboxView {
    private let items: [UnreadMessageCountsItem]
    fileprivate var entries: [MutableUnreadMessageCountsItemEntry]
    
    init(postbox: PostboxImpl, items: [UnreadMessageCountsItem]) {
        self.items = items

        self.entries = items.map { item in
            switch item {
            case let .total(preferencesKey):
                return .total(preferencesKey.flatMap({ ($0, postbox.preferencesTable.get(key: $0)) }), postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: .root))
            case let .totalInGroup(groupId):
                return .totalInGroup(groupId, postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: groupId))
            case let .peer(peerId, handleThreads):
                return .peer(peerId, handleThreads, peerCombinedReadState(postbox: postbox, peerId: peerId, handleThreads: handleThreads))
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        var updatedPreferencesEntry: PreferencesEntry?
        if !transaction.currentPreferencesOperations.isEmpty {
            for i in 0 ..< self.entries.count {
                if case let .total(maybeKeyAndValue, _) = self.entries[i], let (key, _) = maybeKeyAndValue {
                    for operation in transaction.currentPreferencesOperations {
                        if case let .update(updateKey, value) = operation {
                            if key == updateKey {
                                updatedPreferencesEntry = value
                            }
                        }
                    }
                }
            }
        }
        
        if !transaction.currentUpdatedTotalUnreadStates.isEmpty || !transaction.alteredInitialPeerCombinedReadStates.isEmpty || !transaction.updatedPeerThreadsSummaries.isEmpty || !transaction.currentUpdatedPeers.isEmpty || updatedPreferencesEntry != nil {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                case let .total(keyAndEntry, state):
                    if let updatedState = transaction.currentUpdatedTotalUnreadStates[.root] {
                        if updatedState != state {
                            self.entries[i] = .total(keyAndEntry.flatMap({ ($0.0, updatedPreferencesEntry ?? $0.1) }), updatedState)
                            updated = true
                        }
                    }
                case let .totalInGroup(groupId, state):
                    if let updatedState = transaction.currentUpdatedTotalUnreadStates[groupId] {
                        if updatedState != state {
                            self.entries[i] = .totalInGroup(groupId, updatedState)
                            updated = true
                        }
                    }
                case let .peer(peerId, handleThreads, state):
                    if peerCombinedReadStateMayHaveChanged(postbox: postbox, peerId: peerId, handleThreads: handleThreads, transaction: transaction) {
                        let updatedState = peerCombinedReadState(postbox: postbox, peerId: peerId, handleThreads: handleThreads)
                        if updatedState != state {
                            self.entries[i] = .peer(peerId, handleThreads, updatedState)
                            updated = true
                        }
                    }
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let entries: [MutableUnreadMessageCountsItemEntry] = self.items.map { item -> MutableUnreadMessageCountsItemEntry in
            switch item {
            case let .total(preferencesKey):
                return .total(preferencesKey.flatMap({ ($0, postbox.preferencesTable.get(key: $0)) }), postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: .root))
            case let .totalInGroup(groupId):
                return .totalInGroup(groupId, postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: groupId))
            case let .peer(peerId, handleThreads):
                return .peer(peerId, handleThreads, peerCombinedReadState(postbox: postbox, peerId: peerId, handleThreads: handleThreads))
            }
        }
        if self.entries != entries {
            self.entries = entries
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return UnreadMessageCountsView(self)
    }
}

public final class UnreadMessageCountsView: PostboxView {
    public let entries: [UnreadMessageCountsItemEntry]
    
    init(_ view: MutableUnreadMessageCountsView) {
        self.entries = view.entries.map { entry in
            switch entry {
            case let .total(keyAndValue, state):
                return .total(keyAndValue?.1, state)
            case let .totalInGroup(groupId, state):
                return .totalInGroup(groupId, state)
            case let .peer(peerId, _, count):
                return .peer(peerId, count)
            }
        }
    }
    
    public func total() -> (PreferencesEntry?, ChatListTotalUnreadState)? {
        for entry in self.entries {
            switch entry {
            case let .total(preferencesEntry, state):
                return (preferencesEntry, state)
            default:
                break
            }
        }
        return nil
    }
    
    public func count(for item: UnreadMessageCountsItem) -> Int32? {
        for entry in self.entries {
            switch entry {
            case .total, .totalInGroup:
                break
            case let .peer(peerId, state):
                if case .peer(peerId, _) = item {
                    return state?.count ?? 0
                }
            }
        }
        return nil
    }
    
    public func countOrUnread(for item: UnreadMessageCountsItem) -> (Int32, Bool)? {
        for entry in self.entries {
            switch entry {
            case .total, .totalInGroup:
                break
            case let .peer(peerId, state):
                if case .peer(peerId, _) = item {
                    return (state?.count ?? 0, state?.markedUnread ?? false)
                }
            }
        }
        return nil
    }
}

final class MutableCombinedReadStateView: MutablePostboxView {
    private let peerId: PeerId
    private let handleThreads: Bool
    fileprivate var state: CombinedPeerReadState?
    
    init(postbox: PostboxImpl, peerId: PeerId, handleThreads: Bool) {
        self.peerId = peerId
        self.handleThreads = handleThreads
        
        let _ = self.refreshDueToExternalTransaction(postbox: postbox)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if peerCombinedReadStateMayHaveChanged(postbox: postbox, peerId: self.peerId, handleThreads: self.handleThreads, transaction: transaction) {
            return self.reload(postbox: postbox)
        }
        return false
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return self.reload(postbox: postbox)
    }

    /// Re-reads the state and reports whether it changed.
    private func reload(postbox: PostboxImpl) -> Bool {
        let state = peerCombinedReadState(postbox: postbox, peerId: self.peerId, handleThreads: self.handleThreads)
        if state != self.state {
            self.state = state
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return CombinedReadStateView(self)
    }
}

public final class CombinedReadStateView: PostboxView {
    public let state: CombinedPeerReadState?
    
    init(_ view: MutableCombinedReadStateView) {
        self.state = view.state
    }
}
