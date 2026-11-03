import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30):** a paste (plain text or RTF — anything the engine's own paste takes)
/// over a selection that spans TWO blocks takes two undos: the first leaves the selection deleted and the
/// pasted text gone (`"First paragraph." "Second paragraph."`, select 5..<19, paste `PASTED` →
/// `"First PASTED cond paragraph."`, ⌘Z → `"Firstcond paragraph."`), the second restores. A stock
/// `UITextView` undoes the same paste in one step (oracle), and so does the engine for a selection inside
/// one block (control).
///
/// **How it was seen:** p20 external-paste sweep, every source over the cross-block destination.
///
/// **Suspected:** `deleteCrossBlockSelectionBeforeEnginePaste` (`+Clipboard.swift`) deletes the selection
/// through the gate synchronously, then UIKit's paste lands 20-30 ms later (asynchronous, p18) in a later
/// event, so the two edits fall in two undo groups. The deletion and the insertion must be one step.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessCrossBlockPasteUndoTests: XCTestCase {
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

    private static let twoParagraphs = HarnessContent.plainText("First paragraph.\nSecond paragraph.")

    /// Pastes over `selection`, undoes once, and returns (after the paste, after one undo, before).
    private func pasteThenUndoOnce(_ content: ChatInputContent, _ selection: NSRange, _ items: [[String: Any]]) -> (pasted: String, undone: ChatInputContent, before: ChatInputContent) {
        self.driver.arrange(content)
        self.driver.undoManager?.removeAllActions()
        self.driver.setViewSelection(selection)
        self.driver.settle(0.1)
        let before = FuzzModel.normalized(self.driver.model())
        UIPasteboard.general.items = items
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(FuzzConfig.pasteSettle)
        let pasted = self.driver.model().plainText
        self.driver.undoManager?.undo()
        self.driver.settle(0.2)
        return (pasted, FuzzModel.normalized(self.driver.model()), before)
    }

    func testOneUndoRevertsAPlainPasteOverTwoParagraphs() {
        let result = self.pasteThenUndoOnce(Self.twoParagraphs, NSRange(location: 5, length: 14), [["public.utf8-plain-text": "PASTED"]])
        XCTAssertEqual(result.pasted, "First PASTED cond paragraph.", "precondition")
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.before), "one undo did not revert the paste")
    }

    func testOneUndoRevertsAnRTFPasteFromAParagraphIntoAQuote() {
        let rtf = try! NSAttributedString(string: "PASTED").data(from: NSRange(location: 0, length: 6), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let content = ChatInputContent(blocks: [HarnessEngine.paragraph("Intro line."), .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false))])
        let result = self.pasteThenUndoOnce(content, NSRange(location: 5, length: 12), [["public.rtf": rtf]])
        XCTAssertTrue(result.pasted.contains("PASTED"), "precondition")
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.before), "one undo did not revert the paste")
    }

    /// Control: a paste over a selection inside one paragraph is one step.
    func testControlOneUndoRevertsAPasteInsideOneParagraph() {
        let result = self.pasteThenUndoOnce(Self.twoParagraphs, NSRange(location: 2, length: 5), [["public.utf8-plain-text": "PASTED"]])
        XCTAssertEqual(FuzzModel.describe(result.undone), FuzzModel.describe(result.before))
    }

    /// Oracle: a stock `UITextView` undoes the same cross-paragraph paste in one step.
    func testOracleStockTextViewUndoesTheSamePasteInOneStep() throws {
        _ = self.driver.node.resignInputFirstResponder()
        let root = self.driver.root
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer { textView.removeFromSuperview() }
        textView.text = "First paragraph.\nSecond paragraph."
        XCTAssertTrue(textView.becomeFirstResponder())
        textView.selectedRange = NSRange(location: 5, length: 14)
        UIPasteboard.general.items = [["public.utf8-plain-text": "PASTED"]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        textView.paste(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(FuzzConfig.pasteSettle))
        XCTAssertEqual(textView.text, "First PASTED cond paragraph.")
        textView.undoManager?.undo()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(textView.text, "First paragraph.\nSecond paragraph.")
        textView.resignFirstResponder()
    }
}
