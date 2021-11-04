import Foundation

public enum UnreadMessageCountsItem: Equatable {
    case total(ValueBoxKey?)
    case totalInGroup(PeerGroupId)
    case peer(PeerId)
}

private enum MutableUnreadMessageCountsItemEntry: Equatable {
    case total((ValueBoxKey, PreferencesEntry?)?, ChatListTotalUnreadState)
    case totalInGroup(PeerGroupId, ChatListTotalUnreadState)
    case peer(PeerId, CombinedPeerReadState?)

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
        case let .peer(peerId, readState):
            if case .peer(peerId, readState) = rhs {
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
            case let .peer(peerId):
                return .peer(peerId, postbox.readStateTable.getCombinedState(peerId))
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
        
        if !transaction.currentUpdatedTotalUnreadStates.isEmpty || !transaction.alteredInitialPeerCombinedReadStates.isEmpty || updatedPreferencesEntry != nil {
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
                case let .peer(peerId, _):
                    if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
                        self.entries[i] = .peer(peerId, postbox.readStateTable.getCombinedState(peerId))
                        updated = true
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
            case let .peer(peerId):
                return .peer(peerId, postbox.readStateTable.getCombinedState(peerId))
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
            case let .peer(peerId, count):
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
                if case .peer(peerId) = item {
                    return state?.count ?? 0
                }
            }
        }
        return nil
    }
}

final class MutableCombinedReadStateView: MutablePostboxView {
    private let peerId: PeerId
    fileprivate var state: CombinedPeerReadState?
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        self.state = postbox.readStateTable.getCombinedState(peerId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.alteredInitialPeerCombinedReadStates[self.peerId] != nil {
            let state = postbox.readStateTable.getCombinedState(peerId)
            if state != self.state {
                self.state = state
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let state = postbox.readStateTable.getCombinedState(self.peerId)
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
