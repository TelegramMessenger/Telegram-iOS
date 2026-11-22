import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, with a DETAILS block in the composer, the node's
/// `selectedRange` (the composer's flat axis, which the panel reads and writes to insert at the caret)
/// counts the details' title and body, while the model (`ChatInputContent.length` / `plainText`) keeps
/// details off the flat axis. Every position after a details block is therefore wrong in both
/// directions:
///
///     [p "Details:"] [details title "Summary" [p "Hidden body."]] [p "After."]
///       model plainText "Details:\nAfter." (length 15)
///       caret at the end of "After."  (engine 36) → node selectedRange 28, past the model's end
///       caret in the title             (engine 12) → 28, past the end
///       caret in the body              (engine 20) → 12, i.e. inside "After."
///       node selectedRange = 15 (the model's end) → caret lands at engine 23, inside the details body
///     control: a caret in "Details:" (before the block) → 4, correct
///
/// The chat's copy of the input state carries the out-of-range selection too (`selectionRange`
/// 15..<15 is clamped there, but the node answers 28). Anything the panel inserts "at the caret" (an
/// emoji, a mention, a picked sticker's text) after a details block lands in the wrong place.
///
/// **Reachability.** The composer cannot create a details block. One arrives only when an existing
/// rich message is loaded for editing, or from a draft, so the send/edit round trip itself is out of
/// the harness's scope. The axis mismatch is the composer's own.
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix (a details starting
/// document), 2026-09-23, seeds 8, 14, 20, 21, 23 ("the node's selection {21, 0} is outside the model
/// (length 8)"); reduced by probe.
///
/// **Suspected cause.** `RichTextEngineEditorView.composerSelectedRange` (getter and setter) maps
/// engine positions to a flat axis that includes details text, so it disagrees with the model's
/// `blockFlatLength` rule, which gives details, media and tables no characters.
///
/// **Tier 1**: the node's `selectedRange` is the panel's API.
///
/// **Changed 2026-09-24 (twelfth wave), on the controller's decision:** the body case asserted that
/// the caret must not read anywhere in 10...15, which also forbade 15 — the end of the flat text,
/// which is the pre-existing, deliberate answer for ANY caret inside an off-axis block (host suite:
/// `EngineComposerAxisTests`, `EngineMediaRoundTripTests`). It now asserts exactly that answer (15)
/// and still rejects the 12 the pre-fix code reported.
@available(iOS 18.4, *)
final class HarnessDetailsSelectionAxisTests: XCTestCase {
    private static let start = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Details:"),
        .details(ChatInputDetails(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Hidden body.")]), title: [ChatInputRun(text: "Summary")], expanded: true)),
        HarnessEngine.paragraph("After."),
    ])

    private func withCaret(at caret: Int, _ body: (EngineFuzzDriver) -> Void) throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: [.select(caret, caret)])
        XCTAssertEqual(driver.model().plainText, "Details:\nAfter.", "precondition: the model's flat text")
        body(driver)
    }

    func testACaretAtTheEndAfterDetailsIsTheModelsEnd() throws {
        try self.withCaret(at: 36) { driver in
            XCTAssertEqual(driver.node.selectedRange, NSRange(location: 15, length: 0))
        }
    }

    func testACaretInTheDetailsTitleIsInsideTheModel() throws {
        try self.withCaret(at: 12) { driver in
            XCTAssertLessThanOrEqual(NSMaxRange(driver.node.selectedRange), driver.model().length)
        }
    }

    /// A caret inside the details BODY is off the composer axis, and an off-axis caret reads as the
    /// END of the flat text — the documented rule, pinned by the host suite's
    /// `EngineComposerAxisTests.test_aCaretInsideACellReadsAsTheEndOfTheFlatTextAndTheEchoLeavesItAlone`
    /// and `EngineMediaRoundTripTests.test_theWholeUnitIsOffTheComposerAxis` ("as legacy answers").
    /// Before the fix the body was counted and the caret read 12, a place inside "After.".
    func testACaretInTheDetailsBodyReadsAsTheEndOfTheFlatText() throws {
        try self.withCaret(at: 20) { driver in
            XCTAssertEqual(driver.node.selectedRange, NSRange(location: 15, length: 0),
                           "a caret in the details body must read as the model's end (off-axis rule), not a place in \"After.\"")
        }
    }

    func testSettingTheModelsEndPutsTheCaretAtTheEnd() throws {
        try self.withCaret(at: 4) { driver in
            driver.node.selectedRange = NSRange(location: 15, length: 0)
            driver.settle(0.2)
            XCTAssertEqual(driver.viewSelection(), NSRange(location: 36, length: 0))
        }
    }

    /// Control: a caret before the details block.
    func testControlACaretBeforeTheDetails() throws {
        try self.withCaret(at: 4) { driver in
            XCTAssertEqual(driver.node.selectedRange, NSRange(location: 4, length: 0))
        }
    }
}
