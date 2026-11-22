import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, text typed, pasted or composed with the caret at either of
/// a BUTTON ROW's stops (just before or just after its attachment character) goes INTO the row's line.
/// The row's shape ignores its runs, so the model never sees the text — it is lost on send and on
/// every read-back — while the engine shows it; at the LEADING stop the row's hosted view is also no
/// longer drawn (DEBUG builds trap on the derived-view verifier).
///
///     [p "Row:"] [row One|Two] [p "After"]   engine "Row:\n\u{FFFC}\nAfter"
///     caret 6 (after the row), type "x"  → engine "\u{FFFC}x",  model unchanged
///     caret 5 (before the row), type "x" → engine "x\u{FFFC}",  model unchanged, "button row missing"
///     paste "abc" / a Japanese composition at either stop: the same
///     control: a MEDIA atom's stops mint a paragraph (caret 7 in the media document types "Z" into
///     a new paragraph above it)
///
/// **How it was seen.** p13 probe, 2026-09-24, then the fuzz's edited-content sweep.
///
/// **Suspected cause.** `decideTextInput` (`+SurfaceGate.swift`) routes `.standalone(.media)` and
/// `.standalone(.collapsedQuote)` through `decideTextInputAtAnAtomUnit`, and its comment says
/// `.standalone(.buttonRow)` is deliberately left out: "typing into a block whose shape ignores its
/// runs; that was observed while writing this rung and NOT run down, and there is no test either way".
/// This is that test. A button row is an atom unit like the other two (`atomUnitIndex`).
///
/// **Tier 1**: `insertText(_:)`, `paste:` and `setMarkedText` are the keyboard's and edit menu's
/// entry points.
@available(iOS 18.4, *)
final class HarnessButtonRowStopTypingTests: XCTestCase {
    typealias E = HarnessEdited

    private static let row = ChatInputContent(blocks: [E.paragraph([E.run("Row:")]), E.buttonRow(["One", "Two"]), E.paragraph([E.run("After")])])

    private func run(_ ops: [FuzzOp], start: ChatInputContent = HarnessButtonRowStopTypingTests.row) throws -> (model: ChatInputContent, engine: String, violations: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return (driver.model(), driver.viewText(), driver.unfilteredViolations())
    }

    private func assertTyped(_ text: String, _ result: (model: ChatInputContent, engine: String, violations: [String]), file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(result.model.plainText.contains(text), "the typed \(fuzzEscaped(text)) never reached the model: \(E.describe(result.model)); engine \(fuzzEscaped(result.engine))", file: file, line: line)
        XCTAssertTrue(result.engine.components(separatedBy: "\n").contains("\u{FFFC}"), "the row's line holds more than the row: engine \(fuzzEscaped(result.engine))", file: file, line: line)
        XCTAssertEqual(result.violations, [], file: file, line: line)
    }

    func testTypingAfterAButtonRowReachesTheModel() throws {
        self.assertTyped("x", try self.run([.select(6, 6), .insert("x")]))
    }

    func testTypingBeforeAButtonRowReachesTheModelAndKeepsTheRowDrawn() throws {
        self.assertTyped("x", try self.run([.select(5, 5), .insert("x")]))
    }

    func testPastingAfterAButtonRowReachesTheModel() throws {
        self.assertTyped("abc", try self.run([.select(6, 6), .pasteText("abc")]))
    }

    /// The row at the END of the document: after it there is no paragraph to fall into.
    func testTypingAfterATrailingButtonRowReachesTheModel() throws {
        self.assertTyped("x", try self.run([.select(3, 3), .insert("x")], start: ChatInputContent(blocks: [E.paragraph([E.run("a")]), E.buttonRow(["One"])])))
    }

    /// Control: the same keystroke at a MEDIA atom's leading stop mints a paragraph above it.
    func testControlTypingBeforeAMediaAtomMintsAParagraph() throws {
        let result = try self.run([.select(7, 7), .insert("Z")], start: ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])]))
        XCTAssertEqual(E.describe(result.model), "[p body \"Before\"] [p body \"Z\"] [media image x1 cap=\"Cap\"] [p body \"After\"]")
        XCTAssertEqual(result.violations, [])
    }
}
