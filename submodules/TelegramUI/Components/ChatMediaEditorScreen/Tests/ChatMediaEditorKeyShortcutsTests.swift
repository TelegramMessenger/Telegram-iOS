import Foundation
import UIKit
import XCTest
import ChatMediaEditorScreen

final class ChatMediaEditorKeyShortcutsTests: XCTestCase {
    private func returnFocusesCaption(
        hasCaptionPanel: Bool = true,
        hasFirstResponder: Bool = false,
        toolbarSide: ChatMediaEditorToolbarSide? = nil,
        isToolActive: Bool = false,
        isSending: Bool = false,
        isDismissing: Bool = false
    ) -> Bool {
        return chatMediaEditorReturnFocusesCaption(
            hasCaptionPanel: hasCaptionPanel,
            hasFirstResponder: hasFirstResponder,
            toolbarSide: toolbarSide,
            isToolActive: isToolActive,
            isSending: isSending,
            isDismissing: isDismissing
        )
    }

    func testReturnFocusesCaptionWhenNothingIsFocused() {
        XCTAssertTrue(self.returnFocusesCaption())
    }

    func testReturnFocusesCaptionOnTabletInLandscape() {
        // The reported device: an iPad never moves the toolbar to the side, so the caption stays usable.
        let toolbarSide = chatMediaEditorToolbarSide(size: CGSize(width: 1366.0, height: 1024.0), orientation: .landscapeLeft, isTablet: true)
        XCTAssertTrue(self.returnFocusesCaption(toolbarSide: toolbarSide))
    }

    func testReturnKeepsTheFocusedFieldsOwnBehaviour() {
        // The caption itself, a text sticker or any other text field already has the keyboard.
        XCTAssertFalse(self.returnFocusesCaption(hasFirstResponder: true))
    }

    func testReturnDoesNothingWithoutACaptionPanel() {
        XCTAssertFalse(self.returnFocusesCaption(hasCaptionPanel: false))
    }

    func testReturnDoesNothingWhileTheCaptionIsHidden() {
        XCTAssertFalse(self.returnFocusesCaption(toolbarSide: .right))
        XCTAssertFalse(self.returnFocusesCaption(toolbarSide: .left))
        XCTAssertFalse(self.returnFocusesCaption(isToolActive: true))
    }

    func testReturnDoesNothingWhileSendingOrDismissing() {
        XCTAssertFalse(self.returnFocusesCaption(isSending: true))
        XCTAssertFalse(self.returnFocusesCaption(isDismissing: true))
    }
}
