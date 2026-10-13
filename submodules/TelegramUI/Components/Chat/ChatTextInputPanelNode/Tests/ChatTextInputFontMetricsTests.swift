import XCTest
import UIKit
import Display
import TextFormat
import TelegramUIPreferences
import TelegramPresentationData
import ChatInputTextNode
@testable import ChatTextInputPanelNode

/// The legacy composer follows Settings ▸ Appearance ▸ Text Size in ONE place. Before this, the panel read
/// the font size at fourteen sites and eight of them (inherited from upstream) carried an always-true
/// `if "".isEmpty { baseFontSize = 17.0 }` pin — the placeholder font, the empty-field minimum height, the
/// vertical text insets and the initial rendering config — while the per-keystroke re-decoration did not.
/// So typed text scaled on the first keystroke, the placeholder stayed 17pt, and an empty field opened at
/// the 17pt minimum and then animated up to the scaled height once the text node loaded.
final class ChatTextInputFontMetricsTests: XCTestCase {
    /// Not pinned: every step is its own display size.
    func testBaseFontSizeFollowsTextSizeAtEveryStep() {
        for step in PresentationFontSize.allCases {
            XCTAssertEqual(chatTextInputBaseFontSize(for: step), step.baseDisplaySize, "\(step)")
        }
    }

    /// The minimum height IS what an empty field settles at: the legacy text view measuring one line of the
    /// typing font plus the vertical insets, floored at the 17pt minimum of 31. If these two disagree the field
    /// opens at one height and animates to the other as soon as the text node loads — the reported jump.
    func testMinHeightIsTheSettledHeightOfAnEmptyField() {
        for step in PresentationFontSize.allCases {
            let baseFontSize = chatTextInputBaseFontSize(for: step)
            let textView = ChatInputTextView(disableTiling: true)
            textView.textContainerInset = chatTextInputFieldVerticalInsets(for: step)
            refreshChatTextInputTypingAttributes(textView, textColor: .black, baseFontSize: baseFontSize)
            let settled = max(31.0, textView.textHeightForWidth(300.0, rightInset: 0.0))

            XCTAssertEqual(chatTextInputFieldMinHeight(for: step), settled, "\(step): min height must equal the empty field's measured height")
        }
    }

    /// The 17pt step is exactly today's geometry, so the regular case does not move.
    func testRegularStepIsUnchanged() {
        XCTAssertEqual(chatTextInputBaseFontSize(for: .regular), 17.0)
        XCTAssertEqual(chatTextInputFieldMinHeight(for: .regular), 31.0)
        XCTAssertEqual(chatTextInputFieldVerticalInsets(for: .regular), UIEdgeInsets(top: 4.5, left: 0.0, bottom: 5.5, right: 0.0))
    }
}
