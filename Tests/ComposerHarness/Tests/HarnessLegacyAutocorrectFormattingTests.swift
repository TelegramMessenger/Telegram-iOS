import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, a word the keyboard REPLACES (autocorrect `teh`→`the`, an
/// accepted prediction, the double-space period) loses bold / italic / monospace — the eighth wave's
/// open row L4, which could not be reduced because a programmatic `replace(_:withText:)` keeps bold.
///
/// **Mechanism (K1, 2026-09-23, lldb breakpoints on the text-storage mutators during a real
/// software-keyboard correction of " teh " typed after bold "abc"):**
///
///     -[_UIKeyboardStateManager acceptAutocorrectionForWordTerminator:…]
///     -[_UIKeyboardStateManager applyAutocorrection:]
///     -[UIKBInputDelegateManager replaceRange:oldText:withText:forReplaceAction:]
///     -[UITextView replaceRangeWithTextWithoutClosingTyping:replacementText:]      ← not replaceRange:withText:
///     -[UITextInputController _insertText:fromKeyboard:]
///     -[NSConcreteTextStorage replaceCharactersInRange:{4, 3} withAttributedString:"the"]
///
/// Each TYPED letter arrives with `"Attribute__Bold" = 1` (`ChatTextInputAttributes.bold`) and the
/// semibold font. The correction's string carries the semibold FONT but NOT the custom
/// `Attribute__Bold` key. The model reads bold from that key only, so `chatInputTextNodeDidUpdateText`
/// reports "the" plain, and the chat's echo re-renders it `.SFUI-Regular`: bold visibly lost.
///
/// **Tier 1**: `replaceRangeWithTextWithoutClosingTyping:replacementText:` is the private
/// `UITextView` entry point the keyboard's correction uses (the public `replace(_:withText:)` is the
/// control, and keeps bold); autocorrection itself needs the software keyboard, which the runner has
/// not. The reduction must fail the way K1 does to count: it is asserted on the model, as K1 was read.
final class HarnessLegacyAutocorrectFormattingTests: XCTestCase {
    private static let entryPoint = NSSelectorFromString("replaceRangeWithTextWithoutClosingTyping:replacementText:")

    private func correctLastWord(format: (inout ChatInputInlineAttributes) -> Void, usingKeyboardEntryPoint: Bool) throws -> ChatInputContent {
        var attributes = ChatInputInlineAttributes()
        format(&attributes)
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(ChatInputContent(blocks: [.paragraph(ChatInputParagraph(
            style: .body, list: nil, runs: [ChatInputRun(text: "abc teh", attributes: attributes)]))]))
        arranged = value
        HarnessLegacy.select(value, NSRange(location: 7, length: 0))
        let textView = value.textView
        XCTAssertTrue(textView.responds(to: Self.entryPoint), "precondition: UITextView no longer has the keyboard's replacement entry point")
        let start = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: 4))
        let end = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: 7))
        let range = try XCTUnwrap(textView.textRange(from: start, to: end))
        if usingKeyboardEntryPoint {
            _ = textView.perform(Self.entryPoint, with: range, with: "the")
        } else {
            textView.replace(range, withText: "the")
        }
        HarnessEngine.settle(value.root)
        let content = HarnessLegacy.content(value)
        XCTAssertEqual(content.plainText, "abc the", "precondition: the replacement did not land")
        return content
    }

    func testTheKeyboardsCorrectionKeepsBold() throws {
        let content = try self.correctLastWord(format: { $0.bold = true }, usingKeyboardEntryPoint: true)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "abc the", "the keyboard's correction dropped bold: \(FuzzModel.describe(content))")
    }

    func testTheKeyboardsCorrectionKeepsItalic() throws {
        let content = try self.correctLastWord(format: { $0.italic = true }, usingKeyboardEntryPoint: true)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.italic }), "abc the", "the keyboard's correction dropped italic: \(FuzzModel.describe(content))")
    }

    func testTheKeyboardsCorrectionKeepsMonospace() throws {
        let content = try self.correctLastWord(format: { $0.monospace = true }, usingKeyboardEntryPoint: true)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.monospace }), "abc the", "the keyboard's correction dropped monospace: \(FuzzModel.describe(content))")
    }

    /// Control: the public `replace(_:withText:)` keeps bold (why L4 would not reduce before).
    func testControlThePublicReplaceKeepsBold() throws {
        let content = try self.correctLastWord(format: { $0.bold = true }, usingKeyboardEntryPoint: false)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "abc the", "control: the public replace dropped bold")
    }
}
