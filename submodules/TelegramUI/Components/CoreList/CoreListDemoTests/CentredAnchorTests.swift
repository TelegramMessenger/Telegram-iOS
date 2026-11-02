import XCTest
import UIKit
@testable import CoreListDemo

/// `CoreListAnchorMode.preserveCentredContent`: the row through the visible centre keeps its midpoint
/// across a pass that changes every row's height, in one pass, with no viewport track and no halt, while
/// the list's ends still clip. News's Compact ↔ Expanded morph is the client.
///
/// Every fixture is 390 × 800 with 100 pt insets at both ends, so the visible centre line is at 400. The
/// default one scrolls row 50 of a hundred 100 pt rows to 370...470: its midpoint is 20 below the line.
final class CentredAnchorTests: XCTestCase {
    private let insets = UIEdgeInsets(top: 100, left: 0, bottom: 100, right: 0)

    private func rows(_ ids: [UUID], height: CGFloat) -> [CoreListItem] {
        ids.map { ContentResizableItem(id: $0, contentHeight: height) }
    }

    /// 100 pt rows but row 50, which is `tallRowHeight`.
    private func rows(_ ids: [UUID], tallRowHeight: CGFloat) -> [CoreListItem] {
        ids.enumerated().map { index, id in
            ContentResizableItem(id: id, contentHeight: index == 50 ? tallRowHeight : 100)
        }
    }

    private func makeFixture(items: [CoreListItem],
                             scrollTo target: (index: Int, pointOffset: CGFloat)?) -> VirtualListFixture {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        fixture.listView.applyChanges(newInsets: insets, transition: .immediate)
        if let target {
            fixture.listView.applyChanges(
                scrollTo: CoreListScrollTarget(index: target.index, pointOffset: target.pointOffset),
                transition: .immediate)
        }
        return fixture
    }

    /// `count` rows of `height`; with `scrollTo` nil the list rests at its top, row 0 on the top inset.
    private func makeFixture(count: Int = 100,
                             height: CGFloat = 100,
                             scrollTo target: (index: Int, pointOffset: CGFloat)? = (50, 270))
        -> (fixture: VirtualListFixture, ids: [UUID]) {
        let ids = (0..<count).map { _ in UUID() }
        return (makeFixture(items: rows(ids, height: height), scrollTo: target), ids)
    }

    private func centredPass(_ fixture: VirtualListFixture, _ ids: [UUID], height: CGFloat,
                             transition: CoreListTransition = .immediate) {
        fixture.listView.applyChanges(items: rows(ids, height: height),
                                      anchorMode: .preserveCentredContent,
                                      transition: transition)
    }

    private func settledY(_ fixture: VirtualListFixture, _ id: UUID) throws -> CGFloat {
        try XCTUnwrap(fixture.settledScreenY(identity: id), "row \(id) is not loaded")
    }

    private func screenYs(_ fixture: VirtualListFixture) -> [Int: CGFloat] {
        var result: [Int: CGFloat] = [:]
        for index in fixture.loadedIndices {
            result[index] = fixture.screenY(forIndex: index)
        }
        return result
    }

    /// Asserts every row in `drawn` that is still loaded is drawn where it was, and that the comparison
    /// covered more than a handful of rows.
    private func assertStartsWhereDrawn(_ drawn: [Int: CGFloat], _ fixture: VirtualListFixture,
                                        file: StaticString = #filePath, line: UInt = #line) {
        var compared = 0
        for (index, y) in drawn {
            guard let now = fixture.screenY(forIndex: index) else { continue }
            XCTAssertEqual(now, y, accuracy: 1e-6, "row \(index) starts away from where it is drawn",
                           file: file, line: line)
            compared += 1
        }
        XCTAssertGreaterThan(compared, 5, "precondition: rows stay loaded across the pass",
                             file: file, line: line)
    }

    // MARK: - The midpoint

    func testTheRowThroughTheCentreKeepsItsMidpointWhenEveryRowGrows() throws {
        let (fixture, ids) = makeFixture()
        XCTAssertEqual(try settledY(fixture, ids[50]), 370, accuracy: 1e-6, "precondition")

        centredPass(fixture, ids, height: 200)

        XCTAssertEqual(try settledY(fixture, ids[50]), 320, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[49]), 120, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[51]), 520, accuracy: 1e-6)
    }

    func testTheRowThroughTheCentreKeepsItsMidpointWhenEveryRowShrinks() throws {
        let (fixture, ids) = makeFixture()

        centredPass(fixture, ids, height: 50)

        XCTAssertEqual(try settledY(fixture, ids[50]), 395, accuracy: 1e-6)
    }

    /// The row's position and height ride one curve on one clock, so its midpoint never moves, and the
    /// pass needs no viewport track to get there.
    func testTheMidpointHoldsThroughoutTheAnimationWithoutAViewportTrack() throws {
        let (fixture, ids) = makeFixture()

        centredPass(fixture, ids, height: 200, transition: .linear(duration: 0.5))

        XCTAssertNil(fixture.viewportTrack, "a centred pass moves no viewport")
        XCTAssertNotNil(fixture.positionTrack(identity: ids[50]), "precondition: the row moves")
        XCTAssertNotNil(fixture.heightTrack(identity: ids[50]), "precondition: the row grows")
        for step in 0...10 {
            if step > 0 {
                fixture.advance(by: 0.05)
            }
            let y = try XCTUnwrap(fixture.screenY(forIndex: 50))
            let height = try XCTUnwrap(fixture.visualHeight(identity: ids[50]))
            XCTAssertEqual(y + height * 0.5, 420, accuracy: 1e-6, "midpoint at step \(step)")
        }
    }

    func testEveryRowStartsWhereItWasDrawn() {
        let (fixture, ids) = makeFixture()
        let drawn = screenYs(fixture)

        centredPass(fixture, ids, height: 200, transition: .linear(duration: 0.5))

        assertStartsWhereDrawn(drawn, fixture)
    }

    // MARK: - The list's ends

    /// Rows of 200 from the top inset: row 1 at 300...500 crosses the line. Shrunk to 50 it keeps its
    /// midpoint, which would leave a gap above row 0; the top's underfill alignment closes it.
    func testAtTheLoadedTopAShrinkNeverOpensAGapAboveTheFirstRow() throws {
        let (fixture, ids) = makeFixture(height: 200, scrollTo: nil)
        XCTAssertEqual(try settledY(fixture, ids[1]), 300, accuracy: 1e-6, "precondition")

        centredPass(fixture, ids, height: 50)

        XCTAssertEqual(try settledY(fixture, ids[0]), 100, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[1]), 150, accuracy: 1e-6)
        XCTAssertEqual(fixture.boundsOriginY, try XCTUnwrap(fixture.declaredEdges.min), accuracy: 1e-6,
                       "the list rests on its top edge")
    }

    /// Rows of 50 from the top inset: row 6 at 400...450, its top on the line. Grown to 100 it keeps its
    /// midpoint, and the rows above it grow upward past the top. Row 0 stays loaded, at -225: the loaded
    /// top is not pinned, which would have put it back on the top inset.
    func testAtTheLoadedTopAGrowthKeepsTheCentredRowRatherThanTheTop() throws {
        let (fixture, ids) = makeFixture(height: 50, scrollTo: nil)
        XCTAssertEqual(try settledY(fixture, ids[6]), 400, accuracy: 1e-6, "precondition")

        centredPass(fixture, ids, height: 100)

        XCTAssertEqual(try settledY(fixture, ids[6]), 375, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[0]), -225, accuracy: 1e-6)
        let minimum = try XCTUnwrap(fixture.declaredEdges.min)
        XCTAssertEqual(fixture.boundsOriginY - minimum, 325, accuracy: 1e-6,
                       "the list rests 325 past its top edge")
    }

    func testAtTheOldestEdgeAShrinkRestsTheLastRowOnTheBottomInset() throws {
        let (fixture, ids) = makeFixture(scrollTo: (99, 500))
        XCTAssertEqual(try settledY(fixture, ids[99]), 600, accuracy: 1e-6, "precondition")

        centredPass(fixture, ids, height: 50)

        XCTAssertEqual(try settledY(fixture, ids[99]) + 50, 700, accuracy: 1e-6)
    }

    func testACollectionShorterThanTheViewportAlignsToTheTop() throws {
        let (fixture, ids) = makeFixture(count: 5, scrollTo: nil)

        centredPass(fixture, ids, height: 50)

        XCTAssertEqual(try settledY(fixture, ids[0]), 100, accuracy: 1e-6)
        XCTAssertEqual(try settledY(fixture, ids[4]), 300, accuracy: 1e-6)
    }

    // MARK: - The crossing clamp and the witness

    /// An 800 pt row at 380...1180 has its midpoint 380 below the line. Shrunk to 100 that distance would
    /// put it wholly below the line; it is clamped to still cross it, its top on the line.
    func testATallRowCrossedNearItsTopStillCrossesTheLineAfterShrinking() throws {
        let ids = (0..<100).map { _ in UUID() }
        let fixture = makeFixture(items: rows(ids, tallRowHeight: 800), scrollTo: (50, 280))
        XCTAssertEqual(try settledY(fixture, ids[50]), 380, accuracy: 1e-6, "precondition")

        fixture.listView.applyChanges(items: rows(ids, tallRowHeight: 100),
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]), 400, accuracy: 1e-6)
    }

    /// The mirror: an 800 pt row at -380...420 shrunk to 100 still crosses the line, by at most a point.
    func testATallRowCrossedNearItsBottomStillCrossesTheLineAfterShrinking() throws {
        let ids = (0..<100).map { _ in UUID() }
        let fixture = makeFixture(items: rows(ids, tallRowHeight: 800), scrollTo: (50, -480))
        XCTAssertEqual(try settledY(fixture, ids[50]), -380, accuracy: 1e-6, "precondition")

        fixture.listView.applyChanges(items: rows(ids, tallRowHeight: 100),
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        let maxY = try settledY(fixture, ids[50]) + 100
        XCTAssertGreaterThan(maxY, 400, "the row still crosses the line")
        XCTAssertLessThanOrEqual(maxY, 401)
    }

    /// Row 51 sat wholly below the line, so with row 50 gone it keeps its full midpoint distance, 120,
    /// unclamped.
    func testWhenTheWitnessIsDeletedTheNextSurvivorBelowKeepsItsDistance() throws {
        let (fixture, ids) = makeFixture()
        var remaining = ids
        remaining.remove(at: 50)

        fixture.listView.applyChanges(items: rows(remaining, height: 200),
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[51]), 420, accuracy: 1e-6)
    }

    // MARK: - Geometry and precedence

    /// A top inset 60 pt deeper moves the line, and the midpoint with it, by 30.
    func testAnInsetChangeInTheSamePassMovesTheLineByHalfOfIt() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      newInsets: UIEdgeInsets(top: 160, left: 0, bottom: 100, right: 0),
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]) + 100, 450, accuracy: 1e-6)
    }

    func testDecliningInsetCompensationKeepsTheOldLine() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      newInsets: UIEdgeInsets(top: 160, left: 0, bottom: 100, right: 0),
                                      anchorMode: .preserveCentredContent,
                                      compensatesInsetChange: false,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]) + 100, 420, accuracy: 1e-6)
    }

    func testAdditionalScrollDistanceMovesTheCentredRowByIt() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      additionalScrollDistance: 30,
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[50]), 350, accuracy: 1e-6)
    }

    func testAScrollToInTheSamePassWins() throws {
        let (fixture, ids) = makeFixture()

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      scrollTo: CoreListScrollTarget(index: 60, pointOffset: 0),
                                      anchorMode: .preserveCentredContent,
                                      transition: .immediate)

        XCTAssertEqual(try settledY(fixture, ids[60]), 100, accuracy: 1e-6)
    }

    /// A row held by its top at 270 below the top inset stays there; the centred anchor would have moved
    /// it to 320.
    func testAHeldRowWins() throws {
        let (fixture, ids) = makeFixture(scrollTo: nil)
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 50,
                                           hold: CoreListScrollHold(edge: .topInset) { _, _ in 0 },
                                           resolve: { _, _ in 270 }),
            transition: .immediate)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget, "precondition")

        centredPass(fixture, ids, height: 200)

        XCTAssertEqual(try settledY(fixture, ids[50]), 370, accuracy: 1e-6)
    }

    // MARK: - Reversal, attachments, momentum

    /// A switch flipped back mid-flight resolves the same row from the settled geometry, so it starts
    /// every row where it is drawn and lands every row where it started.
    func testAReversedSwitchStartsWhereItIsDrawnAndReturnsToTheOriginalLayout() throws {
        let (fixture, ids) = makeFixture()
        var original: [UUID: CGFloat] = [:]
        for index in fixture.loadedIndices {
            original[ids[index]] = try settledY(fixture, ids[index])
        }

        centredPass(fixture, ids, height: 200, transition: .linear(duration: 0.5))
        fixture.advance(by: 0.2)
        let drawn = screenYs(fixture)
        centredPass(fixture, ids, height: 100, transition: .linear(duration: 0.5))

        assertStartsWhereDrawn(drawn, fixture)
        var compared = 0
        for (id, y) in original {
            guard let now = fixture.settledScreenY(identity: id) else { continue }
            XCTAssertEqual(now, y, accuracy: 1e-6, "row \(id) does not return to where it started")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 5, "precondition: the original rows are loaded again")
    }

    /// A floating overlay attachment over rows 49...51 moves with them, from where it is drawn.
    func testAFloatingAttachmentOverTheCentredRowStartsWhereItIsDrawn() throws {
        let ids = (0..<100).map { _ in UUID() }
        func items(height: CGFloat) -> [CoreListItem] {
            ids.enumerated().map { index, id in
                ResizableAttachedItem(
                    id: id,
                    height: height,
                    attachedItems: (49...51).contains(index)
                        ? ["header": FixedHeightAttachment(label: "run", height: 30, placement: .overlay,
                                                           edge: .top, isFloating: true)]
                        : [:])
            }
        }
        let fixture = makeFixture(items: items(height: 100), scrollTo: (50, 270))
        let serial = try XCTUnwrap(fixture.activeWindow.attachments.first { $0.memberRange.contains(50) },
                                   "precondition: the run is loaded").serial
        func drawnY() throws -> CGFloat {
            let settled = try XCTUnwrap(fixture.listView.attachmentScreenY(serial: serial))
            let offset = fixture.animationController.positionOffset(
                owner: .attachment(serial), at: fixture.animationController.now()) ?? 0
            return settled + offset
        }
        let before = try drawnY()

        fixture.listView.applyChanges(items: items(height: 200),
                                      anchorMode: .preserveCentredContent,
                                      transition: .linear(duration: 0.5))

        XCTAssertNotNil(fixture.animationController.model.track(for: .attachment(serial),
                                                                property: .positionY),
                        "precondition: the attachment moves")
        XCTAssertEqual(try drawnY(), before, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.listView.attachmentScreenY(serial: serial)),
                       try settledY(fixture, ids[49]), accuracy: 1e-6,
                       "the attachment lands on its run's top")
    }

    func testAFlingCarriesOnThroughACentredPass() throws {
        let ids = (0..<200).map { _ in UUID() }
        let fixture = PhysicsListFixture(items: rows(ids, height: 100))
        fixture.simulateFlick(offsetVelocity: 2_000)
        fixture.tick(dt: 1.0 / 60)
        XCTAssertTrue(fixture.engine.isDecelerating, "precondition")

        fixture.listView.applyChanges(items: rows(ids, height: 200),
                                      anchorMode: .preserveCentredContent,
                                      transition: .linear(duration: 0.5))

        XCTAssertTrue(fixture.engine.isDecelerating, "a centred pass halts no fling")
        let probe = fixture.listView.items[fixture.loadedIndices[fixture.loadedIndices.count / 2]].identity
        let y = try XCTUnwrap(settledScreenY(fixture, probe))
        fixture.tick(dt: 1.0 / 60)
        XCTAssertLessThan(try XCTUnwrap(settledScreenY(fixture, probe)), y, "the fling keeps scrolling")
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

/// A row whose height changes through its item, publishing attachments.
private final class ResizableAttachedItem: CoreListItem {
    let id: UUID
    let height: CGFloat
    let attachedItems: [AnyHashable: CoreListAttachedItem]

    init(id: UUID, height: CGFloat, attachedItems: [AnyHashable: CoreListAttachedItem]) {
        self.id = id
        self.height = height
        self.attachedItems = attachedItems
    }

    var identity: AnyHashable { id }

    func view() -> UIView & CoreListItemView {
        let view = ContentResizableItemView()
        apply(to: view, transition: .immediate)
        return view
    }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? ResizableAttachedItem else { return false }
        return other.id == id && other.height == height
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? ContentResizableItemView)?.applyContent(height)
    }
}
