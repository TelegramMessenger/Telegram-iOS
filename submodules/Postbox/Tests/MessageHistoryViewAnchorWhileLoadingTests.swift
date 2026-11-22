import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A view opened around a message that is stored but still inside a hole reports loading with no
/// entries. With `includeAnchorWhileLoading` it carries that message and its album, so a chat can show
/// a cached post before the hole is filled, and it follows an edit or a deletion of the post meanwhile.
final class MessageHistoryViewAnchorWhileLoadingTests: XCTestCase {
    private var fixture: PostboxFixture!
    private let chat = FixturePeer(id: MessageHistoryTableFixture.peerId(700), title: "chat")

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "MessageHistoryViewAnchorWhileLoadingTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.chat], update: { _, updated in updated })
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func messageId(_ id: Int32) -> MessageId {
        return MessageHistoryTableFixture.messageId(peer: 700, id: id)
    }

    private func message(id: Int32, timestamp: Int32, text: String, groupingKey: Int64? = nil) -> StoreMessage {
        return StoreMessage(id: self.messageId(id), customStableId: nil, globallyUniqueId: nil, groupingKey: groupingKey, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: text, attributes: [], media: [])
    }

    private func store(_ messages: [StoreMessage]) {
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages(messages, location: .Random)
        }
    }

    /// The history view around `id`, as the chat opens it. The fixture seeds every peer with a whole-history
    /// hole, so a stored message sits inside the hole until `removeHole`.
    private func observeAround(id: Int32, includeAnchor: Bool) -> PostboxFixture.Recorder<MessageHistoryView> {
        return self.fixture.observe(self.fixture.postbox.aroundIdMessageHistoryViewForLocation(.peer(peerId: self.chat.id, threadId: nil), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 10, trackHoles: true, clipHoles: true, ignoreRelatedChats: false, messageId: self.messageId(id), topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: [], additionalData: [], useRootInterfaceStateForThread: false, includeAnchorWhileLoading: includeAnchor) |> map { $0.0 })
    }

    private func texts(_ view: MessageHistoryView) -> [String] {
        return view.entries.map { $0.message.text }
    }

    func testStoredAnchorInsideAHoleIsCarriedWhileLoading() {
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let view = self.observeAround(id: 5, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertTrue(view.isAnchorOnlyWhileLoading)
        XCTAssertTrue(view.isLoadingEarlier)
        XCTAssertTrue(view.holeEarlier)
        XCTAssertTrue(view.holeLater)
        XCTAssertEqual(self.texts(view), ["post"])
        if case let .message(index) = view.anchorIndex {
            XCTAssertEqual(index.id, self.messageId(5))
        } else {
            XCTFail("anchor index is \(view.anchorIndex)")
        }
    }

    func testAlbumSiblingsAreCarriedWhenOpenedByASibling() {
        self.store([self.message(id: 5, timestamp: 50, text: "a", groupingKey: 1), self.message(id: 6, timestamp: 50, text: "b", groupingKey: 1)])
        let view = self.observeAround(id: 6, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertTrue(view.isAnchorOnlyWhileLoading)
        XCTAssertEqual(self.texts(view), ["a", "b"])
    }

    func testFlagOffKeepsTheLoadingViewEmpty() {
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let view = self.observeAround(id: 5, includeAnchor: false).waitForValues(count: 1).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertFalse(view.isAnchorOnlyWhileLoading)
        XCTAssertTrue(view.entries.isEmpty)
    }

    func testMissingAnchorKeepsTheLoadingViewEmpty() {
        let view = self.observeAround(id: 5, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertFalse(view.isAnchorOnlyWhileLoading)
        XCTAssertTrue(view.entries.isEmpty)
    }

    /// A joined channel with unread messages: the generic read-index pass would place the read edge just
    /// below the post (the only entry), and the chat would draw an unread separator above it. A partial
    /// view makes no read claim.
    func testPartialViewMakesNoReadClaim() {
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.chat.id: [MessageHistoryTableFixture.messageNamespace: .idBased(maxIncomingReadId: 3, maxOutgoingReadId: 0, maxKnownId: 10, count: 2, markedUnread: false)]])
        }
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let view = self.observeAround(id: 5, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertTrue(view.isAnchorOnlyWhileLoading)
        XCTAssertEqual(self.texts(view), ["post"])
        XCTAssertNil(view.maxReadIndex)
    }

    func testEditWhileLoadingUpdatesTheEntry() {
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let recorder = self.observeAround(id: 5, includeAnchor: true)
        let _ = recorder.waitForValues(count: 1)
        let edited = self.message(id: 5, timestamp: 50, text: "edited")
        self.fixture.transaction { transaction in
            transaction.updateMessage(self.messageId(5), update: { _ in .update(edited) })
        }
        let view = recorder.waitForValues(count: 2).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertEqual(self.texts(view), ["edited"])
    }

    func testDeletionWhileLoadingEmptiesTheView() {
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let recorder = self.observeAround(id: 5, includeAnchor: true)
        let _ = recorder.waitForValues(count: 1)
        self.fixture.transaction { transaction in
            transaction.deleteMessages([self.messageId(5)], forEachMedia: nil)
        }
        let view = recorder.waitForValues(count: 2).last!
        XCTAssertTrue(view.isLoading)
        XCTAssertFalse(view.isAnchorOnlyWhileLoading)
        XCTAssertTrue(view.entries.isEmpty)
    }

    func testRemovingTheHoleLoadsTheSameAnchorOnce() {
        self.store([self.message(id: 5, timestamp: 50, text: "post")])
        let recorder = self.observeAround(id: 5, includeAnchor: true)
        let _ = recorder.waitForValues(count: 1)
        self.fixture.transaction { transaction in
            transaction.removeHole(peerId: self.chat.id, threadId: nil, namespace: MessageHistoryTableFixture.messageNamespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
        let view = recorder.waitForValues(count: 2).last!
        XCTAssertFalse(view.isLoading)
        XCTAssertFalse(view.isAnchorOnlyWhileLoading)
        XCTAssertEqual(self.texts(view), ["post"])
        XCTAssertEqual(view.entries.map { $0.message.id }, [self.messageId(5)])
        if case let .message(index) = view.anchorIndex {
            XCTAssertEqual(index.id, self.messageId(5))
        } else {
            XCTFail("anchor index is \(view.anchorIndex)")
        }
    }

    // MARK: a loaded view with holes near the anchor (a joined channel)

    /// A joined channel: the update stream filled its history from the top, so the view around a feed post is
    /// loaded, but the older history below the post is still a hole, holding an older post the feed stored out of
    /// history (id 3), which makes the view report a hole earlier. The chat cannot show that window yet; the
    /// anchor-only copy is what it shows meanwhile, exactly as for a post inside a hole.
    private func storeJoinedChannelHistory(albumAt anchorGroup: Int64? = nil) {
        self.store([
            self.message(id: 3, timestamp: 30, text: "older"),
            self.message(id: 5, timestamp: 50, text: "a", groupingKey: anchorGroup),
            self.message(id: 6, timestamp: 60, text: "b", groupingKey: anchorGroup),
            self.message(id: 7, timestamp: 70, text: "c")
        ])
        self.fixture.transaction { transaction in
            transaction.removeHole(peerId: self.chat.id, threadId: nil, namespace: MessageHistoryTableFixture.messageNamespace, space: .everywhere, range: 5 ... (Int32.max - 1))
        }
    }

    func testALoadedViewWithAHoleBelowIsLoadedNotPartial() {
        self.storeJoinedChannelHistory()
        let view = self.observeAround(id: 6, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertFalse(view.isLoading)
        XCTAssertFalse(view.isAnchorOnlyWhileLoading)
        XCTAssertTrue(view.holeEarlier)
        XCTAssertEqual(self.texts(view), ["a", "b", "c"])
    }

    func testAnchorOnlyCopyCarriesTheAnchorAsALoadingViewDoes() {
        self.storeJoinedChannelHistory()
        let view = self.observeAround(id: 6, includeAnchor: true).waitForValues(count: 1).last!
        guard let copy = view.anchorOnlyWhileLoading() else {
            XCTFail("no anchor-only copy")
            return
        }
        XCTAssertEqual(self.texts(copy), ["b"])
        XCTAssertTrue(copy.isLoading)
        XCTAssertTrue(copy.isLoadingEarlier)
        XCTAssertTrue(copy.isAnchorOnlyWhileLoading)
        XCTAssertTrue(copy.holeEarlier)
        XCTAssertTrue(copy.holeLater)
        if case let .message(index) = copy.anchorIndex {
            XCTAssertEqual(index.id, self.messageId(6))
        } else {
            XCTFail("anchor index is \(copy.anchorIndex)")
        }
    }

    func testAnchorOnlyCopyKeepsTheAnchorsAlbum() {
        self.storeJoinedChannelHistory(albumAt: 1)
        let view = self.observeAround(id: 6, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertEqual(view.anchorOnlyWhileLoading().map(self.texts), ["a", "b"])
    }

    func testAnchorOnlyCopyMakesNoReadClaim() {
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.chat.id: [MessageHistoryTableFixture.messageNamespace: .idBased(maxIncomingReadId: 5, maxOutgoingReadId: 0, maxKnownId: 7, count: 2, markedUnread: false)]])
        }
        self.storeJoinedChannelHistory()
        let view = self.observeAround(id: 6, includeAnchor: true).waitForValues(count: 1).last!
        XCTAssertNil(view.anchorOnlyWhileLoading()?.maxReadIndex)
    }

    func testNoAnchorOnlyCopyWithoutAMessageAnchor() {
        let view = MessageHistoryView(tag: nil, namespaces: .all, entries: [], holeEarlier: true, holeLater: true, isLoading: false)
        XCTAssertNil(view.anchorOnlyWhileLoading())
    }
}
