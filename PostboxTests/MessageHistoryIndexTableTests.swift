import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1

private extension MessageIndex {
    init(id: Int32, timestamp: Int32) {
        self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp)
    }
}

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
                default:
                    return false
            }
        case let .Hole(minId, maxId, maxTimestamp):
            switch rhs {
                case let .Hole(rMinId, rMaxId, rMaxTimestamp):
                    return minId == rMinId && maxId == rMaxId && maxTimestamp == rMaxTimestamp
                default:
                    return false
            }
    }
}

@testable import Postbox

class MessageHistoryIndexTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var indexTable: MessageHistoryIndexTable?
    var globalMessageIdsTable: GlobalMessageIdsTable?
    var historyMetadataTable: MessageHistoryMetadataTable?
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHole: (topLevel: nil, groups: nil), initializeMessageNamespacesWithHoles: [], existingMessageTags: [], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], additionalChatListIndexNamespace: nil)
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, table: GlobalMessageIdsTable.tableSpec(2), namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, table: MessageHistoryMetadataTable.tableSpec(8))
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, table: MessageHistoryIndexTable.tableSpec(1), globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.indexTable = nil
        
        self.valueBox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    func addHole(_ id: Int32) {
        var operations: [MessageHistoryIndexOperation] = []
        self.indexTable!.addHole(MessageId(peerId: peerId, namespace: namespace, id: id), operations: &operations)
    }
    
    func addMessage(_ id: Int32, _ timestamp: Int32, _ groupingKey: Int64? = nil) {
        var operations: [MessageHistoryIndexOperation] = []
        self.indexTable!.addMessages([InternalStoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, globallyUniqueId: nil, groupingKey: groupingKey, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [], media: [])], location: .Random, operations: &operations)
    }
    
    func addMessagesUpperBlock(_ messages: [(Int32, Int32)]) {
        var operations: [MessageHistoryIndexOperation] = []
        self.indexTable!.addMessages(messages.map { (id, timestamp) in
            return InternalStoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, globallyUniqueId: nil, groupingKey: nil, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [], media: [])
        }, location: .UpperHistoryBlock, operations: &operations)
    }
    
    func fillHole(_ id: Int32, _ fillType: HoleFill, _ messages: [(Int32, Int32, Int64?)], _ tagMask: MessageTags? = nil) {
        var operations: [MessageHistoryIndexOperation] = []
        
        self.indexTable!.fillHole(MessageId(peerId: peerId, namespace: namespace, id: id), fillType: fillType, tagMask: tagMask, messages: messages.map({
            return InternalStoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: $0.0), timestamp: $0.1, globallyUniqueId: nil, groupingKey: $0.2, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [], media: [])
        }), operations: &operations)
    }
    
    func fillMultipleHoles(_ mainId: Int32, _ fillType: HoleFill, _ messages: [(Int32, Int32)], _ tagMask: MessageTags? = nil) {
        var operations: [MessageHistoryIndexOperation] = []
        self.indexTable!.fillMultipleHoles(mainHoleId: MessageId(peerId: peerId, namespace: namespace, id: mainId), fillType: fillType, tagMask: tagMask, messages: messages.map({
            return InternalStoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: $0.0), timestamp: $0.1, globallyUniqueId: nil, groupingKey: nil, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [], media: [])
        }), operations: &operations)
    }
    
    func removeMessage(_ id: Int32) {
        var operations: [MessageHistoryIndexOperation] = []
        self.indexTable!.removeMessage(MessageId(peerId: peerId, namespace: namespace, id: id), operations: &operations)
    }
    
    private func expect(_ items: [Item]) {
        let actualList = self.indexTable!.debugList(peerId, namespace: namespace)
        let actualItems = actualList.map { return Item($0) }
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
    
    func testAddMessageIgnoreOverwrite() {
        addMessage(100, 100)
        expect([.Message(100, 100)])
        
        addMessage(100, 110)
        expect([.Message(100, 100)])
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
        fillHole(1, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [])
        expect([])
    }

    func testFillHoleComplete() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(100, 100, nil), (200, 200, nil)])
        expect([.Message(100, 100), .Message(200, 200)])
    }
    
    func testFillHoleUpperToLowerPartial() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(100, 100, nil), (200, 200, nil)])
        expect([.Hole(1, 99, 100), .Message(100, 100), .Message(200, 200)])
    }
    
    func testFillHoleUpperToLowerToBounds() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(1, 1, nil), (200, 200, nil)])
        expect([.Message(1, 1), .Message(200, 200)])
    }
    
    func testFillHoleLowerToUpperToBounds() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil)), [(100, 100, nil), (Int32.max, 200, nil)])
        expect([.Message(100, 100), .Message(Int32.max, 200)])
    }
    
    func testFillHoleLowerToUpperPartial() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil)), [(100, 100, nil), (200, 200, nil)])
        expect([.Message(100, 100), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesUpperToLower() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(150, 150, nil)])
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Hole(101, 149, 150), .Message(150, 150), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesLowerToUpper() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, HoleFill(complete: false, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil)), [(150, 150, nil)])
        
        expect([.Hole(1, 99, 100), .Message(100, 100), .Message(150, 150), .Hole(151, 199, 200), .Message(200, 200), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesComplete() {
        addHole(1)
        
        addMessage(100, 100)
        addMessage(200, 200)
        
        fillHole(199, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(150, 150, nil)])
        
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
        
        fillHole(99, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [])
        
        expect([.Message(100, 100)])
    }
    
    func testFillHoleIgnoreOverMessage() {
        addMessage(100, 100)
        addMessage(101, 101)
        
        fillHole(100, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(90, 90, nil)])
        
        expect([.Message(90, 90), .Message(100, 100), .Message(101, 101)])
    }
    
    func testFillHoleWithOverflow() {
        addMessage(100, 100)
        addMessage(200, 200)
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(150, 150, nil), (300, 300, nil)])
        
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
    
    func testAddMessageCutInitialHole() {
        addHole(1)
        expect([.Hole(1, Int32.max, Int32.max)])
        addMessagesUpperBlock([(100, 100)])
        expect([.Hole(1, 99, 100), .Message(100, 100)])
    }
    
    func testAddMessageRemoveInitialHole() {
        addHole(1)
        expect([.Hole(1, Int32.max, Int32.max)])
        addMessagesUpperBlock([(1, 100)])
        expect([.Message(1, 100)])
    }
    
    func testAddMessageCutHoleAfterMessage1() {
        addMessage(10, 10)
        addHole(11)
        expect([.Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        addMessagesUpperBlock([(100, 100)])
        expect([.Message(10, 10), .Hole(11, 99, 100), .Message(100, 100)])
    }
    
    func testAddMessageCutHoleAfterMessage2() {
        addMessage(10, 10)
        addHole(11)
        expect([.Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        addMessagesUpperBlock([(12, 12)])
        expect([.Message(10, 10), .Hole(11, 11, 12), .Message(12, 12)])
    }
    
    func testAddMessageRemoveHoleAfterMessage() {
        addMessage(10, 10)
        addHole(11)
        expect([.Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        addMessagesUpperBlock([(11, 11)])
        expect([.Message(10, 10), .Message(11, 11)])
    }
    
    func testAddMessageRemoveHoleIgnoreOverwriteMessage() {
        addMessage(10, 10)
        addHole(11)
        expect([.Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        addMessagesUpperBlock([(10, 11)])
        expect([.Message(10, 10)])
    }
    
    func testFillHoleAtIndex() {
        addHole(1)
        expect([.Hole(1, Int32.max, Int32.max)])
        fillHole(1, HoleFill(complete: false, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 10), lowerComplete: false, upperComplete: false)), [(5, 5, nil), (10, 10, nil)])
        expect([.Hole(1, 4, 5), .Message(5, 5), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
    }
    
    func testFillHoleAtIndexComplete() {
        addHole(1)
        expect([.Hole(1, Int32.max, Int32.max)])
        fillHole(1, HoleFill(complete: true, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 10), lowerComplete: false, upperComplete: false)), [(5, 5, nil), (10, 10, nil)])
        expect([.Message(5, 5), .Message(10, 10)])
    }
    
    func testFillMultipleHolesSingleHole() {
        addHole(1)
        expect([.Hole(1, Int32.max, Int32.max)])
        
        fillMultipleHoles(1, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(5, 5), (10, 10)])
        expect([.Hole(1, 4, 5), .Message(5, 5), .Message(10, 10)])
    }
    
    func testFillMultipleHolesTwoHolesUpperToLowerNotComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20)])
    }
    
    func testFillMultipleHolesTwoHolesUpperToLowerNotCompleteSkipOverOne() {
        addHole(1)
        addMessage(10, 10)
        addMessage(13, 13)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, 12, 13), .Message(13, 13), .Hole(14, Int32.max, Int32.max)])
        
        fillMultipleHoles(20, HoleFill(complete: false, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(13, 13), .Message(15, 15), .Message(20, 20)])
    }
    
    func testFillMultipleHolesTwoHolesUpperToLowerComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: true, direction: .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20)])
    }
    
    func testFillMultipleHolesTwoHolesLowerToUpperNotComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20), .Hole(21, Int32.max, Int32.max)])
    }
    
    func testFillMultipleHolesTwoHolesLowerToUpperComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: true, direction: .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: nil)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20)])
    }
    
    func testFillMultipleHolesTwoHolesAroundIndexNotComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 15), lowerComplete: false, upperComplete: false)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20), .Hole(21, Int32.max, Int32.max)])
    }
    
    func testFillMultipleHolesTwoHolesAroundIndexUpperComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 15), lowerComplete: false, upperComplete: true)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20)])
    }
    
    func testFillMultipleHolesTwoHolesAroundIndexLowerComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 15), lowerComplete: true, upperComplete: false)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20), .Hole(21, Int32.max, Int32.max)])
    }
    
    func testFillMultipleHolesTwoHolesAroundIndexAutoComplete() {
        addHole(1)
        addMessage(10, 10)
        expect([.Hole(1, 9, 10), .Message(10, 10), .Hole(11, Int32.max, Int32.max)])
        
        fillMultipleHoles(12, HoleFill(complete: false, direction: .AroundId(MessageId(peerId: peerId, namespace: namespace, id: 15), lowerComplete: false, upperComplete: false)), [(8, 8), (15, 15), (20, 20)])
        
        expect([.Hole(1, 7, 8), .Message(8, 8), .Message(10, 10), .Message(15, 15), .Message(20, 20), .Hole(21, Int32.max, Int32.max)])
    }
    
    func testHole1() {
        addMessage(1000, 1000)
        addMessage(1001, 1001)
        addHole(Int32.max)
        expect([.Message(1000, 1000), .Message(1001, 1001), .Hole(1002, Int32.max, Int32.max)])
        addMessagesUpperBlock([(1005, 1005)])
        expect([.Message(1000, 1000), .Message(1001, 1001), .Hole(1002, 1004, 1005), .Message(1005, 1005)])
        addMessage(1003, 1003)
        expect([.Message(1000, 1000), .Message(1001, 1001), .Hole(1002, 1002, 1003), .Message(1003, 1003), .Hole(1004, 1004, 1005), .Message(1005, 1005)])
    }
}
