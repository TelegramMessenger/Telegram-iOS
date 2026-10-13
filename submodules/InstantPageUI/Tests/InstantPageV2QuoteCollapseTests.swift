import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

/// The pure core of collapsed quotes: which laid-out items survive a three-line budget, and how tall
/// the truncated one becomes. `layoutBlockQuote` is private and `LayoutContext` is expensive to build,
/// so this is where the arithmetic gets tested — the wiring around it is covered by the build.
final class InstantPageV2QuoteCollapseTests: XCTestCase {
    /// Narrow enough that one fixture word fits per line, so a fixture's line count is exact rather
    /// than "at least" — several tests below depend on knowing it precisely.
    private let width: CGFloat = 70.0

    /// A text item of EXACTLY `count` lines, laid out by the renderer's own `layoutTextItem`: one
    /// fixture word per line at `width`. The assertion is the fixture's own guard — a test that
    /// reasons about a three-line budget is worthless if it does not know how many lines it has.
    private func textItem(lines count: Int) -> InstantPageV2LaidOutItem {
        let font = UIFont.systemFont(ofSize: 17.0)
        let words = Array(repeating: "wwww", count: count).joined(separator: " ")
        let string = NSAttributedString(string: words, attributes: [.font: font])
        let (item, _, size) = layoutTextItem(string, boundingWidth: self.width, offset: .zero)
        guard let item else {
            preconditionFailure("layoutTextItem produced no item")
        }
        XCTAssertEqual(item.lines.count, count, "fixture must be exactly \(count) lines")
        return .text(InstantPageV2TextItem(frame: CGRect(origin: .zero, size: size), textItem: item))
    }

    private func mediaItem(height: CGFloat) -> InstantPageV2LaidOutItem {
        return .mediaPlaceholder(InstantPageV2MediaPlaceholderItem(
            frame: CGRect(x: 0.0, y: 0.0, width: self.width, height: height),
            kind: .image,
            cornerRadius: 0.0))
    }

    private func lineCount(_ item: InstantPageV2LaidOutItem) -> Int {
        return instantPageV2TextLineCount(item)
    }

    // MARK: The collapse-state rule

    /// Collapsible is not the same as collapsed: a quote no longer than its own preview shows no
    /// control at all, whatever the author set.
    func test_collapseState_shortQuoteIsNeverCollapsible() {
        XCTAssertEqual(instantPageV2QuoteCollapseState(totalTextLines: 3, authorCollapsed: true, isExpanded: false),
                       .notCollapsible)
        XCTAssertEqual(instantPageV2QuoteCollapseState(totalTextLines: 1, authorCollapsed: true, isExpanded: false),
                       .notCollapsible)
    }

    /// A quote the author did not mark stays uncollapsible however long it is — collapsibility is
    /// author-set, mirroring `TextNodeBlockQuoteData.isCollapsible`.
    func test_collapseState_authorFlagIsRequired() {
        XCTAssertEqual(instantPageV2QuoteCollapseState(totalTextLines: 20, authorCollapsed: false, isExpanded: false),
                       .notCollapsible)
    }

    func test_collapseState_longAuthorCollapsedQuote() {
        XCTAssertEqual(instantPageV2QuoteCollapseState(totalTextLines: 4, authorCollapsed: true, isExpanded: false),
                       .collapsed)
        XCTAssertEqual(instantPageV2QuoteCollapseState(totalTextLines: 4, authorCollapsed: true, isExpanded: true),
                       .expanded)
    }

    // MARK: Line counting

    func test_lineCount_countsTextItemsOnly() {
        XCTAssertGreaterThan(self.lineCount(self.textItem(lines: 5)), 3)
        XCTAssertEqual(self.lineCount(self.mediaItem(height: 100.0)), 0, "a medium costs no budget")
    }

    // MARK: Budgeting

    /// The headline case: one long paragraph truncated to the budget.
    func test_budget_truncatesTheCrossingTextItem() throws {
        let full = self.textItem(lines: 6)
        let fullLines = self.lineCount(full)
        let result = instantPageV2QuoteBudgetedItems([full], remainingLines: 3)

        XCTAssertEqual(result.reserved.count, 1)
        XCTAssertEqual(result.linesConsumed, 3)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail("still a text item") }
        XCTAssertEqual(truncated.textItem.lines.count, 3)
        XCTAssertGreaterThan(fullLines, 3, "the fixture must actually exceed the budget")
    }

    /// The height must shrink by exactly the dropped lines' pitch. This is the arithmetic that, if
    /// wrong, reserves space for text that is not drawn — a mysterious gap rather than a visible bug.
    func test_budget_truncatedHeightDropsExactlyThePitchPerLine() throws {
        let full = self.textItem(lines: 6)
        guard case let .text(original) = full else { return XCTFail() }
        let originalLines = original.textItem.lines
        let pitch = originalLines[1].frame.minY - originalLines[0].frame.minY
        let dropped = originalLines.count - 3

        let result = instantPageV2QuoteBudgetedItems([full], remainingLines: 3)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }

        XCTAssertEqual(truncated.frame.height, original.frame.height - CGFloat(dropped) * pitch, accuracy: 0.01)
    }

    /// The budget spans children: two lines from the first paragraph, one from the second.
    func test_budget_spansItems() {
        let first = self.textItem(lines: 2)
        let firstLines = self.lineCount(first)
        let second = self.textItem(lines: 6)
        let result = instantPageV2QuoteBudgetedItems([first, second], remainingLines: 3)

        XCTAssertEqual(firstLines, 2, "fixture: the first paragraph is exactly two lines")
        XCTAssertEqual(result.reserved.count, 2)
        guard case let .text(secondTruncated) = result.reserved[1] else { return XCTFail() }
        XCTAssertEqual(secondTruncated.textItem.lines.count, 1)
        XCTAssertEqual(result.linesConsumed, 3)
    }

    /// A medium before the budget runs out is kept WHOLE and costs nothing — the deliberate behaviour
    /// that makes a collapsed quote with leading media taller than three lines.
    func test_budget_mediaBeforeTheLimitIsKeptWhole() {
        let media = self.mediaItem(height: 120.0)
        let result = instantPageV2QuoteBudgetedItems([media, self.textItem(lines: 6)], remainingLines: 3)

        XCTAssertEqual(result.reserved.count, 2)
        XCTAssertEqual(result.reserved[0].frame.height, 120.0, "the medium is not clipped")
    }

    /// A medium after the budget is exhausted is absent, not clipped.
    func test_budget_mediaAfterTheLimitIsDropped() {
        let result = instantPageV2QuoteBudgetedItems(
            [self.textItem(lines: 6), self.mediaItem(height: 120.0)], remainingLines: 3)
        XCTAssertEqual(result.reserved.count, 1)
        XCTAssertTrue(result.overflow.isEmpty, "without overflow it is discarded, not carried")
    }

    /// Nothing survives once the budget is gone.
    func test_budget_zeroRemainingDropsEverything() {
        let result = instantPageV2QuoteBudgetedItems([self.textItem(lines: 2)], remainingLines: 0)
        XCTAssertTrue(result.reserved.isEmpty)
        XCTAssertEqual(result.linesConsumed, 0)
    }

    /// Content that fits is returned untouched — the same items, same heights.
    func test_budget_contentThatFitsIsUnchanged() {
        let items = [self.textItem(lines: 2)]
        let result = instantPageV2QuoteBudgetedItems(items, remainingLines: 3)
        XCTAssertEqual(result.reserved.count, 1)
        XCTAssertEqual(result.reserved[0].frame.height, items[0].frame.height)
        XCTAssertEqual(result.linesConsumed, 2)
    }

    // MARK: Overflow — the cut lines kept drawn so the collapse can animate

    /// With overflow on, the cut lines stay in the item and only the LAID-OUT height shrinks. This is
    /// what lets the quote's mask sweep them away as it closes: lines that have already been dropped
    /// from the layout cannot be animated out, they can only blink.
    func test_overflow_keepsTheCutLinesDrawnBelowTheLaidOutBox() {
        let full = self.textItem(lines: 6)
        guard case let .text(original) = full else { return XCTFail() }
        let result = instantPageV2QuoteBudgetedItems([full], remainingLines: 3, keepingOverflow: true)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }

        XCTAssertEqual(truncated.textItem.lines.count, original.textItem.lines.count, "every line is still drawn")
        XCTAssertEqual(result.linesConsumed, 3, "but only three are charged to the budget")
        XCTAssertEqual(truncated.frame.height, original.frame.height - truncated.overflowHeight, accuracy: 0.01)
    }

    /// The overflow is exactly the hidden lines — so the drawn content still ends where the untruncated
    /// item did, and the quote's height is still the three-line one.
    func test_overflow_heightIsExactlyTheHiddenLines() {
        let full = self.textItem(lines: 6)
        guard case let .text(original) = full else { return XCTFail() }
        let lines = original.textItem.lines
        let pitch = lines[1].frame.minY - lines[0].frame.minY

        let result = instantPageV2QuoteBudgetedItems([full], remainingLines: 3, keepingOverflow: true)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }

        XCTAssertEqual(truncated.overflowHeight, CGFloat(lines.count - 3) * pitch, accuracy: 0.01)
        XCTAssertEqual(truncated.frame.height + truncated.overflowHeight, original.frame.height, accuracy: 0.01)
    }

    /// Off by default, and the default must stay lossy: the spill is only invisible because the
    /// quote's mask clips it, and the mask is only opaque below the quote's bottom edge — so a quote
    /// with a caption underneath the cut has to drop the lines instead.
    func test_overflow_isOffByDefaultAndDropsTheLines() {
        let result = instantPageV2QuoteBudgetedItems([self.textItem(lines: 6)], remainingLines: 3)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }
        XCTAssertEqual(truncated.textItem.lines.count, 3)
        XCTAssertEqual(truncated.overflowHeight, 0.0)
    }

    /// Not only lines: a WHOLE item past the cut — a medium, a table, a nested quote — is carried as
    /// overflow rather than discarded. Discarding it means its view is torn down on collapse and
    /// rebuilt on expand, which blinks; carried, it stays mounted and the closing mask sweeps it away.
    func test_overflow_carriesWholeItemsPastTheCut() {
        let media = self.mediaItem(height: 120.0)
        let result = instantPageV2QuoteBudgetedItems(
            [self.textItem(lines: 6), media], remainingLines: 3, keepingOverflow: true)

        XCTAssertEqual(result.reserved.count, 1, "only the truncated paragraph is reserved for")
        XCTAssertEqual(result.overflow.count, 1, "the medium is still drawn")
        XCTAssertEqual(result.overflow[0].frame.height, 120.0, "and is never clipped or resized")
    }

    /// Even with no budget at all, overflow carries everything — so a quote whose very first child is
    /// past the cut still has its views mounted to animate.
    func test_overflow_carriesEverythingWhenNoBudgetRemains() {
        let items = [self.textItem(lines: 2), self.mediaItem(height: 40.0)]
        let result = instantPageV2QuoteBudgetedItems(items, remainingLines: 0, keepingOverflow: true)

        XCTAssertTrue(result.reserved.isEmpty)
        XCTAssertEqual(result.overflow.count, 2)
        XCTAssertEqual(result.linesConsumed, 0)
    }

    /// Sibling positioning reads the DRAWN extent, not the reserved frame — otherwise the items after
    /// a truncated paragraph would shift up on collapse instead of staying put.
    func test_drawnMaxY_includesOverflowForTextAndNothingElse() {
        let result = instantPageV2QuoteBudgetedItems([self.textItem(lines: 6)], remainingLines: 3, keepingOverflow: true)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }

        XCTAssertEqual(instantPageV2DrawnMaxY(result.reserved[0]),
                       truncated.frame.maxY + truncated.overflowHeight,
                       accuracy: 0.01)
        XCTAssertGreaterThan(instantPageV2DrawnMaxY(result.reserved[0]), truncated.frame.maxY)

        let media = self.mediaItem(height: 40.0)
        XCTAssertEqual(instantPageV2DrawnMaxY(media), media.frame.maxY, accuracy: 0.01)
    }

    /// The ellipsis marks the last VISIBLE line, not the last drawn one — overflow must not move it.
    func test_overflow_ellipsisStaysOnTheLastVisibleLine() {
        let result = instantPageV2QuoteBudgetedItems([self.textItem(lines: 6)], remainingLines: 3, keepingOverflow: true)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }
        XCTAssertNotNil(truncated.textItem.lines[2].additionalTrailingLine, "the third line is the cut")
        XCTAssertNil(truncated.textItem.lines[3].additionalTrailingLine, "the overflow carries no token")
        XCTAssertNil(truncated.textItem.lines[5].additionalTrailingLine)
    }

    // MARK: The truncation ellipsis

    /// The cut line gets the "…" `InteractiveTextComponent` puts there, and it is carried as a
    /// trailing token rather than folded into the line's own `CTLine` — the whole point being that
    /// `range`, the attachment frames and the character rects still describe the untruncated text.
    func test_truncation_appendsAnEllipsisToTheCutLine() {
        let result = instantPageV2QuoteBudgetedItems([self.textItem(lines: 6)], remainingLines: 3)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }
        let lines = truncated.textItem.lines

        XCTAssertNotNil(lines[2].additionalTrailingLine, "the cut line carries the ellipsis")
        XCTAssertNil(lines[0].additionalTrailingLine, "earlier lines are untouched")
        XCTAssertNil(lines[1].additionalTrailingLine, "earlier lines are untouched")
        XCTAssertEqual(lines[2].range, self.line(2, of: self.textItem(lines: 6)).range,
                       "the cut line's range still describes the untruncated text")
    }

    /// A line that already fills the band has nowhere to put the token, and the reference's own
    /// ellipsis would land inside the faded corner there anyway — so it is dropped rather than drawn
    /// past the text view's edge, where it would simply be clipped.
    func test_truncation_omitsTheEllipsisWhenTheLineFillsTheBand() {
        let full = self.textItem(lines: 6)
        guard case let .text(item) = full else { return XCTFail() }
        // Re-frame the same laid-out lines into a band exactly as wide as the line that will be cut.
        let tight = InstantPageV2TextItem(
            frame: CGRect(origin: item.frame.origin, size: CGSize(width: item.textItem.lines[2].frame.maxX, height: item.frame.height)),
            textItem: InstantPageTextItem(
                frame: CGRect(origin: item.textItem.frame.origin, size: CGSize(width: item.textItem.lines[2].frame.maxX, height: item.textItem.frame.height)),
                attributedString: item.textItem.attributedString,
                alignment: item.textItem.alignment,
                opaqueBackground: item.textItem.opaqueBackground,
                lines: item.textItem.lines))

        let result = instantPageV2QuoteBudgetedItems([.text(tight)], remainingLines: 3)
        guard case let .text(truncated) = result.reserved[0] else { return XCTFail() }
        XCTAssertNil(truncated.textItem.lines[2].additionalTrailingLine)
    }

    private func line(_ index: Int, of item: InstantPageV2LaidOutItem) -> InstantPageTextLine {
        guard case let .text(textItem) = item else {
            preconditionFailure("not a text item")
        }
        return textItem.textItem.lines[index]
    }

    // MARK: Chevron clearance

    /// The measurement that keeps an expanded quote from growing 10pt for nothing: a paragraph's
    /// FRAME always spans the band, so the clearance has to come from the last line's drawn edge.
    func test_chevronSideInset_textIsMeasuredByItsLastLineNotItsFrame() {
        let item = self.textItem(lines: 3)
        guard case let .text(textItem) = item else { return XCTFail() }
        let quoteFrame = CGRect(x: 0.0, y: 0.0, width: self.width, height: textItem.frame.height)
        let lastLineWidth = textItem.textItem.lines[2].frame.width

        XCTAssertLessThan(lastLineWidth, self.width, "fixture: the last line does not fill the band")
        XCTAssertEqual(instantPageV2QuoteChevronSideInset(item, quoteFrame: quoteFrame, rtl: false),
                       self.width - lastLineWidth,
                       accuracy: 0.01)
        // Measured from the item's frame instead, the clearance would be zero and every expanded
        // quote would take the extra height.
        XCTAssertEqual(quoteFrame.maxX - textItem.frame.maxX, 0.0, accuracy: 0.01)
    }

    /// Anything that is not text paints its whole frame, so its frame is the honest measurement.
    func test_chevronSideInset_nonTextIsMeasuredByItsFrame() {
        let media = self.mediaItem(height: 40.0)
        let quoteFrame = CGRect(x: 0.0, y: 0.0, width: self.width + 30.0, height: 40.0)
        XCTAssertEqual(instantPageV2QuoteChevronSideInset(media, quoteFrame: quoteFrame, rtl: false), 30.0, accuracy: 0.01)
    }

    /// Under RTL the chevron moves to the leading edge, so the clearance is measured from the other
    /// side — and a line's drawn x is reconstructed from its width, because alignment is applied at
    /// draw time and its stored origin is still the LTR one.
    func test_chevronSideInset_rtlMeasuresTheLeadingEdge() {
        let item = self.textItem(lines: 3)
        guard case let .text(textItem) = item else { return XCTFail() }
        let quoteFrame = CGRect(x: 0.0, y: 0.0, width: self.width, height: textItem.frame.height)
        let lastLineWidth = textItem.textItem.lines[2].frame.width

        XCTAssertEqual(instantPageV2QuoteChevronSideInset(item, quoteFrame: quoteFrame, rtl: true),
                       self.width - lastLineWidth,
                       accuracy: 0.01)
    }
}
