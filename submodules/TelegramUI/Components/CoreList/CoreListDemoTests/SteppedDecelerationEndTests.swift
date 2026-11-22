import XCTest
import UIKit
@testable import CoreListDemo

/// A `.stepped` deceleration (what the News feeds embed) publishes no flight, so `didEndScrolling` — which a
/// `.keyframe` flight ends with — never fired for it, and `isScrollFlightActive` read false through the whole
/// fling. A host deciding at finger-up whether momentum follows, and acting again when it ends (News snaps its
/// half-hidden search there), had no way to tell: snapping at every release halted every fling near the top.
final class SteppedDecelerationEndTests: XCTestCase {
    func test_aSteppedFlickIsDeceleratingAtReleaseAndReportsItsEnd() {
        let fixture = PhysicsListFixture(itemCount: 300, decelerationMode: .stepped)
        var ended = 0
        var deceleratingAtRelease: Bool?
        fixture.listView.didEndDragging = { [weak fixture] in
            deceleratingAtRelease = fixture?.listView.isScrollDecelerating
        }
        fixture.listView.didEndScrolling = {
            ended += 1
        }

        fixture.engine.simulateFlick(offsetVelocity: 3000)
        XCTAssertEqual(deceleratingAtRelease, true, "the release launches momentum and says so")
        XCTAssertEqual(ended, 0)

        _ = fixture.driver.runUntilSettled()
        XCTAssertFalse(fixture.listView.isScrollDecelerating)
        XCTAssertEqual(ended, 1, "the stepped deceleration reports its end once")
    }

    func test_aReleaseWithoutMomentumIsNotDecelerating() {
        let fixture = PhysicsListFixture(itemCount: 300, decelerationMode: .stepped)
        var deceleratingAtRelease: Bool?
        fixture.listView.didEndDragging = { [weak fixture] in
            deceleratingAtRelease = fixture?.listView.isScrollDecelerating
        }
        fixture.engine.beginDrag()
        fixture.engine.drag(translation: -30, velocity: 0)
        fixture.engine.drag(translation: -30, velocity: 0)
        _ = fixture.engine.endDrag()
        XCTAssertEqual(deceleratingAtRelease, false)
    }
}
