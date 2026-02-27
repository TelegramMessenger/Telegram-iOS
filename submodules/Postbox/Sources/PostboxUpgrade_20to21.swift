import Foundation

private struct PrivatePeerId: Hashable {
    typealias Namespace = Int32
    typealias Id = Int32
    
    let namespace: Namespace
    let id: Id
    
    init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    init(_ n: Int64) {
        self.namespace = Int32((n >> 32) & 0x7fffffff)
        self.id = Int32(bitPattern: UInt32(n & 0xffffffff))
    }
    
    func toInt64() -> Int64 {
        return (Int64(self.namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: self.id)))
    }
}

private func localChatListPinningIndexFromKeyValue(_ value: UInt16) -> UInt16? {
    if value == 0 {
        return nil
    } else {
        return UInt16.max - 1 - value
    }
}

private func extractChatListKey(_ key: ValueBoxKey) -> (groupId: Int32?, pinningIndex: UInt16?, index: MessageIndex, type: Int8) {
    let groupIdValue = key.getInt32(0)
    return (
        groupId: groupIdValue == 0 ? nil : groupIdValue,
        pinningIndex: localChatListPinningIndexFromKeyValue(key.getUInt16(4)),
        index: MessageIndex(
            id: MessageId(
                peerId: PeerId(key.getInt64(4 + 2 + 4 + 1 + 4)),
                namespace: Int32(key.getInt8(4 + 2 + 4)),
                id: key.getInt32(4 + 2 + 4 + 1)
            ),
            timestamp: key.getInt32(4 + 2)
        ),
        type: key.getInt8(4 + 2 + 4 + 1 + 4 + 8)
    )
}

private struct MessageDataFlags: OptionSet {
    var rawValue: Int8
    
    init() {
        self.rawValue = 0
    }
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
    
    static let hasGloballyUniqueId = MessageDataFlags(rawValue: 1 << 0)
    static let hasGlobalTags = MessageDataFlags(rawValue: 1 << 1)
    static let hasGroupingKey = MessageDataFlags(rawValue: 1 << 2)
    static let hasGroupInfo = MessageDataFlags(rawValue: 1 << 3)
    static let hasLocalTags = MessageDataFlags(rawValue: 1 << 4)
}

private enum MediaEntryType: Int8 {
    case Direct
    case MessageReference
}

private func mediaTableKey(_ id: MediaId) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4 + 8)
    key.setInt32(0, value: id.namespace)
    key.setInt64(4, value: id.id)
    return key
}

private func removeMediaReference(valueBox: ValueBox, table: ValueBoxTable, id: MediaId, sharedWriteBuffer: WriteBuffer = WriteBuffer()) {
    guard let value = valueBox.get(table, key: mediaTableKey(id)) else {
        return
    }
    
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
            valueBox.remove(table, key: mediaTableKey(id), secure: false)
        } else {
            withExtendedLifetime(sharedWriteBuffer, {
                valueBox.set(table, key: mediaTableKey(id), value: sharedWriteBuffer.readBufferNoCopy())
            })
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
        
        valueBox.remove(table, key: mediaTableKey(id), secure: false)
    } else {
        assertionFailure()
    }
}

func postboxUpgrade_20to21(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    postboxLog("Upgrade 20->21 started")
    progress(0.0)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let messageHistoryIndexTable = ValueBoxTable(id: 4, keyType: .binary, compactValuesOnCreation: true)
    let messageHistoryTable = ValueBoxTable(id: 7, keyType: .binary, compactValuesOnCreation: false)
    let messageHistoryMetadataTable = ValueBoxTable(id: 10, keyType: .binary, compactValuesOnCreation: true)
    let chatListIndexTable = ValueBoxTable(id: 8, keyType: .int64, compactValuesOnCreation: false)
    let chatListTable = ValueBoxTable(id: 9, keyType: .binary, compactValuesOnCreation: true)
    let globalMessageIdsTable = ValueBoxTable(id: 3, keyType: .int64, compactValuesOnCreation: false)
    let messageHistoryTagsTable = ValueBoxTable(id: 12, keyType: .binary, compactValuesOnCreation: true)
    let globalMessageHistoryTagsTable = ValueBoxTable(id: 39, keyType: .binary, compactValuesOnCreation: true)
    let localMessageHistoryTagsTable = ValueBoxTable(id: 52, keyType: .binary, compactValuesOnCreation: true)
    let mediaTable = ValueBoxTable(id: 6, keyType: .binary, compactValuesOnCreation: false)
    
    var totalMessageCount = 0
    
    let absoluteLowerBound = ValueBoxKey(length: 8)
    absoluteLowerBound.setInt64(0, value: 0)
    
    let absoluteUpperBound = ValueBoxKey(length: 8)
    absoluteUpperBound.setInt64(0, value: Int64.max - 1)
    
    let sharedMessageHistoryKey = ValueBoxKey(length: 8 + 4 + 4 + 4)
    let sharedPeerHistoryInitializedKey = ValueBoxKey(length: 8 + 1)
    let sharedChatListIndexKey = ValueBoxKey(length: 8)
    let sharedGlobalIdsKey = ValueBoxKey(length: 8)
    let sharedMessageHistoryTagsKey = ValueBoxKey(length: 8 + 4 + 4 + 4 + 4)
    let sharedGlobalTagsKey = ValueBoxKey(length: 4 + 4 + 4 + 4 + 8)
    let sharedLocalTagsKey = ValueBoxKey(length: 4 + 4 + 4 + 8)
    let sharedMediaWriteBuffer = WriteBuffer()
    
    var matchingPeerIds: [PrivatePeerId] = []
    var expectedTotalCount = 0
    
    var currentLowerBound: ValueBoxKey = absoluteLowerBound
    while true {
        var currentPeerId: PrivatePeerId?
        valueBox.range(messageHistoryIndexTable, start: currentLowerBound, end: absoluteUpperBound, keys: {
            key in
            currentPeerId = PrivatePeerId(key.getInt64(0))
            return true
        }, limit: 1)
        if let currentPeerId = currentPeerId {
            let nextLowerBound = ValueBoxKey(length: 8)
            nextLowerBound.setInt64(0, value: currentPeerId.toInt64() + 1)
            
            if currentPeerId.namespace == 0 || currentPeerId.namespace == 1 || currentPeerId.namespace == 2 { // CloudUser || CloudGroup || CloudChannel
                expectedTotalCount += valueBox.count(messageHistoryIndexTable, start: currentLowerBound, end: nextLowerBound)
                matchingPeerIds.append(currentPeerId)
            }
            currentLowerBound = nextLowerBound
        } else {
            break
        }
    }
    
    var messageIndex = -1
    let reportBase = max(1, expectedTotalCount / 100)
    
    postboxLog("Upgrade 20->21 expected to process \(expectedTotalCount) messages")
    
    for peerId in matchingPeerIds {
        let peerCloudLowerBound = ValueBoxKey(length: 8 + 4)
        peerCloudLowerBound.setInt64(0, value: peerId.toInt64())
        peerCloudLowerBound.setInt32(8, value: 0) // Cloud
        
        valueBox.range(messageHistoryIndexTable, start: peerCloudLowerBound, end: peerCloudLowerBound.successor, values: { key, indexValue in
            totalMessageCount += 1
            
            if messageIndex % reportBase == 0 {
                progress(min(1.0, Float(messageIndex) / Float(expectedTotalCount)))
            }
            messageIndex += 1
            
            var flags: Int8 = 0
            indexValue.read(&flags, offset: 0, length: 1)
            
            var timestamp: Int32 = 0
            indexValue.read(&timestamp, offset: 0, length: 4)
            
            let id = key.getInt32(8 + 4)
            
            let HistoryEntryTypeMask: Int8 = 1
            let HistoryEntryTypeMessage: Int8 = 0
            
            if (flags & HistoryEntryTypeMask) == HistoryEntryTypeMessage {
                sharedGlobalIdsKey.setInt64(0, value: Int64(id))
                valueBox.remove(globalMessageIdsTable, key: sharedGlobalIdsKey, secure: false)
            }
            
            sharedMessageHistoryKey.setInt64(0, value: peerId.toInt64())
            sharedMessageHistoryKey.setInt32(8, value: timestamp)
            sharedMessageHistoryKey.setInt32(8 + 4, value: 0)
            sharedMessageHistoryKey.setInt32(8 + 4 + 4, value: id)
            
            if let value = valueBox.get(messageHistoryTable, key: sharedMessageHistoryKey) {
                var type: Int8 = 0
                value.read(&type, offset: 0, length: 1)
                if type == 0 {
                    var stableId: UInt32 = 0
                    value.read(&stableId, offset: 0, length: 4)
                    
                    var stableVersion: UInt32 = 0
                    value.read(&stableVersion, offset: 0, length: 4)
                    
                    var dataFlagsValue: Int8 = 0
                    value.read(&dataFlagsValue, offset: 0, length: 1)
                    let dataFlags = MessageDataFlags(rawValue: dataFlagsValue)
                    
                    if dataFlags.contains(.hasGloballyUniqueId) {
                        var globallyUniqueIdValue: Int64 = 0
                        value.read(&globallyUniqueIdValue, offset: 0, length: 8)
                    }
                    
                    var globalTags: GlobalMessageTags = []
                    if dataFlags.contains(.hasGlobalTags) {
                        var globalTagsValue: UInt32 = 0
                        value.read(&globalTagsValue, offset: 0, length: 4)
                        globalTags = GlobalMessageTags(rawValue: globalTagsValue)
                    }
                    
                    if dataFlags.contains(.hasGroupingKey) {
                        var groupingKeyValue: Int64 = 0
                        value.read(&groupingKeyValue, offset: 0, length: 8)
                    }
                    
                    if dataFlags.contains(.hasGroupInfo) {
                        var stableIdValue: UInt32 = 0
                        value.read(&stableIdValue, offset: 0, length: 4)
                    }
                    
                    var localTags: LocalMessageTags = []
                    if dataFlags.contains(.hasLocalTags) {
                        var localTagsValue: UInt32 = 0
                        value.read(&localTagsValue, offset: 0, length: 4)
                        localTags = LocalMessageTags(rawValue: localTagsValue)
                    }
                    
                    var flagsValue: UInt32 = 0
                    value.read(&flagsValue, offset: 0, length: 4)
                    
                    var tagsValue: UInt32 = 0
                    value.read(&tagsValue, offset: 0, length: 4)
                    let tags = MessageTags(rawValue: tagsValue)
                    
                    var forwardInfoFlags: Int8 = 0
                    value.read(&forwardInfoFlags, offset: 0, length: 1)
                    if forwardInfoFlags != 0 {
                        var forwardAuthorId: Int64 = 0
                        var forwardDate: Int32 = 0
                        
                        value.read(&forwardAuthorId, offset: 0, length: 8)
                        value.read(&forwardDate, offset: 0, length: 4)
                        
                        if (forwardInfoFlags & (1 << 1)) != 0 {
                            var forwardSourceIdValue: Int64 = 0
                            value.read(&forwardSourceIdValue, offset: 0, length: 8)
                        }
                        
                        if (forwardInfoFlags & (1 << 2)) != 0 {
                            var forwardSourceMessagePeerId: Int64 = 0
                            var forwardSourceMessageNamespace: Int32 = 0
                            var forwardSourceMessageIdId: Int32 = 0
                            value.read(&forwardSourceMessagePeerId, offset: 0, length: 8)
                            value.read(&forwardSourceMessageNamespace, offset: 0, length: 4)
                            value.read(&forwardSourceMessageIdId, offset: 0, length: 4)
                        }
                        
                        if (forwardInfoFlags & (1 << 3)) != 0 {
                            var signatureLength: Int32 = 0
                            value.read(&signatureLength, offset: 0, length: 4)
                            value.skip(Int(signatureLength))
                        }
                    }
                    
                    var hasAuthor: Int8 = 0
                    value.read(&hasAuthor, offset: 0, length: 1)
                    if hasAuthor == 1 {
                        var varAuthorId: Int64 = 0
                        value.read(&varAuthorId, offset: 0, length: 8)
                    }
                    
                    var textLength: Int32 = 0
                    value.read(&textLength, offset: 0, length: 4)
                    value.skip(Int(textLength))
                    
                    var attributeCount: Int32 = 0
                    value.read(&attributeCount, offset: 0, length: 4)
                    for _ in 0 ..< attributeCount {
                        var attributeLength: Int32 = 0
                        value.read(&attributeLength, offset: 0, length: 4)
                        value.skip(Int(attributeLength))
                    }
                    
                    let embeddedMediaOffset = value.offset
                    var embeddedMediaCount: Int32 = 0
                    value.read(&embeddedMediaCount, offset: 0, length: 4)
                    for _ in 0 ..< embeddedMediaCount {
                        var mediaLength: Int32 = 0
                        value.read(&mediaLength, offset: 0, length: 4)
                        value.skip(Int(mediaLength))
                    }
                    let embeddedMediaLength = value.offset - embeddedMediaOffset
                    let embeddedMediaBytes = malloc(embeddedMediaLength)!
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
                    
                    for tag in tags {
                        sharedMessageHistoryTagsKey.setInt64(0, value: peerId.toInt64())
                        sharedMessageHistoryTagsKey.setUInt32(8, value: tag.rawValue)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4, value: timestamp)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4 + 4, value: 0)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4 + 4 + 4, value: id)
                        
                        valueBox.remove(messageHistoryTagsTable, key: sharedMessageHistoryTagsKey, secure: false)
                    }
                    
                    for tag in globalTags {
                        sharedGlobalTagsKey.setUInt32(0, value: tag.rawValue)
                        sharedGlobalTagsKey.setInt32(4, value: timestamp)
                        sharedGlobalTagsKey.setInt32(4 + 4, value: 0)
                        sharedGlobalTagsKey.setInt32(4 + 4 + 4, value: id)
                        sharedGlobalTagsKey.setInt64(4 + 4 + 4 + 4, value: peerId.toInt64())
                        
                        valueBox.remove(globalMessageHistoryTagsTable, key: sharedGlobalTagsKey, secure: false)
                    }
                    
                    for tag in localTags {
                        sharedLocalTagsKey.setUInt32(0, value: tag.rawValue)
                        sharedLocalTagsKey.setInt32(4, value: 0)
                        sharedLocalTagsKey.setInt32(4 + 4, value: id)
                        sharedLocalTagsKey.setInt64(4 + 4 + 4, value: peerId.toInt64())
                        
                        valueBox.remove(localMessageHistoryTagsTable, key: sharedLocalTagsKey, secure: false)
                    }
                    
                    for mediaId in referencedMediaIds {
                        removeMediaReference(valueBox: valueBox, table: mediaTable, id: mediaId, sharedWriteBuffer: sharedMediaWriteBuffer)
                    }
                    
                    if embeddedMediaData.length > 4 {
                        var embeddedMediaCount: Int32 = 0
                        embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                        for _ in 0 ..< embeddedMediaCount {
                            var mediaLength: Int32 = 0
                            embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                            if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                                if let mediaId = media.id {
                                    removeMediaReference(valueBox: valueBox, table: mediaTable, id: mediaId, sharedWriteBuffer: sharedMediaWriteBuffer)
                                }
                            }
                            embeddedMediaData.skip(Int(mediaLength))
                        }
                    }
                } else {
                    var stableId: UInt32 = 0
                    value.read(&stableId, offset: 0, length: 4)
                    
                    var minId: Int32 = 0
                    value.read(&minId, offset: 0, length: 4)
                    var tags: UInt32 = 0
                    value.read(&tags, offset: 0, length: 4)
                    
                    for tag in MessageTags(rawValue: tags) {
                        sharedMessageHistoryTagsKey.setInt64(0, value: peerId.toInt64())
                        sharedMessageHistoryTagsKey.setUInt32(8, value: tag.rawValue)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4, value: timestamp)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4 + 4, value: 0)
                        sharedMessageHistoryTagsKey.setInt32(8 + 4 + 4 + 4, value: id)
                        
                        valueBox.remove(messageHistoryTagsTable, key: sharedMessageHistoryTagsKey, secure: false)
                    }
                }
                valueBox.remove(messageHistoryTable, key: sharedMessageHistoryKey, secure: false)
            }
            
            return true
        }, limit: 0)
        
        valueBox.removeRange(messageHistoryIndexTable, start: peerCloudLowerBound, end: peerCloudLowerBound.successor)
        
        sharedPeerHistoryInitializedKey.setInt64(0, value: peerId.toInt64())
        sharedPeerHistoryInitializedKey.setInt8(8, value: 1)
        valueBox.remove(messageHistoryMetadataTable, key: sharedPeerHistoryInitializedKey, secure: false)
        
        sharedChatListIndexKey.setInt64(0, value: peerId.toInt64())
        valueBox.remove(chatListIndexTable, key: sharedChatListIndexKey, secure: false)
    }
    
    var removeChatListKeys: [ValueBoxKey] = []
    valueBox.scan(chatListTable, keys: { key in
        let (_, _, index, type) = extractChatListKey(key)
        if index.id.peerId.namespace._internalGetInt32Value() != 3 { // Secret Chat
            sharedChatListIndexKey.setInt64(0, value: index.id.peerId.toInt64())
            valueBox.remove(chatListIndexTable, key: sharedChatListIndexKey, secure: false)
            
            removeChatListKeys.append(key)
        } else if type == 2 { // Hole
            removeChatListKeys.append(key)
        }
        return true
    })
    
    for key in removeChatListKeys {
        valueBox.remove(chatListTable, key: key, secure: false)
    }
    
    let chatListInitializedKey = ValueBoxKey(length: 1)
    chatListInitializedKey.setInt8(0, value: 0)
    valueBox.remove(messageHistoryMetadataTable, key: chatListInitializedKey, secure: false)
    
    let shouldReindexUnreadCountsKey = ValueBoxKey(length: 1)
    shouldReindexUnreadCountsKey.setInt8(0, value: 8)
    valueBox.set(messageHistoryMetadataTable, key: shouldReindexUnreadCountsKey, value: MemoryBuffer())
    
    let endTime = CFAbsoluteTimeGetCurrent()
    postboxLog("Upgrade 20->21 (\(totalMessageCount) messages) took \(endTime - startTime) s")
    
    metadataTable.setUserVersion(21)
    
    progress(1.0)
}
