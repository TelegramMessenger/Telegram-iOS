import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1

private enum Item: Equatable, CustomStringConvertible {
    case Message(Int32, Int32)
    case Hole(Int32, Int32, Int32)
    
    init(_ item: HistoryIndexEntry) {
        switch item {
            case let .Message(index):
                self = .Message(index.id.id, index.timestamp)
            case let .Hole(hole):
                self = .Hole(hole.min, hole.maxIndex.id.id, hole.maxIndex.timestamp)
        }
    }
    
    var description: String {
        switch self {
            case let .Message(id, timestamp):
                return "Message(\(id), \(timestamp))"
            case let .Hole(minId, maxId, maxTimestamp):
                return "Hole(\(minId), \(maxId), \(maxTimestamp))"
        }
    }
}

private func ==(lhs: Item, rhs: Item) -> Bool {
    switch lhs {
        case let .Message(id, timestamp):
            switch rhs {
                case let .Message(rId, rTimestamp):
                    return id == rId && timestamp == rTimestamp
                case .Hole:
                    return false
            }
        case let .Hole(minId, maxId, maxTimestamp):
            switch rhs {
                case .Message:
                    return false
                case let .Hole(rMinId, rMaxId, rMaxTimestamp):
                    return minId == rMinId && maxId == rMaxId && maxTimestamp == rMaxTimestamp
            }
    }
}

@testable import Postbox

class MessageHistoryIndexTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var indexTable: MessageHistoryIndexTable?
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory().stringByAppendingString("\(randomId)")
        self.valueBox = SqliteValueBox(basePath: path!)
        
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, tableId: 1)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.indexTable = nil
        
        self.valueBox = nil
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(path!)
        self.path = nil
    }
    
    func addHole(id: Int32) {
        self.indexTable!.addHole(MessageId(peerId: peerId, namespace: namespace, id: id))
    }
    
    func addMessage(id: Int32, _ timestamp: Int32) {
        self.indexTable!.addMessage(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp))
    }
    
    func fillHole(id: Int32, _ fillType: HoleFillType, _ messages: [(Int32, Int32)]) {
        self.indexTable!.fillHole(MessageId(peerId: peerId, namespace: namespace, id: id), fillType: fillType, indices: messages.map({MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: $0.0), timestamp: $0.1)}))
    }
    
    func removeMessage(id: Int32) {
        self.indexTable!.removeMessage(MessageId(peerId: peerId, namespace: namespace, id: id))
    }
    
    private func expect(items: [Item]) {
        let actualItems = self.indexTable!.debugList(peerId, namespace: namespace).map { return Item($0) }
        if items != actualItems {
            XCTFail("Expected\n\(items)\nGot\n\(actualItems)")
        }
    }
    
    func testEmpty() {
        expect([])
    }
    
    func testAddMessageToEmpty() {
        addMessage(100, 100)
        expect([.Message(100, 100)])
        
        addMessage(110, 110)
        expect([.Message(100, 100), .Message(110, 110)])
        
        addMessage(90, 90)
        expect([.Message(90, 90), .Message(100, 100), .Message(110, 110)])
    }
    
    func testAddHoleToEmpty() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testAddHoleToFullHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        addHole(110)
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testAddMessageToFullHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageDividingUpperHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
        addMessage(100, 100)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, 99, 100), .Message(100, 100), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testAddMessageDividingLowerHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
        addMessage(80, 80)
        expect([.Hole(1, 79, 80), .Message(80, 80), .Hole(81, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingUpperHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(90, 90)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
        addMessage(91, 91)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Message(91, 91), .Hole(92, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingLowerHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(90, 90)
        expect([.Hole(1, 89, 90), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
        addMessage(89, 89)
        expect([.Hole(1, 88, 89), .Message(89, 89), .Message(90, 90), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingLeftmostHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(1, 1)
        
        expect([.Message(1, 1), .Hole(2, Int32.max, Int32.max)])
    }
    
    func testAddMessageRemovingLefmostHole() {
        addHole(100)
        expect([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(2, 2)
        expect([.Hole(1, 1, 2), .Message(2, 2), .Hole(3, Int32.max, Int32.max)])
        
        addMessage(1, 1)
        expect([.Message(1, 1), .Message(2, 2), .Hole(3, Int32.max, Int32.max)])
    }
    
    func testAddHoleLowerThanMessage() {
        addMessage(100, 100)
        addHole(1)
        
        expect([.Hole(1, 99, 100), .Message(100, 100)])
    }
    
    func testAddHoleHigherThanMessage() {
        addMessage(100, 100)
        addHole(200)
        
        expect([.Message(100, 100), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testIgnoreHigherHole() {
        addHole(200)
        expect([.Hole(1, Int32.max, Int32.max)])
        addHole(400)
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testIgnoreHigherHoleAfterMessage() {
        addMessage(100, 100)
        addHole(200)
        expect([.Message(100, 100), .Hole(101, Int32.max, Int32.max)])
        addHole(400)
        expect([.Message(100, 100), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testAddHoleBetweenMessages() {
        addMessage(100, 100)
        addMessage(200, 200)
        addHole(150)
        
        expect([.Message(100, 100), .Hole(101, 199, 200), .Message(200, 200)])
    }
    
    func testFillHoleEmpty() {
        fillHole(1, .Complete, [])
        expect([])
    }

    func testFillHoleComplete() {
        addHole(100)
        
        fillHole(1, .Complete, [(100, 100), (200, 200)])
        expect([.Message(100, 100), .Message(200, 200)])
    }
    
    func testFillHoleUpperToLowerPartial() {
        addHole(100)
        
        fillHole(1, .UpperToLower, [(100, 100), (200, 200)])
        expect([.Hole(1, 99, 100), .Message(100, 100), .Message(200, 200)])
    }
    
    func testFillHoleUpperToLowerToBounds() {
        addHole(100)
        
        fillHole(1, .UpperToLower, [(1, 1), (200, 200)])
        expect([.Message(1, 1), .Message(200, 200)])
    }
    
    func testFillHoleLowerToUpperToBounds() {
        addHole(100)
        
        fillHole(1, .LowerToUpper, [(100, 100), (Int32.max, 200)])
        expect([.Message(100, 100), .Message(Int32.max, 200)])
    }
    
    func testFillHoleLowerToUpperPartial() {
        addHole(100)
        
        fillHole(1, .LowerToUpper, [(100, 100), (200, 200)])
        expect([.Message(100, 100), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesUpperToLower() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, .UpperToLower, [(150, 150)])
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Hole(101, 149, 150), .Message(150, 150), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesLowerToUpper() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, .LowerToUpper, [(150, 150)])
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Message(150, 150), .Hole(151, 199, 200), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesComplete() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, .Complete, [(150, 150)])
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Message(150, 150), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesWithMessage() {
        addMessage(200, 200)
        addMessage(202, 202)
        addHole(201)
        addMessage(201, 201)
        
        expect([.Message(200, 200), .Message(201, 201), .Message(202, 202)])
    }
    
    func testFillHoleWithNoMessagesComplete() {
        addMessage(100, 100)
        addHole(1)
        
        fillHole(99, .Complete, [])
        
        expect([.Message(100, 100)])
    }
    
    func testFillHoleIgnoreOverMessage() {
        addMessage(100, 100)
        addMessage(101, 101)
        
        fillHole(100, .Complete, [(90, 90)])
        
        expect([.Message(90, 90), .Message(100, 100), .Message(101, 101)])
    }
    
    func testFillHoleWithOverflow() {
        addMessage(100, 100)
        addMessage(200, 200)
        addHole(150)
        
        fillHole(199, .UpperToLower, [(150, 150), (300, 300)])
        
        expect([.Message(100, 100), .Hole(101, 149, 150), .Message(150, 150), .Message(200, 200), .Message(300, 300)])
    }
    
    func testIgnoreHoleOverMessageBetweenMessages() {
        addMessage(199, 199)
        addMessage(200, 200)
        addHole(200)
        
        expect([.Message(199, 199), .Message(200, 200)])
    }
    
    func testMergeHoleAfterDeletingMessage() {
        addMessage(100, 100)
        addHole(1)
        addHole(200)
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Hole(101, Int32.max, Int32.max)])
        
        removeMessage(100)
        
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testMergeHoleLowerAfterDeletingMessage() {
        addMessage(100, 100)
        addHole(1)
        addMessage(200, 200)
        
        removeMessage(100)
        
        expect([.Hole(1, 199, 200), .Message(200, 200)])
    }
    
    func testMergeHoleUpperAfterDeletingMessage() {
        addMessage(100, 100)
        addMessage(200, 200)
        addHole(300)
        
        removeMessage(200)
        
        expect([.Message(100, 100), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testExtendLowerHoleAfterDeletingMessage() {
        addMessage(100, 100)
        addHole(100)
        
        removeMessage(100)
        
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testExtendUpperHoleAfterDeletingMessage() {
        addMessage(100, 100)
        addHole(101)
        
        removeMessage(100)
        
        expect([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testDeleteMessageBelowMessage() {
        addMessage(100, 100)
        addMessage(200, 200)
        removeMessage(100)
        
        expect([.Message(200, 200)])
    }
    
    func testDeleteMessageAboveMessage() {
        addMessage(100, 100)
        addMessage(200, 200)
        removeMessage(200)
        
        expect([.Message(100, 100)])
    }
    
    func testDeleteMessageBetweenMessages() {
        addMessage(100, 100)
        addMessage(200, 200)
        addMessage(300, 300)
        removeMessage(200)
        
        expect([.Message(100, 100), .Message(300, 300)])
    }
}
