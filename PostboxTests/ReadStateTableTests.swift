import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1
private let authorPeerId = PeerId(namespace: 1, id: 6)

private func ==(lhs: [Media], rhs: [Media]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    
    for i in 0 ..< lhs.count {
        if !lhs[i].isEqual(rhs[i]) {
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
    var mediaCleanupTable: MediaCleanupTable?
    var historyTable: MessageHistoryTable?
    var historyMetadataTable: MessageHistoryMetadataTable?
    var unsentTable: MessageHistoryUnsentTable?
    var tagsTable: MessageHistoryTagsTable?
    var readStateTable: MessageHistoryReadStateTable?
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable?
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory().stringByAppendingString("\(randomId)")
        self.valueBox = SqliteValueBox(basePath: path!)
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHoles: [], initializeMessageNamespacesWithHoles: [], existingMessageTags: [.First, .Second])
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, tableId: 5, namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, tableId: 7)
        self.unsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox!, tableId: 8)
        self.tagsTable = MessageHistoryTagsTable(valueBox: self.valueBox!, tableId: 9)
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, tableId: 1, globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.mediaCleanupTable = MediaCleanupTable(valueBox: self.valueBox!, tableId: 3)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, tableId: 2, mediaCleanupTable: self.mediaCleanupTable!)
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox!, tableId: 10)
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox!, tableId: 11)
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, tableId: 4, messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!, historyMetadataTable: self.historyMetadataTable!, unsentTable: self.unsentTable!, tagsTable: self.tagsTable!, readStateTable: self.readStateTable!, synchronizeReadStateTable: self.synchronizeReadStateTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.mediaCleanupTable = nil
        self.peerTable = nil
        self.historyMetadataTable = nil
        
        self.valueBox = nil
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(path!)
        self.path = nil
    }
    
    private func addMessage(id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags = [], _ tags: MessageTags = []) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.addMessages([StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, flags: flags, tags: tags, forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func updateMessage(previousId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags, _ tags: MessageTags) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.updateMessage(MessageId(peerId: peerId, namespace: namespace, id: previousId), message: StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, flags: flags, tags: tags, forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func addHole(id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.addHoles([MessageId(peerId: peerId, namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func removeMessages(ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: peerId, namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func expectApplyRead(messageId: Int32, _ expectInvalidate: Bool) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.applyIncomingReadMaxId(MessageId(peerId: peerId, namespace: namespace, id: messageId), operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        let invalidated = updatedPeerReadStateOperations.count != 0
        if expectInvalidate != invalidated {
            XCTFail("applyRead: invalidated expected \(expectInvalidate), actual: \(invalidated)")
        }
    }
    
    private func expectReadState(maxReadId: Int32, _ maxKnownId: Int32, _ count: Int32) {
        if let state = self.readStateTable!.getCombinedState(peerId)?.states.first?.1 {
            if state.maxReadId != maxReadId || state.maxKnownId != maxKnownId || state.count != count {
                XCTFail("Expected\nmaxReadId: \(maxReadId), maxKnownId: \(maxKnownId), count: \(count)\nActual\nmaxReadId: \(state.maxReadId), maxKnownId: \(state.maxKnownId), count: \(state.count)")
            }
        } else {
            XCTFail("Expected\nmaxReadId: (maxReadId), maxKnownId: \(maxKnownId), count: \(count)\nActual\nnil")
        }
    }
    
    func testResetState() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 120, count: 130)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        expectReadState(100, 120, 130)
    }
    
    func testAddIncomingBeforeKnown() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 120, count: 130)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(99, 99, "", [], [.Incoming])
        
        expectReadState(100, 120, 130)
    }
    
    func testAddIncomingAfterKnown() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 120, count: 130)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(100, 120, 131)
    }
    
    func testApplyReadThenAddIncoming() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 100, count: 0)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.expectApplyRead(200, false)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(200, 200, 0)
    }
    
    func testApplyAddIncomingThenRead() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 100, count: 0)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(130, 130, "", [], [.Incoming])
        
        expectReadState(100, 100, 1)
        
        self.expectApplyRead(200, false)
        
        expectReadState(200, 200, 0)
    }
    
    func testIgnoreOldRead() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 100, count: 0)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.expectApplyRead(90, false)
        
        expectReadState(100, 100, 0)
    }
    
    func testInvalidateReadHole() {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.resetIncomingReadStates([peerId: [namespace: PeerReadState(maxReadId: 100, maxKnownId: 100, count: 0)]], operationsByPeerId: &operationsByPeerId, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
        
        self.addMessage(200, 200)
        self.addHole(1)
        
        self.expectApplyRead(200, true)
        
        expectReadState(200, 200, 0)
    }
    
    
}
