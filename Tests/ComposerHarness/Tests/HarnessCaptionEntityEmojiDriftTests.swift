import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, an EMOJI typed right after a mention or a link inside a media
/// CAPTION is left with presentation drift on `NSColor`: the model (correctly, by the typed-text policy)
/// does not put the emoji in the entity, but the engine keeps drawing it in the entity's colour. The
/// engine's own verifier reports it and, in a DEBUG build, traps at the end of the settle — the same
/// verifier question the fuzz asks after every step.
///
///     [p "x"] [media cap="Two " [mention]"Bo" " z"], caret after "Bo" (10), type 😀
///       model:  cap="Two " [mention]"Bo" "😀 z"
///       engine: presentation drift at the caption block (keys NSColor)
///     a link instead of the mention: the same;  the same with Bold over "o " first: the same
///     controls: a LETTER there (it joins the mention, as typing inside an entity does); the same emoji
///               after a mention in a PARAGRAPH, and in a block quote — no drift
///
/// **How it was seen.** p15 (2026-09-24), edited-content fuzz seed 104: after a push of the album
/// document, an underline over a caption mention's end and an emoji typed inside it failed the engine
/// verifier (`presentation drift at engine block 4 "Two Bo😀 ￼" (keys NSColor)`).
///
/// **Suspected cause.** The caption's role derivation. A character typed after an entity takes the
/// entity's attributes from the typing attributes; for a paragraph the post-edit settle re-derives the
/// presentation of the touched block (`normalisePresentation`, `+Settle.swift`) and the colour comes back
/// to the body's, but a caption is a SECONDARY region of the media unit, and the entity colour for the
/// non-entity emoji survives there — the emoji (unlike a letter, which the policy keeps in the entity)
/// is the one character whose model and engine attributes then disagree.
///
/// **Tier 1**: `insertText` on the engine view; the drift is the engine's own verifier
/// (`presentationDrift(atBlock:)`), asked non-fatally.
@available(iOS 18.4, *)
final class HarnessCaptionEntityEmojiDriftTests: XCTestCase {
    typealias E = HarnessEdited

    private static func media(_ caption: [ChatInputRun]) -> ChatInputBlock {
        return .media(ChatInputMedia(items: [ChatInputMediaItem(media: E.image(1), kind: .image, naturalSize: ChatInputSize(width: 400.0, height: 300.0))], caption: caption))
    }

    /// The engine's verifier findings after `ops` from `content`.
    private func drift(_ content: ChatInputContent, _ ops: [FuzzOp]) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: content, ops: ops)
        return driver.engineVerifierViolations()
    }

    // "x\n\u{FFFC}\nTwo Bo z": the caption is 4..<12, "Bo" 8..<10.

    func testAnEmojiAfterACaptionMentionLeavesNoDrift() throws {
        let found = try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), E.mention("Bo"), E.run(" z")])]), [.select(10, 10), .insert("😀")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testAnEmojiAfterACaptionLinkLeavesNoDrift() throws {
        let found = try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), E.url("Bo"), E.run(" z")])]), [.select(10, 10), .insert("😀")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testAnEmojiInsideABoldRangeAfterACaptionMentionLeavesNoDrift() throws {
        let found = try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), E.mention("Bo"), E.run(" z")])]), [.format(.bold, selecting: (9, 11)), .select(10, 10), .insert("😀")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlALetterAfterACaptionMention() throws {
        let found = try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("x")]), Self.media([E.run("Two "), E.mention("Bo"), E.run(" z")])]), [.select(10, 10), .insert("a")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlAnEmojiAfterAMentionInAParagraph() throws {
        let found = try self.drift(ChatInputContent(blocks: [E.paragraph([E.run("Two "), E.mention("Bo"), E.run(" z")])]), [.select(6, 6), .insert("😀")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }

    func testControlAnEmojiAfterAMentionInABlockQuote() throws {
        let found = try self.drift(ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("Two "), E.mention("Bo"), E.run(" z")])]), collapsed: false))]), [.select(6, 6), .insert("😀")])
        XCTAssertEqual(found, [], found.joined(separator: "\n"))
    }
}
