import XCTest
import UIKit
import Display
import PeerInfoPaneNode

final class PeerInfoSideInsetsTests: XCTestCase {
    private func layout(_ size: CGSize, _ safeInsets: UIEdgeInsets, _ corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_coverPortrait_rightStrip() {
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 466.0, height: 678.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)))
        XCTAssertEqual(insets, PeerInfoSideInsets(base: 16.0, stripLeft: 0.0, stripRight: 84.0, navigationLeft: 0.0, navigationRight: 84.0, sectionLeft: 16.0, sectionRight: 100.0, paneSideInset: 0.0))
    }

    func test_coverLandscapeLeft_rightStripAboveTheBottomBlock() {
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 678.0, height: 466.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))))
        XCTAssertEqual(insets.stripRight, 84.0)
        XCTAssertEqual(insets.sectionRight, 100.0)
        XCTAssertEqual(insets.sectionLeft, 16.0)
    }

    func test_coverLandscapeRight_leftStrip() {
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 678.0, height: 466.0), UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0), ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil)))
        XCTAssertEqual(insets, PeerInfoSideInsets(base: 16.0, stripLeft: 84.0, stripRight: 0.0, navigationLeft: 84.0, navigationRight: 0.0, sectionLeft: 100.0, sectionRight: 16.0, paneSideInset: 0.0))
    }

    func test_unfoldedDetailPane_rightStrip() {
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 631.0, height: 669.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil)))
        XCTAssertEqual(insets.stripRight, 84.0)
        XCTAssertEqual(insets.sectionRight, 100.0)
    }

    func test_notchPhoneLandscape_unchanged() {
        // No corner blocks: everything as today (base 100 beats the 62pt notch inset; panes get the left inset).
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 874.0, height: 402.0), UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), .none))
        XCTAssertEqual(insets, PeerInfoSideInsets(base: 100.0, stripLeft: 0.0, stripRight: 0.0, navigationLeft: 62.0, navigationRight: 62.0, sectionLeft: 100.0, sectionRight: 100.0, paneSideInset: 62.0))
    }

    func test_narrowWidth_zeroBase() {
        let insets = peerInfoSideInsets(layout: self.layout(CGSize(width: 300.0, height: 600.0), UIEdgeInsets(), .none))
        XCTAssertEqual(insets.sectionLeft, 0.0)
        XCTAssertEqual(insets.sectionRight, 0.0)
    }
}
