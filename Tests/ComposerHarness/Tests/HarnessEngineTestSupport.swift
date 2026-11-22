import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// Shared arrange steps for the engine-backend regression tests added in the second roam.
/// The older test files each carry their own `root()`; this one is shared because the three
/// families below need the same three extra handles (the node, the engine text view, a settle).
enum HarnessEngine {
    static func root() throws -> HarnessRootViewController {
        let value = try XCTUnwrap(AppDelegate.harnessRootViewController)
        value.loadViewIfNeeded()
        value.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date().addingTimeInterval(30.0)
        while value.panelHost == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        value.view.layoutIfNeeded()
        return value
    }

    /// Lets the editor's coalesced selection/change deliveries and the root's layout pass land.
    static func settle(_ root: HarnessRootViewController, seconds: TimeInterval = 0.3) {
        root.view.setNeedsLayout()
        root.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        root.view.layoutIfNeeded()
    }

    static func node(_ host: HarnessPanelHost) throws -> ChatRichTextInputNode {
        XCTAssertEqual(host.liveBackend, .engine, "precondition: the engine backend is not live")
        return try XCTUnwrap(host.panel.richTextInputNode, "precondition: no rich input node")
    }

    /// The engine's `UITextInput` view. It is what UIKit (and the keyboard) actually talks to,
    /// so traits, selection geometry and the undo manager are read from it rather than from a wrapper.
    static func textView(in root: HarnessRootViewController) throws -> UIView {
        func find(_ view: UIView) -> UIView? {
            if NSStringFromClass(type(of: view)) == "TGIDObservingBlockTextView" {
                return view
            }
            for subview in view.subviews {
                if let found = find(subview) {
                    return found
                }
            }
            return nil
        }
        return try XCTUnwrap(find(root.view), "precondition: no engine text view in the hierarchy")
    }

    static func paragraph(_ text: String, _ attributes: ChatInputInlineAttributes = ChatInputInlineAttributes()) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: text, attributes: attributes)]))
    }
}
