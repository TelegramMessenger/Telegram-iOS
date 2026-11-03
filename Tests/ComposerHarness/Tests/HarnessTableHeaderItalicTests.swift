import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, Format ▸ Italic over a table HEADER cell leaves the cell's
/// presentation not derived from its role. The engine's verifier reports `IDInlineTextBaseFont`
/// drift, which in any test process is a trap:
///
///     [p "Intro"] [table x y z (header row) / 1 2 3], Italic on "x" (6..<7) → model [i]"x",
///       drift IDInlineTextBaseFont at the cell
///     Italic across the header row (6..<11), or Select All + Italic → the same, for every header cell
///     controls: Italic on a BODY cell ("1") is clean; Bold over the header row is clean
///
/// This is the header-cell sibling of the tenth wave's author-line fix
/// (`HarnessAuthorLineItalicTests`, "the engine keeps a toggled italic in its marker and leaves the
/// base face alone, while the bridge rendered the author's base face WITH the user's italic").
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix, 2026-09-23, seeds 5
/// (`.selectAllFormat(.italic)`) and 17 (`.typeInFormat(.italic, …)` across a pasted table); reduced
/// by probe. Seed 293 drifted the same way with Italic toggled back OFF (no marker left) after
/// Strikethrough and typing; NOT reduced — a plain on/off round trip over the header row is clean.
///
/// **Suspected cause.** The bridge stamps a header cell's ambient bold into its base face
/// (`EngineDocumentBridge`, header cells). When it re-derives the cell after the toggle, it renders the
/// base face WITH the user's italic, while the engine's own toggle keeps italic in the marker only.
///
/// **Tier 1**: `performFormatAction` is what the Format menu calls; the verifier is asked directly with
/// its trap switched off (`FuzzEngineVerifier`).
@available(iOS 18.4, *)
final class HarnessTableHeaderItalicTests: XCTestCase {
    private static let table = "| x | y | z |\n|---|---|---|\n| 1 | 2 | 3 |"

    private func drift(_ ops: [FuzzOp]) throws -> [String] {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        HarnessComposerFuzzTests.perform(driver, start: HarnessContent.plainText("Intro"), ops: [.select(5, 5), .pasteText(Self.table)] + ops)
        guard case let .table(table)? = driver.model().blocks.dropFirst().first, table.rows.first?.isHeader == true else {
            XCTFail("precondition: no table with a header row: \(FuzzModel.describe(driver.model()))")
            return []
        }
        return driver.engineVerifierViolations()
    }

    func testItalicOnOneHeaderCellIsDerived() throws {
        XCTAssertEqual(try self.drift([.format(.italic, selecting: (6, 7))]), [])
    }

    func testItalicAcrossTheHeaderRowIsDerived() throws {
        XCTAssertEqual(try self.drift([.format(.italic, selecting: (6, 11))]), [])
    }

    func testSelectAllItalicIsDerived() throws {
        XCTAssertEqual(try self.drift([.selectAllFormat(.italic)]), [])
    }

    /// Control: Italic on a body cell.
    func testControlItalicOnABodyCell() throws {
        XCTAssertEqual(try self.drift([.format(.italic, selecting: (12, 13))]), [])
    }

    /// Control: Bold across the header row.
    func testControlBoldAcrossTheHeaderRow() throws {
        XCTAssertEqual(try self.drift([.format(.bold, selecting: (6, 11))]), [])
    }
}
