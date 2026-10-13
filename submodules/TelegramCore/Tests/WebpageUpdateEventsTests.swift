import XCTest
import Postbox
@testable import TelegramCore

/// The web-page events a replayed state produces, which `AccountStateManager.updatedWebpage`
/// delivers. A composer showing a pending link preview waits on exactly one of them, so a
/// resolution that never reaches the events leaves the preview on "Loading…".
final class WebpageUpdateEventsTests: XCTestCase {
    private let webpageId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: 1)
    private let otherWebpageId = MediaId(namespace: Namespaces.Media.CloudWebpage, id: 2)

    /// A key holding nil: the page was resolved to `webPageEmpty`.
    private let removal: TelegramMediaWebpage?? = .some(nil)

    private func pendingWebpage(_ id: MediaId) -> TelegramMediaWebpage {
        return TelegramMediaWebpage(webpageId: id, content: .Pending(0, "https://okinawaguide.org/"))
    }

    private func update(_ webpage: TelegramMediaWebpage) -> TelegramMediaWebpage?? {
        return .some(.some(webpage))
    }

    func testAWebpageUpdateIsRecordedWithItsContent() {
        var updatedWebpages: [MediaId: TelegramMediaWebpage?] = [:]

        recordUpdatedWebpage(self.webpageId, media: self.pendingWebpage(self.webpageId), into: &updatedWebpages)

        XCTAssertEqual(updatedWebpages[self.webpageId], self.update(self.pendingWebpage(self.webpageId)))
    }

    /// `updateWebPage(webPageEmpty)` replays as a nil media update: no preview exists.
    func testAWebpageResolvedToEmptyIsRecordedAsARemoval() {
        var updatedWebpages: [MediaId: TelegramMediaWebpage?] = [:]

        recordUpdatedWebpage(self.webpageId, media: nil, into: &updatedWebpages)

        XCTAssertTrue(updatedWebpages.keys.contains(self.webpageId))
        XCTAssertEqual(updatedWebpages[self.webpageId], self.removal)
    }

    func testANilUpdateOfOtherMediaIsNotRecordedAsAWebpage() {
        var updatedWebpages: [MediaId: TelegramMediaWebpage?] = [:]

        recordUpdatedWebpage(MediaId(namespace: Namespaces.Media.CloudFile, id: 1), media: nil, into: &updatedWebpages)

        XCTAssertTrue(updatedWebpages.isEmpty)
    }

    /// `pollDifference` starts from empty events and unions each difference slice in, so the
    /// right-hand side is where every webpage update from getDifference arrives.
    func testMergingEventsKeepsTheWebpageUpdatesOfBothSides() {
        let earlier = AccountFinalStateEvents(updatedWebpages: [self.webpageId: self.pendingWebpage(self.webpageId)])
        // A nil value in a literal keeps its key; only assigning nil through the subscript drops it.
        let later = AccountFinalStateEvents(updatedWebpages: [self.otherWebpageId: nil])

        let merged = AccountFinalStateEvents().union(with: earlier).union(with: later)

        XCTAssertEqual(merged.updatedWebpages.count, 2)
        XCTAssertEqual(merged.updatedWebpages[self.webpageId], self.update(self.pendingWebpage(self.webpageId)))
        XCTAssertEqual(merged.updatedWebpages[self.otherWebpageId], self.removal)
    }

    func testMergingEventsKeepsTheLaterStateOfTheSameWebpage() {
        let earlier = AccountFinalStateEvents(updatedWebpages: [self.webpageId: self.pendingWebpage(self.webpageId)])
        let later = AccountFinalStateEvents(updatedWebpages: [self.webpageId: nil])

        let merged = earlier.union(with: later)

        XCTAssertEqual(merged.updatedWebpages[self.webpageId], self.removal)
    }
}
