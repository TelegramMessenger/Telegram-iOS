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
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000), .now)
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1001), .seconds(1))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1030), .seconds(30))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 6 * 60), .minutes(6))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 60 * 60), .hours(1))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 3 * 24 * 60 * 60), .days(3))
        XCTAssertEqual(newsCompactTime(timestamp: 1000, now: 1000 + 8 * 24 * 60 * 60), .date(1000))
    }

    func testCompactTimeClampsAFutureTimestamp() {
        XCTAssertEqual(newsCompactTime(timestamp: 2000, now: 1000), .now)
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

    // The first emission after a window replacement still carries the previous window's messages.
    func testWindowIsResolvedOnlyByItsOwnMessages() {
        let previous = [self.entry(2, date: 200), self.entry(1, date: 100)]
        let replaced = [self.entry(3, date: 300), self.entry(2, date: 200)]
        XCTAssertFalse(newsWindowIsResolved(entries: replaced, loadedIds: previous.flatMap(\.messageIds)))
        XCTAssertTrue(newsWindowIsResolved(entries: replaced, loadedIds: replaced.flatMap(\.messageIds)))
        XCTAssertTrue(newsWindowIsResolved(entries: [], loadedIds: []))
    }

    // A refresh puts a batch on top, and the first emission after it still carries the previous messages:
    // rendering it showed the batch's interests block without the posts above it, then the posts pushed it away.
    func testForYouIsResolvedOnlyByItsOwnMessages() {
        let old: [EngineForYouItem] = [.post(self.entry(1, date: 100)), .interests]
        let refreshed: [EngineForYouItem] = [.post(self.entry(3, date: 300)), .interests, .post(self.entry(1, date: 100))]
        XCTAssertEqual(newsForYouMessageIds(refreshed), self.entry(3, date: 300).messageIds + self.entry(1, date: 100).messageIds)
        XCTAssertFalse(newsForYouIsResolved(items: refreshed, loadedIds: newsForYouMessageIds(old)))
        XCTAssertTrue(newsForYouIsResolved(items: refreshed, loadedIds: newsForYouMessageIds(refreshed)))
        XCTAssertTrue(newsForYouIsResolved(items: [.interests], loadedIds: []))
    }

    func testResolvedEntriesDropUnavailableMessages() {
        let album = EngineFeedEntry(position: EngineFeedPosition(date: 300, peerId: self.channel, id: 11), messageIds: [EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 10), EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: 11)], groupingKey: 5)
        let gone = self.entry(1, date: 100)
        let resolved = newsResolvedEntries([album, gone], availableMessageIds: [album.messageIds[1]])
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].messageIds, [album.messageIds[1]])
    }

    // MARK: swiping between the tabs

    func testPagerFlickGoesItsOwnWay() {
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 0, pageCount: 2, translation: -20.0, velocity: -300.0, width: 400.0), 1)
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 1, pageCount: 2, translation: 20.0, velocity: 300.0, width: 400.0), 0)
        // A flick back cancels a long drag.
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 0, pageCount: 2, translation: -300.0, velocity: 300.0, width: 400.0), 0)
    }

    // Peer Info's version of this rule sends a slow release past half the width back the way it came.
    func testPagerSlowReleaseGoesOnPastHalfTheWidth() {
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 0, pageCount: 2, translation: -250.0, velocity: 0.0, width: 400.0), 1)
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 1, pageCount: 2, translation: 250.0, velocity: 0.0, width: 400.0), 0)
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 0, pageCount: 2, translation: -150.0, velocity: 0.0, width: 400.0), 0)
    }

    func testPagerStaysWithinThePages() {
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 1, pageCount: 2, translation: -20.0, velocity: -300.0, width: 400.0), 1)
        XCTAssertEqual(newsPagerSettledIndex(currentIndex: 0, pageCount: 2, translation: 20.0, velocity: 300.0, width: 400.0), 0)
    }

    // Each list keeps its own position, so mid-swipe the header is between the two lists' folds.
    func testPagerHeaderBlendsTheTwoFolds() {
        XCTAssertEqual(newsPagerHeaderOffset(current: 0.0, next: 300.0, progress: 0.5, foldHeight: 54.0), 27.0)
        XCTAssertEqual(newsPagerHeaderOffset(current: 10.0, next: 300.0, progress: 0.0, foldHeight: 54.0), 10.0)
        XCTAssertEqual(newsPagerHeaderOffset(current: 10.0, next: 300.0, progress: 1.0, foldHeight: 54.0), 54.0)
    }

    func testPagerHeaderIgnoresOverscrollAndCountsAnUnloadedTopAsFolded() {
        XCTAssertEqual(newsPagerHeaderOffset(current: -40.0, next: nil, progress: 0.5, foldHeight: 54.0), 27.0)
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

    // MARK: dev gate and kill switch

    private func configuration(_ value: JSON?, dev: Double? = 1.0) -> AppConfiguration {
        var configuration = AppConfiguration.defaultValue
        var data: [String: JSON] = [:]
        if let value {
            data[newsFeedEnabledAppConfigurationKey] = value
        }
        if let dev {
            data["dev"] = .number(dev)
        }
        if !data.isEmpty {
            configuration.data = .dictionary(data)
        }
        return configuration
    }

    // The app-config rule, as it applies once the feed API is compiled in.
    private func isEnabled(_ configuration: AppConfiguration) -> Bool {
        return isNewsFeedEnabled(appConfiguration: configuration, apiIsAvailable: true)
    }

    func testNewsIsForDevOnly() {
        XCTAssertFalse(self.isEnabled(AppConfiguration.defaultValue))
        XCTAssertFalse(self.isEnabled(self.configuration(nil, dev: nil)))
        XCTAssertFalse(self.isEnabled(self.configuration(nil, dev: 0.0)))
        XCTAssertTrue(self.isEnabled(self.configuration(nil, dev: 1.0)))
        // The kill switch alone does not enable it.
        XCTAssertFalse(self.isEnabled(self.configuration(.bool(true), dev: nil)))
    }

    func testKillSwitchFollowsABool() {
        XCTAssertFalse(self.isEnabled(self.configuration(.bool(false))))
        XCTAssertTrue(self.isEnabled(self.configuration(.bool(true))))
    }

    func testKillSwitchParsesNumbersAndIgnoresOtherTypes() {
        XCTAssertFalse(self.isEnabled(self.configuration(.number(0.0))))
        XCTAssertTrue(self.isEnabled(self.configuration(.number(1.0))))
        XCTAssertTrue(self.isEnabled(self.configuration(.string("false"))))
    }

    // Layer 232 parks the feed API: News stays off whatever the app config says.
    func testNewsIsOffWhileTheFeedApiIsParked() {
        XCTAssertFalse(isNewsFeedEnabled(appConfiguration: self.configuration(nil, dev: 1.0), apiIsAvailable: false))
        XCTAssertFalse(isNewsFeedEnabled(appConfiguration: self.configuration(.bool(true), dev: 1.0), apiIsAvailable: false))
    }

    // Call sites pass no argument: the gate follows the build's feed API.
    func testTheGateFollowsTheBuildsFeedApi() {
        XCTAssertEqual(isNewsFeedEnabled(appConfiguration: self.configuration(nil, dev: 1.0)), newsFeedApiIsAvailable)
    }

    // MARK: preview text

    func testShortTextKeepsItsEntities() {
        let entities = [MessageTextEntity(range: 0 ..< 5, type: .Spoiler)]
        let result = newsPreviewTextPrefix("hello world", entities: entities, maxLength: 11)
        XCTAssertEqual(result.text, "hello world")
        XCTAssertEqual(result.entities, entities)
    }

    func testLongTextIsCutWithItsEntities() {
        let text = String(repeating: "a", count: 100)
        let result = newsPreviewTextPrefix(text, entities: [
            MessageTextEntity(range: 0 ..< 5, type: .Strikethrough),
            MessageTextEntity(range: 5 ..< 60, type: .Spoiler),
            MessageTextEntity(range: 70 ..< 80, type: .Underline)
        ], maxLength: 50)
        XCTAssertEqual(result.text, String(repeating: "a", count: 50))
        // A spoiler running past the cut still hides the part that is shown.
        XCTAssertEqual(result.entities, [
            MessageTextEntity(range: 0 ..< 5, type: .Strikethrough),
            MessageTextEntity(range: 5 ..< 50, type: .Spoiler)
        ])
    }

    func testCustomEmojiAndDatesAcrossTheCutAreDropped() {
        let text = String(repeating: "a", count: 48) + "😀😀" + String(repeating: "b", count: 20)
        let result = newsPreviewTextPrefix(text, entities: [
            MessageTextEntity(range: 48 ..< 52, type: .CustomEmoji(stickerPack: nil, fileId: 1)),
            MessageTextEntity(range: 40 ..< 60, type: .FormattedDate(format: nil, date: 0))
        ], maxLength: 51)
        XCTAssertEqual(result.entities, [])
    }

    func testCutDoesNotSplitACharacter() {
        // The cut falls between the two halves of the second emoji's surrogate pair.
        let text = String(repeating: "a", count: 48) + "😀😀" + String(repeating: "b", count: 20)
        XCTAssertEqual(newsPreviewTextPrefix(text, entities: [], maxLength: 51).text, String(repeating: "a", count: 48) + "😀")
        // A family emoji is one character of several scalars.
        let family = "x👨‍👩‍👧‍👦y"
        XCTAssertEqual(newsPreviewTextPrefix(family, entities: [], maxLength: 4).text, "x")
    }
}
