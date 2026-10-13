import XCTest
import UIKit
@testable import CoreListDemo

final class CarouselTravelDirectionTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) {
            self.id = id
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: 50)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? Item)?.id == id
        }
    }

    private func makeFixture(ids: Range<Int>) -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: ids.map { Item(id: $0) },
                           preloadMargin: 100)
    }

    // A full replace leaves no surviving identity, so index comparison has nothing to compare and
    // the transition falls back. This is the shape a chat history jump takes.
    func testFullReplaceCarouselTravelsBackwardWhenAsked() throws {
        let fixture = makeFixture(ids: 0..<100)
        let replacement: [CoreListItem] = (1000..<1100).map { Item(id: $0) }

        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: 50, direction: .backward) { _, _ in 0 },
            transition: .easeInOut(duration: 2)
        )

        XCTAssertGreaterThan(try XCTUnwrap(fixture.viewportTrack).from, 0)
    }

    func testFullReplaceCarouselDefaultsToForward() throws {
        let fixture = makeFixture(ids: 0..<100)
        let replacement: [CoreListItem] = (1000..<1100).map { Item(id: $0) }

        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: 50) { _, _ in 0 },
            transition: .easeInOut(duration: 2)
        )

        XCTAssertLessThan(try XCTUnwrap(fixture.viewportTrack).from, 0)
    }

    // A surviving witness is ground truth; the hint is a fallback, never an override. Mirrors
    // ListViewImpl, which consults directionHint only at `if offset == nil`.
    func testSurvivingAnchorOutranksAContradictoryHint() throws {
        let fixture = makeFixture(ids: 0..<500)

        fixture.listView.applyChanges(
            scrollTo: .init(index: 300, direction: .backward) { _, _ in 0 },
            transition: .easeInOut(duration: 2)
        )

        XCTAssertLessThan(try XCTUnwrap(fixture.viewportTrack).from, 0)
    }
}
