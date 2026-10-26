import XCTest
import Postbox
@testable import TelegramCore

/// The thread context skips its own getDiscussionMessage when the opener fetched the same thread
/// moments ago (both answers carry the same read state, measured 2026-10-20).
final class RecentDiscussionMessageFetchesTests: XCTestCase {
    private let group = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1050402467))
    
    func testFreshWithinWindow() {
        var now = 0.0
        let fetches = RecentDiscussionMessageFetches(now: { now })
        fetches.noteFetched(PeerAndBoundThreadId(peerId: self.group, threadId: 2025928))
        now = 29.9
        XCTAssertTrue(fetches.wasFetchedRecently(PeerAndBoundThreadId(peerId: self.group, threadId: 2025928)))
    }
    
    func testStaleAfterWindow() {
        var now = 0.0
        let fetches = RecentDiscussionMessageFetches(now: { now })
        fetches.noteFetched(PeerAndBoundThreadId(peerId: self.group, threadId: 2025928))
        now = 30.1
        XCTAssertFalse(fetches.wasFetchedRecently(PeerAndBoundThreadId(peerId: self.group, threadId: 2025928)))
    }
    
    func testOtherThreadIsNotFresh() {
        let fetches = RecentDiscussionMessageFetches(now: { 0.0 })
        fetches.noteFetched(PeerAndBoundThreadId(peerId: self.group, threadId: 1))
        XCTAssertFalse(fetches.wasFetchedRecently(PeerAndBoundThreadId(peerId: self.group, threadId: 2)))
    }
}
