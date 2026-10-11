#if canImport(UIKit)
import XCTest
import UIKit
import CoreText
@testable import RichTextEditorCore
@testable import RichTextEditorUIKit

/// **What a substituted face's LEADING does to a pinned line, in both of the legacy canvas's
/// engines** — the measurement `RichTextFontLeading` rests on, and the boundary of what that rule
/// can reach on its own.
///
/// The engine backend's half of this is `EngineScriptLineHeightTests`, which asserts the finished
/// result: under the shipping `.safe` re-expression a paragraph lands on V2's grid in every script.
/// These cases exist because the rule has two halves that behave differently, and only one of them
/// is a property:
///
/// 1. **A line's own box** obeys `usesFontLeading`. With it off, every fragment measures exactly the
///    pinned box, in every script and both text systems. That is the whole of the one-line case, and
///    the whole of a block's last line.
/// 2. **The advance to the next line does not.** It is `box + max(lineSpacing, leading)` — the flag
///    cannot drive it below the leading, and no paragraph-style property reaches it. So a style with
///    room to spare absorbs the leading and one with `lineSpacing == 0` does not.
///
/// That second half is why the fix is complete for the engine and partial for the legacy canvas.
/// `StyleSheet` pins `minimumLineHeight == maximumLineHeight == pitch` with `lineSpacing == 0`,
/// leaving nothing to absorb with; the engine's `.safe` re-expression sets the box to
/// `ceil(fontBox)` and moves the remainder into `lineSpacing`, which is exactly the room this needs.
/// Measured across every style at its own point size, worst leading of any script against the
/// spacing `.safe` leaves: heading1 1.4695/3, heading2 1.3359/4, heading3 1.2023/2, heading4
/// 1.1621/3, heading5 1.0688/2, heading6 1.0020/2, body 1.1621/2, caption 1.0020/2 — all absorbed —
/// and pullQuote 1.0020/1, which leaks **0.001953125pt**, about 1/170 of a device pixel at 3×.
///
/// (Thai is the worst case nearly everywhere: `.SFArabic` reports leading only at 17pt, while
/// `.ThonburiUI` reports it at every size. Hebrew substitutes `TimesNewRomanPS-BoldMT` at the
/// heading weights, which has leading, and `.SFHebrew-Regular`, which has none.)
final class ScriptLineHeightTests: XCTestCase {
    private static let scripts: [(name: String, text: String)] = [
        ("latin", "Handy"),
        ("arabic", "\u{645}\u{631}\u{62d}\u{628}\u{627}"),
        ("thai", "\u{e2a}\u{e27}\u{e31}\u{e2a}\u{e14}\u{e35}"),
        ("korean", "\u{c548}\u{b155}"),
        ("hebrew", "\u{5e9}\u{5dc}\u{5d5}\u{5dd}"),
        ("devanagari", "\u{928}\u{92e}\u{938}\u{94d}\u{924}\u{947}"),
    ]

    private let font = UIFont.systemFont(ofSize: 17)

    /// The pitch V2 renders this font on, and the two ways a style can express it.
    private var pitch: CGFloat { 23 }

    private func styled(_ text: String, box: CGFloat, spacing: CGFloat) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = box
        ps.maximumLineHeight = box
        ps.lineSpacing = spacing
        return NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: ps])
    }

    /// What the face CoreText substitutes for `text` reports as its leading — read rather than
    /// tabulated, so these cases keep measuring the real thing when a system font is revised.
    private func leading(of text: String) -> CGFloat {
        var ascent: CGFloat = 0, descent: CGFloat = 0, lead: CGFloat = 0
        _ = CTLineGetTypographicBounds(
            CTLineCreateWithAttributedString(
                NSAttributedString(string: text, attributes: [.font: font])),
            &ascent, &descent, &lead)
        return lead
    }

    private func heights(_ s: NSAttributedString) -> (tk1: CGFloat, tk2: CGFloat) {
        let one = BlockLayoutTK1(attributedString: s, width: 320).boundingHeight
        guard #available(iOS 16.0, *) else { return (one, one) }
        return (one, BlockLayout(attributedString: s, width: 320).boundingHeight)
    }

    // MARK: - 1. The line box obeys the rule

    /// One line is the pinned box, whatever face was substituted onto it — including Devanagari,
    /// whose 26.08pt font box is 5pt PAST the box and is clamped, which is the control that says the
    /// pin was never the broken half.
    func test_oneLineIsThePinnedBoxInEveryScript() {
        for (name, text) in Self.scripts {
            for (label, box, spacing) in [("re-expressed", CGFloat(21), CGFloat(2)),
                                          ("stylesheet", CGFloat(23), CGFloat(0))] {
                let (tk1, tk2) = heights(styled(text, box: box, spacing: spacing))
                XCTAssertEqual(tk1, box, accuracy: 0.001, "tk1 \(name) \(label)")
                XCTAssertEqual(tk2, box, accuracy: 0.001, "tk2 \(name) \(label)")
            }
        }
    }

    // MARK: - 2. The advance does not, and a re-expressed style is what covers it

    /// **The shipping shape.** `box = ceil(fontBox) = 21`, `lineSpacing = pitch - box = 2`, and every
    /// script's leading at 17pt is below 2 — so the advance is the pitch and a wrapped paragraph
    /// lands exactly on V2's grid.
    func test_aReExpressedStyleAbsorbsTheLeadingAndLandsOnV2sGrid() {
        for (name, text) in Self.scripts {
            let s = styled(String(repeating: text + " ", count: 30), box: 21, spacing: 2)
            XCTAssertLessThan(leading(of: text), 2.0, "\(name): fixture assumes the spacing absorbs it")
            let (tk1, tk2) = heights(s)
            for (system, h) in [("tk1", tk1), ("tk2", tk2)] {
                let lines = (h - 21) / pitch
                XCTAssertEqual(lines, lines.rounded(), accuracy: 0.001,
                               "\(system) \(name): \(h) is off a 21 + k×\(pitch) grid")
            }
        }
    }

    /// **The boundary, measured rather than derived.** With `lineSpacing == 0` — which is what
    /// `StyleSheet` pins, and therefore what the legacy canvas lays out with — the advance to the
    /// next line falls back to the leading, and a wrapped paragraph spreads by that much per line.
    ///
    /// Read straight off the fragment rects instead of decomposed out of a total, because the total
    /// needs a line count and the line count is not the same across scripts at one width. The
    /// advance IS the rule; asserting it directly is what makes this a measurement.
    ///
    /// Recorded so that a later change which closes this half fails here loudly, rather than
    /// silently passing a case that has stopped describing the code.
    func test_anUnReExpressedStyleStillCarriesTheLeadingInItsAdvance() {
        let arabic = "\u{645}\u{631}\u{62d}\u{628}\u{627}"
        let lead = leading(of: arabic)
        XCTAssertEqual(lead, 1.162109375, accuracy: 0.0001, "the face's leading moved")

        for (label, box, spacing, expected) in [("stylesheet", CGFloat(23), CGFloat(0), 23 + lead),
                                                ("re-expressed", CGFloat(21), CGFloat(2), 23)] {
            let s = styled(String(repeating: arabic + " ", count: 30), box: box, spacing: spacing)
            let storage = NSTextStorage(attributedString: s)
            let manager = NSLayoutManager()
            RichTextFontLeading.suppress(in: manager)
            let container = NSTextContainer(size: CGSize(width: 320,
                                                        height: CGFloat.greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            storage.addLayoutManager(manager); manager.addTextContainer(container)
            manager.ensureLayout(for: container)

            var tops: [CGFloat] = []
            let glyphs = manager.glyphRange(for: container)
            var index = glyphs.location
            while index < NSMaxRange(glyphs) {
                var effective = NSRange(location: 0, length: 0)
                tops.append(manager.lineFragmentRect(forGlyphAt: index,
                                                     effectiveRange: &effective).minY)
                index = NSMaxRange(effective)
            }
            withExtendedLifetime(storage) {}

            XCTAssertGreaterThan(tops.count, 2, "\(label): the fixture did not wrap")
            for line in 1..<tops.count {
                XCTAssertEqual(tops[line] - tops[line - 1], expected, accuracy: 0.001,
                               "\(label): line \(line) advanced \(tops[line] - tops[line - 1]), "
                               + "expected \(expected)")
            }
        }
    }

}
#endif
