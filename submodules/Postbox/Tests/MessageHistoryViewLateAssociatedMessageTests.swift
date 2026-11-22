import Foundation
import XCTest
@testable import Postbox

/// A history fill stores messages before it fetches the messages they reply to (TelegramCore,
/// 2026-10-13). A view must therefore render a reply whose target is absent, attach the target when
/// it is stored later in the same chat, and attach a target from another chat once the replying
/// message is re-added.
final class MessageHistoryViewLateAssociatedMessageTests: XCTestCase {
    /// A `MessageAttribute` whose only content is the id it references.
    private final class FixtureReplyAttribute: MessageAttribute {
        static let register: Void = {
            declareEncodable(FixtureReplyAttribute.self, f: { FixtureReplyAttribute(decoder: $0) })
        }()

        let targetId: MessageId

        init(targetId: MessageId) {
            self.targetId = targetId
        }

        init(decoder: PostboxDecoder) {
            self.targetId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: decoder.decodeInt32ForKey("n", orElse: 0), id: decoder.decodeInt32ForKey("i", orElse: 0))
        }

        func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.targetId.peerId.toInt64(), forKey: "p")
            encoder.encodeInt32(self.targetId.namespace, forKey: "n")
            encoder.encodeInt32(self.targetId.id, forKey: "i")
        }

        var associatedMessageIds: [MessageId] {
            return [self.targetId]
        }
    }

    private var fixture: PostboxFixture!
    private let chat = FixturePeer(id: MessageHistoryTableFixture.peerId(600), title: "chat")
    private let otherChat = FixturePeer(id: MessageHistoryTableFixture.peerId(601), title: "other")

    override func setUp() {
        super.setUp()
        let _ = FixtureReplyAttribute.register
        self.fixture = PostboxFixture(name: "MessageHistoryViewLateAssociatedMessageTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([self.chat, self.otherChat], update: { _, updated in updated })
            // A chat starts with one hole over its whole history, and a view does not show messages
            // inside a hole. A fill removes the range it stored, so the chat is filled here.
            transaction.removeHole(peerId: self.chat.id, threadId: nil, namespace: PostboxFixture.messageNamespace, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func message(peer: Int64, id: Int32, timestamp: Int32, attributes: [MessageAttribute] = []) -> StoreMessage {
        return StoreMessage(id: MessageHistoryTableFixture.messageId(peer: peer, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "m\(id)", attributes: attributes, media: [])
    }

    private func reply(in view: MessageHistoryView) -> Message? {
        return view.entries.first(where: { $0.message.id.id == 2 })?.message
    }

    func testReplyRendersWithoutItsTargetAndAttachesItWhenStored() {
        let targetId = MessageHistoryTableFixture.messageId(peer: 600, id: 1)
        let history = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [])
        let _ = history.waitForValues(count: 1)

        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peer: 600, id: 2, timestamp: 20, attributes: [FixtureReplyAttribute(targetId: targetId)])], location: .Random)
        }
        let afterReply = history.waitForValues(count: 2).last!
        let reply = self.reply(in: afterReply)
        XCTAssertNotNil(reply, "the reply is rendered although its target is absent")
        XCTAssertEqual(reply?.associatedMessageIds, [targetId])
        XCTAssertNil(reply?.associatedMessages[targetId])

        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peer: 600, id: 1, timestamp: 10)], location: .Random)
        }
        let afterTarget = history.waitForValues(count: 3).last!
        XCTAssertEqual(self.reply(in: afterTarget)?.associatedMessages[targetId]?.text, "m1", "storing the target re-renders the reply")
    }

    func testReAddingTheReplyAttachesATargetInAnotherPeer() {
        let targetId = MessageHistoryTableFixture.messageId(peer: 601, id: 7)
        let history = self.fixture.observeHistory(peerId: self.chat.id, additionalData: [])
        let _ = history.waitForValues(count: 1)

        let replyMessage = self.message(peer: 600, id: 2, timestamp: 20, attributes: [FixtureReplyAttribute(targetId: targetId)])
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([replyMessage], location: .Random)
        }
        let afterReply = history.waitForValues(count: 2).last!
        XCTAssertNil(self.reply(in: afterReply)?.associatedMessages[targetId])

        // The view watches its own chat only, so the target's arrival alone changes nothing; the fill
        // re-adds the replying message (same content) after storing the target.
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peer: 601, id: 7, timestamp: 5)], location: .Random)
            let _ = transaction.addMessages([replyMessage], location: .Random)
        }
        let afterReAdd = history.waitForValues(count: 3).last!
        XCTAssertEqual(self.reply(in: afterReAdd)?.associatedMessages[targetId]?.text, "m7")
    }
}
