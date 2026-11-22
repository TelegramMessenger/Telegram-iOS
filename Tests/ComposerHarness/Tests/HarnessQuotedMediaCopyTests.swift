import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Copy or Cut of a range holding a MEDIA unit that sits inside a
/// BLOCK QUOTE loses the medium, unless the range also reaches the quote's author line. The paste
/// brings back the quote's text (or the caption as a plain paragraph) and no photo; after a Cut the
/// photo is gone for good (only Undo brings it back).
///
///     [quote [p "Al hi"] [media "In"]] [p "out"]   engine "Al hi\n\u{FFFC}\nIn\n\nout"
///     select 3..<10 ("hi" … the caption's end), Copy, paste inside "out"
///                                                  → [quote [p "hi"]] pasted, no media
///     select 0..<10, Cut, Paste                    → [quote [p "Al hi"]] [p "out"]: the photo is lost
///     [quote [media "In"]] [p "out"], select 0..<4, Copy, paste → "In" as a plain paragraph
///     controls: the same range with the media NOT quoted, or inside a DETAILS body, copies the medium;
///     a range reaching the author line (0..<11) copies it too
///
/// **How it was seen.** p13 probe, 2026-09-24.
///
/// **Suspected cause.** `writeSelectionToPasteboard()` (`+Clipboard.swift`) widens the range with
/// `Document.expandingRangeOverNonTextBlocks` and extracts with `extractFragment(…,
/// carryingNonTextBlocks: true)`. For a quote covered only in part the fragment keeps the quote's
/// children as text; the non-text child (the media block) is not carried at that depth. The eighth
/// wave fixed the neighbouring shape for whole quotes (`HarnessQuoteCopyTests`), and details bodies
/// already carry media (control).
///
/// **Tier 1**: `copy:` / `cut:` / `paste:` on the engine view.
@available(iOS 18.4, *)
final class HarnessQuotedMediaCopyTests: XCTestCase {
    typealias E = HarnessEdited

    private static func quote(_ blocks: [ChatInputBlock]) -> ChatInputBlock {
        return .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: blocks), collapsed: false))
    }

    private static let quoted = ChatInputContent(blocks: [quote([E.paragraph([E.run("Al hi")]), E.media(caption: "In")]), E.paragraph([E.run("out")])])

    private func run(_ start: ChatInputContent, _ ops: [FuzzOp]) throws -> ChatInputContent {
        let driver = try EngineFuzzDriver()
        defer { _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.perform(driver, start: start, ops: ops)
        return driver.model()
    }

    func testCopyingAQuotedMediaUnitCarriesTheMedium() throws {
        let got = try self.run(Self.quoted, [.select(3, 10), .copy, .select(14, 14), .paste])
        XCTAssertEqual(E.mediaCount(got), 2, "the pasted copy has no medium: \(E.describe(got))")
    }

    func testCutAndPasteOfAQuotedMediaUnitKeepsTheMedium() throws {
        let got = try self.run(Self.quoted, [.select(0, 10), .cut, .paste])
        XCTAssertEqual(E.mediaCount(got), 1, "cut + paste lost the photo: \(E.describe(got))")
    }

    func testCopyingAQuoteHoldingOnlyAMediumCarriesTheMedium() throws {
        let got = try self.run(ChatInputContent(blocks: [Self.quote([E.media(caption: "In")]), E.paragraph([E.run("out")])]), [.select(0, 4), .copy, .select(8, 8), .paste])
        XCTAssertEqual(E.mediaCount(got), 2, "the pasted copy has no medium: \(E.describe(got))")
    }

    /// Control: the same shape unquoted.
    func testControlCopyingAnUnquotedMediaUnitCarriesTheMedium() throws {
        let got = try self.run(ChatInputContent(blocks: [E.paragraph([E.run("Before")]), E.media(caption: "Cap"), E.paragraph([E.run("After")])]), [.select(3, 15), .copy, .select(18, 18), .paste])
        XCTAssertEqual(E.mediaCount(got), 2, E.describe(got))
    }

    /// Control: a medium inside a DETAILS body is carried.
    func testControlCopyingAMediaUnitInADetailsBodyCarriesTheMedium() throws {
        let got = try self.run(ChatInputContent(blocks: [.details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("b")]), E.media(caption: "In")]), title: [E.run("T")], expanded: true)), E.paragraph([E.run("out")])]), [.select(2, 9), .copy, .select(12, 12), .paste])
        XCTAssertEqual(E.mediaCount(got), 2, E.describe(got))
    }

    /// Control: a range that reaches the quote's author line carries the medium.
    func testControlARangeReachingTheAuthorLineCarriesTheMedium() throws {
        let got = try self.run(Self.quoted, [.select(0, 11), .copy, .select(14, 14), .paste])
        XCTAssertEqual(E.mediaCount(got), 2, E.describe(got))
    }
}
