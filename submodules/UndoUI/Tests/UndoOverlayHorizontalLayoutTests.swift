import XCTest
import UIKit
@testable import UndoUI

final class UndoOverlayHorizontalLayoutTests: XCTestCase {
    private let margin: CGFloat = 12.0
    private let leadingInset: CGFloat = 50.0
    private let trailingInset: CGFloat = 16.0
    private let buttonWidth: CGFloat = 64.0

    private func layout(width: CGFloat, safeInsets: UIEdgeInsets, intrinsicInsets: UIEdgeInsets, buttonWidth: CGFloat?) -> UndoOverlayHorizontalLayout {
        return undoOverlayHorizontalLayout(width: width, safeInsets: safeInsets, intrinsicInsets: intrinsicInsets, margin: self.margin, leadingInset: self.leadingInset, trailingInset: self.trailingInset, buttonWidth: buttonWidth, isNarrow: false)
    }

    // A chat hands its children the history list's insets with left and right swapped, so on the Duo the
    // presenting context's intrinsic insets carry the side strip on the opposite side.
    private func chatIntrinsicInsets(safeInsets: UIEdgeInsets) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0.0, left: safeInsets.right, bottom: 0.0, right: safeInsets.left)
    }

    private func assertFitsBand(_ result: UndoOverlayHorizontalLayout, width: CGFloat, safeInsets: UIEdgeInsets, buttonWidth: CGFloat?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.panelX, safeInsets.left + self.margin, file: file, line: line)
        XCTAssertEqual(result.panelWidth, width - safeInsets.left - safeInsets.right - self.margin * 2.0, file: file, line: line)
        var textMaxX = self.leadingInset + result.textMaxWidth
        if let buttonWidth {
            textMaxX += 8.0 + buttonWidth + self.trailingInset
        }
        XCTAssertLessThanOrEqual(textMaxX, result.panelWidth, file: file, line: line)
    }

    func testDuoFoldedPortraitInChatKeepsTheTextWidth() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let result = self.layout(width: 466.0, safeInsets: safeInsets, intrinsicInsets: self.chatIntrinsicInsets(safeInsets: safeInsets), buttonWidth: self.buttonWidth)
        // The same width as on a 382pt phone without side insets.
        XCTAssertEqual(result.textMaxWidth, 382.0 - 24.0 - 16.0 - 64.0 - 8.0 - 50.0 - 12.0)
        self.assertFitsBand(result, width: 466.0, safeInsets: safeInsets, buttonWidth: self.buttonWidth)
    }

    func testDuoFoldedPortraitInChatWithoutButtonStaysInsideThePanel() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let result = self.layout(width: 466.0, safeInsets: safeInsets, intrinsicInsets: self.chatIntrinsicInsets(safeInsets: safeInsets), buttonWidth: nil)
        self.assertFitsBand(result, width: 466.0, safeInsets: safeInsets, buttonWidth: nil)
    }

    // A forum's side topics panel adds to the list's leading inset, which lands on the context's right.
    func testDuoFoldedPortraitInChatWithSideTopicsPanel() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let result = self.layout(width: 466.0, safeInsets: safeInsets, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 92.0), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result.textMaxWidth, 382.0 - 24.0 - 16.0 - 64.0 - 8.0 - 50.0 - 12.0)
        self.assertFitsBand(result, width: 466.0, safeInsets: safeInsets, buttonWidth: self.buttonWidth)
    }
    
    func testDuoFoldedLandscapeRightInChat() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0)
        let result = self.layout(width: 678.0, safeInsets: safeInsets, intrinsicInsets: self.chatIntrinsicInsets(safeInsets: safeInsets), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result.textMaxWidth, 594.0 - 24.0 - 16.0 - 64.0 - 8.0 - 50.0 - 12.0)
        self.assertFitsBand(result, width: 678.0, safeInsets: safeInsets, buttonWidth: self.buttonWidth)
    }

    func testDuoUnfoldedLandscapeInChat() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let result = self.layout(width: 951.0, safeInsets: safeInsets, intrinsicInsets: self.chatIntrinsicInsets(safeInsets: safeInsets), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result.textMaxWidth, 867.0 - 24.0 - 16.0 - 64.0 - 8.0 - 50.0 - 12.0)
        self.assertFitsBand(result, width: 951.0, safeInsets: safeInsets, buttonWidth: self.buttonWidth)
    }

    func testDuoOutsideChat() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let result = self.layout(width: 466.0, safeInsets: safeInsets, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 0.0), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result.textMaxWidth, 382.0 - 24.0 - 16.0 - 64.0 - 8.0 - 50.0 - 12.0)
        self.assertFitsBand(result, width: 466.0, safeInsets: safeInsets, buttonWidth: self.buttonWidth)
    }

    // Equal side insets keep the previous metrics, which take the context's left inset on both sides on top of the
    // safe insets.
    func testPhonePortraitUnchanged() {
        let result = self.layout(width: 402.0, safeInsets: .zero, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result, UndoOverlayHorizontalLayout(sideMargin: 12.0, panelX: 12.0, panelWidth: 378.0, textMaxWidth: 228.0))
    }

    func testPhoneLandscapeInChatUnchanged() {
        let safeInsets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0)
        let result = self.layout(width: 874.0, safeInsets: safeInsets, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), buttonWidth: self.buttonWidth)
        XCTAssertEqual(result, UndoOverlayHorizontalLayout(sideMargin: 74.0, panelX: 136.0, panelWidth: 602.0, textMaxWidth: 390.0))
    }

    // A forum's side topics panel widens one side of a chat's list; only the context's left inset was used.
    func testPhoneChatWithFloatingTopicsPanelUnchanged() {
        let result = self.layout(width: 402.0, safeInsets: .zero, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 72.0), buttonWidth: nil)
        XCTAssertEqual(result, UndoOverlayHorizontalLayout(sideMargin: 12.0, panelX: 12.0, panelWidth: 378.0, textMaxWidth: 402.0 - 16.0 - 8.0 - 50.0 - 12.0))
    }
}
