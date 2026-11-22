import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A CANCELLED IME composition at a caret (the keyboard sets the marked text to "" and
/// unmarks: the user deleted every candidate, or switched keyboards mid-word) registers an undo step that
/// changes nothing, so the user's next ⌘Z appears to do nothing and only the second one undoes what they
/// typed before:
///
///     [p "hello"], caret 5, type "ab", move the caret away and back (the typing run is closed),
///     compose k → … → 漢字, cancel → [p "helloab"]
///       ⌘Z: engine [p "helloab"] (nothing happens)       stock UITextView: "hello"
///     control: without the caret move (the composition is contiguous with the typing run) one ⌘Z
///       gives "hello" in both
///
/// **How it was seen.** p21 roam (2026-10-01): the new `undoRedo` fuzz op (undo + redo after a step) at
/// default and edited seed 3 step 14 — a `.compose(.japanese, .cancel)` at a caret, then the round trip,
/// whose undo changed nothing.
///
/// **Suspected cause.** The marked text's insertions and removals are storage edits the undo recording
/// sees (`recordUndoForEngineEdit`, `+UndoStack.swift`); with no open typing run to fold them into, the
/// first candidate opens a step whose net change is nil, and nothing drops a step whose document equals its
/// baseline (`performAsOneUndoStep` does, but a composition does not go through it). A stock text view
/// records nothing for a composition that commits nothing.
///
/// **Severity.** Low: nothing is lost; one ⌘Z is swallowed.
///
/// **Tier 1**: `setMarkedText(_:selectedRange:)` / `unmarkText()` as a CJK keyboard calls them, the
/// view's `undoManager` as ⌘Z drives it; a stock `UITextView` given the same calls is the oracle.
@available(iOS 18.4, *)
final class HarnessCancelledCompositionUndoTests: XCTestCase {
    private func engineAfterOneUndo(closingTheTypingRun: Bool) throws -> String {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        HarnessComposerFuzzTests.arrange(driver, ChatInputContent(blocks: [HarnessEngine.paragraph("hello")]))
        driver.setViewSelection(NSRange(location: 5, length: 0))
        driver.settle(0.05)
        driver.insert("a")
        driver.insert("b")
        driver.settle(0.1)
        if closingTheTypingRun {
            driver.setViewSelection(NSRange(location: 0, length: 0))
            driver.settle(0.05)
            driver.setViewSelection(NSRange(location: 7, length: 0))
            driver.settle(0.05)
        }
        for step in FuzzIME.japanese.steps {
            input.setMarkedText(step.text, selectedRange: step.selected)
            driver.settle(0.03)
        }
        input.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        input.unmarkText()
        driver.settle(0.1)
        XCTAssertEqual(driver.model().plainText, "helloab", "precondition: the cancelled composition changed the text")
        driver.undoManager?.undo()
        driver.settle(0.1)
        return driver.model().plainText
    }

    private func stockAfterOneUndo(closingTheTypingRun: Bool) throws -> String {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        func settle() {
            HarnessEngine.settle(root, seconds: 0.05)
        }
        textView.text = "hello"
        textView.undoManager?.removeAllActions()
        _ = textView.becomeFirstResponder()
        settle()
        textView.selectedRange = NSRange(location: 5, length: 0)
        settle()
        textView.insertText("a")
        textView.insertText("b")
        settle()
        if closingTheTypingRun {
            textView.selectedRange = NSRange(location: 0, length: 0)
            settle()
            textView.selectedRange = NSRange(location: 7, length: 0)
            settle()
        }
        for step in FuzzIME.japanese.steps {
            textView.setMarkedText(step.text, selectedRange: step.selected)
            settle()
        }
        textView.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        textView.unmarkText()
        settle()
        textView.undoManager?.undo()
        settle()
        return textView.text ?? ""
    }

    func testOneUndoAfterACancelledCompositionUndoesTheTypingBeforeIt() throws {
        XCTAssertEqual(try self.engineAfterOneUndo(closingTheTypingRun: true), "hello",
                       "the cancelled composition left an undo step that changes nothing")
    }

    /// Control: the composition contiguous with the typing run.
    func testControlContiguousWithTheTypingRun() throws {
        XCTAssertEqual(try self.engineAfterOneUndo(closingTheTypingRun: false), "hello")
    }

    /// Oracle: a stock text view records nothing for the cancelled composition.
    func testControlStockTextViewRecordsNothing() throws {
        XCTAssertEqual(try self.stockAfterOneUndo(closingTheTypingRun: true), "hello")
        XCTAssertEqual(try self.stockAfterOneUndo(closingTheTypingRun: false), "hello")
    }
}
