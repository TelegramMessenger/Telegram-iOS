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
        let insets = centeredAlertSideInsets(alertMinY: 240.0, alertMaxY: 440.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_coverPortrait_raisedIntoTheStatusCorner_keepsTheBand() {
        // The keyboard lifts the alert beside the corner block: it stays clear of it.
        let insets = centeredAlertSideInsets(alertMinY: 60.0, alertMaxY: 260.0, containerSize: self.coverPortraitSize, safeInsets: self.coverPortraitInsets, reservedCorners: self.coverPortraitCorners)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_coverLandscapeLeft_keepsTheBand() {
        // Sheets keep to the band in landscape; the alert stays on their axis although the bottom block is far below it.
        let insets = centeredAlertSideInsets(alertMinY: 130.0, alertMaxY: 330.0, containerSize: self.coverLandscapeSize, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_coverLandscapeRight_keepsTheBand() {
        let insets = centeredAlertSideInsets(alertMinY: 130.0, alertMaxY: 330.0, containerSize: self.coverLandscapeSize, safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0), reservedCorners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 82.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.left, 84.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_unfoldedLandscape_keepsTheBand() {
        let insets = centeredAlertSideInsets(alertMinY: 230.0, alertMaxY: 430.0, containerSize: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_notchedPhoneLandscape_safeInsets() {
        let insets = centeredAlertSideInsets(alertMinY: 100.0, alertMaxY: 300.0, containerSize: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), reservedCorners: .none)
        XCTAssertEqual(insets.left, 62.0)
        XCTAssertEqual(insets.right, 62.0)
    }

    func test_notchedPhonePortrait_noSideInsets() {
        let insets = centeredAlertSideInsets(alertMinY: 340.0, alertMaxY: 540.0, containerSize: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), reservedCorners: .none)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }
}
