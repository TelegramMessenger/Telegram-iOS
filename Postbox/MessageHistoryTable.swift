import Foundation

enum InternalMessageHistoryAnchorIndex: Comparable {
    case message(index: MessageIndex, exact: Bool)
    case lowerBound
    case upperBound
    
    init(_ index: MessageHistoryAnchorIndex) {
        switch index {
            case let .message(index):
                self = .message(index: index, exact: true)
            case .lowerBound:
                self = .lowerBound
            case .upperBound:
                self = .upperBound
        }
    }
    
    public static func <(lhs: InternalMessageHistoryAnchorIndex, rhs: InternalMessageHistoryAnchorIndex) -> Bool {
        switch lhs {
            case let .message(lhsIndex, _):
                switch rhs {
                    case let .message(rhsIndex, _):
                        return lhsIndex < rhsIndex
                    case .lowerBound:
                        return false
                    case .upperBound:
                        return true
                }
            case .lowerBound:
                if case .lowerBound = rhs {
                    return false
                } else {
                    return true
                }
            case .upperBound:
                return false
        }
    }
    
    static func ==(lhs: InternalMessageHistoryAnchorIndex, rhs: InternalMessageHistoryAnchorIndex) -> Bool {
        switch lhs {
            case let .message(index, exact):
                if case .message(index, exact) = rhs {
                    return true
                } else {
                    return false
                }
            case .lowerBound:
                if case .lowerBound = rhs {
                    return true
                } else {
                    return false
                }
            case .upperBound:
                if case .upperBound = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public func isLess(than: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index, _):
                return index < than
        }
    }
    
    func isLessOrEqual(to: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index, _):
                return index <= to
        }
    }
}

public enum MessageHistoryAnchorIndex: Comparable {
    case message(MessageIndex)
    case lowerBound
    case upperBound
    
    init(_ index: InternalMessageHistoryAnchorIndex) {
        switch index {
            case let .message(index, _):
                self = .message(index)
            case .lowerBound:
                self = .lowerBound
            case .upperBound:
                self = .upperBound
        }
    }
    
    public static func ==(lhs: MessageHistoryAnchorIndex, rhs: MessageHistoryAnchorIndex) -> Bool {
        switch lhs {
            case let .message(index):
                if case .message(index) = rhs {
                    return true
                } else {
                    return false
                }
            case .lowerBound:
                if case .lowerBound = rhs {
                    return true
                } else {
                    return false
                }
            case .upperBound:
                if case .upperBound = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public static func <(lhs: MessageHistoryAnchorIndex, rhs: MessageHistoryAnchorIndex) -> Bool {
        switch lhs {
            case let .message(lhsIndex):
                switch rhs {
                    case let .message(rhsIndex):
                        return lhsIndex < rhsIndex
                    case .lowerBound:
                        return false
                    case .upperBound:
                        return true
                }
            case .lowerBound:
                if case .lowerBound = rhs {
                    return false
                } else {
                    return true
                }
            case .upperBound:
                return false
        }
    }
    
    public func isLess(than: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index):
                return index < than
        }
    }
    
    public func isLessOrEqual(to: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index):
                return index <= to
        }
    }
}

enum IntermediateMessageHistoryEntry {
    case Message(IntermediateMessage)
    case Hole(MessageHistoryHole, lowerIndex: MessageIndex?)
    
    var index: MessageIndex {
        switch self {
            case let .Message(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .Hole(hole, _):
                return hole.maxIndex
        }
    }
    
    func debugDescription() -> String {
        switch self {
            case let .Message(message):
                return message.text
            case let .Hole(hole, _):
                return "\(hole)"
        }
    }
}

enum RenderedMessageHistoryEntry {
    case RenderedMessage(Message)
    case Hole(MessageHistoryHole)
    
    var index: MessageIndex {
        switch self {
            case let .RenderedMessage(message):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .Hole(hole):
                return hole.maxIndex
        }
    }
}

private enum AdjacentEntryGroupInfo {
    case none
    case sameGroup(MessageGroupInfo)
    case otherGroup(MessageGroupInfo)
}

private func getAdjacentEntryGroupInfo(_ entry: IntermediateMessageHistoryEntry?, key: Int64) -> (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo) {
    if let entry = entry {
        switch entry {
            case .Hole:
                return (entry, .none)
            case let .Message(message):
                if let groupingKey = message.groupingKey {
                    if groupingKey == key {
                        return (entry, .sameGroup(message.groupInfo!))
                    } else {
                        return (entry, .otherGroup(message.groupInfo!))
                    }
                } else {
                    return (entry, .none)
                }
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
}

enum EntriesInRangeBoundary: Comparable {
    case lowerBound
    case upperBound
    case index(MessageIndex)
    
    static func ==(lhs: EntriesInRangeBoundary, rhs: EntriesInRangeBoundary) -> Bool {
        switch lhs {
            case .lowerBound:
                if case .lowerBound = rhs {
                    return true
                } else {
                    return false
                }
            case .upperBound:
                if case .upperBound = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: EntriesInRangeBoundary, rhs: EntriesInRangeBoundary) -> Bool {
        switch lhs {
            case .lowerBound:
                if case .lowerBound = rhs {
                    return false
                } else {
                    return true
                }
            case .upperBound:
                return false
            case let .index(lhsIndex):
                switch rhs {
                    case .lowerBound:
                        return false
                    case .upperBound:
                        return true
                    case let .index(rhsIndex):
                        return lhsIndex < rhsIndex
                }
        }
    }
}

final class MessageHistoryTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary)
    }
    
    let messageHistoryIndexTable: MessageHistoryIndexTable
    let messageMediaTable: MessageMediaTable
    let historyMetadataTable: MessageHistoryMetadataTable
    let globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable
    let unsentTable: MessageHistoryUnsentTable
    let tagsTable: MessageHistoryTagsTable
    let globalTagsTable: GlobalMessageHistoryTagsTable
    let localTagsTable: LocalMessageHistoryTagsTable
    let readStateTable: MessageHistoryReadStateTable
    let synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable
    let textIndexTable: MessageHistoryTextIndexTable
    let summaryTable: MessageHistoryTagsSummaryTable
    let pendingActionsTable: PendingMessageActionsTable
    let groupAssociationTable: PeerGroupAssociationTable
    let groupFeedIndexTable: GroupFeedIndexTable
    
    init(valueBox: ValueBox, table: ValueBoxTable, messageHistoryIndexTable: MessageHistoryIndexTable, messageMediaTable: MessageMediaTable, historyMetadataTable: MessageHistoryMetadataTable, globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable, unsentTable: MessageHistoryUnsentTable, tagsTable: MessageHistoryTagsTable, globalTagsTable: GlobalMessageHistoryTagsTable, localTagsTable: LocalMessageHistoryTagsTable, readStateTable: MessageHistoryReadStateTable, synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable, textIndexTable: MessageHistoryTextIndexTable, summaryTable: MessageHistoryTagsSummaryTable, pendingActionsTable: PendingMessageActionsTable, groupAssociationTable: PeerGroupAssociationTable, groupFeedIndexTable: GroupFeedIndexTable) {
        self.messageHistoryIndexTable = messageHistoryIndexTable
        self.messageMediaTable = messageMediaTable
        self.historyMetadataTable = historyMetadataTable
        self.globallyUniqueMessageIdsTable = globallyUniqueMessageIdsTable
        self.unsentTable = unsentTable
        self.tagsTable = tagsTable
        self.globalTagsTable = globalTagsTable
        self.localTagsTable = localTagsTable
        self.readStateTable = readStateTable
        self.synchronizeReadStateTable = synchronizeReadStateTable
        self.textIndexTable = textIndexTable
        self.summaryTable = summaryTable
        self.pendingActionsTable = pendingActionsTable
        self.groupAssociationTable = groupAssociationTable
        self.groupFeedIndexTable = groupFeedIndexTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ index: MessageIndex, key: ValueBoxKey = ValueBoxKey(length: 8 + 4 + 4 + 4)) -> ValueBoxKey {
        key.setInt64(0, value: index.id.peerId.toInt64())
        key.setInt32(8, value: index.timestamp)
        key.setInt32(8 + 4, value: index.id.namespace)
        key.setInt32(8 + 4 + 4, value: index.id.id)
        return key
    }
    
    private func lowerBound(_ peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    private func upperBound(_ peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key.successor
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
    
    private func processIndexOperationsCommitAccumulatedRemoveIndices(peerId: PeerId, accumulatedRemoveIndices: inout [(MessageIndex, Bool)], updatedCombinedState: inout CombinedPeerReadState?, invalidateReadState: inout Bool, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], outputOperations: inout [MessageHistoryOperation], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        if !accumulatedRemoveIndices.isEmpty {
            let (combinedState, invalidate) = self.readStateTable.deleteMessages(peerId, indices: accumulatedRemoveIndices.filter({ $0.1 }).map({ $0.0 }), incomingStatsInIndices: { peerId, namespace, indices in
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
                var indicesWithMetadata: [(MessageIndex, Bool, MessageTags)] = []
                var globalIndicesWithMetadata: [(GlobalMessageTags, MessageIndex)] = []
                
                for index in bucket {
                    let tagsAndGlobalTags = self.justRemove(index.0, unsentMessageOperations: &unsentMessageOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    if let (tags, globalTags) = tagsAndGlobalTags {
                        indicesWithMetadata.append((index.0, index.1, tags))
                        
                        if !globalTags.isEmpty {
                            globalIndicesWithMetadata.append((globalTags, index.0))
                        }
                    } else {
                        indicesWithMetadata.append((index.0, index.1, MessageTags()))
                    }
                }
                assert(bucket.count == indicesWithMetadata.count)
                outputOperations.append(.Remove(indicesWithMetadata))
                if !globalIndicesWithMetadata.isEmpty {
                    globalTagsOperations.append(.remove(globalIndicesWithMetadata))
                }
                var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                self.maybeCombineGroups(at: bucket[0].0, updatedGroupInfos: &updatedGroupInfos)
                if !updatedGroupInfos.isEmpty {
                    outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                }
            }
            
            accumulatedRemoveIndices.removeAll()
        }
    }
    
    private func processIndexOperations(_ peerId: PeerId, operations: [MessageHistoryIndexOperation], processedOperationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        let sharedKey = self.key(MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 0), namespace: 0, id: 0), timestamp: 0))
        let sharedBuffer = WriteBuffer()
        let sharedEncoder = PostboxEncoder()
        
        var outputOperations: [MessageHistoryOperation] = []
        var accumulatedRemoveIndices: [(MessageIndex, Bool)] = []
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
                case let .InsertHole(hole):
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    commitAccumulatedAddedIndices()
                    
                    let updatedGroupInfos = self.justInsertHole(hole)
                    outputOperations.append(.InsertHole(hole))
                    if !updatedGroupInfos.isEmpty {
                        outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                    }
                    
                    let tags = self.messageHistoryIndexTable.seedConfiguration.existingMessageTags.rawValue & hole.tags
                    for i in 0 ..< 32 {
                        let currentTags = tags >> UInt32(i)
                        if currentTags == 0 {
                            break
                        }
                        
                        if (currentTags & 1) != 0 {
                            let tag = MessageTags(rawValue: 1 << UInt32(i))
                            self.tagsTable.add(tag, index: hole.maxIndex, isHole: true, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                        }
                    }
                case let .InsertMessage(storeMessage):
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    
                    let (message, updatedGroupInfos) = self.justInsertMessage(storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations, updateExistingMedia: &updateExistingMedia)
                    outputOperations.append(.InsertMessage(message))
                    if !updatedGroupInfos.isEmpty {
                        outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                    }
                    
                    if message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                        self.unsentTable.add(message.id, operations: &unsentMessageOperations)
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
                                self.tagsTable.add(tag, index: MessageIndex(message), isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                            }
                        }
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
                                if self.globalTagsTable.addMessage(tag, index: MessageIndex(message)) {
                                    globalTagsOperations.append(.insertMessage(tag, message))
                                }
                            }
                        }
                    }
                    if !message.localTags.isEmpty {
                        self.localTagsTable.set(id: message.id, tags: message.localTags, previousTags: [], operations: &localTagsOperations)
                    }
                    if message.flags.contains(.Incoming) {
                        accumulatedAddedIncomingMessageIndices.insert(MessageIndex(message))
                    }
                case let .InsertExistingMessage(message):
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    if message.flags.contains(.CanBeGroupedIntoFeed) {
                        if let groupId = self.groupAssociationTable.get(peerId: message.id.peerId) {
                            if let internalMessage = self.getMessage(MessageIndex(message)) {
                                self.groupFeedIndexTable.add(groupId: groupId, message: internalMessage, operations: &groupFeedOperations)
                            } else {
                                assertionFailure()
                            }
                        }
                    }
                case let .Remove(index, isMessage):
                    commitAccumulatedAddedIndices()
                    
                    accumulatedRemoveIndices.append((index, isMessage))
                case let .Update(index, storeMessage):
                    commitAccumulatedAddedIndices()
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    
                    var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                    if let (message, previousTags) = self.justUpdate(index, message: storeMessage, sharedKey: sharedKey, sharedBuffer: sharedBuffer, sharedEncoder: sharedEncoder, unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations, updatedMedia: &updatedMedia) {
                        outputOperations.append(.Remove([(index, true, previousTags)]))
                        outputOperations.append(.InsertMessage(message))
                        if !updatedGroupInfos.isEmpty {
                            outputOperations.append(.UpdateGroupInfos(updatedGroupInfos))
                        }
                        
                        if message.flags.contains(.Incoming) {
                            if index != MessageIndex(message) {
                                accumulatedRemoveIndices.append((index, true))
                                accumulatedAddedIncomingMessageIndices.insert(MessageIndex(message))
                            }
                        }
                    }
                case let .UpdateTimestamp(index, timestamp):
                    commitAccumulatedAddedIndices()
                    processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
                    
                    var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
                    let tagsAndGlobalTags = self.justUpdateTimestamp(index, timestamp: timestamp, unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations, updatedMedia: &updatedMedia)
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
        processIndexOperationsCommitAccumulatedRemoveIndices(peerId: peerId, accumulatedRemoveIndices: &accumulatedRemoveIndices, updatedCombinedState: &updatedCombinedState, invalidateReadState: &invalidateReadState, unsentMessageOperations: &unsentMessageOperations, outputOperations: &outputOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        
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
                    internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
                case let .Partial(peerId, namespace):
                    let id = self.historyMetadataTable.getNextMessageIdAndIncrement(peerId, namespace: namespace)
                    internalStoreMessages.append(InternalStoreMessage(id: id, timestamp: message.timestamp, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributes: message.attributes, media: message.media))
            }
        }
        return internalStoreMessages
    }
    
    func addMessages(messages: [StoreMessage], location: AddMessagesLocation, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], processMessages: (([PeerId : [StoreMessage]]) -> Void)?) -> [Int64: MessageId] {
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
            self.messageHistoryIndexTable.addMessages(internalPeerMessages, location: location, operations: &operations)
            
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
        
        processMessages?(messagesByPeerId)
        
        return globallyUniqueIdToMessageId
    }
    
    func addMessagesInternal(messages: [InternalStoreMessage], location: AddMessagesLocation, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        let messagesByPeerId = self.messagesGroupedByPeerId(messages)
        var globallyUniqueIdToMessageId: [Int64: MessageId] = [:]
        var globalTagsInitialized = Set<GlobalMessageTags>()
        for (peerId, peerMessages) in messagesByPeerId {
            var operations: [MessageHistoryIndexOperation] = []
            let internalPeerMessages = peerMessages
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
            self.messageHistoryIndexTable.addMessages(internalPeerMessages, location: location, operations: &operations)
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
    }
    
    func addHoles(_ messageIds: [MessageId], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            for id in messageIds {
                self.messageHistoryIndexTable.addHole(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
    }
    
    func removeMessages(_ messageIds: [MessageId], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        for (peerId, messageIds) in self.messageIdsByPeerId(messageIds) {
            var operations: [MessageHistoryIndexOperation] = []
            
            for id in messageIds {
                self.messageHistoryIndexTable.removeMessage(id, operations: &operations)
            }
            self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
    }
    
    func removeMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.removeMessagesInRange(peerId: peerId, namespace: namespace, minId: minId, maxId: maxId, operations: &operations)
        
        self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func clearHistory(peerId: PeerId, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        let indices = self.allIndices(peerId)
        for index in indices.holes {
            self.fillHole(index.id, fillType: HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), tagMask: nil, messages: [], operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
        self.removeMessages(indices.messages.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func removeAllMessagesWithAuthor(peerId: PeerId, authorId: PeerId, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        let indices = self.allIndicesWithAuthor(peerId, authorId: authorId)
        self.removeMessages(indices.map { $0.id }, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func fillHole(_ id: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.fillHole(id, fillType: fillType, tagMask: tagMask, messages: self.internalStoreMessages(messages), operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func fillMultipleHoles(mainHoleId: MessageId, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage], operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.fillMultipleHoles(mainHoleId: mainHoleId, fillType: fillType, tagMask: tagMask, messages: self.internalStoreMessages(messages), operations: &operations)
        self.processIndexOperations(mainHoleId.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func updateMessage(_ id: MessageId, message: StoreMessage, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.updateMessage(id, message: self.internalStoreMessages([message]).first!, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func updateMessageTimestamp(_ id: MessageId, timestamp: Int32, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.updateTimestamp(id, timestamp: timestamp, operations: &operations)
        self.processIndexOperations(id.peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
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
        if let topEntry = self.topIndexEntry(peerId: messageId.peerId, namespace: messageId.namespace, operationsByPeerId: &operationsByPeerId), case let .Message(index) = topEntry {
            if let message = self.getMessage(index) {
                topMessageId = (index.id.id, !message.flags.contains(.Incoming))
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
    
    func applyInteractiveMaxReadIndex(_ messageIndex: MessageIndex, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?]) -> [MessageId] {
        var topMessageId: (MessageId.Id, Bool)?
        if let topEntry = self.topIndexEntry(peerId: messageIndex.id.peerId, namespace: messageIndex.id.namespace, operationsByPeerId: &operationsByPeerId), case let .Message(index) = topEntry {
            if let message = self.getMessage(index) {
                topMessageId = (index.id.id, !message.flags.contains(.Incoming))
            } else {
                topMessageId = (index.id.id, false)
            }
        }
        
        let (combinedState, result, messageIds) = self.readStateTable.applyInteractiveMaxReadIndex(messageIndex, incomingStatsInRange: { namespace, fromId, toId in
            return self.messageHistoryIndexTable.incomingMessageCountInRange(messageIndex.id.peerId, namespace: namespace, minId: fromId, maxId: toId)
        }, incomingIndexStatsInRange: { fromIndex, toIndex in
            return self.incomingMessageCountInRange(messageIndex.id.peerId, namespace: messageIndex.id.namespace, fromIndex: fromIndex, toIndex: toIndex)
        }, topMessageId: topMessageId, topMessageIndexByNamespace: { namespace in
            if let topEntry = self.topIndexEntry(peerId: messageIndex.id.peerId, namespace: namespace, operationsByPeerId: &operationsByPeerId), case let .Message(index) = topEntry {
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
    
    func topMessage(_ peerId: PeerId) -> IntermediateMessage? {
        var currentKey = self.upperBound(peerId)
        while true {
            var entry: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.table, start: currentKey, end: self.lowerBound(peerId), values: { key, value in
                entry = self.readIntermediateEntry(key, value: value)
                return true
            }, limit: 1)
            
            if let entry = entry {
                switch entry {
                    case .Hole:
                        currentKey = self.key(entry.index).predecessor
                    case let .Message(message):
                        return message
                }
            } else {
                break
            }
        }
        return nil
    }
    
    func exists(_ index: MessageIndex) -> Bool {
        return self.valueBox.exists(self.table, key: self.key(index))
    }
    
    func topIndexEntry(peerId: PeerId, namespace: MessageId.Namespace, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]]) -> HistoryIndexEntry? {
        var operations: [MessageHistoryIndexOperation] = []
        let result = self.messageHistoryIndexTable.top(peerId, namespace: namespace, operations: &operations)
        
        var updatedMedia: [MediaId: Media?] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var groupFeedOperations: [PeerGroupId: [GroupFeedIndexOperation]] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        
        self.processIndexOperations(peerId, operations: operations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        
        
        assert(updatedMedia.isEmpty)
        assert(unsentMessageOperations.isEmpty)
        assert(updatedPeerReadStateOperations.isEmpty)
        assert(globalTagsOperations.isEmpty)
        assert(pendingActionsOperations.isEmpty)
        assert(updatedMessageActionsSummaries.isEmpty)
        assert(updatedMessageTagSummaries.isEmpty)
        assert(invalidateMessageTagSummaries.isEmpty)
        assert(groupFeedOperations.isEmpty)
        assert(localTagsOperations.isEmpty)
        
        return result
    }
    
    func getMessage(_ index: MessageIndex) -> IntermediateMessage? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.table, key: key) {
            let entry = self.readIntermediateEntry(key, value: value)
            if case let .Message(message) = entry {
                return message
            }
        } else if let tableIndex = self.messageHistoryIndexTable.getMaybeUninitialized(index.id) {
            if case let .Message(updatedIndex) = tableIndex {
                let key = self.key(updatedIndex)
                if let value = self.valueBox.get(self.table, key: key) {
                    let entry = self.readIntermediateEntry(key, value: value)
                    if case let .Message(message) = entry {
                        return message
                    }
                }
            }
        }
        return nil
    }
    
    func getMessageGroup(_ index: MessageIndex) -> [IntermediateMessage]? {
        if let value = self.valueBox.get(self.table, key: self.key(index)) {
            let entry = self.readIntermediateEntry(self.key(index), value: value)
            if case let .Message(message) = entry {
                if let groupingKey = message.groupingKey {
                    var result: [IntermediateMessage] = []
                    var previousIndex = index
                    while true {
                        var previous: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(previousIndex), end: self.lowerBound(index.id.peerId), values: { key, value in
                            previous = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let previous = previous, case let .Message(previousMessage) = previous, previousMessage.groupingKey == groupingKey {
                            result.insert(previousMessage, at: 0)
                            previousIndex = MessageIndex(previousMessage)
                        } else {
                            break
                        }
                    }
                    result.append(message)
                    var nextIndex = index
                    while true {
                        var next: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(nextIndex), end: self.upperBound(index.id.peerId), values: { key, value in
                            next = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let next = next, case let .Message(nextMessage) = next, nextMessage.groupingKey == groupingKey {
                            result.append(nextMessage)
                            nextIndex = MessageIndex(nextMessage)
                        } else {
                            break
                        }
                    }
                    return result
                } else {
                    return [message]
                }
            }
        }
        return nil
    }
    
    func getMessageForwardedGroup(_ index: MessageIndex) -> [IntermediateMessage]? {
        if let value = self.valueBox.get(self.table, key: self.key(index)) {
            let entry = self.readIntermediateEntry(self.key(index), value: value)
            if case let .Message(message) = entry {
                if let _ = message.forwardInfo {
                    var result: [IntermediateMessage] = []
                    var previousIndex = index
                    while true {
                        var previous: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(previousIndex), end: self.lowerBound(index.id.peerId), values: { key, value in
                            previous = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let previous = previous, case let .Message(previousMessage) = previous, previousMessage.authorId == message.authorId, previousMessage.forwardInfo != nil, previousMessage.timestamp == index.timestamp {
                            result.insert(previousMessage, at: 0)
                            previousIndex = MessageIndex(previousMessage)
                        } else {
                            break
                        }
                    }
                    result.append(message)
                    var nextIndex = index
                    while true {
                        var next: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(nextIndex), end: self.upperBound(index.id.peerId), values: { key, value in
                            next = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let next = next, case let .Message(nextMessage) = next, nextMessage.authorId == message.authorId, nextMessage.forwardInfo != nil, nextMessage.timestamp == index.timestamp {
                            result.append(nextMessage)
                            nextIndex = MessageIndex(nextMessage)
                        } else {
                            break
                        }
                    }
                    return result
                } else {
                    return [message]
                }
            }
        }
        return nil
    }
    
    func getMessageFailedGroup(_ index: MessageIndex) -> [IntermediateMessage]? {
        if let value = self.valueBox.get(self.table, key: self.key(index)) {
            let entry = self.readIntermediateEntry(self.key(index), value: value)
            if case let .Message(message) = entry {
                if message.flags.contains(.Failed) {
                    var result: [IntermediateMessage] = []
                    var previousIndex = index
                    while true {
                        var previous: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(previousIndex), end: self.lowerBound(index.id.peerId), values: { key, value in
                            previous = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let previous = previous, case let .Message(previousMessage) = previous, previousMessage.authorId == message.authorId, previousMessage.flags.contains(.Failed) {
                            result.insert(previousMessage, at: 0)
                            previousIndex = MessageIndex(previousMessage)
                        } else {
                            break
                        }
                    }
                    result.append(message)
                    var nextIndex = index
                    while true {
                        var next: IntermediateMessageHistoryEntry?
                        self.valueBox.range(self.table, start: self.key(nextIndex), end: self.upperBound(index.id.peerId), values: { key, value in
                            next = readIntermediateEntry(key, value: value)
                            return false
                        }, limit: 1)
                        if let next = next, case let .Message(nextMessage) = next, nextMessage.authorId == message.authorId, nextMessage.flags.contains(.Failed) {
                            result.append(nextMessage)
                            nextIndex = MessageIndex(nextMessage)
                        } else {
                            break
                        }
                    }
                    return result
                } else {
                    return [message]
                }
            }
        }
        return nil
    }
    
    func offsetPendingMessagesTimestamps(lowerBound: MessageId, excludeIds: Set<MessageId>, timestamp: Int32, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation],  updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) {
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
            self.updateMessageTimestamp(messageId, timestamp: timestamp, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
    }
    
    func updateMessageGroupingKeysAtomically(ids: [MessageId], groupingKey: Int64, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation],  updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation]) {
        if ids.isEmpty {
            return
        }
        
        var indices: [MessageIndex] = []
        for id in ids {
            if let entry = self.messageHistoryIndexTable.getMaybeUninitialized(id), case let .Message(index) = entry {
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
                    .Remove([(index, true, message.tags)]),
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
    
    private func adjacentEntries(_ index: MessageIndex, key: Int64) -> (lower: (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo), upper: (IntermediateMessageHistoryEntry?, AdjacentEntryGroupInfo)) {
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        self.valueBox.range(self.table, start: self.key(index), end: self.lowerBound(index.id.peerId), values: { key, value in
            lower = self.readIntermediateEntry(key, value: value)
            return false
        }, limit: 1)
        
        self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(index.id.peerId), values: { key, value in
            upper = self.readIntermediateEntry(key, value: value)
            return false
        }, limit: 1)
        
        return (getAdjacentEntryGroupInfo(lower, key: key), getAdjacentEntryGroupInfo(upper, key: key))
    }
    
    private func adjacentMessages(_ index: MessageIndex) -> (lower: IntermediateMessage?, upper: IntermediateMessage?) {
        var lower: IntermediateMessage?
        var upper: IntermediateMessage?
        
        self.valueBox.range(self.table, start: self.key(index), end: self.lowerBound(index.id.peerId), values: { key, value in
            if case let .Message(message) = self.readIntermediateEntry(key, value: value) {
                lower = message
            }
            return false
        }, limit: 1)
        
        self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(index.id.peerId), values: { key, value in
            if case let .Message(message) = self.readIntermediateEntry(key, value: value) {
                upper = message
            }
            return false
        }, limit: 1)
        
        return (lower, upper)
    }
    
    private func generateNewGroupInfo() -> MessageGroupInfo {
        return MessageGroupInfo(stableId: self.historyMetadataTable.getNextStableMessageIndexId())
    }
    
    private func updateSameGroupInfos(lowerBound: MessageIndex, from previousInfo: MessageGroupInfo, to updatedInfo: MessageGroupInfo, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        var index = lowerBound
        while true {
            var entry: IntermediateMessageHistoryEntry?
            self.valueBox.range(self.table, start: self.key(index), end: self.upperBound(lowerBound.id.peerId), values: { key, value in
                entry = readIntermediateEntry(key, value: value)
                return false
            }, limit: 1)
            if let entry = entry, case let .Message(message) = entry, message.groupInfo == previousInfo {
                let updatedMessage = message.withUpdatedGroupInfo(updatedInfo)
                self.storeIntermediateMessage(updatedMessage, sharedKey: self.key(MessageIndex(message)))
                updatedGroupInfos[message.id] = updatedInfo
                index = MessageIndex(message)
            } else {
                break
            }
        }
    }
    
    private func maybeSeparateGroups(at index: MessageIndex, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        let (lower, upper) = self.adjacentMessages(index)
        if let lower = lower, let upper = upper, let groupInfo = lower.groupInfo, lower.groupInfo == upper.groupInfo {
            self.updateSameGroupInfos(lowerBound: index, from: groupInfo, to: self.generateNewGroupInfo(), updatedGroupInfos: &updatedGroupInfos)
        }
    }
    
    private func maybeCombineGroups(at index: MessageIndex, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) {
        let (lower, upper) = self.adjacentMessages(index)
        if let lower = lower, let upper = upper, let groupInfo = lower.groupInfo, lower.groupingKey == upper.groupingKey {
            assert(upper.groupInfo != nil)
            if lower.groupInfo != upper.groupInfo {
                self.updateSameGroupInfos(lowerBound: index, from: upper.groupInfo!, to: groupInfo, updatedGroupInfos: &updatedGroupInfos)
            }
        }
    }
    
    private func updateGroupingInfoAroundInsertion(index: MessageIndex, groupingKey: Int64?, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) -> MessageGroupInfo? {
        if let groupingKey = groupingKey {
            var groupInfo: MessageGroupInfo?
            
            let (lowerEntryAndGroup, upperEntryAndGroup) = adjacentEntries(index, key: groupingKey)
            
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
                        self.updateSameGroupInfos(lowerBound: index, from: otherInfo, to: self.generateNewGroupInfo(), updatedGroupInfos: &updatedGroupInfos)
                    }
            }
            return groupInfo
        } else {
            self.maybeSeparateGroups(at: index, updatedGroupInfos: &updatedGroupInfos)
            return nil
        }
    }
    
    private func justInsertMessage(_ message: InternalStoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: PostboxEncoder, groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], updateExistingMedia: inout [MediaId: Media]) -> (IntermediateMessage, [MessageId: MessageGroupInfo]) {
        var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
        
        let groupInfo = self.updateGroupingInfoAroundInsertion(index: MessageIndex(message), groupingKey: message.groupingKey, updatedGroupInfos: &updatedGroupInfos)
        
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
        
        if self.messageHistoryIndexTable.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
            self.textIndexTable.add(messageId: message.id, text: message.text, tags: message.tags)
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
                let mediaInsertResult = self.messageMediaTable.set(media, index: MessageIndex(message), messageHistoryTable: self)
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
        
        self.valueBox.set(self.table, key: self.key(MessageIndex(message), key: sharedKey), value: sharedBuffer)
        
        let result = (IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: groupInfo, timestamp: message.timestamp, flags: flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia), updatedGroupInfos)
        
        if message.flags.contains(.CanBeGroupedIntoFeed) {
            if let groupId = self.groupAssociationTable.get(peerId: result.0.id.peerId) {
                self.groupFeedIndexTable.add(groupId: groupId, message: result.0, operations: &groupFeedOperations)
            }
        }
        
        return result
    }
    
    private func justInsertHole(_ hole: MessageHistoryHole, sharedBuffer: WriteBuffer = WriteBuffer()) -> [MessageId: MessageGroupInfo] {
        var updatedGroupInfos: [MessageId: MessageGroupInfo] = [:]
        
        self.maybeSeparateGroups(at: hole.maxIndex, updatedGroupInfos: &updatedGroupInfos)
        
        sharedBuffer.reset()
        var type: Int8 = 1
        sharedBuffer.write(&type, offset: 0, length: 1)
        var stableId: UInt32 = hole.stableId
        sharedBuffer.write(&stableId, offset: 0, length: 4)
        var minId: Int32 = hole.min
        sharedBuffer.write(&minId, offset: 0, length: 4)
        var tags: UInt32 = hole.tags
        sharedBuffer.write(&tags, offset: 0, length: 4)
        withExtendedLifetime(sharedBuffer, {
            self.valueBox.set(self.table, key: self.key(hole.maxIndex), value: sharedBuffer.readBufferNoCopy())
        })
        
        return updatedGroupInfos
    }
    
    private func tagsForIndex(_ index: MessageIndex) -> (MessageTags, GlobalMessageTags)? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.table, key: key) {
            switch self.readIntermediateEntry(key, value: value) {
                case let .Message(message):
                    return (message.tags, message.globalTags)
                case let .Hole(hole, _):
                    return (MessageTags(rawValue: hole.tags), GlobalMessageTags())
            }
        } else {
            return nil
        }
    }
    
    private func continuousIndexIntervalsForRemoving(_ indices: [(MessageIndex, Bool)]) -> [[(MessageIndex, Bool)]] {
        guard !indices.isEmpty else {
            return []
        }
        
        if indices.count == 1 {
            return [indices]
        }
        
        let indices = indices.sorted(by: {
            $0.0 < $1.0
        })
        var result: [[(MessageIndex, Bool)]] = []
        var bucket: [(MessageIndex, Bool)] = []
        
        bucket.append(indices[0])
        
        for i in 1 ..< indices.count {
            self.valueBox.range(self.table, start: self.key(indices[i].0), end: self.key(bucket[bucket.count - 1].0).predecessor, keys: { key in
                let entryIndex = self.readIndex(key)
                if entryIndex != indices[i - 1].0 {
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
    
    private func justRemove(_ index: MessageIndex, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> (MessageTags, GlobalMessageTags)? {
        let key = self.key(index)
        if let value = self.valueBox.get(self.table, key: key) {
            let resultTags: MessageTags
            let resultGlobalTags: GlobalMessageTags
            switch self.readIntermediateEntry(key, value: value) {
                case let .Message(message):
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
                    
                    if let globallyUniqueId = message.globallyUniqueId {
                        self.globallyUniqueMessageIdsTable.remove(peerId: message.id.peerId, globallyUniqueId: globallyUniqueId)
                    }
                    
                    self.pendingActionsTable.removeMessage(id: message.id, operations: &pendingActionsOperations, updatedSummaries: &updatedMessageActionsSummaries)
                    
                    for tag in message.tags {
                        self.tagsTable.remove(tag, index: index, isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    }
                    for tag in message.globalTags {
                        self.globalTagsTable.remove(tag, index: index)
                    }
                    if !message.localTags.isEmpty {
                        self.localTagsTable.set(id: index.id, tags: [], previousTags: message.localTags, operations: &localTagsOperations)
                    }
                    
                    for mediaId in message.referencedMedia {
                        let _ = self.messageMediaTable.removeReference(mediaId)
                    }
                    
                    if self.messageHistoryIndexTable.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
                        self.textIndexTable.remove(messageId: message.id)
                    }
                    
                    resultTags = message.tags
                    resultGlobalTags = message.globalTags
                
                    if message.flags.contains(.CanBeGroupedIntoFeed) {
                        if let groupId = self.groupAssociationTable.get(peerId: message.id.peerId) {
                            self.groupFeedIndexTable.remove(groupId: groupId, messageIndex: MessageIndex(message), operations: &groupFeedOperations)
                        }
                    }
                case let .Hole(hole, _):
                    let tags = self.messageHistoryIndexTable.seedConfiguration.existingMessageTags.rawValue & hole.tags
                    if tags != 0 {
                        for i in 0 ..< 32 {
                            let currentTags = tags >> UInt32(i)
                            if currentTags == 0 {
                                break
                            }
                            
                            if (currentTags & 1) != 0 {
                                let tag = MessageTags(rawValue: 1 << UInt32(i))
                                self.tagsTable.remove(tag, index: hole.maxIndex, isHole: true, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                            }
                        }
                    }
                    resultTags = MessageTags(rawValue: hole.tags)
                    resultGlobalTags = GlobalMessageTags()
            }
            
            self.valueBox.remove(self.table, key: key)
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
                    self.storeIntermediateMessage(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: message.referencedMedia), sharedKey: self.key(index))
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
    
    private func justUpdate(_ index: MessageIndex, message: InternalStoreMessage, sharedKey: ValueBoxKey, sharedBuffer: WriteBuffer, sharedEncoder: PostboxEncoder, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], updatedGroupInfos: inout [MessageId: MessageGroupInfo], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], updatedMedia: inout [MediaId: Media?]) -> (IntermediateMessage, MessageTags)? {
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
            
            if previousMediaIds != updatedMediaIds || index != MessageIndex(message) {
                for (_, media) in previousEmbeddedMediaWithIds {
                    self.messageMediaTable.removeEmbeddedMedia(media)
                }
                for mediaId in previousMessage.referencedMedia {
                    let _ = self.messageMediaTable.removeReference(mediaId)
                }
            }
            
            self.valueBox.remove(self.table, key: self.key(index))
            
            let updatedIndex = MessageIndex(message)
            
            let updatedGroupInfo = self.updateMovingGroupInfo(index: index, updatedIndex: updatedIndex, groupingKey: message.groupingKey, previousInfo: previousMessage.groupInfo, updatedGroupInfos: &updatedGroupInfos)
            
            if previousMessage.tags != message.tags || index != updatedIndex {
                if !previousMessage.tags.isEmpty {
                    self.tagsTable.remove(previousMessage.tags, index: index, isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                }
                if !message.tags.isEmpty {
                    self.tagsTable.add(message.tags, index: MessageIndex(message), isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                }
            }
            
            if previousMessage.globalTags != message.globalTags || (MessageIndex(previousMessage) != MessageIndex(message) && (!previousMessage.globalTags.isEmpty || !message.globalTags.isEmpty)) {
                if !previousMessage.globalTags.isEmpty {
                    for tag in previousMessage.globalTags {
                        self.globalTagsTable.remove(tag, index: index)
                    }
                }
                if !message.globalTags.isEmpty {
                    for tag in message.globalTags {
                        let _ = self.globalTagsTable.addMessage(tag, index: MessageIndex(message))
                    }
                }
            }
            
            if previousMessage.id != message.id && (!previousMessage.localTags.isEmpty || !message.localTags.isEmpty) {
                self.localTagsTable.set(id: previousMessage.id, tags: [], previousTags: previousMessage.localTags, operations: &localTagsOperations)
                self.localTagsTable.set(id: message.id, tags: message.localTags, previousTags: [], operations: &localTagsOperations)
            } else if previousMessage.localTags != message.localTags {
                self.localTagsTable.set(id: message.id, tags: message.localTags, previousTags: previousMessage.localTags, operations: &localTagsOperations)
            } else {
                for tag in message.localTags {
                    localTagsOperations.append(.Update(tag, message.id))
                }
            }
            
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
                assertionFailure("implement global tags")
                if index != MessageIndex(message) {
                    
                } else if message.globalTags != previousMessage.globalTags {
                    
                }
            }
            
            switch (previousMessage.flags.contains(.Unsent) && !previousMessage.flags.contains(.Failed), message.flags.contains(.Unsent) && !message.flags.contains(.Failed)) {
                case (true, false):
                    self.unsentTable.remove(index.id, operations: &unsentMessageOperations)
                case (false, true):
                    self.unsentTable.add(message.id, operations: &unsentMessageOperations)
                case (true, true):
                    if index != MessageIndex(message) {
                        self.unsentTable.remove(index.id, operations: &unsentMessageOperations)
                        self.unsentTable.add(message.id, operations: &unsentMessageOperations)
                    }
                case (false, false):
                    break
            }
            
            if self.messageHistoryIndexTable.seedConfiguration.peerNamespacesRequiringMessageTextIndex.contains(message.id.peerId.namespace) {
                if previousMessage.id != message.id || previousMessage.text != message.text || previousMessage.tags != message.tags {
                    self.textIndexTable.remove(messageId: previousMessage.id)
                    self.textIndexTable.add(messageId: message.id, text: message.text, tags: message.tags)
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
            if !message.localTags.isEmpty {
                dataFlags.insert(.hasLocalTags)
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
            
            var flags = MessageFlags(message.flags)
            sharedBuffer.write(&flags.rawValue, offset: 0, length: 4)
            
            var tags = message.tags
            sharedBuffer.write(&tags.rawValue, offset: 0, length: 4)
            
            var intermediateForwardInfo: IntermediateMessageForwardInfo?
            if let forwardInfo = message.forwardInfo {
                intermediateForwardInfo = IntermediateMessageForwardInfo(forwardInfo)
                
                var forwardInfoFlags: Int8 = 1
                if forwardInfo.sourceId != nil {
                    forwardInfoFlags |= 2
                }
                if forwardInfo.sourceMessageId != nil {
                    forwardInfoFlags |= 4
                }
                if forwardInfo.authorSignature != nil {
                    forwardInfoFlags |= 8
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
                    let mediaInsertResult = self.messageMediaTable.set(media, index: MessageIndex(message), messageHistoryTable: self)
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
            
            self.valueBox.set(self.table, key: self.key(MessageIndex(message), key: sharedKey), value: sharedBuffer)
            
            let result = (IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: groupInfo, timestamp: message.timestamp, flags: flags, tags: tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: intermediateForwardInfo, authorId: message.authorId, text: message.text, attributesData: attributesBuffer.makeReadBufferAndReset(), embeddedMediaData: embeddedMediaBuffer.makeReadBufferAndReset(), referencedMedia: referencedMedia), previousMessage.tags)
            
            if previousMessage.flags.contains(.CanBeGroupedIntoFeed) {
                if let groupId = self.groupAssociationTable.get(peerId: previousMessage.id.peerId) {
                    self.groupFeedIndexTable.remove(groupId: groupId, messageIndex: MessageIndex(previousMessage), operations: &groupFeedOperations)
                }
            }
            if result.0.flags.contains(.CanBeGroupedIntoFeed) {
                if let groupId = self.groupAssociationTable.get(peerId: result.0.id.peerId) {
                    self.groupFeedIndexTable.add(groupId: groupId, message: result.0, operations: &groupFeedOperations)
                }
            }
            
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
    
    private func updateMovingGroupInfo(index: MessageIndex, updatedIndex: MessageIndex, groupingKey: Int64?, previousInfo: MessageGroupInfo?, updatedGroupInfos: inout [MessageId: MessageGroupInfo]) -> MessageGroupInfo? {
        let (previousLowerMessage, previousUpperMessage) = self.adjacentMessages(index)
        let (updatedLowerMessage, updatedUpperMessage) = self.adjacentMessages(updatedIndex)
        if previousLowerMessage?.id == updatedLowerMessage?.id && previousUpperMessage?.id == updatedUpperMessage?.id {
            return previousInfo
        } else {
            self.maybeCombineGroups(at: index, updatedGroupInfos: &updatedGroupInfos)
            
            let groupInfo = self.updateGroupingInfoAroundInsertion(index: updatedIndex, groupingKey: groupingKey, updatedGroupInfos: &updatedGroupInfos)
            
            return groupInfo
        }
    }
    
    private func justUpdateTimestamp(_ index: MessageIndex, timestamp: Int32, unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], updatedGroupInfos: inout [MessageId: MessageGroupInfo], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation], updatedMedia: inout [MediaId: Media?]) -> (MessageTags, GlobalMessageTags)? {
        if let previousMessage = self.getMessage(index) {
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = previousMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.authorId, sourceId: forwardInfo.sourceId, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
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
            
            let _ = self.justUpdate(index, message: InternalStoreMessage(id: previousMessage.id, timestamp: timestamp, globallyUniqueId: previousMessage.globallyUniqueId, groupingKey: previousMessage.groupingKey, flags: StoreMessageFlags(previousMessage.flags), tags: previousMessage.tags, globalTags: previousMessage.globalTags, localTags: previousMessage.localTags, forwardInfo: storeForwardInfo, authorId: previousMessage.authorId, text: previousMessage.text, attributes: parsedAttributes, media: parsedMedia), sharedKey: self.key(updatedIndex), sharedBuffer: WriteBuffer(), sharedEncoder: PostboxEncoder(), unsentMessageOperations: &unsentMessageOperations, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, updatedGroupInfos: &updatedGroupInfos, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations, updatedMedia: &updatedMedia)
            return (previousMessage.tags, previousMessage.globalTags)
            
            
            self.valueBox.remove(self.table, key: self.key(index))
            //TODO changed updatedIndex -> index
            #if os(iOS)
                //assert(false)
            #endif
            let updatedGroupInfo = self.updateMovingGroupInfo(index: index, updatedIndex: index, groupingKey: previousMessage.groupingKey, previousInfo: previousMessage.groupInfo, updatedGroupInfos: &updatedGroupInfos)
            if let updatedGroupInfo = updatedGroupInfo, previousMessage.groupInfo != updatedGroupInfo {
                updatedGroupInfos[index.id] = updatedGroupInfo
            }
            
            //for media in previousMessage.referencedMedia
            
            let updatedMessage = IntermediateMessage(stableId: previousMessage.stableId, stableVersion: previousMessage.stableVersion + 1, id: previousMessage.id, globallyUniqueId: previousMessage.globallyUniqueId, groupingKey: previousMessage.groupingKey, groupInfo: updatedGroupInfo, timestamp: timestamp, flags: previousMessage.flags, tags: previousMessage.tags, globalTags: previousMessage.globalTags, localTags: previousMessage.localTags, forwardInfo: previousMessage.forwardInfo, authorId: previousMessage.authorId, text: previousMessage.text, attributesData: previousMessage.attributesData, embeddedMediaData: previousMessage.embeddedMediaData, referencedMedia: previousMessage.referencedMedia)
            self.storeIntermediateMessage(updatedMessage, sharedKey: self.key(updatedIndex))
            
            let tags = previousMessage.tags.rawValue
            if tags != 0 {
                for i in 0 ..< 32 {
                    let currentTags = tags >> UInt32(i)
                    if currentTags == 0 {
                        break
                    }
                    
                    if (currentTags & 1) != 0 {
                        let tag = MessageTags(rawValue: 1 << UInt32(i))
                        self.tagsTable.remove(tag, index: index, isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                        self.tagsTable.add(tag, index: updatedIndex, isHole: false, updatedSummaries: &updatedMessageTagSummaries, invalidateSummaries: &invalidateMessageTagSummaries)
                    }
                }
            }
            
            let globalTags = previousMessage.globalTags.rawValue
            if globalTags != 0 {
                for i in 0 ..< 32 {
                    let currentTags = globalTags >> UInt32(i)
                    if currentTags == 0 {
                        break
                    }
                    
                    if (currentTags & 1) != 0 {
                        let tag = GlobalMessageTags(rawValue: 1 << UInt32(i))
                        self.globalTagsTable.remove(tag, index: index)
                        let _ = self.globalTagsTable.addMessage(tag, index: MessageIndex(id: index.id, timestamp: timestamp))
                    }
                }
            }
            
            if previousMessage.flags.contains(.CanBeGroupedIntoFeed) {
                if let groupId = self.groupAssociationTable.get(peerId: previousMessage.id.peerId) {
                    self.groupFeedIndexTable.remove(groupId: groupId, messageIndex: MessageIndex(previousMessage), operations: &groupFeedOperations)
                    self.groupFeedIndexTable.add(groupId: groupId, message: previousMessage.withUpdatedTimestamp(timestamp), operations: &groupFeedOperations)
                }
            }
            
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
                    self.storeIntermediateMessage(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: updatedEmbeddedMediaBuffer.readBufferNoCopy(), referencedMedia: updatedReferencedMedia), sharedKey: self.key(index))
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
        
        var flagsValue: UInt32 = message.flags.rawValue
        sharedBuffer.write(&flagsValue, offset: 0, length: 4)
        
        var tagsValue: UInt32 = message.tags.rawValue
        sharedBuffer.write(&tagsValue, offset: 0, length: 4)
        
        if let forwardInfo = message.forwardInfo {
            var forwardInfoFlags: Int8 = 1
            if forwardInfo.sourceId != nil {
                forwardInfoFlags |= 2
            }
            if forwardInfo.sourceMessageId != nil {
                forwardInfoFlags |= 4
            }
            if forwardInfo.authorSignature != nil {
                forwardInfoFlags |= 8
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
    
    private func readIndex(_ key: ValueBoxKey) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
    }
    
    private func readIntermediateEntry(_ key: ValueBoxKey, value: ReadBuffer) -> IntermediateMessageHistoryEntry {
        let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
        
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
                
                forwardInfo = IntermediateMessageForwardInfo(authorId: forwardAuthorId == 0 ? nil : PeerId(forwardAuthorId), sourceId: forwardSourceId, sourceMessageId: forwardSourceMessageId, date: forwardDate, authorSignature: authorSignature)
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
            
            return .Message(IntermediateMessage(stableId: stableId, stableVersion: stableVersion, id: index.id, globallyUniqueId: globallyUniqueId, groupingKey: groupingKey, groupInfo: groupInfo, timestamp: index.timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: forwardInfo, authorId: authorId, text: text, attributesData: attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: referencedMediaIds))
        } else {
            var stableId: UInt32 = 0
            value.read(&stableId, offset: 0, length: 4)
            
            var minId: Int32 = 0
            value.read(&minId, offset: 0, length: 4)
            var tags: UInt32 = 0
            value.read(&tags, offset: 0, length: 4)
            
            return .Hole(MessageHistoryHole(stableId: stableId, maxIndex: index, min: minId, tags: tags), lowerIndex: nil)
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
    
    func renderMessage(_ message: IntermediateMessage, peerTable: PeerTable, addAssociatedMessages: Bool = true) -> Message {
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
            forwardInfo = MessageForwardInfo(author: forwardAuthor, source: source, sourceMessageId: internalForwardInfo.sourceMessageId, date: internalForwardInfo.date, authorSignature: internalForwardInfo.authorSignature)
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
        for attribute in parsedAttributes {
            for peerId in attribute.associatedPeerIds {
                if let peer = peerTable.get(peerId) {
                    peers[peer.id] = peer
                }
            }
            associatedMessageIds.append(contentsOf: attribute.associatedMessageIds)
            if addAssociatedMessages {
                for messageId in attribute.associatedMessageIds {
                    if let entry = self.messageHistoryIndexTable.getMaybeUninitialized(messageId) {
                        if case let .Message(index) = entry {
                            if let message = self.getMessage(index) {
                                associatedMessages[messageId] = self.renderMessage(message, peerTable: peerTable, addAssociatedMessages: false)
                            }
                        }
                    }
                }
            }
        }
        
        return Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: forwardInfo, author: author, text: message.text, attributes: parsedAttributes, media: parsedMedia, peers: peers, associatedMessages: associatedMessages, associatedMessageIds: associatedMessageIds)
    }
    
    func entriesAround(peerIds: [PeerId], index: MessageIndex, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], updatedMedia: inout [MediaId: Media?], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        var lowerEntries: [IntermediateMessageHistoryEntry] = []
        var upperEntries: [IntermediateMessageHistoryEntry] = []
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        lowerEntries.append(contentsOf: self.earlierEntries(peerIds, index: index, count: count / 2 + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        upperEntries.append(contentsOf: self.laterEntries(peerIds, index: index.predecessor(), count: count - lowerEntries.count + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
        
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [IntermediateMessageHistoryEntry] = []
            
            additionalLowerEntries.append(contentsOf: self.earlierEntries(peerIds, index: lowerEntries.last!.index, count: count - lowerEntries.count - upperEntries.count + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
            
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func entriesAround(_ tagMask: MessageTags, peerIds: [PeerId], index: MessageIndex, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        var lowerEntries: [IntermediateMessageHistoryEntry] = []
        var upperEntries: [IntermediateMessageHistoryEntry] = []
        var lower: IntermediateMessageHistoryEntry?
        var upper: IntermediateMessageHistoryEntry?
        
        lowerEntries.append(contentsOf: self.earlierEntries(tagMask: tagMask, peerIds: peerIds, index: index, count: count / 2 + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
        
        if lowerEntries.count >= count / 2 + 1 {
            lower = lowerEntries.last
            lowerEntries.removeLast()
        }
        
        upperEntries.append(contentsOf: self.laterEntries(tagMask: tagMask, peerIds: peerIds, index: index.predecessor(), count: count - lowerEntries.count + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
        
        if upperEntries.count >= count - lowerEntries.count + 1 {
            upper = upperEntries.last
            upperEntries.removeLast()
        }
        
        if lowerEntries.count != 0 && lowerEntries.count + upperEntries.count < count {
            var additionalLowerEntries: [IntermediateMessageHistoryEntry] = []
            
            additionalLowerEntries.append(contentsOf: self.earlierEntries(tagMask: tagMask, peerIds: peerIds, index: lowerEntries.last!.index, count: count - lowerEntries.count - upperEntries.count + 1, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations))
            
            if additionalLowerEntries.count >= count - lowerEntries.count + upperEntries.count + 1 {
                lower = additionalLowerEntries.last
                additionalLowerEntries.removeLast()
            }
            lowerEntries.append(contentsOf: additionalLowerEntries)
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        entries.append(contentsOf: lowerEntries.reversed())
        entries.append(contentsOf: upperEntries)
        return (entries: entries, lower: lower, upper: upper)
    }
    
    func earlierEntries(_ peerIds: [PeerId], index: MessageIndex?, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(peerIds, fromBoundary: index.flatMap({ EntriesInRangeBoundary.index($0) }) ?? .upperBound, toBoundary: .lowerBound, count: count, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func earlierEntries(tagMask: MessageTags, peerIds: [PeerId], index: MessageIndex?, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(tagMask: tagMask, peerIds: peerIds, fromBoundary: index.flatMap({ EntriesInRangeBoundary.index($0) }) ?? .upperBound, toBoundary: .lowerBound, count: count, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }

    func laterEntries(_ peerIds: [PeerId], index: MessageIndex?, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(peerIds, fromBoundary: index.flatMap({ EntriesInRangeBoundary.index($0) }) ?? .lowerBound, toBoundary: .upperBound, count: count, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    func laterEntries(tagMask: MessageTags, peerIds: [PeerId], index: MessageIndex?, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        return self.entriesInRange(tagMask: tagMask, peerIds: peerIds, fromBoundary: index.flatMap({ EntriesInRangeBoundary.index($0) }) ?? .lowerBound, toBoundary: .upperBound, count: count, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
    }
    
    private func nextIndices(peerId: PeerId, fromBoundary: EntriesInRangeBoundary, toBoundary: EntriesInRangeBoundary, count: Int) -> [MessageIndex] {
        var result: [MessageIndex] = []
        
        let fromKey: ValueBoxKey
        switch fromBoundary {
            case let .index(index):
                fromKey = self.key(index.withPeerId(peerId))
            case .lowerBound:
                fromKey = self.lowerBound(peerId)
            case .upperBound:
                fromKey = self.upperBound(peerId)
        }
        
        let toKey: ValueBoxKey
        switch toBoundary {
            case let .index(index):
                toKey = self.key(index.withPeerId(peerId))
            case .lowerBound:
                toKey = self.lowerBound(peerId)
            case .upperBound:
                toKey = self.upperBound(peerId)
        }
        
        self.valueBox.range(self.table, start: fromKey, end: toKey, keys: { key in
            result.append(self.readIndex(key))
            return true
        }, limit: count)
        
        return result
    }
    
    private func entriesInRange(_ peerIds: [PeerId], fromBoundary: EntriesInRangeBoundary, toBoundary: EntriesInRangeBoundary, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        var indexOperations: [MessageHistoryIndexOperation] = []
        for peerId in peerIds {
            self.messageHistoryIndexTable.ensureInitialized(peerId, operations: &indexOperations)
            if !indexOperations.isEmpty {
                var updatedMedia: [MediaId: Media?] = [:]
                self.processIndexOperations(peerId, operations: indexOperations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
            }
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        if peerIds.count == 1 {
            let fromKey: ValueBoxKey
            switch fromBoundary {
                case let .index(index):
                    fromKey = self.key(index.withPeerId(peerIds[0]))
                case .lowerBound:
                    fromKey = self.lowerBound(peerIds[0])
                case .upperBound:
                    fromKey = self.upperBound(peerIds[0])
            }
            
            let toKey: ValueBoxKey
            switch toBoundary {
                case let .index(index):
                    toKey = self.key(index.withPeerId(peerIds[0]))
                case .lowerBound:
                    toKey = self.lowerBound(peerIds[0])
                case .upperBound:
                    toKey = self.upperBound(peerIds[0])
            }
            
            self.valueBox.range(self.table, start: fromKey, end: toKey, values: { key, value in
                entries.append(self.readIntermediateEntry(key, value: value))
                return true
            }, limit: count)
        } else if fromBoundary != toBoundary {
            var hasNoIndicesLeft = Set<PeerId>()
            var indices: [MessageIndex] = []
            for peerId in peerIds {
                if let index = self.nextIndices(peerId: peerId, fromBoundary: fromBoundary, toBoundary: toBoundary, count: 1).first {
                    indices.append(index)
                } else {
                    hasNoIndicesLeft.insert(peerId)
                }
            }

            indices.sort()
            if fromBoundary > toBoundary {
                indices.reverse()
            }
            
            var i = 0
            while i < indices.count {
                var initialBoundary: EntriesInRangeBoundary = .index(indices[i])
                let nextBoundary: EntriesInRangeBoundary
                if i == indices.count - 1 {
                    nextBoundary = toBoundary
                } else {
                    nextBoundary = .index(indices[i + 1].withPeerId(indices[i].id.peerId))
                }
                var addIndices: [MessageIndex] = []
                inner: while true {
                    let result = self.nextIndices(peerId: indices[i].id.peerId, fromBoundary: initialBoundary, toBoundary: nextBoundary, count: 16)
                    if result.isEmpty {
                        break inner
                    } else {
                        addIndices.append(contentsOf: result)
                        initialBoundary = .index(result[result.count - 1])
                    }
                    if i + addIndices.count > count {
                        break inner
                    }
                }
                if fromBoundary < toBoundary {
                    for index in addIndices {
                        assert(index > indices[i])
                        assert(EntriesInRangeBoundary.index(index) < nextBoundary)
                    }
                } else {
                    for index in addIndices {
                        assert(index < indices[i])
                        assert(EntriesInRangeBoundary.index(index) > nextBoundary)
                    }
                }
                indices.insert(contentsOf: addIndices, at: i + 1)
                
                if !hasNoIndicesLeft.contains(indices[i].id.peerId) {
                    let futureBoundary: MessageIndex = addIndices.last ?? indices[i]
                    if let index = self.nextIndices(peerId: indices[i].id.peerId, fromBoundary: .index(futureBoundary), toBoundary: toBoundary, count: 1).first {
                        if fromBoundary < toBoundary {
                            let insertionIndex = binaryInsertionIndex(indices, searchItem: index)
                            indices.insert(index, at: insertionIndex)
                        } else {
                            let insertionIndex = binaryInsertionIndexReverse(indices, searchItem: index)
                            indices.insert(index, at: insertionIndex)
                        }
                    } else {
                        hasNoIndicesLeft.insert(indices[i].id.peerId)
                    }
                }
                
                i += 1 + addIndices.count
                if i >= count {
                    break
                }
            }
            if indices.count > count {
                indices.removeLast(indices.count - count)
            }
            if fromBoundary < toBoundary {
              //  assert(indices == indices.sorted())
            } else {
               // assert(indices == indices.sorted().reversed())
            }
            
            for index in indices {
                let key = self.key(index)
                if let value = self.valueBox.get(self.table, key: key) {
                    entries.append(self.readIntermediateEntry(key, value: value))
                } else {
                    assertionFailure()
                }
            }
        }
        return entries
    }
    
    private func entriesInRange(tagMask: MessageTags, peerIds: [PeerId], fromBoundary: EntriesInRangeBoundary, toBoundary: EntriesInRangeBoundary, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        var indexOperations: [MessageHistoryIndexOperation] = []
        for peerId in peerIds {
            self.messageHistoryIndexTable.ensureInitialized(peerId, operations: &indexOperations)
            if !indexOperations.isEmpty {
                var updatedMedia: [MediaId: Media?] = [:]
                self.processIndexOperations(peerId, operations: indexOperations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
            }
        }
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for index in self.tagsTable.indicesInRange(tagMask, peerIds: peerIds, fromBoundary: fromBoundary, toBoundary: toBoundary, count: count) {
            let key = self.key(index)
            if let value = self.valueBox.get(self.table, key: key) {
                entries.append(self.readIntermediateEntry(key, value: value))
            } else {
                assertionFailure()
            }
        }
        return entries
    }
    
    func laterEntries(_ tagMask: MessageTags, peerId: PeerId, index: MessageIndex?, count: Int, operationsByPeerId: inout [PeerId: [MessageHistoryOperation]], unsentMessageOperations: inout [IntermediateMessageHistoryUnsentOperation], updatedPeerReadStateOperations: inout [PeerId: PeerReadStateSynchronizationOperation?], globalTagsOperations: inout [GlobalMessageHistoryTagsOperation], pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32], updatedMessageTagSummaries: inout [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], invalidateMessageTagSummaries: inout [InvalidatedMessageHistoryTagsSummaryEntryOperation], groupFeedOperations: inout [PeerGroupId : [GroupFeedIndexOperation]], localTagsOperations: inout [IntermediateMessageHistoryLocalTagsOperation]) -> [IntermediateMessageHistoryEntry] {
        var indexOperations: [MessageHistoryIndexOperation] = []
        self.messageHistoryIndexTable.ensureInitialized(peerId, operations: &indexOperations)
        if !indexOperations.isEmpty {
            var updatedMedia: [MediaId: Media?] = [:]
            self.processIndexOperations(peerId, operations: indexOperations, processedOperationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations)
        }
        
        let indices = self.tagsTable.laterIndices(tagMask, peerId: peerId, index: index, count: count)
        
        var entries: [IntermediateMessageHistoryEntry] = []
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.table, key: key) {
                entries.append(readIntermediateEntry(key, value: value))
            } else {
                assertionFailure()
            }
        }
        
        return entries
    }
    
    private func globalTagsIntermediateEntry(_ entry: IntermediateMessageHistoryEntry) -> IntermediateGlobalMessageTagsEntry? {
        switch entry {
            case let .Message(message):
                return .message(message)
            case .Hole:
                return nil
        }
    }
    
    func groupFeedEntriesAround(groupId: PeerGroupId, index: MessageIndex, count: Int) -> (entries: [IntermediateMessageHistoryEntry], lower: IntermediateMessageHistoryEntry?, upper: IntermediateMessageHistoryEntry?) {
        return self.groupFeedIndexTable.entriesAround(groupId: groupId, index: index, count: count, messageHistoryTable: self)
    }
    
    func groupFeedEarlierEntries(groupId: PeerGroupId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        return self.groupFeedIndexTable.earlierEntries(groupId: groupId, index: index, count: count, messageHistoryTable: self)
    }
    
    func groupFeedLaterEntries(groupId: PeerGroupId, index: MessageIndex?, count: Int) -> [IntermediateMessageHistoryEntry] {
        return self.groupFeedIndexTable.laterEntries(groupId: groupId, index: index, count: count, messageHistoryTable: self)
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
    
    func maxReadIndex(_ peerId: PeerId) -> (InternalMessageHistoryAnchorIndex, Int32)? {
        if let combinedState = self.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
            switch state.1 {
                case let .idBased(maxIncomingReadId, _, _, _, _):
                    if let anchorIndex = self.anchorIndex(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId)) {
                        return (anchorIndex, state.1.count)
                    } else {
                        return nil
                    }
                case let .indexBased(maxIncomingReadIndex, _, _, _):
                    return (.message(index: maxIncomingReadIndex, exact: true), state.1.count)
            }
        }
        return nil
    }
    
    func anchorIndex(_ messageId: MessageId) -> InternalMessageHistoryAnchorIndex? {
        let (lower, upper) = self.messageHistoryIndexTable.adjacentItems(messageId, bindUpper: false)
        if let lower = lower, case let .Hole(hole) = lower, messageId.id >= hole.min && messageId.id <= hole.maxIndex.id.id {
            return .message(index: MessageIndex(id: messageId, timestamp: lower.index.timestamp), exact: false)
        }
        if let upper = upper, case let .Hole(hole) = upper, messageId.id >= hole.min && messageId.id <= hole.maxIndex.id.id {
            return .message(index: MessageIndex(id: messageId, timestamp: upper.index.timestamp), exact: false)
        }
        
        if let lower = lower {
            return .message(index: MessageIndex(id: messageId, timestamp: lower.index.timestamp), exact: true)
        } else if let upper = upper {
            return .message(index: MessageIndex(id: messageId, timestamp: upper.index.timestamp), exact: true)
        }
        
        return .message(index: MessageIndex(id: messageId, timestamp: 1), exact: false)
    }
    
    func findMessageId(peerId: PeerId, timestamp: Int32) -> MessageId? {
        var result: MessageId?
        self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp)), end: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: Int32.max, id: Int32.max), timestamp: timestamp)), values: { key, value in
            let entry = self.readIntermediateEntry(key, value: value)
            if case .Message = entry {
                result = entry.index.id
                return false
            }
            return true
        }, limit: 0)
        return result
    }
    
    func findClosestMessageId(peerId: PeerId, timestamp: Int32) -> MessageId? {
        var result: MessageId?
        self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp)), end: self.lowerBound(peerId), values: { key, value in
            let entry = self.readIntermediateEntry(key, value: value)
            if case .Message = entry {
                result = entry.index.id
                return false
            }
            return true
        }, limit: 0)
        if result == nil {
            self.valueBox.range(self.table, start: self.key(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp)), end: self.upperBound(peerId), values: { key, value in
                let entry = self.readIntermediateEntry(key, value: value)
                if case .Message = entry {
                    result = entry.index.id
                    return false
                }
                return true
            }, limit: 0)
        }
        return result
    }
    
    func findRandomMessage(peerId: PeerId, tagMask: MessageTags, ignoreIds: ([MessageId], Set<MessageId>)) -> MessageIndex? {
        if let index = self.tagsTable.findRandomIndex(peerId: peerId, tagMask: tagMask, ignoreIds: ignoreIds, isMessage: { index in
            return self.getMessage(index) != nil
        }) {
            return self.getMessage(index).flatMap(MessageIndex.init)
        } else {
            return nil
        }
    }
    
    func incomingMessageStatsInIndices(_ peerId: PeerId, namespace: MessageId.Namespace, indices: [MessageIndex]) -> (Int, Bool) {
        var count: Int = 0
        var holes = false
        for index in indices {
            let key = self.key(index)
            if let value = self.valueBox.get(self.table, key: key) {
                let entry = self.readIntermediateEntry(key, value: value)
                if case let .Message(message) = entry {
                    if message.id.namespace == namespace && message.flags.contains(.Incoming) {
                        count += 1
                    }
                } else {
                    holes = true
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
                if case let .Message(message) = entry {
                    if message.id.namespace == namespace && message.flags.contains(.Incoming) {
                        count += 1
                        messageIds.append(message.id)
                    }
                } else {
                    holes = true
                }
                return true
            }, limit: 0)
        }
        
        return (count, holes, messageIds)
    }
    
    func outgoingMessageCountInRange(_ peerId: PeerId, namespace: MessageId.Namespace, fromIndex: MessageIndex, toIndex: MessageIndex) -> [MessageId] {
        var messageIds: [MessageId] = []
        self.valueBox.range(self.table, start: self.key(fromIndex).predecessor, end: self.key(toIndex).successor, values: { key, value in
            let entry = self.readIntermediateEntry(key, value: value)
            if case let .Message(message) = entry {
                if message.id.namespace == namespace && !message.flags.contains(.Incoming) {
                    messageIds.append(message.id)
                }
            }
            return true
        }, limit: 0)
        
        return messageIds
    }
    
    func allIndices(_ peerId: PeerId) -> (messages: [MessageIndex], holes: [MessageIndex]) {
        var messages: [MessageIndex] = []
        var holes: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.key(MessageIndex.lowerBound(peerId: peerId)).predecessor, end: self.key(MessageIndex.upperBound(peerId: peerId)).successor, values: { key, value in
            let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
            if extractIntermediateEntryIsMessage(value: value) {
                messages.append(index)
            } else {
                holes.append(index)
            }
            return true
        }, limit: 0)
        return (messages, holes)
    }
    
    func allMessageIndices(_ peerId: PeerId) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.key(MessageIndex.lowerBound(peerId: peerId)).predecessor, end: self.key(MessageIndex.upperBound(peerId: peerId)).successor, values: { key, value in
            if extractIntermediateEntryIsMessage(value: value) {
                let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
                indices.append(index)
            }
            return true
        }, limit: 0)
        return indices
    }
    
    func allIndicesWithAuthor(_ peerId: PeerId, authorId: PeerId) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.valueBox.range(self.table, start: self.key(MessageIndex.lowerBound(peerId: peerId)).predecessor, end: self.key(MessageIndex.upperBound(peerId: peerId)).successor, values: { key, value in
            if extractIntermediateEntryAuthor(value: value) == authorId {
                let index = MessageIndex(id: MessageId(peerId: PeerId(key.getInt64(0)), namespace: key.getInt32(8 + 4), id: key.getInt32(8 + 4 + 4)), timestamp: key.getInt32(8))
                indices.append(index)
            }
            return true
        }, limit: 0)
        return indices
    }
    
    func getMessageCountInRange(peerId: PeerId, tagMask: MessageTags, lowerBound: MessageIndex, upperBound: MessageIndex) -> Int32 {
        return self.tagsTable.getMessageCountInRange(tagMask: tagMask, peerId: peerId, lowerBound: lowerBound, upperBound: upperBound)
    }
    
    func setPendingMessageAction(id: MessageId, type: PendingMessageActionType, action: PendingMessageActionData?, pendingActionsOperations: inout [PendingMessageActionsOperation], updatedMessageActionsSummaries: inout [PendingMessageActionsSummaryKey: Int32]) {
        if let entry = self.messageHistoryIndexTable.getMaybeUninitialized(id), case .Message = entry {
            self.pendingActionsTable.setAction(id: id, type: type, action: action, operations: &pendingActionsOperations, updatedSummaries: &updatedMessageActionsSummaries)
        }
    }
    
    func enumerateMedia(lowerBound: MessageIndex?, limit: Int) -> ([PeerId: Set<MediaId>], [MediaId: Media], MessageIndex?) {
        var mediaRefs: [MediaId: Media] = [:]
        var result: [PeerId: Set<MediaId>] = [:]
        var lastIndex: MessageIndex?
        var count = 0
        self.valueBox.range(self.table, start: self.key(lowerBound == nil ? MessageIndex.absoluteLowerBound() : lowerBound!), end: self.key(MessageIndex.absoluteUpperBound()), values: { key, value in
            count += 1
            
            let entry = self.readIntermediateEntry(key, value: value)
            lastIndex = entry.index
            
            if case let .Message(message) = entry {
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
            }
            return true
        }, limit: limit)
        return (result, mediaRefs, count == 0 ? nil : lastIndex)
    }

    func debugList(_ peerId: PeerId, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        var operationsByPeerId: [PeerId : [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId : PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var groupFeedOperations: [PeerGroupId : [GroupFeedIndexOperation]] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        
        return self.laterEntries([peerId], index: nil, count: 1000, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations).map({ entry -> RenderedMessageHistoryEntry in
            switch entry {
                case let .Hole(hole, _):
                    return .Hole(hole)
                case let .Message(message):
                    return .RenderedMessage(self.renderMessage(message, peerTable: peerTable))
            }
        })
    }
    
    func debugList(_ tagMask: MessageTags, peerId: PeerId, peerTable: PeerTable) -> [RenderedMessageHistoryEntry] {
        var operationsByPeerId: [PeerId : [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId : PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var groupFeedOperations: [PeerGroupId: [GroupFeedIndexOperation]] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        
        return self.laterEntries(tagMask, peerId: peerId, index: nil, count: 1000, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, groupFeedOperations: &groupFeedOperations, localTagsOperations: &localTagsOperations).map({ entry -> RenderedMessageHistoryEntry in
            switch entry {
                case let .Hole(hole, _):
                    return .Hole(hole)
                case let .Message(message):
                    return .RenderedMessage(self.renderMessage(message, peerTable: peerTable))
            }
        })
    }
    
    func debugCheckTagIndexIntegrity(peerId: PeerId) {
        let tagIndices = Set(self.tagsTable.debugGetAllIndices())
        for index in tagIndices {
            if index.id.peerId != peerId {
                continue
            }
            var operations: [MessageHistoryIndexOperation] = []
            if let entry = self.messageHistoryIndexTable.getEnsureInitialized(index.id, operations: &operations) {
                switch entry {
                    case let .Hole(hole):
                        break
                    case let .Message(index):
                        if let _ = self.getMessage(index) {
                        } else {
                            assertionFailure()
                        }
                }
            } else {
                assertionFailure()
            }
        }
    }
}
