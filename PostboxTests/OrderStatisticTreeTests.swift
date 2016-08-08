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

class OrderStatisticTreeTests: XCTestCase {
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
        path = NSTemporaryDirectory() + "\(randomId)"
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
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    func testOST() {
        /*let tree = RBTree(rootData: 0)
        for _ in 0 ..< 1000 {
            let key = Int(arc4random_uniform(UInt32(Int32.max - 1)))
            tree.insert(key)
        }
        print("OST height: \(tree.depth())")*/
    }
}
