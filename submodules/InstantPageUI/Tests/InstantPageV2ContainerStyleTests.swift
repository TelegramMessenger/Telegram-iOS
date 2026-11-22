import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

private func makeImageBlock(_ id: Int64) -> InstantPageBlock {
    return .image(
        id: EngineMedia.Id(namespace: 0, id: id),
        caption: InstantPageCaption(text: .empty, credit: .empty),
        url: nil,
        webpageId: nil,
        spoiler: false
    )
}

/// A page laid out without a rounded container around it (a chat message without a bubble) rounds its own media, code
/// bands and quotes. `layoutInstantPageV2` needs `PresentationStrings`, which a test process cannot build, so these pin
/// the style value and the helpers the layout reads it through.
final class InstantPageV2ContainerStyleTests: XCTestCase {
    private let bubbleless = InstantPageV2ContainerStyle.bubbleless(mainRadius: 16.0, blockCornerRadius: 10.0, codeBlockMinimumPadding: 12.0, separateMediaSpacing: 8.0)

    func testBubbleStyleIsMastersConstants() {
        let style = InstantPageV2ContainerStyle.bubble
        XCTAssertEqual(style.minimumMediaCornerRadius, 0.0)
        XCTAssertEqual(style.codeBlockMinimumPadding, 0.0)
        XCTAssertEqual(style.codeBlockCornerRadius, 0.0)
        XCTAssertEqual(style.quoteCornerRadius, 6.0)
        XCTAssertEqual(style.separateMediaSpacing, 0.0)
        XCTAssertTrue(style.mediaBleeds)
    }

    func testBubblelessQuotesRoundAtTen() {
        XCTAssertEqual(self.bubbleless.quoteCornerRadius, 10.0)
        XCTAssertEqual(self.bubbleless.codeBlockCornerRadius, 10.0)
        XCTAssertFalse(self.bubbleless.mediaBleeds)
    }

    func testBubblelessMediaRoundAtLeastTheMainRadius() {
        XCTAssertEqual(instantPageV2MediaCornerRadius(0.0, style: self.bubbleless), 16.0)
        XCTAssertEqual(instantPageV2MediaCornerRadius(20.0, style: self.bubbleless), 20.0)
        XCTAssertEqual(instantPageV2MediaCornerRadius(0.0, style: .bubble), 0.0)
    }

    func testCollageRoundsOnlyItsOutline() {
        XCTAssertEqual(instantPageV2CollageCellRoundedCorners(top: true, bottom: false, left: true, right: false), [.layerMinXMinYCorner])
        XCTAssertEqual(instantPageV2CollageCellRoundedCorners(top: true, bottom: true, left: false, right: true), [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        XCTAssertEqual(instantPageV2CollageCellRoundedCorners(top: false, bottom: false, left: false, right: false), [])
    }

    func testSeparateMediaStandEightApart() {
        XCTAssertEqual(instantPageV2BlockGap(1.0, upper: makeImageBlock(1), lower: makeImageBlock(2), style: self.bubbleless), 8.0)
        XCTAssertEqual(instantPageV2BlockGap(1.0, upper: makeImageBlock(1), lower: makeImageBlock(2), style: .bubble), 1.0)
        XCTAssertEqual(instantPageV2BlockGap(12.0, upper: makeImageBlock(1), lower: .paragraph(.plain("Text")), style: self.bubbleless), 12.0)
        XCTAssertEqual(instantPageV2BlockGap(5.0, upper: nil, lower: makeImageBlock(2), style: self.bubbleless), 5.0)
    }

    func testCodeBandKeepsTwelvePointsOfPadding() {
        XCTAssertEqual(instantPageV2CodeBandStandalonePadding(bleed: .none, horizontalInset: 0.0, bandMinX: 0.0, style: self.bubbleless), 12.0)
        XCTAssertEqual(instantPageV2CodeBandStandalonePadding(bleed: .none, horizontalInset: 9.0, bandMinX: 0.0, style: self.bubbleless), 3.0)
        XCTAssertEqual(instantPageV2CodeBandStandalonePadding(bleed: .none, horizontalInset: 0.0, bandMinX: 0.0, style: .bubble), 0.0)
        XCTAssertEqual(instantPageV2CodeBandStandalonePadding(bleed: InstantPageV2ChildBleed(minXSide: 9.0, maxXSide: 9.0), horizontalInset: 9.0, bandMinX: 0.0, style: self.bubbleless), 0.0)
    }
}
