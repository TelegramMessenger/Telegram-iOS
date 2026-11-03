import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p23, 2026-10-01).** After Format ▸ Link, text entered over a selection that STARTS ON A LINE
/// BREAK at the end of a linked line, with linked text after it, is formatted differently after an UNDO than
/// before it. Plain the first time, linked once an undo has restored the same document:
///
///     [p "nested"] [p "open"] [p "close"], select 4..<16, Link → [p "nest" [e]"ed"] [p [e]"open"] [p [e]"clos" "e"]
///     select 6..<16 (the break after "nested" through "clos"), compose あ … ありがとう (or type it)
///        first time:                         [p "nest" [e]"ed" "ありがとうe"]       (plain)
///        ⌘Z, the same selection, the same input: [p "nest" [e]"edありがとう" "e"]   (linked)
///
/// The document and the selection are the same both times; only the history differs, so what is sent depends
/// on whether the user undid something first. The fuzz's composition oracle reports exactly that
/// (`typingDependsOnUndoHistory`, default and edited seed 20 step 46, p23 sweep: the first composition plain,
/// the one after the undo and the typing after the undo linked).
///
/// **How it was seen.** p23 sweep, default and edited seed 20; reduced from the verbose replay.
///
/// **Suspected cause.** The input over a selection takes the attributes of the selection's FIRST character,
/// here the line break ending the linked line. The Link command does not put the link on that separator (an
/// inline command never formats a separator, p22), and the undo snapshot's re-render does
/// (`applyUndoSnapshot` → the separator follows its block's last character, p21
/// `id_restoreAttributedBlocks:changedRange:`), so the separator is plain before the undo and linked after it.
/// This is the p21 `HarnessUndoSeparatorTypingAttributesTests` class through a LINK, which neither the p21 rule
/// (empty lines) nor the p22 one (`tgid_formatCommandSelection`, trait commands only) covers. Which answer is
/// right is the fix's decision; the test asks that history not decide it.
///
/// **Tier 1**: view selection, Format ▸ Link answered by `linkPromptOverride`, `setMarkedText` / `unmarkText`,
/// `insertText`, `undo`.
@available(iOS 18.4, *)
final class HarnessCompositionAfterLinkFromLineEndTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.root.linkPromptOverride = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private static let document = ChatInputContent(blocks: [HarnessEngine.paragraph("nested"), HarnessEngine.paragraph("open"), HarnessEngine.paragraph("close")])
    private static let kana = ["a", "あ", "あr", "あり", "ありg", "ありが", "ありがと", "ありがとう"]

    private func arrangeLinked(_ apply: (EngineFuzzDriver) -> Void) {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 4, length: 12))
        self.driver.settle()
        apply(self.driver)
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 6, length: 10))
        self.driver.settle(0.1)
    }

    private func link(_ driver: EngineFuzzDriver) {
        driver.root.linkPromptOverride = { _, _ in "https://telegram.org" }
        driver.host.panel.formatAttributesLink(driver.host.panel)
        driver.settle(0.2)
        driver.root.linkPromptOverride = nil
    }

    private func compose() {
        let input = self.driver.view as! (UIView & UITextInput)
        for step in Self.kana {
            input.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
            self.driver.settle()
        }
        input.unmarkText()
        self.driver.settle(0.1)
    }

    private func typed(_ apply: (EngineFuzzDriver) -> Void) -> ChatInputContent {
        self.arrangeLinked(apply)
        self.driver.insert("ありがとう")
        self.driver.settle(0.1)
        return FuzzModel.normalized(self.driver.model())
    }

    // MARK: - Red

    func testTheSameTypingGivesTheSameResultAfterAnUndo() {
        self.arrangeLinked(self.link)
        self.driver.insert("ありがとう")
        self.driver.settle(0.1)
        let first = FuzzModel.normalized(self.driver.model())
        self.driver.undoManager?.undo()
        self.driver.settle(0.2)
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle()
        self.driver.setViewSelection(NSRange(location: 6, length: 10))
        self.driver.settle(0.1)
        self.driver.insert("ありがとう")
        self.driver.settle(0.1)
        XCTAssertEqual(HarnessEdited.describe(first), HarnessEdited.describe(FuzzModel.normalized(self.driver.model())))
    }

    func testTheSameCompositionGivesTheSameResultAfterAnUndo() {
        self.arrangeLinked(self.link)
        self.compose()
        let first = FuzzModel.normalized(self.driver.model())
        self.driver.undoManager?.undo()
        self.driver.settle(0.2)
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle()
        self.driver.setViewSelection(NSRange(location: 6, length: 10))
        self.driver.settle(0.1)
        self.compose()
        let again = FuzzModel.normalized(self.driver.model())
        XCTAssertEqual(HarnessEdited.describe(first), HarnessEdited.describe(again))
    }

    // MARK: - The decision (p23 fix wave): LINKED, both times

    /// Fixed by making an attribute TRANSFORM (the Link command's path) give a non-empty block's separator its
    /// last character's attributes, as an undo's restore already did (`IDBlockDocument
    /// id_transformTextAttributesInCanonicalRange:usingBlock:`). The separator after "ed" is linked from the
    /// command on, so the input over a selection starting on it is linked before an undo as after one — the
    /// stock answer (the oracle below) and the typed-text policy's (a word typed against a link joins it).
    func testTypingOverTheSelectionIsLinkedBeforeAnyUndo() {
        self.arrangeLinked(self.link)
        self.driver.insert("ありがとう")
        self.driver.settle(0.1)
        let model = FuzzModel.normalized(self.driver.model())
        guard model.blocks.count == 1, case let .paragraph(paragraph) = model.blocks[0] else {
            return XCTFail(HarnessEdited.describe(model))
        }
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "nestedありがとうe", HarnessEdited.describe(model))
        let typed = paragraph.runs.first { $0.text.contains("ありがとう") }
        XCTAssertNotNil(typed?.attributes.entity, "the typed text is not linked: \(HarnessEdited.describe(model))")
    }

    /// Oracle: a stock `UITextView` given the link over the same range, then the same selection and input, links
    /// the typed text (its newline carries the link the attribute was added over).
    func testControlStockTextViewLinksTheTypedText() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        textView.allowsEditingTextAttributes = true
        let text = NSMutableAttributedString(string: "nested\nopen\nclose", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        text.addAttribute(.link, value: "https://telegram.org", range: NSRange(location: 4, length: 12))
        textView.attributedText = text
        _ = textView.becomeFirstResponder()
        HarnessEngine.settle(root, seconds: 0.05)
        textView.selectedRange = NSRange(location: 6, length: 10)
        HarnessEngine.settle(root, seconds: 0.05)
        textView.insertText("ありがとう")
        HarnessEngine.settle(root, seconds: 0.05)
        XCTAssertEqual(textView.text, "nestedありがとうe")
        XCTAssertNotNil(textView.attributedText.attribute(.link, at: 6, effectiveRange: nil), "the typed text is not linked")
    }

    // MARK: - Controls (fresh state)

    /// On the state the Link command left, a composition and typing agree (both plain).
    func testControlAFreshCompositionDoesWhatFreshTypingDoes() {
        let typed = self.typed(self.link)
        self.arrangeLinked(self.link)
        self.compose()
        let composed = FuzzModel.normalized(self.driver.model())
        XCTAssertEqual(HarnessEdited.describe(composed), HarnessEdited.describe(typed))
    }

    /// With Bold instead of Link (the p22 trait rule), composition and typing agree.
    func testControlAfterBoldCompositionAndTypingAgree() {
        let bold: (EngineFuzzDriver) -> Void = { $0.node.performFormatAction(.bold); $0.settle(0.2) }
        let typed = self.typed(bold)
        self.arrangeLinked(bold)
        self.compose()
        XCTAssertEqual(HarnessEdited.describe(FuzzModel.normalized(self.driver.model())), HarnessEdited.describe(typed))
    }

    /// From INSIDE the linked text (not a line break), composition and typing agree.
    func testControlFromInsideTheLinkCompositionAndTypingAgree() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 4, length: 12))
        self.driver.settle()
        self.link(self.driver)
        self.driver.setViewSelection(NSRange(location: 7, length: 9))
        self.driver.settle(0.1)
        self.driver.insert("ありがとう")
        self.driver.settle(0.1)
        let typed = FuzzModel.normalized(self.driver.model())
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        self.driver.setViewSelection(NSRange(location: 4, length: 12))
        self.driver.settle()
        self.link(self.driver)
        self.driver.setViewSelection(NSRange(location: 7, length: 9))
        self.driver.settle(0.1)
        self.compose()
        XCTAssertEqual(HarnessEdited.describe(FuzzModel.normalized(self.driver.model())), HarnessEdited.describe(typed))
    }
}
