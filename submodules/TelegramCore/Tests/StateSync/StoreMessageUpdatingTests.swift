import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `StoreMessage(updating:attributes:tags:)`, the rebuild the replay's `transaction.updateMessage` closures use when
/// they change only a stored message's attributes and tags: every other field is the stored message's, exactly as the
/// full initializer those closures called before builds it from the same message.
final class StoreMessageUpdatingTests: StateSyncTestCase {
    func testUpdatingKeepsEveryFieldButTheAttributesAndTags() {
        let channel = self.seedChannel(300, pts: 50, storedMessageId: nil)
        let author = self.seedUserChat(2000)
        let forwardAuthor = self.seedUserChat(2001)
        let id = self.messageId(channel, 10)
        let forwardInfo = StoreMessageForwardInfo(authorId: forwardAuthor, sourceId: channel, sourceMessageId: self.messageId(channel, 5), date: self.baseDate - 10, authorSignature: "signature", psaType: "psa", flags: [])
        let stored = StoreMessage(id: id, customStableId: nil, globallyUniqueId: 77, groupingKey: 88, threadId: 1, timestamp: self.baseDate, flags: [.Incoming], tags: [.file], globalTags: [.Calls], localTags: [.OutgoingDeliveredToServer], forwardInfo: forwardInfo, authorId: author, text: "text", attributes: [ViewCountMessageAttribute(count: 5)], media: [TelegramMediaAction(action: .historyCleared)])
        // Stored and read back in one transaction, so that the forward info's author and the message's author resolve
        // to the seeded peers.
        let readBack = self.fixture.transaction { transaction -> Message? in
            let _ = transaction.addMessages([stored], location: .UpperHistoryBlock)
            return transaction.getMessage(id)
        }
        guard let message = readBack ?? nil else {
            XCTFail("the stored message was not read back")
            return
        }
        XCTAssertEqual(message.forwardInfo?.author?.id, forwardAuthor)
        XCTAssertEqual(message.author?.id, author)

        let attribute = ViewCountMessageAttribute(count: 9)
        let updated = StoreMessage(updating: message, attributes: [attribute], tags: [.pinned])
        // The initializer the replay's attribute and tag rebuilds called before, on the same message.
        let full = StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: [.pinned], globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: [attribute], media: message.media)

        // StoreMessage is not Equatable: field by field, each also against the stored value.
        guard case let .Id(updatedId) = updated.id, case let .Id(fullId) = full.id else {
            XCTFail("a rebuilt message has no full id")
            return
        }
        XCTAssertEqual(updatedId, fullId)
        XCTAssertEqual(updatedId, id)
        XCTAssertNil(updated.customStableId)
        XCTAssertNil(full.customStableId)
        XCTAssertEqual(updated.globallyUniqueId, full.globallyUniqueId)
        XCTAssertEqual(updated.globallyUniqueId, 77)
        XCTAssertEqual(updated.groupingKey, full.groupingKey)
        XCTAssertEqual(updated.groupingKey, 88)
        XCTAssertEqual(updated.threadId, full.threadId)
        XCTAssertEqual(updated.threadId, 1)
        XCTAssertEqual(updated.timestamp, full.timestamp)
        XCTAssertEqual(updated.timestamp, self.baseDate)
        XCTAssertEqual(updated.flags, full.flags)
        XCTAssertTrue(updated.flags.contains(.Incoming))
        XCTAssertEqual(updated.tags, full.tags)
        XCTAssertEqual(updated.tags, [.pinned])
        XCTAssertEqual(updated.globalTags, full.globalTags)
        XCTAssertEqual(updated.globalTags, [.Calls])
        XCTAssertEqual(updated.localTags, full.localTags)
        XCTAssertEqual(updated.localTags, [.OutgoingDeliveredToServer])

        guard let updatedForwardInfo = updated.forwardInfo, let fullForwardInfo = full.forwardInfo else {
            XCTFail("a rebuilt message lost its forward info")
            return
        }
        XCTAssertEqual(updatedForwardInfo.authorId, fullForwardInfo.authorId)
        XCTAssertEqual(updatedForwardInfo.authorId, forwardAuthor)
        XCTAssertEqual(updatedForwardInfo.sourceId, fullForwardInfo.sourceId)
        XCTAssertEqual(updatedForwardInfo.sourceId, channel)
        XCTAssertEqual(updatedForwardInfo.sourceMessageId, fullForwardInfo.sourceMessageId)
        XCTAssertEqual(updatedForwardInfo.sourceMessageId, self.messageId(channel, 5))
        XCTAssertEqual(updatedForwardInfo.date, fullForwardInfo.date)
        XCTAssertEqual(updatedForwardInfo.date, self.baseDate - 10)
        XCTAssertEqual(updatedForwardInfo.authorSignature, fullForwardInfo.authorSignature)
        XCTAssertEqual(updatedForwardInfo.authorSignature, "signature")
        XCTAssertEqual(updatedForwardInfo.psaType, fullForwardInfo.psaType)
        XCTAssertEqual(updatedForwardInfo.psaType, "psa")
        XCTAssertEqual(updatedForwardInfo.flags, fullForwardInfo.flags)

        XCTAssertEqual(updated.authorId, full.authorId)
        XCTAssertEqual(updated.authorId, author)
        XCTAssertEqual(updated.text, full.text)
        XCTAssertEqual(updated.text, "text")
        XCTAssertEqual(updated.attributes.count, 1)
        XCTAssertTrue(updated.attributes.first === attribute)
        XCTAssertTrue(full.attributes.first === attribute)
        XCTAssertEqual(updated.media.count, 1)
        XCTAssertEqual(updated.media.count, full.media.count)
        if let updatedMedia = updated.media.first, let fullMedia = full.media.first {
            XCTAssertTrue(updatedMedia === fullMedia)
            XCTAssertTrue(updatedMedia is TelegramMediaAction)
        }
    }
}
