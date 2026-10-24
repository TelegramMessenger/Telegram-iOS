import XCTest
import UIKit
@testable import InstantPageUI

/// `v2TableColumnWidths`: how a V2 table shares its content width among columns. A column's minimum
/// width is its widest unbreakable word plus the cell padding (`layoutTable` measures it with
/// `layoutTextItem(minimizeWidth: true)`); a table whose minimums overflow the bubble must keep them,
/// up to a cap, and scroll rather than break words mid-word (issue #20).
final class InstantPageV2TableColumnWidthTests: XCTestCase {
    private let padding: CGFloat = 26.0
    private let borderWidth: CGFloat = 2.0 / 3.0
    private let baseFloor: CGFloat = 60.0

    /// A cell's (min, max) width exactly as `layoutTable` measures it: the maximally-wrapped and the
    /// single-line text widths, plus the cell padding, at the chat table's 15pt face.
    private func measure(_ text: String) -> (min: CGFloat, max: CGFloat) {
        let string = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 15.0)])
        let shortest = layoutTextItem(string, boundingWidth: 1000.0, offset: CGPoint(), minimizeWidth: true).0!
        let longest = layoutTextItem(string, boundingWidth: 1000.0, offset: CGPoint()).0!
        let minWidth = shortest.effectiveWidth() + padding
        return (minWidth, max(minWidth, longest.effectiveWidth() + padding))
    }

    private func columns(_ table: [[String]]) -> (min: [Int: CGFloat], max: [Int: CGFloat]) {
        var minWidths: [Int: CGFloat] = [:]
        var maxWidths: [Int: CGFloat] = [:]
        for row in table {
            for (i, cell) in row.enumerated() {
                let m = measure(cell)
                minWidths[i] = max(minWidths[i] ?? 1.0, m.min)
                maxWidths[i] = max(maxWidths[i] ?? 1.0, m.max)
            }
        }
        return (minWidths, maxWidths)
    }

    private func widths(min: [Int: CGFloat], max: [Int: CGFloat], contentWidth: CGFloat) -> (widths: [Int: CGFloat], totalWidth: CGFloat) {
        return v2TableColumnWidths(
            minColumnWidths: min,
            maxColumnWidths: max,
            columnCount: min.count,
            contentBoundingWidth: contentWidth,
            borderWidth: borderWidth,
            minCompressedColumnWidth: baseFloor
        )
    }

    /// The minimum the text layout reports is the widest word, not the whole cell.
    func testCellMinimumIsTheWidestWord() {
        let cell = measure("Conversion, before")
        XCTAssertEqual(cell.min, measure("Conversion,").min, accuracy: 6.0)
        XCTAssertLessThan(cell.min, cell.max)
    }

    /// Issue #20: a five-column table of short words and numbers in a ~300pt bubble. Every column
    /// keeps its widest word, so no word breaks, and the table scrolls instead.
    func testFiveColumnTableKeepsWholeWordsAndScrolls() {
        let table = [
            ["Device", "Account", "Model", "Conversion, before", "Time"],
            ["iPhone", "Premium", "Galaxy S24", "12.4%", "115.2 s"],
            ["Android", "Non-premium", "Pixel 9", "8.1%", "98.7 s"],
        ]
        let (minWidths, maxWidths) = columns(table)
        let result = widths(min: minWidths, max: maxWidths, contentWidth: 300.0)

        for i in 0 ..< table[0].count {
            XCTAssertGreaterThanOrEqual(result.widths[i]!, minWidths[i]!, "column \(i) is narrower than its widest word")
        }
        XCTAssertGreaterThan(result.totalWidth, 300.0)
    }

    /// A table whose minimums fit is laid out exactly as before: minimums grown toward the natural
    /// widths to fill the content width.
    func testFittingTableIsUnchanged() {
        let result = widths(min: [0: 50.0, 1: 60.0], max: [0: 80.0, 1: 90.0], contentWidth: 320.0)

        XCTAssertEqual(result.totalWidth, 320.0)
        XCTAssertEqual(result.widths[0]!, 149.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[1]!, 320.0 - borderWidth - 149.0, accuracy: 0.001)
    }

    /// One very long token (a URL) does not make its column huge: its floor is capped at half the
    /// content width, past which the token wraps.
    func testLongTokenFloorIsCappedAtHalfTheContentWidth() {
        let result = widths(min: [0: 400.0, 1: 100.0, 2: 100.0], max: [0: 400.0, 1: 140.0, 2: 120.0], contentWidth: 300.0)

        XCTAssertEqual(result.widths[0]!, 150.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[1]!, 100.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[2]!, 100.0, accuracy: 0.001)
        XCTAssertEqual(result.totalWidth, 350.0 + borderWidth, accuracy: 0.001)
    }

    /// When the capped floors fit, the table still fills the content width without scrolling, and no
    /// column is squeezed below its widest word (or the cap).
    func testCompressedTableFitsWithoutBreakingWords() {
        let minWidths: [Int: CGFloat] = [0: 250.0, 1: 70.0, 2: 60.0]
        let result = widths(min: minWidths, max: [0: 400.0, 1: 120.0, 2: 80.0], contentWidth: 300.0)

        XCTAssertEqual(result.totalWidth, 300.0)
        XCTAssertGreaterThanOrEqual(result.widths[0]!, 150.0)
        XCTAssertGreaterThanOrEqual(result.widths[1]!, 70.0)
        XCTAssertGreaterThanOrEqual(result.widths[2]!, 60.0)
        XCTAssertEqual(result.widths.values.reduce(0.0, +), 300.0 - borderWidth, accuracy: 0.001)
    }

    /// Fractional floors (cell padding is pixel-snapped under Text Size scaling) survive the
    /// proportional pass's rounding at every bubble width: no column lands even a fraction of a point
    /// below its widest word (or the cap), and a table that does not scroll never overflows the width.
    func testNoColumnDropsBelowItsFloorAtAnyWidth() {
        let minWidths: [Int: CGFloat] = [0: 61.3, 1: 200.0, 2: 60.4, 3: 90.7]
        let maxWidths: [Int: CGFloat] = [0: 100.0, 1: 400.0, 2: 75.0, 3: 130.0]
        for step in 0 ... 800 {
            let contentWidth = 250.0 + CGFloat(step) * 0.25
            let result = widths(min: minWidths, max: maxWidths, contentWidth: contentWidth)
            for i in 0 ..< 4 {
                let floor = min(minWidths[i]!, contentWidth / 2.0)
                XCTAssertGreaterThanOrEqual(result.widths[i]!, floor - 0.0001, "column \(i) at width \(contentWidth)")
            }
            if result.totalWidth == contentWidth {
                XCTAssertLessThanOrEqual(result.widths.values.reduce(0.0, +), contentWidth - borderWidth + 0.001, "width \(contentWidth)")
            }
        }
    }
}
