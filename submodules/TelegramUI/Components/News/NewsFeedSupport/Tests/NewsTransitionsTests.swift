import XCTest
import CoreGraphics
@testable import NewsFeedSupport

/// The cascade (Feed2 FeedRow.swift:104-112), the tab-switch shutter (FeedStore.swift:799-815) and Reload Feed.
final class NewsTransitionsTests: XCTestCase {
    // The mockup counts its search and widget rows, so its first post waits two steps; ours does too.
    func testCascadeStartsTheFirstRowWhereTheMockupStartsItsFirstPost() {
        XCTAssertEqual(NewsCascade.delay(position: 0), 0.09, accuracy: 0.0001)
        XCTAssertEqual(NewsCascade.delay(position: 1), 0.135, accuracy: 0.0001)
        XCTAssertEqual(NewsCascade.delay(position: 6), 0.36, accuracy: 0.0001)
        XCTAssertEqual(NewsCascade.delay(position: 40), 0.36, accuracy: 0.0001)
    }

    func testShutterSwapsWhenOpaqueAndClearsThirtyMillisecondsLater() {
        XCTAssertEqual(NewsShutter.swapDelay, NewsShutter.fadeInDuration)
        XCTAssertEqual(NewsShutter.fadeOutDelay - NewsShutter.swapDelay, 0.03, accuracy: 0.0001)
        XCTAssertEqual(NewsShutter.fadeOutDuration, 0.3)
    }

    func testANewerTransitionCancelsTheOlderOnesSteps() {
        let generation = NewsGeneration()
        let first = generation.begin()
        XCTAssertTrue(generation.isCurrent(first))
        let second = generation.begin()
        XCTAssertFalse(generation.isCurrent(first))
        XCTAssertTrue(generation.isCurrent(second))
    }

    func testReloadEndsWhenTheLoadItStartedEnds() {
        var tracker = NewsReloadTracker()
        tracker.begin(isLoading: false)
        XCTAssertTrue(tracker.isActive)
        // The request has not been reported yet: still waiting.
        XCTAssertFalse(tracker.observe(isLoading: false))
        XCTAssertFalse(tracker.observe(isLoading: true))
        XCTAssertTrue(tracker.observe(isLoading: false))
        XCTAssertFalse(tracker.isActive)
    }

    // A refresh already in flight is the reload's load.
    func testReloadJoinsALoadAlreadyInFlight() {
        var tracker = NewsReloadTracker()
        tracker.begin(isLoading: true)
        XCTAssertTrue(tracker.observe(isLoading: false))
        XCTAssertFalse(tracker.isActive)
    }

    // Offline the request is queued, not failed: a reload must still give the rows back.
    func testATimedOutReloadEndsEvenWithoutALoad() {
        var tracker = NewsReloadTracker()
        let token = tracker.begin(isLoading: false)
        XCTAssertTrue(tracker.expire(token: token))
        XCTAssertFalse(tracker.isActive)
    }

    func testAnExpiryFromAnEarlierReloadIsIgnored() {
        var tracker = NewsReloadTracker()
        let first = tracker.begin(isLoading: false)
        let second = tracker.begin(isLoading: true)
        XCTAssertFalse(tracker.expire(token: first))
        XCTAssertTrue(tracker.isActive)
        XCTAssertTrue(tracker.expire(token: second))
        XCTAssertFalse(tracker.isActive)
    }

    func testAnExpiryAfterTheReloadEndedDoesNothing() {
        var tracker = NewsReloadTracker()
        let token = tracker.begin(isLoading: true)
        XCTAssertTrue(tracker.observe(isLoading: false))
        XCTAssertFalse(tracker.expire(token: token))
    }

    func testIdleTrackerIgnoresStates() {
        var tracker = NewsReloadTracker()
        XCTAssertFalse(tracker.observe(isLoading: true))
        XCTAssertFalse(tracker.observe(isLoading: false))
        XCTAssertFalse(tracker.isActive)
    }
}
