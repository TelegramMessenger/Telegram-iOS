import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, an IME composition delivered through
/// `setAttributedMarkedText(_:selectedRange:)` — the attributed twin of `setMarkedText`, which the
/// keyboard uses when its marked text carries attributes (segment underlines) — over a selection that
/// crosses blocks is not decided by the surface gate. The plain `setMarkedText` door was fixed for
/// exactly these shapes (findings.md, 2026-09-24, `HarnessCompositionOverSelectionTests`); the
/// attributed door still bypasses it:
///
///     select "␣line⏎Quot" ([p "Intro line."] [quote "Quoted text here."]), compose k → か → … → 漢字
///       plain:       [p "Intro漢字d text here."]
///       attributed:  [p "Introk漢字d text here."]          ← the first candidate stays behind
///     select from a paragraph into a code body:  plain keeps the code block; attributed MERGES it
///       into the paragraph ([p "Code 漢字t x = 1"])
///     select from a pull quote's body into its author: plain keeps the author; attributed drops it
///     select from a table cell into the paragraph after (the table covered in part): plain is refused
///       like typing; attributed empties the second row and the paragraph after, and the model and the
///       engine's lines disagree
///
/// Undo restores the document in each case.
///
/// **How it was seen.** p12 roam, 2026-09-24: the composition-over-selection shapes re-run through
/// `setAttributedMarkedText` beside `setMarkedText`.
///
/// **Suspected cause.** `TGIDObservingBlockTextView` overrides `setMarkedText:selectedRange:` to have
/// the selection decided by the gate first; `setAttributedMarkedText:selectedRange:` is not overridden,
/// so it reaches `-[IDBlockTextView setAttributedMarkedText:selectedRange:]` and the controller's own
/// identity merge.
///
/// **Tier 1**: `setAttributedMarkedText(_:selectedRange:)` / `unmarkText()` are the calls the keyboard
/// makes; the plain `setMarkedText` door over the same selection is the oracle (and the control).
@available(iOS 18.4, *)
final class HarnessAttributedMarkedTextOverSelectionTests: XCTestCase {
    private let japanese = ["k", "か", "かn", "かん", "かんj", "かんじ", "漢字"]

    private func compose(_ content: ChatInputContent, select range: NSRange, attributed: Bool) throws -> (model: String, mismatch: String?) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(content)
        driver.setViewSelection(range)
        driver.settle(0.1)
        XCTAssertEqual(driver.viewSelection(), range, "precondition: the selection did not land")
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        for step in self.japanese {
            let caret = NSRange(location: (step as NSString).length, length: 0)
            if attributed {
                input.setAttributedMarkedText?(NSAttributedString(string: step, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]), selectedRange: caret)
            } else {
                input.setMarkedText(step, selectedRange: caret)
            }
            driver.settle(0.03)
        }
        input.unmarkText()
        driver.settle(0.3)
        let model = driver.model()
        return (FuzzModel.describe(FuzzModel.normalized(model)), FuzzModel.engineAxisMismatch(model, engineText: driver.viewText()))
    }

    private func assertAttributedMatchesPlain(_ content: ChatInputContent, _ range: NSRange, _ what: String) throws {
        let plain = try self.compose(content, select: range, attributed: false)
        XCTAssertNil(plain.mismatch, "control: the plain composition broke the engine axis")
        let attributed = try self.compose(content, select: range, attributed: true)
        XCTAssertNil(attributed.mismatch, "\(what): the model and the engine disagree")
        XCTAssertEqual(attributed.model, plain.model, "\(what): an attributed composition did not do what the plain one does")
    }

    func testFromAParagraphIntoAQuote() throws {
        try self.assertAttributedMatchesPlain(HarnessComposerFuzzTests.startingContents()[3], NSRange(location: 5, length: 12), "paragraph → quote")
    }

    func testFromAParagraphIntoACodeBody() throws {
        try self.assertAttributedMatchesPlain(HarnessComposerFuzzTests.startingContents()[4], NSRange(location: 5, length: 10), "paragraph → code")
    }

    func testFromAPullQuoteBodyIntoItsAuthor() throws {
        try self.assertAttributedMatchesPlain(HarnessComposerFuzzTests.extendedStartingContents()[0], NSRange(location: 20, length: 12), "pull quote body → author")
    }

    func testFromATableCellIntoTheParagraphAfter() throws {
        try self.assertAttributedMatchesPlain(HarnessComposerFuzzTests.extendedStartingContents()[3], NSRange(location: 20, length: 16), "table cell → paragraph after")
    }

    /// The attributed door ATTRIBUTES its commit as the plain one does: over a bold selection inside
    /// one block the text stays bold, and the keyboard's segment underline does not reach the model.
    func testAttributesMatchThePlainDoorOverABoldSelection() throws {
        try self.assertAttributedMatchesPlain(HarnessComposerFuzzTests.startingContents()[2], NSRange(location: 4, length: 5), "bold selection")
    }

    /// …and over a cross-block selection starting in a formatted run (a spoiler into a quote), where
    /// the gate resolves the selection first and the commit takes the typing attributes from before it.
    func testAttributesMatchThePlainDoorFromASpoilerIntoAQuote() throws {
        var spoiler = ChatInputInlineAttributes()
        spoiler.spoiler = true
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "Intro "), ChatInputRun(text: "line.", attributes: spoiler)])),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
        ])
        try self.assertAttributedMatchesPlain(content, NSRange(location: 8, length: 9), "spoiler → quote")
    }

    /// Control: across two plain paragraphs the controller's merge is already right, attributed or not.
    func testControlAcrossTwoParagraphs() throws {
        try self.assertAttributedMatchesPlain(HarnessContent.plainText("First paragraph.\nSecond paragraph."), NSRange(location: 2, length: 18), "paragraph → paragraph")
    }
}
