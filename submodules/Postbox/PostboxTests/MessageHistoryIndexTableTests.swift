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
    var valueBox: SqliteValueBox?
    var path: String?
    
    var postbox: Postbox?
    
    override func setUp() {
        super.setUp()
        
        self.continueAfterFailure = false
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        
        var randomKey = Data(count: 32)
        randomKey.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<Int8>) -> Void in
            arc4random_buf(bytes, 32)
        })
        var randomSalt = Data(count: 16)
        randomSalt.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<Int8>) -> Void in
            arc4random_buf(bytes, 16)
        })
        
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue(), encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: true, key: ValueBoxEncryptionParameters.Key(data: randomKey)!, salt: ValueBoxEncryptionParameters.Salt(data: randomSalt)!), upgradeProgress: { _ in })
        
        let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [
            peerId.namespace: [
                namespace: Set([.media])
            ]
        ]
        
        let seedConfiguration = SeedConfiguration(globalMessageIdsPeerIdNamespaces: Set(), initializeChatListWithHole: (topLevel: nil, groups: nil), messageHoles: messageHoles, existingMessageTags: [.media], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil, messageNamespacesRequiringGroupStatsValidation: Set(), chatMessagesNamespaces: Set())
        
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
                verificationSet.insert(integersIn: 1 ... Int(Int32.max - 1))
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
                everywhereVerificationSet.insert(integersIn: 1 ... Int(Int32.max - 1))
                mediaVerificationSet.insert(integersIn: 1 ... Int(Int32.max - 1))
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
    
    func _testDirectAccessPerformance() {
        self.beginTestDirectAccessPerformance(compactValuesOnCreation: false)
    }
    
    func _testDirectAccessPerformanceCompact() {
        self.beginTestDirectAccessPerformance(compactValuesOnCreation: true)
    }
    
    func _testBlobExtractPerformance() {
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
    
    func _testIncrementalBlobExtractPerformance() {
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
    
    func _testBlobUpdatePerformance() {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: false)
        
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
            let buffer = WriteBuffer()
            self.startMeasuring()
            for key in keys.shuffled() {
                if let value = valueBox.get(table, key: key) {
                    var output: Int32 = 0
                    value.read(&output, offset: 0, length: 4)
                    output += 1
                    buffer.reset()
                    buffer.write(&output, offset: 0, length: 4)
                    valueBox.set(table, key: key, value: buffer)
                }
            }
            self.stopMeasuring()
        })
    }
    
    func _testBlobIncrementalUpdatePerformance() {
        let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: false)
        
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
                valueBox.readWrite(table, key: key, { size, read, write in
                    var output: Int32 = 0
                    read(&output, 0, 4)
                    output += 1
                    write(&output, 0, 4)
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
    
    func _testDirectWritePerformance() {
        self.beginTestDirectWritePerformance(compactValuesOnCreation: false)
    }
    
    func _testDirectWritePerformanceCompact() {
        self.beginTestDirectWritePerformance(compactValuesOnCreation: true)
    }
    
    private func beginTestDirectWritePerformance(compactValuesOnCreation: Bool) {
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false, for: {
            let table = ValueBoxTable(id: 1000, keyType: .binary, compactValuesOnCreation: compactValuesOnCreation)
            let valueBox = self.postbox!.valueBox
            
            self.startMeasuring()
            
            let memory = malloc(4)!
            let value = MemoryBuffer(memory: memory, capacity: 4, length: 4, freeWhenDone: true)
            var keys: [ValueBoxKey] = []
            for _ in 0 ... 40000 {
                let key = ValueBoxKey(length: 16)
                arc4random_buf(key.memory, 16)
                keys.append(key)
                valueBox.set(table, key: key, value: value)
            }
            for key in keys.shuffled() {
                let _ = valueBox.get(table, key: key)
            }
            self.stopMeasuring()
            
            valueBox.removeAllFromTable(table)
        })
    }
    
    func _testRangeAccessPerformance() {
        self.beginTestRangeAccessPerformance(compactValuesOnCreation: false)
    }
    
    func _testRangeAccessPerformanceCompact() {
        self.beginTestRangeAccessPerformance(compactValuesOnCreation: true)
    }
    
    func _testBinarySearchAccessPerformance() {
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
}
