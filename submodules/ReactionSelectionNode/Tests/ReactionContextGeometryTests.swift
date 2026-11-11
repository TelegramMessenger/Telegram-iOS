import XCTest
import CoreGraphics
import ReactionContextGeometry

// The reaction bar lined up with a lifted message's card (bubble-free mode, spec 5.9), and master's bar everywhere else.
final class ReactionContextGeometryTests: XCTestCase {
    func testTheBarStartsAtTheCard() {
        let insets = reactionContextBarInsets(sideInset: 17.0, rightSideInset: 17.0, anchorMinX: 51.0, alignsToAnchorLeadingEdge: true, forceTailToRight: false)
        XCTAssertEqual(insets.left, 17.0)
        XCTAssertEqual(insets.right, 17.0)
        XCTAssertEqual(reactionContextClampedBarX(x: 51.0, width: 300.0, containerWidth: 402.0, leftInset: insets.left, rightInset: insets.right), 51.0)
    }

    // A card close to the screen edge takes the bar with it.
    func testTheBarMayComeCloserThanTheUsualInset() {
        let insets = reactionContextBarInsets(sideInset: 17.0, rightSideInset: 17.0, anchorMinX: 8.0, alignsToAnchorLeadingEdge: true, forceTailToRight: false)
        XCTAssertEqual(insets.left, 8.0)
        XCTAssertEqual(insets.right, 8.0)
        XCTAssertEqual(reactionContextClampedBarX(x: 8.0, width: 300.0, containerWidth: 402.0, leftInset: insets.left, rightInset: insets.right), 8.0)
    }

    // iPhone Duo's side strip gives the right edge its own inset; an aligned bar keeps clear of it.
    func testTheRightEdgeKeepsTheDuoInset() {
        let insets = reactionContextBarInsets(sideInset: 17.0, rightSideInset: 101.0, anchorMinX: 150.0, alignsToAnchorLeadingEdge: true, forceTailToRight: false)
        XCTAssertEqual(insets.right, 101.0)
        XCTAssertEqual(reactionContextClampedBarX(x: 150.0, width: 200.0, containerWidth: 402.0, leftInset: insets.left, rightInset: insets.right) + 200.0, 301.0)
        let close = reactionContextBarInsets(sideInset: 17.0, rightSideInset: 101.0, anchorMinX: 10.0, alignsToAnchorLeadingEdge: true, forceTailToRight: false)
        XCTAssertEqual(close.left, 10.0)
        XCTAssertEqual(close.right, 94.0)
    }

    func testWithoutAlignmentTheBarIsMasters() {
        let unaligned = reactionContextBarInsets(sideInset: 17.0, rightSideInset: 101.0, anchorMinX: 8.0, alignsToAnchorLeadingEdge: false, forceTailToRight: false)
        XCTAssertEqual(unaligned.left, 17.0)
        XCTAssertEqual(unaligned.right, 101.0)
        let stories = reactionContextBarInsets(sideInset: 0.0, rightSideInset: 0.0, anchorMinX: 8.0, alignsToAnchorLeadingEdge: true, forceTailToRight: true)
        XCTAssertEqual(stories.left, 0.0)
        XCTAssertEqual(stories.right, 0.0)
    }

    // Master's clamp: left, then right, then left again.
    func testTheClampIsMasters() {
        XCTAssertEqual(reactionContextClampedBarX(x: 5.0, width: 300.0, containerWidth: 402.0, leftInset: 17.0, rightInset: 17.0), 17.0)
        XCTAssertEqual(reactionContextClampedBarX(x: 200.0, width: 300.0, containerWidth: 402.0, leftInset: 17.0, rightInset: 17.0), 85.0)
        XCTAssertEqual(reactionContextClampedBarX(x: 0.0, width: 420.0, containerWidth: 402.0, leftInset: 17.0, rightInset: 17.0), 17.0)
    }

    func testTheTailHangsBesideTheCard() {
        let card = CGRect(x: 51.0, y: 300.0, width: 149.0, height: 60.0)
        XCTAssertEqual(reactionContextTailBesideAnchor(anchorRect: card, barMaxX: 380.0, largeCircleSize: 16.0), 212.0)
        XCTAssertNil(reactionContextTailBesideAnchor(anchorRect: card, barMaxX: 230.0, largeCircleSize: 16.0))
    }

    // In a group with avatars the card starts 51pt in; the bar shrinks its items rather than dropping one.
    func testItemsShrinkToKeepTheirCount() {
        XCTAssertEqual(reactionContextAvailableWidth(containerWidth: 402.0, anchorMinX: 51.0, sideInset: 6.0, rightInset: 0.0), 334.0)
        XCTAssertNil(reactionContextShrunkItemSize(visibleContentWidth: 290.0, availableWidth: 334.0, visibleItemCount: 6.5, itemSpacing: 8.0, sideInset: 6.0))
        let available = reactionContextAvailableWidth(containerWidth: 402.0, anchorMinX: 120.0, sideInset: 6.0, rightInset: 0.0)
        XCTAssertEqual(available, 265.0)
        XCTAssertEqual(reactionContextShrunkItemSize(visibleContentWidth: 290.0, availableWidth: available, visibleItemCount: 6.5, itemSpacing: 8.0, sideInset: 6.0), 32.0)
    }
}
