import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The channel arm of `deleteStoredMessagesAsReceivedDeletion` (StoredMessageConfirmation.swift; the account reset
/// deletes a channel's ghost tail with it), reached here through `applyStoredMessageConfirmation`, deletes a missing
/// channel message as a received `updateDeleteChannelMessages` does (`.DeleteMessages`, `applyDeleteMessages` in
/// StateReplay+Messages.swift, `_internal_deleteMessages` in DeleteMessages.swift), not as a plain
/// `transaction.deleteMessages`: the thread the message replied in counts one reply less, and an ephemeral
/// replacement anchored to the message goes with it.
/// StoredMessageConfirmationTests.testApplyDeletesAMissingChannelMessage only checks that the message is
/// gone, which a plain delete also passes. Driven directly: no state manager.
final class ConfirmationChannelDeletionTests: StateSyncTestCase {
    /// A supergroup (`.group` info: thread stats are kept for groups, not broadcasts) the account is in, at pts 10.
    private func seedSupergroup(_ id: Int64) -> PeerId {
        let peerId = StateSyncFixture.channelPeerId(id)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: peerId, accessHash: 1, title: "G\(id)", isBroadcast: false), state: ChannelState(pts: 10, invalidatedPts: nil, synchronizedUntilMessageId: nil))
        self.fixture.seedChat(peerId: peerId)
        return peerId
    }

    /// Stores message `id` (`.Random`: no hole moves) in thread `threadId` with `attributes`.
    private func store(_ id: MessageId, threadId: Int64?, attributes: [MessageAttribute] = []) {
        let message = StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: self.baseDate + id.id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "stored", attributes: attributes, media: [])
        self.fixture.transaction { transaction -> Void in
            let _ = transaction.addMessages([message], location: .Random)
        }
    }

    /// Applies a confirmation in which the server no longer has `ids`, with the versions they are stored at
    /// now, as a caller that read them just before would.
    private func applyMissing(_ ids: [MessageId], file: StaticString = #filePath, line: UInt = #line) -> [MessageId]? {
        let versions = self.fixture.transaction { transaction -> [MessageId: UInt32] in
            var result: [MessageId: UInt32] = [:]
            for id in ids {
                if let message = transaction.getMessage(id) {
                    result[id] = message.stableVersion
                }
            }
            return result
        } ?? [:]
        let mediaBox = self.fixture.postbox.mediaBox
        let confirmation = StoredMessageConfirmation(existing: [], peers: AccumulatedPeers(), missing: Set(ids))
        return self.fixture.transaction({ transaction -> [MessageId] in
            return applyStoredMessageConfirmation(transaction: transaction, accountPeerId: StateSyncFixture.accountPeerId, mediaBox: mediaBox, confirmation: confirmation, versions: versions)
        }, file: file, line: line)
    }

    /// The reply count of the thread rooted at `id` (its `ReplyThreadMessageAttribute`).
    private func replyCount(_ id: MessageId) -> Int32? {
        let attribute = self.fixture.message(id)?.attributes.first(where: { $0 is ReplyThreadMessageAttribute }) as? ReplyThreadMessageAttribute
        return attribute?.count
    }

    /// Thread 5 has two replies, 6 and 7. The server no longer has 6: it is deleted, and the root's reply count
    /// drops to 1, as `updateMessageThreadStats` does for a received channel deletion.
    func testAMissingReplyLeavesItsThreadOneReplyShorter() {
        let group = self.seedSupergroup(340)
        let root = self.messageId(group, 5)
        self.store(root, threadId: 1, attributes: [ReplyThreadMessageAttribute(count: 2, latestUsers: [], commentsPeerId: nil, maxMessageId: 7, maxReadMessageId: nil)])
        self.store(self.messageId(group, 6), threadId: 5)
        self.store(self.messageId(group, 7), threadId: 5)
        XCTAssertEqual(self.replyCount(root), 2, "precondition")

        let deleted = self.applyMissing([self.messageId(group, 6)])

        XCTAssertEqual(deleted, [self.messageId(group, 6)])
        XCTAssertNil(self.fixture.message(self.messageId(group, 6)))
        XCTAssertNotNil(self.fixture.message(self.messageId(group, 7)))
        XCTAssertEqual(self.replyCount(root), 1, "the thread still counts the deleted reply: the channel message was deleted as plain storage, not as a received channel deletion")
    }

    /// Message 8 is the anchor of an ephemeral replacement (`EphemeralReplacementMessageAttribute`, the
    /// replacement stored in `Namespaces.Message.EphemeralAnchored`). The server no longer has 8: the
    /// replacement is deleted with it.
    func testAMissingAnchorTakesItsEphemeralReplacementWithIt() {
        let group = self.seedSupergroup(341)
        let anchor = self.messageId(group, 8)
        let replacement = MessageId(peerId: group, namespace: Namespaces.Message.EphemeralAnchored, id: 1)
        self.store(replacement, threadId: 1)
        self.store(anchor, threadId: 1, attributes: [EphemeralReplacementMessageAttribute(state: .active, replacementMessageId: replacement, receiverId: 0)])
        XCTAssertNotNil(self.fixture.message(replacement), "precondition")

        let deleted = self.applyMissing([anchor])

        XCTAssertEqual(deleted, [anchor])
        XCTAssertNil(self.fixture.message(anchor))
        XCTAssertNil(self.fixture.message(replacement), "the anchor's ephemeral replacement outlived it: the channel message was deleted as plain storage, not as a received channel deletion")
    }
}
