import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, text typed INSIDE an underlined link or mention (or at its
/// end, inside a range that is underlined on both sides) loses the UNDERLINE in the model, although it
/// stays in the link / mention. Every other inline format survives there, and underline survives on
/// plain text:
///
///     [p "Two " [link]"Bo" " z"], Format ▸ Underline over "Bo", caret between B and o, type "a"
///       → [p "Two " [u,link]"B" [link]"a" [u,link]"o" " z"]          the "a" is not underlined
///     mention: the same;  a media caption: the same
///     Format ▸ Underline over "o " (the link's end and the space after), type "a" between them
///       → [link]"B" [u,link]"o" [link]"a" [u]" " "z"]                 a gap in the underline
///     controls: Strikethrough / Italic / Bold instead of Underline → "Bao" all formatted;
///               Underline over plain "Bo" → "Bao" underlined
///
/// What is sent is the model, so the message goes out with a gap in the underline under every character
/// typed into it.
///
/// **How it was seen.** p15 (2026-09-24), reducing edited-content fuzz seed 104 (an underline typed over
/// a mention's end in a caption, then a character typed inside it).
///
/// **Suspected cause.** The typed-text policy that keeps typing from EXTENDING a link's own underline
/// (links are drawn underlined, and that presentation is stripped on read-back) also removes the user's
/// underline trait: the attributes adopted for a character typed into a link drop `NSUnderline` /
/// `IDInlineTextUnderline` whatever set them (`TGIDObservingBlockTextView`'s
/// `tgid_replacementAttributesHandler` and the typing-attribute adoption in
/// `RichTextEngineEditorView+TypedText.swift`), where the engine's other trait markers are carried.
///
/// **Tier 1**: Format ▸ Underline through `performFormatAction`, typing with `insertText` on the engine
/// view.
@available(iOS 18.4, *)
final class HarnessUnderlinedLinkTypingTests: XCTestCase {
    typealias E = HarnessEdited

    /// Formats `range` with `format`, types "a" at `caret`; the normalized model.
    private func typed(_ content: ChatInputContent, format: FuzzFormat, _ range: (Int, Int), caret: Int) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: content, ops: [.format(format, selecting: range), .select(caret, caret), .insert("a")])
        return FuzzModel.normalized(driver.model())
    }

    private static func line(_ middle: ChatInputRun) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("Two "), middle, E.run(" z")])])
    }

    /// The runs of the first paragraph holding "a", with their formats.
    private static func runHolding(_ text: String, in content: ChatInputContent) -> ChatInputRun? {
        guard case let .paragraph(paragraph)? = content.blocks.first else { return nil }
        return paragraph.runs.first { $0.text.contains(text) }
    }

    func testTypingInsideAnUnderlinedLinkKeepsTheUnderline() throws {
        let model = try self.typed(Self.line(E.url("Bo")), format: .underline, (4, 6), caret: 5)
        let run = try XCTUnwrap(Self.runHolding("a", in: model), FuzzModel.describe(model))
        XCTAssertTrue(run.attributes.underline, "the character typed inside an underlined link is not underlined: \(FuzzModel.describe(model))")
    }

    func testTypingInsideAnUnderlinedMentionKeepsTheUnderline() throws {
        let model = try self.typed(Self.line(E.mention("Bo")), format: .underline, (4, 6), caret: 5)
        let run = try XCTUnwrap(Self.runHolding("a", in: model), FuzzModel.describe(model))
        XCTAssertTrue(run.attributes.underline, "the character typed inside an underlined mention is not underlined: \(FuzzModel.describe(model))")
    }

    func testTypingBetweenAnUnderlinedLinkEndAndAnUnderlinedSpaceKeepsTheUnderline() throws {
        let model = try self.typed(Self.line(E.url("Bo")), format: .underline, (5, 7), caret: 6)
        let run = try XCTUnwrap(Self.runHolding("a", in: model), FuzzModel.describe(model))
        XCTAssertTrue(run.attributes.underline, "the character typed inside an underlined range at a link's end is not underlined: \(FuzzModel.describe(model))")
    }

    func testControlOtherFormatsSurviveTypingInsideALink() throws {
        for format in [FuzzFormat.strikethrough, .italic, .bold] {
            let model = try self.typed(Self.line(E.url("Bo")), format: format, (4, 6), caret: 5)
            let run = try XCTUnwrap(Self.runHolding("a", in: model), FuzzModel.describe(model))
            XCTAssertEqual(run.text, "Bao", "\(format): \(FuzzModel.describe(model))")
        }
    }

    func testControlUnderlineSurvivesTypingInsidePlainText() throws {
        let model = try self.typed(Self.line(E.run("Bo")), format: .underline, (4, 6), caret: 5)
        let run = try XCTUnwrap(Self.runHolding("a", in: model), FuzzModel.describe(model))
        XCTAssertTrue(run.attributes.underline, FuzzModel.describe(model))
        XCTAssertEqual(run.text, "Bao", FuzzModel.describe(model))
    }
}
