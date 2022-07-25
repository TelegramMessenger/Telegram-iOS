import Foundation

private enum MediaEntryType: Int8 {
    case Direct
    case MessageReference
}

enum InsertMediaResult {
    case Reference
    case Embed(Media)
}

enum RemoveMediaResult {
    case Reference
    case Embedded(MessageIndex)
}

enum DebugMediaEntry {
    case Direct(Media, Int)
    case MessageReference(MessageIndex)
}

final class MessageMediaTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }

    func key(_ id: MediaId, key: ValueBoxKey = ValueBoxKey(length: 4 + 8)) -> ValueBoxKey {
        key.setInt32(0, value: id.namespace)
        key.setInt64(4, value: id.id)
        return key
    }
    
    func exists(id: MediaId) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(id))
    }
    
    func get(_ id: MediaId, embedded: (MessageIndex, MediaId) -> Media?) -> (MessageIndex?, Media)? {
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            var type: Int8 = 0
            value.read(&type, offset: 0, length: 1)
            if type == MediaEntryType.Direct.rawValue {
                var dataLength: Int32 = 0
                value.read(&dataLength, offset: 0, length: 4)
                if let media = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory + value.offset, capacity: Int(dataLength), length: Int(dataLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    return (nil, media)
                }
            } else if type == MediaEntryType.MessageReference.rawValue {
                var idPeerId: Int64 = 0
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                var idTimestamp: Int32 = 0
                value.read(&idPeerId, offset: 0, length: 8)
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                value.read(&idTimestamp, offset: 0, length: 4)
                
                let referencedMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                
                if let result = embedded(referencedMessageIndex, id) {
                    return (referencedMessageIndex, result)
                } else {
                    return nil
                }
            }
        }
        return nil
    }
    
    func set(_ media: Media, index: MessageIndex?, messageHistoryTable: MessageHistoryTable, sharedWriteBuffer: WriteBuffer = WriteBuffer(), sharedEncoder: PostboxEncoder = PostboxEncoder()) -> InsertMediaResult {
        if let id = media.id {
            if let value = self.valueBox.get(self.table, key: self.key(id)) {
                var type: Int8 = 0
                value.read(&type, offset: 0, length: 1)
                if type == MediaEntryType.Direct.rawValue {
                    var dataLength: Int32 = 0
                    value.read(&dataLength, offset: 0, length: 4)
                    value.skip(Int(dataLength))
                    
                    sharedWriteBuffer.reset()
                    sharedWriteBuffer.write(value.memory, offset: 0, length: value.offset)
                    
                    var messageReferenceCount: Int32 = 0
                    value.read(&messageReferenceCount, offset: 0, length: 4)
                    messageReferenceCount += 1
                    sharedWriteBuffer.write(&messageReferenceCount, offset: 0, length: 4)
                    
                    withExtendedLifetime(sharedWriteBuffer, {
                        self.valueBox.set(self.table, key: self.key(id), value: sharedWriteBuffer.readBufferNoCopy())
                    })
                    
                    return .Reference
                } else if type == MediaEntryType.MessageReference.rawValue {
                    var idPeerId: Int64 = 0
                    var idNamespace: Int32 = 0
                    var idId: Int32 = 0
                    var idTimestamp: Int32 = 0
                    value.read(&idPeerId, offset: 0, length: 8)
                    value.read(&idNamespace, offset: 0, length: 4)
                    value.read(&idId, offset: 0, length: 4)
                    value.read(&idTimestamp, offset: 0, length: 4)
                    
                    let referencedMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                    if referencedMessageIndex == index {
                        return .Embed(media)
                    }
                    
                    if let media = messageHistoryTable.unembedMedia(referencedMessageIndex, id: id) {
                        sharedWriteBuffer.reset()
                        var directType: Int8 = MediaEntryType.Direct.rawValue
                        sharedWriteBuffer.write(&directType, offset: 0, length: 1)
                        
                        sharedEncoder.reset()
                        sharedEncoder.encodeRootObject(media)
                        let mediaBuffer = sharedEncoder.memoryBuffer()
                        var mediaBufferLength = Int32(mediaBuffer.length)
                        sharedWriteBuffer.write(&mediaBufferLength, offset: 0, length: 4)
                        sharedWriteBuffer.write(mediaBuffer.memory, offset: 0, length: mediaBuffer.length)
                        
                        var messageReferenceCount: Int32 = 2
                        sharedWriteBuffer.write(&messageReferenceCount, offset: 0, length: 4)
                        
                        withExtendedLifetime(sharedWriteBuffer, {
                            self.valueBox.set(self.table, key: self.key(id), value: sharedWriteBuffer.readBufferNoCopy())
                        })
                    }
                    
                    return .Reference
                } else {
                    return .Embed(media)
                }
            } else {
                if let index = index {
                    sharedWriteBuffer.reset()
                    var type: Int8 = MediaEntryType.MessageReference.rawValue
                    sharedWriteBuffer.write(&type, offset: 0, length: 1)
                    var idPeerId: Int64 = index.id.peerId.toInt64()
                    var idNamespace: Int32 = index.id.namespace
                    var idId: Int32 = index.id.id
                    var idTimestamp: Int32 = index.timestamp
                    sharedWriteBuffer.write(&idPeerId, offset: 0, length: 8)
                    sharedWriteBuffer.write(&idNamespace, offset: 0, length: 4)
                    sharedWriteBuffer.write(&idId, offset: 0, length: 4)
                    sharedWriteBuffer.write(&idTimestamp, offset: 0, length: 4)
                    
                    withExtendedLifetime(sharedWriteBuffer, {
                        self.valueBox.set(self.table, key: self.key(id), value: sharedWriteBuffer.readBufferNoCopy())
                    })
                    
                    return .Embed(media)
                } else {
                    sharedWriteBuffer.reset()
                    var directType: Int8 = MediaEntryType.Direct.rawValue
                    sharedWriteBuffer.write(&directType, offset: 0, length: 1)
                    
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(media)
                    let mediaBuffer = sharedEncoder.memoryBuffer()
                    var mediaBufferLength = Int32(mediaBuffer.length)
                    sharedWriteBuffer.write(&mediaBufferLength, offset: 0, length: 4)
                    sharedWriteBuffer.write(mediaBuffer.memory, offset: 0, length: mediaBuffer.length)
                    
                    var messageReferenceCount: Int32 = 2
                    sharedWriteBuffer.write(&messageReferenceCount, offset: 0, length: 4)
                    
                    withExtendedLifetime(sharedWriteBuffer, {
                        self.valueBox.set(self.table, key: self.key(id), value: sharedWriteBuffer.readBufferNoCopy())
                    })
                    
                    return .Reference
                }
            }
        } else {
            return .Embed(media)
        }
    }
    
    func removeReference(_ id: MediaId, sharedWriteBuffer: WriteBuffer = WriteBuffer()) -> RemoveMediaResult {
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            var type: Int8 = 0
            value.read(&type, offset: 0, length: 1)
            if type == MediaEntryType.Direct.rawValue {
                var dataLength: Int32 = 0
                value.read(&dataLength, offset: 0, length: 4)
                value.skip(Int(dataLength))
                
                sharedWriteBuffer.reset()
                sharedWriteBuffer.write(value.memory, offset: 0, length: value.offset)
                
                var messageReferenceCount: Int32 = 0
                value.read(&messageReferenceCount, offset: 0, length: 4)
                messageReferenceCount -= 1
                sharedWriteBuffer.write(&messageReferenceCount, offset: 0, length: 4)
                
                if messageReferenceCount <= 0 {
                    self.valueBox.remove(self.table, key: self.key(id), secure: false)
                } else {
                    withExtendedLifetime(sharedWriteBuffer, {
                        self.valueBox.set(self.table, key: self.key(id), value: sharedWriteBuffer.readBufferNoCopy())
                    })
                }
                
                return .Reference
            } else if type == MediaEntryType.MessageReference.rawValue {
                var idPeerId: Int64 = 0
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                var idTimestamp: Int32 = 0
                value.read(&idPeerId, offset: 0, length: 8)
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                value.read(&idTimestamp, offset: 0, length: 4)
                
                let referencedMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                
                self.valueBox.remove(self.table, key: self.key(id), secure: false)
                
                return .Embedded(referencedMessageIndex)
            } else {
                assertionFailure()
            }
        }
        return .Reference
    }
    
    func removeEmbeddedMedia(_ media: Media) {
        if let id = media.id {
            self.valueBox.remove(self.table, key: self.key(id), secure: false)
        }
    }
    
    func update(_ id: MediaId, media: Media, messageHistoryTable: MessageHistoryTable, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], sharedWriteBuffer: WriteBuffer = WriteBuffer(), sharedEncoder: PostboxEncoder = PostboxEncoder())  {
        if let updatedId = media.id {
            if let value = self.valueBox.get(self.table, key: self.key(id)) {
                var type: Int8 = 0
                value.read(&type, offset: 0, length: 1)
                if type == MediaEntryType.Direct.rawValue {
                    var dataLength: Int32 = 0
                    value.read(&dataLength, offset: 0, length: 4)
                    value.skip(Int(dataLength))
                    
                    var messageReferenceCount: Int32 = 0
                    value.read(&messageReferenceCount, offset: 0, length: 4)
                    
                    sharedWriteBuffer.reset()
                    var directType: Int8 = MediaEntryType.Direct.rawValue
                    sharedWriteBuffer.write(&directType, offset: 0, length: 1)
                    
                    sharedEncoder.reset()
                    sharedEncoder.encodeRootObject(media)
                    let mediaBuffer = sharedEncoder.memoryBuffer()
                    var mediaBufferLength = Int32(mediaBuffer.length)
                    sharedWriteBuffer.write(&mediaBufferLength, offset: 0, length: 4)
                    sharedWriteBuffer.write(mediaBuffer.memory, offset: 0, length: mediaBuffer.length)
                    
                    sharedWriteBuffer.write(&messageReferenceCount, offset: 0, length: 4)
                    
                    if id != updatedId {
                        self.valueBox.remove(self.table, key: self.key(id), secure: false)
                    }
                    withExtendedLifetime(sharedWriteBuffer, {
                        self.valueBox.set(self.table, key: self.key(updatedId), value: sharedWriteBuffer.readBufferNoCopy())
                    })
                } else if type == MediaEntryType.MessageReference.rawValue {
                    var idPeerId: Int64 = 0
                    var idNamespace: Int32 = 0
                    var idId: Int32 = 0
                    var idTimestamp: Int32 = 0
                    value.read(&idPeerId, offset: 0, length: 8)
                    value.read(&idNamespace, offset: 0, length: 4)
                    value.read(&idId, offset: 0, length: 4)
                    value.read(&idTimestamp, offset: 0, length: 4)
                    
                    let referencedMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                    messageHistoryTable.updateEmbeddedMedia(referencedMessageIndex, mediaId: id, media: media, operationsByPeerId: &operationsByPeerId)
                }
            }
        }
    }
    
    func debugList() -> [DebugMediaEntry] {
        var entries: [DebugMediaEntry] = []
        
        let upperBoundKey = ValueBoxKey(length: 8 + 4)
        memset(upperBoundKey.memory, 0xff, 8 + 4)
        self.valueBox.range(self.table, start: ValueBoxKey(length: 0), end: upperBoundKey, values: { key, value in
            var type: Int8 = 0
            value.read(&type, offset: 0, length: 1)
            if type == MediaEntryType.Direct.rawValue {
                var dataLength: Int32 = 0
                value.read(&dataLength, offset: 0, length: 4)
                if let media = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory + value.offset, capacity: Int(dataLength), length: Int(dataLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    
                    value.skip(Int(dataLength))
                    
                    var messageReferenceCount: Int32 = 0
                    value.read(&messageReferenceCount, offset: 0, length: 4)
                    
                    entries.append(.Direct(media, Int(messageReferenceCount)))
                }
            } else if type == MediaEntryType.MessageReference.rawValue {
                var idPeerId: Int64 = 0
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                var idTimestamp: Int32 = 0
                value.read(&idPeerId, offset: 0, length: 8)
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                value.read(&idTimestamp, offset: 0, length: 4)
                
                let referencedMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(idPeerId), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                
                entries.append(.MessageReference(referencedMessageIndex))
            }
            
            return true
        }, limit: 1000)
        
        return entries
    }
}
