import Foundation

private struct UpgradeChatListIndexFlags: OptionSet {
    var rawValue: Int8
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
    
    static let hasIndex = UpgradeChatListIndexFlags(rawValue: 1 << 0)
}

private enum UpgradePeerChatListInclusion {
    case notSpecified
    case never
    case ifHasMessages
    case ifHasMessagesOrOneOf(pinningIndex: UInt16?, minTimestamp: Int32?)
}

private struct UpgradeChatListPeerInclusionIndex {
    let topMessageIndex: MessageIndex?
    let inclusion: UpgradePeerChatListInclusion
    
    func includedIndex(peerId: PeerId) -> Bool {
        switch inclusion {
        case .notSpecified, .never:
            return false
        case .ifHasMessages:
            if let _ = self.topMessageIndex {
                return true
            } else {
                return false
            }
        case let .ifHasMessagesOrOneOf(pinningIndex, minTimestamp):
            if let _ = minTimestamp {
                return true
            } else if let _ = self.topMessageIndex {
                return true
            } else if let _ = pinningIndex {
                return true
            } else {
                return false
            }
        }
    }
}

private func parseInclusionIndex(peerId: PeerId, value: ReadBuffer) -> Bool {
    let topMessageIndex: MessageIndex?
    
    var flagsValue: Int8 = 0
    value.read(&flagsValue, offset: 0, length: 1)
    let flags = UpgradeChatListIndexFlags(rawValue: flagsValue)
    
    if flags.contains(.hasIndex) {
        var idNamespace: Int32 = 0
        var idId: Int32 = 0
        var idTimestamp: Int32 = 0
        value.read(&idNamespace, offset: 0, length: 4)
        value.read(&idId, offset: 0, length: 4)
        value.read(&idTimestamp, offset: 0, length: 4)
        topMessageIndex = MessageIndex(id: MessageId(peerId: peerId, namespace: idNamespace, id: idId), timestamp: idTimestamp)
    } else {
        topMessageIndex = nil
    }
    
    let inclusion: UpgradePeerChatListInclusion
    
    var inclusionId: Int8 = 0
    value.read(&inclusionId, offset: 0, length: 1)
    if inclusionId == 0 {
        inclusion = .notSpecified
    } else if inclusionId == 1 {
        inclusion = .never
    } else if inclusionId == 2 {
        inclusion = .ifHasMessages
    } else if inclusionId == 3 {
        var pinningIndexValue: UInt16 = 0
        value.read(&pinningIndexValue, offset: 0, length: 2)
        
        var hasMinTimestamp: Int8 = 0
        value.read(&hasMinTimestamp, offset: 0, length: 1)
        let minTimestamp: Int32?
        if hasMinTimestamp != 0 {
            var minTimestampValue: Int32 = 0
            value.read(&minTimestampValue, offset: 0, length: 4)
            minTimestamp = minTimestampValue
        } else {
            minTimestamp = nil
        }
        inclusion = .ifHasMessagesOrOneOf(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), minTimestamp: minTimestamp)
    } else {
        assertionFailure()
        return false
    }
    
    let inclusionIndex = UpgradeChatListPeerInclusionIndex(topMessageIndex: topMessageIndex, inclusion: inclusion)
    return inclusionIndex.includedIndex(peerId: peerId)
}

private struct UpgradePeerNotificationSettingsTableEntryFlags: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let hasCurrent = UpgradePeerNotificationSettingsTableEntryFlags(rawValue: 1 << 0)
    static let hasPending = UpgradePeerNotificationSettingsTableEntryFlags(rawValue: 1 << 1)
}

private func parseNotificationSettings(valueBox: ValueBox, table: ValueBoxTable, peerId: PeerId) -> Bool {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.toInt64())
    if let value = valueBox.get(table, key: key) {
        var flagsValue: Int32 = 0
        value.read(&flagsValue, offset: 0, length: 4)
        let flags = UpgradePeerNotificationSettingsTableEntryFlags(rawValue: flagsValue)
        
        var current: PeerNotificationSettings?
        if flags.contains(.hasCurrent) {
            var length: Int32 = 0
            value.read(&length, offset: 0, length: 4)
            let object = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(length), length: Int(length), freeWhenDone: false)).decodeRootObject() as? PeerNotificationSettings
            assert(object != nil)
            current = object
            value.skip(Int(length))
        }
        
        var pending: PeerNotificationSettings?
        if flags.contains(.hasPending) {
            var length: Int32 = 0
            value.read(&length, offset: 0, length: 4)
            let object = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(length), length: Int(length), freeWhenDone: false)).decodeRootObject() as? PeerNotificationSettings
            assert(object != nil)
            pending = object
            value.skip(Int(length))
        }
        if let pending = pending {
            return !pending.isRemovedFromTotalUnreadCount(default: false)
        } else if let current = current {
            return !current.isRemovedFromTotalUnreadCount(default: false)
        } else {
            return false
        }
    }
    return false
}

private func getReadStateCount(valueBox: ValueBox, table: ValueBoxTable, peerId: PeerId) -> Int32 {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.toInt64())
    var totalCount: Int32 = 0
    if let value = valueBox.get(table, key: key) {
        var count: Int32 = 0
        value.read(&count, offset: 0, length: 4)
        for _ in 0 ..< count {
            var namespaceId: Int32 = 0
            value.read(&namespaceId, offset: 0, length: 4)

            var kind: Int8 = 0
            value.read(&kind, offset: 0, length: 1)
            if kind == 0 {
                var maxIncomingReadId: Int32 = 0
                var maxOutgoingReadId: Int32 = 0
                var maxKnownId: Int32 = 0
                var count: Int32 = 0
                
                value.read(&maxIncomingReadId, offset: 0, length: 4)
                value.read(&maxOutgoingReadId, offset: 0, length: 4)
                value.read(&maxKnownId, offset: 0, length: 4)
                value.read(&count, offset: 0, length: 4)
                
                totalCount += count
            } else {
                var maxIncomingReadTimestamp: Int32 = 0
                var maxIncomingReadIdPeerId: Int64 = 0
                var maxIncomingReadIdNamespace: Int32 = 0
                var maxIncomingReadIdId: Int32 = 0
                
                var maxOutgoingReadTimestamp: Int32 = 0
                var maxOutgoingReadIdPeerId: Int64 = 0
                var maxOutgoingReadIdNamespace: Int32 = 0
                var maxOutgoingReadIdId: Int32 = 0
                
                var count: Int32 = 0
                
                value.read(&maxIncomingReadTimestamp, offset: 0, length: 4)
                value.read(&maxIncomingReadIdPeerId, offset: 0, length: 8)
                value.read(&maxIncomingReadIdNamespace, offset: 0, length: 4)
                value.read(&maxIncomingReadIdId, offset: 0, length: 4)
                
                value.read(&maxOutgoingReadTimestamp, offset: 0, length: 4)
                value.read(&maxOutgoingReadIdPeerId, offset: 0, length: 8)
                value.read(&maxOutgoingReadIdNamespace, offset: 0, length: 4)
                value.read(&maxOutgoingReadIdId, offset: 0, length: 4)
                
                value.read(&count, offset: 0, length: 4)
                totalCount += count
            }
        }
    }
    return totalCount
}

func postboxUpgrade_16to17(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    let chatListIndexTable = ValueBoxTable(id: 8, keyType: .int64, compactValuesOnCreation: false)
    let messageHistoryMetadataTable = ValueBoxTable(id: 10, keyType: .binary, compactValuesOnCreation: true)
    
    var includedPeerIds: [PeerId] = []
    
    valueBox.scanInt64(chatListIndexTable, values: { key, value in
        let peerId = PeerId(key)
        if parseInclusionIndex(peerId: peerId, value: value) {
            includedPeerIds.append(peerId)
        }
        return true
    })
    
    let state = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
    
    let key = ValueBoxKey(length: 1)
    key.setInt8(0, value: 4)
    let encoder = PostboxEncoder()
    encoder.encodeObject(state, forKey: "_")
    
    valueBox.set(messageHistoryMetadataTable, key: key, value: encoder.readBufferNoCopy())
    
    metadataTable.setUserVersion(17)
}

