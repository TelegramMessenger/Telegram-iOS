import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getCustomEmojiDocuments = "messages.getCustomEmojiDocuments"

/// Api values only these tests need.
private enum RichTextEmojiApi {
    /// A private message of `peerUserId` whose rich text (flags2.13) is one paragraph holding custom emoji `fileId`.
    static func richMessage(id: Int32, peerUserId: Int64, date: Int32, fileId: Int64) -> Api.Message {
        let paragraph = Api.PageBlock.pageBlockParagraph(Api.PageBlock.Cons_pageBlockParagraph(text: .textCustomEmoji(Api.RichText.Cons_textCustomEmoji(documentId: fileId, alt: "😀"))))
        let richMessage = Api.RichMessage.richMessage(Api.RichMessage.Cons_richMessage(flags: 0, blocks: [paragraph], photos: [], documents: []))
        return .message(.init(flags: 1 << 8, flags2: 1 << 13, id: id, fromId: StateSyncApi.peerUser(peerUserId), fromBoostsApplied: nil, fromRank: nil, peerId: StateSyncApi.peerUser(peerUserId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: nil, date: date, message: "", media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: richMessage))
    }

    /// The custom emoji's document, as `messages.getCustomEmojiDocuments` returns it.
    static func emojiDocument(id: Int64) -> Api.Document {
        return .document(Api.Document.Cons_document(flags: 0, id: id, accessHash: 1, fileReference: Buffer(data: Data()), date: 0, mimeType: "application/x-tgsticker", size: 100, thumbs: nil, videoThumbs: nil, dcId: 2, attributes: []))
    }
}

/// A rich message's previews (chat list, reply headers) draw a custom emoji only once its file is stored: they read it
/// from the message's associated media (`RichTextMessageAttribute.associatedMediaIds`) and draw an unknown one as its
/// alt text. A history fill stores its messages first and fetches unknown emoji files in its follow-up, so the follow-up
/// must redraw the rich messages waiting for them. The fill is driven directly, as ManagedMessageHistoryHoles starts it.
final class HistoryFillRichTextEmojiTests: StateSyncTestCase {
    func testARichMessageIsRedrawnOnceItsEmojiFileIsStored() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        let fileId: Int64 = 777
        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            RichTextEmojiApi.richMessage(id: 10, peerUserId: 500, date: self.baseDate + 10, fileId: fileId)
        ])))
        self.server.on(getCustomEmojiDocuments, .hold)

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        let id = self.messageId(peerId, 10)
        XCTAssertTrue(self.server.waitForRequest(getCustomEmojiDocuments), "the follow-up did not ask for the emoji file: \(self.server.requestNames)")
        let stored = self.fixture.message(id)
        XCTAssertNotNil(stored?.attributes.first(where: { $0 is RichTextMessageAttribute }), "precondition: the rich message is stored before the follow-up")
        XCTAssertNil(stored?.associatedMedia[mediaId], "precondition")
        let version = stored?.stableVersion

        XCTAssertTrue(self.server.release(getCustomEmojiDocuments, with: .result([RichTextEmojiApi.emojiDocument(id: fileId)])))

        // Decisive: without the rewrite the stored message never changes (storing a file updates no view).
        self.fixture.eventually { self.fixture.message(id)?.stableVersion != version }
        XCTAssertNotNil(self.fixture.message(id)?.associatedMedia[mediaId], "the emoji's file was not stored")
    }

    /// Pin: a rich message whose emoji files are all stored is not rewritten by the follow-up.
    func testARichMessageWithItsEmojiFileStoredIsNotRedrawn() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        let fileId: Int64 = 778
        self.fixture.transaction { transaction -> Void in
            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: fileId), partialReference: nil, resource: LocalFileMediaResource(fileId: fileId), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])
            transaction.storeMediaIfNotPresent(media: file)
        }
        self.server.on(getHistory, .result(StateSyncApi.messages([
            RichTextEmojiApi.richMessage(id: 10, peerUserId: 500, date: self.baseDate + 10, fileId: fileId)
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))
        let id = self.messageId(peerId, 10)
        let version = self.fixture.message(id)?.stableVersion
        XCTAssertNotNil(version, "precondition")
        // There is no signal for the follow-up's end: it makes no request here, only a few transactions, which this
        // wait outlasts. A slow run can only pass falsely, never fail falsely.
        Thread.sleep(forTimeInterval: 0.3)
        self.fixture.transaction { _ -> Void in }

        XCTAssertEqual(self.server.requestNames, [getHistory], "the follow-up asked for a stored emoji file")
        XCTAssertEqual(self.fixture.message(id)?.stableVersion, version, "the follow-up rewrote a message that waited for nothing")
    }
}
