import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** Deleting exactly the LINE BREAK between a paragraph and a following block quote or
/// pull quote that has an AUTHOR (select the break, then Backspace or Cut — a drag-and-drop move of it
/// does the same, since a move is Cut + Paste) dissolves the quote:
///
///     [p ".Rem"] [quote [p "closed"] author="q"] [p "Afte"]   (".Rem\nclosed\nq\nAfte"), select 4..<5, Backspace
///       → [p ".Rem"] [p "closed"] [p "Afte"]                   the quote is gone and its AUTHOR TEXT "q" is lost
///     [p ".Rem"] [pull "closed" author="q"] [p "Afte"], the same
///       → [p ".Rem"] [p "closed"] [p "q"] [p "Afte"]           the pull quote is gone, its author a body line
///     a move of that break to offset 2 is refused for the pull quote and STILL changes the document as
///     above; for the block quote it is accepted and loses the author
///     controls: the break before a CODE block (with a language) changes nothing; between two paragraphs
///       it joins them (".Remclosed")
///
/// Nothing joins: ".Rem" and "closed" stay apart, so the edit is not a join either — the only effect is
/// that the container is destroyed.
///
/// **How it was seen.** p21 roam (2026-10-01), the default fuzz sweep (seed 19 step 41): the `move` op's
/// "a refused move changed the model" invariant, a move of one character (the break before a pull quote)
/// four places back. Reduced by setting the document directly; then Backspace and Cut over the same range
/// do it with no move at all.
///
/// **Suspected cause.** The surface gate's cross-block replacement (`replaceAcrossBlocks` /
/// `applyReplaceOutcome`, `RichTextEngineEditorView+SurfaceGate.swift`): a range from a paragraph's end to
/// the quote's first block start "covers" the quote's primary region in the gate's `containerIsCovered`
/// sense with no text kept, so the container is dropped with its second lines (the author) — the p19
/// widening rule reads a quote whose primary blocks a range covers "second lines included" as covered,
/// and an empty coverage at its very start satisfies it. The paragraph-to-paragraph case merges; the code
/// block is refused.
///
/// **Severity.** CORRUPTS WHAT IS SENT: a quote's author text is deleted (block quote), or a pull quote
/// becomes plain paragraphs with its author as body text, from one Backspace on an invisible character.
///
/// **Tier 1**: a view selection and `deleteBackward` / `cut:`, as the keyboard and the edit menu drive them.
@available(iOS 18.4, *)
final class HarnessSeparatorBeforeQuoteDeletionTests: XCTestCase {
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

    private static let blockQuote = ChatInputContent(blocks: [
        E.paragraph([E.run(".Rem")]),
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("closed")])]), collapsed: false, author: [E.run("q")])),
        E.paragraph([E.run("Afte")]),
    ])
    private static let pullQuote = ChatInputContent(blocks: [
        E.paragraph([E.run(".Rem")]),
        .pullQuote(ChatInputPullQuote(runs: [E.run("closed")], author: [E.run("q")])),
        E.paragraph([E.run("Afte")]),
    ])

    private func deleteBreak(in content: ChatInputContent, cut: Bool) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, content)
        XCTAssertEqual((self.driver.viewText() as NSString).substring(with: NSRange(location: 4, length: 1)), "\n", "precondition: 4..<5 is the break")
        self.driver.setViewSelection(NSRange(location: 4, length: 1))
        self.driver.settle(0.1)
        if cut {
            _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
            HarnessComposerFuzzTests.notePasteboardWritten()
            self.driver.settle(0.3)
        } else {
            self.driver.deleteBackward()
            self.driver.settle(0.2)
        }
        return self.driver.model()
    }

    private func hasBlockQuoteWithAuthor(_ content: ChatInputContent) -> Bool {
        return content.blocks.contains { block in
            if case let .blockQuote(quote) = block { return quote.author.map(\.text).joined() == "q" }
            return false
        }
    }

    private func hasPullQuoteWithAuthor(_ content: ChatInputContent) -> Bool {
        return content.blocks.contains { block in
            if case let .pullQuote(quote) = block { return quote.author.map(\.text).joined() == "q" }
            return false
        }
    }

    // MARK: - Red

    func testBackspaceOverTheBreakBeforeABlockQuoteKeepsTheQuoteAndItsAuthor() {
        let model = self.deleteBreak(in: Self.blockQuote, cut: false)
        XCTAssertTrue(self.hasBlockQuoteWithAuthor(model), "the block quote or its author is gone: \(FuzzModel.describe(model))")
    }

    func testCutOfTheBreakBeforeABlockQuoteKeepsTheQuoteAndItsAuthor() {
        let model = self.deleteBreak(in: Self.blockQuote, cut: true)
        XCTAssertTrue(self.hasBlockQuoteWithAuthor(model), "the block quote or its author is gone: \(FuzzModel.describe(model))")
    }

    func testBackspaceOverTheBreakBeforeAPullQuoteKeepsThePullQuote() {
        let model = self.deleteBreak(in: Self.pullQuote, cut: false)
        XCTAssertTrue(self.hasPullQuoteWithAuthor(model), "the pull quote is gone: \(FuzzModel.describe(model))")
    }

    /// The fuzz's shape: a move the editor REFUSES must leave the document alone.
    func testARefusedMoveOfTheBreakBeforeAPullQuoteChangesNothing() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.pullQuote)
        let violation = HarnessComposerFuzzTests.moveViolation(4, 5, 2, on: self.driver)
        XCTAssertNil(violation, violation ?? "")
    }

    // MARK: - Controls

    func testControlTheBreakBeforeACodeBlockChangesNothing() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run(".Rem")]), .code(ChatInputCode(language: "sw", runs: [E.run("closed")])), E.paragraph([E.run("Afte")])])
        let model = self.deleteBreak(in: content, cut: false)
        XCTAssertEqual(FuzzModel.normalized(model), FuzzModel.normalized(content))
    }

    func testControlTheBreakBetweenTwoParagraphsJoinsThem() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run(".Rem")]), E.paragraph([E.run("closed")]), E.paragraph([E.run("Afte")])])
        let model = self.deleteBreak(in: content, cut: false)
        XCTAssertEqual(FuzzModel.describe(model), "[p body \".Remclosed\"] [p body \"Afte\"]")
    }
}
