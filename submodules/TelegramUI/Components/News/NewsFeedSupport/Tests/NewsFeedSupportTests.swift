import XCTest
import CoreGraphics
import TelegramCore
@testable import NewsFeedSupport

final class NewsFeedSupportTests: XCTestCase {
    private let channel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func entry(_ id: Int32, date: Int32) -> EngineFeedEntry {
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: self.channel, id: id), messageIds: [EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: id)], groupingKey: nil)
    }

    // MARK: compact time

    func testCompactTimeThresholds() {
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1030), .seconds(30))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 6 * 60), .minutes(6))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 60 * 60), .hours(1))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 3 * 24 * 60 * 60), .days(3))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 8 * 24 * 60 * 60), .date(1000))
    }

    func testCompactTimeClampsAFutureTimestamp() {
        XCTAssertEqual(newsCompactTime(timestamp: 2000, now: 1000), .seconds(0))
    }

    // MARK: rows

    // The list opens with the oldest unread post at the bottom of the viewport.
    func testOldestUnreadPostIsTheLastOneNewerThanTheReadMark() {
        let entries = [self.entry(4, date: 400), self.entry(3, date: 300), self.entry(2, date: 200), self.entry(1, date: 100)]
        XCTAssertEqual(newsAddedFirstUnreadIndex(entries: entries, readMarkPosition: entries[2].position), 1)
    }

    func testNothingUnreadGivesNoAnchor() {
        let entries = [self.entry(2, date: 200), self.entry(1, date: 100)]
        XCTAssertNil(newsAddedFirstUnreadIndex(entries: entries, readMarkPosition: entries[0].position))
    }

    func testNoReadMarkGivesNoAnchor() {
        XCTAssertNil(newsAddedFirstUnreadIndex(entries: [self.entry(1, date: 100)], readMarkPosition: nil))
    }

    func testNoEntriesGiveNoAnchor() {
        XCTAssertNil(newsAddedFirstUnreadIndex(entries: [], readMarkPosition: EngineFeedPosition(date: 100, peerId: self.channel, id: 1)))
    }

    func testAllLoadedUnreadAnchorsTheLastPost() {
        let entries = [self.entry(3, date: 300), self.entry(2, date: 200)]
        XCTAssertEqual(newsAddedFirstUnreadIndex(entries: entries, readMarkPosition: EngineFeedPosition(date: 100, peerId: self.channel, id: 1)), 1)
    }

    func testResolvedEntriesDropUnavailableMessages() {
        let album = EngineFeedEntry(position: EngineFeedPosition(date: 300, peerId: self.channel, id: 11), messageIds: [EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 10), EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 11)], groupingKey: 5)
        let gone = self.entry(1, date: 100)
        let resolved = newsResolvedEntries([album, gone], availableMessageIds: [album.messageIds[1]])
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].messageIds, [album.messageIds[1]])
    }

    // MARK: For you interests block

    // The test server sends an empty For you without the block, which left no way to pick interests.
    func testForYouWithoutTheBlockGetsItOnTop() {
        let first = self.entry(2, date: 200)
        let second = self.entry(1, date: 100)
        XCTAssertEqual(newsForYouItemsShowingInterests([]), [.interests])
        XCTAssertEqual(newsForYouItemsShowingInterests([.post(first), .post(second)]), [.interests, .post(first), .post(second)])
    }

    func testForYouKeepsTheServersBlockWhereItIs() {
        let first = self.entry(2, date: 200)
        let second = self.entry(1, date: 100)
        XCTAssertEqual(newsForYouItemsShowingInterests([.post(first), .interests, .post(second)]), [.post(first), .interests, .post(second)])
    }

    func testForYouShowsTheBlockOnce() {
        let first = self.entry(2, date: 200)
        XCTAssertEqual(newsForYouItemsShowingInterests([.interests, .post(first), .interests]), [.interests, .post(first)])
    }

    // MARK: For you list status

    func testForYouLoadingShowsPlaceholders() {
        XCTAssertEqual(newsForYouListStatus(hasPosts: false, didLoadSnapshot: false, isLoadingMore: false, isExhausted: false, hasError: false), .placeholders)
        XCTAssertEqual(newsForYouListStatus(hasPosts: false, didLoadSnapshot: true, isLoadingMore: true, isExhausted: false, hasError: false), .placeholders)
        XCTAssertEqual(newsForYouListStatus(hasPosts: false, didLoadSnapshot: true, isLoadingMore: false, isExhausted: false, hasError: true), .error)
    }

    // An empty first batch used to leave the placeholders shimmering forever.
    func testForYouEmptyFirstBatchShowsTheEmptyState() {
        XCTAssertEqual(newsForYouListStatus(hasPosts: false, didLoadSnapshot: true, isLoadingMore: false, isExhausted: true, hasError: false), .empty)
    }

    func testForYouLoadMoreFailureWithPostsOffersRetry() {
        XCTAssertEqual(newsForYouListStatus(hasPosts: true, didLoadSnapshot: true, isLoadingMore: false, isExhausted: false, hasError: true), .loadMoreFailed)
        XCTAssertEqual(newsForYouListStatus(hasPosts: true, didLoadSnapshot: true, isLoadingMore: true, isExhausted: false, hasError: false), .loadingMore)
        XCTAssertEqual(newsForYouListStatus(hasPosts: true, didLoadSnapshot: true, isLoadingMore: false, isExhausted: false, hasError: false), .none)
    }

    // MARK: read tracking

    func testNewestFullyVisiblePost() {
        let viewport = CGRect(x: 0.0, y: 100.0, width: 320.0, height: 400.0)
        let rows = [
            NewsVisibleRow(position: EngineFeedPosition(date: 300, peerId: self.channel, id: 3), frame: CGRect(x: 0.0, y: 60.0, width: 320.0, height: 80.0)),
            NewsVisibleRow(position: EngineFeedPosition(date: 200, peerId: self.channel, id: 2), frame: CGRect(x: 0.0, y: 140.0, width: 320.0, height: 80.0)),
            NewsVisibleRow(position: EngineFeedPosition(date: 100, peerId: self.channel, id: 1), frame: CGRect(x: 0.0, y: 220.0, width: 320.0, height: 80.0))
        ]
        XCTAssertEqual(newsNewestFullyVisiblePosition(rows: rows, viewport: viewport)?.id, 2)
    }

    func testNoFullyVisiblePost() {
        let viewport = CGRect(x: 0.0, y: 100.0, width: 320.0, height: 50.0)
        let rows = [NewsVisibleRow(position: EngineFeedPosition(date: 300, peerId: self.channel, id: 3), frame: CGRect(x: 0.0, y: 60.0, width: 320.0, height: 200.0))]
        XCTAssertNil(newsNewestFullyVisiblePosition(rows: rows, viewport: viewport))
    }

    // MARK: kill switch

    private func configuration(_ value: JSON?) -> AppConfiguration {
        var configuration = AppConfiguration.defaultValue
        if let value {
            configuration.data = .dictionary([newsFeedEnabledAppConfigurationKey: value])
        }
        return configuration
    }

    func testKillSwitchDefaultsToEnabled() {
        XCTAssertTrue(isNewsFeedEnabled(appConfiguration: self.configuration(nil)))
        XCTAssertTrue(isNewsFeedEnabled(appConfiguration: AppConfiguration.defaultValue))
    }

    func testKillSwitchFollowsABool() {
        XCTAssertFalse(isNewsFeedEnabled(appConfiguration: self.configuration(.bool(false))))
        XCTAssertTrue(isNewsFeedEnabled(appConfiguration: self.configuration(.bool(true))))
    }

    func testKillSwitchParsesNumbersAndIgnoresOtherTypes() {
        XCTAssertFalse(isNewsFeedEnabled(appConfiguration: self.configuration(.number(0.0))))
        XCTAssertTrue(isNewsFeedEnabled(appConfiguration: self.configuration(.number(1.0))))
        XCTAssertTrue(isNewsFeedEnabled(appConfiguration: self.configuration(.string("false"))))
    }

    // MARK: channel bar

    func testNewsOnlyChannelThatReadsAsLeftShowsAddedToNews() {
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: true, participation: .left, featureEnabled: true, isAddingToNews: false), .addedToNews)
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: true, participation: .member, featureEnabled: true, isAddingToNews: false), .addedToNews)
    }

    func testAddedToNewsStaysWithTheFeatureOff() {
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: true, participation: .left, featureEnabled: false, isAddingToNews: false), .addedToNews)
    }

    func testUnjoinedChannelOffersAddToNewsOnlyWithTheFeatureOn() {
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: false, participation: .left, featureEnabled: true, isAddingToNews: false), .addToNews)
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: false, participation: .left, featureEnabled: false, isAddingToNews: false), .existing)
    }

    func testAddingShowsAddedToNewsAtOnce() {
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: false, participation: .left, featureEnabled: true, isAddingToNews: true), .addedToNews)
    }

    func testGroupsMembersAndKickedKeepTheExistingBar() {
        XCTAssertEqual(newsChannelBarAction(isBroadcast: false, isInNews: false, participation: .left, featureEnabled: true, isAddingToNews: false), .existing)
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: false, participation: .member, featureEnabled: true, isAddingToNews: false), .existing)
        XCTAssertEqual(newsChannelBarAction(isBroadcast: true, isInNews: true, participation: .kicked, featureEnabled: true, isAddingToNews: false), .existing)
    }
}
