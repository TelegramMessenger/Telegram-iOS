import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a quote's AUTHOR line loses every inline entity on a mere
/// set → get — the composer opening an edited message is enough, no keystroke. A mention, a link or a
/// date in a pull quote's or a block quote's author becomes plain text, and a CUSTOM EMOJI there
/// becomes a bare `U+FFFC` with no entity, which then reaches the model (and the wire) as an object
/// replacement character.
///
///     [p "x"] [pull "pq" author=[@777]"Au"]          → author "Au" (no mention)
///     [quote [p "q"] author="A "+[emoji]"😀"] [p "x"] → author "A \u{FFFC}" (no emoji entity)
///     controls: a media CAPTION and a details TITLE (the other two secondary lines) keep a mention,
///     a custom emoji and a formula; a plain author round-trips
///
/// The editor's own model (`PullQuote.author`, `BlockQuote.author`: `[TextRun]`) and the chat currency
/// (`ChatInputPullQuote.author`, `ChatInputBlockQuote.author`: `[ChatInputRun]`) both carry runs; only
/// the author's bold/italic is documented as render-only. Whether an author may carry entities at all
/// is a product question — the `U+FFFC` leak is not.
///
/// **How it was seen.** p13 probe, 2026-09-24: arranging a pull quote whose author held a mention; the
/// model read back differed from the one set.
///
/// **Suspected cause.** `EngineBlockRole.merging(_:)` (`EngineBlockRole.swift`, the
/// `.blockQuoteAuthor` / `.pullQuoteAuthor` arms) rebuilds the author as
/// `[TextRun(text: secondary.flatText)]` — the line's flat STRING — to drop the render-only emphasis,
/// which also drops every run attribute and keeps an attachment's `U+FFFC` as text. The caption and
/// title arms keep their runs.
///
/// **Tier 1**: `setInputContent` → `currentInputContent`, the composer's own round trip.
@available(iOS 18.4, *)
final class HarnessAuthorLineEntityTests: XCTestCase {
    typealias E = HarnessEdited

    private func roundTrip(_ content: ChatInputContent) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        E.installFormulaRenderer(on: driver.host)
        HarnessComposerFuzzTests.perform(driver, start: content, ops: [])
        return driver.model()
    }

    private func author(_ content: ChatInputContent) -> [ChatInputRun] {
        for block in content.blocks {
            switch block {
            case let .pullQuote(quote): return FuzzModel.merged(quote.author)
            case let .blockQuote(quote): return FuzzModel.merged(quote.author)
            default: continue
            }
        }
        return []
    }

    func testAMentionInAPullQuoteAuthorSurvivesTheRoundTrip() throws {
        let set = ChatInputContent(blocks: [E.paragraph([E.run("x")]), .pullQuote(ChatInputPullQuote(runs: [E.run("pq")], author: [E.mention("Au")]))])
        let got = try self.roundTrip(set)
        XCTAssertEqual(self.author(got), [E.mention("Au")], "the author's mention was dropped: \(E.describe(got))")
    }

    func testACustomEmojiInABlockQuoteAuthorIsNotABareObjectReplacementCharacter() throws {
        let set = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("q")])]), collapsed: false, author: [E.run("A "), E.emoji()])), E.paragraph([E.run("x")])])
        let got = try self.roundTrip(set)
        let bare = self.author(got).contains { $0.text.contains("\u{FFFC}") && $0.attributes.entity == nil && $0.attributes.formula == nil }
        XCTAssertFalse(bare, "the author holds a U+FFFC with no entity: \(E.describe(got))")
        XCTAssertEqual(FuzzModel.normalized(got), FuzzModel.normalized(set), "the author's custom emoji was dropped: \(E.describe(got))")
    }

    /// Control: the other two secondary lines keep their runs.
    func testControlACaptionAndADetailsTitleKeepTheirEntities() throws {
        let set = ChatInputContent(blocks: [
            E.paragraph([E.run("c")]),
            .media(ChatInputMedia(media: E.image(4), kind: .image, naturalSize: ChatInputSize(width: 40, height: 30), caption: [E.mention("Bob"), E.run(" "), E.emoji(), E.run(" "), E.formula("x")])),
            .details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("b")])]), title: [E.mention("M"), E.run(" "), E.emoji()], expanded: true)),
        ])
        let got = try self.roundTrip(set)
        XCTAssertEqual(FuzzModel.normalized(got), FuzzModel.normalized(set), E.describe(got))
    }

    /// Control: a plain author round-trips.
    func testControlAPlainAuthorSurvivesTheRoundTrip() throws {
        let set = ChatInputContent(blocks: [E.paragraph([E.run("x")]), .pullQuote(ChatInputPullQuote(runs: [E.run("pq")], author: [E.run("Au")]))])
        XCTAssertEqual(FuzzModel.normalized(try self.roundTrip(set)), FuzzModel.normalized(set))
    }
}
