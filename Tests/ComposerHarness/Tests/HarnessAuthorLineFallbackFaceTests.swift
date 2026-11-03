import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** The engine's presentation verifier reports DRIFT for an emoji, CJK or Arabic
/// character typed into a pull-quote or block-quote AUTHOR line, and so TRAPS any test process that
/// does so. The screen is right: the author line's bold (and the pull quote's italic) is ambient,
/// render-only styling, and the fallback face TextKit substitutes cannot carry it (an emoji is never
/// bold). The verifier forgives exactly this for inline bold/italic, which carry
/// `IDInlineTextBold/Italic` markers (`withCarriedTraitsOnFallbackFaces`), but an author line's traits
/// have no markers, so the comparison fails on the traits.
///
///     [p "Intro"] [pull "pq"] → caret in the author line → type 👍🏽
///       verifier: NSFont want .SFUI-SemiboldItalic 15, have .AppleColorEmojiUI 15
///     CJK: have .PingFangUITextSC-Semibold (bold, not italic); block-quote author + emoji: want
///     .SFUI-Semibold, have .AppleColorEmojiUI
///     control: ASCII "Ab" in the same line — no drift
///
/// A VERIFIER false positive, not a visible defect; filed because it traps every hosted/engine test
/// that types a non-Latin author, and would hide a real drift behind it.
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seeds 22 and 35 of 1-60;
/// reduced by the probe's greedy op reducer.
///
/// **Tier 1**: typing through `insertText` on the engine view; the verifier is asked directly.
@available(iOS 18.4, *)
final class HarnessAuthorLineFallbackFaceTests: XCTestCase {
    private func drift(_ start: ChatInputContent, caret: Int, _ text: String) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(caret, caret), .insert(text)])
        return driver.engineVerifierViolations()
    }

    /// Engine axis: "Intro" 0..<5, "\n", "pq" 6..<8, "\n", the author line at 9.
    private static let pull = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Intro"),
        .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pq")])),
    ])

    func testAnEmojiInAPullQuoteAuthorIsNotDrift() throws {
        XCTAssertEqual(try self.drift(Self.pull, caret: 9, "\u{1F44D}\u{1F3FD}"), [])
    }

    func testCJKInAPullQuoteAuthorIsNotDrift() throws {
        XCTAssertEqual(try self.drift(Self.pull, caret: 9, "\u{6F22}\u{5B57}"), [])
    }

    func testAnEmojiInABlockQuoteAuthorIsNotDrift() throws {
        let quote = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [HarnessEngine.paragraph("q")]), collapsed: false))])
        XCTAssertEqual(try self.drift(quote, caret: 2, "\u{1F44D}\u{1F3FD}"), [])
    }

    /// The same false positive in a HEADING (fuzz seeds 11, 12): its New York Medium face falls back
    /// to a BOLD face for Thai (Thonburi-Bold) or Hebrew (Times New Roman Bold), so the traits differ.
    func testThaiInAHeadingIsNotDrift() throws {
        let heading = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Title")]))])
        XCTAssertEqual(try self.drift(heading, caret: 5, "\u{E01}\u{E48}\u{E2D}\u{E19}"), [])
    }

    func testHebrewInAHeadingIsNotDrift() throws {
        let heading = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")]))])
        XCTAssertEqual(try self.drift(heading, caret: 5, "\u{5E2}\u{5D1}\u{5E8}\u{5D9}\u{5EA}"), [])
    }

    /// Control: Latin text in the same author line.
    func testControlLatinInAPullQuoteAuthor() throws {
        XCTAssertEqual(try self.drift(Self.pull, caret: 9, "Ab"), [])
    }
}
