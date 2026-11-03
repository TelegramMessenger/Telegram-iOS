#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Regression tests for the TextKit-1 (iOS 13–15 back-port) RTL caret. `BlockLayoutTK1.caretRect` used the
/// glyph's LTR pen origin (`location.x`) for every offset and the last glyph's INK right edge at end-of-text,
/// so an RTL caret sat a glyph off and the end caret overshot the container / jumped on trailing spaces. The
/// fix places the caret on the direction-correct edge of the glyph's ADVANCE box. These tests pin TK1 to the
/// TextKit-2 engine (`BlockLayout`), which is independently verified glyph-accurate (see `RTLCaretTrackingTests`).
@available(iOS 16.0, *)
final class TK1RTLCaretTests: XCTestCase {
    private func attr(_ s: String, rtl: Bool) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .natural
        ps.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        return NSAttributedString(string: s, attributes: [.font: UIFont.systemFont(ofSize: 17), .paragraphStyle: ps])
    }

    /// TK1's caret matches TK2's at EVERY offset for a wrapped RTL paragraph (the engines must agree).
    func test_tk1_matchesTK2_rtl_everyOffset() {
        let s = "مرحبا بالعالم هذا نص عربي طويل جدا لكي ينتقل الى عدة اسطر في المحرر"
        let tk1 = BlockLayoutTK1(attributedString: attr(s, rtl: true), width: 200)
        let tk2 = BlockLayout(attributedString: attr(s, rtl: true), width: 200)
        XCTAssertEqual(tk1.length, tk2.length)
        for off in 0...tk1.length {
            let a = tk1.caretRect(atOffset: off), b = tk2.caretRect(atOffset: off)
            XCTAssertEqual(a.minX, b.minX, accuracy: 1.5, "RTL caret x mismatch at offset \(off)")
            XCTAssertEqual(a.minY, b.minY, accuracy: 1.5, "RTL caret y (line) mismatch at offset \(off)")
        }
    }

    /// LTR is unchanged by the fix — TK1 still matches TK2 at every offset.
    func test_tk1_matchesTK2_ltr_everyOffset() {
        let s = "For decades they were just math now we photograph the black hole shadow here ok"
        let tk1 = BlockLayoutTK1(attributedString: attr(s, rtl: false), width: 200)
        let tk2 = BlockLayout(attributedString: attr(s, rtl: false), width: 200)
        for off in 0...tk1.length {
            let a = tk1.caretRect(atOffset: off), b = tk2.caretRect(atOffset: off)
            XCTAssertEqual(a.minX, b.minX, accuracy: 1.5, "LTR caret x mismatch at offset \(off)")
            XCTAssertEqual(a.minY, b.minY, accuracy: 1.5, "LTR caret y mismatch at offset \(off)")
        }
    }

    /// The original symptom: while TYPING on a wrapped RTL line the end caret must track LEFT (not freeze /
    /// overshoot the container edge). Build incremental prefixes and check the end caret on line 2.
    func test_tk1_rtl_typing_endCaret_tracksLeftwardOnWrappedLine() {
        let ns = "مرحبا بالعالم هذا نص عربي طويل جدا لكي ينتقل الى عدة اسطر في المحرر" as NSString
        var samples: [(x: CGFloat, y: CGFloat)] = []
        for len in 28...52 {                      // these prefixes end on the second line at width 200
            let l = BlockLayoutTK1(attributedString: attr(ns.substring(to: len), rtl: true), width: 200)
            let r = l.caretRect(atOffset: l.length)
            samples.append((r.minX, r.minY))
        }
        let y = samples[0].y
        XCTAssertGreaterThan(y, 0, "prefixes should wrap onto a second line")
        for s in samples { XCTAssertEqual(s.y, y, accuracy: 0.5) }
        XCTAssertLessThan(samples.last!.x, samples.first!.x - 100, "end caret should travel far left as the RTL line fills")
        for s in samples { XCTAssertLessThanOrEqual(s.x, 201, "end caret must not overshoot the container right edge") }
        XCTAssertGreaterThan(Set(samples.map { ($0.x / 2).rounded() }).count, 8, "end caret must not be frozen")
    }
}
#endif
