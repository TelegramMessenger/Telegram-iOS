import XCTest
import UIKit
@testable import CoreListDemo

final class InfiniteLoadingAnchorTests: XCTestCase {
    private final class ViewCounter {
        var count = 0
    }

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

    private final class CountingItem: CoreListItem {
        let id: Int
        let counter: ViewCounter

        var identity: AnyHashable { id }

        init(id: Int, counter: ViewCounter) {
            self.id = id
            self.counter = counter
        }

        func view() -> UIView & CoreListItemView {
            counter.count += 1
            return FixedHeightItemView(height: 50)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? CountingItem)?.id == id
        }
    }

    private func items<S: Sequence>(_ ids: S,
                                    height: CGFloat = 50) -> [CoreListItem]
    where S.Element == Int {
        ids.map { Item(id: $0, height: height) }
    }

    private func makeAnchoredFixture(
        emitsCA: Bool = false
    ) throws -> (fixture: VirtualListFixture, source: [CoreListItem]) {
        let source = items(0..<100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100,
            emitsCA: emitsCA
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 20, pointOffset: -20),
            transition: .easeInOut(duration: 0)
        )
        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 20)),
            40,
            accuracy: 1e-6
        )
        return (fixture, source)
    }

    func testPreserveVisibleContentPrependsAboveMidListWitness() throws {
        let context = try makeAnchoredFixture()
        let changed = items(-5..<0) + context.source

        context.fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(context.fixture.settledScreenY(identity: 20)),
            40,
            accuracy: 1e-6
        )
        XCTAssertEqual(context.fixture.listView.items[25].identity, AnyHashable(20))
    }

    func testPreserveVisibleContentPrependsAboveLoadedTopWitness() throws {
        let source = items(0..<100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 0)),
            60,
            accuracy: 1e-6
        )

        fixture.listView.applyChanges(
            items: items(-5..<0) + source,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 0)),
            60,
            accuracy: 1e-6
        )
        XCTAssertEqual(fixture.listView.items[5].identity, AnyHashable(0))
    }

    func testAutomaticModeKeepsFiniteListTopPinning() throws {
        let source = items(0..<100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )

        fixture.listView.applyChanges(
            items: items([-1]) + source,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: -1)),
            60,
            accuracy: 1e-6
        )
        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 0)),
            110,
            accuracy: 1e-6
        )
    }

    func testRemovedWitnessPreservesNearestLoadedSurvivorBelowAtItsOwnPosition() throws {
        let context = try makeAnchoredFixture()
        let oldBelowY = try XCTUnwrap(context.fixture.settledScreenY(identity: 21))
        let changed = context.source.filter { $0.identity != AnyHashable(20) }

        context.fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(context.fixture.settledScreenY(identity: 21)),
            oldBelowY,
            accuracy: 1e-6
        )
    }

    func testRemovedTailWitnessFallsBackAboveThenClampsToBottomEdge() throws {
        let context = try makeAnchoredFixture()
        let changed = Array(context.source.prefix(20))

        context.fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        let lastY = try XCTUnwrap(context.fixture.settledScreenY(identity: 19))
        XCTAssertEqual(lastY + 50, 300, accuracy: 1e-6)
        XCTAssertEqual(context.fixture.activeWindow.endIndex, changed.count - 1)
    }

    func testRemovedLoadedTopWitnessClampsFallbackToTopInset() throws {
        let source = items(0..<100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )

        fixture.listView.applyChanges(
            items: Array(source.dropFirst()),
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 1)),
            60,
            accuracy: 1e-6
        )
    }

    func testMovedWitnessRetainsItsOwnInsetRelativePosition() throws {
        let context = try makeAnchoredFixture()
        var changed = context.source
        let moved = changed.remove(at: 20)
        changed.insert(moved, at: 25)

        context.fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(context.fixture.settledScreenY(identity: 20)),
            40,
            accuracy: 1e-6
        )
    }

    func testPreservedDistanceMovesWithChangedTopInset() throws {
        let context = try makeAnchoredFixture()
        let changed = items(-5..<0) + context.source

        context.fixture.listView.applyChanges(
            items: changed,
            newInsets: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0),
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(context.fixture.settledScreenY(identity: 20)),
            80,
            accuracy: 1e-6
        )
    }

    func testScrollToOverridesPreserveVisibleContent() throws {
        let context = try makeAnchoredFixture()
        let changed = items(-5..<0) + context.source

        context.fixture.listView.applyChanges(
            items: changed,
            scrollTo: .init(index: 40, pointOffset: 0),
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        let targetIdentity = changed[40].identity
        XCTAssertEqual(
            try XCTUnwrap(context.fixture.settledScreenY(identity: targetIdentity)),
            60,
            accuracy: 1e-6
        )
    }

    func testFullIdentityReplacementFallsBackToAutomaticResolution() throws {
        let preserved = try makeAnchoredFixture().fixture
        let automatic = try makeAnchoredFixture().fixture
        let replacement = items(1_000..<1_100)

        preserved.listView.applyChanges(
            items: replacement,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )
        automatic.listView.applyChanges(
            items: replacement,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            preserved.activeWindow.items.map(\.index),
            automatic.activeWindow.items.map(\.index)
        )
        XCTAssertEqual(preserved.boundsOriginY, automatic.boundsOriginY, accuracy: 1e-6)
        XCTAssertEqual(
            try XCTUnwrap(preserved.settledScreenY(identity: 1_000)),
            try XCTUnwrap(automatic.settledScreenY(identity: 1_000)),
            accuracy: 1e-6
        )
    }

    func testMixedPrependResizeMoveAndReplacementPreservesWitness() throws {
        let ids = (0..<100).map { _ in UUID() }
        let source: [CoreListItem] = ids.map {
            ContentResizableItem(id: $0, contentHeight: 50)
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 20, pointOffset: -20),
            transition: .easeInOut(duration: 0)
        )
        let witness = ids[20]
        var changed: [CoreListItem] = (0..<5).map { _ in
            ContentResizableItem(id: UUID(), contentHeight: 50)
        } + source
        changed[24] = ContentResizableItem(id: ids[19], contentHeight: 100)
        changed.swapAt(35, 36)
        changed[45] = ContentResizableItem(id: UUID(), contentHeight: 75)

        fixture.listView.applyChanges(
            items: changed,
            newSize: CGSize(width: 390, height: 320),
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: witness)),
            40,
            accuracy: 1e-6
        )
    }

    func testMissingLoadedFallbackDoesNotMeasureTowardOffscreenSurvivor() {
        let counter = ViewCounter()
        let source: [CoreListItem] = (0..<200).map {
            CountingItem(id: $0, counter: counter)
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100
        )
        fixture.listView.applyChanges(
            scrollTo: .init(index: 40, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        let oldLoadedIDs = Set(fixture.activeWindow.items.map {
            fixture.listView.items[$0.index].identity
        })
        let oldViews = Set(fixture.activeWindow.items.map {
            ObjectIdentifier($0.view)
        })
        let before = counter.count
        let changed = source.filter { !oldLoadedIDs.contains($0.identity) }

        fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )

        let newlyLoaded = fixture.activeWindow.items.filter {
            !oldViews.contains(ObjectIdentifier($0.view))
        }.count
        XCTAssertEqual(counter.count - before, newlyLoaded)
        XCTAssertEqual(
            fixture.loadedIndices,
            Array(fixture.activeWindow.startIndex...fixture.activeWindow.endIndex)
        )
    }

    func testTimedPrependKeepsWitnessContinuousAndUsesNormalInsertAnimation() throws {
        let source = items(0..<100)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: source,
            preloadMargin: 100,
            emitsCA: true
        )
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        let beforeRendered = try XCTUnwrap(fixture.renderedY(identity: 0))
        let changed = items(-5..<0) + source

        fixture.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 4)
        )

        XCTAssertEqual(
            try XCTUnwrap(fixture.renderedY(identity: 0)),
            beforeRendered,
            accuracy: 1e-5
        )
        XCTAssertEqual(
            try XCTUnwrap(fixture.settledScreenY(identity: 0)),
            60,
            accuracy: 1e-6
        )
        let insertedTrack = try XCTUnwrap(fixture.opacityTrack(identity: -1))
        XCTAssertEqual(insertedTrack.duration, 4, accuracy: 1e-9)
        XCTAssertEqual(insertedTrack.curve, .easeInOut)
        let insertedView = try XCTUnwrap(fixture.view(identity: -1))
        XCTAssertNotNil(insertedView.layer.animation(
            forKey: fixture.animationController.compiler.animationKey(for: .opacity)
        ))

        _ = fixture.runUntilSettled()
        XCTAssertFalse(fixture.hasActiveAnimations)
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
    }

    func testOverlappingPreservedPrependKeepsUnchangedWitnessTrackExact() throws {
        let context = try makeAnchoredFixture()
        var first = context.source
        first.insert(Item(id: 500, height: 50), at: 21)
        context.fixture.listView.applyChanges(
            items: first,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 4)
        )
        context.fixture.advance(by: 1)
        let beforeTrack = try XCTUnwrap(context.fixture.positionTrack(identity: 22))
        let beforeRendered = try XCTUnwrap(context.fixture.renderedY(identity: 22))

        let second = items(-5..<0) + first
        context.fixture.listView.applyChanges(
            items: second,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 3)
        )

        XCTAssertEqual(
            try XCTUnwrap(context.fixture.renderedY(identity: 22)),
            beforeRendered,
            accuracy: 1e-5
        )
        XCTAssertEqual(context.fixture.positionTrack(identity: 22), beforeTrack)

        _ = context.fixture.runUntilSettled()
        XCTAssertFalse(context.fixture.hasActiveAnimations)
        XCTAssertTrue(context.fixture.crossingCarryIdentities.isEmpty)
        XCTAssertTrue(context.fixture.viewportCarryViews.isEmpty)
        XCTAssertTrue(context.fixture.ghostBlocks.isEmpty)
    }

    func testPreservedAnchorSettlesIdenticallyAcrossScrollEngines() throws {
        let source = items(0..<100)
        let changed = items(-5..<0) + source

        let uikit = try makeAnchoredFixture().fixture
        uikit.listView.applyChanges(
            items: changed,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )
        let expected = try XCTUnwrap(uikit.settledScreenY(identity: 20))

        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            let fixture = PhysicsListFixture(
                viewport: CGSize(width: 390, height: 300),
                items: source,
                preloadMargin: 100,
                decelerationMode: mode
            )
            fixture.listView.applyChanges(
                newInsets: UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0),
                transition: .easeInOut(duration: 0)
            )
            fixture.listView.applyChanges(
                scrollTo: .init(index: 20, pointOffset: -20),
                transition: .easeInOut(duration: 0)
            )
            fixture.listView.applyChanges(
                items: changed,
                anchorMode: .preserveVisibleContent,
                transition: .easeInOut(duration: 0)
            )
            let item = try XCTUnwrap(fixture.activeWindow.items.first {
                fixture.listView.items[$0.index].identity == AnyHashable(20)
            })
            let y = fixture.containerOriginY + item.frame.minY
                - fixture.activeWindow.minY - fixture.offset
            XCTAssertEqual(y, expected, accuracy: 1e-6, "\(mode)")
        }
    }

    func testPreservedMutationDoesNotCancelPhysicsDeceleration() {
        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            let source = items(0..<200)
            let fixture = PhysicsListFixture(
                items: source,
                decelerationMode: mode
            )
            fixture.simulateFlick(offsetVelocity: 4_000)
            fixture.tick(dt: 0.2)
            XCTAssertTrue(fixture.engine.isDecelerating)

            fixture.listView.applyChanges(
                items: items(-5..<0) + source,
                anchorMode: .preserveVisibleContent,
                transition: .easeInOut(duration: 0.3)
            )

            XCTAssertTrue(fixture.engine.isDecelerating, "\(mode)")
        }
    }
}
