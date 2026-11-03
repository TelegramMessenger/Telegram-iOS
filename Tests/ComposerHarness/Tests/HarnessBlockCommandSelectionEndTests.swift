import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A block command — Format ▸ Quote, Code, Pull Quote, and the list's Tab /
/// Shift-Tab — over a selection that ENDS exactly at the start of the next paragraph also converts
/// that next paragraph, although the selection holds none of its characters:
///
///     [p "First"] [p "Second"] [p "Third"], select 0..<6 ("First⏎", what ⇧↓ from the line's start
///     selects), Format ▸ Quote
///       engine: [quote [p "First"] [p "Second"]] [p "Third"]
///       legacy: [quote [p "First"] …] [p "Second"] [p "Third"]      (control, inside)
///     Code → [code "First\nSecond"]; Pull Quote → [pull "First\nSecond"]
///     [• one] [• two] [• three], select 4..<8 ("two⏎"), Tab → "two" AND "three" indented
///
/// A selection of the paragraph break ALONE (5..<6) quotes both paragraphs too. A paragraph is
/// touched when the selection holds one of its characters — its break included —
/// (`NSString.paragraphRange(for:)`, pinned inside); Bold over the same selection formats only
/// "First" (control).
///
/// **How it was seen.** p16 roam, 2026-09-25, hosted probes of Format over block boundaries.
///
/// **Suspected cause.** `touchedBlockIndices(for:)` (`RichTextEngineEditorView+Containers.swift`)
/// counts a block as touched when `hi >= start`, so a non-empty range ending at a block's start
/// touches it; `touchedParagraphIndices(for:)` (`+Paragraph.swift`, the Tab path) resolves the end
/// offset with `blockRelativeLocation(forFlatOffset:)`, which puts a block-start offset in the block
/// after. For a NON-EMPTY range the end is exclusive.
///
/// **Tier 1**: `performFormatAction` is the Format menu's entry point; Tab is the editor's own key
/// command, performed as UIKit would.
@available(iOS 18.4, *)
final class HarnessBlockCommandSelectionEndTests: XCTestCase {
    private typealias S = HarnessP16

    private func threeLines() -> [ChatInputBlock] {
        return [S.paragraph("First"), S.paragraph("Second"), S.paragraph("Third")]
    }

    private func format(_ action: ChatRichTextFormatAction, _ lower: Int, _ upper: Int, _ blocks: [ChatInputBlock]) throws -> ChatInputContent {
        let arranged = try S.arrange(blocks)
        defer { S.finish(arranged) }
        S.select(arranged, lower, upper)
        arranged.node.performFormatAction(action)
        HarnessEngine.settle(arranged.root, seconds: 0.2)
        return S.content(arranged)
    }

    /// The top-level blocks holding "Second" and "Third" must still be plain body paragraphs.
    private func assertUntouched(_ content: ChatInputContent, _ texts: [String], _ message: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        for text in texts {
            let plain = content.blocks.contains { block in
                if case let .paragraph(paragraph) = block {
                    return paragraph.text == text && paragraph.list == nil && paragraph.style == .body
                }
                return false
            }
            XCTAssertTrue(plain, "\(message): \"\(text)\" is no longer a plain top-level paragraph: \(S.describe(content))", file: file, line: line)
        }
    }

    func testQuoteOverALineSelectedToTheNextLinesStartQuotesOnlyThatLine() throws {
        // Oracle: the paragraphs a selection touches.
        XCTAssertEqual(("First\nSecond\nThird" as NSString).paragraphRange(for: NSRange(location: 0, length: 6)), NSRange(location: 0, length: 6))
        // Legacy control: Second stays out of the quote.
        var legacy: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(legacy) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("First\nSecond\nThird"))
        legacy = value
        HarnessLegacy.select(value, NSRange(location: 0, length: 6))
        value.host.panel.formatAttributesQuote(self)
        HarnessEngine.settle(value.root)
        self.assertUntouched(HarnessLegacy.content(value), ["Second", "Third"], "control: legacy")
        HarnessLegacy.restore(value)
        legacy = nil

        let content = try self.format(.quote, 0, 6, self.threeLines())
        self.assertUntouched(content, ["Second", "Third"], "Format ▸ Quote over \"First⏎\" also quoted the next line")
    }

    func testCodeOverALineSelectedToTheNextLinesStartTakesOnlyThatLine() throws {
        let content = try self.format(.code, 0, 6, self.threeLines())
        self.assertUntouched(content, ["Second", "Third"], "Format ▸ Code over \"First⏎\" also took the next line")
    }

    func testPullQuoteOverALineSelectedToTheNextLinesStartTakesOnlyThatLine() throws {
        let content = try self.format(.pullQuote, 0, 6, self.threeLines())
        self.assertUntouched(content, ["Second", "Third"], "Format ▸ Pull Quote over \"First⏎\" also took the next line")
    }

    func testQuoteOverTheParagraphBreakAloneLeavesTheNextLine() throws {
        let content = try self.format(.quote, 5, 6, [S.paragraph("First"), S.paragraph("Second")])
        self.assertUntouched(content, ["Second"], "Format ▸ Quote over the paragraph break alone also quoted the next line")
    }

    func testTabOverAnItemSelectedToTheNextItemsStartIndentsOnlyThatItem() throws {
        let arranged = try S.arrange([S.item("one"), S.item("two"), S.item("three")])
        defer { S.finish(arranged) }
        S.select(arranged, 4, 8)
        var responder: UIView? = arranged.input
        var command: UIKeyCommand?
        while let view = responder, command == nil {
            command = view.keyCommands?.first { $0.input == "\t" && $0.modifierFlags == [] }
            if command == nil { responder = view.superview }
        }
        let tab = try XCTUnwrap(command, "precondition: no list Tab key command")
        _ = try XCTUnwrap(responder).perform(try XCTUnwrap(tab.action), with: tab)
        HarnessEngine.settle(arranged.root, seconds: 0.2)
        let content = S.content(arranged)
        XCTAssertEqual(S.describe(content), S.describe(ChatInputContent(blocks: [S.item("one"), S.item("two", level: 1), S.item("three")])),
                       "Tab over \"two⏎\" also indented the next item")
    }

    /// Control: Bold over the same selection formats only the first line.
    func testControlBoldOverALineSelectedToTheNextLinesStart() throws {
        let content = try self.format(.bold, 0, 6, self.threeLines())
        XCTAssertEqual(FuzzModel.describe(content), "[p body [b]\"First\"] [p body \"Second\"] [p body \"Third\"]")
    }

    /// Control: Quote over the line's text without its break quotes only that line.
    func testControlQuoteOverTheLinesTextOnly() throws {
        let content = try self.format(.quote, 0, 5, self.threeLines())
        self.assertUntouched(content, ["Second", "Third"], "control")
    }
}
