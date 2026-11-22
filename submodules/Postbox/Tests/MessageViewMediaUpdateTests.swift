import Foundation
import XCTest
@testable import Postbox

/// The single-message and multi-message views must show a media update the same way
/// the full history view does, whether the media is embedded in the one message that
/// uses it or shared by several messages through a media record of its own.
final class MessageViewMediaUpdateTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let peer: Int64 = 600
    private let sharedMediaId = MediaId(namespace: 0, id: 6001)
    private let embeddedMediaId = MediaId(namespace: 0, id: 6002)
    private let albumMediaId = MediaId(namespace: 0, id: 6003)
    private let albumGroupingKey: Int64 = 77

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "MessageViewMediaUpdateTests")
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([
                self.message(1, media: FixtureMedia(id: self.sharedMediaId, label: "old")),
                self.message(2, media: FixtureMedia(id: self.sharedMediaId, label: "old")),
                self.message(3, media: FixtureMedia(id: self.embeddedMediaId, label: "old")),
                // An album of two messages whose photos share one media record.
                self.message(4, media: FixtureMedia(id: self.albumMediaId, label: "old"), groupingKey: self.albumGroupingKey),
                self.message(5, media: FixtureMedia(id: self.albumMediaId, label: "old"), groupingKey: self.albumGroupingKey),
            ], location: .Random)
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func messageId(_ id: Int32) -> MessageId {
        return MessageHistoryTableFixture.messageId(peer: self.peer, id: id)
    }

    private func message(_ id: Int32, media: Media, groupingKey: Int64? = nil) -> StoreMessage {
        return StoreMessage(id: self.messageId(id), customStableId: nil, globallyUniqueId: nil, groupingKey: groupingKey, threadId: nil, timestamp: 1000 + id, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "m\(id)", attributes: [], media: [media])
    }

    private func label(of message: Message?) -> String? {
        return (message?.media.first as? FixtureMedia)?.label
    }

    private func update(_ mediaId: MediaId, to label: String) {
        self.fixture.transaction { transaction in
            let _ = transaction.updateMedia(mediaId, update: FixtureMedia(id: mediaId, label: label))
        }
    }

    // MARK: - Shared media (a record of its own, no history operation)

    func testSingleMessageViewShowsAnUpdateToSharedMedia() {
        let recorder = self.fixture.observeMessage(self.messageId(1))
        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 1).last?.message), "old")

        self.update(self.sharedMediaId, to: "new")

        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 2).last?.message), "new")
    }

    func testMessagesViewShowsAnUpdateToSharedMedia() {
        let recorder = self.fixture.observe(.messages([self.messageId(1), self.messageId(2)]), as: MessagesView.self)
        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 1).last?.messages[self.messageId(2)]), "old")

        self.update(self.sharedMediaId, to: "new")

        let view = recorder.waitForValues(count: 2).last
        XCTAssertEqual(self.label(of: view?.messages[self.messageId(1)]), "new")
        XCTAssertEqual(self.label(of: view?.messages[self.messageId(2)]), "new")
    }

    /// The view was opened on the local id; the server then confirms the message under
    /// a new id, which the view follows through the unchanged stable id.
    func testSingleMessageViewFollowsAnIdChangeAndStillShowsMediaUpdates() {
        let recorder = self.fixture.observeMessage(self.messageId(1))
        recorder.waitForValues(count: 1)

        let confirmedId = self.messageId(100)
        self.fixture.transaction { transaction in
            transaction.updateMessage(self.messageId(1), update: { message in
                return .update(MessageHistoryTableFixture.storeMessage(id: confirmedId, timestamp: message.timestamp, text: message.text, media: message.media))
            })
        }
        XCTAssertEqual(recorder.waitForValues(count: 2).last?.message?.id, confirmedId)

        self.update(self.sharedMediaId, to: "new")

        let view = recorder.waitForValues(count: 3).last
        XCTAssertEqual(view?.message?.id, confirmedId, "the view must keep the message it followed, not blank itself")
        XCTAssertEqual(self.label(of: view?.message), "new")
    }

    // MARK: - Embedded media (rewritten inside the message, reported as an operation)

    func testSingleMessageViewShowsAnUpdateToEmbeddedMedia() {
        let recorder = self.fixture.observeMessage(self.messageId(3))
        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 1).last?.message), "old")

        self.update(self.embeddedMediaId, to: "new")

        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 2).last?.message), "new")
    }

    func testMessagesViewShowsAnUpdateToEmbeddedMedia() {
        let recorder = self.fixture.observe(.messages([self.messageId(3)]), as: MessagesView.self)
        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 1).last?.messages[self.messageId(3)]), "old")

        self.update(self.embeddedMediaId, to: "new")

        XCTAssertEqual(self.label(of: recorder.waitForValues(count: 2).last?.messages[self.messageId(3)]), "new")
    }

    func testBothViewsShowTheRemovalOfEmbeddedMedia() {
        let single = self.fixture.observeMessage(self.messageId(3))
        let multiple = self.fixture.observe(.messages([self.messageId(3)]), as: MessagesView.self)
        single.waitForValues(count: 1)
        multiple.waitForValues(count: 1)

        self.fixture.transaction { transaction in
            let _ = transaction.updateMedia(self.embeddedMediaId, update: nil)
        }

        XCTAssertEqual(single.waitForValues(count: 2).last?.message?.media.count, 0)
        XCTAssertEqual(multiple.waitForValues(count: 2).last?.messages[self.messageId(3)]?.media.count, 0)
    }

    // MARK: - Album view

    func testMessageGroupViewShowsAnUpdateToSharedMedia() {
        let recorder = self.fixture.observe(.messageGroup(id: self.messageId(4)), as: MessageGroupView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.messages.map { self.label(of: $0) }, ["old", "old"])

        self.update(self.albumMediaId, to: "new")

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.messages.map { self.label(of: $0) }, ["new", "new"])
    }
}
