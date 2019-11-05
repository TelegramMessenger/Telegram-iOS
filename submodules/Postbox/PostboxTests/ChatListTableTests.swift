import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let namespace: Int32 = 1

private let authorPeerId = PeerId(namespace: 2, id: 3)

private enum Entry: Equatable, CustomStringConvertible {
    case Message(Int32, Int32, Int32, Bool)
    case Hole(Int32, Int32, Int32)
    case GroupReference(PeerGroupId, Int32, Int32, Int32)
    
    var description: String {
        switch self {
            case let .Message(peerId, id, timestamp, exists):
                return "Message(\(peerId), \(id), \(timestamp), \(exists))"
            case let .Hole(peerId, id, timestamp):
                return "Hole(\(peerId), \(id), \(timestamp))"
            case let .GroupReference(groupId, peerId, id, timestamp):
                return "GroupReference(\(groupId), \(peerId), \(id), \(timestamp))"
        }
    }
}

private func ==(lhs: Entry, rhs: Entry) -> Bool {
    switch lhs {
        case let .Message(lhsPeerId, lhsId, lhsTimestamp, lhsExists):
            switch rhs {
                case let .Message(rhsPeerId, rhsId, rhsTimestamp, rhsExists):
                    return lhsPeerId == rhsPeerId && lhsId == rhsId && lhsTimestamp == rhsTimestamp && lhsExists == rhsExists
                case .Hole, .GroupReference:
                    return false
            }
        case let .Hole(lhsPeerId, lhsId, lhsTimestamp):
            switch rhs {
                case .Message, .GroupReference:
                    return false
                case let .Hole(rhsPeerId, rhsId, rhsTimestamp):
                    return lhsPeerId == rhsPeerId && lhsId == rhsId && lhsTimestamp == rhsTimestamp
            }
        case let .GroupReference(lhsGroupId, lhsPeerId, lhsId, lhsTimestamp):
            switch rhs {
                case .GroupReference(lhsGroupId, lhsPeerId, lhsId, lhsTimestamp):
                    return true
                default:
                    return false
            }
    }
}

class ChatListTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var globalMessageIdsTable: GlobalMessageIdsTable?
    var indexTable: MessageHistoryIndexTable?
    var mediaTable: MessageMediaTable?
    var historyTable: MessageHistoryTable?
    var chatListIndexTable: ChatListIndexTable?
    var chatListTable: ChatListTable?
    var historyMetadataTable: MessageHistoryMetadataTable?
    var unsentTable: MessageHistoryUnsentTable?
    var tagsTable: MessageHistoryTagsTable?
    var readStateTable: MessageHistoryReadStateTable?
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable?
    var peerChatInterfaceStateTable: PeerChatInterfaceStateTable?
    var peerTable: PeerTable?
    var peerNameTokenIndexTable: ReverseIndexReferenceTable<PeerIdReverseIndexReference>?
    var peerNameIndexTable: PeerNameIndexTable?
    var notificationSettingsTable: PeerNotificationSettingsTable?
    var globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable?
    var globalTagsTable: GlobalMessageHistoryTagsTable?
    var localTagsTable: LocalMessageHistoryTagsTable?
    var reverseAssociatedTable: ReverseAssociatedPeerTable?
    var textIndexTable: MessageHistoryTextIndexTable?
    var messageHistoryTagsSummaryTable: MessageHistoryTagsSummaryTable?
    var invalidatedMessageHistoryTagsSummaryTable: InvalidatedMessageHistoryTagsSummaryTable?
    var pendingMessageActionsTable: PendingMessageActionsTable?
    var pendingMessageActionsMetadataTable: PendingMessageActionsMetadataTable?
    var pendingPeerNotificationSettingsIndexTable: PendingPeerNotificationSettingsIndexTable?
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHole: (topLevel: nil, groups: nil), initializeMessageNamespacesWithHoles: [], existingMessageTags: [], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil, chatMessagesNamespaces: Set())
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, table: GlobalMessageIdsTable.tableSpec(7), namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, table: MessageHistoryMetadataTable.tableSpec(8))
        self.unsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox!, table: MessageHistoryUnsentTable.tableSpec(9))
        self.invalidatedMessageHistoryTagsSummaryTable = InvalidatedMessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(31))
        self.messageHistoryTagsSummaryTable = MessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(28), invalidateTable: self.invalidatedMessageHistoryTagsSummaryTable!)
        self.pendingMessageActionsMetadataTable = PendingMessageActionsMetadataTable(valueBox: self.valueBox!, table: PendingMessageActionsMetadataTable.tableSpec(29))
        self.pendingMessageActionsTable = PendingMessageActionsTable(valueBox: self.valueBox!, table: PendingMessageActionsTable.tableSpec(30), metadataTable: self.pendingMessageActionsMetadataTable!)
        self.tagsTable = MessageHistoryTagsTable(valueBox: self.valueBox!, table: MessageHistoryTagsTable.tableSpec(10), seedConfiguration: seedConfiguration, summaryTable: self.messageHistoryTagsSummaryTable!)
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, table: MessageHistoryIndexTable.tableSpec(1), globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, table: MessageMediaTable.tableSpec(2))
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox!, table: MessageHistoryReadStateTable.tableSpec(11))
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox!, table: MessageHistorySynchronizeReadStateTable.tableSpec(12))
        self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox!, table: MessageGloballyUniqueIdTable.tableSpec(24))
        self.globalTagsTable = GlobalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(25))
        self.localTagsTable = LocalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(35))
        self.textIndexTable = MessageHistoryTextIndexTable(valueBox: self.valueBox!, table: MessageHistoryTextIndexTable.tableSpec(27))
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, table: MessageHistoryTable.tableSpec(4), messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!, historyMetadataTable: self.historyMetadataTable!, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable!, unsentTable: self.unsentTable!, tagsTable: self.tagsTable!, globalTagsTable: self.globalTagsTable!, localTagsTable: self.localTagsTable!, readStateTable: self.readStateTable!, synchronizeReadStateTable: self.synchronizeReadStateTable!, textIndexTable: self.textIndexTable!, summaryTable: self.messageHistoryTagsSummaryTable!, pendingActionsTable: self.pendingMessageActionsTable!)
        self.reverseAssociatedTable = ReverseAssociatedPeerTable(valueBox: self.valueBox!, table: ReverseAssociatedPeerTable.tableSpec(26))
        self.peerTable = PeerTable(valueBox: self.valueBox!, table: PeerTable.tableSpec(20), reverseAssociatedTable: self.reverseAssociatedTable!)
        self.peerNameTokenIndexTable = ReverseIndexReferenceTable<PeerIdReverseIndexReference>(valueBox: self.valueBox!, table: ReverseIndexReferenceTable<PeerIdReverseIndexReference>.tableSpec(21))
        self.peerNameIndexTable = PeerNameIndexTable(valueBox: self.valueBox!, table: PeerNameIndexTable.tableSpec(22), peerTable: self.peerTable!, peerNameTokenIndexTable: self.peerNameTokenIndexTable!)
        self.pendingPeerNotificationSettingsIndexTable = PendingPeerNotificationSettingsIndexTable(valueBox: self.valueBox!, table: PeerNotificationSettingsTable.tableSpec(32))
        self.notificationSettingsTable = PeerNotificationSettingsTable(valueBox: self.valueBox!, table: PeerNotificationSettingsTable.tableSpec(23), pendingIndexTable: self.pendingPeerNotificationSettingsIndexTable!)
        self.chatListIndexTable = ChatListIndexTable(valueBox: self.valueBox!, table: ChatListIndexTable.tableSpec(5), peerNameIndexTable: self.peerNameIndexTable!, metadataTable: self.historyMetadataTable!, readStateTable: self.readStateTable!, notificationSettingsTable: self.notificationSettingsTable!)
        self.chatListTable = ChatListTable(valueBox: self.valueBox!, table: ChatListTable.tableSpec(6), indexTable: self.chatListIndexTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.peerChatInterfaceStateTable = PeerChatInterfaceStateTable(valueBox: self.valueBox!, table: PeerChatInterfaceStateTable.tableSpec(20))
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.chatListIndexTable = nil
        self.chatListTable = nil
        
        self.valueBox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    private func addMessage(_ peerId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ groupingKey: Int64? = nil) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        let initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        var updatedMedia: [MediaId : Media?] = [:]
        
        let _ = self.historyTable!.addMessages(messages: [StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: groupingKey, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, processMessages: nil)
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
        var updatedTotalUnreadState: ChatListTotalUnreadState?
        self.chatListIndexTable?.commitWithTransaction(postbox: postbox, alteredInitialPeerCombinedReadStates: [:], updatedPeers: [], transactionParticipationInTotalUnreadCountUpdates: (added: Set(), removed: Set()), updatedTotalUnreadState: &updatedTotalUnreadState)
        self.chatListIndexTable?.clearMemoryCache()
    }
    
    private func updateInclusion(_ peerId: Int32, f: (PeerChatListInclusion) -> PeerChatListInclusion) {
        var updatedChatListInclusions: [PeerId: PeerChatListInclusion] = [:]
        self.chatListTable!.updateInclusion(peerId: PeerId(namespace: namespace, id: peerId), updatedChatListInclusions: &updatedChatListInclusions, f)
        
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        let initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        
        self.chatListTable!.replay(historyOperationsByPeerId: [:], updatedPeerChatListEmbeddedStates: [:], updatedChatListInclusions: updatedChatListInclusions, updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
        var updatedTotalUnreadState: ChatListTotalUnreadState?
        self.chatListIndexTable?.commitWithTransaction(alteredInitialPeerCombinedReadStates: [:], transactionParticipationInTotalUnreadCountUpdates: (added: Set(), removed: Set()), getCombinedPeerReadState: { peerId -> CombinedPeerReadState? in
            self.readStateTable?.getCombinedState(peerId)
        }, getPeer: { _ in
            return nil
        }, updatedTotalUnreadState: &updatedTotalUnreadState)
        self.chatListIndexTable?.clearMemoryCache()
    }
    
    private func updatePeerGroup(_ peerId: Int32, _ groupId: PeerGroupId?) {
        var initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        self.groupAssociationTable!.set(peerId: PeerId(namespace: namespace, id: peerId), groupId: groupId, initialPeerGroupIdsBeforeUpdate: &initialPeerGroupIdsBeforeUpdate)
        
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        
        self.chatListTable!.replay(historyOperationsByPeerId: [:], updatedPeerChatListEmbeddedStates: [:], updatedChatListInclusions: [:], updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
        var updatedTotalUnreadState: ChatListTotalUnreadState?
        self.chatListIndexTable?.commitWithTransaction(alteredInitialPeerCombinedReadStates: [:], transactionParticipationInTotalUnreadCountUpdates: (added: Set(), removed: Set()), getCombinedPeerReadState: { peerId -> CombinedPeerReadState? in
            self.readStateTable?.getCombinedState(peerId)
        }, getPeer: { _ in
            return nil
        }, updatedTotalUnreadState: &updatedTotalUnreadState)
        self.chatListIndexTable?.clearMemoryCache()
    }
    
    private func addHole(_ peerId: Int32, _ id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        let initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.addHoles([MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func addChatListHole(groupId: PeerGroupId?, peerId: Int32, id: Int32, timestamp: Int32) {
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.addHole(groupId: groupId, hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp)), operations: &operations)
    }
    
    private func replaceChatListHole(groupId: PeerGroupId?, peerId: Int32, id: Int32, timestamp: Int32, otherPeerId: Int32, otherId: Int32, otherTimestamp: Int32) {
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replaceHole(groupId: groupId, index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp), hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: otherPeerId), namespace: namespace, id: otherId), timestamp: otherTimestamp)), operations: &operations)
    }
    
    private func removeChatListHole(groupId: PeerGroupId?, peerId: Int32, id: Int32, timestamp: Int32) {
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replaceHole(groupId: groupId, index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp), hole: nil, operations: &operations)
    }
    
    private func removeMessages(_ peerId: Int32, _ ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        let initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func fillHole(_ peerId: Int32, _ id: Int32, _ fillType: HoleFill, _ messages: [(Int32, Int32, String, [Media], Int64?)]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        let initialPeerGroupIdsBeforeUpdate: [PeerId: WrappedPeerGroupId] = [:]
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        let updatedChatListGroupInclusions: [PeerGroupId: GroupChatListInclusion] = [:]
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.fillHole(MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), fillType: fillType, tagMask: nil, messages: messages.map({ StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0.0), globallyUniqueId: nil, groupingKey: $0.4, timestamp: $0.1, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorPeerId, text: $0.2, attributes: [], media: $0.3) }), operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
        var operations: [WrappedPeerGroupId: [ChatListOperation]] = [:]
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], updatedChatListGroupInclusions: updatedChatListGroupInclusions, initialPeerGroupIdsBeforeUpdate: initialPeerGroupIdsBeforeUpdate, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func expectEntries(groupId: PeerGroupId?, entries: [Entry]) {
        let actualEntries = self.chatListTable!.debugList(groupId: groupId, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!).map({ entry -> Entry in
            switch entry {
                case let .message(index, message, _):
                    if let message = message, message.authorId != authorPeerId {
                        XCTFail("Expected authorId \(authorPeerId), actual \(String(describing: message.authorId))")
                    }
                    return .Message(index.messageIndex.id.peerId.id, index.messageIndex.id.id, index.messageIndex.timestamp, message != nil)
                case let .hole(hole):
                    return .Hole(hole.index.id.peerId.id, hole.index.id.id, hole.index.timestamp)
                case let .groupReference(groupId, index):
                    return .GroupReference(groupId, index.messageIndex.id.peerId.id, index.messageIndex.id.id, index.messageIndex.timestamp)
            }
        })
        if entries != actualEntries {
            XCTFail("Expected\n\(entries)\nActual\n\(actualEntries)")
        }
    }
    
    func testEmpty() {
        expectEntries(groupId: nil, entries: [])
    }
    
    func testAddSingleMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true)])
    }
    
    func testInsertLaterMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(1, 200, 200)
        expectEntries(groupId: nil, entries: [.Message(1, 200, 200, true)])
    }
    
    func testInsertEarlierMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(1, 10, 20)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true)])
    }
    
    func testInsertTwoChatMessages() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(2, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(2, 10, 20)
        expectEntries(groupId: nil, entries: [.Message(2, 10, 20, true), .Message(1, 100, 100, true)])
    }
    
    func testMoveChatUpper() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(2, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(2, 10, 20)
        addMessage(2, 120, 120)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true), .Message(2, 120, 120, true)])
    }
    
    func testRemoveSingleMessageInclusionIfHasMessages() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        expectEntries(groupId: nil, entries: [])
    }
    
    func testAddSingleMessageInclusionNever() {
        addMessage(1, 100, 100)
        expectEntries(groupId: nil, entries: [])
    }
    
    func testEmptyWithInclusionMinIndex() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 50)
        })
        expectEntries(groupId: nil, entries: [.Message(1, 0, 50, false)])
        addMessage(1, 20, 20)
        expectEntries(groupId: nil, entries: [.Message(1, 0, 50, true)])
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        expectEntries(groupId: nil, entries: [.Message(1, 20, 20, true)])
    }
    
    func testEmptyWithInclusionPinningIndex() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: 0, minTimestamp: nil)
        })
        expectEntries(groupId: nil, entries: [.Message(1, 0, 0, false)])
    }
    
    func testRemoveSingleMessageInclusionWithMinIndexUpdate() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 50)
        })
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        expectEntries(groupId: nil, entries: [.Message(1, 0, 50, false)])
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 200)
        })
        expectEntries(groupId: nil, entries: [.Message(1, 0, 200, false)])
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        expectEntries(groupId: nil, entries: [])
        addMessage(1, 200, 200)
        expectEntries(groupId: nil, entries: [.Message(1, 200, 200, true)])
    }
    
    func testOverrideNothing() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        addMessage(1, 100, 100)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true)])
    }
    
    func testInsertHoleIntoEmpty() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(groupId: nil, peerId: 1, id: 10, timestamp: 10)
        expectEntries(groupId: nil, entries: [.Hole(1, 10, 10)])
    }
    
    func testInsertHoleLower() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addChatListHole(groupId: nil, peerId: 1, id: 10, timestamp: 10)
        expectEntries(groupId: nil, entries: [.Hole(1, 10, 10), .Message(1, 100, 100, true)])
    }
    
    func testInsertHoleUpper() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addChatListHole(groupId: nil, peerId: 1, id: 200, timestamp: 200)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true), .Hole(1, 200, 200)])
    }
    
    func testIgnoreRemoveHole() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(groupId: nil, peerId: 1, id: 100, timestamp: 100)
        removeMessages(1, [100])
        expectEntries(groupId: nil, entries: [.Hole(1, 100, 100)])
        
        addMessage(1, 100, 100)
        expectEntries(groupId: nil, entries: [.Message(1, 100, 100, true), .Hole(1, 100, 100)])
        
        removeMessages(1, [100])
        expectEntries(groupId: nil, entries: [.Hole(1, 100, 100)])
        
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 100)
        })
        expectEntries(groupId: nil, entries: [.Message(1, 0, 100, false), .Hole(1, 100, 100)])
    }
    
    func testReplaceHoleWithHole() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(2, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(groupId: nil, peerId: 1, id: 100, timestamp: 100)
        replaceChatListHole(groupId: nil, peerId: 1, id: 100, timestamp: 100, otherPeerId: 2, otherId: 200, otherTimestamp: 200)
        expectEntries(groupId: nil, entries: [.Hole(2, 200, 200)])
    }
    
    func testReplaceHoleWithNone() {
        addChatListHole(groupId: nil, peerId: 1, id: 100, timestamp: 100)
        removeChatListHole(groupId: nil, peerId: 1, id: 100, timestamp: 100)
        expectEntries(groupId: nil, entries: [])
    }
    
    func testInclusionUpdate() {
        addMessage(1, 100, 100)
        addMessage(1, 200, 200)
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 1)
        })
        addMessage(1, 300, 300)
        expectEntries(groupId: nil, entries: [.Message(1, 300, 300, true)])
    }
    
    func testGroup1() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(2, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(3, f: { _ in
            return .ifHasMessages
        })
        
        updatePeerGroup(1, PeerGroupId(rawValue: 1))
        updatePeerGroup(2, PeerGroupId(rawValue: 2))
        addMessage(1, 100, 100)
        addMessage(1, 200, 200)
        addMessage(2, 110, 100)
        addMessage(3, 220, 200)
        expectEntries(groupId: PeerGroupId(rawValue: 1), entries: [
            .Message(1, 200, 200, true)
        ])
        expectEntries(groupId: PeerGroupId(rawValue: 2), entries: [
            .Message(2, 110, 100, true)
        ])
        expectEntries(groupId: nil, entries: [
            .GroupReference(PeerGroupId(rawValue: 2), 2, 110, 100),
            .GroupReference(PeerGroupId(rawValue: 1), 1, 200, 200),
            .Message(3, 220, 200, true)
        ])
        removeMessages(1, [200])
        expectEntries(groupId: PeerGroupId(rawValue: 1), entries: [
            .Message(1, 100, 100, true)
        ])
        expectEntries(groupId: PeerGroupId(rawValue: 2), entries: [
            .Message(2, 110, 100, true)
        ])
        expectEntries(groupId: nil, entries: [
            .GroupReference(PeerGroupId(rawValue: 1), 1, 100, 100),
            .GroupReference(PeerGroupId(rawValue: 2), 2, 110, 100),
            .Message(3, 220, 200, true)
        ])
        
        updatePeerGroup(1, nil)
        expectEntries(groupId: PeerGroupId(rawValue: 1), entries: [])
        expectEntries(groupId: PeerGroupId(rawValue: 2), entries: [
            .Message(2, 110, 100, true)
        ])
        expectEntries(groupId: nil, entries: [
            .Message(1, 100, 100, true),
            .GroupReference(PeerGroupId(rawValue: 2), 2, 110, 100),
            .Message(3, 220, 200, true)
        ])
        removeMessages(2, [110])
        expectEntries(groupId: nil, entries: [
            .Message(1, 100, 100, true),
            .Message(3, 220, 200, true)
        ])
        addMessage(2, 110, 100)
        expectEntries(groupId: nil, entries: [
            .Message(1, 100, 100, true),
            .GroupReference(PeerGroupId(rawValue: 2), 2, 110, 100),
            .Message(3, 220, 200, true)
        ])
    }
}
