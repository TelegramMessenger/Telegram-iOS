import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, what text typed over a selection is formatted with depends on
/// the document's HISTORY, not on the document: Return at the start of a struck-through line leaves an
/// empty line whose (invisible) separator carries the strikethrough, so typing over a selection that
/// starts on that empty line is struck; after ANY undo that re-renders the line — the Return undone and
/// redone, or an unrelated letter typed elsewhere and undone — the same model with the same selection
/// types plain:
///
///     [p [s]"ab "] [p [s]"漢字"], caret 4 (start of 漢字), Return → [p [s]"ab "] [p ""] [p [s]"漢字"]
///     select 4..<6 (the empty line and 漢), type 中国
///       straight away:                        [p [s]"ab "] [p [s]"中国字"]
///       after type-a-letter-at-0-then-undo:   [p [s]"ab "] [p "中国"+[s]"字"]
///       after undo + redo of the Return:      [p [s]"ab "] [p "中国"+[s]"字"]
///     a stock UITextView: struck in all three (its undo restores the separator's attributes)
///     an IME composition over the same selection agrees with typing in each state (control)
///
/// The model has no way to carry formatting on an empty paragraph, so after a set of the same model the
/// line types plain too; the struck answer comes only from a separator the Return split minted with the
/// split line's typing attributes. Either answer could be the rule; it must not change across an undo.
///
/// **How it was seen.** p21 roam (2026-10-01), reducing the open default/edited fuzz failure at seed 73
/// step 55 ("a pinyin composition over (36, 38) commits all struck; typing gives 中国 plain"), left open
/// by the p20 fix wave. Reduced by replaying the seed and shrinking: the composition does what FRESH
/// typing does (both struck); the fuzz's oracle types after UNDOING the composition, and that undo
/// re-rendered the empty line's separator plain. So the composition was right and the oracle compared
/// unlike states — but the states are unlike only because the engine's undo is not faithful, which is
/// this defect. (The fuzz's oracle now compares like with like and reports this class separately.)
///
/// **Suspected cause.** The undo replay restores blocks from the model snapshot through the document
/// set path (`renderedBlocksAgree` span replace), which renders a separator from the role, while the
/// Return split (`engineDidFinishEdit` / settle) leaves the separator with the controller's typing
/// attributes; `normalisePresentation` does not re-derive separators (the batch edits block TEXT only,
/// p15 follow-up), so a split's separator keeps presentation the role does not derive.
///
/// **Severity.** Low: drawn as sent; the formatting of typed text depends on an undo the user made
/// elsewhere.
///
/// **Tier 1**: `insertText`, `undoManager.undo()` / `redo()` and a view selection, as the keyboard and
/// ⌘Z drive them.
@available(iOS 18.4, *)
final class HarnessUndoSeparatorTypingAttributesTests: XCTestCase {
    private static var struck: ChatInputInlineAttributes {
        var value = ChatInputInlineAttributes()
        value.strikethrough = true
        return value
    }

    private static let start = ChatInputContent(blocks: [
        .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "ab ", attributes: HarnessUndoSeparatorTypingAttributesTests.struck)])),
        .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "漢字", attributes: HarnessUndoSeparatorTypingAttributesTests.struck)])),
    ])

    private enum History {
        case none, unrelatedUndo, undoRedo
        var ops: [FuzzOp] {
            switch self {
            case .none: return [.edge(4, .newline)]
            case .unrelatedUndo: return [.edge(4, .newline), .edge(0, .letter), .undo]
            case .undoRedo: return [.edge(4, .newline), .undo, .redo]
            }
        }
    }

    /// The model after `history`, then 中国 typed (or composed) over 4..<6 — the selection made by moving
    /// the caret away first, as a user's selection is.
    private func result(_ history: History, composing: Bool = false) throws -> (before: ChatInputContent, after: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: history.ops)
        let before = FuzzModel.normalized(driver.model())
        driver.setViewSelection(NSRange(location: 0, length: 0))
        driver.settle(0.05)
        driver.setViewSelection(NSRange(location: 4, length: 2))
        driver.settle(0.05)
        if composing {
            for step in FuzzIME.pinyin.steps {
                input.setMarkedText(step.text, selectedRange: step.selected)
                driver.settle(0.03)
            }
            input.unmarkText()
        } else {
            driver.insert("中国")
        }
        driver.settle(0.2)
        return (before, FuzzModel.normalized(driver.model()))
    }

    private func assertSameAsWithoutTheUndo(_ history: History, _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let fresh = try self.result(.none)
        let other = try self.result(history)
        XCTAssertEqual(FuzzModel.describe(other.before), FuzzModel.describe(fresh.before), "precondition: the history did not lead to the same document", file: file, line: line)
        XCTAssertEqual(FuzzModel.describe(other.after), FuzzModel.describe(fresh.after),
                       "\(what): the same document and selection typed differently\n  without it \(FuzzModel.describe(fresh.after))\n  with it    \(FuzzModel.describe(other.after))",
                       file: file, line: line)
    }

    // MARK: - Red

    func testAnUnrelatedUndoDoesNotChangeHowTypingOverTheEmptyLineIsFormatted() throws {
        try self.assertSameAsWithoutTheUndo(.unrelatedUndo, "after a letter typed elsewhere and undone")
    }

    func testUndoAndRedoOfTheReturnDoNotChangeHowTypingOverTheEmptyLineIsFormatted() throws {
        try self.assertSameAsWithoutTheUndo(.undoRedo, "after the Return undone and redone")
    }

    // MARK: - Controls

    /// The engine's composition agrees with its typing in each state (the fuzz's original report was the
    /// oracle typing after an undo, i.e. in the second state).
    func testControlCompositionMatchesTypingInEachState() throws {
        for history in [History.none, .unrelatedUndo] {
            let typed = try self.result(history)
            let composed = try self.result(history, composing: true)
            XCTAssertEqual(FuzzModel.describe(composed.after), FuzzModel.describe(typed.after), "control: composing and typing disagree after \(history)")
        }
    }

    /// A stock `UITextView` given the same keystrokes types struck text over the same selection with or
    /// without the undo cycles: its undo restores the separator's attributes.
    func testControlStockTextViewIsIndependentOfTheUndo() throws {
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
        func struckText(_ history: History) -> String {
            textView.attributedText = NSAttributedString(string: "ab \n漢字", attributes: [.font: UIFont.systemFont(ofSize: 17.0), .strikethroughStyle: NSUnderlineStyle.single.rawValue])
            textView.undoManager?.removeAllActions()
            _ = textView.becomeFirstResponder()
            settle()
            textView.selectedRange = NSRange(location: 4, length: 0)
            settle()
            textView.insertText("\n")
            settle()
            switch history {
            case .none:
                break
            case .unrelatedUndo:
                textView.selectedRange = NSRange(location: 0, length: 0)
                settle()
                textView.insertText("q")
                settle()
                textView.undoManager?.undo()
                settle()
            case .undoRedo:
                textView.undoManager?.undo()
                settle()
                textView.undoManager?.redo()
                settle()
            }
            textView.selectedRange = NSRange(location: 0, length: 0)
            settle()
            textView.selectedRange = NSRange(location: 4, length: 2)
            settle()
            textView.insertText("中国")
            settle()
            var result = ""
            let text = textView.attributedText ?? NSAttributedString()
            text.enumerateAttribute(.strikethroughStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
                if value != nil {
                    result += (text.string as NSString).substring(with: range)
                }
            }
            return result
        }
        let fresh = struckText(.none)
        XCTAssertTrue(fresh.contains("中国"), "control: stock does not strike the typed text: \(fuzzEscaped(fresh))")
        XCTAssertEqual(struckText(.unrelatedUndo), fresh, "control: stock types differently after an unrelated undo")
        XCTAssertEqual(struckText(.undoRedo), fresh, "control: stock types differently after undo + redo")
    }
}
