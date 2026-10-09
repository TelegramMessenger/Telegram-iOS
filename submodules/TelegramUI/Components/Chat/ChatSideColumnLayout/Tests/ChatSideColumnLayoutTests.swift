import XCTest
import UIKit
import Display
import ChatSideColumnLayout

final class ChatSideColumnLayoutTests: XCTestCase {
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
    private var iPhone: ContainerViewLayout {
        return self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none)
    }

    // Which item goes where.

    func test_assignment_detailRootGroup_closeSearchAvatar() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .close, left: nil, right: [.avatar]), ChatSideColumnAssignment(column: [.close, .addedSearch, .right(index: 0)], keepsLeftInTopRow: false, topRowRightIndices: []))
    }

    func test_assignment_pushedChat_backSearchAvatar() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: nil, right: [.avatar]).column, [.back, .addedSearch, .right(index: 0)])
    }

    func test_assignment_savedMessages_noSecondSearch() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: nil, right: [.search]).column, [.back, .right(index: 0)])
    }

    func test_assignment_forum_moreThenSearchBeforeTheAvatar() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: nil, right: [.icon, .avatar]).column, [.back, .right(index: 0), .addedSearch, .right(index: 1)])
    }

    func test_assignment_selectionMode_textInTheTopRow_emptyColumn() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: .text, right: [.text]), ChatSideColumnAssignment(column: [], keepsLeftInTopRow: true, topRowRightIndices: [0]))
    }

    func test_assignment_editMode_backInTheColumn_editInTheTopRow() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: nil, right: [.text]), ChatSideColumnAssignment(column: [.back], keepsLeftInTopRow: false, topRowRightIndices: [0]))
    }

    func test_assignment_noPreviousItem_searchAndAvatar() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .none, left: nil, right: [.avatar]).column, [.addedSearch, .right(index: 0)])
    }

    func test_assignment_spacerOnTheRight_staysInTheTopRow() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: nil, right: [.empty]), ChatSideColumnAssignment(column: [.back], keepsLeftInTopRow: false, topRowRightIndices: [0]))
    }

    func test_assignment_leftIcon_replacesBackInTheColumn() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: .icon, right: [.avatar]).column, [.left, .addedSearch, .right(index: 0)])
    }

    func test_assignment_leftSearch_noSecondSearch() {
        XCTAssertEqual(chatSideColumnAssignment(navigation: .back, left: .search, right: [.avatar]).column, [.left, .right(index: 0)])
    }

    // What an item is.

    func test_kind_title_text() {
        XCTAssertEqual(chatSideColumnItemKind(title: "Cancel", hasImage: false, hasCustomNode: false, isAvatar: false, isSearch: false), .text)
    }

    func test_kind_blankTitle_empty() {
        XCTAssertEqual(chatSideColumnItemKind(title: " ", hasImage: false, hasCustomNode: false, isAvatar: false, isSearch: false), .empty)
        XCTAssertEqual(chatSideColumnItemKind(title: nil, hasImage: false, hasCustomNode: false, isAvatar: false, isSearch: false), .empty)
    }

    func test_kind_imageOrNode_icon() {
        XCTAssertEqual(chatSideColumnItemKind(title: nil, hasImage: true, hasCustomNode: false, isAvatar: false, isSearch: false), .icon)
        XCTAssertEqual(chatSideColumnItemKind(title: nil, hasImage: false, hasCustomNode: true, isAvatar: false, isSearch: false), .icon)
    }

    func test_kind_avatarAndSearch_win() {
        XCTAssertEqual(chatSideColumnItemKind(title: nil, hasImage: false, hasCustomNode: true, isAvatar: true, isSearch: false), .avatar)
        XCTAssertEqual(chatSideColumnItemKind(title: nil, hasImage: true, hasCustomNode: false, isAvatar: false, isSearch: true), .search)
    }

    func test_stripEdge_rightThenLeftThenNone() {
        XCTAssertEqual(chatSideColumnStripEdge(self.coverPortrait), .right)
        XCTAssertEqual(chatSideColumnStripEdge(self.coverLandscapeRight), .left)
        XCTAssertNil(chatSideColumnStripEdge(self.iPhone))
    }

    // How the column moves between two layout passes.

    private let rightColumn = [CGRect(x: 396.0, y: 178.0, width: 48.0, height: 48.0)]

    func test_move_nothingLaidOutBefore_immediate() {
        // New slots start at a zero frame: animating from it flies them in from the top-left corner.
        XCTAssertEqual(chatSideColumnMove(previousFrames: [], previousContainerSize: nil, frames: self.rightColumn, containerSize: CGSize(width: 466.0, height: 678.0)), .immediate)
    }

    func test_move_sameContainerSameEdge_animate() {
        XCTAssertEqual(chatSideColumnMove(previousFrames: self.rightColumn, previousContainerSize: CGSize(width: 466.0, height: 678.0), frames: self.rightColumn, containerSize: CGSize(width: 466.0, height: 678.0)), .animate)
    }

    func test_move_rotation_fade() {
        XCTAssertEqual(chatSideColumnMove(previousFrames: self.rightColumn, previousContainerSize: CGSize(width: 466.0, height: 678.0), frames: [CGRect(x: 608.0, y: 20.0, width: 48.0, height: 48.0)], containerSize: CGSize(width: 678.0, height: 466.0)), .fade)
    }

    func test_move_edgeFlipSameSize_fade() {
        // Cover landscape-left to landscape-right keeps 678x466 but moves the strip to the other side.
        XCTAssertEqual(chatSideColumnMove(previousFrames: [CGRect(x: 608.0, y: 20.0, width: 48.0, height: 48.0)], previousContainerSize: CGSize(width: 678.0, height: 466.0), frames: [CGRect(x: 22.0, y: 92.0, width: 48.0, height: 48.0)], containerSize: CGSize(width: 678.0, height: 466.0)), .fade)
    }

    // The input panel (spec section 5).

    private let portraitColumn: (edge: ContainerViewLayoutSideEdge, frames: [CGRect]) = (.right, [
        CGRect(x: 396.0, y: 178.0, width: 48.0, height: 48.0),
        CGRect(x: 396.0, y: 238.0, width: 48.0, height: 48.0),
        CGRect(x: 396.0, y: 298.0, width: 48.0, height: 48.0)
    ])

    func test_inputPanel_portraitAtTheBottom_runsIntoTheStrip() {
        XCTAssertEqual(chatInputPanelSideInsets(layout: self.coverPortrait, bandMinY: 600.0, bandMaxY: 644.0, column: self.portraitColumn).right, 0.0)
    }

    func test_inputPanel_portraitWithTheKeyboardUp_keepsTheStripBesideTheColumn() {
        // The column ends at 346; a panel from 300 would run under it.
        XCTAssertEqual(chatInputPanelSideInsets(layout: self.coverPortrait, bandMinY: 300.0, bandMaxY: 350.0, column: self.portraitColumn).right, 84.0)
    }

    func test_band_scrollButtonsAboveThePanel_followThePanelIntoTheStrip() {
        // The scroll-to-bottom stack uses the same rule for its own span: below the column it runs in.
        XCTAssertEqual(chatInputPanelSideInsets(layout: self.coverPortrait, bandMinY: 540.0, bandMaxY: 580.0, column: self.portraitColumn).right, 0.0)
    }

    func test_band_scrollButtonsBesideTheColumn_keepTheStrip() {
        XCTAssertEqual(chatInputPanelSideInsets(layout: self.coverPortrait, bandMinY: 250.0, bandMaxY: 290.0, column: self.portraitColumn).right, 84.0)
    }

    func test_inputPanel_landscapeLeft_bottomBlock_keepsTheStrip() {
        XCTAssertEqual(chatInputPanelSideInsets(layout: self.coverLandscapeLeft, bandMinY: 390.0, bandMaxY: 432.0, column: nil).right, 84.0)
    }

    func test_inputPanel_noCorners_safeInsets() {
        let insets = chatInputPanelSideInsets(layout: self.iPhone, bandMinY: 790.0, bandMaxY: 840.0, column: nil)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 0.0)
    }
}
