import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A `Media` whose only content is an id, so two messages can share one media row.
final class FixtureMedia: Media {
    static let register: Void = {
        declareEncodable(FixtureMedia.self, f: { FixtureMedia(decoder: $0) })
    }()

    let id: MediaId?
    let label: String

    init(id: MediaId, label: String = "") {
        self.id = id
        self.label = label
    }

    init(decoder: PostboxDecoder) {
        self.id = MediaId(namespace: decoder.decodeInt32ForKey("n", orElse: 0), id: decoder.decodeInt64ForKey("i", orElse: 0))
        self.label = decoder.decodeStringForKey("l", orElse: "")
    }

    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.id!.namespace, forKey: "n")
        encoder.encodeInt64(self.id!.id, forKey: "i")
        encoder.encodeString(self.label, forKey: "l")
    }

    var peerIds: [PeerId] { return [] }
    var indexableText: String? { return nil }
    func isLikelyToBeUpdated() -> Bool { return false }
    func preventsAutomaticMessageSendingFailure() -> Bool { return false }
    func isEqual(to other: Media) -> Bool {
        guard let other = other as? FixtureMedia else { return false }
        return other.id == self.id && other.label == self.label
    }
    func isSemanticallyEqual(to other: Media) -> Bool { return self.isEqual(to: other) }
}

/// The message-history table and every table it writes through, on an in-memory
/// value box. Table ids mirror `Postbox.init` so the layout matches production.
final class MessageHistoryTableFixture {
    /// Everything that must be released on the value-box queue (`SqliteValueBox.deinit`
    /// preconditions it), so `close()` can drop it inside `queue.sync`.
    final class Tables {
        let valueBox: SqliteValueBox
        let messageHistoryMetadataTable: MessageHistoryMetadataTable
        let messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable
        let globalMessageIdsTable: GlobalMessageIdsTable
        let messageHistoryIndexTable: MessageHistoryIndexTable
        let mediaTable: MessageMediaTable
        let readStateTable: MessageHistoryReadStateTable
        let synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable
        let messageHistoryTagsSummaryTable: MessageHistoryTagsSummaryTable
        let invalidatedMessageHistoryTagsSummaryTable: InvalidatedMessageHistoryTagsSummaryTable
        let globalMessageHistoryTagsTable: GlobalMessageHistoryTagsTable
        let messageHistoryTable: MessageHistoryTable
        /// Every table above, so a commit can flush them all as `Postbox` does.
        let allTables: [Table]

        init(valueBox: SqliteValueBox, seedConfiguration: SeedConfiguration) {
            self.valueBox = valueBox
            let useCaches = false
            let messageHistoryMetadataTable = MessageHistoryMetadataTable(valueBox: valueBox, table: MessageHistoryMetadataTable.tableSpec(10), useCaches: useCaches)
            self.messageHistoryMetadataTable = messageHistoryMetadataTable
            let messageHistoryHoleIndexTable = MessageHistoryHoleIndexTable(valueBox: valueBox, table: MessageHistoryHoleIndexTable.tableSpec(56), useCaches: useCaches, metadataTable: messageHistoryMetadataTable, seedConfiguration: seedConfiguration)
            self.messageHistoryHoleIndexTable = messageHistoryHoleIndexTable
            let globalMessageIdsTable = GlobalMessageIdsTable(valueBox: valueBox, table: GlobalMessageIdsTable.tableSpec(3), useCaches: useCaches, seedConfiguration: seedConfiguration)
            self.globalMessageIdsTable = globalMessageIdsTable
            let globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: valueBox, table: MessageGloballyUniqueIdTable.tableSpec(32), useCaches: useCaches)
            let messageCustomTagIdTable = MessageCustomTagIdTable(valueBox: valueBox, table: MessageCustomTagIdTable.tableSpec(81), useCaches: useCaches, metadataTable: messageHistoryMetadataTable)
            let messageCustomTagTable = MessageCustomTagTable(valueBox: valueBox, table: MessageCustomTagTable.tableSpec(83), useCaches: useCaches, messageCustomTagIdTable: messageCustomTagIdTable)
            let unsentTable = MessageHistoryUnsentTable(valueBox: valueBox, table: MessageHistoryUnsentTable.tableSpec(11), useCaches: useCaches)
            let failedTable = MessageHistoryFailedTable(valueBox: valueBox, table: MessageHistoryFailedTable.tableSpec(49), useCaches: useCaches)
            let invalidatedMessageHistoryTagsSummaryTable = InvalidatedMessageHistoryTagsSummaryTable(valueBox: valueBox, table: InvalidatedMessageHistoryTagsSummaryTable.tableSpec(47), useCaches: useCaches)
            self.invalidatedMessageHistoryTagsSummaryTable = invalidatedMessageHistoryTagsSummaryTable
            let messageHistoryTagsSummaryTable = MessageHistoryTagsSummaryTable(valueBox: valueBox, table: MessageHistoryTagsSummaryTable.tableSpec(44), useCaches: useCaches, invalidateTable: invalidatedMessageHistoryTagsSummaryTable)
            self.messageHistoryTagsSummaryTable = messageHistoryTagsSummaryTable
            let messageCustomTagWithTagTable = MessageCustomTagWithTagTable(valueBox: valueBox, table: MessageCustomTagWithTagTable.tableSpec(85), useCaches: useCaches, messageCustomTagIdTable: messageCustomTagIdTable, seedConfiguration: seedConfiguration, summaryTable: messageHistoryTagsSummaryTable)
            let pendingMessageActionsMetadataTable = PendingMessageActionsMetadataTable(valueBox: valueBox, table: PendingMessageActionsMetadataTable.tableSpec(45), useCaches: useCaches)
            let pendingMessageActionsTable = PendingMessageActionsTable(valueBox: valueBox, table: PendingMessageActionsTable.tableSpec(46), useCaches: useCaches, metadataTable: pendingMessageActionsMetadataTable)
            let tagsTable = MessageHistoryTagsTable(valueBox: valueBox, table: MessageHistoryTagsTable.tableSpec(12), useCaches: useCaches, seedConfiguration: seedConfiguration, summaryTable: messageHistoryTagsSummaryTable)
            let threadsTable = MessageHistoryThreadsTable(valueBox: valueBox, table: MessageHistoryThreadsTable.tableSpec(62), useCaches: useCaches)
            let threadTagsTable = MessageHistoryThreadTagsTable(valueBox: valueBox, table: MessageHistoryThreadTagsTable.tableSpec(71), useCaches: useCaches, seedConfiguration: seedConfiguration, summaryTable: messageHistoryTagsSummaryTable)
            let globalMessageHistoryTagsTable = GlobalMessageHistoryTagsTable(valueBox: valueBox, table: GlobalMessageHistoryTagsTable.tableSpec(39), useCaches: useCaches)
            self.globalMessageHistoryTagsTable = globalMessageHistoryTagsTable
            let localMessageHistoryTagsTable = LocalMessageHistoryTagsTable(valueBox: valueBox, table: GlobalMessageHistoryTagsTable.tableSpec(52), useCaches: useCaches)
            let messageHistoryIndexTable = MessageHistoryIndexTable(valueBox: valueBox, table: MessageHistoryIndexTable.tableSpec(4), useCaches: useCaches, messageHistoryHoleIndexTable: messageHistoryHoleIndexTable, globalMessageIdsTable: globalMessageIdsTable, metadataTable: messageHistoryMetadataTable, seedConfiguration: seedConfiguration)
            self.messageHistoryIndexTable = messageHistoryIndexTable
            let mediaTable = MessageMediaTable(valueBox: valueBox, table: MessageMediaTable.tableSpec(6), useCaches: useCaches)
            self.mediaTable = mediaTable
            let readStateTable = MessageHistoryReadStateTable(valueBox: valueBox, table: MessageHistoryReadStateTable.tableSpec(14), useCaches: useCaches, seedConfiguration: seedConfiguration)
            self.readStateTable = readStateTable
            let synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: valueBox, table: MessageHistorySynchronizeReadStateTable.tableSpec(15), useCaches: useCaches)
            self.synchronizeReadStateTable = synchronizeReadStateTable
            let timestampBasedMessageAttributesIndexTable = TimestampBasedMessageAttributesIndexTable(valueBox: valueBox, table: TimestampBasedMessageAttributesTable.tableSpec(33), useCaches: useCaches)
            let timestampBasedMessageAttributesTable = TimestampBasedMessageAttributesTable(valueBox: valueBox, table: TimestampBasedMessageAttributesTable.tableSpec(34), useCaches: useCaches, indexTable: timestampBasedMessageAttributesIndexTable)
            let textIndexTable = MessageHistoryTextIndexTable(valueBox: valueBox, table: MessageHistoryTextIndexTable.tableSpec(41))

            self.messageHistoryTable = MessageHistoryTable(valueBox: valueBox, table: MessageHistoryTable.tableSpec(7), useCaches: useCaches, seedConfiguration: seedConfiguration, messageHistoryIndexTable: messageHistoryIndexTable, messageHistoryHoleIndexTable: messageHistoryHoleIndexTable, messageMediaTable: mediaTable, historyMetadataTable: messageHistoryMetadataTable, globallyUniqueMessageIdsTable: globallyUniqueMessageIdsTable, unsentTable: unsentTable, failedTable: failedTable, tagsTable: tagsTable, threadsTable: threadsTable, threadTagsTable: threadTagsTable, customTagTable: messageCustomTagTable, customTagWithTagTable: messageCustomTagWithTagTable, globalTagsTable: globalMessageHistoryTagsTable, localTagsTable: localMessageHistoryTagsTable, timeBasedAttributesTable: timestampBasedMessageAttributesTable, readStateTable: readStateTable, synchronizeReadStateTable: synchronizeReadStateTable, textIndexTable: textIndexTable, summaryTable: messageHistoryTagsSummaryTable, pendingActionsTable: pendingMessageActionsTable)
            self.allTables = [messageHistoryMetadataTable, messageHistoryHoleIndexTable, globalMessageIdsTable, globallyUniqueMessageIdsTable, messageCustomTagIdTable, messageCustomTagTable, unsentTable, failedTable, invalidatedMessageHistoryTagsSummaryTable, messageHistoryTagsSummaryTable, messageCustomTagWithTagTable, pendingMessageActionsMetadataTable, pendingMessageActionsTable, tagsTable, threadsTable, threadTagsTable, globalMessageHistoryTagsTable, localMessageHistoryTagsTable, messageHistoryIndexTable, mediaTable, readStateTable, synchronizeReadStateTable, timestampBasedMessageAttributesIndexTable, timestampBasedMessageAttributesTable, self.messageHistoryTable]
        }
    }

    let queue: Queue
    let basePath: String
    let seedConfiguration: SeedConfiguration
    private var tables: Tables?

    var valueBox: SqliteValueBox { return self.tables!.valueBox }
    var messageHistoryTable: MessageHistoryTable { return self.tables!.messageHistoryTable }
    var mediaTable: MessageMediaTable { return self.tables!.mediaTable }
    var readStateTable: MessageHistoryReadStateTable { return self.tables!.readStateTable }
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable { return self.tables!.synchronizeReadStateTable }
    var globalMessageHistoryTagsTable: GlobalMessageHistoryTagsTable { return self.tables!.globalMessageHistoryTagsTable }
    var messageHistoryIndexTable: MessageHistoryIndexTable { return self.tables!.messageHistoryIndexTable }

    static let messageNamespace: MessageId.Namespace = 0

    static func makeSeedConfiguration() -> SeedConfiguration {
        return SeedConfiguration(
            globalMessageIdsPeerIdNamespaces: [],
            initializeChatListWithHole: (topLevel: nil, groups: nil),
            // Holes are allowed in the message namespace for every peer namespace the
            // tests use; the history-view state asserts this before it will track holes.
            messageHoles: [PeerId.Namespace._internalFromInt32Value(0): [messageNamespace: Set()]],
            upgradedMessageHoles: [:],
            messageThreadHoles: { _, _ in nil },
            existingMessageTags: [],
            messageTagsWithSummary: [],
            messageTagsWithThreadSummary: [],
            existingGlobalMessageTags: [],
            peerNamespacesRequiringMessageTextIndex: [],
            peerSummaryCounterTags: { _, _ in PeerSummaryCounterTags() },
            peerSummaryIsThreadBased: { peer, _ in ((peer as? FixturePeer)?.isForum ?? false, false) },
            additionalChatListIndexNamespace: nil,
            messageNamespacesRequiringGroupStatsValidation: [],
            defaultMessageNamespaceReadStates: [:],
            chatMessagesNamespaces: [messageNamespace],
            getGlobalNotificationSettings: { _ in nil },
            defaultGlobalNotificationSettings: PostboxGlobalNotificationSettings(defaultIncludePeer: { _ in true }),
            mergeMessageAttributes: { _, _ in },
            decodeMessageThreadInfo: { _ in nil },
            decodeAutoremoveTimeout: { _ in nil },
            decodeDisplayPeerAsRegularChat: { _ in false },
            isPeerUpgradeMessage: { _ in false },
            automaticThreadIndexInfo: { _, _ in nil },
            customTagsFromAttributes: { _ in [] },
            displaySavedMessagesAsTopicListPreferencesKey: ValueBoxKey(length: 0)
        )
    }

    init(name: String) {
        let _ = FixtureMedia.register
        self.queue = Queue(name: name)
        self.basePath = NSTemporaryDirectory() + name + "-" + UUID().uuidString
        let queue = self.queue
        let basePath = self.basePath
        var valueBox: SqliteValueBox?
        queue.sync {
            valueBox = SqliteValueBox(basePath: basePath, queue: queue, isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true)
        }
        let seedConfiguration = MessageHistoryTableFixture.makeSeedConfiguration()
        self.seedConfiguration = seedConfiguration

        self.tables = Tables(valueBox: valueBox!, seedConfiguration: seedConfiguration)
    }

    func close() {
        self.queue.sync {
            self.tables?.valueBox.internalClose()
            self.tables = nil
        }
        // The value box creates its base directory even when the database itself is in memory.
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
    }

    // MARK: - Convenience

    static func peerId(_ id: Int64) -> PeerId {
        return PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(id))
    }

    static func messageId(peer: Int64, id: Int32) -> MessageId {
        return MessageId(peerId: peerId(peer), namespace: messageNamespace, id: id)
    }

    static func storeMessage(id: MessageId, timestamp: Int32, text: String = "", media: [Media] = [], flags: StoreMessageFlags = [], tags: MessageTags = [], globalTags: GlobalMessageTags = []) -> StoreMessage {
        return StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: nil, text: text, attributes: [], media: media)
    }

    /// Every by-product an add/update/remove call reports; tests inspect what they need.
    final class Operations {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        var updatedMedia: [MediaId: Media?] = [:]
        var unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation] = []
        var updatedPeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
        var globalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
        var pendingActionsOperations: [PendingMessageActionsOperation] = []
        var updatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
        var updatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary] = [:]
        var invalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
        var localTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
        var timestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation] = []
    }

    /// Runs `f` inside a write transaction on the value-box queue.
    func transaction<T>(_ f: (MessageHistoryTable, Operations) -> T) -> T {
        var result: T?
        self.queue.sync {
            self.valueBox.begin()
            result = f(self.messageHistoryTable, Operations())
            for table in self.tables!.allTables {
                table.beforeCommit()
            }
            self.valueBox.commit()
        }
        return result!
    }

    @discardableResult
    func addMessages(_ messages: [StoreMessage]) -> Operations {
        return self.transaction { table, ops in
            let _ = table.addMessages(messages: messages, operationsByPeerId: &ops.operationsByPeerId, updatedMedia: &ops.updatedMedia, unsentMessageOperations: &ops.unsentMessageOperations, updatedPeerReadStateOperations: &ops.updatedPeerReadStateOperations, globalTagsOperations: &ops.globalTagsOperations, pendingActionsOperations: &ops.pendingActionsOperations, updatedMessageActionsSummaries: &ops.updatedMessageActionsSummaries, updatedMessageTagSummaries: &ops.updatedMessageTagSummaries, invalidateMessageTagSummaries: &ops.invalidateMessageTagSummaries, localTagsOperations: &ops.localTagsOperations, timestampBasedMessageAttributesOperations: &ops.timestampBasedMessageAttributesOperations, processMessages: nil)
            return ops
        }
    }

    @discardableResult
    func updateMessage(_ id: MessageId, message: StoreMessage) -> Operations {
        return self.transaction { table, ops in
            table.updateMessage(id, message: message, operationsByPeerId: &ops.operationsByPeerId, updatedMedia: &ops.updatedMedia, unsentMessageOperations: &ops.unsentMessageOperations, updatedPeerReadStateOperations: &ops.updatedPeerReadStateOperations, globalTagsOperations: &ops.globalTagsOperations, pendingActionsOperations: &ops.pendingActionsOperations, updatedMessageActionsSummaries: &ops.updatedMessageActionsSummaries, updatedMessageTagSummaries: &ops.updatedMessageTagSummaries, invalidateMessageTagSummaries: &ops.invalidateMessageTagSummaries, localTagsOperations: &ops.localTagsOperations, timestampBasedMessageAttributesOperations: &ops.timestampBasedMessageAttributesOperations)
            return ops
        }
    }

    @discardableResult
    func updateMessageTimestamp(_ id: MessageId, timestamp: Int32) -> Operations {
        return self.transaction { table, ops in
            table.updateMessageTimestamp(id, timestamp: timestamp, operationsByPeerId: &ops.operationsByPeerId, updatedMedia: &ops.updatedMedia, unsentMessageOperations: &ops.unsentMessageOperations, updatedPeerReadStateOperations: &ops.updatedPeerReadStateOperations, globalTagsOperations: &ops.globalTagsOperations, pendingActionsOperations: &ops.pendingActionsOperations, updatedMessageActionsSummaries: &ops.updatedMessageActionsSummaries, updatedMessageTagSummaries: &ops.updatedMessageTagSummaries, invalidateMessageTagSummaries: &ops.invalidateMessageTagSummaries, localTagsOperations: &ops.localTagsOperations, timestampBasedMessageAttributesOperations: &ops.timestampBasedMessageAttributesOperations)
            return ops
        }
    }

    @discardableResult
    func removeMessages(_ ids: [MessageId]) -> Operations {
        return self.transaction { table, ops in
            table.removeMessages(ids, operationsByPeerId: &ops.operationsByPeerId, updatedMedia: &ops.updatedMedia, unsentMessageOperations: &ops.unsentMessageOperations, updatedPeerReadStateOperations: &ops.updatedPeerReadStateOperations, globalTagsOperations: &ops.globalTagsOperations, pendingActionsOperations: &ops.pendingActionsOperations, updatedMessageActionsSummaries: &ops.updatedMessageActionsSummaries, updatedMessageTagSummaries: &ops.updatedMessageTagSummaries, invalidateMessageTagSummaries: &ops.invalidateMessageTagSummaries, localTagsOperations: &ops.localTagsOperations, timestampBasedMessageAttributesOperations: &ops.timestampBasedMessageAttributesOperations, forEachMedia: nil)
            return ops
        }
    }

    /// A freshly initialised global tag holds one hole at the upper bound, and a message
    /// below a hole is not indexed. Like the app's hole fill, this replaces that hole with
    /// one at the lower bound: everything above it is accepted, and because the tag's
    /// range is no longer empty the upper hole is not recreated after a cache clear.
    func fillGlobalTagHole(_ tag: GlobalMessageTags) {
        self.transaction { _, _ in
            self.globalMessageHistoryTagsTable.ensureInitialized(tag)
            self.globalMessageHistoryTagsTable.remove(tag, index: MessageIndex.absoluteUpperBound())
            self.globalMessageHistoryTagsTable.addHole(tag, index: MessageIndex.absoluteLowerBound())
        }
    }

    /// Marks the region below `index` as not loaded for `tag`.
    func addGlobalTagHole(_ tag: GlobalMessageTags, index: MessageIndex) {
        self.transaction { _, _ in
            self.globalMessageHistoryTagsTable.addHole(tag, index: index)
        }
    }

    /// Indices the global-tags table lists under `tag`, excluding holes.
    func globalTagIndices(_ tag: GlobalMessageTags) -> [MessageIndex] {
        var indices: [MessageIndex] = []
        self.queue.sync {
            for entry in self.globalMessageHistoryTagsTable.laterEntries(tag, index: MessageIndex.absoluteLowerBound(), count: 1000) {
                if case let .message(index) = entry {
                    indices.append(index)
                }
            }
        }
        return indices
    }

    /// The media table's row for `id`: `.Direct(media, referenceCount)` when shared,
    /// `.MessageReference(index)` when embedded in one message, nil when absent.
    func mediaEntry(_ id: MediaId, file: StaticString = #file, line: UInt = #line) -> DebugMediaEntry? {
        var entry: DebugMediaEntry?
        self.queue.sync {
            defer {
                if entry == nil && self.mediaTable.exists(id: id) {
                    XCTFail("media row for \(id) exists but points at a message that is gone", file: file, line: line)
                }
            }
            for candidate in self.mediaTable.debugList() {
                switch candidate {
                case let .Direct(media, _):
                    if media.id == id {
                        entry = candidate
                    }
                case let .MessageReference(index):
                    if let message = self.messageHistoryTable.getMessage(index) {
                        let ids = self.messageHistoryTable.renderMessageMedia(referencedMedia: [], embeddedMediaData: message.embeddedMediaData).compactMap { $0.id }
                        if ids.contains(id) {
                            entry = candidate
                        }
                    }
                }
            }
        }
        return entry
    }

    func referenceCount(_ id: MediaId) -> Int? {
        if case let .Direct(_, count)? = self.mediaEntry(id) {
            return count
        }
        return nil
    }
}
