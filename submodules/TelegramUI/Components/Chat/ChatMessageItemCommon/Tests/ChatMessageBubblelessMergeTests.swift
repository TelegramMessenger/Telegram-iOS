import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

private func makeRoundVideoFile() -> TelegramMediaFile {
    return TelegramMediaFile(
        fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: 1),
        partialReference: nil,
        resource: LocalFileMediaResource(fileId: 1),
        previewRepresentations: [],
        videoThumbnails: [],
        immediateThumbnailData: nil,
        mimeType: "video/mp4",
        size: 1024,
        attributes: [.Video(duration: 1.0, size: PixelDimensions(width: 100, height: 100), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)],
        alternativeRepresentations: []
    )
}

// Runs without bubbles: one author's messages within ten minutes, whatever they carry (spec 5.4).
final class ChatMessageBubblelessMergeTests: XCTestCase {
    private let group = makeGroupChannel(id: 100)
    private let userA = makeUser(id: 2)
    private let userB = makeUser(id: 3)

    private func fingerprint(_ message: Message) -> ChatMessageMergeFingerprint {
        return ChatMessageMergeFingerprint(message: message, accountPeerId: accountPeerIdForTests, bubbleless: true)
    }

    private func merge(_ upper: Message, _ lower: Message) -> ChatMessageMerge {
        return chatMessageBubblelessMerge(upper: self.fingerprint(upper), lower: self.fingerprint(lower))
    }

    func testSameAuthorWithinTenMinutesMergesWhateverTheMedia() {
        let text = makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000)
        let roundVideo = makeMessage(stableId: 2, peer: self.group, author: self.userA, timestamp: 1300, media: [makeRoundVideoFile()])
        XCTAssertEqual(chatMessageMerge(upper: self.fingerprint(roundVideo), lower: self.fingerprint(text)), .none)
        XCTAssertEqual(self.merge(roundVideo, text), .semanticallyMerged)
    }

    func testTenMinutesApartStartsANewRun() {
        let first = makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, media: [makeRoundVideoFile()])
        let tooLate = makeMessage(stableId: 2, peer: self.group, author: self.userA, timestamp: 1000 + chatMessageBubblelessRunInterval, media: [makeRoundVideoFile()])
        let justInTime = makeMessage(stableId: 3, peer: self.group, author: self.userA, timestamp: 1000 + chatMessageBubblelessRunInterval - 1, media: [makeRoundVideoFile()])
        XCTAssertEqual(self.merge(tooLate, first), .none)
        XCTAssertEqual(self.merge(justInTime, first), .semanticallyMerged)
    }

    func testPaidStarsAndServiceBreakARun() {
        let first = makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, media: [makeRoundVideoFile()])
        let paid = makeMessage(stableId: 2, peer: self.group, author: self.userA, timestamp: 1010, attributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)], media: [makeRoundVideoFile()])
        let service = makeMessage(stableId: 3, peer: self.group, author: self.userA, timestamp: 1020, media: [TelegramMediaAction(action: .groupCreated(title: "G"))])
        XCTAssertEqual(self.merge(paid, first), .none)
        XCTAssertEqual(self.merge(service, first), .none)
    }

    func testAnotherAuthorOrSourceAuthorBreaksARun() {
        let first = makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, media: [makeRoundVideoFile()])
        let other = makeMessage(stableId: 2, peer: self.group, author: self.userB, timestamp: 1010, media: [makeRoundVideoFile()])
        XCTAssertEqual(self.merge(other, first), .none)
    }

    func testConsecutiveServiceMessagesMerge() {
        let first = makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, media: [TelegramMediaAction(action: .groupCreated(title: "G"))])
        let second = makeMessage(stableId: 2, peer: self.group, author: self.userB, timestamp: 5000, media: [TelegramMediaAction(action: .groupCreated(title: "H"))])
        XCTAssertEqual(self.merge(second, first), .semanticallyMerged)
    }

    func testOutgoingMergesAsWithBubbles() {
        let pairs: [(Message, Message)] = [
            (makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, isOutgoing: true), makeMessage(stableId: 2, peer: self.group, author: self.userA, timestamp: 1010, isOutgoing: true)),
            (makeMessage(stableId: 1, peer: self.group, author: self.userA, timestamp: 1000, isOutgoing: true, media: [makeRoundVideoFile()]), makeMessage(stableId: 2, peer: self.group, author: self.userA, timestamp: 1010, isOutgoing: true))
        ]
        for (lower, upper) in pairs {
            XCTAssertEqual(self.merge(upper, lower), chatMessageMerge(upper: self.fingerprint(upper), lower: self.fingerprint(lower)))
        }
    }

    func testFingerprintCarriesNoBubblelessFactsByDefault() {
        let service = makeMessage(peer: self.group, author: self.userA, media: [TelegramMediaAction(action: .groupCreated(title: "G"))])
        let withBubbles = ChatMessageMergeFingerprint(message: service, accountPeerId: accountPeerIdForTests)
        XCTAssertNil(withBubbles.bubblelessMediaKind)
        XCTAssertEqual(self.fingerprint(service).bubblelessMediaKind, .service)
        XCTAssertFalse(self.fingerprint(service).keepsBubbleWithoutBubbleMode)
        let outgoing = makeMessage(peer: self.group, author: self.userA, isOutgoing: true)
        XCTAssertTrue(self.fingerprint(outgoing).keepsBubbleWithoutBubbleMode)
    }
}
