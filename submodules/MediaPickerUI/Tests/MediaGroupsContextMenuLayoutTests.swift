import XCTest
import CoreGraphics

final class MediaGroupsContextMenuLayoutTests: XCTestCase {
    private let itemSize = CGSize(width: 220.0, height: 61.0)

    func testItemHeightAddsVerticalInsetsAndSpacing() {
        XCTAssertEqual(MediaGroupsContextMenuLayout.itemHeight(titleHeight: 21.0, subtitleHeight: 17.0), 61.0)
    }

    func testContentHeightPadsTopAndBottom() {
        XCTAssertEqual(MediaGroupsContextMenuLayout.contentHeight(itemCount: 4, itemHeight: 61.0), 10.0 + 244.0 + 10.0)
        XCTAssertEqual(MediaGroupsContextMenuLayout.contentHeight(itemCount: 0, itemHeight: 61.0), 0.0)
    }

    func testItemFramesStartBelowTopPadding() {
        XCTAssertEqual(MediaGroupsContextMenuLayout.itemFrame(index: 0, itemHeight: 61.0, width: 220.0), CGRect(x: 0.0, y: 10.0, width: 220.0, height: 61.0))
        XCTAssertEqual(MediaGroupsContextMenuLayout.itemFrame(index: 2, itemHeight: 61.0, width: 220.0).minY, 132.0)
    }

    func testVisibleIndicesAccountForTopPaddingAndClampToCount() {
        XCTAssertEqual(MediaGroupsContextMenuLayout.visibleIndices(minY: -180.0, maxY: 295.0 + 180.0, itemHeight: 61.0, itemCount: 4), 0 ..< 4)
        XCTAssertEqual(MediaGroupsContextMenuLayout.visibleIndices(minY: 0.0, maxY: 71.0, itemHeight: 61.0, itemCount: 10), 0 ..< 1)
        XCTAssertEqual(MediaGroupsContextMenuLayout.visibleIndices(minY: 0.0, maxY: 72.0, itemHeight: 61.0, itemCount: 10), 0 ..< 2)
        XCTAssertEqual(MediaGroupsContextMenuLayout.visibleIndices(minY: 0.0, maxY: 100.0, itemHeight: 61.0, itemCount: 0), 0 ..< 0)
    }

    func testTextAndThumbnailUseContextMenuInsets() {
        let frames = MediaGroupsContextMenuLayout.textFrames(itemSize: self.itemSize, titleSize: CGSize(width: 80.0, height: 21.0), subtitleSize: CGSize(width: 20.0, height: 17.0))
        XCTAssertEqual(frames.title, CGRect(x: 18.0, y: 11.0, width: 80.0, height: 21.0))
        XCTAssertEqual(frames.subtitle, CGRect(x: 18.0, y: 33.0, width: 20.0, height: 17.0))
        XCTAssertEqual(MediaGroupsContextMenuLayout.iconFrame(itemSize: self.itemSize), CGRect(x: 176.0, y: 18.0, width: 24.0, height: 24.0))
        XCTAssertEqual(MediaGroupsContextMenuLayout.maxTextWidth(itemWidth: 220.0), 150.0)
    }

    func testSeparatorIsInsetOnBothSides() {
        XCTAssertEqual(MediaGroupsContextMenuLayout.separatorFrame(itemSize: self.itemSize, thickness: 1.0 / 3.0), CGRect(x: 18.0, y: 61.0 - 1.0 / 3.0, width: 184.0, height: 1.0 / 3.0))
    }

    func testHighlightIsInsetAndRounded() {
        let frame = MediaGroupsContextMenuLayout.highlightFrame(itemSize: self.itemSize)
        XCTAssertEqual(frame, CGRect(x: 10.0, y: 0.0, width: 200.0, height: 61.0))
        XCTAssertEqual(MediaGroupsContextMenuLayout.highlightCornerRadius(highlightHeight: frame.height), 20.0)
        XCTAssertEqual(MediaGroupsContextMenuLayout.highlightCornerRadius(highlightHeight: 30.0), 15.0)
    }

    func testSeparatorsAroundHighlightedRowAndAfterLastRowAreHidden() {
        XCTAssertFalse(MediaGroupsContextMenuLayout.isSeparatorHidden(index: 0, itemCount: 4, highlightedIndex: nil))
        XCTAssertTrue(MediaGroupsContextMenuLayout.isSeparatorHidden(index: 3, itemCount: 4, highlightedIndex: nil))
        XCTAssertTrue(MediaGroupsContextMenuLayout.isSeparatorHidden(index: 0, itemCount: 4, highlightedIndex: 1))
        XCTAssertTrue(MediaGroupsContextMenuLayout.isSeparatorHidden(index: 1, itemCount: 4, highlightedIndex: 1))
        XCTAssertFalse(MediaGroupsContextMenuLayout.isSeparatorHidden(index: 2, itemCount: 4, highlightedIndex: 1))
    }
}
