import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; provisional — a WIDTH finding):** every level of block-quote nesting
/// takes 16pt from the text column and nothing stops it: at the harness's 402pt a line 16 quotes deep is
/// 27pt wide (a character per line), and from 18 deep the column has NO width — every caret offset in the
/// line is one point, typed text is added to the model but drawn nowhere, and a selection touching it has
/// no geometry (`selectionRects` answers one `(inf, inf, 0, 0)` rect, `firstRect` infinity: nothing
/// highlighted, no handles, the edit menu placed at infinity). Reachable: nesting is a Quote over a
/// selection spanning a quote and its neighbour, repeated (no depth cap), a fragment paste, or an edited
/// message (fuzz default seed 10 built 21 levels). Narrower widths (Split View, a small phone) collapse
/// sooner. Legacy floors its quote column at 1pt (`max(…, 1)`).
///
/// **How it was seen:** p19 left it as an observation (the fuzz's geometry check exempts a line with no
/// extent); p20 measured the depth series 1-30.
///
/// **Suspected:** the engine's per-level indent (`EngineAncestor` indent contribution, the canvas's quote
/// inset) with no floor on the text width and no nesting cap. Fix-agnostic: a line at any depth keeps a
/// usable column (a floor, or the indent stops growing past some depth).
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessDeepQuoteColumnTests: XCTestCase {
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

    /// `[p "Top"] [quote×depth [p "Deep line text"]]`: the deep line is 4..<18 on the engine axis.
    private func arrange(depth: Int) -> UIView & UITextInput {
        var block = HarnessEngine.paragraph("Deep line text")
        for _ in 0 ..< depth {
            block = .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [block]), collapsed: false))
        }
        self.driver.arrange(ChatInputContent(blocks: [HarnessEngine.paragraph("Top"), block]))
        return self.driver.view as! (UIView & UITextInput)
    }

    private func assertUsableLine(depth: Int, file: StaticString = #filePath, line: UInt = #line) {
        let input = self.arrange(depth: depth)
        let begin = input.beginningOfDocument
        guard let start = input.position(from: begin, offset: 4), let end = input.position(from: begin, offset: 18),
              let range = input.textRange(from: start, to: end) else {
            XCTFail("precondition: positions", file: file, line: line)
            return
        }
        XCTAssertNotEqual(input.caretRect(for: start).origin, input.caretRect(for: end).origin, "depth \(depth): the line has no extent — every caret in it is at one point", file: file, line: line)
        let rects = input.selectionRects(for: range).map(\.rect)
        XCTAssertFalse(rects.isEmpty || rects.contains { !$0.minX.isFinite || !$0.minY.isFinite }, "depth \(depth): the line's selection has no geometry: \(rects)", file: file, line: line)
        XCTAssertTrue(input.firstRect(for: range).minX.isFinite, "depth \(depth): firstRect is at infinity", file: file, line: line)
    }

    func testALineEighteenQuotesDeepHasAColumn() {
        self.assertUsableLine(depth: 18)
    }

    func testALineTwentyTwoQuotesDeepHasAColumn() {
        self.assertUsableLine(depth: 22)
    }

    /// Control: ten deep is fine.
    func testControlALineTenQuotesDeepHasAColumn() {
        self.assertUsableLine(depth: 10)
    }
}
