import XCTest
import UIKit
import TelegramCore
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, italic code text moved into a code block's LANGUAGE line (a
/// local drag-and-drop move) left the language line drawn in an italic face its model cannot carry — the
/// language is a plain string — so the presentation drifted from what the role renders (the engine's
/// verifier traps on it in a debug build):
///
///     [code lang=- [i]"\nabcd"+"efgh"], select the line break and "d" (2..<5), move it to 0
///       → the language line reads "abc" in italic; the model's language is plain "abc"
///     the same move of PLAIN code text → no drift (the control)
///
/// **How it was seen.** The p18 fix-wave fuzz sweep, seed 53 (default and edited), at the end-of-sequence
/// local-move round trip. It surfaced only once typing over a just-italicised selection kept the italic
/// (`HarnessTypingOverFormattedSelectionTests`), which is what put italic text in that code block.
///
/// **Cause.** `normalisePresentation` re-derives a touched block's presentation keys from its role, and
/// leaves the engine's inline TRAIT markers alone because they are user state — but on a language line
/// there is no user state to keep: the marker that arrived with the moved text made the engine's trait
/// pass derive the italic face again after the font was corrected.
///
/// **Tier 1.** `performLocalMove`, the drop's own move, on the panel's editor.
@available(iOS 18.4, *)
final class HarnessCodeLanguageMoveFormattingTests: XCTestCase {
    private func moveIntoLanguageLine(_ runs: [ChatInputRun]) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [.code(ChatInputCode(runs: runs))]))
        driver.settle(0.2)
        driver.setViewSelection(NSRange(location: 2, length: 3))
        driver.settle(0.2)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext(), "precondition: no drag context")
        XCTAssertTrue(driver.editor.performLocalMove(context, toFlatOffset: 0), "precondition: the move was refused")
        driver.settle(0.3)
        return driver.engineVerifierViolations()
    }

    func testItalicCodeTextMovedIntoTheLanguageLineTakesItsPlainFace() throws {
        let violations = try self.moveIntoLanguageLine([ChatInputRun(text: "\nabcd", attributes: ChatInputInlineAttributes(italic: true)), ChatInputRun(text: "efgh")])
        XCTAssertEqual(violations, [])
    }

    func testBoldCodeTextMovedIntoTheLanguageLineTakesItsPlainFace() throws {
        let violations = try self.moveIntoLanguageLine([ChatInputRun(text: "\nabcd", attributes: ChatInputInlineAttributes(bold: true)), ChatInputRun(text: "efgh")])
        XCTAssertEqual(violations, [])
    }

    /// Control: plain code text moved the same way.
    func testControlPlainCodeTextMovedIntoTheLanguageLine() throws {
        let violations = try self.moveIntoLanguageLine([ChatInputRun(text: "\nabcd"), ChatInputRun(text: "efgh")])
        XCTAssertEqual(violations, [])
    }
}
