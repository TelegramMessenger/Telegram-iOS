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
    
    var description: String {
        switch self {
            case let .Message(peerId, id, timestamp, exists):
                return "Message(\(peerId), \(id), \(timestamp), \(exists))"
            case let .Hole(peerId, id, timestamp):
                return "Hole(\(peerId), \(id), \(timestamp))"
        }
    }
}

private func ==(lhs: Entry, rhs: Entry) -> Bool {
    switch lhs {
        case let .Message(lhsPeerId, lhsId, lhsTimestamp, lhsExists):
            switch rhs {
                case let .Message(rhsPeerId, rhsId, rhsTimestamp, rhsExists):
                    return lhsPeerId == rhsPeerId && lhsId == rhsId && lhsTimestamp == rhsTimestamp && lhsExists == rhsExists
                case .Hole:
                    return false
            }
        case let .Hole(lhsPeerId, lhsId, lhsTimestamp):
            switch rhs {
                case .Message:
                    return false
                case let .Hole(rhsPeerId, rhsId, rhsTimestamp):
                    return lhsPeerId == rhsPeerId && lhsId == rhsId && lhsTimestamp == rhsTimestamp
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
    var peerNameTokenIndexTable: PeerNameTokenIndexTable?
    var peerNameIndexTable: PeerNameIndexTable?
    var notificationSettingsTable: PeerNotificationSettingsTable?
    var globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable?
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHoles: [], initializeMessageNamespacesWithHoles: [], existingMessageTags: [])
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, table: GlobalMessageIdsTable.tableSpec(7), namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, table: MessageHistoryMetadataTable.tableSpec(8))
        self.unsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox!, table: MessageHistoryUnsentTable.tableSpec(9))
        self.tagsTable = MessageHistoryTagsTable(valueBox: self.valueBox!, table: MessageHistoryTagsTable.tableSpec(10))
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, table: MessageHistoryIndexTable.tableSpec(1), globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, table: MessageMediaTable.tableSpec(2))
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox!, table: MessageHistoryReadStateTable.tableSpec(11))
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox!, table: MessageHistorySynchronizeReadStateTable.tableSpec(12))
        self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox!, table: MessageGloballyUniqueIdTable.tableSpec(24))
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, table: MessageHistoryTable.tableSpec(4), messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!, historyMetadataTable: self.historyMetadataTable!, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable!, unsentTable: self.unsentTable!, tagsTable: self.tagsTable!, readStateTable: self.readStateTable!, synchronizeReadStateTable: self.synchronizeReadStateTable!)
        self.peerTable = PeerTable(valueBox: self.valueBox!, table: PeerTable.tableSpec(20))
        self.peerNameTokenIndexTable = PeerNameTokenIndexTable(valueBox: self.valueBox!, table: PeerNameTokenIndexTable.tableSpec(21))
        self.peerNameIndexTable = PeerNameIndexTable(valueBox: self.valueBox!, table: PeerNameIndexTable.tableSpec(22), peerTable: self.peerTable!, peerNameTokenIndexTable: self.peerNameTokenIndexTable!)
        self.notificationSettingsTable = PeerNotificationSettingsTable(valueBox: self.valueBox!, table: PeerNotificationSettingsTable.tableSpec(23))
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
    
    private func addMessage(_ peerId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = []) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        self.historyTable!.addMessages([StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), globallyUniqueId: nil, timestamp: timestamp, flags: [], tags: [], forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
        var updatedTotalUnreadCount: Int32?
        self.chatListIndexTable?.commitWithTransactionUnreadCountDeltas([:], transactionParticipationInTotalUnreadCountUpdates: ([], []), getPeer: { _ in
            return nil
        }, updatedTotalUnreadCount: &updatedTotalUnreadCount)
        self.chatListIndexTable?.clearMemoryCache()
    }
    
    private func updateInclusion(_ peerId: Int32, f: (PeerChatListInclusion) -> PeerChatListInclusion) {
        var updatedChatListInclusions: [PeerId: PeerChatListInclusion] = [:]
        self.chatListTable!.updateInclusion(peerId: PeerId(namespace: namespace, id: peerId), updatedChatListInclusions: &updatedChatListInclusions, f)
        
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        
        var operations: [ChatListOperation] = []
        
        self.chatListTable!.replay(historyOperationsByPeerId: [:], updatedPeerChatListEmbeddedStates: [:], updatedChatListInclusions: updatedChatListInclusions, messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
        var updatedTotalUnreadCount: Int32?
        self.chatListIndexTable?.commitWithTransactionUnreadCountDeltas([:], transactionParticipationInTotalUnreadCountUpdates: ([], []), getPeer: { _ in
            return nil
        }, updatedTotalUnreadCount: &updatedTotalUnreadCount)
        self.chatListIndexTable?.clearMemoryCache()
    }
    
    private func addHole(_ peerId: Int32, _ id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        self.historyTable!.addHoles([MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func addChatListHole(_ peerId: Int32, _ id: Int32, _ timestamp: Int32) {
        var operations: [ChatListOperation] = []
        self.chatListTable!.addHole(ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp)), operations: &operations)
    }
    
    private func replaceChatListHole(_ peerId: Int32, _ id: Int32, _ timestamp: Int32, _ otherPeerId: Int32, _ otherId: Int32, _ otherTimestamp: Int32) {
        var operations: [ChatListOperation] = []
        self.chatListTable!.replaceHole(MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp), hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: otherPeerId), namespace: namespace, id: otherId), timestamp: otherTimestamp)), operations: &operations)
    }
    
    private func removeChatListHole(_ peerId: Int32, _ id: Int32, _ timestamp: Int32) {
        var operations: [ChatListOperation] = []
        self.chatListTable!.replaceHole(MessageIndex(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp), hole: nil, operations: &operations)
    }
    
    private func removeMessages(_ peerId: Int32, _ ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func fillHole(_ peerId: Int32, _ id: Int32, _ fillType: HoleFill, _ messages: [(Int32, Int32, String, [Media])]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        let updatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
        self.historyTable!.fillHole(MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), fillType: fillType, tagMask: nil, messages: messages.map({ StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0.0), globallyUniqueId: nil, timestamp: $0.1, flags: [], tags: [], forwardInfo: nil, authorId: authorPeerId, text: $0.2, attributes: [], media: $0.3) }), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(historyOperationsByPeerId: operationsByPeerId, updatedPeerChatListEmbeddedStates: updatedPeerChatListEmbeddedStates, updatedChatListInclusions: [:], messageHistoryTable: self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!, operations: &operations)
    }
    
    private func expectEntries(_ entries: [Entry]) {
        let actualEntries = self.chatListTable!.debugList(self.historyTable!, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable!).map({ entry -> Entry in
            switch entry {
                case let .Message(index, message, _):
                    if let message = message, message.authorId != authorPeerId {
                        XCTFail("Expected authorId \(authorPeerId), actual \(String(describing: message.authorId))")
                    }
                    return .Message(index.messageIndex.id.peerId.id, index.messageIndex.id.id, index.messageIndex.timestamp, message != nil)
                case let .Hole(hole):
                    return .Hole(hole.index.id.peerId.id, hole.index.id.id, hole.index.timestamp)
            }
        })
        if entries != actualEntries {
            XCTFail("Expected\n\(entries)\nActual\n\(actualEntries)")
        }
    }
    
    func testEmpty() {
        expectEntries([])
    }
    
    func testAddSingleMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        expectEntries([.Message(1, 100, 100, true)])
    }
    
    func testInsertLaterMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(1, 200, 200)
        expectEntries([.Message(1, 200, 200, true)])
    }
    
    func testInsertEarlierMessage() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addMessage(1, 10, 20)
        expectEntries([.Message(1, 100, 100, true)])
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
        expectEntries([.Message(2, 10, 20, true), .Message(1, 100, 100, true)])
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
        expectEntries([.Message(1, 100, 100, true), .Message(2, 120, 120, true)])
    }
    
    func testRemoveSingleMessageInclusionIfHasMessages() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        expectEntries([])
        //expectEntries([.Message(1, 100, 100, false)])
    }
    
    func testAddSingleMessageInclusionNever() {
        addMessage(1, 100, 100)
        expectEntries([])
    }
    
    func testEmptyWithInclusionMinIndex() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 50)
        })
        expectEntries([.Message(1, 0, 50, false)])
        addMessage(1, 20, 20)
        expectEntries([.Message(1, 0, 50, true)])
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        expectEntries([.Message(1, 20, 20, true)])
    }
    
    func testEmptyWithInclusionPinningIndex() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: 0, minTimestamp: nil)
        })
        expectEntries([.Message(1, 0, 0, false)])
    }
    
    func testRemoveSingleMessageInclusionWithMinIndexUpdate() {
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 50)
        })
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        expectEntries([.Message(1, 0, 50, false)])
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 200)
        })
        expectEntries([.Message(1, 0, 200, false)])
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        expectEntries([])
        addMessage(1, 200, 200)
        expectEntries([.Message(1, 200, 200, true)])
    }
    
    func testOverrideNothing() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        addMessage(1, 100, 100)
        expectEntries([.Message(1, 100, 100, true)])
    }
    
    func testInsertHoleIntoEmpty() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(1, 10, 10)
        expectEntries([.Hole(1, 10, 10)])
    }
    
    func testInsertHoleLower() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addChatListHole(1, 10, 10)
        expectEntries([.Hole(1, 10, 10), .Message(1, 100, 100, true)])
    }
    
    func testInsertHoleUpper() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addMessage(1, 100, 100)
        addChatListHole(1, 200, 200)
        expectEntries([.Message(1, 100, 100, true), .Hole(1, 200, 200)])
    }
    
    func testIgnoreRemoveHole() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(1, 100, 100)
        removeMessages(1, [100])
        expectEntries([.Hole(1, 100, 100)])
        
        addMessage(1, 100, 100)
        expectEntries([.Message(1, 100, 100, true), .Hole(1, 100, 100)])
        
        removeMessages(1, [100])
        expectEntries([.Hole(1, 100, 100)])
        
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 100)
        })
        expectEntries([.Message(1, 0, 100, false), .Hole(1, 100, 100)])
    }
    
    func testReplaceHoleWithHole() {
        updateInclusion(1, f: { _ in
            return .ifHasMessages
        })
        updateInclusion(2, f: { _ in
            return .ifHasMessages
        })
        
        addChatListHole(1, 100, 100)
        replaceChatListHole(1, 100, 100, 2, 200, 200)
        expectEntries([.Hole(2, 200, 200)])
    }
    
    func testReplaceHoleWithNone() {
        addChatListHole(1, 100, 100)
        removeChatListHole(1, 100, 100)
        expectEntries([])
    }
    
    func testInclusionUpdate() {
        //expectEntries([.Message(1, 0, 1, false)])
        addMessage(1, 100, 100)
        //expectEntries([.Message(1, 100, 100, true)])
        addMessage(1, 200, 200)
        updateInclusion(1, f: { _ in
            return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: 1)
        })
        addMessage(1, 300, 300)
        expectEntries([.Message(1, 300, 300, true)])
    }
}
