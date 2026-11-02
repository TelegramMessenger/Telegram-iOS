import XCTest
import UIKit
import Display
@testable import VideoMessageCameraScreen

final class VideoMessageCameraLayoutTests: XCTestCase {
    // iPhone Duo, folded portrait (466x678): right strip of 84pt, the status corner 84x170 at its top.
    private let foldedSafeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
    private let foldedCorners = ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)

    // The phone placement above a bot keyboard (the report's screenshot): a 358pt circle from y 92 reaches 178pt below
    // the panel's top at 272. It shrinks to end 20pt above the panel, from the top margin, centred on the band.
    func testFoldedCircleAboveBotKeyboardFitsAbovePanel() {
        let phoneFrame = CGRect(x: 12.0, y: 92.0, width: 358.0, height: 358.0)
        let frame = videoMessageCameraPreviewFrameAbovePanel(frame: phoneFrame, bandMinX: 0.0, bandMaxX: 382.0, topY: 12.0, panelTop: 272.0)
        XCTAssertEqual(frame, CGRect(x: 71.0, y: 12.0, width: 240.0, height: 240.0))
        XCTAssertLessThanOrEqual(frame.maxY, 272.0 - 20.0)
        XCTAssertEqual(frame.midX, 191.0)
        // The flash button beside the circle's lower-left corner (40pt, 28pt above the panel, after the flip button)
        // stays clear of the circle with either side inset the screen uses (26 without input, 8 with the keyboard).
        for flashCenter in [CGPoint(x: 97.0, y: 244.0), CGPoint(x: 79.0, y: 244.0)] {
            let distance = hypot(flashCenter.x - frame.midX, flashCenter.y - frame.midY)
            XCTAssertGreaterThanOrEqual(distance, frame.width / 2.0 + 20.0)
        }
    }

    // A circle that only slightly reaches the panel keeps its size and moves up just enough.
    func testCircleMovesUpBeforeShrinking() {
        let phoneFrame = CGRect(x: 12.0, y: 92.0, width: 358.0, height: 358.0)
        let frame = videoMessageCameraPreviewFrameAbovePanel(frame: phoneFrame, bandMinX: 0.0, bandMaxX: 382.0, topY: 12.0, panelTop: 430.0)
        XCTAssertEqual(frame, CGRect(x: 12.0, y: 52.0, width: 358.0, height: 358.0))
    }

    // Above the panel at the bottom of the screen (no keyboard) the phone placement stays.
    func testCircleAbovePanelIsUnchanged() {
        let phoneFrame = CGRect(x: 12.0, y: 92.0, width: 358.0, height: 358.0)
        let frame = videoMessageCameraPreviewFrameAbovePanel(frame: phoneFrame, bandMinX: 0.0, bandMaxX: 382.0, topY: 12.0, panelTop: 610.0)
        XCTAssertEqual(frame, phoneFrame)
    }

    // Above a bot keyboard's panel (top 272) the view-once button while recording (rows 122..162), and the column of
    // view-once and record-more in the preview (rows 157..250), reach the status corner: the column keeps clear of the
    // strip, both buttons together. Lower down, below the corner (rows 450..540, no keyboard), it stays in the strip.
    func testTrailingControlsKeepClearOfStatusCorner() {
        XCTAssertEqual(videoMessageCameraTrailingControlInset(minY: 122.0, maxY: 162.0, containerHeight: 678.0, safeInsets: self.foldedSafeInsets, reservedCorners: self.foldedCorners), 84.0)
        XCTAssertEqual(videoMessageCameraTrailingControlInset(minY: 157.0, maxY: 250.0, containerHeight: 678.0, safeInsets: self.foldedSafeInsets, reservedCorners: self.foldedCorners), 84.0)
        XCTAssertEqual(videoMessageCameraTrailingControlInset(minY: 450.0, maxY: 540.0, containerHeight: 678.0, safeInsets: self.foldedSafeInsets, reservedCorners: self.foldedCorners), 0.0)
    }

    // Every other device keeps the controls where they were, whatever its side insets.
    func testTrailingControlsUnchangedWithoutReservedCorners() {
        let insets = UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)
        XCTAssertEqual(videoMessageCameraTrailingControlInset(minY: 122.0, maxY: 162.0, containerHeight: 402.0, safeInsets: insets, reservedCorners: .none), 0.0)
    }

    // Above a bot keyboard the panel's rows take touches (Cancel, trash, send); the keyboard below stays covered.
    func testTouchesReachPanelAboveInputNode() {
        let panelFrame = CGRect(x: 0.0, y: 272.0, width: 466.0, height: 40.0)
        XCTAssertTrue(videoMessageCameraPassesTouchToInputPanel(y: 290.0, layoutHeight: 678.0, bottomInset: 0.0, inputPanelFrame: panelFrame, hasInputNode: true))
        XCTAssertFalse(videoMessageCameraPassesTouchToInputPanel(y: 400.0, layoutHeight: 678.0, bottomInset: 0.0, inputPanelFrame: panelFrame, hasInputNode: true))
        XCTAssertFalse(videoMessageCameraPassesTouchToInputPanel(y: 200.0, layoutHeight: 678.0, bottomInset: 0.0, inputPanelFrame: panelFrame, hasInputNode: true))
    }

    // Without an input node the area from the panel's height above the reported input down passes, as before.
    func testTouchesWithoutInputNodeUnchanged() {
        let panelFrame = CGRect(x: 0.0, y: 798.0, width: 402.0, height: 42.0)
        XCTAssertTrue(videoMessageCameraPassesTouchToInputPanel(y: 810.0, layoutHeight: 874.0, bottomInset: 34.0, inputPanelFrame: panelFrame, hasInputNode: false))
        XCTAssertFalse(videoMessageCameraPassesTouchToInputPanel(y: 790.0, layoutHeight: 874.0, bottomInset: 34.0, inputPanelFrame: panelFrame, hasInputNode: false))
        XCTAssertFalse(videoMessageCameraPassesTouchToInputPanel(y: 290.0, layoutHeight: 678.0, bottomInset: 0.0, inputPanelFrame: CGRect(x: 0.0, y: 272.0, width: 466.0, height: 40.0), hasInputNode: false))
    }

    // iPhone 17 Pro above a tall bot keyboard: the preview's 369pt square (y 165..534) reaches into the panel's rows
    // (y 497..549). There a corner of the square, over the panel's trash, is not the preview's; the circle is.
    func testPreviewClaimsOnlyItsCircleOverTheInputPanel() {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 369.0, height: 369.0)
        let lowerLeftCorner = CGPoint(x: 10.0, y: 360.0)
        let circleBottom = CGPoint(x: 184.5, y: 360.0)
        XCTAssertFalse(videoMessageCameraPreviewClaimsTouch(point: lowerLeftCorner, bounds: bounds, overInputPanel: true))
        XCTAssertTrue(videoMessageCameraPreviewClaimsTouch(point: circleBottom, bounds: bounds, overInputPanel: true))
        XCTAssertFalse(videoMessageCameraPreviewClaimsTouch(point: CGPoint(x: 184.5, y: 380.0), bounds: bounds, overInputPanel: true))
    }

    // Away from the input panel the preview keeps its whole square, as before.
    func testPreviewClaimsItsSquareElsewhere() {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 369.0, height: 369.0)
        XCTAssertTrue(videoMessageCameraPreviewClaimsTouch(point: CGPoint(x: 10.0, y: 360.0), bounds: bounds, overInputPanel: false))
        XCTAssertTrue(videoMessageCameraPreviewClaimsTouch(point: CGPoint(x: 184.5, y: 184.5), bounds: bounds, overInputPanel: false))
        XCTAssertFalse(videoMessageCameraPreviewClaimsTouch(point: CGPoint(x: 400.0, y: 10.0), bounds: bounds, overInputPanel: false))
    }
}
