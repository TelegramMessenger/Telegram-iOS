import XCTest
import UIKit
import SideColumnLayout

/// Which ItemList bar buttons go into iPhone Duo's side column (ItemList spec, section 1.1).
final class SideColumnBarSplitTests: XCTestCase {
    func test_pushed_backOnly() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: nil, right: []), SideColumnBarSplit(top: .navigation, capsule: [], confirm: nil, keepsLeftInTopRow: false, topRowRightIndices: []))
    }

    func test_pushed_backAndTextEdit_editStaysInTheRow() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: nil, right: [.text]), SideColumnBarSplit(top: .navigation, capsule: [], confirm: nil, keepsLeftInTopRow: false, topRowRightIndices: [0]))
    }

    func test_firstInDetailPane_close() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .close, left: nil, right: [])?.top, .navigation)
    }

    func test_root_allText_nothingMoves() {
        XCTAssertNil(sideColumnBarSplit(navigation: .none, left: nil, right: [.text]))
    }

    func test_root_noButtons_nothingMoves() {
        XCTAssertNil(sideColumnBarSplit(navigation: .none, left: nil, right: []))
    }

    func test_modalEditor_closeXAndCheckmark() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .none, left: .close, right: [.confirm]), SideColumnBarSplit(top: .left, capsule: [], confirm: .right(index: 0), keepsLeftInTopRow: false, topRowRightIndices: []))
    }

    func test_cancelTextAndCheckmark_cancelStaysInTheRow() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: .text, right: [.confirm]), SideColumnBarSplit(top: nil, capsule: [], confirm: .right(index: 0), keepsLeftInTopRow: true, topRowRightIndices: []))
    }

    func test_leftSpacer_staysInTheRow() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: .spacer, right: [.icon]), SideColumnBarSplit(top: nil, capsule: [.right(index: 0)], confirm: nil, keepsLeftInTopRow: true, topRowRightIndices: []))
    }

    func test_icons_leftFirstThenRightInOrder() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: .icon, right: [.icon, .icon])?.capsule, [.left, .right(index: 0), .right(index: 1)])
    }

    func test_leftCheckmark_takesTheAccentCircle_noBack() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: .confirm, right: [.text]), SideColumnBarSplit(top: nil, capsule: [], confirm: .left, keepsLeftInTopRow: false, topRowRightIndices: [0]))
    }

    func test_twoCheckmarks_secondJoinsTheCapsule() {
        let split = sideColumnBarSplit(navigation: .none, left: nil, right: [.confirm, .confirm])
        XCTAssertEqual(split?.confirm, .right(index: 0))
        XCTAssertEqual(split?.capsule, [.right(index: 1)])
    }

    func test_rightClose_joinsTheCapsule() {
        XCTAssertEqual(sideColumnBarSplit(navigation: .back, left: nil, right: [.close])?.capsule, [.right(index: 0)])
    }

    func test_textAndIcon_textStaysIconMoves() {
        let split = sideColumnBarSplit(navigation: .back, left: nil, right: [.text, .icon])
        XCTAssertEqual(split?.topRowRightIndices, [0])
        XCTAssertEqual(split?.capsule, [.right(index: 1)])
    }
}
