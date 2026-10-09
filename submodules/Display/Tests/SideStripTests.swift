import XCTest
import UIKit
@testable import Display

final class SideStripTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private func corners(topLeft: CGSize? = nil, topRight: CGSize? = nil, bottomLeft: CGSize? = nil, bottomRight: CGSize? = nil) -> ContainerViewLayoutCorners {
        return ContainerViewLayoutCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }

    // The measured cover and inner postures (reserved-corners spec).

    func test_coverPortrait_rightStripBelowTheBlock() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(topRight: CGSize(width: 84.0, height: 170.0)))
        XCTAssertEqual(l.sideStrip(edge: .right), CGRect(x: 382.0, y: 170.0, width: 84.0, height: 508.0))
        XCTAssertNil(l.sideStrip(edge: .left))
    }

    func test_coverLandscapeLeft_rightStripAboveTheBlock() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(bottomRight: CGSize(width: 84.0, height: 82.0)))
        XCTAssertEqual(l.sideStrip(edge: .right), CGRect(x: 594.0, y: 0.0, width: 84.0, height: 384.0))
    }

    func test_coverLandscapeRight_leftStripBelowTheBlock() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: self.corners(topLeft: CGSize(width: 84.0, height: 84.0)))
        XCTAssertEqual(l.sideStrip(edge: .left), CGRect(x: 0.0, y: 84.0, width: 84.0, height: 382.0))
        XCTAssertNil(l.sideStrip(edge: .right))
    }

    func test_unfoldedLandscapeFullWidth_rightStripBelowTheBlock() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertEqual(l.sideStrip(edge: .right), CGRect(x: 867.0, y: 120.0, width: 84.0, height: 549.0))
    }

    func test_unfoldedPortrait_topInsetOnly_none() {
        let l = self.layout(size: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 34.0, right: 0.0), corners: self.corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertNil(l.sideStrip(edge: .right))
        XCTAssertNil(l.sideStrip(edge: .left))
    }

    // The rule's edges.

    func test_insetWithoutCorners_none() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: .none)
        XCTAssertNil(l.sideStrip(edge: .right))
    }

    func test_blockOfAnotherWidth_none() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(topRight: CGSize(width: 134.0, height: 82.0)))
        XCTAssertNil(l.sideStrip(edge: .right))
    }

    func test_zeroInsetWithBlock_none() {
        let l = self.layout(size: CGSize(width: 320.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0), corners: self.corners(topRight: CGSize(width: 84.0, height: 120.0)))
        XCTAssertNil(l.sideStrip(edge: .right))
    }

    func test_blocksAtBothEnds_stripBetweenThem() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(topRight: CGSize(width: 84.0, height: 100.0), bottomRight: CGSize(width: 84.0, height: 50.0)))
        XCTAssertEqual(l.sideStrip(edge: .right), CGRect(x: 382.0, y: 100.0, width: 84.0, height: 528.0))
    }

    func test_blocksCoverTheWholeEdge_none() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: self.corners(topRight: CGSize(width: 84.0, height: 400.0), bottomRight: CGSize(width: 84.0, height: 300.0)))
        XCTAssertNil(l.sideStrip(edge: .right))
    }
}
