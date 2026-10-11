import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** In a paragraph that BEGINS with a right-to-left mark (`U+200F`, which makes its base
/// direction RTL) and then holds left-to-right text, every selection that starts at the paragraph's start
/// and ends before its end has no geometry: one rect at `(inf, inf, 0, 0)`, no logical start or end,
/// `firstRect` at infinity. `[p "\u{200F}Ft abc"]`, select 0..<3 (or 0..<1 … 0..<6) → nothing drawn; 0..<7
/// (the whole paragraph) is drawn. A stock `UITextView` holding the same text draws all of them (oracle,
/// in the test). Controls: a paragraph whose first strong character is Hebrew ("שלום abc def"), and the
/// same Latin text without the mark, draw every range.
///
/// **How it was seen.** p19 roam, 2026-09-25: the fuzz's new selection-geometry invariant, default seed 9
/// at step 40 (a paragraph the fuzz had started with its bidi-mark insertion), reduced by scanning every
/// range.
///
/// **Suspected cause.** The per-line selection-fill rule decides RTL from the LINE and flips the covered
/// side (RichTextEditor `CLAUDE.md`, "Block selection rectangles": "the sides are LOGICAL and the
/// direction is the LINE's"); for a line whose base direction is RTL while every glyph is LTR the fill
/// comes out zero-width or inverted, is reported as "failed to measure", and the coordinator discards the
/// whole answer. Narrow in practice (a paragraph must start with the mark), but the whole selection vanishes.
///
/// **Tier 1**: the public `UITextInput` geometry calls on the engine view and a stock text view.
@available(iOS 18.4, *)
final class HarnessBidiMarkSelectionGeometryTests: XCTestCase {
    private typealias E = HarnessEdited

    private func problems(_ text: String, _ lower: Int, _ upper: Int) throws -> (engine: [String], stock: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, ChatInputContent(blocks: [E.paragraph([E.run(text)]), E.paragraph([E.run("x")])]))
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        return (HarnessSelectionGeometry.problems(input, lower, upper), HarnessSelectionGeometry.stockProblems(driver.root, text, lower, upper))
    }

    func testAPartialSelectionFromTheStartOfAMarkLedParagraphHasGeometry() throws {
        let result = try self.problems("\u{200F}Ft abc", 0, 3)
        XCTAssertEqual(result.stock, [], "precondition: a stock text view draws it")
        XCTAssertEqual(result.engine, [], "the selection has no geometry")
    }

    func testSelectingJustTheMarkHasGeometry() throws {
        let result = try self.problems("\u{200F}Ft abc", 0, 1)
        XCTAssertEqual(result.stock, [], "precondition: a stock text view draws it")
        XCTAssertEqual(result.engine, [], "the selection has no geometry")
    }

    // Controls.

    func testControlTheWholeMarkLedParagraphHasGeometry() throws {
        XCTAssertEqual(try self.problems("\u{200F}Ft abc", 0, 7).engine, [])
    }

    func testControlAHebrewLedParagraphHasGeometry() throws {
        XCTAssertEqual(try self.problems("\u{05E9}\u{05DC}\u{05D5}\u{05DD} abc def", 0, 3).engine, [])
    }

    func testControlTheSameTextWithoutTheMarkHasGeometry() throws {
        XCTAssertEqual(try self.problems("Ft abc", 0, 2).engine, [])
    }
}
