import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** The editor's own copy of a range that holds a QUOTE WITH AN AUTHOR (block or pull) or a
/// CODE BLOCK WITH A LANGUAGE, pasted into a one-line field — a quote's or pull quote's author, a details
/// title, a code block's language — arrives without that author / language:
///
///     [p "aa"] [pull "pxy" author="pau"] [p "bb"] [quote [p "QB"] author="QA"] [p "end"]
///     copy 1..<(the "b" of "bb"), caret after the "Q" of "QA", Paste  →  author "Qa pxy bA"      ("pau" missing)
///     the same with [quote [p "qxy"] author="qau"]                     →  "Qa qxy bA"            ("qau" missing)
///     the same with [code lang="clang" "cxy"]                          →  "Qa cxy bA"            ("clang" missing)
///     control: a details' TITLE is carried ("Qa dti dxy bA"); a checklist item's text too ("Qa ✅ kxy bA")
///
/// For Copy that is an incomplete paste; for CUT + Paste, and a drag-and-drop MOVE (which is Cut + Paste), the
/// author / language text is deleted and lands nowhere: fuzz edited seed 40 step 22, "a local move lost
/// content" (a range holding an authored pull quote moved into another pull quote's author).
///
/// **How it was seen.** p22 roam (2026-10-01), the edited sweep 31-60; reduced by copying each container kind
/// into each one-line field.
///
/// **Suspected cause.** `pastePlainTextIntoOneLineField` (`+Clipboard.swift`) pastes the pasteboard's PLAIN
/// string, and the plain text the copy writes (`RichTextEditorClipboard` → Core `blockPlainText`) leaves out a
/// quote's author and a code block's language, where `blockInlineRuns` — the runs-only fragment path, fixed
/// in p19 (row 144) for exactly this loss — keeps them. The p19 fix also refuses a MOVE of a code block with a
/// language into a runs-only destination (`containsCodeLanguage`); a paste, and a move of a quote with an
/// author, are not covered.
///
/// **Severity.** CORRUPTS WHAT IS SENT (Cut / move): an attribution or a language the user moved is gone.
///
/// **Tier 1**: a view selection, `copy:` / `cut:` / `paste:`, and the editor's own drag-and-drop move.
@available(iOS 18.4, *)
final class HarnessFragmentIntoOneLineFieldTests: XCTestCase {
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

    private static let pull = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [E.run("pxy")], author: [E.run("pau")]))
    private static let quote = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("qxy")])]), collapsed: false, author: [E.run("qau")]))
    private static let code = ChatInputBlock.code(ChatInputCode(language: "clang", runs: [E.run("cxy")]))
    private static let details = ChatInputBlock.details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("dxy")])]), title: [E.run("dti")], expanded: true))
    private static let destination = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("QB")])]), collapsed: false, author: [E.run("QA")]))

    private static func document(_ source: ChatInputBlock) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]), destination, E.paragraph([E.run("end")])])
    }

    /// Every letter of the model, sorted: authors, titles and languages included.
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
                default: return ""
                }
            }.joined()
        }
        return String(text(content.blocks).filter(\.isLetter).sorted())
    }

    private func destinationAuthor(_ content: ChatInputContent) -> String {
        for block in content.blocks.reversed() {
            if case let .blockQuote(quote) = block { return quote.author.map(\.text).joined() }
        }
        return ""
    }

    /// The range from the second "a" to the first "b": the whole source block plus a letter either side.
    private func sourceRange() -> NSRange {
        let text = self.driver.viewText() as NSString
        let end = text.range(of: "bb").location + 1
        return NSRange(location: 1, length: end - 1)
    }

    private func clipIntoTheAuthor(_ source: ChatInputBlock, cut: Bool) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(source))
        self.driver.setViewSelection(self.sourceRange())
        self.driver.settle(0.1)
        _ = self.driver.view.perform(cut ? #selector(UIResponderStandardEditActions.cut(_:)) : #selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: "QA").location + 1, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        return self.driver.model()
    }

    // MARK: - Red

    func testAPastedPullQuoteKeepsItsAuthor() {
        let model = self.clipIntoTheAuthor(Self.pull, cut: false)
        XCTAssertTrue(self.destinationAuthor(model).contains("pau"), "pasted as \"\(self.destinationAuthor(model))\": \(FuzzModel.describe(model))")
    }

    func testAPastedQuoteKeepsItsAuthor() {
        let model = self.clipIntoTheAuthor(Self.quote, cut: false)
        XCTAssertTrue(self.destinationAuthor(model).contains("qau"), "pasted as \"\(self.destinationAuthor(model))\": \(FuzzModel.describe(model))")
    }

    func testCutAndPasteOfAnAuthoredPullQuoteLosesNothing() {
        let model = self.clipIntoTheAuthor(Self.pull, cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.pull)), FuzzModel.describe(model))
    }

    func testCutAndPasteOfACodeBlockWithALanguageLosesNothing() {
        let model = self.clipIntoTheAuthor(Self.code, cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.code)), FuzzModel.describe(model))
    }

    /// The fuzz's shape: a drag-and-drop move into the author either keeps every letter or is refused.
    func testAMoveOfAnAuthoredPullQuoteIntoAnAuthorLosesNothing() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.pull))
        let range = self.sourceRange()
        let text = self.driver.viewText() as NSString
        let violation = HarnessComposerFuzzTests.moveViolation(range.location, NSMaxRange(range), text.range(of: "QA").location + 1, on: self.driver)
        XCTAssertNil(violation, violation ?? "")
    }

    // MARK: - Controls

    /// A details' title is carried into the field.
    func testControlADetailsTitleIsCarried() {
        let model = self.clipIntoTheAuthor(Self.details, cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.details)), FuzzModel.describe(model))
    }

    /// The same quote pasted into a BODY paragraph keeps its author (the fragment path).
    func testControlPastedIntoABodyParagraphTheAuthorIsKept() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.pull))
        self.driver.setViewSelection(self.sourceRange())
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.length, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        let model = self.driver.model()
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document(Self.pull)), FuzzModel.describe(model))
    }

    // MARK: - Neighbours (p22 fix wave): every one-line field, every secondary line

    /// Paste `source`'s range into the one-line field whose text starts with `field` (after its first letter).
    private func clip(_ source: ChatInputBlock, into destination: ChatInputBlock, at field: String, cut: Bool) -> ChatInputContent {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]), destination, E.paragraph([E.run("end")])])
        HarnessComposerFuzzTests.arrange(self.driver, content)
        self.driver.setViewSelection(self.sourceRange())
        self.driver.settle(0.1)
        _ = self.driver.view.perform(cut ? #selector(UIResponderStandardEditActions.cut(_:)) : #selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: field).location + 1, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        return self.driver.model()
    }

    private static let codeDestination = ChatInputBlock.code(ChatInputCode(language: "LANG", runs: [E.run("body")]))
    private static let detailsDestination = ChatInputBlock.details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("dbody")])]), title: [E.run("TITLE")], expanded: true))
    private static let pullDestination = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [E.run("pbody")], author: [E.run("PAUTH")]))

    func testCutIntoACodeLanguageLosesNothing() {
        for source in [Self.pull, Self.quote, Self.code] {
            let model = self.clip(source, into: Self.codeDestination, at: "LANG", cut: true)
            let expected = ChatInputContent(blocks: [E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]), Self.codeDestination, E.paragraph([E.run("end")])])
            XCTAssertEqual(Self.letters(model), Self.letters(expected), FuzzModel.describe(model))
        }
    }

    func testCutIntoADetailsTitleLosesNothing() {
        for source in [Self.pull, Self.quote, Self.code] {
            let model = self.clip(source, into: Self.detailsDestination, at: "TITLE", cut: true)
            let expected = ChatInputContent(blocks: [E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]), Self.detailsDestination, E.paragraph([E.run("end")])])
            XCTAssertEqual(Self.letters(model), Self.letters(expected), FuzzModel.describe(model))
        }
    }

    func testCutIntoAPullQuoteAuthorLosesNothing() {
        for source in [Self.quote, Self.code, Self.details] {
            let model = self.clip(source, into: Self.pullDestination, at: "PAUTH", cut: true)
            let expected = ChatInputContent(blocks: [E.paragraph([E.run("aa")]), source, E.paragraph([E.run("bb")]), Self.pullDestination, E.paragraph([E.run("end")])])
            XCTAssertEqual(Self.letters(model), Self.letters(expected), FuzzModel.describe(model))
        }
    }

    /// The flattened text joins lines with ONE space (the field's convention, `oneLineFieldText`).
    func testTheFieldTakesTheFragmentOnOneLineJoinedBySpaces() {
        let model = self.clipIntoTheAuthor(Self.quote, cut: false)
        XCTAssertEqual(self.destinationAuthor(model), "Qa qxy qau bA", FuzzModel.describe(model))
    }

    /// A MOVE of a code block with a language into a table CELL (a runs-only region) is refused (p19) or loses
    /// nothing. **p23:** this used `sourceRange()`, whose fixed `location: 1` lies inside THIS document's
    /// leading table cell, so the range covered the table in part, the move was refused for that, and the code
    /// block never moved: the case stayed green with the runs-only refusal neutered while the real move lost
    /// `clang`. The range now runs from the second "a" to the first "b" + 1 (the whole code block, a letter
    /// either side) and the target is inside the cell. Measured: red with the refusal (`destinationHolds`) AND
    /// the runs-only paste's covered text (`pasteFragment`, p23) neutered; green with either alone, since a
    /// move is Cut + Paste and the paste now carries the language (`HarnessCodeLanguageIntoRunsRegionTests`).
    func testAMoveOfACodeBlockWithALanguageIntoACellLosesNothing() {
        let table = ChatInputBlock.table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)],
                                                        rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [E.run("ce")]), ChatInputTableCell(runs: [E.run("ll")])])]))
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [table, E.paragraph([E.run("aa")]), Self.code, E.paragraph([E.run("bb")])]))
        let text = self.driver.viewText() as NSString
        let start = text.range(of: "aa").location + 1
        let end = text.range(of: "bb").location + 1
        let target = text.range(of: "ce").location + 1
        let violation = HarnessComposerFuzzTests.moveViolation(start, end, target, on: self.driver)
        XCTAssertNil(violation, violation ?? "")
    }

    /// A SLICE of a code body (the language not in the range) pasted into a field is the slice alone: the
    /// fragment carries the language as metadata, and flattening it from the fragment (the fix wave's first
    /// version) pasted the language a second time. Reduced from default / edited seed 27.
    func testACodeBodySlicePastedIntoAFieldIsTheSliceAlone() {
        let code = ChatInputBlock.code(ChatInputCode(language: "clang", runs: [E.run("cxyz")]))
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("aa")]), code, E.paragraph([E.run("bb")]), Self.destination, E.paragraph([E.run("end")])]))
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: "cxyz").location + 1, length: 2))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let after = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: after.range(of: "QA").location + 1, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        let model = self.driver.model()
        XCTAssertEqual(self.destinationAuthor(model), "QxyA", FuzzModel.describe(model))
    }

    /// A move of a code body slice into the block's OWN language line: the slice moves, nothing is duplicated
    /// (seed 27's shape).
    func testAMoveOfACodeBodySliceIntoItsLanguage() {
        let code = ChatInputBlock.code(ChatInputCode(language: "clang", runs: [E.run("cxyz")]))
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [code]))
        // "clang\ncxyz": the slice "xy" is 7..<9, the target 1 is after the language's "c".
        let violation = HarnessComposerFuzzTests.moveViolation(7, 9, 1, on: self.driver)
        XCTAssertNil(violation, violation ?? "")
        guard case let .code(moved)? = self.driver.model().blocks.first else {
            XCTFail(FuzzModel.describe(self.driver.model()))
            return
        }
        // `moveViolation` undoes and redoes the move; the redone state is the move's.
        XCTAssertEqual(moved.language, "cxylang", FuzzModel.describe(self.driver.model()))
        XCTAssertEqual(moved.runs.map(\.text).joined(), "cz", FuzzModel.describe(self.driver.model()))
    }
}
