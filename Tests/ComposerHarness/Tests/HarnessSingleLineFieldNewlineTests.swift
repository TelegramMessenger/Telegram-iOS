import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, text with a newline that reaches a ONE-LINE field — a pull or
/// block quote's author, a code block's language, a details block's title — has the newline deleted, so
/// the lines run together with no separator:
///
///     author "Someone", replace it with the text replacement "123 Main St⏎City"  → "123 Main StCity"
///     details title "Summary", replace with "Line one⏎Line two"                  → "Line oneLine two"
///     dictating "one", "new line", "two" at the end of an author                  → "Someoneonetwo"
///
/// A stock `UITextField` — the platform's one-line field — turns the same newline into a SPACE for
/// `insertText`, `replace(_:withText:)` and paste alike ("123 Main St City"), measured in the control
/// below.
///
/// **How it was seen.** p12 roam, 2026-09-24: multi-line text replacements and dictation driven into
/// every block kind; the single-line fields were the ones that lost the word boundary.
///
/// **Suspected cause.** `RichTextEngineEditorView+SurfaceGate.swift` `decideTextInput`: for
/// `.codeLanguage`, `.detailsTitle` and the author lines a non-Return text is forwarded as
/// `text.replacingOccurrences(of: "\n", with: "")` — "a paste runs together".
///
/// **Tier 1**: `replace(_:withText:)` / `insertText(_:)` are the calls a text replacement, dictation and a
/// hardware keyboard make; `UITextField` is the oracle.
@available(iOS 18.4, *)
final class HarnessSingleLineFieldNewlineTests: XCTestCase {
    private func replace(_ content: ChatInputContent, range: NSRange, with text: String) throws -> String {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(content)
        driver.settle(0.1)
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: range.location))
        let end = try XCTUnwrap(input.position(from: start, offset: range.length))
        input.replace(try XCTUnwrap(input.textRange(from: start, to: end)), withText: text)
        driver.settle(0.3)
        return FuzzModel.describe(FuzzModel.normalized(driver.model()))
    }

    func testAnAuthorKeepsTheWordBoundaryOfAReplacementsNewline() throws {
        // "Attributed:\nWords to live by.\nSomeone": the author is 30..<37.
        let model = try self.replace(HarnessComposerFuzzTests.extendedStartingContents()[0], range: NSRange(location: 30, length: 7), with: "123 Main St\nCity")
        XCTAssertEqual(model, "[p body \"Attributed:\"] [pull \"Words to live by.\" author=\"123 Main St City\"]",
                       "the author line ran the replacement's lines together")
    }

    func testADetailsTitleKeepsTheWordBoundaryOfAReplacementsNewline() throws {
        // "Details:\nSummary\nHidden body.": the title is 9..<16.
        let model = try self.replace(HarnessComposerFuzzTests.extendedStartingContents()[4], range: NSRange(location: 9, length: 7), with: "Line one\nLine two")
        XCTAssertEqual(model, "[p body \"Details:\"] [details title=\"Line one Line two\" [p body \"Hidden body.\"]]",
                       "the details title ran the replacement's lines together")
    }

    func testACodeLanguageKeepsTheWordBoundaryOfAnInsertedNewline() throws {
        // "Code below:\nswift\nlet x = 1": the language is 12..<17; insert at its end.
        let model = try self.replace(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Code below:"),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1")])),
        ]), range: NSRange(location: 17, length: 0), with: " one\ntwo")
        XCTAssertEqual(model, "[p body \"Code below:\"] [code lang=\"swift one two\" \"let x = 1\"]",
                       "the language line ran the inserted lines together")
    }

    /// A PASTE of two lines over an author, and at a caret in a details title: the words stay apart,
    /// as `UITextField`'s paste keeps them.
    func testAPasteOverAnAuthorKeepsTheWordBoundary() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: HarnessComposerFuzzTests.extendedStartingContents()[0],
                                         ops: [.select(30, 37), .pasteText("123 Main St\nCity")])
        driver.settle(0.3)
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(driver.model())),
                       "[p body \"Attributed:\"] [pull \"Words to live by.\" author=\"123 Main St City\"]",
                       "a two-line paste over the author ran together or split it")
    }

    func testAPasteIntoADetailsTitleKeepsTheWordBoundary() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: HarnessComposerFuzzTests.extendedStartingContents()[4],
                                         ops: [.select(16, 16), .pasteText(" one\ntwo")])
        driver.settle(0.3)
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(driver.model())),
                       "[p body \"Details:\"] [details title=\"Summary one two\" [p body \"Hidden body.\"]]",
                       "a two-line paste into the details title ran together or split it")
    }

    /// A RUN of newlines and the whitespace around them is one word boundary, not several.
    func testARunOfNewlinesAndSpacesBecomesOneSpace() throws {
        let model = try self.replace(HarnessComposerFuzzTests.extendedStartingContents()[0], range: NSRange(location: 30, length: 7), with: "Ann \n\n  Lee\n")
        XCTAssertEqual(model, "[p body \"Attributed:\"] [pull \"Words to live by.\" author=\"Ann Lee \"]")
    }

    /// The Return KEY keeps its own rule in each field: a lone newline in a language line moves the
    /// caret into the code and changes no text.
    func testControlALoneReturnInALanguageLineStillMovesIntoTheCode() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        driver.arrange(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Code below:"),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        driver.setViewSelection(NSRange(location: 17, length: 0))
        driver.settle(0.1)
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        input.insertText("\n")
        driver.settle(0.2)
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(driver.model())), "[p body \"Code below:\"] [code lang=\"swift\" \"let x = 1\"]")
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 18, length: 0), "Return in the language line did not move into the code")
    }

    /// Control: the platform's one-line field turns the newline into a space.
    func testControlUITextFieldTurnsTheNewlineIntoASpace() throws {
        let root = try HarnessEngine.root()
        let field = UITextField(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 40.0))
        root.view.addSubview(field)
        defer {
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
        _ = field.becomeFirstResponder()
        field.text = "Someone"
        let whole = try XCTUnwrap(field.textRange(from: field.beginningOfDocument, to: field.endOfDocument))
        field.replace(whole, withText: "123 Main St\nCity")
        XCTAssertEqual(field.text, "123 Main St City")
        field.insertText("\nx")
        XCTAssertEqual(field.text, "123 Main St City x")
        // Measured, not asserted: what the platform does with a RUN (the engine collapses it to one).
        field.text = ""
        field.insertText("Ann \n\n  Lee")
        print("harness: UITextField run of newlines -> \"\(field.text ?? "")\"")
    }
}
