import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1
private let authorPeerId = PeerId(namespace: 1, id: 6)
private let peer = TestPeer(id: 6, data: "abc")

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

private class TestEmbeddedMedia: Media, CustomStringConvertible {
    var id: MediaId? { return nil }
    var peerIds: [PeerId] = []
    let data: String
    
    init(data: String) {
        self.data = data
    }
    
    required init(decoder: Decoder) {
        self.data = decoder.decodeStringForKey("s")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeString(self.data, forKey: "s")
    }
    
    func isEqual(_ other: Media) -> Bool {
        if let other = other as? TestEmbeddedMedia {
            return self.data == other.data
        }
        return false
    }
    
    var description: String {
        return "TestEmbeddedMedia(\(self.data))"
    }
}

private class TestExternalMedia: Media {
    let id: MediaId?
    var peerIds: [PeerId] = []
    let data: String
    
    init(id: Int64, data: String) {
        self.id = MediaId(namespace: namespace, id: id)
        self.data = data
    }
    
    required init(decoder: Decoder) {
        self.id = MediaId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i"))
        self.data = decoder.decodeStringForKey("s")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.id!.namespace, forKey: "i.n")
        encoder.encodeInt64(self.id!.id, forKey: "i.i")
        encoder.encodeString(self.data, forKey: "s")
    }
    
    func isEqual(_ other: Media) -> Bool {
        if let other = other as? TestExternalMedia {
            return self.id == other.id && self.data == other.data
        }
        return false
    }
    
    var description: String {
        return "TestExternalMedia(\(self.id!.id), \(self.data))"
    }
}

private class TestPeer: Peer {
    var indexName: PeerIndexNameRepresentation {
        return .title("Test")
    }

    let id: PeerId
    let data: String
    
    init(id: Int32, data: String) {
        self.id = PeerId(namespace: namespace, id: id)
        self.data = data
    }
    
    required init(decoder: Decoder) {
        self.id = PeerId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt32ForKey("i.i"))
        self.data = decoder.decodeStringForKey("s")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.id.namespace, forKey: "i.n")
        encoder.encodeInt32(self.id.id, forKey: "i.i")
        encoder.encodeString(self.data, forKey: "s")
    }
    
    func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TestPeer {
            return self.id == other.id && self.data == other.data
        }
        return false
    }
    
    var description: String {
        return "TestPeer(\(self.id.id), \(self.data))"
    }
}

private enum MediaEntry: Equatable {
    case Direct(Media, Int)
    case MessageReference(Int32)
    
    init(_ entry: DebugMediaEntry) {
        switch entry {
            case let .Direct(media, referenceCount):
                self = .Direct(media, referenceCount)
            case let .MessageReference(index):
                self = .MessageReference(index.id.id)
        }
    }
}

private func ==(lhs: MediaEntry, rhs: MediaEntry) -> Bool {
    switch lhs {
        case let .Direct(lhsMedia, lhsReferenceCount):
            switch rhs {
                case let .Direct(rhsMedia, rhsReferenceCount):
                    return lhsMedia.isEqual(rhsMedia) && lhsReferenceCount == rhsReferenceCount
                case .MessageReference:
                    return false
            }
        case let .MessageReference(lhsId):
            switch rhs {
                case .Direct:
                    return false
                case let .MessageReference(rhsId):
                    return lhsId == rhsId
            }
    }
}

private extension MessageTags {
    static let First = MessageTags(rawValue: 1 << 0)
    static let Second = MessageTags(rawValue: 1 << 1)
}

class MessageHistoryTableTests: XCTestCase {
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
    
    override class func setUp() {
        super.setUp()
        
        declareEncodable(TestEmbeddedMedia.self, f: {TestEmbeddedMedia(decoder: $0)})
        declareEncodable(TestExternalMedia.self, f: {TestExternalMedia(decoder: $0)})
        declareEncodable(TestPeer.self, f: {TestPeer(decoder: $0)})
    }
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
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
        self.peerTable = PeerTable(valueBox: self.valueBox!, tableId: 6)
        self.peerTable!.set(peer)
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
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    private func addMessage(_ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags = [], _ tags: MessageTags = []) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.addMessages([StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, flags: flags, tags: tags, forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media)], location: .Random, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }

    private func updateMessage(_ previousId: Int32, _ id: Int32, _ timestamp: Int32, _ text: String = "", _ media: [Media] = [], _ flags: StoreMessageFlags, _ tags: MessageTags) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.updateMessage(MessageId(peerId: peerId, namespace: namespace, id: previousId), message: StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, flags: flags, tags: tags, forwardInfo: nil, authorId: authorPeerId, text: text, attributes: [], media: media), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func addHole(_ id: Int32) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.addHoles([MessageId(peerId: peerId, namespace: namespace, id: id)], operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func removeMessages(_ ids: [Int32]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: peerId, namespace: namespace, id: $0) }), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func fillHole(_ id: Int32, _ fillType: HoleFill, _ messages: [(Int32, Int32, String, [Media])], _ tagMask: MessageTags? = nil) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        self.historyTable!.fillHole(MessageId(peerId: peerId, namespace: namespace, id: id), fillType: fillType, tagMask: tagMask, messages: messages.map({ StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: $0.0), timestamp: $0.1, flags: [], tags: [], forwardInfo: nil, authorId: authorPeerId, text: $0.2, attributes: [], media: $0.3) }), operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &unsentMessageOperations, updatedPeerReadStateOperations: &updatedPeerReadStateOperations)
    }
    
    private func expectEntries(_ entries: [Entry], tagMask: MessageTags? = nil) {
        var stableIds = Set<UInt32>()
        
        let list: [RenderedMessageHistoryEntry]
        if let tagMask = tagMask {
            list = self.historyTable!.debugList(tagMask, peerId: peerId, peerTable: self.peerTable!)
        } else {
            list = self.historyTable!.debugList(peerId, peerTable: self.peerTable!)
        }
        
        let actualEntries = list.map({ entry -> Entry in
            let stableId: UInt32
            switch entry {
                case let .RenderedMessage(message):
                    stableId = message.stableId
                    if let messagePeer = message.author {
                        if !peer.isEqual(messagePeer) {
                            XCTFail("Expected peer \(peer), actual: \(messagePeer)")
                        }
                    } else {
                        XCTFail("Expected peer \(peer), actual: nil")
                    }
                    if stableIds.contains(stableId) {
                        XCTFail("Stable id not unique \(stableId)")
                    } else {
                        stableIds.insert(stableId)
                    }
                    return .Message(message.id.id, message.timestamp, message.text, message.media, message.flags)
                case let .Hole(hole):
                    stableId = hole.stableId
                    if stableIds.contains(stableId) {
                        XCTFail("Stable id not unique \(stableId)")
                    } else {
                        stableIds.insert(stableId)
                    }
                    return .Hole(hole.min, hole.maxIndex.id.id, hole.maxIndex.timestamp)
            }
        })
        if actualEntries != entries {
            XCTFail("Expected\n\(entries)\nActual\n\(actualEntries)")
        }
    }
    
    private func expectUnsent(_ indices: [Int32]) {
        let actualUnsent = self.unsentTable!.get().map({ $0.id })
        var match = true
        if actualUnsent.count == indices.count {
            for i in 0 ..< indices.count {
                if indices[i] != actualUnsent[i] {
                    match = false
                    break
                }
            }
        } else {
            match = false
        }
        if !match {
            XCTFail("Expected\n\(indices)\nActual\n\(actualUnsent)")
        }
    }
    
    private func expectMedia(_ media: [MediaEntry]) {
        let actualMedia = self.mediaTable!.debugList().map({MediaEntry($0)})
        if media != actualMedia {
            XCTFail("Expected\n\(media)\nActual\n\(actualMedia)")
        }
    }
    
    private func expectCleanupMedia(_ media: [Media]) {
        let actualMedia = self.mediaCleanupTable!.debugList()
        var equal = true
        if media.count != actualMedia.count {
            equal = false
        } else {
            for i in 0 ..< media.count {
                if !media[i].isEqual(actualMedia[i]) {
                    equal = false
                    break
                }
            }
        }
        
        if !equal {
            XCTFail("Expected\n\(media)\nActual\n\(actualMedia)")
        }
    }
    
    func testInsertMessageIntoEmpty() {
        addMessage(100, 100, "t100")
        addMessage(200, 200, "t200")
        
        expectEntries([.Message(100, 100, "t100", [], []), .Message(200, 200, "t200", [], [])])
    }
    
    func testInsertMessageIgnoreOverwrite() {
        addMessage(100, 100, "t100")
        addMessage(100, 200, "t200")
        
        expectEntries([.Message(100, 100, "t100", [], [])])
    }
    
    func testInsertMessageWithEmbeddedMedia() {
        addMessage(100, 100, "t100", [TestEmbeddedMedia(data: "abc1")])
        
        expectEntries([.Message(100, 100, "t100", [TestEmbeddedMedia(data: "abc1")], [])])
        expectMedia([])
    }
    
    func testInsertMessageWithExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        
        expectEntries([.Message(100, 100, "t100", [media], [])])
        expectMedia([.MessageReference(100)])
    }
    
    func testUnembedExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media])
        
        expectEntries([.Message(100, 100, "t100", [media], []), .Message(200, 200, "t200", [media], [])])
        expectMedia([.Direct(media, 2)])
    }
    
    func testIgnoreOverrideExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        let media1 = TestExternalMedia(id: 10, data: "abc2")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media1])
        
        expectEntries([.Message(100, 100, "t100", [media], []), .Message(200, 200, "t200", [media], [])])
        expectMedia([.Direct(media, 2)])
    }
    
    func testRemoveSingleMessage() {
        addMessage(100, 100, "t100", [])
        
        removeMessages([100])
        
        expectEntries([])
        expectMedia([])
    }
    
    func testRemoveMessageWithEmbeddedMedia() {
        let media = TestEmbeddedMedia(data: "abc1")
        addMessage(100, 100, "t100", [media])
        self.removeMessages([100])
        
        expectEntries([])
        expectMedia([])
        expectCleanupMedia([media])
    }
    
    func testRemoveOnlyReferenceToExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        removeMessages([100])
        
        expectEntries([])
        expectMedia([])
        expectCleanupMedia([media])
    }
    
    func testRemoveReferenceToExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media])
        removeMessages([100])
        
        expectEntries([.Message(200, 200, "t200", [media], [])])
        expectMedia([.Direct(media, 1)])
        expectCleanupMedia([])
        
        removeMessages([200])
        
        expectEntries([])
        expectMedia([])
        expectCleanupMedia([media])
    }
    
    func testAddHoleToEmpty() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testAddHoleToFullHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        addHole(110)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testAddMessageToFullHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90, "m90")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageDividingUpperHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90, "m90")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
        addMessage(100, 100, "m100")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, 99, 100), .Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testAddMessageDividingLowerHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        addMessage(90, 90, "m90")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
        addMessage(80, 80, "m80")
        expectEntries([.Hole(1, 79, 80), .Message(80, 80, "m80", [], []), .Hole(81, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingUpperHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(90, 90, "m90")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
        addMessage(91, 91, "m91")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Message(91, 91, "m91", [], []), .Hole(92, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingLowerHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(90, 90, "m90")
        expectEntries([.Hole(1, 89, 90), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
        addMessage(89, 89, "m89")
        expectEntries([.Hole(1, 88, 89), .Message(89, 89, "m89", [], []), .Message(90, 90, "m90", [], []), .Hole(91, Int32.max, Int32.max)])
    }
    
    func testAddMessageOffsettingLeftmostHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(1, 1, "m1")
        
        expectEntries([.Message(1, 1, "m1", [], []), .Hole(2, Int32.max, Int32.max)])
    }
    
    func testAddMessageRemovingLefmostHole() {
        addHole(100)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        
        addMessage(2, 2, "m2")
        expectEntries([.Hole(1, 1, 2), .Message(2, 2, "m2", [], []), .Hole(3, Int32.max, Int32.max)])
        
        addMessage(1, 1, "m1")
        expectEntries([.Message(1, 1, "m1", [], []), .Message(2, 2, "m2", [], []), .Hole(3, Int32.max, Int32.max)])
    }
    
    func testAddHoleLowerThanMessage() {
        addMessage(100, 100, "m100")
        addHole(1)
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], [])])
    }
    
    func testAddHoleHigherThanMessage() {
        addMessage(100, 100, "m100")
        addHole(200)
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testIgnoreHigherHole() {
        addHole(200)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
        addHole(400)
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testIgnoreHigherHoleAfterMessage() {
        addMessage(100, 100, "m100")
        addHole(200)
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
        addHole(400)
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testAddHoleBetweenMessages() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        addHole(150)
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testFillHoleEmpty() {
        fillHole(1, HoleFill(complete: true, direction: .UpperToLower), [])
        expectEntries([])
    }
    
    func testFillHoleComplete() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: true, direction: .UpperToLower), [(100, 100, "m100", []), (200, 200, "m200", [])])
        expectEntries([.Message(100, 100, "m100", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testFillHoleUpperToLowerPartial() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .UpperToLower), [(100, 100, "m100", []), (200, 200, "m200", [])])
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testFillHoleUpperToLowerToBounds() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .UpperToLower), [(1, 1, "m1", []), (200, 200, "m200", [])])
        expectEntries([.Message(1, 1, "m1", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testFillHoleLowerToUpperToBounds() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .LowerToUpper), [(100, 100, "m100", []), (Int32.max, 200, "m200", [])])
        expectEntries([.Message(100, 100, "m100", [], []), .Message(Int32.max, 200, "m200", [], [])])
    }
    
    func testFillHoleLowerToUpperPartial() {
        addHole(100)
        
        fillHole(1, HoleFill(complete: false, direction: .LowerToUpper), [(100, 100, "m100", []), (200, 200, "m200", [])])
        expectEntries([.Message(100, 100, "m100", [], []), .Message(200, 200, "m200", [], []), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesUpperToLower() {
        addHole(1)
        
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower), [(150, 150, "m150", [])])
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Hole(101, 149, 150), .Message(150, 150, "m150", [], []), .Message(200, 200, "m200", [], []), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesLowerToUpper() {
        addHole(1)
        
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        
        fillHole(199, HoleFill(complete: false, direction: .LowerToUpper), [(150, 150, "m150", [])])
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Message(150, 150, "m150", [], []), .Hole(151, 199, 200), .Message(200, 200, "m200", [], []), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesComplete() {
        addHole(1)
        
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        
        fillHole(199, HoleFill(complete: true, direction: .UpperToLower), [(150, 150, "m150", [])])
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Message(150, 150, "m150", [], []), .Message(200, 200, "m200", [], []), .Hole(201, Int32.max, Int32.max)])
    }
    
    func testFillHoleBetweenMessagesWithMessage() {
        addMessage(200, 200, "m200")
        addMessage(202, 202, "m202")
        addHole(201)
        addMessage(201, 201, "m201")
        
        expectEntries([.Message(200, 200, "m200", [], []), .Message(201, 201, "m201", [], []), .Message(202, 202, "m202", [], [])])
    }
    
    func testFillHoleWithNoMessagesComplete() {
        addMessage(100, 100, "m100")
        addHole(1)
        
        fillHole(99, HoleFill(complete: true, direction: .UpperToLower), [])
        
        expectEntries([.Message(100, 100, "m100", [], [])])
    }
    
    func testFillHoleIgnoreOverMessage() {
        addMessage(100, 100, "m100")
        addMessage(101, 101, "m101")
        
        fillHole(100, HoleFill(complete: true, direction: .UpperToLower), [(90, 90, "m90", [])])
        
        expectEntries([.Message(90, 90, "m90", [], []), .Message(100, 100, "m100", [], []), .Message(101, 101, "m101", [], [])])
    }
    
    func testFillHoleWithOverflow() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower), [(150, 150, "m150", []), (300, 300, "m300", [])])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 149, 150), .Message(150, 150, "m150", [], []), .Message(200, 200, "m200", [], []), .Message(300, 300, "m300", [], [])])
    }
    
    func testIgnoreHoleOverMessageBetweenMessages() {
        addMessage(199, 199, "m199")
        addMessage(200, 200, "m200")
        addHole(200)
        
        expectEntries([.Message(199, 199, "m199", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testMergeHoleAfterDeletingMessage() {
        addMessage(100, 100, "m100")
        addHole(1)
        addHole(200)
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
        
        removeMessages([100])
        
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testMergeHoleLowerAfterDeletingMessage() {
        addMessage(100, 100, "m100")
        addHole(1)
        addMessage(200, 200, "m200")
        
        removeMessages([100])
        
        expectEntries([.Hole(1, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testMergeHoleUpperAfterDeletingMessage() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        addHole(300)
        
        removeMessages([200])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)])
    }
    
    func testExtendLowerHoleAfterDeletingMessage() {
        addMessage(100, 100, "m100")
        addHole(100)
        
        removeMessages([100])
        
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testExtendUpperHoleAfterDeletingMessage() {
        addMessage(100, 100, "m100")
        addHole(101)
        
        removeMessages([100])
        
        expectEntries([.Hole(1, Int32.max, Int32.max)])
    }
    
    func testDeleteMessageBelowMessage() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        removeMessages([100])
        
        expectEntries([.Message(200, 200, "m200", [], [])])
    }
    
    func testDeleteMessageAboveMessage() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        removeMessages([200])
        
        expectEntries([.Message(100, 100, "m100", [], [])])
    }
    
    func testDeleteMessageBetweenMessages() {
        addMessage(100, 100, "m100")
        addMessage(200, 200, "m200")
        addMessage(300, 300, "m300")
        removeMessages([200])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Message(300, 300, "m300", [], [])])
    }
    
    func testAddUnsent() {
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent])])
        expectUnsent([100])
    }
    
    func testRemoveUnsent() {
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent])])
        expectUnsent([100])
        
        removeMessages([100])
        expectEntries([])
        expectUnsent([])
    }
    
    func testUpdateUnsentToSentSameIndex() {
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent])])
        expectUnsent([100])
        
        updateMessage(100, 100, 100, "m100", [], [], [])
        expectEntries([.Message(100, 100, "m100", [], [])])
        expectUnsent([])
    }
    
    func testUpdateUnsentToFailed() {
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent])])
        expectUnsent([100])
        
        updateMessage(100, 100, 100, "m100", [], [.Unsent, .Failed], [])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent, .Failed])])
        expectUnsent([])
    }
    
    func testUpdateDifferentIndex() {
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Message(100, 100, "m100", [], [.Unsent])])
        expectUnsent([100])
        
        updateMessage(100, 200, 200, "m100", [], [], [])
        expectEntries([.Message(200, 200, "m100", [], [])])
        expectUnsent([])
    }
    
    func testUpdateDifferentIndexBreakHole() {
        addHole(1)
        
        addMessage(100, 100, "m100", [], [.Unsent])
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], [.Unsent]), .Hole(101, Int32.max, Int32.max)])
        expectUnsent([100])
        
        updateMessage(100, 200, 200, "m100", [], [], [])
        expectEntries([.Hole(1, 199, 200), .Message(200, 200, "m100", [], []), .Hole(201, Int32.max, Int32.max)])
        expectUnsent([])
    }
    
    func testInsertTaggedIntoEmpty() {
        addMessage(100, 100, "m100", [], [], MessageTags(rawValue: 1))
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: MessageTags(rawValue: 1))
    }
    
    func testInsertMultipleTagsIntoEmpty() {
        addMessage(200, 200, "m200", [], [], MessageTags(rawValue: 2))
        addMessage(100, 100, "m100", [], [], MessageTags(rawValue: 1 | 2))
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: MessageTags(rawValue: 1))
        expectEntries([.Message(100, 100, "m100", [], []), .Message(200, 200, "m200", [], [])], tagMask: MessageTags(rawValue: 2))
    }
    
    func testRemoveSingleTagged() {
        addMessage(100, 100, "m100", [], [], MessageTags(rawValue: 1))
        removeMessages([100])
        
        expectEntries([], tagMask: MessageTags(rawValue: 1))
    }
    
    func testRemoveMultipleTagged() {
        addMessage(200, 200, "m200", [], [], MessageTags(rawValue: 2))
        addMessage(100, 100, "m100", [], [], MessageTags(rawValue: 1 | 2))
        removeMessages([100])
        expectEntries([], tagMask: MessageTags(rawValue: 1))
        expectEntries([.Message(200, 200, "m200", [], [])], tagMask: MessageTags(rawValue: 2))
    }
    
    func testTagsInsertHoleIntoEmpty() {
        addHole(1)
        expectEntries([.Hole(1, Int32.max, Int32.max)], tagMask: [.First])
        expectEntries([.Hole(1, Int32.max, Int32.max)], tagMask: [.Second])
    }
    
    func testTagsBreakHoleWithMessage() {
        addHole(1)
        addMessage(100, 100, "m100", [], [], [.First])
        
        expectEntries([.Hole(1, 99, 100), .Message(100, 100, "m100", [], []), .Hole(101, Int32.max, Int32.max)], tagMask: [.First])
        expectEntries([.Hole(1, 99, 100), .Hole(101, Int32.max, Int32.max)], tagMask: [.Second])
    }
    
    func testTagsFillHoleUpperToLowerAllTags() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower), [(180, 180, "m180", [])])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180)], tagMask: [.First])
        expectEntries([.Hole(101, 179, 180), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180), .Message(180, 180, "m180", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleLowerToUpperAllTags() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .LowerToUpper), [(180, 180, "m180", [])])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(181, 199, 200)], tagMask: [.First])
        expectEntries([.Hole(181, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Message(180, 180, "m180", [], []), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleCompleteAllTags() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: true, direction: .UpperToLower), [(180, 180, "m180", [])])
        
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: [.First])
        expectEntries([.Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Message(180, 180, "m180", [], []), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleUpperToLowerSingleTagWithMessages() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower), [(180, 180, "m180", [])], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180)], tagMask: [.First])
        expectEntries([.Hole(101, 179, 180), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180), .Message(180, 180, "m180", [], []), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleLowerToUpperSingleTagWithMessages() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .LowerToUpper), [(180, 180, "m180", [])], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(181, 199, 200)], tagMask: [.First])
        expectEntries([.Hole(101, 179, 180), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180), .Message(180, 180, "m180", [], []), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleCompleteSingleTagWithMessages() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: true, direction: .UpperToLower), [(180, 180, "m180", [])], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: [.First])
        expectEntries([.Hole(101, 179, 180), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 179, 180), .Message(180, 180, "m180", [], []), .Hole(181, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleUpperToLowerSingleTagWithEmpty() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .UpperToLower), [], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: [.First])
        expectEntries([.Hole(101, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleLowerToUpperSingleTagWithEmpty() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: false, direction: .LowerToUpper), [], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: [.First])
        expectEntries([.Hole(101, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 199, 200), .Message(200, 200, "m200", [], [])])
    }
    
    func testTagsFillHoleCompleteSingleTagWithEmpty() {
        addMessage(100, 100, "m100", [], [], [.First])
        addMessage(200, 200, "m200", [], [], [.Second])
        addHole(150)
        
        fillHole(199, HoleFill(complete: true, direction: .UpperToLower), [], [.First])
        
        expectEntries([.Message(100, 100, "m100", [], [])], tagMask: [.First])
        expectEntries([.Hole(101, 199, 200), .Message(200, 200, "m200", [], [])], tagMask: [.Second])
        expectEntries([.Message(100, 100, "m100", [], []), .Hole(101, 199, 200), .Message(200, 200, "m200", [], [])])
    }
}
