import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// Shared arrange steps for the seventh roam's LEGACY-backend regression tests, where the legacy
/// composer (`ChatTextInputPanelNode` + `ChatInputTextNode`) is the subject rather than the control.
///
/// Every test that uses `arrange` switches the root to `.legacy`; call `restore(_:)` in a `defer`, since
/// other cases assume the launch arm (`.engine`).
enum HarnessLegacy {
    struct Arranged {
        let root: HarnessRootViewController
        let host: HarnessPanelHost
        let node: ChatRichTextInputNode
        let textView: UITextView
    }

    static func arrange(_ content: ChatInputContent) throws -> Arranged {
        let root = try HarnessEngine.root()
        root.setBackend(.legacy)
        let host = try XCTUnwrap(root.panelHost)
        XCTAssertEqual(host.liveBackend, .legacy, "precondition: the legacy backend is not live")
        let node = try XCTUnwrap(host.panel.richTextInputNode, "precondition: no input node")
        host.setInputContent(content)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try XCTUnwrap(node.inputView as? UITextView, "precondition: the legacy input view is not a UITextView")
        return Arranged(root: root, host: host, node: node, textView: textView)
    }

    static func restore(_ arranged: Arranged?) {
        guard let arranged else {
            return
        }
        _ = arranged.node.resignInputFirstResponder()
        arranged.root.setBackend(.engine)
    }

    /// Selects through the text view, as a user's drag does, and lets the panel's (asynchronous)
    /// selection sync land in the input state the Format commands read.
    static func select(_ arranged: Arranged, _ range: NSRange) {
        arranged.textView.selectedRange = range
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(arranged.host.panel.inputTextState.selectionRange, range.location ..< (range.location + range.length),
                       "precondition: the selection did not reach the input state")
    }

    static func content(_ arranged: Arranged) -> ChatInputContent {
        return arranged.host.panel.inputTextState.content
    }

    /// The text of every top-level paragraph run matching `predicate`, joined.
    static func text(in content: ChatInputContent, where predicate: (ChatInputInlineAttributes) -> Bool) -> String {
        var result = ""
        for block in content.blocks {
            if case let .paragraph(paragraph) = block {
                for run in paragraph.runs where predicate(run.attributes) {
                    result += run.text
                }
            }
        }
        return result
    }
}
