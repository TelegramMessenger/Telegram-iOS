import Foundation

import UIKit
import XCTest

import Postbox
@testable import Postbox

import SwiftSignalKit

private let peerId = PeerId(namespace: 1, id: 1)
private let namespace: Int32 = 1
private let authorPeerId = PeerId(namespace: 1, id: 6)

private func ==(lhs: [Media], rhs: [Media]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    
    for i in 0 ..< lhs.count {
        if !lhs[i].isEqual(to: rhs[i]) {
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
    var historyTable: MessageHistoryTable?
    var historyMetadataTable: MessageHistoryMetadataTable?
    var unsentTable: MessageHistoryUnsentTable?
    var tagsTable: MessageHistoryTagsTable?
    var readStateTable: MessageHistoryReadStateTable?
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable?
    var globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable?
    var globalTagsTable: GlobalMessageHistoryTagsTable?
    var localTagsTable: LocalMessageHistoryTagsTable?
    var textIndexTable: MessageHistoryTextIndexTable?
    var messageHistoryTagsSummaryTable: MessageHistoryTagsSummaryTable?
    var invalidatedMessageHistoryTagsSummaryTable: InvalidatedMessageHistoryTagsSummaryTable?
    var pendingMessageActionsTable: PendingMessageActionsTable?
    var pendingMessageActionsMetadataTable: PendingMessageActionsMetadataTable?
    
    override func setUp() {
        super.setUp()
        
        var randomId: Int64 = 0
        arc4random_buf(&randomId, 8)
        path = NSTemporaryDirectory() + "\(randomId)"
        self.valueBox = SqliteValueBox(basePath: path!, queue: Queue.mainQueue())
        
        let seedConfiguration = SeedConfiguration(initializeChatListWithHole: (topLevel: nil, groups: nil), initializeMessageNamespacesWithHoles: [], existingMessageTags: [.First, .Second], messageTagsWithSummary: [], existingGlobalMessageTags: [], peerNamespacesRequiringMessageTextIndex: [], peerSummaryCounterTags: { _ in PeerSummaryCounterTags(rawValue: 0) }, additionalChatListIndexNamespace: nil, chatMessagesNamespaces: Set())
        
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox!, table: GlobalMessageIdsTable.tableSpec(5), namespace: namespace)
        self.historyMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox!, table: MessageHistoryMetadataTable.tableSpec(7))
        self.unsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox!, table: MessageHistoryUnsentTable.tableSpec(8))
        self.invalidatedMessageHistoryTagsSummaryTable = InvalidatedMessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(18))
        self.messageHistoryTagsSummaryTable = MessageHistoryTagsSummaryTable(valueBox: self.valueBox!, table: MessageHistoryTagsSummaryTable.tableSpec(15), invalidateTable: self.invalidatedMessageHistoryTagsSummaryTable!)
        self.pendingMessageActionsMetadataTable = PendingMessageActionsMetadataTable(valueBox: self.valueBox!, table: PendingMessageActionsMetadataTable.tableSpec(16))
        self.pendingMessageActionsTable = PendingMessageActionsTable(valueBox: self.valueBox!, table: PendingMessageActionsTable.tableSpec(17), metadataTable: self.pendingMessageActionsMetadataTable!)
        self.tagsTable = MessageHistoryTagsTable(valueBox: self.valueBox!, table: MessageHistoryTagsTable.tableSpec(9), seedConfiguration: seedConfiguration, summaryTable: messageHistoryTagsSummaryTable!)
        self.indexTable = MessageHistoryIndexTable(valueBox: self.valueBox!, table: MessageHistoryIndexTable.tableSpec(1), globalMessageIdsTable: self.globalMessageIdsTable!, metadataTable: self.historyMetadataTable!, seedConfiguration: seedConfiguration)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox!, table: MessageMediaTable.tableSpec(2))
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox!, table: MessageHistoryReadStateTable.tableSpec(10))
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox!, table: MessageHistorySynchronizeReadStateTable.tableSpec(11))
        self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox!, table: MessageGloballyUniqueIdTable.tableSpec(12))
        self.globalTagsTable = GlobalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(13))
        self.localTagsTable = LocalMessageHistoryTagsTable(valueBox: self.valueBox!, table: GlobalMessageHistoryTagsTable.tableSpec(20))
        self.textIndexTable = MessageHistoryTextIndexTable(valueBox: self.valueBox!, table: MessageHistoryTextIndexTable.tableSpec(14))
        
        self.historyTable = MessageHistoryTable(valueBox: self.valueBox!, table: MessageHistoryTable.tableSpec(4), messageHistoryIndexTable: self.indexTable!, messageMediaTable: self.mediaTable!, historyMetadataTable: self.historyMetadataTable!, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable!, unsentTable: self.unsentTable!, tagsTable: self.tagsTable!, globalTagsTable: self.globalTagsTable!, localTagsTable: self.localTagsTable!, readStateTable: self.readStateTable!, synchronizeReadStateTable: self.synchronizeReadStateTable!, textIndexTable: self.textIndexTable!, summaryTable: messageHistoryTagsSummaryTable!, pendingActionsTable: self.pendingMessageActionsTable!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        self.historyTable = nil
        self.indexTable = nil
        self.mediaTable = nil
        self.peerTable = nil
        self.historyMetadataTable = nil
        
        self.valueBox = nil
        let _ = try? FileManager.default.removeItem(atPath: path!)
        self.path = nil
    }
    
    func testOST() {
        let access = BTreeAccess(order: 100)
        var entries: [MessageOrderKey: Int32] = [:]
        for i in 0 ..< 1000 {
            let k = Int32(bitPattern: arc4random())
            let key = MessageOrderKey(timestamp: k, namespace: 0, id: 0)
            let value = Int32(bitPattern: arc4random())
            access.insert(value, for: key)
            entries[key] = value
        }
        for (key, value) in entries {
            if let result = access.value(for: key) {
                XCTAssert(result == value)
            } else {
                XCTAssert(false)
            }
        }
    }
}
