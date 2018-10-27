import Foundation

func shouldPeerParticipateInUnreadCountStats(peer: Peer) -> Bool {
    return true
}

struct ChatListPeerInclusionIndex {
    let topMessageIndex: MessageIndex?
    let inclusion: PeerChatListInclusion
    
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

struct ChatListGroupInclusionIndex {
    let topMessageIndex: MessageIndex?
    let inclusion: GroupChatListInclusion
    
    func includedIndex() -> ChatListIndex? {
        switch self.inclusion {
            case let .ifHasMessagesOrPinningIndex(pinningIndex):
                if let topMessageIndex = self.topMessageIndex {
                    return ChatListIndex(pinningIndex: pinningIndex, messageIndex: topMessageIndex)
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
    
    private var cachedPeerIndices: [PeerId: ChatListPeerInclusionIndex] = [:]
    private var cachedGroupIndices: [PeerGroupId: ChatListGroupInclusionIndex] = [:]
    
    private var updatedPreviousPeerCachedIndices: [PeerId: ChatListPeerInclusionIndex] = [:]
    private var updatedPreviousGroupCachedIndices: [PeerGroupId: ChatListGroupInclusionIndex] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, peerNameIndexTable: PeerNameIndexTable, metadataTable: MessageHistoryMetadataTable, readStateTable: MessageHistoryReadStateTable, notificationSettingsTable: PeerNotificationSettingsTable) {
        self.peerNameIndexTable = peerNameIndexTable
        self.metadataTable = metadataTable
        self.readStateTable = readStateTable
        self.notificationSettingsTable = notificationSettingsTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: peerId.namespace)
        self.sharedKey.setInt32(4, value: peerId.id)
        assert(self.sharedKey.getInt64(0) == peerId.toInt64())
        return self.sharedKey
    }
    
    private func key(_ groupId: PeerGroupId) -> ValueBoxKey {
        self.sharedKey.setInt32(0, value: Int32.max)
        self.sharedKey.setInt32(4, value: groupId.rawValue)
        return self.sharedKey
    }
    
    func setTopMessageIndex(peerId: PeerId, index: MessageIndex?) -> ChatListPeerInclusionIndex {
        let current = self.get(peerId: peerId)
        if self.updatedPreviousPeerCachedIndices[peerId] == nil {
            self.updatedPreviousPeerCachedIndices[peerId] = current
        }
        let updated = ChatListPeerInclusionIndex(topMessageIndex: index, inclusion: current.inclusion)
        self.cachedPeerIndices[peerId] = updated
        return updated
    }
    
    func setInclusion(peerId: PeerId, inclusion: PeerChatListInclusion) -> ChatListPeerInclusionIndex {
        let current = self.get(peerId: peerId)
        if self.updatedPreviousPeerCachedIndices[peerId] == nil {
            self.updatedPreviousPeerCachedIndices[peerId] = current
        }
        let updated = ChatListPeerInclusionIndex(topMessageIndex: current.topMessageIndex, inclusion: inclusion)
        self.cachedPeerIndices[peerId] = updated
        return updated
    }
    
    func setTopMessageIndex(groupId: PeerGroupId, index: MessageIndex?) -> ChatListGroupInclusionIndex {
        let current = self.get(groupId: groupId)
        if self.updatedPreviousGroupCachedIndices[groupId] == nil {
            self.updatedPreviousGroupCachedIndices[groupId] = current
        }
        let updated = ChatListGroupInclusionIndex(topMessageIndex: index, inclusion: current.inclusion)
        self.cachedGroupIndices[groupId] = updated
        return updated
    }
    
    func setInclusion(groupId: PeerGroupId, inclusion: GroupChatListInclusion) -> ChatListGroupInclusionIndex {
        let current = self.get(groupId: groupId)
        if self.updatedPreviousGroupCachedIndices[groupId] == nil {
            self.updatedPreviousGroupCachedIndices[groupId] = current
        }
        let updated = ChatListGroupInclusionIndex(topMessageIndex: current.topMessageIndex, inclusion: inclusion)
        self.cachedGroupIndices[groupId] = updated
        return updated
    }
    
    func get(peerId: PeerId) -> ChatListPeerInclusionIndex {
        if let cached = self.cachedPeerIndices[peerId] {
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
                
                let inclusionIndex = ChatListPeerInclusionIndex(topMessageIndex: topMessageIndex, inclusion: inclusion)
                self.cachedPeerIndices[peerId] = inclusionIndex
                return inclusionIndex
            } else {
                return ChatListPeerInclusionIndex(topMessageIndex: nil, inclusion: .notSpecified)
            }
        }
    }
    
    func get(groupId: PeerGroupId) -> ChatListGroupInclusionIndex {
        if let cached = self.cachedGroupIndices[groupId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(groupId)) {
                let topMessageIndex: MessageIndex?
                
                var flagsValue: Int8 = 0
                value.read(&flagsValue, offset: 0, length: 1)
                let flags = ChatListIndexFlags(rawValue: flagsValue)
                
                if flags.contains(.hasIndex) {
                    var peerIdValue: Int64 = 0
                    value.read(&peerIdValue, offset: 0, length: 8)
                    
                    var idNamespace: Int32 = 0
                    var idId: Int32 = 0
                    var idTimestamp: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    value.read(&idId, offset: 0, length: 4)
                    value.read(&idTimestamp, offset: 0, length: 4)
                    topMessageIndex = MessageIndex(id: MessageId(peerId: PeerId(peerIdValue), namespace: idNamespace, id: idId), timestamp: idTimestamp)
                } else {
                    topMessageIndex = nil
                }
                
                let inclusion: GroupChatListInclusion
                
                var inclusionId: Int8 = 0
                value.read(&inclusionId, offset: 0, length: 1)
                if inclusionId == 0 {
                    var pinningIndexValue: UInt16 = 0
                    value.read(&pinningIndexValue, offset: 0, length: 2)
                    inclusion = .ifHasMessagesOrPinningIndex(pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue))
                } else {
                    preconditionFailure()
                }
                
                let inclusionIndex = ChatListGroupInclusionIndex(topMessageIndex: topMessageIndex, inclusion: inclusion)
                self.cachedGroupIndices[groupId] = inclusionIndex
                return inclusionIndex
            } else {
                return ChatListGroupInclusionIndex(topMessageIndex: nil, inclusion: .ifHasMessagesOrPinningIndex(pinningIndex: nil))
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedPeerIndices.removeAll()
        self.cachedGroupIndices.removeAll()
        assert(self.updatedPreviousPeerCachedIndices.isEmpty)
        assert(self.updatedPreviousGroupCachedIndices.isEmpty)
    }
    
    func commitWithTransaction(alteredInitialPeerCombinedReadStates: [PeerId: CombinedPeerReadState], transactionParticipationInTotalUnreadCountUpdates: (added: Set<PeerId>, removed: Set<PeerId>), getCombinedPeerReadState: (PeerId) -> CombinedPeerReadState?, getPeer: (PeerId) -> Peer?, updatedTotalUnreadState: inout ChatListTotalUnreadState?) {
        if !self.updatedPreviousPeerCachedIndices.isEmpty || !alteredInitialPeerCombinedReadStates.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.added.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.removed.isEmpty {
            var addedChatListPeerIds = Set<PeerId>()
            var removedChatListPeerIds = Set<PeerId>()
            
            for (peerId, previousIndex) in self.updatedPreviousPeerCachedIndices {
                let index = self.cachedPeerIndices[peerId]!
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
                
                withExtendedLifetime(writeBuffer, {
                    self.valueBox.set(self.table, key: self.key(peerId), value: writeBuffer.readBufferNoCopy())
                })
            }
            self.updatedPreviousPeerCachedIndices.removeAll()
            
            let addedUnreadCountPeerIds = addedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.added)
            let removedUnreadCountPeerIds = removedChatListPeerIds.union(transactionParticipationInTotalUnreadCountUpdates.removed)
            
            var totalUnreadState = self.metadataTable.getChatListTotalUnreadState()
            for (peerId, initialState) in alteredInitialPeerCombinedReadStates {
                guard let peer = getPeer(peerId) else {
                    continue
                }
                var notificationSettings: PeerNotificationSettings?
                if let peer = getPeer(peerId) {
                    if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                        notificationSettings = self.notificationSettingsTable.getEffective(notificationSettingsPeerId)
                    } else {
                        notificationSettings = self.notificationSettingsTable.getEffective(peerId)
                    }
                }
                
                let initialCount = initialState.count
                let initialIsUnread = initialState.isUnread
                let currentCount = getCombinedPeerReadState(peerId)?.count ?? 0
                let currentIsUnread = getCombinedPeerReadState(peerId)?.isUnread ?? false
                let delta = currentCount - initialCount
                let chatDelta: Int32 = (currentIsUnread ? 1 : 0) - (initialIsUnread ? 1 : 0)
                if !addedUnreadCountPeerIds.contains(peerId) && !removedUnreadCountPeerIds.contains(peerId) {
                    
                    if let _ = self.get(peerId: peerId).includedIndex(peerId: peerId) {
                        totalUnreadState.absoluteCounters.messageCount += delta
                        totalUnreadState.absoluteCounters.chatCount += chatDelta
                        if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                            totalUnreadState.filteredCounters.messageCount += delta
                            totalUnreadState.filteredCounters.chatCount += chatDelta
                        }
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
                        totalUnreadState.absoluteCounters.messageCount += combinedState.count
                        totalUnreadState.filteredCounters.messageCount += combinedState.count
                        if combinedState.isUnread {
                            totalUnreadState.absoluteCounters.chatCount += 1
                            totalUnreadState.filteredCounters.chatCount += 1
                        }
                    }
                } else if addedToList {
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(peerId) {
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationSettings = self.notificationSettingsTable.getEffective(notificationSettingsPeerId)
                        } else {
                            notificationSettings = self.notificationSettingsTable.getEffective(peerId)
                        }
                    }
                    if let combinedState = self.readStateTable.getCombinedState(peerId) {
                        totalUnreadState.absoluteCounters.messageCount += combinedState.count
                        if combinedState.isUnread {
                            totalUnreadState.absoluteCounters.chatCount += 1
                        }
                        if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                            totalUnreadState.filteredCounters.messageCount += combinedState.count
                            if combinedState.isUnread {
                                totalUnreadState.filteredCounters.chatCount += 1
                            }
                        }
                    }
                } else if startedParticipationInUnreadCount {
                    if let _ = self.get(peerId: peerId).includedIndex(peerId: peerId) {
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            totalUnreadState.filteredCounters.messageCount += combinedState.count
                            if combinedState.isUnread {
                                totalUnreadState.filteredCounters.chatCount += 1
                            }
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
                var currentPeerChatUnreadCount: Int32 = 0
                var initialPeerChatUnreadCount: Int32 = 0
                if let combinedState = self.readStateTable.getCombinedState(peerId) {
                    currentPeerUnreadCount = combinedState.count
                    currentPeerChatUnreadCount = combinedState.isUnread ? 1 : 0
                    initialPeerChatUnreadCount = currentPeerChatUnreadCount
                }
                
                if let initialState = alteredInitialPeerCombinedReadStates[peerId] {
                    let initialCount = initialState.count
                    let initialIsUnread = initialState.isUnread
                    let currentCount = getCombinedPeerReadState(peerId)?.count ?? 0
                    let currentIsUnread = getCombinedPeerReadState(peerId)?.isUnread ?? false
                    let delta = currentCount - initialCount
                    let chatDelta: Int32 = (currentIsUnread ? 1 : 0) - (initialIsUnread ? 1 : 0)
                    currentPeerUnreadCount -= delta
                    initialPeerChatUnreadCount -= chatDelta
                }
                
                let removedFromList = removedChatListPeerIds.contains(peerId)
                let removedFromParticipationInUnreadCount = transactionParticipationInTotalUnreadCountUpdates.removed.contains(peerId)
                if removedFromList && removedFromParticipationInUnreadCount {
                    totalUnreadState.absoluteCounters.messageCount -= currentPeerUnreadCount
                    totalUnreadState.filteredCounters.messageCount -= currentPeerUnreadCount
                    totalUnreadState.absoluteCounters.chatCount -= currentPeerChatUnreadCount
                    totalUnreadState.filteredCounters.chatCount -= currentPeerChatUnreadCount
                } else if removedFromList {
                    var notificationSettings: PeerNotificationSettings?
                    if let peer = getPeer(peerId) {
                        if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                            notificationSettings = self.notificationSettingsTable.getEffective(notificationSettingsPeerId)
                        } else {
                            notificationSettings = self.notificationSettingsTable.getEffective(peerId)
                        }
                    }
                    totalUnreadState.absoluteCounters.messageCount -= currentPeerUnreadCount
                    totalUnreadState.absoluteCounters.chatCount -= initialPeerChatUnreadCount
                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        totalUnreadState.filteredCounters.messageCount -= currentPeerUnreadCount
                        totalUnreadState.filteredCounters.chatCount -= initialPeerChatUnreadCount
                    }
                } else if removedFromParticipationInUnreadCount {
                    if let _ = self.get(peerId: peerId).includedIndex(peerId: peerId) {
                        totalUnreadState.filteredCounters.messageCount -= currentPeerUnreadCount
                        totalUnreadState.filteredCounters.chatCount -= currentPeerChatUnreadCount
                    }
                } else {
                    assertionFailure()
                }
            }
            
            //assert(totalUnreadCount >= 0)
            
            totalUnreadState.absoluteCounters.messageCount = max(0, totalUnreadState.absoluteCounters.messageCount)
            totalUnreadState.filteredCounters.messageCount = max(0, totalUnreadState.filteredCounters.messageCount)
            totalUnreadState.absoluteCounters.chatCount = max(0, totalUnreadState.absoluteCounters.chatCount)
            totalUnreadState.filteredCounters.chatCount = max(0, totalUnreadState.filteredCounters.chatCount)
            
            if self.metadataTable.getChatListTotalUnreadState() != totalUnreadState {
                self.metadataTable.setChatListTotalUnreadState(totalUnreadState)
                updatedTotalUnreadState = totalUnreadState
            }
        }
        
        if !self.updatedPreviousGroupCachedIndices.isEmpty {
            let writeBuffer = WriteBuffer()
            for (groupId, _) in self.updatedPreviousGroupCachedIndices {
                writeBuffer.reset()
                
                let index = self.cachedGroupIndices[groupId]!
                
                var flags: ChatListIndexFlags = []
                
                if index.topMessageIndex != nil {
                    flags.insert(.hasIndex)
                }
                
                var flagsValue = flags.rawValue
                writeBuffer.write(&flagsValue, offset: 0, length: 1)
                
                if let topMessageIndex = index.topMessageIndex {
                    var peerIdValue: Int64 = topMessageIndex.id.peerId.toInt64()
                    writeBuffer.write(&peerIdValue, offset: 0, length: 8)
                    var idNamespace: Int32 = topMessageIndex.id.namespace
                    var idId: Int32 = topMessageIndex.id.id
                    var idTimestamp: Int32 = topMessageIndex.timestamp
                    writeBuffer.write(&idNamespace, offset: 0, length: 4)
                    writeBuffer.write(&idId, offset: 0, length: 4)
                    writeBuffer.write(&idTimestamp, offset: 0, length: 4)
                }
                
                switch index.inclusion {
                    case let .ifHasMessagesOrPinningIndex(pinningIndex):
                        var key: Int8 = 0
                        writeBuffer.write(&key, offset: 0, length: 1)
                        
                        var pinningIndexValue: UInt16 = keyValueForChatListPinningIndex(pinningIndex)
                        writeBuffer.write(&pinningIndexValue, offset: 0, length: 2)
                }
                
                withExtendedLifetime(writeBuffer, {
                    self.valueBox.set(self.table, key: self.key(groupId), value: writeBuffer.readBufferNoCopy())
                })
            }
            
            self.updatedPreviousGroupCachedIndices.removeAll()
        }
    }
    
    override func beforeCommit() {
        assert(self.updatedPreviousPeerCachedIndices.isEmpty)
        assert(self.updatedPreviousGroupCachedIndices.isEmpty)
    }
    
    func debugReindexUnreadCounts(postbox: Postbox) -> ChatListTotalUnreadState {
        var peerIds: [PeerId] = []
        self.valueBox.scanInt64(self.table, values: { key, _ in
            let peerId = PeerId(key)
            if peerId.namespace != Int32.max {
                peerIds.append(peerId)
            }
            return true
        })
        var state = ChatListTotalUnreadState(absoluteCounters: ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0), filteredCounters: ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0))
        for peerId in peerIds {
            guard let peer = postbox.peerTable.get(peerId) else {
                continue
            }
            let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
            let inclusion = self.get(peerId: peerId)
            if inclusion.includedIndex(peerId: peerId) != nil {
                if let combinedState = postbox.readStateTable.getCombinedState(peerId) {
                    var peerMessageCount = combinedState.count
                    
                    let include = shouldPeerParticipateInUnreadCountStats(peer: peer)
                    if include {
                        state.absoluteCounters.messageCount = state.absoluteCounters.messageCount &+ peerMessageCount
                        if state.absoluteCounters.messageCount < 0 {
                            state.absoluteCounters.messageCount = 0
                        }
                        if combinedState.isUnread {
                            state.absoluteCounters.chatCount += 1
                        }
                    }
                    
                    if include, let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        state.filteredCounters.messageCount = state.filteredCounters.messageCount &+ combinedState.count
                        if state.filteredCounters.messageCount < 0 {
                            state.filteredCounters.messageCount = 0
                        }
                        if combinedState.isUnread {
                            state.filteredCounters.chatCount += 1
                        }
                    }
                }
            }
        }
        
        return state
    }
}
