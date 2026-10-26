import XCTest
import UIKit
import TelegramCore
import AccountContext
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Undo and Redo reach ACROSS a content set the chat makes from
/// outside — Send's clear, a draft arriving from another device, anything the chat pushes through
/// `updateInputTextState` (`RichTextEditorChatInputNode.setInputContent`). The steps typed before the set
/// stay on the stack, and replaying one restores the document as it was BEFORE the set, wiping what the
/// chat put there:
///
///     "abc", type "d", a draft sync pushes "remote draft", ⌘Z → "abc"            the pushed draft is gone
///     "Hello" (a draft), type " world", Send, ⌘Z             → "Hello"          the sent message comes back
///     type, ⌘Z, a draft sync, ⌘⇧Z                             → the pre-sync text replaces the draft
///
/// A stock `UITextView` empties its undo stack when `text` / `attributedText` is set, and so does the
/// legacy composer (its `setInputContent` sets `attributedText`): after either set `canUndo` and
/// `canRedo` are false (controls below).
///
/// **How it was seen.** p15 (2026-09-24), external content sets while editing: a hosted probe pushed a
/// different `ChatTextInputState` through the panel's interface interaction — the route
/// `ChatControllerNode` takes — while the engine held an open typing run. The fuzz's undo-all check
/// could not see it: it accepts undo-all landing on the START model, which is exactly where an undo that
/// crosses the Send clear lands.
///
/// **Suspected cause.** The `document` setter (`RichTextEngineEditorView.swift`) treats a host set as a
/// new undo BASELINE (`endTypingRun()`, `lastSettledUndoSnapshot = currentUndoSnapshot()`) and keeps the
/// history, which is right for the editor's own commands that rebuild through the setter and register
/// their own step; the node's EXTERNAL set (`RichTextEditorChatInputNode.setInputContent`'s rebuild
/// branch) never clears the engine's undo manager (`engineUndoManager.removeAllActions()`), as the
/// stock text view does. A content-EQUAL set (the chat's echo of the editor's own edit) must keep the
/// stack, and does: it returns before the rebuild.
///
/// **Tier 1**: the chat's set goes through `ChatPanelInterfaceInteraction.updateTextInputStateAndMode`,
/// as `ChatControllerNode` does; Send is the harness's `simulateSend` (the panel's clear); undo and redo
/// are the text view's `undoManager`, which ⌘Z and the edit menu reach.
@available(iOS 18.4, *)
final class HarnessExternalSetUndoTests: XCTestCase {
    /// The chat's external set: `updateChatPresentationInterfaceState` → `ChatControllerNode` →
    /// `updateInputTextState`, which is how Send's clear and a draft sync arrive — NOT the interface
    /// interaction's `updateTextInputStateAndMode`, which is the funnel of the user's own edits through
    /// the chat and applies them undoably (`HarnessChatSideEditUndoTests`). Until 2026-09-25 this pushed
    /// through the interaction, which reached the same `setInputContent` then.
    static func push(_ host: HarnessPanelHost, _ content: ChatInputContent, caret: Int? = nil) {
        let offset = caret ?? content.plainText.utf16.count
        host.setInputContent(content, selectionRange: offset ..< offset)
    }

    private func type(_ driver: EngineFuzzDriver, _ text: String) {
        for character in text {
            driver.insert(String(character))
        }
        driver.settle(0.2)
    }

    private func engine(_ start: String) throws -> (EngineFuzzDriver, FuzzEngineVerifier) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        driver.arrange(HarnessContent.plainText(start))
        return (driver, verifier)
    }

    func testUndoAfterADraftSyncKeepsThePushedDraft() throws {
        let (driver, verifier) = try self.engine("abc")
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        self.type(driver, "d")
        XCTAssertEqual(driver.undoManager?.canUndo, true, "precondition: the typing registered no undo step")

        Self.push(driver.host, HarnessContent.plainText("remote draft"))
        driver.settle(0.2)
        XCTAssertEqual(driver.model().plainText, "remote draft", "precondition: the push did not land")

        XCTAssertEqual(driver.undoManager?.canUndo, false, "Undo is still offered after the chat replaced the content (stock and legacy: false)")
        if driver.undoManager?.canUndo == true {
            driver.undoManager?.undo()
            driver.settle(0.2)
        }
        XCTAssertEqual(driver.model().plainText, "remote draft", "an undo after the draft sync threw the pushed draft away")
    }

    func testUndoAfterSendDoesNotBringTheSentTextBack() throws {
        let (driver, verifier) = try self.engine("Hello")
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        self.type(driver, " world")
        let before = driver.root.historyView.entries.count
        driver.root.simulateSend()
        driver.settle(0.2)
        XCTAssertEqual(driver.root.historyView.entries.count, before + 1, "precondition: nothing was sent")
        XCTAssertEqual(driver.model().plainText, "", "precondition: Send did not clear the composer")

        XCTAssertEqual(driver.undoManager?.canUndo, false, "Undo is still offered after Send cleared the composer (stock and legacy: false)")
        if driver.undoManager?.canUndo == true {
            driver.undoManager?.undo()
            driver.settle(0.2)
        }
        XCTAssertEqual(driver.model().plainText, "", "an undo after Send brought the sent message's text back")
    }

    func testRedoAfterADraftSyncDoesNotRestoreTheOlderText() throws {
        let (driver, verifier) = try self.engine("abc")
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        self.type(driver, "d")
        driver.undoManager?.undo()
        driver.settle(0.2)
        XCTAssertEqual(driver.undoManager?.canRedo, true, "precondition: nothing to redo")

        Self.push(driver.host, HarnessContent.plainText("remote draft"))
        driver.settle(0.2)
        XCTAssertEqual(driver.undoManager?.canRedo, false, "Redo is still offered after the chat replaced the content (stock and legacy: false)")
        if driver.undoManager?.canRedo == true {
            driver.undoManager?.redo()
            driver.settle(0.2)
        }
        XCTAssertEqual(driver.model().plainText, "remote draft", "a redo after the draft sync replaced the pushed draft with the older text")
    }

    /// Control: typing AFTER the set is undoable back to exactly the pushed content.
    func testControlTypingAfterAPushUndoesToThePushedContent() throws {
        let (driver, verifier) = try self.engine("abc")
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        Self.push(driver.host, HarnessContent.plainText("remote draft"))
        driver.settle(0.2)
        self.type(driver, "X")
        driver.undoManager?.undo()
        driver.settle(0.2)
        XCTAssertEqual(driver.model().plainText, "remote draft")
    }

    /// Control: a content-EQUAL set (the chat's echo of the editor's own edit) keeps the stack.
    func testControlAnEchoKeepsTheUndoStack() throws {
        let (driver, verifier) = try self.engine("abc")
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        self.type(driver, "d")
        Self.push(driver.host, driver.model())
        driver.settle(0.2)
        XCTAssertEqual(driver.undoManager?.canUndo, true)
        driver.undoManager?.undo()
        driver.settle(0.2)
        XCTAssertEqual(driver.model().plainText, "abc")
    }

    /// Control: the legacy composer empties its stack on both sets.
    func testControlLegacyClearsTheUndoStackOnAnExternalSet() throws {
        let arranged = try HarnessLegacy.arrange(HarnessContent.plainText("abc"))
        defer { HarnessLegacy.restore(arranged) }
        arranged.textView.insertText("d")
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(arranged.textView.undoManager?.canUndo, true, "precondition: legacy registered no undo step")
        Self.push(arranged.host, HarnessContent.plainText("remote draft"))
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(arranged.textView.undoManager?.canUndo, false)

        arranged.textView.insertText("!")
        HarnessEngine.settle(arranged.root)
        arranged.root.simulateSend()
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(arranged.textView.undoManager?.canUndo, false)
    }

    /// Control: a stock `UITextView` empties its stack when its text is set.
    func testControlStockTextViewClearsTheUndoStackOnASet() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 100.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        XCTAssertTrue(textView.becomeFirstResponder(), "precondition: the stock text view did not focus")
        textView.insertText("d")
        HarnessEngine.settle(root)
        XCTAssertEqual(textView.undoManager?.canUndo, true, "precondition: stock registered no undo step")
        textView.attributedText = NSAttributedString(string: "remote draft")
        HarnessEngine.settle(root)
        XCTAssertEqual(textView.undoManager?.canUndo, false)
        XCTAssertEqual(textView.undoManager?.canRedo, false)
    }
}
