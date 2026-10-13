import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

private func makeMessageId(_ id: Int32) -> MessageId {
    return MessageId(peerId: makeUserPeerId(100), namespace: Namespaces.Message.Cloud, id: id)
}

private func makeSourcedForwardInfo(author: Peer?, source: Peer, authorSignature: String?) -> MessageForwardInfo {
    return MessageForwardInfo(
        author: author,
        source: source,
        sourceMessageId: nil,
        date: 900,
        authorSignature: authorSignature,
        psaType: nil,
        flags: MessageForwardInfo.Flags()
    )
}

/// Stand-in for the presentation layer's peer-name rendering, which this module cannot reach.
private func displayTitle(_ peer: Peer) -> String {
    return "title(\(peer.id))"
}

final class ChatMessageForwardInfoDisplayTests: XCTestCase {
    private let messageA = makeMessageId(1)
    private let messageB = makeMessageId(2)

    private func resolve(
        _ forwardInfo: MessageForwardInfo,
        messageId: MessageId,
        previouslyApplied: ChatMessageAppliedForwardInfo? = nil
    ) -> ChatMessageAppliedForwardInfo {
        return chatMessageForwardInfoDisplay(
            forwardInfo: forwardInfo,
            messageId: messageId,
            previouslyApplied: previouslyApplied,
            peerDisplayTitle: displayTitle
        )
    }

    func testPlainForwardUsesItsOwnAuthor() {
        let user = makeUser(id: 5)
        let result = self.resolve(makeForwardInfo(author: user, authorSignature: nil, date: 900, isImported: false), messageId: self.messageA)
        XCTAssertEqual(result.source?.id, user.id)
        XCTAssertNil(result.authorSignature)
    }

    func testAnonymousForwardUsesItsSignature() {
        let result = self.resolve(makeForwardInfo(author: nil, authorSignature: "Ghost", date: 900, isImported: false), messageId: self.messageA)
        XCTAssertNil(result.source)
        XCTAssertEqual(result.authorSignature, "Ghost")
    }

    func testChannelSourceKeepsItsSignature() {
        let channel = makeBroadcastChannel(id: 7, messagesShouldHaveProfiles: false)
        let result = self.resolve(makeSourcedForwardInfo(author: channel, source: channel, authorSignature: "John"), messageId: self.messageA)
        XCTAssertEqual(result.source?.id, channel.id)
        XCTAssertEqual(result.authorSignature, "John")
    }

    func testChannelSourceNamesAnAuthorThatDiffersFromIt() {
        let channel = makeBroadcastChannel(id: 7, messagesShouldHaveProfiles: true)
        let admin = makeUser(id: 5)
        let result = self.resolve(makeSourcedForwardInfo(author: admin, source: channel, authorSignature: nil), messageId: self.messageA)
        XCTAssertEqual(result.source?.id, channel.id)
        XCTAssertEqual(result.authorSignature, displayTitle(admin))
    }

    func testChannelSourceAuthoredByItselfHasNoSignature() {
        let channel = makeBroadcastChannel(id: 7, messagesShouldHaveProfiles: false)
        let result = self.resolve(makeSourcedForwardInfo(author: channel, source: channel, authorSignature: nil), messageId: self.messageA)
        XCTAssertEqual(result.source?.id, channel.id)
        XCTAssertNil(result.authorSignature)
    }

    /// The anti-flicker case the cache exists for: the author peer is momentarily unresolved, so
    /// this same message keeps the sender it already displayed.
    func testUnresolvedAuthorKeepsWhatThisMessageLastShowed() {
        let user = makeUser(id: 5)
        let applied = ChatMessageAppliedForwardInfo(messageId: self.messageA, source: user, authorSignature: nil)
        let result = self.resolve(
            makeForwardInfo(author: nil, authorSignature: nil, date: 900, isImported: false),
            messageId: self.messageA,
            previouslyApplied: applied
        )
        XCTAssertEqual(result.source?.id, user.id)
    }

    func testUnresolvedAuthorWithNothingPreviouslyAppliedResolvesToNothing() {
        let result = self.resolve(makeForwardInfo(author: nil, authorSignature: nil, date: 900, isImported: false), messageId: self.messageA)
        XCTAssertNil(result.source)
        XCTAssertNil(result.authorSignature)
    }

    /// The regression: an item node reused for a different message must not inherit the previous
    /// message's sender. An anonymous forward has a nil author, which is what the cache keys on.
    func testReusedNodeDoesNotInheritAnotherMessagesSender() {
        let previousChannel = makeBroadcastChannel(id: 7, messagesShouldHaveProfiles: false)
        let applied = ChatMessageAppliedForwardInfo(messageId: self.messageA, source: previousChannel, authorSignature: "John")
        let result = self.resolve(
            makeForwardInfo(author: nil, authorSignature: "Ghost", date: 900, isImported: false),
            messageId: self.messageB,
            previouslyApplied: applied
        )
        XCTAssertNil(result.source)
        XCTAssertEqual(result.authorSignature, "Ghost")
    }

    func testReusedNodeDoesNotInheritAnotherMessagesSenderWhenItHasNoNameOfItsOwn() {
        let previousChannel = makeBroadcastChannel(id: 7, messagesShouldHaveProfiles: false)
        let applied = ChatMessageAppliedForwardInfo(messageId: self.messageA, source: previousChannel, authorSignature: "John")
        let result = self.resolve(
            makeForwardInfo(author: nil, authorSignature: nil, date: 900, isImported: false),
            messageId: self.messageB,
            previouslyApplied: applied
        )
        XCTAssertNil(result.source)
        XCTAssertNil(result.authorSignature)
    }

    /// Feeding the result back in is what a repeated layout pass does; an anonymous forward must
    /// not drift into the cached branch and start reporting a source.
    func testRepeatedLayoutOfAnAnonymousForwardIsStable() {
        let forwardInfo = makeForwardInfo(author: nil, authorSignature: "Ghost", date: 900, isImported: false)
        var result = self.resolve(forwardInfo, messageId: self.messageA)
        for _ in 0 ..< 3 {
            result = self.resolve(forwardInfo, messageId: self.messageA, previouslyApplied: result)
        }
        XCTAssertNil(result.source)
        XCTAssertEqual(result.authorSignature, "Ghost")
    }
}
