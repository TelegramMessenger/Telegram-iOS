import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** The engine's two whole-document presentation passes cost time QUADRATIC in the
/// number of blocks:
///
/// - `normalisePresentation` (`RichTextEngineEditorView+Settle.swift`), which re-derives every block
///   an edit or a host command touched — Select All ▸ Monospace, a link over a selection, a settle
///   after a large paste — located each block by summing the lengths of every block before it
///   (`flatOffset(ofRoleAt:)`, which also rebuilds `attributedBlocks` per call), and applied every
///   differing run as its own `tgid_mergeAttributes`, i.e. one storage edit that re-projects the whole
///   document and runs a canvas pass over every block.
/// - `rerenderPresentation(of:)` (`RichTextEngineEditorView.swift`), the in-place re-colour behind a
///   theme change, Text Size and the code / quote geometry appliers: one `tgid_mergeAttributes` per
///   differing run of every block — so a theme change over N paragraphs was N canvas passes over N
///   blocks.
///
/// **How it was seen.** The p15 fix-wave rule "the same trap stands in `normalisePresentation` and
/// `rerenderPresentation`, which still merge per run; they have not measured superlinear yet" (editor
/// `CLAUDE.md`), measured here on 2026-09-25.
///
/// Measured before the fix: theme 60 → 0.56 s, 240 → 8.37 s (15.0); Monospace OFF 60 → 0.97 s,
/// 240 → 14.6 s (15.1). After: 0.05 → 0.16 s and 0.06 → 0.21 s.
///
/// **Fix.** Both passes collect their edits and apply them in ONE storage edit
/// (`applyPresentationEdits` → host `tgid_mergeAttributeEditsInCanonicalRanges:attributes:removingKeys:`), and `normalisePresentation` walks the block offsets once.
///
/// **Tier 1**, asserting SCALING (four times the paragraphs, about four times the time), minimum of
/// five after a warm-up. The timed window is the command and the layout pass it owes, run
/// synchronously; the Core Animation commit is flushed outside it (see
/// `HarnessAtomFormatScalingTests.boldSeconds`).
@available(iOS 18.4, *)
final class HarnessPresentationPassScalingTests: XCTestCase {
    typealias E = HarnessEdited

    /// Paragraphs with several runs each, so a pass has more than one run per block to re-derive.
    private static func paragraphs(_ count: Int) -> ChatInputContent {
        return ChatInputContent(blocks: (0 ..< count).map { index in
            E.paragraph([
                E.run("Paragraph \(index) "),
                E.run("bold") { $0.bold = true },
                E.run(" then "),
                E.run("italic") { $0.italic = true },
                E.run(" and a "),
                E.run("link") { $0.entity = .url("https://example.com/\(index)") },
                E.run(" to end."),
            ])
        })
    }

    private func timed(_ driver: EngineFuzzDriver, prepare: () -> Void, _ body: () -> Void) -> Double {
        var times: [Double] = []
        for _ in 0 ..< 5 {
            autoreleasepool {
                prepare()
                driver.root.view.layoutIfNeeded()
                CATransaction.flush()
                let start = CACurrentMediaTime()
                body()
                driver.root.view.layoutIfNeeded()
                times.append(CACurrentMediaTime() - start)
                CATransaction.flush()
                driver.settle(0.05)
            }
        }
        return times.min() ?? 0
    }

    private func ratio(_ label: String, small: Int = 60, large: Int = 240,
                       _ content: (Int) -> ChatInputContent = HarnessPresentationPassScalingTests.paragraphs,
                       _ measure: (EngineFuzzDriver, ChatInputContent) -> Double) throws -> Double {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            driver.host.updatePresentationInterfaceState { $0.updatedTheme(defaultPresentationTheme) }
            driver.settle(0.1)
            _ = driver.node.resignInputFirstResponder()
        }
        _ = measure(driver, content(small / 4))
        let smallSeconds = measure(driver, content(small))
        let largeSeconds = measure(driver, content(large))
        let value = largeSeconds / max(smallSeconds, 0.001)
        print(String(format: "HARNESS presentation pass scaling %@: %d → %.3f s, %d → %.3f s, ratio %.1f", label, small, smallSeconds, large, largeSeconds, value))
        return value
    }

    /// Select All ▸ Monospace: the inline-code command re-derives every touched block through
    /// `normalisePresentation(ofBlocksTouching:)`. Linear before the fix too (3.6): turning code ON
    /// leaves few runs for the pass to correct. Kept beside the OFF case, which was not.
    func testMonospaceOverParagraphsScalesLinearly() throws {
        let value = try self.ratio("monospace") { driver, content in
            self.timed(driver, prepare: {
                HarnessComposerFuzzTests.arrange(driver, content)
                _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
                driver.settle(0.05)
            }) {
                driver.format(.monospace)
            }
        }
        XCTAssertLessThan(value, 8.0, String(format: "four times the paragraphs cost %.1fx for one Monospace", value))
    }

    /// Select All ▸ Monospace OFF over paragraphs that are all code: the command re-derives every
    /// touched block (`normalisePresentation(ofBlocksTouching:)`), and toggling code off leaves the
    /// base-font key on every run for the pass to remove.
    func testMonospaceOffOverParagraphsScalesLinearly() throws {
        let value = try self.ratio("monospace off", { count in
            ChatInputContent(blocks: (0 ..< count).map { index in
                E.paragraph([E.run("Code paragraph \(index) "), E.run("bold code") { $0.bold = true; $0.monospace = true }, E.run(" tail")].map { run in
                    var run = run
                    run.attributes.monospace = true
                    return run
                })
            })
        }) { driver, content in
            self.timed(driver, prepare: {
                HarnessComposerFuzzTests.arrange(driver, content)
                _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
                driver.settle(0.05)
            }) {
                driver.format(.monospace)
            }
        }
        XCTAssertLessThan(value, 8.0, String(format: "four times the paragraphs cost %.1fx for one Monospace off", value))
    }

    /// Select All ▸ Link: the link command re-derives every touched block. Linear before the fix too
    /// (3.8): the link's own write leaves little for the pass to correct.
    func testLinkOverParagraphsScalesLinearly() throws {
        let value = try self.ratio("link") { driver, content in
            self.timed(driver, prepare: {
                HarnessComposerFuzzTests.arrange(driver, content)
                _ = driver.view.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
                driver.settle(0.05)
            }) {
                driver.node.applyRichTextLink("https://example.org/all")
            }
        }
        XCTAssertLessThan(value, 8.0, String(format: "four times the paragraphs cost %.1fx for one link", value))
    }

    /// A theme change re-colours every run in place (`rerenderPresentation(of:)`).
    func testThemeChangeOverParagraphsScalesLinearly() throws {
        var dark = false
        let value = try self.ratio("theme") { driver, content in
            HarnessComposerFuzzTests.arrange(driver, content)
            return self.timed(driver, prepare: {}) {
                dark.toggle()
                driver.host.updatePresentationInterfaceState { $0.updatedTheme(dark ? defaultDarkPresentationTheme : defaultPresentationTheme) }
                driver.root.view.setNeedsLayout()
            }
        }
        XCTAssertLessThan(value, 8.0, String(format: "four times the paragraphs cost %.1fx for one theme change", value))
    }
}
