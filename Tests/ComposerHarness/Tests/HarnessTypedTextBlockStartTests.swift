import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, the first character typed into an EMPTY block took the
/// marks of the block ABOVE it through the separator: a space typed into a pull quote's empty author
/// line, after a body ending in inline code, came out as inline code (model `[m]` in the author) and
/// drawn in the author's face over a grey pill, which the engine's verifier reports as drift:
///
///     [p "Intro"] [pull "plain " [m]"code"] → caret in the author line → type "x"
///       engine: author [m]"x" (base font monospaced, grey background); drift IDInlineTextBaseFont, NSFont
///     control: the same line typed after a plain body — no drift, no monospace
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 15; reduced by replay.
///
/// **Cause.** The typed-text policy (`attributesForTypedText`, `+TypedText.swift`) tells a block's
/// start by the caret, but the engine applies it AFTER the insert, when the caret is already past the
/// run — so a block's first character read as mid-block and the separator's attributes (the block
/// above's last character) were carried. Fixed upstream: `id_applyTypedTextPolicyForInsertionAt:`
/// hands over no `preceding` when the run starts after a block separator.
///
/// **Tier 1**: `insertText` on the engine view is what the keyboard calls.
@available(iOS 18.4, *)
final class HarnessTypedTextBlockStartTests: XCTestCase {
    private func typeIntoAuthor(body: [ChatInputRun]) throws -> (author: [ChatInputRun], drift: [String]) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        let start = ChatInputContent(blocks: [HarnessEngine.paragraph("Intro"), .pullQuote(ChatInputPullQuote(runs: body))])
        let authorLine = 5 + 1 + body.reduce(0) { $0 + ($1.text as NSString).length } + 1
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(authorLine, authorLine), .insert("x")])
        var author: [ChatInputRun] = []
        for block in driver.model().blocks {
            if case let .pullQuote(quote) = block {
                author = quote.author
            }
        }
        return (author, driver.engineVerifierViolations())
    }

    func testTheFirstCharacterOfAnAuthorLineDoesNotContinueTheBodysInlineCode() throws {
        var mono = ChatInputInlineAttributes()
        mono.monospace = true
        let result = try self.typeIntoAuthor(body: [ChatInputRun(text: "plain "), ChatInputRun(text: "code", attributes: mono)])
        XCTAssertEqual(result.author.map(\.text).joined(), "x", "precondition: the character did not land in the author line")
        XCTAssertFalse(result.author.contains { $0.attributes.monospace }, "the author line continued the body's inline code")
        XCTAssertEqual(result.drift, [], "the author line's presentation is not derived from its role")
    }

    /// Control: after a plain body.
    func testControlAfterAPlainBody() throws {
        let result = try self.typeIntoAuthor(body: [ChatInputRun(text: "plain body")])
        XCTAssertEqual(result.author.map(\.text).joined(), "x")
        XCTAssertEqual(result.drift, [])
    }
}
