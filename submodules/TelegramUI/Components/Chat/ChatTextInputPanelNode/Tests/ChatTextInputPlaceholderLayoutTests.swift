import XCTest
@testable import ChatTextInputPanelNode

/// The input field's placeholder ends where the field's buttons begin, wherever its text starts (#116: with the
/// send-as avatar, "Анонимное сообщение" ran under the sticker button, because the width assumed the text started at
/// the field's own 12 pt inset).
final class ChatTextInputPlaceholderLayoutTests: XCTestCase {
    // `textInputViewInternalInsets.left`, and that plus the send-as avatar's 31 pt.
    private let plainLeftInset: CGFloat = 12.0
    private let sendAsLeftInset: CGFloat = 12.0 + 31.0

    func testPlaceholderWithoutSendAsAvatarIsUnchanged() {
        XCTAssertEqual(chatTextInputPlaceholderMaxWidth(textLeftInset: self.plainLeftInset, buttonsMinX: 250.0), 238.0)
    }

    func testPlaceholderAfterSendAsAvatarEndsAtTheButtons() {
        let buttonsMinX: CGFloat = 250.0
        let width = chatTextInputPlaceholderMaxWidth(textLeftInset: self.sendAsLeftInset, buttonsMinX: buttonsMinX)
        XCTAssertEqual(width, 207.0)
        XCTAssertEqual(self.sendAsLeftInset + width, buttonsMinX)
    }

    func testPlaceholderKeepsAPositiveWidthWithoutRoom() {
        XCTAssertEqual(chatTextInputPlaceholderMaxWidth(textLeftInset: self.sendAsLeftInset, buttonsMinX: 20.0), 1.0)
    }
}
