import Foundation

public protocol PendingMessageActionData: PostboxCoding {
    func isEqual(to: PendingMessageActionData) -> Bool
}

public struct PendingMessageActionsEntry {
    public let id: MessageId
    public let action: PendingMessageActionData
    
    public init(id: MessageId, action: PendingMessageActionData) {
        self.id = id
        self.action = action
    }
}

public struct PendingMessageActionType: RawRepresentable, Equatable, Hashable {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

enum PendingMessageActionsOperation {
    case add(PendingMessageActionType, MessageId, PendingMessageActionData)
    case remove(PendingMessageActionType, MessageId)
}

struct PendingMessageActionsSummaryKey: Equatable, Hashable {
    let type: PendingMessageActionType
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

private func getReverseId(_ key: ValueBoxKey) -> MessageId {
    return MessageId(peerId: PeerId(key.getInt64(1 + 4)), namespace: key.getInt32(1 + 4 + 8), id: key.getInt32(1 + 4 + 8 + 4))
}

private func getActionType(_ key: ValueBoxKey) -> PendingMessageActionType {
    return PendingMessageActionType(rawValue: key.getUInt32(1 + 8 + 4 + 4))
}

private enum PendingMessageActionsTableSection: UInt8 {
    case actions = 0
    case index = 1
}

final class PendingMessageActionsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private let metadataTable: PendingMessageActionsMetadataTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, metadataTable: PendingMessageActionsMetadataTable) {
        self.metadataTable = metadataTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func forwardKey(id: MessageId, actionType: PendingMessageActionType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 8 + 4 + 4 + 4)
        key.setUInt8(0, value: PendingMessageActionsTableSection.actions.rawValue)
        key.setInt64(1, value: id.peerId.toInt64())
        key.setInt32(1 + 8, value: id.namespace)
        key.setInt32(1 + 8 + 4, value: id.id)
        key.setUInt32(1 + 8 + 4 + 4, value: actionType.rawValue)
        return key
    }
    
    private func reverseKey(id: MessageId, actionType: PendingMessageActionType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 8 + 4 + 4 + 4)
        key.setUInt8(0, value: PendingMessageActionsTableSection.index.rawValue)
        key.setUInt32(1, value: actionType.rawValue)
        key.setInt64(1 + 4, value: id.peerId.toInt64())
        key.setInt32(1 + 4 + 8, value: id.namespace)
        key.setInt32(1 + 4 + 8 + 4, value: id.id)
        return key
    }
    
    private func lowerBoundForward(id: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 8 + 4 + 4)
        key.setUInt8(0, value: PendingMessageActionsTableSection.actions.rawValue)
        key.setInt64(1, value: id.peerId.toInt64())
        key.setInt32(1 + 8, value: id.namespace)
        key.setInt32(1 + 8 + 4, value: id.id)
        return key
    }
    
    private func upperBoundForward(id: MessageId) -> ValueBoxKey {
        return self.lowerBoundForward(id: id).successor
    }
    
    private func lowerBoundReverse(type: PendingMessageActionType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4)
        key.setUInt8(0, value: PendingMessageActionsTableSection.index.rawValue)
        key.setUInt32(1, value: type.rawValue)
        return key
    }
    
    private func upperBoundReverse(type: PendingMessageActionType) -> ValueBoxKey {
        return self.lowerBoundReverse(type: type).successor
    }
    
    func getAction(id: MessageId, type: PendingMessageActionType) -> PendingMessageActionData? {
        if let value = self.valueBox.get(self.table, key: self.forwardKey(id: id, actionType: type)) {
            if let action = PostboxDecoder(buffer: value).decodeRootObject() as? PendingMessageActionData {
                return action
            } else {
                assertionFailure()
                return nil
            }
        } else {
            return nil
        }
    }
    
    func setAction(id: MessageId, type: PendingMessageActionType, action: PendingMessageActionData?, operations: inout [PendingMessageActionsOperation], updatedSummaries: inout [PendingMessageActionsSummaryKey: Int32]) {
        let currentAction = self.getAction(id: id, type: type)
        if let action = action {
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(action)
            self.valueBox.set(self.table, key: self.forwardKey(id: id, actionType: type), value: encoder.readBufferNoCopy())
            self.valueBox.set(self.table, key: self.reverseKey(id: id, actionType: type), value: MemoryBuffer())
            if currentAction != nil {
                operations.append(.remove(type, id))
            }
            operations.append(.add(type, id, action))
            if currentAction == nil {
                let updatedCount = self.metadataTable.addCount(.peerNamespaceAction(id.peerId, id.namespace, type), value: 1)
                updatedSummaries[PendingMessageActionsSummaryKey(type: type, peerId: id.peerId, namespace: id.namespace)] = updatedCount
                let _ = self.metadataTable.addCount(.peerNamespace(id.peerId, id.namespace), value: 1)
                
            }
        } else if currentAction != nil {
            operations.append(.remove(type, id))
            self.valueBox.remove(self.table, key: self.forwardKey(id: id, actionType: type), secure: false)
            self.valueBox.remove(self.table, key: self.reverseKey(id: id, actionType: type), secure: false)
            let updatedCount = self.metadataTable.addCount(.peerNamespaceAction(id.peerId, id.namespace, type), value: -1)
            updatedSummaries[PendingMessageActionsSummaryKey(type: type, peerId: id.peerId, namespace: id.namespace)] = updatedCount
            let _ = self.metadataTable.addCount(.peerNamespace(id.peerId, id.namespace), value: -1)
        }
    }
    
    func removeMessage(id: MessageId, operations: inout [PendingMessageActionsOperation], updatedSummaries: inout [PendingMessageActionsSummaryKey: Int32]) {
        if self.metadataTable.getCount(.peerNamespace(id.peerId, id.namespace)) != 0 {
            var removeTypes: [PendingMessageActionType] = []
            self.valueBox.range(self.table, start: self.lowerBoundForward(id: id), end: self.upperBoundForward(id: id), keys: { key in
                removeTypes.append(getActionType(key))
                return true
            }, limit: 0)
            for type in removeTypes {
                operations.append(.remove(type, id))
                self.valueBox.remove(self.table, key: self.forwardKey(id: id, actionType: type), secure: false)
                self.valueBox.remove(self.table, key: self.reverseKey(id: id, actionType: type), secure: false)
                let updatedCount = self.metadataTable.addCount(.peerNamespaceAction(id.peerId, id.namespace, type), value: -1)
                updatedSummaries[PendingMessageActionsSummaryKey(type: type, peerId: id.peerId, namespace: id.namespace)] = updatedCount
            }
            let _ = self.metadataTable.addCount(.peerNamespace(id.peerId, id.namespace), value: Int32(-removeTypes.count))
        }
    }
    
    func getActions(type: PendingMessageActionType) -> [PendingMessageActionsEntry] {
        var ids: [MessageId] = []
        self.valueBox.range(self.table, start: self.lowerBoundReverse(type: type), end: self.upperBoundReverse(type: type), keys: { key in
            ids.append(getReverseId(key))
            return true
        }, limit: 0)
        
        var entries: [PendingMessageActionsEntry] = []
        for id in ids {
            if let action = self.getAction(id: id, type: type) {
                entries.append(PendingMessageActionsEntry(id: id, action: action))
            } else {
                assertionFailure()
            }
        }
        return entries
    }
}
