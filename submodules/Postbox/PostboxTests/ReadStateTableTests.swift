import Foundation

import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1
private let authorPeerId = PeerId(namespace: 1, id: 6)

private func ==(lhs: [Media], rhs: [Media]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    
    for i in 0 ..< lhs.count {
        if !lhs[i].isEqual(to: rhs[i]) {
            return false
        }
    }
    return true
}

private enum Entry: Equatable, CustomStringConvertible {
    case Message(Int32, Int32, String, [Media], MessageFlags)
    case Hole(Int32, Int32, Int32)
    
    var description: String {
        switch self {
        case let .Message(id, timestamp, text, media, flags):
            return "Message(\(id), \(timestamp), \(text), \(media), \(flags))"
        case let .Hole(min, max, timestamp):
            return "Hole(\(min), \(max), \(timestamp))"
        }
    }
}

private func ==(lhs: Entry, rhs: Entry) -> Bool {
    switch lhs {
    case let .Message(lhsId, lhsTimestamp, lhsText, lhsMedia, lhsFlags):
        switch rhs {
        case let .Message(rhsId, rhsTimestamp, rhsText, rhsMedia, rhsFlags):
            return lhsId == rhsId && lhsTimestamp == rhsTimestamp && lhsText == rhsText && lhsMedia == rhsMedia && lhsFlags == rhsFlags
        case .Hole:
            return false
        }
    case let .Hole(lhsMin, lhsMax, lhsMaxTimestamp):
        switch rhs {
        case .Message:
            return false
        case let .Hole(rhsMin, rhsMax, rhsMaxTimestamp):
            return lhsMin == rhsMin && lhsMax == rhsMax && lhsMaxTimestamp == rhsMaxTimestamp
        }
    }
}

private extension MessageTags {
    static let First = MessageTags(rawValue: 1 << 0)
    static let Second = MessageTags(rawValue: 1 << 1)
}

class ReadStateTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var peerTable: PeerTable?
    var globalMessageIdsTable: GlobalMessageIdsTable?
    var indexTable: MessageHistoryIndexTable?
    var mediaTable: MessageMediaTable?
    var historyTable: MessageHistoryTable?
    var historyMetadataTable: MessageHistoryMetadataTable?
    var unsentTable: MessageHistoryUnsentTable?
    var tagsTable: MessageHistoryTagsTable?
    var readStateTable: MessageHistoryReadStateTable?
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable?
    var globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable?
    var globalTagsTable: GlobalMessageHistoryTagsTable?
    var localTagsTable: LocalMessageHistoryTagsTable?
    var textIndexTable: MessageHistoryTextIndexTable?
    var messageHistoryTagsSummaryTable: MessageHistoryTagsSummaryTable?
    var invalidatedMessageHistoryTagsSummaryTable: InvalidatedMessageHistoryTagsSummaryTable?
    var pendingMessageActionsTable: PendingMessageActionsTable?
    var pendingMessageActionsMetadataTable: PendingMessageActionsMetadataTable?
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHole: (topLevel: nil, groups: nil), initializeMessageNamespacesWithHoles: [], existingMessageTags: [.First, .Second], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil, chatMessagesNamespaces: Set())
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, table: GlobalMessageIdsTable.tableSpec(5), namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, table: MessageHistoryMetadataTable.tableSpec(7))
        self.unsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox!, table: MessageHistoryUnsentTable.tableSpec(8))
        self.invalidatedMessageHistoryTagsSummaryTable = InvalidatedMessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(18))
        self.messageHistoryTagsSummaryTable = MessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(15), invalidateTable: self.invalidatedMessageHistoryTagsSummaryTable!)
        self.pendingMessageActionsMetadataTable = PendingMessageActionsMetadataTable(valueBox: self.valueBox!, table: PendingMessageActionsMetadataTable.tableSpec(16))
        self.pendingMessageActionsTable = PendingMessageActionsTable(valueBox: self.valueBox!, table: PendingMessageActionsTable.tableSpec(17), metadataTable: self.pendingMessageActionsMetadataTable!)
        self.tagsTable = MessageHistoryTagsTable(valueBox: self.valueBox!, table: MessageHistoryTagsTable.tableSpec(9), seedConfiguration: seedConfiguration, summaryTable: self.messageHistoryTagsSummaryTable!)
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, table: MessageHistoryIndexTable.tableSpec(1), globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, table: MessageMediaTable.tableSpec(2))
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox!, table: MessageHistoryReadStateTable.tableSpec(10))
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox!, table: MessageHistorySynchronizeReadStateTable.tableSpec(11))
        self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox!, table: MessageGloballyUniqueIdTable.tableSpec(12))
        self.globalTagsTable = GlobalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(13))
        self.localTagsTable = LocalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(19))
        self.textIndexTable = MessageHistoryTextIndexTable(valueBox: self.valueBox!, table: MessageHistoryTextIndexTable.tableSpec(14))
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, table: MessageHistoryTable.tableSpec(4), messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!, historyMetadataTable: self.historyMetadataTable!, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable!, unsentTable: self.unsentTable!, tagsTable: self.tagsTable!, globalTagsTable: self.globalTagsTable!, localTagsTable: self.localTagsTable!, readStateTable: self.readStateTable!, synchronizeReadStateTable: self.synchronizeReadStateTable!, textIndexTable: self.textIndexTable!, summaryTable: self.messageHistoryTagsSummaryTable!, pendingActionsTable: self.pendingMessageActionsTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.peerTable = nil
        self.historyMetadataTable = nil
        
        self.valueBox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    private func addMessage(_ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags = [], _ tags: MessageTags = []) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        var updatedMedia: [MediaId : Media?] = [:]
        
        let _ = self.historyTable!.addMessages(messages: [StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: nil, timestamp: timestamp, flags: flags, tags: tags, globalTags: [], localTags: [], forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations, processMessages: nil)
    }
    
    private func updateMessage(_ previousId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags, _ tags: MessageTags) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.updateMessage(MessageId(peerId: peerId, namespace: namespace, id: previousId), message: StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: nil, timestamp: timestamp, flags: flags, tags: tags, globalTags: [], localTags: [], forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media), operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
    }
    
    private func addHole(_ id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.addHoles([MessageId(peerId: peerId, namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
    }
    
    private func removeMessages(_ ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        var updatedMedia: [MediaId : Media?] = [:]
        
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: peerId, namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId, updatedMedia: &updatedMedia, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations, globalTagsOperations: &globalTagsOperations, pendingActionsOperations: &pendingActionsOperations, updatedMessageActionsSummaries: &updatedMessageActionsSummaries, updatedMessageTagSummaries: &updatedMessageTagSummaries, invalidateMessageTagSummaries: &invalidateMessageTagSummaries, localTagsOperations: &localTagsOperations)
    }
    
    private func expectApplyRead(_ messageId: Int32, _ expectInvalidate: Bool) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.applyIncomingReadMaxId(MessageId(peerId: peerId, namespace: namespace, id: messageId), operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        let invalidated = updatedPeerReadStateOperations.count != 0
        if expectInvalidate != invalidated {
            XCTFail("applyRead: invalidated expected \(expectInvalidate), actual: \(invalidated)")
        }
    }
    
    private func expectReadState(_ maxReadId: Int32, _ maxKnownId: Int32, _ count: Int32, _ markedUnread: Bool) {
        if let state = self.readStateTable!.getCombinedState(peerId)?.states.first?.1 {
            switch state {
                case let .idBased(maxIncomingReadId, maxOutgoingReadId, stateMaxKnownId, stateCount, stateMarkedUnread):
                    if maxIncomingReadId != maxReadId || stateMaxKnownId != maxKnownId || stateCount != count || stateMarkedUnread != markedUnread {
                        XCTFail("Expected\nmaxIncomingReadId: \(maxReadId), maxKnownId: \(maxKnownId), count: \(count) markedUnread: \(markedUnread)\nActual\nmaxIncomingReadId: \(maxIncomingReadId), maxKnownId: \(stateMaxKnownId), count: \(stateCount), markedUnread: \(stateMarkedUnread)")
                    }
                case .indexBased:
                    XCTFail()
            }
        } else {
            XCTFail("Expected\nmaxReadId: \(maxReadId), maxKnownId: \(maxKnownId), count: \(count)\nActual\nnil")
        }
    }
    
    func testResetState() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 120, count: 130, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        expectReadState(100, 120, 130, false)
    }
    
    func testAddIncomingBeforeKnown() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 120, count: 130, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(99, 99, "", [], [.Incoming])
        
        expectReadState(100, 120, 130, false)
    }
    
    func testAddIncomingAfterKnown() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 120, count: 130, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(100, 120, 131, false)
    }
    
    func testApplyReadThenAddIncoming() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 100, count: 0, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.expectApplyRead(200, false)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(200, 100, 0, false)
    }
    
    func testApplyAddIncomingThenRead() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 100, count: 0, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(100, 100, 1, false)
        
        self.expectApplyRead(200, false)
        
        expectReadState(200, 100, 0, false)
    }
    
    func testIgnoreOldRead() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 100, count: 0, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.expectApplyRead(90, false)
        
        expectReadState(100, 100, 0, false)
    }
    
    func testInvalidateReadHole() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: .idBased(maxIncomingReadId: 100, maxOutgoingReadId: 0, maxKnownId: 100, count: 0, markedUnread: false)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(200, 200)
        self.addHole(1)
        
        self.expectApplyRead(200, true)
        
        expectReadState(200, 100, 0, false)
    }
}
