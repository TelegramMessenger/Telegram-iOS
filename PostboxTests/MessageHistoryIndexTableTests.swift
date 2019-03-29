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

private extension MessageTags {
    static let media = MessageTags(rawValue: 1 << 0)
}

class MessageHistoryIndexTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var postbox: Postbox?
    
    override func setUp() {
        super.setUp()
        
        self.continueAfterFailure = false
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue(), encryptionKey: "secret".data(using: .utf8)!)
        
        let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [
            peerId.namespace: [
                namespace: Set([.media])
            ]
        ]
        
        let seedConfiguration = SeedConfiguration(globalMessageIdsPeerIdNamespaces: Set(), initializeChatListWithHole: (topLevel: nil, groups: nil), messageHoles: messageHoles, existingMessageTags: [.media], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil)
        
        self.postbox = Postbox(queue: Queue.mainQueue(), basePath: path!, seedConfiguration: seedConfiguration, valueBox: self.valueBox!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.postbox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    func addHole(_ range: ClosedRange<Int32>, space: MessageHistoryHoleSpace) {
        var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
        self.postbox!.messageHistoryHoleIndexTable.add(peerId: peerId, namespace: namespace, space: space, range: range, operations: &operations)
    }
    
    func removeHole(_ range: ClosedRange<Int32>, space: MessageHistoryHoleSpace) {
        var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
        self.postbox!.messageHistoryHoleIndexTable.remove(peerId: peerId, namespace: namespace, space: space, range: range, operations: &operations)
    }
    
    func addMessage(_ id: Int32, _ timestamp: Int32, _ groupingKey: Int64? = nil) {
        var operations: [MessageHistoryIndexOperation] = []
        self.postbox!.messageHistoryIndexTable.addMessages([InternalStoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, globallyUniqueId: nil, groupingKey: groupingKey, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [], media: [])], operations: &operations)
    }
    
    func removeMessage(_ id: Int32) {
        var operations: [MessageHistoryIndexOperation] = []
        self.postbox!.messageHistoryIndexTable.removeMessage(MessageId(peerId: peerId, namespace: namespace, id: id), operations: &operations)
    }
    
    private func expectMessages(_ items: [MessageIndex]) {
        let actualList = self.postbox!.messageHistoryIndexTable.debugList(peerId, namespace: namespace)
        if items != actualList {
            XCTFail("Expected\n\(items)\nGot\n\(actualList)")
        }
    }
    
    private func expectHoles(space: MessageHistoryHoleSpace, _ ranges: [ClosedRange<Int32>], failure: () -> Void = {}) {
        let actualList = self.postbox!.messageHistoryHoleIndexTable.debugList(peerId: peerId, namespace: namespace, space: space)
        if ranges != actualList {
            failure()
            XCTFail("Expected\n\(ranges)\nGot\n\(actualList)")
        }
    }
    
    func testEmpty() {
        expectMessages([])
        expectHoles(space: .everywhere, [])
        expectHoles(space: .tag(.media), [])
    }
    
    func testSimpleMessages() {
        addMessage(10, 10)
        expectMessages([.init(id: 10, timestamp: 10)])
        addMessage(11, 11)
        expectMessages([.init(id: 10, timestamp: 10), .init(id: 11, timestamp: 11)])
        expectHoles(space: .everywhere, [])
        expectHoles(space: .tag(.media), [])
    }
    
    func testSimpleHoles() {
        removeHole(1 ... Int32.max, space: .everywhere)
        
        addHole(3 ... 10, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 10])
        
        addHole(3 ... 10, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 10])
        
        addHole(5 ... 20, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 20])
        
        addHole(25 ... 30, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 20, 25 ... 30])
        
        addHole(21 ... 23, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 23, 25 ... 30])
        
        addHole(5 ... 25, space: .everywhere)
        expectHoles(space: .everywhere, [3 ... 30])
        
        addHole(2 ... 35, space: .everywhere)
        expectHoles(space: .everywhere, [2 ... 35])
        
        removeHole(1 ... 5, space: .everywhere)
        expectHoles(space: .everywhere, [6 ... 35])
        
        removeHole(11 ... 11, space: .everywhere)
        expectHoles(space: .everywhere, [6 ... 10, 12 ... 35])
        
        removeHole(8 ... 15, space: .everywhere)
        expectHoles(space: .everywhere, [6 ... 7, 16 ... 35])
        
        removeHole(1 ... 16, space: .everywhere)
        expectHoles(space: .everywhere, [17 ... 35])
    }
    
    func testHoleVectors() {
        struct Operation: Codable {
            struct Key: CodingKey {
                var stringValue: String
                
                init?(stringValue: String) {
                    self.stringValue = stringValue
                }
                
                let intValue: Int? = nil
                init?(intValue: Int) {
                    return nil
                }
            }
            
            let add: Bool
            let range: ClosedRange<Int32>
            
            init(add: Bool, range: ClosedRange<Int32>) {
                self.add = add
                self.range = range
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Key.self)
                self.add = try container.decode(Bool.self, forKey: Key(stringValue: "a")!)
                self.range = (try container.decode(Int32.self, forKey: Key(stringValue: "l")!)) ... (try container.decode(Int32.self, forKey: Key(stringValue: "u")!))
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Key.self)
                try container.encode(self.add, forKey: Key(stringValue: "a")!)
                try container.encode(self.range.lowerBound, forKey: Key(stringValue: "l")!)
                try container.encode(self.range.upperBound, forKey: Key(stringValue: "u")!)
            }
        }
        
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "HoleOperationsVector1", ofType: "json")!
        let jsonData = try! Data(contentsOf: URL(fileURLWithPath: path))
        
        var operations: [Operation] = (try? JSONDecoder().decode(Array<Operation>.self, from: jsonData)) ?? []
        
        if operations.isEmpty {
            for _ in 0 ..< 10000 {
                let bound1 = Int(max(1, arc4random_uniform(1000)))
                let bound2 = Int(max(1, arc4random_uniform(1000)))
                let range: ClosedRange<Int> = min(bound1, bound2) ... max(bound1, bound2)
                let int32Range = Int32(range.lowerBound) ... Int32(range.upperBound)
                let operation = arc4random_uniform(10)
                if operation < 5 {
                    operations.append(Operation(add: true, range: int32Range))
                } else {
                    operations.append(Operation(add: false, range: int32Range))
                }
            }
            let data = try! JSONEncoder().encode(operations)
            print(String(data: data, encoding: .utf8)!)
        }
        
        var verificationSet = IndexSet()
        for (_, holesByMessageNamespace) in self.postbox!.seedConfiguration.messageHoles {
            for (_, _) in holesByMessageNamespace{
                verificationSet.insert(integersIn: 1 ... Int(Int32.max))
            }
        }
        for i in 0 ..< operations.count {
            let operation = operations[i]
            if operation.add {
                verificationSet.insert(integersIn: Int(operation.range.lowerBound) ... Int(operation.range.upperBound))
                addHole(operation.range, space: .everywhere)
            } else {
                verificationSet.remove(integersIn: Int(operation.range.lowerBound) ... Int(operation.range.upperBound))
                removeHole(operation.range, space: .everywhere)
            }
            let testRanges = verificationSet.rangeView.map({ ClosedRange(Int32($0.lowerBound) ... Int32($0.upperBound - 1)) })
            expectHoles(space: .everywhere, testRanges)
            expectHoles(space: .tag(.media), testRanges)
        }
    }
    
    func testHoleTagVectors() {
        struct Operation: Codable {
            struct Key: CodingKey {
                var stringValue: String
                
                init?(stringValue: String) {
                    self.stringValue = stringValue
                }
                
                let intValue: Int? = nil
                init?(intValue: Int) {
                    return nil
                }
            }
            
            let add: Bool
            let range: ClosedRange<Int32>
            let space: MessageHistoryHoleSpace
            
            init(add: Bool, range: ClosedRange<Int32>, space: MessageHistoryHoleSpace) {
                self.add = add
                self.range = range
                self.space = space
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Key.self)
                self.add = try container.decode(Bool.self, forKey: Key(stringValue: "a")!)
                self.range = (try container.decode(Int32.self, forKey: Key(stringValue: "l")!)) ... (try container.decode(Int32.self, forKey: Key(stringValue: "u")!))
                let spaceValue = try container.decode(Int32.self, forKey: Key(stringValue: "s")!)
                if spaceValue == 0 {
                    self.space = .everywhere
                } else {
                    self.space = .tag(MessageTags(rawValue: UInt32(spaceValue)))
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Key.self)
                try container.encode(self.add, forKey: Key(stringValue: "a")!)
                try container.encode(self.range.lowerBound, forKey: Key(stringValue: "l")!)
                try container.encode(self.range.upperBound, forKey: Key(stringValue: "u")!)
                switch self.space {
                    case .everywhere:
                        try container.encode(0, forKey: Key(stringValue: "s")!)
                    case let .tag(tag):
                        try container.encode(Int32(tag.rawValue), forKey: Key(stringValue: "s")!)
                }
            }
        }
        
        var operations: [Operation] = []
        let bundle = Bundle(for: type(of: self))
        if let path = bundle.path(forResource: "HoleOperationsVector2", ofType: "json"), let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            if let value = try? JSONDecoder().decode(Array<Operation>.self, from: jsonData) {
                operations = value
            }
        }
        
        if operations.isEmpty {
            for _ in 0 ..< 10000 {
                let bound1 = Int(max(1, arc4random_uniform(1000)))
                let bound2 = Int(max(1, arc4random_uniform(1000)))
                let range: ClosedRange<Int> = min(bound1, bound2) ... max(bound1, bound2)
                let int32Range = Int32(range.lowerBound) ... Int32(range.upperBound)
                let operation = arc4random_uniform(10)
                let spaceValue = arc4random_uniform(2)
                let space: MessageHistoryHoleSpace
                if spaceValue == 0 {
                    space = .everywhere
                } else {
                    space = .tag(.media)
                }
                if operation < 5 {
                    operations.append(Operation(add: true, range: int32Range, space: space))
                } else {
                    operations.append(Operation(add: false, range: int32Range, space: space))
                }
            }
            let data = try! JSONEncoder().encode(operations)
            print(String(data: data, encoding: .utf8)!)
        }
        
        var everywhereVerificationSet = IndexSet()
        var mediaVerificationSet = IndexSet()
        for (_, holesByMessageNamespace) in self.postbox!.seedConfiguration.messageHoles {
            for (_, _) in holesByMessageNamespace{
                everywhereVerificationSet.insert(integersIn: 1 ... Int(Int32.max))
                mediaVerificationSet.insert(integersIn: 1 ... Int(Int32.max))
            }
        }
        for i in 0 ..< operations.count {
            let operation = operations[i]
            let intRange = Int(operation.range.lowerBound) ... Int(operation.range.upperBound)
            if operation.add {
                switch operation.space {
                    case .everywhere:
                        everywhereVerificationSet.insert(integersIn: intRange)
                        mediaVerificationSet.insert(integersIn: intRange)
                    case .tag:
                        mediaVerificationSet.insert(integersIn: intRange)
                }
                addHole(operation.range, space: operation.space)
            } else {
                switch operation.space {
                    case .everywhere:
                        everywhereVerificationSet.remove(integersIn: intRange)
                        mediaVerificationSet.remove(integersIn: intRange)
                    case .tag:
                        mediaVerificationSet.remove(integersIn: intRange)
                }
                removeHole(operation.range, space: operation.space)
            }
            let everywhereTestRanges = everywhereVerificationSet.rangeView.map({ ClosedRange(Int32($0.lowerBound) ... Int32($0.upperBound - 1)) })
            let mediaTestRanges = mediaVerificationSet.rangeView.map({ ClosedRange(Int32($0.lowerBound) ... Int32($0.upperBound - 1)) })
            expectHoles(space: .everywhere, everywhereTestRanges)
            expectHoles(space: .tag(.media), mediaTestRanges)
        }
    }
    
    func testDirectAccessPerformance() {
        self.beginTestDirectAccessPerformance(compactValuesOnCreation: false)
    }
    
    func testDirectAccessPerformanceCompact() {
        self.beginTestDirectAccessPerformance(compactValuesOnCreation: true)
    }
    
    func testBlobExtractPerformance() {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: false)
        
        let valueBox = self.postbox!.valueBox
        let memory = malloc(4000)!
        let value = MemoryBuffer(memory: memory, capacity: 4000, length: 4000, freeWhenDone: true)
        var keys: [ValueBoxKey] = []
        for _ in 0 ... 1000 {
            let key = ValueBoxKey(length: 16)
            arc4random_buf(key.memory, 16)
            keys.append(key)
            valueBox.set(table, key: key, value: value)
        }
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            self.startMeasuring()
            for key in keys.shuffled() {
                if let value = valueBox.get(table, key: key) {
                    var i = 0
                    let length = value.length
                    if i < length {
                        var output: Int32 = 0
                        value.read(&output, offset: i, length: 4)
                        i += 4
                    }
                }
            }
            self.stopMeasuring()
        })
    }
    
    func testIncrementalBlobExtractPerformance() {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: false)
        
        let valueBox = self.postbox!.valueBox
        let memory = malloc(4000)!
        let value = MemoryBuffer(memory: memory, capacity: 4000, length: 4000, freeWhenDone: true)
        var keys: [ValueBoxKey] = []
        for _ in 0 ... 100000 {
            let key = ValueBoxKey(length: 16)
            arc4random_buf(key.memory, 16)
            keys.append(key)
            valueBox.set(table, key: key, value: value)
        }
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            self.startMeasuring()
            for key in keys.shuffled() {
                valueBox.read(table, key: key, { length, read in
                    var i = 0
                    if i < length {
                        var output: Int32 = 0
                        read(&output, i, 4)
                        i += 4
                    }
                })
            }
            self.stopMeasuring()
        })
    }
    
    private func beginTestDirectAccessPerformance(compactValuesOnCreation: Bool) {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: compactValuesOnCreation)
        
        let valueBox = self.postbox!.valueBox
        let memory = malloc(250)!
        let value = MemoryBuffer(memory: memory, capacity: 250, length: 250, freeWhenDone: true)
        var keys: [ValueBoxKey] = []
        for _ in 0 ... 100000 {
            let key = ValueBoxKey(length: 16)
            arc4random_buf(key.memory, 16)
            keys.append(key)
            valueBox.set(table, key: key, value: value)
        }
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            self.startMeasuring()
            for key in keys.shuffled() {
                let _ = valueBox.get(table, key: key)
            }
            self.stopMeasuring()
        })
    }
    
    func testRangeAccessPerformance() {
        self.beginTestRangeAccessPerformance(compactValuesOnCreation: false)
    }
    
    func testRangeAccessPerformanceCompact() {
        self.beginTestRangeAccessPerformance(compactValuesOnCreation: true)
    }
    
    func testBinarySearchAccessPerformance() {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: true)
        
        let valueBox = self.postbox!.valueBox
        let memory = malloc(250)!
        let value = MemoryBuffer(memory: memory, capacity: 250, length: 250, freeWhenDone: true)
        var keys: [ValueBoxKey] = []
        
        var randomSpacedKeys: [Int32] = []
        for _ in 0 ... 1000000 {
            randomSpacedKeys.append(Int32(arc4random_uniform(100_000_000)))
        }
        randomSpacedKeys.sort()
        
        for i in 0 ..< randomSpacedKeys.count {
            let key = ValueBoxKey(length: 16)
            key.setUInt32(0, value: 200)
            key.setUInt32(4, value: 300)
            key.setInt32(8, value: Int32(randomSpacedKeys[i]))
            key.setInt32(12, value: Int32(i))
            keys.append(key)
            valueBox.set(table, key: key, value: value)
        }
        
        let lowerBound = ValueBoxKey(length: 8)
        lowerBound.setUInt32(0, value: 200)
        lowerBound.setUInt32(4, value: 300)
        
        let upperBound = ValueBoxKey(length: 16)
        upperBound.setUInt32(0, value: 200)
        upperBound.setUInt32(4, value: 301)
        upperBound.setUInt32(8, value: UInt32.max)
        upperBound.setUInt32(12, value: UInt32.max)
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            self.startMeasuring()
            for i in 0 ... 1000 {
                var startingLowerIndexValue: Int32?
                valueBox.range(table, start: lowerBound, end: upperBound, keys: { key in
                    startingLowerIndexValue = key.getInt32(8)
                    return false
                }, limit: 1)
                
                var startingUpperIndexValue: Int32?
                valueBox.range(table, start: upperBound, end: lowerBound, keys: { key in
                    startingUpperIndexValue = key.getInt32(8)
                    return false
                }, limit: 1)
                
                guard let startingLowerIndex = startingLowerIndexValue, let startingUpperIndex = startingUpperIndexValue else {
                    XCTAssert(false)
                    continue
                }
                
                var lowerIndex: Int32 = startingLowerIndex
                var upperIndex: Int32 = startingUpperIndex
                var rangeToLower = false
                
                var readCount = 0
                
                var found = false
                while true {
                    readCount += 1
                    let currentIndex = Int32((Int64(lowerIndex) + Int64(upperIndex)) / 2)
                    let key = ValueBoxKey(length: 12)
                    key.setUInt32(0, value: 200)
                    key.setUInt32(4, value: 300)
                    key.setInt32(8, value: currentIndex)
                    
                    var foundValue: (Int32, Int32)?
                    if !rangeToLower {
                        valueBox.range(table, start: key, end: upperBound, keys: { key in
                            foundValue = (key.getInt32(8), key.getInt32(12))
                            return false
                        }, limit: 1)
                    } else {
                        valueBox.range(table, start: key, end: lowerBound, keys: { key in
                            foundValue = (key.getInt32(8), key.getInt32(12))
                            return false
                        }, limit: 1)
                    }
                    
                    if let (foundKey, foundValue) = foundValue {
                        if foundValue == Int32(i) {
                            found = true
                            break
                        } else if lowerIndex > upperIndex {
                            break
                        } else {
                            if foundValue > Int(i) {
                                upperIndex = foundKey - 1
                                rangeToLower = true
                            } else {
                                lowerIndex = foundKey + 1
                                rangeToLower = false
                            }
                        }
                    } else {
                        break
                    }
                }
                if !found {
                    XCTAssert(false)
                }
            }
            self.stopMeasuring()
        })
    }
    
    func beginTestRangeAccessPerformance(compactValuesOnCreation: Bool) {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: compactValuesOnCreation)
        
        let valueBox = self.postbox!.valueBox
        let memory = malloc(250)!
        let value = MemoryBuffer(memory: memory, capacity: 250, length: 250, freeWhenDone: true)
        var keys: [ValueBoxKey] = []
        for _ in 0 ... 100000 {
            let key = ValueBoxKey(length: 16)
            arc4random_buf(key.memory, 16)
            keys.append(key)
            valueBox.set(table, key: key, value: value)
        }
        let upperBound = ValueBoxKey(length: 16)
        upperBound.setUInt32(0, value: UInt32.max)
        upperBound.setUInt32(4, value: UInt32.max)
        upperBound.setUInt32(8, value: UInt32.max)
        upperBound.setUInt32(12, value: UInt32.max)
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            self.startMeasuring()
            for key in keys.shuffled() {
                valueBox.range(table, start: key.prefix(12), end: upperBound, keys: { _ in
                    return false
                }, limit: 1)
                let _ = valueBox.get(table, key: key)
            }
            self.stopMeasuring()
        })
    }
    
    /*func addMessagesUpperBlock(_ messages: [(Int32, Int32)]) {
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
    }*/
}
