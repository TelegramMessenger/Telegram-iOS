import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1

private func ==(lhs: (Int32, Int32, String, [Media]), rhs: (Int32, Int32, String, [Media])) -> Bool {
    if lhs.3.count != rhs.3.count {
        return false
    }
    for i in 0 ..< lhs.3.count {
        if !lhs.3[i].isEqual(rhs.3[i]) {
            return false
        }
    }
    return lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2
}

private class TestEmbeddedMedia: Media, CustomStringConvertible {
    var id: MediaId? { return nil }
    let data: String
    
    init(data: String) {
        self.data = data
    }
    
    required init(decoder: Decoder) {
        self.data = decoder.decodeStringForKey("s")
    }
    
    func encode(encoder: Encoder) {
        encoder.encodeString(self.data, forKey: "s")
    }
    
    func isEqual(other: Media) -> Bool {
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
    let data: String
    
    init(id: Int64, data: String) {
        self.id = MediaId(namespace: namespace, id: id)
        self.data = data
    }
    
    required init(decoder: Decoder) {
        self.id = MediaId(namespace: decoder.decodeInt32ForKey("i.n"), id: decoder.decodeInt64ForKey("i.i"))
        self.data = decoder.decodeStringForKey("s")
    }
    
    func encode(encoder: Encoder) {
        encoder.encodeInt32(self.id!.namespace, forKey: "i.n")
        encoder.encodeInt64(self.id!.id, forKey: "i.i")
        encoder.encodeString(self.data, forKey: "s")
    }
    
    func isEqual(other: Media) -> Bool {
        if let other = other as? TestExternalMedia {
            return self.id == other.id && self.data == other.data
        }
        return false
    }
    
    var description: String {
        return "TestExternalMedia(\(self.id!.id), \(self.data))"
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
                self = MessageReference(index.id.id)
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

class MessageHistoryTableTests: XCTestCase {
    var valueBox: ValueBox?
    var path: String?
    
    var indexTable: MessageHistoryIndexTable?
    var mediaTable: MessageMediaTable?
    var mediaCleanupTable: MediaCleanupTable?
    var historyTable: MessageHistoryTable?
    
    override class func setUp() {
        super.setUp()
        
        declareEncodable(TestEmbeddedMedia.self, f: {TestEmbeddedMedia(decoder: $0)})
        declareEncodable(TestExternalMedia.self, f: {TestExternalMedia(decoder: $0)})
    }
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory().stringByAppendingString("\(randomId)")
        self.valueBox = SqliteValueBox(basePath: path!)
        
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, tableId: 1)
        self.mediaCleanupTable = MediaCleanupTable(valueBox: self.valueBox!, tableId: 3)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, tableId: 2, mediaCleanupTable: self.mediaCleanupTable!)
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, tableId: 4, messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.mediaCleanupTable = nil
        
        self.valueBox = nil
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(path!)
        self.path = nil
    }
    
    private func addMessage(id: Int32, _ timestamp: Int32, _ text: String, _ media: [Media] = []) {
        self.historyTable!.addMessages([StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: id), timestamp: timestamp, text: text, attributes: [], media: media)])
    }
    
    private func removeMessages(ids: [Int32]) {
        self.historyTable!.removeMessages(ids.map({ MessageId(peerId: peerId, namespace: namespace, id: $0) }))
    }
    
    func expectMessages(messages: [(Int32, Int32, String, [Media])]) {
        let actualMessages = self.historyTable!.debugList(peerId).map({ ($0.id.id, $0.timestamp, $0.text, $0.media) })
        var equal = true
        if messages.count != actualMessages.count {
            equal = false
        } else {
            for i in 0 ..< messages.count {
                if !(messages[i] == actualMessages[i]) {
                    equal = false
                    break
                }
            }
        }
        
        if !equal {
            XCTFail("Expected\n\(messages)\nActual\n\(actualMessages)")
        }
    }
    
    private func expectMedia(media: [MediaEntry]) {
        let actualMedia = self.mediaTable!.debugList().map({MediaEntry($0)})
        if media != actualMedia {
            XCTFail("Expected\n\(media)\nActual\n\(actualMedia)")
        }
    }
    
    private func expectCleanupMedia(media: [Media]) {
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
        
        expectMessages([(100, 100, "t100", []), (200, 200, "t200", [])])
    }
    
    func testInsertMessageIgnoreOverwrite() {
        addMessage(100, 100, "t100")
        addMessage(100, 200, "t200")
        
        expectMessages([(100, 100, "t100", [])])
    }
    
    func testInsertMessageWithEmbeddedMedia() {
        addMessage(100, 100, "t100", [TestEmbeddedMedia(data: "abc1")])
        
        expectMessages([(100, 100, "t100", [TestEmbeddedMedia(data: "abc1")])])
        expectMedia([])
    }
    
    func testInsertMessageWithExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        
        expectMessages([(100, 100, "t100", [media])])
        expectMedia([.MessageReference(100)])
    }
    
    func testUnembedExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media])
        
        expectMessages([(100, 100, "t100", [media]), (200, 200, "t200", [media])])
        expectMedia([.Direct(media, 2)])
    }
    
    func testIgnoreOverrideExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        let media1 = TestExternalMedia(id: 10, data: "abc2")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media1])
        
        expectMessages([(100, 100, "t100", [media]), (200, 200, "t200", [media])])
        expectMedia([.Direct(media, 2)])
    }
    
    func testRemoveSingleMessage() {
        addMessage(100, 100, "t100", [])
        
        removeMessages([100])
        
        expectMessages([])
        expectMedia([])
    }
    
    func testRemoveMessageWithEmbeddedMedia() {
        let media = TestEmbeddedMedia(data: "abc1")
        addMessage(100, 100, "t100", [media])
        self.removeMessages([100])
        
        expectMessages([])
        expectMedia([])
        expectCleanupMedia([media])
    }
    
    func testRemoveOnlyReferenceToExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        removeMessages([100])
        
        expectMessages([])
        expectMedia([])
        expectCleanupMedia([media])
    }
    
    func testRemoveReferenceToExternalMedia() {
        let media = TestExternalMedia(id: 10, data: "abc1")
        addMessage(100, 100, "t100", [media])
        addMessage(200, 200, "t200", [media])
        removeMessages([100])
        
        expectMessages([(200, 200, "t200", [media])])
        expectMedia([.Direct(media, 1)])
        expectCleanupMedia([])
        
        removeMessages([200])
        
        expectMessages([])
        expectMedia([])
        expectCleanupMedia([media])
    }
}