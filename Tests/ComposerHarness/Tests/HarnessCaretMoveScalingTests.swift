import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, moving the caret costs time QUADRATIC in the number of
/// blocks. Every selection change marks the spoiler display decoration dirty (a spoiler reveals under
/// the caret), so the next canvas pass re-decorates EVERY block, and the decorator
/// (`spoilerDecorated`, `RichTextEngineEditorView+Spoiler.swift`) located each block by summing the
/// lengths of all the blocks before it — rebuilding `attributedBlocks` and `tgid_blockIdentifiers`
/// per call. It did so for every block, spoiler or not. The same walk ran on every content update of
/// a Format command (Select All ▸ Bold over 160 media blocks: 25 ms of the command in the decorator,
/// 181 ms at 480).
///
/// A second, smaller quadratic term sat in the same pass: `-[IDBlockStackCanvasView
/// updateForDocumentChange:width:]` re-inserted every block canvas at its index, and
/// `insertSubview:atIndex:` looks the view up in `subviews` even when it does not move.
///
/// **How it was seen.** The p15 fix wave's follow-up (2026-09-25): profiling
/// `HarnessAtomFormatScalingTests.testBoldOverMediaBlocksScalesLinearly` with probes in the canvas
/// pass showed the per-block content update growing from 23 µs to 49 µs per block from 40 to 160
/// media blocks; the decorator's block walk was all of the growth.
///
/// **Fix.** The decorator asks `tgid_canonicalStart(ofBlockIdentifier:)`, answered from the engine
/// view's identity cache (rebuilt once per `blocks` array); the canvas pass skips an insert whose view
/// is already at its index while the hierarchy is unchanged.
///
/// **Tier 1**, asserting SCALING (four times the blocks, about four times the time), minimum of
/// five after a warm-up. The timed window is the selection change and the layout pass it owes,
/// run synchronously — the run loop is not spun inside it, so a Core Animation commit never lands in
/// some samples and not others.
@available(iOS 18.4, *)
final class HarnessCaretMoveScalingTests: XCTestCase {
    private static func paragraphs(_ count: Int) -> ChatInputContent {
        return ChatInputContent(blocks: (0 ..< count).map { HarnessEngine.paragraph("Paragraph number \($0) of the document") })
    }

    /// Seconds for one caret move and the layout it owes, best of five.
    private func caretMoveSeconds(_ driver: EngineFuzzDriver, _ content: ChatInputContent) -> Double {
        HarnessComposerFuzzTests.arrange(driver, content)
        driver.setViewSelection(NSRange(location: 5, length: 0))
        driver.settle(0.05)
        var times: [Double] = []
        for index in 0 ..< 6 {
            autoreleasepool {
                let start = CACurrentMediaTime()
                driver.setViewSelection(NSRange(location: 3 + index % 2 * 4, length: 0))
                driver.root.view.layoutIfNeeded()
                let elapsed = CACurrentMediaTime() - start
                if index > 0 { times.append(elapsed) }
                driver.settle(0.02)
            }
        }
        return times.min() ?? 0
    }

    func testCaretMoveScalesLinearly() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        _ = self.caretMoveSeconds(driver, Self.paragraphs(75))
        let small = self.caretMoveSeconds(driver, Self.paragraphs(300))
        let large = self.caretMoveSeconds(driver, Self.paragraphs(1200))
        let value = large / max(small, 0.0005)
        print(String(format: "HARNESS caret move scaling: 300 → %.4f s, 1200 → %.4f s, ratio %.1f", small, large, value))
        XCTAssertLessThan(value, 6.0, String(format: "four times the paragraphs cost %.1fx for one caret move", value))
    }
}
