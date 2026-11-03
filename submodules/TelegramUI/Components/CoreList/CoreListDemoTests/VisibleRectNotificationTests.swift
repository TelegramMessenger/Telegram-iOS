import XCTest
@testable import CoreListDemo

/// 60pt rows in a 390x800 viewport with the default 160pt preload margin. The initial window is
/// rows 0...15 (the load band is -160...960): rows 0...12 are fully visible (0...780), row 13
/// straddles the bottom edge (780...840), rows 14 and 15 are loaded by the preload margin but sit
/// entirely below the viewport.
final class VisibleRectNotificationTests: XCTestCase {
    private let rowHeight: CGFloat = 60
    private let viewport = CGSize(width: 390, height: 800)

    private func makeFixture(count: Int = 60) -> (VirtualListFixture, [VisibleRectRecordingItem]) {
        let items = (0..<count).map { _ in VisibleRectRecordingItem(id: UUID(), height: rowHeight) }
        let fixture = VirtualListFixture(viewport: viewport, items: items)
        return (fixture, items)
    }

    private func view(_ fixture: VirtualListFixture,
                      _ items: [VisibleRectRecordingItem],
                      _ index: Int) throws -> VisibleRectRecordingItemView {
        try XCTUnwrap(fixture.view(identity: items[index].identity) as? VisibleRectRecordingItemView)
    }

    func testFullyVisibleRowIsNotifiedItsWholeRect() throws {
        let (fixture, items) = makeFixture()
        let row = try view(fixture, items, 0)
        XCTAssertEqual(row.lastRect, CGRect(x: 0, y: 0, width: 390, height: rowHeight))
    }

    func testLoadedRowBelowTheViewportIsNotifiedNil() throws {
        let (fixture, items) = makeFixture()
        XCTAssertTrue(fixture.loadedIndices.contains(14), "row 14 must be loaded by the preload margin")
        let row = try view(fixture, items, 14)
        XCTAssertTrue(row.wasNotifiedNil, "a loaded but off-viewport row must be notified nil")
    }

    func testRowStraddlingTheBottomEdgeIsClippedAndItemLocal() throws {
        let (fixture, items) = makeFixture()
        // 780...840 clipped to 800 -> 20pt tall, expressed from the row's own origin.
        let row = try view(fixture, items, 13)
        XCTAssertEqual(row.lastRect, CGRect(x: 0, y: 0, width: 390, height: 20))
    }

    // Proves the `handleUserScroll` hook specifically: with the whole 16-row collection loaded
    // (960pt of content in an 800pt viewport), a small scroll cannot append, prepend or trim
    // anything — so no render() runs, and the only path left to report the new rects is the
    // scroll hook.
    func testScrollingUpdatesRectsWithoutAWindowChange() throws {
        let (fixture, items) = makeFixture(count: 16)
        let before = fixture.loadedIndices
        XCTAssertEqual(before, Array(0...15), "the whole collection must be loaded")

        fixture.scroll(to: fixture.boundsOriginY + 30)

        XCTAssertEqual(fixture.loadedIndices, before, "a 30pt scroll must not change the window")
        // Row 0 now has its top 30pt above the viewport; only its bottom half remains.
        let row = try view(fixture, items, 0)
        XCTAssertEqual(row.lastRect, CGRect(x: 0, y: 30, width: 390, height: 30))
    }

    func testRowLeavingTheLoadedWindowIsNotifiedNil() throws {
        let (fixture, items) = makeFixture()
        // Resolve the view BEFORE the scroll: once the row unloads it is no longer in the window,
        // and the local reference is also what keeps it alive past the weak notified-view table.
        let row = try view(fixture, items, 0)

        // handleUserScroll clamps a jump to one viewport height, so this lands at +800 and the
        // window moves to rows 10 and beyond.
        fixture.scroll(to: fixture.boundsOriginY + 2000)

        XCTAssertFalse(fixture.loadedIndices.contains(0), "row 0 must have left the window")
        XCTAssertTrue(row.wasNotifiedNil, "an unloaded row must be notified nil")
    }

    func testDepartingRowIsNotifiedNil() throws {
        let (fixture, items) = makeFixture()
        let row = try view(fixture, items, 0)
        XCTAssertEqual(row.lastRect, CGRect(x: 0, y: 0, width: 390, height: rowHeight))

        fixture.apply(Array(items.dropFirst()), duration: 0)

        XCTAssertTrue(row.wasNotifiedNil,
                      "a row transferred to the exit overlay must be notified nil so it stops playing")
    }
}
