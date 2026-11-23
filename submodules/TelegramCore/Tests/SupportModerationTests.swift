import Foundation
import XCTest
import Postbox
@testable import TelegramCore

final class SupportModerationTests: XCTestCase {
    private let currentChatId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))
    private let otherChatId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(2))

    private func channel(id: PeerId, flags: TelegramChannelFlags = [], info: TelegramChannelInfo = .group(TelegramChannelGroupInfo(flags: [])), adminRights: TelegramChatAdminRightsFlags? = nil) -> TelegramChannel {
        return TelegramChannel(
            id: id,
            accessHash: nil,
            title: "c",
            username: nil,
            photo: [],
            creationDate: 0,
            version: 0,
            participationStatus: .member,
            info: info,
            flags: flags,
            restrictionInfo: nil,
            adminRights: adminRights.flatMap { TelegramChatAdminRights(rights: $0) },
            bannedRights: nil,
            defaultBannedRights: nil,
            usernames: [],
            storiesHidden: nil,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            emojiStatus: nil,
            approximateBoostLevel: nil,
            subscriptionUntilDate: nil,
            verificationIconFileId: nil,
            sendPaidMessageStars: nil,
            linkedMonoforumId: nil
        )
    }

    func testSupportSeesBadgesWherePremiumIsBlocked() {
        XCTAssertTrue(supportPremiumBadgesShown(isSupport: true, isPremiumDisabled: true))
        XCTAssertTrue(supportPremiumBadgesShown(isSupport: true, isPremiumDisabled: false))
    }

    func testOrdinaryAccountFollowsTheBlock() {
        XCTAssertFalse(supportPremiumBadgesShown(isSupport: false, isPremiumDisabled: true))
        XCTAssertTrue(supportPremiumBadgesShown(isSupport: false, isPremiumDisabled: false))
    }

    func testGroupWithBanRightIsListed() {
        XCTAssertTrue(supportCanModerateCommonGroup(self.channel(id: self.otherChatId, adminRights: [.canBanUsers]), currentChatId: self.currentChatId))
    }

    func testGroupTheAccountCreatedIsListed() {
        XCTAssertTrue(supportCanModerateCommonGroup(self.channel(id: self.otherChatId, flags: [.isCreator]), currentChatId: self.currentChatId))
    }

    func testCurrentGroupIsNotListed() {
        XCTAssertFalse(supportCanModerateCommonGroup(self.channel(id: self.currentChatId, flags: [.isCreator]), currentChatId: self.currentChatId))
    }

    func testGroupWithoutBanRightIsNotListed() {
        XCTAssertFalse(supportCanModerateCommonGroup(self.channel(id: self.otherChatId), currentChatId: self.currentChatId))
        XCTAssertFalse(supportCanModerateCommonGroup(self.channel(id: self.otherChatId, adminRights: [.canPinMessages]), currentChatId: self.currentChatId))
    }

    func testBroadcastChannelIsNotListed() {
        XCTAssertFalse(supportCanModerateCommonGroup(self.channel(id: self.otherChatId, flags: [.isCreator], info: .broadcast(TelegramChannelBroadcastInfo(flags: []))), currentChatId: self.currentChatId))
    }

    func testBasicGroupIsNotListed() {
        let group = TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(3)), title: "g", photo: [], participantCount: 2, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        XCTAssertFalse(supportCanModerateCommonGroup(group, currentChatId: self.currentChatId))
    }
}
