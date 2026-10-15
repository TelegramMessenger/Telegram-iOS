import XCTest
import CoreGraphics
import TelegramCore
@testable import NewsFeedSupport

final class NewsFreshBlockTests: XCTestCase {
    private let channel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func entry(_ id: Int32, date: Int32) -> EngineFeedEntry {
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: self.channel, id: id), messageIds: [EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: id)], groupingKey: nil)
    }

    func testBlockAlphaEnvelope() {
        XCTAssertEqual(NewsFreshBlock.alpha(at: 0.1), 0.0)
        XCTAssertEqual(NewsFreshBlock.alpha(at: 0.14 + 0.175), 0.5, accuracy: 1e-6)
        XCTAssertEqual(NewsFreshBlock.alpha(at: 2.0), 1.0)
        XCTAssertEqual(NewsFreshBlock.alpha(at: 4.57), 0.5, accuracy: 1e-6)
        XCTAssertEqual(NewsFreshBlock.alpha(at: 6.0), 0.0, accuracy: 1e-9)
    }

    func testSlicesJoinIntoOneCard() {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 100.0)
        XCTAssertEqual(NewsFreshBlock.sliceRect(bounds: bounds, isFirst: true, isLast: true), CGRect(x: 8.0, y: 3.0, width: 386.0, height: 94.0))
        XCTAssertEqual(NewsFreshBlock.sliceRect(bounds: bounds, isFirst: true, isLast: false), CGRect(x: 8.0, y: 3.0, width: 386.0, height: 137.0))
        XCTAssertEqual(NewsFreshBlock.sliceRect(bounds: bounds, isFirst: false, isLast: false), CGRect(x: 8.0, y: -40.0, width: 386.0, height: 180.0))
        XCTAssertEqual(NewsFreshBlock.clipRect(bounds: bounds, isFirst: false, isLast: true), CGRect(x: 8.0, y: 0.0, width: 386.0, height: 97.0))
    }

    func testLens() {
        XCTAssertEqual(NewsFreshBlock.lensScale(0.0), 1.3, accuracy: 1e-9)
        XCTAssertEqual(NewsFreshBlock.lensBlur(0.5), 3.0, accuracy: 1e-9)
        XCTAssertEqual(NewsFreshBlock.lensAlpha(0.35), 0.5, accuracy: 1e-9)
        XCTAssertEqual(NewsFreshBlock.lensProgress(NewsFreshBlock.lensSettle), 1.0, accuracy: 0.001)
        let segment = NewsFreshSegment(index: 2, isFirst: false, isLast: false, revealTime: 10.0)
        XCTAssertEqual(NewsFreshBlock.lensDelay(now: 10.0, segment: segment), 0.14 + 0.12, accuracy: 1e-9)
        XCTAssertEqual(NewsFreshBlock.lensDelay(now: 10.5, segment: segment), 0.12, accuracy: 1e-9)
        XCTAssertTrue(NewsFreshBlock.runsLens(createdAt: 10.3, segment: segment))
        XCTAssertFalse(NewsFreshBlock.runsLens(createdAt: 10.31, segment: segment))
    }

    func testGlowDrift() {
        let (start, end) = NewsFreshBlock.glowCenters(size: CGSize(width: 386.0, height: 300.0))
        XCTAssertEqual(start.x, 8.0, accuracy: 1e-9)
        XCTAssertEqual(start.y, 120.0, accuracy: 1e-9)
        XCTAssertEqual(end.x, 177.56, accuracy: 1e-9)
        XCTAssertEqual(end.y, 2.0, accuracy: 1e-9)
    }

    func testRunsOfFreshRows() {
        let segments = newsFreshSegments(isFresh: [true, true, false, true], revealTime: 5.0)
        XCTAssertEqual(segments[0], NewsFreshSegment(index: 0, isFirst: true, isLast: false, revealTime: 5.0))
        XCTAssertEqual(segments[1], NewsFreshSegment(index: 1, isFirst: false, isLast: true, revealTime: 5.0))
        XCTAssertNil(segments[2])
        XCTAssertEqual(segments[3], NewsFreshSegment(index: 2, isFirst: true, isLast: true, revealTime: 5.0))
    }

    func testForYouFreshPostsAreTheOnesNotKnownBefore() {
        let old = self.entry(1, date: 100)
        let new = self.entry(2, date: 200)
        let known = newsForYouPostKeys([.post(old)])
        XCTAssertEqual(newsForYouFreshPostKeys(knownKeys: known, items: [.post(new), .post(old)]), [newsPostIdentity(new)])
        XCTAssertEqual(newsForYouFreshPostKeys(knownKeys: known, items: [.post(old)]), [])
    }

    func testForYouFreshPostsAreOnlyTheOnesTheRefreshPrepended() {
        let old = self.entry(1, date: 100)
        let new = self.entry(2, date: 200)
        let appended = self.entry(3, date: 50)
        let known = newsForYouPostKeys([.post(old)])
        // A load-more that landed during the pull appended `appended` after the known posts: it is not fresh.
        XCTAssertEqual(newsForYouFreshPostKeys(knownKeys: known, items: [.interests, .post(new), .post(old), .post(appended)]), [newsPostIdentity(new)])
    }

    func testHeldItemsAreThePrePullFeedPlusAppendedPosts() {
        let a = self.entry(1, date: 100)
        let b = self.entry(2, date: 90)
        let c = self.entry(3, date: 80)
        let x = self.entry(4, date: 200)
        let f = self.entry(5, date: 70)
        // Before the pull the marker sat mid-list; the refresh's batch brought its own marker, and the merge dropped the old one.
        let snapshot: [EngineForYouItem] = [.post(a), .post(b), .interests, .post(c)]
        XCTAssertEqual(newsForYouHeldItems(snapshot: snapshot, current: [.interests, .post(x), .post(a), .post(b), .post(c)]), snapshot)
        // A load-more appended `f` meanwhile: it shows, after the snapshot.
        XCTAssertEqual(newsForYouHeldItems(snapshot: snapshot, current: [.interests, .post(x), .post(a), .post(b), .post(c), .post(f)]), snapshot + [.post(f)])
    }

    func testAnAddedPullEndsWhenTheInitialLoadItWaitedOnEnds() {
        // The pull began while the first page was still loading: loadNewer(force:) refuses to start then.
        var request = NewsAddedPullRequest(isLoadingNewer: false, isLoadingInitial: true)
        XCTAssertFalse(request.observe(isLoadingNewer: false, isLoadingInitial: true))
        XCTAssertTrue(request.observe(isLoadingNewer: false, isLoadingInitial: false))
        // An ordinary pull: not started yet, running, done.
        var plain = NewsAddedPullRequest(isLoadingNewer: false, isLoadingInitial: false)
        XCTAssertFalse(plain.observe(isLoadingNewer: false, isLoadingInitial: false))
        XCTAssertFalse(plain.observe(isLoadingNewer: true, isLoadingInitial: false))
        XCTAssertTrue(plain.observe(isLoadingNewer: false, isLoadingInitial: false))
    }

    func testAddedFreshPostsAreTheOnesAboveTheOldTop() {
        let entries = [self.entry(3, date: 300), self.entry(2, date: 200), self.entry(1, date: 100)]
        XCTAssertEqual(newsAddedFreshPostKeys(entries: entries, above: entries[1].position), [newsPostIdentity(entries[0])])
    }
}
