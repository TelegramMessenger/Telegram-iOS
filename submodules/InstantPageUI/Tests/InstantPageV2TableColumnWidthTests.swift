import XCTest
import UIKit
import CoreText
@testable import InstantPageUI

/// `v2TableColumnWidths`: how a V2 table shares its content width among columns. A table whose
/// minimum widths overflow the bubble compresses each column no further than its widest unbreakable
/// segment (between two line-break opportunities, `v2WidestUnbreakableSegmentWidth`) plus the cell
/// padding, up to a cap, and scrolls rather than break words mid-word (issue #20).
final class InstantPageV2TableColumnWidthTests: XCTestCase {
    private let padding: CGFloat = 26.0
    private let borderWidth: CGFloat = 2.0 / 3.0
    private let baseFloor: CGFloat = 60.0

    /// The chat table's 15pt face.
    private func string(_ text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 15.0)])
    }

    private func textWidth(_ text: String) -> CGFloat {
        let line = CTLineCreateWithAttributedString(string(text))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// A cell's widths exactly as `layoutTable` measures them, plus the cell padding: the maximally-
    /// wrapped (space-split) and single-line text widths, and the widest unbreakable segment.
    private func measure(_ text: String) -> (min: CGFloat, max: CGFloat, unbreakable: CGFloat) {
        let shortest = layoutTextItem(string(text), boundingWidth: 1000.0, offset: CGPoint(), minimizeWidth: true).0!
        let longest = layoutTextItem(string(text), boundingWidth: 1000.0, offset: CGPoint()).0!
        let minWidth = shortest.effectiveWidth() + padding
        let unbreakable = ceil(v2WidestUnbreakableSegmentWidth(string(text))) + padding
        return (minWidth, max(minWidth, longest.effectiveWidth() + padding), unbreakable)
    }

    private func columns(_ table: [[String]]) -> (min: [Int: CGFloat], max: [Int: CGFloat], unbreakable: [Int: CGFloat]) {
        var minWidths: [Int: CGFloat] = [:]
        var maxWidths: [Int: CGFloat] = [:]
        var unbreakableWidths: [Int: CGFloat] = [:]
        for row in table {
            for (i, cell) in row.enumerated() {
                let m = measure(cell)
                minWidths[i] = max(minWidths[i] ?? 1.0, m.min)
                maxWidths[i] = max(maxWidths[i] ?? 1.0, m.max)
                unbreakableWidths[i] = max(unbreakableWidths[i] ?? 1.0, m.unbreakable)
            }
        }
        return (minWidths, maxWidths, unbreakableWidths)
    }

    /// `unbreakable` defaults to `min`: for space-separated words the two measures agree.
    private func widths(min: [Int: CGFloat], max: [Int: CGFloat], unbreakable: [Int: CGFloat]? = nil, contentWidth: CGFloat) -> (widths: [Int: CGFloat], totalWidth: CGFloat) {
        return v2TableColumnWidths(
            minColumnWidths: min,
            maxColumnWidths: max,
            unbreakableColumnWidths: unbreakable ?? min,
            columnCount: min.count,
            contentBoundingWidth: contentWidth,
            borderWidth: borderWidth,
            minCompressedColumnWidth: baseFloor
        )
    }

    /// The widest unbreakable segment of a Latin cell is its widest word, without the space after it.
    func testUnbreakableSegmentIsTheWidestWord() {
        XCTAssertEqual(v2WidestUnbreakableSegmentWidth(string("Conversion, before")), textWidth("Conversion,"), accuracy: 0.5)
        XCTAssertEqual(v2WidestUnbreakableSegmentWidth(string("115.2 s")), textWidth("115.2"), accuracy: 0.5)
    }

    /// Scripts without spaces break between characters (CJK) or dictionary words (Thai), so a whole
    /// sentence is not one unbreakable token there.
    func testUnbreakableSegmentFollowsLineBreakOpportunitiesWithoutSpaces() {
        let chinese = "东京都的人口很多"
        XCTAssertEqual(v2WidestUnbreakableSegmentWidth(string(chinese)), textWidth("东"), accuracy: 1.0)
        let thai = "ภาษาไทยเป็นภาษาที่สวยงาม"
        XCTAssertLessThan(v2WidestUnbreakableSegmentWidth(string(thai)), textWidth(thai) / 2.0)
    }

    /// Issue #20: a five-column table of short words and numbers in a ~300pt bubble. Every column
    /// keeps its widest word, so no word breaks, and the table scrolls instead.
    func testFiveColumnTableKeepsWholeWordsAndScrolls() {
        let table = [
            ["Device", "Account", "Model", "Conversion, before", "Time"],
            ["iPhone", "Premium", "Galaxy S24", "12.4%", "115.2 s"],
            ["Android", "Non-premium", "Pixel 9", "8.1%", "98.7 s"],
        ]
        let (minWidths, maxWidths, unbreakableWidths) = columns(table)
        let result = widths(min: minWidths, max: maxWidths, unbreakable: unbreakableWidths, contentWidth: 300.0)

        for i in 0 ..< table[0].count {
            XCTAssertGreaterThanOrEqual(result.widths[i]!, unbreakableWidths[i]!, "column \(i) is narrower than its widest word")
        }
        XCTAssertGreaterThan(result.totalWidth, 300.0)
    }

    /// From the allocation down: at the widths it gives, CoreText wraps every cell only where the
    /// tokenizer saw a break opportunity, so no segment the floor measured is split. Latin, Chinese and
    /// Thai, in a table that overflows the bubble.
    func testCellsWrapOnlyAtSegmentBoundariesAtTheAllocatedWidths() {
        let table = [
            ["Device", "Account", "Conversion, before", "东京都的人口很多", "ภาษาไทยเป็นภาษาที่สวยงาม"],
            ["Non-premium", "115.2 s", "2024-10-24", "高级会员账户", "สวัสดีครับ"],
        ]
        let (minWidths, maxWidths, unbreakableWidths) = columns(table)
        let result = widths(min: minWidths, max: maxWidths, unbreakable: unbreakableWidths, contentWidth: 300.0)
        XCTAssertGreaterThan(result.totalWidth, 300.0)

        var wrappedCells = 0
        for row in table {
            for (i, text) in row.enumerated() {
                let cfText = text as CFString
                let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, cfText, CFRangeMake(0, CFStringGetLength(cfText)), kCFStringTokenizerUnitLineBreak, nil)!
                var boundaries = Set<Int>()
                while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
                    let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                    boundaries.insert(range.location + range.length)
                }
                let item = layoutTextItem(string(text), boundingWidth: result.widths[i]! - padding, offset: CGPoint()).0!
                if item.lines.count > 1 {
                    wrappedCells += 1
                }
                for line in item.lines.dropLast() {
                    XCTAssertTrue(boundaries.contains(line.range.upperBound), "\"\(text)\" wrapped inside a segment at \(line.range.upperBound)")
                }
            }
        }
        XCTAssertGreaterThan(wrappedCells, 2, "the table must be narrow enough for cells to wrap, or nothing is checked")
    }

    /// A Chinese table of short sentences still compresses to the bubble and wraps between
    /// characters, as before; it must not turn into a wide scrolling table.
    func testChineseTableStillFitsTheBubble() {
        let table = [
            ["设备", "账户", "转化率说明"],
            ["东京都的人口很多", "高级会员账户", "转化之前的比例数据"],
        ]
        let (minWidths, maxWidths, unbreakableWidths) = columns(table)
        let result = widths(min: minWidths, max: maxWidths, unbreakable: unbreakableWidths, contentWidth: 300.0)

        XCTAssertEqual(result.totalWidth, 300.0)
    }

    /// Two columns each holding a token wider than the cap share the bubble: the cap is half of
    /// what the columns may fill (inside the border), so they fit instead of scrolling by a point.
    func testTwoCappedColumnsFitWithoutScrolling() {
        for contentWidth: CGFloat in [300.0, 301.33, 320.0] {
            let result = widths(min: [0: 400.0, 1: 400.0], max: [0: 400.0, 1: 400.0], contentWidth: contentWidth)
            XCTAssertEqual(result.totalWidth, contentWidth, "width \(contentWidth)")
        }
    }

    /// Colspan growth can leave a column's minimum above its natural width; the floor still holds
    /// the minimum, so the spanning cell's word stays whole.
    func testFloorHoldsWhenColspanLeavesMinimumAboveNatural() {
        let result = widths(min: [0: 120.0, 1: 100.0, 2: 100.0], max: [0: 100.0, 1: 300.0, 2: 300.0], contentWidth: 300.0)

        XCTAssertGreaterThanOrEqual(result.widths[0]!, 120.0)
    }

    /// A table whose minimums fit is laid out exactly as before: minimums grown toward the natural
    /// widths to fill the content width.
    func testFittingTableIsUnchanged() {
        let result = widths(min: [0: 50.0, 1: 60.0], max: [0: 80.0, 1: 90.0], contentWidth: 320.0)

        XCTAssertEqual(result.totalWidth, 320.0)
        XCTAssertEqual(result.widths[0]!, 149.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[1]!, 320.0 - borderWidth - 149.0, accuracy: 0.001)
    }

    /// One very long token (a URL) does not make its column huge: its floor is capped at half of what
    /// the columns may fill (here `floor(299.33 / 2)`), past which the token wraps.
    func testLongTokenFloorIsCappedAtHalfTheContentWidth() {
        let result = widths(min: [0: 400.0, 1: 100.0, 2: 100.0], max: [0: 400.0, 1: 140.0, 2: 120.0], contentWidth: 300.0)

        XCTAssertEqual(result.widths[0]!, 149.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[1]!, 100.0, accuracy: 0.001)
        XCTAssertEqual(result.widths[2]!, 100.0, accuracy: 0.001)
        XCTAssertEqual(result.totalWidth, 349.0 + borderWidth, accuracy: 0.001)
    }

    /// When the capped floors fit, the table still fills the content width without scrolling, and no
    /// column is squeezed below its widest word (or the cap).
    func testCompressedTableFitsWithoutBreakingWords() {
        let minWidths: [Int: CGFloat] = [0: 250.0, 1: 70.0, 2: 60.0]
        let result = widths(min: minWidths, max: [0: 400.0, 1: 120.0, 2: 80.0], contentWidth: 300.0)

        XCTAssertEqual(result.totalWidth, 300.0)
        XCTAssertGreaterThanOrEqual(result.widths[0]!, 149.0)
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
                let floor = min(minWidths[i]!, Foundation.floor((contentWidth - borderWidth) / 2.0))
                XCTAssertGreaterThanOrEqual(result.widths[i]!, floor - 0.0001, "column \(i) at width \(contentWidth)")
            }
            if result.totalWidth == contentWidth {
                XCTAssertLessThanOrEqual(result.widths.values.reduce(0.0, +), contentWidth - borderWidth + 0.001, "width \(contentWidth)")
            }
        }
    }
}
