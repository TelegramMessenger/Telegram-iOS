import Foundation

struct Table_Meta {
    static let id: Int32 = 0
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4)
    }
    
    static func key(key: ValueBoxKey = Table_Meta.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: 0)
        return key
    }
}

struct Table_State {
    static let id: Int32 = 1
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4)
    }
    
    static func key(key: ValueBoxKey = Table_State.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: 0)
        return key
    }
}

struct Table_Keychain {
    static let id: Int32 = 2
    
    static func key(string: String) -> ValueBoxKey {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding) ?? NSData()
        let key = ValueBoxKey(length: data.length)
        memcpy(key.memory, data.bytes, data.length)
        return key
    }
}

struct Table_Message {
    static let id: Int32 = 4
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 8 + 4 + 4)
    }
    
    static func lowerBoundKey(peerId: PeerId, namespace: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    static func upperBoundKey(peerId: PeerId, namespace: Int32) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key.successor
    }
    
    static func key(messageId: MessageId, key: ValueBoxKey = Table_Message.emptyKey()) -> ValueBoxKey {
        key.setInt64(0, value: messageId.peerId.toInt64())
        key.setInt32(8, value: messageId.namespace)
        key.setInt32(8 + 4, value: messageId.id)
        return key
    }
    
    static func set(message: Message, encoder: Encoder = Encoder()) -> MemoryBuffer {
        encoder.reset()
        encoder.encodeRootObject(message)
        return encoder.memoryBuffer()
    }
    
    static func get(value: ReadBuffer) -> Message? {
        if let message = Decoder(buffer: value).decodeRootObject() as? Message {
            return message
        }
        return nil
    }
}

struct Table_AbsoluteMessageId {
    static let id: Int32 = 5
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4)
    }
    
    static func key(id: Int32, key: ValueBoxKey = Table_AbsoluteMessageId.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: id)
        return key
    }
    
    static func set(messageId: MessageId) -> MemoryBuffer {
        let buffer = WriteBuffer()
        
        var peerId: Int64 = messageId.peerId.toInt64()
        buffer.write(&peerId, offset: 0, length: 8)
        var id_namespace: Int32 = messageId.namespace
        buffer.write(&id_namespace, offset: 0, length: 4)
        
        return buffer
    }
    
    static func get(id: Int32, value: ReadBuffer) -> MessageId {
        let offset = value.offset
        
        var peerId: Int64 = 0
        var id_namespace: Int32 = 0
        value.read(&peerId, offset: 0, length: 8)
        value.read(&id_namespace, offset: 0, length: 4)
        value.offset = offset
        
        return MessageId(peerId: PeerId(peerId), namespace: id_namespace, id: id)
    }
}

struct Table_Media {
    static let id: Int32 = 6
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4 + 8)
    }
    
    static func key(id: MediaId, key: ValueBoxKey = Table_Media.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
    
    static func set(media: Media, encoder: Encoder = Encoder()) -> MemoryBuffer {
        encoder.reset()
        encoder.encodeRootObject(media)
        return encoder.memoryBuffer()
    }
    
    static func get(value: ReadBuffer) -> Media? {
        let decoder = Decoder(buffer: value)
        if let media = decoder.decodeRootObject() as? Media {
            return media
        }
        
        return nil
    }
}

struct Table_Media_MessageIds {
    static let id: Int32 = 3
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4 + 8 + 8 + 4 + 4)
    }
    
    static func key(id: MediaId, messageId: MessageId, key: ValueBoxKey = Table_Media_MessageIds.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        key.setInt64(4 + 8, value: messageId.peerId.toInt64())
        key.setInt32(4 + 8 + 8, value: messageId.namespace)
        key.setInt32(4 + 8 + 8 + 4, value: messageId.id)
        return key
    }
    
    static func lowerBoundKey(id: MediaId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
    
    static func upperBoundKey(id: MediaId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 8)
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key.successor
    }
    
    static func getMessageId(key: ValueBoxKey) -> MessageId {
        let peerId = key.getInt64(4 + 8)
        let messageId_namespace: Int32 = key.getInt32(4 + 8 + 8)
        let messageId_id: Int32 = key.getInt32(4 + 8 + 8 + 4)
        return MessageId(peerId: PeerId(peerId), namespace: messageId_namespace, id: messageId_id)
    }
}

struct Table_Peer {
    static let id: Int32 = 7
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4 + 4)
    }
    
    static func key(id: PeerId, key: ValueBoxKey = Table_Peer.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: id.namespace)
        key.setInt32(4, value: id.id)
        return key
    }
}

struct Table_PeerEntry_Sorted {
    static let id: Int32 = 8
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 4 + 4 + 4 + 8)
    }
    
    static func lowerBoundKey() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: 0)
        return key
    }
    
    static func upperBoundKey() -> ValueBoxKey {
        let key = ValueBoxKey(length: 4)
        key.setInt32(0, value: Int32.max)
        return key
    }
    
    static func key(index: PeerViewEntryIndex, key: ValueBoxKey = Table_PeerEntry_Sorted.emptyKey()) -> ValueBoxKey {
        key.setInt32(0, value: index.messageIndex.timestamp)
        key.setInt32(4, value: index.messageIndex.id.namespace)
        key.setInt32(4 + 4, value: index.messageIndex.id.id)
        key.setInt64(4 + 4 + 4, value: index.peerId.toInt64())
        return key
    }
    
    static func get(key: ValueBoxKey) -> PeerViewEntryIndex {
        let messageIndex_timestamp = key.getInt32(0)
        let messageIndex_id_namespace = key.getInt32(4)
        let messageIndex_id_id = key.getInt32(4 + 4)
        let messageIndex_peerId = key.getInt64(4 + 4 + 4)
        return PeerViewEntryIndex(peerId: PeerId(messageIndex_peerId), messageIndex: MessageIndex(id: MessageId(peerId: PeerId(messageIndex_peerId), namespace: messageIndex_id_namespace, id: messageIndex_id_id), timestamp: messageIndex_timestamp))
    }
}

struct Table_PeerEntry {
    static let id: Int32 = 9
    
    static func emptyKey() -> ValueBoxKey {
        return ValueBoxKey(length: 8)
    }
    
    static func key(peerId: PeerId, key: ValueBoxKey = Table_PeerEntry.emptyKey()) -> ValueBoxKey {
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    static func set(index: PeerViewEntryIndex) -> MemoryBuffer {
        let buffer = WriteBuffer()

        var messageId_namespace: Int32 = index.messageIndex.id.namespace
        var messageId_id: Int32 = index.messageIndex.id.id
        var timestamp: Int32 = index.messageIndex.timestamp
        buffer.write(&messageId_namespace, offset: 0, length: 4)
        buffer.write(&messageId_id, offset: 0, length: 4)
        buffer.write(&timestamp, offset: 0, length: 4)
        
        return buffer
    }
    
    static func get(peerId: PeerId, value: ReadBuffer) -> PeerViewEntryIndex {
        let offset = value.offset
        
        var messageId_namespace: Int32 = 0
        var messageId_id: Int32 = 0
        var timestamp: Int32 = 0
        value.read(&messageId_namespace, offset: 0, length: 4)
        value.read(&messageId_id, offset: 0, length: 4)
        value.read(&timestamp, offset: 0, length: 4)
        let index = PeerViewEntryIndex(peerId: peerId, messageIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: messageId_namespace, id: messageId_id), timestamp: timestamp))
        value.offset = offset
        
        return index
    }
}
