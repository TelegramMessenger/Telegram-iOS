import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, the composer's flat axis — the node's `selectedRange`,
/// which the panel hands the chat as `inputTextState.selectionRange` — counts an inline FORMULA and a
/// CUSTOM EMOJI as ONE character, while the model it indexes (`ChatInputContent.plainText` /
/// `length`) counts the formula's LaTeX source and the emoji's alt text. Every offset after one is
/// short by the difference:
///
///     [p "x " [formula a^2] " y"]        caret at the end → selectedRange 5, model length 7
///     [p "E " [emoji 👍🏽] " z"]           caret at the end → 5, model length 8
///     [p "Top"] [p [formula E=mc^2]] [p "End"]  setting the model's offset 11 (start of "End")
///                                        puts the caret at the END of "End"
///
/// So the chat's own edits at the selection land in the wrong place. A mention / hashtag / emoji
/// suggestion commits through `ChatTextInputState.replacingFlatRange(selection, …)`; after the custom
/// emoji above that splits the emoji's surrogate pair (`"E 👍\u{FFFD}@\u{FFFD} z"`), and the query the
/// chat reads before the caret never contains what was just typed, so no suggestions appear. The
/// documented invariant (`docs/richtext-composer.md` §2: "Custom emoji occupies its alt-string's
/// UTF-16 length in the composer flat space … else the caret drifts past custom emoji") is broken.
///
/// **How it was seen.** p13 probe, 2026-09-24: arranging edited-message content and walking the
/// caret; `inputTextState.selectionRange` read 5 against a model length of 7 / 8.
///
/// **Suspected cause.** `RichTextEngineEditorView+Selection.swift` `composerAxisSegments()` measures
/// each on-axis block by its ENGINE length (`engine.attributedBlocks[i].length`), where a formula /
/// custom emoji is one `U+FFFC`; the bridge's model run (`DocumentChatInputContentBridge.chatInputRun`)
/// holds the LaTeX / alt text instead. The segment arithmetic needs the model's per-run length.
///
/// **Controls:** a mention (plain text under an entity) and an inline button (a `U+FFFC` in BOTH
/// axes) read the model's length.
///
/// **Tier 1**: the node's selection and the panel's input state are what the chat reads.
@available(iOS 18.4, *)
final class HarnessAtomComposerAxisTests: XCTestCase {
    typealias E = HarnessEdited

    private func caretAtEnd(_ content: ChatInputContent) throws -> (driver: EngineFuzzDriver, selection: NSRange, length: Int) {
        let driver = try EngineFuzzDriver()
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: content, ops: [])
        let end = (driver.viewText() as NSString).length
        driver.setViewSelection(NSRange(location: end, length: 0))
        driver.settle(0.2)
        return (driver, driver.node.selectedRange, driver.model().length)
    }

    func testTheCaretAfterAnInlineFormulaReadsTheModelsOffset() throws {
        let result = try self.caretAtEnd(ChatInputContent(blocks: [E.paragraph([E.run("x "), E.formula("a^2"), E.run(" y")])]))
        defer { _ = result.driver.node.resignInputFirstResponder() }
        XCTAssertEqual(result.selection, NSRange(location: result.length, length: 0),
                       "the caret at the end reads \(result.selection) on the composer axis; the model is \(result.length) long")
    }

    func testTheCaretAfterACustomEmojiReadsTheModelsOffset() throws {
        let result = try self.caretAtEnd(ChatInputContent(blocks: [E.paragraph([E.run("E "), E.emoji("👍🏽"), E.run(" z")])]))
        defer { _ = result.driver.node.resignInputFirstResponder() }
        XCTAssertEqual(result.selection, NSRange(location: result.length, length: 0),
                       "the caret at the end reads \(result.selection) on the composer axis; the model is \(result.length) long")
    }

    /// The chat's own edit at the selection — the shape a mention / emoji suggestion commits.
    func testTheChatsReplaceAtTheSelectionAfterACustomEmojiLandsAtTheCaret() throws {
        let result = try self.caretAtEnd(ChatInputContent(blocks: [E.paragraph([E.run("E "), E.emoji("👍🏽"), E.run(" z")])]))
        defer { _ = result.driver.node.resignInputFirstResponder() }
        let state = result.driver.host.panel.inputTextState
        let replaced = state.replacingFlatRange(NSRange(location: state.selectionRange.lowerBound, length: 0), with: "@")
        XCTAssertEqual(replaced.content.plainText, "E 👍🏽 z@",
                       "the chat's replace at the selection landed at \(state.selectionRange): \(fuzzEscaped(replaced.content.plainText))")
    }

    /// The other direction: the chat sets a caret on the model's axis.
    func testSettingTheModelsOffsetAfterABlockFormulaPutsTheCaretThere() throws {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: ChatInputContent(blocks: [E.paragraph([E.run("Top")]), E.paragraph([E.formula("E=mc^2")]), E.paragraph([E.run("End")])]), ops: [])
        let model = driver.model().plainText as NSString
        let offset = model.range(of: "End").location   // 11
        driver.node.selectedRange = NSRange(location: offset, length: 0)
        driver.settle(0.2)
        driver.insert("Q")
        driver.settle(0.2)
        XCTAssertEqual(E.describe(driver.model()), "[p body \"Top\"] [p body [f=\"E=mc^2\"]\"E=mc^2\"] [p body \"QEnd\"]",
                       "a caret set at the model's offset \(offset) typed elsewhere")
    }

    /// Control: a mention is plain text under an entity — the same length on both axes.
    func testControlTheCaretAfterAMentionReadsTheModelsOffset() throws {
        let result = try self.caretAtEnd(ChatInputContent(blocks: [E.paragraph([E.run("Hi "), E.mention("Alice"), E.run(" there")])]))
        defer { _ = result.driver.node.resignInputFirstResponder() }
        XCTAssertEqual(result.selection, NSRange(location: result.length, length: 0))
    }

    /// Control: an inline button is a `U+FFFC` on BOTH axes.
    func testControlTheCaretAfterAnInlineButtonReadsTheModelsOffset() throws {
        let result = try self.caretAtEnd(ChatInputContent(blocks: [E.paragraph([E.run("Tap "), E.pill("Go"), E.run(" now")])]))
        defer { _ = result.driver.node.resignInputFirstResponder() }
        XCTAssertEqual(result.selection, NSRange(location: result.length, length: 0))
    }
}
