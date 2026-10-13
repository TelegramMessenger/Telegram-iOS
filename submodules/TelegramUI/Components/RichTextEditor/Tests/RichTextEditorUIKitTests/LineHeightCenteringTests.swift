#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The editor pins each line box to InstantPage V2's `linePitch` and places the first baseline
/// explicitly at the font's ascender — V2's own baseline position. This REPLACED an earlier model
/// that used `lineHeightMultiple` and centred the glyphs in the resulting box: a multiple cannot
/// express a pitch TIGHTER than the font's natural line height (which V2's headings want at the
/// reader theme's 0.685 line-spacing factor), and the system font's non-zero leading means the body
/// baseline does not line up by luck either.
/// Verified on BOTH engines — TextKit 2 (`BlockLayout`) and TextKit 1 (`BlockLayoutTK1`).
final class LineHeightCenteringTests: XCTestCase {
    /// A sample line in `style`, with the font and line-spacing factor it resolves to.
    private func line(_ style: ParagraphStyleName, _ text: String = "Qwefqwef") -> (NSAttributedString, UIFont, CGFloat) {
        let sheet = StyleSheet.default
        let font = sheet.font(for: style, attributes: .plain)
        let ps = sheet.paragraphStyle(for: style, attributes: .default)
        let factor = sheet.metrics.spec(for: style).lineSpacingFactor
        return (NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: ps]), font, factor)
    }

    // MARK: The pinned box

    /// The paragraph style pins the box to V2's pitch, so the box is the pitch rather than a scaled
    /// natural line height.
    func test_paragraphStyle_pinsTheLineBoxToTheV2Pitch() {
        for style in [ParagraphStyleName.body, .caption, .heading1, .heading2, .heading6] {
            let (_, font, factor) = line(style)
            let ps = StyleSheet.default.paragraphStyle(for: style, attributes: .default)
            let pitch = RichTextRenderMetrics.linePitch(font, factor: factor)
            XCTAssertEqual(ps.minimumLineHeight, pitch, accuracy: 0.0001, "\(style) min")
            XCTAssertEqual(ps.maximumLineHeight, pitch, accuracy: 0.0001, "\(style) max")
        }
    }

    /// The mechanism must express a pitch on BOTH sides of the font's natural line height, which is
    /// why `lineHeightMultiple`/`lineSpacing` cannot be used: at the chat-message factors the pitch is
    /// LOOSER than natural, and at the Instant Page reader's heading factor (0.685) it is TIGHTER.
    /// `NSParagraphStyle.lineSpacing` cannot go negative, so it could only ever express the first.
    func test_pinnedBox_expressesBothLooserAndTighterThanNaturalPitch() {
        let (_, bodyFont, bodyFactor) = line(.body)
        XCTAssertGreaterThan(RichTextRenderMetrics.linePitch(bodyFont, factor: bodyFactor), bodyFont.lineHeight,
                             "chat-message body pitch is looser than natural")

        let (_, headingFont, _) = line(.heading1)
        XCTAssertLessThan(RichTextRenderMetrics.linePitch(headingFont, factor: 0.685), headingFont.lineHeight,
                          "an Instant Page reader heading (factor 0.685) is TIGHTER than natural")
    }

    /// An explicit model-level multiple is user content and still wins — the box is not pinned then,
    /// because scaling a pinned box would apply the geometry twice.
    func test_modelLineHeightMultiple_stillOverridesThePinnedBox() {
        var attrs = ParagraphAttributes.default
        attrs.lineHeightMultiple = 2.0
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: attrs)
        XCTAssertEqual(ps.lineHeightMultiple, 2.0, accuracy: 0.0001)
        XCTAssertEqual(ps.maximumLineHeight, 0, "an explicit multiple must not be combined with a pinned box")
        XCTAssertEqual(ps.minimumLineHeight, 0)
    }

    // MARK: The headline invariant — first baseline at the ascender

    @available(iOS 16.0, *)
    func test_textKit2_firstBaselineIsAtTheAscender() {
        for style in [ParagraphStyleName.body, .caption, .heading1, .heading6] {
            let (attr, font, _) = line(style)
            let engine = BlockLayout(attributedString: attr, width: 300)
            engine.setWidth(300)
            XCTAssertEqual(engine.firstLineBaselineFromTop ?? -1,
                           RichTextRenderMetrics.firstBaselineFromTop(font),
                           accuracy: 0.01, "TK2 \(style)")
        }
    }

    func test_textKit1_firstBaselineIsAtTheAscender() {
        for style in [ParagraphStyleName.body, .caption, .heading1, .heading6] {
            let (attr, font, _) = line(style)
            let engine = BlockLayoutTK1(attributedString: attr, width: 300)
            engine.setWidth(300)
            XCTAssertEqual(engine.firstLineBaselineFromTop ?? -1,
                           RichTextRenderMetrics.firstBaselineFromTop(font),
                           accuracy: 0.01, "TK1 \(style)")
        }
    }

    // MARK: Line-to-line advance

    /// Offset of the first line after a wrap, or nil when the sample did not wrap.
    private func secondLineTop(_ engine: BlockLayoutEngine, length: Int) -> CGFloat? {
        let first = engine.caretRect(atOffset: 0).minY
        for i in 1...length {
            let y = engine.caretRect(atOffset: i).minY
            if y > first + 0.5 { return y }
        }
        return nil
    }

    @available(iOS 16.0, *)
    func test_textKit2_lineAdvanceEqualsThePitch() throws {
        let text = "one two three four five six seven eight nine ten eleven twelve thirteen"
        let (attr, font, factor) = line(.body, text)
        let engine = BlockLayout(attributedString: attr, width: 160)
        engine.setWidth(160)
        let second = try XCTUnwrap(secondLineTop(engine, length: attr.length), "the sample must wrap")
        XCTAssertEqual(second - engine.caretRect(atOffset: 0).minY,
                       RichTextRenderMetrics.linePitch(font, factor: factor), accuracy: 0.01)
    }

    func test_textKit1_lineAdvanceEqualsThePitch() throws {
        let text = "one two three four five six seven eight nine ten eleven twelve thirteen"
        let (attr, font, factor) = line(.body, text)
        let engine = BlockLayoutTK1(attributedString: attr, width: 160)
        engine.setWidth(160)
        let second = try XCTUnwrap(secondLineTop(engine, length: attr.length), "the sample must wrap")
        XCTAssertEqual(second - engine.caretRect(atOffset: 0).minY,
                       RichTextRenderMetrics.linePitch(font, factor: factor), accuracy: 0.01)
    }

    // MARK: The box that caret/selection fill keeps its full height

    @available(iOS 16.0, *)
    func test_textKit2_caretBoxKeepsTheFullPitchHeight() {
        let (attr, font, factor) = line(.body)
        let engine = BlockLayout(attributedString: attr, width: 300)
        engine.setWidth(300)
        XCTAssertEqual(engine.caretRect(atOffset: 0).height,
                       RichTextRenderMetrics.linePitch(font, factor: factor), accuracy: 0.5)
    }

    func test_textKit1_caretBoxKeepsTheFullPitchHeight() {
        let (attr, font, factor) = line(.body)
        let engine = BlockLayoutTK1(attributedString: attr, width: 300)
        engine.setWidth(300)
        XCTAssertEqual(engine.caretRect(atOffset: 0).height,
                       RichTextRenderMetrics.linePitch(font, factor: factor), accuracy: 0.5)
    }
}
#endif
