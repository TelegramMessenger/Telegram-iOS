import Foundation
import UIKit
import XCTest
import CallScreen

/// Pins where the 1:1 call screen puts the peer's name over full-screen video (`privateCallScreenVideoTitleY`).
///
/// The top row holds the back button (top-left, at `insets.top + 12`) and, once the call is active, the encryption
/// key emoji and the conference button. The name goes below that row whenever the row holds the back button, in
/// every call state, so it never shares a line with "Back" (issue #104: on an outgoing video call, "‹ Назад" and a
/// long name ran into each other). iPhone Duo puts the back button in the side strip; there the name keeps the top
/// row until the key emoji takes it.
final class PrivateCallScreenTitleLayoutTests: XCTestCase {
    private let insetTop: CGFloat = 62.0
    // The back button is a 17pt label (about 21pt tall) at `insets.top + 12`.
    private let backButtonRowMaxY: CGFloat = 62.0 + 12.0 + 22.0

    func testTitleIsBelowTheBackButtonRowBeforeTheCallIsActive() {
        let titleY = privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: false, isBackButtonInTopRow: true)
        XCTAssertGreaterThan(titleY, self.backButtonRowMaxY)
    }

    func testTitleDoesNotMoveWhenTheCallBecomesActive() {
        XCTAssertEqual(
            privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: false, isBackButtonInTopRow: true),
            privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: true, isBackButtonInTopRow: true)
        )
    }

    func testActiveCallKeepsItsPosition() {
        XCTAssertEqual(privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: true, isBackButtonInTopRow: true), self.insetTop + 2.0 + 54.0)
        XCTAssertEqual(privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: true, isBackButtonInTopRow: false), self.insetTop + 2.0 + 54.0)
    }

    func testBackButtonInTheSideStripLeavesTheTopRowToTheTitle() {
        XCTAssertEqual(privateCallScreenVideoTitleY(insetTop: self.insetTop, isActive: false, isBackButtonInTopRow: false), self.insetTop + 2.0)
    }
}
