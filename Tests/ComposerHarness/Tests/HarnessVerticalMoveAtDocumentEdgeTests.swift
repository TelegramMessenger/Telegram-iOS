import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, ↓ / ↑ pressed REPEATEDLY — a held arrow key, or presses in a
/// row, which UIKit resolves with the arrow-key history the previous press returned — move the caret
/// the wrong way once a container (a code block, a table, a details block, a captioned medium) is in
/// the composer. A single press (no history) behaves; plain paragraphs behave (controls).
///
///     [p "Code below:"] [code lang="" "let x = 1"], caret 0, ↓ ↓ ↓ ↓
///       engine: 12, 13, 11, 22   — the third press jumps BACK to the end of line 0
///       expected (stock, and the engine on the same text as plain paragraphs): 12, 13, 22, 22
///     [p "Table below:"] [table Name|Value / alpha|1] [p "After the table."], caret 0, ↓ ×5
///       engine: 13, 32, 12, 48, 48 — skips the "alpha" row, then goes back to line 0
///     same table, caret 32 (start of the line under it), ↑ ×4
///       engine: 30, 0, 0, 0 — lands in the last column, then skips the header row
///     details and media documents: the same jump back to line 0 from the last line.
///
/// The primitive behind a repeated press is `position(from:in:offset:)` with an offset of 2+ (the
/// history's start position moved by the presses so far): over the code block `down 3` answers 11
/// (the end of line 0) where the end of the text (22) is due; over the table `down 2` answers 32
/// (skipping a row); on plain paragraphs past the last line it answers the last line's START where a
/// stock `UITextView` answers the end.
///
/// Separately, a SINGLE ↑ from the start of the line under a table (x = 0, left of the table's first
/// column) lands in the table's LAST column rather than the nearest one.
///
/// **How it was seen.** p17 roam, 2026-09-25: a probe walked every structured starting document with
/// the private arrow-key actions UIKit's hardware keyboard performs (`_moveDown:withHistory:`,
/// feeding each press the history the previous one returned, as `UIKeyboardImpl` does) and recorded
/// the caret after each press; the earlier (p11) arrow-key checks passed no history, so they never
/// reached this path. The fuzz's new `keyWalk` op finds it on its own (`FuzzKnownDefect.keyWalkWrongWay`).
///
/// **Suspected cause.** `-[IDRichTextLayoutController id_positionFromPosition:inDirection:offset:…]`
/// steps `-[IDDocumentLayoutCoordinator visuallyAdjacentPositionFromCanonicalOffset:…]` once per line,
/// and leaving a block vertically asks the canvas
/// (`-[IDBlockStackCanvasView verticallyAdjacentBlockIdentifierFromBlockIdentifier:downward:anchorPositionOffset:]`).
/// Its "leaving a placed block" branch probes every placed block's hit rect for the point just past the
/// source's edge — if those rects are not in one coordinate space, the probe can hit a block far away
/// (line 0) — and its "entering a run" branch falls back to `run.firstObject`, which for an UPWARD entry
/// is the run's LAST cell (the run is collected walking up), hence the last column for a probe left of
/// the table. Past the last block the multi-step walk does not clamp to the end of the document.
///
/// **Tier 1**: `_moveDown:withHistory:` / `_moveUp:withHistory:` are the actions ↓ / ↑ perform on the
/// first responder; plain paragraphs on the same engine and a stock `UITextView` are the controls.
final class HarnessVerticalMoveAtDocumentEdgeTests: XCTestCase {
    private typealias MoveFunction = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> AnyObject?

    private func move(_ name: String, on target: NSObject, extending: Bool = false, history: AnyObject?) throws -> AnyObject? {
        let selector = NSSelectorFromString(name)
        let method = try XCTUnwrap(class_getInstanceMethod(type(of: target), selector), "precondition: \(type(of: target)) has no \(name)")
        let function = unsafeBitCast(method_getImplementation(method), to: MoveFunction.self)
        return function(target, selector, extending, history)
    }

    private func selection(_ input: UITextInput) -> NSRange {
        let range = input.selectedTextRange!
        let start = input.offset(from: input.beginningOfDocument, to: range.start)
        return NSRange(location: start, length: input.offset(from: range.start, to: range.end))
    }

    /// Arranges `content`, puts the caret at `caret` and presses `action` `presses` times, passing each
    /// press the history the previous one returned. Returns the caret after each press.
    private func walk(_ content: ChatInputContent, from caret: Int, _ action: String, presses: Int, extending: Bool = false, formulas: Bool = false) throws -> [NSRange] {
        let arranged = try HarnessP16.arrange(content.blocks)
        if formulas {
            HarnessEdited.installFormulaRenderer(on: arranged.host)
            arranged.host.setInputContent(content)
            HarnessEngine.settle(arranged.root, seconds: 0.2)
        }
        defer {
            if formulas { arranged.host.panel.formulaRenderer = nil }
            HarnessP16.finish(arranged)
        }
        HarnessP16.select(arranged, caret, caret)
        var history: AnyObject?
        var result: [NSRange] = []
        for _ in 0 ..< presses {
            history = try self.move(action, on: arranged.input, extending: extending, history: history)
            HarnessEngine.settle(arranged.root, seconds: 0.05)
            result.append(self.selection(arranged.input))
        }
        return result
    }

    private func stockWalk(_ text: String, from caret: Int, _ action: String, presses: Int) throws -> [NSRange] {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 380.0, height: 300.0))
        textView.font = UIFont.systemFont(ofSize: 17.0)
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        _ = textView.becomeFirstResponder()
        textView.text = text
        textView.selectedRange = NSRange(location: caret, length: 0)
        var history: AnyObject?
        var result: [NSRange] = []
        for _ in 0 ..< presses {
            history = try self.move(action, on: textView, history: history)
            result.append(textView.selectedRange)
        }
        return result
    }

    private func carets(_ values: [Int]) -> [NSRange] {
        return values.map { NSRange(location: $0, length: 0) }
    }

    private var codeDocument: ChatInputContent { HarnessComposerFuzzTests.startingContents()[4] }      // "Code below:" / "" / "let x = 1"
    private var tableDocument: ChatInputContent { HarnessComposerFuzzTests.startingContents()[9] }     // "Table below:" / 4 cells / "After the table."
    private var detailsDocument: ChatInputContent { HarnessComposerFuzzTests.startingContents()[10] }  // "Details:" / "Summary" / "Hidden body."
    private var mediaDocument: ChatInputContent { HarnessComposerFuzzTests.editedStartingContents()[0] } // "Before the photo." / atom / caption / "After it."

    // MARK: - Repeated presses (UIKit passes each press the previous press's history)

    func testDownWalkedOverACodeBlockNeverGoesUp() throws {
        let walk = try self.walk(self.codeDocument, from: 0, "_moveDown:withHistory:", presses: 4).map(\.location)
        XCTAssertEqual(walk, [12, 13, 22, 22], "↓ pressed repeatedly from the start went backwards")
    }

    func testDownWalkedOverADetailsBlockNeverGoesUp() throws {
        let walk = try self.walk(self.detailsDocument, from: 0, "_moveDown:withHistory:", presses: 4).map(\.location)
        XCTAssertEqual(walk, [9, 17, 29, 29], "↓ pressed repeatedly from the start went backwards")
    }

    func testDownWalkedOverAMediumNeverGoesUp() throws {
        let walk = try self.walk(self.mediaDocument, from: 0, "_moveDown:withHistory:", presses: 5).map(\.location)
        XCTAssertEqual(walk, [18, 20, 35, 44, 44], "↓ pressed repeatedly from the start went backwards")
    }

    func testDownWalkedOverATableVisitsEveryRow() throws {
        // "Table below:" → "Name" (row 1) → "alpha" (row 2) → "After the table." → the end.
        let walk = try self.walk(self.tableDocument, from: 0, "_moveDown:withHistory:", presses: 5).map(\.location)
        XCTAssertEqual(walk, [13, 24, 32, 48, 48], "↓ pressed repeatedly skipped a table row or went backwards")
    }

    func testUpWalkedFromTheEndNeverGoesDown() throws {
        let walk = try self.walk(self.tableDocument, from: 32, "_moveUp:withHistory:", presses: 4).map(\.location)
        XCTAssertEqual(walk, [24, 13, 0, 0], "↑ pressed repeatedly from the last line's start skipped a row or went down")
    }

    func testShiftDownWalkedOverACodeBlockOnlyGrows() throws {
        let walk = try self.walk(self.codeDocument, from: 0, "_moveDown:withHistory:", presses: 4, extending: true)
        XCTAssertEqual(walk.map { NSMaxRange($0) }, [12, 13, 22, 22], "⇧↓ pressed repeatedly shrank the selection")
    }

    // MARK: - The primitive behind a repeated press

    /// `positionFromPosition:inDirection:offset:` is what a repeated press resolves: the history's start
    /// position moved by the number of presses so far. Past the last line it must clamp to the END (stock
    /// does), and it must count each line once.
    func testPositionDownByManyLinesClampsToTheEnd() throws {
        let arranged = try HarnessP16.arrange(self.codeDocument.blocks)
        defer { HarnessP16.finish(arranged) }
        let input = arranged.input
        let answers = (1 ... 5).map { n -> Int? in
            input.position(from: input.beginningOfDocument, in: .down, offset: n).map { input.offset(from: input.beginningOfDocument, to: $0) }
        }
        XCTAssertEqual(answers, [12, 13, 22, 22, 22], "position(from: 0, in: .down, offset: n) over a code block")
    }

    func testPositionDownByTwoLinesInATableIsTheSecondRow() throws {
        let arranged = try HarnessP16.arrange(self.tableDocument.blocks)
        defer { HarnessP16.finish(arranged) }
        let input = arranged.input
        let answers = (1 ... 4).map { n -> Int? in
            input.position(from: input.beginningOfDocument, in: .down, offset: n).map { input.offset(from: input.beginningOfDocument, to: $0) }
        }
        XCTAssertEqual(answers, [13, 24, 32, 48], "position(from: 0, in: .down, offset: n) over a table")
    }

    /// On plain paragraphs the engine stops at the LAST LINE'S START where stock clamps to the end
    /// (stock `down5` over five lines: 32; engine: 28). Pinned separately: it is the same primitive.
    func testPositionDownPastThePlainLastLineIsTheEnd() throws {
        let text = "Code below:\n\nlet x = 1\nfour\nfive"
        let stock = try self.stockPositions(text, .down, from: 0, offsets: [5, 6])
        XCTAssertEqual(stock, [32, 32], "control: stock")
        let arranged = try HarnessP16.arrange(HarnessContent.plainText(text).blocks)
        defer { HarnessP16.finish(arranged) }
        let input = arranged.input
        let answers = [5, 6].map { n -> Int? in
            input.position(from: input.beginningOfDocument, in: .down, offset: n).map { input.offset(from: input.beginningOfDocument, to: $0) }
        }
        XCTAssertEqual(answers, [32, 32], "position(from: 0, in: .down, offset: n) past the last line")
    }

    private func stockPositions(_ text: String, _ direction: UITextLayoutDirection, from: Int, offsets: [Int]) throws -> [Int?] {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 380.0, height: 300.0))
        textView.font = UIFont.systemFont(ofSize: 17.0)
        root.view.addSubview(textView)
        defer { textView.removeFromSuperview() }
        textView.text = text
        let origin = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: from))
        return offsets.map { n in textView.position(from: origin, in: direction, offset: n).map { textView.offset(from: textView.beginningOfDocument, to: $0) } }
    }

    // MARK: - A single ↑ into a table from the line below

    /// ↑ from the START of the line under a table (x = 0, left of the table's first column at x ≈ 44)
    /// lands in the LAST column ("1", x ≈ 195) instead of the nearest one ("alpha", x ≈ 47). The caret
    /// rects (`caretRect(for:)`) are right; the pick of a position for a point left of the table's first
    /// column is not. A point over a column works (↑ from x ≈ 56 is control).
    func testUpIntoATableFromTheLineStartLandsInTheFirstColumn() throws {
        let caret = try XCTUnwrap(try self.walk(self.tableDocument, from: 32, "_moveUp:withHistory:", presses: 1).first).location
        XCTAssertTrue((24 ... 29).contains(caret), "↑ from the start of the line under the table went to \(caret), not into the first column (24...29)")
    }

    func testControlUpIntoATableFromOverTheFirstColumn() throws {
        let caret = try XCTUnwrap(try self.walk(self.tableDocument, from: 40, "_moveUp:withHistory:", presses: 1).first).location
        XCTAssertTrue((24 ... 29).contains(caret), "control: ↑ from x ≈ 56 under the table went to \(caret)")
    }

    // MARK: - Single presses (no history): these already behave, kept as controls

    func testControlSinglePressesAtTheDocumentEdges() throws {
        XCTAssertEqual(try self.walk(self.codeDocument, from: 13, "_moveDown:withHistory:", presses: 1), self.carets([22]), "code: last line ↓")
        XCTAssertEqual(try self.walk(self.detailsDocument, from: 17, "_moveDown:withHistory:", presses: 1), self.carets([29]), "details: last line ↓")
        XCTAssertEqual(try self.walk(self.tableDocument, from: 12, "_moveUp:withHistory:", presses: 1), self.carets([0]), "table: first line ↑")
    }

    /// Control: plain paragraphs on the engine, and a stock `UITextView`, walked with history.
    func testControlPlainParagraphsWalkDown() throws {
        let text = "Code below:\n\nlet x = 1"
        XCTAssertEqual(try self.stockWalk(text, from: 0, "_moveDown:withHistory:", presses: 4).map(\.location), [12, 13, 22, 22], "control: stock")
        XCTAssertEqual(try self.walk(HarnessContent.plainText(text), from: 0, "_moveDown:withHistory:", presses: 4).map(\.location), [12, 13, 22, 22],
                       "control: the engine on plain paragraphs")
    }

    func testControlPlainParagraphsGoToTheEnd() throws {
        let text = "Code below:\n\nlet x = 1"
        XCTAssertEqual(try self.stockWalk(text, from: 13, "_moveDown:withHistory:", presses: 1), self.carets([22]), "control: stock")
        XCTAssertEqual(try self.walk(HarnessContent.plainText(text), from: 13, "_moveDown:withHistory:", presses: 1), self.carets([22]),
                       "control: the engine on plain paragraphs")
        XCTAssertEqual(try self.stockWalk(text, from: 5, "_moveUp:withHistory:", presses: 1), self.carets([0]), "control: stock ↑")
        XCTAssertEqual(try self.walk(HarnessContent.plainText(text), from: 5, "_moveUp:withHistory:", presses: 1), self.carets([0]),
                       "control: the engine on plain paragraphs ↑")
    }
}
