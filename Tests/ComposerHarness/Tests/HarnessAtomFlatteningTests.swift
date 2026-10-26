import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** Two edits rewrite text as PLAIN engine text, and a custom
/// emoji's engine text is its attachment character, so the model is left with a bare `U+FFFC` — no
/// entity, no alt text — which the message then sends as a literal character:
///
///     (a) [p "item " 😀], select it, Format ▸ Code
///           engine:   [code "item \u{FFFC}"]
///           expected: [code "item 😀"]              (the emoji's alt text; a formula already becomes
///                                                     its LaTeX, control inside)
///     (b) [p "Mixed " 😀] [table ("a" 😀 | "yb")], select from the end of cell 1 to the end of cell 2
///         (10..<13 on the engine axis), Backspace
///           engine:   cell 1 = "a\u{FFFC}" (plain), cell 2 = ""
///           expected: cell 1 = "a" + 😀 (untouched), cell 2 = ""
///
/// Controls: Code over a paragraph with an inline FORMULA gives its LaTeX; the same cross-cell deletion
/// in a table without an atom.
///
/// **How it was seen.** p16 sweep of the edited-content fuzz with the new bare-U+FFFC invariant: seeds
/// 12, 32, 38, 80 (a) — the `line` op's Code over a whole line, or the menu's Code — and seed 56 (b).
///
/// **Suspected cause.** (a) `makeCodeBlock` (`RichTextEngineEditorView+Containers.swift`) gathers
/// `paragraph.text` (Core's plain text, where an atom is U+FFFC) instead of the runs' model text (the
/// emoji's alt, the formula's LaTeX). (b) The cross-cell replacement re-issues the covered cells as
/// ONE `replaceFlat` of the cells' joined PLAIN texts (`RichTextEngineEditorView+SurfaceGate.swift`,
/// the cells branch: `replaceFlat(… with: texts.joined(separator: "\n"), adopting: currentRoles)`),
/// which re-inserts every kept attachment character without its attachment.
///
/// **Tier 1**: the selection, Backspace and the Format command are the keyboard's / menu's entry points.
@available(iOS 18.4, *)
final class HarnessAtomFlatteningTests: XCTestCase {
    private func run(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: driver.host)
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            driver.host.panel.formulaRenderer = nil
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return driver.model()
    }

    func testCodeOverACustomEmojiKeepsItsText() throws {
        let content = try self.run(ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("item "), HarnessEdited.emoji()])]),
                                   [.format(.code, selecting: (0, 6))])
        guard case let .code(code)? = content.blocks.first else {
            return XCTFail("precondition: no code block: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, "Code turned the custom emoji into a bare U+FFFC: \(FuzzModel.describe(content))")
        XCTAssertEqual(code.text, "item 😀", "the code block does not carry the emoji's text")
    }

    func testDeletingAcrossTableCellsKeepsACustomEmojiInTheKeptText() throws {
        func cell(_ runs: [ChatInputRun]) -> ChatInputTableCell { return ChatInputTableCell(runs: runs) }
        let start = ChatInputContent(blocks: [
            HarnessEdited.paragraph([HarnessEdited.run("Mixed "), HarnessEdited.emoji()]),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(cells: [cell([HarnessEdited.run("a"), HarnessEdited.emoji()]), cell([HarnessEdited.run("yb")])]),
            ])),
        ])
        let content = try self.run(start, [.select(10, 13), .deleteBackward])
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, "the cross-cell deletion turned the kept emoji into a bare U+FFFC: \(FuzzModel.describe(content))")
        guard content.blocks.count > 1, case let .table(table) = content.blocks[1], let first = table.rows.first?.cells.first else {
            return XCTFail("precondition: the table is gone: \(FuzzModel.describe(content))")
        }
        XCTAssertTrue(first.runs.contains { if case .customEmoji? = $0.attributes.entity { return true }; return false },
                      "the untouched cell lost its custom emoji: \(FuzzModel.describe(content))")
        XCTAssertEqual(table.rows.first?.cells.last?.runs.map(\.text).joined() ?? "?", "", "precondition: the second cell was not emptied")
    }

    // MARK: the same flattening on other paths (p16 fix wave's audit)

    /// (c) A custom emoji copied from a paragraph and PASTED into a code block: Core's code arm
    /// (`replacingRangeInsideOneContainer`) joined the fragment's plain text, an atom's being its
    /// attachment character. Found by the fix wave's audit of text-flattening paths.
    func testPastingACustomEmojiIntoCodeKeepsItsText() throws {
        let start = ChatInputContent(blocks: [
            HarnessEdited.paragraph([HarnessEdited.run("Mixed "), HarnessEdited.emoji()]),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let")])),
        ])
        // Past the code block's language line.
        let codeStart = HarnessComposerFuzzTests.topLevelStart(start, 1) + 1
        let content = try self.run(start, [.select(6, 7), .copy, .select(codeStart + 3, codeStart + 3), .paste])
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, "the pasted custom emoji became a bare U+FFFC: \(FuzzModel.describe(content))")
        guard content.blocks.count > 1, case let .code(code) = content.blocks[1] else {
            return XCTFail("precondition: the code block is gone: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(code.text, "let😀")
    }

    /// (d) The same copy pasted into a quote's AUTHOR line, a one-line field that takes the
    /// pasteboard's PLAIN text (`pastePlainTextIntoOneLineField`), which carried the attachment
    /// character (`blockPlainText`). Found by the fix wave's audit.
    func testPastingACustomEmojiIntoAnAuthorLineLeavesNoBareAttachment() throws {
        let start = ChatInputContent(blocks: [
            HarnessEdited.paragraph([HarnessEdited.run("Mixed "), HarnessEdited.emoji()]),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pq")], author: [ChatInputRun(text: "Au")])),
        ])
        // "Mixed \u{FFFC}" 0..<7, "pq" 8..<10, "Au" 11..<13.
        let content = try self.run(start, [.select(6, 7), .copy, .select(13, 13), .paste])
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, "the pasted custom emoji became a bare U+FFFC in the author: \(FuzzModel.describe(content))")
        guard content.blocks.count > 1, case let .pullQuote(quote) = content.blocks[1] else {
            return XCTFail("precondition: the pull quote is gone: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Au😀")
    }

    /// (e) Table ▸ Convert to Text over a cell holding a custom emoji: each row became a paragraph of
    /// the cells' PLAIN text (`tableFlattenedText`). Found by the fix wave's audit.
    func testConvertingATableToTextLeavesNoBareAttachment() throws {
        func cell(_ runs: [ChatInputRun]) -> ChatInputTableCell { return ChatInputTableCell(runs: runs) }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("x"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(cells: [cell([HarnessEdited.run("a"), HarnessEdited.emoji()]), cell([HarnessEdited.run("yb")])]),
            ])),
        ])
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(3, 3)])
        driver.editor.convertCurrentTableToText()
        driver.settle()
        let content = driver.model()
        XCTAssertFalse(content.blocks.contains { if case .table = $0 { return true }; return false }, "precondition: the table was not converted: \(FuzzModel.describe(content))")
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, "Convert to Text turned the custom emoji into a bare U+FFFC: \(FuzzModel.describe(content))")
        XCTAssertTrue(content.blocks.contains { if case let .paragraph(p) = $0 { return p.text == "a😀 yb" }; return false }, FuzzModel.describe(content))
    }

    /// Control: a formula becomes its LaTeX in a code block.
    func testControlCodeOverAFormulaKeepsItsLatex() throws {
        let content = try self.run(ChatInputContent(blocks: [HarnessEdited.paragraph([HarnessEdited.run("Sum "), HarnessEdited.formula("a^2")])]),
                                   [.format(.code, selecting: (0, 5))])
        XCTAssertEqual(FuzzModel.bareAttachments(content).count, 0, FuzzModel.describe(content))
        guard case let .code(code)? = content.blocks.first else {
            return XCTFail("precondition: no code block: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(code.text, "Sum a^2")
    }

    /// Control: the same cross-cell deletion without an atom.
    func testControlDeletingAcrossTableCellsWithoutAnAtom() throws {
        func cell(_ text: String) -> ChatInputTableCell { return ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Mixed x"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(cells: [cell("ax"), cell("yb")]),
            ])),
        ])
        let content = try self.run(start, [.select(10, 13), .deleteBackward])
        guard content.blocks.count > 1, case let .table(table) = content.blocks[1] else {
            return XCTFail("precondition: the table is gone: \(FuzzModel.describe(content))")
        }
        XCTAssertEqual(table.rows.first?.cells.map { $0.runs.map(\.text).joined() }, ["ax", ""])
    }
}
