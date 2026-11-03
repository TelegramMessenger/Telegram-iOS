import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Italic over a BLOCK QUOTE's author line left its
/// presentation underived: the engine keeps a toggled italic in its marker and leaves the run's base
/// face (the author line's ambient bold) alone, while the bridge rendered the base face WITH the
/// user's italic, so the verifier reported `IDInlineTextBaseFont` drift and trapped:
///
///     [quote [p "q"] author "abc"] → select the author (2..<5) → Format ▸ Italic
///       engine: drift IDInlineTextBaseFont on the author line
///     same over a range from the quote's child into its author line
///     control: Bold over the same author line
///
/// **How it was seen.** `HarnessComposerFuzzTests` (engine), 2026-09-23, seed 20 (an italic range
/// ending in a nested quote's author line); reduced by hand.
///
/// **Cause.** `EngineDocumentBridge.authorLine` stamped the rendered face — ambient emphasis AND the
/// user's italic — as the base face. Fixed: the base carries the emphasis only.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls; the verifier is asked directly.
@available(iOS 18.4, *)
final class HarnessAuthorLineItalicTests: XCTestCase {
    private static let start = ChatInputContent(blocks: [
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("q")]), collapsed: false)),
    ])

    private func drift(_ format: FuzzFormat, selecting: (Int, Int)) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        // The author is typed, as a user types it (an author line exists once the quote has content).
        HarnessComposerFuzzTests.perform(driver, start: Self.start, ops: [.select(2, 2), .insert("abc"), .format(format, selecting: selecting)])
        return driver.engineVerifierViolations()
    }

    func testItalicOverABlockQuoteAuthorLineIsDerived() throws {
        XCTAssertEqual(try self.drift(.italic, selecting: (2, 5)), [])
    }

    func testItalicFromTheChildIntoTheAuthorLineIsDerived() throws {
        XCTAssertEqual(try self.drift(.italic, selecting: (0, 5)), [])
    }

    /// Control: Bold over the same author line.
    func testControlBold() throws {
        XCTAssertEqual(try self.drift(.bold, selecting: (2, 5)), [])
    }
}
