#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class SpoilerHideTests: XCTestCase {
    private func layout(_ s: String) -> BlockLayout {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body, runs: [TextRun(text: s)])
        return BlockLayout(attributedString: AttributedStringMapper().attributedString(for: block), width: 320)
    }

    /// Collects the display-only foreground rendering colors as (startOffset, length, color).
    private func renderingForegrounds(_ l: BlockLayout) -> [(Int, Int, UIColor)] {
        var out: [(Int, Int, UIColor)] = []
        let docStart = l.contentStorage.documentRange.location
        l.layoutManager.enumerateRenderingAttributes(from: docStart, reverse: false) { _, attrs, range in
            if let c = attrs[.foregroundColor] as? UIColor {
                let s = l.contentStorage.offset(from: docStart, to: range.location)
                let e = l.contentStorage.offset(from: docStart, to: range.endLocation)
                out.append((s, e - s, c))
            }
            return true
        }
        return out
    }

    func test_setSpoilerHidden_isRenderingOnly_doesNotModifyStorage() {
        let l = layout("hello world")
        let before = l.renderVersion
        let storageColorBefore = l.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        let storageColorAfter = l.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        // Storage foreground is untouched (the hide is a rendering attribute only) — exact value, any colorspace.
        XCTAssertEqual(storageColorBefore, storageColorAfter)
        XCTAssertGreaterThan(l.renderVersion, before)
        let fg = renderingForegrounds(l)
        XCTAssertTrue(fg.contains { $0.0 == 0 && $0.1 == 5 && $0.2 == .clear })
    }

    func test_setSpoilerHidden_emptyClearsPreviousHide() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        l.setSpoilerHidden([])
        XCTAssertTrue(renderingForegrounds(l).isEmpty)
    }

    func test_spoilerHide_and_ghost_coexist() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        l.setGhostForeground(.placeholderText, start: 6, end: 11)
        let fg = renderingForegrounds(l)
        XCTAssertTrue(fg.contains { $0.0 == 0 && $0.1 == 5 && $0.2 == .clear }, "spoiler hide survives a ghost set")
        XCTAssertTrue(fg.contains { $0.0 == 6 && $0.1 == 5 && $0.2 == .placeholderText }, "ghost is applied too")
    }

    func test_ghost_doesNotWipeSpoiler_onUpdate() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        l.setGhostForeground(.placeholderText, start: 6, end: 11)
        l.setGhostForeground(nil, start: 0, end: 0)
        XCTAssertTrue(renderingForegrounds(l).contains { $0.0 == 0 && $0.1 == 5 && $0.2 == .clear },
                      "clearing the ghost must not remove the spoiler hide")
    }

    func test_setSpoilerHidden_multipleRanges_hidesEach_andSkipsEmpty() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5),
                            NSRange(location: 6, length: 0),   // empty → skipped
                            NSRange(location: 6, length: 5)])
        let fg = renderingForegrounds(l)
        XCTAssertTrue(fg.contains { $0.0 == 0 && $0.1 == 5 && $0.2 == .clear }, "first word hidden")
        XCTAssertTrue(fg.contains { $0.0 == 6 && $0.1 == 5 && $0.2 == .clear }, "second word hidden")
        // The zero-length range must not produce a rendering attribute.
        XCTAssertEqual(fg.filter { $0.2 == .clear }.count, 2, "exactly two hidden ranges; the empty one is skipped")
    }

    // MARK: - Repaint-gate no-op tests (Fix 1)

    func test_setSpoilerHidden_emptyOnFreshLayout_doesNotBumpRenderVersion() {
        let l = layout("hello world")
        let before = l.renderVersion
        l.setSpoilerHidden([])
        XCTAssertEqual(l.renderVersion, before, "empty hide on a no-spoiler layout must not bump (repaint gate)")
    }

    func test_setSpoilerHidden_sameRangesTwice_secondIsNoOp() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        let after1 = l.renderVersion
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        XCTAssertEqual(l.renderVersion, after1, "re-applying identical hidden ranges must not bump renderVersion")
    }

    func test_setSpoilerHidden_afterStorageEdit_reappliesHide() {
        let l = layout("hello world")
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        // A storage edit resets the tracked ranges AND drops the rendering attributes.
        l.replace(start: 11, end: 11, with: NSAttributedString(string: "!"))
        let before = l.renderVersion
        l.setSpoilerHidden([NSRange(location: 0, length: 5)])
        XCTAssertGreaterThan(l.renderVersion, before, "after an edit dropped the hide, re-hiding must re-apply (not no-op)")
        XCTAssertTrue(renderingForegrounds(l).contains { $0.0 == 0 && $0.1 == 5 && $0.2 == .clear },
                      "the clear-foreground hide is present again after re-applying")
    }
}
#endif
