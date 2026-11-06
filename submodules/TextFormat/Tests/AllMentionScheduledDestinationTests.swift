import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

final class AllMentionScheduledDestinationTests: XCTestCase {
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
            self.setChannel(transaction)
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(AllMentionGroupPermission(isEnabled: true)) })
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


    private func setChannel(_ transaction: Transaction, creator: Bool = true, manager: Bool = false, member: Bool = true) {
        let channel = TelegramChannel(id: self.peerId, accessHash: .personal(0), title: "Пятница в Белграде · темы", username: nil, photo: [], creationDate: 100, version: 1, participationStatus: member ? .member : .left, info: .group(TelegramChannelGroupInfo(flags: [])), flags: creator ? [.isCreator, .isForum] : [.isForum], restrictionInfo: nil, adminRights: manager ? TelegramChatAdminRights(rights: [.canManageTopics]) : nil, bannedRights: nil, defaultBannedRights: TelegramChatBannedRights(flags: [], untilDate: Int32.max), usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
        updatePeersCustom(transaction: transaction, peers: [channel], update: { _, updated in updated })
    }

    private func queue(_ transaction: Transaction, id: Int32 = 1, threadId: Int64 = 100, timestamp: Int32 = 1000, groupingKey: Int64? = nil) -> Message {
        let id = MessageId(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud, id: id)
        let _ = transaction.addMessages([StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: groupingKey, threadId: threadId, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.authorId, text: "@all", attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: timestamp, repeatPeriod: nil), NotificationInfoMessageAttribute(flags: [.muted]), EffectMessageAttribute(id: 123)], media: [])], location: .UpperHistoryBlock)
        return transaction.getMessage(id)!
    }

    private func close(_ transaction: Transaction, owned: Bool = false) {
        var data = self.topicData(100)
        data.isClosed = true
        data.isOwnedByMe = owned
        transaction.setMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100, info: AllMentionDemoForumState.stored(data))
    }

    func testDeletedTopicKeepsEntireBatchAndQuota() {
        transact { transaction in
            let first = self.queue(transaction, groupingKey: 42)
            let second = self.queue(transaction, id: 2, threadId: 200, groupingKey: 42)
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            transaction.setMessageHistoryThreadInfo(peerId: self.peerId, threadId: 200, info: nil)
            XCTAssertEqual(AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: [first, second], timestamp: 1001, force: false), .topicDeleted)
            for old in [first, second] {
                let saved = transaction.getMessage(old.id)!
                XCTAssertTrue(saved.flags.contains(.Failed))
                XCTAssertEqual(saved.threadId, old.threadId)
                XCTAssertEqual(saved.text, old.text)
                XCTAssertEqual(saved.timestamp, old.timestamp)
                XCTAssertTrue(saved.attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
                XCTAssertEqual(saved.attributes.compactMap { $0 as? EffectMessageAttribute }.first?.id, 123)
            }
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
            XCTAssertNil(transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 1)))
        }
    }

    func testFutureQueueIsNotRejectedPrematurely() {
        transact { transaction in
            self.setChannel(transaction, creator: false)
            self.close(transaction)
            let message = self.queue(transaction, timestamp: 2000)
            XCTAssertNil(AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: [message], timestamp: 1001, force: false))
            XCTAssertFalse(transaction.getMessage(message.id)!.flags.contains(.Failed))
        }
    }

    func testClosedTopicRejectsOrdinaryMemberButAllowsOwnerAndManagers() {
        transact { transaction in
            self.setChannel(transaction, creator: false)
            self.close(transaction)
            XCTAssertEqual(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true), .topicClosed)
            self.close(transaction, owned: true)
            XCTAssertNil(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true))
            self.close(transaction)
            self.setChannel(transaction, creator: false, manager: true)
            XCTAssertNil(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true))
            self.setChannel(transaction)
            XCTAssertNil(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true))
        }
    }

    func testForceSendCannotBypassRevokedTextPermission() {
        transact { transaction in
            let message = self.queue(transaction, timestamp: 2000)
            AllMentionDemoForumScenario.apply(transaction: transaction, scenario: "readonly")
            XCTAssertEqual(AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: [message], timestamp: 1001, force: true), .sendPermissionDenied)
            XCTAssertTrue(transaction.getMessage(message.id)!.flags.contains(.Failed))
        }
    }

    func testLeavingGroupBlocksEvenAnExistingTopic() {
        transact { transaction in
            self.setChannel(transaction, member: false)
            XCTAssertEqual(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true), .groupUnavailable)
        }
    }

    func testHiddenTopicStillAcceptsMessages() {
        transact { transaction in
            var topic = self.topicData(100)
            topic.isHidden = true
            transaction.setMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100, info: AllMentionDemoForumState.stored(topic))
            XCTAssertNil(AllMentionDemoScheduledDestination.failure(transaction: transaction, peerId: self.peerId, threadId: 100, hasText: true))
        }
    }

    func testFailurePersistsAndRestoringAccessDoesNotRetryAutomatically() {
        var id: MessageId!
        transact { transaction in
            let message = self.queue(transaction)
            id = message.id
            AllMentionDemoForumScenario.apply(transaction: transaction, scenario: "delete:100")
            XCTAssertEqual(AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: [message], timestamp: 1001, force: false), .topicDeleted)
        }
        transact { transaction in
            AllMentionDemoForumScenario.apply(transaction: transaction, scenario: "restore")
            let failed = transaction.getMessage(id)!
            XCTAssertTrue(failed.flags.contains(.Failed))
            XCTAssertEqual(failed.threadId, 100)
            XCTAssertEqual(allMentionScheduledDeliveryDecision(scheduleTime: failed.timestamp, timestamp: 1200, requiresCollectiveMention: true, hasFailed: true, force: false, permission: allMentionGroupState(transaction: transaction, peerId: self.peerId)), .wait)
            XCTAssertNil(AllMentionDemoScheduledDestination.rejectUnavailableBatch(transaction: transaction, messages: [failed], timestamp: 1200, force: true))
            if case .deliver = allMentionScheduledDeliveryDecision(scheduleTime: failed.timestamp, timestamp: 1200, requiresCollectiveMention: true, hasFailed: true, force: true, permission: allMentionGroupState(transaction: transaction, peerId: self.peerId)) {} else { XCTFail("Manual retry should be available") }
        }
    }

    func testRestoringScenarioPreservesQueueAndNewReadBoundary() {
        transact { transaction in
            let queued = self.queue(transaction)
            AllMentionDemoForumScenario.apply(transaction: transaction, scenario: "close:100")
            var data = transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)!.data.get(MessageHistoryThreadData.self)!
            data.maxIncomingReadId = 150
            transaction.setMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100, info: AllMentionDemoForumState.stored(data))
            AllMentionDemoForumScenario.apply(transaction: transaction, scenario: "restore")
            let restored = transaction.getMessageHistoryThreadInfo(peerId: self.peerId, threadId: 100)!.data.get(MessageHistoryThreadData.self)!
            XCTAssertFalse(restored.isClosed)
            XCTAssertTrue(restored.isOwnedByMe)
            XCTAssertEqual(restored.maxIncomingReadId, 150)
            XCTAssertNotNil(transaction.getMessage(queued.id))
            XCTAssertTrue((transaction.getPeer(self.peerId) as! TelegramChannel).flags.contains(.isCreator))
        }
    }
}
