import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30):** a paste the engine's own paste performs (plain text or RTF from
/// another app) straight after TYPING joins the open typing run, so one undo takes back the paste AND the
/// typing before it: `"Hello"`, type `" ab"`, paste `XYZ` → `"Hello ab XYZ"`, ⌘Z → `"Hello"`. A stock
/// `UITextView` undoes the paste alone (`"Hello ab"`, oracle), and so does the engine for a paste of its own
/// fragment (control). The fuzz met it after compositions, typed emoji and Send's typed letter
/// (default seeds 16, 34, 40; edited 16, 30, 34 — the p20 `externalPaste` op's one-undo check).
///
/// **Suspected:** the engine's typing coalescing (RichTextEditor `CLAUDE.md`, "Typing coalesces because
/// UIKit coalesces it") treats the paste's storage edit as typing contiguous with the run; a paste must end
/// the run as a caret move does (`endTypingRun`).
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessPasteJoinsTypingUndoTests: XCTestCase {
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

    private func typeThenPaste(_ items: [[String: Any]]?) -> (after: String, undone: String) {
        self.driver.arrange(HarnessContent.plainText("Hello"))
        self.driver.undoManager?.removeAllActions()
        if items == nil {
            // The editor's own fragment: copy "He" first.
            self.driver.setViewSelection(NSRange(location: 0, length: 2))
            self.driver.settle()
            _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
            HarnessComposerFuzzTests.notePasteboardWritten()
        }
        self.driver.setViewSelection(NSRange(location: 5, length: 0))
        self.driver.settle()
        self.driver.insert(" ab")
        self.driver.settle()
        if let items {
            UIPasteboard.general.items = items
            HarnessComposerFuzzTests.notePasteboardWritten()
        }
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(FuzzConfig.pasteSettle)
        let after = self.driver.model().plainText
        self.driver.undoManager?.undo()
        self.driver.settle(0.2)
        return (after, self.driver.model().plainText)
    }

    func testUndoingAPlainPasteKeepsTheTypingBeforeIt() {
        let result = self.typeThenPaste([["public.utf8-plain-text": "XYZ"]])
        XCTAssertEqual(result.after, "Hello ab XYZ", "precondition")
        XCTAssertEqual(result.undone, "Hello ab", "one undo took back the typing before the paste too")
    }

    func testUndoingAnRTFPasteKeepsTheTypingBeforeIt() {
        let rtf = FuzzExternalPaste.rtf(NSAttributedString(string: "XYZ"))
        let result = self.typeThenPaste([["public.rtf": rtf]])
        XCTAssertEqual(result.after, "Hello ab XYZ", "precondition")
        XCTAssertEqual(result.undone, "Hello ab", "one undo took back the typing before the paste too")
    }

    /// Control: a paste of the editor's own fragment is its own step.
    func testControlAFragmentPasteIsItsOwnStep() {
        let result = self.typeThenPaste(nil)
        XCTAssertEqual(result.after, "Hello abHe", "precondition")
        XCTAssertEqual(result.undone, "Hello ab")
    }

    /// Oracle: a stock `UITextView` undoes the paste alone.
    func testOracleStockTextViewUndoesThePasteAlone() {
        _ = self.driver.node.resignInputFirstResponder()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        self.driver.root.view.addSubview(textView)
        defer { textView.removeFromSuperview() }
        textView.text = "Hello"
        XCTAssertTrue(textView.becomeFirstResponder())
        textView.selectedRange = NSRange(location: 5, length: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        textView.insertText(" ab")
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        UIPasteboard.general.items = [["public.utf8-plain-text": "XYZ"]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        textView.paste(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(FuzzConfig.pasteSettle))
        XCTAssertEqual(textView.text, "Hello ab XYZ")
        textView.undoManager?.undo()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(textView.text, "Hello ab")
        textView.resignFirstResponder()
    }
}
