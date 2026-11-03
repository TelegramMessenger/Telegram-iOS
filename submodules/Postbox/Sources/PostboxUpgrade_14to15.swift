import Foundation

private func extractPinningIndexFromKeyValue(_ value: UInt16) -> UInt16? {
    if value == 0 {
        return nil
    } else {
        return UInt16.max - 1 - value
    }
}

private func makeKeyValueForChatListPinningIndex(_ index: UInt16?) -> UInt16 {
    if let index = index {
        return UInt16.max - 1 - index
    } else {
        return 0
    }
}

private func extractPreviousKey(_ key: ValueBoxKey) -> (pinningIndex: UInt16?, index: MessageIndex, type: Int8) {
    return (
        pinningIndex: extractPinningIndexFromKeyValue(key.getUInt16(0)),
        index: MessageIndex(
            id: MessageId(
                peerId: PeerId(key.getInt64(2 + 4 + 4 + 4)),
                namespace: key.getInt32(2 + 4),
                id: key.getInt32(2 + 4 + 4)
            ),
            timestamp: key.getInt32(2)
        ),
        type: key.getInt8(2 + 4 + 4 + 4 + 8)
    )
}

private func makeKey(groupId: Int32?, index: ChatListIndex, type: Int8) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4 + 2 + 4 + 1 + 4 + 8 + 1)
    key.setInt32(0, value: groupId ?? 0)
    key.setUInt16(4, value: keyValueForChatListPinningIndex(index.pinningIndex))
    key.setInt32(4 + 2, value: index.messageIndex.timestamp)
    key.setInt8(4 + 2 + 4, value: Int8(index.messageIndex.id.namespace))
    key.setInt32(4 + 2 + 4 + 1, value: index.messageIndex.id.id)
    key.setInt64(4 + 2 + 4 + 1 + 4, value: index.messageIndex.id.peerId.toInt64())
    key.setInt8(4 + 2 + 4 + 1 + 4 + 8, value: type)
    return key
}

private func extractNewKey(_ key: ValueBoxKey) -> (groupId: PeerGroupId, pinningIndex: UInt16?, index: MessageIndex, type: Int8) {
    let groupIdValue = key.getInt32(0)
    return (
        groupId: PeerGroupId(rawValue: groupIdValue),
        pinningIndex: chatListPinningIndexFromKeyValue(key.getUInt16(4)),
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

func postboxUpgrade_14to15(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    let chatListTable = ValueBoxTable(id: 9, keyType: .binary, compactValuesOnCreation: true)
    
    var values: [(ValueBoxKey, ValueBoxKey, Data)] = []
    
    valueBox.scan(chatListTable, values: { key, value in
        let (pinningIndex, index, type) = extractPreviousKey(key)
        let updatedKey = makeKey(groupId: 0, index: ChatListIndex(pinningIndex: pinningIndex, messageIndex: index), type: type)
        let (xgroupId, xpinningIndex, xindex, xtype) = extractNewKey(updatedKey)
        assert(xgroupId == .root)
        assert(xpinningIndex == pinningIndex)
        assert(index == xindex)
        assert(type == xtype)
        values.append((key, updatedKey, value.makeData()))
        return true
    })
    
    for (previous, _, _) in values {
        valueBox.remove(chatListTable, key: previous, secure: false)
    }
    
    for (_, updatedKey, updatedValue) in values {
        valueBox.set(chatListTable, key: updatedKey, value: MemoryBuffer(data: updatedValue))
    }
    
    metadataTable.setUserVersion(15)
}
