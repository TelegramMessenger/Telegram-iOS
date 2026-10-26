import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** The p21 wall (`authoredQuoteWall`) protects an authored block quote only when the
/// deleted range is EXACTLY the one invisible break before it. Any wider range from the paragraph above into
/// the quote's lone child — one more character either side, Backspace, Cut, typing or a composition over it —
/// still dissolves the quote, and its AUTHOR becomes an ordinary body line, sent as message text:
///
///     [p ".Rem"] [quote [p "closed"] author="q"] [p "Afte"]      (".Rem\nclosed\nq\nAfte")
///       select 3..<5 ("m" + the break), Backspace (or Cut)  →  [p ".Reclosed"] [p "q"] [p "Afte"]
///       select 3..<6, type X                                →  [p ".ReXlosed"] [p "q"] [p "Afte"]
///       select 2..<6, compose か                            →  [p ".Rかlosed"] [p "q"] [p "Afte"]
///       select 4..<5 (the break alone), Backspace           →  unchanged (the p21 wall; control)
///     nested: [p ".Rem"] [quote [quote [p "closed"] author="in"]], select 3..<5, Backspace
///       →  [p ".Reclosed"] [quote [p "in"]]   (the inner quote's attribution is body text in the outer one)
///
/// Controls: with a SECOND child the quote keeps its author (only the first child merges up); an author-less
/// quote dissolves into the paragraph with no stray line; a pull quote with an author keeps it.
///
/// **How it was seen.** p22 roam (2026-10-01), auditing the p21 `authoredQuoteWall` (Priority 1b): every
/// range around the break, every verb.
///
/// **Suspected cause.** The wall lives in the Backspace rule table (`backspaceJoinRules`), which the gate asks
/// only for a range that `rangeIsTheJoinBefore` (one character, empty text). Every other range goes to
/// `replaceAcrossBlocks` / `applyReplaceOutcome`, where "a block quote's endpoint child merges like a
/// paragraph" — the lone child merges into the start paragraph, the quote has no children left, and
/// `settleOrphanedSecondaryLines` turns its non-empty orphaned author line into a body paragraph (row 26's fix
/// removes only an EMPTY orphan). The p21 decision ("an authored quote's author is not something one
/// keystroke turns into body text") holds for one range and not for its neighbours.
///
/// **Severity.** CORRUPTS WHAT IS SENT: the attribution is sent as a line of message text and the quote is
/// gone, from an ordinary selection-and-delete across the line boundary.
///
/// **Tier 1**: a view selection, then `deleteBackward` / `cut:` / `insertText` / `setMarkedText`.
@available(iOS 18.4, *)
final class HarnessAuthoredQuoteWideRangeTests: XCTestCase {
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

    private static func quote(_ children: [ChatInputBlock], author: String?) -> ChatInputBlock {
        return .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: children), collapsed: false, author: author.map { [E.run($0)] } ?? []))
    }

    private static let authored = ChatInputContent(blocks: [
        E.paragraph([E.run(".Rem")]), quote([E.paragraph([E.run("closed")])], author: "q"), E.paragraph([E.run("Afte")]),
    ])

    private enum Verb { case backspace, cut, type, compose }

    private func edit(_ content: ChatInputContent, _ range: NSRange, _ verb: Verb) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, content)
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        switch verb {
        case .backspace:
            self.driver.deleteBackward()
        case .cut:
            _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            HarnessComposerFuzzTests.notePasteboardWritten()
            self.driver.settle(0.3)
        case .type:
            self.driver.insert("X")
        case .compose:
            let input = self.driver.view as! (UIView & UITextInput)
            for text in ["k", "か"] {
                input.setMarkedText(text, selectedRange: NSRange(location: 1, length: 0))
                self.driver.settle(0.03)
            }
            input.unmarkText()
        }
        self.driver.settle(0.2)
        return self.driver.model()
    }

    /// The author `name` is still some block quote's author, at any depth, and no paragraph's whole text.
    private func assertAuthorKept(_ name: String, in content: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        func authors(_ blocks: [ChatInputBlock]) -> [String] {
            return blocks.flatMap { block -> [String] in
                if case let .blockQuote(quote) = block { return [quote.author.map(\.text).joined()] + authors(quote.content.blocks) }
                return []
            }
        }
        func paragraphs(_ blocks: [ChatInputBlock]) -> [String] {
            return blocks.flatMap { block -> [String] in
                switch block {
                case let .paragraph(paragraph): return [paragraph.runs.map(\.text).joined()]
                case let .blockQuote(quote): return paragraphs(quote.content.blocks)
                default: return []
                }
            }
        }
        XCTAssertTrue(authors(content.blocks).contains(name), "the quote's author \"\(name)\" is gone: \(FuzzModel.describe(content))", file: file, line: line)
        XCTAssertFalse(paragraphs(content.blocks).contains(name), "the author \"\(name)\" became a body line: \(FuzzModel.describe(content))", file: file, line: line)
    }

    // MARK: - Red

    func testBackspaceFromInsideTheParagraphAboveKeepsTheAuthor() {
        self.assertAuthorKept("q", in: self.edit(Self.authored, NSRange(location: 3, length: 2), .backspace))
    }

    func testCutFromInsideTheParagraphAboveKeepsTheAuthor() {
        self.assertAuthorKept("q", in: self.edit(Self.authored, NSRange(location: 3, length: 2), .cut))
    }

    func testTypingOverARangeIntoTheQuoteKeepsTheAuthor() {
        self.assertAuthorKept("q", in: self.edit(Self.authored, NSRange(location: 3, length: 3), .type))
    }

    func testACompositionOverARangeIntoTheQuoteKeepsTheAuthor() {
        self.assertAuthorKept("q", in: self.edit(Self.authored, NSRange(location: 2, length: 4), .compose))
    }

    func testBackspaceFromTheBreakIntoTheQuoteTextKeepsTheAuthor() {
        self.assertAuthorKept("q", in: self.edit(Self.authored, NSRange(location: 4, length: 2), .backspace))
    }

    func testANestedAuthoredQuoteKeepsItsAuthor() {
        let nested = ChatInputContent(blocks: [
            E.paragraph([E.run(".Rem")]), Self.quote([Self.quote([E.paragraph([E.run("closed")])], author: "in")], author: nil), E.paragraph([E.run("Afte")]),
        ])
        self.assertAuthorKept("in", in: self.edit(nested, NSRange(location: 3, length: 2), .backspace))
    }

    // MARK: - Controls

    /// The p21 wall: the break alone changes nothing.
    func testControlTheBreakAloneIsAWall() {
        let model = self.edit(Self.authored, NSRange(location: 4, length: 1), .backspace)
        XCTAssertEqual(FuzzModel.normalized(model), FuzzModel.normalized(Self.authored))
    }

    /// With a second child the first merges up and the quote keeps its author.
    func testControlASecondChildKeepsTheQuote() {
        let two = ChatInputContent(blocks: [
            E.paragraph([E.run(".Rem")]), Self.quote([E.paragraph([E.run("closed")]), E.paragraph([E.run("more")])], author: "q"), E.paragraph([E.run("Afte")]),
        ])
        self.assertAuthorKept("q", in: self.edit(two, NSRange(location: 3, length: 2), .backspace))
    }

    /// Without an author the quote dissolves into the paragraph, no stray line.
    func testControlAnAuthorlessQuoteDissolves() {
        let plain = ChatInputContent(blocks: [E.paragraph([E.run(".Rem")]), Self.quote([E.paragraph([E.run("closed")])], author: nil), E.paragraph([E.run("Afte")])])
        let model = self.edit(plain, NSRange(location: 3, length: 2), .backspace)
        XCTAssertEqual(FuzzModel.describe(model), "[p body \".Reclosed\"] [p body \"Afte\"]")
    }

    /// A pull quote with an author keeps it over the same range.
    func testControlAnAuthoredPullQuoteKeepsItsAuthor() {
        let pull = ChatInputContent(blocks: [E.paragraph([E.run(".Rem")]), .pullQuote(ChatInputPullQuote(runs: [E.run("closed")], author: [E.run("q")])), E.paragraph([E.run("Afte")])])
        let model = self.edit(pull, NSRange(location: 3, length: 3), .backspace)
        XCTAssertTrue(model.blocks.contains { block in
            if case let .pullQuote(quote) = block { return quote.author.map(\.text).joined() == "q" }
            return false
        }, FuzzModel.describe(model))
    }

    // MARK: - Neighbours (p22 fix wave): one rule for every entry point

    /// The decided shape: the lone child's remainder merges up, the quote keeps an EMPTY body line and its
    /// author (what a document set renders for an authored quote with no children).
    func testTheQuoteKeepsAnEmptyBodyAndItsAuthor() {
        let model = self.edit(Self.authored, NSRange(location: 3, length: 2), .backspace)
        XCTAssertEqual(FuzzModel.describe(model), FuzzModel.describe(ChatInputContent(blocks: [
            E.paragraph([E.run(".Reclosed")]), Self.quote([E.paragraph([])], author: "q"), E.paragraph([E.run("Afte")]),
        ])))
    }

    /// The same shape survives a get → set → get round trip.
    func testTheResultIsStableThroughASet() {
        let model = self.edit(Self.authored, NSRange(location: 3, length: 2), .backspace)
        HarnessComposerFuzzTests.arrange(self.driver, model)
        self.driver.settle(0.1)
        XCTAssertEqual(FuzzModel.normalized(self.driver.model()), FuzzModel.normalized(model))
    }

    /// One undo restores the quote exactly.
    func testUndoRestoresTheQuote() throws {
        _ = self.edit(Self.authored, NSRange(location: 3, length: 3), .type)
        let undoManager = try XCTUnwrap(self.driver.undoManager)
        undoManager.undo()
        self.driver.settle(0.2)
        XCTAssertEqual(FuzzModel.normalized(self.driver.model()), FuzzModel.normalized(Self.authored))
    }

    /// A drag-and-drop MOVE of the same range (Cut + Paste) keeps the author and loses no letter.
    func testAMoveOfTheRangeKeepsTheAuthor() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.authored)
        let length = (self.driver.viewText() as NSString).length
        let violation = HarnessComposerFuzzTests.moveViolation(3, 5, length, on: self.driver)
        XCTAssertNil(violation, violation ?? "")
        self.assertAuthorKept("q", in: self.driver.model())
    }

    /// Return over the range (a deletion, then a split): the author stays an author.
    func testReturnOverTheRangeKeepsTheAuthor() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.authored)
        self.driver.setViewSelection(NSRange(location: 3, length: 2))
        self.driver.settle(0.1)
        self.driver.insert("\n")
        self.driver.settle(0.2)
        self.assertAuthorKept("q", in: self.driver.model())
    }

    /// A quote nested as the LONE child of an AUTHORED outer quote: both authors survive.
    func testNestedInAnAuthoredQuoteBothAuthorsSurvive() {
        let nested = ChatInputContent(blocks: [
            E.paragraph([E.run(".Rem")]), Self.quote([Self.quote([E.paragraph([E.run("closed")])], author: "in")], author: "out"), E.paragraph([E.run("Afte")]),
        ])
        let model = self.edit(nested, NSRange(location: 3, length: 2), .backspace)
        self.assertAuthorKept("in", in: model)
        self.assertAuthorKept("out", in: model)
    }

    /// Control (p19, unchanged): a range covering the quote's whole body drops the quote WITH its author, and
    /// the copy is widened to carry it, so Cut + Paste back keeps every letter.
    func testControlCoveringTheWholeBodyDropsTheQuoteAndCutCarriesTheAuthor() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.authored)
        self.driver.setViewSelection(NSRange(location: 3, length: 8))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        XCTAssertFalse(self.driver.model().blocks.contains { if case .blockQuote = $0 { return true }; return false })
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        self.assertAuthorKept("q", in: self.driver.model())
    }
}
