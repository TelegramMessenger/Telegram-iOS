import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case InsertHole(MessageHistoryHole)
    case Remove([MessageIndex])
    case UpdateReadState(CombinedPeerReadState)
}

struct MessageHistoryAnchorIndex {
    let index: MessageIndex
    let exact: Bool
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

final class MessageHistoryTable: Table {
    let messageHistoryIndexTable: MessageHistoryIndexTable
    let messageMediaTable: MessageMediaTable
    let historyMetadataTable: MessageHistoryMetadataTable
    let unsentTable: MessageHistoryUnsentTable
    let tagsTable: MessageHistoryTagsTable
    let readStateTable: MessageHistoryReadStateTable
    let synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable
    
    init(valueBox: ValueBox, tableId: Int32, messageHistoryIndexTable: MessageHistoryIndexTable, messageMediaTable: MessageMediaTable, historyMetadataTable: MessageHistoryMetadataTable, unsentTable: MessageHistoryUnsentTable, tagsTable: MessageHistoryTagsTable, readStateTable: MessageHistoryReadStateTable, synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable) {
        self.messageHistoryIndexTable = messageHistoryIndexTable
        self.messageMediaTable = messageMediaTable
        self.historyMetadataTable = historyMetadataTable
        self.unsentTable = unsentTable
        self.tagsTable = tagsTable
        self.readStateTable = readStateTable
        self.synchronizeReadStateTable = synchronizeReadStateTable
        
        super.init(valueBox: valueBox, tableId: tableId)
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
    
    private func processIndexOperations(peerId: PeerId, operations: [MessageHistoryIndexOperation], inout processedOperationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        let sharedKey = self.key(MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0))
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = Encoder()
        
        var outputOperations: [MessageHistoryOperation] = []
        var accumulatedRemoveIndices: [MessageIndex] = []
        var addedIncomingMessageIds: [MessageId] = []
        var removedMessageIds: [MessageId] = []
        for operation in operations {
            switch operation {
                case let .InsertHole(hole):
                    if accumulatedRemoveIndices.count != 0 {
                        outputOperations.append(.Remove(accumulatedRemoveIndices))
                        accumulatedRemoveIndices.removeAll()
                    }
                    self.justInsertHole(hole)
                    outputOperations.append(.InsertHole(hole))
                    
                    let tags = self.messageHistoryIndexTable.seedConfiguration.existingMessageTags.rawValue & hole.tags
                    for i in 0 ..< 32 {
                        let currentTags = tags >> UInt32(i)
                        if currentTags == 0 {
                            break
                        }
                        
                        if (currentTags & 1) != 0 {
                            let tag = MessageTags(rawValue: 1 << UInt32(i))
                            self.tagsTable.add(tag, index: hole.maxIndex)
                        }
                    }
                case let .InsertMessage(storeMessage):
                    if accumulatedRemoveIndices.count != 0 {
                        outputOperations.append(.Remove(accumulatedRemoveIndices))
                        accumulatedRemoveIndices.removeAll()
                    }
                    let message = self.justInsertMessage(storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder)
                    outputOperations.append(.InsertMessage(message))
                    if message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                        self.unsentTable.add(MessageIndex(message), operations: &unsentMessageOperations)
                    }
                    let tags = message.tags.rawValue
                    if tags != 0 {
                        for i in 0 ..< 32 {
                            let currentTags = tags >> UInt32(i)
                            if currentTags == 0 {
                                break
                            }
                            
                            if (currentTags & 1) != 0 {
                                let tag = MessageTags(rawValue: 1 << UInt32(i))
                                self.tagsTable.add(tag, index: MessageIndex(message))
                            }
                        }
                    }
                    if message.flags.contains(.Incoming) {
                        addedIncomingMessageIds.append(message.id)
                    }
                case let .Remove(index):
                    self.justRemove(index, unsentMessageOperations: &unsentMessageOperations)
                    accumulatedRemoveIndices.append(index)
                case let .Update(index, storeMessage):
                    accumulatedRemoveIndices.append(index)
                    if accumulatedRemoveIndices.count != 0 {
                        outputOperations.append(.Remove(accumulatedRemoveIndices))
                        accumulatedRemoveIndices.removeAll()
                    }
                    if let message = self.justUpdate(index, message: storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, unsentMessageOperations: &unsentMessageOperations) {
                        outputOperations.append(.InsertMessage(message))
                    }
            }
        }
        if accumulatedRemoveIndices.count != 0 {
            outputOperations.append(.Remove(accumulatedRemoveIndices))
        }
        
        if !addedIncomingMessageIds.isEmpty {
            let (combinedState, invalidate) = self.readStateTable.addIncomingMessages(peerId, ids: addedIncomingMessageIds)
            if let combinedState = combinedState {
                outputOperations.append(.UpdateReadState(combinedState))
            }
            if invalidate {
                self.synchronizeReadStateTable.set(peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
            }
        }
        
        if processedOperationsByPeerId[peerId] == nil {
            processedOperationsByPeerId[peerId] = outputOperations
        } else {
            processedOperationsByPeerId[peerId]!.appendContentsOf(outputOperations)
        }
    }
    
    private func internalStoreMessages(messages: [StoreMessage]) -> [InternalStoreMessage] {
        var internalStoreMessages: [InternalStoreMessage] = []
        for message in messages {
            switch message.id {
            case let .Id(id):
                internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
            case let .Partial(peerId, namespace):
                let id = self.historyMetadataTable.getNextMessageIdAndIncrement(peerId, namespace: namespace)
                internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
            }
        }
        return internalStoreMessages
    }
    
    func addMessages(messages: [StoreMessage], location: AddMessagesLocation, inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        let messagesByPeerId = self.messagesGroupedByPeerId(messages)
        for (peerId, peerMessages) in messagesByPeerId {
            var operations: [MessageHistoryIndexOperation] = []
            self.messageHistoryIndexTable.addMessages(self.internalStoreMessages(peerMessages), location: location, operations: &operations)
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        }
    }
    
    func addHoles(messageIds: [MessageId], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            for id in messageIds {
                self.messageHistoryIndexTable.addHole(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        }
    }
    
    func removeMessages(messageIds: [MessageId], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            
            let (combinedState, invalidate) = self.readStateTable.deleteMessages(peerId, ids: messageIds, incomingStatsInIds: { peerId, namespace, ids in
                return self.messageHistoryIndexTable.incomingMessageCountInIds(peerId, namespace: namespace, ids: ids)
            })
            
            for id in messageIds {
                self.messageHistoryIndexTable.removeMessage(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
            
            if let combinedState = combinedState {
                var outputOperations: [MessageHistoryOperation] = []
                outputOperations.append(.UpdateReadState(combinedState))
                
                if operationsByPeerId[peerId] == nil {
                    operationsByPeerId[peerId] = outputOperations
                } else {
                    operationsByPeerId[peerId]!.appendContentsOf(outputOperations)
                }
            }
            
            if invalidate {
                self.synchronizeReadStateTable.set(peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
            }
        }
    }
    
    func fillHole(id: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.fillHole(id, fillType: fillType, tagMask: tagMask, messages: self.internalStoreMessages(messages), operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    func updateMessage(id: MessageId, message: StoreMessage, inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.updateMessage(id, message: self.internalStoreMessages([message]).first!, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    func resetIncomingReadStates(states: [PeerId: [MessageId.Namespace: PeerReadState]], inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        for (peerId, namespaces) in states {
            if let combinedState = self.readStateTable.resetStates(peerId, namespaces: namespaces) {
                if operationsByPeerId[peerId] == nil {
                    operationsByPeerId[peerId] = [.UpdateReadState(combinedState)]
                } else {
                    operationsByPeerId[peerId]!.append(.UpdateReadState(combinedState))
                }
            }
            self.synchronizeReadStateTable.set(peerId, operation: nil, operations: &updatedPeerReadStateOperations)
        }
    }
    
    func applyIncomingReadMaxId(messageId: MessageId, inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        var topMessageId: MessageId.Id?
        if let topEntry = self.messageHistoryIndexTable.top(messageId.peerId, namespace: messageId.namespace), case let .Message(index) = topEntry {
            topMessageId = index.id.id
        }
        
        let (combinedState, invalidated) = self.readStateTable.applyMaxReadId(messageId, incomingStatsInRange: { fromId, toId in
            return self.messageHistoryIndexTable.incomingMessageCountInRange(messageId.peerId, namespace: messageId.namespace, minId: fromId, maxId: toId)
        }, topMessageId: topMessageId)
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageId.peerId] == nil {
                operationsByPeerId[messageId.peerId] = [.UpdateReadState(combinedState)]
            } else {
                operationsByPeerId[messageId.peerId]!.append(.UpdateReadState(combinedState))
            }
        }
        
        if invalidated {
            self.synchronizeReadStateTable.set(messageId.peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
        }
    }
    
    func applyInteractiveMaxReadId(messageId: MessageId, inout operationsByPeerId: [PeerId: [MessageHistoryOperation]], inout updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]) {
        var topMessageId: MessageId.Id?
        if let topEntry = self.messageHistoryIndexTable.top(messageId.peerId, namespace: messageId.namespace), case let .Message(index) = topEntry {
            topMessageId = index.id.id
        }
        
        let (combinedState, result) = self.readStateTable.applyInteractiveMaxReadId(messageId, incomingStatsInRange: { fromId, toId in
            return self.messageHistoryIndexTable.incomingMessageCountInRange(messageId.peerId, namespace: messageId.namespace, minId: fromId, maxId: toId)
        }, topMessageId: topMessageId)
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageId.peerId] == nil {
                operationsByPeerId[messageId.peerId] = [.UpdateReadState(combinedState)]
            } else {
                operationsByPeerId[messageId.peerId]!.append(.UpdateReadState(combinedState))
            }
        }
        
        switch result {
            case let .Push(thenSync):
                self.synchronizeReadStateTable.set(messageId.peerId, operation: .Push(thenSync: thenSync), operations: &updatedPeerReadStateOperations)
            case .None:
                break
        }
    }
    
    func topMessage(peerId: PeerId) -> IntermediateMessage? {
        var currentKey = self.upperBound(peerId)
        while true {
            var entry: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.tableId, start: currentKey, end: self.lowerBound(peerId), values: { key, value in
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
    
    func getMessage(index: MessageIndex) -> IntermediateMessage? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.tableId, key: key) {
            let entry = self.readIntermediateEntry(key, value: value)
            if case let .Message(message) = entry {
                return message
            }
        }
        return nil
    }
    
    private func justInsertMessage(message: InternalStoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: Encoder) -> IntermediateMessage {
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)
        
        var stableId: UInt32 = self.historyMetadataTable.getNextStableMessageIndexId()
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        
        var flags = MessageFlags(message.flags)
        sharedBuffer.write(&flags.rawValue, offset: 0, length: 4)
        
        var tags = message.tags
        sharedBuffer.write(&tags.rawValue, offset: 0, length: 4)
        
        var intermediateForwardInfo: IntermediateMessageForwardInfo?
        if let forwardInfo = message.forwardInfo {
            intermediateForwardInfo = IntermediateMessageForwardInfo(forwardInfo)
            
            var forwardInfoFlags: Int8 = 1
            if forwardInfo.sourceId != nil {
                forwardInfoFlags |= 2
            }
            if forwardInfo.sourceMessageId != nil {
                forwardInfoFlags |= 4
            }
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
            var forwardAuthorId: Int64 = forwardInfo.authorId.toInt64()
            var forwardDate: Int32 = forwardInfo.date
            sharedBuffer.write(&forwardAuthorId, offset: 0, length: 8)
            sharedBuffer.write(&forwardDate, offset: 0, length: 4)
            
            if let sourceId = forwardInfo.sourceId {
                var sourceIdValue: Int64 = sourceId.toInt64()
                sharedBuffer.write(&sourceIdValue, offset: 0, length: 8)
            }
            
            if let sourceMessageId = forwardInfo.sourceMessageId {
                var sourceMessageIdPeerId: Int64 = sourceMessageId.peerId.toInt64()
                var sourceMessageIdNamespace: Int32 = sourceMessageId.namespace
                var sourceMessageIdId: Int32 = sourceMessageId.id
                sharedBuffer.write(&sourceMessageIdPeerId, offset: 0, length: 8)
                sharedBuffer.write(&sourceMessageIdNamespace, offset: 0, length: 4)
                sharedBuffer.write(&sourceMessageIdId, offset: 0, length: 4)
            }
        } else {
            var forwardInfoFlags: Int8 = 0
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
        }
        
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
        
        return IntermediateMessage(stableId: stableId, id: message.id, timestamp: message.timestamp, flags: flags, tags: message.tags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia)
    }
    
    private func justInsertHole(hole: MessageHistoryHole, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        var type: Int8 = 1
        sharedBuffer.write(&type, offset: 0, length: 1)
        var stableId: UInt32 = hole.stableId
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        var minId: Int32 = hole.min
        sharedBuffer.write(&minId, offset: 0, length: 4)
        var tags: UInt32 = hole.tags
        sharedBuffer.write(&tags, offset: 0, length: 4)
        self.valueBox.set(self.tableId, key: self.key(hole.maxIndex), value: sharedBuffer.readBufferNoCopy())
    }
    
    private func justRemove(index: MessageIndex, inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation]) {
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
                    
                    if message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                        self.unsentTable.remove(index, operations: &unsentMessageOperations)
                    }
                    
                    let tags = message.tags.rawValue
                    if tags != 0 {
                        for i in 0 ..< 32 {
                            let currentTags = tags >> UInt32(i)
                            if currentTags == 0 {
                                break
                            }
                            
                            if (currentTags & 1) != 0 {
                                let tag = MessageTags(rawValue: 1 << UInt32(i))
                                self.tagsTable.remove(tag, index: index)
                            }
                        }
                    }
                    
                    for mediaId in message.referencedMedia {
                        self.messageMediaTable.removeReference(mediaId)
                    }
                case let .Hole(hole):
                    let tags = self.messageHistoryIndexTable.seedConfiguration.existingMessageTags.rawValue & hole.tags
                    if tags != 0 {
                        for i in 0 ..< 32 {
                            let currentTags = tags >> UInt32(i)
                            if currentTags == 0 {
                                break
                            }
                            
                            if (currentTags & 1) != 0 {
                                let tag = MessageTags(rawValue: 1 << UInt32(i))
                                self.tagsTable.remove(tag, index: hole.maxIndex)
                            }
                        }
                    }
            }
            
            self.valueBox.remove(self.tableId, key: key)
        }
    }
    
    private func justUpdate(index: MessageIndex, message: InternalStoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: Encoder, inout unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation]) -> IntermediateMessage? {
        if let previousMessage = self.getMessage(index) {
            self.valueBox.remove(self.tableId, key: self.key(index))
            
            switch (previousMessage.flags.contains(.Unsent) && !previousMessage.flags.contains(.Failed), message.flags.contains(.Unsent) && !message.flags.contains(.Failed)) {
                case (true, false):
                    self.unsentTable.remove(index, operations: &unsentMessageOperations)
                case (false, true):
                    self.unsentTable.add(MessageIndex(message), operations: &unsentMessageOperations)
                case (true, true):
                    if index != MessageIndex(message) {
                        self.unsentTable.remove(index, operations: &unsentMessageOperations)
                        self.unsentTable.add(MessageIndex(message), operations: &unsentMessageOperations)
                    }
                case (false, false):
                    break
            }
            
            if previousMessage.tags != message.tags {
                assertionFailure()
            }
            
            let previousEmbeddedMediaData = previousMessage.embeddedMediaData
            
            var previousMedia: [Media] = []
            if previousEmbeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                previousEmbeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    previousEmbeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = Decoder(buffer: MemoryBuffer(memory: previousEmbeddedMediaData.memory + previousEmbeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        previousMedia.append(media)
                    }
                    previousEmbeddedMediaData.skip(Int(mediaLength))
                }
            }
            
            for mediaId in previousMessage.referencedMedia {
                if let media = self.messageMediaTable.get(mediaId) {
                    previousMedia.append(media)
                }
            }
            
            let updatedMedia = message.media
            
            var removedMediaIds: [MediaId] = []
            
            var updatedEmbeddedMedia: [Media] = []
            var updatedReferencedMediaIds: [MediaId] = []
            
            for media in updatedMedia {
                assertionFailure()
                if let mediaId = media.id {
                    var found = false
                    for previous in previousMedia {
                        if let previousId = previous.id {
                            if previousId == mediaId {
                                found = true
                                break
                            }
                        }
                    }
                    if !found {
                        let result = self.messageMediaTable.set(media, index: MessageIndex(message), messageHistoryTable: self)
                        switch result {
                            case let .Embed(embedded):
                                updatedEmbeddedMedia.append(embedded)
                            case .Reference:
                                updatedReferencedMediaIds.append(mediaId)
                        }
                    } else {
                        
                    }
                } else {
                    updatedEmbeddedMedia.append(media)
                }
            }
            for media in previousMedia {
                assertionFailure()
                if let mediaId = media.id {
                    var found = false
                    for updated in updatedMedia {
                        if let updatedId = updated.id {
                            if updatedId == mediaId {
                                found = true
                                break
                            }
                        }
                    }
                    if !found {
                        assertionFailure()
                    }
                } else {
                    self.messageMediaTable.removeEmbeddedMedia(media)
                }
            }
            
            sharedBuffer.reset()
            
            var type: Int8 = 0
            sharedBuffer.write(&type, offset: 0, length: 1)
            
            var stableId: UInt32 = previousMessage.stableId
            sharedBuffer.write(&stableId, offset: 0, length: 4)
            
            var flags = MessageFlags(message.flags)
            sharedBuffer.write(&flags.rawValue, offset: 0, length: 4)
            
            var tags = message.tags
            sharedBuffer.write(&tags.rawValue, offset: 0, length: 4)
            
            var intermediateForwardInfo: IntermediateMessageForwardInfo?
            if let forwardInfo = message.forwardInfo {
                intermediateForwardInfo = IntermediateMessageForwardInfo(forwardInfo)
                
                var forwardInfoFlags: Int8 = 1
                if forwardInfo.sourceId != nil {
                    forwardInfoFlags |= 2
                }
                if forwardInfo.sourceMessageId != nil {
                    forwardInfoFlags |= 4
                }
                sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
                var forwardAuthorId: Int64 = forwardInfo.authorId.toInt64()
                var forwardDate: Int32 = forwardInfo.date
                sharedBuffer.write(&forwardAuthorId, offset: 0, length: 8)
                sharedBuffer.write(&forwardDate, offset: 0, length: 4)
                
                if let sourceId = forwardInfo.sourceId {
                    var sourceIdValue: Int64 = sourceId.toInt64()
                    sharedBuffer.write(&sourceIdValue, offset: 0, length: 8)
                }
                
                if let sourceMessageId = forwardInfo.sourceMessageId {
                    var sourceMessageIdPeerId: Int64 = sourceMessageId.peerId.toInt64()
                    var sourceMessageIdNamespace: Int32 = sourceMessageId.namespace
                    var sourceMessageIdId: Int32 = sourceMessageId.id
                    sharedBuffer.write(&sourceMessageIdPeerId, offset: 0, length: 8)
                    sharedBuffer.write(&sourceMessageIdNamespace, offset: 0, length: 4)
                    sharedBuffer.write(&sourceMessageIdId, offset: 0, length: 4)
                }
            } else {
                var forwardInfoFlags: Int8 = 0
                sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
            }
            
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
            
            return IntermediateMessage(stableId: stableId, id: message.id, timestamp: message.timestamp, flags: flags, tags: tags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia)
        } else {
            return nil
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
                self.storeIntermediateMessage(IntermediateMessage(stableId: message.stableId, id: message.id, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: updatedReferencedMedia), sharedKey: self.key(index))
                
                return extractedMedia
            }
        }
        return nil
    }
    
    func storeIntermediateMessage(message: IntermediateMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)
        
        var stableId: UInt32 = message.stableId
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        
        var flagsValue: UInt32 = message.flags.rawValue
        sharedBuffer.write(&flagsValue, offset: 0, length: 4)
        
        var tagsValue: UInt32 = message.tags.rawValue
        sharedBuffer.write(&tagsValue, offset: 0, length: 4)
        
        if let forwardInfo = message.forwardInfo {
            var forwardInfoFlags: Int8 = 1
            if forwardInfo.sourceId != nil {
                forwardInfoFlags |= 2
            }
            if forwardInfo.sourceMessageId != nil {
                forwardInfoFlags |= 4
            }
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
            var forwardAuthorId: Int64 = forwardInfo.authorId.toInt64()
            var forwardDate: Int32 = forwardInfo.date
            sharedBuffer.write(&forwardAuthorId, offset: 0, length: 8)
            sharedBuffer.write(&forwardDate, offset: 0, length: 4)
            
            if let sourceId = forwardInfo.sourceId {
                var sourceIdValue: Int64 = sourceId.toInt64()
                sharedBuffer.write(&sourceIdValue, offset: 0, length: 8)
            }
            
            if let sourceMessageId = forwardInfo.sourceMessageId {
                var sourceMessageIdPeerId: Int64 = sourceMessageId.peerId.toInt64()
                var sourceMessageIdNamespace: Int32 = sourceMessageId.namespace
                var sourceMessageIdId: Int32 = sourceMessageId.id
                sharedBuffer.write(&sourceMessageIdPeerId, offset: 0, length: 8)
                sharedBuffer.write(&sourceMessageIdNamespace, offset: 0, length: 4)
                sharedBuffer.write(&sourceMessageIdId, offset: 0, length: 4)
            }
        } else {
            var forwardInfoFlags: Int8 = 0
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
        }

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
            var stableId: UInt32 = 0
            value.read(&stableId, offset: 0, length: 4)
            
            var flagsValue: UInt32 = 0
            value.read(&flagsValue, offset: 0, length: 4)
            let flags = MessageFlags(rawValue: flagsValue)
            
            var tagsValue: UInt32 = 0
            value.read(&tagsValue, offset: 0, length: 4)
            let tags = MessageTags(rawValue: tagsValue)
            
            var forwardInfoFlags: Int8 = 0
            value.read(&forwardInfoFlags, offset: 0, length: 1)
            var forwardInfo: IntermediateMessageForwardInfo?
            if forwardInfoFlags != 0 {
                var forwardAuthorId: Int64 = 0
                var forwardDate: Int32 = 0
                var forwardSourceId: PeerId?
                var forwardSourceMessageId: MessageId?
                
                value.read(&forwardAuthorId, offset: 0, length: 8)
                value.read(&forwardDate, offset: 0, length: 4)
                
                if (forwardInfoFlags & 2) != 0 {
                    var forwardSourceIdValue: Int64 = 0
                    value.read(&forwardSourceIdValue, offset: 0, length: 8)
                    forwardSourceId = PeerId(forwardSourceIdValue)
                }
                
                if (forwardInfoFlags & 4) != 0 {
                    var forwardSourceMessagePeerId: Int64 = 0
                    var forwardSourceMessageNamespace: Int32 = 0
                    var forwardSourceMessageIdId: Int32 = 0
                    value.read(&forwardSourceMessagePeerId, offset: 0, length: 8)
                    value.read(&forwardSourceMessageNamespace, offset: 0, length: 4)
                    value.read(&forwardSourceMessageIdId, offset: 0, length: 4)
                    forwardSourceMessageId = MessageId(peerId: PeerId(forwardSourceMessagePeerId), namespace: forwardSourceMessageNamespace, id: forwardSourceMessageIdId)
                }
                
                forwardInfo = IntermediateMessageForwardInfo(authorId: PeerId(forwardAuthorId), sourceId: forwardSourceId, sourceMessageId: forwardSourceMessageId, date: forwardDate)
            }
            
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
            //let text = NSString(bytes: value.memory + value.offset, length: Int(textLength), encoding: NSUTF8StringEncoding) ?? ""
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
            
            return .Message(IntermediateMessage(stableId: stableId, id: index.id, timestamp: index.timestamp, flags: flags, tags: tags, forwardInfo: forwardInfo, authorId: authorId, text: text, attributesData: attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: referencedMediaIds))
        } else {
            var stableId: UInt32 = 0
            value.read(&stableId, offset: 0, length: 4)
            
            var minId: Int32 = 0
            value.read(&minId, offset: 0, length: 4)
            var tags: UInt32 = 0
            value.read(&tags, offset: 0, length: 4)
            
            return .Hole(MessageHistoryHole(stableId: stableId, maxIndex: index, min: minId, tags: tags))
        }
    }
    
    func renderMessage(message: IntermediateMessage, peerTable: PeerTable, addAssociatedMessages: Bool = true) -> Message {
        var parsedAttributes: [MessageAttribute] = []
        var parsedMedia: [Media] = []
        
        let attributesData = message.attributesData.sharedBufferNoCopy()
        if attributesData.length > 4 {
            var attributeCount: Int32 = 0
            attributesData.read(&attributeCount, offset: 0, length: 4)
            for _ in 0 ..< attributeCount {
                var attributeLength: Int32 = 0
                attributesData.read(&attributeLength, offset: 0, length: 4)
                if let attribute = Decoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() as? MessageAttribute {
                    parsedAttributes.append(attribute)
                }
                attributesData.skip(Int(attributeLength))
            }
        }
        
        let embeddedMediaData = message.embeddedMediaData.sharedBufferNoCopy()
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
        
        var forwardInfo: MessageForwardInfo?
        if let internalForwardInfo = message.forwardInfo, forwardAuthor = peerTable.get(internalForwardInfo.authorId) {
            var source: Peer?
            if let sourceId = internalForwardInfo.sourceId {
                source = peerTable.get(sourceId)
            }
            forwardInfo = MessageForwardInfo(author: forwardAuthor, source: source, sourceMessageId: internalForwardInfo.sourceMessageId, date: internalForwardInfo.date)
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
        
        var associatedMessages = SimpleDictionary<MessageId, Message>()
        for attribute in parsedAttributes {
            for peerId in attribute.associatedPeerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
            for messageId in attribute.associatedMessageIds {
                if let entry = self.messageHistoryIndexTable.get(messageId) {
                    if case let .Message(index) = entry {
                        if let message = self.getMessage(index) {
                            associatedMessages[messageId] = self.renderMessage(message, peerTable: peerTable, addAssociatedMessages: false)
                        }
                    }
                }
            }
        }
        
        return Message(stableId: message.stableId, id: message.id, timestamp: message.timestamp, flags: message.flags, tags: message.tags, forwardInfo: forwardInfo, author: author, text: message.text, attributes: parsedAttributes, media: parsedMedia, peers: peers, associatedMessages: associatedMessages)
    }
    
    func entriesAround(index: MessageIndex, count: Int) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        var lowerEntries: [IntermediateMessageHistoryEntry] = []
        var upperEntries: [IntermediateMessageHistoryEntry] = []
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        self.valueBox.range(self.tableId, start: self.key(index), end: self.lowerBound(index.id.peerId), values: { key, value in
            lowerEntries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count / 2 + 1)
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.tableId, start: self.key(index).predecessor, end: self.upperBound(index.id.peerId), values: { key, value in
            upperEntries.append(self.readIntermediateEntry(key, value: value))
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [IntermediateMessageHistoryEntry] = []
            self.valueBox.range(self.tableId, start: self.key(lowerEntries.last!.index), end: self.lowerBound(index.id.peerId), values: { key, value in
                additionalLowerEntries.append(self.readIntermediateEntry(key, value: value))
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.appendContentsOf(additionalLowerEntries)
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        entries.appendContentsOf(lowerEntries.reverse())
        entries.appendContentsOf(upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func entriesAround(tagMask: MessageTags, index: MessageIndex, count: Int) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        let (indices, lower, upper) = self.tagsTable.indicesAround(tagMask, index: index, count: count)
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.tableId, key: key) {
                entries.append(readIntermediateEntry(key, value: value))
            } else {
                assertionFailure()
            }
        }
        
        var lowerEntry: IntermediateMessageHistoryEntry?
        var upperEntry: IntermediateMessageHistoryEntry?
        
        if let lowerIndex = lower {
            let key = self.key(lowerIndex)
            if let value = self.valueBox.get(self.tableId, key: key) {
                lowerEntry = readIntermediateEntry(key, value: value)
            } else {
                assertionFailure()
            }
        }
        
        if let upperIndex = upper {
            let key = self.key(upperIndex)
            if let value = self.valueBox.get(self.tableId, key: key) {
                upperEntry = readIntermediateEntry(key, value: value)
            } else {
                assertionFailure()
            }
        }
        
        return (entries, lowerEntry, upperEntry)
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
    
    func earlierEntries(tagMask: MessageTags, peerId: PeerId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        let indices = self.tagsTable.earlierIndices(tagMask, peerId: peerId, index: index, count: count)
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.tableId, key: key) {
                entries.append(readIntermediateEntry(key, value: value))
            } else {
                assertionFailure()
            }
        }
        
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
    
    func laterEntries(tagMask: MessageTags, peerId: PeerId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        let indices = self.tagsTable.laterIndices(tagMask, peerId: peerId, index: index, count: count)
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.tableId, key: key) {
                entries.append(readIntermediateEntry(key, value: value))
            } else {
                assertionFailure()
            }
        }
        
        return entries
    }
    
    func maxReadIndex(peerId: PeerId) -> MessageHistoryAnchorIndex? {
        if let combinedState = self.readStateTable.getCombinedState(peerId), state = combinedState.states.first where state.1.count != 0 {
            return self.anchorIndex(MessageId(peerId: peerId, namespace: state.0, id: state.1.maxReadId))
        }
        return nil
    }
    
    func anchorIndex(messageId: MessageId) -> MessageHistoryAnchorIndex? {
        let (lower, upper) = self.messageHistoryIndexTable.adjacentItems(messageId, bindUpper: false)
        if let lower = lower, case let .Hole(hole) = lower where messageId.id >= hole.min && messageId.id <= hole.maxIndex.id.id {
            return MessageHistoryAnchorIndex(index: MessageIndex(id: messageId, timestamp: lower.index.timestamp), exact: false)
        }
        if let upper = upper, case let .Hole(hole) = upper where messageId.id >= hole.min && messageId.id <= hole.maxIndex.id.id {
            return MessageHistoryAnchorIndex(index: MessageIndex(id: messageId, timestamp: upper.index.timestamp), exact: false)
        }
        
        if let lower = lower {
            return MessageHistoryAnchorIndex(index: MessageIndex(id: messageId, timestamp: lower.index.timestamp), exact: true)
        } else if let upper = upper {
            return MessageHistoryAnchorIndex(index: MessageIndex(id: messageId, timestamp: upper.index.timestamp), exact: true)
        }
        return nil
    }

    func debugList(peerId: PeerId, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        return self.laterEntries(peerId, index: nil, count: 1000).map({ entry -> RenderedMessageHistoryEntry in
            switch entry {
                case let .Hole(hole):
                    return .Hole(hole)
                case let .Message(message):
                    return .RenderedMessage(self.renderMessage(message, peerTable: peerTable))
            }
        })
    }
    
    func debugList(tagMask: MessageTags, peerId: PeerId, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        return self.laterEntries(tagMask, peerId: peerId, index: nil, count: 1000).map({ entry -> RenderedMessageHistoryEntry in
            switch entry {
            case let .Hole(hole):
                return .Hole(hole)
            case let .Message(message):
                return .RenderedMessage(self.renderMessage(message, peerTable: peerTable))
            }
        })
    }
}
