import XCTest
import Postbox
@testable import TelegramCore

/// The basic group a channel was migrated from, read from the channel's cached data: the same
/// source a channel's history views use to include the group's history, so the gallery and the
/// shared-media list agree with the view about which group belongs to the channel.
final class ChannelMigratedFromGroupTests: XCTestCase {
    private let channelId = SparseFixtures.channelId
    private let groupId = SparseFixtures.groupId

    private func migrated(lastGroupMessage: MessageId) -> CachedChannelData {
        return CachedChannelData().withUpdatedMigrationReference(ChannelMigrationReference(maxMessageId: lastGroupMessage))
    }

    func testAMigratedChannelNamesItsGroup() {
        let cachedData = self.migrated(lastGroupMessage: SparseFixtures.messageId(self.groupId, 12413))
        XCTAssertEqual(channelMigratedFromGroupId(channelId: self.channelId, cachedData: cachedData), self.groupId)
    }

    func testAChannelThatWasNeverMigratedNamesNoGroup() {
        XCTAssertNil(channelMigratedFromGroupId(channelId: self.channelId, cachedData: CachedChannelData()))
    }

    func testAChannelWithoutCachedDataNamesNoGroup() {
        // The channel's views then show its own history only, so nothing else may join it.
        XCTAssertNil(channelMigratedFromGroupId(channelId: self.channelId, cachedData: nil))
    }

    func testAReferenceToTheChannelItselfNamesNoGroup() {
        // Postbox ignores such a reference (`peerIdsForLocation`), so it must not name one either.
        let cachedData = self.migrated(lastGroupMessage: SparseFixtures.messageId(self.channelId, 5))
        XCTAssertNil(channelMigratedFromGroupId(channelId: self.channelId, cachedData: cachedData))
    }
}
