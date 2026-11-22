import XCTest
import UIKit
import TelegramCore
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting plain text that is markdown lands as literal text
/// (`# Title`, `- one`, `**bold**`). The legacy composer parses it through the panel's
/// `pastedMarkdownParser` and inserts structure; the engine editor stores the equivalent hook,
/// `plainTextFragmentTransformer`, in its deferred configuration and never consults it on the paste
/// path ("RE-DEFERRED TO: R7-paste" in `RichTextEngineEditorView+DeferredConfiguration.swift`). In the
/// app's default dual-field mode the legacy field catches the paste first, so the gap shows with the
/// engine forced on (Debug ▸ "Force Text Field v2") and whenever the field is already native.
///
/// **How it was seen.** The fourth roam could not reach markdown paste at all: the harness had no
/// parser wired (it now mirrors `ChatInterfaceStateInputPanels.swift`); with it wired, the engine still
/// pasted the markdown literally (controller, 2026-09-23).
///
/// **Tier 1**: `paste(_:)` is what the edit menu calls, and the pasteboard is this process's own.
final class HarnessMarkdownPasteTests: XCTestCase {
    func testPastingMarkdownProducesStructure() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }

        UIPasteboard.general.string = "# Title\n\n- one\n- two\n\n**bold** text"
        let textView = try HarnessEngine.textView(in: root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)

        let content = node.currentInputContent().content
        XCTAssertFalse(content.plainText.contains("# Title"), "the heading marker was pasted literally: \(content.blocks)")
        XCTAssertFalse(content.plainText.contains("**"), "the bold markers were pasted literally: \(content.blocks)")
        let hasList = content.blocks.contains { block in
            if case let .paragraph(paragraph) = block {
                return paragraph.list != nil
            }
            return false
        }
        XCTAssertTrue(hasList, "the list did not become a list: \(content.blocks)")
    }
}
