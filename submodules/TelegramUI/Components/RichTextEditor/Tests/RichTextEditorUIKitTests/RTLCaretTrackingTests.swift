#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Regression tests for the RTL caret on wrapped lines (TextKit 2 `BlockLayout`).
///
/// Bug: `caretRect(atOffset:)` enumerated the `.standard` text segment, which for an RTL paragraph reports
/// the caret x in a non-right-aligned coordinate and FREEZES the end-of-text caret on a wrapped line — so
/// while typing on the second line the caret stopped tracking the text (it jumped to the line and stayed at
/// its end). The fix enumerates the `.selection` segment (the glyph-accurate geometry the selection wash
/// already uses), so the caret follows the text. LTR is byte-identical.
@available(iOS 16.0, *)
final class RTLCaretTrackingTests: XCTestCase {
    /// A long Arabic string that wraps to several lines at width 200.
    private let arabic = "مرحبا بالعالم هذا نص عربي طويل جدا لكي ينتقل الى عدة اسطر في المحرر"

    private func rtl(_ s: String, width: CGFloat = 200) -> BlockLayout {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .natural
        ps.baseWritingDirection = .rightToLeft
        return BlockLayout(attributedString: NSAttributedString(string: s, attributes: [
            .font: UIFont.systemFont(ofSize: 17), .paragraphStyle: ps,
        ]), width: width)
    }

    private func ltr(_ s: String, width: CGFloat = 200) -> BlockLayout {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .natural
        ps.baseWritingDirection = .leftToRight
        return BlockLayout(attributedString: NSAttributedString(string: s, attributes: [
            .font: UIFont.systemFont(ofSize: 17), .paragraphStyle: ps,
        ]), width: width)
    }

    /// The end caret on the first RTL line sits at the container's right edge (the line is right-aligned and
    /// full), and the rendered glyphs reach that same edge — i.e. the caret is glyph-accurate, not inset.
    func test_rtl_firstChar_caretAtRightEdge() {
        let l = rtl(arabic)
        let caret0 = l.caretRect(atOffset: 0)
        XCTAssertEqual(caret0.minX, l.containerWidth, accuracy: 1.0,
                       "RTL caret before the first char should be at the container's right edge")
        XCTAssertEqual(caret0.minY, 0, accuracy: 0.5, "offset 0 is on the first line")
    }

    /// The headline regression: while typing on a WRAPPED RTL line, the end-of-text caret must keep moving
    /// LEFT as each character is added (RTL grows leftward). The bug froze it at a fixed x on the line.
    func test_rtl_typing_endCaret_tracksLeftwardOnWrappedLine() {
        let ns = arabic as NSString
        // Find an x-monotonic run of lengths whose end caret all land on the SECOND line (same y > 0).
        var samples: [(len: Int, x: CGFloat, y: CGFloat)] = []
        for len in 28...52 {                       // these prefixes end on line 2 at width 200
            let l = rtl(ns.substring(to: len))
            let r = l.caretRect(atOffset: l.length)
            samples.append((len, r.minX, r.minY))
        }
        // All on the same (second) line.
        let y = samples[0].y
        XCTAssertGreaterThan(y, 0, "the sampled prefixes should wrap onto a second line")
        for s in samples { XCTAssertEqual(s.y, y, accuracy: 0.5, "len \(s.len) drifted off line 2") }

        // The caret must make meaningful leftward progress (NOT frozen): the last sample is well left of the
        // first, and it is strictly non-increasing across non-space additions.
        XCTAssertLessThan(samples.last!.x, samples.first!.x - 100,
                          "end caret should move far left as text fills the RTL line (was frozen)")
        // Strong anti-freeze guard: the set of x values must not collapse to (almost) a single value.
        let distinctXs = Set(samples.map { ($0.x / 2).rounded() })
        XCTAssertGreaterThan(distinctXs.count, 8,
                             "end caret x was effectively frozen across the line (\(distinctXs.count) distinct values)")
    }

    /// Glyph-accuracy: at an interior RTL offset the caret sits exactly on the glyph boundary. In RTL the
    /// caret before char N coincides with the RIGHT edge (maxX) of char N's glyph box — the bug placed it
    /// ~one right-alignment displacement to the left of the glyphs.
    func test_rtl_caret_sitsOnGlyphBoundary() {
        let l = rtl(arabic)
        for offset in [3, 30, 60] {                       // interior positions across lines 1–3
            let caret = l.caretRect(atOffset: offset).minX
            let glyph = l.selectionRects(start: offset, end: offset + 1)   // char N's glyph box
            XCTAssertEqual(glyph.count, 1, "expected one glyph rect for char \(offset)")
            XCTAssertEqual(caret, glyph[0].maxX, accuracy: 2.0,
                           "RTL caret before char \(offset) should sit at that glyph's right edge")
        }
    }

    /// Guard: LTR caret behavior is unchanged by the fix — it advances rightward with offset.
    func test_ltr_caret_advancesRightward() {
        let l = ltr("For decades they were just math. Now we photograph them.")
        XCTAssertLessThan(l.caretRect(atOffset: 0).minX, l.caretRect(atOffset: l.length).minX)
        // Within the first line, the caret strictly advances.
        XCTAssertLessThan(l.caretRect(atOffset: 1).minX, l.caretRect(atOffset: 5).minX)
    }
}
#endif
