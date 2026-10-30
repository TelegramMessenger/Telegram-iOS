import XCTest
import UIKit
@testable import Display

final class CenteredAlertSideInsetsTests: XCTestCase {
    private let coverPortraitSize = CGSize(width: 466.0, height: 678.0)
    private let coverPortraitInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
    private let coverPortraitCorners = ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)

    private let coverLandscapeSize = CGSize(width: 678.0, height: 466.0)

    func test_coverPortrait_midScreen_centeredOnTheScreen() {
        // The session sheet spans the strip in folded portrait; an alert below the status corner centers on its axis.
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 240.0, alertMaxY: 440.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverPortrait_raisedIntoTheStatusCorner_keepsTheBand() {
        // The keyboard lifts a wide alert into the corner block: it stays clear of it.
        let insets = centeredAlertSideInsets(alertWidth: 320.0, alertMinY: 60.0, alertMaxY: 260.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_coverPortrait_raisedBesideTheStatusCorner_centeredOnTheScreen() {
        // Screen-centered, a 300pt alert ends 1pt inside the 84pt block (x 83...383): within the 1pt tolerance it does
        // not reach it, so the keyboard lifting it does not move it sideways.
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 60.0, alertMaxY: 260.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverPortrait_narrowAlertBesideTheStatusCorner_centeredOnTheScreen() {
        let insets = centeredAlertSideInsets(alertWidth: 270.0, alertMinY: 60.0, alertMaxY: 260.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverPortrait_wideAlertJustBelowTheStatusCorner_centeredOnTheScreen() {
        // The block ends at 170; an alert starting there does not reach it.
        let insets = centeredAlertSideInsets(alertWidth: 320.0, alertMinY: 170.0, alertMaxY: 370.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverPortrait_insetWithAnotherCause_safeInset() {
        // A side inset that is not a corner block's strip always applies.
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 240.0, alertMaxY: 440.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_unfoldedPortrait_noSideInsets() {
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 60.0, alertMaxY: 260.0, containerSize: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverLandscapeLeft_keepsTheBand() {
        // Sheets keep to the band in landscape; the alert stays on their axis although the bottom block is far below it.
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 130.0, alertMaxY: 330.0, containerSize: self.coverLandscapeSize, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_coverLandscapeRight_keepsTheBand() {
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 130.0, alertMaxY: 330.0, containerSize: self.coverLandscapeSize, safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0), reservedCorners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.left, 84.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_unfoldedLandscape_keepsTheBand() {
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 230.0, alertMaxY: 430.0, containerSize: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_notchedPhoneLandscape_safeInsets() {
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 100.0, alertMaxY: 300.0, containerSize: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), reservedCorners: .none)
        XCTAssertEqual(insets.left, 62.0)
        XCTAssertEqual(insets.right, 62.0)
    }

    func test_notchedPhonePortrait_noSideInsets() {
        let insets = centeredAlertSideInsets(alertWidth: 300.0, alertMinY: 340.0, alertMaxY: 540.0, containerSize: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), reservedCorners: .none)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }
}
