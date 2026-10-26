import XCTest
import UIKit
@testable import CoreListDemo

final class ApplyChangesDuringFlightMutationTests: XCTestCase {
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

    private func items(_ ids: [Int]) -> [CoreListItem] {
        ids.map { Item(id: $0, height: 50) }
    }

    private func fixture(
        mode: TestScrollEngine.DecelerationMode,
        items source: [CoreListItem]? = nil
    ) -> PhysicsListFixture {
        PhysicsListFixture(
            items: source ?? items(Array(0..<200)),
            decelerationMode: mode
        )
    }

    private func startFlight(_ fixture: PhysicsListFixture) {
        fixture.simulateFlick(offsetVelocity: 4_000)
        fixture.tick(dt: 0.2)
        XCTAssertTrue(fixture.engine.isDecelerating, "flight must be active at mutation boundary")
    }

    func testPopulatedToEmptyHaltsMotionDeclaresZeroEdgesAndLetsExitsFinish() {
        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            let fixture = fixture(mode: mode)
            startFlight(fixture)

            fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 1))

            XCTAssertFalse(fixture.engine.isDecelerating, "\(mode) motion must halt on empty content")
            XCTAssertEqual(fixture.engine.declaredEdges.min, 0)
            XCTAssertEqual(fixture.engine.declaredEdges.max, 0)
            XCTAssertTrue(fixture.activeWindow.isEmpty)
            XCTAssertFalse(fixture.listView.exitOverlay.subviews.isEmpty)
            XCTAssertTrue(fixture.hasActiveAnimations, "exit opacity is independent of scroll motion")

            fixture.tick(dt: 0.5)
            XCTAssertFalse(fixture.listView.exitOverlay.subviews.isEmpty)
            fixture.tick(dt: 0.5)
            XCTAssertTrue(fixture.listView.exitOverlay.subviews.isEmpty)
        }
    }

    func testResizeInsertDeleteAndMixedPassesPreserveMotion() {
        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            do {
                let fixture = fixture(mode: mode)
                startFlight(fixture)
                fixture.listView.applyChanges(
                    newSize: CGSize(width: 390, height: 700),
                    transition: .easeInOut(duration: 0.3)
                )
                XCTAssertTrue(fixture.engine.isDecelerating, "\(mode) resize should preserve motion")
            }
            do {
                let source = items(Array(0..<200))
                let fixture = fixture(mode: mode, items: source)
                startFlight(fixture)
                var changed = source
                changed.insert(Item(id: 500, height: 50), at: 30)
                fixture.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0.3))
                XCTAssertTrue(fixture.engine.isDecelerating, "\(mode) insert should preserve motion")
            }
            do {
                let source = items(Array(0..<200))
                let fixture = fixture(mode: mode, items: source)
                startFlight(fixture)
                var changed = source
                changed.remove(at: 30)
                fixture.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0.3))
                XCTAssertTrue(fixture.engine.isDecelerating, "\(mode) delete should preserve motion")
            }
            do {
                let source = items(Array(0..<200))
                let fixture = fixture(mode: mode, items: source)
                startFlight(fixture)
                var changed = source
                changed.insert(Item(id: 500, height: 50), at: 30)
                changed.remove(at: 61)
                fixture.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0.3))
                XCTAssertTrue(fixture.engine.isDecelerating, "\(mode) mixed pass should preserve motion")
            }
        }
    }

    func testScrollToAndNoOverlapReplacementIntentionallyHaltMotion() {
        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            do {
                let fixture = fixture(mode: mode)
                startFlight(fixture)
                fixture.listView.applyChanges(
                    scrollTo: .init(index: 5, pointOffset: 0),
                    transition: .easeInOut(duration: 0.3)
                )
                XCTAssertFalse(fixture.engine.isDecelerating, "\(mode) scrollTo must halt motion")
                XCTAssertNotNil(fixture.animationController.model.track(
                    for: .viewport, property: .viewportOffset),
                    "scrollTo halts user momentum but starts independent programmatic motion")
            }
            do {
                let fixture = fixture(mode: mode)
                startFlight(fixture)
                fixture.listView.applyChanges(
                    items: items(Array(500..<700)),
                    transition: .easeInOut(duration: 0.3)
                )
                XCTAssertFalse(fixture.engine.isDecelerating, "\(mode) no-overlap replacement must halt motion")
            }
        }
    }

    func testDragAndPhysicsUseSettledStateDuringViewportTrack() throws {
        for mode in [TestScrollEngine.DecelerationMode.stepped, .keyframe] {
            let fixture = PhysicsListFixture(
                itemCount: 200, itemHeight: 50,
                viewport: CGSize(width: 390, height: 300),
                preloadMargin: 100, decelerationMode: mode)
            fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                          transition: .easeInOut(duration: 4))
            fixture.tick(dt: 1)
            let before = try XCTUnwrap(fixture.viewportTrack)
            fixture.beginDrag()
            fixture.drag(translation: -80, velocity: -2_000)
            _ = fixture.endDrag()
            fixture.tick(dt: 0.1)
            XCTAssertEqual(fixture.viewportTrack, before, "\(mode)")
            XCTAssertTrue(fixture.engine.isDecelerating, "\(mode)")
        }
    }
}
