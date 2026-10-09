import XCTest
import UIKit
@testable import Display

/// iPhone Duo's safe insets per posture: the settled system values, tabulated because the system's own
/// lag behind rotations and folds (measured) and a stale inset paired with the table's corners drops the
/// side strip (the chat lost its column after rotating the unfolded screen back to landscape).
final class DuoSafeInsetsTests: XCTestCase {
    private let cover = CGSize(width: 466.0, height: 678.0)
    private let coverLandscape = CGSize(width: 678.0, height: 466.0)
    private let inner = CGSize(width: 669.0, height: 951.0)
    private let innerLandscape = CGSize(width: 951.0, height: 669.0)

    func test_coverPortrait_right84() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.cover, orientation: .portrait), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_coverLandscapeLeft_right84() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.coverLandscape, orientation: .landscapeLeft), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    func test_coverLandscapeRight_left84() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.coverLandscape, orientation: .landscapeRight), UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))
    }

    func test_innerLandscape_bothSides_right84() {
        for orientation: UIInterfaceOrientation in [.landscapeLeft, .landscapeRight] {
            XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.innerLandscape, orientation: orientation), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
        }
    }

    func test_innerPortrait_top82() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.inner, orientation: .portrait), UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0))
    }

    func test_innerLandscapeSize_withStalePortraitOrientation_stillLandscape() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.innerLandscape, orientation: .portrait), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }

    // Postures the table does not know keep the live system insets.

    func test_upsideDown_coverNil_innerAsPortrait() {
        // The cover screen refuses upside-down; the simulator's unfolded portrait reports it, with the portrait insets.
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: self.inner, orientation: .portraitUpsideDown), UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0))
        XCTAssertNil(iPhoneDuoSafeInsets(windowSize: self.cover, orientation: .portraitUpsideDown))
    }

    func test_statusBarHeight_neverBelowTopInset() {
        // Unfolded portrait: a 2pt status bar sliver beside the 82pt corner block.
        XCTAssertEqual(iPhoneDuoStatusBarHeight(systemHeight: 2.0, safeInsetTop: 82.0), 82.0)
        // Folded: no top inset, the system height stands.
        XCTAssertEqual(iPhoneDuoStatusBarHeight(systemHeight: 0.0, safeInsetTop: 0.0), 0.0)
        XCTAssertEqual(iPhoneDuoStatusBarHeight(systemHeight: 20.0, safeInsetTop: 0.0), 20.0)
        XCTAssertNil(iPhoneDuoStatusBarHeight(systemHeight: nil, safeInsetTop: 82.0))
    }

    func test_coverLandscape_unknownSide_nil() {
        XCTAssertNil(iPhoneDuoSafeInsets(windowSize: self.coverLandscape, orientation: .portrait))
    }

    func test_windowOfAnotherSize_nil() {
        XCTAssertNil(iPhoneDuoSafeInsets(windowSize: CGSize(width: 475.0, height: 669.0), orientation: .landscapeLeft))
        XCTAssertNil(iPhoneDuoSafeInsets(windowSize: CGSize(width: 402.0, height: 874.0), orientation: .portrait))
    }

    func test_sizeWithinOnePoint_matches() {
        XCTAssertEqual(iPhoneDuoSafeInsets(windowSize: CGSize(width: 466.4, height: 677.6), orientation: .portrait), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
    }
}
