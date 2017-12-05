import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private struct TestListItem: OrderedItemListEntryContents {
    init() {
        
    }
    
    init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
        
    }
}

private let declaredEncodables: Void = {
    declareEncodable(TestListItem.self, f: { TestListItem(decoder: $0) })
    return ()
}()

class OrderedItemListTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var itemListTable: OrderedItemListTable?
    var itemListIndexTable: OrderedItemListIndexTable?
    
    override func setUp() {
        super.setUp()
        
        let _ = declaredEncodables
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        self.itemListIndexTable = OrderedItemListIndexTable(valueBox: self.valueBox!, table: OrderedItemListIndexTable.tableSpec(0))
        self.itemListTable = OrderedItemListTable(valueBox: self.valueBox!, table: OrderedItemListTable.tableSpec(1), indexTable: self.itemListIndexTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.valueBox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    private func expectIds(_ ids: [Int32]) {
        let actualIds = self.itemListTable!.getItems(collectionId: 0).map { entry -> Int32 in
            var value: Int32 = 0
            memcpy(&value, entry.id.memory, 4)
            return value
        }
        XCTAssert(ids == actualIds, "Expected\n\(ids)\nActual\n\(actualIds)")
    }
    
    private func setIds(_ ids: [Int32]) {
        var operations: [Int32 : [OrderedItemListOperation]] = [:]
        self.itemListTable!.replaceItems(collectionId: 0, items: ids.map { id -> OrderedItemListEntry in
            var idValue: Int32 = id
            let buffer = MemoryBuffer(memory: malloc(4)!, capacity: 4, length: 4, freeWhenDone: true)
            memcpy(buffer.memory, &idValue, 4)
            return OrderedItemListEntry(id: buffer, contents: TestListItem())
        }, operations: &operations)
        XCTAssert(self.itemListTable!.testIntegrity(collectionId: 0), "Index integrity violated")
    }
    
    private func addOrMoveId(_ id: Int32, _ maxCount: Int? = nil) {
        var operations: [Int32 : [OrderedItemListOperation]] = [:]
        var idValue: Int32 = id
        let buffer = MemoryBuffer(memory: malloc(4)!, capacity: 4, length: 4, freeWhenDone: true)
        memcpy(buffer.memory, &idValue, 4)
        self.itemListTable!.addItemOrMoveToFirstPosition(collectionId: 0, item: OrderedItemListEntry(id: buffer, contents: TestListItem()), removeTailIfCountExceeds: maxCount, operations: &operations)
        XCTAssert(self.itemListTable!.testIntegrity(collectionId: 0), "Index integrity violated")
    }
    
    private func removeId(_ id: Int32) {
        var operations: [Int32 : [OrderedItemListOperation]] = [:]
        var idValue: Int32 = id
        let buffer = MemoryBuffer(memory: malloc(4)!, capacity: 4, length: 4, freeWhenDone: true)
        memcpy(buffer.memory, &idValue, 4)
        self.itemListTable!.remove(collectionId: 0, itemId: buffer, operations: &operations)
        XCTAssert(self.itemListTable!.testIntegrity(collectionId: 0), "Index integrity violated")
    }
    
    func testEmpty() {
        expectIds([])
    }
    
    func testSetIds() {
        expectIds([])
        setIds([10, 20, 30])
        expectIds([10, 20, 30])
        setIds([40, 50, 60])
        expectIds([40, 50, 60])
        setIds([10, 20, 30, 40])
        expectIds([10, 20, 30, 40])
    }
    
    func testAddItem() {
        expectIds([])
        addOrMoveId(10)
        expectIds([10])
        addOrMoveId(20)
        expectIds([20, 10])
        addOrMoveId(30)
        expectIds([30, 20, 10])
        addOrMoveId(40, 4)
        expectIds([40, 30, 20, 10])
        addOrMoveId(50, 4)
        expectIds([50, 40, 30, 20])
    }
    
    func testMoveItem() {
        expectIds([])
        setIds([10, 20, 30])
        expectIds([10, 20, 30])
        addOrMoveId(10)
        expectIds([10, 20, 30])
        addOrMoveId(20)
        expectIds([20, 10, 30])
        addOrMoveId(30)
        expectIds([30, 20, 10])
    }
    
    func testRandom() {
        expectIds([])
        var currentIds = Set<Int32>()
        for _ in 0 ..< 100 {
            let op = arc4random_uniform(4)
            switch op {
                case 0 ... 2:
                    let id = Int32(bitPattern: arc4random_uniform(100))
                    addOrMoveId(id, op == 0 ? 20 : nil)
                    currentIds.insert(id)
                default:
                    if !currentIds.isEmpty {
                        let index = Int(Int32(bitPattern: arc4random_uniform(UInt32(bitPattern: Int32(currentIds.count)))))
                        let id = currentIds[currentIds.index(currentIds.startIndex, offsetBy: index)]
                        removeId(id)
                        currentIds.remove(id)
                    }
            }
        }
    }
}
