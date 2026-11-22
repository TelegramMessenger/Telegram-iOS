import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** Format ▸ Bold (or Strikethrough, Italic, Underline) over a selection that STARTS on a
/// LINE BREAK — an empty line, or the end of a line (found by the p22 fuzz) — then typing or composing over
/// that selection, drops the format the user just applied:
///
///     [p "Top"] [p ""] [p "end"], select 4..<7 (the empty line + "en"), Format ▸ Bold → [p ""] [p [b]"en" "d"]
///       type x   engine: [p "Top"] [p "xd"]          (x plain)
///                stock UITextView, same keystrokes: x BOLD
///       compose か: the same, plain
///     controls: the selection starting in text ([p "mid"], select from "id"): x bold; a CARET on the empty
///     line, Bold, type x: x bold
///
/// This is row 134's defect ("typing over a selection straight after a Format command over it drops the
/// format", fixed in p15 with `tgid_adoptTypingAttributesOfSelectedText`) coming back for one start position.
///
/// **How it was seen.** p22 roam (2026-10-01), auditing the p21 empty-line typing attributes (Priority 1c):
/// formats applied over selections that start on empty lines, then typing / composing / pasting.
///
/// **Suspected cause.** The p21 override (`TGIDObservingBlockTextView id_adoptEmptyBlockTypingAttributesIfNeeded`)
/// replaces the typing attributes of a selection that starts on an empty line with that line's ROLE
/// attributes (the empty-line provider), and `tgid_adoptTypingAttributesOfSelectedText` — which
/// `recordingInlineFormatStep` calls after every inline format precisely so that typing over the formatted
/// selection keeps the format — calls that override last. So the format command's own re-derivation is
/// overwritten with the role's plain attributes. The p21 decision ("types as a caret on that line") is not met
/// either: a caret on an empty line after Bold types bold. From a non-empty line's END the override does not
/// apply; there the re-derivation reads the line's SEPARATOR, which the inline command never formats (the
/// model has no place for a format on a line break), so it types the separator's — the line's last
/// character's — attributes. Probably older than p21 there; same class, same fix point.
///
/// **Severity.** Low: drawn as sent; the user's formatting is lost on the next keystroke.
///
/// **Tier 1**: the panel's Format action, `insertText` / `setMarkedText` on the engine view; a stock
/// `UITextView` with `toggleBoldface` is the oracle.
@available(iOS 18.4, *)
final class HarnessFormatOverEmptyLineSelectionTypingTests: XCTestCase {
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

    private static let emptyLine = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([]), E.paragraph([E.run("end")])])

    /// The attributes of the run holding `character` in the model.
    private func attributes(of character: String) -> ChatInputInlineAttributes? {
        for block in self.driver.model().blocks {
            if case let .paragraph(paragraph) = block, let run = paragraph.runs.first(where: { $0.text.contains(character) }) {
                return run.attributes
            }
        }
        return nil
    }

    private func formatThenType(_ content: ChatInputContent, _ range: NSRange, _ format: FuzzFormat, compose: Bool = false) -> ChatInputInlineAttributes? {
        HarnessComposerFuzzTests.arrange(self.driver, content)
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        self.driver.format(format)
        self.driver.settle(0.1)
        if compose {
            let input = self.driver.view as! (UIView & UITextInput)
            for text in ["k", "か"] {
                input.setMarkedText(text, selectedRange: NSRange(location: 1, length: 0))
                self.driver.settle(0.03)
            }
            input.unmarkText()
            self.driver.settle(0.1)
            return self.attributes(of: "か")
        }
        self.driver.insert("x")
        self.driver.settle(0.1)
        return self.attributes(of: "x")
    }

    // MARK: - Red

    func testBoldOverASelectionFromAnEmptyLineThenTypingIsBold() {
        let attributes = self.formatThenType(Self.emptyLine, NSRange(location: 4, length: 3), .bold)
        XCTAssertEqual(attributes?.bold, true, "the typed x lost the Bold just applied: \(FuzzModel.describe(self.driver.model()))")
    }

    func testStrikethroughOverASelectionFromAnEmptyLineThenTypingIsStruck() {
        let attributes = self.formatThenType(Self.emptyLine, NSRange(location: 4, length: 3), .strikethrough)
        XCTAssertEqual(attributes?.strikethrough, true, "the typed x lost the Strikethrough just applied: \(FuzzModel.describe(self.driver.model()))")
    }

    func testBoldOverASelectionFromAnEmptyLineThenComposingIsBold() {
        let attributes = self.formatThenType(Self.emptyLine, NSRange(location: 4, length: 3), .bold, compose: true)
        XCTAssertEqual(attributes?.bold, true, "the composed text lost the Bold just applied: \(FuzzModel.describe(self.driver.model()))")
    }

    /// The same from a non-empty line's END (the selection's first character is its line break): found by the
    /// p22 `formatTypeOver` fuzz op (edited seed 12 step 21, Strikethrough over a selection starting at the
    /// end of a line). A stock text view types struck here too (its newline was formatted with the rest).
    func testStrikethroughOverASelectionFromALinesEndThenTypingIsStruck() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([E.run("end")])])
        let attributes = self.formatThenType(content, NSRange(location: 3, length: 3), .strikethrough)
        XCTAssertEqual(attributes?.strikethrough, true, "the typed x lost the Strikethrough just applied: \(FuzzModel.describe(self.driver.model()))")
    }

    // MARK: - Controls

    /// The same over a selection starting in text (row 134's fix).
    func testControlASelectionStartingInTextKeepsTheBold() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([E.run("mid")]), E.paragraph([E.run("end")])])
        let attributes = self.formatThenType(content, NSRange(location: 5, length: 4), .bold)
        XCTAssertEqual(attributes?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// A CARET on the empty line: Bold, then type — bold (the pending toggle).
    func testControlACaretOnTheEmptyLineTypesBold() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.emptyLine)
        self.driver.setViewSelection(NSRange(location: 4, length: 0))
        self.driver.settle(0.1)
        self.driver.format(.bold)
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.1)
        XCTAssertEqual(self.attributes(of: "x")?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// Oracle: from a line's END a stock text view types struck as well.
    func testControlStockTextViewFromALinesEndTypesStruck() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        textView.allowsEditingTextAttributes = true
        textView.attributedText = NSAttributedString(string: "Top\nend", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        _ = textView.becomeFirstResponder()
        HarnessEngine.settle(root, seconds: 0.05)
        textView.selectedRange = NSRange(location: 3, length: 3)
        HarnessEngine.settle(root, seconds: 0.05)
        let struck = NSMutableAttributedString(attributedString: textView.attributedText)
        struck.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 3, length: 3))
        textView.attributedText = struck
        textView.selectedRange = NSRange(location: 3, length: 3)
        HarnessEngine.settle(root, seconds: 0.05)
        textView.insertText("x")
        HarnessEngine.settle(root, seconds: 0.05)
        XCTAssertEqual(textView.text, "Topxd")
        XCTAssertNotNil(textView.attributedText.attribute(.strikethroughStyle, at: 3, effectiveRange: nil))
    }

    /// Oracle: a stock text view types bold after the same keystrokes.
    func testControlStockTextViewTypesBold() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        textView.allowsEditingTextAttributes = true
        textView.attributedText = NSAttributedString(string: "Top\n\nend", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        _ = textView.becomeFirstResponder()
        HarnessEngine.settle(root, seconds: 0.05)
        textView.selectedRange = NSRange(location: 4, length: 3)
        HarnessEngine.settle(root, seconds: 0.05)
        textView.toggleBoldface(nil)
        HarnessEngine.settle(root, seconds: 0.05)
        textView.insertText("x")
        HarnessEngine.settle(root, seconds: 0.05)
        let font = textView.attributedText.attribute(.font, at: 4, effectiveRange: nil) as? UIFont
        XCTAssertEqual(textView.text, "Top\nxd")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    // MARK: - Neighbours (p22 fix wave)

    func testItalicOverASelectionFromAnEmptyLineThenTypingIsItalic() {
        let attributes = self.formatThenType(Self.emptyLine, NSRange(location: 4, length: 3), .italic)
        XCTAssertEqual(attributes?.italic, true, FuzzModel.describe(self.driver.model()))
    }

    func testUnderlineOverASelectionFromAnEmptyLineThenTypingIsUnderlined() {
        let attributes = self.formatThenType(Self.emptyLine, NSRange(location: 4, length: 3), .underline)
        XCTAssertEqual(attributes?.underline, true, FuzzModel.describe(self.driver.model()))
    }

    /// From an empty HEADING line: the format wins, the line's role still decides the rest (the typed text is
    /// in the heading).
    func testBoldFromAnEmptyHeadingLine() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [])), E.paragraph([E.run("end")])])
        let attributes = self.formatThenType(content, NSRange(location: 4, length: 3), .bold)
        XCTAssertEqual(attributes?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// The p21 rule stands when no format command intervened: typing over a selection from an empty line next
    /// to bold text takes the LINE's attributes, not the bold.
    func testControlWithoutAFormatCommandTheLineDecides() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([]), E.paragraph([E.run("en") { $0.bold = true }, E.run("d")])])
        HarnessComposerFuzzTests.arrange(self.driver, content)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.1)
        XCTAssertNotEqual(self.attributes(of: "x")?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// The command's traits last only while the selection is the one it formatted: move away and back, and
    /// the p21 rule decides again.
    func testControlTheFormatLastsUntilTheSelectionMoves() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.emptyLine)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.format(.bold)
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.1)
        XCTAssertNotEqual(self.attributes(of: "x")?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// Bold, then UNDO under the same selection, then typing: plain (the traits are read from the live text).
    func testControlUndoOfTheFormatThenTypingIsPlain() throws {
        HarnessComposerFuzzTests.arrange(self.driver, Self.emptyLine)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.format(.bold)
        self.driver.settle(0.1)
        try XCTUnwrap(self.driver.undoManager).undo()
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.1)
        XCTAssertNotEqual(self.attributes(of: "x")?.bold, true, FuzzModel.describe(self.driver.model()))
    }

    /// Bold, then an edit over the selection, UNDONE, then typing over the restored selection: bold. The
    /// format command's typing state is part of what an undo restores (as a stock text view's undo restores
    /// its newline's attributes). Found by the fuzz's chat-insert oracle (default seed 40, edited seed 4),
    /// which inserts, undoes and types: the insert took the format, the typing after the undo did not.
    func testAnUndoneEditOverTheSelectionRestoresTheFormat() throws {
        HarnessComposerFuzzTests.arrange(self.driver, Self.emptyLine)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.format(.bold)
        self.driver.settle(0.1)
        self.driver.insert("y")
        self.driver.settle(0.1)
        XCTAssertEqual(self.attributes(of: "y")?.bold, true, FuzzModel.describe(self.driver.model()))
        try XCTUnwrap(self.driver.undoManager).undo()
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 4, length: 3))
        self.driver.settle(0.1)
        self.driver.insert("x")
        self.driver.settle(0.1)
        XCTAssertEqual(self.attributes(of: "x")?.bold, true, FuzzModel.describe(self.driver.model()))
    }
}
