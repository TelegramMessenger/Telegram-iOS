import Foundation

struct GroupFeedReadStateEntry {
    let state: GroupFeedReadState?
    
    init(_ state: GroupFeedReadState?) {
        self.state = state
    }
}

struct GroupFeedReadStateSyncOperationEntry {
    let operation: GroupFeedReadStateSyncOperation?
    
    init(_ operation: GroupFeedReadStateSyncOperation?) {
        self.operation = operation
    }
}

private enum ReadStateTableKeySpace: Int8 {
    case state = 0
    case sync = 1
}

public struct GroupFeedReadStateSyncOperation: Equatable {
    public let id: UInt32
    public let validate: Bool
    public let push: Bool
    
    public static func ==(lhs: GroupFeedReadStateSyncOperation, rhs: GroupFeedReadStateSyncOperation) -> Bool {
        return lhs.id == rhs.id && lhs.validate == rhs.validate && lhs.push == rhs.push
    }
    
    var isEmpty: Bool {
        return self.validate == false && self.push == false
    }
}

private func parseSyncKey(_ key: ValueBoxKey) -> PeerGroupId {
    assert(key.getInt8(0) == ReadStateTableKeySpace.sync.rawValue)
    return PeerGroupId(rawValue: key.getInt32(1))
}

private struct GroupFeedReadStateSyncOperationFlags: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let validate = GroupFeedReadStateSyncOperationFlags(rawValue: 1 << 0)
    static let push = GroupFeedReadStateSyncOperationFlags(rawValue: 1 << 1)
}

private func parseSyncOperation(_ value: ReadBuffer) -> GroupFeedReadStateSyncOperation {
    var idValue: UInt32 = 0
    value.read(&idValue, offset: 0, length: 4)
    var flagsValue: Int32 = 0
    value.read(&flagsValue, offset: 0, length: 4)
    let flags = GroupFeedReadStateSyncOperationFlags(rawValue: flagsValue)
    return GroupFeedReadStateSyncOperation(id: idValue, validate: flags.contains(.validate), push: flags.contains(.push))
}

private func writeSyncOperation(_ operation: GroupFeedReadStateSyncOperation, to buffer: WriteBuffer) {
    var idValue = operation.id
    buffer.write(&idValue, offset: 0, length: 4)
    var flags: GroupFeedReadStateSyncOperationFlags = []
    if operation.validate {
        flags.insert(.validate)
    }
    if operation.push {
        flags.insert(.push)
    }
    var flagsValue = flags.rawValue
    buffer.write(&flagsValue, offset: 0, length: 4)
}

final class GroupFeedReadStateUpdateContext {
    var updatedStates: [PeerGroupId: GroupFeedReadStateEntry] = [:]
    var updatedOperations: [PeerGroupId: GroupFeedReadStateSyncOperationEntry] = [:]
    
    var isEmpty: Bool {
        if !self.updatedStates.isEmpty {
            return false
        }
        if !self.updatedOperations.isEmpty {
            return false
        }
        return true
    }
}

final class GroupFeedReadStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    private let metadataTable: MessageHistoryMetadataTable
    
    private var cachedStates: [PeerGroupId: GroupFeedReadStateEntry] = [:]
    private var updatedGroupIds = Set<PeerGroupId>()
    
    private let sharedKey = ValueBoxKey(length: 1 + 4)
    
    init(valueBox: ValueBox, table: ValueBoxTable, metadataTable: MessageHistoryMetadataTable) {
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(space: ReadStateTableKeySpace, id: PeerGroupId) -> ValueBoxKey {
        self.sharedKey.setInt8(0, value: space.rawValue)
        self.sharedKey.setInt32(1, value: id.rawValue)
        return self.sharedKey
    }
    
    private func lowerBound(space: ReadStateTableKeySpace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: space.rawValue)
        return key
    }
    
    private func upperBound(space: ReadStateTableKeySpace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: space.rawValue)
        return key.successor
    }
    
    func get(_ id: PeerGroupId) -> GroupFeedReadState? {
        if let state = self.cachedStates[id] {
            return state.state
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(space: .state, id: id)) {
                var timestamp: Int32 = 0
                var idPeerId: Int64 = 0
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                value.read(&timestamp, offset: 0, length: 4)
                value.read(&idPeerId, offset: 0, length: 8)
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                let state = GroupFeedReadState(maxReadIndex: MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: timestamp))
                self.cachedStates[id] = GroupFeedReadStateEntry(state)
                return state
            } else {
                self.cachedStates[id] = GroupFeedReadStateEntry(nil)
                return nil
            }
        }
    }
    
    func set(_ id: PeerGroupId, state: GroupFeedReadState?, context: GroupFeedReadStateUpdateContext) {
        if self.get(id) != state {
            self.cachedStates[id] = GroupFeedReadStateEntry(state)
            self.updatedGroupIds.insert(id)
            context.updatedStates[id] = GroupFeedReadStateEntry(state)
        }
    }
    
    func applyLocalReadMaxIndex(postbox: Postbox, id: PeerGroupId, index: MessageIndex, context: GroupFeedReadStateUpdateContext, applyPeerRead: (PeerId, MessageIndex) -> Void) {
        if let currentState = self.get(id) {
            if currentState.maxReadIndex < index {
                let (count, holes, messagesByBeers) = postbox.groupFeedIndexTable.incomingStatsInRange(messageHistoryTable: postbox.messageHistoryTable, groupId: id, lowerBound: currentState.maxReadIndex, upperBound: index.successor())
                
                self.set(id, state: GroupFeedReadState(maxReadIndex: index), context: context)
                self.addSyncPush(id, context: context)
                
                for (peerId, index) in messagesByBeers {
                    applyPeerRead(peerId, index)
                }
            }
            if let topMessageIndex = postbox.groupFeedIndexTable.topMessageIndex(groupId: id), index >= topMessageIndex {
                let peerIds = ChatListGroupReferenceUnreadCounters(postbox: postbox, groupId: id).getUnreadPeerIds()
                for peerId in peerIds {
                    if let message = postbox.messageHistoryTable.topMessage(peerId) {
                        applyPeerRead(peerId, MessageIndex(message))
                    }
                }
            }
        } else {
            self.set(id, state: GroupFeedReadState(maxReadIndex: index), context: context)
            self.addSyncPush(id, context: context)
            self.addSyncValidate(id, context: context)
        }
    }
    
    func applyRemoteReadMaxIndex(_ id: PeerGroupId, index: MessageIndex, context: GroupFeedReadStateUpdateContext) {
        if let currentState = self.get(id) {
            self.set(id, state: GroupFeedReadState(maxReadIndex: index), context: context)
            self.removeSyncPush(id, context: context)
            self.removeSyncValidate(id, context: context)
        
            if currentState.maxReadIndex > index {
                self.addSyncPush(id, context: context)
            }
        } else {
            self.set(id, state: GroupFeedReadState(maxReadIndex: index), context: context)
            self.removeSyncPush(id, context: context)
            self.removeSyncValidate(id, context: context)
        }
    }
    
    private func getSyncOperation(_ id: PeerGroupId) -> GroupFeedReadStateSyncOperation? {
        if let value = self.valueBox.get(self.table, key: self.key(space: .sync, id: id)) {
            return parseSyncOperation(value)
        } else {
            return nil
        }
    }
    
    private func setSyncOperation(_ id: PeerGroupId, operation: GroupFeedReadStateSyncOperation?, context: GroupFeedReadStateUpdateContext) {
        if self.getSyncOperation(id) != operation {
            if let operation = operation {
                let buffer = WriteBuffer()
                writeSyncOperation(operation, to: buffer)
                self.valueBox.set(self.table, key: self.key(space: .sync, id: id), value: buffer.readBufferNoCopy())
            } else {
                self.valueBox.remove(self.table, key: self.key(space: .sync, id: id))
            }
            context.updatedOperations[id] = GroupFeedReadStateSyncOperationEntry(operation)
        }
    }
    
    func getSyncOperations() -> [PeerGroupId: GroupFeedReadStateSyncOperation] {
        var result: [PeerGroupId: GroupFeedReadStateSyncOperation] = [:]
        self.valueBox.range(self.table, start: self.lowerBound(space: .sync), end: self.upperBound(space: .sync), values: { key, value in
            let groupId = parseSyncKey(key)
            result[groupId] = parseSyncOperation(value)
            return true
        }, limit: 0)
        return result
    }
    
    func addSyncValidate(_ id: PeerGroupId, context: GroupFeedReadStateUpdateContext) {
        var operation: GroupFeedReadStateSyncOperation
        if let current = self.getSyncOperation(id) {
            operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: true, push: current.push)
        } else {
            operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: true, push: false)
        }
        self.setSyncOperation(id, operation: operation, context: context)
    }
    
    func ensureIsSyncValidating(_ id: PeerGroupId, context: GroupFeedReadStateUpdateContext) {
        if !(self.getSyncOperation(id)?.validate ?? false) {
            self.addSyncValidate(id, context: context)
        }
    }
    
    func removeSyncValidate(_ id: PeerGroupId, context: GroupFeedReadStateUpdateContext) {
        if let current = self.getSyncOperation(id) {
            let operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: false, push: current.push)
            if operation.isEmpty {
                self.setSyncOperation(id, operation: nil, context: context)
            } else {
                self.setSyncOperation(id, operation: operation, context: context)
            }
        }
    }
    
    func addSyncPush(_ id: PeerGroupId, context: GroupFeedReadStateUpdateContext) {
        var operation: GroupFeedReadStateSyncOperation
        if let current = self.getSyncOperation(id) {
            operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: current.validate, push: true)
        } else {
            operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: false, push: true)
        }
        self.setSyncOperation(id, operation: operation, context: context)
    }
    
    func removeSyncPush(_ id: PeerGroupId, context: GroupFeedReadStateUpdateContext) {
        if let current = self.getSyncOperation(id) {
            let operation = GroupFeedReadStateSyncOperation(id: self.metadataTable.getNextStableMessageIndexId(), validate: current.validate, push: false)
            if operation.isEmpty {
                self.setSyncOperation(id, operation: nil, context: context)
            } else {
                self.setSyncOperation(id, operation: operation, context: context)
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedStates.removeAll()
        self.updatedGroupIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedGroupIds.isEmpty {
            let buffer = WriteBuffer()
            for id in self.updatedGroupIds {
                if let entry = self.cachedStates[id], let state = entry.state {
                    buffer.reset()
                    var timestamp: Int32 = state.maxReadIndex.timestamp
                    var idPeerId: Int64 = state.maxReadIndex.id.peerId.toInt64()
                    var idNamespace: Int32 = state.maxReadIndex.id.namespace
                    var idId: Int32 = state.maxReadIndex.id.id
                    buffer.write(&timestamp, offset: 0, length: 4)
                    buffer.write(&idPeerId, offset: 0, length: 8)
                    buffer.write(&idNamespace, offset: 0, length: 4)
                    buffer.write(&idId, offset: 0, length: 4)
                    self.valueBox.set(self.table, key: self.key(space: .state, id: id), value: buffer.readBufferNoCopy())
                } else {
                    self.valueBox.remove(self.table, key: self.key(space: .state, id: id))
                }
            }
            self.updatedGroupIds.removeAll()
        }
    }
}
