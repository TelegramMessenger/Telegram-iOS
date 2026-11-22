import XCTest
import UIKit
import Display
import ChatInputPanelNode

// The chat's bottom panels, and the history navigation buttons that line up with their right edge, step 18pt in from
// a rounded screen's corners when the bottom inset is small; screens without rounded corners (iPads, home-button
// iPhones) keep them at the plain side inset. (ChatInputPanelNode has no test target of its own.)
final class ChatInputPanelCompactBottomSideInsetTests: XCTestCase {
    func test_roundedCorners_smallBottomInset_stepsIn() {
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 21.0, deviceMetrics: .iPhone18Pro), 18.0)
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 32.0, deviceMetrics: .iPhone18Pro), 18.0)
    }

    func test_roundedCorners_homeIndicatorInset_none() {
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 34.0, deviceMetrics: .iPhone18Pro), 0.0)
    }

    func test_iPad_none() {
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 20.0, deviceMetrics: .iPadPro11Inch), 0.0)
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 0.0, deviceMetrics: .iPad), 0.0)
        // An iPad the table does not know (iPad Pro 11" M4/M5, 834 x 1210) reports no corner radius either.
        let unknownIPad = DeviceMetrics.unknown(screenSize: CGSize(width: 834.0, height: 1210.0), statusBarHeight: 24.0, onScreenNavigationHeight: 20.0, screenCornerRadius: 0.0)
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 20.0, deviceMetrics: unknownIPad), 0.0)
    }

    // The history navigation buttons and footer panels line up with the input panels on iPad, and keep their step on
    // every phone with a small bottom inset, home-button iPhones included.
    func test_bottomControls_iPad_lineUpWithThePanels() {
        XCTAssertEqual(chatBottomControlsCompactSideInset(bottomInset: 20.0, deviceMetrics: .iPadPro11Inch), 0.0)
        XCTAssertEqual(chatBottomControlsCompactSideInset(bottomInset: 0.0, deviceMetrics: .iPad), 0.0)
    }

    func test_bottomControls_homeButtonIPhone_keepTheirStep() {
        XCTAssertEqual(chatBottomControlsCompactSideInset(bottomInset: 0.0, deviceMetrics: .iPhone6), 18.0)
        XCTAssertEqual(chatInputPanelCompactBottomSideInset(bottomInset: 0.0, deviceMetrics: .iPhone6), 0.0)
    }

    func test_bottomControls_roundedCorners_matchThePanels() {
        XCTAssertEqual(chatBottomControlsCompactSideInset(bottomInset: 21.0, deviceMetrics: .iPhone18Pro), 18.0)
        XCTAssertEqual(chatBottomControlsCompactSideInset(bottomInset: 34.0, deviceMetrics: .iPhone18Pro), 0.0)
    }
}
