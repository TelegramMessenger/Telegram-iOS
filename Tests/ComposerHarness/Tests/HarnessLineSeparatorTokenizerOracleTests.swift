import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **Not a product defect — the fuzz invariant was stricter than UIKit (p16, 2026-09-25).**
///
/// Edited-content fuzz seed 83 (p16 sweep, step 18) failed `FuzzTextInputConsistency`: after ⇧↑ landed
/// the selection on the start of a line inside a PULL QUOTE — a line beginning right after a `U+2028`
/// — the tokenizer's LINE boundary FORWARD from the selection start was the separator itself, one
/// BEFORE the anchor. Reduced by hand:
///
///     [pull "first line here⏎second line here⏎third line here⏎fourth"] (⏎ = U+2028 in the engine)
///     caret 30, ⇧↑ → 16..<30; forward line boundary from the selection start → 15 (the U+2028)
///
/// A stock `UITextView` holding the same text answers EXACTLY the same (15, oracle inside): the
/// up-move leaves a position with the line above's affinity, and UIKit's own tokenizer honours it at a
/// hard line separator. So the invariant now forgives exactly that answer (a line boundary forward
/// that is the U+2028 immediately before the anchor), and these tests pin that the engine agrees with
/// stock there. The seed's 11-op reduction answered the same way (121 before 122, the separator).
/// Nothing is filed as an engine defect.
///
/// **Tier 1**: `_moveUp:withHistory:` is the action ⇧↑ performs on the first responder.
@available(iOS 18.4, *)
final class HarnessLineSeparatorTokenizerOracleTests: XCTestCase {
    private static let lines = "first line here\nsecond line here\nthird line here\nfourth"

    private func forwardLineBoundary(_ input: UIView & UITextInput, from position: UITextPosition) -> Int? {
        return input.tokenizer.position(from: position, toBoundary: .line, inDirection: UITextDirection(rawValue: UITextStorageDirection.forward.rawValue))
            .map { input.offset(from: input.beginningOfDocument, to: $0) }
    }

    private func stockAnswer() throws -> (selection: NSRange, boundary: Int?) {
        let root = try HarnessEngine.root()
        let stock = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 300.0, height: 200.0))
        root.view.addSubview(stock)
        defer {
            stock.resignFirstResponder()
            stock.removeFromSuperview()
        }
        stock.font = UIFont.systemFont(ofSize: 17.0)
        stock.text = Self.lines.replacingOccurrences(of: "\n", with: "\u{2028}")
        _ = stock.becomeFirstResponder()
        stock.selectedRange = NSRange(location: 30, length: 0)
        FuzzKeyMove.perform("_moveUp:withHistory:", on: stock, extending: true)
        let start = try XCTUnwrap(stock.selectedTextRange).start
        return (stock.selectedRange, self.forwardLineBoundary(stock, from: start))
    }

    /// Oracle: stock answers the U+2028 before the anchor.
    func testStockAnswersTheSeparatorBeforeALineStartReachedByShiftUp() throws {
        let stock = try self.stockAnswer()
        XCTAssertEqual(stock.selection, NSRange(location: 16, length: 14))
        XCTAssertEqual(stock.boundary, 15)
    }

    /// The engine agrees with stock, and the fuzz's invariant (which forgives exactly this) holds.
    func testTheEngineAgreesWithStockInAPullQuote() throws {
        let stock = try self.stockAnswer()
        let arranged = try HarnessP16.arrange([.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: Self.lines)], author: [ChatInputRun(text: "Au")]))])
        defer { HarnessP16.finish(arranged) }
        HarnessP16.select(arranged, 30, 30)
        FuzzKeyMove.perform("_moveUp:withHistory:", on: arranged.input, extending: true)
        HarnessEngine.settle(arranged.root, seconds: 0.1)
        let selection = try XCTUnwrap(arranged.input.selectedTextRange)
        XCTAssertEqual(arranged.input.offset(from: arranged.input.beginningOfDocument, to: selection.start), stock.selection.location)
        XCTAssertEqual(self.forwardLineBoundary(arranged.input, from: selection.start), stock.boundary)
        XCTAssertNil(FuzzTextInputConsistency.violation(of: arranged.input))
    }
}
