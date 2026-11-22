import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// Shared arrange steps for the p16 roam's regression tests (lists, checklists, whole-line deletion,
/// block commands at a paragraph boundary, partial-fragment paste). Engine backend.
enum HarnessP16 {
    struct Arranged {
        let root: HarnessRootViewController
        let host: HarnessPanelHost
        let node: ChatRichTextInputNode
        let input: UIView & UITextInput
    }

    static func arrange(_ blocks: [ChatInputBlock]) throws -> Arranged {
        let root = try HarnessEngine.root()
        root.setBackend(.engine)
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root, seconds: 0.2)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root, seconds: 0.2)
        let input = try XCTUnwrap(try HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        input.undoManager?.removeAllActions()
        return Arranged(root: root, host: host, node: node, input: input)
    }

    static func finish(_ arranged: Arranged) {
        _ = arranged.node.resignInputFirstResponder()
    }

    /// Selects on the engine view's axis (what a drag or ⇧-arrow selects).
    static func select(_ arranged: Arranged, _ lower: Int, _ upper: Int) {
        let input = arranged.input
        guard let start = input.position(from: input.beginningOfDocument, offset: lower),
              let end = input.position(from: input.beginningOfDocument, offset: upper) else {
            XCTFail("precondition: \(lower)..<\(upper) is outside the text")
            return
        }
        input.selectedTextRange = input.textRange(from: start, to: end)
        HarnessEngine.settle(arranged.root, seconds: 0.1)
    }

    static func type(_ arranged: Arranged, _ text: String) {
        arranged.input.insertText(text)
        HarnessEngine.settle(arranged.root, seconds: 0.1)
    }

    static func backspace(_ arranged: Arranged) {
        arranged.input.deleteBackward()
        HarnessEngine.settle(arranged.root, seconds: 0.1)
    }

    static func perform(_ arranged: Arranged, _ action: Selector) {
        _ = arranged.input.perform(action, with: nil)
        HarnessEngine.settle(arranged.root, seconds: 0.3)
    }

    static func content(_ arranged: Arranged) -> ChatInputContent {
        return FuzzModel.normalized(arranged.node.currentInputContent().content)
    }

    static func paragraph(_ text: String, style: ChatInputParagraphStyle = .body) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: style, list: nil, runs: [ChatInputRun(text: text)]))
    }

    static func item(_ text: String, _ marker: ChatInputListMarker = .bullet, level: Int32 = 0, checked: Bool? = nil) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker, level: level, checked: checked),
                                             runs: [ChatInputRun(text: text)]))
    }

    static func quote(_ blocks: [ChatInputBlock]) -> ChatInputBlock {
        return .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: blocks), collapsed: false))
    }

    /// A readable dump that, unlike `FuzzModel.describe`, prints paragraph style and list membership.
    static func describe(_ content: ChatInputContent) -> String {
        return content.blocks.map { block -> String in
            switch block {
            case let .paragraph(paragraph):
                var list = ""
                if let membership = paragraph.list {
                    list = " \(membership.marker)\(membership.level)" + (membership.checked.map { $0 ? "[x]" : "[ ]" } ?? "")
                }
                return "[p \(paragraph.style)\(list) \(fuzzEscaped(paragraph.text))]"
            case let .blockQuote(quote):
                return "[quote \(Self.describe(quote.content))]"
            default:
                return FuzzModel.describe(block)
            }
        }.joined(separator: " ")
    }
}
