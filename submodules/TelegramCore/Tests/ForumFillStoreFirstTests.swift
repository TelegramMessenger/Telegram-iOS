import XCTest
import Postbox
@testable import TelegramCore

/// A forum fill resolves what its messages reference before storing them only when one of the messages belongs to a
/// topic whose info is not stored: topic headers read that info while drawing. Otherwise it stores first.
final class ForumFillStoreFirstTests: XCTestCase {
    func testKnownTopicsStoreFirst() {
        XCTAssertTrue(forumFillStoresFirst(fetchedThreadIds: [5], storedThreadIds: [1, 5], answerThreadIds: []))
    }
    
    func testUnknownTopicResolvesFirst() {
        XCTAssertFalse(forumFillStoresFirst(fetchedThreadIds: [5, 9], storedThreadIds: [5], answerThreadIds: []))
    }
    
    func testNoTopicsStoreFirst() {
        XCTAssertTrue(forumFillStoresFirst(fetchedThreadIds: [], storedThreadIds: [], answerThreadIds: []))
    }
    
    func testAnswerTopicsCount() {
        // A topic the answer carries is stored together with its messages, so it counts as known.
        XCTAssertTrue(forumFillStoresFirst(fetchedThreadIds: [5, 9], storedThreadIds: [5], answerThreadIds: [9]))
    }
    
    // MARK: - Reply targets a fill waits for
    
    private let forum = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1003073997))
    
    func testForumTopicRootIsNotPending() {
        // Every topic message replies to its topic's root, which is usually not stored and never drawn as a header.
        let root = MessageId(peerId: self.forum, namespace: Namespaces.Message.Cloud, id: 24623760)
        XCTAssertEqual(pendingReplyTargets(replyTargets: [root], messageThreadId: 24623760, peerIsForum: true), [])
    }
    
    func testForumReplyIsPending() {
        let target = MessageId(peerId: self.forum, namespace: Namespaces.Message.Cloud, id: 25279591)
        XCTAssertEqual(pendingReplyTargets(replyTargets: [target], messageThreadId: 24623760, peerIsForum: true), [target])
    }
    
    func testNonForumThreadRootIsPending() {
        // Outside forums a thread's root draws as a header (comments, group threads), so it is waited for.
        let root = MessageId(peerId: self.forum, namespace: Namespaces.Message.Cloud, id: 70)
        XCTAssertEqual(pendingReplyTargets(replyTargets: [root], messageThreadId: 70, peerIsForum: false), [root])
    }
}
