import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case InsertHole(MessageHistoryHole)
    case Remove([MessageIndex])
}

enum IntermediateMessageHistoryEntry {
    case Message(IntermediateMessage)
    case Hole(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
            case let .Message(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .Hole(hole):
                return hole.maxIndex
        }
    }
}

enum RenderedMessageHistoryEntry {
    case RenderedMessage(Message)
    case Hole(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
        case let .RenderedMessage(message):
            return MessageIndex(id: message.id, timestamp: message.timestamp)
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
    
    private func messagesGroupedByPeerId(messages: [StoreMessage]) -> [PeerId: [StoreMessage]] {
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
    
    private func messageIdsByPeerId(ids: [MessageId]) -> [PeerId: [MessageId]] {
        var dict: [PeerId: [MessageId]] = [:]
        
        for id in ids {
            let peerId = id.peerId
            if dict[peerId] == nil {
                dict[peerId] = [id]
            } else {
                dict[peerId]!.append(id)
            }
        }
        
        return dict
    }
    
    private func processIndexOperations(peerId: PeerId, operations: [MessageHistoryIndexOperation], inout processedOperationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        let sharedKey = self.key(MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0))
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = Encoder()
        
        var outputOperations: [MessageHistoryOperation] = []
        var accumulatedRemoveIndices: [MessageIndex] = []
        for operation in operations {
            switch operation {
            case let .InsertHole(hole):
                if accumulatedRemoveIndices.count != 0 {
                    outputOperations.append(.Remove(accumulatedRemoveIndices))
                    accumulatedRemoveIndices.removeAll()
                }
                self.justInsertHole(hole)
                outputOperations.append(.InsertHole(hole))
            case let .InsertMessage(storeMessage):
                if accumulatedRemoveIndices.count != 0 {
                    outputOperations.append(.Remove(accumulatedRemoveIndices))
                    accumulatedRemoveIndices.removeAll()
                }
                let message = self.justInsertMessage(storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder)
                outputOperations.append(.InsertMessage(message))
            case let .Remove(index):
                self.justRemove(index)
                accumulatedRemoveIndices.append(index)
            }
        }
        if accumulatedRemoveIndices.count != 0 {
            outputOperations.append(.Remove(accumulatedRemoveIndices))
        }
        
        if processedOperationsByPeerId[peerId] == nil {
            processedOperationsByPeerId[peerId] = outputOperations
        } else {
            processedOperationsByPeerId[peerId]!.appendContentsOf(outputOperations)
        }
    }
    
    func addMessages(messages: [StoreMessage], location: AddMessagesLocation, inout operationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        let messagesByPeerId = self.messagesGroupedByPeerId(messages)
        for (peerId, peerMessages) in messagesByPeerId {
            var operations: [MessageHistoryIndexOperation] = []
            self.messageHistoryIndexTable.addMessages(peerMessages, location: location, operations: &operations)
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId)
        }
    }
    
    func addHoles(messageIds: [MessageId], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            for id in messageIds {
                self.messageHistoryIndexTable.addHole(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId)
        }
    }
    
    func removeMessages(messageIds: [MessageId], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            for id in messageIds {
                self.messageHistoryIndexTable.removeMessage(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId)
        }
    }
    
    func fillHole(id: MessageId, fillType: HoleFillType, messages: [StoreMessage], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.fillHole(id, fillType: fillType, messages: messages, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId)
    }
    
    func topMessage(peerId: PeerId) -> IntermediateMessage? {
        var currentKey = self.lowerBound(peerId)
        while true {
            var entry: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.tableId, start: self.upperBound(peerId), end: currentKey, values: { key, value in
                entry = self.readIntermediateEntry(key, value: value)
                return true
            }, limit: 1)
            
            if let entry = entry {
                switch entry {
                    case .Hole:
                        currentKey = self.key(entry.index).predecessor
                    case let .Message(message):
                        return message
                }
            } else {
                break
            }
        }
        return nil
    }
    
    private func justInsertMessage(message: StoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: Encoder) -> IntermediateMessage {
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)
        
        if let authorId = message.authorId {
            var varAuthorId: Int64 = authorId.toInt64()
            var hasAuthor: Int8 = 1
            sharedBuffer.write(&hasAuthor, offset: 0, length: 1)
            sharedBuffer.write(&varAuthorId, offset: 0, length: 8)
        } else {
            var hasAuthor: Int8 = 0
            sharedBuffer.write(&hasAuthor, offset: 0, length: 1)
        }

        let data = message.text.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
        var length: Int32 = Int32(data.length)
        sharedBuffer.write(&length, offset: 0, length: 4)
        sharedBuffer.write(data.bytes, offset: 0, length: Int(length))

        let attributesBuffer = WriteBuffer()
        
        var attributeCount: Int32 = Int32(message.attributes.count)
        attributesBuffer.write(&attributeCount, offset: 0, length: 4)
        for attribute in message.attributes {
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(attribute)
            let attributeBuffer = sharedEncoder.memoryBuffer()
            var attributeBufferLength = Int32(attributeBuffer.length)
            attributesBuffer.write(&attributeBufferLength, offset: 0, length: 4)
            attributesBuffer.write(attributeBuffer.memory, offset: 0, length: attributeBuffer.length)
        }
        
        sharedBuffer.write(attributesBuffer.memory, offset: 0, length: attributesBuffer.length)
        
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
        
        let embeddedMediaBuffer = WriteBuffer()
        var embeddedMediaCount: Int32 = Int32(embeddedMedia.count)
        embeddedMediaBuffer.write(&embeddedMediaCount, offset: 0, length: 4)
        for media in embeddedMedia {
            sharedEncoder.reset()
            sharedEncoder.encodeRootObject(media)
            let mediaBuffer = sharedEncoder.memoryBuffer()
            var mediaBufferLength = Int32(mediaBuffer.length)
            embeddedMediaBuffer.write(&mediaBufferLength, offset: 0, length: 4)
            embeddedMediaBuffer.write(mediaBuffer.memory, offset: 0, length: mediaBuffer.length)
        }
        
        sharedBuffer.write(embeddedMediaBuffer.memory, offset: 0, length: embeddedMediaBuffer.length)
        
        var referencedMediaCount: Int32 = Int32(referencedMedia.count)
        sharedBuffer.write(&referencedMediaCount, offset: 0, length: 4)
        for mediaId in referencedMedia {
            var idNamespace: Int32 = mediaId.namespace
            var idId: Int64 = mediaId.id
            sharedBuffer.write(&idNamespace, offset: 0, length: 4)
            sharedBuffer.write(&idId, offset: 0, length: 8)
        }
        
        self.valueBox.set(self.tableId, key: self.key(MessageIndex(message), key: sharedKey), value: sharedBuffer)
        
        return IntermediateMessage(id: message.id, timestamp: message.timestamp, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia)
    }
    
    private func justInsertHole(hole: MessageHistoryHole, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        var type: Int8 = 1
        sharedBuffer.write(&type, offset: 0, length: 1)
        var minId: Int32 = hole.min
        sharedBuffer.write(&minId, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.maxIndex), value: sharedBuffer.readBufferNoCopy())
    }
    
    private func justRemove(index: MessageIndex) {
        let key = self.key(index)
        if let value = self.valueBox.get(self.tableId, key: key) {
            switch self.readIntermediateEntry(key, value: value) {
                case let .Message(message):
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
                case .Hole:
                    break
            }
            
            self.valueBox.remove(self.tableId, key: key)
        }
    }
    
    func unembedMedia(index: MessageIndex, id: MediaId) -> Media? {
        if let message = self.getMessage(index) where message.embeddedMediaData.length > 4 {
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
                self.storeIntermediateMessage(IntermediateMessage(id: message.id, timestamp: message.timestamp, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: updatedReferencedMedia), sharedKey: self.key(index))
                
                return extractedMedia
            }
        }
        return nil
    }
    
    func storeIntermediateMessage(message: IntermediateMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)

        if let authorId = message.authorId {
            var varAuthorId: Int64 = authorId.toInt64()
            var hasAuthor: Int8 = 1
            sharedBuffer.write(&hasAuthor, offset: 0, length: 1)
            sharedBuffer.write(&varAuthorId, offset: 0, length: 8)
        } else {
            var hasAuthor: Int8 = 0
            sharedBuffer.write(&hasAuthor, offset: 0, length: 1)
        }
        
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
    
    private func readIntermediateEntry(key: ValueBoxKey, value: ReadBuffer) -> IntermediateMessageHistoryEntry {
        let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
        
        var type: Int8 = 0
        value.read(&type, offset: 0, length: 1)
        if type == 0 {
            var hasAuthor: Int8 = 0
            value.read(&hasAuthor, offset: 0, length: 1)
            var authorId: PeerId?
            if hasAuthor == 1 {
                var varAuthorId: Int64 = 0
                value.read(&varAuthorId, offset: 0, length: 8)
                authorId = PeerId(varAuthorId)
            }
            
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
            
            return .Message(IntermediateMessage(id: index.id, timestamp: index.timestamp, authorId: authorId, text: text, attributesData: attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: referencedMediaIds))
        } else {
            var minId: Int32 = 0
            value.read(&minId, offset: 0, length: 4)
            
            return .Hole(MessageHistoryHole(maxIndex: index, min: minId))
        }
    }
    
    func getMessage(index: MessageIndex) -> IntermediateMessage? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.tableId, key: key) {
            if case let .Message(message) = self.readIntermediateEntry(key, value: value) {
                return message
            }
        }
        return nil
    }
    
    func renderMessage(message: IntermediateMessage, peerTable: PeerTable) -> Message {
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
        
        var author: Peer?
        if let authorId = message.authorId {
            author = peerTable.get(authorId)
        }
        
        var peers = SimpleDictionary<PeerId, Peer>()
        if let chatPeer = peerTable.get(message.id.peerId) {
            peers[chatPeer.id] = chatPeer
        }
        
        for media in parsedMedia {
            for peerId in media.peerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        return Message(id: message.id, timestamp: message.timestamp, author: author, text: message.text, attributes: parsedAttributes, media: parsedMedia, peers: peers)
    }
    
    func entriesAround(index: MessageIndex, count: Int) -> [IntermediateMessageHistoryEntry] {
        var lowerEntries: [IntermediateMessageHistoryEntry] = []
        var upperEntries: [IntermediateMessageHistoryEntry] = []
        
        self.valueBox.range(self.tableId, start: self.key(index), end: self.lowerBound(index.id.peerId), values: { key, value in
            lowerEntries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count / 2)
        
        self.valueBox.range(self.tableId, start: self.key(index).predecessor, end: self.upperBound(index.id.peerId), values: { key, value in
            upperEntries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count - lowerEntries.count)
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            self.valueBox.range(self.tableId, start: self.key(lowerEntries.last!.index), end: self.lowerBound(index.id.peerId), values: { key, value in
                lowerEntries.append(self.readIntermediateEntry(key, value: value))
                return true
            }, limit: count - (lowerEntries.count + upperEntries.count))
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for entry in lowerEntries.reverse() {
            entries.append(entry)
        }
        entries.appendContentsOf(upperEntries)
        
        return entries
    }
    
    func earlierEntries(peerId: PeerId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        var entries: [IntermediateMessageHistoryEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index)
        } else {
            key = self.upperBound(peerId)
        }
        self.valueBox.range(self.tableId, start: key, end: self.lowerBound(peerId), values: { key, value in
            entries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(peerId: PeerId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        var entries: [IntermediateMessageHistoryEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(index)
        } else {
            key = self.lowerBound(peerId)
        }
        self.valueBox.range(self.tableId, start: key, end: self.upperBound(peerId), values: { key, value in
            entries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func debugList(peerId: PeerId, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        return self.entriesAround(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0), count: 1000).map({ entry -> RenderedMessageHistoryEntry in
            switch entry {
                case let .Hole(hole):
                    return .Hole(hole)
                case let .Message(message):
                    return .RenderedMessage(self.renderMessage(message, peerTable: peerTable))
            }
        })
    }
}
