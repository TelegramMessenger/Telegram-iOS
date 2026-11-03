import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting the editor's own clipboard (the private fragment
/// type, i.e. anything copied or cut inside the composer) with the caret INSIDE a block quote or a
/// code block splits the container in two and inserts the pasted text between the halves as a BODY
/// paragraph, even when what was copied is a single word:
///
///     [p "First paragraph."] [quote "Second paragraph."]
///     copy "First" (0..<5) → caret after "Second " in the quote → Paste
///       engine: [p "First paragraph."] [quote "Second "] [p "First"] [quote "paragraph."]
///       expected: [p "First paragraph."] [quote "Second Firstparagraph."]
///     same, caret in an EMPTY quote paragraph made by Return at the quote's end
///       engine: … [quote "Second paragraph."] [p "First"] [quote ""]   (the quote is split, the text is out)
///     same with a code block
///       engine: [p …] [code "Second"] [p "First"] [code " paragraph."]
///
/// Controls: the same fragment pasted mid-word into a plain paragraph splices inline
/// (`"FirFirstst paragraph."`), and a plain-text paste into the quote stays inside it.
///
/// **How it was seen.** K1, 2026-09-23, eighth roam: `copy:` / `paste:` sent to the engine text view
/// through lldb, the model read from the harness readout. Seen 3× for the empty quote paragraph, 2×
/// mid-quote (twice in one document: two pastes gave five blocks), 1× in a code block.
///
/// **Suspected cause.** `pasteFragmentFromPasteboard()` (`RichTextEngineEditorView+Clipboard.swift`)
/// → `Document.replacingRange` / `replacingRangeReportingInsertion` (Core): the fragment's first
/// block is folded inline only into a TOP-LEVEL host paragraph; when the host paragraph is a child
/// of a quote or the body of a code block, the fragment's paragraph is inserted as a sibling block at
/// the top level, which splits the container around it.
///
/// **Tier 1**: `copy(_:)` and `paste(_:)` on the engine view are what the edit menu calls, the
/// pasteboard is this process's own (written before it is read, so no paste prompt), and the defect
/// is in the model.
final class HarnessFragmentPasteIntoContainerTests: XCTestCase {
    private func pasteCopiedWord(into container: ChatInputBlock, caret: Int) throws -> [ChatInputBlock] {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [HarnessEngine.paragraph("First paragraph."), container]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)

        node.selectedRange = NSRange(location: 0, length: 5)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(root)
        XCTAssertNotNil(UIPasteboard.general.data(forPasteboardType: "org.telegram.richtexteditor.fragment"),
                        "precondition: the copy did not put the editor's fragment on the pasteboard")

        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)
        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        return blocks
    }

    func testAWordPastedInsideAQuoteStaysInTheQuote() throws {
        let blocks = try self.pasteCopiedWord(
            into: .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [HarnessEngine.paragraph("Second paragraph.")]),
                collapsed: false)),
            caret: 24)
        XCTAssertEqual(blocks.count, 2, "pasting a copied word inside a quote split it: \(blocks)")
        guard blocks.count == 2, case let .blockQuote(quote) = blocks[1] else {
            XCTFail("the second block is no longer the quote: \(blocks)")
            return
        }
        XCTAssertEqual(quote.content.plainText, "Second Firstparagraph.",
                       "the pasted word did not land inline in the quote: \(blocks)")
    }

    func testAWordPastedInsideACodeBlockStaysInTheCodeBlock() throws {
        let blocks = try self.pasteCopiedWord(
            into: .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "Second paragraph.")])),
            caret: 20)
        XCTAssertEqual(blocks.count, 2, "pasting a copied word inside a code block split it: \(blocks)")
        guard blocks.count == 2, case let .code(code) = blocks[1] else {
            XCTFail("the second block is no longer the code block: \(blocks)")
            return
        }
        XCTAssertTrue(code.runs.map(\.text).joined().contains("First"),
                      "the pasted word did not land in the code block: \(blocks)")
    }

    /// Control: the same fragment pasted mid-word into a plain paragraph splices inline.
    func testControlAWordPastedInsideAParagraphStaysInline() throws {
        let blocks = try self.pasteCopiedWord(into: HarnessEngine.paragraph("Second paragraph."), caret: 24)
        XCTAssertEqual(blocks.count, 2, "control: pasting a copied word into a paragraph changed the block count: \(blocks)")
        XCTAssertEqual(ChatInputContent(blocks: blocks).plainText, "First paragraph.\nSecond Firstparagraph.",
                       "control: the pasted word did not splice inline")
    }
}
