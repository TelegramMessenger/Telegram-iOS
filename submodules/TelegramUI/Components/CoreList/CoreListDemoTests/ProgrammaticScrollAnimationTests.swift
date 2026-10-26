import XCTest
import UIKit
@testable import CoreListDemo

final class ProgrammaticScrollAnimationTests: XCTestCase {
    private final class ViewCounter {
        var views = 0
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
            counter.views += 1
            return FixedHeightItemView(height: 50)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? CountingItem)?.id == id
        }
    }

    private func fixedItem(id: Int, height: CGFloat = 50) -> CoreListItem {
        Item(id: id, height: height)
    }

    private func makeFixture(itemCount: Int,
                             viewportHeight: CGFloat,
                             preload: CGFloat) -> VirtualListFixture {
        VirtualListFixture(
            viewport: CGSize(width: 390, height: viewportHeight),
            items: (0..<itemCount).map { fixedItem(id: $0) },
            preloadMargin: preload)
    }

    private func makeCountingFixture(itemCount: Int,
                                     viewportHeight: CGFloat,
                                     preload: CGFloat) -> (VirtualListFixture, ViewCounter) {
        let counter = ViewCounter()
        let source: [CoreListItem] = (0..<itemCount).map {
            CountingItem(id: $0, counter: counter)
        }
        return (VirtualListFixture(
            viewport: CGSize(width: 390, height: viewportHeight),
            items: source,
            preloadMargin: preload), counter)
    }

    private func viewportCarryScreenYs(_ fixture: VirtualListFixture)
        -> [ObjectIdentifier: CGFloat] {
        return Dictionary(uniqueKeysWithValues: fixture.viewportCarryViews.map {
            (ObjectIdentifier($0), fixture.driver.viewportCarryScreenY(view: $0))
        })
    }

    private func loadedScreenBounds(_ fixture: VirtualListFixture) throws
        -> ClosedRange<CGFloat> {
        let frames = try fixture.activeWindow.items.map { item -> CGRect in
            let y = try XCTUnwrap(fixture.screenY(forIndex: item.index))
            return CGRect(x: 0, y: y,
                          width: item.frame.width, height: item.frame.height)
        }
        let minY = try XCTUnwrap(frames.map(\.minY).min())
        let maxY = try XCTUnwrap(frames.map(\.maxY).max())
        return minY...maxY
    }

    private func carryScreenBounds(_ fixture: VirtualListFixture) throws
        -> ClosedRange<CGFloat> {
        let tops = viewportCarryScreenYs(fixture)
        let frames = fixture.viewportCarryViews.compactMap { view -> CGRect? in
            guard let y = tops[ObjectIdentifier(view)] else { return nil }
            return CGRect(x: 0, y: y,
                          width: view.bounds.width, height: view.bounds.height)
        }
        let minY = try XCTUnwrap(frames.map(\.minY).min())
        let maxY = try XCTUnwrap(frames.map(\.maxY).max())
        return minY...maxY
    }

    func testMixedStructuralCarouselUsesOnePhysicalViewPerIdentity() {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        let expanded: [CoreListItem] = (1000..<1005).map { fixedItem(id: $0) }
            + (0..<100).map { fixedItem(id: $0) }

        fixture.listView.applyChanges(
            items: expanded,
            scrollTo: .init(index: 30, pointOffset: 0),
            transition: .easeInOut(duration: 2)
        )

        let allRendered = fixture.activeWindow.items.map { ObjectIdentifier($0.view) }
            + fixture.crossingCarryViews.map(ObjectIdentifier.init)
            + fixture.viewportCarryViews.map(ObjectIdentifier.init)
        XCTAssertEqual(Set(allRendered).count, allRendered.count)

        fixture.tick(dt: 2)
        XCTAssertTrue(fixture.crossingCarryViews.isEmpty)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
        XCTAssertLessThanOrEqual(
            fixture.animationController.model.ownerCount,
            fixture.activeWindow.items.count + 1
        )
    }

    func testOverlapScrollStartsAtExactOldPresentationAndSettlesAtTarget() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        let identity = AnyHashable(4)
        let before = try XCTUnwrap(fixture.screenY(identity: identity))
        let oldEngineOffset = fixture.boundsOriginY
        let currentViewportCorrection = fixture.viewportCorrection
        let oldReferenceY = try XCTUnwrap(fixture.settledContentY(identity: identity))

        fixture.listView.applyChanges(scrollTo: .init(index: 4, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))

        let track = try XCTUnwrap(fixture.viewportTrack)
        let newReferenceY = try XCTUnwrap(fixture.settledContentY(identity: identity))
        let coordinateShift = ViewportTransitionGeometry.coordinateShift(
            oldReferenceY: oldReferenceY,
            newReferenceY: newReferenceY
        )
        let expectedViewportFrom = ViewportTransitionGeometry.overlapViewportFrom(
            oldEngineOffset: oldEngineOffset,
            currentViewportCorrection: currentViewportCorrection,
            coordinateShift: coordinateShift,
            newEngineOffset: fixture.boundsOriginY
        )
        XCTAssertEqual(track.from, expectedViewportFrom, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                       before, accuracy: 1e-9)
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)
        fixture.tick(dt: 2)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                       0, accuracy: 1e-9)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }

    func testOverlapScrollPreservesExistingRowTrackWithoutDoubleCounting() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        var changed = fixture.listView.items
        changed.remove(at: 0)
        fixture.listView.applyChanges(items: changed, transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)
        let identity = AnyHashable(4)
        let rowTrack = try XCTUnwrap(fixture.positionTrack(identity: identity))
        let before = try XCTUnwrap(fixture.screenY(identity: identity))
        fixture.listView.applyChanges(scrollTo: .init(index: 3, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))
        XCTAssertEqual(fixture.positionTrack(identity: identity), rowTrack)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: identity)),
                       before, accuracy: 1e-9)
    }

    func testFarJumpUsesCarouselWithoutCreatingIntermediateRows() throws {
        let (fixture, counter) = makeCountingFixture(itemCount: 500,
                                                     viewportHeight: 300,
                                                     preload: 100)
        let createdBefore = counter.views

        fixture.listView.applyChanges(scrollTo: .init(index: 300, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))

        XCTAssertLessThanOrEqual(counter.views - createdBefore,
                                 fixture.activeWindow.items.count)
        XCTAssertLessThan(fixture.viewportCorrection, 0)
        XCTAssertEqual(fixture.viewportCarryViews.count, createdBefore)
        fixture.tick(dt: 2)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: AnyHashable(300))),
                       0, accuracy: 1e-9)
    }

    func testRepeatedFarJumpsKeepAnimationOwnerStorageWindowBoundedAfterEachCarryFinishes() throws {
        let clock = SyntheticClock()
        var viewportCompletions: [() -> Void] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { clock.now },
            durationFactor: { 1 },
            animationInstaller: { _, property, _, _, completion in
                if property == .viewportOffset {
                    viewportCompletions.append(completion)
                }
            }
        )
        let driver = VirtualListDriver(
            viewport: CGSize(width: 390, height: 300),
            items: (0..<500).map { self.fixedItem(id: $0) },
            preloadMargin: 100,
            clock: clock,
            animationController: controller
        )

        for target in [60, 120, 180, 240, 300, 360, 420] {
            driver.listView.applyChanges(scrollTo: .init(index: target, pointOffset: 0),
                                         transition: .easeInOut(duration: 1))
            XCTAssertFalse(driver.viewportCarryViews.isEmpty)
            XCTAssertEqual(viewportCompletions.count, 1)
            let completion = try XCTUnwrap(viewportCompletions.popLast())

            clock.advance(by: 1)
            completion()

            XCTAssertTrue(driver.viewportCarryViews.isEmpty)
            XCTAssertLessThanOrEqual(
                controller.model.ownerCount,
                driver.listView.activeWindow.items.count + 1,
                "settled carry owners must not accumulate across visited windows"
            )
        }
    }

    func testFarTopUsesBackwardCarousel() {
        let fixture = makeFixture(itemCount: 500, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 300, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))

        fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))

        XCTAssertGreaterThan(fixture.viewportCorrection, 0)
    }

    func testForwardCarouselWithTopInsetKeepsLoadedStripsAdjacent() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        XCTAssertNotEqual(fixture.activeWindow.minY, 0)

        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))

        var incoming = try loadedScreenBounds(fixture)
        var outgoing = try carryScreenBounds(fixture)
        XCTAssertEqual(incoming.lowerBound, outgoing.upperBound, accuracy: 1e-9)

        fixture.tick(dt: 1)
        incoming = try loadedScreenBounds(fixture)
        outgoing = try carryScreenBounds(fixture)
        XCTAssertEqual(incoming.lowerBound, outgoing.upperBound, accuracy: 1e-9)
    }

    func testSamePassInsetFarJumpKeepsDestinationCarouselRigid() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            scrollTo: .init(index: 40, pointOffset: 0),
            transition: .easeInOut(duration: 0.5)
        )

        XCTAssertNotNil(fixture.viewportTrack)
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)

        func assertRigidDestination(file: StaticString = #filePath,
                                    line: UInt = #line) throws {
            for item in fixture.activeWindow.items {
                let identity = fixture.listView.items[item.index].identity
                XCTAssertNil(fixture.positionTrack(identity: identity),
                             file: file, line: line)
            }
            for (first, second) in zip(
                fixture.activeWindow.items,
                fixture.activeWindow.items.dropFirst()
            ) {
                let firstY = try XCTUnwrap(fixture.screenY(forIndex: first.index),
                                           file: file, line: line)
                let secondY = try XCTUnwrap(fixture.screenY(forIndex: second.index),
                                            file: file, line: line)
                XCTAssertEqual(secondY, firstY + first.frame.height,
                               accuracy: 1e-9, file: file, line: line)
            }
            let incoming = try loadedScreenBounds(fixture)
            let outgoing = try carryScreenBounds(fixture)
            XCTAssertEqual(incoming.lowerBound, outgoing.upperBound,
                           accuracy: 1e-9, file: file, line: line)
        }

        try assertRigidDestination()
        fixture.tick(dt: 0.125)
        try assertRigidDestination()
        fixture.tick(dt: 0.125)
        try assertRigidDestination()

        fixture.tick(dt: 0.25)
        XCTAssertEqual(fixture.listView.viewportGeometry.insets.top, 300)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(forIndex: 40)),
                       300, accuracy: 1e-9)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }

    func testBackwardCarouselWithTopInsetKeepsLoadedStripsAdjacent() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        XCTAssertNotEqual(fixture.activeWindow.minY, 0)

        fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))

        var incoming = try loadedScreenBounds(fixture)
        var outgoing = try carryScreenBounds(fixture)
        XCTAssertEqual(incoming.upperBound, outgoing.lowerBound, accuracy: 1e-9)

        fixture.tick(dt: 1)
        incoming = try loadedScreenBounds(fixture)
        outgoing = try carryScreenBounds(fixture)
        XCTAssertEqual(incoming.upperBound, outgoing.lowerBound, accuracy: 1e-9)
    }

    func testCarouselDirectionFallsBackToNearestSurvivorWhenAnchorIsDeleted() {
        let fixture = makeFixture(itemCount: 500, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 300, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        var changed = fixture.listView.items
        let survivorAbove = changed[299]
        let survivorBelow = changed[301]
        changed.removeAll {
            [AnyHashable(299), AnyHashable(300), AnyHashable(301)].contains($0.identity)
        }
        changed.insert(survivorBelow, at: 100)
        changed.insert(survivorAbove, at: 400)

        fixture.listView.applyChanges(items: changed,
                                      scrollTo: .init(index: 200, pointOffset: 0),
                                      transition: .easeInOut(duration: 2))

        XCTAssertGreaterThan(fixture.viewportCorrection, 0)
    }

    func testCarouselComposesWithDiffResizeAndPointOffset() throws {
        let fixture = makeFixture(itemCount: 500, viewportHeight: 300, preload: 100)
        var changed = fixture.listView.items
        changed.remove(at: 50)
        changed.insert(fixedItem(id: 900, height: 70), at: 301)

        fixture.listView.applyChanges(
            items: changed,
            newSize: CGSize(width: 320, height: 360),
            scrollTo: .init(index: 300, pointOffset: 25),
            transition: .easeInOut(duration: 2)
        )

        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)
        XCTAssertNotNil(fixture.opacityTrack(identity: AnyHashable(900)))
        XCTAssertNil(fixture.positionTrack(identity: AnyHashable(900)))
        fixture.tick(dt: 2)
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(forIndex: 300)),
                       25, accuracy: 1e-9)
        XCTAssertEqual(fixture.listView.logicalSize, CGSize(width: 320, height: 360))
    }

    func testRetargetCarriesExistingStripsWithoutBoundaryJump() throws {
        let fixture = makeFixture(itemCount: 500, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 300, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)

        let beforeY = try XCTUnwrap(fixture.renderedY(identity: AnyHashable(300)))
        let oldCarryCount = fixture.viewportCarryViews.count
        fixture.listView.applyChanges(scrollTo: .init(index: 20, pointOffset: 0),
                                      transition: .easeInOut(duration: 3))

        XCTAssertNotNil(fixture.viewportTrack)
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: AnyHashable(300))),
                       beforeY, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(fixture.viewportCarryViews.count, oldCarryCount)
        fixture.tick(dt: 3)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }

    func testInsetChangeDuringCarouselPreservesEveryDetachedCarryBoundary() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .linear(duration: 4))
        fixture.tick(dt: 0.1)

        let destination = AnyHashable(40)
        let destinationBefore = try XCTUnwrap(fixture.renderedY(identity: destination))
        let carriesBefore = viewportCarryScreenYs(fixture)
        XCTAssertFalse(carriesBefore.isEmpty)

        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
            transition: .linear(duration: 2)
        )

        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: destination)),
                       destinationBefore, accuracy: 1e-9)
        let carriesAfter = viewportCarryScreenYs(fixture)
        XCTAssertEqual(Set(carriesAfter.keys), Set(carriesBefore.keys))
        for (view, beforeY) in carriesBefore {
            XCTAssertEqual(try XCTUnwrap(carriesAfter[view]), beforeY, accuracy: 1e-9)
        }
        let replacement = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertEqual(replacement.curve, .linear)
        XCTAssertEqual(replacement.duration, 2, accuracy: 1e-9)

        fixture.tick(dt: 2)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }

    func testOldDeadlineCannotClearReplacementTrackOrCarries() throws {
        let fixture = makeFixture(itemCount: 500, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 300, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)
        let firstGeneration = try XCTUnwrap(fixture.viewportTrack).generation

        fixture.listView.applyChanges(scrollTo: .init(index: 20, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        let replacement = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertNotEqual(replacement.generation, firstGeneration)
        fixture.tick(dt: 3)

        XCTAssertEqual(fixture.viewportTrack, replacement)
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)
    }

    func testDeleteAddLeavesExactViewportTrackUntouched() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)
        let before = try XCTUnwrap(fixture.viewportTrack)
        var changed = fixture.listView.items
        changed.remove(at: 0)
        changed.insert(fixedItem(id: 900), at: 0)
        fixture.listView.applyChanges(items: changed, transition: .easeInOut(duration: 2))
        XCTAssertEqual(fixture.viewportTrack, before)
    }

    func testUserDragChangesSettledStateWithoutTouchingViewportTrack() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)
        let before = try XCTUnwrap(fixture.viewportTrack)
        let logicalBefore = fixture.boundsOriginY
        fixture.simulateDrag(by: 40)
        XCTAssertEqual(fixture.viewportTrack, before)
        XCTAssertNotEqual(fixture.boundsOriginY, logicalBefore)
    }

    func testSameTargetIsExactNoOpAndZeroDurationSettlesImmediately() throws {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        fixture.tick(dt: 1)
        let before = try XCTUnwrap(fixture.viewportTrack)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 9))
        XCTAssertEqual(fixture.viewportTrack, before)

        fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        XCTAssertNil(fixture.viewportTrack)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }

    func testViewportReplacementMigratesCrossingReleaseGeneration() {
        var scenario = MixedPassScenario(seed: 1, itemCount: 120)
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: scenario.makeInitialItems(),
            preloadMargin: 160
        )
        let prefix = (0...12).map { _ in scenario.nextStep() }
        let settledBase = prefix[12]
        fixture.listView.frame.size = settledBase.size
        fixture.listView.applyChanges(
            items: settledBase.items.map { $0 as CoreListItem },
            newSize: settledBase.size,
            newInsets: settledBase.insets,
            scrollTo: settledBase.scrollTo,
            transition: .easeInOut(duration: 0)
        )
        let insetStep = scenario.nextStep()
        fixture.listView.applyChanges(
            newInsets: insetStep.insets,
            transition: insetStep.transition
        )
        XCTAssertFalse(fixture.crossingCarryIdentities.isEmpty)
        fixture.tick(dt: insetStep.advanceAfter)

        let replacement = scenario.nextStep()
        fixture.listView.applyChanges(
            scrollTo: replacement.scrollTo,
            transition: replacement.transition
        )
        fixture.tick(dt: replacement.transition.duration)

        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }

    func testRebuildClearsViewportTrackAndCarries() {
        let fixture = makeFixture(itemCount: 100, viewportHeight: 300, preload: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 4))
        XCTAssertFalse(fixture.viewportCarryViews.isEmpty)
        fixture.listView.items = (0..<20).map { fixedItem(id: 1_000 + $0) }
        XCTAssertNil(fixture.viewportTrack)
        XCTAssertTrue(fixture.viewportCarryViews.isEmpty)
    }
}
