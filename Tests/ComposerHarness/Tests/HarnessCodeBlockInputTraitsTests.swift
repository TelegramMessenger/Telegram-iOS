import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, the keyboard autocapitalizes and autocorrects inside a
/// code block. Typing `let teh ` at the start of a code-block line in the composer produced
/// `Let the ` — the keyboard came up shifted on every new code line and replaced "teh" with "the".
/// The previous editor backend switched these traits off while the caret was in a code region
/// (`DocumentCanvasView+MarkedText.swift`: `autocorrectionType`, `autocapitalizationType`,
/// `spellCheckingType` are `.no`/`.none` when `caretIsInCodeRegion`, plus
/// `refreshCodeInputTraitsIfNeeded()` to reload the keyboard on entering/leaving code). The engine's
/// `IDBlockTextView` synthesizes fixed values (`_autocapitalizationType = Sentences`,
/// autocorrection/spell-checking `Default`, `IDBlockTextView.m:168-171`) and nothing in
/// `RichTextEngineEditor` / `RichTextInputDecHost` varies them by region, so the policy was lost in
/// the backend swap. Legacy has no code blocks, so it is not a control here.
///
/// **How it was seen.** K1, engine, 2026-09-22: `two-paragraphs` → Select All → Format ▸ Code →
/// Return → typed `let teh ` → model `"\nLet the First paragraph..."`. Second reproduction:
/// `one-paragraph` → Select All → Format ▸ Code, then lldb on the first responder read
/// `autocapitalizationType == 2` (sentences), `autocorrectionType == 0`, `spellCheckingType == 0`
/// with the caret in the code block.
///
/// **Tier 1**, because the defect is the traits the text view reports for a caret in a code
/// block; no keyboard is needed to read them. The keyboard's own reaction (shift state, the
/// replacement) is UIKit's response to these values.
final class HarnessCodeBlockInputTraitsTests: XCTestCase {
    private func trait(_ view: UIView, _ key: String) -> Int? {
        return (view.value(forKey: key) as? NSNumber)?.intValue
    }

    func testACaretInACodeBlockTurnsOffAutocapitalizationAndAutocorrection() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        // "Intro" (0..<5), then the code block's text starts at flat offset 6.
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        let textView = try HarnessEngine.textView(in: root)

        // Control: in the ordinary paragraph the prose traits are expected and present.
        node.selectedRange = NSRange(location: 2, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.trait(textView, "autocapitalizationType"),
                       UITextAutocapitalizationType.sentences.rawValue,
                       "precondition: the paragraph does not report sentence capitalization")

        node.selectedRange = NSRange(location: 8, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 8, length: 0),
                       "precondition: the caret did not land in the code block")

        XCTAssertEqual(self.trait(textView, "autocapitalizationType"),
                       UITextAutocapitalizationType.none.rawValue,
                       "a caret in a code block still asks the keyboard to capitalize sentences")
        XCTAssertEqual(self.trait(textView, "autocorrectionType"),
                       UITextAutocorrectionType.no.rawValue,
                       "a caret in a code block still lets the keyboard autocorrect")
        XCTAssertEqual(self.trait(textView, "spellCheckingType"),
                       UITextSpellCheckingType.no.rawValue,
                       "a caret in a code block still spell-checks")

        node.resignInputFirstResponder()
    }

    /// Smart punctuation rewrites what the user types or pastes: `"` becomes a curly quote, `--` an
    /// em dash, and a paste gains a space on either side. In prose that is the point; in code it
    /// breaks the code. The first traits fix switched off capitalisation, autocorrection and spell
    /// checking in code blocks and left these three on (found reviewing that fix, 2026-09-23).
    func testACaretInACodeBlockTurnsOffSmartPunctuation() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { node.resignInputFirstResponder() }
        let textView = try HarnessEngine.textView(in: root)

        node.selectedRange = NSRange(location: 2, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.trait(textView, "smartQuotesType"), UITextSmartQuotesType.default.rawValue,
                       "precondition: the paragraph does not report default smart quotes")

        node.selectedRange = NSRange(location: 8, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.trait(textView, "smartQuotesType"), UITextSmartQuotesType.no.rawValue,
                       "a caret in a code block still turns straight quotes into curly ones")
        XCTAssertEqual(self.trait(textView, "smartDashesType"), UITextSmartDashesType.no.rawValue,
                       "a caret in a code block still turns -- into a dash")
        XCTAssertEqual(self.trait(textView, "smartInsertDeleteType"), UITextSmartInsertDeleteType.no.rawValue,
                       "a caret in a code block still pads pasted text with spaces")

        // And back: leaving the code block restores the prose behaviour.
        node.selectedRange = NSRange(location: 2, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.trait(textView, "smartQuotesType"), UITextSmartQuotesType.default.rawValue,
                       "leaving the code block did not restore smart quotes")
    }
}
