import Foundation

private let traceReadStates = false

enum ApplyInteractiveMaxReadIdResult {
    case None
    case Push(thenSync: Bool)
}

private final class InternalPeerReadStates {
    var namespaces: [MessageId.Namespace: PeerReadState]
    
    init(namespaces: [MessageId.Namespace: PeerReadState]) {
        self.namespaces = namespaces
    }
}

final class MessageHistoryReadStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private var cachedPeerReadStates: [PeerId: InternalPeerReadStates?] = [:]
    private var updatedInitialPeerReadStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    override init(valueBox: ValueBox, table: ValueBoxTable) {
        super.init(valueBox: valueBox, table: table)
    }

    private func get(_ id: PeerId) -> InternalPeerReadStates? {
        if let states = self.cachedPeerReadStates[id] {
            return states
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(id)) {
                var count: Int32 = 0
                value.read(&count, offset: 0, length: 4)
                var stateByNamespace: [MessageId.Namespace: PeerReadState] = [:]
                for _ in 0 ..< count {
                    var namespaceId: Int32 = 0
                    var maxIncomingReadId: Int32 = 0
                    var maxOutgoingReadId: Int32 = 0
                    var maxKnownId: Int32 = 0
                    var count: Int32 = 0
                    value.read(&namespaceId, offset: 0, length: 4)
                    value.read(&maxIncomingReadId, offset: 0, length: 4)
                    value.read(&maxOutgoingReadId, offset: 0, length: 4)
                    value.read(&maxKnownId, offset: 0, length: 4)
                    value.read(&count, offset: 0, length: 4)
                    
                    let state = PeerReadState(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count)
                    stateByNamespace[namespaceId] = state
                }
                let states = InternalPeerReadStates(namespaces: stateByNamespace)
                self.cachedPeerReadStates[id] = states
                return states
            } else {
                self.cachedPeerReadStates[id] = nil
                return nil
            }
        }
    }
    
    func getCombinedState(_ peerId: PeerId) -> CombinedPeerReadState? {
        if let states = self.get(peerId) {
            return CombinedPeerReadState(states: states.namespaces.map({$0}))
        }
        return nil
    }
    
    private func markReadStatesAsUpdated(_ peerId: PeerId, namespaces: [MessageId.Namespace: PeerReadState]) {
        if self.updatedInitialPeerReadStates[peerId] == nil {
            self.updatedInitialPeerReadStates[peerId] = namespaces
        }
    }
    
    func resetStates(_ peerId: PeerId, namespaces: [MessageId.Namespace: PeerReadState]) -> CombinedPeerReadState? {
        if traceReadStates {
            print("[ReadStateTable] resetStates peerId: \(peerId), namespaces: \(namespaces)")
        }
        
        if let states = self.get(peerId) {
            var updated = false
            for (namespace, state) in namespaces {
                if states.namespaces[namespace] == nil || states.namespaces[namespace]! != state {
                    self.markReadStatesAsUpdated(peerId, namespaces: states.namespaces)
                    updated = true
                }
                states.namespaces[namespace] = state
            }
            if updated {
                return CombinedPeerReadState(states: states.namespaces.map({$0}))
            } else {
                return nil
            }
        } else {
            self.markReadStatesAsUpdated(peerId, namespaces: [:])
            let states = InternalPeerReadStates(namespaces: namespaces)
            self.cachedPeerReadStates[peerId] = states
            return CombinedPeerReadState(states: states.namespaces.map({$0}))
        }
    }
    
    func addIncomingMessages(_ peerId: PeerId, ids: Set<MessageId>) -> (CombinedPeerReadState?, Bool) {
        var idsByNamespace: [MessageId.Namespace: [MessageId.Id]] = [:]
        for id in ids {
            if idsByNamespace[id.namespace] != nil {
                idsByNamespace[id.namespace]!.append(id.id)
            } else {
                idsByNamespace[id.namespace] = [id.id]
            }
        }
        
        if let states = self.get(peerId) {
            if traceReadStates {
                print("[ReadStateTable] addIncomingMessages peerId: \(peerId), ids: \(ids) (before: \(states.namespaces))")
            }
            
            var updated = false
            let invalidated = false
            for (namespace, ids) in idsByNamespace {
                if let currentState = states.namespaces[namespace] {
                    var addedUnreadCount: Int32 = 0
                    var maxIncomingId: Int32 = 0
                    for id in ids {
                        if id > currentState.maxKnownId && id > currentState.maxIncomingReadId {
                            addedUnreadCount += 1
                            maxIncomingId = max(id, maxIncomingId)
                        }
                    }
                    
                    if addedUnreadCount != 0 {
                        self.markReadStatesAsUpdated(peerId, namespaces: states.namespaces)
                        
                        states.namespaces[namespace] = PeerReadState(maxIncomingReadId: currentState.maxIncomingReadId, maxOutgoingReadId: currentState.maxOutgoingReadId, maxKnownId: currentState.maxKnownId, count: currentState.count + addedUnreadCount)
                        updated = true
                        
                        if traceReadStates {
                            print("[ReadStateTable] added \(addedUnreadCount)")
                        }
                    }
                }
            }
            
            return (updated ? CombinedPeerReadState(states: states.namespaces.map({$0})) : nil, invalidated)
        } else {
            if traceReadStates {
                print("[ReadStateTable] addIncomingMessages peerId: \(peerId), just invalidated)")
            }
            return (nil, true)
        }
    }
    
    func deleteMessages(_ peerId: PeerId, ids: [MessageId], incomingStatsInIds: (PeerId, MessageId.Namespace, [MessageId.Id]) -> (Int, Bool)) -> (CombinedPeerReadState?, Bool) {
        var idsByNamespace: [MessageId.Namespace: [MessageId.Id]] = [:]
        for id in ids {
            if idsByNamespace[id.namespace] != nil {
                idsByNamespace[id.namespace]!.append(id.id)
            } else {
                idsByNamespace[id.namespace] = [id.id]
            }
        }
        
        if let states = self.get(peerId) {
            if traceReadStates {
                print("[ReadStateTable] deleteMessages peerId: \(peerId), ids: \(ids) (before: \(states.namespaces))")
            }
            
            var updated = false
            var invalidate = false
            for (namespace, ids) in idsByNamespace {
                if let currentState = states.namespaces[namespace] {
                    var unreadIds: [MessageId.Id] = []
                    for id in ids {
                        if id > currentState.maxIncomingReadId {
                            unreadIds.append(id)
                        }
                    }
                    
                    let (knownCount, holes) = incomingStatsInIds(peerId, namespace, unreadIds)
                    if holes {
                        invalidate = true
                    }
                    
                    self.markReadStatesAsUpdated(peerId, namespaces: states.namespaces)
                    
                    states.namespaces[namespace] = PeerReadState(maxIncomingReadId: currentState.maxIncomingReadId, maxOutgoingReadId: currentState.maxOutgoingReadId, maxKnownId: currentState.maxKnownId, count: currentState.count - knownCount)
                    updated = true
                } else {
                    invalidate = true
                }
            }
            
            return (updated ? CombinedPeerReadState(states: states.namespaces.map({$0})) : nil, invalidate)
        } else {
            return (nil, true)
        }
    }
    
    func applyIncomingMaxReadId(_ messageId: MessageId, incomingStatsInRange: (MessageId.Id, MessageId.Id) -> (count: Int, holes: Bool), topMessageId: MessageId.Id?) -> (CombinedPeerReadState?, Bool) {
        if let states = self.get(messageId.peerId), let state = states.namespaces[messageId.namespace] {
            if traceReadStates {
                print("[ReadStateTable] applyMaxReadId peerId: \(messageId.peerId), maxReadId: \(messageId.id) (before: \(states.namespaces))")
            }
            
            if state.maxIncomingReadId < messageId.id || (messageId.id == topMessageId && state.count != 0) {
                var (deltaCount, holes) = incomingStatsInRange(state.maxIncomingReadId + 1, messageId.id)
                
                if traceReadStates {
                    print("[ReadStateTable] applyMaxReadId after deltaCount: \(deltaCount), holes: \(holes)")
                }
                
                if messageId.id == topMessageId {
                    if deltaCount != Int(state.count) {
                        deltaCount = Int(state.count)
                        holes = true
                    }
                }
                
                self.markReadStatesAsUpdated(messageId.peerId, namespaces: states.namespaces)
                
                states.namespaces[messageId.namespace] = PeerReadState(maxIncomingReadId: messageId.id, maxOutgoingReadId: state.maxOutgoingReadId, maxKnownId: state.maxKnownId, count: state.count - Int32(deltaCount))
                return (CombinedPeerReadState(states: states.namespaces.map({$0})), holes)
            }
        } else {
            return (nil, true)
        }
        
        return (nil, false)
    }
    
    func applyOutgoingMaxReadId(_ messageId: MessageId) -> (CombinedPeerReadState?, Bool) {
        if let states = self.get(messageId.peerId), let state = states.namespaces[messageId.namespace] {
            if state.maxOutgoingReadId < messageId.id {
                self.markReadStatesAsUpdated(messageId.peerId, namespaces: states.namespaces)
                
                states.namespaces[messageId.namespace] = PeerReadState(maxIncomingReadId: state.maxIncomingReadId, maxOutgoingReadId: messageId.id, maxKnownId: state.maxKnownId, count: state.count)
                return (CombinedPeerReadState(states: states.namespaces.map({$0})), false)
            }
        } else {
            return (nil, true)
        }
        
        return (nil, false)
    }
    
    func applyInteractiveMaxReadId(_ messageId: MessageId, incomingStatsInRange: (MessageId.Id, MessageId.Id) -> (count: Int, holes: Bool), topMessageId: MessageId.Id?) -> (combinedState: CombinedPeerReadState?, ApplyInteractiveMaxReadIdResult) {
        let (combinedState, holes) = self.applyIncomingMaxReadId(messageId, incomingStatsInRange: incomingStatsInRange, topMessageId: topMessageId)
        
        if let combinedState = combinedState {
            return (combinedState, .Push(thenSync: holes))
        }
        
        return (combinedState, holes ? .Push(thenSync: true) : .None)
    }
    
    func transactionUnreadCountDeltas() -> [PeerId: Int32] {
        var deltas: [PeerId: Int32] = [:]
        for (id, initialNamespaces) in self.updatedInitialPeerReadStates {
            var initialCount: Int32 = 0
            for (_, state) in initialNamespaces {
                initialCount += state.count
            }
            
            var updatedCount: Int32 = 0
            if let maybeStates = self.cachedPeerReadStates[id] {
                if let states = maybeStates {
                    for (_, state) in states.namespaces {
                        updatedCount += state.count
                    }
                }
            } else {
                assertionFailure()
            }
            
            if initialCount != updatedCount {
                deltas[id] = updatedCount - initialCount
            }
        }
        return deltas
    }
    
    override func clearMemoryCache() {
        self.cachedPeerReadStates.removeAll()
        assert(self.updatedInitialPeerReadStates.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedInitialPeerReadStates.isEmpty {
            let sharedBuffer = WriteBuffer()
            for (id, initialNamespaces) in self.updatedInitialPeerReadStates {
                if let wrappedStates = self.cachedPeerReadStates[id], let states = wrappedStates {
                    sharedBuffer.reset()
                    var count: Int32 = Int32(states.namespaces.count)
                    sharedBuffer.write(&count, offset: 0, length: 4)
                    for (namespace, state) in states.namespaces {
                        var namespaceId: Int32 = namespace
                        var maxIncomingReadId: Int32 = state.maxIncomingReadId
                        var maxOutgoingReadId: Int32 = state.maxOutgoingReadId
                        var maxKnownId: Int32 = state.maxKnownId
                        var count: Int32 = state.count
                        sharedBuffer.write(&namespaceId, offset: 0, length: 4)
                        sharedBuffer.write(&maxIncomingReadId, offset: 0, length: 4)
                        sharedBuffer.write(&maxOutgoingReadId, offset: 0, length: 4)
                        sharedBuffer.write(&maxKnownId, offset: 0, length: 4)
                        sharedBuffer.write(&count, offset: 0, length: 4)
                    }
                    self.valueBox.set(self.table, key: self.key(id), value: sharedBuffer)
                } else {
                    self.valueBox.remove(self.table, key: self.key(id))
                }
            }
            self.updatedInitialPeerReadStates.removeAll()
        }
    }
}
