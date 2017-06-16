import Foundation

struct ChatListInclusionIndex {
    let topMessageIndex: MessageIndex?
    let inclusion: PeerChatListInclusion
    var tags: [UInt16]?
    
    func includedIndex(peerId: PeerId) -> ChatListIndex? {
        switch inclusion {
            case .notSpecified, .never:
                return nil
            case .ifHasMessages:
                if let topMessageIndex = self.topMessageIndex {
                    return ChatListIndex(pinningIndex: nil, messageIndex: topMessageIndex)
                } else {
                    return nil
                }
            case let .ifHasMessagesOrOneOf(pinningIndex, minTimestamp):
                if let minTimestamp = minTimestamp {
                    if let topMessageIndex = self.topMessageIndex, topMessageIndex.timestamp >= minTimestamp {
                        return ChatListIndex(pinningIndex: pinningIndex, messageIndex: topMessageIndex)
                    } else {
                        return ChatListIndex(pinningIndex: pinningIndex, messageIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: minTimestamp))
                    }
                } else if let topMessageIndex = self.topMessageIndex {
                    return ChatListIndex(pinningIndex: pinningIndex, messageIndex: topMessageIndex)
                } else if let pinningIndex = pinningIndex {
                    return ChatListIndex(pinningIndex: pinningIndex, messageIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0))
                } else {
                    return nil
                }
        }
    }
}

private struct ChatListIndexFlags: OptionSet {
    var rawValue: Int8
    
    init(rawValue: Int8) {
        self.rawValue = rawValue
    }
    
    static let hasIndex = ChatListIndexFlags(rawValue: 1 << 0)
    static let hasTags = ChatListIndexFlags(rawValue: 1 << 1)
}

final class ChatListIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private let peerNameIndexTable: PeerNameIndexTable
    private let metadataTable: MessageHistoryMetadataTable
    private let readStateTable: MessageHistoryReadStateTable
    private let notificationSettingsTable: PeerNotificationSettingsTable
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedIndices: [PeerId: ChatListInclusionIndex] = [:]
    private var updatedPreviousCachedIndices: [PeerId: ChatListInclusionIndex] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, peerNameIndexTable: PeerNameIndexTable, metadataTable: MessageHistoryMetadataTable, readStateTable: MessageHistoryReadStateTable, notificationSettingsTable: PeerNotificationSettingsTable) {
        self.peerNameIndexTable = peerNameIndexTable
        self.metadataTable = metadataTable
        self.readStateTable = readStateTable
        self.notificationSettingsTable = notificationSettingsTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    func setTopMessageIndex(peerId: PeerId, index: MessageIndex?) -> ChatListInclusionIndex {
        let current = self.get(peerId)
        if self.updatedPreviousCachedIndices[peerId] == nil {
            self.updatedPreviousCachedIndices[peerId] = current
        }
        let updated = ChatListInclusionIndex(topMessageIndex: index, inclusion: current.inclusion, tags: current.tags)
        self.cachedIndices[peerId] = updated
        return updated
    }
    
    func setInclusion(peerId: PeerId, inclusion: PeerChatListInclusion) -> ChatListInclusionIndex {
        let current = self.get(peerId)
        if self.updatedPreviousCachedIndices[peerId] == nil {
            self.updatedPreviousCachedIndices[peerId] = current
        }
        let updated = ChatListInclusionIndex(topMessageIndex: current.topMessageIndex, inclusion: inclusion, tags: current.tags)
        self.cachedIndices[peerId] = updated
        return updated
    }
    
    func get(_ peerId: PeerId) -> ChatListInclusionIndex {
        if let cached = self.cachedIndices[peerId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
                let topMessageIndex: MessageIndex?
                
                var flagsValue: Int8 = 0
                value.read(&flagsValue, offset: 0, length: 1)
                let flags = ChatListIndexFlags(rawValue: flagsValue)
                
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
                
                let inclusion: PeerChatListInclusion
                
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
                    preconditionFailure()
                }
                
                var tags: [UInt16]?
                if flags.contains(.hasTags) {
                    var count: UInt16 = 0
                    value.read(&count, offset: 0, length: 2)
                    var resultTags: [UInt16] = []
                    for _ in 0 ..< Int(count) {
                        var tag: UInt16 = 0
                        value.read(&tag, offset: 0, length: 2)
                        resultTags.append(tag)
                    }
                    tags = resultTags
                }
                
                let inclusionIndex = ChatListInclusionIndex(topMessageIndex: topMessageIndex, inclusion: inclusion, tags: tags)
                self.cachedIndices[peerId] = inclusionIndex
                return inclusionIndex
            } else {
                return ChatListInclusionIndex(topMessageIndex: nil, inclusion: .notSpecified, tags: nil)
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedIndices.removeAll()
        assert(self.updatedPreviousCachedIndices.isEmpty)
    }
    
    func commitWithTransactionUnreadCountDeltas(_ deltas: [PeerId: Int32], transactionParticipationInTotalUnreadCountUpdates: (added: Set<PeerId>, removed: Set<PeerId>), getPeer: (PeerId) -> Peer?, updatedTotalUnreadCount: inout Int32?) {
        if !self.updatedPreviousCachedIndices.isEmpty || !deltas.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.added.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.removed.isEmpty {
            var addedChatListPeerIds = Set<PeerId>()
            var removedChatListPeerIds = Set<PeerId>()
            
            for (peerId, previousIndex) in self.updatedPreviousCachedIndices {
                let index = self.cachedIndices[peerId]!
                if index.includedIndex(peerId: peerId) != nil {
                    if previousIndex.includedIndex(peerId: peerId) == nil {
                        addedChatListPeerIds.insert(peerId)
                    }
                } else if previousIndex.includedIndex(peerId: peerId) != nil {
                    removedChatListPeerIds.insert(peerId)
                }
                
                let writeBuffer = WriteBuffer()
                
                var flags: ChatListIndexFlags = []
                
                if index.topMessageIndex != nil {
                    flags.insert(.hasIndex)
                }
                
                if index.tags != nil {
                    flags.insert(.hasTags)
                }
                
                var flagsValue = flags.rawValue
                writeBuffer.write(&flagsValue, offset: 0, length: 1)
                
                if let topMessageIndex = index.topMessageIndex {
                    var idNamespace: Int32 = topMessageIndex.id.namespace
                    var idId: Int32 = topMessageIndex.id.id
                    var idTimestamp: Int32 = topMessageIndex.timestamp
                    writeBuffer.write(&idNamespace, offset: 0, length: 4)
                    writeBuffer.write(&idId, offset: 0, length: 4)
                    writeBuffer.write(&idTimestamp, offset: 0, length: 4)
                }
                
                switch index.inclusion {
                    case .notSpecified:
                        var key: Int8 = 0
                        writeBuffer.write(&key, offset: 0, length: 1)
                    case .never:
                        var key: Int8 = 1
                        writeBuffer.write(&key, offset: 0, length: 1)
                    case .ifHasMessages:
                        var key: Int8 = 2
                        writeBuffer.write(&key, offset: 0, length: 1)
                    case let .ifHasMessagesOrOneOf(pinningIndex, minTimestamp):
                        var key: Int8 = 3
                        writeBuffer.write(&key, offset: 0, length: 1)
                    
                        var pinningIndexValue: UInt16 = keyValueForChatListPinningIndex(pinningIndex)
                        writeBuffer.write(&pinningIndexValue, offset: 0, length: 2)
                    
                        if let minTimestamp = minTimestamp {
                            var hasMinTimestamp: Int8 = 1
                            writeBuffer.write(&hasMinTimestamp, offset: 0, length: 1)
                            
                            var minTimestampValue = minTimestamp
                            writeBuffer.write(&minTimestampValue, offset: 0, length: 4)
                        } else {
                            var hasMinTimestamp: Int8 = 0
                            writeBuffer.write(&hasMinTimestamp, offset: 0, length: 1)
                        }
                }
                
                if let tags = index.tags {
                    var count = UInt16(tags.count)
                    writeBuffer.write(&count, offset: 0, length: 2)
                    
                    for tag in tags {
                        var tagValue: UInt16 = tag
                        writeBuffer.write(&tagValue, offset: 0, length: 2)
                    }
                }
                
                withExtendedLifetime(writeBuffer, {
                    self.valueBox.set(self.table, key: self.key(peerId), value: writeBuffer.readBufferNoCopy())
                })
            }
            self.updatedPreviousCachedIndices.removeAll()
            
            let addedUnreadCountPeerIds = addedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.added)
            let removedUnreadCountPeerIds = removedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.removed)
            
            var totalUnreadCount = self.metadataTable.getChatListTotalUnreadCount()
            for (peerId, delta) in deltas {
                if !addedUnreadCountPeerIds.contains(peerId) && !removedUnreadCountPeerIds.contains(peerId) {
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(peerId) {
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationSettings = self.notificationSettingsTable.get(notificationSettingsPeerId)
                        } else {
                            notificationSettings = self.notificationSettingsTable.get(peerId)
                        }
                    }
                    if let _ = self.get(peerId).includedIndex(peerId: peerId), let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        totalUnreadCount += delta
                    }
                }
            }
            
            for peerId in addedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: true)
            }
            
            for peerId in addedUnreadCountPeerIds {
                let addedToList = addedChatListPeerIds.contains(peerId)
                let startedParticipationInUnreadCount = transactionParticipationInTotalUnreadCountUpdates.added.contains(peerId)
                
                if addedToList && startedParticipationInUnreadCount {
                    if let combinedState = self.readStateTable.getCombinedState(peerId) {
                        totalUnreadCount += combinedState.count
                    }
                } else if addedToList {
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(peerId) {
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationSettings = self.notificationSettingsTable.get(notificationSettingsPeerId)
                        } else {
                            notificationSettings = self.notificationSettingsTable.get(peerId)
                        }
                    }
                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            totalUnreadCount += combinedState.count
                        }
                    }
                } else if startedParticipationInUnreadCount {
                    if let _ = self.get(peerId).includedIndex(peerId: peerId) {
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            totalUnreadCount += combinedState.count
                        }
                    }
                } else {
                    assertionFailure()
                }
            }
            
            for peerId in removedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: false)
            }
            
            for peerId in removedUnreadCountPeerIds {
                var currentPeerUnreadCount: Int32 = 0
                if let combinedState = self.readStateTable.getCombinedState(peerId) {
                    currentPeerUnreadCount = combinedState.count
                }
                
                if let delta = deltas[peerId] {
                    currentPeerUnreadCount -= delta
                }
                
                let removedFromList = removedChatListPeerIds.contains(peerId)
                let removedFromParticipationInUnreadCount = transactionParticipationInTotalUnreadCountUpdates.removed.contains(peerId)
                if removedFromList && removedFromParticipationInUnreadCount {
                    totalUnreadCount -= currentPeerUnreadCount
                } else if removedFromList {
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(peerId) {
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationSettings = self.notificationSettingsTable.get(notificationSettingsPeerId)
                        } else {
                            notificationSettings = self.notificationSettingsTable.get(peerId)
                        }
                    }
                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        totalUnreadCount -= currentPeerUnreadCount
                    }
                } else if removedFromParticipationInUnreadCount {
                    if let _ = self.get(peerId).includedIndex(peerId: peerId) {
                        totalUnreadCount -= currentPeerUnreadCount
                    }
                } else {
                    assertionFailure()
                }
            }
            
            //assert(totalUnreadCount >= 0)
            
            if self.metadataTable.getChatListTotalUnreadCount() != totalUnreadCount {
                self.metadataTable.setChatListTotalUnreadCount(totalUnreadCount)
                updatedTotalUnreadCount = totalUnreadCount
            }
        }
    }
    
    override func beforeCommit() {
        assert(self.updatedPreviousCachedIndices.isEmpty)
    }
}
