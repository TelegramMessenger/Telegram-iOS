import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02).** A carriage return in content that arrives by a SET — a draft or an edited
/// message whose text holds CR or CRLF line endings — is kept in the model as `U+000D`. TextKit draws it as a line
/// break, but structurally it is a character: the model's paragraph holds "a\r\nb", the text route sends that, and
/// the message loads back for editing as TWO paragraphs, the first ending in a stray CR (`[p "a\r"] [p "b"]`, the
/// send oracle's divergence). "a\rb" is kept as one paragraph holding a raw CR, sent as such.
///
/// The PASTE door normalises CR and CRLF to "\n" since p20 (`EnginePasteSource.normalisingLineEndings`, the host
/// view's combine step, `HarnessPastedCarriageReturnTests`); the set door does not.
///
/// **Suspected cause.** The bridge's body render (`EngineDocumentBridge.engineText`) maps only "\n" (to `U+2028`);
/// CR passes through to the engine and back. The set door should normalise line endings as the paste door does
/// (CRLF / CR → "\n", then "\n" → `U+2028` in a block), and report it (`HarnessUnreportedSetNormalisationTests`).
///
/// **Severity.** Low (what is sent carries a stray CR; an edit load of it is split differently).
///
/// **Tier 1**: an external set and the send-path oracle.
@available(iOS 18.4, *)
final class HarnessSetCarriageReturnTests: XCTestCase {
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

    private func set(_ text: String) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run(text)])]))
        self.driver.settle(0.3)
        return self.driver.model()
    }

    // MARK: - Red

    func testACRLFInASetParagraphIsALineBreak() {
        let model = self.set("a\r\nb")
        XCTAssertFalse(model.plainText.contains("\r"), "the model keeps a CR: \(fuzzEscaped(model.plainText))")
        let divergence = HarnessSendPath.divergence(self.driver.chatCopy())
        XCTAssertNil(divergence, divergence?.description ?? "")
    }

    func testALoneCRInASetParagraphIsALineBreak() {
        let model = self.set("a\rb")
        XCTAssertEqual(model.plainText, "a\nb")
    }

    /// Every `UITextInput` answer over the paragraph agrees (`FuzzTextInputConsistency`: the tokenizer's boundaries,
    /// the selection geometry), at each caret and over each range to the end.
    private func textInputProblems(_ text: String) -> [String] {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("ab")]), E.paragraph([E.run(text)]), E.paragraph([E.run("end")])]))
        self.driver.settle(0.3)
        return self.currentTextInputProblems()
    }

    private func currentTextInputProblems() -> [String] {
        let input = self.driver.view as! (UIView & UITextInput)
        let total = (self.driver.viewText() as NSString).length
        var problems: [String] = []
        for lower in 0 ... total {
            for upper in Set([lower, total]) {
                self.driver.setViewSelection(NSRange(location: lower, length: upper - lower))
                if let problem = FuzzTextInputConsistency.violation(of: input) { problems.append("\(lower)..<\(upper): \(problem)") }
            }
        }
        return problems
    }

    /// Found by the p24 fuzz (default seeds 17, 24, 29; edited 9, 24, 26): with "cr\r\nlf" in a paragraph the
    /// paragraph-granularity boundary forward from a caret is on the wrong side, and a selection over the CR has
    /// no geometry (one rect at infinity: no highlight, the edit menu placed nowhere).
    func testTextInputAnswersAgreeOverASetCRLF() {
        let problems = self.textInputProblems("cr\r\nlf")
        XCTAssertTrue(problems.isEmpty, "\(problems.count) inconsistent answers, first: \(problems.prefix(3))")
    }

    func testTextInputAnswersAgreeOverASetLoneCR() {
        let problems = self.textInputProblems("cr\rlf")
        XCTAssertTrue(problems.isEmpty, "\(problems.count) inconsistent answers, first: \(problems.prefix(3))")
    }

    /// The same for a PARAGRAPH SEPARATOR (`U+2029`), which reached the model by a plain PASTE as well (the engine's
    /// paste normalised CR and CRLF since p20, not `U+2029`): a stock `UITextView` holding the same text answers
    /// consistently (measured p24 with the same check: 0 inconsistent answers for "cr\r\nlf", "cr\rlf" and
    /// "ps\u{2029}x"). Since the p24 fix wave the paste makes it a paragraph break and the answers agree.
    func testTextInputAnswersAgreeAfterAPastedParagraphSeparator() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("ab")]), E.paragraph([E.run("x")]), E.paragraph([E.run("end")])]))
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "x")), length: 0))
        self.driver.settle(0.1)
        UIPasteboard.general.items = [["public.utf8-plain-text": "ps\u{2029}y"]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        // p24 fix wave: the paste maps `U+2029` to a paragraph break, as it maps CR / CRLF (Core `normalisedLineBreaks`).
        XCTAssertFalse(self.driver.model().plainText.contains("\u{2029}"), "the paste kept U+2029: \(fuzzEscaped(self.driver.model().plainText))")
        XCTAssertTrue(self.driver.model().plainText.contains("ps\ny"), "the pasted text did not land as two lines: \(fuzzEscaped(self.driver.model().plainText))")
        let problems = self.currentTextInputProblems()
        XCTAssertTrue(problems.isEmpty, "\(problems.count) inconsistent answers, first: \(problems.prefix(3))")
    }

    // MARK: - Controls

    func testControlTextInputAnswersAgreeOverALineFeed() {
        let problems = self.textInputProblems("cr\nlf")
        XCTAssertTrue(problems.isEmpty, "\(problems.prefix(3))")
    }

    func testControlALineFeedInASetParagraphRoundTrips() {
        let model = self.set("a\nb")
        XCTAssertEqual(model.plainText, "a\nb")
        XCTAssertNil(HarnessSendPath.divergence(self.driver.chatCopy()))
    }

    /// The paste door normalises the same text (p20).
    func testControlAPastedCRLFIsALineBreak() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("x")])]))
        UIPasteboard.general.items = [["public.utf8-plain-text": "a\r\nb"]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        XCTAssertFalse(self.driver.model().plainText.contains("\r"), fuzzEscaped(self.driver.model().plainText))
    }
}
