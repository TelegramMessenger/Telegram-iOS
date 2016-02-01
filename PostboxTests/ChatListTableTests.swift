import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

private let namespace: Int32 = 1

private let authorPeerId = PeerId(namespace: 2, id: 3)

private enum Entry: Equatable, CustomStringConvertible {
    case Message(Int32, Int32, Int32)
    case Nothing(Int32, Int32, Int32)
    
    var description: String {
        switch self {
            case let .Message(peerId, id, timestamp):
                return "Message(\(peerId), \(id), \(timestamp))"
            case let .Nothing(peerId, id, timestamp):
                return "Nothing(\(peerId), \(id), \(timestamp))"
        }
    }
}

private func ==(lhs: Entry, rhs: Entry) -> Bool {
    switch lhs {
        case let .Message(lhsPeerId, lhsId, lhsTimestamp):
            switch rhs {
                case let .Message(rhsPeerId, rhsId, rhsTimestamp):
                    return lhsPeerId == rhsPeerId && lhsId == rhsId && lhsTimestamp == rhsTimestamp
                case .Nothing:
                    return false
            }
        case let .Nothing(lhsPeerId, lhsId, lhsTimestamp):
            switch rhs {
                case .Message:
                    return false
                case let .Nothing(rhsPeerId, rhsId, rhsTimestamp):
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
    var mediaCleanupTable: MediaCleanupTable?
    var historyTable: MessageHistoryTable?
    var chatListIndexTable: ChatListIndexTable?
    var chatListTable: ChatListTable?
    
    override class func setUp() {
        super.setUp()
    }
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory().stringByAppendingString("\(randomId)")
        self.valueBox = SqliteValueBox(basePath: path!)
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, tableId: 7, namespace: namespace)
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, tableId: 1, globalMessageIdsTable: self.globalMessageIdsTable!)
        self.mediaCleanupTable = MediaCleanupTable(valueBox: self.valueBox!, tableId: 3)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, tableId: 2, mediaCleanupTable: self.mediaCleanupTable!)
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, tableId: 4, messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!)
        self.chatListIndexTable = ChatListIndexTable(valueBox: self.valueBox!, tableId: 5)
        self.chatListTable = ChatListTable(valueBox: self.valueBox!, tableId: 6, indexTable: self.chatListIndexTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.mediaCleanupTable = nil
        self.chatListIndexTable = nil
        self.chatListTable = nil
        
        self.valueBox = nil
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(path!)
        self.path = nil
    }
    
    private func addMessage(peerId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = []) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.historyTable!.addMessages([StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), timestamp: timestamp, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(operationsByPeerId, messageHistoryTable: self.historyTable!, operations: &operations)
    }
    
    private func addHole(peerId: Int32, _ id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.historyTable!.addHoles([MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(operationsByPeerId, messageHistoryTable: self.historyTable!, operations: &operations)
    }
    
    private func removeMessages(peerId: Int32, _ ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(operationsByPeerId, messageHistoryTable: self.historyTable!, operations: &operations)
    }
    
    private func fillHole(peerId: Int32, _ id: Int32, _ fillType: HoleFillType, _ messages: [(Int32, Int32, String, [Media])]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.historyTable!.fillHole(MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: id), fillType: fillType, messages: messages.map({ StoreMessage(id: MessageId(peerId: PeerId(namespace: namespace, id: peerId), namespace: namespace, id: $0.0), timestamp: $0.1, authorId: authorPeerId, text: $0.2, attributes: [], media: $0.3) }), operationsByPeerId: &operationsByPeerId)
        var operations: [ChatListOperation] = []
        self.chatListTable!.replay(operationsByPeerId, messageHistoryTable: self.historyTable!, operations: &operations)
    }
    
    private func expectEntries(entries: [Entry]) {
        let actualEntries = self.chatListTable!.debugList(self.historyTable!).map({ entry -> Entry in
            switch entry {
                case let .Message(message):
                    if message.authorId != authorPeerId {
                        XCTFail("Expected authorId \(authorPeerId), actual \(message.authorId)")
                    }
                    return .Message(message.id.peerId.id, message.id.id, message.timestamp)
                case let .Nothing(index):
                    return .Nothing(index.id.peerId.id, index.id.id, index.timestamp)
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
        addMessage(1, 100, 100)
        expectEntries([.Message(1, 100, 100)])
    }
    
    func testInsertLaterMessage() {
        addMessage(1, 100, 100)
        addMessage(1, 200, 200)
        expectEntries([.Message(1, 200, 200)])
    }
    
    func testInsertEarlierMessage() {
        addMessage(1, 100, 100)
        addMessage(1, 10, 20)
        expectEntries([.Message(1, 100, 100)])
    }
    
    func testInsertTwoChatMessages() {
        addMessage(1, 100, 100)
        addMessage(2, 10, 20)
        expectEntries([.Message(2, 10, 20), .Message(1, 100, 100)])
    }
    
    func testMoveChatUpper() {
        addMessage(1, 100, 100)
        addMessage(2, 10, 20)
        addMessage(2, 120, 120)
        expectEntries([.Message(1, 100, 100), .Message(2, 120, 120)])
    }
    
    func testRemoveSingleMessage() {
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        expectEntries([.Nothing(1, 100, 100)])
    }
    
    func testOverrideNothing() {
        addMessage(1, 100, 100)
        removeMessages(1, [100])
        addMessage(1, 100, 100)
        expectEntries([.Message(1, 100, 100)])
    }
}