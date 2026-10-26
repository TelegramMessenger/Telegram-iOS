import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, an Undo or Redo of a one-character edit REBUILDS every block
/// from the edit up to a paragraph holding a custom emoji, an inline formula or an inline button — even
/// when that paragraph was never touched. The replayed snapshot is applied through the `document`
/// setter, which keeps the blocks outside the differing span and replaces the rest; its span test
/// compares each block's rendered attributed text with `isEqual`, and a block whose text holds one of
/// these attachments is never equal to a fresh render of itself (each render mints a new attachment
/// object). So the span always reaches the atom's paragraph:
///
///     [p "Top"] [p "a " 😀 " b"] [p "End"], type "q" in Top, ⌘Z → the emoji paragraph gets a NEW
///     engine block (identity), its emoji view rebuilt; the same on ⌘⇧Z
///     200 paragraphs, then one emoji paragraph: every undo of an edit at the top replaces all 201
///
/// Measured on the hosted runner: undo of one typed character next to a 200-emoji paragraph 0.10-0.25 s,
/// redo up to 0.8 s, where a plain paragraph of the same length costs ~0.03 s. The same span rule serves
/// every host command that rebuilds through the setter.
///
/// Controls (identity kept): plain text, a mention, a date, a URL, a spoiler, inline code, a button
/// row, a media block, a pull quote, a code block with a language, a details block, a checklist item and
/// a heading.
///
/// **How it was seen.** p15 (2026-09-24), performance at scale: undo/redo latency of a single keystroke
/// in large documents did not track the document's size for custom emoji (a 200-emoji paragraph cost more
/// than 500 list items), so the engine's block identities were read before and after each replay.
///
/// **Suspected cause.** The span scan in `RichTextEngineEditorView.document`'s setter
/// (`attributedBlocks[first].isEqual(to: engineBlocks[first])`, both directions): `EmojiTextAttachment`,
/// `FormulaTextAttachment` and the inline-button attachment compare by object identity, so NSAttributedString
/// equality fails for the same model. Comparing the block's MODEL (role and model block) instead, or giving
/// those attachments value equality, keeps the span to what changed.
///
/// **Tier 1**: the undo manager is the one ⌘Z reaches; identities are the engine's own
/// (`tgid_blockIdentifiers`).
@available(iOS 18.4, *)
final class HarnessAtomParagraphReplayIdentityTests: XCTestCase {
    typealias E = HarnessEdited

    private func identities(_ driver: EngineFuzzDriver) -> [String] {
        return driver.editor.engine.tgid_blockIdentifiers.map { "\($0)" }
    }

    /// Types "q" at offset 2 (in the first block), then undoes and redoes; returns how many engine blocks
    /// each replay replaced.
    private func replacedByReplay(_ blocks: [ChatInputBlock]) throws -> (undo: Int, redo: Int, total: Int) {
        let driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: driver.host)
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
            driver.host.panel.formulaRenderer = nil
        }
        driver.arrange(ChatInputContent(blocks: blocks))
        driver.setViewSelection(NSRange(location: 2, length: 0))
        driver.settle(0.05)
        driver.insert("q")
        driver.settle(0.1)
        let typed = self.identities(driver)
        driver.undoManager?.undo()
        driver.settle(0.1)
        let undone = self.identities(driver)
        XCTAssertEqual(driver.model().blocks.first.map { ChatInputContent(blocks: [$0]).plainText }, "Top", "precondition: the undo did not remove the typed character")
        driver.undoManager?.redo()
        driver.settle(0.1)
        let redone = self.identities(driver)
        return (typed.count - Set(typed).intersection(undone).count, undone.count - Set(undone).intersection(redone).count, typed.count)
    }

    private func assertUntouchedBlockSurvives(_ middle: ChatInputBlock, _ label: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try self.replacedByReplay([HarnessEngine.paragraph("Top"), middle, HarnessEngine.paragraph("End")])
        XCTAssertEqual(result.undo, 0, "undo of an edit in the first paragraph replaced \(result.undo) of \(result.total) engine blocks (\(label) paragraph untouched)", file: file, line: line)
        XCTAssertEqual(result.redo, 0, "redo of an edit in the first paragraph replaced \(result.redo) of \(result.total) engine blocks (\(label) paragraph untouched)", file: file, line: line)
    }

    func testReplayKeepsAnUntouchedCustomEmojiParagraph() throws {
        try self.assertUntouchedBlockSurvives(E.paragraph([E.run("a "), E.emoji(), E.run(" b")]), "custom emoji")
    }

    func testReplayKeepsAnUntouchedFormulaParagraph() throws {
        try self.assertUntouchedBlockSurvives(E.paragraph([E.run("a "), E.formula("x^2"), E.run(" b")]), "formula")
    }

    func testReplayKeepsAnUntouchedInlineButtonParagraph() throws {
        try self.assertUntouchedBlockSurvives(E.paragraph([E.run("a "), E.pill("Go"), E.run(" b")]), "inline button")
    }

    /// The reach: an emoji at the END of a long document makes every replay of an edit at its top
    /// replace the whole document.
    func testReplayOfAnEditAtTheTopDoesNotReplaceTheWholeDocument() throws {
        var blocks: [ChatInputBlock] = [HarnessEngine.paragraph("Top")]
        blocks += (0 ..< 60).map { HarnessEngine.paragraph("paragraph \($0)") }
        blocks.append(E.paragraph([E.run("last "), E.emoji()]))
        let result = try self.replacedByReplay(blocks)
        XCTAssertEqual(result.undo, 0, "undo of one character at the top replaced \(result.undo) of \(result.total) engine blocks")
    }

    func testControlReplayKeepsUntouchedParagraphsWithoutAtoms() throws {
        var spoiler = ChatInputInlineAttributes()
        spoiler.spoiler = true
        var code = ChatInputInlineAttributes()
        code.monospace = true
        let middles: [(String, ChatInputBlock)] = [
            ("plain", E.paragraph([E.run("a b")])),
            ("mention", E.paragraph([E.run("a "), E.mention("Al"), E.run(" b")])),
            ("date", E.paragraph([E.run("a "), E.date("noon"), E.run(" b")])),
            ("url", E.paragraph([E.run("a "), E.url("site"), E.run(" b")])),
            ("spoiler", E.paragraph([E.run("a "), ChatInputRun(text: "hid", attributes: spoiler), E.run(" b")])),
            ("inline code", E.paragraph([E.run("a "), ChatInputRun(text: "x", attributes: code), E.run(" b")])),
            ("button row", E.buttonRow(["One", "Two"])),
            ("media", E.media(5, caption: "cap")),
            ("code", .code(ChatInputCode(language: "swift", runs: [E.run("let x = 1")]))),
        ]
        for (label, middle) in middles {
            try self.assertUntouchedBlockSurvives(middle, label)
        }
    }
}
