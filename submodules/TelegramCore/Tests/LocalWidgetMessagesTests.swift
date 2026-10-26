import XCTest
import Postbox
@testable import TelegramCore

/// The debug insertion of widget messages into a chat (the conformance set, the corpus): local messages, one per post and
/// one per reference picture after it, in order, as the shared test channel posts them.
final class LocalWidgetMessagesTests: XCTestCase {
    private let account = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
    private let other = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2))

    private func posts() -> [EngineLocalWidgetPost] {
        return [
            EngineLocalWidgetPost(html: "<p>one</p>", width: 0, height: 0, caption: "visual/01 · boxes", photos: []),
            EngineLocalWidgetPost(html: "<p>two</p>", width: 300, height: 0, caption: "", photos: [EngineLocalWidgetPost.Photo(png: Data([0x89, 0x50]), width: 780, height: 420)])
        ]
    }

    func testEachPostIsAWidgetMessageThenItsPhotos() {
        let resources = [[], [LocalFileMediaResource(fileId: 7)]]
        let messages = _internal_localWidgetStoreMessages(posts: self.posts(), photoResources: resources, peerId: self.account, accountPeerId: self.account, lastTimestamp: 1_000)
        XCTAssertEqual(messages.count, 3)
        guard messages.count == 3 else {
            return
        }
        let first = messages[0].media.first as? TelegramMediaWidget
        XCTAssertEqual(first?.html(), "<p>one</p>")
        XCTAssertEqual(messages[0].text, "visual/01 · boxes")
        let second = messages[1].media.first as? TelegramMediaWidget
        XCTAssertEqual(second?.width, 300)
        XCTAssertEqual(second?.height, 0)
        XCTAssertEqual(second?.html(), "<p>two</p>")
        let image = messages[2].media.first as? TelegramMediaImage
        XCTAssertEqual(image?.imageId.namespace, Namespaces.Media.LocalImage)
        XCTAssertEqual(image?.representations.first?.dimensions, PixelDimensions(width: 780, height: 420))
        XCTAssertEqual(messages.map(\.timestamp), [998, 999, 1_000])
        for message in messages {
            guard case let .Partial(peerId, namespace) = message.id else {
                return XCTFail("\(message.id)")
            }
            XCTAssertEqual(peerId, self.account)
            XCTAssertEqual(namespace, Namespaces.Message.Local)
            XCTAssertEqual(message.authorId, self.account)
            XCTAssertNotNil(message.globallyUniqueId)
        }
        XCTAssertEqual(Set(messages.compactMap(\.globallyUniqueId)).count, 3)
    }

    /// The reference pictures open in the gallery and show in the Media tab, which read the `.photoOrVideo` tag; and
    /// nothing inserted is ever sent (no `.Unsent`, the pending-send queue's flag). Task 8 review I1.
    func testThePicturesAreTaggedAndNothingIsSent() {
        let resources = [[], [LocalFileMediaResource(fileId: 7)]]
        let messages = _internal_localWidgetStoreMessages(posts: self.posts(), photoResources: resources, peerId: self.account, accountPeerId: self.account, lastTimestamp: 1_000)
        XCTAssertEqual(messages.count, 3)
        guard messages.count == 3 else {
            return
        }
        XCTAssertTrue(messages[2].tags.contains(.photoOrVideo))
        XCTAssertTrue(messages[2].tags.contains(.photo))
        for message in messages {
            XCTAssertFalse(message.flags.contains(.Unsent))
        }
    }

    func testSavedMessagesPostsAreInMyNotes() {
        let resources: [[LocalFileMediaResource]] = [[], [LocalFileMediaResource(fileId: 7)]]
        let saved = _internal_localWidgetStoreMessages(posts: self.posts(), photoResources: resources, peerId: self.account, accountPeerId: self.account, lastTimestamp: 1_000)
        XCTAssertEqual(Set(saved.map(\.threadId)), [self.account.toInt64()])
        let elsewhere = _internal_localWidgetStoreMessages(posts: self.posts(), photoResources: resources, peerId: self.other, accountPeerId: self.account, lastTimestamp: 1_000)
        XCTAssertEqual(Set(elsewhere.map(\.threadId)), [nil])
    }
}
