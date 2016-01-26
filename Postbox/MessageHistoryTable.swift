import Foundation

enum MessageHistoryEntry {
    case Msg(Message)
    case Hole(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
            case let .Msg(message):
                return MessageIndex(message)
            case let .Hole(hole):
                return hole.maxIndex
        }
    }
}

final class MessageHistoryTable {
    let valueBox: ValueBox
    let tableId: Int32
    
    let messageHistoryIndexTable: MessageHistoryIndexTable
    let messageMediaTable: MessageMediaTable
    
    init(valueBox: ValueBox, tableId: Int32, messageHistoryIndexTable: MessageHistoryIndexTable, messageMediaTable: MessageMediaTable) {
        self.valueBox = valueBox
        self.tableId = tableId
        self.messageHistoryIndexTable = messageHistoryIndexTable
        self.messageMediaTable = messageMediaTable
    }
    
    private func key(index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt32(8, value: index.timestamp)
        key.setInt32(8 + 4, value: index.id.namespace)
        key.setInt32(8 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key.successor
    }
    
    private func messagesByPeerId(messages: [StoreMessage]) -> [PeerId: [StoreMessage]] {
        var dict: [PeerId: [StoreMessage]] = [:]
        
        for message in messages {
            let peerId = message.id.peerId
            if dict[peerId] == nil {
                dict[peerId] = [message]
            } else {
                dict[peerId]!.append(message)
            }
        }
        
        return dict
    }
    
    func addMessages(messages: [StoreMessage]) {
        let sharedKey = self.key(MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0))
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = Encoder()
        
        let messagesByPeerId = self.messagesByPeerId(messages)
        for (_, peerMessages) in messagesByPeerId {
            for message in peerMessages {
                if self.messageHistoryIndexTable.messageExists(message.id) {
                    continue
                }
                
                self.messageHistoryIndexTable.addMessage(MessageIndex(message))
                self.justInsert(message, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder)
            }
        }
    }
    
    func removeMessages(messageIds: [MessageId]) {
        for messageId in messageIds {
            if let entry = self.messageHistoryIndexTable.get(messageId) {
                if case let .Message(index) = entry {
                    if let message = self.get(index) {
                        let embeddedMediaData = message.embeddedMediaData
                        if embeddedMediaData.length > 4 {
                            var embeddedMediaCount: Int32 = 0
                            embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                            for _ in 0 ..< embeddedMediaCount {
                                var mediaLength: Int32 = 0
                                embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                                if let media = Decoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                                    self.messageMediaTable.removeEmbeddedMedia(media)
                                }
                                embeddedMediaData.skip(Int(mediaLength))
                            }
                        }
                        
                        for mediaId in message.referencedMedia {
                            self.messageMediaTable.removeReference(mediaId)
                        }
                    }
                    
                    self.messageHistoryIndexTable.removeMessage(messageId)
                    self.valueBox.remove(self.tableId, key: self.key(index))
                }
            }
        }
    }
    
    private func justInsert(message: StoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: Encoder) {
        sharedBuffer.reset()

        let data = message.text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
        var length: Int32 = Int32(data.length)
        sharedBuffer.write(&length, offset: 0, length: 4)
        sharedBuffer.write(data.bytes, offset: 0, length: Int(length))

        var attributeCount: Int32 = Int32(message.attributes.count)
        sharedBuffer.write(&attributeCount, offset: 0, length: 4)
        for attribute in message.attributes {
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(attribute)
            let attributeBuffer = sharedEncoder.memoryBuffer()
            var attributeBufferLength = Int32(attributeBuffer.length)
            sharedBuffer.write(&attributeBufferLength, offset: 0, length: 4)
            sharedBuffer.write(attributeBuffer.memory, offset: 0, length: attributeBuffer.length)
        }
        
        var embeddedMedia: [Media] = []
        var referencedMedia: [MediaId] = []
        for media in message.media {
            if let mediaId = media.id {
                let mediaInsertResult = self.messageMediaTable.set(media, index: MessageIndex(message), messageHistoryTable: self)
                switch mediaInsertResult {
                    case let .Embed(media):
                        embeddedMedia.append(media)
                    case .Reference:
                        referencedMedia.append(mediaId)
                }
            } else {
                embeddedMedia.append(media)
            }
        }
        
        var embeddedMediaCount: Int32 = Int32(embeddedMedia.count)
        sharedBuffer.write(&embeddedMediaCount, offset: 0, length: 4)
        for media in embeddedMedia {
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(media)
            let mediaBuffer = sharedEncoder.memoryBuffer()
            var mediaBufferLength = Int32(mediaBuffer.length)
            sharedBuffer.write(&mediaBufferLength, offset: 0, length: 4)
            sharedBuffer.write(mediaBuffer.memory, offset: 0, length: mediaBuffer.length)
        }
        
        var referencedMediaCount: Int32 = Int32(referencedMedia.count)
        sharedBuffer.write(&referencedMediaCount, offset: 0, length: 4)
        for mediaId in referencedMedia {
            var idNamespace: Int32 = mediaId.namespace
            var idId: Int64 = mediaId.id
            sharedBuffer.write(&idNamespace, offset: 0, length: 4)
            sharedBuffer.write(&idId, offset: 0, length: 8)
        }
        
        self.valueBox.set(self.tableId, key: self.key(MessageIndex(message), key: sharedKey), value: sharedBuffer)
    }
    
    func unembedMedia(index: MessageIndex, id: MediaId) -> Media? {
        if let message = self.get(index) where message.embeddedMediaData.length > 4 {
            var embeddedMediaCount: Int32 = 0
            message.embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
            
            let updatedEmbeddedMediaBuffer = WriteBuffer()
            var updatedEmbeddedMediaCount = embeddedMediaCount - 1
            updatedEmbeddedMediaBuffer.write(&updatedEmbeddedMediaCount, offset: 0, length: 4)
            
            var extractedMedia: Media?
            
            for _ in 0 ..< embeddedMediaCount {
                let mediaOffset = message.embeddedMediaData.offset
                var mediaLength: Int32 = 0
                var copyMedia = true
                message.embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                if let media = Decoder(buffer: MemoryBuffer(memory: message.embeddedMediaData.memory + message.embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    
                    if let mediaId = media.id where mediaId == id {
                        copyMedia = false
                        extractedMedia = media
                    }
                }
                
                if copyMedia {
                    updatedEmbeddedMediaBuffer.write(message.embeddedMediaData.memory + mediaOffset, offset: 0, length: message.embeddedMediaData.offset - mediaOffset)
                }
            }
            
            if let extractedMedia = extractedMedia {
                var updatedReferencedMedia = message.referencedMedia
                updatedReferencedMedia.append(extractedMedia.id!)
                self.storeIntermediateMessage(IntermediateMessage(id: message.id, timestamp: message.timestamp, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: updatedReferencedMedia), sharedKey: self.key(index))
                
                return extractedMedia
            }
        }
        return nil
    }
    
    func storeIntermediateMessage(message: IntermediateMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        
        let data = message.text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
        var length: Int32 = Int32(data.length)
        sharedBuffer.write(&length, offset: 0, length: 4)
        sharedBuffer.write(data.bytes, offset: 0, length: Int(length))
        
        sharedBuffer.write(message.attributesData.memory, offset: 0, length: message.attributesData.length)
        sharedBuffer.write(message.embeddedMediaData.memory, offset: 0, length: message.embeddedMediaData.length)
        
        var referencedMediaCount: Int32 = Int32(message.referencedMedia.count)
        sharedBuffer.write(&referencedMediaCount, offset: 0, length: 4)
        for mediaId in message.referencedMedia {
            var idNamespace: Int32 = mediaId.namespace
            var idId: Int64 = mediaId.id
            sharedBuffer.write(&idNamespace, offset: 0, length: 4)
            sharedBuffer.write(&idId, offset: 0, length: 8)
        }
        
        self.valueBox.set(self.tableId, key: self.key(MessageIndex(id: message.id, timestamp: message.timestamp), key: sharedKey), value: sharedBuffer)
    }
    
    private func readIntermediateMessage(key: ValueBoxKey, value: ReadBuffer) -> IntermediateMessage {
        let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
        
        var textLength: Int32 = 0
        value.read(&textLength, offset: 0, length: 4)
        let text = String(data: NSData(bytes: value.memory + value.offset, length: Int(textLength)), encoding: NSUTF8StringEncoding) ?? ""
        value.skip(Int(textLength))
        
        let attributesOffset = value.offset
        var attributeCount: Int32 = 0
        value.read(&attributeCount, offset: 0, length: 4)
        for _ in 0 ..< attributeCount {
            var attributeLength: Int32 = 0
            value.read(&attributeLength, offset: 0, length: 4)
            value.skip(Int(attributeLength))
        }
        let attributesLength = value.offset - attributesOffset
        let attributesBytes = malloc(attributesLength)
        memcpy(attributesBytes, value.memory + attributesOffset, attributesLength)
        let attributesData = ReadBuffer(memory: attributesBytes, length: attributesLength, freeWhenDone: true)
        
        let embeddedMediaOffset = value.offset
        var embeddedMediaCount: Int32 = 0
        value.read(&embeddedMediaCount, offset: 0, length: 4)
        for _ in 0 ..< embeddedMediaCount {
            var mediaLength: Int32 = 0
            value.read(&mediaLength, offset: 0, length: 4)
            value.skip(Int(mediaLength))
        }
        let embeddedMediaLength = value.offset - embeddedMediaOffset
        let embeddedMediaBytes = malloc(embeddedMediaLength)
        memcpy(embeddedMediaBytes, value.memory + embeddedMediaOffset, embeddedMediaLength)
        let embeddedMediaData = ReadBuffer(memory: embeddedMediaBytes, length: embeddedMediaLength, freeWhenDone: true)
        
        var referencedMediaIds: [MediaId] = []
        var referencedMediaIdsCount: Int32 = 0
        value.read(&referencedMediaIdsCount, offset: 0, length: 4)
        for _ in 0 ..< referencedMediaIdsCount {
            var idNamespace: Int32 = 0
            var idId: Int64 = 0
            value.read(&idNamespace, offset: 0, length: 4)
            value.read(&idId, offset: 0, length: 8)
            referencedMediaIds.append(MediaId(namespace: idNamespace, id: idId))
        }
        
        return IntermediateMessage(id: index.id, timestamp: index.timestamp, text: text, attributesData: attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: referencedMediaIds)
    }
    
    func get(index: MessageIndex) -> IntermediateMessage? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.tableId, key: key) {
            return self.readIntermediateMessage(key, value: value)
        }
        return nil
    }
    
    func renderMessage(message: IntermediateMessage) -> Message {
        var parsedAttributes: [Coding] = []
        var parsedMedia: [Media] = []
        
        let attributesData = message.attributesData
        if attributesData.length > 4 {
            var attributeCount: Int32 = 0
            attributesData.read(&attributeCount, offset: 0, length: 4)
            for _ in 0 ..< attributeCount {
                var attributeLength: Int32 = 0
                attributesData.read(&attributeLength, offset: 0, length: 4)
                if let attribute = Decoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() {
                    parsedAttributes.append(attribute)
                }
                attributesData.skip(Int(attributeLength))
            }
        }
        
        let embeddedMediaData = message.embeddedMediaData
        if embeddedMediaData.length > 4 {
            var embeddedMediaCount: Int32 = 0
            embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
            for _ in 0 ..< embeddedMediaCount {
                var mediaLength: Int32 = 0
                embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                if let media = Decoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    parsedMedia.append(media)
                }
                embeddedMediaData.skip(Int(mediaLength))
            }
        }
        
        for mediaId in message.referencedMedia {
            if let media = self.messageMediaTable.get(mediaId) {
                parsedMedia.append(media)
            }
        }
        
        return Message(id: message.id, timestamp: message.timestamp, text: message.text, attributes: parsedAttributes, media: parsedMedia)
    }
    
    func messagesAround(index: MessageIndex, count: Int) -> [IntermediateMessage] {
        var lowerMessages: [IntermediateMessage] = []
        var upperMessages: [IntermediateMessage] = []
        
        self.valueBox.range(self.tableId, start: self.key(index), end: self.lowerBound(index.id.peerId), values: { key, value in
            lowerMessages.append(self.readIntermediateMessage(key, value: value))
            return true
        }, limit: count)
        
        self.valueBox.range(self.tableId, start: self.key(index).predecessor, end: self.upperBound(index.id.peerId), values: { key, value in
            upperMessages.append(self.readIntermediateMessage(key, value: value))
            return true
        }, limit: count)
        
        var messages: [IntermediateMessage] = []
        for message in lowerMessages.reverse() {
            messages.append(message)
        }
        messages.appendContentsOf(upperMessages)
        
        return messages
    }
    
    func debugList(peerId: PeerId) -> [Message] {
        return self.messagesAround(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0), count: 1000).map({self.renderMessage($0)})
    }
}
