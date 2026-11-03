import Foundation
import UIKit
import XCTest
import ComponentFlow
import TelegramPresentationData
import MultilineTextWithEntitiesComponent
import LiquidLens
@testable import HorizontalTabsComponent

/// The layout of `HorizontalTabsComponent`, whose `.fill` mode the chat list's folder tabs use
/// (bugs.telegram.org/c/64681).
///
/// When the tabs fit side by side, `.fill` stretches them across the whole bar. It used to do that
/// by giving every tab the same slot, checking only that the tabs' TOTAL width fit, and centring
/// each tab in its slot. A tab wider than an equal share then spilled over both neighbours: on a
/// 402pt iPhone "All", "Chatssssssss", "musicccccccc" and "abc" measure 367pt against a 370pt bar,
/// but each slot was 91pt and the two long titles 127pt and 132pt, so they drew over each other.
///
/// The bar is a 3pt border around the glass lens, and the tabs are laid out in the lens. A row
/// slightly wider than the lens (by up to that border on each side) has always filled the bar
/// rather than scrolling, so it still must: the reported row is 3pt wider than the lens.
///
/// The pill is positioned in the lens and the titles in the scroll views, so the two must share
/// coordinates: the scroll views used to sit another 3pt inside the lens, drawing every filled row
/// 3pt right of its pills, and the scrolling layout's compensation made each pill reach 3pt into the
/// previous tab, where a tap selected both.
final class HorizontalTabsFillLayoutTests: XCTestCase {
    // The bar width of a 402pt-wide iPhone (16pt margins), and the lens inside its 3pt border.
    private static let barWidth: CGFloat = 370.0
    private static let barHeight: CGFloat = 44.0
    private static let lensWidth: CGFloat = barWidth - 3.0 * 2.0

    private static let reportedTitles = ["All", "Chatssssssss", "musicccccccc", "abc"]
    private static let shortTitles = ["All", "Chats", "Music", "Bots"]
    private static let scrollingTitles = ["All", "Chatssssssss", "musicccccccc", "Channelsssss", "Botsssssssss"]

    // MARK: - Rendered component

    func testTheReportedFoldersFillTheBarWithoutOverlapping() {
        let rendered = self.render(titles: Self.reportedTitles)
        XCTAssertEqual(rendered.titleFrames.count, 4)
        self.assertNoOverlap(rendered.titleFrames)
        XCTAssertFalse(rendered.isScrollable, "the reported row is 3pt wider than the lens and must fill the bar, not scroll")
        for frame in rendered.titleFrames {
            XCTAssertTrue(rendered.lensFrame.contains(frame), "\(frame) outside the lens \(rendered.lensFrame)")
        }
    }

    func testTheReportedRowIsWiderThanTheLensButNarrowerThanTheBar() {
        // Guards the premise of the test above.
        let rendered = self.render(titles: Self.reportedTitles)
        let totalWidth = rendered.titleFrames.reduce(0.0, { $0 + $1.width + Self.tabPadding * 2.0 })
        XCTAssertGreaterThan(totalWidth, Self.lensWidth)
        XCTAssertLessThanOrEqual(totalWidth, Self.barWidth)
    }

    func testLongTitlesThatFitTheLensDoNotOverlap() {
        let rendered = self.render(titles: ["All", "Chatssssssss", "musicccccccc", "ir"])
        XCTAssertEqual(rendered.titleFrames.count, 4)
        self.assertNoOverlap(rendered.titleFrames)
        XCTAssertFalse(rendered.isScrollable)
    }

    func testTheSelectedTitleIsCentredInItsPill() {
        // Equal slots, grown slots, squeezed slots and a scrolling row.
        let rows = [
            Self.shortTitles,
            ["All", "Chatssssssss", "musicccccccc", "ir"],
            Self.reportedTitles,
            Self.scrollingTitles,
        ]
        for titles in rows {
            for index in titles.indices {
                let rendered = self.render(titles: titles, selectedIndex: index)
                XCTAssertEqual(rendered.isScrollable, titles == Self.scrollingTitles, "\(titles)")
                XCTAssertEqual(rendered.pillFrame.midX, rendered.titleFrames[index].midX, accuracy: 1.0, "\(titles[index]) in \(titles)")
            }
        }
    }

    func testAScrollingRowsPillIsItsTab() {
        // Tabs too wide for the bar scroll, laid out at their own widths from the lens edge.
        let rendered = self.render(titles: Self.scrollingTitles, selectedIndex: 1)
        XCTAssertTrue(rendered.isScrollable)
        self.assertNoOverlap(rendered.titleFrames)

        let tabFrames = self.tabFrames(of: rendered)
        for (titleFrame, tabFrame) in zip(rendered.titleFrames, tabFrames) {
            XCTAssertEqual(titleFrame.minX, tabFrame.minX + Self.tabPadding, accuracy: 0.001)
        }
        XCTAssertEqual(tabFrames.first?.minX ?? 0.0, rendered.lensFrame.minX, accuracy: 0.001)
        XCTAssertEqual(rendered.pillFrame.minX, tabFrames[1].minX, accuracy: 0.001)
        XCTAssertEqual(rendered.pillFrame.maxX, tabFrames[1].maxX, accuracy: 0.001)
    }

    func testPillsDoNotOverlap() {
        for titles in [Self.shortTitles, Self.reportedTitles, Self.scrollingTitles] {
            // In content coordinates: selecting a tab can scroll the row to it.
            let pills = titles.indices.map { index -> CGRect in
                let rendered = self.render(titles: titles, selectedIndex: index)
                return rendered.pillFrame.offsetBy(dx: rendered.scrollOffset, dy: 0.0)
            }
            for (lhs, rhs) in zip(pills, pills.dropFirst()) {
                XCTAssertLessThanOrEqual(lhs.maxX, rhs.minX, "\(lhs) overlaps \(rhs) in \(titles)")
            }
        }
    }

    func testATapSelectsOnlyTheTabUnderIt() {
        // Filled rows: the tab whose pill covers the point.
        for titles in [Self.shortTitles, Self.reportedTitles] {
            let (componentView, view) = self.makeView(titles: titles)
            let rendered = self.measure(view)
            XCTAssertFalse(rendered.isScrollable)
            let pills = titles.indices.map { self.render(titles: titles, selectedIndex: $0).pillFrame }
            for x in stride(from: rendered.lensFrame.minX, to: rendered.lensFrame.maxX, by: 0.5) {
                let point = CGPoint(x: x, y: rendered.lensFrame.midY)
                let expected = pills.firstIndex(where: { $0.contains(point) }).map { AnyHashable($0) }
                XCTAssertNotNil(expected, "\(point) in no pill in \(titles)")
                XCTAssertEqual(view.tabId(at: point), expected, "\(point) in \(titles)")
            }
            withExtendedLifetime(componentView) {}
        }

        // A scrolling row, unscrolled: the tab under the point, including the 3pt just left of each
        // tab, where the pills used to overlap the previous tab's and a tap selected both.
        let (componentView, view) = self.makeView(titles: Self.scrollingTitles)
        let rendered = self.measure(view)
        XCTAssertTrue(rendered.isScrollable)
        XCTAssertEqual(rendered.scrollOffset, 0.0)
        let tabFrames = self.tabFrames(of: rendered)
        for x in stride(from: rendered.lensFrame.minX, to: rendered.lensFrame.maxX, by: 0.5) {
            let point = CGPoint(x: x, y: rendered.lensFrame.midY)
            let expected = tabFrames.firstIndex(where: { $0.contains(point) }).map { AnyHashable($0) }
            XCTAssertEqual(view.tabId(at: point), expected, "\(point)")
        }
        for index in tabFrames.indices.dropFirst() where tabFrames[index].minX < rendered.lensFrame.maxX {
            let point = CGPoint(x: tabFrames[index].minX - 1.5, y: rendered.lensFrame.midY)
            XCTAssertEqual(view.tabId(at: point), AnyHashable(index - 1), "\(point)")
        }
        withExtendedLifetime(componentView) {}
    }

    func testTheBorderAroundTheLensBelongsToTheNearestTab() {
        let (componentView, view) = self.makeView(titles: Self.shortTitles)
        let rendered = self.measure(view)
        let midY = rendered.lensFrame.midY
        let secondTitleMidX = rendered.titleFrames[1].midX

        let cases: [(CGPoint, Int)] = [
            (CGPoint(x: 1.0, y: midY), 0),
            (CGPoint(x: Self.barWidth - 1.0, y: midY), 3),
            (CGPoint(x: secondTitleMidX, y: 1.0), 1),
            (CGPoint(x: secondTitleMidX, y: Self.barHeight - 1.0), 1),
            (CGPoint(x: 0.0, y: 0.0), 0),
        ]
        for (point, index) in cases {
            XCTAssertNotNil(view.hitTest(point, with: nil), "\(point)")
            XCTAssertEqual(view.tabId(at: point), AnyHashable(index), "\(point)")
        }
        for point in [CGPoint(x: -1.0, y: midY), CGPoint(x: Self.barWidth + 1.0, y: midY), CGPoint(x: secondTitleMidX, y: -1.0)] {
            XCTAssertNil(view.hitTest(point, with: nil), "\(point)")
            XCTAssertNil(view.tabId(at: point), "\(point)")
        }
        withExtendedLifetime(componentView) {}
    }

    func testDraggingTheSelectedTabCarriesItsPill() {
        // Edit mode, a row that fills the bar: the pill keeps its slot's width and follows the tab.
        let (componentView, view) = self.makeView(titles: Self.shortTitles, selectedIndex: 1, isEditing: true)
        let before = self.measure(view)
        let titleFrame = before.titleFrames[1]
        XCTAssertEqual(before.pillFrame.midX, titleFrame.midX, accuracy: 1.0)

        view.beginReordering(at: CGPoint(x: titleFrame.midX, y: titleFrame.midY))
        view.updateReordering(offset: 4.0)
        let during = self.measure(view)
        XCTAssertEqual(during.pillFrame.width, before.pillFrame.width, accuracy: 0.001)
        XCTAssertEqual(during.pillFrame.midX, titleFrame.midX + 4.0, accuracy: 1.0)

        view.endReordering()
        let after = self.measure(view)
        XCTAssertEqual(after.pillFrame, before.pillFrame)
        withExtendedLifetime(componentView) {}
    }

    // MARK: - Slot widths

    func testShortTabsGetEqualSlots() {
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [50.0, 58.0, 70.0, 42.0], availableWidth: 364.0, paddingAllowance: 6.0), [91.0, 91.0, 91.0, 91.0])
        // The rounding is spread over the row, not left to the last slot.
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [50.0, 58.0, 70.0], availableWidth: 364.0, paddingAllowance: 6.0), [121.0, 122.0, 121.0])
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [40.0, 40.0, 40.0, 40.0, 40.0], availableWidth: 364.0, paddingAllowance: 6.0), [73.0, 73.0, 72.0, 73.0, 73.0])
    }

    func testWideTabsKeepTheirWidthAndTheRestShareTheRemainder() {
        // The two long titles keep their own width, the short ones split the 105pt that is left.
        let slots = horizontalTabsFillSlotWidths(itemWidths: [50.0, 127.0, 132.0, 42.0], availableWidth: 364.0, paddingAllowance: 6.0)
        XCTAssertEqual(slots, [53.0, 127.0, 132.0, 52.0])
    }

    func testATabNarrowerThanTheEqualShareCanStillNeedItsOwnWidth() {
        // 70 fits the equal share of 75, but once the 110pt tab keeps its own width the other three
        // share only 190pt, 63pt each. Only splitting off the tabs wider than the first share would
        // squeeze the 70pt tab into 63pt.
        let slots = horizontalTabsFillSlotWidths(itemWidths: [40.0, 70.0, 110.0, 40.0], availableWidth: 300.0, paddingAllowance: 6.0)
        XCTAssertEqual(slots, [60.0, 70.0, 110.0, 60.0])
    }

    func testARowSlightlyWiderThanTheLensGivesUpPaddingEvenly() {
        // The reported row, 3pt over: every tab gives up 0.75pt of padding, to the nearest point.
        let itemWidths: [CGFloat] = [50.0, 127.0, 132.0, 58.0]
        let slots = horizontalTabsFillSlotWidths(itemWidths: itemWidths, availableWidth: 364.0, paddingAllowance: 6.0)
        XCTAssertEqual(slots, [49.0, 127.0, 131.0, 57.0])
        for (slot, itemWidth) in zip(slots ?? [], itemWidths) {
            XCTAssertLessThan(abs(slot - (itemWidth - 0.75)), 1.0)
        }

        // The whole allowance.
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [100.0, 170.0, 100.0], availableWidth: 364.0, paddingAllowance: 6.0), [98.0, 168.0, 98.0])
    }

    func testEverySlotHoldsItsTab() {
        let widthSets: [[CGFloat]] = [
            [50.0, 127.0, 132.0, 42.0],
            [300.0, 20.0],
            [20.0, 300.0],
            [100.0, 100.0, 100.0],
            [364.0],
            [10.0],
            [33.0, 97.0, 12.0, 160.0, 41.0],
        ]
        for itemWidths in widthSets {
            guard let slots = horizontalTabsFillSlotWidths(itemWidths: itemWidths, availableWidth: 364.0, paddingAllowance: 6.0) else {
                XCTFail("\(itemWidths) fit in 364pt")
                continue
            }
            XCTAssertEqual(slots.count, itemWidths.count)
            XCTAssertEqual(slots.reduce(0.0, +), 364.0, "\(itemWidths)")
            for (slot, itemWidth) in zip(slots, itemWidths) {
                XCTAssertGreaterThanOrEqual(slot, itemWidth, "\(itemWidths) -> \(slots)")
            }
        }
    }

    func testFractionalTabWidthsStillGetWholePointSlots() {
        // A `.custom` tab can measure a fraction of a point. The slot edges stay on whole points so
        // that no later tab is drawn off the pixel grid.
        // The last set is 4.5pt wider than the lens and squeezed; the others fit, so each slot is at
        // most the rounding short of its tab.
        let widthSets: [[CGFloat]] = [
            [50.4, 127.6, 132.3, 42.1],
            [60.25, 60.25, 60.25],
            [50.4, 127.6, 132.3, 58.2],
        ]
        for itemWidths in widthSets {
            guard let slots = horizontalTabsFillSlotWidths(itemWidths: itemWidths, availableWidth: 364.0, paddingAllowance: 6.0) else {
                XCTFail("\(itemWidths) fit in 370pt")
                continue
            }
            XCTAssertEqual(slots.reduce(0.0, +), 364.0, accuracy: 0.0001, "\(itemWidths)")
            let fits = itemWidths.reduce(0.0, +) <= 364.0
            var edge: CGFloat = 0.0
            for (slot, itemWidth) in zip(slots, itemWidths) {
                XCTAssertEqual(edge, edge.rounded(), "\(itemWidths) -> \(slots)")
                if fits {
                    XCTAssertGreaterThanOrEqual(slot, itemWidth - 1.0, "\(itemWidths) -> \(slots)")
                }
                edge += slot
            }
        }
    }

    func testTabsExactlyFillingTheLensGetTheirOwnWidths() {
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [100.0, 164.0, 100.0], availableWidth: 364.0, paddingAllowance: 6.0), [100.0, 164.0, 100.0])
    }

    func testTabsWiderThanTheAllowanceScroll() {
        XCTAssertNil(horizontalTabsFillSlotWidths(itemWidths: [100.0, 171.0, 100.0], availableWidth: 364.0, paddingAllowance: 6.0))
        XCTAssertNil(horizontalTabsFillSlotWidths(itemWidths: [100.0, 165.0, 100.0], availableWidth: 364.0, paddingAllowance: 0.0))
    }

    func testNoTabsFit() {
        XCTAssertEqual(horizontalTabsFillSlotWidths(itemWidths: [], availableWidth: 364.0, paddingAllowance: 6.0), [])
    }

    // MARK: - Helpers

    // ItemComponent's side inset around the title.
    private static let tabPadding: CGFloat = 16.0

    private struct Rendered {
        // All in the component's coordinates, the titles sorted left to right.
        var titleFrames: [CGRect]
        var pillFrame: CGRect
        var lensFrame: CGRect
        var isScrollable: Bool
        var scrollOffset: CGFloat
    }

    private func render(titles: [String], selectedIndex: Int = 0, file: StaticString = #filePath, line: UInt = #line) -> Rendered {
        let (componentView, view) = self.makeView(titles: titles, selectedIndex: selectedIndex, file: file, line: line)
        return withExtendedLifetime(componentView) {
            self.measure(view, file: file, line: line)
        }
    }

    private func makeView(titles: [String], selectedIndex: Int = 0, isEditing: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> (ComponentView<Empty>, HorizontalTabsComponent.View) {
        let tabs = titles.enumerated().map { index, title in
            HorizontalTabsComponent.Tab(
                id: AnyHashable(index),
                content: .title(HorizontalTabsComponent.Tab.Title(text: title, entities: [], enableAnimations: false)),
                badge: nil,
                action: {}
            )
        }
        let component = HorizontalTabsComponent(
            context: nil,
            theme: defaultDarkPresentationTheme,
            tabs: tabs,
            selectedTab: AnyHashable(selectedIndex),
            isEditing: isEditing
        )
        let componentView = ComponentView<Empty>()
        let _ = componentView.update(
            transition: .immediate,
            component: AnyComponent(component),
            environment: {},
            containerSize: CGSize(width: Self.barWidth, height: Self.barHeight)
        )
        guard let view = componentView.view as? HorizontalTabsComponent.View else {
            XCTFail("no view", file: file, line: line)
            return (componentView, HorizontalTabsComponent.View(frame: .zero))
        }
        view.frame = CGRect(origin: .zero, size: CGSize(width: Self.barWidth, height: Self.barHeight))
        return (componentView, view)
    }

    private func measure(_ view: HorizontalTabsComponent.View, file: StaticString = #filePath, line: UInt = #line) -> Rendered {
        // The titles of the regular copy of each tab: in the scroll view, or reparented to the
        // component while dragged. The selected copy lives under the lens and has the same frames.
        let scrollViews = self.descendants(of: view).compactMap { $0 as? UIScrollView }
        XCTAssertEqual(scrollViews.count, 1, file: file, line: line)
        let lensViews = self.descendants(of: view).compactMap { $0 as? LiquidLensView }
        XCTAssertEqual(lensViews.count, 1, file: file, line: line)
        guard let scrollView = scrollViews.first, let lensView = lensViews.first, let selectionOrigin = lensView.selectionOrigin, let selectionSize = lensView.selectionSize else {
            return Rendered(titleFrames: [], pillFrame: .zero, lensFrame: .zero, isScrollable: false, scrollOffset: 0.0)
        }
        let selectedCopies = Set(self.descendants(of: lensView.selectedContentView).map(ObjectIdentifier.init))
        let titleFrames = self.descendants(of: view)
            .filter { $0 is MultilineTextWithEntitiesComponent.View && !selectedCopies.contains(ObjectIdentifier($0)) }
            .map { $0.convert($0.bounds, to: view) }
            .sorted(by: { $0.minX < $1.minX })
        return Rendered(
            titleFrames: titleFrames,
            pillFrame: lensView.convert(CGRect(origin: selectionOrigin, size: selectionSize), to: view),
            lensFrame: lensView.frame,
            isScrollable: scrollView.contentSize.width > scrollView.bounds.width + 0.001,
            scrollOffset: scrollView.contentOffset.x
        )
    }

    // The tabs of a scrolling row, back to back from the lens edge.
    private func tabFrames(of rendered: Rendered) -> [CGRect] {
        var minX = rendered.lensFrame.minX
        return rendered.titleFrames.map { titleFrame in
            let frame = CGRect(x: minX, y: rendered.lensFrame.minY, width: titleFrame.width + Self.tabPadding * 2.0, height: rendered.lensFrame.height)
            minX = frame.maxX
            return frame
        }
    }

    private func descendants(of view: UIView) -> [UIView] {
        return view.subviews.flatMap { [$0] + self.descendants(of: $0) }
    }

    private func assertNoOverlap(_ frames: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        for (lhs, rhs) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThanOrEqual(lhs.maxX, rhs.minX, "\(lhs) overlaps \(rhs) in \(frames)", file: file, line: line)
        }
    }
}
