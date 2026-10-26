import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a Format command over text in a code block's LANGUAGE line
/// formats the line on screen although the model cannot carry it (`ChatInputCode.language` is a plain
/// string): the screen and the message disagree.
///
///     [p "Code below:"] [code "let x = 1"] → type "swift" in the language line → select it
///       Format ▸ Spoiler:        "swift" drawn as a spoiler; model language "swift" (plain)
///       Format ▸ Italic:         drawn .SFUI-SemiboldItalic; the role derives .SFUI-Semibold
///       Format ▸ Monospace:      drawn as inline code (grey background, monospaced face)
///       Format ▸ Strikethrough / Underline: drawn struck / underlined
///     control: Format ▸ Bold — no drift (the line is already semibold)
///
/// The engine's own verifier reports "presentation does not match its role" and traps in any test
/// process.
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 20 (a spoiler over a
/// language line inside a quote); reduced by replay.
///
/// **Suspected cause.** The inline Format commands apply to every engine block the selection touches,
/// including a code block's secondary language line, which has no runs in the model; the language
/// line should be excluded (as the language line's traits are, see `+CodeInputTraits.swift`), or the
/// menu not offered there.
///
/// **Tier 1**: typing and `performFormatAction` are what the keyboard and the menu call.
@available(iOS 18.4, *)
final class HarnessCodeLanguageFormatTests: XCTestCase {
    /// Engine axis: "Code below:" 0..<11, "\n", the language line at 12, "\n", the body.
    private static let start = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Code below:"),
        .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
    ])

    private func drift(after format: FuzzFormat) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: [.select(12, 12), .insert("swift"), .format(format, selecting: (12, 17))])
        var language: String?
        for block in driver.model().blocks {
            if case let .code(code) = block {
                language = code.language
            }
        }
        XCTAssertEqual(language, "swift", "precondition: the language was not typed")
        return driver.engineVerifierViolations()
    }

    func testSpoilerOverTheLanguageLineDoesNotFormatIt() throws {
        XCTAssertEqual(try self.drift(after: .spoiler), [], "Spoiler formatted the language line the model cannot carry")
    }

    func testItalicOverTheLanguageLineDoesNotFormatIt() throws {
        XCTAssertEqual(try self.drift(after: .italic), [], "Italic formatted the language line the model cannot carry")
    }

    func testMonospaceOverTheLanguageLineDoesNotFormatIt() throws {
        XCTAssertEqual(try self.drift(after: .monospace), [], "Monospace formatted the language line the model cannot carry")
    }

    func testStrikethroughOverTheLanguageLineDoesNotFormatIt() throws {
        XCTAssertEqual(try self.drift(after: .strikethrough), [], "Strikethrough formatted the language line the model cannot carry")
    }

    /// The same family on a block quote's AUTHOR line (fuzz seeds 18, 30): the model's `author` is
    /// plain runs (its bold is render-only), so a Format command there formats what cannot be sent.
    private func authorDrift(after format: FuzzFormat) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        // Engine axis: "q" 0..<1, "\n", the author line at 2.
        let quote = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [HarnessEngine.paragraph("q")]), collapsed: false))])
        HarnessComposerFuzzTests.perform(driver, start: quote, ops: [.select(2, 2), .insert("hello"), .format(format, selecting: (2, 7))])
        var author = ""
        if case let .blockQuote(value)? = driver.model().blocks.first {
            author = value.author.map(\.text).joined()
        }
        XCTAssertEqual(author, "hello", "precondition: the author was not typed")
        return driver.engineVerifierViolations()
    }

    func testMonospaceOverAQuoteAuthorDoesNotFormatIt() throws {
        XCTAssertEqual(try self.authorDrift(after: .monospace), [], "Monospace formatted the author line the model carries as plain runs")
    }

    func testUnderlineOverAQuoteAuthorDoesNotFormatIt() throws {
        XCTAssertEqual(try self.authorDrift(after: .underline), [], "Underline formatted the author line the model carries as plain runs")
    }

    /// Control: Bold on the (already semibold) line derives cleanly.
    func testControlBoldOverTheLanguageLine() throws {
        XCTAssertEqual(try self.drift(after: .bold), [], "control: Bold over the language line drifted")
    }
}
