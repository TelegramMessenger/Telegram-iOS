import XCTest
import ReactionContextGeometry

// A reaction picked in a message's context menu flies from the reaction bar into the message's reaction button and
// plays there in place of the button's own icon. The icon hides only while that copy is drawing (issue #97: it hid on
// landing, and a copy that had not drawn yet left the button empty until the 2 s fallback).
final class ReactionFlyInIconHandoffTests: XCTestCase {
    // The usual case: the copy started playing during the flight, so it covers the icon from the landing on.
    func testACopyThatIsPlayingHidesTheIconOnLanding() {
        let handoff = ReactionFlyInIconHandoff()
        handoff.expandedAnimationBegan()
        XCTAssertFalse(handoff.hidesTargetIcon)
        handoff.land()
        XCTAssertTrue(handoff.hidesTargetIcon)
    }

    // The copy has drawn nothing yet when it lands (its animation still loading, or nowhere to draw): the button keeps
    // its own icon.
    func testACopyThatHasNotDrawnLeavesTheIconVisible() {
        let handoff = ReactionFlyInIconHandoff()
        handoff.land()
        XCTAssertFalse(handoff.hidesTargetIcon)
    }

    // ...until the copy starts playing in the button, which then takes over from the icon.
    func testACopyThatStartsAfterLandingTakesOver() {
        let handoff = ReactionFlyInIconHandoff()
        handoff.land()
        handoff.expandedAnimationBegan()
        XCTAssertTrue(handoff.hidesTargetIcon)
    }

    // The fallback that ends the hand-off removes the copy and shows the icon again.
    func testTheFallbackShowsTheIconAgain() {
        let handoff = ReactionFlyInIconHandoff()
        handoff.expandedAnimationBegan()
        handoff.land()
        handoff.finish()
        XCTAssertFalse(handoff.hidesTargetIcon)
    }

    // A copy that starts only after the fallback has removed it must not hide the icon again.
    func testACopyThatStartsAfterTheFallbackLeavesTheIconVisible() {
        let handoff = ReactionFlyInIconHandoff()
        handoff.land()
        handoff.finish()
        handoff.expandedAnimationBegan()
        XCTAssertFalse(handoff.hidesTargetIcon)
    }
}
