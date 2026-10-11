import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, ⌘← (move to the start of the line) and ⇧⌘← (select to it)
/// do nothing when the caret is at the END of a paragraph — the most common place to press them,
/// right after typing a line. Mid-line they work.
///
///     "First paragraph, with words.⏎Second …", caret at 28 (end of line 1), ⌘←
///       engine: caret stays at 28; ⇧⌘← selects nothing
///       stock UITextView (same text): 0 / 0..<28
///     `two-paragraphs`, caret at the end of the text (34), real HID ⌘← (XCUITest `typeKey`):
///       engine 34 → 34, legacy 34 → 17; ⇧⌘← engine nothing, legacy 17..<34
///
/// **How it was seen.** p11 roam, 2026-09-24: the arrow-key actions UIKit's hardware-keyboard
/// handling sends (`_moveToStartOfLine:withHistory:` & co.) driven against the engine and a stock
/// `UITextView` with the same text — every other movement (character, word, paragraph, document,
/// ⌥←/⌥→, up/down across blocks) matched — then confirmed with real HID keys through XCUITest.
///
/// **Suspected cause.** The line boundary UIKit's input controller resolves over the engine's layout
/// at a position that ends a block (just before the block separator): backward to the line start it
/// answers the same position. Look at the engine's line-granularity answer for an end-of-block
/// position (the tokenizer / `caretRect`/`closestPosition` pair behind
/// `positionFromPosition:toBoundary:UITextGranularityLine inDirection:`).
///
/// **Fixed (2026-09-24).** UIKit's `_UITextInputControllerTokenizer` answered a position that ENDS a
/// block (or the document) as an empty line of its own (`rangeEnclosingPosition` → `p..p`, backward
/// boundary → `p`); a stock `UITextView` answers the line it ends. `TGIDObservingBlockTextView` now
/// hands out `TGIDLineEndCorrectingTokenizer`, which corrects exactly that answer (and leaves a
/// genuinely empty line alone).
///
/// **Tier 1**: `_moveToStartOfLine:withHistory:` is the action ⌘← performs on the first responder;
/// a stock `UITextView` given the same text and caret is the oracle. Tier 2 reproduced it with real
/// key events and was reduced to this.
final class HarnessLineStartKeyTests: XCTestCase {
    private typealias MoveFunction = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> AnyObject?
    private let text = "First paragraph, with words.\nSecond line."

    /// Performs the private arrow-key action `name` (extending the selection when `extending`).
    private func perform(_ name: String, on target: NSObject, extending: Bool) throws {
        let selector = NSSelectorFromString(name)
        let method = try XCTUnwrap(class_getInstanceMethod(type(of: target), selector), "precondition: \(type(of: target)) has no \(name)")
        let function = unsafeBitCast(method_getImplementation(method), to: MoveFunction.self)
        _ = function(target, selector, extending, nil)
    }

    private func selection(_ input: UITextInput) -> NSRange? {
        guard let range = input.selectedTextRange else { return nil }
        let start = input.offset(from: input.beginningOfDocument, to: range.start)
        return NSRange(location: start, length: input.offset(from: range.start, to: range.end))
    }

    private func engineSelection(afterLineStartFrom caret: Int, extending: Bool, action: String = "_moveToStartOfLine:withHistory:", text: String? = nil) throws -> NSRange? {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText(text ?? self.text))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        let position = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: caret))
        view.selectedTextRange = view.textRange(from: position, to: position)
        HarnessEngine.settle(root)
        try self.perform(action, on: view, extending: extending)
        HarnessEngine.settle(root)
        return self.selection(view)
    }

    private func stockSelection(afterLineStartFrom caret: Int, extending: Bool, action: String = "_moveToStartOfLine:withHistory:", text: String? = nil) throws -> NSRange {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 380.0, height: 200.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        _ = textView.becomeFirstResponder()
        textView.text = text ?? self.text
        textView.selectedRange = NSRange(location: caret, length: 0)
        try self.perform(action, on: textView, extending: extending)
        return textView.selectedRange
    }

    func testCommandLeftAtTheEndOfAParagraphMovesToItsStart() throws {
        XCTAssertEqual(try self.stockSelection(afterLineStartFrom: 28, extending: false), NSRange(location: 0, length: 0), "control: stock")
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: 28, extending: false), NSRange(location: 0, length: 0),
                       "⌘← at the end of the first paragraph did not move the caret to the line start")
    }

    func testCommandLeftAtTheEndOfTheTextMovesToTheLastLinesStart() throws {
        let end = (self.text as NSString).length
        XCTAssertEqual(try self.stockSelection(afterLineStartFrom: end, extending: false), NSRange(location: 29, length: 0), "control: stock")
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: end, extending: false), NSRange(location: 29, length: 0),
                       "⌘← at the end of the text did not move the caret to the last line's start")
    }

    func testShiftCommandLeftAtTheEndOfAParagraphSelectsTheLine() throws {
        XCTAssertEqual(try self.stockSelection(afterLineStartFrom: 28, extending: true), NSRange(location: 0, length: 28), "control: stock")
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: 28, extending: true), NSRange(location: 0, length: 28),
                       "⇧⌘← at the end of the first paragraph did not select to the line start")
    }

    /// ⌘→ at the START of a paragraph goes to its end, as stock. Added with the fix (2026-09-24; it
    /// already worked — the engine's forward answer at a block start was right).
    func testCommandRightAtTheStartOfAParagraphMovesToItsEnd() throws {
        let action = "_moveToEndOfLine:withHistory:"
        let stock = try self.stockSelection(afterLineStartFrom: 29, extending: false, action: action)
        XCTAssertEqual(stock, NSRange(location: 41, length: 0), "control: stock")
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: 29, extending: false, action: action), stock)
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: 28, extending: false, action: action),
                       try self.stockSelection(afterLineStartFrom: 28, extending: false, action: action), "⌘→ at a line's end")
    }

    /// An EMPTY paragraph is a line of its own: ⌘← and ⌘→ on it stay put, as stock, and ⌘← at the end
    /// of the line before it still reaches that line's start. Added with the fix (2026-09-24): the
    /// correction must not merge an empty line into the one before it.
    func testAnEmptyParagraphStaysALineOfItsOwn() throws {
        let text = "First line\n\nThird"
        for (caret, action) in [(11, "_moveToStartOfLine:withHistory:"), (11, "_moveToEndOfLine:withHistory:"), (10, "_moveToStartOfLine:withHistory:")] {
            XCTAssertEqual(try self.engineSelection(afterLineStartFrom: caret, extending: false, action: action, text: text),
                           try self.stockSelection(afterLineStartFrom: caret, extending: false, action: action, text: text),
                           "\(action) from \(caret)")
        }
    }

    /// Control: mid-line, ⌘← works on the engine.
    func testControlCommandLeftMidLine() throws {
        XCTAssertEqual(try self.engineSelection(afterLineStartFrom: 10, extending: false), NSRange(location: 0, length: 0), "control")
    }
}
