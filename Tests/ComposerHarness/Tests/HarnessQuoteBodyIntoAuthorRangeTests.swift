import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A selection from a block quote's BODY into its AUTHOR line:
///
///     [quote [p "body"] author="author"] [p "after"] [quote [p "zz"] author="AU"]   ("body\nauthor\nafter\nzz\nAU")
///     select 2..<7 ("dy" + break + "au")
///       Backspace   → [quote [p "bothor"] author=""]    the author's remainder "thor" became BODY text, the
///                                                        author is empty
///       type X      → [quote [p "boXthor"] author=""]
///       Copy        → the clipboard holds "dy" only: pasted into the other author, "AdyU" (the "au" is missing)
///       Cut + Paste → "au" is deleted and is on no clipboard: LOST (a drag-and-drop move, which is Cut + Paste,
///                      the same: fuzz default seed 40 step 22, "a local move lost content")
///     control: the reverse range, from the author into the paragraph after it (7..<15), keeps every letter
///       (Cut + Paste carries "thor aft")
///
/// The details-title precedent is the opposite (row 76, fixed twelfth wave): a range whose END enters a details
/// title keeps the title's tail AS the title.
///
/// **How it was seen.** p22 roam (2026-10-01): the default sweep's seed 40 failed the move op's content
/// check (a move from a nested quote's paragraph into its author lost "- [ ] op"); reduced to a set document
/// and one Cut / Copy / Backspace.
///
/// **Suspected cause.** Two halves. (1) The gate's cross-block replacement (`replaceAcrossBlocks` /
/// `applyReplaceOutcome`) treats the author line as an ordinary end leaf and merges its remainder into the
/// start block, and nothing re-mints the author from it (unlike `settleLanguageLinePresence` / the details
/// title's truncation). (2) The copy (`Document.extractFragment` through `writeSelectionToPasteboard`) carries
/// a quote's covered author slice only when the range STARTS in the author (p19, row 144); a range ending in it
/// drops the slice, so Cut deletes text it never copied.
///
/// **Severity.** CORRUPTS WHAT IS SENT: Cut and a move lose the user's text; the attribution becomes message
/// body text.
///
/// **Tier 1**: a view selection, `deleteBackward` / `copy:` / `cut:` / `paste:`.
@available(iOS 18.4, *)
final class HarnessQuoteBodyIntoAuthorRangeTests: XCTestCase {
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

    private static let document = ChatInputContent(blocks: [
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("body")])]), collapsed: false, author: [E.run("author")])),
        E.paragraph([E.run("after")]),
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("zz")])]), collapsed: false, author: [E.run("AU")])),
    ])

    /// Letters of the whole model, sorted (quote authors included).
    private static func letters(_ content: ChatInputContent) -> String {
        func runs(_ runs: [ChatInputRun]) -> String { runs.map(\.text).joined() }
        func text(_ blocks: [ChatInputBlock]) -> String {
            return blocks.map { block -> String in
                switch block {
                case let .paragraph(paragraph): return runs(paragraph.runs)
                case let .blockQuote(quote): return text(quote.content.blocks) + runs(quote.author)
                default: return ""
                }
            }.joined()
        }
        return String(text(content.blocks).filter(\.isLetter).sorted())
    }

    private func firstAuthor(_ content: ChatInputContent) -> String? {
        guard case let .blockQuote(quote)? = content.blocks.first else { return nil }
        return quote.author.map(\.text).joined()
    }

    /// Cut or Copy `range`, then paste into the second quote's author (after its "A").
    private func clip(_ range: NSRange, cut: Bool) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        _ = self.driver.view.perform(cut ? #selector(UIResponderStandardEditActions.cut(_:)) : #selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: "AU").location + 1, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        return self.driver.model()
    }

    // MARK: - Red

    func testCutAndPasteOfARangeIntoTheAuthorLosesNothing() {
        let model = self.clip(NSRange(location: 2, length: 5), cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document), "Cut + Paste lost letters: \(FuzzModel.describe(model))")
    }

    func testCopyOfARangeIntoTheAuthorCarriesTheAuthorSlice() {
        let model = self.clip(NSRange(location: 2, length: 5), cut: false)
        guard case let .blockQuote(second)? = model.blocks.last else {
            XCTFail("no second quote: \(FuzzModel.describe(model))")
            return
        }
        let author = second.author.map(\.text).joined()
        XCTAssertTrue(author.contains("dy") && author.contains("au"), "the pasted copy is \"\(author)\", without the author slice \"au\": \(FuzzModel.describe(model))")
    }

    func testBackspaceOverARangeIntoTheAuthorKeepsTheAuthorsRemainder() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 2, length: 5))
        self.driver.settle(0.1)
        self.driver.deleteBackward()
        self.driver.settle(0.2)
        let model = self.driver.model()
        XCTAssertEqual(self.firstAuthor(model), "thor", "the author's remainder did not stay the author: \(FuzzModel.describe(model))")
    }

    // MARK: - Controls

    /// The reverse range — from the author into the paragraph after — loses nothing through Cut + Paste.
    func testControlARangeFromTheAuthorOnLosesNothing() {
        let model = self.clip(NSRange(location: 7, length: 8), cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document), FuzzModel.describe(model))
    }

    /// A range inside the body alone is copied whole.
    func testControlARangeInsideTheBodyCopiesWhole() {
        let model = self.clip(NSRange(location: 1, length: 2), cut: true)
        XCTAssertEqual(Self.letters(model), Self.letters(Self.document), FuzzModel.describe(model))
    }

    // MARK: - Neighbours (p22 fix wave)

    func testTypingOverARangeIntoTheAuthorKeepsTheAuthorsRemainder() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 2, length: 5))
        self.driver.settle(0.1)
        self.driver.insert("X")
        self.driver.settle(0.2)
        let model = self.driver.model()
        XCTAssertEqual(self.firstAuthor(model), "thor", FuzzModel.describe(model))
        XCTAssertEqual(model.plainText.hasPrefix("boX"), true, FuzzModel.describe(model))
    }

    func testACompositionOverARangeIntoTheAuthorKeepsTheAuthorsRemainder() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 2, length: 5))
        self.driver.settle(0.1)
        let input = self.driver.view as! (UIView & UITextInput)
        for text in ["k", "か"] {
            input.setMarkedText(text, selectedRange: NSRange(location: 1, length: 0))
            self.driver.settle(0.03)
        }
        input.unmarkText()
        self.driver.settle(0.2)
        XCTAssertEqual(self.firstAuthor(self.driver.model()), "thor", FuzzModel.describe(self.driver.model()))
    }

    /// From the FIRST of two children into the author: the second child goes with the range, the author keeps
    /// its remainder.
    func testFromTheFirstOfTwoChildrenIntoTheAuthor() {
        let two = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("body")]), E.paragraph([E.run("more")])]), collapsed: false, author: [E.run("author")])),
            E.paragraph([E.run("after")]),
        ])
        HarnessComposerFuzzTests.arrange(self.driver, two)
        self.driver.setViewSelection(NSRange(location: 2, length: 10))   // "dy⏎more⏎au"
        self.driver.settle(0.1)
        self.driver.deleteBackward()
        self.driver.settle(0.2)
        let model = self.driver.model()
        XCTAssertEqual(self.firstAuthor(model), "thor", FuzzModel.describe(model))
    }

    /// From a NESTED quote's child into the OUTER author: both quotes keep their structure, the outer author
    /// keeps its remainder, and Cut + Paste loses nothing.
    func testFromANestedChildIntoTheOuterAuthor() {
        let nested = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("body")])]), collapsed: false, author: [E.run("inner")])),
            ]), collapsed: false, author: [E.run("author")])),
            E.paragraph([E.run("after")]),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("zz")])]), collapsed: false, author: [E.run("AU")])),
        ])
        HarnessComposerFuzzTests.arrange(self.driver, nested)
        self.driver.setViewSelection(NSRange(location: 2, length: 11))   // "dy⏎inner⏎au"
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessComposerFuzzTests.notePasteboardWritten()
        self.driver.settle(0.3)
        XCTAssertEqual(self.firstAuthor(self.driver.model()), "thor", FuzzModel.describe(self.driver.model()))
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: text.range(of: "after").location, length: 0))
        self.driver.settle(0.1)
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        let model = self.driver.model()
        XCTAssertEqual(Self.letters(model).count, Self.letters(nested).count, FuzzModel.describe(model))
    }

    /// A pull quote's body into its author already kept the remainder (its author is in a leaf container).
    func testControlAPullQuoteBodyIntoItsAuthor() {
        let pull = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [E.run("body")], author: [E.run("author")])), E.paragraph([E.run("after")])])
        HarnessComposerFuzzTests.arrange(self.driver, pull)
        self.driver.setViewSelection(NSRange(location: 2, length: 5))
        self.driver.settle(0.1)
        self.driver.deleteBackward()
        self.driver.settle(0.2)
        guard case let .pullQuote(quote)? = self.driver.model().blocks.first else {
            XCTFail(FuzzModel.describe(self.driver.model()))
            return
        }
        XCTAssertEqual(quote.author.map(\.text).joined(), "thor")
    }
}
