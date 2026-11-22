import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A selection holding exactly the paragraph break AFTER a caption-less atom — a button
/// row, an audio file — has no geometry at all: `selectionRects(for:)` answers one rect at
/// `(inf, inf, 0, 0)` with neither `containsStart` nor `containsEnd`, and `firstRect(for:)` answers
/// `(inf, inf, 0, 0)`. So nothing is highlighted, no handles are drawn, and anything placed from
/// `firstRect` (the edit menu, the autocorrection prompt) is placed at infinity. It is the selection
/// Shift+→ makes with the caret at the atom's trailing stop. `[p "Tap " pill " now"] [row One|Two]
/// [p "After the row."]`, select 11..<12 → no rects; `[p "Listen"] [audio] [album] …`, select 8..<9 →
/// the same. Controls: the break after a plain paragraph, and the break between a CAPTIONED medium's atom
/// and its caption, both draw a rect with both endpoints.
///
/// **How it was seen.** p19 roam, 2026-09-25: a UITextInput conformance probe asking every range of
/// every fuzz starting document (all pairs of offsets up to 90 characters) for its geometry; these two
/// ranges were the only ones, in 14 documents, that came back empty.
///
/// **Suspected cause.** The rule that stands a selected paragraph break up as a mark ("A selected
/// paragraph break on an EMPTY line draws a narrow mark", RichTextEditor `CLAUDE.md`, block selection
/// rectangles) covers a break before an EMPTY line; a break after an attachment-only line whose segment
/// has zero width is reported as "failed to measure" (`IDBlockTextGeometry` / the coordinator's
/// all-or-nothing validity check in `IDDocumentLayoutCoordinator`), which discards the whole answer.
///
/// **Tier 1**: the public `UITextInput` geometry calls, and the arrow-key action UIKit performs for ⇧→.
@available(iOS 18.4, *)
final class HarnessAtomLineBreakSelectionGeometryTests: XCTestCase {
    private typealias E = HarnessEdited

    private func assertGeometry(_ content: ChatInputContent, formulas: Bool = false, lower: Int, upper: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let driver = try EngineFuzzDriver()
        if formulas { E.installFormulaRenderer(on: driver.host) }
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, content)
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        let begin = input.beginningOfDocument
        let range = try XCTUnwrap(input.textRange(from: try XCTUnwrap(input.position(from: begin, offset: lower)), to: try XCTUnwrap(input.position(from: begin, offset: upper))))
        XCTAssertEqual(input.text(in: range), "\n", "precondition: \(lower)..<\(upper) is not the paragraph break", file: file, line: line)
        let rects = input.selectionRects(for: range)
        XCTAssertFalse(rects.isEmpty, "no selection rects", file: file, line: line)
        for rect in rects {
            XCTAssertTrue(rect.rect.minX.isFinite && rect.rect.minY.isFinite && rect.rect.height > 0, "selection rect \(rect.rect)", file: file, line: line)
        }
        XCTAssertEqual(rects.filter(\.containsStart).count, 1, "rects carrying the start", file: file, line: line)
        XCTAssertEqual(rects.filter(\.containsEnd).count, 1, "rects carrying the end", file: file, line: line)
        let first = input.firstRect(for: range)
        XCTAssertTrue(first.minX.isFinite && first.minY.isFinite, "firstRect \(first)", file: file, line: line)
    }

    private func buttonRowDocument() -> ChatInputContent {
        // "Tap \u{FFFC} now\n\u{FFFC}\nAfter the row.": the row's atom is 10, its break 11.
        return ChatInputContent(blocks: [E.paragraph([E.run("Tap "), E.pill("Go"), E.run(" now")]), E.buttonRow(["One", "Two"]), E.paragraph([E.run("After the row.")])])
    }

    private func audioDocument() -> ChatInputContent {
        // "Listen\n\u{FFFC}\ntail": the audio atom is 7, its break 8.
        return ChatInputContent(blocks: [E.paragraph([E.run("Listen")]), E.audio(3), E.paragraph([E.run("tail")])])
    }

    func testTheBreakAfterAButtonRowHasGeometry() throws {
        try self.assertGeometry(self.buttonRowDocument(), lower: 11, upper: 12)
    }

    func testTheBreakAfterAnAudioAtomHasGeometry() throws {
        try self.assertGeometry(self.audioDocument(), lower: 8, upper: 9)
    }

    /// The same selection made the way a user makes it: the caret at the row's trailing stop, then ⇧→
    /// (`_moveRight:withHistory:` extending, what UIKit performs for the key).
    func testShiftRightFromAButtonRowsTrailingStopIsDrawn() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        HarnessComposerFuzzTests.arrange(driver, self.buttonRowDocument())
        driver.setViewSelection(NSRange(location: 11, length: 0))
        driver.settle(0.1)
        FuzzKeyMove.perform("_moveRight:withHistory:", on: driver.view, extending: true)
        driver.settle(0.1)
        XCTAssertEqual(driver.viewSelection(), NSRange(location: 11, length: 1), "precondition: ⇧→ did not select the break")
        let input = try XCTUnwrap(driver.view as? (UIView & UITextInput))
        let selected = try XCTUnwrap(input.selectedTextRange)
        let rects = input.selectionRects(for: selected)
        XCTAssertTrue(rects.contains { $0.rect.minY.isFinite && $0.rect.height > 0 }, "the selection ⇧→ made is not drawn: \(rects.map(\.rect))")
    }

    // Controls.

    func testControlTheBreakAfterAParagraphHasGeometry() throws {
        try self.assertGeometry(HarnessContent.plainText("abc\ndef"), lower: 3, upper: 4)
    }

    func testControlTheBreakBetweenACaptionedAtomAndItsCaptionHasGeometry() throws {
        // "Before the photo.\n\u{FFFC}\nA caption here\nAfter it.": the atom is 18, its break 19.
        try self.assertGeometry(HarnessComposerFuzzTests.editedStartingContents()[0], lower: 19, upper: 20)
    }

    func testControlTheBreakBeforeAButtonRowHasGeometry() throws {
        try self.assertGeometry(self.buttonRowDocument(), lower: 9, upper: 10)
    }
}
