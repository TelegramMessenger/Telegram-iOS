import XCTest
import Postbox
@testable import TelegramCore

/// What the store alone says about whether messaging a user is gated. The server's answer
/// (`users.getRequirementsToContact`) is authoritative; this is the prefilter the app uses to
/// decide whom to ask, and the whole decision for surfaces that cannot ask, such as Siri.
final class LocalRequirementToContactTests: XCTestCase {
    private func user(flags: UserInfoFlags = []) -> TelegramUser {
        return TelegramUser(
            id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1001)),
            accessHash: nil, firstName: "Alice", lastName: nil, username: nil, phone: nil, photo: [],
            botInfo: nil, restrictionInfo: nil, flags: flags, emojiStatus: nil, usernames: [],
            storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
            profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil
        )
    }

    private func isStars(_ requirement: LocalRequirementToContact?) -> Bool {
        if case .stars = requirement {
            return true
        }
        return false
    }

    func testAnUngatedUserHasNoRequirement() {
        XCTAssertNil(localRequirementToContact(peer: self.user(), cachedData: nil))
        XCTAssertNil(localRequirementToContact(peer: self.user(), cachedData: CachedUserData()))
    }

    func testCachedDataReportsStarsWithTheAmount() {
        let cached = CachedUserData().withUpdatedSendPaidMessageStars(StarsAmount(value: 5, nanos: 0))

        guard case let .stars(amount) = localRequirementToContact(peer: self.user(), cachedData: cached) else {
            return XCTFail("expected a stars requirement")
        }
        XCTAssertEqual(amount, StarsAmount(value: 5, nanos: 0))
    }

    func testCachedDataReportsPremium() {
        let cached = CachedUserData().withUpdatedFlags([.premiumRequired])

        guard case .premium = localRequirementToContact(peer: self.user(), cachedData: cached) else {
            return XCTFail("expected a premium requirement")
        }
    }

    func testUserFlagsReportTheGateWithoutCachedData() {
        XCTAssertTrue(isStars(localRequirementToContact(peer: self.user(flags: [.requireStars]), cachedData: nil)))
        guard case .premium = localRequirementToContact(peer: self.user(flags: [.requirePremium]), cachedData: nil) else {
            return XCTFail("expected a premium requirement")
        }
    }

    func testMutualContactsAreExemptFromTheFlagGate() {
        XCTAssertNil(localRequirementToContact(peer: self.user(flags: [.requirePremium, .mutualContact]), cachedData: nil))
        XCTAssertNil(localRequirementToContact(peer: self.user(flags: [.requireStars, .mutualContact]), cachedData: nil))
    }

    /// Cached data is refreshed only when the chat is opened; the user's flags arrive with
    /// every update. Stale cached data without a fee must not hide a fresh flag.
    func testFreshFlagsCountEvenWhenCachedDataShowsNoGate() {
        XCTAssertTrue(isStars(localRequirementToContact(peer: self.user(flags: [.requireStars]), cachedData: CachedUserData())))
    }

    func testOnlyUsersCanBeGated() {
        let group = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1)), title: "G", photo: [], participantCount: 1, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)

        XCTAssertNil(localRequirementToContact(peer: group, cachedData: nil))
    }
}
