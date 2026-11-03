import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting a long rich document costs time SUPERLINEAR in its
/// length, all of it on the main thread inside `paste:`. Measured on K1 (debug build, CPU seconds of the
/// app process for one markdown paste of N paragraphs, each `Some **bold** and *italic* text with
/// `code` number i.`):
///
///     N=25: 0.23 s   N=50: 0.59 s   N=100: 2.3 s   N=200: 12.9 s   N=250: 23.8 s
///     a 1000-line mixed document (200 headings, 200 formatted paragraphs, 400 list items): 149 s,
///     the composer frozen for ~2.5 minutes and the process growing by ~1.25 GB
///
/// Pasting the SAME document as the editor's own fragment (copy, then paste) costs the same (N=200:
/// 12.4 s), so it is the application of a large document, not the markdown parser. 500 plain list items
/// (no inline formatting) cost 1.3 s, so the per-block cost grows with formatted runs.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam, "very large markdown" area: `paste:` scheduled through
/// lldb, the process's CPU time read with `ps` (no debugger attached while it ran), and a `sample` of the
/// main thread during the N=250 paste.
///
/// **Suspected cause (from the sample).** 2685 of 2950 main-thread samples are under
/// `-[IDBlockTextView id_reconcileDerivedStateForDocumentChange:]` → `-[IDBlockStackCanvasView
/// updateForDocumentChange:width:]`, of which ~1740 are the per-block `id_emptyLineAttributesForIdentifier:`
/// / `id_emptyLineCaretOffsetForIdentifier:` callbacks → `installEmptyLineProviders()` closures →
/// `RichTextEngineEditorView.role(forEngineIdentity:)`, whose fallback while `isApplyingHostDocument` is
/// `engine.tgid_blockIdentifiers.firstIndex(of:)` — the whole identifier array rebuilt and bridged
/// (`swift_dynamicCast` dominates the leaf frames) for every block, i.e. O(n²).
///
/// **Tier 1**, and asserting SCALING rather than a time budget, so it does not depend on the runner's
/// speed: eight times the document should cost about eight times as much, not sixty.
final class HarnessLargeRichPasteScalingTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    private func markdown(paragraphs: Int) -> String {
        return (0 ..< paragraphs).map { "Some **bold** and *italic* text with `code` number \($0)." }.joined(separator: "\n\n")
    }

    /// Seconds spent inside one `paste:` of `paragraphs` formatted paragraphs into an empty composer.
    private func pasteSeconds(paragraphs: Int) throws -> CFTimeInterval {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer {
            _ = node.resignInputFirstResponder()
            host.setInputContent(ChatInputContent())
            HarnessEngine.settle(root)
        }
        let textView = try HarnessEngine.textView(in: root)
        UIPasteboard.general.string = self.markdown(paragraphs: paragraphs)

        // The timed window is the paste plus a synchronous layout pass, with Core Animation's pending
        // commit flushed OUTSIDE it, before and after, and no run-loop spin inside it (manual, "A timed
        // window never spins the run loop"; p16 conversion). The pass is inside so a superlinear
        // layout the paste leaves for later is still counted.
        var elapsed: CFTimeInterval = 0.0
        autoreleasepool {
            root.view.layoutIfNeeded()
            CATransaction.flush()
            let start = CACurrentMediaTime()
            _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
            root.view.layoutIfNeeded()
            elapsed = CACurrentMediaTime() - start
            CATransaction.flush()
        }
        HarnessEngine.settle(root)

        let pasted = node.currentInputContent().content
        XCTAssertGreaterThanOrEqual(pasted.blocks.count, paragraphs, "precondition: the paste did not land as \(paragraphs) paragraphs")
        XCTAssertFalse(pasted.plainText.contains("**"), "precondition: the paste did not parse as markdown")
        return elapsed
    }

    func testPasteCostGrowsRoughlyLinearlyWithDocumentLength() throws {
        // Warm up once so first-use costs (fonts, caches) do not land on the small case.
        _ = try self.pasteSeconds(paragraphs: 10)
        // The MINIMUM of three per size: scheduler noise on a loaded machine only adds time, so the
        // fastest sample measures the code, and O(n²) shows in it just the same. One sample per size
        // let a single slow paste decide the ratio.
        func fastest(_ paragraphs: Int) throws -> CFTimeInterval {
            return try (0 ..< 3).map { _ in try self.pasteSeconds(paragraphs: paragraphs) }.min() ?? 0
        }
        // 8x the paragraphs, 100 against 800 (p16 fix wave): a larger n² share than 4x at 50 / 200, so
        // a smaller quadratic term still shows. NEUTER-CHECKED on the term this paste still depends
        // on: with `IDCanonicalTextStorageAdapter.fixAttributesInRange:` fixing through the document
        // again (one document rebuild per attribute fix, not one working copy adopted once) it reads
        // 48.3 (100: 0.97 s, 800: 46.8 s), red. The finding's other two terms are no longer on this
        // path at all: `role(forEngineIdentity:)`'s array lookup and the canvas's `-subviews` per
        // block (3.4 at 4x, p16 roam), and the projection's per-read rebuild (8.1 at 8x, i.e. linear)
        // — a paste now reads neither per block, so no size can make a test see them.
        let small = try fastest(100)
        let large = try fastest(800)
        let ratio = large / max(small, 0.001)
        print(String(format: "HARNESS large rich paste: 100 %.3f s, 800 %.3f s, ratio %.1f", small, large, ratio))
        // Linear would be ~8x; measured on K1 before the fix ~22x for 4x the paragraphs.
        XCTAssertLessThan(ratio, 16.0,
                          String(format: "8x the paragraphs cost %.1fx the time (100: %.2f s, 800: %.2f s)", ratio, small, large))
    }
}
