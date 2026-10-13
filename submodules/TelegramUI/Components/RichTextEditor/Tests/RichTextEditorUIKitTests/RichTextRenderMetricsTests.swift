#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `RichTextRenderMetrics` owns InstantPage V2's line geometry as formulas, so the editor and the
/// renderer share one definition instead of two coincidentally-equal implementations. These tests
/// pin the formulas against hand-computed values; `//submodules/InstantPageUI:InstantPageUITests`
/// pins them against `layoutTextItem`'s real output.
final class RichTextRenderMetricsTests: XCTestCase {
    private let body = UIFont.systemFont(ofSize: 17)

    /// V2's `fontLineHeight`: floor(ascender + descender), with descender negative — a REDUCED box,
    /// not the font's natural line height.
    func test_reducedLineHeight_isFlooredAscentPlusDescent() {
        let expected = floor(body.ascender + body.descender)
        XCTAssertEqual(RichTextRenderMetrics.reducedLineHeight(body), expected)
        XCTAssertLessThan(RichTextRenderMetrics.reducedLineHeight(body), body.lineHeight)
    }

    /// V2's `fontLineSpacing`: floor(reducedLineHeight * factor).
    func test_lineSpacing_isFlooredProductOfReducedHeightAndFactor() {
        let L = RichTextRenderMetrics.reducedLineHeight(body)
        XCTAssertEqual(RichTextRenderMetrics.lineSpacing(body, factor: 0.9), floor(L * 0.9))
        XCTAssertEqual(RichTextRenderMetrics.lineSpacing(body, factor: 1.0), floor(L * 1.0))
    }

    /// V2 advances a line by `lineAscent + fontLineSpacing`, and `lineAscent` starts at `fontLineHeight`.
    func test_linePitch_isReducedHeightPlusLineSpacing() {
        let L = RichTextRenderMetrics.reducedLineHeight(body)
        let S = RichTextRenderMetrics.lineSpacing(body, factor: 0.9)
        XCTAssertEqual(RichTextRenderMetrics.linePitch(body, factor: 0.9), L + S)
    }

    /// V2 starts the line stack at `lineBoxTopInset = ascender - reducedLineHeight` and puts the first
    /// baseline `lineAscent` below that, which collapses to exactly the ascender.
    func test_firstBaselineFromTop_isTheAscender() {
        XCTAssertEqual(RichTextRenderMetrics.firstBaselineFromTop(body), body.ascender, accuracy: 0.0001)
    }

    /// V2's item height: `ceil(lines.last.maxY + fontDescentBelowBaseline)`, i.e. a single line measures
    /// ascender + |descender| ROUNDED UP (NOT the pitch), and each further line adds one pitch.
    ///
    /// The ceiling matters: `layoutTextItem` returns `ceil(height)` so that stacking blocks by adding
    /// sizes to a running origin keeps every origin whole. Without it the editor's blocks were ~0.7pt
    /// short each and drifted cumulatively down the document.
    func test_textHeight_singleLineIsCeiledAscentPlusDescent_andEachFurtherLineAddsOnePitch() {
        let single = ceil(body.ascender - body.descender)
        XCTAssertEqual(RichTextRenderMetrics.textHeight(body, factor: 0.9, lineCount: 1), single, accuracy: 0.0001)
        XCTAssertEqual(single, 21, "17pt body: 20.29 rounds up to a whole 21pt box")
        let pitch = RichTextRenderMetrics.linePitch(body, factor: 0.9)
        XCTAssertEqual(RichTextRenderMetrics.textHeight(body, factor: 0.9, lineCount: 3),
                       single + 2 * pitch, accuracy: 0.0001)
    }

    /// The pitch is integral by construction (both terms are floors), which is WHY ceiling the whole
    /// height expression is equivalent to ceiling only `ascender + |descender|` — and therefore why
    /// `trailingHeightCorrection` can stay independent of the line count.
    func test_linePitch_isIntegral() {
        for factor in [CGFloat(0.9), 1.0, 0.685] {
            let pitch = RichTextRenderMetrics.linePitch(body, factor: factor)
            XCTAssertEqual(pitch, pitch.rounded(), "pitch must be whole for factor \(factor)")
        }
    }

    func test_textHeight_zeroLinesIsZero() {
        XCTAssertEqual(RichTextRenderMetrics.textHeight(body, factor: 0.9, lineCount: 0), 0)
    }

    /// The default metrics are the chat-bubble values: headings at factor 1.0, body at 0.9.
    func test_defaultMetrics_matchTheChatBubbleTable() {
        let m = RichTextRenderMetrics.default
        XCTAssertEqual(m.body.size, 17)
        XCTAssertEqual(m.body.lineSpacingFactor, 0.9)
        XCTAssertEqual(m.body.style, .sans)
        XCTAssertEqual(m.caption.size, 15)
        XCTAssertEqual(m.caption.lineSpacingFactor, 1.0)
        XCTAssertEqual(m.table.size, 15)
        XCTAssertEqual(m.codeBlock.size, 15)          // V2 overrides the theme's 14pt with 15pt
        XCTAssertEqual(m.codeBlock.style, .monospace)
        // The language line carries no font of its own — both surfaces derive it from `body` + bold,
        // the way the quote author is derived. What the contract carries is the block's geometry.
        XCTAssertEqual(m.code.verticalInset, 14)
        XCTAssertEqual(m.code.languageSpacing, 3)
    }

    /// The heading ladder, serif medium at V2's sizes.
    func test_defaultMetrics_headingLadderIsSerifMediumAtV2Sizes() {
        let m = RichTextRenderMetrics.default
        let expected: [(ParagraphStyleName, CGFloat)] = [
            (.heading1, 22), (.heading2, 20), (.heading3, 18),
            (.heading4, 17), (.heading5, 16), (.heading6, 15)
        ]
        for (style, size) in expected {
            let spec = m.spec(for: style)
            XCTAssertEqual(spec.size, size, "\(style)")
            XCTAssertEqual(spec.style, .serif, "\(style)")
            XCTAssertEqual(spec.weight, .medium, "\(style)")
            XCTAssertEqual(spec.lineSpacingFactor, 1.0, "\(style)")
        }
    }

    func test_spec_mapsBodyAndCaptionToTheirCategories() {
        let m = RichTextRenderMetrics.default
        XCTAssertEqual(m.spec(for: .body).size, 17)
        XCTAssertEqual(m.spec(for: .caption).size, 15)
    }

    /// Block-rhythm scalars mirror `InstantPageMetrics(scale: 1.0)`.
    func test_defaultMetrics_blockRhythmScalars() {
        let m = RichTextRenderMetrics.default
        XCTAssertEqual(m.baseBlockSpacing, 8)
        XCTAssertEqual(m.blockVerticalPadding, 4)
        XCTAssertEqual(m.headingVerticalPadding, 8)
        XCTAssertEqual(m.dividerVerticalPadding, 4)
        XCTAssertEqual(m.detailsAdjacentSpacing, 4)
        XCTAssertEqual(m.edgeSpacingReduction, 0)
    }
}
#endif
