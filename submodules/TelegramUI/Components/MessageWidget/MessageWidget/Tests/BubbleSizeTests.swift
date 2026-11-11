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

    /// widget-sandbox v0.1.3 (integration.md, "Which edge stays put"): the anchor is kept next to the height, for a bubble
    /// re-created from the cache before its widget reports.
    func testTheCacheKeepsTheAnchorWithTheHeight() {
        let cache = MessageWidgetHeightCache()
        cache.set(100.0, anchor: .bottom, for: AnyHashable("A"))
        XCTAssertEqual(cache.entry(for: AnyHashable("A"))?.height, 100.0)
        XCTAssertEqual(cache.entry(for: AnyHashable("A"))?.anchor, .bottom)
        XCTAssertEqual(cache.height(for: AnyHashable("A")), 100.0)
        cache.set(140.0, anchor: .top, for: AnyHashable("A"))
        XCTAssertEqual(cache.entry(for: AnyHashable("A"))?.anchor, .top)
        XCTAssertNil(cache.entry(for: AnyHashable("B")))
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

    // MARK: the edge a bubble's next update keeps (widget-sandbox v0.1.3, integration.md "Which edge stays put")

    private func laidOut(height: CGFloat = 220.0, autoHeight: Bool = true, placeholder: Bool = false, pill: Bool = false, widgetsEnabled: Bool = true) -> MessageWidgetLaidOutHeight {
        return MessageWidgetLaidOutHeight(autoHeight: autoHeight, placeholder: placeholder, pill: pill, widgetsEnabled: widgetsEnabled, height: height)
    }

    private func widget(reported: CGFloat?, anchor: MessageWidgetResizeAnchor = .bottom, failedToStart: Bool = false) -> MessageWidgetRunState {
        return MessageWidgetRunState(reportedHeight: reported, resizeAnchor: anchor, failedToStart: failedToStart)
    }

    func testANewReportedHeightKeepsTheWidgetsEdge() {
        XCTAssertEqual(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: true, widget: self.widget(reported: 340.0), cachedAnchor: .top), .bottom)
    }

    /// An update that leaves the height as it is keeps no edge: its scroll target would end a held jump for nothing.
    func testAnUpdateThatKeepsTheHeightKeepsNoEdge() {
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: true, widget: self.widget(reported: 220.0), cachedAnchor: .bottom))
        // Clamped alike: a report past 600 laid out at 600.
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(height: 600.0), widgetsEnabled: true, widget: self.widget(reported: 900.0), cachedAnchor: .bottom))
        // Nothing reported yet in this run: the cached height stays.
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: true, widget: self.widget(reported: nil), cachedAnchor: .bottom))
    }

    /// The first height after the placeholder is placed as a new message is; a fixed height no report changes.
    func testTheFirstHeightAndAFixedHeightKeepNoEdge() {
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(height: 160.0, placeholder: true), widgetsEnabled: true, widget: self.widget(reported: 340.0), cachedAnchor: nil))
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(height: 300.0, autoHeight: false), widgetsEnabled: true, widget: self.widget(reported: 340.0), cachedAnchor: .bottom))
    }

    /// Widgets switched off: the live widget becomes the pill, keeping the edge it asked for.
    func testWidgetsSwitchedOffKeepTheLiveWidgetsEdge() {
        XCTAssertEqual(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: false, widget: self.widget(reported: 220.0), cachedAnchor: .top), .bottom)
    }

    /// Widgets switched on: the pill becomes the widget, with no widget yet, keeping the edge cached with its height.
    func testWidgetsSwitchedOnKeepTheCachedEdge() {
        XCTAssertEqual(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(height: 64.0, pill: true, widgetsEnabled: false), widgetsEnabled: true, widget: nil, cachedAnchor: .bottom), .bottom)
    }

    func testAPillThatStaysAPillKeepsNoEdge() {
        XCTAssertNil(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(height: 64.0, pill: true), widgetsEnabled: true, widget: nil, cachedAnchor: .bottom))
    }

    /// A widget re-created at its cached height that fails to start goes to the pill, a height change; it never ran,
    /// so the edge is the one cached with the height.
    func testAWidgetThatFailsToStartKeepsTheCachedEdge() {
        XCTAssertEqual(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: true, widget: self.widget(reported: nil, anchor: .top, failedToStart: true), cachedAnchor: .bottom), .bottom)
    }

    /// A re-created widget that has not reported has not run its script either, so its top is no choice of its own:
    /// switched off then, the bubble keeps the edge cached with its height.
    func testAWidgetThatHasNotRunKeepsTheCachedEdge() {
        XCTAssertEqual(MessageWidgetBubbleSize.resizeAnchor(laidOut: self.laidOut(), widgetsEnabled: false, widget: self.widget(reported: nil, anchor: .top), cachedAnchor: .bottom), .bottom)
    }
}
