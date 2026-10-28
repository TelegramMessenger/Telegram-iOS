import XCTest
import CoreGraphics

final class CameraDualPreviewPlacementTests: XCTestCase {
    // The shutter is 96pt; the mode row sits below it, its top 45pt below the shutter's centre on a lifted row.
    private let shutterRadius: CGFloat = 48.0
    private let modeRowTopBelowShutterCenter: CGFloat = 45.0

    private func circleSide(viewfinderWidth: CGFloat) -> CGFloat {
        return viewfinderWidth * 160.0 / 393.0
    }

    private func assertClearOfControls(_ center: CGPoint, side: CGFloat, shutterCenter: CGPoint, containerHeight: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let distance = hypot(center.x - shutterCenter.x, center.y - shutterCenter.y)
        XCTAssertGreaterThan(distance, side / 2.0 + self.shutterRadius, "overlaps the shutter", file: file, line: line)
        XCTAssertLessThanOrEqual(center.y + side / 2.0, shutterCenter.y + self.modeRowTopBelowShutterCenter, "reaches the mode row", file: file, line: line)
        XCTAssertLessThanOrEqual(center.y + side / 2.0, containerHeight, "below the screen's bottom edge", file: file, line: line)
    }

    // iPhone 17/18 Pro: a 393x698 viewfinder with room below it. Without a shutter anchor it is the original expression.
    func testOrdinaryIPhoneKeepsTheViewfinderCorners() {
        let size = CGSize(width: 393.0, height: 698.0)
        let topLeft = cameraDualPreviewCenter(isLeft: true, isBottom: false, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
        XCTAssertEqual(topLeft.x, 393.0 * 267.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, 393.0 * 438.0 / 1080.0, accuracy: 0.001)

        let bottomRight = cameraDualPreviewCenter(isLeft: false, isBottom: true, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
        XCTAssertEqual(bottomRight.x, 393.0 - 393.0 * 267.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(bottomRight.y, 698.0 - 393.0 * 438.0 / 1080.0, accuracy: 0.001)
    }

    // On a phone whose viewfinder fits, the shutter's centre is 53pt above the viewfinder's bottom: keeping to the
    // shutter is the same place, which is what the Duo copies.
    func testShutterAnchorReducesToTheViewfinderCornerWhereTheViewfinderFits() {
        let size = CGSize(width: 393.0, height: 698.0)
        for isLeft in [true, false] {
            let plain = cameraDualPreviewCenter(isLeft: isLeft, isBottom: true, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
            let anchored = cameraDualPreviewCenter(isLeft: isLeft, isBottom: true, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: 698.0 - 53.0)
            XCTAssertEqual(plain.x, anchored.x, accuracy: 0.001)
            XCTAssertEqual(plain.y, anchored.y, accuracy: 0.001)
        }
    }

    // iPhone Duo folded (466x678, the strip on the right): the story viewfinder is the band's 381x678, the controls
    // lifted 46pt above the home indicator, the shutter's centre at 558.67.
    func testDuoFoldedBottomCornersClearTheControls() {
        let size = CGSize(width: 381.0, height: 678.0)
        let shutterCenterY: CGFloat = 678.0 - 48.0 - 20.0 - 5.0 - 46.0 - 1.0 / 3.0
        let side = self.circleSide(viewfinderWidth: 381.0)

        let old = cameraDualPreviewCenter(isLeft: true, isBottom: true, viewfinderWidth: 381.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
        XCTAssertLessThan(hypot(old.x - size.width / 2.0, old.y - shutterCenterY), side / 2.0 + self.shutterRadius, "the viewfinder's corner is under the shutter")

        for isLeft in [true, false] {
            let center = cameraDualPreviewCenter(isLeft: isLeft, isBottom: true, viewfinderWidth: 381.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: shutterCenterY)
            XCTAssertEqual(center.y, shutterCenterY + 53.0 - 381.0 * 438.0 / 1080.0, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(center.x - side / 2.0, 0.0)
            XCTAssertLessThanOrEqual(center.x + side / 2.0, size.width)
            self.assertClearOfControls(center, side: side, shutterCenter: CGPoint(x: size.width / 2.0, y: shutterCenterY), containerHeight: size.height)
        }
    }

    // iPhone Duo unfolded (669x951): the 9:16 viewfinder is 669x1189, 238pt below the screen; the bottom corner was
    // there with it.
    func testDuoUnfoldedBottomCornersStayOnScreenAndClearTheControls() {
        let size = CGSize(width: 669.0, height: 1189.0)
        let screenHeight: CGFloat = 951.0
        let shutterCenterY: CGFloat = 951.0 - 48.0 - 20.0 - 5.0 - 46.0 - 1.0 / 3.0
        let side = self.circleSide(viewfinderWidth: 669.0)

        let old = cameraDualPreviewCenter(isLeft: true, isBottom: true, viewfinderWidth: 669.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
        XCTAssertGreaterThan(old.y + side / 2.0, screenHeight, "the viewfinder's corner is below the screen")

        for isLeft in [true, false] {
            let center = cameraDualPreviewCenter(isLeft: isLeft, isBottom: true, viewfinderWidth: 669.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: shutterCenterY)
            self.assertClearOfControls(center, side: side, shutterCenter: CGPoint(x: size.width / 2.0, y: shutterCenterY), containerHeight: screenHeight)
        }
    }

    func testTopCornersIgnoreTheShutter() {
        let size = CGSize(width: 669.0, height: 1189.0)
        for isLeft in [true, false] {
            let plain = cameraDualPreviewCenter(isLeft: isLeft, isBottom: false, viewfinderWidth: 669.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
            let anchored = cameraDualPreviewCenter(isLeft: isLeft, isBottom: false, viewfinderWidth: 669.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: 831.67)
            XCTAssertEqual(plain, anchored)
        }
    }

    // The shutter only ever raises a bottom corner, never lowers it below the viewfinder's.
    func testShutterAnchorNeverLowersTheCorner() {
        let size = CGSize(width: 393.0, height: 698.0)
        let plain = cameraDualPreviewCenter(isLeft: true, isBottom: true, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: nil)
        let anchored = cameraDualPreviewCenter(isLeft: true, isBottom: true, viewfinderWidth: 393.0, containerSize: size, leftInset: 0.0, rightInset: 0.0, shutterCenterY: 900.0)
        XCTAssertEqual(plain, anchored)
    }

    func testSideInsetsMoveTheirOwnSideOnly() {
        let size = CGSize(width: 466.0, height: 828.0)
        let left = cameraDualPreviewCenter(isLeft: true, isBottom: false, viewfinderWidth: 466.0, containerSize: size, leftInset: 0.0, rightInset: 84.0, shutterCenterY: nil)
        XCTAssertEqual(left.x, 466.0 * 267.0 / 1080.0, accuracy: 0.001)
        let right = cameraDualPreviewCenter(isLeft: false, isBottom: false, viewfinderWidth: 466.0, containerSize: size, leftInset: 0.0, rightInset: 84.0, shutterCenterY: nil)
        XCTAssertEqual(right.x, 466.0 - 84.0 - 466.0 * 267.0 / 1080.0, accuracy: 0.001)
    }
}
