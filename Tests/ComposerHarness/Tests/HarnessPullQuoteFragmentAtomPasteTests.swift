import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** Text copied from INSIDE a pull quote and pasted inside a
/// pull quote (the same one or another) loses its custom emoji: the model gets a bare `U+FFFC` with no
/// entity, which is what the message then sends.
///
///     [pull "pq " 😀 " x"] [p "end"], copy the pull quote's text (0..<6), paste after "pq"
///       engine:   [pull "pqpq \u{FFFC} x" + 😀 + " x"]           (the pasted emoji is U+FFFC, plain)
///       expected: [pull "pqpq " + 😀 + " x" + " " + 😀 + " x"]
///     the fuzz's self-paste into a pull quote the same (seed 83 of the p16 edited-content sweep
///     carried two bare U+FFFC by its end)
///
/// Controls: the same emoji copied from a PARAGRAPH and pasted into the pull quote keeps its entity;
/// the pull quote's own emoji is untouched.
///
/// **How it was seen.** p16 roam, 2026-09-25: reducing edited-content fuzz seed 83, whose model held
/// `\u{FFFC}` runs without an entity inside a pull quote; hosted probes.
///
/// **Suspected cause.** Core's pull-quote arm of `replacingRangeInsideOneContainer`
/// (`DocumentFragment.swift`, p8 fix) splices "paragraph runs with their formatting, other blocks as
/// plain lines". A copy made inside a pull quote is a PULL-QUOTE fragment, so it takes the plain-lines
/// branch, and an atom's plain text is its attachment character. The pull quote's own runs should be
/// spliced like a paragraph's.
///
/// **Tier 1**: Copy and Paste are the edit-menu actions on the engine view.
@available(iOS 18.4, *)
final class HarnessPullQuoteFragmentAtomPasteTests: XCTestCase {
    private func pasted(_ start: ChatInputContent, copy: (Int, Int), at caret: Int) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(copy.0, copy.1), .copy, .select(caret, caret), .paste])
        return driver.model()
    }

    /// Every run that carries a bare attachment character with no entity (the corruption), anywhere.
    private func bareAttachments(_ content: ChatInputContent) -> [String] {
        var result: [String] = []
        func scan(_ runs: [ChatInputRun]) {
            for run in runs where run.text.contains("\u{FFFC}") && run.attributes.entity == nil && run.attributes.formula == nil {
                result.append(fuzzEscaped(run.text))
            }
        }
        for block in content.blocks {
            switch block {
            case let .paragraph(paragraph): scan(paragraph.runs)
            case let .pullQuote(quote): scan(quote.runs); scan(quote.author)
            default: break
            }
        }
        return result
    }

    private func emojiCount(_ content: ChatInputContent) -> Int {
        var count = 0
        for block in content.blocks {
            let runs: [ChatInputRun]
            switch block {
            case let .paragraph(paragraph): runs = paragraph.runs
            case let .pullQuote(quote): runs = quote.runs
            default: runs = []
            }
            count += runs.filter { if case .customEmoji? = $0.attributes.entity { return true }; return false }.count
        }
        return count
    }

    private var pulled: ChatInputContent {
        return ChatInputContent(blocks: [
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pq "), HarnessEdited.emoji(), ChatInputRun(text: " x")], author: [ChatInputRun(text: "Au")])),
            HarnessEngine.paragraph("end"),
        ])
    }

    func testACustomEmojiCopiedInsideAPullQuoteSurvivesAPasteIntoIt() throws {
        let content = try self.pasted(self.pulled, copy: (0, 6), at: 2)
        XCTAssertEqual(self.bareAttachments(content), [], "the pasted custom emoji became a bare U+FFFC in the model: \(FuzzModel.describe(content))")
        XCTAssertEqual(self.emojiCount(content), 2, "the pasted custom emoji was lost: \(FuzzModel.describe(content))")
    }

    func testAPartialCopyWithACustomEmojiInsideAPullQuoteSurvivesAPasteIntoIt() throws {
        let content = try self.pasted(self.pulled, copy: (3, 6), at: 1)
        XCTAssertEqual(self.bareAttachments(content), [], "the pasted custom emoji became a bare U+FFFC in the model: \(FuzzModel.describe(content))")
        XCTAssertEqual(self.emojiCount(content), 2, "the pasted custom emoji was lost: \(FuzzModel.describe(content))")
    }

    /// Control: the emoji copied from a PARAGRAPH and pasted into the pull quote keeps its entity.
    func testControlAnEmojiFromAParagraphPastedIntoAPullQuote() throws {
        let start = ChatInputContent(blocks: [
            HarnessEdited.paragraph([HarnessEdited.run("Mixed "), HarnessEdited.emoji()]),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pq")], author: [ChatInputRun(text: "Au")])),
        ])
        let content = try self.pasted(start, copy: (0, 7), at: 9)
        XCTAssertEqual(self.bareAttachments(content), [], FuzzModel.describe(content))
        XCTAssertEqual(self.emojiCount(content), 2, FuzzModel.describe(content))
    }
}
