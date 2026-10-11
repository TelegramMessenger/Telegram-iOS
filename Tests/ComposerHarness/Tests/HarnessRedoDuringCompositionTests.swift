import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** While an IME composition is open, the engine still offers REDO, and a redo there throws
/// the composition away and leaves a half-composed state on the undo stack:
///
///     [p "x"], caret 1, type "ab", ⌘Z  →  "x" (canRedo true, correct)
///     caret 0, compose k → か (marked)
///       engine: canRedo TRUE      stock UITextView: canRedo FALSE (the composition's first edit cleared it)
///     ⌘⇧Z (or the three-finger redo) mid-composition
///       engine: "xab", the marked text gone; the keyboard's next candidate かん then lands at the end
///               ("xabかん"), and undo walks "xab" → "かx" → nothing: the document before the composition
///               ("x") is no longer reachable
///       stock:  redo does nothing; the composition commits as "かんx"
///
/// **How it was seen.** p22 roam (2026-10-01), auditing the p21 held composition step (Priority 1a): probes of
/// every verb during an open composition, each against a stock `UITextView` given the same calls. Undo, Bold,
/// an external push, Send, a theme / width change and a cancel over a selection all agree with stock; redo
/// does not.
///
/// **Suspected cause.** The p21 fix holds the composition's first step back (`pendingCompositionUndoStep`,
/// `+UndoStack.swift`) and registers it only when the composition ends. Registering is what empties the
/// REDO stack in `NSUndoManager`, so until then the old redo steps stay live. `EngineUndoManager` overrides
/// `canUndo` and `undo()` to account for the held step, but not `canRedo` / `redo()`: `canRedo` still answers
/// from the stale redo stack, and `redo()` replays it (`applyUndoSnapshot` discards the held step).
///
/// **Severity.** Low-medium: needs a redo during a composition (a hardware keyboard with an IME, iPad's
/// three-finger swipe, the edit menu); then the pre-composition state is lost from history and the
/// composition lands in the wrong place.
///
/// **Tier 1**: `setMarkedText` / `unmarkText` as a CJK keyboard calls them, the view's `undoManager` as ⌘Z /
/// ⌘⇧Z drive it, a stock `UITextView` as the oracle.
@available(iOS 18.4, *)
final class HarnessRedoDuringCompositionTests: XCTestCase {
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

    private var input: UIView & UITextInput { self.driver.view as! (UIView & UITextInput) }

    /// "x", type "ab" at 1, undo (a redo is now available), caret 0, compose k → か (left marked).
    private func arrangeOpenCompositionOverARedo() throws -> UndoManager {
        HarnessComposerFuzzTests.arrange(self.driver, HarnessContent.plainText("x"))
        let undoManager = try XCTUnwrap(self.driver.undoManager)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle(0.05)
        self.driver.insert("a")
        self.driver.insert("b")
        self.driver.settle(0.1)
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "x", "precondition: the typing is undone")
        XCTAssertTrue(undoManager.canRedo, "precondition: a redo is available")
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle(0.05)
        for text in ["k", "か"] {
            self.input.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            self.driver.settle(0.03)
        }
        XCTAssertNotNil(self.input.markedTextRange, "precondition: the composition is open")
        return undoManager
    }

    // MARK: - Red

    func testRedoIsNotOfferedWhileACompositionIsOpen() throws {
        let undoManager = try self.arrangeOpenCompositionOverARedo()
        XCTAssertFalse(undoManager.canRedo, "redo is offered during an open composition (a stock text view's first marked edit clears it)")
    }

    func testARedoDuringACompositionLeavesTheCompositionAlone() throws {
        let undoManager = try self.arrangeOpenCompositionOverARedo()
        undoManager.redo()
        self.driver.settle(0.1)
        self.input.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        self.driver.settle(0.03)
        self.input.unmarkText()
        self.driver.settle(0.1)
        XCTAssertEqual(fuzzEscaped(self.driver.model().plainText), fuzzEscaped("かんx"), "a redo during the composition replaced it")
    }

    func testTheDocumentBeforeTheCompositionStaysReachable() throws {
        let undoManager = try self.arrangeOpenCompositionOverARedo()
        undoManager.redo()
        self.driver.settle(0.1)
        self.input.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        self.driver.settle(0.03)
        self.input.unmarkText()
        self.driver.settle(0.1)
        var seen: [String] = [self.driver.model().plainText]
        while undoManager.canUndo, seen.count < 10 {
            undoManager.undo()
            self.driver.settle(0.1)
            seen.append(self.driver.model().plainText)
        }
        XCTAssertEqual(seen.last, "x", "undo never returns to the document before the composition: \(seen.map(fuzzEscaped))")
    }

    // MARK: - Controls

    /// Without a composition the redo is offered and works.
    func testControlRedoAfterAnUndoWithoutAComposition() throws {
        HarnessComposerFuzzTests.arrange(self.driver, HarnessContent.plainText("x"))
        let undoManager = try XCTUnwrap(self.driver.undoManager)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle(0.05)
        self.driver.insert("a")
        self.driver.settle(0.1)
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "xa")
    }

    /// Oracle: a stock text view offers no redo during the composition, and the composition commits in place.
    func testControlStockTextView() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        func settle() { HarnessEngine.settle(root, seconds: 0.05) }
        textView.text = "x"
        textView.undoManager?.removeAllActions()
        _ = textView.becomeFirstResponder()
        settle()
        let undoManager = try XCTUnwrap(textView.undoManager)
        textView.selectedRange = NSRange(location: 1, length: 0)
        settle()
        textView.insertText("a")
        textView.insertText("b")
        settle()
        undoManager.undo()
        settle()
        XCTAssertTrue(undoManager.canRedo)
        textView.selectedRange = NSRange(location: 0, length: 0)
        settle()
        for text in ["k", "か"] {
            textView.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            settle()
        }
        XCTAssertFalse(undoManager.canRedo)
        // (A redo with nothing to redo is not sent: UIKit only offers the verb when `canRedo` says so.)
        if undoManager.canRedo {
            undoManager.redo()
            settle()
        }
        textView.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        settle()
        textView.unmarkText()
        settle()
        XCTAssertEqual(fuzzEscaped(textView.text), fuzzEscaped("かんx"))
    }

    // MARK: - Neighbours (p22 fix wave)

    /// A CANCELLED composition clears redo too (stock does: its first marked edit registered), and by the p21
    /// decision registers no undo step of its own: the next ⌘Z still reverts the typing before the undo's
    /// target, not a no-op (stock registers one; deliberately not matched).
    func testACancelledCompositionClearsRedoAndRegistersNothing() throws {
        HarnessComposerFuzzTests.arrange(self.driver, HarnessContent.plainText("x"))
        let undoManager = try XCTUnwrap(self.driver.undoManager)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle(0.05)
        self.driver.insert("a")
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle(0.05)
        self.driver.insert("q")
        self.driver.settle(0.1)
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "xa")
        XCTAssertTrue(undoManager.canRedo)
        self.driver.setViewSelection(NSRange(location: 2, length: 0))
        self.driver.settle(0.05)
        self.input.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        self.driver.settle(0.03)
        XCTAssertFalse(undoManager.canRedo, "redo offered during the composition")
        self.input.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        self.input.unmarkText()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "xa")
        XCTAssertFalse(undoManager.canRedo, "redo came back after the cancel")
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "x", "the ⌘Z after the cancel did not revert the typing before it")
    }

    /// A composition with NOTHING to redo leaves undo intact: one undo takes back the composition, the next the
    /// typing before it (the redo-clearing must not disturb the undo stack).
    func testACompositionWithNoRedoKeepsTheUndoStack() throws {
        HarnessComposerFuzzTests.arrange(self.driver, HarnessContent.plainText("x"))
        let undoManager = try XCTUnwrap(self.driver.undoManager)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle(0.05)
        self.driver.insert("a")
        self.driver.settle(0.1)
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle(0.05)
        for text in ["k", "か"] {
            self.input.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            self.driver.settle(0.03)
        }
        self.input.unmarkText()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "かxa")
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "xa")
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "x")
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        self.driver.settle(0.1)
        undoManager.redo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "かxa", "redo did not walk back to the composed state")
    }

    /// Undo DURING the composition after an undo: reverts the composition, and the old redo is gone (the
    /// composition's step is the redo now).
    func testUndoDuringACompositionOverARedo() throws {
        let undoManager = try self.arrangeOpenCompositionOverARedo()
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()
        self.driver.settle(0.1)
        XCTAssertEqual(self.driver.model().plainText, "x")
        XCTAssertNil(self.input.markedTextRange)
        undoManager.redo()
        self.driver.settle(0.1)
        XCTAssertFalse(self.driver.model().plainText.contains("ab"), "redo replayed the typing the composition had cleared: \(fuzzEscaped(self.driver.model().plainText))")
    }
}
