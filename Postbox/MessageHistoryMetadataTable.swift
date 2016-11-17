import Foundation

private enum MetadataPrefix: Int8 {
    case ChatListInitialized = 0
    case PeerHistoryInitialized = 1
    case PeerNextMessageIdByNamespace = 2
    case NextStableMessageId = 3
}

final class MessageHistoryMetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let sharedPeerHistoryInitializedKey = ValueBoxKey(length: 8 + 1)
    let sharedPeerNextMessageIdByNamespaceKey = ValueBoxKey(length: 8 + 1 + 4)
    let sharedBuffer = WriteBuffer()
    
    private var initializedChatList: Bool?
    private var initializedHistoryPeerIds = Set<PeerId>()
    
    private var peerNextMessageIdByNamespace: [PeerId: [MessageId.Namespace: MessageId.Id]] = [:]
    private var updatedPeerNextMessageIdByNamespace: [PeerId: Set<MessageId.Namespace>] = [:]
    
    private var nextMessageStableId: UInt32?
    private var nextMessageStableIdUpdated = false
    
    private func peerHistoryInitializedKey(_ id: PeerId) -> ValueBoxKey {
        self.sharedPeerHistoryInitializedKey.setInt64(0, value: id.toInt64())
        self.sharedPeerHistoryInitializedKey.setInt8(8, value: MetadataPrefix.PeerHistoryInitialized.rawValue)
        return self.sharedPeerHistoryInitializedKey
    }
    
    private func peerNextMessageIdByNamespaceKey(_ id: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        self.sharedPeerNextMessageIdByNamespaceKey.setInt64(0, value: id.toInt64())
        self.sharedPeerNextMessageIdByNamespaceKey.setInt8(8, value: MetadataPrefix.PeerNextMessageIdByNamespace.rawValue)
        self.sharedPeerNextMessageIdByNamespaceKey.setInt32(8 + 1, value: namespace)
        
        return self.sharedPeerNextMessageIdByNamespaceKey
    }
    
    private func key(_ prefix: MetadataPrefix) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: prefix.rawValue)
        return key
    }
    
    func setInitializedChatList() {
        self.initializedChatList = true
        self.valueBox.set(self.table, key: self.key(MetadataPrefix.ChatListInitialized), value: MemoryBuffer())
    }
    
    func isInitializedChatList() -> Bool {
        if let initializedChatList = self.initializedChatList {
            return initializedChatList
        }
        
        if self.valueBox.get(self.table, key: self.key(MetadataPrefix.ChatListInitialized)) != nil {
            self.initializedChatList = true
            return true
        }
        
        return false
    }
    
    func setInitialized(_ peerId: PeerId) {
        self.initializedHistoryPeerIds.insert(peerId)
        self.sharedBuffer.reset()
        self.valueBox.set(self.table, key: self.peerHistoryInitializedKey(peerId), value: self.sharedBuffer)
    }
    
    func isInitialized(_ peerId: PeerId) -> Bool {
        if self.initializedHistoryPeerIds.contains(peerId) {
            return true
        } else {
            if self.valueBox.exists(self.table, key: self.peerHistoryInitializedKey(peerId)) {
                self.initializedHistoryPeerIds.insert(peerId)
                return true
            } else {
                return false
            }
        }
    }
    
    func getNextMessageIdAndIncrement(_ peerId: PeerId, namespace: MessageId.Namespace) -> MessageId {
        if let messageIdByNamespace = self.peerNextMessageIdByNamespace[peerId] {
            if let nextId = messageIdByNamespace[namespace] {
                self.peerNextMessageIdByNamespace[peerId]![namespace] = nextId + 1
                if updatedPeerNextMessageIdByNamespace[peerId] != nil {
                    updatedPeerNextMessageIdByNamespace[peerId]!.insert(namespace)
                } else {
                    updatedPeerNextMessageIdByNamespace[peerId] = Set<MessageId.Namespace>([namespace])
                }
                return MessageId(peerId: peerId, namespace: namespace, id: nextId)
            } else {
                var nextId: Int32 = 1
                if let value = self.valueBox.get(self.table, key: self.peerNextMessageIdByNamespaceKey(peerId, namespace: namespace)) {
                    value.read(&nextId, offset: 0, length: 4)
                }
                self.peerNextMessageIdByNamespace[peerId]![namespace] = nextId + 1
                if updatedPeerNextMessageIdByNamespace[peerId] != nil {
                    updatedPeerNextMessageIdByNamespace[peerId]!.insert(namespace)
                } else {
                    updatedPeerNextMessageIdByNamespace[peerId] = Set<MessageId.Namespace>([namespace])
                }
                return MessageId(peerId: peerId, namespace: namespace, id: nextId)
            }
        } else {
            var nextId: Int32 = 1
            if let value = self.valueBox.get(self.table, key: self.peerNextMessageIdByNamespaceKey(peerId, namespace: namespace)) {
                value.read(&nextId, offset: 0, length: 4)
            }
            
            self.peerNextMessageIdByNamespace[peerId] = [namespace: nextId + 1]
            if updatedPeerNextMessageIdByNamespace[peerId] != nil {
                updatedPeerNextMessageIdByNamespace[peerId]!.insert(namespace)
            } else {
                updatedPeerNextMessageIdByNamespace[peerId] = Set<MessageId.Namespace>([namespace])
            }
            return MessageId(peerId: peerId, namespace: namespace, id: nextId)
        }
    }
    
    func getNextStableMessageIndexId() -> UInt32 {
        if let nextId = self.nextMessageStableId {
            self.nextMessageStableId = nextId + 1
            self.nextMessageStableIdUpdated = true
            return nextId
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(.NextStableMessageId)) {
                var nextId: UInt32 = 0
                value.read(&nextId, offset: 0, length: 4)
                self.nextMessageStableId = nextId + 1
                self.nextMessageStableIdUpdated = true
                return nextId
            } else {
                let nextId: UInt32 = 1
                self.nextMessageStableId = nextId + 1
                self.nextMessageStableIdUpdated = true
                return nextId
            }
        }
    }
    
    override func clearMemoryCache() {
        self.initializedChatList = nil
        self.initializedHistoryPeerIds.removeAll()
        self.peerNextMessageIdByNamespace.removeAll()
        self.updatedPeerNextMessageIdByNamespace.removeAll()
        self.nextMessageStableId = nil
        self.nextMessageStableIdUpdated = false
    }
    
    override func beforeCommit() {
        let sharedBuffer = WriteBuffer()
        for (peerId, namespaces) in self.updatedPeerNextMessageIdByNamespace {
            for namespace in namespaces {
                if let messageIdByNamespace = self.peerNextMessageIdByNamespace[peerId], let maxId = messageIdByNamespace[namespace] {
                    sharedBuffer.reset()
                    var mutableMaxId = maxId
                    sharedBuffer.write(&mutableMaxId, offset: 0, length: 4)
                    self.valueBox.set(self.table, key: self.peerNextMessageIdByNamespaceKey(peerId, namespace: namespace), value: sharedBuffer)
                } else {
                    self.valueBox.remove(self.table, key: self.peerNextMessageIdByNamespaceKey(peerId, namespace: namespace))
                }
            }
        }
        self.updatedPeerNextMessageIdByNamespace.removeAll()
        
        if self.nextMessageStableIdUpdated {
            if let nextMessageStableId = self.nextMessageStableId {
                var nextId: UInt32 = nextMessageStableId
                self.valueBox.set(self.table, key: self.key(.NextStableMessageId), value: MemoryBuffer(memory: &nextId, capacity: 4, length: 4, freeWhenDone: false))
                self.nextMessageStableIdUpdated = false
            }
        }
    }
}
