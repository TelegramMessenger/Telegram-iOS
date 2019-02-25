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
    
    func commitWithTransaction(postbox: Postbox, alteredInitialPeerCombinedReadStates: [PeerId: CombinedPeerReadState], updatedPeers: [(Peer?, Peer)], transactionParticipationInTotalUnreadCountUpdates: (added: Set<PeerId>, removed: Set<PeerId>), updatedTotalUnreadState: inout ChatListTotalUnreadState?) {
        var updatedPeerTags: [PeerId: (previous: PeerSummaryCounterTags, updated: PeerSummaryCounterTags)] = [:]
        for (previous, updated) in updatedPeers {
            let previousTags: PeerSummaryCounterTags
            if let previous = previous {
                previousTags = postbox.seedConfiguration.peerSummaryCounterTags(previous)
            } else {
                previousTags = []
            }
            let updatedTags = postbox.seedConfiguration.peerSummaryCounterTags(updated)
            if previousTags != updatedTags {
                updatedPeerTags[updated.id] = (previousTags, updatedTags)
            }
        }
        
        if !self.updatedPreviousPeerCachedIndices.isEmpty || !alteredInitialPeerCombinedReadStates.isEmpty || !updatedPeerTags.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.added.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.removed.isEmpty {
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
            
            for peerId in addedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: true)
            }
            
            for peerId in removedChatListPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: false)
            }
            
            var totalUnreadState = self.metadataTable.getChatListTotalUnreadState()
            
            var alteredPeerIds = Set<PeerId>()
            for (peerId, _) in alteredInitialPeerCombinedReadStates {
                alteredPeerIds.insert(peerId)
            }
            alteredPeerIds.formUnion(addedChatListPeerIds)
            alteredPeerIds.formUnion(removedChatListPeerIds)
            alteredPeerIds.formUnion(transactionParticipationInTotalUnreadCountUpdates.added)
            alteredPeerIds.formUnion(transactionParticipationInTotalUnreadCountUpdates.removed)
            
            for peerId in updatedPeerTags.keys {
                alteredPeerIds.insert(peerId)
            }
            
            let alterTags: (PeerId, PeerSummaryCounterTags, (ChatListTotalUnreadCounters, ChatListTotalUnreadCounters) -> (ChatListTotalUnreadCounters, ChatListTotalUnreadCounters)) -> Void = { peerId, tag, f in
                if totalUnreadState.absoluteCounters[tag] == nil {
                    totalUnreadState.absoluteCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                }
                if totalUnreadState.filteredCounters[tag] == nil {
                    totalUnreadState.filteredCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                }
                var (updatedAbsoluteCounters, updatedFilteredCounters) = f(totalUnreadState.absoluteCounters[tag]!, totalUnreadState.filteredCounters[tag]!)
                if updatedAbsoluteCounters.messageCount < 0 {
                    updatedAbsoluteCounters.messageCount = 0
                }
                if updatedAbsoluteCounters.chatCount < 0 {
                    updatedAbsoluteCounters.chatCount = 0
                }
                if updatedFilteredCounters.messageCount < 0 {
                    updatedFilteredCounters.messageCount = 0
                }
                if updatedFilteredCounters.chatCount < 0 {
                    updatedFilteredCounters.chatCount = 0
                }
                totalUnreadState.absoluteCounters[tag] = updatedAbsoluteCounters
                totalUnreadState.filteredCounters[tag] = updatedFilteredCounters
            }
            
            for peerId in alteredPeerIds {
                guard let peer = postbox.peerTable.get(peerId) else {
                    continue
                }
                let notificationPeerId: PeerId = peer.associatedPeerId ?? peerId
                let initialReadState = alteredInitialPeerCombinedReadStates[peerId] ?? postbox.readStateTable.getCombinedState(peerId)
                let currentReadState = postbox.readStateTable.getCombinedState(peerId)
                
                var initialValue: (Int32, Bool, Bool) = (0, false, false)
                var currentValue: (Int32, Bool, Bool) = (0, false, false)
                if addedChatListPeerIds.contains(peerId) {
                    if let currentReadState = currentReadState {
                        currentValue = (currentReadState.count, currentReadState.isUnread, currentReadState.markedUnread)
                    }
                } else if removedChatListPeerIds.contains(peerId) {
                    if let initialReadState = initialReadState {
                        initialValue = (initialReadState.count, initialReadState.isUnread, initialReadState.markedUnread)
                    }
                } else {
                    if self.get(peerId: peerId).includedIndex(peerId: peerId) != nil {
                        if let initialReadState = initialReadState {
                            initialValue = (initialReadState.count, initialReadState.isUnread, initialReadState.markedUnread)
                        }
                        if let currentReadState = currentReadState {
                            currentValue = (currentReadState.count, currentReadState.isUnread, currentReadState.markedUnread)
                        }
                    }
                }
                var initialFilteredValue: (Int32, Bool, Bool) = initialValue
                var currentFilteredValue: (Int32, Bool, Bool) = currentValue
                if transactionParticipationInTotalUnreadCountUpdates.added.contains(peerId) {
                    initialFilteredValue = (0, false, false)
                } else if transactionParticipationInTotalUnreadCountUpdates.removed.contains(peerId) {
                    currentFilteredValue = (0, false, false)
                } else {
                    if let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(notificationPeerId), !notificationSettings.isRemovedFromTotalUnreadCount {
                    } else {
                        initialFilteredValue = (0, false, false)
                        currentFilteredValue = (0, false, false)
                    }
                }
                
                var keptTags: PeerSummaryCounterTags = postbox.seedConfiguration.peerSummaryCounterTags(peer)
                if let (removedTags, addedTags) = updatedPeerTags[peerId] {
                    keptTags.remove(removedTags)
                    keptTags.remove(addedTags)
                    
                    for tag in removedTags {
                        alterTags(peerId, tag, { absolute, filtered in
                            var absolute = absolute
                            var filtered = filtered
                            absolute.messageCount -= initialValue.0
                            if initialValue.1 {
                                absolute.chatCount -= 1
                            }
                            if initialValue.2 && initialValue.0 == 0 {
                                absolute.messageCount -= 1
                            }
                            filtered.messageCount -= initialFilteredValue.0
                            if initialFilteredValue.1 {
                                filtered.chatCount -= 1
                            }
                            if initialFilteredValue.2 && initialFilteredValue.0 == 0 {
                                filtered.messageCount -= 1
                            }
                            return (absolute, filtered)
                        })
                    }
                    for tag in addedTags {
                        alterTags(peerId, tag, { absolute, filtered in
                            var absolute = absolute
                            var filtered = filtered
                            absolute.messageCount += currentValue.0
                            if currentValue.2 && currentValue.0 == 0 {
                                absolute.messageCount += 1
                            }
                            if currentValue.1 {
                                absolute.chatCount += 1
                            }
                            filtered.messageCount += currentFilteredValue.0
                            if currentFilteredValue.1 {
                                filtered.chatCount += 1
                            }
                            if currentFilteredValue.2 && currentFilteredValue.0 == 0 {
                                filtered.messageCount += 1
                            }
                            return (absolute, filtered)
                        })
                    }
                }
                
                for tag in keptTags {
                    alterTags(peerId, tag, { absolute, filtered in
                        var absolute = absolute
                        var filtered = filtered
                        
                        let chatDifference: Int32
                        if initialValue.1 != currentValue.1 {
                            chatDifference = initialValue.1 ? -1 : 1
                        } else {
                            chatDifference = 0
                        }
                        
                        let currentUnreadMark: Int32 = currentValue.2 ? 1 : 0
                        let initialUnreadMark: Int32 = initialValue.2 ? 1 : 0
                        let messageDifference = max(currentValue.0, currentUnreadMark) - max(initialValue.0, initialUnreadMark)
                        
                        let chatFilteredDifference: Int32
                        if initialFilteredValue.1 != currentFilteredValue.1 {
                            chatFilteredDifference = initialFilteredValue.1 ? -1 : 1
                        } else {
                            chatFilteredDifference = 0
                        }
                        let currentFilteredUnreadMark: Int32 = currentFilteredValue.2 ? 1 : 0
                        let initialFilteredUnreadMark: Int32 = initialFilteredValue.2 ? 1 : 0
                        let messageFilteredDifference = max(currentFilteredValue.0, currentFilteredUnreadMark) - max(initialFilteredValue.0, initialFilteredUnreadMark)
                        
                        absolute.messageCount += messageDifference
                        absolute.chatCount += chatDifference
                        filtered.messageCount += messageFilteredDifference
                        filtered.chatCount += chatFilteredDifference
                        
                        return (absolute, filtered)
                    })
                }
            }
            var removeAbsoluteKeys = PeerSummaryCounterTags()
            var removeFilteredKeys = PeerSummaryCounterTags()
            for (tag, value) in totalUnreadState.absoluteCounters {
                if value.chatCount == 0 && value.messageCount == 0 {
                    removeAbsoluteKeys.insert(tag)
                }
            }
            for (tag, value) in totalUnreadState.filteredCounters {
                if value.chatCount == 0 && value.messageCount == 0 {
                    removeFilteredKeys.insert(tag)
                }
            }
            for tag in removeAbsoluteKeys {
                totalUnreadState.absoluteCounters.removeValue(forKey: tag)
            }
            for tag in removeFilteredKeys {
                totalUnreadState.filteredCounters.removeValue(forKey: tag)
            }
            
            /*#if DEBUG && targetEnvironment(simulator)
            let reindexedCounts = self.debugReindexUnreadCounts(postbox: postbox)
            
            if reindexedCounts != totalUnreadState {
                print("reindexedCounts \(reindexedCounts) != totalUnreadState \(totalUnreadState)")
                totalUnreadState = reindexedCounts
            }
            #endif*/
            
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
        var state = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
        for peerId in peerIds {
            guard let peer = postbox.peerTable.get(peerId) else {
                continue
            }
            let notificationPeerId: PeerId = peer.associatedPeerId ?? peerId
            let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(notificationPeerId)
            let inclusion = self.get(peerId: peerId)
            if inclusion.includedIndex(peerId: peerId) != nil {
                if let combinedState = postbox.readStateTable.getCombinedState(peerId) {
                    let peerMessageCount = combinedState.count
                    let summaryTags = postbox.seedConfiguration.peerSummaryCounterTags(peer)
                    
                    for tag in summaryTags {
                        if state.absoluteCounters[tag] == nil {
                            state.absoluteCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                        }
                        var messageCount = state.absoluteCounters[tag]!.messageCount
                        messageCount = messageCount &+ peerMessageCount
                        if messageCount < 0 {
                            messageCount = 0
                        }
                        if combinedState.isUnread {
                            state.absoluteCounters[tag]!.chatCount += 1
                        }
                        if combinedState.markedUnread {
                            messageCount = max(1, messageCount)
                        }
                        state.absoluteCounters[tag]!.messageCount = messageCount
                    }
                    
                    if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                        for tag in summaryTags {
                            if state.filteredCounters[tag] == nil {
                                state.filteredCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                            }
                            var messageCount = state.filteredCounters[tag]!.messageCount
                            messageCount = messageCount &+ peerMessageCount
                            if messageCount < 0 {
                                messageCount = 0
                            }
                            if combinedState.isUnread {
                                state.filteredCounters[tag]!.chatCount += 1
                            }
                            if combinedState.markedUnread {
                                messageCount = max(1, messageCount)
                            }
                            state.filteredCounters[tag]!.messageCount = messageCount
                        }
                    }
                }
            }
        }
        
        var removeAbsoluteKeys = PeerSummaryCounterTags()
        var removeFilteredKeys = PeerSummaryCounterTags()
        for (tag, value) in state.absoluteCounters {
            if value.chatCount == 0 && value.messageCount == 0 {
                removeAbsoluteKeys.insert(tag)
            }
        }
        for (tag, value) in state.filteredCounters {
            if value.chatCount == 0 && value.messageCount == 0 {
                removeFilteredKeys.insert(tag)
            }
        }
        for tag in removeAbsoluteKeys {
            state.absoluteCounters.removeValue(forKey: tag)
        }
        for tag in removeFilteredKeys {
            state.filteredCounters.removeValue(forKey: tag)
        }
        
        return state
    }
}
