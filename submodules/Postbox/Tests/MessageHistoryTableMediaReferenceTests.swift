import Foundation
import XCTest
@testable import Postbox

/// A media shared by two or more messages lives in one `Direct` row whose count is
/// the number of messages referencing it. Every write path that touches a message
/// must leave that count equal to the number of live referencing messages, or the
/// row (and for secret chats, its key) is never freed.
final class MessageHistoryTableMediaReferenceTests: XCTestCase {
    private var fixture: MessageHistoryTableFixture!

    private let peer: Int64 = 100
    private let sharedMediaId = MediaId(namespace: 0, id: 555)

    override func setUp() {
        super.setUp()
        self.fixture = MessageHistoryTableFixture(name: "MessageHistoryTableMediaReferenceTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func message(_ id: Int32, text: String = "", media: [Media]) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: MessageHistoryTableFixture.messageId(peer: self.peer, id: id), timestamp: 1000 + id, text: text, media: media)
    }

    private func shared() -> FixtureMedia {
        return FixtureMedia(id: self.sharedMediaId, label: "sticker")
    }

    /// Two messages referencing the same media: the row is `Direct` with count 2.
    private func addTwoMessagesSharingTheMedia() {
        self.fixture.addMessages([self.message(1, media: [self.shared()]), self.message(2, media: [self.shared()])])
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 2)
    }

    // MARK: - Tests

    func testReAddingAnUnchangedMessageKeepsTheSharedReferenceCount() {
        self.addTwoMessagesSharingTheMedia()

        // An overlapping history fetch delivers message 1 again, byte-for-byte the same.
        self.fixture.addMessages([self.message(1, media: [self.shared()])])

        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 2)
    }

    func testEditingAMessageInPlaceKeepsTheSharedReferenceCount() {
        self.addTwoMessagesSharingTheMedia()

        // An edit changes the text but keeps the same media and the same index.
        self.fixture.updateMessage(MessageHistoryTableFixture.messageId(peer: self.peer, id: 1), message: self.message(1, text: "edited", media: [self.shared()]))

        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 2)
    }

    func testSharedMediaRowIsFreedOnceEveryReferencingMessageIsGone() {
        self.addTwoMessagesSharingTheMedia()
        self.fixture.addMessages([self.message(1, media: [self.shared()])])
        self.fixture.updateMessage(MessageHistoryTableFixture.messageId(peer: self.peer, id: 2), message: self.message(2, text: "edited", media: [self.shared()]))

        self.fixture.removeMessages([MessageHistoryTableFixture.messageId(peer: self.peer, id: 1), MessageHistoryTableFixture.messageId(peer: self.peer, id: 2)])

        XCTAssertNil(self.fixture.mediaEntry(self.sharedMediaId), "no message references the media any more, so its row must be gone")
    }

    func testChangingHowOftenAMessageReferencesAMediaKeepsTheCountExact() {
        self.addTwoMessagesSharingTheMedia()

        // The same media id twice in one message counts twice, so the multiplicity
        // matters even though the set of ids is unchanged.
        self.fixture.addMessages([self.message(1, media: [self.shared(), self.shared()])])
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 3)

        self.fixture.addMessages([self.message(1, media: [self.shared()])])
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 2)

        self.fixture.addMessages([self.message(1, media: [self.shared(), self.shared()])])
        self.fixture.removeMessages([MessageHistoryTableFixture.messageId(peer: self.peer, id: 1)])
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 1, "message 2 still references the media")
    }

    // MARK: - Guards: the paths that already worked must keep working

    func testChangingAMessagesTimestampKeepsTheSharedReferenceCount() {
        self.addTwoMessagesSharingTheMedia()

        // A sent message gets its server timestamp: same media, different index.
        self.fixture.updateMessageTimestamp(MessageHistoryTableFixture.messageId(peer: self.peer, id: 1), timestamp: 5000)
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 2)

        self.fixture.removeMessages([MessageHistoryTableFixture.messageId(peer: self.peer, id: 1)])
        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 1)
    }

    func testReplacingAMessagesMediaReleasesTheOldReference() {
        self.addTwoMessagesSharingTheMedia()

        let other = FixtureMedia(id: MediaId(namespace: 0, id: 777), label: "photo")
        self.fixture.updateMessage(MessageHistoryTableFixture.messageId(peer: self.peer, id: 1), message: self.message(1, media: [other]))

        XCTAssertEqual(self.fixture.referenceCount(self.sharedMediaId), 1)
        XCTAssertNotNil(self.fixture.mediaEntry(other.id!))
    }

    func testReAddingAMessageWithEmbeddedMediaKeepsItEmbedded() {
        let only = FixtureMedia(id: MediaId(namespace: 0, id: 888), label: "photo")
        self.fixture.addMessages([self.message(3, media: [only])])
        self.fixture.addMessages([self.message(3, media: [only])])

        guard case .MessageReference(let index)? = self.fixture.mediaEntry(only.id!) else {
            return XCTFail("a media referenced by one message stays embedded in it")
        }
        XCTAssertEqual(index.id, MessageHistoryTableFixture.messageId(peer: self.peer, id: 3))

        self.fixture.removeMessages([MessageHistoryTableFixture.messageId(peer: self.peer, id: 3)])
        XCTAssertNil(self.fixture.mediaEntry(only.id!))
    }

    func testSecondMessageSharingAnEmbeddedMediaPromotesItToACountedRow() {
        let only = FixtureMedia(id: MediaId(namespace: 0, id: 999), label: "gif")
        self.fixture.addMessages([self.message(4, media: [only])])
        self.fixture.addMessages([self.message(5, media: [only])])

        XCTAssertEqual(self.fixture.referenceCount(only.id!), 2)

        self.fixture.removeMessages([MessageHistoryTableFixture.messageId(peer: self.peer, id: 4)])
        XCTAssertEqual(self.fixture.referenceCount(only.id!), 1)
    }
}
