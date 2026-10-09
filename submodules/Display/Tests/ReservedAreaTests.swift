import XCTest
import UIKit
@testable import Display

final class ReservedAreaTests: XCTestCase {
    private func corners(topLeft: CGSize? = nil, topRight: CGSize? = nil, bottomLeft: CGSize? = nil, bottomRight: CGSize? = nil) -> ContainerViewLayoutCorners {
        return ContainerViewLayoutCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }

    // The table (spec section 3). UIInterfaceOrientation.landscapeLeft = 4, .landscapeRight = 3.

    func test_coverPortrait_topRight84x170() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 466.0, height: 678.0), orientation: .portrait), corners(topRight: CGSize(width: 84.0, height: 170.0)))
    }

    func test_coverLandscapeLeft_bottomRight84x82() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 678.0, height: 466.0), orientation: .landscapeLeft), corners(bottomRight: CGSize(width: 84.0, height: 82.0)))
    }

    func test_coverLandscapeRight_topLeftUnion84x84() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 678.0, height: 466.0), orientation: .landscapeRight), corners(topLeft: CGSize(width: 84.0, height: 84.0)))
    }

    func test_innerPortrait_topRight134x82() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 669.0, height: 951.0), orientation: .portrait), corners(topRight: CGSize(width: 134.0, height: 82.0)))
    }

    func test_innerLandscape_topRight84x120() {
        for orientation: UIInterfaceOrientation in [.landscapeLeft, .landscapeRight] {
            XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 951.0, height: 669.0), orientation: orientation), corners(topRight: CGSize(width: 84.0, height: 120.0)))
        }
    }

    func test_halfWidthInnerWindow_none() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 475.0, height: 669.0), orientation: .landscapeLeft), ContainerViewLayoutCorners.none)
    }

    func test_unknownWindowSize_none() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 402.0, height: 874.0), orientation: .portrait), ContainerViewLayoutCorners.none)
    }

    func test_upsideDown_none() {
        // The unfolded screen's upside-down portrait keeps the portrait block (measured on the simulator).
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 669.0, height: 951.0), orientation: .portraitUpsideDown), corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 466.0, height: 678.0), orientation: .portraitUpsideDown), ContainerViewLayoutCorners.none)
    }

    func test_sizeWithinOnePoint_matches() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 466.4, height: 677.6), orientation: .portrait), corners(topRight: CGSize(width: 84.0, height: 170.0)))
    }

    // A stale orientation (the layout keeps the one from the last size change, and a launch can
    // report portrait for a landscape window): the size decides portrait vs landscape.

    func test_innerLandscapeSize_withPortraitOrientation_stillLandscapeBlock() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 951.0, height: 669.0), orientation: .portrait), corners(topRight: CGSize(width: 84.0, height: 120.0)))
    }

    func test_coverLandscapeSize_withPortraitOrientation_none() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 678.0, height: 466.0), orientation: .portrait), ContainerViewLayoutCorners.none)
    }

    func test_portraitSize_withLandscapeOrientation_portraitBlock() {
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 669.0, height: 951.0), orientation: .landscapeLeft), corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertEqual(iPhoneDuoReservedCorners(windowSize: CGSize(width: 466.0, height: 678.0), orientation: .landscapeRight), corners(topRight: CGSize(width: 84.0, height: 170.0)))
    }

    // The fold: a reported division is accepted only on the inner screen and only when it crosses
    // the whole window (measured: folding reported the inner screen's fold at (455.5, -203) on the
    // cover screen for 66ms).

    func test_division_innerLandscape_fullHeightStrip_accepted() {
        let fold = CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0)
        XCTAssertEqual(iPhoneDuoDivision(windowSize: CGSize(width: 951.0, height: 669.0), reported: fold), fold)
    }

    func test_division_innerPortrait_fullWidthStrip_accepted() {
        let fold = CGRect(x: 0.0, y: 455.5, width: 669.0, height: 40.0)
        XCTAssertEqual(iPhoneDuoDivision(windowSize: CGSize(width: 669.0, height: 951.0), reported: fold), fold)
    }

    func test_division_onCoverScreen_rejected() {
        XCTAssertNil(iPhoneDuoDivision(windowSize: CGSize(width: 678.0, height: 466.0), reported: CGRect(x: 455.5, y: -203.0, width: 40.0, height: 669.0)))
    }

    func test_division_notCrossingWindow_rejected() {
        XCTAssertNil(iPhoneDuoDivision(windowSize: CGSize(width: 951.0, height: 669.0), reported: CGRect(x: 455.5, y: -203.0, width: 40.0, height: 669.0)))
    }

    func test_division_none_staysNil() {
        XCTAssertNil(iPhoneDuoDivision(windowSize: CGSize(width: 951.0, height: 669.0), reported: nil))
    }

    // Sheets below the status bar.

    func test_offsettingTop_shortensTopBlockThatReachesBelowSheetTop() {
        let value = corners(topRight: CGSize(width: 84.0, height: 170.0), bottomRight: CGSize(width: 7.0, height: 8.0))
        XCTAssertEqual(value.offsettingTop(by: 40.0), corners(topRight: CGSize(width: 84.0, height: 130.0), bottomRight: CGSize(width: 7.0, height: 8.0)))
    }

    func test_offsettingTop_dropsTopBlockThatEndsAboveSheetTop() {
        let value = corners(topLeft: CGSize(width: 10.0, height: 20.0), bottomLeft: CGSize(width: 5.0, height: 6.0))
        XCTAssertEqual(value.offsettingTop(by: 40.0), corners(bottomLeft: CGSize(width: 5.0, height: 6.0)))
    }

    // Split panes.

    func test_pane_masterKeepsOnlyLeftCorners_andDropsDivisionItDoesNotCross() {
        let result = reservedAreaForPane(corners: corners(topLeft: CGSize(width: 10.0, height: 10.0), topRight: CGSize(width: 84.0, height: 120.0)), division: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), paneFrame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, corners(topLeft: CGSize(width: 10.0, height: 10.0)))
        XCTAssertNil(result.division)
    }

    func test_pane_detailKeepsRightCorners_andTranslatesDivision() {
        let result = reservedAreaForPane(corners: corners(topLeft: CGSize(width: 10.0, height: 10.0), topRight: CGSize(width: 84.0, height: 120.0)), division: CGRect(x: 455.5, y: 0.0, width: 40.0, height: 669.0), paneFrame: CGRect(x: 320.0, y: 0.0, width: 631.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertEqual(result.division, CGRect(x: 135.5, y: 0.0, width: 40.0, height: 669.0))
    }

    func test_pane_fullFrameKeepsEverything() {
        let all = corners(topLeft: CGSize(width: 1.0, height: 1.0), topRight: CGSize(width: 2.0, height: 2.0), bottomLeft: CGSize(width: 3.0, height: 3.0), bottomRight: CGSize(width: 4.0, height: 4.0))
        let result = reservedAreaForPane(corners: all, division: nil, paneFrame: CGRect(x: 0.0, y: 0.0, width: 951.0, height: 669.0), containerSize: CGSize(width: 951.0, height: 669.0))
        XCTAssertEqual(result.corners, all)
        XCTAssertNil(result.division)
    }
}
