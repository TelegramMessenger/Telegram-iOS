import XCTest
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
@testable import ComposerHarnessLib

/// An inline bot's placeholder (`botInfo.inlinePlaceholder`, "Search..." once "@bot " is typed) is one line the panel draws
/// over the field (`ChatTextInputPanelNode.contextPlaceholderNode`): the typed username in a clear colour, then the
/// placeholder, truncated at its end. The chat shows it with the search layout's clear button (`extendedSearchLayout`) and
/// the input-mode button.
///
/// **What broke** (seen on the "iPhone 18 Pro" simulator with the test servers' Widget Bot, 2026-10-28): the line was laid
/// out to the panel's width less the field's insets and the accessory buttons only, not the clear button's slot, so
/// "Search..." ran on under the emoji button. It must end where the field's buttons begin, as the field's own placeholder
/// does.
///
/// **Tier 1**: the defect is the panel's layout, which the hosted panel lays out with the chat's own code; no touch path is
/// involved.
final class HarnessInlinePlaceholderTests: XCTestCase {
    func testTheInlinePlaceholderEndsBeforeTheFieldsButtons() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let username = "@asmico_widget_bot"
        host.setInputContent(ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run(username + " ")])]))

        // As `inputTextPanelStateForChatPresentationInterfaceState` builds it, with a placeholder long enough to reach the
        // buttons at any text size.
        let font = UIFont.systemFont(ofSize: 17.0)
        let placeholder = NSMutableAttributedString(string: username, attributes: [.font: font, .foregroundColor: UIColor.clear])
        placeholder.append(NSAttributedString(string: " Search the bot's widgets, polls and tickers", attributes: [.font: font, .foregroundColor: UIColor.gray]))
        let accessoryItems: [ChatTextInputAccessoryItem] = [.input(isEnabled: true, inputMode: .emoji)]
        var originalPanelState = ChatTextInputPanelState()
        host.updatePresentationInterfaceState { state in
            originalPanelState = state.inputTextPanelState
            return state.updatedInputTextPanelState { _ in
                return ChatTextInputPanelState(accessoryItems: accessoryItems, contextPlaceholder: placeholder, mediaRecordingState: nil)
            }
        }
        // The next layout pass reads the panel state from the interface state, so a later case in this process would
        // inherit the placeholder, the button and the search layout: put back what the panel had.
        defer {
            host.updatePresentationInterfaceState { $0.updatedInputTextPanelState { _ in originalPanelState } }
            host.setInputContent(ChatInputContent())
            HarnessEngine.settle(root)
        }
        // As `ChatControllerNode` passes it while a bot's inline results are open.
        host.panel.updateInputTextState(host.panel.inputTextState, keepSendButtonEnabled: false, extendedSearchLayout: true, accessoryItems: accessoryItems, animated: false)
        HarnessEngine.settle(root)

        let placeholderNode = try XCTUnwrap(host.panel.contextPlaceholderNode, "the panel shows no inline placeholder")
        let container = try XCTUnwrap(placeholderNode.view.superview)
        let placeholderFrame = placeholderNode.frame
        XCTAssertGreaterThan(placeholderFrame.width, 100.0, "precondition: the placeholder is not laid out: \(placeholderFrame)")

        // The input-mode button and the clear button, both in the placeholder's container, on its row (one line of text).
        let inputButtons = container.subviews.filter { String(describing: type(of: $0)) == "AccessoryItemIconButton" && !$0.isHidden && $0.alpha > 0.01 }
        let inputButton = try XCTUnwrap(inputButtons.min(by: { $0.frame.minX < $1.frame.minX }), "precondition: the field shows no accessory button")
        let clearButton = host.panel.searchLayoutClearButton
        XCTAssertTrue(clearButton.superview != nil && !clearButton.isHidden && clearButton.alpha > 0.01, "precondition: the search layout's clear button is not shown")
        let clearFrame = container.convert(clearButton.bounds, from: clearButton)

        // The line ends where the field's own placeholder does: at the input-mode button's frame plus the 2 pt of its
        // icon's padding the panel gives back to `.input` (`nextButtonTopRight`), and before the clear button.
        XCTAssertLessThanOrEqual(placeholderFrame.maxX, inputButton.frame.minX + 2.5, "the placeholder \(placeholderFrame) runs under the input-mode button \(inputButton.frame)")
        XCTAssertLessThanOrEqual(placeholderFrame.maxX, clearFrame.minX, "the placeholder \(placeholderFrame) runs under the clear button \(clearFrame)")
    }
}
