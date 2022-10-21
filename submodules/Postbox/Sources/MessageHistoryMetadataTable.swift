import Foundation

private enum MetadataPrefix: Int8 {
    case ChatListInitialized = 0
    case PeerNextMessageIdByNamespace = 2
    case NextStableMessageId = 3
    case ChatListTotalUnreadState = 4
    case NextPeerOperationLogIndex = 5
    case ChatListGroupInitialized = 6
    case GroupFeedIndexInitialized = 7
    case ShouldReindexUnreadCounts = 8
    case PeerHistoryInitialized = 9
    case ShouldReindexUnreadCountsState = 10
    case TotalUnreadCountStates = 11
    case PeerHistoryTagInitialized = 12
    case PeerHistoryThreadHoleIndexInitialized = 13
}

public struct ChatListTotalUnreadCounters: PostboxCoding, Equatable {
    public var messageCount: Int32
    public var chatCount: Int32
    
    public init(messageCount: Int32, chatCount: Int32) {
        self.messageCount = messageCount
        self.chatCount = chatCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.messageCount = decoder.decodeInt32ForKey("m", orElse: 0)
        self.chatCount = decoder.decodeInt32ForKey("c", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.messageCount, forKey: "m")
        encoder.encodeInt32(self.chatCount, forKey: "c")
    }
}

private struct InitializedChatListKey: Hashable {
    let groupId: PeerGroupId
}

final class MessageHistoryMetadataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }
    
    let sharedPeerHistoryInitializedKey = ValueBoxKey(length: 8 + 1)
    let sharedPeerThreadHoleIndexInitializedKey = ValueBoxKey(length: 8 + 1 + 8)
    let sharedGroupFeedIndexInitializedKey = ValueBoxKey(length: 4 + 1)
    let sharedChatListGroupHistoryInitializedKey = ValueBoxKey(length: 4 + 1)
    let sharedPeerNextMessageIdByNamespaceKey = ValueBoxKey(length: 8 + 1 + 4)
    let sharedBuffer = WriteBuffer()
    
    private var initializedChatList = Set<InitializedChatListKey>()
    private var initializedHistoryPeerIds = Set<PeerId>()
    private var initializedHistoryPeerIdTags: [PeerId: Set<MessageTags>] = [:]
    private var initializedGroupFeedIndexIds = Set<PeerGroupId>()
    
    private var peerNextMessageIdByNamespace: [PeerId: [MessageId.Namespace: MessageId.Id]] = [:]
    private var updatedPeerNextMessageIdByNamespace: [PeerId: Set<MessageId.Namespace>] = [:]
    
    private var nextMessageStableId: UInt32?
    private var nextMessageStableIdUpdated = false
    
    private var chatListTotalUnreadStates: [PeerGroupId: ChatListTotalUnreadState] = [:]
    private var updatedChatListTotalUnreadStates = Set<PeerGroupId>()
    
    private var nextPeerOperationLogIndex: UInt32?
    private var nextPeerOperationLogIndexUpdated = false
    
    private var currentPinnedChatPeerIds: Set<PeerId>?
    private var currentPinnedChatPeerIdsUpdated = false
    
    private func peerHistoryInitializedKey(_ id: PeerId) -> ValueBoxKey {
        self.sharedPeerHistoryInitializedKey.setInt64(0, value: id.toInt64())
        self.sharedPeerHistoryInitializedKey.setInt8(8, value: MetadataPrefix.PeerHistoryInitialized.rawValue)
        return self.sharedPeerHistoryInitializedKey
    }
    
    private func peerThreadHoleIndexInitializedKey(peerId: PeerId, threadId: Int64) -> ValueBoxKey {
        self.sharedPeerThreadHoleIndexInitializedKey.setInt64(0, value: peerId.toInt64())
        self.sharedPeerThreadHoleIndexInitializedKey.setInt8(8, value: MetadataPrefix.PeerHistoryThreadHoleIndexInitialized.rawValue)
        self.sharedPeerThreadHoleIndexInitializedKey.setInt64(8 + 1, value: threadId)
        return self.sharedPeerThreadHoleIndexInitializedKey
    }
    
    private func peerHistoryInitializedTagKey(id: PeerId, tag: UInt32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 1 + 4)
        key.setInt64(0, value: id.toInt64())
        key.setInt8(8, value: MetadataPrefix.PeerHistoryTagInitialized.rawValue)
        key.setUInt32(8 + 1, value: tag)
        return key
    }
    
    private func groupFeedIndexInitializedKey(_ id: PeerGroupId) -> ValueBoxKey {
        self.sharedGroupFeedIndexInitializedKey.setInt32(0, value: id.rawValue)
        self.sharedGroupFeedIndexInitializedKey.setInt8(4, value: MetadataPrefix.GroupFeedIndexInitialized.rawValue)
        return self.sharedGroupFeedIndexInitializedKey
    }
    
    private func chatListGroupInitializedKey(_ key: InitializedChatListKey) -> ValueBoxKey {
        self.sharedChatListGroupHistoryInitializedKey.setInt32(0, value: key.groupId.rawValue)
        self.sharedChatListGroupHistoryInitializedKey.setInt8(4, value: MetadataPrefix.ChatListGroupInitialized.rawValue)
        return self.sharedChatListGroupHistoryInitializedKey
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
    
    private func totalUnreadCountStateKey(groupId: PeerGroupId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 1 + 4)
        key.setInt8(0, value: MetadataPrefix.TotalUnreadCountStates.rawValue)
        key.setInt32(1, value: groupId.rawValue)
        return key
    }
    
    private func totalUnreadCountLowerBound() -> ValueBoxKey {
        let key = ValueBoxKey(length: 1)
        key.setInt8(0, value: MetadataPrefix.TotalUnreadCountStates.rawValue)
        return key
    }
    
    private func totalUnreadCountUpperBound() -> ValueBoxKey {
        return self.totalUnreadCountLowerBound().successor
    }
    
    func setInitializedChatList(groupId: PeerGroupId) {
        switch groupId {
            case .root:
                self.valueBox.set(self.table, key: self.key(MetadataPrefix.ChatListInitialized), value: MemoryBuffer())
            case .group:
                self.valueBox.set(self.table, key: self.chatListGroupInitializedKey(InitializedChatListKey(groupId: groupId)), value: MemoryBuffer())
        }
        self.initializedChatList.insert(InitializedChatListKey(groupId: groupId))
    }
    
    func isInitializedChatList(groupId: PeerGroupId) -> Bool {
        let key = InitializedChatListKey(groupId: groupId)
        if self.initializedChatList.contains(key) {
            return true
        } else {
            switch groupId {
                case .root:
                    if self.valueBox.exists(self.table, key: self.key(MetadataPrefix.ChatListInitialized)) {
                        self.initializedChatList.insert(key)
                        return true
                    } else {
                        return false
                    }
                case .group:
                    if self.valueBox.exists(self.table, key: self.chatListGroupInitializedKey(key)) {
                        self.initializedChatList.insert(key)
                        return true
                    } else {
                        return false
                    }
            }
        }
    }
    
    func setShouldReindexUnreadCounts(value: Bool) {
        if value {
            self.valueBox.set(self.table, key: self.key(MetadataPrefix.ShouldReindexUnreadCounts), value: MemoryBuffer())
        } else {
            self.valueBox.remove(self.table, key: self.key(MetadataPrefix.ShouldReindexUnreadCounts), secure: false)
        }
    }
    
    func shouldReindexUnreadCounts() -> Bool {
        if self.valueBox.exists(self.table, key: self.key(MetadataPrefix.ShouldReindexUnreadCounts)) {
            return true
        } else {
            return false
        }
    }
    
    func setShouldReindexUnreadCountsState(value: Int32) {
        var value = value
        self.valueBox.set(self.table, key: self.key(MetadataPrefix.ShouldReindexUnreadCountsState), value: MemoryBuffer(memory: &value, capacity: 4, length: 4, freeWhenDone: false))
       }
    
    func getShouldReindexUnreadCountsState() -> Int32? {
        if let value = self.valueBox.get(self.table, key: self.key(MetadataPrefix.ShouldReindexUnreadCountsState)) {
            var version: Int32 = 0
            value.read(&version, offset: 0, length: 4)
            return version
        } else {
            return nil
        }
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
    
    func isThreadHoleIndexInitialized(peerId: PeerId, threadId: Int64) -> Bool {
        if self.valueBox.exists(self.table, key: self.peerThreadHoleIndexInitializedKey(peerId: peerId, threadId: threadId)) {
            return true
        } else {
            return false
        }
    }
    
    func setIsThreadHoleIndexInitialized(peerId: PeerId, threadId: Int64) {
        self.valueBox.set(self.table, key: self.peerThreadHoleIndexInitializedKey(peerId: peerId, threadId: threadId), value: MemoryBuffer())
    }
    
    func setPeerTagInitialized(peerId: PeerId, tag: MessageTags) {
        if self.initializedHistoryPeerIdTags[peerId] == nil {
            self.initializedHistoryPeerIdTags[peerId] = Set()
        }
        initializedHistoryPeerIdTags[peerId]!.insert(tag)
        self.sharedBuffer.reset()
        self.valueBox.set(self.table, key: self.peerHistoryInitializedTagKey(id: peerId, tag: tag.rawValue), value: self.sharedBuffer)
    }
    
    func isPeerTagInitialized(peerId: PeerId, tag: MessageTags) -> Bool {
        if let currentTags = self.initializedHistoryPeerIdTags[peerId], currentTags.contains(tag) {
            return true
        } else {
            if self.valueBox.exists(self.table, key: self.peerHistoryInitializedTagKey(id: peerId, tag: tag.rawValue)) {
                if self.initializedHistoryPeerIdTags[peerId] == nil {
                    self.initializedHistoryPeerIdTags[peerId] = Set()
                }
                initializedHistoryPeerIdTags[peerId]!.insert(tag)
                return true
            } else {
                return false
            }
        }
    }
    
    func setGroupFeedIndexInitialized(_ groupId: PeerGroupId) {
        self.initializedGroupFeedIndexIds.insert(groupId)
        self.sharedBuffer.reset()
        self.valueBox.set(self.table, key: self.groupFeedIndexInitializedKey(groupId), value: self.sharedBuffer)
    }
    
    func isGroupFeedIndexInitialized(_ groupId: PeerGroupId) -> Bool {
        if self.initializedGroupFeedIndexIds.contains(groupId) {
            return true
        } else {
            if self.valueBox.exists(self.table, key: self.groupFeedIndexInitializedKey(groupId)) {
                self.initializedGroupFeedIndexIds.insert(groupId)
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
    
    func getNextPeerOperationLogIndex() -> UInt32 {
        if let nextId = self.nextPeerOperationLogIndex {
            self.nextPeerOperationLogIndex = nextId + 1
            self.nextPeerOperationLogIndexUpdated = true
            return nextId
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(.NextPeerOperationLogIndex)) {
                var nextId: UInt32 = 0
                value.read(&nextId, offset: 0, length: 4)
                self.nextPeerOperationLogIndex = nextId + 1
                self.nextPeerOperationLogIndexUpdated = true
                return nextId
            } else {
                let nextId: UInt32 = 1
                self.nextPeerOperationLogIndex = nextId + 1
                self.nextPeerOperationLogIndexUpdated = true
                return nextId
            }
        }
    }
    
    func removeAllTotalUnreadStates() {
        var groupIds: [PeerGroupId] = []
        self.valueBox.range(self.table, start: self.totalUnreadCountLowerBound(), end: self.totalUnreadCountUpperBound(), keys: { key in
            let groupId = key.getInt32(1)
            groupIds.append(PeerGroupId(rawValue: groupId))
            return true
        }, limit: 0)
        for groupId in groupIds {
            self.setTotalUnreadState(groupId: groupId, state: ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:]))
        }
    }
    
    func getTotalUnreadState(groupId: PeerGroupId) -> ChatListTotalUnreadState {
        if let cached = self.chatListTotalUnreadStates[groupId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.totalUnreadCountStateKey(groupId: groupId)), let state = PostboxDecoder(buffer: value).decodeObjectForKey("_", decoder: { ChatListTotalUnreadState(decoder: $0) }) as? ChatListTotalUnreadState {
                self.chatListTotalUnreadStates[groupId] = state
                return state
            } else {
                let state = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
                self.chatListTotalUnreadStates[groupId] = state
                return state
            }
        }
    }
    
    func setTotalUnreadState(groupId: PeerGroupId, state: ChatListTotalUnreadState) {
        let current = self.getTotalUnreadState(groupId: groupId)
        if current != state {
            self.chatListTotalUnreadStates[groupId] = state
            self.updatedChatListTotalUnreadStates.insert(groupId)
        }
    }
    
    override func clearMemoryCache() {
        self.initializedChatList.removeAll()
        self.initializedHistoryPeerIds.removeAll()
        self.peerNextMessageIdByNamespace.removeAll()
        self.updatedPeerNextMessageIdByNamespace.removeAll()
        self.nextMessageStableId = nil
        self.nextMessageStableIdUpdated = false
        self.chatListTotalUnreadStates.removeAll()
        self.updatedChatListTotalUnreadStates.removeAll()
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
                    self.valueBox.remove(self.table, key: self.peerNextMessageIdByNamespaceKey(peerId, namespace: namespace), secure: false)
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
        
        if self.nextPeerOperationLogIndexUpdated {
            if let nextPeerOperationLogIndex = self.nextPeerOperationLogIndex {
                var nextId: UInt32 = nextPeerOperationLogIndex
                self.valueBox.set(self.table, key: self.key(.NextPeerOperationLogIndex), value: MemoryBuffer(memory: &nextId, capacity: 4, length: 4, freeWhenDone: false))
                self.nextPeerOperationLogIndexUpdated = false
            }
        }
        
        for groupId in self.updatedChatListTotalUnreadStates {
            if let state = self.chatListTotalUnreadStates[groupId] {
                let buffer = PostboxEncoder()
                buffer.encodeObject(state, forKey: "_")
                self.valueBox.set(self.table, key: self.totalUnreadCountStateKey(groupId: groupId), value: buffer.readBufferNoCopy())
            }
            self.updatedChatListTotalUnreadStates.removeAll()
        }
    }
}
