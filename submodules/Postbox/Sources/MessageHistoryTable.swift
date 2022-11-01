import Foundation

struct IntermediateMessageHistoryEntry {
    let message: IntermediateMessage
}

struct RenderedMessageHistoryEntry {
    let message: Message
    
    var index: MessageIndex {
        return MessageIndex(id: self.message.id, timestamp: self.message.timestamp)
    }
}

private enum AdjacentEntryGroupInfo {
    case none
    case sameGroup(MessageGroupInfo)
    case otherGroup(MessageGroupInfo)
}

private func getAdjacentEntryGroupInfo(_ entry: IntermediateMessageHistoryEntry?, key: Int64) -> (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo) {
    if let entry = entry {
        if let groupingKey = entry.message.groupingKey, let _ = entry.message.groupInfo {
            if groupingKey == key {
                if let groupInfo = entry.message.groupInfo {
                    return (entry, .sameGroup(groupInfo))
                } else {
                    return (entry, .none)
                }
            } else {
                if let groupInfo = entry.message.groupInfo {
                    return (entry, .otherGroup(groupInfo))
                } else {
                    return (entry, .none)
                }
            }
        } else {
            return (entry, .none)
        }
    } else {
        return (nil, .none)
    }
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
    static let hasThreadId = MessageDataFlags(rawValue: 1 << 5)
}

private func extractKey(_ key: ValueBoxKey) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8 + 4))
}

final class MessageHistoryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: false)
    }
    
    private let seedConfiguration: SeedConfiguration
    
    let messageHistoryIndexTable: MessageHistoryIndexTable
    let messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable
    let messageMediaTable: MessageMediaTable
    let historyMetadataTable: MessageHistoryMetadataTable
    let globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable
    let unsentTable: MessageHistoryUnsentTable
    let failedTable: MessageHistoryFailedTable
    let tagsTable: MessageHistoryTagsTable
    let threadsTable: MessageHistoryThreadsTable
    let threadTagsTable: MessageHistoryThreadTagsTable
    let globalTagsTable: GlobalMessageHistoryTagsTable
    let localTagsTable: LocalMessageHistoryTagsTable
    let timeBasedAttributesTable: TimestampBasedMessageAttributesTable
    let readStateTable: MessageHistoryReadStateTable
    let synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable
    let textIndexTable: MessageHistoryTextIndexTable
    let summaryTable: MessageHistoryTagsSummaryTable
    let pendingActionsTable: PendingMessageActionsTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, seedConfiguration: SeedConfiguration, messageHistoryIndexTable: MessageHistoryIndexTable, messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable, messageMediaTable: MessageMediaTable, historyMetadataTable: MessageHistoryMetadataTable, globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable, unsentTable: MessageHistoryUnsentTable, failedTable: MessageHistoryFailedTable, tagsTable: MessageHistoryTagsTable, threadsTable: MessageHistoryThreadsTable, threadTagsTable: MessageHistoryThreadTagsTable, globalTagsTable: GlobalMessageHistoryTagsTable, localTagsTable: LocalMessageHistoryTagsTable, timeBasedAttributesTable: TimestampBasedMessageAttributesTable, readStateTable: MessageHistoryReadStateTable, synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable, textIndexTable: MessageHistoryTextIndexTable, summaryTable: MessageHistoryTagsSummaryTable, pendingActionsTable: PendingMessageActionsTable) {
        self.seedConfiguration = seedConfiguration
        self.messageHistoryIndexTable = messageHistoryIndexTable
        self.messageHistoryHoleIndexTable = messageHistoryHoleIndexTable
        self.messageMediaTable = messageMediaTable
        self.historyMetadataTable = historyMetadataTable
        self.globallyUniqueMessageIdsTable = globallyUniqueMessageIdsTable
        self.unsentTable = unsentTable
        self.failedTable = failedTable
        self.tagsTable = tagsTable
        self.threadsTable = threadsTable
        self.threadTagsTable = threadTagsTable
        self.globalTagsTable = globalTagsTable
        self.localTagsTable = localTagsTable
        self.timeBasedAttributesTable = timeBasedAttributesTable
        self.readStateTable = readStateTable
        self.synchronizeReadStateTable = synchronizeReadStateTable
        self.textIndexTable = textIndexTable
        self.summaryTable = summaryTable
        self.pendingActionsTable = pendingActionsTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt32(8, value: index.id.namespace)
        key.setInt32(8 + 4, value: index.timestamp)
        key.setInt32(8 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: namespace)
        return key
    }
    
    private func upperBound(peerId: PeerId, namespace: MessageId.Namespace) -> ValueBoxKey {
        return self.lowerBound(peerId: peerId, namespace: namespace).successor
    }
    
    private func messagesGroupedByPeerId(_ messages: [StoreMessage]) -> [PeerId: [StoreMessage]] {
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
    
    private func messagesGroupedByPeerId(_ messages: [InternalStoreMessage]) -> [PeerId: [InternalStoreMessage]] {
        var dict: [PeerId: [InternalStoreMessage]] = [:]
        
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
    
    private func messageIdsByPeerId(_ ids: [MessageId]) -> [PeerId: [MessageId]] {
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
    
    private func processIndexOperationsCommitAccumulatedRemoveIndices(peerId: PeerId, accumulatedRemoveIndices: inout [MessageIndex], updatedCombinedState: inout CombinedPeerReadState?, invalidateReadState: inout Bool, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], outputOperations: inout [MessageHistoryOperation], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) {
        if !accumulatedRemoveIndices.isEmpty {
            let (combinedState, invalidate) = self.readStateTable.deleteMessages(peerId, indices: accumulatedRemoveIndices, incomingStatsInIndices: { peerId, namespace, indices in
                return self.incomingMessageStatsInIndices(peerId, namespace: namespace, indices: indices)
            })
            if let combinedState = combinedState {
                updatedCombinedState = combinedState
            }
            if invalidate {
                invalidateReadState = true
            }
            
            let buckets = self.continuousIndexIntervalsForRemoving(accumulatedRemoveIndices)
            for bucket in buckets {
                var indicesWithMetadata: [(MessageIndex, MessageTags)] = []
                var globalIndicesWithMetadata: [(GlobalMessageTags, MessageIndex)] = []
                
                for index in bucket {
                    let tagsAndGlobalTags = self.justRemove(index, unsentMessageOperations: &unsentMessageOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
                    if let (tags, globalTags) = tagsAndGlobalTags {
                        indicesWithMetadata.append((index, tags))
                        
                        if !globalTags.isEmpty {
                            globalIndicesWithMetadata.append((globalTags, index))
                        }
                    } else {
                        indicesWithMetadata.append((index, MessageTags()))
                    }
                }
                assert(bucket.count == indicesWithMetadata.count)
                outputOperations.append(.Remove(indicesWithMetadata))
                if !globalIndicesWithMetadata.isEmpty {
                    globalTagsOperations.append(.remove(globalIndicesWithMetadata))
                }
                var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                self.maybeCombineGroupsInNamespace(at: bucket[0], updatedGroupInfos: &updatedGroupInfos)
                if !updatedGroupInfos.isEmpty {
                    outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                }
            }
            
            accumulatedRemoveIndices.removeAll()
        }
    }
    
    private func processIndexOperations(_ peerId: PeerId, operations: [MessageHistoryIndexOperation], processedOperationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) {
        let sharedKey = self.key(MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: 0), timestamp: 0))
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = PostboxEncoder()
        
        var outputOperations: [MessageHistoryOperation] = []
        var accumulatedRemoveIndices: [(MessageIndex)] = []
        var accumulatedAddedIncomingMessageIndices = Set<MessageIndex>()
        
        var updatedCombinedState: CombinedPeerReadState?
        var invalidateReadState = false
        
        var updateExistingMedia: [MediaId: Media] = [:]
        
        let commitAccumulatedAddedIndices: () -> Void = {
            if !accumulatedAddedIncomingMessageIndices.isEmpty {
                let (combinedState, invalidate) = self.readStateTable.addIncomingMessages(peerId, indices: accumulatedAddedIncomingMessageIndices)
                if let combinedState = combinedState {
                    updatedCombinedState = combinedState
                }
                if invalidate {
                    invalidateReadState = true
                }
                
                accumulatedAddedIncomingMessageIndices.removeAll()
            }
        }
        
        for operation in operations {
            switch operation {
                case let .InsertMessage(storeMessage):
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
                    
                    let (message, updatedGroupInfos) = self.justInsertMessage(storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, localTagsOperations: &localTagsOperations, updateExistingMedia: &updateExistingMedia)
                    outputOperations.append(.InsertMessage(message))
                    if !updatedGroupInfos.isEmpty {
                        outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                    }
                    
                    if message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                        self.unsentTable.add(message.id, operations: &unsentMessageOperations)
                    }
                    if message.flags.contains(.Failed) {
                        self.failedTable.add(message.id)
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
                                self.tagsTable.add(tags: tag, index: message.index, isNewlyAdded: true, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                                if let threadId = message.threadId {
                                    self.threadTagsTable.add(tags: tag, threadId: threadId, index: message.index, isNewlyAdded: true, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                                }
                            }
                        }
                    }
                    if let threadId = message.threadId {
                        self.threadsTable.add(threadId: threadId, index: message.index)
                    }
                    let globalTags = message.globalTags.rawValue
                    if globalTags != 0 {
                        for i in 0 ..< 32 {
                            let currentTags = globalTags >> UInt32(i)
                            if currentTags == 0 {
                                break
                            }
                            
                            if (currentTags & 1) != 0 {
                                let tag = GlobalMessageTags(rawValue: 1 << UInt32(i))
                                if self.globalTagsTable.addMessage(tag, index: message.index) {
                                    globalTagsOperations.append(.insertMessage(tag, message))
                                }
                            }
                        }
                    }
                    if !message.localTags.isEmpty {
                        self.localTagsTable.set(id: message.id, tags: message.localTags, previousTags: [], operations: &localTagsOperations)
                    }
                    for attribute in MessageHistoryTable.renderMessageAttributes(message) {
                        if let (tag, timestamp) = attribute.automaticTimestampBasedAttribute {
                            self.timeBasedAttributesTable.set(tag: tag, id: message.id, timestamp: timestamp, operations: &timestampBasedMessageAttributesOperations)
                        }
                    }
                    if !message.flags.intersection(.IsIncomingMask).isEmpty {
                        accumulatedAddedIncomingMessageIndices.insert(message.index)
                    }
                case let .InsertExistingMessage(storeMessage):
                    commitAccumulatedAddedIndices()
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
                    
                    var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                    if let (message, previousTags) = self.justUpdate(storeMessage.index, message: storeMessage, keepLocalTags: true, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, updatedMedia: &updatedMedia) {
                        outputOperations.append(.Remove([(storeMessage.index, previousTags)]))
                        outputOperations.append(.InsertMessage(message))
                        if !updatedGroupInfos.isEmpty {
                            outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                        }
                }
                case let .Remove(index):
                    commitAccumulatedAddedIndices()
                    accumulatedRemoveIndices.append(index)
                case let .Update(index, storeMessage):
                    commitAccumulatedAddedIndices()
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
                    
                    var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                    if let (message, previousTags) = self.justUpdate(index, message: storeMessage, keepLocalTags: false, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, updatedMedia: &updatedMedia) {
                        outputOperations.append(.Remove([(index, previousTags)]))
                        outputOperations.append(.InsertMessage(message))
                        if !updatedGroupInfos.isEmpty {
                            outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                        }
                        
                        if !message.flags.intersection(.IsIncomingMask).isEmpty {
                            if index != message.index {
                                accumulatedRemoveIndices.append(index)
                                accumulatedAddedIncomingMessageIndices.insert(message.index)
                            }
                        }
                    }
                case let .UpdateTimestamp(index, timestamp):
                    commitAccumulatedAddedIndices()
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
                    
                    var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                    let tagsAndGlobalTags = self.justUpdateTimestamp(index, timestamp: timestamp, unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, updatedMedia: &updatedMedia)
                    outputOperations.append(.UpdateTimestamp(index, timestamp))
                    if !updatedGroupInfos.isEmpty {
                        outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                    }
                    if let (_, globalTags) = tagsAndGlobalTags {
                        if !globalTags.isEmpty {
                            globalTagsOperations.append(.updateTimestamp(globalTags, index, timestamp))
                        }
                    }
            }
        }
        
        commitAccumulatedAddedIndices()
        processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
        
        if let updatedCombinedState = updatedCombinedState {
            outputOperations.append(.UpdateReadState(peerId, updatedCombinedState))
        }
        
        if invalidateReadState {
            self.synchronizeReadStateTable.set(peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
        }
        
        if processedOperationsByPeerId[peerId] == nil {
            processedOperationsByPeerId[peerId] = outputOperations
        } else {
            processedOperationsByPeerId[peerId]!.append(contentsOf: outputOperations)
        }
        
        for (_, media) in updateExistingMedia {
            if let id = media.id {
                var updatedMessageIndices = Set<MessageIndex>()
                self.updateMedia(id, media: media, operationsByPeerId: &processedOperationsByPeerId, updatedMedia: &updatedMedia, updatedMessageIndices: &updatedMessageIndices)
            }
        }
        
        //self.debugCheckTagIndexIntegrity(peerId: peerId)
    }
    
    func internalStoreMessages(_ messages: [StoreMessage]) -> [InternalStoreMessage] {
        var internalStoreMessages: [InternalStoreMessage] = []
        for message in messages {
            switch message.id {
                case let .Id(id):
                    internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
                case let .Partial(peerId, namespace):
                    let id = self.historyMetadataTable.getNextMessageIdAndIncrement(peerId, namespace: namespace)
                    internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
            }
        }
        return internalStoreMessages
    }
    
    func addMessages(messages: [StoreMessage], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], processMessages: (([PeerId : [StoreMessage]]) -> Void)?) -> [Int64: MessageId] {
        let messagesByPeerId = self.messagesGroupedByPeerId(messages)
        var globallyUniqueIdToMessageId: [Int64: MessageId] = [:]
        var globalTagsInitialized = Set<GlobalMessageTags>()
        for (peerId, peerMessages) in messagesByPeerId {
            var operations: [MessageHistoryIndexOperation] = []
            let internalPeerMessages = self.internalStoreMessages(peerMessages)
            for message in internalPeerMessages {
                if let globallyUniqueId = message.globallyUniqueId {
                    globallyUniqueIdToMessageId[globallyUniqueId] = message.id
                }
                if !message.globalTags.isEmpty {
                    for tag in message.globalTags {
                        if !globalTagsInitialized.contains(tag) {
                            self.globalTagsTable.ensureInitialized(tag)
                            globalTagsInitialized.insert(tag)
                        }
                    }
                }
            }
            self.messageHistoryIndexTable.addMessages(internalPeerMessages, operations: &operations)
            
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
        }
        
        processMessages?(messagesByPeerId)
        
        return globallyUniqueIdToMessageId
    }
    
    func removeMessages(_ messageIds: [MessageId], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            
            for id in messageIds {
                self.messageHistoryIndexTable.removeMessage(id, operations: &operations)
            }
            
            if let forEachMedia = forEachMedia {
                for operation in operations {
                    if case let .Remove(index) = operation {
                        if let message = self.getMessage(index) {
                            for media in self.renderMessageMedia(referencedMedia: message.referencedMedia, embeddedMediaData: message.embeddedMediaData) {
                                forEachMedia(media)
                            }
                        }
                    }
                }
            }
            
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
        }
    }
    
    func removeMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.removeMessagesInRange(peerId: peerId, namespace: namespace, minId: minId, maxId: maxId, operations: &operations)
        if let forEachMedia = forEachMedia {
            for operation in operations {
                if case let .Remove(index) = operation {
                    if let message = self.getMessage(index) {
                        for media in self.renderMessageMedia(referencedMedia: message.referencedMedia, embeddedMediaData: message.embeddedMediaData) {
                            forEachMedia(media)
                        }
                    }
                }
            }
        }
        
        self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
    }

    func clearHistoryInRange(peerId: PeerId, threadId: Int64?, minTimestamp: Int32, maxTimestamp: Int32, namespaces: MessageIdNamespaces, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        var indices = self.allMessageIndices(peerId: peerId).filter { namespaces.contains($0.id.namespace) }
        if let threadId = threadId {
            indices = indices.filter { index in
                if let message = self.getMessage(index) {
                    if message.threadId == threadId {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        indices = indices.filter { index in
            return index.timestamp >= minTimestamp && index.timestamp <= maxTimestamp
        }
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, forEachMedia: forEachMedia)
    }
    
    func clearHistory(peerId: PeerId, threadId: Int64?, namespaces: MessageIdNamespaces, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        var indices = self.allMessageIndices(peerId: peerId).filter { namespaces.contains($0.id.namespace) }
        if let threadId = threadId {
            indices = indices.filter { index in
                if let message = self.getMessage(index) {
                    if message.threadId == threadId {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, forEachMedia: forEachMedia)
    }
    
    func removeAllMessagesWithAuthor(peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        let indices = self.allIndicesWithAuthor(peerId: peerId, authorId: authorId, namespace: namespace)
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, forEachMedia: forEachMedia)
    }
    
    func removeAllMessagesWithGlobalTag(tag: GlobalMessageTags, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        var indices: [MessageIndex] = []
        for entry in self.allIndicesWithGlobalTag(tag: tag) {
            switch entry {
            case let .message(index):
                indices.append(index)
            case .hole:
                break
            }
        }
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, forEachMedia: forEachMedia)
    }
    
    func removeAllMessagesWithForwardAuthor(peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], forEachMedia: ((Media) -> Void)?) {
        let indices = self.allIndicesWithForwardAuthor(peerId: peerId, forwardAuthorId: forwardAuthorId, namespace: namespace)
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, forEachMedia: forEachMedia)
    }
    
    func updateMessage(_ id: MessageId, message: StoreMessage, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.updateMessage(id, message: self.internalStoreMessages([message]).first!, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
    }
    
    func updateMessageTimestamp(_ id: MessageId, timestamp: Int32, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.updateTimestamp(id, timestamp: timestamp, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
    }
    
    func updateMedia(_ id: MediaId, media: Media?, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], updatedMessageIndices: inout Set<MessageIndex>) {
        if let (previousIndex, previousMedia) = self.messageMediaTable.get(id, embedded: { index, id in
            return self.embeddedMediaForIndex(index, id: id)
        }) {
            if let media = media {
                if !previousMedia.isEqual(to: media) {
                    self.messageMediaTable.update(id, media: media, messageHistoryTable: self, operationsByPeerId: &operationsByPeerId)
                    updatedMedia[id] = media
                    if let previousIndex = previousIndex {
                        updatedMessageIndices.insert(previousIndex)
                    }
                }
            } else {
                updatedMedia[id] = nil
                if case let .Embedded(index) = self.messageMediaTable.removeReference(id) {
                    self.updateEmbeddedMedia(index, operationsByPeerId: &operationsByPeerId, update: { previousMedia in
                        var updated: [Media] = []
                        for previous in previousMedia {
                            if previous.id != id {
                                updated.append(previous)
                            }
                        }
                        return updated
                    })
                    updatedMessageIndices.insert(index)
                }
            }
        }
    }
    
    func storeMediaIfNotPresent(media: Media) {
        guard let id = media.id else {
            return
        }
        if let _ = self.messageMediaTable.get(id, embedded: { index, id in
            return self.embeddedMediaForIndex(index, id: id)
        }) {
        } else {
            let _ = self.messageMediaTable.set(media, index: nil, messageHistoryTable: self)
        }
    }
    
    func getMedia(_ id: MediaId) -> Media? {
        return self.messageMediaTable.get(id, embedded: { index, id in
            return self.embeddedMediaForIndex(index, id: id)
        })?.1
    }
    
    func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) {
        for (peerId, namespaces) in states {
            if let combinedState = self.readStateTable.resetStates(peerId, namespaces: namespaces) {
                if operationsByPeerId[peerId] == nil {
                    operationsByPeerId[peerId] = [.UpdateReadState(peerId, combinedState)]
                } else {
                    operationsByPeerId[peerId]!.append(.UpdateReadState(peerId, combinedState))
                }
            }
            self.synchronizeReadStateTable.set(peerId, operation: nil, operations: &updatedPeerReadStateOperations)
        }
    }
    

    func applyIncomingReadMaxId(_ messageId: MessageId, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) {
        var topMessageId: (MessageId.Id, Bool)?
        if let index = self.topIndexEntry(peerId: messageId.peerId, namespace: messageId.namespace) {
            if let message = self.getMessage(index) {
                topMessageId = (index.id.id, message.flags.intersection(.IsIncomingMask).isEmpty)
            } else {
                topMessageId = (index.id.id, false)
            }
        }
        
        let (combinedState, invalidated) = self.readStateTable.applyIncomingMaxReadId(messageId, incomingStatsInRange: { namespace, fromId, toId in
            return self.messageHistoryIndexTable.incomingMessageCountInRange(messageId.peerId, namespace: namespace, minId: fromId, maxId: toId)
        }, topMessageId: topMessageId)
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageId.peerId] == nil {
                operationsByPeerId[messageId.peerId] = [.UpdateReadState(messageId.peerId, combinedState)]
            } else {
                operationsByPeerId[messageId.peerId]!.append(.UpdateReadState(messageId.peerId, combinedState))
            }
        }
        
        if invalidated {
            self.synchronizeReadStateTable.set(messageId.peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
        }
    }
    
    func applyOutgoingReadMaxId(_ messageId: MessageId, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) {
        let (combinedState, invalidated) = self.readStateTable.applyOutgoingMaxReadId(messageId)
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageId.peerId] == nil {
                operationsByPeerId[messageId.peerId] = [.UpdateReadState(messageId.peerId, combinedState)]
            } else {
                operationsByPeerId[messageId.peerId]!.append(.UpdateReadState(messageId.peerId, combinedState))
            }
        }
        
        if invalidated {
            self.synchronizeReadStateTable.set(messageId.peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
        }
    }
    
    
    func applyOutgoingReadMaxIndex(_ messageIndex: MessageIndex, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) -> [MessageId] {
        let (combinedState, invalidated, messageIds) = self.readStateTable.applyOutgoingMaxReadIndex(messageIndex, outgoingIndexStatsInRange: { fromIndex, toIndex in
            return self.outgoingMessageCountInRange(messageIndex.id.peerId, namespace: messageIndex.id.namespace, fromIndex: fromIndex, toIndex: toIndex)
        })
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageIndex.id.peerId] == nil {
                operationsByPeerId[messageIndex.id.peerId] = [.UpdateReadState(messageIndex.id.peerId, combinedState)]
            } else {
                operationsByPeerId[messageIndex.id.peerId]!.append(.UpdateReadState(messageIndex.id.peerId, combinedState))
            }
        }
        
        if invalidated {
            self.synchronizeReadStateTable.set(messageIndex.id.peerId, operation: .Validate, operations: &updatedPeerReadStateOperations)
        }
        
        return messageIds
    }
    
    func applyInteractiveMaxReadIndex(postbox: PostboxImpl, messageIndex: MessageIndex, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) -> [MessageId] {
        var topMessageId: (MessageId.Id, Bool)?
        if let index = self.topIndexEntry(peerId: messageIndex.id.peerId, namespace: messageIndex.id.namespace) {
            if let message = self.getMessage(index) {
                topMessageId = (index.id.id, message.flags.intersection(.IsIncomingMask).isEmpty)
            } else {
                topMessageId = (index.id.id, false)
            }
        }
        
        let (combinedState, result, messageIds) = self.readStateTable.applyInteractiveMaxReadIndex(postbox: postbox, messageIndex: messageIndex, incomingStatsInRange: { namespace, fromId, toId in
            return self.messageHistoryIndexTable.incomingMessageCountInRange(messageIndex.id.peerId, namespace: namespace, minId: fromId, maxId: toId)
        }, incomingIndexStatsInRange: { fromIndex, toIndex in
            return self.incomingMessageCountInRange(messageIndex.id.peerId, namespace: messageIndex.id.namespace, fromIndex: fromIndex, toIndex: toIndex)
        }, topMessageId: topMessageId, topMessageIndexByNamespace: { namespace in
            if let index = self.topIndexEntry(peerId: messageIndex.id.peerId, namespace: namespace) {
                return index
            } else {
                return nil
            }
        })
        
        if let combinedState = combinedState {
            if operationsByPeerId[messageIndex.id.peerId] == nil {
                operationsByPeerId[messageIndex.id.peerId] = [.UpdateReadState(messageIndex.id.peerId, combinedState)]
            } else {
                operationsByPeerId[messageIndex.id.peerId]!.append(.UpdateReadState(messageIndex.id.peerId, combinedState))
            }
        }
        
        switch result {
            case let .Push(thenSync):
                self.synchronizeReadStateTable.set(messageIndex.id.peerId, operation: .Push(state: self.readStateTable.getCombinedState(messageIndex.id.peerId), thenSync: thenSync), operations: &updatedPeerReadStateOperations)
            case .None:
                break
        }
        
        return messageIds
    }
    
    func topIndex(peerId: PeerId) -> MessageIndex? {
        var topIndex: MessageIndex?
        for namespace in self.messageHistoryIndexTable.existingNamespaces(peerId: peerId) where self.seedConfiguration.chatMessagesNamespaces.contains(namespace) {
            self.valueBox.range(self.table, start: self.upperBound(peerId: peerId, namespace: namespace), end: self.lowerBound(peerId: peerId, namespace: namespace), keys: { key in
                let index = extractKey(key)
                if let topIndexValue = topIndex {
                    if topIndexValue < index {
                        topIndex = index
                    }
                } else {
                    topIndex = index
                }
                return false
            }, limit: 1)
        }
        
        return topIndex
    }
    
    func topMessage(peerId: PeerId) -> IntermediateMessage? {
        return self.topIndex(peerId: peerId).flatMap(self.getMessage)
    }
    
    func exists(index: MessageIndex) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(index))
    }
    
    func topIndexEntry(peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        let result = self.messageHistoryIndexTable.top(peerId, namespace: namespace)
        return result
    }
    
    func getMessage(_ index: MessageIndex) -> IntermediateMessage? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.table, key: key) {
            let entry = self.readIntermediateEntry(key, value: value)
            return entry.message
        } else if let updatedIndex = self.messageHistoryIndexTable.getIndex(index.id) {
            let key = self.key(updatedIndex)
            if let value = self.valueBox.get(self.table, key: key) {
                let entry = self.readIntermediateEntry(key, value: value)
                return entry.message
            }
        }
        return nil
    }
    
    private func getMessageGroup(startingAt index: MessageIndex, limit: Int, initialPredicate: (IntermediateMessage) -> Bool, predicate: (IntermediateMessage, IntermediateMessage) -> Bool) -> [IntermediateMessage]? {
        guard let value = self.valueBox.get(self.table, key: self.key(index)) else {
            return nil
        }
        
        let centralMessage = self.readIntermediateEntry(self.key(index), value: value).message
        
        if !initialPredicate(centralMessage) {
            return nil
        }
        
        if !predicate(centralMessage, centralMessage) {
            return [centralMessage]
        }
        
        var result: [IntermediateMessage] = []
       
        var previousIndex = index
        while true {
            var previous: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.table, start: self.key(previousIndex), end: self.lowerBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
                previous = readIntermediateEntry(key, value: value)
                return false
            }, limit: 1)
            if let previous = previous, predicate(previous.message, centralMessage) {
                result.insert(previous.message, at: 0)
                if result.count == limit {
                    return result
                }
                previousIndex = previous.message.index
            } else {
                break
            }
        }
        
        result.append(centralMessage)
        if result.count == limit {
            return result
        }
        
        var nextIndex = index
        while true {
            var next: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.table, start: self.key(nextIndex), end: self.upperBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
                next = readIntermediateEntry(key, value: value)
                return false
            }, limit: 1)
            if let next = next, predicate(next.message, centralMessage) {
                result.append(next.message)
                if result.count == limit {
                    return result
                }
                nextIndex = next.message.index
            } else {
                break
            }
        }
        return result
    }
    
    func getMessageGroup(at index: MessageIndex, limit: Int) -> [IntermediateMessage]? {
        return self.getMessageGroup(startingAt: index, limit: limit, initialPredicate: { _ in
            return true
        }, predicate: { lhs, rhs in
            guard let lhsGroupingKey = lhs.groupingKey, let rhsGroupingKey = rhs.groupingKey else {
                return false
            }
            return lhsGroupingKey == rhsGroupingKey
        })
    }
    
    func getMessageForwardedGroup(at index: MessageIndex, limit: Int) -> [IntermediateMessage]? {
        return self.getMessageGroup(startingAt: index, limit: limit, initialPredicate: { message in
            return message.forwardInfo != nil
        }, predicate: { lhs, rhs in
            if lhs.forwardInfo == nil {
                return false
            }
            if rhs.forwardInfo == nil {
                return false
            }
            if lhs.authorId != rhs.authorId {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            return true
        })
    }
    
    func getMessageFailedGroup(at index: MessageIndex, limit: Int) -> [IntermediateMessage]? {
        return self.getMessageGroup(startingAt: index, limit: limit, initialPredicate: { message in
            return message.flags.contains(.Failed)
        }, predicate: { lhs, rhs in
            if !lhs.flags.contains(.Failed) {
                return false
            }
            if !rhs.flags.contains(.Failed) {
                return false
            }
            if lhs.authorId != rhs.authorId {
                return false
            }
            return true
        })
    }
    
    func offsetPendingMessagesTimestamps(lowerBound: MessageId, excludeIds: Set<MessageId>, timestamp: Int32, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation],  updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) {
        var peerMessageIds: [MessageId] = []
        for messageId in self.unsentTable.get() {
            if messageId.peerId == lowerBound.peerId && messageId.namespace == lowerBound.namespace && messageId.id > lowerBound.id {
                if !excludeIds.contains(messageId) {
                    peerMessageIds.append(messageId)
                }
            }
        }
        
        peerMessageIds.sort()
        
        for messageId in peerMessageIds.reversed() {
            self.updateMessageTimestamp(messageId, timestamp: timestamp, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations)
        }
    }
    
    func updateMessageGroupingKeysAtomically(ids: [MessageId], groupingKey: Int64, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation],  updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if ids.isEmpty {
            return
        }
        
        var indices: [MessageIndex] = []
        for id in ids {
            if let index = self.messageHistoryIndexTable.getIndex(id) {
                indices.append(index)
            }
        }
        indices.sort()
        assert(indices.count == ids.count)
        
        for index in indices {
            if let message = self.getMessage(index), let _ = message.groupInfo {
                let updatedMessage = message.withUpdatedGroupingKey(groupingKey)
                self.storeIntermediateMessage(updatedMessage, sharedKey: self.key(MessageIndex.absoluteLowerBound()))
                
                let operations: [MessageHistoryOperation] = [
                    .Remove([(index, message.tags)]),
                    .InsertMessage(updatedMessage)
                ]
                if operationsByPeerId[message.id.peerId] == nil {
                    operationsByPeerId[message.id.peerId] = operations
                } else {
                    operationsByPeerId[message.id.peerId]!.append(contentsOf: operations)
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    private func adjacentEntriesInNamespace(index: MessageIndex, groupingKey: Int64) -> (lower: (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo), upper: (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo)) {
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        self.valueBox.range(self.table, start: self.key(index), end: self.lowerBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
            lower = self.readIntermediateEntry(key, value: value)
            return false
        }, limit: 1)
        
        self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
            upper = self.readIntermediateEntry(key, value: value)
            return false
        }, limit: 1)
        
        return (getAdjacentEntryGroupInfo(lower, key: groupingKey), getAdjacentEntryGroupInfo(upper, key: groupingKey))
    }
    
    private func adjacentMessagesInNamespace(index: MessageIndex) -> (lower: IntermediateMessage?, upper: IntermediateMessage?) {
        var lower: IntermediateMessage?
        var upper: IntermediateMessage?
        
        self.valueBox.range(self.table, start: self.key(index), end: self.lowerBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
            lower = self.readIntermediateEntry(key, value: value).message
            return false
        }, limit: 1)
        
        self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(peerId: index.id.peerId, namespace: index.id.namespace), values: { key, value in
            upper = self.readIntermediateEntry(key, value: value).message
            return false
        }, limit: 1)
        
        return (lower, upper)
    }
    
    private func generateNewGroupInfo() -> MessageGroupInfo {
        return MessageGroupInfo(stableId: self.historyMetadataTable.getNextStableMessageIndexId())
    }
    
    private func updateSameGroupInfosInNamespace(lowerBound: MessageIndex, from previousInfo: MessageGroupInfo, to updatedInfo: MessageGroupInfo, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        var index = lowerBound
        while true {
            var entry: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(peerId: lowerBound.id.peerId, namespace: lowerBound.id.namespace), values: { key, value in
                entry = readIntermediateEntry(key, value: value)
                return false
            }, limit: 1)
            if let entry = entry, entry.message.groupInfo == previousInfo {
                let updatedMessage = entry.message.withUpdatedGroupInfo(updatedInfo)
                self.storeIntermediateMessage(updatedMessage, sharedKey: self.key(entry.message.index))
                updatedGroupInfos[entry.message.id] = updatedInfo
                index = entry.message.index
            } else {
                break
            }
        }
    }
    
    private func maybeSeparateGroupsInNamespace(at index: MessageIndex, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        let (lower, upper) = self.adjacentMessagesInNamespace(index: index)
        if let lower = lower, let upper = upper, let groupInfo = lower.groupInfo, lower.groupInfo == upper.groupInfo {
            self.updateSameGroupInfosInNamespace(lowerBound: index, from: groupInfo, to: self.generateNewGroupInfo(), updatedGroupInfos: &updatedGroupInfos)
        }
    }
    
    private func maybeCombineGroupsInNamespace(at index: MessageIndex, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        let (lower, upper) = self.adjacentMessagesInNamespace(index: index)
        if let lower = lower, let upper = upper, let groupInfo = lower.groupInfo, lower.groupingKey == upper.groupingKey {
            assert(upper.groupInfo != nil)
            if lower.groupInfo != upper.groupInfo {
                if let upperGroupInfo = upper.groupInfo {
                    self.updateSameGroupInfosInNamespace(lowerBound: index, from: groupInfo, to: upperGroupInfo, updatedGroupInfos: &updatedGroupInfos)
                }
            }
        }
    }
    
    private func updateGroupingInfoAroundInsertionInNamespace(index: MessageIndex, groupingKey: Int64?, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) -> MessageGroupInfo? {
        if let groupingKey = groupingKey {
            var groupInfo: MessageGroupInfo?
            
            let (lowerEntryAndGroup, upperEntryAndGroup) = adjacentEntriesInNamespace(index: index, groupingKey: groupingKey)
            
            let (_, lowerGroup) = lowerEntryAndGroup
            let (_, upperGroup) = upperEntryAndGroup
            
            switch (lowerGroup, upperGroup) {
                case (.none, .none):
                    groupInfo = self.generateNewGroupInfo()
                case (.none, .otherGroup):
                    groupInfo = self.generateNewGroupInfo()
                case (.otherGroup, .none):
                    groupInfo = self.generateNewGroupInfo()
                case (.none, .sameGroup(let info)):
                    groupInfo = info
                case (.sameGroup(let info), .none):
                    groupInfo = info
                case (.sameGroup(let info), .sameGroup(let otherInfo)):
                    assert(info == otherInfo)
                    groupInfo = info
                case (.sameGroup(let info), .otherGroup):
                    groupInfo = info
                case (.otherGroup, .sameGroup(let info)):
                    groupInfo = info
                case (.otherGroup(let info), .otherGroup(let otherInfo)):
                    groupInfo = self.generateNewGroupInfo()
                    if info == otherInfo {
                        self.updateSameGroupInfosInNamespace(lowerBound: index, from: otherInfo, to: self.generateNewGroupInfo(), updatedGroupInfos: &updatedGroupInfos)
                    }
            }
            return groupInfo
        } else {
            self.maybeSeparateGroupsInNamespace(at: index, updatedGroupInfos: &updatedGroupInfos)
            return nil
        }
    }
    
    private func justInsertMessage(_ message: InternalStoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: PostboxEncoder, localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], updateExistingMedia: inout [MediaId: Media]) -> (IntermediateMessage, [MessageId: MessageGroupInfo]) {
        var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
        
        let groupInfo = self.updateGroupingInfoAroundInsertionInNamespace(index: message.index, groupingKey: message.groupingKey, updatedGroupInfos: &updatedGroupInfos)
        
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)
        
        var stableId: UInt32 = self.historyMetadataTable.getNextStableMessageIndexId()
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        
        var stableVersion: UInt32 = 0
        sharedBuffer.write(&stableVersion, offset: 0, length: 4)
        
        var dataFlags: MessageDataFlags = []
        if message.globallyUniqueId != nil {
            dataFlags.insert(.hasGloballyUniqueId)
        }
        if !message.globalTags.isEmpty {
            dataFlags.insert(.hasGlobalTags)
        }
        if message.groupingKey != nil {
            dataFlags.insert(.hasGroupingKey)
        }
        if groupInfo != nil {
            dataFlags.insert(.hasGroupInfo)
        }
        if !message.localTags.isEmpty {
            dataFlags.insert(.hasLocalTags)
        }
        if message.threadId != nil {
            dataFlags.insert(.hasThreadId)
        }
        sharedBuffer.write(&dataFlags, offset: 0, length: 1)
        if let globallyUniqueId = message.globallyUniqueId {
            var globallyUniqueIdValue = globallyUniqueId
            sharedBuffer.write(&globallyUniqueIdValue, offset: 0, length: 8)
            self.globallyUniqueMessageIdsTable.set(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId, id: message.id)
        }
        if !message.globalTags.isEmpty {
            var globalTagsValue: UInt32 = message.globalTags.rawValue
            sharedBuffer.write(&globalTagsValue, offset: 0, length: 4)
        }
        if let groupingKey = message.groupingKey {
            var groupingKeyValue = groupingKey
            sharedBuffer.write(&groupingKeyValue, offset: 0, length: 8)
        }
        if let groupInfo = groupInfo {
            var stableIdValue = groupInfo.stableId
            sharedBuffer.write(&stableIdValue, offset: 0, length: 4)
        }
        if !message.localTags.isEmpty {
            var localTagsValue: UInt32 = message.localTags.rawValue
            sharedBuffer.write(&localTagsValue, offset: 0, length: 4)
        }
        if var threadId = message.threadId {
            sharedBuffer.write(&threadId, length: 8)
        }
        
        if self.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
            var indexableText = message.text
            for media in message.media {
                if let mediaText = media.indexableText {
                    indexableText.append(" ")
                    indexableText.append(mediaText)
                }
            }
            self.textIndexTable.add(messageId: message.id, text: indexableText, tags: message.tags)
        }
        
        var flags = MessageFlags(message.flags)
        sharedBuffer.write(&flags.rawValue, offset: 0, length: 4)
        
        var tags = message.tags
        sharedBuffer.write(&tags.rawValue, offset: 0, length: 4)
        
        var intermediateForwardInfo: IntermediateMessageForwardInfo?
        if let forwardInfo = message.forwardInfo {
            intermediateForwardInfo = IntermediateMessageForwardInfo(forwardInfo)
            
            var forwardInfoFlags: Int8 = 1 << 0
            if forwardInfo.sourceId != nil {
                forwardInfoFlags |= 1 << 1
            }
            if forwardInfo.sourceMessageId != nil {
                forwardInfoFlags |= 1 << 2
            }
            if forwardInfo.authorSignature != nil {
                forwardInfoFlags |= 1 << 3
            }
            if forwardInfo.psaType != nil {
                forwardInfoFlags |= 1 << 4
            }
            if !forwardInfo.flags.isEmpty {
                forwardInfoFlags |= 1 << 5
            }
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
            var forwardAuthorId: Int64 = forwardInfo.authorId?.toInt64() ?? 0
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
            
            if let authorSignature = forwardInfo.authorSignature {
                if let data = authorSignature.data(using: .utf8, allowLossyConversion: true) {
                    var length: Int32 = Int32(data.count)
                    sharedBuffer.write(&length, offset: 0, length: 4)
                    sharedBuffer.write(data)
                } else {
                    var length: Int32 = 0
                    sharedBuffer.write(&length, offset: 0, length: 4)
                }
            }
            
            if let psaType = forwardInfo.psaType {
                if let data = psaType.data(using: .utf8, allowLossyConversion: true) {
                    var length: Int32 = Int32(data.count)
                    sharedBuffer.write(&length, offset: 0, length: 4)
                    sharedBuffer.write(data)
                } else {
                    var length: Int32 = 0
                    sharedBuffer.write(&length, offset: 0, length: 4)
                }
            }
            
            if !forwardInfo.flags.isEmpty {
                var value: Int32 = forwardInfo.flags.rawValue
                sharedBuffer.write(&value, offset: 0, length: 4)
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

        if let data = message.text.data(using: .utf8, allowLossyConversion: true) {
            var length: Int32 = Int32(data.count)
            sharedBuffer.write(&length, offset: 0, length: 4)
            sharedBuffer.write(data)
        } else {
            var length: Int32 = 0
            sharedBuffer.write(&length, offset: 0, length: 4)
        }

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
                let mediaInsertResult = self.messageMediaTable.set(media, index: message.index, messageHistoryTable: self)
                switch mediaInsertResult {
                    case let .Embed(media):
                        embeddedMedia.append(media)
                    case .Reference:
                        referencedMedia.append(mediaId)
                        if media.isLikelyToBeUpdated() {
                            updateExistingMedia[mediaId] = media
                        }
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
        
        self.valueBox.set(self.table, key: self.key(message.index, key: sharedKey), value: sharedBuffer)
        
        let result = (IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia), updatedGroupInfos)
        
        return result
    }
    
    private func continuousIndexIntervalsForRemoving(_ indices: [MessageIndex]) -> [[MessageIndex]] {
        guard !indices.isEmpty else {
            return []
        }
        
        if indices.count == 1 {
            return [indices]
        }
        
        let indices = indices.sorted(by: {
            $0 < $1
        })
        var result: [[(MessageIndex)]] = []
        var bucket: [(MessageIndex)] = []
        
        bucket.append(indices[0])
        
        for i in 1 ..< indices.count {
            self.valueBox.range(self.table, start: self.key(indices[i]), end: self.key(bucket[bucket.count - 1]).predecessor, keys: { key in
                let entryIndex = extractKey(key)
                if entryIndex != indices[i - 1] {
                    result.append(bucket)
                    bucket.removeAll()
                }
                return true
            }, limit: 1)
            bucket.append(indices[i])
        }
        
        if !bucket.isEmpty {
            result.append(bucket)
        }
        
        return result
    }
    
    private func justRemove(_ index: MessageIndex, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation]) -> (MessageTags, GlobalMessageTags)? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.table, key: key) {
            let resultTags: MessageTags
            let resultGlobalTags: GlobalMessageTags
            let message = self.readIntermediateEntry(key, value: value).message
            let embeddedMediaData = message.embeddedMediaData
            if embeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        self.messageMediaTable.removeEmbeddedMedia(media)
                    }
                    embeddedMediaData.skip(Int(mediaLength))
                }
            }
        
            if message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                self.unsentTable.remove(index.id, operations: &unsentMessageOperations)
            }
            if message.flags.contains(.Failed) {
                self.failedTable.remove(message.id)
            }
        
            if let globallyUniqueId = message.globallyUniqueId {
                self.globallyUniqueMessageIdsTable.remove(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId)
            }
        
            self.pendingActionsTable.removeMessage(id: message.id, operations: &pendingActionsOperations, updatedSummaries: &updatedMessageActionsSummaries)
        
            for tag in message.tags {
                self.tagsTable.remove(tags: tag, index: index, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                if let threadId = message.threadId {
                    self.threadTagsTable.remove(tags: tag, threadId: threadId, index: index, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                }
            }
            if let threadId = message.threadId {
                self.threadsTable.remove(threadId: threadId, index: index)
            }
            for tag in message.globalTags {
                self.globalTagsTable.remove(tag, index: index)
            }
            if !message.localTags.isEmpty {
                self.localTagsTable.set(id: index.id, tags: [], previousTags: message.localTags, operations: &localTagsOperations)
            }
            for attribute in MessageHistoryTable.renderMessageAttributes(message) {
                if let (tag, _) = attribute.automaticTimestampBasedAttribute {
                    self.timeBasedAttributesTable.remove(tag: tag, id: message.id, operations: &timestampBasedMessageAttributesOperations)
                }
            }
        
            for mediaId in message.referencedMedia {
                let _ = self.messageMediaTable.removeReference(mediaId)
            }
        
            if self.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
                self.textIndexTable.remove(messageId: message.id)
            }
        
            resultTags = message.tags
            resultGlobalTags = message.globalTags
            
            self.valueBox.remove(self.table, key: key, secure: true)
            return (resultTags, resultGlobalTags)
        } else {
            return nil
        }
    }
    
    func embeddedMediaForIndex(_ index: MessageIndex, id: MediaId) -> Media? {
        if let message = self.getMessage(index), message.embeddedMediaData.length > 4 {
            var embeddedMediaCount: Int32 = 0
            message.embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
            
            for _ in 0 ..< embeddedMediaCount {
                var mediaLength: Int32 = 0
                message.embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                if let readMedia = PostboxDecoder(buffer: MemoryBuffer(memory: message.embeddedMediaData.memory + message.embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    
                    if let readMediaId = readMedia.id, readMediaId == id {
                        return readMedia
                    }
                }
                message.embeddedMediaData.skip(Int(mediaLength))
            }
        }
        
        return nil
    }
    
    func updateEmbeddedMedia(_ index: MessageIndex, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], update: ([Media]) -> [Media]) {
        if let message = self.getMessage(index) {
            var embeddedMediaCount: Int32 = 0
            message.embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
            
            var previousMedia: [Media] = []
            for _ in 0 ..< embeddedMediaCount {
                var mediaLength: Int32 = 0
                message.embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                if let readMedia = PostboxDecoder(buffer: MemoryBuffer(memory: message.embeddedMediaData.memory + message.embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    previousMedia.append(readMedia)
                }
                message.embeddedMediaData.skip(Int(mediaLength))
            }
            
            let updatedMedia = update(previousMedia)
            var updated = false
            if updatedMedia.count != previousMedia.count {
                updated = true
            } else {
                outer: for i in 0 ..< previousMedia.count {
                    if !previousMedia[i].isEqual(to: updatedMedia[i]) {
                        updated = true
                        break outer
                    }
                }
            }
            
            if updated {
                var updatedEmbeddedMediaCount: Int32 = Int32(updatedMedia.count)
                
                let updatedEmbeddedMediaBuffer = WriteBuffer()
                updatedEmbeddedMediaBuffer.write(&updatedEmbeddedMediaCount, offset: 0, length: 4)
                
                let encoder = PostboxEncoder()
                
                for media in updatedMedia {
                    encoder.reset()
                    encoder.encodeRootObject(media)
                    withExtendedLifetime(encoder, {
                        let encodedBuffer = encoder.readBufferNoCopy()
                        var encodedLength: Int32 = Int32(encodedBuffer.length)
                        updatedEmbeddedMediaBuffer.write(&encodedLength, offset: 0, length: 4)
                        updatedEmbeddedMediaBuffer.write(encodedBuffer.memory, offset: 0, length: encodedBuffer.length)
                    })
                }
                
                withExtendedLifetime(updatedEmbeddedMediaBuffer, {
                    self.storeIntermediateMessage(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: message.referencedMedia), sharedKey: self.key(index))
                })
                
                let operation: MessageHistoryOperation = .UpdateEmbeddedMedia(index, updatedEmbeddedMediaBuffer.makeReadBufferAndReset())
                if operationsByPeerId[index.id.peerId] == nil {
                    operationsByPeerId[index.id.peerId] = [operation]
                } else {
                    operationsByPeerId[index.id.peerId]!.append(operation)
                }
            }
        }
    }
    
    func updateEmbeddedMedia(_ index: MessageIndex, mediaId: MediaId, media: Media?, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]]) {
        self.updateEmbeddedMedia(index, operationsByPeerId: &operationsByPeerId, update: { previousMedia in
            var updatedMedia: [Media] = []
            for previous in previousMedia {
                if previous.id == mediaId {
                    if let media = media {
                        updatedMedia.append(media)
                    }
                } else {
                    updatedMedia.append(previous)
                }
            }
            return updatedMedia
        })
    }
    
    private func justUpdate(_ index: MessageIndex, message: InternalStoreMessage, keepLocalTags: Bool, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: PostboxEncoder, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], updatedGroupInfos: inout [MessageId: MessageGroupInfo], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], updatedMedia: inout [MediaId: Media?]) -> (IntermediateMessage, MessageTags)? {
        if let previousMessage = self.getMessage(index) {
            var mediaToUpdate: [Media] = []
            
            var previousEmbeddedMediaWithIds: [(MediaId, Media)] = []
            if previousMessage.embeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                let previousEmbeddedMediaData = previousMessage.embeddedMediaData
                previousEmbeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    previousEmbeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = PostboxDecoder(buffer: MemoryBuffer(memory: previousEmbeddedMediaData.memory + previousEmbeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        if let mediaId = media.id {
                            previousEmbeddedMediaWithIds.append((mediaId, media))
                        }
                    }
                    previousEmbeddedMediaData.skip(Int(mediaLength))
                }
            }
            
            var previousMediaIds = Set<MediaId>()
            for (mediaId, _) in previousEmbeddedMediaWithIds {
                previousMediaIds.insert(mediaId)
            }
            for mediaId in previousMessage.referencedMedia {
                previousMediaIds.insert(mediaId)
            }
            
            var updatedMediaIds = Set<MediaId>()
            for media in message.media {
                if let mediaId = media.id {
                    updatedMediaIds.insert(mediaId)
                }
            }
            
            if previousMediaIds != updatedMediaIds || index != message.index {
                for (_, media) in previousEmbeddedMediaWithIds {
                    self.messageMediaTable.removeEmbeddedMedia(media)
                }
                for mediaId in previousMessage.referencedMedia {
                    let _ = self.messageMediaTable.removeReference(mediaId)
                }
            }
            
            var previousAttributes: [MessageAttribute] = []
            let attributesData = previousMessage.attributesData.sharedBufferNoCopy()
            if attributesData.length > 4 {
                var attributeCount: Int32 = 0
                attributesData.read(&attributeCount, offset: 0, length: 4)
                for _ in 0 ..< attributeCount {
                    var attributeLength: Int32 = 0
                    attributesData.read(&attributeLength, offset: 0, length: 4)
                    if let attribute = PostboxDecoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() as? MessageAttribute {
                        previousAttributes.append(attribute)
                    }
                    attributesData.skip(Int(attributeLength))
                }
            }
            
            var updatedAttributes = message.attributes
            self.seedConfiguration.mergeMessageAttributes(previousAttributes, &updatedAttributes)
            
            self.valueBox.remove(self.table, key: self.key(index), secure: true)
            
            let updatedIndex = message.index
            
            let updatedGroupInfo = self.updateMovingGroupInfoInNamespace(index: updatedIndex, updatedIndex: updatedIndex, groupingKey: message.groupingKey, previousInfo: previousMessage.groupInfo, updatedGroupInfos: &updatedGroupInfos)
            
            if previousMessage.tags != message.tags || index != updatedIndex {
                if !previousMessage.tags.isEmpty {
                    self.tagsTable.remove(tags: previousMessage.tags, index: index, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    if let threadId = previousMessage.threadId {
                        self.threadTagsTable.remove(tags: previousMessage.tags, threadId: threadId, index: index, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    }
                }
                if !message.tags.isEmpty {
                    //let isNewlyAdded = previousMessage.tags.isEmpty
                    self.tagsTable.add(tags: message.tags, index: message.index, isNewlyAdded: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    
                    if let threadId = message.threadId {
                        self.threadTagsTable.add(tags: message.tags, threadId: threadId, index: message.index, isNewlyAdded: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    }
                }
            }
            if previousMessage.threadId != message.threadId || index != message.index {
                if let threadId = previousMessage.threadId {
                    self.threadsTable.remove(threadId: threadId, index: index)
                }
                if let threadId = message.threadId {
                    self.threadsTable.add(threadId: threadId, index: message.index)
                }
            }
            
            if !previousMessage.globalTags.isEmpty || !message.globalTags.isEmpty {
                if !previousMessage.globalTags.isEmpty {
                    for tag in previousMessage.globalTags {
                        self.globalTagsTable.remove(tag, index: index)
                    }
                }
                if !message.globalTags.isEmpty {
                    for tag in message.globalTags {
                        let _ = self.globalTagsTable.addMessage(tag, index: message.index)
                    }
                }
            }
            
            let updatedLocalTags = keepLocalTags ? previousMessage.localTags : message.localTags
            
            if previousMessage.id != message.id && (!previousMessage.localTags.isEmpty || !updatedLocalTags.isEmpty) {
                self.localTagsTable.set(id: previousMessage.id, tags: [], previousTags: previousMessage.localTags, operations: &localTagsOperations)
                self.localTagsTable.set(id: message.id, tags: updatedLocalTags, previousTags: [], operations: &localTagsOperations)
            } else if previousMessage.localTags != updatedLocalTags {
                self.localTagsTable.set(id: message.id, tags: updatedLocalTags, previousTags: previousMessage.localTags, operations: &localTagsOperations)
            } else {
                for tag in updatedLocalTags {
                    localTagsOperations.append(.Update(tag, message.id))
                }
            }
            
            var previousTimestampBasedAttibutes: [UInt16: Int32] = [:]
            for attribute in MessageHistoryTable.renderMessageAttributes(previousMessage) {
                if let (tag, timestamp) = attribute.automaticTimestampBasedAttribute {
                    previousTimestampBasedAttibutes[tag] = timestamp
                }
            }
            if previousMessage.id != message.id {
                for tag in previousTimestampBasedAttibutes.keys {
                    self.timeBasedAttributesTable.remove(tag: tag, id: previousMessage.id, operations: &timestampBasedMessageAttributesOperations)
                }
                for attribute in updatedAttributes {
                    if let (tag, timestamp) = attribute.automaticTimestampBasedAttribute {
                        self.timeBasedAttributesTable.set(tag: tag, id: message.id, timestamp: timestamp, operations: &timestampBasedMessageAttributesOperations)
                    }
                }
            } else {
                var updatedTimestampBasedAttibuteTags: [UInt16] = []
                for attribute in updatedAttributes {
                    if let (tag, timestamp) = attribute.automaticTimestampBasedAttribute {
                        updatedTimestampBasedAttibuteTags.append(tag)
                        if previousTimestampBasedAttibutes[tag] != timestamp {
                            self.timeBasedAttributesTable.remove(tag: tag, id: previousMessage.id, operations: &timestampBasedMessageAttributesOperations)
                            self.timeBasedAttributesTable.set(tag: tag, id: message.id, timestamp: timestamp, operations: &timestampBasedMessageAttributesOperations)
                        }
                    }
                }
                for tag in previousTimestampBasedAttibutes.keys {
                    if !updatedTimestampBasedAttibuteTags.contains(tag) {
                        self.timeBasedAttributesTable.remove(tag: tag, id: previousMessage.id, operations: &timestampBasedMessageAttributesOperations)
                    }
                }
            }
            
            //self.timeBasedAttributesTable.remove(tag: tag, id: message.id, operations: &timestampBasedMessageAttributesOperations)
            
            if message.globallyUniqueId != previousMessage.globallyUniqueId {
                if let globallyUniqueId = previousMessage.globallyUniqueId {
                    self.globallyUniqueMessageIdsTable.remove(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId)
                }
                if let globallyUniqueId = message.globallyUniqueId {
                    self.globallyUniqueMessageIdsTable.set(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId, id: message.id)
                }
            } else if let globallyUniqueId = message.globallyUniqueId, previousMessage.id != message.id {
                self.globallyUniqueMessageIdsTable.set(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId, id: message.id)
            }
            
            if !message.globalTags.isEmpty || !previousMessage.globalTags.isEmpty {
                //assertionFailure("implement global tags")
                if index != message.index {
                    
                } else if message.globalTags != previousMessage.globalTags {
                    
                }
            }
            
            switch (previousMessage.flags.contains(.Unsent) && !previousMessage.flags.contains(.Failed), message.flags.contains(.Unsent) && !message.flags.contains(.Failed)) {
                case (true, false):
                    self.unsentTable.remove(index.id, operations: &unsentMessageOperations)
                case (false, true):
                    self.unsentTable.add(message.id, operations: &unsentMessageOperations)
                case (true, true):
                    if index != message.index {
                        self.unsentTable.remove(index.id, operations: &unsentMessageOperations)
                        self.unsentTable.add(message.id, operations: &unsentMessageOperations)
                    }
                case (false, false):
                    break
            }
            
            if previousMessage.id != message.id {
                if previousMessage.flags.contains(.Failed) {
                    self.failedTable.remove(previousMessage.id)
                }
                if message.flags.contains(.Failed) {
                    self.failedTable.add(message.id)
                }
            } else {
                if previousMessage.flags.contains(.Failed) != message.flags.contains(.Failed) {
                    if previousMessage.flags.contains(.Failed) {
                        self.failedTable.remove(previousMessage.id)
                    } else {
                        self.failedTable.add(message.id)
                    }
                }
            }
            
            if self.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
                if previousMessage.id != message.id || previousMessage.text != message.text || previousMessage.tags != message.tags {
                    self.textIndexTable.remove(messageId: previousMessage.id)
                    
                    var indexableText = message.text
                    for media in message.media {
                        if let mediaText = media.indexableText {
                            indexableText.append(" ")
                            indexableText.append(mediaText)
                        }
                    }
                    
                    self.textIndexTable.add(messageId: message.id, text: indexableText, tags: message.tags)
                }
            }
            
            let groupInfo = updatedGroupInfo
            
            sharedBuffer.reset()
            
            var type: Int8 = 0
            sharedBuffer.write(&type, offset: 0, length: 1)
            
            var stableId: UInt32 = previousMessage.stableId
            sharedBuffer.write(&stableId, offset: 0, length: 4)
            
            var stableVersion: UInt32 = previousMessage.stableVersion + 1
            sharedBuffer.write(&stableVersion, offset: 0, length: 4)
            
            var dataFlags: MessageDataFlags = []
            if message.globallyUniqueId != nil {
                dataFlags.insert(.hasGloballyUniqueId)
            }
            if !message.globalTags.isEmpty {
                dataFlags.insert(.hasGlobalTags)
            }
            if message.groupingKey != nil {
                dataFlags.insert(.hasGroupingKey)
            }
            if groupInfo != nil {
                dataFlags.insert(.hasGroupInfo)
            }
            if !updatedLocalTags.isEmpty {
                dataFlags.insert(.hasLocalTags)
            }
            if message.threadId != nil {
                dataFlags.insert(.hasThreadId)
            }
            sharedBuffer.write(&dataFlags, offset: 0, length: 1)
            if let globallyUniqueId = message.globallyUniqueId {
                var globallyUniqueIdValue = globallyUniqueId
                sharedBuffer.write(&globallyUniqueIdValue, offset: 0, length: 8)
                self.globallyUniqueMessageIdsTable.set(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId, id: message.id)
            }
            if !message.globalTags.isEmpty {
                var globalTagsValue: UInt32 = message.globalTags.rawValue
                sharedBuffer.write(&globalTagsValue, offset: 0, length: 4)
            }
            if let groupingKey = message.groupingKey {
                var groupingKeyValue = groupingKey
                sharedBuffer.write(&groupingKeyValue, offset: 0, length: 8)
            }
            if let groupInfo = groupInfo {
                var stableIdValue = groupInfo.stableId
                sharedBuffer.write(&stableIdValue, offset: 0, length: 4)
            }
            if !updatedLocalTags.isEmpty {
                var localTagsValue: UInt32 = updatedLocalTags.rawValue
                sharedBuffer.write(&localTagsValue, offset: 0, length: 4)
            }
            if var threadId = message.threadId {
                sharedBuffer.write(&threadId, length: 8)
            }
            
            var flags = MessageFlags(message.flags)
            sharedBuffer.write(&flags.rawValue, offset: 0, length: 4)
            
            var tags = message.tags
            sharedBuffer.write(&tags.rawValue, offset: 0, length: 4)
            
            var intermediateForwardInfo: IntermediateMessageForwardInfo?
            if let forwardInfo = message.forwardInfo {
                intermediateForwardInfo = IntermediateMessageForwardInfo(forwardInfo)
                
                var forwardInfoFlags: Int8 = 1
                if forwardInfo.sourceId != nil {
                    forwardInfoFlags |= 1 << 1
                }
                if forwardInfo.sourceMessageId != nil {
                    forwardInfoFlags |= 1 << 2
                }
                if forwardInfo.authorSignature != nil {
                    forwardInfoFlags |= 1 << 3
                }
                if forwardInfo.psaType != nil {
                    forwardInfoFlags |= 1 << 4
                }
                if !forwardInfo.flags.isEmpty {
                    forwardInfoFlags |= 1 << 5
                }
                sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
                var forwardAuthorId: Int64 = forwardInfo.authorId?.toInt64() ?? 0
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
                
                if let authorSignature = forwardInfo.authorSignature {
                    if let data = authorSignature.data(using: .utf8, allowLossyConversion: true) {
                        var length: Int32 = Int32(data.count)
                        sharedBuffer.write(&length, offset: 0, length: 4)
                        sharedBuffer.write(data)
                    } else {
                        var length: Int32 = 0
                        sharedBuffer.write(&length, offset: 0, length: 4)
                    }
                }
                
                if let psaType = forwardInfo.psaType {
                    if let data = psaType.data(using: .utf8, allowLossyConversion: true) {
                        var length: Int32 = Int32(data.count)
                        sharedBuffer.write(&length, offset: 0, length: 4)
                        sharedBuffer.write(data)
                    } else {
                        var length: Int32 = 0
                        sharedBuffer.write(&length, offset: 0, length: 4)
                    }
                }
                
                if !forwardInfo.flags.isEmpty {
                    var value: Int32 = forwardInfo.flags.rawValue
                    sharedBuffer.write(&value, offset: 0, length: 4)
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
            
            let data = message.text.data(using: .utf8, allowLossyConversion: true)!
            var length: Int32 = Int32(data.count)
            sharedBuffer.write(&length, offset: 0, length: 4)
            sharedBuffer.write(data)
            
            let attributesBuffer = WriteBuffer()
            
            var attributeCount: Int32 = Int32(updatedAttributes.count)
            attributesBuffer.write(&attributeCount, offset: 0, length: 4)
            for attribute in updatedAttributes {
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
                    let mediaInsertResult = self.messageMediaTable.set(media, index: message.index, messageHistoryTable: self)
                    switch mediaInsertResult {
                        case let .Embed(media):
                            embeddedMedia.append(media)
                        case .Reference:
                            referencedMedia.append(mediaId)
                            if let currentMedia = self.messageMediaTable.get(mediaId, embedded: { _, _ in nil })?.1, !currentMedia.isEqual(to: media) {
                                mediaToUpdate.append(media)
                            }
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
            
            self.valueBox.set(self.table, key: self.key(message.index, key: sharedKey), value: sharedBuffer)
            
            let result = (IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: flags, tags: tags, globalTags: message.globalTags, localTags: updatedLocalTags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia), previousMessage.tags)
            
            for media in mediaToUpdate {
                if let id = media.id {
                    var updatedMessageIndices = Set<MessageIndex>()
                    var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
                    self.updateMedia(id, media: media, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, updatedMessageIndices: &updatedMessageIndices)
                }
            }
            
            return result
        } else {
            return nil
        }
    }
    
    private func updateMovingGroupInfoInNamespace(index: MessageIndex, updatedIndex: MessageIndex, groupingKey: Int64?, previousInfo: MessageGroupInfo?, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) -> MessageGroupInfo? {
        let (previousLowerMessage, previousUpperMessage) = self.adjacentMessagesInNamespace(index: index)
        let (updatedLowerMessage, updatedUpperMessage) = self.adjacentMessagesInNamespace(index: updatedIndex)
        if previousLowerMessage?.id == updatedLowerMessage?.id && previousUpperMessage?.id == updatedUpperMessage?.id {
            return previousInfo
        } else {
            self.maybeCombineGroupsInNamespace(at: index, updatedGroupInfos: &updatedGroupInfos)
            
            let groupInfo = self.updateGroupingInfoAroundInsertionInNamespace(index: index, groupingKey: groupingKey, updatedGroupInfos: &updatedGroupInfos)
            
            return groupInfo
        }
    }
    
    private func justUpdateTimestamp(_ index: MessageIndex, timestamp: Int32, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], updatedGroupInfos: inout [MessageId: MessageGroupInfo], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], timestampBasedMessageAttributesOperations: inout [TimestampBasedMessageAttributesOperation], updatedMedia: inout [MediaId: Media?]) -> (MessageTags, GlobalMessageTags)? {
        if let previousMessage = self.getMessage(index) {
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = previousMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.authorId, sourceId: forwardInfo.sourceId, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            
            var parsedAttributes: [MessageAttribute] = []
            var parsedMedia: [Media] = []
            
            let attributesData = previousMessage.attributesData.sharedBufferNoCopy()
            if attributesData.length > 4 {
                var attributeCount: Int32 = 0
                attributesData.read(&attributeCount, offset: 0, length: 4)
                for _ in 0 ..< attributeCount {
                    var attributeLength: Int32 = 0
                    attributesData.read(&attributeLength, offset: 0, length: 4)
                    if let attribute = PostboxDecoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() as? MessageAttribute {
                        parsedAttributes.append(attribute)
                    }
                    attributesData.skip(Int(attributeLength))
                }
            }
            
            let embeddedMediaData = previousMessage.embeddedMediaData.sharedBufferNoCopy()
            if embeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        parsedMedia.append(media)
                    }
                    embeddedMediaData.skip(Int(mediaLength))
                }
            }
            
            for mediaId in previousMessage.referencedMedia {
                if let media = self.messageMediaTable.get(mediaId, embedded: { _, _ in
                    return nil
                })?.1 {
                    parsedMedia.append(media)
                }
            }
            
            let updatedIndex = MessageIndex(id: index.id, timestamp: timestamp)
            
            let _ = self.justUpdate(index, message: InternalStoreMessage(id: previousMessage.id, timestamp: timestamp, globallyUniqueId: previousMessage.globallyUniqueId, groupingKey: previousMessage.groupingKey, threadId: previousMessage.threadId, flags: StoreMessageFlags(previousMessage.flags), tags: previousMessage.tags, globalTags: previousMessage.globalTags, localTags: previousMessage.localTags, forwardInfo: storeForwardInfo, authorId: previousMessage.authorId, text: previousMessage.text, attributes: parsedAttributes, media: parsedMedia), keepLocalTags: false, sharedKey: self.key(updatedIndex), sharedBuffer: WriteBuffer(), sharedEncoder: PostboxEncoder(), unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, localTagsOperations: &localTagsOperations, timestampBasedMessageAttributesOperations: &timestampBasedMessageAttributesOperations, updatedMedia: &updatedMedia)
            return (previousMessage.tags, previousMessage.globalTags)
        } else {
            return nil
        }
    }
    
    func unembedMedia(_ index: MessageIndex, id: MediaId) -> Media? {
        if let message = self.getMessage(index), message.embeddedMediaData.length > 4 {
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
                if let media = PostboxDecoder(buffer: MemoryBuffer(memory: message.embeddedMediaData.memory + message.embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    
                    if let mediaId = media.id, mediaId == id {
                        copyMedia = false
                        extractedMedia = media
                    }
                }
                
                if copyMedia {
                    updatedEmbeddedMediaBuffer.write(message.embeddedMediaData.memory.advanced(by: mediaOffset), offset: 0, length: message.embeddedMediaData.offset - mediaOffset)
                }
            }
            
            if let extractedMedia = extractedMedia {
                var updatedReferencedMedia = message.referencedMedia
                updatedReferencedMedia.append(extractedMedia.id!)
                withExtendedLifetime(updatedEmbeddedMediaBuffer, {
                    self.storeIntermediateMessage(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: updatedReferencedMedia), sharedKey: self.key(index))
                })
                
                return extractedMedia
            }
        }
        return nil
    }
    
    func storeIntermediateMessage(_ message: IntermediateMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer = WriteBuffer()) {
        sharedBuffer.reset()
        
        var type: Int8 = 0
        sharedBuffer.write(&type, offset: 0, length: 1)
        
        var stableId: UInt32 = message.stableId
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        
        var stableVersion: UInt32 = message.stableVersion
        sharedBuffer.write(&stableVersion, offset: 0, length: 4)
        
        var dataFlags: MessageDataFlags = []
        if message.globallyUniqueId != nil {
            dataFlags.insert(.hasGloballyUniqueId)
        }
        if !message.globalTags.isEmpty {
            dataFlags.insert(.hasGlobalTags)
        }
        if message.groupingKey != nil {
            dataFlags.insert(.hasGroupingKey)
        }
        if message.groupInfo != nil {
            dataFlags.insert(.hasGroupInfo)
        }
        if !message.localTags.isEmpty {
            dataFlags.insert(.hasLocalTags)
        }
        if message.threadId != nil {
            dataFlags.insert(.hasThreadId)
        }
        sharedBuffer.write(&dataFlags, offset: 0, length: 1)
        if let globallyUniqueId = message.globallyUniqueId {
            var globallyUniqueIdValue = globallyUniqueId
            sharedBuffer.write(&globallyUniqueIdValue, offset: 0, length: 8)
            self.globallyUniqueMessageIdsTable.set(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId, id: message.id)
        }
        if !message.globalTags.isEmpty {
            var globalTagsValue: UInt32 = message.globalTags.rawValue
            sharedBuffer.write(&globalTagsValue, offset: 0, length: 4)
        }
        if let groupingKey = message.groupingKey {
            var groupingKeyValue = groupingKey
            sharedBuffer.write(&groupingKeyValue, offset: 0, length: 8)
        }
        if let groupInfo = message.groupInfo {
            var stableIdValue = groupInfo.stableId
            sharedBuffer.write(&stableIdValue, offset: 0, length: 4)
        }
        if !message.localTags.isEmpty {
            var localTagsValue: UInt32 = message.localTags.rawValue
            sharedBuffer.write(&localTagsValue, offset: 0, length: 4)
        }
        if var threadId = message.threadId {
            sharedBuffer.write(&threadId, length: 8)
        }
        
        var flagsValue: UInt32 = message.flags.rawValue
        sharedBuffer.write(&flagsValue, offset: 0, length: 4)
        
        var tagsValue: UInt32 = message.tags.rawValue
        sharedBuffer.write(&tagsValue, offset: 0, length: 4)
        
        if let forwardInfo = message.forwardInfo {
            var forwardInfoFlags: Int8 = 1
            if forwardInfo.sourceId != nil {
                forwardInfoFlags |= 1 << 1
            }
            if forwardInfo.sourceMessageId != nil {
                forwardInfoFlags |= 1 << 2
            }
            if forwardInfo.authorSignature != nil {
                forwardInfoFlags |= 1 << 3
            }
            if forwardInfo.psaType != nil {
                forwardInfoFlags |= 1 << 4
            }
            sharedBuffer.write(&forwardInfoFlags, offset: 0, length: 1)
            var forwardAuthorId: Int64 = forwardInfo.authorId?.toInt64() ?? 0
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
            
            if let authorSignature = forwardInfo.authorSignature {
                if let data = authorSignature.data(using: .utf8, allowLossyConversion: true) {
                    var length: Int32 = Int32(data.count)
                    sharedBuffer.write(&length, offset: 0, length: 4)
                    sharedBuffer.write(data)
                } else {
                    var length: Int32 = 0
                    sharedBuffer.write(&length, offset: 0, length: 4)
                }
            }
            
            if let psaType = forwardInfo.psaType {
                if let data = psaType.data(using: .utf8, allowLossyConversion: true) {
                    var length: Int32 = Int32(data.count)
                    sharedBuffer.write(&length, offset: 0, length: 4)
                    sharedBuffer.write(data)
                } else {
                    var length: Int32 = 0
                    sharedBuffer.write(&length, offset: 0, length: 4)
                }
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
        
        let data = message.text.data(using: .utf8, allowLossyConversion: true)!
        var length: Int32 = Int32(data.count)
        sharedBuffer.write(&length, offset: 0, length: 4)
        sharedBuffer.write(data)
        
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
        
        self.valueBox.set(self.table, key: self.key(MessageIndex(id: message.id, timestamp: message.timestamp), key: sharedKey), value: sharedBuffer)
    }
    
    private func extractIntermediateEntryIsMessage(value: ReadBuffer) -> Bool {
        var type: Int8 = 0
        value.read(&type, offset: 0, length: 1)
        if type == 0 {
            return true
        } else {
            return false
        }
    }
    
    private func extractIntermediateEntryAuthor(value: ReadBuffer) -> PeerId? {
        var type: Int8 = 0
        value.read(&type, offset: 0, length: 1)
        if type == 0 {
            value.skip(4) // stableId
            value.skip(4) // stableVersion
            
            var hasGloballyUniqueId: Int8 = 0
            value.read(&hasGloballyUniqueId, offset: 0, length: 1)
            if hasGloballyUniqueId != 0 {
                value.skip(8) // globallyUniqueId
            }
            
            value.skip(4) // flags
            value.skip(4) // tags
            
            var forwardInfoFlags: Int8 = 0
            value.read(&forwardInfoFlags, offset: 0, length: 1)
            if forwardInfoFlags != 0 {
                value.skip(8) // forwardAuthorId
                value.skip(4) // forwardDate
                
                if (forwardInfoFlags & 2) != 0 {
                    value.skip(8) // forwardSourceIdValue
                }
                
                if (forwardInfoFlags & 4) != 0 {
                    value.skip(8) // forwardSourceMessagePeerId
                    value.skip(4) // forwardSourceMessageNamespace
                    value.skip(4) // forwardSourceMessageIdId
                }
            }
            
            var hasAuthor: Int8 = 0
            value.read(&hasAuthor, offset: 0, length: 1)
            if hasAuthor == 1 {
                var varAuthorId: Int64 = 0
                value.read(&varAuthorId, offset: 0, length: 8)
                return PeerId(varAuthorId)
            }
        }
        return nil
    }
    
    private func extractIntermediateEntryForwardAuthor(value: ReadBuffer) -> PeerId? {
        var type: Int8 = 0
        value.read(&type, offset: 0, length: 1)
        if type == 0 {
            value.skip(4) // stableId
            value.skip(4) // stableVersion
            
            var hasGloballyUniqueId: Int8 = 0
            value.read(&hasGloballyUniqueId, offset: 0, length: 1)
            if hasGloballyUniqueId != 0 {
                value.skip(8) // globallyUniqueId
            }
            
            value.skip(4) // flags
            value.skip(4) // tags
            
            var forwardInfoFlags: Int8 = 0
            value.read(&forwardInfoFlags, offset: 0, length: 1)
            if forwardInfoFlags != 0 {
                var forwardAuthorId: Int64 = 0
                value.read(&forwardAuthorId, offset: 0, length: 8)
                return PeerId(forwardAuthorId)
            }
        }
        return nil
    }
    
    private func readIntermediateEntry(_ key: ValueBoxKey, value: ReadBuffer) -> IntermediateMessageHistoryEntry {
        let index = extractKey(key)
        
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
            
            var globallyUniqueId: Int64?
            if dataFlags.contains(.hasGloballyUniqueId) {
                var globallyUniqueIdValue: Int64 = 0
                value.read(&globallyUniqueIdValue, offset: 0, length: 8)
                globallyUniqueId = globallyUniqueIdValue
            }
            
            var globalTags: GlobalMessageTags = []
            if dataFlags.contains(.hasGlobalTags) {
                var globalTagsValue: UInt32 = 0
                value.read(&globalTagsValue, offset: 0, length: 4)
                globalTags = GlobalMessageTags(rawValue: globalTagsValue)
            }
            
            var groupingKey: Int64?
            if dataFlags.contains(.hasGroupingKey) {
                var groupingKeyValue: Int64 = 0
                value.read(&groupingKeyValue, offset: 0, length: 8)
                groupingKey = groupingKeyValue
            }
            
            var groupInfo: MessageGroupInfo?
            if dataFlags.contains(.hasGroupInfo) {
                var stableIdValue: UInt32 = 0
                value.read(&stableIdValue, offset: 0, length: 4)
                groupInfo = MessageGroupInfo(stableId: stableIdValue)
            }
            
            var localTags: LocalMessageTags = []
            if dataFlags.contains(.hasLocalTags) {
                var localTagsValue: UInt32 = 0
                value.read(&localTagsValue, offset: 0, length: 4)
                localTags = LocalMessageTags(rawValue: localTagsValue)
            }
            
            var threadId: Int64?
            if dataFlags.contains(.hasThreadId) {
                var threadIdValue: Int64 = 0
                value.read(&threadIdValue, offset: 0, length: 8)
                threadId = threadIdValue
            }
            
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
                var authorSignature: String? = nil
                var psaType: String? = nil
                var flags: MessageForwardInfo.Flags = []
                
                value.read(&forwardAuthorId, offset: 0, length: 8)
                value.read(&forwardDate, offset: 0, length: 4)
                
                if (forwardInfoFlags & (1 << 1)) != 0 {
                    var forwardSourceIdValue: Int64 = 0
                    value.read(&forwardSourceIdValue, offset: 0, length: 8)
                    forwardSourceId = PeerId(forwardSourceIdValue)
                }
                
                if (forwardInfoFlags & (1 << 2)) != 0 {
                    var forwardSourceMessagePeerId: Int64 = 0
                    var forwardSourceMessageNamespace: Int32 = 0
                    var forwardSourceMessageIdId: Int32 = 0
                    value.read(&forwardSourceMessagePeerId, offset: 0, length: 8)
                    value.read(&forwardSourceMessageNamespace, offset: 0, length: 4)
                    value.read(&forwardSourceMessageIdId, offset: 0, length: 4)
                    forwardSourceMessageId = MessageId(peerId: PeerId(forwardSourceMessagePeerId), namespace: forwardSourceMessageNamespace, id: forwardSourceMessageIdId)
                }
                
                if (forwardInfoFlags & (1 << 3)) != 0 {
                    var signatureLength: Int32 = 0
                    value.read(&signatureLength, offset: 0, length: 4)
                    authorSignature = String(data: Data(bytes: value.memory.assumingMemoryBound(to: UInt8.self).advanced(by: value.offset), count: Int(signatureLength)), encoding: .utf8)
                    value.skip(Int(signatureLength))
                }
                
                if (forwardInfoFlags & (1 << 4)) != 0 {
                    var psaTypeLength: Int32 = 0
                    value.read(&psaTypeLength, offset: 0, length: 4)
                    psaType = String(data: Data(bytes: value.memory.assumingMemoryBound(to: UInt8.self).advanced(by: value.offset), count: Int(psaTypeLength)), encoding: .utf8)
                    value.skip(Int(psaTypeLength))
                }
                
                if (forwardInfoFlags & (1 << 5)) != 0 {
                    var rawValue: Int32 = 0
                    value.read(&rawValue, offset: 0, length: 4)
                    flags = MessageForwardInfo.Flags(rawValue: rawValue)
                }
                
                forwardInfo = IntermediateMessageForwardInfo(authorId: forwardAuthorId == 0 ? nil : PeerId(forwardAuthorId), sourceId: forwardSourceId, sourceMessageId: forwardSourceMessageId, date: forwardDate, authorSignature: authorSignature, psaType: psaType, flags: flags)
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
            let text = String(data: Data(bytes: value.memory.assumingMemoryBound(to: UInt8.self).advanced(by: value.offset), count: Int(textLength)), encoding: .utf8) ?? ""
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
            let attributesBytes = malloc(attributesLength)!
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
            
            return IntermediateMessageHistoryEntry(message: IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: index.id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, threadId: threadId, timestamp: index.timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, authorId: authorId, text: text, attributesData: attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: referencedMediaIds))
        } else {
            preconditionFailure()
        }
    }
    
    static func renderMessageAttributes(_ message: IntermediateMessage) -> [MessageAttribute] {
        var parsedAttributes: [MessageAttribute] = []
        
        let attributesData = message.attributesData.sharedBufferNoCopy()
        if attributesData.length > 4 {
            var attributeCount: Int32 = 0
            attributesData.read(&attributeCount, offset: 0, length: 4)
            for _ in 0 ..< attributeCount {
                var attributeLength: Int32 = 0
                attributesData.read(&attributeLength, offset: 0, length: 4)
                if let attribute = PostboxDecoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() as? MessageAttribute {
                    parsedAttributes.append(attribute)
                }
                attributesData.skip(Int(attributeLength))
            }
        }
        
        return parsedAttributes
    }
    
    func renderMessageMedia(referencedMedia: [MediaId], embeddedMediaData: ReadBuffer) -> [Media] {
        var parsedMedia: [Media] = []
        
        let embeddedMediaData = embeddedMediaData.sharedBufferNoCopy()
        if embeddedMediaData.length > 4 {
            var embeddedMediaCount: Int32 = 0
            embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
            for _ in 0 ..< embeddedMediaCount {
                var mediaLength: Int32 = 0
                embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    parsedMedia.append(media)
                }
                embeddedMediaData.skip(Int(mediaLength))
            }
        }
        
        for mediaId in referencedMedia {
            if let media = self.messageMediaTable.get(mediaId, embedded: { _, _ in
                return nil
            })?.1 {
                parsedMedia.append(media)
            }
        }
        
        return parsedMedia
    }
    
    func renderMessage(_ message: IntermediateMessage, peerTable: PeerTable, threadIndexTable: MessageHistoryThreadIndexTable, addAssociatedMessages: Bool = true) -> Message {
        var parsedAttributes: [MessageAttribute] = []
        var parsedMedia: [Media] = []
        
        let attributesData = message.attributesData.sharedBufferNoCopy()
        if attributesData.length > 4 {
            var attributeCount: Int32 = 0
            attributesData.read(&attributeCount, offset: 0, length: 4)
            for _ in 0 ..< attributeCount {
                var attributeLength: Int32 = 0
                attributesData.read(&attributeLength, offset: 0, length: 4)
                if let attribute = PostboxDecoder(buffer: MemoryBuffer(memory: attributesData.memory + attributesData.offset, capacity: Int(attributeLength), length: Int(attributeLength), freeWhenDone: false)).decodeRootObject() as? MessageAttribute {
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
                if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                    parsedMedia.append(media)
                }
                embeddedMediaData.skip(Int(mediaLength))
            }
        }
        
        for mediaId in message.referencedMedia {
            if let media = self.messageMediaTable.get(mediaId, embedded: { _, _ in
                return nil
            })?.1 {
                parsedMedia.append(media)
            }
        }
        
        var forwardInfo: MessageForwardInfo?
        if let internalForwardInfo = message.forwardInfo {
            let forwardAuthor = internalForwardInfo.authorId.flatMap({ peerTable.get($0) })
            var source: Peer?
            
            if let sourceId = internalForwardInfo.sourceId {
                source = peerTable.get(sourceId)
            }
            forwardInfo = MessageForwardInfo(author: forwardAuthor, source: source, sourceMessageId: internalForwardInfo.sourceMessageId, date: internalForwardInfo.date, authorSignature: internalForwardInfo.authorSignature, psaType: internalForwardInfo.psaType, flags: internalForwardInfo.flags)
        }
        
        var author: Peer?
        var peers = SimpleDictionary<PeerId, Peer>()
        if let authorId = message.authorId {
            author = peerTable.get(authorId)
        }
        
        if let chatPeer = peerTable.get(message.id.peerId) {
            peers[chatPeer.id] = chatPeer
            
            if let associatedPeerId = chatPeer.associatedPeerId {
                if let peer = peerTable.get(associatedPeerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        for media in parsedMedia {
            for peerId in media.peerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        var associatedMessageIds: [MessageId] = []
        var associatedMessages = SimpleDictionary<MessageId, Message>()
        var associatedMedia: [MediaId: Media] = [:]
        for attribute in parsedAttributes {
            for peerId in attribute.associatedPeerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
            for mediaId in attribute.associatedMediaIds {
                if associatedMedia[mediaId] == nil {
                    if let media = self.getMedia(mediaId) {
                        associatedMedia[mediaId] = media
                    }
                }
            }
            associatedMessageIds.append(contentsOf: attribute.associatedMessageIds)
            if addAssociatedMessages {
                for messageId in attribute.associatedMessageIds {
                    if let index = self.messageHistoryIndexTable.getIndex(messageId) {
                        if let message = self.getMessage(index) {
                            associatedMessages[messageId] = self.renderMessage(message, peerTable: peerTable, threadIndexTable: threadIndexTable, addAssociatedMessages: false)
                        }
                    }
                }
            }
        }
        
        var associatedThreadInfo: Message.AssociatedThreadInfo?
        if let threadId = message.threadId, let data = threadIndexTable.get(peerId: message.id.peerId, threadId: threadId) {
            associatedThreadInfo = self.seedConfiguration.decodeMessageThreadInfo(data.data)
        }
        
        return Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: forwardInfo, author: author, text: message.text, attributes: parsedAttributes, media: parsedMedia, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds, associatedMedia: associatedMedia, associatedThreadInfo: associatedThreadInfo)
    }
    
    func renderMessagePeers(_ message: Message, peerTable: PeerTable) -> Message {
        var author: Peer?
        var peers = SimpleDictionary<PeerId, Peer>()
        if let authorId = message.author?.id {
            author = peerTable.get(authorId)
        }

        if let author = author {
            peers[author.id] = author
        }
        
        if let chatPeer = peerTable.get(message.id.peerId) {
            peers[chatPeer.id] = chatPeer
            
            if let associatedPeerId = chatPeer.associatedPeerId {
                if let peer = peerTable.get(associatedPeerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        for media in message.media {
            for peerId in media.peerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        for attribute in message.attributes {
            for peerId in attribute.associatedPeerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
        }
        
        return message.withUpdatedPeers(peers)
    }
    
    func renderAssociatedMessages(associatedMessageIds: [MessageId], peerTable: PeerTable, threadIndexTable: MessageHistoryThreadIndexTable) -> SimpleDictionary<MessageId, Message> {
        var associatedMessages = SimpleDictionary<MessageId, Message>()
        for messageId in associatedMessageIds {
            if let index = self.messageHistoryIndexTable.getIndex(messageId) {
                if let message = self.getMessage(index) {
                    associatedMessages[messageId] = self.renderMessage(message, peerTable: peerTable, threadIndexTable: threadIndexTable, addAssociatedMessages: false)
                }
            }
        }
        return associatedMessages
    }
    
    private func globalTagsIntermediateEntry(_ entry: IntermediateMessageHistoryEntry) -> IntermediateGlobalMessageTagsEntry? {
        return .message(entry.message)
    }
    
    func entriesAround(globalTagMask: GlobalMessageTags, index: MessageIndex, count: Int) -> (entries: [IntermediateGlobalMessageTagsEntry], lower: MessageIndex?, upper: MessageIndex?) {
        self.globalTagsTable.ensureInitialized(globalTagMask)
        
        let (globalEntries, lower, upper) = self.globalTagsTable.entriesAround(globalTagMask, index: index, count: count)
        
        var entries: [IntermediateGlobalMessageTagsEntry] = []
        for entry in globalEntries {
            switch entry {
                case let .hole(index):
                    entries.append(.hole(index))
                case let .message(index):
                    let key = self.key(index)
                    if let value = self.valueBox.get(self.table, key: key) {
                        if let entry = self.globalTagsIntermediateEntry(readIntermediateEntry(key, value: value)) {
                            entries.append(entry)
                        } else {
                            assertionFailure()
                        }
                    } else {
                        assertionFailure()
                    }
            }
        }
        
        return (entries, lower?.index, upper?.index)
    }
    
    func earlierEntries(globalTagMask: GlobalMessageTags, index: MessageIndex?, count: Int) -> [IntermediateGlobalMessageTagsEntry] {
        self.globalTagsTable.ensureInitialized(globalTagMask)
        
        let globalEntries = self.globalTagsTable.earlierEntries(globalTagMask, index: index, count: count)
        
        var entries: [IntermediateGlobalMessageTagsEntry] = []
        for entry in globalEntries {
            switch entry {
                case let .hole(index):
                    entries.append(.hole(index))
                case let .message(index):
                    let key = self.key(index)
                    if let value = self.valueBox.get(self.table, key: key) {
                        if let entry = self.globalTagsIntermediateEntry(readIntermediateEntry(key, value: value)) {
                            entries.append(entry)
                        } else {
                            assertionFailure()
                        }
                    } else {
                        assertionFailure()
                    }
            }
        }
        
        return entries
    }
    
    func laterEntries(globalTagMask: GlobalMessageTags, index: MessageIndex?, count: Int) -> [IntermediateGlobalMessageTagsEntry] {
        self.globalTagsTable.ensureInitialized(globalTagMask)
        
        let globalEntries = self.globalTagsTable.laterEntries(globalTagMask, index: index, count: count)
        
        var entries: [IntermediateGlobalMessageTagsEntry] = []
        for entry in globalEntries {
            switch entry {
                case let .hole(index):
                    entries.append(.hole(index))
                case let .message(index):
                    let key = self.key(index)
                    if let value = self.valueBox.get(self.table, key: key) {
                        if let entry = self.globalTagsIntermediateEntry(readIntermediateEntry(key, value: value)) {
                            entries.append(entry)
                        } else {
                            assertionFailure()
                        }
                    } else {
                        assertionFailure()
                    }
            }
        }
        
        return entries
    }
    
    func findMessageId(peerId: PeerId, namespace: MessageId.Namespace, timestamp: Int32) -> MessageId? {
        var result: MessageId?
        self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 0), timestamp: timestamp)), end: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32.max), timestamp: timestamp)), values: { key, value in
            let entry = self.readIntermediateEntry(key, value: value)
            result = entry.message.id
            return false
        }, limit: 1)
        return result
    }
    
    func findClosestMessageIndex(peerId: PeerId, timestamp: Int32) -> MessageIndex? {
        var closestIndex: MessageIndex?
        for namespace in self.messageHistoryIndexTable.existingNamespaces(peerId: peerId) {
            var index: MessageIndex?
            self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 0), timestamp: timestamp)), end: self.lowerBound(peerId: peerId, namespace: namespace), keys: { key in
                index = extractKey(key)
                return false
            }, limit: 1)
            if index == nil {
                self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 0), timestamp: timestamp)), end: self.upperBound(peerId: peerId, namespace: namespace), keys: { key in
                    index = extractKey(key)
                    return false
                }, limit: 0)
            }
            if let index = index {
                if let closestIndexValue = closestIndex {
                    if abs(index.timestamp - timestamp) < abs(closestIndexValue.timestamp - timestamp) {
                        closestIndex = index
                    }
                } else {
                    closestIndex = index
                }
            }
        }
        return closestIndex
    }

    func findMessageAtAbsoluteIndex(peerId: PeerId, namespace: MessageId.Namespace, index: Int) -> MessageIndex? {
        var count = 0
        var result: MessageIndex?
        self.valueBox.range(self.table, start: self.upperBound(peerId: peerId, namespace: namespace), end: self.lowerBound(peerId: peerId, namespace: namespace), keys: { key in
            if count == index {
                result = extractKey(key)
                return false
            }
            count += 1
            return true
        }, limit: 10000)
        return result
    }
    
    func findRandomMessage(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, ignoreIds: ([MessageId], Set<MessageId>)) -> MessageIndex? {
        if let index = self.tagsTable.findRandomIndex(peerId: peerId, namespace: namespace, tag: tag, ignoreIds: ignoreIds, isMessage: { index in
            return self.getMessage(index) != nil
        }) {
            return self.getMessage(index).flatMap({ $0.index })
        } else {
            return nil
        }
    }

    func firstMessageInRange(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, timestampMax: Int32, timestampMin: Int32) -> IntermediateMessage? {
        guard let index = self.tagsTable.earlierIndices(tag: tag, peerId: peerId, namespace: namespace, index: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 1), timestamp: timestampMax), includeFrom: true, minIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: 1), timestamp: timestampMin), count: 1).first else {
            return nil
        }
        return self.getMessage(index)
    }
    
    func incomingMessageStatsInIndices(_ peerId: PeerId, namespace: MessageId.Namespace, indices: [MessageIndex]) -> (Int, Bool) {
        var count: Int = 0
        var holes = false
        
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.table, key: key) {
                let entry = self.readIntermediateEntry(key, value: value)
                if entry.message.id.namespace == namespace && !entry.message.flags.intersection(.IsIncomingMask).isEmpty {
                    count += 1
                }
            } else {
                if !holes {
                    if !self.messageHistoryHoleIndexTable.containing(id: index.id).isEmpty {
                        holes = true
                    }
                }
            }
        }
        return (count, holes)
    }
    
    func incomingMessageCountInRange(_ peerId: PeerId, namespace: MessageId.Namespace, fromIndex: MessageIndex, toIndex: MessageIndex) -> (Int, Bool, [MessageId]) {
        var count: Int = 0
        var messageIds: [MessageId] = []
        var holes = false
        
        if fromIndex <= toIndex {
            self.valueBox.range(self.table, start: self.key(fromIndex).predecessor, end: self.key(toIndex).successor, values: { key, value in
                let entry = self.readIntermediateEntry(key, value: value)
                if entry.message.id.namespace == namespace && !entry.message.flags.intersection(.IsIncomingMask).isEmpty {
                    count += 1
                    messageIds.append(entry.message.id)
                }
                return true
            }, limit: 0)
            
            if fromIndex.id.namespace == namespace && toIndex.id.namespace == namespace && fromIndex.id.id <= toIndex.id.id {
                holes = !self.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: fromIndex.id.namespace, space: .everywhere, range: fromIndex.id.id ... toIndex.id.id).isEmpty
            }
        }
        
        return (count, holes, messageIds)
    }
    
    func outgoingMessageCountInRange(_ peerId: PeerId, namespace: MessageId.Namespace, fromIndex: MessageIndex, toIndex: MessageIndex) -> [MessageId] {
        var messageIds: [MessageId] = []
        self.valueBox.range(self.table, start: self.key(fromIndex).predecessor, end: self.key(toIndex).successor, values: { key, value in
            let entry = self.readIntermediateEntry(key, value: value)
            if entry.message.flags.intersection(.IsIncomingMask).isEmpty {
                messageIds.append(entry.message.id)
            }
            return true
        }, limit: 0)
        
        return messageIds
    }
    
    func allMessageIndices(peerId: PeerId, namespace: MessageId.Namespace? = nil) -> [MessageIndex] {
        var messages: [MessageIndex] = []
        let start: ValueBoxKey
        let end: ValueBoxKey
        if let namespace = namespace {
            start = self.lowerBound(peerId: peerId, namespace: namespace)
            end = self.upperBound(peerId: peerId, namespace: namespace)
        } else {
            start = self.key(MessageIndex.lowerBound(peerId: peerId)).predecessor
            end = self.key(MessageIndex.upperBound(peerId: peerId)).successor
        }
        self.valueBox.range(self.table, start: start, end: end, keys: { key in
            messages.append(extractKey(key))
            return true
        }, limit: 0)
        return messages
    }
    
    func allIndicesWithAuthor(peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId, namespace: namespace), end: self.upperBound(peerId: peerId, namespace: namespace), values: { key, value in
            if extractIntermediateEntryAuthor(value: value) == authorId {
                indices.append(extractKey(key))
            }
            return true
        }, limit: 0)
        return indices
    }
    
    func allIndicesWithGlobalTag(tag: GlobalMessageTags) -> [GlobalMessageHistoryTagsTableEntry] {
        return self.globalTagsTable.getAll()
    }
    
    func allIndicesWithForwardAuthor(peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.lowerBound(peerId: peerId, namespace: namespace), end: self.upperBound(peerId: peerId, namespace: namespace), values: { key, value in
            if extractIntermediateEntryForwardAuthor(value: value) == forwardAuthorId {
                indices.append(extractKey(key))
            }
            return true
        }, limit: 0)
        return indices
    }
    
    func getMessageCountInRange(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags?, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int {
        if let tag = tag {
            return self.tagsTable.getMessageCountInRange(tag: tag, peerId: peerId, namespace: namespace, lowerBound: lowerBound, upperBound: upperBound)
        } else {
            precondition(lowerBound.id.namespace == namespace)
            precondition(upperBound.id.namespace == namespace)
            var lowerBoundKey = self.key(lowerBound)
            if lowerBound.timestamp > 1 {
                lowerBoundKey = lowerBoundKey.predecessor
            }
            var upperBoundKey = self.key(upperBound)
            if upperBound.timestamp < Int32.max - 1 {
                upperBoundKey = upperBoundKey.successor
            }
            return Int(self.valueBox.count(self.table, start: lowerBoundKey, end: upperBoundKey))
        }
    }
    
    func setPendingMessageAction(id: MessageId, type: PendingMessageActionType, action: PendingMessageActionData?, pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32]) {
        if let _ = self.messageHistoryIndexTable.getIndex(id) {
            self.pendingActionsTable.setAction(id: id, type: type, action: action, operations: &pendingActionsOperations, updatedSummaries: &updatedMessageActionsSummaries)
        }
    }
    
    func enumerateMedia(lowerBound: MessageIndex?, upperBound: MessageIndex?, limit: Int) -> ([PeerId: Set<MediaId>], [MediaId: Media], MessageIndex?) {
        var mediaRefs: [MediaId: Media] = [:]
        var result: [PeerId: Set<MediaId>] = [:]
        var lastIndex: MessageIndex?
        var count = 0
        self.valueBox.range(self.table, start: self.key(lowerBound == nil ? MessageIndex.absoluteLowerBound() : lowerBound!), end: self.key(upperBound == nil ? MessageIndex.absoluteUpperBound() : upperBound!), values: { key, value in
            count += 1
            
            let entry = self.readIntermediateEntry(key, value: value)
            lastIndex = entry.message.index
            
            let message = entry.message
            
            if let upperBound = upperBound, message.id.peerId != upperBound.id.peerId {
                return true
            }
            
            var parsedMedia: [Media] = []
            
            let embeddedMediaData = message.embeddedMediaData.sharedBufferNoCopy()
            if embeddedMediaData.length > 4 {
                var embeddedMediaCount: Int32 = 0
                embeddedMediaData.read(&embeddedMediaCount, offset: 0, length: 4)
                for _ in 0 ..< embeddedMediaCount {
                    var mediaLength: Int32 = 0
                    embeddedMediaData.read(&mediaLength, offset: 0, length: 4)
                    if let media = PostboxDecoder(buffer: MemoryBuffer(memory: embeddedMediaData.memory + embeddedMediaData.offset, capacity: Int(mediaLength), length: Int(mediaLength), freeWhenDone: false)).decodeRootObject() as? Media {
                        parsedMedia.append(media)
                    }
                    embeddedMediaData.skip(Int(mediaLength))
                }
            }
            
            for mediaId in message.referencedMedia {
                if let media = self.messageMediaTable.get(mediaId, embedded: { _, _ in
                    return nil
                })?.1 {
                    parsedMedia.append(media)
                }
            }
            
            for media in parsedMedia {
                if let id = media.id {
                    mediaRefs[id] = media
                    if result[message.id.peerId] == nil {
                        result[message.id.peerId] = Set()
                    }
                    result[message.id.peerId]!.insert(id)
                }
            }
            return true
        }, limit: limit)
        return (result, mediaRefs, count == 0 ? nil : lastIndex)
    }
    
    func fetch(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags?, threadId: Int64?, from fromIndex: MessageIndex, includeFrom: Bool, to toIndex: MessageIndex, ignoreMessagesInTimestampRange: ClosedRange<Int32>?, limit: Int) -> [IntermediateMessage] {
        precondition(fromIndex.id.peerId == toIndex.id.peerId)
        precondition(fromIndex.id.namespace == toIndex.id.namespace)
        var result: [IntermediateMessage] = []
        if let threadId = threadId {
            if let tag = tag {
                let indices: [MessageIndex]
                if fromIndex < toIndex {
                    indices = self.threadTagsTable.laterIndices(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace, index: fromIndex, includeFrom: includeFrom, count: limit)
                } else {
                    indices = self.threadTagsTable.earlierIndices(tag: tag, threadId: threadId, peerId: peerId, namespace: namespace, index: fromIndex, includeFrom: includeFrom, count: limit)
                }
                for index in indices {
                    if let ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange {
                        if ignoreMessagesInTimestampRange.contains(index.timestamp) {
                            continue
                        }
                    }
                    if fromIndex < toIndex {
                        if index < fromIndex || index > toIndex {
                            continue
                        }
                    } else {
                        if index < toIndex || index > fromIndex {
                            continue
                        }
                    }
                    if let message = self.getMessage(index) {
                        result.append(message)
                    } else {
                        assertionFailure()
                    }
                }
            } else {
                var indices: [MessageIndex] = []
                var startIndex = fromIndex
                var localIncludeFrom = includeFrom
                while true {
                    let sliceIndices: [MessageIndex]
                    if fromIndex < toIndex {
                        sliceIndices = self.threadsTable.laterIndices(threadId: threadId, peerId: peerId, namespace: namespace, index: startIndex, includeFrom: localIncludeFrom, count: limit)
                    } else {
                        sliceIndices = self.threadsTable.earlierIndices(threadId: threadId, peerId: peerId, namespace: namespace, index: startIndex, includeFrom: localIncludeFrom, count: limit)
                    }
                    if sliceIndices.isEmpty {
                        break
                    }
                    
                    startIndex = sliceIndices[sliceIndices.count - 1]
                    localIncludeFrom = false
                    
                    for index in sliceIndices {
                        if let ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange {
                            if ignoreMessagesInTimestampRange.contains(index.timestamp) {
                                continue
                            }
                        }
                        if let tag = tag {
                            if self.tagsTable.entryExists(tag: tag, index: index) {
                                indices.append(index)
                            }
                        } else {
                            indices.append(index)
                        }
                    }
                    if indices.count >= limit {
                        break
                    }
                }
                for index in indices {
                    if fromIndex < toIndex {
                        if index < fromIndex || index > toIndex {
                            continue
                        }
                    } else {
                        if index < toIndex || index > fromIndex {
                            continue
                        }
                    }
                    if let message = self.getMessage(index) {
                        result.append(message)
                    } else {
                        assertionFailure()
                    }
                }
            }
        } else if let tag = tag {
            let indices: [MessageIndex]
            if fromIndex < toIndex {
                indices = self.tagsTable.laterIndices(tag: tag, peerId: peerId, namespace: namespace, index: fromIndex, includeFrom: includeFrom, count: limit)
            } else {
                indices = self.tagsTable.earlierIndices(tag: tag, peerId: peerId, namespace: namespace, index: fromIndex, includeFrom: includeFrom, count: limit)
            }
            for index in indices {
                if let ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange {
                    if ignoreMessagesInTimestampRange.contains(index.timestamp) {
                        continue
                    }
                }
                if fromIndex < toIndex {
                    if index < fromIndex || index > toIndex {
                        continue
                    }
                } else {
                    if index < toIndex || index > fromIndex {
                        continue
                    }
                }
                if let message = self.getMessage(index) {
                    result.append(message)
                } else {
                    assertionFailure()
                }
            }
        } else if ignoreMessagesInTimestampRange != nil {
            var indices: [MessageIndex] = []
            var startIndex = fromIndex
            var localIncludeFrom = includeFrom
            while true {
                let startKey: ValueBoxKey
                if localIncludeFrom && startIndex != MessageIndex.upperBound(peerId: peerId, namespace: namespace) {
                    if startIndex < toIndex {
                        startKey = self.key(startIndex).predecessor
                    } else {
                        startKey = self.key(startIndex).successor
                    }
                } else {
                    startKey = self.key(startIndex)
                }
                
                var sliceIndices: [MessageIndex] = []
                
                self.valueBox.range(self.table, start: startKey, end: self.key(toIndex), values: { key, value in
                    sliceIndices.append(extractKey(key))
                    return true
                }, limit: limit)
                
                if sliceIndices.isEmpty {
                    break
                }
                startIndex = sliceIndices[sliceIndices.count - 1]
                localIncludeFrom = false
                
                for index in sliceIndices {
                    if let ignoreMessagesInTimestampRange = ignoreMessagesInTimestampRange {
                        if ignoreMessagesInTimestampRange.contains(index.timestamp) {
                            continue
                        }
                    }
                    indices.append(index)
                    if indices.count >= limit {
                        break
                    }
                }
                if indices.count >= limit {
                    break
                }
            }
            assert(Set(indices).count == indices.count)
            for index in indices {
                if fromIndex < toIndex {
                    if index < fromIndex || index > toIndex {
                        continue
                    }
                } else {
                    if index < toIndex || index > fromIndex {
                        continue
                    }
                }
                if let message = self.getMessage(index) {
                    result.append(message)
                } else {
                    assertionFailure()
                }
            }
        } else {
            let startKey: ValueBoxKey
            if includeFrom && fromIndex != MessageIndex.upperBound(peerId: peerId, namespace: namespace) {
                if fromIndex < toIndex {
                    startKey = self.key(fromIndex).predecessor
                } else {
                    startKey = self.key(fromIndex).successor
                }
            } else {
                startKey = self.key(fromIndex)
            }
            self.valueBox.range(self.table, start: startKey, end: self.key(toIndex), values: { key, value in
                let message = self.readIntermediateEntry(key, value: value).message
                assert(message.id.peerId == peerId && message.id.namespace == namespace)
                assert(message.index == extractKey(key))
                result.append(message)
                return true
            }, limit: limit)
        }
        return result
    }

    func debugList(tag: MessageTags?, peerId: PeerId, namespace: MessageId.Namespace, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        preconditionFailure()
    }
}
