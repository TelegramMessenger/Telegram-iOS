import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Select All → Copy → Paste (a round trip the harness pins,
/// `HarnessContainerCutPasteRoundTripTests`) silently DROPS an EMPTY pull quote or an EMPTY code
/// block. A pull quote's author goes with it:
///
///     [p "a"] [pull "" author=""] [p "b"]     → [p "a"] [p "b"]
///     [p "a"] [pull "" author="x"] [p "b"]    → [p "a"] [p "b"]    ← the author "x" is lost
///     [p "a"] [code ""] [p "b"]               → [p "a"] [p "b"]
///     [p "a"] [pull "" author=""]             → [p "a"]
///     controls: an empty BLOCK quote survives; a non-empty pull quote survives
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix, 2026-09-23, seed 83: the
/// end-of-sequence copy → paste-back lost `[pull  author=]` between two paragraphs. Reduced by probe.
///
/// **Suspected cause.** The copy extracts the selection's fragment by covered TEXT
/// (`Document.extractFragment`, `+Clipboard.swift`'s `writeSelectionToPasteboard()`). A container
/// whose body is empty covers no characters, so it is never "entered" and is left out. A block quote
/// survives because its empty child paragraph is a block of its own. The eighth wave's quote-copy fix
/// (`HarnessQuoteCopyTests`) handled the entering case only.
///
/// **Tier 1**: `selectAll:` / `copy:` / `paste:` on the engine view, as the edit menu sends them.
@available(iOS 18.4, *)
final class HarnessEmptyContainerCopyPasteTests: XCTestCase {
    private func roundTrip(_ start: ChatInputContent) throws -> (before: String, after: String) {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [])
        let before = FuzzModel.describe(FuzzModel.normalized(driver.model()))
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        driver.settle(0.1)
        _ = driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        driver.settle(0.3)
        return (before, FuzzModel.describe(FuzzModel.normalized(driver.model())))
    }

    private static func between(_ block: ChatInputBlock) -> ChatInputContent {
        return ChatInputContent(blocks: [HarnessEngine.paragraph("a"), block, HarnessEngine.paragraph("b")])
    }

    func testAnEmptyPullQuoteSurvivesCopyPaste() throws {
        let result = try self.roundTrip(Self.between(.pullQuote(ChatInputPullQuote(runs: []))))
        XCTAssertEqual(result.after, result.before)
    }

    func testAnEmptyPullQuoteWithAnAuthorSurvivesCopyPaste() throws {
        let result = try self.roundTrip(Self.between(.pullQuote(ChatInputPullQuote(runs: [], author: [ChatInputRun(text: "x")]))))
        XCTAssertEqual(result.after, result.before)
    }

    func testAnEmptyCodeBlockSurvivesCopyPaste() throws {
        let result = try self.roundTrip(Self.between(.code(ChatInputCode(language: nil, runs: []))))
        XCTAssertEqual(result.after, result.before)
    }

    /// Control: an empty block quote.
    func testControlAnEmptyBlockQuote() throws {
        let result = try self.roundTrip(Self.between(.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("")]), collapsed: false))))
        XCTAssertEqual(result.after, result.before)
    }

    /// Control: a non-empty pull quote.
    func testControlANonEmptyPullQuote() throws {
        let result = try self.roundTrip(Self.between(.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "pulled")]))))
        XCTAssertEqual(result.after, result.before)
    }
}
