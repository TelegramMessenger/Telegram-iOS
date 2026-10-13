import UIKit
import XCTest
@testable import CoreListDemo

/// A horizontal inset change is the only pass that changes a row's WIDTH. Rows anchor at
/// `(0, 0)` (`CoreVirtualListView.swift:2544/2886`), so `position.x` is the row's left edge and a
/// width change moves no position — `bounds.size.width` animating from the left edge is the whole
/// mechanism. If that track is missing, the row's far edge snaps.
final class WidthTrackOnInsetChangeTests: XCTestCase {
    private func fixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                           items: (0..<8).map { FixedHeightItem(height: CGFloat(40 + $0)) })
    }

    func testRightInsetChangeCreatesAWidthTrack() {
        let f = fixture()
        let identity = f.listView.items[0].identity
        let before = f.frame(identity: identity)

        f.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 92),
                                transition: .linear(duration: 0.3))

        let after = f.frame(identity: identity)
        XCTAssertEqual(before?.minX, after?.minX, "precondition: right inset leaves the left edge put")
        XCTAssertEqual((before?.width ?? 0) - (after?.width ?? 0), 92, accuracy: 0.5,
                       "precondition: the width shrinks by the inset")

        let model = f.listView.animationController.model
        let track = model.track(for: .live(identity), property: .width)
        XCTAssertNotNil(track, "the row's width must animate, or its far edge snaps")
        if let track {
            XCTAssertEqual(track.from, before?.width ?? 0, accuracy: 0.5)
            XCTAssertEqual(track.to, after?.width ?? 0, accuracy: 0.5)
        }
    }
}
