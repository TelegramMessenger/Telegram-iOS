import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, deleting (Backspace, Cut, or typing over) a selection that runs
/// from a DETAILS block's title into its one-paragraph body leaves a details block with NO body at all:
/// the title absorbs the body's remainder and the body line is gone, in the engine and in the model.
///
///     [p "Details:"] [details title="Summary" [p "Hidden body."]], select "mary⏎Hid", Backspace
///       → [p "Details:"] [details title="Sumden body." ]        (engine: "Details:\nSumden body.")
///
/// That is a structure the composer's own SET never produces: `setInputContent` of a details whose content
/// is empty gives it one empty body paragraph (control below). So the result does not survive a draft
/// round trip — save and restore it (a draft, a cloud sync, any external set) and the details gains an
/// empty body line:
///
///       get → set → get: [details title="Sumden body." ] → [details title="Sumden body." [p ""]]
///
/// **How it was seen.** p15 (2026-09-24), the fuzz's new external-push op (seed 11): a push of the
/// model's own content with its first block replaced came back with an extra empty body paragraph in a
/// details block an earlier cross delete had emptied.
///
/// **Suspected cause.** The surface gate's cross-block rule (`applyReplaceOutcome`) keeps the start
/// block's role — the details' TITLE — merges the end block's remainder into it and drops the body
/// paragraph, and no settle rule restores a details' body the way `settleDetailsWithoutTitle` handles a
/// details that lost its title (`RichTextEngineEditorView+Settle.swift`). The bridge's set path always
/// mints a body, so the two directions disagree.
///
/// Controls: a deletion inside the body, and one from the title into the FIRST of two body paragraphs,
/// keep a body; setting a details with no body gives it one.
///
/// **Tier 1**: the view's `deleteBackward` / `cut:` / `insertText` over a view selection, as the keyboard
/// and the edit menu deliver them; the round trip is the chat's set.
@available(iOS 18.4, *)
final class HarnessDetailsBodyCrossDeleteTests: XCTestCase {
    private static func start(_ bodies: [String] = ["Hidden body."]) -> ChatInputContent {
        return ChatInputContent(blocks: [
            HarnessEngine.paragraph("Details:"),
            .details(ChatInputDetails(content: ChatInputContent(blocks: bodies.map { HarnessEngine.paragraph($0) }), title: [ChatInputRun(text: "Summary")], expanded: true)),
        ])
    }

    private static func details(in content: ChatInputContent) -> ChatInputDetails? {
        for block in content.blocks {
            if case let .details(details) = block {
                return details
            }
        }
        return nil
    }

    /// Runs `ops` from `start`; returns the model, the engine's line count, and the model after a
    /// draft-style round trip (clear, then set the model back).
    private func run(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> (model: ChatInputContent, engineLines: Int, roundTripped: ChatInputContent) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        let model = driver.model()
        let lines = driver.viewText().components(separatedBy: "\n").count
        driver.host.setInputContent(ChatInputContent())
        driver.settle(0.1)
        driver.host.setInputContent(model)
        driver.settle(0.2)
        return (model, lines, driver.model())
    }

    private func assertKeepsABody(_ ops: [FuzzOp], file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.run(Self.start(), ops)
        let details = try XCTUnwrap(Self.details(in: result.model), "precondition: no details block left: \(FuzzModel.describe(result.model))", file: file, line: line)
        XCTAssertFalse(details.content.blocks.isEmpty, "the details block was left with no body: \(FuzzModel.describe(result.model)) (\(result.engineLines) engine lines)", file: file, line: line)
        XCTAssertEqual(FuzzModel.describe(result.roundTripped), FuzzModel.describe(result.model), "a draft round trip (clear, set the model back) changed the document", file: file, line: line)
    }

    // "Details:\nSummary\nHidden body." — the title line is 9..<16, the body 17..<29.

    func testBackspaceFromTheTitleIntoTheBodyKeepsABody() throws {
        try self.assertKeepsABody([.select(12, 20), .deleteBackward])
    }

    func testCutFromTheTitleIntoTheBodyKeepsABody() throws {
        try self.assertKeepsABody([.select(12, 20), .cut])
    }

    func testTypingFromTheTitleIntoTheBodyKeepsABody() throws {
        try self.assertKeepsABody([.select(12, 20), .insert("X")])
    }

    func testBackspaceFromTheTitleStartToTheBodyEndKeepsABody() throws {
        try self.assertKeepsABody([.select(13, 29), .deleteBackward])
    }

    func testControlDeletionInsideTheBodyKeepsIt() throws {
        try self.assertKeepsABody([.select(18, 24), .deleteBackward])
    }

    func testControlFromTheTitleIntoTheFirstOfTwoBodyParagraphsKeepsTheSecond() throws {
        let result = try self.run(Self.start(["Hidden body.", "More."]), [.select(12, 20), .deleteBackward])
        let details = try XCTUnwrap(Self.details(in: result.model))
        XCTAssertFalse(details.content.blocks.isEmpty, FuzzModel.describe(result.model))
        XCTAssertEqual(FuzzModel.describe(result.roundTripped), FuzzModel.describe(result.model))
    }

    /// Control: the set path never makes a body-less details.
    func testControlSettingADetailsWithoutABodyGivesItOne() throws {
        let result = try self.run(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Details:"),
            .details(ChatInputDetails(content: ChatInputContent(blocks: []), title: [ChatInputRun(text: "T")], expanded: true)),
        ]), [])
        let details = try XCTUnwrap(Self.details(in: result.model))
        XCTAssertEqual(details.content.blocks.count, 1, FuzzModel.describe(result.model))
    }
}
