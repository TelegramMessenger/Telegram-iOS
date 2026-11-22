import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** On the engine backend, one Format command (Bold, Italic, Underline, Strikethrough;
/// Spoiler less so) over a selection holding N custom emoji, inline formulas or inline buttons costs time
/// QUADRATIC in N, all on the main thread. Hosted runner, Select All ▸ Bold over one paragraph of N atoms
/// separated by " w ", best of two:
///
///                 N=25     N=50     N=100    N=200
///     emoji       0.06 s   0.20 s   0.90 s   4.38 s
///     formula     0.06 s   0.19 s   0.79 s   4.33 s
///     inline btn  0.06 s   0.21 s   1.04 s   4.60 s
///     mention     0.015 s  0.031 s  0.077 s  0.10 s   (control: an entity, not an attachment)
///     plain text  0.004 s  0.004 s  0.005 s  0.006 s  (control)
///
/// A message with a couple of hundred custom emoji (a common "emoji art" message) freezes the composer
/// for seconds on Select All ▸ Bold, and again on the undo.
///
/// **How it was seen.** p15 (2026-09-24), performance at scale: Select All ▸ Bold / Spoiler over large
/// documents of each kind; the custom-emoji document went 0.19 s → 3.75 s from 50 to 200 emoji where
/// the others grew about linearly.
///
/// **Suspected cause.** `rederiveAtomPresentation(touching:)` (`RichTextEngineEditorView+Settle.swift`,
/// the fix for `HarnessAtomInlineFormatDriftTests`) issues one `engine.tgid_mergeAttributes(_:removingKeys:
/// inCanonicalRange:)` per attribute run of every atom, and each is an engine storage edit that
/// re-processes the whole block — O(atoms × block length). Batching the block's merges into one edit (or
/// excluding the atoms from the toggle in the first place) makes it linear.
///
/// **Tier 1**, asserting SCALING (quadrupling the atoms should cost about four times as much, not
/// sixteen), so it does not depend on the runner's speed. The minimum of five runs after a warm-up:
/// noise only adds time.
@available(iOS 18.4, *)
final class HarnessAtomFormatScalingTests: XCTestCase {
    typealias E = HarnessEdited

    private static func paragraph(_ count: Int, _ atom: (Int) -> ChatInputRun) -> ChatInputContent {
        var runs: [ChatInputRun] = []
        for index in 0 ..< count {
            runs.append(atom(index))
            runs.append(ChatInputRun(text: " w "))
        }
        return ChatInputContent(blocks: [E.paragraph(runs)])
    }

    /// Seconds for Select All ▸ Bold over `content` (the command and the layout pass it owes), best of
    /// five.
    ///
    /// **The timed window never spins the run loop.** It used to end with `settle(0.0)`, whose
    /// `RunLoop.run(until: now)` sometimes performs UIKit's pending Core Animation commit — which
    /// redraws every block canvas the command touched — and sometimes does not. Bold over 40 media
    /// blocks measured 0.050 s or 0.125 s in alternate samples, over 160 blocks 0.23 s or 0.55 s; the
    /// minimum of five picked the fast mode at 40 and, the slow mode being far more frequent there,
    /// the slow one at 160, so the media case read 9.4-11.2x where each mode alone was ~4x (p15
    /// follow-up, 2026-09-25). The commit is flushed OUTSIDE the window instead, so no sample inherits
    /// another's rendering.
    private func boldSeconds(_ driver: EngineFuzzDriver, _ content: ChatInputContent) -> Double {
        var times: [Double] = []
        for _ in 0 ..< 5 {
            autoreleasepool {
                HarnessComposerFuzzTests.arrange(driver, content)
                _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
                driver.settle(0.05)
                driver.root.view.layoutIfNeeded()
                CATransaction.flush()
                let start = CACurrentMediaTime()
                driver.format(.bold)
                driver.root.view.layoutIfNeeded()
                times.append(CACurrentMediaTime() - start)
                CATransaction.flush()
                driver.settle(0.05)
            }
        }
        return times.min() ?? 0
    }

    private func ratio(_ label: String, _ atom: @escaping (Int) -> ChatInputRun) throws -> Double {
        return try self.ratio(label, small: 40, large: 160) { Self.paragraph($0, atom) }
    }

    private func ratio(_ label: String, small smallCount: Int, large largeCount: Int, middle middleCount: Int? = nil, _ content: @escaping (Int) -> ChatInputContent) throws -> Double {
        let driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: driver.host)
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
            driver.host.panel.formulaRenderer = nil
        }
        _ = self.boldSeconds(driver, content(smallCount / 4))
        let small = self.boldSeconds(driver, content(smallCount))
        if let middleCount {
            let middle = self.boldSeconds(driver, content(middleCount))
            print(String(format: "HARNESS atom format scaling %@: %d → %.3f s (middle point)", label, middleCount, middle))
        }
        let large = self.boldSeconds(driver, content(largeCount))
        let value = large / max(small, 0.002)
        print(String(format: "HARNESS atom format scaling %@: %d → %.3f s, %d → %.3f s, ratio %.1f", label, smallCount, small, largeCount, large, value))
        return value
    }

    func testBoldOverCustomEmojiScalesLinearly() throws {
        let value = try self.ratio("emoji") { E.emoji("😀", 5_000_000_001 + Int64($0 % 7)) }
        XCTAssertLessThan(value, 8.0, String(format: "four times the custom emoji cost %.1fx for one Bold", value))
    }

    func testBoldOverFormulasScalesLinearly() throws {
        let value = try self.ratio("formula") { _ in E.formula("x^2") }
        XCTAssertLessThan(value, 8.0, String(format: "four times the formulas cost %.1fx for one Bold", value))
    }

    /// Media BLOCKS (p15 fix wave, 2026-09-25): the same re-derivation runs over every touched block, and
    /// one attribute edit per medium made Bold over 80 media cost 1.0 s against 0.26 s for 40.
    ///
    /// Also measured at 80 (printed, not asserted) so a run shows three points: after the follow-up
    /// fixes (see `boldSeconds` and `HarnessCaretMoveScalingTests`) 40 / 80 / 160 media blocks cost
    /// about 0.046 / 0.09 / 0.17 s.
    func testBoldOverMediaBlocksScalesLinearly() throws {
        let media: (Int) -> ChatInputContent = { count in
            ChatInputContent(blocks: (0 ..< count).map { E.media(Int64($0 + 1), caption: "cap \($0)") })
        }
        let value = try self.ratio("media", small: 40, large: 160, middle: 80, media)
        XCTAssertLessThan(value, 8.0, String(format: "four times the media blocks cost %.1fx for one Bold", value))
    }

    func testControlBoldOverMentionsScalesLinearly() throws {
        let value = try self.ratio("mention") { _ in E.mention("Al") }
        XCTAssertLessThan(value, 8.0, String(format: "four times the mentions cost %.1fx for one Bold", value))
    }
}
