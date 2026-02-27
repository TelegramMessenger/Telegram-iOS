import Foundation

private struct PeerChatTopTaggedUpdateRecord: Equatable, Hashable {
    let peerAndThreadId: PeerAndThreadId
    let namespace: MessageId.Namespace
}

final class PeerChatTopTaggedMessageIdsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    private var cachedTopIds: [PeerAndThreadId: [MessageId.Namespace: MessageId?]] = [:]
    private var updatedPeerIds = Set<PeerChatTopTaggedUpdateRecord>()
    
    private let sharedKeyNoThreadId = ValueBoxKey(length: 8 + 4)
    private let sharedKeyWithThreadId = ValueBoxKey(length: 8 + 4 + 8)
    
    private func key(combinedId: PeerAndThreadId, namespace: MessageId.Namespace) -> ValueBoxKey {
        if let threadId = combinedId.threadId {
            self.sharedKeyWithThreadId.setInt64(0, value: combinedId.peerId.toInt64())
            self.sharedKeyWithThreadId.setInt32(8, value: namespace)
            self.sharedKeyWithThreadId.setInt64(8 + 4, value: threadId)
            
            return self.sharedKeyWithThreadId
        } else {
            self.sharedKeyNoThreadId.setInt64(0, value: combinedId.peerId.toInt64())
            self.sharedKeyNoThreadId.setInt32(8, value: namespace)
            
            return self.sharedKeyNoThreadId
        }
    }
    
    func get(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) -> MessageId? {
        let combinedId = PeerAndThreadId(peerId: peerId, threadId: threadId)
        
        if let cachedDict = self.cachedTopIds[combinedId] {
            if let maybeCachedId = cachedDict[namespace] {
                return maybeCachedId
            } else {
                if let value = self.valueBox.get(self.table, key: self.key(combinedId: combinedId, namespace: namespace)) {
                    var messageIdId: Int32 = 0
                    value.read(&messageIdId, offset: 0, length: 4)
                    self.cachedTopIds[combinedId]![namespace] = MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
                    return MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
                } else {
                    let item: MessageId? = nil
                    self.cachedTopIds[combinedId]![namespace] = item
                    return nil
                }
            }
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(combinedId: combinedId, namespace: namespace)) {
                var messageIdId: Int32 = 0
                value.read(&messageIdId, offset: 0, length: 4)
                self.cachedTopIds[combinedId] = [namespace: MessageId(peerId: peerId, namespace: namespace, id: messageIdId)]
                return MessageId(peerId: peerId, namespace: namespace, id: messageIdId)
            } else {
                let item: MessageId? = nil
                self.cachedTopIds[combinedId] = [namespace: item]
                return nil
            }
        }
    }
    
    private func set(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace, id: MessageId?) {
        let combinedId = PeerAndThreadId(peerId: peerId, threadId: threadId)
        
        if let _ = self.cachedTopIds[combinedId] {
            self.cachedTopIds[combinedId]![namespace] = id
        } else {
            self.cachedTopIds[combinedId] = [namespace: id]
        }
        self.updatedPeerIds.insert(PeerChatTopTaggedUpdateRecord(peerAndThreadId: combinedId, namespace: namespace))
    }
    
    func replay(historyOperationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        for (_, operations) in historyOperationsByPeerId {
            for operation in operations {
                switch operation {
                    case let .InsertMessage(message):
                        if message.flags.contains(.TopIndexable) {
                            let currentTopMessageId = self.get(peerId: message.id.peerId, threadId: message.threadId, namespace: message.id.namespace)
                            if currentTopMessageId == nil || currentTopMessageId! < message.id {
                                self.set(peerId: message.id.peerId, threadId: message.threadId, namespace: message.id.namespace, id: message.id)
                            }
                        }
                    case let .Remove(indices):
                        for (index, _, threadId) in indices {
                            if let messageId = self.get(peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace), index.id == messageId {
                                self.set(peerId: index.id.peerId, threadId: threadId, namespace: index.id.namespace, id: nil)
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
                if let cachedDict = self.cachedTopIds[record.peerAndThreadId], let maybeMessageId = cachedDict[record.namespace] {
                    if let maybeMessageId = maybeMessageId {
                        var messageIdId: Int32 = maybeMessageId.id
                        self.valueBox.set(self.table, key: self.key(combinedId: record.peerAndThreadId, namespace: record.namespace), value: MemoryBuffer(memory: &messageIdId, capacity: 4, length: 4, freeWhenDone: false))
                    } else {
                        self.valueBox.remove(self.table, key: self.key(combinedId: record.peerAndThreadId, namespace: record.namespace), secure: false)
                    }
                }
            }
            self.updatedPeerIds.removeAll()
        }
    }
}
