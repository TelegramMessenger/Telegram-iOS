import XCTest
@testable import TelegramCore

/// Occupation drafts as TDesktop's `support_helper.cpp` writes and reads them.
final class SupportOccupationTests: XCTestCase {
    private let now: Int32 = 1762160000
    private let ownTag: UInt32 = 3735928559

    private func peerId(_ namespace: EnginePeer.Id.Namespace, _ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    func testFormatMatchesTDesktop() {
        XCTAssertEqual(supportOccupationDraftText(now: self.now, tag: self.ownTag, normalizedName: "Agent"), "t:1762160060;u:3735928559;n:Agent")
    }

    func testTagIsTheLow32BitsOfTheInstallationTag() {
        XCTAssertEqual(supportOccupationTag(installationTag: 0x1234_5678_DEAD_BEEF), 0xDEAD_BEEF)
        XCTAssertEqual(supportOccupationTag(installationTag: UInt64(bitPattern: -1)), UInt32.max)
    }

    func testNameNormalisation() {
        XCTAssertEqual(supportNormalizedName("a:b;c"), "a_b_c")
        XCTAssertEqual(supportNormalizedName("Plain Name"), "Plain Name")
    }

    func testOwnFormatRoundTrips() {
        let text = supportOccupationDraftText(now: self.now, tag: 42, normalizedName: supportNormalizedName("Agent: One"))
        XCTAssertEqual(supportParseOccupationTag(text, now: self.now), 42)
        XCTAssertEqual(supportParseOccupationName(text, now: self.now), "Agent_ One")
        XCTAssertEqual(supportOccupiedBySomeoneTill(text, now: self.now, ownTag: self.ownTag), self.now + 60)
        XCTAssertEqual(supportOccupiedBySomeoneTill(text, now: self.now, ownTag: 42), 0)
    }

    func testExpiryComesOnlyFromT() {
        let text = "t:1762160000;u:5;n:x"
        XCTAssertEqual(supportParseOccupationTag(text, now: self.now), 5)
        XCTAssertEqual(supportParseOccupationTag(text, now: self.now + 1), 0)
        XCTAssertEqual(supportParseOccupationName(text, now: self.now + 1), "")
        XCTAssertEqual(supportOccupiedBySomeoneTill(text, now: self.now + 1, ownTag: self.ownTag), 0)
        XCTAssertEqual(supportParseOccupationTag("u:5;n:x", now: self.now), 0)
        XCTAssertEqual(supportParseOccupationTag("t:soon;u:5;n:x", now: self.now), 0)
    }

    func testPartsInAnyOrder() {
        let text = "n:x;u:5;t:1762160060"
        XCTAssertEqual(supportParseOccupationTag(text, now: self.now), 5)
        XCTAssertEqual(supportParseOccupationName(text, now: self.now), "x")
        XCTAssertEqual(supportOccupiedBySomeoneTill(text, now: self.now, ownTag: self.ownTag), self.now + 60)
    }

    func testTDesktopQuirks() {
        // A bad u: is not occupied for ParseOccupationTag, but counts as someone else in OccupiedBySomeoneTill.
        XCTAssertEqual(supportParseOccupationTag("t:1762160060;u:abc;n:x", now: self.now), 0)
        XCTAssertEqual(supportOccupiedBySomeoneTill("t:1762160060;u:abc;n:x", now: self.now, ownTag: self.ownTag), self.now + 60)
        // No u: at all is nobody.
        XCTAssertEqual(supportOccupiedBySomeoneTill("t:1762160060;n:x", now: self.now, ownTag: self.ownTag), 0)
        // The name stops at the next separator, and the last n: wins.
        XCTAssertEqual(supportParseOccupationName("t:1762160060;u:5;n:first;n:second", now: self.now), "second")
        // Ordinary text is not a claim.
        XCTAssertEqual(supportParseOccupationTag("Hello there", now: self.now), 0)
        XCTAssertEqual(supportOccupiedBySomeoneTill("Hello there", now: self.now, ownTag: self.ownTag), 0)
    }

    func testOccupationBySomeoneAndByMe() {
        let other = "t:1762160060;u:5;n:Other"
        let mine = "t:1762160060;u:3735928559;n:Me"
        XCTAssertEqual(supportOccupationBySomeone(other, now: self.now, ownTag: self.ownTag), SupportOccupation(till: self.now + 60, name: "Other"))
        XCTAssertNil(supportOccupationBySomeone(mine, now: self.now, ownTag: self.ownTag))
        XCTAssertNil(supportOccupationBySomeone(nil, now: self.now, ownTag: self.ownTag))
        XCTAssertTrue(supportIsOccupiedByMe(mine, now: self.now, ownTag: self.ownTag))
        XCTAssertFalse(supportIsOccupiedByMe(other, now: self.now, ownTag: self.ownTag))
        XCTAssertFalse(supportIsOccupiedByMe(mine, now: self.now + 61, ownTag: self.ownTag))
        XCTAssertFalse(supportIsOccupiedByMe(nil, now: self.now, ownTag: self.ownTag))
    }

    func testTrackedChats() {
        let account = self.peerId(Namespaces.Peer.CloudUser, 1)
        XCTAssertTrue(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudUser, 119474480), accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudUser, 119474480), accountPeerId: account, isBot: true))
        XCTAssertFalse(supportTracksOccupation(peerId: account, accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudUser, 777000), accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudUser, 333000), accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudGroup, 5), accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.CloudChannel, 5), accountPeerId: account, isBot: false))
        XCTAssertFalse(supportTracksOccupation(peerId: self.peerId(Namespaces.Peer.SecretChat, 5), accountPeerId: account, isBot: false))
    }

    func testReceivedDraftText() {
        XCTAssertNil(supportReceivedDraftText(nil))
        XCTAssertNil(supportReceivedDraftText(SynchronizeableChatInputState(replySubject: nil, text: "", entities: [], timestamp: 1, textSelection: nil, messageEffectId: nil, suggestedPost: nil)))
        XCTAssertEqual(supportReceivedDraftText(SynchronizeableChatInputState(replySubject: nil, text: "t:1;u:2;n:x", entities: [], timestamp: 1, textSelection: nil, messageEffectId: nil, suggestedPost: nil)), "t:1;u:2;n:x")
    }
}
