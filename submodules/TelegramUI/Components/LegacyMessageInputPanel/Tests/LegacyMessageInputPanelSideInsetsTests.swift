import XCTest
import UIKit
import Display
import LegacyMessageInputPanel

final class LegacyMessageInputPanelSideInsetsTests: XCTestCase {
    // iPhone Duo, folded portrait (466x678): the right strip exists only because of the 84x170 status corner block.
    private let foldedPortraitSafeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
    private let foldedPortraitCorners = ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)

    private func insets(from minY: CGFloat, to maxY: CGFloat, height: CGFloat, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> (left: CGFloat, right: CGFloat) {
        return legacyMessageInputPanelSideInsets(forRowsFrom: minY, to: maxY, containerHeight: height, safeInsets: safeInsets, reservedCorners: corners)
    }

    // The caption above the media, being edited: its row at the top runs into the status corner.
    func testDuoFoldedPortraitCaptionAboveKeepsClearOfTheStatusCorner() {
        let result = self.insets(from: 8.0, to: 52.0, height: 678.0, safeInsets: self.foldedPortraitSafeInsets, corners: self.foldedPortraitCorners)
        XCTAssertEqual(result.left, 0.0)
        XCTAssertEqual(result.right, 84.0)
    }

    // The caption below the media, above the keyboard: the strip is free there, so the panel spans it.
    func testDuoFoldedPortraitCaptionBelowSpansTheStrip() {
        let result = self.insets(from: 330.0, to: 374.0, height: 678.0, safeInsets: self.foldedPortraitSafeInsets, corners: self.foldedPortraitCorners)
        XCTAssertEqual(result.left, 0.0)
        XCTAssertEqual(result.right, 0.0)
    }

    // A caption below the media that grows up into the status corner keeps clear of it.
    func testDuoFoldedPortraitTallCaptionBelowKeepsClearOfTheStatusCorner() {
        let result = self.insets(from: 120.0, to: 374.0, height: 678.0, safeInsets: self.foldedPortraitSafeInsets, corners: self.foldedPortraitCorners)
        XCTAssertEqual(result.right, 84.0)
    }

    // Unfolded portrait: the status island is a top inset, not a side strip, so a caption above the media keeps the full
    // width.
    func testDuoUnfoldedPortraitCaptionAboveHasNoSideInsets() {
        let safeInsets = UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil)
        let result = self.insets(from: 90.0, to: 134.0, height: 951.0, safeInsets: safeInsets, corners: corners)
        XCTAssertEqual(result.left, 0.0)
        XCTAssertEqual(result.right, 0.0)
    }

    // Every other device: the panel spans the container's full width whatever the safe insets, as it always has.
    func testWithoutReservedCornersThePanelSpansTheFullWidth() {
        let landscape = UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)
        let result = self.insets(from: 8.0, to: 52.0, height: 402.0, safeInsets: landscape, corners: .none)
        XCTAssertEqual(result.left, 0.0)
        XCTAssertEqual(result.right, 0.0)
        let portrait = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let portraitResult = self.insets(from: 70.0, to: 114.0, height: 874.0, safeInsets: portrait, corners: .none)
        XCTAssertEqual(portraitResult.left, 0.0)
        XCTAssertEqual(portraitResult.right, 0.0)
    }
}
