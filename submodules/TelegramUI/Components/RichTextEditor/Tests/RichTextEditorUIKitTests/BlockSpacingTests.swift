#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// `richTextSpacingBetweenBlocks` mirrors `InstantPageLayoutSpacings.spacingBetweenBlocks`. These
/// tests pin the rules against hand-read values; `//submodules/InstantPageUI:InstantPageUITests`
/// pins the WHOLE pairwise table against the renderer's own function, which is the check that
/// actually stops drift.
final class BlockSpacingTests: XCTestCase {
    private let m = RichTextRenderMetrics.default

    private func gap(_ upper: RichTextBlockSpacingKind?, _ lower: RichTextBlockSpacingKind?,
                     kind: RichTextBlockSequenceKind = .topLevel) -> CGFloat {
        richTextSpacingBetweenBlocks(upper: upper, lower: lower, kind: kind, metrics: m)
    }

    /// Two body paragraphs are held apart by their own line boxes, so the gap is a bare minimum
    /// separation — NOT the sum of their paddings, and not the base spacing.
    func test_paragraphToParagraph_isOnePoint() {
        XCTAssertEqual(gap(.paragraph, .paragraph), 1.0)
    }

    /// A heading followed by body: both paddings, no base spacing between them.
    func test_headingToParagraph_isTheSumOfPaddings() {
        XCTAssertEqual(gap(.heading, .paragraph), m.headingVerticalPadding + m.blockVerticalPadding)
    }

    /// Two headings take only the UPPER's padding.
    func test_headingToHeading_isTheUpperPaddingAlone() {
        XCTAssertEqual(gap(.heading, .heading), m.headingVerticalPadding)
    }

    /// Body followed by a heading is the one paragraph pairing that DOES take the base spacing.
    func test_paragraphToHeading_includesTheBaseSpacing() {
        XCTAssertEqual(gap(.paragraph, .heading),
                       m.blockVerticalPadding + m.baseBlockSpacing + m.headingVerticalPadding)
    }

    func test_paragraphToList_andListToParagraph_areSumsOfPaddings() {
        XCTAssertEqual(gap(.paragraph, .list), m.blockVerticalPadding + m.blockVerticalPadding)
        XCTAssertEqual(gap(.list, .paragraph), m.blockVerticalPadding + m.blockVerticalPadding)
    }

    func test_listToList_isTheSumOfPaddings() {
        XCTAssertEqual(gap(.list, .list), m.blockVerticalPadding + m.blockVerticalPadding)
    }

    /// Inside a list sequence every pairing collapses to the sum of paddings.
    func test_insideAListSequence_everyPairingIsTheSumOfPaddings() {
        XCTAssertEqual(gap(.paragraph, .paragraph, kind: .list),
                       m.blockVerticalPadding + m.blockVerticalPadding)
        XCTAssertEqual(gap(.heading, .paragraph, kind: .list),
                       m.headingVerticalPadding + m.blockVerticalPadding)
    }

    /// Two bare images butt together at 1pt — the distinction that makes a photo run read as a strip.
    func test_twoRawMediaBlocks_areOnePointApart() {
        let image = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: true)
        XCTAssertEqual(gap(image, image), 1.0)
    }

    /// A credited image is NOT raw media: its credit needs room, so it takes padding + 2 and the
    /// 1pt raw-media rule does not apply.
    func test_creditedMediaIsNotRawMedia() {
        let credited = RichTextBlockSpacingKind.media(hasCredit: true, isRawMedia: true)
        let bare = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: true)
        XCTAssertNotEqual(gap(credited, bare), 1.0)
        XCTAssertEqual(gap(credited, bare),
                       (m.blockVerticalPadding + 2.0) + m.baseBlockSpacing + m.blockVerticalPadding)
    }

    /// A non-raw media block (audio, document) never takes the 1pt rule either.
    func test_audioAndDocumentAreNotRawMedia() {
        let audio = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: false)
        XCTAssertNotEqual(gap(audio, audio), 1.0)
    }

    /// Body next to a bare image gets at least 1pt, and otherwise the paddings plus one.
    func test_paragraphNextToRawMedia_takesPaddingsPlusOne() {
        let image = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: true)
        let expected = max(1.0, m.blockVerticalPadding + m.blockVerticalPadding + 1.0)
        XCTAssertEqual(gap(.paragraph, image), expected)
        XCTAssertEqual(gap(image, .paragraph), expected)
    }

    func test_detailsToDetails_isTheSumOfPaddings() {
        XCTAssertEqual(gap(.details, .details), m.blockVerticalPadding + m.blockVerticalPadding)
    }

    /// A details block followed by anything else takes its own adjacency spacing, not the base.
    func test_detailsToParagraph_usesTheDetailsAdjacentSpacing() {
        XCTAssertEqual(gap(.details, .table),
                       m.blockVerticalPadding + m.detailsAdjacentSpacing + m.blockVerticalPadding)
    }

    /// Anything not named by a rule falls through to padding + base + padding — a code block, a
    /// table, a quote.
    func test_unnamedPairings_fallThroughToPaddingBasePadding() {
        let expected = m.blockVerticalPadding + m.baseBlockSpacing + m.blockVerticalPadding
        XCTAssertEqual(gap(.preformatted, .table), expected)
        XCTAssertEqual(gap(.blockQuote, .preformatted), expected)
        XCTAssertEqual(gap(.table, .pullQuote), expected)
        XCTAssertEqual(gap(.formula, .blockQuote), expected)
    }

    // MARK: Sequence edges

    func test_leadingEdge_paragraphTakesPaddingPlusTwo() {
        XCTAssertEqual(gap(nil, .paragraph), m.blockVerticalPadding + 2.0)
    }

    func test_leadingEdge_tableTakesPaddingPlusSeven() {
        XCTAssertEqual(gap(nil, .table), m.blockVerticalPadding + 7.0)
    }

    func test_trailingEdge_paragraphTakesPaddingPlusTwo() {
        XCTAssertEqual(gap(.paragraph, nil), m.blockVerticalPadding + 2.0)
    }

    /// The table's edge padding is asymmetric: 7 above, 4 below.
    func test_trailingEdge_tableTakesPaddingPlusFour() {
        XCTAssertEqual(gap(.table, nil), m.blockVerticalPadding + 4.0)
    }

    /// Media is flush at the edge it butts against — this is the only place the flush flags are read.
    func test_edges_bareMediaIsFlush() {
        let bare = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: true)
        XCTAssertEqual(gap(nil, bare), 0.0)
        XCTAssertEqual(gap(bare, nil), 0.0)
    }

    /// A credited image is flush above but NOT below — its credit sits under it.
    func test_edges_creditedMediaIsFlushAboveOnly() {
        let credited = RichTextBlockSpacingKind.media(hasCredit: true, isRawMedia: true)
        XCTAssertEqual(gap(nil, credited), 0.0)
        XCTAssertEqual(gap(credited, nil), m.blockVerticalPadding + 2.0)
    }

    func test_bothNil_isZero() {
        XCTAssertEqual(gap(nil, nil), 0.0)
    }

    /// `edgeSpacingReduction` trims the OUTER spacing only, clamped at 0, so a host that insets the
    /// whole document gives that inset back out of the document's own padding.
    func test_edgeSpacingReduction_trimsEdgesOnlyAndClampsAtZero() {
        var trimmed = RichTextRenderMetrics.default
        trimmed.edgeSpacingReduction = 3.0
        let edge = richTextSpacingBetweenBlocks(upper: nil, lower: .paragraph, kind: .topLevel, metrics: trimmed)
        XCTAssertEqual(edge, m.blockVerticalPadding + 2.0 - 3.0)

        let interior = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph, kind: .topLevel, metrics: trimmed)
        XCTAssertEqual(interior, 1.0, "an interior gap must not be trimmed")

        var huge = RichTextRenderMetrics.default
        huge.edgeSpacingReduction = 1000
        XCTAssertEqual(richTextSpacingBetweenBlocks(upper: nil, lower: .paragraph, kind: .topLevel, metrics: huge), 0.0)
    }
}
#endif
