import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TextFormat

final class AllMentionMessageReuseTests: XCTestCase {
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
            let user = TelegramUser(id: self.authorId, accessHash: nil, firstName: "Demo", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
            updatePeersCustom(transaction: transaction, peers: [user], update: { _, updated in updated })
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

    private var collective: MessageTextEntity { MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention)) }

    private func addMessage(_ transaction: Transaction, id: Int32 = 300, namespace: Int32 = Namespaces.Message.Cloud, text: String = "@all", entities: [MessageTextEntity] = [], failed: Bool = false) -> Message {
        let id = MessageId(peerId: self.peerId, namespace: namespace, id: id)
        var attributes: [MessageAttribute] = [TextEntitiesMessageAttribute(entities: entities), NotificationInfoMessageAttribute(flags: [.muted]), EffectMessageAttribute(id: 123)]
        if namespace == Namespaces.Message.ScheduledCloud { attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: 2000, repeatPeriod: nil)) }
        let _ = transaction.addMessages([StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: 42, threadId: 100, timestamp: namespace == Namespaces.Message.ScheduledCloud ? 2000 : 1300, flags: failed ? [.Failed] : [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.authorId, text: text, attributes: attributes, media: [])], location: .UpperHistoryBlock)
        return transaction.getMessage(id)!
    }

    private func edited(_ transaction: Transaction, message: Message, text: String, entities: [MessageTextEntity] = []) -> Message {
        AllMentionDemoMessageReuse.edit(transaction: transaction, peerId: self.peerId, id: message.id, text: text, media: .keep, entities: TextEntitiesMessageAttribute(entities: entities), webpagePreviewAttribute: nil)
        return transaction.getMessage(message.id)!
    }

    private func hasCollective(_ message: Message) -> Bool {
        message.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.contains { $0.entities.contains { $0.type == self.collective.type } }
    }

    func testEditingSentOrdinaryMessageCannotCreateCallEvenWithExplicitAtom() {
        transact { transaction in
            let source = self.addMessage(transaction, text: "hello")
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            let edited = self.edited(transaction, message: source, text: "@all", entities: [self.collective])
            XCTAssertFalse(self.hasCollective(edited))
            XCTAssertEqual(edited.text, "@all")
            XCTAssertEqual(edited.timestamp, source.timestamp)
            XCTAssertEqual(edited.attributes.compactMap { $0 as? EditedMessageAttribute }.count, 1)
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
        }
    }

    func testEditingExistingCallRetainsShiftedAtomWithoutReservingAgain() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            let text = "👋 @all updated"
            let range = (text as NSString).range(of: "@all")
            let moved = MessageTextEntity(range: range.location ..< NSMaxRange(range), type: self.collective.type)
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            let edited = self.edited(transaction, message: source, text: text, entities: [moved])
            XCTAssertTrue(self.hasCollective(edited))
            XCTAssertEqual(edited.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first?.entities, [moved])
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
        }
    }

    func testOldCallRemainsHistoricalWhenPermissionTurnsOff() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(AllMentionGroupPermission(isEnabled: false, callsInBurst: 3, burstResetsAt: 5000)) })
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            XCTAssertTrue(self.hasCollective(self.edited(transaction, message: source, text: "@all updated", entities: [self.collective])))
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
        }
    }

    func testRemovedSentAtomCannotBeResurrectedByAnotherEdit() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            let removed = self.edited(transaction, message: source, text: "hello")
            XCTAssertFalse(self.hasCollective(removed))
            XCTAssertFalse(self.hasCollective(self.edited(transaction, message: removed, text: "@all", entities: [self.collective])))
        }
    }

    func testEditingQueuedRawTokenDoesNotPromoteIt() {
        transact { transaction in
            let source = self.addMessage(transaction, namespace: Namespaces.Message.ScheduledCloud)
            XCTAssertFalse(self.hasCollective(self.edited(transaction, message: source, text: "@all updated")))
        }
    }

    func testExplicitQueuedAtomRequestsFutureCallWithoutReservingQuota() {
        transact { transaction in
            let source = self.addMessage(transaction, namespace: Namespaces.Message.ScheduledCloud, text: "hello")
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            let edited = self.edited(transaction, message: source, text: "@all", entities: [self.collective])
            XCTAssertTrue(self.hasCollective(edited))
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
            if case let .deliver(reserved) = allMentionScheduledDeliveryDecision(scheduleTime: 2000, timestamp: 2000, requiresCollectiveMention: true, hasFailed: false, force: false, permission: before) { XCTAssertEqual(reserved.callsInBurst, before.callsInBurst + 1) } else { XCTFail("Intent should reserve at delivery only") }
        }
    }

    func testQueuedEditCannotBypassDisabledPermissionOrProtectedText() {
        transact { transaction in
            let source = self.addMessage(transaction, namespace: Namespaces.Message.ScheduledCloud, entities: [self.collective])
            let code = MessageTextEntity(range: 0 ..< 4, type: .Code)
            XCTAssertFalse(self.hasCollective(self.edited(transaction, message: source, text: "@all", entities: [self.collective, code])))
            transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.allMentionGroupPermission(peerId: self.peerId), { _ in PreferencesEntry(AllMentionGroupPermission()) })
            XCTAssertFalse(self.hasCollective(self.edited(transaction, message: source, text: "@all", entities: [self.collective])))
        }
    }

    func testFailedQueuedEditPreservesDateTopicSilenceEffectAndFailure() {
        transact { transaction in
            let source = self.addMessage(transaction, namespace: Namespaces.Message.ScheduledCloud, entities: [self.collective], failed: true)
            let edited = self.edited(transaction, message: source, text: "@all updated", entities: [self.collective])
            XCTAssertTrue(edited.flags.contains(.Failed))
            XCTAssertFalse(edited.attributes.contains { $0 is EditedMessageAttribute })
            XCTAssertEqual(edited.threadId, 100)
            XCTAssertEqual(edited.groupingKey, 42)
            XCTAssertEqual(edited.timestamp, 2000)
            XCTAssertEqual(edited.attributes.compactMap { $0 as? OutgoingScheduleInfoMessageAttribute }.first?.scheduleTime, 2000)
            XCTAssertEqual(edited.attributes.compactMap { $0 as? EffectMessageAttribute }.first?.id, 123)
            XCTAssertTrue(edited.attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
            XCTAssertEqual(allMentionScheduledDeliveryDecision(scheduleTime: 2000, timestamp: 2100, requiresCollectiveMention: true, hasFailed: true, force: false, permission: allMentionGroupState(transaction: transaction, peerId: self.peerId)), .wait)
        }
    }

    func testForwardKeepsFormattingButDoesNotCopyCollectiveEffectOrReadState() {
        transact { transaction in
            let bold = MessageTextEntity(range: 0 ..< 4, type: .Bold)
            let source = self.addMessage(transaction, entities: [self.collective, bold])
            let before = allMentionGroupState(transaction: transaction, peerId: self.peerId)
            let forwarded = AllMentionDemoMessageReuse.forward(original: source, id: MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 301), threadId: 200, timestamp: 1400, authorId: self.authorId, attributes: [], correlationId: 55)
            let _ = transaction.addMessages([forwarded], location: .UpperHistoryBlock)
            let saved = transaction.getMessage(MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 301))!
            XCTAssertFalse(self.hasCollective(saved))
            XCTAssertEqual(saved.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first?.entities, [bold])
            XCTAssertFalse(saved.attributes.contains { $0 is EffectMessageAttribute || $0 is ConsumablePersonalMentionMessageAttribute || $0 is NotificationInfoMessageAttribute })
            XCTAssertTrue(saved.flags.contains(.ReactionsArePossible))
            XCTAssertFalse(saved.flags.contains(.Incoming))
            XCTAssertFalse(saved.tags.contains(.unseenPersonalMessage))
            XCTAssertEqual(saved.threadId, 200)
            XCTAssertEqual(saved.forwardInfo?.author?.id, self.authorId)
            XCTAssertEqual(saved.attributes.compactMap { $0 as? OutgoingMessageInfoAttribute }.first?.correlationId, 55)
            XCTAssertTrue(self.hasCollective(transaction.getMessage(source.id)!))
            XCTAssertEqual(allMentionGroupState(transaction: transaction, peerId: self.peerId), before)
        }
    }

    func testForwardWithoutAuthorStillCannotCallEveryoneOrBePromotedByEdit() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            let id = MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: 301)
            let forwarded = AllMentionDemoMessageReuse.forward(original: source, id: id, threadId: 200, timestamp: 1400, authorId: self.authorId, attributes: [ForwardOptionsMessageAttribute(hideNames: true, hideCaptions: false), TextEntitiesMessageAttribute(entities: [self.collective])], correlationId: nil)
            let _ = transaction.addMessages([forwarded], location: .UpperHistoryBlock)
            let saved = transaction.getMessage(id)!
            XCTAssertNil(saved.forwardInfo)
            XCTAssertFalse(self.hasCollective(saved))
            XCTAssertFalse(self.hasCollective(self.edited(transaction, message: saved, text: "@all updated", entities: [self.collective])))
        }
    }

    func testScheduledForwardRetainsNewSilenceButNeverRecreatesOriginalCall() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            let id = MessageId(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud, id: 301)
            let forwarded = AllMentionDemoMessageReuse.forward(original: source, id: id, threadId: 200, timestamp: 2000, authorId: self.authorId, attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: 2000, repeatPeriod: nil), NotificationInfoMessageAttribute(flags: [.muted])], correlationId: nil)
            let _ = transaction.addMessages([forwarded], location: .UpperHistoryBlock)
            let saved = transaction.getMessage(transaction.getTopPeerMessageId(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud)!)!
            XCTAssertFalse(self.hasCollective(saved))
            let entities = saved.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.flatMap { $0.entities }
            XCTAssertTrue(allMentionEntitiesForScheduledDemoDelivery(text: saved.text, entities: entities).isEmpty)
            XCTAssertTrue(saved.attributes.contains { ($0 as? NotificationInfoMessageAttribute)?.flags.contains(.muted) == true })
            XCTAssertFalse(saved.attributes.contains { $0 is EffectMessageAttribute })
        }
    }
    func testScheduledForwardAllocatesDistinctIdsAfterDateReordering() {
        transact { transaction in
            let source = self.addMessage(transaction, entities: [self.collective])
            let id = MessageId(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud, id: 1)
            for timestamp: Int32 in [3000, 2000, 2500] {
                let forward = AllMentionDemoMessageReuse.forward(original: source, id: id, threadId: 200, timestamp: timestamp, authorId: self.authorId, attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: timestamp, repeatPeriod: nil)], correlationId: nil)
                let _ = transaction.addMessages([forward], location: .UpperHistoryBlock)
            }
            let messages = transaction.getMessages(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud, from: .lowerBound(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud), includeFrom: true, to: .upperBound(peerId: self.peerId, namespace: Namespaces.Message.ScheduledCloud), limit: 10)
            XCTAssertEqual(messages.count, 3)
            XCTAssertEqual(Set(messages.map { $0.id }).count, 3)
            XCTAssertEqual(Set(messages.map { $0.timestamp }), [2000, 2500, 3000])
            XCTAssertTrue(messages.allSatisfy { !self.hasCollective($0) && $0.threadId == 200 && $0.forwardInfo?.author?.id == self.authorId })
        }
    }

}
