import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** In the chat composer's real editor width (317pt at a 402pt screen: the attach and send
/// buttons take the rest), a block quote nested 6 or 7 levels deep — BELOW the p20 cap of 8 indented
/// levels — has almost no text column: 7 deep, every character of `"Deepest line text here"` is on a line
/// of its own (caret x 111 or 112 for every offset, 23 lines); 6 deep, the 7-letter first word is broken
/// in two. And the column is not monotonic in depth: 8 or more deep the same line is laid out ~117pt wide
/// (two lines), far wider than 7 deep. Measured (caret x of the line's start → furthest caret x):
///
///     depth 2: 31 → 183 (one line)    depth 5: 79 → 138 (3 lines)   depth 6: 95 → 128 (5 lines)
///     depth 7: 111 → 114 (23 lines)   depth 8: 127 → 244 (2 lines)  depth 9, 10: as 8
///
/// The paragraph styles are exactly the capped sums (7 deep: head 112, tail −154; 8 deep: head 128,
/// tail −176, the same at 9 and 10), so the text column the engine lays out does not follow the
/// paragraph style alone: at 7 deep it is narrower than `317 − 112 − 154 = 51`, at 8 deep wider than
/// `317 − 128 − 176 = 13`.
///
/// **How it was seen.** p21 roam (2026-10-01), probing the p20 decision's edges (quotes 8-20 deep:
/// caret geometry, hit-testing, typing, the send oracle). 8-20 deep are clean (hit-testing exact, typing
/// and Quote land, the rich route round-trips, Select All → Copy → Paste is identity). The collapse is
/// just below the cap; a hit test at 7 deep lands one offset late after each word. The p20 cap was sized
/// for the SCREEN width ("155pt at 402pt"); each level costs 16 + 22 = 38pt, so eight levels at the
/// editor's 317pt leave 13pt by the paragraph styles' own arithmetic.
///
/// **Suspected cause.** Two things. (1) The cap of 8 levels is too deep for the composer's editor width
/// (`EngineAncestor.maxIndentedQuoteLevels`, `EngineBlockRole.swift`; its comment's arithmetic uses the
/// screen width and the leading indent only). (2) Something besides the paragraph style narrows a quoted
/// block's layout width per level below the cap and stops at it — the column at 7 deep is narrower than
/// its paragraph style allows and at 8 deep wider — likely a container/decoration frame that insets the
/// block per ancestor without going through the capped `contentIndent` / `contentTrailingInset` sums.
///
/// **Severity.** A WIDTH finding (provisional by rule). The model is right and what is sent is right; the
/// user sees one character per line and taps land one offset late.
///
/// **Tier 1**: the deep block is set as content (an edited message, a paste or repeated Quote all reach
/// it); geometry is read through `UITextInput.caretRect(for:)`.
@available(iOS 18.4, *)
final class HarnessDeepQuoteNarrowColumnTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private static let line = "Deepest line text here"

    /// The caret rects of every offset of the deep line, `[p "Top"] [quote×depth [p line]] [p "end"]`.
    private func carets(depth: Int) -> [CGRect] {
        var block = HarnessEngine.paragraph(Self.line)
        for _ in 0 ..< depth {
            block = .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [block]), collapsed: false))
        }
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [HarnessEngine.paragraph("Top"), block, HarnessEngine.paragraph("end")]))
        self.driver.settle(0.2)
        let input = self.driver.view as! (UIView & UITextInput)
        let start = (self.driver.viewText() as NSString).range(of: Self.line).location
        return (0 ... (Self.line as NSString).length).map { offset in
            input.caretRect(for: input.position(from: input.beginningOfDocument, offset: start + offset)!)
        }
    }

    /// The width the line's text spreads over: the furthest caret from the line's start.
    private func spread(depth: Int) -> CGFloat {
        let rects = self.carets(depth: depth)
        return (rects.map(\.maxX).max() ?? 0.0) - (rects.first?.minX ?? 0.0)
    }

    private func assertFirstWordOnOneLine(depth: Int, file: StaticString = #filePath, line: UInt = #line) {
        let rects = self.carets(depth: depth)
        XCTAssertEqual(self.driver.editor.bounds.width, 317.0, accuracy: 1.0, "precondition: the composer's editor width", file: file, line: line)
        // "Deepest" is offsets 0..<7: its carets 0...7 lie on one line, ~60pt wide.
        let ys = Set(rects[0 ... 7].map { Int($0.minY.rounded()) })
        XCTAssertEqual(ys.count, 1, "\(depth) deep: the 7-letter word \"Deepest\" is broken over \(ys.count) lines (carets x \(rects[0 ... 7].map { Int($0.minX) }))", file: file, line: line)
    }

    // MARK: - Red

    func testSevenDeepTheFirstWordFitsOnOneLine() {
        self.assertFirstWordOnOneLine(depth: 7)
    }

    func testSixDeepTheFirstWordFitsOnOneLine() {
        self.assertFirstWordOnOneLine(depth: 6)
    }

    /// One level deeper never gives the text MORE room.
    func testTheColumnDoesNotWidenPastTheCap() {
        let seven = self.spread(depth: 7)
        let eight = self.spread(depth: 8)
        XCTAssertLessThanOrEqual(eight, seven + 1.0, "8 deep the line spreads \(eight)pt, 7 deep only \(seven)pt")
    }

    // MARK: - Controls

    func testControlFiveDeepTheFirstWordFitsOnOneLine() {
        self.assertFirstWordOnOneLine(depth: 5)
    }

    func testControlEightDeepTheFirstWordFitsOnOneLine() {
        self.assertFirstWordOnOneLine(depth: 8)
    }

    func testControlTheColumnNarrowsFromTwoToFive() {
        XCTAssertGreaterThan(self.spread(depth: 2), self.spread(depth: 5))
    }
}
