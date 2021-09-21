import Foundation

struct ChatListPeerInclusionIndex {
    let topMessageIndex: MessageIndex?
    let inclusion: PeerChatListInclusion
    
    func includedIndex(peerId: PeerId) -> (PeerGroupId, ChatListIndex)? {
        switch inclusion {
            case .notIncluded:
                return nil
            case let .ifHasMessagesOrOneOf(groupId, pinningIndex, minTimestamp):
                if let minTimestamp = minTimestamp {
                    if let topMessageIndex = self.topMessageIndex, topMessageIndex.timestamp >= minTimestamp {
                        return (groupId, ChatListIndex(pinningIndex: pinningIndex, messageIndex: topMessageIndex))
                    } else {
                        return (groupId, ChatListIndex(pinningIndex: pinningIndex, messageIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: minTimestamp)))
                    }
                } else if let topMessageIndex = self.topMessageIndex {
                    return (groupId, ChatListIndex(pinningIndex: pinningIndex, messageIndex: topMessageIndex))
                } else if let pinningIndex = pinningIndex {
                    return (groupId, ChatListIndex(pinningIndex: pinningIndex, messageIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: 0)))
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
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private let peerNameIndexTable: PeerNameIndexTable
    private let metadataTable: MessageHistoryMetadataTable
    private let readStateTable: MessageHistoryReadStateTable
    private let notificationSettingsTable: PeerNotificationSettingsTable
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedPeerIndices: [PeerId: ChatListPeerInclusionIndex] = [:]
    
    private var updatedPreviousPeerCachedIndices: [PeerId: ChatListPeerInclusionIndex] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, peerNameIndexTable: PeerNameIndexTable, metadataTable: MessageHistoryMetadataTable, readStateTable: MessageHistoryReadStateTable, notificationSettingsTable: PeerNotificationSettingsTable) {
        self.peerNameIndexTable = peerNameIndexTable
        self.metadataTable = metadataTable
        self.readStateTable = readStateTable
        self.notificationSettingsTable = notificationSettingsTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
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
                    inclusion = .notIncluded
                } else if inclusionId == 1 {
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
                    
                    var groupIdValue: Int32 = 0
                    value.read(&groupIdValue, offset: 0, length: 4)
                    
                    inclusion = .ifHasMessagesOrOneOf(groupId: PeerGroupId(rawValue: groupIdValue), pinningIndex: chatListPinningIndexFromKeyValue(pinningIndexValue), minTimestamp: minTimestamp)
                } else {
                    preconditionFailure()
                }
                
                let inclusionIndex = ChatListPeerInclusionIndex(topMessageIndex: topMessageIndex, inclusion: inclusion)
                self.cachedPeerIndices[peerId] = inclusionIndex
                return inclusionIndex
            } else {
                let inclusionIndex = ChatListPeerInclusionIndex(topMessageIndex: nil, inclusion: .notIncluded)
                self.cachedPeerIndices[peerId] = inclusionIndex
                return inclusionIndex
            }
        }
    }
    
    func getAllPeerIds() -> [PeerId] {
        var peerIds: [PeerId] = []
        self.valueBox.scanInt64(self.table, keys: { key in
            peerIds.append(PeerId(key))
            return true
        })
        return peerIds
    }
    
    override func clearMemoryCache() {
        self.cachedPeerIndices.removeAll()
        assert(self.updatedPreviousPeerCachedIndices.isEmpty)
    }
    
    func commitWithTransaction(postbox: PostboxImpl, currentTransaction: Transaction, alteredInitialPeerCombinedReadStates: [PeerId: CombinedPeerReadState], updatedPeers: [((Peer, Bool)?, (Peer, Bool))], transactionParticipationInTotalUnreadCountUpdates: (added: Set<PeerId>, removed: Set<PeerId>), updatedTotalUnreadStates: inout [PeerGroupId: ChatListTotalUnreadState], updatedGroupTotalUnreadSummaries: inout [PeerGroupId: PeerGroupUnreadCountersCombinedSummary], currentUpdatedGroupSummarySynchronizeOperations: inout [PeerGroupAndNamespace: Bool]) {
        var updatedPeerTags: [PeerId: (previous: PeerSummaryCounterTags, updated: PeerSummaryCounterTags)] = [:]
        for (previous, updated) in updatedPeers {
            let previousTags: PeerSummaryCounterTags
            if let (previous, previousIsContact) = previous {
                previousTags = postbox.seedConfiguration.peerSummaryCounterTags(previous, previousIsContact)
            } else {
                previousTags = []
            }
            let updatedTags = postbox.seedConfiguration.peerSummaryCounterTags(updated.0, updated.1)
            if previousTags != updatedTags {
                updatedPeerTags[updated.0.id] = (previousTags, updatedTags)
            }
        }
        
        if !self.updatedPreviousPeerCachedIndices.isEmpty || !alteredInitialPeerCombinedReadStates.isEmpty || !updatedPeerTags.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.added.isEmpty || !transactionParticipationInTotalUnreadCountUpdates.removed.isEmpty {
            var addedToGroupPeerIds: [PeerId: PeerGroupId] = [:]
            var removedFromGroupPeerIds: [PeerId: PeerGroupId] = [:]
            var addedToIndexPeerIds = Set<PeerId>()
            var removedFromIndexPeerIds = Set<PeerId>()
            
            for (peerId, previousIndex) in self.updatedPreviousPeerCachedIndices {
                let index = self.cachedPeerIndices[peerId]!
                if let (currentGroupId, _) = index.includedIndex(peerId: peerId) {
                    let previousGroupId = previousIndex.includedIndex(peerId: peerId)?.0
                    if previousGroupId != currentGroupId {
                        addedToGroupPeerIds[peerId] = currentGroupId
                        if let previousGroupId = previousGroupId {
                            removedFromGroupPeerIds[peerId] = previousGroupId
                        } else {
                            addedToIndexPeerIds.insert(peerId)
                        }
                    }
                } else if let (previousGroupId, _) = previousIndex.includedIndex(peerId: peerId) {
                    removedFromGroupPeerIds[peerId] = previousGroupId
                    removedFromIndexPeerIds.insert(peerId)
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
                    case .notIncluded:
                        var key: Int8 = 0
                        writeBuffer.write(&key, offset: 0, length: 1)
                    case let .ifHasMessagesOrOneOf(groupId, pinningIndex, minTimestamp):
                        var key: Int8 = 1
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
                    
                        var groupIdValue = groupId.rawValue
                        writeBuffer.write(&groupIdValue, offset: 0, length: 4)
                }
                
                withExtendedLifetime(writeBuffer, {
                    self.valueBox.set(self.table, key: self.key(peerId), value: writeBuffer.readBufferNoCopy())
                })
            }
            self.updatedPreviousPeerCachedIndices.removeAll()
            
            for peerId in addedToIndexPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: true)
            }
            
            for peerId in removedFromIndexPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: false)
            }
            
            var alteredPeerIds = Set<PeerId>()
            for (peerId, _) in alteredInitialPeerCombinedReadStates {
                alteredPeerIds.insert(peerId)
            }
            alteredPeerIds.formUnion(addedToGroupPeerIds.keys)
            alteredPeerIds.formUnion(removedFromGroupPeerIds.keys)
            alteredPeerIds.formUnion(transactionParticipationInTotalUnreadCountUpdates.added)
            alteredPeerIds.formUnion(transactionParticipationInTotalUnreadCountUpdates.removed)
            
            for peerId in updatedPeerTags.keys {
                alteredPeerIds.insert(peerId)
            }
            
            var additionalAlteredPeerIds = Set<PeerId>()
            for peerId in alteredPeerIds {
                guard let peer = postbox.peerTable.get(peerId) else {
                    continue
                }
                if let associatedPeerId = peer.associatedPeerId {
                    additionalAlteredPeerIds.insert(associatedPeerId)
                }
                if let reverseAssociatedPeerId = postbox.reverseAssociatedPeerTable.get(peerId: peerId).first {
                    additionalAlteredPeerIds.insert(reverseAssociatedPeerId)
                }
            }
            alteredPeerIds.formUnion(additionalAlteredPeerIds)
            
            func alterTags(_ totalUnreadState: inout ChatListTotalUnreadState, _ peerId: PeerId, _ tag: PeerSummaryCounterTags, _ f: (ChatListTotalUnreadCounters, ChatListTotalUnreadCounters) -> (ChatListTotalUnreadCounters, ChatListTotalUnreadCounters)) {
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
            
            func alterNamespace(summary: inout PeerGroupUnreadCountersSummary, previousState: PeerReadState?, updatedState: PeerReadState?) {
                let previousCount = previousState?.count ?? 0
                let updatedCount = updatedState?.count ?? 0
                if previousCount != updatedCount {
                    if (previousCount != 0) != (updatedCount != 0) {
                        if updatedCount != 0 {
                            summary.all.chatCount += 1
                        } else {
                            summary.all.chatCount -= 1
                            summary.all.chatCount = max(0, summary.all.chatCount)
                        }
                    }
                    summary.all.messageCount += updatedCount - previousCount
                    summary.all.messageCount = max(0, summary.all.messageCount)
                }
            }
            
            var updatedTotalStates: [PeerGroupId: ChatListTotalUnreadState] = [:]
            var updatedTotalUnreadSummaries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary] = [:]
            
            let globalNotificationSettings = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
            
            for peerId in alteredPeerIds {
                guard let peer = postbox.peerTable.get(peerId) else {
                    continue
                }
                let isContact = postbox.contactsTable.isContact(peerId: peerId)
                let notificationPeerId: PeerId = peer.associatedPeerId ?? peerId
                let initialReadState = alteredInitialPeerCombinedReadStates[peerId] ?? postbox.readStateTable.getCombinedState(peerId)
                let currentReadState = postbox.readStateTable.getCombinedState(peerId)
                
                var groupIds: [PeerGroupId] = []
                if let (groupId, _) = self.get(peerId: peerId).includedIndex(peerId: peerId) {
                    groupIds.append(groupId)
                }
                if let groupId = addedToGroupPeerIds[peerId] {
                    if !groupIds.contains(groupId) {
                        groupIds.append(groupId)
                    }
                }
                if let groupId = removedFromGroupPeerIds[peerId] {
                    if !groupIds.contains(groupId) {
                        groupIds.append(groupId)
                    }
                }
                
                for groupId in groupIds {
                    var totalGroupUnreadState: ChatListTotalUnreadState
                    var summary: PeerGroupUnreadCountersCombinedSummary
                    if let current = updatedTotalStates[groupId] {
                        totalGroupUnreadState = current
                    } else {
                        totalGroupUnreadState = postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: groupId)
                    }
                    if let current = updatedTotalUnreadSummaries[groupId] {
                        summary = current
                    } else {
                        summary = postbox.groupMessageStatsTable.get(groupId: groupId)
                    }
                    
                    var initialValue: (Int32, Bool, Bool) = (0, false, false)
                    var currentValue: (Int32, Bool, Bool) = (0, false, false)
                    
                    var initialStates: CombinedPeerReadState = CombinedPeerReadState(states: [])
                    var currentStates: CombinedPeerReadState = CombinedPeerReadState(states: [])
                    
                    if addedToGroupPeerIds[peerId] == groupId {
                        if let currentReadState = currentReadState {
                            currentValue = (currentReadState.count, currentReadState.isUnread, currentReadState.markedUnread)
                            currentStates = currentReadState
                        }
                    } else if removedFromGroupPeerIds[peerId] == groupId {
                        if let initialReadState = initialReadState {
                            initialValue = (initialReadState.count, initialReadState.isUnread, initialReadState.markedUnread)
                            initialStates = initialReadState
                        }
                    } else {
                        if self.get(peerId: peerId).includedIndex(peerId: peerId)?.0 == groupId {
                            if let initialReadState = initialReadState {
                                initialValue = (initialReadState.count, initialReadState.isUnread, initialReadState.markedUnread)
                                initialStates = initialReadState
                            }
                            if let currentReadState = currentReadState {
                                currentValue = (currentReadState.count, currentReadState.isUnread, currentReadState.markedUnread)
                                currentStates = currentReadState
                            }
                        }
                    }
                    
                    var initialFilteredValue: (Int32, Bool, Bool) = initialValue
                    var currentFilteredValue: (Int32, Bool, Bool) = currentValue
                    
                    if transactionParticipationInTotalUnreadCountUpdates.added.contains(peerId) || transactionParticipationInTotalUnreadCountUpdates.added.contains(notificationPeerId) {
                        initialFilteredValue = (0, false, false)
                    } else if transactionParticipationInTotalUnreadCountUpdates.removed.contains(peerId) || transactionParticipationInTotalUnreadCountUpdates.removed.contains(notificationPeerId) {
                        currentFilteredValue = (0, false, false)
                    } else {
                        let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettings, peer: peer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(notificationPeerId))
                        
                        if isRemovedFromTotalUnreadCount {
                            initialFilteredValue = (0, false, false)
                            currentFilteredValue = (0, false, false)
                        }
                    }
                    
                    var keptTags: PeerSummaryCounterTags = postbox.seedConfiguration.peerSummaryCounterTags(peer, isContact)
                    if let (removedTags, addedTags) = updatedPeerTags[peerId] {
                        keptTags.remove(removedTags)
                        keptTags.remove(addedTags)
                        
                        for tag in removedTags {
                            alterTags(&totalGroupUnreadState, peerId, tag, { absolute, filtered in
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
                            alterTags(&totalGroupUnreadState, peerId, tag, { absolute, filtered in
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
                        alterTags(&totalGroupUnreadState, peerId, tag, { absolute, filtered in
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
                    
                    updatedTotalStates[groupId] = totalGroupUnreadState
                    
                    var namespaces: [MessageId.Namespace] = []
                    for (namespace, _) in initialStates.states {
                        namespaces.append(namespace)
                    }
                    for (namespace, _) in currentStates.states {
                        if !namespaces.contains(namespace) {
                            namespaces.append(namespace)
                        }
                    }
                    
                    for namespace in namespaces {
                        if postbox.seedConfiguration.messageNamespacesRequiringGroupStatsValidation.contains(namespace) && addedToGroupPeerIds[peerId] == groupId && removedFromGroupPeerIds[peerId] == nil {
                            postbox.synchronizeGroupMessageStatsTable.set(groupId: groupId, namespace: namespace, needsValidation: true, operations: &currentUpdatedGroupSummarySynchronizeOperations)
                        } else {
                            var namespaceSummary = summary.namespaces[namespace] ?? PeerGroupUnreadCountersSummary(all: PeerGroupUnreadCounters(messageCount: 0, chatCount: 0))
                            let previousState = initialStates.states.first(where: { $0.0 == namespace })?.1
                            let updatedState = currentStates.states.first(where: { $0.0 == namespace })?.1
                            alterNamespace(summary: &namespaceSummary, previousState: previousState, updatedState: updatedState)
                            summary.namespaces[namespace] = namespaceSummary
                        }
                    }
                    
                    updatedTotalUnreadSummaries[groupId] = summary
                }
            }
            
            for (groupId, state) in updatedTotalStates {
                if postbox.messageHistoryMetadataTable.getTotalUnreadState(groupId: groupId) != state {
                    postbox.messageHistoryMetadataTable.setTotalUnreadState(groupId: groupId, state: state)
                    updatedTotalUnreadStates[groupId] = state
                }
            }
            
            for groupId in updatedTotalUnreadSummaries.keys {
                if postbox.groupMessageStatsTable.get(groupId: groupId) != updatedTotalUnreadSummaries[groupId]! {
                    postbox.groupMessageStatsTable.set(groupId: groupId, summary: updatedTotalUnreadSummaries[groupId]!)
                    updatedGroupTotalUnreadSummaries[groupId] = updatedTotalUnreadSummaries[groupId]!
                }
            }
        }
    }
    
    override func beforeCommit() {
        assert(self.updatedPreviousPeerCachedIndices.isEmpty)

        if !self.useCaches {
            self.cachedPeerIndices.removeAll()
        }
    }
    
    func debugReindexUnreadCounts(postbox: PostboxImpl, currentTransaction: Transaction) -> ([PeerGroupId: ChatListTotalUnreadState], [PeerGroupId: PeerGroupUnreadCountersCombinedSummary]) {
        let globalNotificationSettings = postbox.getGlobalNotificationSettings(transaction: currentTransaction)
        
        var peerIds: [PeerId] = []
        for groupId in postbox.chatListTable.existingGroups() + [.root] {
            let groupPeerIds = postbox.chatListTable.allPeerIds(groupId: groupId)
            peerIds.append(contentsOf: groupPeerIds)
        }
        var totalStates: [PeerGroupId: ChatListTotalUnreadState] = [:]
        var summaries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary] = [:]
        for peerId in peerIds {
            guard let peer = postbox.peerTable.get(peerId) else {
                continue
            }
            guard let combinedState = postbox.readStateTable.getCombinedState(peerId) else {
                continue
            }
            let isContact = postbox.contactsTable.isContact(peerId: peerId)
            let notificationPeerId: PeerId = peer.associatedPeerId ?? peerId
            let inclusion = self.get(peerId: peerId)
            if let (groupId, _) = inclusion.includedIndex(peerId: peerId) {
                if totalStates[groupId] == nil {
                    totalStates[groupId] = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
                }
                
                let peerMessageCount = combinedState.count
                
                let summaryTags = postbox.seedConfiguration.peerSummaryCounterTags(peer, isContact)
                for tag in summaryTags {
                    if totalStates[groupId]!.absoluteCounters[tag] == nil {
                        totalStates[groupId]!.absoluteCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                    }
                    var messageCount = totalStates[groupId]!.absoluteCounters[tag]!.messageCount
                    messageCount = messageCount &+ peerMessageCount
                    if messageCount < 0 {
                        messageCount = 0
                    }
                    if combinedState.isUnread {
                        totalStates[groupId]!.absoluteCounters[tag]!.chatCount += 1
                    }
                    if combinedState.markedUnread {
                        messageCount = max(1, messageCount)
                    }
                    totalStates[groupId]!.absoluteCounters[tag]!.messageCount = messageCount
                }
                
                let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettings, peer: peer, peerSettings: postbox.peerNotificationSettingsTable.getEffective(notificationPeerId))
                
                if !isRemovedFromTotalUnreadCount {
                    for tag in summaryTags {
                        if totalStates[groupId]!.filteredCounters[tag] == nil {
                            totalStates[groupId]!.filteredCounters[tag] = ChatListTotalUnreadCounters(messageCount: 0, chatCount: 0)
                        }
                        var messageCount = totalStates[groupId]!.filteredCounters[tag]!.messageCount
                        messageCount = messageCount &+ peerMessageCount
                        if messageCount < 0 {
                            messageCount = 0
                        }
                        if combinedState.isUnread {
                            totalStates[groupId]!.filteredCounters[tag]!.chatCount += 1
                        }
                        if combinedState.markedUnread {
                            messageCount = max(1, messageCount)
                        }
                        totalStates[groupId]!.filteredCounters[tag]!.messageCount = messageCount
                    }
                }
                
                for (namespace, state) in combinedState.states {
                    if summaries[groupId] == nil {
                        summaries[groupId] = PeerGroupUnreadCountersCombinedSummary(namespaces: [:])
                    }
                    if summaries[groupId]!.namespaces[namespace] == nil {
                        summaries[groupId]!.namespaces[namespace] = PeerGroupUnreadCountersSummary(all: PeerGroupUnreadCounters(messageCount: 0, chatCount: 0))
                    }
                    if state.count > 0 {
                        summaries[groupId]!.namespaces[namespace]!.all.chatCount += 1
                        summaries[groupId]!.namespaces[namespace]!.all.messageCount += state.count
                    }
                }
            }
        }
        
        return (totalStates, summaries)
    }
    
    func reindexPeerGroupUnreadCounts(postbox: PostboxImpl, groupId: PeerGroupId) -> PeerGroupUnreadCountersCombinedSummary {
        var summary = PeerGroupUnreadCountersCombinedSummary(namespaces: [:])
        
        postbox.chatListTable.forEachPeer(groupId: groupId, { peerId in
            if peerId.namespace == .max {
                return
            }
            guard let combinedState = postbox.readStateTable.getCombinedState(peerId) else {
                return
            }
            
            let inclusion = self.get(peerId: peerId)
            if let (inclusionGroupId, _) = inclusion.includedIndex(peerId: peerId), inclusionGroupId == groupId {
                for (namespace, state) in combinedState.states {
                    if summary.namespaces[namespace] == nil {
                        summary.namespaces[namespace] = PeerGroupUnreadCountersSummary(all: PeerGroupUnreadCounters(messageCount: 0, chatCount: 0))
                    }
                    if state.count > 0 {
                        summary.namespaces[namespace]!.all.chatCount += 1
                        summary.namespaces[namespace]!.all.messageCount += state.count
                    }
                }
            }
        })
        
        return summary
    }
}
