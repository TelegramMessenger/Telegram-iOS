import XCTest
import UIKit
@testable import CoreListDemo

/// `CoreListAnchorMode.preserveItem`: the named row keeps its top's distance from the top inset edge
/// across a pass that changes its height and its neighbours', never above the edge, while the list's ends
/// still clip. News's per-row Expand / Collapse swipe is the client: the post the user swiped stays where
/// it was swiped.
///
/// Every fixture is 390 × 800 with 100 pt insets at both ends. The default one scrolls row 50 of a
/// hundred 100 pt rows to 370...470.
final class PreservedItemAnchorTests: XCTestCase {
    private let insets = UIEdgeInsets(top: 100, left: 0, bottom: 100, right: 0)

    private func rows(_ ids: [UUID], height: CGFloat) -> [CoreListItem] {
        ids.map { ContentResizableItem(id: $0, contentHeight: height) }
    }

    /// `count` rows of `height`; with `scrollTo` nil the list rests at its top, row 0 on the top inset.
    private func makeFixture(count: Int = 100,
                             height: CGFloat = 100,
                             scrollTo target: (index: Int, pointOffset: CGFloat)? = (50, 270))
        -> (fixture: VirtualListFixture, ids: [UUID]) {
        let ids = (0..<count).map { _ in UUID() }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: rows(ids, height: height))
        fixture.listView.applyChanges(newInsets: insets, transition: .immediate)
        if let target {
            fixture.listView.applyChanges(
                scrollTo: CoreListScrollTarget(index: target.index, pointOffset: target.pointOffset),
                transition: .immediate)
        }
        return (fixture, ids)
    }

    private func settledY(_ fixture: VirtualListFixture, _ id: UUID) throws -> CGFloat {
        try XCTUnwrap(fixture.settledScreenY(identity: id), "row \(id) is not loaded")
    }

    /// Every loaded row's settled screen Y, by index.
    private func settledYs(_ fixture: VirtualListFixture) -> [Int: CGFloat] {
        var result: [Int: CGFloat] = [:]
        for index in fixture.loadedIndices {
            result[index] = fixture.settledScreenY(identity: fixture.listView.items[index].identity)
        }
        return result
    }

    // MARK: - The row's top

    func testTheRowKeepsItsTopWhenEveryRowGrows() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      anchorMode: .preserveItem(ids[50]),
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]), 370, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[49]), 170, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[51]), 570, accuracy: 1e-6)
    }

    func testTheRowKeepsItsTopWhenEveryRowShrinks() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 50),
                                      anchorMode: .preserveItem(ids[50]),
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]), 370, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[49]), 320, accuracy: 1e-6)
    }

    /// The swipe's own shape: only the row changes, collapsing while scrolled partly under the top inset
    /// edge (60...160). It lands on the edge, wholly in view, instead of keeping its top 40 pt under it.
    func testARowPartlyUnderTheTopInsetLandsOnTheEdge() throws {
        let (fixture, ids) = makeFixture(scrollTo: (50, -40))
        XCTAssertEqual(try settledY(fixture, ids[50]), 60, accuracy: 1e-6, "precondition")
        let items: [CoreListItem] = ids.enumerated().map {
            ContentResizableItem(id: $1, contentHeight: $0 == 50 ? 50 : 100)
        }

        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveItem(ids[50]),
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]), 100, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[51]), 150, accuracy: 1e-6)
    }

    // MARK: - The fallback

    /// A row the old window did not load (row 0 of a list scrolled to row 50), a loaded row wholly above
    /// the top inset edge (row 45, at -130...-30 in the preload band), a row leaving in the same pass, and
    /// an identity the list never had each make the pass exactly a `.preserveVisibleContent` one. The pass grows every row, so a fallback that kept the named row, or the `.automatic` anchor,
    /// would land elsewhere.
    func testAnIdentityThatCannotBePreservedFallsBackToPreserveVisibleContent() throws {
        func layout(removing removed: Int?,
                    anchorMode: (_ ids: [UUID]) -> CoreListAnchorMode) -> [Int: CGFloat] {
            let (fixture, ids) = makeFixture()
            var remaining = ids
            if let removed {
                remaining.remove(at: removed)
            }
            fixture.listView.applyChanges(items: rows(remaining, height: 200),
                                          anchorMode: anchorMode(ids),
                                          transition: .immediate)
            return settledYs(fixture)
        }

        let preserved = layout(removing: nil) { _ in .preserveVisibleContent }
        XCTAssertNotEqual(preserved, layout(removing: nil) { ids in .preserveItem(ids[50]) },
                          "precondition: keeping row 50 lands elsewhere")
        XCTAssertNotEqual(preserved, layout(removing: nil) { _ in .automatic },
                          "precondition: the automatic anchor lands elsewhere")
        XCTAssertEqual(layout(removing: nil) { ids in .preserveItem(ids[0]) }, preserved,
                       "a row the old window did not load")
        do {
            let (fixture, ids) = makeFixture()
            XCTAssertTrue(fixture.loadedIndices.contains(45), "precondition: row 45 is loaded")
            XCTAssertLessThanOrEqual(try settledY(fixture, ids[45]) + 100, insets.top, "precondition: wholly above the edge")
        }
        XCTAssertEqual(layout(removing: nil) { ids in .preserveItem(ids[45]) }, preserved,
                       "a loaded row wholly above the top inset edge")
        XCTAssertEqual(layout(removing: nil) { _ in .preserveItem(AnyHashable("missing")) }, preserved,
                       "an identity the list never had")
        XCTAssertEqual(layout(removing: 50) { ids in .preserveItem(ids[50]) },
                       layout(removing: 50) { _ in .preserveVisibleContent },
                       "a row leaving in the same pass")
    }

    // MARK: - The list's ends

    /// At the list's top, rows shrinking above the named row would leave a gap above row 0 if the row
    /// kept its top; the top's underfill alignment closes it.
    func testAShrinkNearTheTopLeavesNoGapAboveTheFirstRow() throws {
        let (fixture, ids) = makeFixture(scrollTo: nil)
        XCTAssertEqual(try settledY(fixture, ids[2]), 300, accuracy: 1e-6, "precondition")

        fixture.listView.applyChanges(items: rows(ids, height: 50),
                                      anchorMode: .preserveItem(ids[2]),
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[0]), 100, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[2]), 200, accuracy: 1e-6)
        XCTAssertEqual(fixture.boundsOriginY, try XCTUnwrap(fixture.declaredEdges.min), accuracy: 1e-6,
                       "the list rests on its top edge")
    }

    /// At the list's top a growing row keeps its top too: the loaded top is not pinned, so the rows above
    /// it grow upward past the edge.
    func testAtTheLoadedTopAGrowthKeepsTheRowRatherThanTheTop() throws {
        let (fixture, ids) = makeFixture(scrollTo: nil)

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      anchorMode: .preserveItem(ids[2]),
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[2]), 300, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[0]), -100, accuracy: 1e-6)
    }

    // MARK: - Continuity, geometry, momentum

    func testEveryRowStartsWhereItWasDrawn() {
        let (fixture, ids) = makeFixture()
        var drawn: [Int: CGFloat] = [:]
        for index in fixture.loadedIndices {
            drawn[index] = fixture.screenY(forIndex: index)
        }

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      anchorMode: .preserveItem(ids[50]),
                                      transition: .linear(duration: 0.5))

        XCTAssertNil(fixture.viewportTrack, "the pass moves no viewport")
        XCTAssertNotNil(fixture.positionTrack(identity: ids[51]), "precondition: the rows below move")
        var compared = 0
        for (index, y) in drawn {
            guard let now = fixture.screenY(forIndex: index) else { continue }
            XCTAssertEqual(now, y, accuracy: 1e-6, "row \(index) starts away from where it is drawn")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 5, "precondition: rows stay loaded across the pass")
    }

    /// An inset change in the same pass carries the row with the top inset edge, as it carries
    /// `.preserveVisibleContent`'s witness; declining the compensation keeps it where it is on screen.
    func testAnInsetChangeCarriesTheRowWithTheEdge() throws {
        let deeper = UIEdgeInsets(top: 160, left: 0, bottom: 100, right: 0)
        let (compensated, compensatedIDs) = makeFixture()
        compensated.listView.applyChanges(items: rows(compensatedIDs, height: 200),
                                          newInsets: deeper,
                                          anchorMode: .preserveItem(compensatedIDs[50]),
                                          transition: .immediate)
        XCTAssertEqual(try settledY(compensated, compensatedIDs[50]), 430, accuracy: 1e-6)

        let (uncompensated, uncompensatedIDs) = makeFixture()
        uncompensated.listView.applyChanges(items: rows(uncompensatedIDs, height: 200),
                                            newInsets: deeper,
                                            anchorMode: .preserveItem(uncompensatedIDs[50]),
                                            compensatesInsetChange: false,
                                            transition: .immediate)
        XCTAssertEqual(try settledY(uncompensated, uncompensatedIDs[50]), 370, accuracy: 1e-6)
    }

    func testAFlingCarriesOnThroughThePass() throws {
        let ids = (0..<200).map { _ in UUID() }
        let fixture = PhysicsListFixture(items: rows(ids, height: 100))
        fixture.simulateFlick(offsetVelocity: 2_000)
        fixture.tick(dt: 1.0 / 60)
        XCTAssertTrue(fixture.engine.isDecelerating, "precondition")
        let named = fixture.listView.items[fixture.loadedIndices[fixture.loadedIndices.count / 2]].identity

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      anchorMode: .preserveItem(named),
                                      transition: .linear(duration: 0.5))

        XCTAssertTrue(fixture.engine.isDecelerating, "the pass halts no fling")
        let y = try XCTUnwrap(settledScreenY(fixture, named))
        fixture.tick(dt: 1.0 / 60)
        XCTAssertLessThan(try XCTUnwrap(settledScreenY(fixture, named)), y, "the fling keeps scrolling")
    }

    /// A physics fixture's row in settled screen space. The engine's offset alone is no measure of motion:
    /// a rebalance re-bases it, and the container with it.
    private func settledScreenY(_ fixture: PhysicsListFixture, _ identity: AnyHashable) -> CGFloat? {
        guard let item = fixture.activeWindow.items.first(where: {
            fixture.listView.items[$0.index].identity == identity
        }) else { return nil }
        return fixture.listView.container.frame.origin.y + item.frame.minY - fixture.activeWindow.minY
            - fixture.offset
    }
}
