import XCTest
import UIKit
@testable import CoreListDemo

/// `stacksFromBottom` (`ListViewImpl.stackFromBottom`; the chat's inline bot results list): a whole collection that fits
/// between the insets rests on the BOTTOM inset edge instead of the top one, and its scroll range is that one offset. A
/// collection taller than that area is placed as without it, its first row on the top inset edge.
///
/// Viewport 400, insets 100 / 50: the area between them is 250, five 50 pt rows.
final class StackFromBottomTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)
    private let insets = UIEdgeInsets(top: 100, left: 0, bottom: 50, right: 0)

    private func items(_ ids: [UUID]) -> [CoreListItem] {
        return ids.map { IdentifiableFixedHeightItem(id: $0, height: 50) }
    }

    /// Built empty, the option set, then the rows and insets in one pass, as a host sets it once before its first rows.
    /// The insets arrive after construction anyway: the driver's construction-time layout clamps a negative offset (see
    /// `BottomEdgePinTests.fixture`).
    private func fixture(_ items: [CoreListItem], stacks: Bool = true) -> VirtualListFixture {
        let fixture = VirtualListFixture(viewport: viewport, items: [])
        fixture.listView.stacksFromBottom = stacks
        fixture.listView.applyChanges(items: items, newInsets: insets, transition: .easeInOut(duration: 0))
        return fixture
    }

    private func fixture(count: Int, stacks: Bool = true) -> (VirtualListFixture, [UUID]) {
        let ids = (0..<count).map { _ in UUID() }
        return (self.fixture(self.items(ids), stacks: stacks), ids)
    }

    private func bottom(_ fixture: VirtualListFixture, _ id: UUID) throws -> CGFloat {
        return try XCTUnwrap(fixture.settledScreenY(identity: id)) + 50
    }

    func testAShortCollectionRestsOnTheBottomInsetEdge() throws {
        let (fixture, ids) = self.fixture(count: 3)
        XCTAssertEqual(try self.bottom(fixture, ids[2]), 350, accuracy: 1e-6, "the last row is not on the bottom inset edge")
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 200, accuracy: 1e-6)
    }

    /// The control: off, the same collection rests on the top inset edge.
    func testWithoutItAShortCollectionRestsOnTheTopInsetEdge() throws {
        let (fixture, ids) = self.fixture(count: 3, stacks: false)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 100, accuracy: 1e-6)
    }

    /// The declared minimum edge carries the placement, so a drag springs back to it and the pass's own clamp keeps it;
    /// the maximum is the same offset (the content fits), so there is nothing to scroll.
    func testTheScrollRangeIsTheRestingOffset() throws {
        let (fixture, _) = self.fixture(count: 3)
        let minimum = try XCTUnwrap(fixture.declaredEdges.min)
        let maximum = try XCTUnwrap(fixture.declaredEdges.max)
        XCTAssertEqual(fixture.boundsOriginY, minimum, accuracy: 1e-6, "the list does not rest on its declared minimum")
        XCTAssertLessThanOrEqual(maximum, minimum + 1e-6, "a stacked collection that fits can scroll: \(fixture.declaredEdges)")
    }

    func testACollectionTallerThanTheAreaRestsOnTheTopInsetEdge() throws {
        let (fixture, ids) = self.fixture(count: 6)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 100, accuracy: 1e-6)
    }

    func testARowAddedThatStillFitsKeepsTheLastRowOnTheBottomEdge() throws {
        let (fixture, ids) = self.fixture(count: 3)
        let added = UUID()
        fixture.listView.applyChanges(items: self.items(ids + [added]), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try self.bottom(fixture, added), 350, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 150, accuracy: 1e-6)
    }

    /// Growing past the area hands the collection to the top edge, as `ListViewImpl` does; shrinking back stacks it
    /// again.
    func testGrowingPastTheAreaAndBack() throws {
        let (fixture, ids) = self.fixture(count: 3)
        let more = (0..<3).map { _ in UUID() }
        fixture.listView.applyChanges(items: self.items(ids + more), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 100, accuracy: 1e-6, "past the area")
        fixture.listView.applyChanges(items: self.items(ids), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try self.bottom(fixture, ids[2]), 350, accuracy: 1e-6, "back inside the area")
    }

    func testABottomInsetChangeKeepsTheLastRowOnTheBottomEdge() throws {
        let (fixture, ids) = self.fixture(count: 3)
        var insets = self.insets
        insets.bottom = 80
        fixture.listView.applyChanges(newInsets: insets, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try self.bottom(fixture, ids[2]), 320, accuracy: 1e-6)
    }

    /// A row's own growth (a widget result reporting its height) while the collection still fits: the rows above it move
    /// up, the last row stays on the bottom edge.
    func testARowGrowingWhileItFitsKeepsTheLastRowOnTheBottomEdge() throws {
        let ids = (0..<3).map { _ in UUID() }
        func items(middle: CGFloat) -> [CoreListItem] {
            return [
                ContentResizableItem(id: ids[0], contentHeight: 50),
                ContentResizableItem(id: ids[1], contentHeight: middle),
                ContentResizableItem(id: ids[2], contentHeight: 50)
            ]
        }
        let fixture = self.fixture(items(middle: 50))
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[2])) + 50, 350, accuracy: 1e-6, "precondition")

        fixture.listView.applyChanges(items: items(middle: 100), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[2])) + 50, 350, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: ids[0])), 150, accuracy: 1e-6)
    }
}
