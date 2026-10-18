import XCTest
@testable import NewsFeedSupport

/// The channel bar's News states, its menus and the title's mute badge (spec §1.1, §1.3, §3).
final class NewsChannelBarTests: XCTestCase {
    private func action(broadcast: Bool = true, inNews: Bool = false, _ participation: NewsChannelParticipation, muted: Bool = false, feature: Bool = true, pending: NewsChannelBarPending = NewsChannelBarPending()) -> NewsChannelBarAction {
        return newsChannelBarAction(isBroadcast: broadcast, isInNews: inNews, participation: participation, isMuted: muted, featureEnabled: feature, pending: pending)
    }

    // MARK: states

    func testUnjoinedChannelOffersAddToNewsOnlyWithTheFeatureOn() {
        XCTAssertEqual(self.action(.left), .addToNews)
        XCTAssertEqual(self.action(.left, feature: false), .existing)
    }

    // With the feature off a channel shows Join, as before News, even when it was added to News while the feature was
    // on (user decision, 2026-10-16).
    func testLightJoinShowsAddedToNewsOnlyWithTheFeatureOn() {
        XCTAssertEqual(self.action(inNews: true, .left), .addedToNews)
        XCTAssertEqual(self.action(inNews: true, .left, feature: false), .existing)
    }

    // The mockup has no Mute/Unmute: every joined channel is "Added to Chats", in News or not.
    func testJoinedChannelShowsAddedToChatsWithItsMuteState() {
        XCTAssertEqual(self.action(.member, muted: true), .addedToChats(muted: true))
        XCTAssertEqual(self.action(.member, muted: false), .addedToChats(muted: false))
        XCTAssertEqual(self.action(inNews: true, .member, muted: true), .addedToChats(muted: true))
    }

    func testJoinedChannelKeepsMuteUnmuteWithTheFeatureOff() {
        XCTAssertEqual(self.action(.member, feature: false), .existing)
        XCTAssertEqual(self.action(inNews: true, .member, feature: false), .existing)
    }

    func testGroupsAndKickedKeepTheExistingBar() {
        XCTAssertEqual(self.action(broadcast: false, .left), .existing)
        XCTAssertEqual(self.action(broadcast: false, .member), .existing)
        XCTAssertEqual(self.action(inNews: true, .kicked), .existing)
        XCTAssertEqual(self.action(.kicked, pending: NewsChannelBarPending(isRemovingFromChats: true)), .existing)
    }

    // MARK: pending requests

    func testAddingShowsAddedToNewsAtOnce() {
        XCTAssertEqual(self.action(.left, pending: NewsChannelBarPending(isAddingToNews: true)), .addedToNews)
        XCTAssertEqual(self.action(.left, feature: false, pending: NewsChannelBarPending(isAddingToNews: true)), .existing)
    }

    // Add to Chats mutes the channel before its request ends, so the island never shows the bell in between.
    func testJoiningShowsMutedAddedToChatsAtOnce() {
        XCTAssertEqual(self.action(inNews: true, .left, pending: NewsChannelBarPending(isJoining: true)), .addedToChats(muted: true))
        XCTAssertEqual(self.action(inNews: true, .member, muted: false, pending: NewsChannelBarPending(isJoining: true)), .addedToChats(muted: true))
        XCTAssertEqual(self.action(inNews: true, .left, feature: false, pending: NewsChannelBarPending(isJoining: true)), .existing)
    }

    func testPendingRemovalShowsAddToNews() {
        XCTAssertEqual(self.action(.member, muted: true, pending: NewsChannelBarPending(isRemovingFromChats: true)), .addToNews)
        XCTAssertEqual(self.action(inNews: true, .member, pending: NewsChannelBarPending(isRemovingFromChats: true)), .addToNews)
        XCTAssertEqual(self.action(.member, feature: false, pending: NewsChannelBarPending(isRemovingFromChats: true)), .existing)
    }

    func testPendingRequestsTakeTheSpecsPrecedence() {
        XCTAssertEqual(self.action(.member, pending: NewsChannelBarPending(isAddingToNews: true, isJoining: true, isRemovingFromChats: true)), .addToNews)
        XCTAssertEqual(self.action(.left, pending: NewsChannelBarPending(isAddingToNews: true, isJoining: true)), .addedToChats(muted: true))
    }

    func testRemovingFromNewsShowsAddToNewsAtOnce() {
        XCTAssertEqual(self.action(inNews: true, .left, pending: NewsChannelBarPending(isRemovingFromNews: true)), .addToNews)
        XCTAssertEqual(self.action(inNews: true, .left, feature: false, pending: NewsChannelBarPending(isRemovingFromNews: true)), .existing)
    }

    func testAMuteChoiceShowsAtOnce() {
        XCTAssertEqual(self.action(.member, muted: false, pending: NewsChannelBarPending(muted: true)), .addedToChats(muted: true))
        XCTAssertEqual(self.action(.member, muted: true, pending: NewsChannelBarPending(muted: false)), .addedToChats(muted: false))
        XCTAssertEqual(self.action(inNews: true, .left, pending: NewsChannelBarPending(isJoining: true, muted: false)), .addedToChats(muted: false))
    }

    func testATapIsIgnoredWhileARequestRuns() {
        XCTAssertTrue(NewsChannelBarPending().acceptsTap)
        XCTAssertTrue(NewsChannelBarPending(isRemovingFromChats: true).acceptsTap)
        XCTAssertFalse(NewsChannelBarPending(isAddingToNews: true).acceptsTap)
        XCTAssertFalse(NewsChannelBarPending(isJoining: true).acceptsTap)
    }

    // MARK: menus

    func testNewsMenuOffersAddToChatsThenRemoveFromNews() {
        XCTAssertEqual(newsChannelMenuItems(for: .addedToNews, isArchived: false), [.addToChats, .removeFromNews])
    }

    func testChatsMenuFollowsMuteAndArchive() {
        XCTAssertEqual(newsChannelMenuItems(for: .addedToChats(muted: true), isArchived: false), [.notify, .archive, .removeFromChats])
        XCTAssertEqual(newsChannelMenuItems(for: .addedToChats(muted: false), isArchived: true), [.doNotNotify, .unarchive, .removeFromChats])
    }

    func testAddToNewsAndTheExistingBarOpenNoMenu() {
        XCTAssertEqual(newsChannelMenuItems(for: .addToNews, isArchived: false), [])
        XCTAssertEqual(newsChannelMenuItems(for: .existing, isArchived: false), [])
    }

    func testOnlyTheRemovalsAreDestructive() {
        let all: [NewsChannelMenuItem] = [.addToChats, .removeFromNews, .notify, .doNotNotify, .archive, .unarchive, .removeFromChats]
        XCTAssertEqual(all.filter(\.isDestructive), [.removeFromNews, .removeFromChats])
        XCTAssertEqual(Set(all.map(\.iconName)).count, all.count)
    }

    // MARK: title badge

    func testTitleShowsMuteForAMutedChannelInChatsEvenWhenVerified() {
        XCTAssertTrue(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .member, isMuted: true, isVerified: true, featureEnabled: true))
        XCTAssertTrue(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .member, isMuted: true, isVerified: false, featureEnabled: true))
    }

    func testTitleHidesMuteForAChannelOutsideChatsOrUnmuted() {
        XCTAssertFalse(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .left, isMuted: true, isVerified: false, featureEnabled: true))
        XCTAssertFalse(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .member, isMuted: false, isVerified: false, featureEnabled: true))
    }

    func testOtherChatsKeepTheOldTitleRule() {
        XCTAssertTrue(newsChatTitleShowsMuteIcon(isBroadcast: false, participation: .member, isMuted: true, isVerified: false, featureEnabled: true))
        XCTAssertFalse(newsChatTitleShowsMuteIcon(isBroadcast: false, participation: .member, isMuted: true, isVerified: true, featureEnabled: true))
        XCTAssertFalse(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .member, isMuted: true, isVerified: true, featureEnabled: false))
        XCTAssertTrue(newsChatTitleShowsMuteIcon(isBroadcast: true, participation: .left, isMuted: true, isVerified: false, featureEnabled: false))
    }
}
