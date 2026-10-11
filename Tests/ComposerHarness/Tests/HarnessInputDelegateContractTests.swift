import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** The simulator's keyboard daemon (kbd) aborted deterministically at fuzz seed 15,
/// undo-all step 23 (`NSRangeException` under `-[TIRevisionHistory handleRevisedTokenString:…]` ←
/// `syncToDocumentState:`), and every keyboard sync after it waited out a timeout. The kbd row in
/// `docs/findings.md` has the history.
///
/// **How it was seen.** A spy on the keyboard state manager during a replay of seed 15 showed the
/// document state UIKit sent kbd right after the undo's `textDidChange:`:
/// `"Sub heax\u{FFFD}[\u{FFFD}yadi…"` — the selection marker BETWEEN the two halves of the 😀
/// surrogate pair. When a host set lands (an undo/redo snapshot, a content set) the engine rewrites
/// the text inside `textWillChange:`/`textDidChange:`, but UIKit's input controller still held the
/// PREVIOUS document's selection: its ranges are untracked snapshots, and the engine re-seated the
/// selection only AFTER `textDidChange:`. UIKit builds the document state it sends the daemon from
/// the selection at `textDidChange:`, so it sent the old offsets resolved against the new text.
/// There they split an emoji, and kbd aborted on the lone surrogates.
///
/// **The contract pinned here, measured on a stock `UITextView` (the control in every case):** at
/// every `textDidChange:` / `selectionDidChange:` the input delegate receives, the selection lies
/// inside the document and on composed-character boundaries, and the text brackets are balanced and
/// never nested. (Not pinned: that the text never changes OUTSIDE a bracket. A programmatic
/// `insertText(_:)` — the call the harness makes where the keyboard would — sends no bracket on a
/// stock `UITextView` either, measured; the keyboard knows about its own insertions.)
///
/// **Tier 1**: `insertText(_:)`, the undo manager and `setInputContent` are the calls the keyboard,
/// the system undo and the chat make. The input delegate is wrapped in-process by a forwarding
/// recorder, so UIKit still receives every call.
final class HarnessInputDelegateContractTests: XCTestCase {
    /// Forwards every call to UIKit's delegate and records what `UITextInput` answers at that moment.
    final class Recorder: NSObject, UITextInputDelegate {
        weak var forward: UITextInputDelegate?
        weak var input: (UIView & UITextInput)?
        var problems: [String] = []
        var log: [String] = []
        private var inTextBracket = false

        init(input: UIView & UITextInput) {
            self.input = input
            self.forward = input.inputDelegate
            super.init()
        }

        func text() -> String {
            guard let input, let all = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument) else { return "" }
            return input.text(in: all) ?? ""
        }

        private func checkSelection(_ event: String) {
            guard let input, let selected = input.selectedTextRange else { return }
            let text = self.text() as NSString
            let start = input.offset(from: input.beginningOfDocument, to: selected.start)
            let end = input.offset(from: input.beginningOfDocument, to: selected.end)
            self.log.append("\(event) text=\(fuzzEscaped(text as String)) sel=\(start)..<\(end)")
            if start < 0 || end > text.length || start > end {
                self.problems.append("\(event): selection \(start)..<\(end) outside the document (length \(text.length)) \(fuzzEscaped(text as String))")
                return
            }
            for offset in [start, end] where offset > 0 && offset < text.length {
                if text.rangeOfComposedCharacterSequence(at: offset).location != offset {
                    self.problems.append("\(event): selection \(start)..<\(end) splits a composed character in \(fuzzEscaped(text as String))")
                    return
                }
            }
        }

        func textWillChange(_ textInput: UITextInput?) {
            if self.inTextBracket {
                self.problems.append("textWillChange: nested inside another text bracket")
            }
            self.inTextBracket = true
            self.forward?.textWillChange(textInput)
        }

        func textDidChange(_ textInput: UITextInput?) {
            if !self.inTextBracket {
                self.problems.append("textDidChange: without textWillChange")
            }
            self.inTextBracket = false
            self.checkSelection("textDidChange")
            self.forward?.textDidChange(textInput)
        }

        func selectionWillChange(_ textInput: UITextInput?) {
            self.forward?.selectionWillChange(textInput)
        }

        func selectionDidChange(_ textInput: UITextInput?) {
            self.checkSelection("selectionDidChange")
            self.forward?.selectionDidChange(textInput)
        }

        @available(iOS 18.4, *)
        func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {
            self.forward?.conversationContext(context, didChange: textInput)
        }

        // UIKit also sends its delegate private messages; they reach it unchanged.
        override func responds(to selector: Selector!) -> Bool {
            return super.responds(to: selector) || ((self.forward as? NSObject)?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            return self.forward
        }

        func finish() {
            if self.inTextBracket {
                self.problems.append("a textWillChange was never closed")
            }
        }
    }

    private func settle(_ root: HarnessRootViewController, _ seconds: TimeInterval = 0.1) {
        HarnessEngine.settle(root, seconds: seconds)
    }

    /// Type `Z` at the start of `a😀b`, put the caret before the emoji, undo, redo — on `input`.
    private func typeMoveUndoRedo(_ input: UIView & UITextInput, root: HarnessRootViewController, setCaret: (Int) -> Void) {
        setCaret(0)
        self.settle(root)
        input.insertText("Z")
        self.settle(root)
        // Before the emoji in "Za😀b": offset 2. The same offset splits the emoji once Z is undone.
        setCaret(2)
        self.settle(root)
        input.undoManager?.undo()
        self.settle(root)
        input.undoManager?.redo()
        self.settle(root)
    }

    private func install(_ input: UIView & UITextInput) throws -> Recorder {
        XCTAssertNotNil(input.inputDelegate, "precondition: UIKit bound no input delegate")
        let recorder = Recorder(input: input)
        input.inputDelegate = recorder
        XCTAssertTrue(input.inputDelegate === recorder, "precondition: the recorder did not take the delegate role")
        return recorder
    }

    func testStockTextViewKeepsTheSelectionValidAtEveryNotification() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 120.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        XCTAssertTrue(textView.becomeFirstResponder(), "precondition: the stock text view did not focus")
        textView.text = "a😀b"
        self.settle(root)
        let recorder = try self.install(textView)
        defer { textView.inputDelegate = recorder.forward }
        self.typeMoveUndoRedo(textView, root: root) { textView.selectedRange = NSRange(location: $0, length: 0) }
        recorder.finish()
        XCTAssertEqual(textView.text, "Za😀b", "control: the stock sequence did not end on the redone text")
        XCTAssertEqual(recorder.problems, [], "control: stock UIKit broke the contract\n" + recorder.log.joined(separator: "\n"))
    }

    func testEngineUndoAndRedoKeepTheSelectionValidAtEveryNotification() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText("a😀b"))
        self.settle(root, 0.3)
        _ = node.makeInputFirstResponder()
        self.settle(root, 0.3)
        let input = try XCTUnwrap(try HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        input.undoManager?.removeAllActions()
        let recorder = try self.install(input)
        defer { input.inputDelegate = recorder.forward }
        self.typeMoveUndoRedo(input, root: root) { offset in
            let position = input.position(from: input.beginningOfDocument, offset: offset)!
            input.selectedTextRange = input.textRange(from: position, to: position)
        }
        recorder.finish()
        XCTAssertEqual(recorder.text(), "Za😀b", "precondition: the engine sequence did not end on the redone text")
        XCTAssertEqual(recorder.problems, [], recorder.log.joined(separator: "\n"))
    }

    func testEngineContentSetKeepsTheSelectionValidAtEveryNotification() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText("Za😀b"))
        self.settle(root, 0.3)
        _ = node.makeInputFirstResponder()
        self.settle(root, 0.3)
        let input = try XCTUnwrap(try HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        // Before the emoji: offset 2, which splits it in the text set next.
        let position = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 2))
        input.selectedTextRange = input.textRange(from: position, to: position)
        self.settle(root)
        let recorder = try self.install(input)
        defer { input.inputDelegate = recorder.forward }
        host.setInputContent(HarnessContent.plainText("a😀b"))
        self.settle(root, 0.3)
        recorder.finish()
        XCTAssertEqual(recorder.text(), "a😀b", "precondition: the content set did not land")
        XCTAssertEqual(recorder.problems, [], recorder.log.joined(separator: "\n"))
    }
}
