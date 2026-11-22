import XCTest
import UIKit
import Display
import SideColumnLayout

final class SideColumnPlacementChangeTests: XCTestCase {
    private let portrait = SideColumnRegion(edge: .right, frame: CGRect(x: 396.0, y: 178.0, width: 48.0, height: 234.0))
    private let landscapeLeft = SideColumnRegion(edge: .right, frame: CGRect(x: 608.0, y: 8.0, width: 48.0, height: 124.0))
    private let landscapeRight = SideColumnRegion(edge: .left, frame: CGRect(x: 22.0, y: 92.0, width: 48.0, height: 108.0))

    func test_noColumnBeforeOrAfter_none() {
        XCTAssertEqual(sideColumnPlacementChange(from: nil, to: nil), .none)
    }

    func test_folding_appear() {
        XCTAssertEqual(sideColumnPlacementChange(from: nil, to: self.portrait), .appear)
    }

    func test_unfolding_disappear() {
        XCTAssertEqual(sideColumnPlacementChange(from: self.portrait, to: nil), .disappear)
    }

    func test_sameEdgeAndX_animate() {
        // The tab bar's reservation changing: same place, another length.
        let shorter = SideColumnRegion(edge: .right, frame: CGRect(x: 396.0, y: 178.0, width: 48.0, height: 478.0))
        XCTAssertEqual(sideColumnPlacementChange(from: self.portrait, to: shorter), .animate)
    }

    func test_rotationAlongTheSameEdge_move() {
        XCTAssertEqual(sideColumnPlacementChange(from: self.portrait, to: self.landscapeLeft), .move)
    }

    func test_stripSwitchingSides_move() {
        XCTAssertEqual(sideColumnPlacementChange(from: self.landscapeLeft, to: self.landscapeRight), .move)
    }
}
