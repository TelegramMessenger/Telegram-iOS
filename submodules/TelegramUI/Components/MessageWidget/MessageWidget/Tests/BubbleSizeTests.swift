import XCTest
@testable import MessageWidget

/// widget-sandbox v0.1.0, integration.md "Bubble sizing" and sdk-v1.md §5.6: width 0 is the bubble's width, W a fixed
/// width in [200, the bubble's maximum]; height 0 is the placeholder, then the reported content height in [50, 600],
/// cached per message; H a fixed clamp(H, 50, 600) the content does not change.
final class BubbleSizeTests: XCTestCase {
    private func anchors(_ width: Int32, _ height: Int32) -> MessageWidgetAnchors {
        return MessageWidgetAnchors(width: width, height: height)
    }

    func testAutoWidthIsTheBubblesWidth() {
        XCTAssertEqual(MessageWidgetBubbleSize.width(anchors: self.anchors(0, 0), maximumWidth: 320.0), 320.0)
    }

    func testAFixedWidthIsClampedTo200AndTheBubble() {
        XCTAssertEqual(MessageWidgetBubbleSize.width(anchors: self.anchors(150, 0), maximumWidth: 320.0), 200.0)
        XCTAssertEqual(MessageWidgetBubbleSize.width(anchors: self.anchors(300, 0), maximumWidth: 320.0), 300.0)
        XCTAssertEqual(MessageWidgetBubbleSize.width(anchors: self.anchors(500, 0), maximumWidth: 320.0), 320.0)
    }

    func testAutoHeightIsTheReportedHeightClamped() {
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 0), reported: 30.0, cached: nil), 50.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 0), reported: 240.0, cached: nil), 240.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 0), reported: 900.0, cached: 100.0), 600.0)
    }

    func testAutoHeightBeforeLoadIsTheCachedOneThenThePlaceholder() {
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 0), reported: nil, cached: 240.0), 240.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 0), reported: nil, cached: nil), MessageWidgetInstance.placeholderHeight)
        XCTAssertEqual(MessageWidgetInstance.placeholderHeight, 160.0)
    }

    func testFixedHeightIgnoresTheContent() {
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 300), reported: 900.0, cached: nil), 300.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 10), reported: nil, cached: nil), 50.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(300, 1000), reported: 40.0, cached: nil), 600.0)
        XCTAssertEqual(MessageWidgetBubbleSize.height(anchors: self.anchors(0, 300), reported: nil, cached: 120.0), 300.0)
    }

    func testTheHeightCacheKeepsTheLatestPerMessage() {
        let cache = MessageWidgetHeightCache()
        cache.set(100.0, for: AnyHashable("A"))
        cache.set(140.0, for: AnyHashable("A"))
        XCTAssertEqual(cache.height(for: AnyHashable("A")), 140.0)
        XCTAssertNil(cache.height(for: AnyHashable("B")))
    }

    /// Every layout pass sets its message's height again: that must not grow the cache's bookkeeping (task 7 review M2).
    func testSettingTheSameKeysAgainKeepsTheCacheBounded() {
        let cache = MessageWidgetHeightCache(capacity: 2)
        for i in 0 ..< 10_000 {
            cache.set(CGFloat(i % 7), for: AnyHashable(i % 2 == 0 ? "A" : "B"))
        }
        XCTAssertLessThanOrEqual(cache.bookkeepingCountForTesting, 4)
        XCTAssertEqual(cache.height(for: AnyHashable("A")), CGFloat(9_998 % 7))
        XCTAssertEqual(cache.height(for: AnyHashable("B")), CGFloat(9_999 % 7))
    }

    func testTheHeightCacheIsBounded() {
        let cache = MessageWidgetHeightCache(capacity: 2)
        cache.set(100.0, for: AnyHashable("A"))
        cache.set(110.0, for: AnyHashable("B"))
        cache.set(120.0, for: AnyHashable("C"))
        XCTAssertNil(cache.height(for: AnyHashable("A")))
        XCTAssertEqual(cache.height(for: AnyHashable("B")), 110.0)
        XCTAssertEqual(cache.height(for: AnyHashable("C")), 120.0)
    }
}
