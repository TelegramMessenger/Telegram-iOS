import XCTest
import Postbox
@testable import TelegramCore

/// Opening a thread sends `getReplies` beside `getDiscussionMessage` when the ids it needs are already
/// known, and reconciles once the server has answered: the server's anchor always decides where the
/// thread opens, a fill for another thread is never applied, and anything not covered falls back to
/// the sequential fill (which checks the cache before it sends).
final class ReplyThreadOpenPlanTests: XCTestCase {
    private let target = ReplyThreadFillTarget.channelPost(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 6860))

    // MARK: - The time-zero plan

    func testNoTargetIsSequential() {
        XCTAssertEqual(replyThreadOpenPlan(target: nil, storedReplies: ReplyThreadStoredReplies(maxMessageId: 900, maxReadMessageId: 800), linkedCommentId: 500, cachedWindowIsComplete: nil), .sequential)
    }

    func testNoAttributeNoLinkIsSequential() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: nil, linkedCommentId: nil, cachedWindowIsComplete: nil), .sequential)
    }

    func testNoAttributeWithLinkIsParallel() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: nil, linkedCommentId: 500, cachedWindowIsComplete: nil), .parallel(self.target, .around(500)))
    }

    func testEmptyAttributeIsDiscussionOnly() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: ReplyThreadStoredReplies(maxMessageId: nil, maxReadMessageId: nil), linkedCommentId: nil, cachedWindowIsComplete: nil), .discussionOnly)
    }

    func testLinkBeatsEmptyAttribute() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: ReplyThreadStoredReplies(maxMessageId: nil, maxReadMessageId: nil), linkedCommentId: 500, cachedWindowIsComplete: nil), .parallel(self.target, .around(500)))
    }

    func testCompleteCacheIsDiscussionOnly() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: ReplyThreadStoredReplies(maxMessageId: 900, maxReadMessageId: 800), linkedCommentId: nil, cachedWindowIsComplete: true), .discussionOnly)
    }

    func testReadPositionAnchors() {
        let replies = ReplyThreadStoredReplies(maxMessageId: 900, maxReadMessageId: 800)
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: replies, linkedCommentId: nil, cachedWindowIsComplete: false), .parallel(self.target, .around(800)))
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: replies, linkedCommentId: nil, cachedWindowIsComplete: nil), .parallel(self.target, .around(800)))
    }

    func testNoReadPositionIsOldest() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: ReplyThreadStoredReplies(maxMessageId: 900, maxReadMessageId: nil), linkedCommentId: nil, cachedWindowIsComplete: false), .parallel(self.target, .oldest))
    }

    func testLinkBeatsReadPosition() {
        XCTAssertEqual(replyThreadOpenPlan(target: self.target, storedReplies: ReplyThreadStoredReplies(maxMessageId: 900, maxReadMessageId: 800), linkedCommentId: 500, cachedWindowIsComplete: false), .parallel(self.target, .around(500)))
    }

    // MARK: - What a thread open can request before the server answers
    
    private let group = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(2))
    
    func testBroadcastPostTargetsThePost() {
        let post = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: 6860)
        XCTAssertEqual(replyThreadFillTarget(chat: .broadcastChannel, messageId: post, subjectThreadId: nil), .channelPost(post))
    }
    
    func testGroupMessageTargetsItsOwnThread() {
        let message = MessageId(peerId: self.group, namespace: Namespaces.Message.Cloud, id: 70)
        XCTAssertEqual(replyThreadFillTarget(chat: .nonForumGroup, messageId: message, subjectThreadId: nil), .groupThread(peerId: self.group, threadId: 70))
    }
    
    func testGroupReplyTargetsItsThreadRoot() {
        let reply = MessageId(peerId: self.group, namespace: Namespaces.Message.Cloud, id: 75)
        XCTAssertEqual(replyThreadFillTarget(chat: .nonForumGroup, messageId: reply, subjectThreadId: 70), .groupThread(peerId: self.group, threadId: 70))
    }
    
    func testOtherChatsHaveNoTarget() {
        let message = MessageId(peerId: self.group, namespace: Namespaces.Message.Cloud, id: 70)
        XCTAssertNil(replyThreadFillTarget(chat: .other, messageId: message, subjectThreadId: nil))
    }
    
    // MARK: - Whether a fill belongs to the thread the server named
    
    func testChannelPostEmptyAnswerMatches() {
        XCTAssertTrue(replyThreadFillMatchesServerThread(target: self.target, actualPeerId: nil, actualThreadId: nil, serverPeerId: self.group, serverThreadId: 7))
    }
    
    func testChannelPostAnswerFromAnotherThreadDoesNotMatch() {
        XCTAssertFalse(replyThreadFillMatchesServerThread(target: self.target, actualPeerId: self.group, actualThreadId: 5, serverPeerId: self.group, serverThreadId: 7))
    }
    
    func testGroupThreadEmptyAnswerForAnotherThreadDoesNotMatch() {
        // An empty answer carries no thread; the request named thread 5, so its whole-range fill is thread 5's.
        XCTAssertFalse(replyThreadFillMatchesServerThread(target: .groupThread(peerId: self.group, threadId: 5), actualPeerId: nil, actualThreadId: nil, serverPeerId: self.group, serverThreadId: 7))
    }
    
    func testGroupThreadSameThreadMatches() {
        XCTAssertTrue(replyThreadFillMatchesServerThread(target: .groupThread(peerId: self.group, threadId: 7), actualPeerId: nil, actualThreadId: nil, serverPeerId: self.group, serverThreadId: 7))
    }
    
    // MARK: - The server's anchor

    func testServerAnchorOrder() {
        XCTAssertEqual(replyThreadServerAnchor(linkedCommentId: 500, readInboxMaxId: 800), .around(500))
        XCTAssertEqual(replyThreadServerAnchor(linkedCommentId: nil, readInboxMaxId: 800), .around(800))
        XCTAssertEqual(replyThreadServerAnchor(linkedCommentId: nil, readInboxMaxId: nil), .oldest)
    }

    // MARK: - Reconciling with the server's answer

    func testServerEmptyWins() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: false, serverAnchor: .around(800), fill: .succeeded(usedAnchor: .around(800), matchesServerThread: true)), .empty)
    }

    func testFailedFillRefills() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: true, serverAnchor: .around(800), fill: .failed), .refill(.around(800)))
    }

    func testMismatchedThreadRefills() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: true, serverAnchor: .around(800), fill: .succeeded(usedAnchor: .around(800), matchesServerThread: false)), .refill(.around(800)))
    }

    func testSameAnchorAccepts() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: true, serverAnchor: .around(800), fill: .succeeded(usedAnchor: .around(800), matchesServerThread: true)), .accept)
    }

    func testStaleAnchorRefills() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: true, serverAnchor: .around(800), fill: .succeeded(usedAnchor: .around(700), matchesServerThread: true)), .refill(.around(800)))
    }

    func testNotSentAlwaysRefills() {
        XCTAssertEqual(replyThreadReconcile(serverHasComments: true, serverAnchor: .around(800), fill: .notSent), .refill(.around(800)))
    }
}
