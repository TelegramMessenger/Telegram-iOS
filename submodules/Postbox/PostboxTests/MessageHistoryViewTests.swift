import Foundation

import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1

private func extract(from array: [Int32], aroundIndex: Int, halfLimit: Int) -> [Int32] {
    var lower: [Int32] = []
    var higher: [Int32] = []
    
    var i = aroundIndex
    while i >= 0 && lower.count < halfLimit {
        lower.append(array[i])
        i -= 1
    }
    
    var j = aroundIndex + 1
    while j < array.count && higher.count < halfLimit {
        higher.append(array[j])
        j += 1
    }
    
    var result: [Int32] = []
    result.append(contentsOf: lower.reversed())
    result.append(contentsOf: higher)
    
    assert(result.count <= halfLimit * 2)
    
    return result
}

class MessageHistoryViewTests: XCTestCase {
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
        
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue(), encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: randomKey)!, salt: ValueBoxEncryptionParameters.Salt(data: randomSalt)!), upgradeProgress: { _ in }, inMemory: true)
        
        let messageHoles: [PeerId.Namespace: [MessageId.Namespace: Set<MessageTags>]] = [
            peerId.namespace: [:
            //    namespace: Set([.media])
            ]
        ]
        
        let seedConfiguration = SeedConfiguration(globalMessageIdsPeerIdNamespaces: Set(), initializeChatListWithHole: (topLevel: nil, groups: nil), messageHoles: messageHoles, existingMessageTags: [], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil, messageNamespacesRequiringGroupStatsValidation: Set(), chatMessagesNamespaces: Set())
        
        self.postbox = Postbox(queue: Queue.mainQueue(), basePath: path!, seedConfiguration: seedConfiguration, valueBox: self.valueBox!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.postbox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    private func addHole(_ range: ClosedRange<Int32>, space: MessageHistoryHoleSpace) {
        let _ = self.postbox!.transaction({ transaction -> Void in
            transaction.addHole(peerId: peerId, namespace: namespace, space: .everywhere, range: range)
        }).start()
    }
    
    private func removeHole(_ range: ClosedRange<Int32>, space: MessageHistoryHoleSpace) {
        let _ = self.postbox!.transaction({ transaction -> Void in
            transaction.removeHole(peerId: peerId, namespace: namespace, space: .everywhere, range: range)
        }).start()
    }
    
    private func addMessage(_ id: Int32, _ timestamp: Int32, _ groupingKey: Int64? = nil) -> UInt32 {
        var stableId: UInt32?
        let _ = self.postbox!.transaction({ transaction -> Void in
            let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
            let _ = transaction.addMessages([StoreMessage(id: messageId, globallyUniqueId: nil, groupingKey: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "", attributes: [], media: [])], location: .Random)
            stableId = transaction.getMessage(messageId)!.stableId
        }).start()
        return stableId!
    }
    
    private func removeMessage(_ id: Int32) {
        let _ = self.postbox!.transaction({ transaction -> Void in
            transaction.deleteMessages([MessageId(peerId: peerId, namespace: namespace, id: id)])
        }).start()
    }
    
    private func removeAllMessages() {
        let _ = self.postbox!.transaction({ transaction -> Void in
            transaction.deleteMessagesInRange(peerId: peerId, namespace: namespace, minId: 1, maxId: Int32.max)
        }).start()
    }
    
    func testEmpty() {
        let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .upperBound, tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        switch state {
            case let .loaded(loadedState):
                let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                assert(entries.isEmpty)
            case .loading:
                XCTAssert(false)
        }
    }
    
    func testFixed() {
        var testIds: [MessageId.Id] = []
        for i in 1 ..< 11 {
            testIds.append(Int32(i * 10))
            let _ = addMessage(Int32(i * 10), Int32(i * 10))
        }
        for i in 3 ... testIds.count + 10 {
            let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .upperBound, tag: nil, statistics: [], halfLimit: i, locations: .single(peerId))
            switch state {
                case let .loaded(loadedState):
                    let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                    let ids = entries.map({ $0.message.id.id })
                    let clippedTestIds: [Int32]
                    if i >= testIds.count {
                        clippedTestIds = testIds
                    } else {
                        clippedTestIds = Array(testIds.dropFirst(testIds.count - i))
                    }
                    assert(ids == clippedTestIds)
                case .loading:
                    XCTAssert(false)
            }
        }
        for i in 3 ... testIds.count + 10 {
            let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .lowerBound, tag: nil, statistics: [], halfLimit: i, locations: .single(peerId))
            switch state {
                case let .loaded(loadedState):
                    let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                    let ids = entries.map({ $0.message.id.id })
                    let clippedTestIds: [Int32]
                    if i >= testIds.count {
                        clippedTestIds = testIds
                    } else {
                        clippedTestIds = Array(testIds.dropLast(testIds.count - i))
                    }
                    assert(ids == clippedTestIds)
                case .loading:
                    XCTAssert(false)
            }
        }
        for i in 3 ... testIds.count + 10 {
            for j in testIds[0] - 10 ... testIds.last! + 10 {
                let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32(j)), timestamp: Int32(j))), tag: nil, statistics: [], halfLimit: i, locations: .single(peerId))
                
                let clippedTestIds: [Int32]
                if let index = testIds.firstIndex(where: { $0 > Int32(j) }), index >= 0 {
                    clippedTestIds = extract(from: testIds, aroundIndex: index - 1, halfLimit: i)
                } else {
                    if i >= testIds.count {
                        clippedTestIds = testIds
                    } else {
                        clippedTestIds = Array(testIds.dropFirst(testIds.count - i))
                    }
                }
                
                switch state {
                    case let .loaded(loadedState):
                        let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                        let ids = entries.map({ $0.message.id.id })
                        assert(ids == clippedTestIds)
                    case .loading:
                        XCTAssert(false)
                }
            }
        }
    }
    
    func testDynamicAdd() {
        var randomOperations: [Int32] = []
        
        randomOperations = [100, 74, 83, 22, 32, 16, 25, 35, 15, 117, 81, 115, 33, 59, 10, 67, 91, 70, 24, 97, 77, 49, 89, 51, 116, 110, 86, 57, 13, 104, 112, 26, 31, 79, 29, 90, 18, 92, 93, 105, 52, 80, 78, 55, 14, 37, 30, 101, 88, 41, 94, 65, 19, 96, 102, 48, 21, 28, 47, 54, 85, 42, 72, 38, 45, 87, 58, 27, 106, 43, 34, 40, 98, 50, 84, 82, 75, 56, 53, 68, 69, 36, 119, 76, 17, 107, 46, 61, 12, 114, 95, 60, 99, 64, 23, 63, 44, 118, 111, 71, 113, 109, 62, 103, 66, 20, 73, 108, 11]
        
        if randomOperations.isEmpty {
            for _ in 0 ..< 500 {
                let insertId = Int32(10 + arc4random_uniform(110))
                if !randomOperations.contains(insertId) {
                    randomOperations.append(insertId)
                }
            }
            print("randomOperations = \(randomOperations)")
        }
        
        let sequentialForwardOperations: [Int32] = Array((10 ... 110).map({ Int32($0) }))
        let sequentialBackwardOperations: [Int32] = Array(sequentialForwardOperations.reversed())
        
        var shuffledOperations: [Int32] = []
        
        shuffledOperations = [88, 27, 41, 43, 53, 90, 110, 55, 65, 75, 69, 35, 54, 66, 16, 89, 98, 52, 23, 51, 30, 81, 76, 93, 58, 101, 10, 86, 34, 95, 91, 26, 42, 20, 107, 11, 64, 21, 63, 82, 67, 39, 70, 72, 25, 48, 79, 94, 106, 103, 56, 60, 59, 47, 68, 18, 38, 71, 29, 108, 33, 12, 17, 92, 84, 50, 32, 99, 37, 96, 46, 36, 61, 28, 19, 109, 45, 24, 87, 49, 97, 14, 78, 73, 104, 31, 57, 62, 22, 13, 80, 85, 100, 15, 83, 102, 40, 105, 74, 44, 77]
        
        if shuffledOperations.isEmpty {
            shuffledOperations = Array(sequentialForwardOperations.shuffled())
            print("shuffledOperations = \(shuffledOperations)")
        }
        
        let operationSets: [[Int32]] = [
            sequentialForwardOperations,
            sequentialBackwardOperations,
            shuffledOperations,
            randomOperations
        ]
        
        for operationSetIndex in 0 ..< operationSets.count {
            let operations = operationSets[operationSetIndex]
            for halfLimit in [3, 4, 5, 6, 7, 200] {
                for position in 10 ... 110 {
                    removeAllMessages()
                    
                    var testIds: [MessageId.Id] = []
                    let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32(position)), timestamp: Int32(position))), tag: nil, statistics: [], halfLimit: halfLimit, locations: .single(peerId))
                    switch state {
                        case let .loaded(loadedState):
                            for operationIndex in 0 ..< operations.count {
                                let insertId = operations[operationIndex]
                                if !testIds.contains(insertId) {
                                    testIds.append(insertId)
                                    testIds.sort()
                                } else {
                                    assertionFailure()
                                }
                                
                                let attributesData = ReadBuffer(data: Data())
                                
                                let stableId = addMessage(Int32(insertId), Int32(insertId))
                                let _ = loadedState.add(entry: .IntermediateMessageEntry(IntermediateMessage(stableId: stableId, stableVersion: 0, id: MessageId(peerId: peerId, namespace: namespace, id: insertId), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: insertId, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "", attributesData: attributesData, embeddedMediaData: attributesData, referencedMedia: []), nil, nil))
                                
                                let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                                let ids = entries.map({ $0.message.id.id })
                                
                                let clippedTestIds: [Int32]
                                if let index = testIds.firstIndex(where: { $0 > Int32(position) }), index >= 0 {
                                    clippedTestIds = extract(from: testIds, aroundIndex: index - 1, halfLimit: halfLimit)
                                } else {
                                    if halfLimit >= testIds.count {
                                        clippedTestIds = testIds
                                    } else {
                                        clippedTestIds = Array(testIds.dropFirst(testIds.count - halfLimit))
                                    }
                                }
                                
                                XCTAssert(ids == clippedTestIds, "\(ids) != \(clippedTestIds)")
                            }
                        case .loading:
                            XCTAssert(false)
                    }
                }
            }
        }
    }
    
    func testDynamicRemove() {
        var randomOperations: [(Int32, Bool)] = []
        
        randomOperations = [(78, true), (31, true), (50, true), (110, true), (50, false), (37, true), (26, true), (104, true), (31, false), (108, true), (26, false), (104, false), (108, false), (37, false), (78, false), (110, false), (31, true), (40, true), (90, true), (54, true), (22, true), (54, false), (46, true), (46, false), (23, true), (15, true), (109, true), (75, true), (75, false), (23, false), (109, false), (90, false), (22, false), (105, true), (39, true), (39, false), (31, false), (15, false), (105, false), (55, true), (91, true), (55, false), (68, true), (91, false), (68, false), (73, true), (64, true), (77, true), (77, false), (98, true), (41, true), (80, true), (63, true), (41, false), (61, true), (61, false), (63, false), (40, false), (17, true), (80, false), (117, true), (11, true), (113, true), (30, true), (109, true), (44, true), (93, true), (17, false), (93, false), (71, true), (104, true), (66, true), (11, false), (94, true), (74, true), (114, true), (92, true), (114, false), (117, false), (23, true), (83, true), (98, false), (42, true), (103, true), (51, true), (104, false), (64, false), (30, false), (15, true), (66, false), (60, true), (22, true), (72, true), (73, false), (48, true), (74, false), (54, true), (10, true), (83, false), (39, true), (99, true), (61, true), (40, true), (48, false), (103, false), (73, true), (10, false), (105, true), (68, true), (83, true), (39, false), (92, false), (73, false), (94, false), (54, false), (111, true), (60, false), (74, true), (109, false), (41, true), (72, false), (94, true), (117, true), (61, false), (74, false), (62, true), (22, false), (71, false), (38, true), (101, true), (53, true), (59, true), (42, false), (22, true), (66, true), (38, false), (40, false), (60, true), (114, true), (62, false), (101, false), (111, false), (99, false), (94, false), (34, true), (97, true), (63, true), (45, true), (34, false), (92, true), (14, true), (59, false), (92, false), (117, false), (114, false), (89, true), (45, false), (83, false), (76, true), (15, false), (76, false), (113, false), (118, true), (53, false), (116, true), (51, false), (116, false), (25, true), (89, false), (14, false), (22, false), (90, true), (78, true), (68, false), (47, true), (36, true), (23, false), (25, false), (60, false), (118, false), (25, true), (56, true), (52, true), (63, false), (107, true), (66, false), (56, false), (13, true), (36, false), (41, false), (112, true), (112, false), (97, false), (13, false), (90, false), (25, false), (47, false), (23, true), (107, false), (105, false), (23, false), (44, false), (52, false), (93, true), (60, true), (53, true), (60, false), (78, false), (57, true), (57, false), (93, false), (53, false), (17, true), (50, true), (80, true), (35, true), (116, true), (116, false), (35, false), (29, true), (43, true), (43, false), (49, true), (80, false), (106, true), (62, true), (29, false), (32, true), (31, true), (75, true), (66, true), (42, true), (31, false), (107, true), (46, true), (19, true), (50, false), (20, true), (46, false), (42, false), (107, false), (13, true), (33, true), (17, false), (103, true), (32, false), (49, false), (96, true), (19, false), (25, true), (96, false), (86, true), (26, true), (86, false), (25, false), (103, false), (66, false), (106, false), (75, false), (65, true), (33, false), (103, true), (26, false), (75, true), (62, false), (75, false), (13, false), (65, false), (103, false), (50, true), (52, true), (116, true), (51, true), (53, true), (52, false), (53, false), (102, true), (116, false), (102, false), (50, false), (62, true), (13, true), (35, true), (20, false), (15, true), (18, true), (19, true), (22, true), (29, true), (62, false), (29, false), (15, false), (35, false), (18, false), (63, true), (14, true), (102, true), (102, false), (94, true), (19, false), (117, true), (87, true), (94, false), (63, false), (94, true), (13, false), (51, false), (94, false), (103, true), (103, false), (87, false), (20, true), (18, true), (87, true), (101, true), (101, false), (14, false), (87, false), (20, false), (22, false), (18, false), (82, true), (28, true), (117, false), (28, false), (93, true), (97, true), (82, false), (86, true), (97, false), (110, true), (86, false), (79, true), (110, false), (101, true), (103, true), (12, true), (35, true), (79, false), (12, false), (93, false), (103, false), (39, true), (11, true), (10, true), (33, true), (35, false), (61, true), (59, true), (55, true), (66, true), (41, true), (61, false), (39, false), (35, true), (55, false), (41, false), (83, true), (119, true), (51, true), (70, true), (98, true), (47, true), (41, true), (11, false), (83, false), (10, false), (70, false), (49, true), (49, false), (33, false), (63, true), (41, false), (59, false), (79, true), (24, true), (58, true), (111, true), (54, true), (119, false), (99, true), (53, true), (51, false), (98, false), (79, false), (35, false), (28, true), (53, false), (47, false), (97, true), (66, false), (67, true), (54, false), (106, true), (24, false), (48, true), (32, true), (111, false), (106, false), (59, true), (18, true), (48, false), (38, true), (101, false), (32, false), (63, false), (58, false), (34, true), (44, true), (67, false), (76, true), (34, false), (74, true), (74, false), (99, false), (75, true), (100, true), (32, true), (35, true), (100, false), (95, true), (119, true), (76, false), (45, true), (38, false), (18, false), (67, true), (24, true), (26, true), (13, true), (35, false), (76, true), (45, false), (50, true), (24, false), (79, true), (79, false), (67, false), (29, true), (28, false), (13, false), (50, false), (68, true), (83, true), (89, true), (25, true), (95, false), (97, false), (80, true), (68, false), (43, true), (44, false), (103, true), (76, false), (89, false), (98, true), (116, true), (32, false), (119, false), (80, false), (114, true), (26, false), (75, false), (45, true), (114, false), (107, true), (116, false), (25, false), (58, true), (83, false), (58, false), (29, false), (45, false), (60, true), (98, false), (103, false), (60, false), (43, false), (34, true), (34, false)]
        
        if randomOperations.isEmpty {
            var currentIds: [Int32] = []
            for _ in 0 ..< 500 {
                let isAdd = arc4random_uniform(10) < 5
                if isAdd || currentIds.isEmpty {
                    let insertId = Int32(10 + arc4random_uniform(110))
                    if !currentIds.contains(insertId) {
                        currentIds.append(insertId)
                        currentIds.sort()
                        randomOperations.append((insertId, true))
                    }
                } else {
                    let removeIndex = Int(arc4random_uniform(UInt32(currentIds.count)))
                    randomOperations.append((currentIds[removeIndex], false))
                    currentIds.remove(at: removeIndex)
                }
            }
            print("randomOperations = \(randomOperations)")
        }
        
        let operationSets: [[(Int32, Bool)]] = [
            randomOperations
        ]
        
        for operationSetIndex in 0 ..< operationSets.count {
            let operations = operationSets[operationSetIndex]
            for halfLimit in [3, 4, 5, 6, 7, 200] {
                for position in 10 ... 110 {
                    removeAllMessages()
                    
                    var testIds: [MessageId.Id] = []
                    let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: namespace, id: Int32(position)), timestamp: Int32(position))), tag: nil, statistics: [], halfLimit: halfLimit, locations: .single(peerId))
                    switch state {
                    case let .loaded(loadedState):
                        for operationIndex in 0 ..< operations.count {
                            let (itemId, isAdd) = operations[operationIndex]
                            if isAdd {
                                if !testIds.contains(itemId) {
                                    testIds.append(itemId)
                                    testIds.sort()
                                } else {
                                    assertionFailure()
                                }
                            } else {
                                if let currentIndex = testIds.firstIndex(of: itemId) {
                                    testIds.remove(at: currentIndex)
                                } else {
                                    assertionFailure()
                                }
                            }
                            
                            let messageId = MessageId(peerId: peerId, namespace: namespace, id: itemId)
                            if isAdd {
                                let stableId = addMessage(Int32(itemId), Int32(itemId))
                                let attributesData = ReadBuffer(data: Data())
                                let _ = loadedState.add(entry: .IntermediateMessageEntry(IntermediateMessage(stableId: stableId, stableVersion: 0, id: messageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: itemId, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "", attributesData: attributesData, embeddedMediaData: attributesData, referencedMedia: []), nil, nil))
                            } else {
                                removeMessage(itemId)
                                let _ = loadedState.remove(index: MessageIndex(id: messageId, timestamp: itemId))
                            }
                            
                            let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                            let ids = entries.map({ $0.message.id.id })
                            
                            let clippedTestIds: [Int32]
                            if let index = testIds.firstIndex(where: { $0 > Int32(position) }), index >= 0 {
                                clippedTestIds = extract(from: testIds, aroundIndex: index - 1, halfLimit: halfLimit)
                            } else {
                                if halfLimit >= testIds.count {
                                    clippedTestIds = testIds
                                } else {
                                    clippedTestIds = Array(testIds.dropFirst(testIds.count - halfLimit))
                                }
                            }
                            
                            XCTAssert(ids == clippedTestIds, "\(ids) != \(clippedTestIds)")
                        }
                    case .loading:
                        XCTAssert(false)
                    }
                }
            }
        }
    }
    
    func testLoadInitialHole() {
        addHole(1 ... 1000, space: .everywhere)
        var state = HistoryViewState(postbox: self.postbox!, inputAnchor: .message(MessageId(peerId: peerId, namespace: namespace, id: Int32(100))), tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        switch state {
            case .loaded:
                XCTAssert(false)
            case let .loading(loadingState):
                let sampledResult = loadingState.checkAndSample(postbox: self.postbox!)
                switch sampledResult {
                    case .ready:
                        XCTAssert(false)
                    case let .loadHole(holePeerId, holeNamespace, holeTags, holeAroundId):
                        XCTAssert(holePeerId == peerId)
                        XCTAssert(holeNamespace == namespace)
                        XCTAssert(holeTags == nil)
                        XCTAssert(holeAroundId == 100)
                    
                        removeHole(20 ... 110, space: .everywhere)
                        let _ = loadingState.removeHole(space: PeerIdAndNamespace(peerId: peerId, namespace: namespace), range: 20 ... 110)
                        state = .loading(loadingState)
                }
        }
        
        switch state {
            case .loaded:
                XCTAssert(false)
            case let .loading(loadingState):
                let sampledResult = loadingState.checkAndSample(postbox: self.postbox!)
                switch sampledResult {
                    case let .ready(anchor, holes):
                        switch anchor {
                            case .upperBound:
                                break
                            default:
                                XCTAssert(false)
                        }
                        state = .loaded(HistoryViewLoadedState(anchor: anchor, tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId), postbox: self.postbox!, holes: holes))
                    case .loadHole:
                        XCTAssert(false)
                }
        }
        
        switch state {
            case let .loaded(loadedState):
                let entries = loadedState.completeAndSample(postbox: self.postbox!).entries
                XCTAssert(entries.isEmpty)
            case .loading:
                XCTAssert(false)
        }
    }
    
    func testEdgeHoles1() {
        let _ = addMessage(100, 100)
        let _ = addMessage(200, 200)
        let _ = addMessage(300, 300)
        
        addHole(1 ... 100, space: .everywhere)
        
        let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .upperBound, tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        guard case let .loaded(loadedState) = state else {
            XCTAssert(false)
            return
        }
        let sampledState = loadedState.completeAndSample(postbox: self.postbox!)
        let ids = sampledState.entries.map({ $0.message.id.id })
        XCTAssert(ids == [200, 300])
        XCTAssert(sampledState.hole == SampledHistoryViewHole(peerId: peerId, namespace: namespace, tag: nil, indices: IndexSet(integersIn: 1 ... 100), startId: 100, endId: 1))
        XCTAssert(sampledState.holesToHigher == false)
        XCTAssert(sampledState.holesToLower == true)
    }
    
    func testEdgeHoles2() {
        let _ = addMessage(100, 100)
        let _ = addMessage(200, 200)
        let _ = addMessage(300, 300)
        
        addHole(1 ... 99, space: .everywhere)
        
        let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .upperBound, tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        guard case let .loaded(loadedState) = state else {
            XCTAssert(false)
            return
        }
        let sampledState = loadedState.completeAndSample(postbox: self.postbox!)
        let ids = sampledState.entries.map({ $0.message.id.id })
        XCTAssert(ids == [100, 200, 300])
        XCTAssert(sampledState.hole == SampledHistoryViewHole(peerId: peerId, namespace: namespace, tag: nil, indices: IndexSet(integersIn: 1 ... 99), startId: 99, endId: 1))
        XCTAssert(sampledState.holesToHigher == false)
        XCTAssert(sampledState.holesToLower == false)
    }
    
    func testEdgeHoles3() {
        let _ = addMessage(100, 100)
        let _ = addMessage(200, 200)
        let _ = addMessage(300, 300)
        
        addHole(300 ... 400, space: .everywhere)
        
        let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .upperBound, tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        guard case let .loaded(loadedState) = state else {
            XCTAssert(false)
            return
        }
        let sampledState = loadedState.completeAndSample(postbox: self.postbox!)
        let ids = sampledState.entries.map({ $0.message.id.id })
        XCTAssert(ids == [])
        XCTAssert(sampledState.hole == SampledHistoryViewHole(peerId: peerId, namespace: namespace, tag: nil, indices: IndexSet(integersIn: 300 ... 400), startId: 400, endId: 1))
        XCTAssert(sampledState.holesToHigher == false)
        XCTAssert(sampledState.holesToLower == true)
    }
    
    func testEdgeHoles4() {
        let _ = addMessage(100, 100)
        let _ = addMessage(200, 200)
        let _ = addMessage(300, 300)
        
        addHole(300 ... 400, space: .everywhere)
        
        let state = HistoryViewState(postbox: self.postbox!, inputAnchor: .message(MessageId(peerId: peerId, namespace: namespace, id: 200)), tag: nil, statistics: [], halfLimit: 10, locations: .single(peerId))
        guard case let .loaded(loadedState) = state else {
            XCTAssert(false)
            return
        }
        let sampledState = loadedState.completeAndSample(postbox: self.postbox!)
        let ids = sampledState.entries.map({ $0.message.id.id })
        XCTAssert(ids == [100, 200])
        XCTAssert(sampledState.hole == SampledHistoryViewHole(peerId: peerId, namespace: namespace, tag: nil, indices: IndexSet(integersIn: 300 ... 400), startId: 300, endId: Int32.max - 1))
        XCTAssert(sampledState.holesToHigher == true)
        XCTAssert(sampledState.holesToLower == false)
    }
}
