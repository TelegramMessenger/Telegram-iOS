import XCTest
import UIKit
@testable import CoreListDemo

final class CarouselFadeSuppressionTests: XCTestCase {
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

    private func fullReplaceCarousel(_ fixture: VirtualListFixture,
                                     targetIndex: Int,
                                     duration: TimeInterval) {
        let replacement: [CoreListItem] = (1000..<1100).map { Item(id: $0) }
        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: targetIndex) { _, _ in 0 },
            transition: .easeInOut(duration: duration)
        )
    }

    func testCarouselIncomingRowsDoNotFade() throws {
        let fixture = makeFixture(ids: 0..<100)

        fullReplaceCarousel(fixture, targetIndex: 50, duration: 2)

        let incoming = try XCTUnwrap(fixture.activeWindow.items.first).index
        let identity = AnyHashable(1000 + incoming)
        XCTAssertNil(fixture.opacityTrack(identity: identity))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: identity)), 1, accuracy: 1e-9)
    }

    func testCarouselOutgoingGhostsHoldTheirOpacity() throws {
        let fixture = makeFixture(ids: 0..<100)

        fullReplaceCarousel(fixture, targetIndex: 50, duration: 2)

        XCTAssertFalse(fixture.ghostMemberViews.isEmpty)
        for view in fixture.ghostMemberViews {
            XCTAssertEqual(CGFloat(view.layer.opacity), 1, accuracy: 1e-6)
        }
        fixture.tick(dt: 1)
        for view in fixture.ghostMemberViews {
            XCTAssertEqual(CGFloat(view.layer.opacity), 1, accuracy: 1e-6)
        }
    }

    // Teardown must not have moved: the hold track carries the same deadline the fade did.
    func testCarouselGhostsAreStillTornDownOnTheSameDeadline() throws {
        let fixture = makeFixture(ids: 0..<100)

        fullReplaceCarousel(fixture, targetIndex: 50, duration: 2)
        XCTAssertFalse(fixture.ghostMemberViews.isEmpty)

        fixture.tick(dt: 2)

        XCTAssertTrue(fixture.ghostMemberViews.isEmpty)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
    }

    func testZeroDurationCarouselTearsDownImmediately() throws {
        let fixture = makeFixture(ids: 0..<100)

        fullReplaceCarousel(fixture, targetIndex: 50, duration: 0)

        XCTAssertTrue(fixture.ghostMemberViews.isEmpty)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
    }

    // The shape a real host produces. A chat's non-message rows carry CONSTANT identities — the
    // unread separator is `4 << 40`, chat-info `6 << 40` — so a wholesale history replace still
    // leaves one identity alive somewhere in the collection. Suppression must key off the
    // DESTINATION window, not the collection: a survivor parked far from where we are travelling to
    // says nothing about whether the incoming strip is new content.
    func testFullReplaceCarouselSuppressesDespiteASurvivorOutsideTheDestination() throws {
        let pinned = Item(id: 7777)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: [pinned] + (0..<100).map { Item(id: $0) },
            preloadMargin: 100
        )
        let replacement: [CoreListItem] = [pinned] + (1000..<1100).map { Item(id: $0) }

        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: 50) { _, _ in 0 },
            transition: .easeInOut(duration: 2)
        )

        XCTAssertFalse(fixture.loadedIndices.contains(0), "the survivor must be outside the destination window")
        let incoming = try XCTUnwrap(fixture.activeWindow.items.first).index
        let identity = AnyHashable(1000 + incoming - 1)
        XCTAssertNil(fixture.opacityTrack(identity: identity))
        for view in fixture.ghostMemberViews {
            XCTAssertEqual(CGFloat(view.layer.opacity), 1, accuracy: 1e-6)
        }
    }

    // The boundary: disjoint LOADED windows are not enough. A far jump within a collection that
    // mostly survives is a carousel too, and a genuinely new row landing in its destination is real
    // new content — it must still fade in. Only a wholesale collection replace suppresses.
    func testCarouselWithSurvivingCollectionStillFadesAGenuineInsert() throws {
        let fixture = makeFixture(ids: 0..<500)
        var items = fixture.listView.items
        items.insert(Item(id: 9999), at: 301)

        fixture.listView.applyChanges(items: items,
                                      scrollTo: .init(index: 300) { _, _ in 0 },
                                      transition: .easeInOut(duration: 2))

        XCTAssertTrue(fixture.loadedIndices.contains(301))
        XCTAssertNotNil(fixture.opacityTrack(identity: AnyHashable(9999)))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: AnyHashable(9999))),
                       0, accuracy: 1e-9)
    }

    // Suppression is scoped to the carousel. A scrollTo that still shares loaded rows is an ordinary
    // structural pass, and a genuinely new row in it must still fade in.
    func testOverlappingScrollStillFadesAGenuineInsert() throws {
        let fixture = makeFixture(ids: 0..<200)
        var items = fixture.listView.items
        items.insert(Item(id: 9999), at: 3)

        fixture.listView.applyChanges(items: items,
                                      scrollTo: .init(index: 2, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))

        XCTAssertNotNil(fixture.opacityTrack(identity: AnyHashable(9999)))
        XCTAssertEqual(try XCTUnwrap(fixture.opacity(identity: AnyHashable(9999))),
                       0, accuracy: 1e-9)
    }
}
