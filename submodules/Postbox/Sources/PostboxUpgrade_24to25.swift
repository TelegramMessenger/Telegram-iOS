import Foundation

private func localChatListPinningIndexFromKeyValue(_ value: UInt16) -> UInt16? {
    if value == 0 {
        return nil
    } else {
        return UInt16.max - 1 - value
    }
}

private func extractChatListKey(_ key: ValueBoxKey) -> (groupId: Int32, pinningIndex: UInt16?, index: MessageIndex, type: Int8) {
    let groupIdValue = key.getInt32(0)
    return (
        groupId: groupIdValue,
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

private struct ChatListIndexFlags: OptionSet {
    var rawValue: Int8
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
    
    static let hasIndex = ChatListIndexFlags(rawValue: 1 << 0)
}

func postboxUpgrade_24to25(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    postboxLog("Upgrade 24->25 started")
    let messageHistoryMetadataTable = ValueBoxTable(id: 10, keyType: .binary, compactValuesOnCreation: true)
    
    let chatListTable = ValueBoxTable(id: 9, keyType: .binary, compactValuesOnCreation: true)
    var peerIdToGroupId: [PeerId: Int32] = [:]
    valueBox.scan(chatListTable, keys: { key in
        let (groupId, _, index, type) = extractChatListKey(key)
        if type == 1  {
            peerIdToGroupId[index.id.peerId] = groupId
        }
        return true
    })
    
    let chatListIndexTable = ValueBoxTable(id: 8, keyType: .int64, compactValuesOnCreation: true)
    var updatedValues: [PeerId: MemoryBuffer] = [:]
    valueBox.scanInt64(chatListIndexTable, values: { key, value in
        let writeBuffer = WriteBuffer()
        
        let peerId = PeerId(key)
        
        var flagsValue: Int8 = 0
        value.read(&flagsValue, offset: 0, length: 1)
        writeBuffer.write(&flagsValue, offset: 0, length: 1)
        let flags = ChatListIndexFlags(rawValue: flagsValue)
        
        if flags.contains(.hasIndex) {
            var idNamespace: Int32 = 0
            var idId: Int32 = 0
            var idTimestamp: Int32 = 0
            value.read(&idNamespace, offset: 0, length: 4)
            value.read(&idId, offset: 0, length: 4)
            value.read(&idTimestamp, offset: 0, length: 4)
            writeBuffer.write(&idNamespace, offset: 0, length: 4)
            writeBuffer.write(&idId, offset: 0, length: 4)
            writeBuffer.write(&idTimestamp, offset: 0, length: 4)
        }
        
        var inclusionId: Int8 = 0
        value.read(&inclusionId, offset: 0, length: 1)
        if inclusionId == 0 {
        } else {
            if inclusionId == 1 || peerIdToGroupId[peerId] == nil {
                inclusionId = 0
                writeBuffer.write(&inclusionId, offset: 0, length: 1)
            } else if inclusionId == 2 {
                inclusionId = 1
                writeBuffer.write(&inclusionId, offset: 0, length: 1)
                
                var pinningIndexValue: UInt16 = 0
                writeBuffer.write(&pinningIndexValue, offset: 0, length: 2)
                
                var hasMinTimestamp: Int8 = 0
                writeBuffer.write(&hasMinTimestamp, offset: 0, length: 1)
                
                var groupId = peerIdToGroupId[peerId] ?? 0
                writeBuffer.write(&groupId, offset: 0, length: 4)
            } else if inclusionId == 3 {
                inclusionId = 1
                writeBuffer.write(&inclusionId, offset: 0, length: 1)
                
                var pinningIndexValue: UInt16 = 0
                value.read(&pinningIndexValue, offset: 0, length: 2)
                writeBuffer.write(&pinningIndexValue, offset: 0, length: 2)
                
                var hasMinTimestamp: Int8 = 0
                value.read(&hasMinTimestamp, offset: 0, length: 1)
                writeBuffer.write(&hasMinTimestamp, offset: 0, length: 1)
                
                if hasMinTimestamp != 0 {
                    var minTimestampValue: Int32 = 0
                    value.read(&minTimestampValue, offset: 0, length: 4)
                    writeBuffer.write(&minTimestampValue, offset: 0, length: 4)
                }
                
                var groupId = peerIdToGroupId[peerId] ?? 0
                writeBuffer.write(&groupId, offset: 0, length: 4)
            } else {
                assertionFailure()
            }
            
            updatedValues[peerId] = writeBuffer
        }
        
        return true
    })
    
    for (peerId, value) in updatedValues {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        valueBox.set(chatListIndexTable, key: key, value: value)
    }
    
    let shouldReindexUnreadCountsKey = ValueBoxKey(length: 1)
    shouldReindexUnreadCountsKey.setInt8(0, value: 8)
    valueBox.set(messageHistoryMetadataTable, key: shouldReindexUnreadCountsKey, value: MemoryBuffer())
    
    let synchronizeGroupMessageStatsTable = ValueBoxTable(id: 59, keyType: .binary, compactValuesOnCreation: true)
    let synchronizeGroupMessageStatsKey = ValueBoxKey(length: 4 + 4)
    synchronizeGroupMessageStatsKey.setInt32(0, value: 1) //Archive
    synchronizeGroupMessageStatsKey.setInt32(4, value: 0) //Messages.Cloud
    valueBox.set(synchronizeGroupMessageStatsTable, key: synchronizeGroupMessageStatsKey, value: MemoryBuffer())
    
    metadataTable.setUserVersion(25)
}
