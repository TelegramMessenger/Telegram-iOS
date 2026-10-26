import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, typing over a selection STRAIGHT AFTER a Format command
/// (Bold, Strikethrough, a link…) over that selection drops the format the selection now carries:
///
///     "zPull quote next.", select "uote ne", Strikethrough, type X   → "zPull qXxt."          (plain X)
///     the same, but move the caret away and re-select before typing  → "zPull q"+[s]"X"+"xt." (struck X)
///     a stock UITextView (the oracle)                               → struck X
///
/// A replacement typed over a selection takes the attributes of the text it replaces — that is the
/// stock rule and the engine's own answer after a re-selection. The input controller's TYPING
/// attributes are what it uses, and UIKit derives them only on a selection CHANGE; a format command
/// changes the text under an unchanged selection, so they still describe the text as it was.
///
/// **How it was seen.** The p18 fix-wave fuzz sweep, once the `chatInsert` op's known-defect filter was
/// removed: its oracle (undo, re-select, type) re-derives the typing attributes, and the chat's insert
/// — typing at the live selection, as the user would — did not. Seeds 2, 4, 5, 11, 20, 27, 28, 31,
/// 40, 41, 43, 44 of 1-45 (seed 5: Strikethrough ×3 then an emoji; seed 44: a link then an emoji).
///
/// **Tier 1.** The same Format command and keystroke as the chat's menu and the keyboard, on the panel.
@available(iOS 18.4, *)
final class HarnessTypingOverFormattedSelectionTests: XCTestCase {
    private func typeOverFormatted(_ format: (EngineFuzzDriver) -> Void, reselect: Bool = false) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [HarnessP16.paragraph("zPull quote next.")]))
        driver.setViewSelection(NSRange(location: 7, length: 7))
        driver.settle(0.2)
        format(driver)
        driver.settle(0.2)
        if reselect {
            driver.setViewSelection(NSRange(location: 0, length: 0))
            driver.settle(0.1)
            driver.setViewSelection(NSRange(location: 7, length: 7))
            driver.settle(0.2)
        }
        driver.insert("X")
        driver.settle(0.3)
        return FuzzModel.normalized(driver.model())
    }

    private static func xRun(_ content: ChatInputContent) -> ChatInputRun? {
        guard case let .paragraph(paragraph)? = content.blocks.first else { return nil }
        return paragraph.runs.first { $0.text.contains("X") }
    }

    /// The oracle: a stock text view, the replaced text struck, typed over.
    func testStockTextViewTypesOverAStruckSelectionStruck() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        root.view.addSubview(textView)
        defer { _ = textView.resignFirstResponder(); textView.removeFromSuperview() }
        _ = textView.becomeFirstResponder()
        textView.attributedText = NSAttributedString(string: "zPull quote next.", attributes: [.font: UIFont.systemFont(ofSize: 17)])
        textView.textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 7, length: 7))
        textView.selectedRange = NSRange(location: 7, length: 7)
        HarnessEngine.settle(root)
        textView.insertText("X")
        XCTAssertEqual(textView.text, "zPull qXxt.")
        XCTAssertNotNil(textView.textStorage.attribute(.strikethroughStyle, at: 7, effectiveRange: nil))
    }

    func testTypingOverAJustStruckSelectionIsStruck() throws {
        let model = try self.typeOverFormatted { $0.node.performFormatAction(.strikethrough) }
        XCTAssertEqual(model.plainText, "zPull qXxt.", "precondition")
        XCTAssertEqual(Self.xRun(model)?.attributes.strikethrough, true, "typed over a just-struck selection: \(HarnessP16.describe(model))")
    }

    func testTypingOverAJustBoldedSelectionIsBold() throws {
        let model = try self.typeOverFormatted { $0.node.performFormatAction(.bold) }
        XCTAssertEqual(Self.xRun(model)?.attributes.bold, true, "typed over a just-bolded selection: \(HarnessP16.describe(model))")
    }

    func testTypingOverAJustLinkedSelectionKeepsTheLink() throws {
        let model = try self.typeOverFormatted { $0.node.applyRichTextLink("https://t.example/a") }
        guard case .url? = Self.xRun(model)?.attributes.entity else {
            return XCTFail("typed over a just-linked selection: \(HarnessP16.describe(model))")
        }
    }

    /// **A second defect, found measuring the first.** Backspace over a formatted selection, then type:
    /// a stock text view types PLAIN (the typing attributes are re-derived from the caret the deletion
    /// leaves), the engine typed the DELETED text's formatting. The engine deletes a selection as a gated
    /// `replaceRange:withText:` with empty text, and a replacement keeps the replaced text's typing
    /// attributes for the text typed over it — right for typing over, wrong for a deletion. Seen as fuzz
    /// seed 47 (Strikethrough over "laced 60", Backspace, emoji: struck by the chat, plain by the
    /// oracle's re-selection). Cut does the same deletion.
    func testStockTextViewTypesPlainAfterDeletingAStruckSelection() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        root.view.addSubview(textView)
        defer { _ = textView.resignFirstResponder(); textView.removeFromSuperview() }
        _ = textView.becomeFirstResponder()
        textView.attributedText = NSAttributedString(string: "Replaced 60", attributes: [.font: UIFont.systemFont(ofSize: 17)])
        textView.textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 3, length: 8))
        textView.selectedRange = NSRange(location: 3, length: 8)
        HarnessEngine.settle(root)
        textView.deleteBackward()
        HarnessEngine.settle(root)
        textView.insertText("X")
        XCTAssertEqual(textView.text, "RepX")
        XCTAssertNil(textView.textStorage.attribute(.strikethroughStyle, at: 3, effectiveRange: nil))
    }

    func testTypingAfterDeletingAStruckSelectionIsPlain() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "Rep"), ChatInputRun(text: "laced 60", attributes: ChatInputInlineAttributes(strikethrough: true)),
        ]))]))
        driver.setViewSelection(NSRange(location: 3, length: 8))
        driver.settle(0.2)
        driver.deleteBackward()
        driver.settle(0.2)
        driver.insert("X")
        driver.settle(0.3)
        let model = FuzzModel.normalized(driver.model())
        XCTAssertEqual(model.plainText, "RepX", "precondition")
        XCTAssertEqual(Self.xRun(model)?.attributes.strikethrough, false, "typed after deleting a struck selection: \(HarnessP16.describe(model))")
    }

    func testTypingAfterCuttingABoldSelectionIsPlain() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "Rep"), ChatInputRun(text: "laced 60", attributes: ChatInputInlineAttributes(bold: true)),
        ]))]))
        driver.setViewSelection(NSRange(location: 3, length: 8))
        driver.settle(0.2)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        driver.settle(0.2)
        driver.insert("X")
        driver.settle(0.3)
        let model = FuzzModel.normalized(driver.model())
        XCTAssertEqual(model.plainText, "RepX", "precondition")
        XCTAssertEqual(Self.xRun(model)?.attributes.bold, false, "typed after cutting a bold selection: \(HarnessP16.describe(model))")
    }

    /// Control: re-selecting first gives the struck X already.
    func testControlTypingAfterReselectingIsStruck() throws {
        let model = try self.typeOverFormatted({ $0.node.performFormatAction(.strikethrough) }, reselect: true)
        XCTAssertEqual(Self.xRun(model)?.attributes.strikethrough, true, "\(HarnessP16.describe(model))")
    }
}
