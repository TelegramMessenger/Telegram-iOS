import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p23, 2026-10-01; CORRUPTS WHAT IS SENT through Cut + Paste).** The editor's own copy of a
/// range holding a CODE BLOCK WITH A LANGUAGE (language line included), pasted into a RUNS-only region (a
/// table cell, a media caption, a pull quote's body), arrives without the language. The code body and the
/// text around it arrive:
///
///     [p "aa"] [code lang="clang" "cxy"] [p "bb"] [table ("cell")] [media cap="capt"] [pull "pqbody"] [p "end"]
///     copy 1..<(the first "b" + 1), caret after "ce", Paste   →  cell "cea\ncxy\nbll"         ("clang" missing)
///     the same into the caption                              →  cap "caa cxy bpt"
///     the same into the pull quote's body                    →  pull "pqba\ncxy\nbody"
///
/// Cut + Paste therefore deletes the language: Cut removes the whole code block, and the paste does not put
/// the language back. A drag-and-drop MOVE of the same range is refused (p19, `destinationHolds`), which keeps
/// the language, so the two disagree. A block QUOTE'S AUTHOR in the same position is kept as a line of its
/// own (p19, `blockInlineRuns`), and since p22 a ONE-LINE field takes exactly the copied text, language
/// included (`oneLineFieldTextUTI`). The code language is the one piece of copied text a runs-only paste
/// drops.
///
/// **Legacy** cannot be compared: the legacy composer is the flat text view (`ChatInputTextNode`) and holds no
/// code language, cell, caption or pull quote.
///
/// **How it was seen.** p23 roam, p22's unfixed observation (a), measured.
///
/// **Suspected cause.** `blockInlineRuns` (Core `DocumentFragment.swift`) degrades a `.code` block to its body
/// runs. It cannot add the language, because a fragment carries a code block's language as METADATA even for
/// a partial body copy (p22, Core `CodeBlockPositionTests`), so it cannot tell whether the range held the
/// language line. The copy knows (`clipboardSelection().deletion` covers the language line), as the p22
/// one-line text does. Either the copy marks a language it covered (for example as a fragment flag), or a
/// runs-only paste of a code block with a language is refused, as the move is.
///
/// **Tier 1**: view selection, `copy:` / `cut:` / `paste:`, and the editor's own move.
@available(iOS 18.4, *)
final class HarnessCodeLanguageIntoRunsRegionTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private static func document(_ source: ChatInputBlock) -> ChatInputContent {
        return ChatInputContent(blocks: [
            E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0)], rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [E.run("cell")])])])),
            E.media(1, caption: "capt"),
            .pullQuote(ChatInputPullQuote(runs: [E.run("pqbody")], author: [E.run("AU")])),
            E.paragraph([E.run("end")]),
        ])
    }

    private static let code = ChatInputBlock.code(ChatInputCode(language: "clang", runs: [E.run("cxy")]))

    /// Every letter of the model, sorted: languages, authors and captions included.
    private static func letters(_ content: ChatInputContent) -> String {
        func runs(_ runs: [ChatInputRun]) -> String { runs.map(\.text).joined() }
        func text(_ blocks: [ChatInputBlock]) -> String {
            return blocks.map { block -> String in
                switch block {
                case let .paragraph(paragraph): return runs(paragraph.runs)
                case let .pullQuote(quote): return runs(quote.runs) + runs(quote.author)
                case let .blockQuote(quote): return text(quote.content.blocks) + runs(quote.author)
                case let .code(code): return (code.language ?? "") + runs(code.runs)
                case let .details(details): return runs(details.title) + text(details.content.blocks)
                case let .media(media): return runs(media.caption)
                case let .table(table): return table.rows.flatMap { $0.cells.map { runs($0.runs) } }.joined()
                default: return ""
                }
            }.joined()
        }
        return String(text(content.blocks).filter(\.isLetter).sorted())
    }

    /// Copies (or cuts) from the second "a" to the first "b" + 1 (the whole source block plus a letter either
    /// side), then pastes after `needle`.
    private func clip(_ source: ChatInputBlock, cut: Bool, into needle: String) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(source))
        let text = self.driver.viewText() as NSString
        let start = text.range(of: "aa").location + 1
        self.driver.setViewSelection(NSRange(location: start, length: text.range(of: "bb").location + 1 - start))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(cut ? #selector(UIResponderStandardEditActions.cut(_:)) : #selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let after = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(after.range(of: needle)), length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        return self.driver.model()
    }

    private func cellText(_ content: ChatInputContent) -> String {
        for block in content.blocks {
            if case let .table(table) = block { return table.rows.first?.cells.first.map { $0.runs.map(\.text).joined() } ?? "" }
        }
        return ""
    }

    // MARK: - Red

    func testACopiedCodeBlockPastedIntoACellCarriesItsLanguage() {
        let model = self.clip(Self.code, cut: false, into: "ce")
        XCTAssertTrue(self.cellText(model).contains("clang"), "cell \(fuzzEscaped(self.cellText(model))): \(FuzzModel.describe(model))")
    }

    func testCutAndPasteOfACodeBlockIntoACellLosesNothing() {
        let model = self.clip(Self.code, cut: true, into: "ce")
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.code)), FuzzModel.describe(model))
    }

    func testCutAndPasteOfACodeBlockIntoACaptionLosesNothing() {
        let model = self.clip(Self.code, cut: true, into: "ca")
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.code)), FuzzModel.describe(model))
    }

    func testCutAndPasteOfACodeBlockIntoAPullQuoteBodyLosesNothing() {
        let model = self.clip(Self.code, cut: true, into: "pqb")
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.code)), FuzzModel.describe(model))
    }

    // MARK: - Controls

    /// A block quote's AUTHOR in the same position is carried into the cell (p19, `blockInlineRuns`).
    func testControlCutAndPasteOfAnAuthoredQuoteIntoACellLosesNothing() {
        let quote = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("qxy")])]), collapsed: false, author: [E.run("qau")]))
        let model = self.clip(quote, cut: true, into: "ce")
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(quote)), FuzzModel.describe(model))
    }

    /// The same Cut pasted into a BODY paragraph keeps the code block and its language.
    func testControlPastedIntoABodyParagraphTheLanguageIsKept() {
        let model = self.clip(Self.code, cut: true, into: "en")
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.code)), FuzzModel.describe(model))
    }

    /// A slice of the code BODY (the language line not in the range) pasted into a cell is the slice alone.
    func testControlACodeBodySliceIntoACellCarriesNoLanguage() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.code))
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: "cxy").location + 1, length: 1))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "ce")), length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        XCTAssertEqual(self.cellText(self.driver.model()), "cexll", FuzzModel.describe(self.driver.model()))
    }

    /// The MOVE of the same range into the cell is refused and changes nothing (p19). Unlike
    /// `HarnessFragmentIntoOneLineFieldTests.testAMoveOfACodeBlockWithALanguageIntoACellLosesNothing`, whose
    /// fixed `location: 1` falls inside its leading table cell — so its move is refused as a partial-table
    /// range and the code block never moves (it stayed green with the refusal neutered, p23) — this range
    /// starts in the paragraph before the code block.
    func testControlAMoveOfTheCodeBlockIntoACellIsRefused() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.code))
        let before = FuzzModel.normalized(self.driver.model())
        let text = self.driver.viewText() as NSString
        let start = text.range(of: "aa").location + 1
        self.driver.setViewSelection(NSRange(location: start, length: text.range(of: "bb").location + 1 - start))
        self.driver.settle(0.1)
        guard let context = self.driver.editor.makeTextDragContext() else { return XCTFail("precondition: no drag context") }
        let moved = self.driver.editor.performLocalMove(context, toFlatOffset: NSMaxRange(text.range(of: "ce")))
        self.driver.settle(0.2)
        XCTAssertFalse(moved, FuzzModel.describe(self.driver.model()))
        XCTAssertEqual(FuzzModel.normalized(self.driver.model()), before, FuzzModel.describe(self.driver.model()))
    }
}
