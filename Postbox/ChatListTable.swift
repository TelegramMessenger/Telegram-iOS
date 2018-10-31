import Foundation

enum ChatListOperation {
    case InsertEntry(ChatListIndex, IntermediateMessage?, CombinedPeerReadState?, PeerChatListEmbeddedInterfaceState?)
    case InsertHole(ChatListHole)
    case InsertGroupReference(PeerGroupId, ChatListIndex)
    case RemoveEntry([ChatListIndex])
    case RemoveHoles([ChatListIndex])
    case RemoveGroupReferences([ChatListIndex])
}

enum ChatListEntryInfo {
    case message(ChatListIndex, MessageIndex?)
    case hole(ChatListHole)
    case groupReference(PeerGroupId, ChatListIndex)
    
    var index: ChatListIndex {
        switch self {
            case let .message(index, _):
                return index
            case let .hole(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .groupReference(_, index):
                return index
        }
    }
}

enum ChatListIntermediateEntry {
    case message(ChatListIndex, IntermediateMessage?, PeerChatListEmbeddedInterfaceState?)
    case hole(ChatListHole)
    case groupReference(PeerGroupId, ChatListIndex)
    
    var index: ChatListIndex {
        switch self {
            case let .message(index, _, _):
                return index
            case let .hole(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
            case let .groupReference(_, index):
                return index
        }
    }
}

public enum ChatListRelativePosition {
    case later(than: ChatListIndex?)
    case earlier(than: ChatListIndex?)
}

private enum ChatListEntryType: Int8 {
    case message = 1
    case hole = 2
    case groupReference = 3
}

func chatListPinningIndexFromKeyValue(_ value: UInt16) -> UInt16? {
    if value == 0 {
        return nil
    } else {
        return UInt16.max - 1 - value
    }
}

func keyValueForChatListPinningIndex(_ index: UInt16?) -> UInt16 {
    if let index = index {
        return UInt16.max - 1 - index
    } else {
        return 0
    }
}

private func extractKey(_ key: ValueBoxKey) -> (groupId: PeerGroupId?, pinningIndex: UInt16?, index: MessageIndex, type: Int8) {
    let groupIdValue = key.getInt32(0)
    return (
        groupId: groupIdValue == 0 ? nil : PeerGroupId(rawValue: groupIdValue),
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

private func readEntry(groupId: PeerGroupId?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, key: ValueBoxKey, value: ReadBuffer) -> ChatListIntermediateEntry {
    let (keyGroupId, pinningIndex, messageIndex, type) = extractKey(key)
    assert(groupId == keyGroupId)
    //preconditionFailure()
    let index = ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex)
    if type == ChatListEntryType.message.rawValue {
        var message: IntermediateMessage?
        if value.length != 0 {
            var idNamespace: Int32 = 0
            value.read(&idNamespace, offset: 0, length: 4)
            var idId: Int32 = 0
            value.read(&idId, offset: 0, length: 4)
            var indexTimestamp: Int32 = 0
            value.read(&indexTimestamp, offset: 0, length: 4)
            
            message = messageHistoryTable.getMessage(MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp))
        }
        return .message(index, message, peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState)
    } else if type == ChatListEntryType.hole.rawValue {
        return .hole(ChatListHole(index: index.messageIndex))
    } else if type == ChatListEntryType.groupReference.rawValue {
        var groupIdValue: Int32 = 0
        value.read(&groupIdValue, offset: 0, length: 4)
        return .groupReference(PeerGroupId(rawValue: groupIdValue), index)
    } else {
        preconditionFailure()
    }
}

private func addOperation(_ operation: ChatListOperation, peerGroupId: PeerGroupId?, to operations: inout [WrappedPeerGroupId: [ChatListOperation]]) {
    let wrappedId = WrappedPeerGroupId(groupId: peerGroupId)
    if operations[wrappedId] == nil {
        operations[wrappedId] = []
    }
    operations[wrappedId]!.append(operation)
}

/*
 dialog.unread_mark ? 1 : 0,
 dialog.peer.channel_id || dialog.peer.chat_id || dialog.peer.user_id,
 dialog.top_message.id,
 top_message.edit_date || top_message.date,
 dialog.read_inbox_max_id,
 dialog.read_outbox_max_id,
 dialog.unread_count,
 dialog.unread_mentions_count,
 draft.draft.date || 0

 */

public enum ChatListNamespaceEntry {
    case peer(index: ChatListIndex, readState: PeerReadState?, topMessageAttributes: [MessageAttribute], tagSummary: MessageHistoryTagNamespaceSummary?, interfaceState: PeerChatInterfaceState?)
    case hole(MessageIndex)
    
    public var index: ChatListIndex {
        switch self {
            case let .peer(peer):
                return peer.index
            case let .hole(index):
                return ChatListIndex(pinningIndex: nil, messageIndex: index)
        }
    }
}

final class ChatListTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let groupAssociationTable: PeerGroupAssociationTable
    let indexTable: ChatListIndexTable
    let emptyMemoryBuffer = MemoryBuffer()
    let metadataTable: MessageHistoryMetadataTable
    let seedConfiguration: SeedConfiguration
    
    init(valueBox: ValueBox, table: ValueBoxTable, groupAssociationTable: PeerGroupAssociationTable, indexTable: ChatListIndexTable, metadataTable: MessageHistoryMetadataTable, seedConfiguration: SeedConfiguration) {
        self.groupAssociationTable = groupAssociationTable
        self.indexTable = indexTable
        self.metadataTable = metadataTable
        self.seedConfiguration = seedConfiguration
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(groupId: PeerGroupId?, index: ChatListIndex, type: ChatListEntryType) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 2 + 4 + 1 + 4 + 8 + 1)
        key.setInt32(0, value: groupId?.rawValue ?? 0)
        key.setUInt16(4, value: keyValueForChatListPinningIndex(index.pinningIndex))
        key.setInt32(4 + 2, value: index.messageIndex.timestamp)
        key.setInt8(4 + 2 + 4, value: Int8(index.messageIndex.id.namespace))
        key.setInt32(4 + 2 + 4 + 1, value: index.messageIndex.id.id)
        key.setInt64(4 + 2 + 4 + 1 + 4, value: index.messageIndex.id.peerId.toInt64())
        key.setInt8(4 + 2 + 4 + 1 + 4 + 8, value: type.rawValue)
        return key
    }
    
    private func lowerBound(groupId: PeerGroupId?) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 2 + 4)
        key.setInt32(0, value: groupId?.rawValue ?? 0)
        key.setUInt16(4, value: 0)
        key.setInt32(4 + 2, value: 0)
        return key
    }
    
    private func upperBound(groupId: PeerGroupId?) -> ValueBoxKey {
        let key = ValueBoxKey(length: 4 + 2 + 4)
        key.setInt32(0, value: groupId?.rawValue ?? 0)
        key.setUInt16(4, value: UInt16.max)
        key.setInt32(4 + 2, value: Int32.max)
        return key
    }
    
    private func ensureInitialized(groupId: PeerGroupId?) {
        if !self.metadataTable.isInitializedChatList(groupId: groupId) {
            let hole: ChatListHole?
            if groupId != nil {
                hole = self.seedConfiguration.initializeChatListWithHole.groups
            } else {
                hole = self.seedConfiguration.initializeChatListWithHole.topLevel
            }
            if let hole = hole {
                self.justInsertHole(groupId: groupId, hole: hole)
            }
            self.metadataTable.setInitializedChatList(groupId: groupId)
        }
    }
    
    func updateInclusion(peerId: PeerId, updatedChatListInclusions: inout [PeerId: PeerChatListInclusion], _ f: (PeerChatListInclusion) -> PeerChatListInclusion) {
        let currentInclusion: PeerChatListInclusion
        if let updated = updatedChatListInclusions[peerId] {
            currentInclusion = updated
        } else {
            currentInclusion = self.indexTable.get(peerId: peerId).inclusion
        }
        let updatedInclusion = f(currentInclusion)
        if currentInclusion != updatedInclusion {
            updatedChatListInclusions[peerId] = updatedInclusion
        }
    }
    
    func updateInclusion(groupId: PeerGroupId, updatedChatListGroupInclusions: inout [PeerGroupId: GroupChatListInclusion], _ f: (GroupChatListInclusion) -> GroupChatListInclusion) {
        let currentInclusion: GroupChatListInclusion
        if let updated = updatedChatListGroupInclusions[groupId] {
            currentInclusion = updated
        } else {
            currentInclusion = self.indexTable.get(groupId: groupId).inclusion
        }
        let updatedInclusion = f(currentInclusion)
        if currentInclusion != updatedInclusion {
            updatedChatListGroupInclusions[groupId] = updatedInclusion
        }
    }
    
    func getPinnedItemIds(messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable) -> [PinnedItemId] {
        var itemIds: [PinnedItemId] = []
        self.valueBox.range(self.table, start: self.upperBound(groupId: nil), end: self.key(groupId: nil, index: ChatListIndex(pinningIndex: UInt16.max - 1, messageIndex: MessageIndex.absoluteUpperBound()), type: .message).successor, values: { key, value in
            let entry = readEntry(groupId: nil, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value)
            switch entry {
                case let .groupReference(groupId, _):
                    itemIds.append(.group(groupId))
                case let .message(index, _, _):
                    itemIds.append(.peer(index.messageIndex.id.peerId))
                default:
                    break
            }
            return true
        }, limit: 0)
        return itemIds
    }
    
    func setPinnedItemIds(_ itemIds: [PinnedItemId], updatedChatListInclusions: inout [PeerId: PeerChatListInclusion], updatedChatListGroupInclusions: inout [PeerGroupId: GroupChatListInclusion], messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable) {
        let updatedIds = Set(itemIds)
        for itemId in self.getPinnedItemIds(messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable) {
            if !updatedIds.contains(itemId) {
                switch itemId {
                    case let .peer(peerId):
                        self.updateInclusion(peerId: peerId, updatedChatListInclusions: &updatedChatListInclusions, { inclusion in
                            return inclusion.withoutPinningIndex()
                        })
                    case let .group(groupId):
                        self.updateInclusion(groupId: groupId, updatedChatListGroupInclusions: &updatedChatListGroupInclusions, { inclusion in
                            return inclusion.withoutPinningIndex()
                        })
                }
            }
        }
        for i in 0 ..< itemIds.count {
            switch itemIds[i] {
                case let .peer(peerId):
                    self.updateInclusion(peerId: peerId, updatedChatListInclusions: &updatedChatListInclusions, { inclusion in
                        return inclusion.withPinningIndex(UInt16(i))
                    })
                case let .group(groupId):
                    self.updateInclusion(groupId: groupId, updatedChatListGroupInclusions: &updatedChatListGroupInclusions, { inclusion in
                        return inclusion.withPinningIndex(UInt16(i))
                    })
            }
        }
    }
    
    func getPeerChatListIndex(peerId: PeerId) -> (PeerGroupId?, ChatListIndex)? {
        if let index = self.indexTable.get(peerId: peerId).includedIndex(peerId: peerId) {
            return (self.groupAssociationTable.get(peerId: peerId), index)
        } else {
            return nil
        }
    }
    
    func getUnreadChatListPeerIds(postbox: Postbox) -> [PeerId] {
        var result: [PeerId] = []
        self.valueBox.range(self.table, start: self.upperBound(groupId: nil), end: self.lowerBound(groupId: nil), keys: { key in
            let (_, _, messageIndex, _) = extractKey(key)
            if let state = postbox.readStateTable.getCombinedState(messageIndex.id.peerId), state.isUnread {
                result.append(messageIndex.id.peerId)
            }
            return true
        }, limit: 0)
        return result
    }
    
    private func topGroupMessageIndex(groupId: PeerGroupId) -> MessageIndex? {
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.upperBound(groupId: groupId), end: self.lowerBound(groupId: groupId), keys: { key in
            result = extractKey(key).index
            return true
        }, limit: 1)
        return result
    }
    
    func replay(historyOperationsByPeerId: [PeerId : [MessageHistoryOperation]], updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?], updatedChatListInclusions: [PeerId: PeerChatListInclusion], updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion], initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId], messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, operations: inout [WrappedPeerGroupId: [ChatListOperation]]) {
        var changedPeerIds = Set<PeerId>()
        for peerId in historyOperationsByPeerId.keys {
            changedPeerIds.insert(peerId)
        }
        for peerId in updatedPeerChatListEmbeddedStates.keys {
            changedPeerIds.insert(peerId)
        }
        for peerId in updatedChatListInclusions.keys {
            changedPeerIds.insert(peerId)
        }
        
        self.ensureInitialized(groupId: nil)
        var usedGroupIds = self.groupAssociationTable.get(peerIds: changedPeerIds)
        for groupId in updatedChatListGroupInclusions.keys {
            usedGroupIds.insert(groupId)
        }
        for (peerId, groupId) in initialPeerGroupIdsBeforeUpdate {
            changedPeerIds.insert(peerId)
            if let value = groupId.groupId {
                usedGroupIds.insert(value)
            }
            if let updatedGroupId = self.groupAssociationTable.get(peerId: peerId) {
                usedGroupIds.insert(updatedGroupId)
            }
        }
        for groupId in usedGroupIds {
            self.ensureInitialized(groupId: groupId)
        }
        
        for peerId in changedPeerIds {
            let groupId = self.groupAssociationTable.get(peerId: peerId)
            
            var currentIndex: ChatListIndex? = self.indexTable.get(peerId: peerId).includedIndex(peerId: peerId)
            if let previousGroupId = initialPeerGroupIdsBeforeUpdate[peerId] {
                if previousGroupId.groupId != groupId {
                    if let currentIndex = currentIndex {
                        self.justRemoveMessageIndex(groupId: previousGroupId.groupId, index: currentIndex)
                        addOperation(.RemoveEntry([currentIndex]), peerGroupId: previousGroupId.groupId, to: &operations)
                    }
                    currentIndex = nil
                }
            }
            
            
            let topMessage = messageHistoryTable.topMessage(peerId)
            let embeddedChatState = peerChatInterfaceStateTable.get(peerId)?.chatListEmbeddedState
            
            let rawTopMessageIndex: MessageIndex?
            let topMessageIndex: MessageIndex?
            if let topMessage = topMessage {
                var updatedTimestamp = topMessage.timestamp
                rawTopMessageIndex = MessageIndex(id: topMessage.id, timestamp: topMessage.timestamp)
                if let embeddedChatState = embeddedChatState {
                    updatedTimestamp = max(updatedTimestamp, embeddedChatState.timestamp)
                }
                topMessageIndex = MessageIndex(id: topMessage.id, timestamp: updatedTimestamp)
            } else if let embeddedChatState = embeddedChatState, embeddedChatState.timestamp != 0 {
                topMessageIndex = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 1), timestamp: embeddedChatState.timestamp)
                rawTopMessageIndex = nil
            } else {
                topMessageIndex = nil
                rawTopMessageIndex = nil
            }
            
            var updatedIndex = self.indexTable.setTopMessageIndex(peerId: peerId, index: topMessageIndex)
            if let updatedInclusion = updatedChatListInclusions[peerId] {
                updatedIndex = self.indexTable.setInclusion(peerId: peerId, inclusion: updatedInclusion)
            }
            
            if let updatedOrderingIndex = updatedIndex.includedIndex(peerId: peerId) {
                if let currentIndex = currentIndex, currentIndex != updatedOrderingIndex {
                    self.justRemoveMessageIndex(groupId: groupId, index: currentIndex)
                }
                if let currentIndex = currentIndex {
                    addOperation(.RemoveEntry([currentIndex]), peerGroupId: groupId, to: &operations)
                }
                self.justInsertIndex(groupId: groupId, index: updatedOrderingIndex, topMessageIndex: rawTopMessageIndex)
                addOperation(.InsertEntry(updatedOrderingIndex, topMessage, messageHistoryTable.readStateTable.getCombinedState(peerId), embeddedChatState), peerGroupId: groupId, to: &operations)
            } else {
                if let currentIndex = currentIndex {
                    self.justRemoveMessageIndex(groupId: groupId, index: currentIndex)
                    addOperation(.RemoveEntry([currentIndex]), peerGroupId: groupId, to: &operations)
                }
            }
        }
        
        for groupId in usedGroupIds {
            let currentIndex: ChatListIndex? = self.indexTable.get(groupId: groupId).includedIndex()
            
            let topMessageIndex = self.topGroupMessageIndex(groupId: groupId)
            var updatedIndex = self.indexTable.setTopMessageIndex(groupId: groupId, index: topMessageIndex)
            if let updatedInclusion = updatedChatListGroupInclusions[groupId] {
                updatedIndex = self.indexTable.setInclusion(groupId: groupId, inclusion: updatedInclusion)
            }
            
            if let updatedOrderingIndex = updatedIndex.includedIndex() {
                if let currentIndex = currentIndex, currentIndex != updatedOrderingIndex {
                    self.justRemoveGroupReferenceIndex(groupId: nil, index: currentIndex)
                }
                if currentIndex != updatedOrderingIndex {
                    if let currentIndex = currentIndex {
                        addOperation(.RemoveGroupReferences([currentIndex]), peerGroupId: nil, to: &operations)
                    }
                    self.justInsertGroupReferenceIndex(groupId: nil, referenceGroupId: groupId, index: updatedOrderingIndex)
                    addOperation(.InsertGroupReference(groupId, updatedOrderingIndex), peerGroupId: nil, to: &operations)
                }
            } else {
                if let currentIndex = currentIndex {
                    self.justRemoveGroupReferenceIndex(groupId: nil, index: currentIndex)
                    addOperation(.RemoveGroupReferences([currentIndex]), peerGroupId: nil, to: &operations)
                }
            }
        }
    }
    
    func addHole(groupId: PeerGroupId?, hole: ChatListHole, operations: inout [WrappedPeerGroupId: [ChatListOperation]]) {
        self.ensureInitialized(groupId: groupId)
        
        if self.valueBox.get(self.table, key: self.key(groupId: groupId, index: ChatListIndex(pinningIndex: nil, messageIndex: hole.index), type: .hole)) == nil {
            self.justInsertHole(groupId: groupId, hole: hole)
            addOperation(.InsertHole(hole), peerGroupId: groupId, to: &operations)
        }
    }
    
    func replaceHole(groupId: PeerGroupId?, index: MessageIndex, hole: ChatListHole?, operations: inout [WrappedPeerGroupId: [ChatListOperation]]) {
        self.ensureInitialized(groupId: groupId)
        
        if self.valueBox.get(self.table, key: self.key(groupId: groupId, index: ChatListIndex(pinningIndex: nil, messageIndex: index), type: .hole)) != nil {
            if let hole = hole {
                if hole.index != index {
                    self.justRemoveHole(groupId: groupId, index: index)
                    self.justInsertHole(groupId: groupId, hole: hole)
                    addOperation(.RemoveHoles([ChatListIndex(pinningIndex: nil, messageIndex: index)]), peerGroupId: groupId, to: &operations)
                    addOperation(.InsertHole(hole), peerGroupId: groupId, to: &operations)
                }
            } else{
                self.justRemoveHole(groupId: groupId, index: index)
                addOperation(.RemoveHoles([ChatListIndex(pinningIndex: nil, messageIndex: index)]), peerGroupId: groupId, to: &operations)
            }
        }
    }
    
    private func justInsertIndex(groupId: PeerGroupId?, index: ChatListIndex, topMessageIndex: MessageIndex?) {
        let buffer = WriteBuffer()
        if let topMessageIndex = topMessageIndex {
            var idNamespace = topMessageIndex.id.namespace
            buffer.write(&idNamespace, offset: 0, length: 4)
            var idId = topMessageIndex.id.id
            buffer.write(&idId, offset: 0, length: 4)
            var indexTimestamp = topMessageIndex.timestamp
            buffer.write(&indexTimestamp, offset: 0, length: 4)
        }
        self.valueBox.set(self.table, key: self.key(groupId: groupId, index: index, type: .message), value: buffer)
    }
    
    private func justRemoveMessageIndex(groupId: PeerGroupId?, index: ChatListIndex) {
        self.valueBox.remove(self.table, key: self.key(groupId: groupId, index: index, type: .message))
    }
    
    private func justRemoveGroupReferenceIndex(groupId: PeerGroupId?, index: ChatListIndex) {
        self.valueBox.remove(self.table, key: self.key(groupId: groupId, index: index, type: .groupReference))
    }
    
    private func justInsertHole(groupId: PeerGroupId?, hole: ChatListHole) {
        self.valueBox.set(self.table, key: self.key(groupId: groupId, index: ChatListIndex(pinningIndex: nil, messageIndex: hole.index), type: .hole), value: self.emptyMemoryBuffer)
    }
    
    private func justRemoveHole(groupId: PeerGroupId?, index: MessageIndex) {
        self.valueBox.remove(self.table, key: self.key(groupId: groupId, index: ChatListIndex(pinningIndex: nil, messageIndex: index), type: .hole))
    }
    
    private func justInsertGroupReferenceIndex(groupId: PeerGroupId?, referenceGroupId: PeerGroupId, index: ChatListIndex) {
        var value: Int32 = referenceGroupId.rawValue
        self.valueBox.set(self.table, key: self.key(groupId: groupId, index: index, type: .groupReference), value: MemoryBuffer(memory: &value, capacity: 4, length: 4, freeWhenDone: false))
    }
    
    func entriesAround(groupId: PeerGroupId?, index: ChatListIndex, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> (entries: [ChatListIntermediateEntry], lower: ChatListIntermediateEntry?, upper: ChatListIntermediateEntry?) {
        self.ensureInitialized(groupId: groupId)
        
        var lowerEntries: [ChatListIntermediateEntry] = []
        var upperEntries: [ChatListIntermediateEntry] = []
        var lower: ChatListIntermediateEntry?
        var upper: ChatListIntermediateEntry?
        
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: index, type: .message), end: self.lowerBound(groupId: groupId), values: { key, value in
            lowerEntries.append(readEntry(groupId: groupId, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value))
            return true
        }, limit: count / 2 + 1)
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        self.valueBox.range(self.table, start: self.key(groupId: groupId, index: index, type: .message).predecessor, end: self.upperBound(groupId: groupId), values: { key, value in
            upperEntries.append(readEntry(groupId: groupId, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value))
            return true
        }, limit: count - lowerEntries.count + 1)
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [ChatListIntermediateEntry] = []
            let startEntryType: ChatListEntryType
            switch lowerEntries.last! {
                case .message:
                    startEntryType = .message
                case .hole:
                    startEntryType = .hole
                case .groupReference:
                    startEntryType = .groupReference
            }
            self.valueBox.range(self.table, start: self.key(groupId: groupId, index: lowerEntries.last!.index, type: startEntryType), end: self.lowerBound(groupId: groupId), values: { key, value in
                additionalLowerEntries.append(readEntry(groupId: groupId, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value))
                return true
            }, limit: count - lowerEntries.count - upperEntries.count + 1)
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [ChatListIntermediateEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func topPeerIds(groupId: PeerGroupId?, count: Int) -> [PeerId] {
        var peerIds: [PeerId] = []
        while true {
            var completed = true
            self.valueBox.range(self.table, start: self.upperBound(groupId: groupId), end: self.lowerBound(groupId: groupId), keys: { key in
                let (keyGroupId, _, messageIndex, type) = extractKey(key)
                assert(groupId == keyGroupId)
                
                if type == ChatListEntryType.message.rawValue {
                    peerIds.append(messageIndex.id.peerId)
                }
                completed = false
                return true
            }, limit: count)
            if completed || peerIds.count >= count {
                break
            }
        }
        return peerIds
    }
    
    func topMessageIndices(groupId: PeerGroupId?, count: Int) -> [ChatListIndex] {
        var indices: [ChatListIndex] = []
        var startKey = self.upperBound(groupId: groupId)
        while true {
            var completed = true
            self.valueBox.range(self.table, start: startKey, end: self.lowerBound(groupId: groupId), keys: { key in
                startKey = key
                
                let (keyGroupId, pinningIndex, messageIndex, type) = extractKey(key)
                assert(groupId == keyGroupId)
                
                let index = ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex)
                
                if type == ChatListEntryType.message.rawValue {
                    indices.append(index)
                }
                completed = false
                return true
            }, limit: indices.isEmpty ? count : 1)
            if completed || indices.count >= count {
                break
            }
        }
        return indices
    }
    
    func earlierEntries(groupId: PeerGroupId?, index: ChatListIndex?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized(groupId: groupId)
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(groupId: groupId, index: index, type: .message)
        } else {
            key = self.upperBound(groupId: groupId)
        }
        
        self.valueBox.range(self.table, start: key, end: self.lowerBound(groupId: groupId), values: { key, value in
            entries.append(readEntry(groupId: groupId, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func laterEntries(groupId: PeerGroupId?, index: ChatListIndex?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, count: Int) -> [ChatListIntermediateEntry] {
        self.ensureInitialized(groupId: groupId)
        
        var entries: [ChatListIntermediateEntry] = []
        let key: ValueBoxKey
        if let index = index {
            key = self.key(groupId: groupId, index: index, type: .message)
        } else {
            key = self.lowerBound(groupId: groupId)
        }
        
        self.valueBox.range(self.table, start: key, end: self.upperBound(groupId: groupId), values: { key, value in
            entries.append(readEntry(groupId: groupId, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, key: key, value: value))
            return true
        }, limit: count)
        return entries
    }
    
    func getStandalone(peerId: PeerId, messageHistoryTable: MessageHistoryTable) -> ChatListIntermediateEntry? {
        let index = self.indexTable.get(peerId: peerId)
        switch index.inclusion {
            case .ifHasMessages, .ifHasMessagesOrOneOf:
                return nil
            default:
                break
        }
        if let topMessageIndex = index.topMessageIndex {
            if let message = messageHistoryTable.getMessage(topMessageIndex) {
                return ChatListIntermediateEntry.message(ChatListIndex(pinningIndex: nil, messageIndex: topMessageIndex), message, nil)
            }
        }
        return nil
    }
    
    func allEntries(groupId: PeerGroupId?) -> [ChatListEntryInfo] {
        var entries: [ChatListEntryInfo] = []
        self.valueBox.range(self.table, start: self.upperBound(groupId: groupId), end: self.lowerBound(groupId: groupId), values: { key, value in
            let (keyGroupId, pinningIndex, messageIndex, type) = extractKey(key)
            assert(groupId == keyGroupId)
            
            let index = ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex)
            if type == ChatListEntryType.message.rawValue {
                var messageIndex: MessageIndex?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    messageIndex = MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp)
                }
                entries.append(.message(index, messageIndex))
            } else if type == ChatListEntryType.hole.rawValue {
                entries.append(.hole(ChatListHole(index: index.messageIndex)))
            } else if type == ChatListEntryType.groupReference.rawValue {
                var groupIdValue: Int32 = 0
                value.read(&groupIdValue, offset: 0, length: 4)
                entries.append(.groupReference(PeerGroupId(rawValue: groupIdValue), index))
            } else {
                assertionFailure()
            }
            return true
        }, limit: 0)
        return entries
    }
    
    func entriesInRange(groupId: PeerGroupId?, upperBound: ChatListIndex, lowerBound: ChatListIndex) -> [ChatListEntryInfo] {
        var entries: [ChatListEntryInfo] = []
        let upperBoundKey: ValueBoxKey
        if upperBound.messageIndex.timestamp == Int32.max {
            upperBoundKey = self.upperBound(groupId: groupId)
        } else {
            upperBoundKey = self.key(groupId: groupId, index: upperBound, type: .message).successor
        }
        self.valueBox.range(self.table, start: upperBoundKey, end: self.key(groupId: groupId, index: lowerBound, type: .message).predecessor, values: { key, value in
            let (keyGroupId, pinningIndex, messageIndex, type) = extractKey(key)
            assert(groupId == keyGroupId)
            
            let index = ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex)
            if type == ChatListEntryType.message.rawValue {
                var messageIndex: MessageIndex?
                if value.length != 0 {
                    var idNamespace: Int32 = 0
                    value.read(&idNamespace, offset: 0, length: 4)
                    var idId: Int32 = 0
                    value.read(&idId, offset: 0, length: 4)
                    var indexTimestamp: Int32 = 0
                    value.read(&indexTimestamp, offset: 0, length: 4)
                    messageIndex = MessageIndex(id: MessageId(peerId: index.messageIndex.id.peerId, namespace: idNamespace, id: idId), timestamp: indexTimestamp)
                }
                entries.append(.message(index, messageIndex))
            } else if type == ChatListEntryType.hole.rawValue {
                entries.append(.hole(ChatListHole(index: index.messageIndex)))
            } else if type == ChatListEntryType.groupReference.rawValue {
                var groupIdValue: Int32 = 0
                value.read(&groupIdValue, offset: 0, length: 4)
                entries.append(.groupReference(PeerGroupId(rawValue: groupIdValue), index))
            } else {
                assertionFailure()
            }
            return true
        }, limit: 0)
        return entries
    }
    
    func getRelativeUnreadChatListIndex(postbox: Postbox, filtered: Bool, position: ChatListRelativePosition) -> ChatListIndex? {
        let groupId: PeerGroupId? = nil
        var result: ChatListIndex?
        
        let lower: ValueBoxKey
        let upper: ValueBoxKey
        
        switch position {
            case let .earlier(index):
                upper = self.upperBound(groupId: groupId)
                if let index = index {
                    lower = self.key(groupId: groupId, index: index, type: .message)
                } else {
                    lower = self.lowerBound(groupId: groupId)
                }
            case let .later(index):
                upper = self.lowerBound(groupId: groupId)
                if let index = index {
                    lower = self.key(groupId: groupId, index: index, type: .message)
                } else {
                    lower = self.upperBound(groupId: groupId)
            }
        }
        
        self.valueBox.range(self.table, start: lower, end: upper, values: { key, value in
            let (keyGroupId, pinningIndex, messageIndex, type) = extractKey(key)
            assert(groupId == keyGroupId)
            
            let index = ChatListIndex(pinningIndex: pinningIndex, messageIndex: messageIndex)
            if type == ChatListEntryType.message.rawValue {
                let peerId = index.messageIndex.id.peerId
                if let readState = postbox.readStateTable.getCombinedState(peerId), readState.isUnread {
                    if filtered {
                        var notificationSettings: PeerNotificationSettings?
                        if let peer = postbox.peerTable.get(peerId) {
                            if let notificationSettingsPeerId = peer.notificationSettingsPeerId {
                                notificationSettings = postbox.peerNotificationSettingsTable.getEffective(notificationSettingsPeerId)
                            } else {
                                notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
                            }
                        }
                        if let notificationSettings = notificationSettings, !notificationSettings.isRemovedFromTotalUnreadCount {
                            result = index
                            return false
                        }
                    } else {
                        result = index
                        return false
                    }
                }
            }
            return true
        }, limit: 0)
        return result
    }
    
    func debugList(groupId: PeerGroupId?, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable) -> [ChatListIntermediateEntry] {
        return self.laterEntries(groupId: groupId, index: ChatListIndex.absoluteLowerBound, messageHistoryTable: messageHistoryTable, peerChatInterfaceStateTable: peerChatInterfaceStateTable, count: 1000)
    }
    
    func getNamespaceEntries(groupId: PeerGroupId?, namespace: MessageId.Namespace, summaryTag: MessageTags?, messageIndexTable: MessageHistoryIndexTable, messageHistoryTable: MessageHistoryTable, peerChatInterfaceStateTable: PeerChatInterfaceStateTable, readStateTable: MessageHistoryReadStateTable, summaryTable: MessageHistoryTagsSummaryTable) -> [ChatListNamespaceEntry] {
        var result: [ChatListNamespaceEntry] = []
        self.valueBox.range(self.table, start: self.upperBound(groupId: groupId), end: self.lowerBound(groupId: groupId), keys: { key in
            let keyComponents = extractKey(key)
            if keyComponents.type == ChatListEntryType.hole.rawValue {
                if keyComponents.index.id.namespace == namespace {
                    result.append(.hole(keyComponents.index))
                }
            } else {
                var topMessage: IntermediateMessage?
                var peerIndex: ChatListIndex?
                if let pinningIndex = keyComponents.pinningIndex {
                    if keyComponents.index.id.namespace == namespace {
                        peerIndex = ChatListIndex(pinningIndex: pinningIndex, messageIndex: keyComponents.index)
                    }
                } else if keyComponents.index.id.namespace == namespace {
                    peerIndex = ChatListIndex(pinningIndex: nil, messageIndex: keyComponents.index)
                } else {
                    if let entry = messageIndexTable.topMaybeUninitialized(keyComponents.index.id.peerId, namespace: namespace) {
                        switch entry {
                            case let .Message(index):
                                peerIndex = ChatListIndex(pinningIndex: nil, messageIndex: index)
                                topMessage = messageHistoryTable.getMessage(index)
                            default:
                                break
                        }
                    }
                }
                if topMessage == nil {
                    if let entry = messageIndexTable.topMaybeUninitialized(keyComponents.index.id.peerId, namespace: namespace) {
                        switch entry {
                            case let .Message(index):
                                topMessage = messageHistoryTable.getMessage(index)
                            default:
                                break
                        }
                    }
                }
                if let peerIndex = peerIndex {
                    var readState: PeerReadState?
                    if let combinedState = readStateTable.getCombinedState(peerIndex.messageIndex.id.peerId) {
                        for item in combinedState.states {
                            if item.0 == namespace {
                                readState = item.1
                            }
                        }
                    }
                    var tagSummary: MessageHistoryTagNamespaceSummary?
                    if let summaryTag = summaryTag {
                        tagSummary = summaryTable.get(MessageHistoryTagsSummaryKey(tag: summaryTag, peerId: peerIndex.messageIndex.id.peerId, namespace: namespace))
                    }
                    var topMessageAttributes: [MessageAttribute] = []
                    if let topMessage = topMessage {
                        topMessageAttributes = MessageHistoryTable.renderMessageAttributes(topMessage)
                    }
                    result.append(.peer(index: peerIndex, readState: readState, topMessageAttributes: topMessageAttributes, tagSummary: tagSummary, interfaceState: peerChatInterfaceStateTable.get(peerIndex.messageIndex.id.peerId)))
                }
            }
            return true
        }, limit: 0)
        return result.sorted(by: { lhs, rhs in
            return lhs.index > rhs.index
        })
    }
}
