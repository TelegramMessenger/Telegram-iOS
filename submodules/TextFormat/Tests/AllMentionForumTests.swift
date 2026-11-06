import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

final class AllMentionForumTests: XCTestCase {
    private var postbox: Postbox!
    private var path: String!
    private let peerId = AllMentionDemoConfiguration.forumPeerId
    private let authorId = AllMentionDemoConfiguration.accountPeerId

    override func setUpWithError() throws {
        initializeAccountManagement()
        self.path = NSTemporaryDirectory() + "all-mention-forum-test-" + UUID().uuidString
        let opened = expectation(description: "Open isolated test Postbox")
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: .init(data: Data(repeating: 0, count: 32))!, salt: .init(data: Data(repeating: 0, count: 16))!)
        let disposable = openPostbox(basePath: self.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: 1000, isMainProcess: false, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: false, removeDatabaseOnError: false).start(next: { result in
            if case let .postbox(postbox) = result { self.postbox = postbox; opened.fulfill() }
        })
        wait(for: [opened], timeout: 20)
        disposable.dispose()
        _ = try XCTUnwrap(self.postbox)
        transact { transaction in
            for threadId: Int64 in [100, 200] {
                let data = self.topicData(threadId)
                transaction.setMessageHistoryThreadInfo(peerId: self.peerId, threadId: threadId, info: AllMentionDemoForumState.stored(data))
                transaction.removeHole(peerId: self.peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                let _ = transaction.addMessages([self.message(id: Int32(threadId), threadId: threadId, incoming: false)], location: .UpperHistoryBlock)
            }
        }
    }

    override func tearDownWithError() throws {
        if let postbox = self.postbox {
            let ready = expectation(description: "Finish test media storage")
            let disposable = postbox.mediaBox.storageBox.totalSize().start(next: { _ in ready.fulfill() })
            wait(for: [ready], timeout: 10)
            disposable.dispose()
        }
        self.postbox = nil
        // Postbox releases storage asynchronously on its queue. The OS temporary
        // directory owns these small test stores; do not race that close by deleting it.
    }

    private func transact(_ body: @escaping (Transaction) -> Void) {
        let completed = expectation(description: "Postbox transaction")
        let disposable = self.postbox.transaction { transaction -> Void in body(transaction) }.start(completed: { completed.fulfill() })
        wait(for: [completed], timeout: 10)
        disposable.dispose()
    }

    private func topicData(_ threadId: Int64) -> MessageHistoryThreadData {
        return MessageHistoryThreadData(creationDate: 100, isOwnedByMe: true, author: authorId, info: .init(title: "Topic \(threadId)", icon: nil, iconColor: 0x6fb9f0), incomingUnreadCount: 0, isMarkedUnread: false, maxIncomingReadId: Int32(threadId), maxKnownMessageId: Int32(threadId), maxOutgoingReadId: Int32(threadId), isClosed: false, isHidden: false, notificationSettings: .defaultSettings, isMessageFeeRemoved: false)
    }

    private func message(id: Int32, threadId: Int64, incoming: Bool) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: 1000 + id, flags: incoming ? [.Incoming, .TopIndexable] : [.TopIndexable], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "@all", attributes: [], media: [])
    }

    private func add(_ transaction: Transaction, id: Int32, threadId: Int64, incoming: Bool = true) {
        let _ = transaction.addMessages([message(id: id, threadId: threadId, incoming: incoming)], location: .UpperHistoryBlock)
        if incoming {
            AllMentionDemoForumState.recordIncoming(transaction: transaction, peerId: peerId, threadId: threadId, messageId: id)
        } else {
            AllMentionDemoForumState.recordOutgoing(transaction: transaction, peerId: peerId, threadId: threadId, messageId: id)
        }
    }

    func testSeedChronologyRepairPreservesTopicsCallsAndReadState() {
        transact { transaction in
            // A later topic was seeded earlier in time than the preceding
            // topic's last message. Cloud history requires both orders to agree.
            self.add(transaction, id: 150, threadId: 100)
            let _ = transaction.addMessages([StoreMessage(id: MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 200), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: 200, timestamp: 1050, flags: [.TopIndexable], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.authorId, text: "Topic seed", attributes: [], media: [])], location: .UpperHistoryBlock)
            self.add(transaction, id: 250, threadId: 200)
            let before = transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 200)
            AllMentionDemoForumChronology.repair(transaction: transaction, peerId: self.peerId, maxSeedId: 200)
            AllMentionDemoForumChronology.repair(transaction: transaction, peerId: self.peerId, maxSeedId: 200)
            let seed = transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 200))!
            XCTAssertEqual(seed.timestamp, 1150)
            XCTAssertEqual(seed.threadId, 200)
            XCTAssertEqual(seed.text, "Topic seed")
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 200), before)
            XCTAssertEqual(transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 250))?.timestamp, 1250)
        }
    }

    func testReadingOneTopicKeepsOtherTopicUnread() {
        transact { transaction in
            self.add(transaction, id: 201, threadId: 100)
            self.add(transaction, id: 202, threadId: 200)
            AllMentionDemoForumState.markRead(transaction: transaction, peerId: self.peerId, threadId: 100, through: transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 201))!.index)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)?.summary.totalUnreadCount, 0)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 200)?.summary.totalUnreadCount, 1)
        }
    }

    func testOutgoingMessageDoesNotReadCallsInEitherTopic() {
        transact { transaction in
            self.add(transaction, id: 201, threadId: 100)
            self.add(transaction, id: 202, threadId: 200)
            self.add(transaction, id: 203, threadId: 100, incoming: false)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)?.summary.totalUnreadCount, 1)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 200)?.summary.totalUnreadCount, 1)
        }
    }

    func testPartialReadCountsIncomingOnlyAndIsIdempotent() {
        transact { transaction in
            self.add(transaction, id: 201, threadId: 100)
            self.add(transaction, id: 202, threadId: 100, incoming: false)
            self.add(transaction, id: 203, threadId: 100)
            let index = transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 202))!.index
            AllMentionDemoForumState.markRead(transaction: transaction, peerId: self.peerId, threadId: 100, through: index)
            AllMentionDemoForumState.markRead(transaction: transaction, peerId: self.peerId, threadId: 100, through: index)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)?.summary.totalUnreadCount, 1)
        }
    }

    func testOtherTopicMessageCannotAdvanceReadBoundary() {
        transact { transaction in
            self.add(transaction, id: 201, threadId: 100)
            self.add(transaction, id: 202, threadId: 200)
            AllMentionDemoForumState.markRead(transaction: transaction, peerId: self.peerId, threadId: 100, through: transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 202))!.index)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)?.summary.totalUnreadCount, 1)
            XCTAssertEqual(transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)?.data.get(MessageHistoryThreadData.self)?.maxIncomingReadId, 100)
        }
    }

    func testQuotaAndPermissionAreSharedByTopicsAndSurviveTransactions() {
        transact { transaction in
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(AllMentionGroupPermission(isEnabled: true)) })
        }
        for (offset, threadId) in [Int64(100), 200, 100].enumerated() {
            transact { transaction in
                let state = allMentionGroupState(transaction: transaction, peerId: self.peerId)
                let reserved = state.reservingCall(at: 1000 + Double(offset))!
                transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(reserved) })
                self.add(transaction, id: 201 + Int32(offset), threadId: threadId)
            }
        }
        transact { transaction in
            let state = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            XCTAssertNil(state.reservingCall(at: 1003))
            XCTAssertNotNil(state.reservingCall(at: 1302))
            XCTAssertFalse(allMentionGroupState(transaction: transaction, peerId: AllMentionDemoConfiguration.groupPeerId).isEnabled)
        }
    }

    func testStoredTopicRoundTripPreservesReadStateAndNotificationSettings() {
        var data = topicData(100)
        data.notificationSettings = .defaultSettings.withUpdatedMuteState(.muted(until: 2000))
        data = AllMentionDemoForumState.recordingMessage(data, id: 201, incoming: true)
        let stored = AllMentionDemoForumState.stored(data)
        XCTAssertEqual(stored.data.get(MessageHistoryThreadData.self), data)
        XCTAssertEqual(stored.summary.totalUnreadCount, 1)
        XCTAssertEqual(stored.summary.mutedUntil, 2000)
        let read = AllMentionDemoForumState.reading(data, through: 201, incomingReadCount: 1, reachedTop: true)
        XCTAssertEqual(AllMentionDemoForumState.stored(read).data.get(MessageHistoryThreadData.self)?.incomingUnreadCount, 0)
        XCTAssertEqual(read.notificationSettings, data.notificationSettings)
    }
}
