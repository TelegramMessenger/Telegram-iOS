import XCTest
import CoreGraphics

final class CameraDualPreviewPlacementTests: XCTestCase {
    // The 96pt shutter's centre is 53pt above the viewfinder's bottom where the viewfinder fits above the controls.
    private let shutterRadius: CGFloat = 48.0
    private let shutterAbove: CGFloat = 53.0
    // On a lifted row (iPhone Duo) the mode row's top is 45pt below the shutter's centre.
    private let modeRowTopBelowShutterCenter: CGFloat = 45.0

    private func circleSide(viewfinderWidth: CGFloat) -> CGFloat {
        return viewfinderWidth * 160.0 / 393.0
    }

    private func center(isLeft: Bool, isBottom: Bool, width: CGFloat, size: CGSize, visibleHeight: CGFloat? = nil, leftInset: CGFloat = 0.0, rightInset: CGFloat = 0.0, shutterCenterY: CGFloat?) -> CGPoint {
        return cameraDualPreviewCenter(isLeft: isLeft, isBottom: isBottom, viewfinderWidth: width, containerSize: size, visibleHeight: visibleHeight ?? size.height, leftInset: leftInset, rightInset: rightInset, shutterCenterY: shutterCenterY, shutterCenterAboveViewfinderBottom: self.shutterAbove)
    }

    // iPhone 17/18 Pro: a 393x698 viewfinder with room below it, the frame's corners.
    func testOrdinaryIPhoneKeepsTheViewfinderCorners() {
        let size = CGSize(width: 393.0, height: 698.0)
        let topLeft = self.center(isLeft: true, isBottom: false, width: 393.0, size: size, shutterCenterY: nil)
        XCTAssertEqual(topLeft.x, 393.0 * 267.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, 393.0 * 438.0 / 1080.0, accuracy: 0.001)

        let bottomRight = self.center(isLeft: false, isBottom: true, width: 393.0, size: size, shutterCenterY: nil)
        XCTAssertEqual(bottomRight.x, 393.0 - 393.0 * 267.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(bottomRight.y, 698.0 - 393.0 * 438.0 / 1080.0, accuracy: 0.001)

        // Its shutter, 53pt above the viewfinder's bottom, is the relation iPhone Duo unfolded copies; passed here it
        // changes nothing, the viewfinder ending on the screen.
        let anchored = self.center(isLeft: false, isBottom: true, width: 393.0, size: size, shutterCenterY: 698.0 - self.shutterAbove)
        XCTAssertEqual(anchored, bottomRight)
    }

    // iPhone Duo folded (466x678, the strip on the right): the story viewfinder is the band's 381x678 and ends on the
    // screen, so a bottom corner stays where the capture puts it, as on home-button phones, though the controls are
    // lifted over it.
    func testDuoFoldedKeepsTheViewfinderCorner() {
        let size = CGSize(width: 381.0, height: 678.0)
        let shutterCenterY: CGFloat = 678.0 - 48.0 - 20.0 - 5.0 - 46.0 - 1.0 / 3.0
        for isLeft in [true, false] {
            let plain = self.center(isLeft: isLeft, isBottom: true, width: 381.0, size: size, shutterCenterY: nil)
            let anchored = self.center(isLeft: isLeft, isBottom: true, width: 381.0, size: size, shutterCenterY: shutterCenterY)
            XCTAssertEqual(plain, anchored)
            XCTAssertEqual(anchored.y, 678.0 - 381.0 * 438.0 / 1080.0, accuracy: 0.001)
        }
    }

    // iPhone Duo unfolded (669x951): the 9:16 viewfinder is 669x1189, 238pt below the screen, and the bottom corner
    // was there with it. It keeps to the shutter instead: on screen and clear of the controls.
    func testDuoUnfoldedBottomCornersStayOnScreenAndClearTheControls() {
        let size = CGSize(width: 669.0, height: 1189.0)
        let screenHeight: CGFloat = 951.0
        let shutterCenterY: CGFloat = 951.0 - 48.0 - 20.0 - 5.0 - 46.0 - 1.0 / 3.0
        let side = self.circleSide(viewfinderWidth: 669.0)

        let old = self.center(isLeft: true, isBottom: true, width: 669.0, size: size, visibleHeight: screenHeight, shutterCenterY: nil)
        XCTAssertGreaterThan(old.y + side / 2.0, screenHeight, "the viewfinder's corner is below the screen")

        for isLeft in [true, false] {
            let center = self.center(isLeft: isLeft, isBottom: true, width: 669.0, size: size, visibleHeight: screenHeight, shutterCenterY: shutterCenterY)
            XCTAssertEqual(center.y, shutterCenterY + self.shutterAbove - 669.0 * 438.0 / 1080.0, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(center.x - side / 2.0, 0.0)
            XCTAssertLessThanOrEqual(center.x + side / 2.0, size.width)

            let distance = hypot(center.x - size.width / 2.0, center.y - shutterCenterY)
            XCTAssertGreaterThan(distance, side / 2.0 + self.shutterRadius, "overlaps the shutter")
            XCTAssertLessThanOrEqual(center.y + side / 2.0, shutterCenterY - self.shutterRadius, "reaches the shutter's row")
            XCTAssertLessThanOrEqual(center.y + side / 2.0, shutterCenterY + self.modeRowTopBelowShutterCenter, "reaches the mode row")
        }
    }

    func testTopCornersIgnoreTheShutter() {
        let size = CGSize(width: 669.0, height: 1189.0)
        for isLeft in [true, false] {
            let plain = self.center(isLeft: isLeft, isBottom: false, width: 669.0, size: size, visibleHeight: 951.0, shutterCenterY: nil)
            let anchored = self.center(isLeft: isLeft, isBottom: false, width: 669.0, size: size, visibleHeight: 951.0, shutterCenterY: 831.67)
            XCTAssertEqual(plain, anchored)
        }
    }

    // A guard: the shutter only ever raises a bottom corner, never lowers it below the viewfinder's.
    func testShutterAnchorNeverLowersTheCorner() {
        let size = CGSize(width: 669.0, height: 1189.0)
        let plain = self.center(isLeft: true, isBottom: true, width: 669.0, size: size, visibleHeight: 951.0, shutterCenterY: nil)
        let anchored = self.center(isLeft: true, isBottom: true, width: 669.0, size: size, visibleHeight: 951.0, shutterCenterY: 1300.0)
        XCTAssertEqual(plain, anchored)
    }

    func testSideInsetsMoveTheirOwnSideOnly() {
        let size = CGSize(width: 466.0, height: 828.0)
        let left = self.center(isLeft: true, isBottom: false, width: 466.0, size: size, rightInset: 84.0, shutterCenterY: nil)
        XCTAssertEqual(left.x, 466.0 * 267.0 / 1080.0, accuracy: 0.001)
        let right = self.center(isLeft: false, isBottom: false, width: 466.0, size: size, rightInset: 84.0, shutterCenterY: nil)
        XCTAssertEqual(right.x, 466.0 - 84.0 - 466.0 * 267.0 / 1080.0, accuracy: 0.001)
    }
}
