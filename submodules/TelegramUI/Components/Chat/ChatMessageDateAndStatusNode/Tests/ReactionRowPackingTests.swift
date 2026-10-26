import XCTest
import UIKit
@testable import ChatMessageDateAndStatusNode

/// The status node reserves vertical space for the reaction buttons during the measure pass and
/// positions them during the apply pass. Those were two separate copies of one row-packing loop,
/// run against two different widths — `arguments.constrainedSize.width` when measuring and the
/// `boundingWidth` handed to the continue closure when applying — so they could disagree on the row
/// count and the node reserved rows it never drew.
///
/// The symptom was a rich-text message in a channel: the bubble is widened past the content node's
/// proposal by the author-name header, so two reactions packed onto two rows when measured and onto
/// one row when drawn, leaving a blank reaction row of dead space above the date.
///
/// `packReactionRows` is now the single routine both passes go through. These tests pin the property
/// that made the duplication a bug in the first place: **the reported size must be the true extent
/// of the returned positions**, so a caller reserving `size.height` reserves exactly what gets drawn.
final class ReactionRowPackingTests: XCTestCase {
    private let pill = CGSize(width: 50.0, height: 30.0)
    private let topInset: CGFloat = 3.0

    private func sizes(_ count: Int) -> [CGSize] {
        return Array(repeating: self.pill, count: count)
    }

    /// The invariant the two-copy version violated: whatever width it is packed at, the reported
    /// height is exactly the extent of the positions it returns.
    func test_reportedHeight_isTheExtentOfTheReturnedPositions() {
        for count in 1 ... 6 {
            for width in stride(from: 20.0, through: 400.0, by: 7.0) {
                let pack = packReactionRows(self.sizes(count), width: width, topInset: self.topInset)
                XCTAssertEqual(pack.positions.count, count, "every item is placed (count \(count), width \(width))")
                let bottom = pack.positions.map { $0.y + self.pill.height }.max() ?? self.topInset
                XCTAssertEqual(pack.size.height, bottom - self.topInset, accuracy: 0.001,
                               "reserved height vs drawn extent (count \(count), width \(width))")
            }
        }
    }

    /// Rows are `reactionButtonSpacing` apart and each starts at the leading bleed.
    func test_rowsAreEvenlyPitchedAndLeadingAligned() {
        let pack = packReactionRows(self.sizes(4), width: 110.0, topInset: self.topInset)
        let rowYs = Array(Set(pack.positions.map { $0.y })).sorted()
        XCTAssertEqual(rowYs.count, 2, "two pills per row at this width")
        XCTAssertEqual(rowYs[1] - rowYs[0], self.pill.height + reactionButtonSpacing, accuracy: 0.001)
        for y in rowYs {
            let first = pack.positions.first(where: { $0.y == y })
            XCTAssertEqual(first?.x, reactionButtonLeadingBleed, "each row starts at the bleed")
        }
    }

    /// The reported width is the widest row, so a caller can propose a bubble wide enough to hold it.
    func test_reportedWidth_isTheWidestRow() {
        let pack = packReactionRows(self.sizes(3), width: 110.0, topInset: self.topInset)
        // Two pills on the first row, one on the second.
        XCTAssertEqual(pack.size.width, self.pill.width * 2.0 + reactionButtonSpacing, accuracy: 0.001)
    }

    /// `lastRowWidth` drives the "does the date fit beside the final row" decision, so it must
    /// describe the FINAL row only — not the whole run.
    func test_lastRowWidth_describesTheFinalRowOnly() {
        let wide = packReactionRows(self.sizes(2), width: 400.0, topInset: self.topInset)
        XCTAssertEqual(wide.lastRowWidth, self.pill.width * 2.0 + reactionButtonSpacing, accuracy: 0.001,
                       "both pills share the only row")

        let narrow = packReactionRows(self.sizes(3), width: 110.0, topInset: self.topInset)
        XCTAssertEqual(narrow.lastRowWidth, self.pill.width, accuracy: 0.001,
                       "the trailing row holds one pill")
    }

    /// The regression itself, stated as the caller sees it: the same reactions must occupy ONE row
    /// once there is room for them. Measuring against a narrow width and drawing against a wide one
    /// is what produced the extra reserved row; both now come from a pack at the real width.
    func test_widthGrowth_collapsesTheReactionsBackOntoOneRow() {
        let narrow = packReactionRows(self.sizes(2), width: 60.0, topInset: self.topInset)
        XCTAssertEqual(narrow.size.height, self.pill.height * 2.0 + reactionButtonSpacing, accuracy: 0.001,
                       "two rows when the pills genuinely do not fit")

        let wide = packReactionRows(self.sizes(2), width: 200.0, topInset: self.topInset)
        XCTAssertEqual(wide.size.height, self.pill.height, accuracy: 0.001,
                       "one row — and so one row's worth of reserved height — once they fit")
        XCTAssertEqual(wide.positions.map { $0.y }, [self.topInset, self.topInset])
    }

    /// A button wider than the available width used to break the row on the very first iteration,
    /// which counted its height once for the flush and again for the trailing row: two rows reserved
    /// for one button, with one drawn. A break before anything is placed is not a row.
    func test_singleButtonWiderThanTheWidth_isStillOneRow() {
        let oversized = CGSize(width: 100.0, height: 30.0)
        let pack = packReactionRows([oversized], width: 60.0, topInset: self.topInset)
        XCTAssertEqual(pack.positions, [CGPoint(x: reactionButtonLeadingBleed, y: self.topInset)])
        XCTAssertEqual(pack.size.height, oversized.height, accuracy: 0.001)
    }

    func test_noButtons_reservesNothing() {
        let pack = packReactionRows([], width: 200.0, topInset: self.topInset)
        XCTAssertTrue(pack.positions.isEmpty)
        XCTAssertEqual(pack.size.height, 0.0)
        XCTAssertEqual(pack.lastRowWidth, 0.0)
    }
}
