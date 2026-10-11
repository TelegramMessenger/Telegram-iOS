import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A selection holding exactly one SOFT line break — the `U+2028` a newline becomes inside
/// a body paragraph, a pull quote or a code block (Shift+Return, a multi-line paste into code or a pull
/// quote, a model `"\n"` inside a run) — has no geometry: one rect at `(inf, inf, 0, 0)`, no logical start
/// or end, and `firstRect` at infinity. Nothing is highlighted, no handles are drawn, and the edit menu is
/// placed at infinity. It is what ⇧→ selects with the caret at the end of a line that a soft break ends.
/// `[p "ab\ncd"]` (engine `"ab\u{2028}cd"`), select 2..<3 → no geometry; the same in a pull quote and in a
/// code block. A stock `UITextView` holding `"ab\u{2028}cd"` draws the same selection (oracle, in the same
/// test), and so does the engine for any wider range around the break (control).
///
/// **How it was seen.** p19 roam, 2026-09-25: the fuzz's new selection-geometry invariant
/// (`FuzzTextInputConsistency`), default seed 44 during undo-all (`[pull "한글\nl2\nl2\n☺︎l"]`, selection
/// 8..<9), then every range of the reduced shapes scanned: exactly the lone separators come back empty.
///
/// **Suspected cause.** The selection-geometry rule that stands a selected PARAGRAPH break up as a mark
/// (RichTextEditor `CLAUDE.md`, "Block selection rectangles": a zero-width segment is reported as "failed to
/// measure" and the coordinator's all-or-nothing validity check discards the whole answer) covers breaks
/// BETWEEN blocks; a line separator inside one block produces the same zero-width segment inside
/// `IDBlockTextGeometry` and is not stood up.
///
/// **Tier 1**: the public `UITextInput` geometry calls on the engine view and a stock text view.
@available(iOS 18.4, *)
final class HarnessSoftLineBreakSelectionGeometryTests: XCTestCase {
    private typealias E = HarnessEdited

    private func assertSeparatorHasGeometry(_ content: ChatInputContent, at offset: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, content)
        let text = driver.viewText() as NSString
        XCTAssertEqual(text.character(at: offset), 0x2028, "precondition: \(offset) is not the line separator in \(fuzzEscaped(text as String))", file: file, line: line)
        XCTAssertEqual(HarnessSelectionGeometry.stockProblems(driver.root, "ab\u{2028}cd", 2, 3), [], "precondition: a stock text view draws a lone line separator", file: file, line: line)
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        XCTAssertEqual(HarnessSelectionGeometry.problems(input, offset, offset + 1), [], "the selected line separator has no geometry", file: file, line: line)
    }

    func testASoftBreakInAParagraphHasGeometry() throws {
        try self.assertSeparatorHasGeometry(ChatInputContent(blocks: [E.paragraph([E.run("ab\ncd")])]), at: 2)
    }

    func testASoftBreakInAPullQuoteHasGeometry() throws {
        try self.assertSeparatorHasGeometry(ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [E.run("ab\ncd")]))]), at: 2)
    }

    func testASoftBreakInACodeBlockHasGeometry() throws {
        // "\nab\u{2028}cd": the empty language line, then the body.
        try self.assertSeparatorHasGeometry(ChatInputContent(blocks: [.code(ChatInputCode(language: nil, runs: [E.run("ab\ncd")]))]), at: 3)
    }

    /// Control: a range around the separator is drawn.
    func testControlARangeAroundASoftBreakHasGeometry() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, ChatInputContent(blocks: [E.paragraph([E.run("ab\ncd")])]))
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        XCTAssertEqual(HarnessSelectionGeometry.problems(input, 1, 4), [])
        XCTAssertEqual(HarnessSelectionGeometry.problems(input, 2, 4), [])
    }
}
