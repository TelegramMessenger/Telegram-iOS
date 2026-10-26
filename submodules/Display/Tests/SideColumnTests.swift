import XCTest
import UIKit
@testable import Display

final class SideColumnTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private var coverPortrait: ContainerViewLayout {
        return self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
    }
    private var coverLandscapeLeft: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
    }
    private var coverLandscapeRight: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
    }
    private var unfoldedDetailPane: ContainerViewLayout {
        return self.layout(size: CGSize(width: 631.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
    }

    // sideInsets(forBandFrom:to:)

    func test_bandInsets_coverPortraitBottom_rightFree() {
        let insets = self.coverPortrait.sideInsets(forBandFrom: 600.0, to: 644.0)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }

    func test_bandInsets_coverPortraitTop_rightReserved() {
        XCTAssertEqual(self.coverPortrait.sideInsets(forBandFrom: 0.0, to: 60.0).right, 84.0)
    }

    func test_bandInsets_coverLandscapeLeftBottom_rightReservedByTheBottomBlock() {
        XCTAssertEqual(self.coverLandscapeLeft.sideInsets(forBandFrom: 390.0, to: 432.0).right, 84.0)
    }

    func test_bandInsets_coverLandscapeRightBottom_leftFree() {
        XCTAssertEqual(self.coverLandscapeRight.sideInsets(forBandFrom: 390.0, to: 432.0).left, 0.0)
    }

    func test_bandInsets_unfoldedDetailPaneBottom_rightFree() {
        XCTAssertEqual(self.unfoldedDetailPane.sideInsets(forBandFrom: 590.0, to: 635.0).right, 0.0)
    }

    func test_bandInsets_noCorners_safeInsets() {
        let l = self.layout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), corners: .none)
        let insets = l.sideInsets(forBandFrom: 330.0, to: 380.0)
        XCTAssertEqual(insets.left, 62.0)
        XCTAssertEqual(insets.right, 62.0)
    }

    func test_bandInsets_insetWithAnotherCause_safeInset() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(l.sideInsets(forBandFrom: 600.0, to: 644.0).right, 84.0)
    }

    // sideColumnFrames(itemSize:spacing:count:minY:)

    private let circle = CGSize(width: 48.0, height: 48.0)

    func test_column_unfoldedDetailPane_underTheBlock() {
        let column = self.unfoldedDetailPane.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 3, minY: 8.0)
        XCTAssertEqual(column?.edge, .right)
        XCTAssertEqual(column?.frames, [
            CGRect(x: 561.0, y: 128.0, width: 48.0, height: 48.0),
            CGRect(x: 561.0, y: 188.0, width: 48.0, height: 48.0),
            CGRect(x: 561.0, y: 248.0, width: 48.0, height: 48.0)
        ])
    }

    func test_column_coverPortrait_underTheClock() {
        let column = self.coverPortrait.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 3, minY: 8.0)
        XCTAssertEqual(column?.edge, .right)
        XCTAssertEqual(column?.frames.first, CGRect(x: 396.0, y: 178.0, width: 48.0, height: 48.0))
        XCTAssertEqual(column?.frames.last, CGRect(x: 396.0, y: 298.0, width: 48.0, height: 48.0))
    }

    func test_column_coverLandscapeLeft_noBlockAbove_startsAtMinY() {
        let column = self.coverLandscapeLeft.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 3, minY: 20.0)
        XCTAssertEqual(column?.edge, .right)
        XCTAssertEqual(column?.frames.first, CGRect(x: 608.0, y: 20.0, width: 48.0, height: 48.0))
    }

    func test_column_coverLandscapeRight_leftStrip() {
        let column = self.coverLandscapeRight.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 2, minY: 8.0)
        XCTAssertEqual(column?.edge, .left)
        XCTAssertEqual(column?.frames, [
            CGRect(x: 22.0, y: 92.0, width: 48.0, height: 48.0),
            CGRect(x: 22.0, y: 152.0, width: 48.0, height: 48.0)
        ])
    }

    func test_column_minYBelowTheBlock_wins() {
        XCTAssertEqual(self.coverPortrait.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 1, minY: 200.0)?.frames.first?.minY, 200.0)
    }

    func test_column_noStrip_nil() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none)
        XCTAssertNil(l.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 3, minY: 8.0))
    }

    func test_column_doesNotFitAboveTheBottomBlock_nil() {
        // 7 * 48 + 6 * 12 = 408 from y 20 ends at 428, past 384 - 8.
        XCTAssertNil(self.coverLandscapeLeft.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 7, minY: 20.0))
    }

    func test_column_noItems_nil() {
        XCTAssertNil(self.coverPortrait.sideColumnFrames(itemSize: self.circle, spacing: 12.0, count: 0, minY: 8.0))
    }
}
