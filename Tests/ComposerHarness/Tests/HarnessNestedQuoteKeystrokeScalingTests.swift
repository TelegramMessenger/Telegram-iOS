import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, a keystroke's cost grows with quote NESTING DEPTH times the
/// number of blocks, where the document size alone predicts it. The same 160 quoted paragraphs cost
/// far more per keystroke when they are nested 16 deep than when one quote holds them all.
///
///     hosted test runner (debug), one "x" typed near the start, median of 5 (as first measured):
///       depth  4 × 10 paragraphs per level (470 chars)    12 ms
///       depth  8 × 10                        (1074 chars)  33 ms
///       depth 16 × 10                        (2332 chars) 177 ms
///       depth  4 × 40                        (1910 chars)  32 ms   ← similar size, shallow
///       controls: 400 flat paragraphs (17,489 chars) 66 ms; 64 sibling quotes 50 ms
///     The fuzz's document (seed 51 of the first extended sweep: 64 quotes nested by self-pastes into
///     a quote, 233 paragraphs) took 1.5-3.8 s per keystroke and 10 s for one Format command.
///
/// **How it was seen.** `HarnessComposerFuzzTests` with the extended op mix (`selfPaste`), 2026-09-23,
/// seed 51. The `FUZZ SLOW` lines flagged it. A `sample` of the test process while typing into a
/// 16-deep document put about 60 % of the main thread under `settleAfterEdit` →
/// `settleAuthorLinePresence` → `authorLinePresenceThatIsWrong` → `span(of:around:)` →
/// `EngineBlockRole.isWithin`.
///
/// **Suspected cause.** `authorLinePresenceThatIsWrong()` (`RichTextEngineEditorView+Containers.swift`)
/// builds a candidate, INCLUDING its `span(of:around:)` walk, for every role and every block-quote
/// ancestor of that role, and only then filters on `seen`. That is O(roles × depth × span) per
/// settle. Filtering on `seen` before computing the span (or one pass computing every quote's span)
/// removes it.
///
/// **Tier 1**, asserting SCALING rather than a time budget: the deep document may cost more per block
/// than the shallow one (each role's ancestry is longer), but not several times more.
@available(iOS 18.4, *)
final class HarnessNestedQuoteKeystrokeScalingTests: XCTestCase {
    private static func nested(depth: Int, perLevel: Int) -> ChatInputContent {
        var block = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("deepest")]), collapsed: false))
        for level in (0 ..< depth - 1).reversed() {
            let paragraphs = (0 ..< perLevel).map { HarnessEngine.paragraph("level \(level) paragraph \($0)") }
            block = .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: paragraphs + [block]), collapsed: false))
        }
        return ChatInputContent(blocks: [HarnessEngine.paragraph("Top line"), block])
    }

    /// The MINIMUM seconds for one typed character (the edit and its settle) near the document's
    /// start, over five timed keystrokes after one untimed warm-up. The minimum, not the median:
    /// scheduler noise on a loaded machine only ever ADDS time, so the fastest sample is the one that
    /// measures the code, and an O(depth) cost shows in it just the same. A median of five still let
    /// one or two slow samples through (2 of 9 runs over the threshold with the fix in place, machine
    /// load ~5.7).
    private func keystrokeSeconds(_ driver: EngineFuzzDriver, _ content: ChatInputContent) -> Double {
        HarnessComposerFuzzTests.perform(driver, start: content, ops: [.select(3, 3)])
        driver.insert("x")
        driver.settle(0.05)
        var times: [Double] = []
        for _ in 0 ..< 5 {
            // The timed window is the keystroke plus a synchronous layout pass, with Core Animation's
            // pending commit flushed OUTSIDE it, before and after. `settle(0.0)` inside the window
            // (as this test first did) sometimes performs that commit and sometimes not, so samples
            // came in two modes (manual, "A timed window never spins the run loop"; p16 conversion).
            autoreleasepool {
                driver.root.view.layoutIfNeeded()
                CATransaction.flush()
                let start = CACurrentMediaTime()
                driver.insert("x")
                driver.root.view.layoutIfNeeded()
                times.append(CACurrentMediaTime() - start)
                CATransaction.flush()
                driver.settle(0.05)
            }
        }
        return times.min() ?? 0
    }

    func testKeystrokeCostDoesNotGrowWithNestingDepth() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        _ = self.keystrokeSeconds(driver, Self.nested(depth: 2, perLevel: 10))
        // The same 150 quoted paragraphs: two levels deep, then sixteen.
        let shallow = self.keystrokeSeconds(driver, Self.nested(depth: 2, perLevel: 150))
        let deep = self.keystrokeSeconds(driver, Self.nested(depth: 16, perLevel: 10))
        let ratio = deep / max(shallow, 0.001)
        print(String(format: "HARNESS nested-quote keystroke: shallow %.3f s, deep %.3f s, ratio %.1f", shallow, deep, ratio))
        XCTAssertLessThan(ratio, 2.5, String(format: "the same paragraphs nested 16 deep cost %.1fx per keystroke (shallow %.3f s, deep %.3f s)", ratio, shallow, deep))
    }
}
