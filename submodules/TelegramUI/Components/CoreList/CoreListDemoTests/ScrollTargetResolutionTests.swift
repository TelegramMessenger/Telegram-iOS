import XCTest
import UIKit
@testable import CoreListDemo

final class ScrollTargetResolutionTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int
        let height: CGFloat

        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: height)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? Item)?.id == id
        }
    }

    private func makeFixture(itemCount: Int = 500,
                             itemHeight: CGFloat = 50,
                             viewportHeight: CGFloat = 300,
                             topInset: CGFloat = 0) -> VirtualListFixture {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: viewportHeight),
            items: (0..<itemCount).map { Item(id: $0, height: itemHeight) },
            preloadMargin: 100
        )
        if topInset != 0 {
            fixture.listView.applyChanges(
                newInsets: UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0),
                transition: .easeInOut(duration: 0)
            )
        }
        return fixture
    }

    // The resolver's return value means the same thing `pointOffset` meant: an offset from the top
    // inset edge. With a zero top inset that is the row's screen Y.
    func testResolverPlacesRowAtRequestedOffset() throws {
        let fixture = makeFixture()

        fixture.listView.applyChanges(scrollTo: .init(index: 200) { _, _ in 12 },
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(200))),
                       12, accuracy: 1e-9)
    }

    // The whole point of the resolver: bottom/center placements need the row's height, and only
    // CoreList has measured it by the time the anchor is placed.
    func testResolverReceivesMeasuredHeightExactlyOnce() throws {
        let fixture = makeFixture(itemHeight: 73)
        var observed: [CGFloat] = []

        fixture.listView.applyChanges(
            scrollTo: .init(index: 200) { height, _ in
                observed.append(height)
                return 0
            },
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(observed, [73])
    }

    func testResolverCanBottomAlignUsingMeasuredHeight() throws {
        let viewportHeight: CGFloat = 300
        let fixture = makeFixture(itemHeight: 73, viewportHeight: viewportHeight)

        fixture.listView.applyChanges(
            scrollTo: .init(index: 200) { height, _ in viewportHeight - height },
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(200))),
                       viewportHeight - 73, accuracy: 1e-9)
    }

    // The motivating case: the target is nowhere near the loaded window, so the host cannot measure
    // it and must delegate.
    func testFarUnloadedTargetResolvesAgainstItsOwnMeasuredHeight() throws {
        let fixture = makeFixture(itemCount: 1000, itemHeight: 50, viewportHeight: 300)
        XCTAssertFalse(fixture.loadedIndices.contains(800))

        fixture.listView.applyChanges(
            scrollTo: .init(index: 800) { height, _ in 150 - height / 2 },
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(800))),
                       125, accuracy: 1e-9)
    }

    func testResolvedOffsetIsRelativeToTheTopInset() throws {
        let fixture = makeFixture(topInset: 60)

        fixture.listView.applyChanges(scrollTo: .init(index: 200) { _, _ in 0 },
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(200))),
                       60, accuracy: 1e-9)
    }

    func testPointOffsetFormAndResolverFormAgree() throws {
        let byValue = makeFixture()
        let byResolver = makeFixture()

        byValue.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 40),
                                      transition: .easeInOut(duration: 0))
        byResolver.listView.applyChanges(scrollTo: .init(index: 120) { _, _ in 40 },
                                         transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(byValue.screenY(identity: AnyHashable(120))),
                       try XCTUnwrap(byResolver.screenY(identity: AnyHashable(120))),
                       accuracy: 1e-9)
    }

    // The `.visible`-already-visible shape: resolving to where the row already sits must not move it.
    func testResolvingToTheCurrentOffsetDoesNotMoveTheRow() throws {
        let fixture = makeFixture(itemCount: 200)
        fixture.listView.applyChanges(scrollTo: .init(index: 100, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))
        fixture.tick(dt: 2)
        let before = try XCTUnwrap(fixture.screenY(identity: AnyHashable(100)))

        fixture.listView.applyChanges(scrollTo: .init(index: 100) { _, _ in before },
                                      transition: .easeInOut(duration: 2))
        fixture.tick(dt: 2)

        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(100))),
                       before, accuracy: 1e-9)
    }
}
