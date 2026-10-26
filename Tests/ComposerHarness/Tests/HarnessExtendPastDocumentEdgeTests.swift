import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** `UITextInput.characterRange(byExtending:in:)` asked to extend PAST a document edge — left
/// or up from the start, right or down from the end, any direction in an empty composer — raises an
/// uncaught `NSInvalidArgumentException` in the engine ("IDRichTextLayoutController
/// textRangeFromPosition:toPosition: failed: position has a foreign concrete class"). A stock `UITextView`
/// answers an EMPTY range at the edge (measured: `""` → 0..<0 in every direction, `"abc"` 0 ←  → 0..<0,
/// 3 → → 3..<3, 3 ↓ → 3..<3). Anything outside the process that asks this at an edge takes the app down;
/// inside the app every other direction and offset matches stock (controls below).
///
/// **How it was seen.** p19 roam, 2026-09-25: a UITextInput conformance probe over every fuzz starting
/// document; the first call at offset 0 of the empty composer killed the probe.
///
/// **Suspected cause.** The kernel forwards to UIKit's `UITextInputController`
/// (`IDUIKitInputControllerCapability characterRangeByExtendingPosition:inDirection:`), which steps a
/// position past the edge — `nil` — and hands it to the text input's `textRangeFromPosition:toPosition:`.
/// UIKit's own text view answers nil for a nil endpoint; the engine's
/// `-[IDRichTextLayoutController id_positionWithValidIdentity:stage:]` raises for anything that is not an
/// `IDRichTextPosition`, nil included (`IDRichTextLayoutController.m`).
///
/// UIKit's own delete paths at the edges (`_deleteForwardAndNotify:`, `_deleteByWord`,
/// `_deleteToEndOfLine`, `_deleteForwardByWord`, `_transpose`, `_deleteToEndOfParagraph`) were driven
/// on the engine and a stock view and do NOT reach it; the caller that does is the public API itself.
///
/// **Tier 1**: a public `UITextInput` call on the engine view, compared with a stock `UITextView`.
@available(iOS 18.4, *)
final class HarnessExtendPastDocumentEdgeTests: XCTestCase {
    private func engineRange(_ text: String, offset: (Int) -> Int, _ direction: UITextLayoutDirection) throws -> NSRange? {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText(text))
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        let begin = input.beginningOfDocument
        let position = try XCTUnwrap(input.position(from: begin, offset: offset(input.offset(from: begin, to: input.endOfDocument))))
        guard let range = input.characterRange(byExtending: position, in: direction) else { return nil }
        let start = input.offset(from: begin, to: range.start)
        return NSRange(location: start, length: input.offset(from: begin, to: range.end) - start)
    }

    private func stockRange(_ text: String, offset: (Int) -> Int, _ direction: UITextLayoutDirection) -> NSRange? {
        let stock = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0))
        stock.text = text
        let begin = stock.beginningOfDocument
        let position = stock.position(from: begin, offset: offset((text as NSString).length))!
        guard let range = stock.characterRange(byExtending: position, in: direction) else { return nil }
        let start = stock.offset(from: begin, to: range.start)
        return NSRange(location: start, length: stock.offset(from: begin, to: range.end) - start)
    }

    private func assertMatchesStock(_ text: String, offset: @escaping (Int) -> Int, _ direction: UITextLayoutDirection, file: StaticString = #filePath, line: UInt = #line) throws {
        let stock = self.stockRange(text, offset: offset, direction)
        let engine = try self.engineRange(text, offset: offset, direction)
        XCTAssertEqual(engine, stock, "characterRange(byExtending:in: \(direction.rawValue)) in \(fuzzEscaped(text))", file: file, line: line)
    }

    func testExtendingLeftFromTheStartAnswersAnEmptyRange() throws {
        try self.assertMatchesStock("abc", offset: { _ in 0 }, .left)
    }

    func testExtendingRightFromTheEndAnswersAnEmptyRange() throws {
        try self.assertMatchesStock("abc", offset: { $0 }, .right)
    }

    func testExtendingDownFromTheEndAnswersAnEmptyRange() throws {
        try self.assertMatchesStock("abc", offset: { $0 }, .down)
    }

    func testExtendingInAnEmptyComposerAnswersAnEmptyRange() throws {
        try self.assertMatchesStock("", offset: { _ in 0 }, .right)
    }

    // The audit (p19 fix wave): UIKit's `UITextInputController` hands the layout controller an
    // UNCHECKED stepped position in `characterRangeByExtendingPosition:inDirection:` (to
    // `textRangeFromPosition:toPosition:`) and after a keyboard replacement (to
    // `emptyTextRangeAtPosition:`). The native layout controller reads a nil endpoint as the beginning
    // of the document (`from`) or as the other endpoint (`to`); the engine raised for both.

    private func rangeOffsets(_ input: UITextInput, _ range: UITextRange?) -> NSRange? {
        guard let range else { return nil }
        let start = input.offset(from: input.beginningOfDocument, to: range.start)
        return NSRange(location: start, length: input.offset(from: range.start, to: range.end))
    }

    private func nilEndpointRanges(_ input: UIView & UITextInput) -> [NSRange?] {
        let object = input as NSObject
        let selector = NSSelectorFromString("textRangeFromPosition:toPosition:")
        let middle = input.position(from: input.beginningOfDocument, offset: 2)!
        let toNil = object.perform(selector, with: middle, with: nil)?.takeUnretainedValue() as? UITextRange
        let fromNil = object.perform(selector, with: nil, with: middle)?.takeUnretainedValue() as? UITextRange
        return [self.rangeOffsets(input, toNil), self.rangeOffsets(input, fromNil)]
    }

    func testATextRangeWithAMissingEndpointMatchesStock() throws {
        let stock = UITextView(frame: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0))
        stock.text = "abcd"
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText("abcd"))
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        XCTAssertEqual(self.nilEndpointRanges(input), self.nilEndpointRanges(stock))
    }

    // Controls: away from the edges the engine already answers what stock does.

    func testControlExtendingLeftInsideTheText() throws {
        try self.assertMatchesStock("abc", offset: { _ in 1 }, .left)
    }

    func testControlExtendingRightInsideTheText() throws {
        try self.assertMatchesStock("abc", offset: { _ in 1 }, .right)
    }

    func testControlExtendingUpFromTheStart() throws {
        try self.assertMatchesStock("abc", offset: { _ in 0 }, .up)
    }

    func testControlExtendingLeftAcrossAParagraphBreak() throws {
        try self.assertMatchesStock("abc\ndef", offset: { _ in 4 }, .left)
    }
}
