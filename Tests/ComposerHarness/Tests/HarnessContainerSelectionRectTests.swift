import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, a selection inside a multi-line QUOTE, PULL QUOTE or CODE
/// block is drawn one rectangle tall enough to cover every line of the block. Selecting the word
/// "lazy" on the second line of a quoted paragraph highlighted a band over both lines (covering
/// "quic" on line one too); selecting "paragraph" on line one of a two-line code block or pull quote
/// highlighted lines one AND two, with the end handle hanging on line two. In a pull quote (centred
/// text) a multi-line selection's rects also start at the box's left edge / the composer's left edge
/// instead of at the centred glyphs, so the highlight spills outside the pull-quote box. A plain
/// paragraph is fine: the same word gives one line-high rect.
///
/// **How it was seen.** K1, engine, 2026-09-22. `one-paragraph` → Select All → Format ▸ Quote, then
/// `selectionRectsForRange:` on the first responder for 4..<9 ("quick", line 1) and 36..<40 ("lazy",
/// line 2) both returned `{{46, 4}, {…, 47}}` — the same y and a two-line height. Code block
/// (`two-paragraphs` → Select All → Format ▸ Code): 6..<15 → `{{53, 35}, {81, 52}}`. Pull quote:
/// 6..<15 → `{{113, 4}, {71, 47}}`. Plain paragraph control: 6..<15 → `{{37, 3}, {79, 23}}`, with a
/// caret 22.7 pt tall. Screenshots on K1 show the highlight exactly as those rects say.
///
/// **Suspected cause.** The rects come from the upstream engine
/// (`IDBlockTextView+TextInput.m` → `id_behaviorInput selectionRectsForRange:`); for a block whose
/// region is laid out inside a container box the per-line fragments are apparently replaced by the
/// box's (or the block's) full extent. Not investigated further.
///
/// **Tier 1**, because the defect is the geometry the text view hands UIKit, readable in-process
/// through `UITextInput`. What is on screen is UIKit drawing exactly these rects.
final class HarnessContainerSelectionRectTests: XCTestCase {
    private static let text = "The quick brown fox jumps over the lazy dog and then keeps running far away from here."

    private func rects(_ root: HarnessRootViewController, _ range: NSRange) throws -> (rects: [CGRect], caretHeight: CGFloat) {
        let view = try HarnessEngine.textView(in: root)
        let input = try XCTUnwrap(view as? UITextInput, "precondition: the engine view is not a UITextInput")
        let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: range.location))
        let end = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: NSMaxRange(range)))
        let textRange = try XCTUnwrap(input.textRange(from: start, to: end))
        let rects = input.selectionRects(for: textRange).map(\.rect).filter { !$0.isEmpty }
        return (rects, input.caretRect(for: start).height)
    }

    private func assertLineHigh(_ root: HarnessRootViewController, _ range: NSRange, _ what: String,
                                file: StaticString = #filePath, line: UInt = #line) throws {
        let (rects, caretHeight) = try self.rects(root, range)
        XCTAssertFalse(rects.isEmpty, "precondition: no selection rects for \(what)", file: file, line: line)
        XCTAssertGreaterThan(caretHeight, 0.0, "precondition: no caret height for \(what)", file: file, line: line)
        for rect in rects {
            XCTAssertLessThanOrEqual(rect.height, caretHeight * 1.5,
                                     "\(what): a one-line selection produced a rect \(rect) spanning more than one line (caret height \(caretHeight))",
                                     file: file, line: line)
        }
    }

    private func arrange(_ blocks: [ChatInputBlock]) throws -> HarnessRootViewController {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        _ = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root)
        return root
    }

    /// Control: the measurement itself is sound, on a plain paragraph with the same text.
    func testAWordInAPlainParagraphIsOneLineHigh() throws {
        let root = try self.arrange([HarnessEngine.paragraph(Self.text)])
        try self.assertLineHigh(root, NSRange(location: 4, length: 5), "paragraph, \"quick\"")
    }

    func testAWordInAQuoteIsOneLineHigh() throws {
        let root = try self.arrange([
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph(Self.text)]),
                                            collapsed: false)),
        ])
        try self.assertLineHigh(root, NSRange(location: 4, length: 5), "quote, \"quick\"")
    }

    func testAWordInACodeBlockIsOneLineHigh() throws {
        let root = try self.arrange([
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "First paragraph.\nSecond paragraph.")])),
        ])
        // UITextInput offsets inside a code block can include the language line; a word-sized range
        // anywhere in the body is enough — the defect makes EVERY rect block-high.
        try self.assertLineHigh(root, NSRange(location: 6, length: 9), "code block, line 1")
    }

    func testAWordInAPullQuoteIsOneLineHigh() throws {
        let root = try self.arrange([
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "First paragraph.\nSecond paragraph.")])),
        ])
        try self.assertLineHigh(root, NSRange(location: 6, length: 9), "pull quote, \"paragraph\"")
    }
}
