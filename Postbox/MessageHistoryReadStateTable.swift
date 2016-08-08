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
    private var cachedPeerReadStates: [PeerId: InternalPeerReadStates?] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }

    private func get(_ id: PeerId) -> InternalPeerReadStates? {
        if let states = self.cachedPeerReadStates[id] {
            return states
        } else {
            if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
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
    
    func resetStates(_ peerId: PeerId, namespaces: [MessageId.Namespace: PeerReadState]) -> CombinedPeerReadState? {
        if traceReadStates {
            print("[ReadStateTable] resetStates peerId: \(peerId), namespaces: \(namespaces)")
        }
        
        self.updatedPeerIds.insert(peerId)
        
        if let states = self.get(peerId) {
            var updated = false
            for (namespace, state) in namespaces {
                if states.namespaces[namespace] == nil || states.namespaces[namespace]! != state {
                    updated = true
                }
                states.namespaces[namespace] = state
            }
            if updated {
                self.updatedPeerIds.insert(peerId)
                return CombinedPeerReadState(states: states.namespaces.map({$0}))
            } else {
                return nil
            }
        } else {
            self.updatedPeerIds.insert(peerId)
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
                        states.namespaces[namespace] = PeerReadState(maxIncomingReadId: currentState.maxIncomingReadId, maxOutgoingReadId: currentState.maxOutgoingReadId, maxKnownId: currentState.maxKnownId, count: currentState.count + addedUnreadCount)
                        updated = true
                        
                        if traceReadStates {
                            print("[ReadStateTable] added \(addedUnreadCount)")
                        }
                    }
                }
            }
            
            if updated {
                self.updatedPeerIds.insert(peerId)
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
                    
                    states.namespaces[namespace] = PeerReadState(maxIncomingReadId: currentState.maxIncomingReadId, maxOutgoingReadId: currentState.maxOutgoingReadId, maxKnownId: currentState.maxKnownId, count: currentState.count - knownCount)
                    updated = true
                } else {
                    invalidate = true
                }
            }
            
            if updated {
                self.updatedPeerIds.insert(peerId)
            }
            
            return (updated ? CombinedPeerReadState(states: states.namespaces.map({$0})) : nil, invalidate)
        } else {
            return (nil, true)
        }
    }
    
    func applyIncomingMaxReadId(_ messageId: MessageId, incomingStatsInRange: (MessageId.Id, MessageId.Id) -> (count: Int, holes: Bool), topMessageId: MessageId.Id?) -> (CombinedPeerReadState?, Bool) {
        if let states = self.get(messageId.peerId), state = states.namespaces[messageId.namespace] {
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
                
                states.namespaces[messageId.namespace] = PeerReadState(maxIncomingReadId: messageId.id, maxOutgoingReadId: state.maxOutgoingReadId, maxKnownId: state.maxKnownId, count: state.count - Int32(deltaCount))
                self.updatedPeerIds.insert(messageId.peerId)
                return (CombinedPeerReadState(states: states.namespaces.map({$0})), holes)
            }
        } else {
            return (nil, true)
        }
        
        return (nil, false)
    }
    
    func applyOutgoingMaxReadId(_ messageId: MessageId) -> (CombinedPeerReadState?, Bool) {
        if let states = self.get(messageId.peerId), state = states.namespaces[messageId.namespace] {
            if state.maxOutgoingReadId < messageId.id {
                states.namespaces[messageId.namespace] = PeerReadState(maxIncomingReadId: state.maxIncomingReadId, maxOutgoingReadId: state.maxOutgoingReadId, maxKnownId: state.maxKnownId, count: state.count)
                self.updatedPeerIds.insert(messageId.peerId)
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
    
    override func beforeCommit() {
        let sharedBuffer = WriteBuffer()
        for id in self.updatedPeerIds {
            if let wrappedStates = self.cachedPeerReadStates[id], states = wrappedStates {
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
                self.valueBox.set(self.tableId, key: self.key(id), value: sharedBuffer)
            } else {
                self.valueBox.remove(self.tableId, key: self.key(id))
            }
        }
        self.updatedPeerIds.removeAll()
    }
}
