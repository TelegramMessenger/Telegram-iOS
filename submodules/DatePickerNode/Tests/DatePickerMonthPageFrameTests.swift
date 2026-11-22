import Foundation
import CoreGraphics
import XCTest
@testable import DatePickerNode

/// Where `DatePickerNode` places its month pages.
///
/// The grid is at most 390pt wide and centred in the picker, which clips to its bounds. A picker wider than that (the
/// chat-search calendar in landscape, iPhone Duo folded) has margins beside the grid, and pages stepped one page width
/// apart rested in them: slivers of the previous and next months showed on both sides of the current one.
final class DatePickerMonthPageFrameTests: XCTestCase {
    private let gridWidth: CGFloat = 390.0
    private let gridHeight: CGFloat = 300.0

    // The grid's container is centred in the picker, as `DatePickerNode.updateLayout` places it.
    private func pickerFrame(indexOffset: Int, transitionFraction: CGFloat = 0.0, pickerWidth: CGFloat) -> CGRect {
        let pageSize = CGSize(width: min(self.gridWidth, pickerWidth), height: self.gridHeight)
        let containerMinX = (pickerWidth - pageSize.width) / 2.0
        return datePickerMonthPageFrame(indexOffset: indexOffset, transitionFraction: transitionFraction, pageSize: pageSize, pickerWidth: pickerWidth).offsetBy(dx: containerMinX, dy: 0.0)
    }

    func testNeighbourPagesRestOutsideAPickerWiderThanTheGrid() {
        for pickerWidth: CGFloat in [391.0, 408.0, 418.0, 444.0, 647.0] {
            let current = self.pickerFrame(indexOffset: 0, pickerWidth: pickerWidth)
            XCTAssertGreaterThanOrEqual(current.minX, 0.0, "\(pickerWidth)")
            XCTAssertLessThanOrEqual(current.maxX, pickerWidth, "\(pickerWidth)")

            let previous = self.pickerFrame(indexOffset: -1, pickerWidth: pickerWidth)
            XCTAssertLessThanOrEqual(previous.maxX, 0.0, "\(pickerWidth): the previous month shows in the left margin")
            let next = self.pickerFrame(indexOffset: 1, pickerWidth: pickerWidth)
            XCTAssertGreaterThanOrEqual(next.minX, pickerWidth, "\(pickerWidth): the next month shows in the right margin")
        }
    }

    // Phones whose picker is no wider than the grid keep the placement they had.
    func testPagesStepOnePageWidthWhenTheGridFillsThePicker() {
        for pickerWidth: CGFloat in [353.0, 380.0, 390.0] {
            let pageSize = CGSize(width: pickerWidth, height: self.gridHeight)
            for indexOffset in -1 ... 1 {
                for transitionFraction: CGFloat in [-0.3, 0.0, 0.25] {
                    let frame = datePickerMonthPageFrame(indexOffset: indexOffset, transitionFraction: transitionFraction, pageSize: pageSize, pickerWidth: pickerWidth)
                    let expected = CGRect(origin: CGPoint(x: CGFloat(indexOffset) * pageSize.width + transitionFraction * pageSize.width, y: 0.0), size: pageSize)
                    XCTAssertEqual(frame, expected, "\(pickerWidth), \(indexOffset), \(transitionFraction)")
                }
            }
        }
    }

    // A swipe's fraction is its translation over the picker's width, so the pages follow the finger.
    func testSwipedPagesFollowTheFinger() {
        let pickerWidth: CGFloat = 444.0
        let translation: CGFloat = 100.0
        let transitionFraction = translation / pickerWidth
        for indexOffset in -1 ... 1 {
            let resting = self.pickerFrame(indexOffset: indexOffset, pickerWidth: pickerWidth)
            let swiped = self.pickerFrame(indexOffset: indexOffset, transitionFraction: transitionFraction, pickerWidth: pickerWidth)
            XCTAssertEqual(swiped.minX - resting.minX, translation, accuracy: 0.001, "\(indexOffset)")
        }
        // A swipe across the whole picker brings the next month to where the current one rests.
        let next = self.pickerFrame(indexOffset: 1, transitionFraction: -1.0, pickerWidth: pickerWidth)
        XCTAssertEqual(next, self.pickerFrame(indexOffset: 0, pickerWidth: pickerWidth))
    }
}
