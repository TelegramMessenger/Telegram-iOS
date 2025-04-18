import Foundation

private struct PeerChatTopTaggedUpdateRecord: Equatable, Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

final class PeerChatTopTaggedMessageIdsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var cachedTopIds: [PeerId: [MessageId.Namespace: MessageId?]] = [:]
    private var updatedPeerIds = Set<PeerChatTopTaggedUpdateRecord>()
    
    private let sharedKey = ValueBoxKey(length: 8 + 4)
    
    private func key(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        self.sharedKey.setInt32(8, value: namespace)
        return self.sharedKey
    }
    
    func get(peerId: PeerId, namespace: MessageId.Namespace) -> MessageId? {
        if let cachedDict = self.cachedTopIds[peerId] {
            if let maybeCachedId = cachedDict[namespace] {
                return maybeCachedId
            } else {
                if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId, namespace: namespace)) {
                    var messageIdId: Int32 = 0
                    value.read(&messageIdId, offset: 0, length: 4)
                    self.cachedTopIds[peerId]![namespace] = MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
                    return MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
                } else {
                    let item: MessageId? = nil
                    self.cachedTopIds[peerId]![namespace] = item
                    return nil
                }
            }
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(peerId: peerId, namespace: namespace)) {
                var messageIdId: Int32 = 0
                value.read(&messageIdId, offset: 0, length: 4)
                self.cachedTopIds[peerId] = [namespace: MessageId(peerId: peerId, namespace: namespace, id: messageIdId)]
                return MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
            } else {
                let item: MessageId? = nil
                self.cachedTopIds[peerId] = [namespace: item]
                return nil
            }
        }
    }
    
    private func set(peerId: PeerId, namespace: MessageId.Namespace, id: MessageId?) {
        if let _ = self.cachedTopIds[peerId] {
            self.cachedTopIds[peerId]![namespace] = id
        } else {
            self.cachedTopIds[peerId] = [namespace: id]
        }
        self.updatedPeerIds.insert(PeerChatTopTaggedUpdateRecord(peerId: peerId, namespace: namespace))
    }
    
    func replay(historyOperationsByPeerId: [PeerId : [MessageHistoryOperation]]) {
        for (_, operations) in historyOperationsByPeerId {
            for operation in operations {
                switch operation {
                    case let .InsertMessage(message):
                        if message.flags.contains(.TopIndexable) {
                            let currentTopMessageId = self.get(peerId: message.id.peerId, namespace: message.id.namespace)
                            if currentTopMessageId == nil || currentTopMessageId! < message.id {
                                self.set(peerId: message.id.peerId, namespace: message.id.namespace, id: message.id)
                            }
                        }
                    case let .Remove(indices):
                        for (index, _) in indices {
                            if let messageId = self.get(peerId: index.id.peerId, namespace: index.id.namespace), index.id == messageId {
                                self.set(peerId: index.id.peerId, namespace: index.id.namespace, id: nil)
                            }
                        }
                    default:
                        break
                }
            }
        }
    }
    
    override func clearMemoryCache() {
        assert(self.updatedPeerIds.isEmpty)
        self.cachedTopIds.removeAll()
    }
    
    override func beforeCommit() {
        if !self.updatedPeerIds.isEmpty {
            for record in self.updatedPeerIds {
                if let cachedDict = self.cachedTopIds[record.peerId], let maybeMessageId = cachedDict[record.namespace] {
                    if let maybeMessageId = maybeMessageId {
                        var messageIdId: Int32 = maybeMessageId.id
                        self.valueBox.set(self.table, key: self.key(peerId: record.peerId, namespace: record.namespace), value: MemoryBuffer(memory: &messageIdId, capacity: 4, length: 4, freeWhenDone: false))
                    } else {
                        self.valueBox.remove(self.table, key: self.key(peerId: record.peerId, namespace: record.namespace), secure: false)
                    }
                }
            }
            self.updatedPeerIds.removeAll()
        }
    }
}
