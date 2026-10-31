import XCTest
import UIKit
@testable import Display

final class ToastFrameTests: XCTestCase {
    private let compact = LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil)
    private let regular = LayoutMetrics(widthClass: .regular, heightClass: .regular, orientation: nil)

    func test_compact_wideBand_unchanged() {
        // A phone in landscape: the toast keeps the band however wide it is.
        let band = CGRect(x: 74.0, y: 300.0, width: 726.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.compact), band)
    }

    func test_regular_wideBand_cappedAndCenteredOnTheBand() {
        // An iPad window 1194 wide with 12pt margins: 416 wide, centred on the window.
        let band = CGRect(x: 12.0, y: 700.0, width: 1170.0, height: 50.0)
        let result = toastFrame(band, metrics: self.regular)
        XCTAssertEqual(result, CGRect(x: 389.0, y: 700.0, width: toastMaximumWidth, height: 50.0))
        XCTAssertEqual(result.midX, band.midX)
    }

    func test_regular_paneBand_centeredOnThePane() {
        // A toast laid out in a split view's detail pane (its own container) is centred in that pane.
        let band = CGRect(x: 12.0, y: 0.0, width: 770.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.regular), CGRect(x: 189.0, y: 0.0, width: toastMaximumWidth, height: 50.0))
    }

    func test_regular_unequalSideInsets_centeredOnTheBandNotTheContainer() {
        let band = CGRect(x: 96.0, y: 0.0, width: 843.0, height: 50.0)
        let result = toastFrame(band, metrics: self.regular)
        XCTAssertEqual(result.width, toastMaximumWidth)
        XCTAssertEqual(result.minX, floorToScreenPixels(96.0 + (843.0 - toastMaximumWidth) / 2.0))
    }

    func test_regular_narrowBand_unchanged() {
        // Already narrower than the maximum (a narrow toast, a slide-over window): nothing to cap.
        let band = CGRect(x: 30.0, y: 0.0, width: 210.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.regular), band)
    }

    func test_maximumWidth_isTheLargestPhonesToast() {
        // A 440pt phone with the toast's 12pt margins.
        XCTAssertEqual(toastMaximumWidth, 440.0 - 12.0 * 2.0)
    }

    // A toast with an arrow pointing at a tab (the avatar upload toast at Settings): on iPad the tab is in the master
    // column, outside the centred toast; the toast moves over it, keeping a margin, within the band.
    func test_regular_anchorOutsideTheCenteredToast_shiftedToContainIt() {
        let band = CGRect(x: 12.0, y: 0.0, width: 1170.0, height: 50.0)
        let result = toastFrame(band, metrics: self.regular, anchorX: 320.0)
        XCTAssertEqual(result, CGRect(x: 320.0 - 32.0, y: 0.0, width: toastMaximumWidth, height: 50.0))
    }

    func test_regular_anchorNearTheBandsEdge_staysInTheBand() {
        let band = CGRect(x: 12.0, y: 0.0, width: 1170.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.regular, anchorX: 20.0).minX, 12.0)
        XCTAssertEqual(toastFrame(band, metrics: self.regular, anchorX: 1180.0).maxX, band.maxX)
    }

    func test_regular_anchorInsideTheCenteredToast_staysCentered() {
        let band = CGRect(x: 12.0, y: 0.0, width: 1170.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.regular, anchorX: 597.0), toastFrame(band, metrics: self.regular))
    }

    func test_compact_anchor_unchanged() {
        let band = CGRect(x: 12.0, y: 0.0, width: 378.0, height: 50.0)
        XCTAssertEqual(toastFrame(band, metrics: self.compact, anchorX: 360.0), band)
    }
}
