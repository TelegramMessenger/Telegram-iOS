import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

final class InstantPageV2PortraitMediaFrameTests: XCTestCase {
    private func frame(
        _ naturalSize: CGSize,
        boundingWidth: CGFloat = 320.0,
        flush: Bool = true,
        horizontalInset: CGFloat = 0.0,
        capHeight: Bool = true
    ) -> (frame: CGRect, scaledSize: CGSize, cornerRadius: CGFloat) {
        return instantPageV2MediaFrame(
            naturalSize: naturalSize,
            flush: flush,
            cornerRadius: 8.0,
            boundingWidth: boundingWidth,
            horizontalInset: horizontalInset,
            capHeight: capHeight
        )
    }

    func testPortraitHeightCapShrinksWidthInsteadOfLetterboxing() {
        let result = self.frame(CGSize(width: 1080, height: 2400))
        XCTAssertEqual(result.scaledSize, CGSize(width: 144, height: 320))
        XCTAssertEqual(result.frame, CGRect(x: 0, y: 0, width: 144, height: 320))
        XCTAssertEqual(result.cornerRadius, 0)
    }

    func testLandscapeRetainsFullWidthBleed() {
        let result = self.frame(CGSize(width: 1920, height: 1080))
        XCTAssertEqual(result.scaledSize, CGSize(width: 320, height: 180))
        XCTAssertEqual(result.frame, CGRect(x: 0, y: 0, width: 324, height: 180))
    }

    func testSquareRetainsFullWidthBleed() {
        let result = self.frame(CGSize(width: 800, height: 800))
        XCTAssertEqual(result.scaledSize, CGSize(width: 320, height: 320))
        XCTAssertEqual(result.frame.size.width, 324)
    }

    func testSmallMediaIsNotUpscaledOrBled() {
        let result = self.frame(CGSize(width: 90, height: 120))
        XCTAssertEqual(result.scaledSize, CGSize(width: 90, height: 120))
        XCTAssertEqual(result.frame.size.width, 90)
    }

    func testAbsoluteHeightLimitPreservesAspectRatio() {
        let result = self.frame(CGSize(width: 2000, height: 8000), boundingWidth: 1500)
        XCTAssertEqual(result.scaledSize, CGSize(width: 250, height: 1000))
        XCTAssertEqual(result.frame.size.width, 250)
    }

    func testUncappedCoverKeepsOriginalWidthAndHeight() {
        let result = self.frame(CGSize(width: 1080, height: 2400), capHeight: false)
        XCTAssertEqual(result.scaledSize, CGSize(width: 320, height: 711))
        XCTAssertEqual(result.frame.size.width, 324)
    }

    func testMissingDimensionsPreservePlaceholderSize() {
        let result = self.frame(.zero)
        XCTAssertEqual(result.scaledSize, CGSize(width: 320, height: 0))
    }

    func testNonFlushMediaUsesInsetButKeepsAspectRatio() {
        let result = self.frame(
            CGSize(width: 1080, height: 2400),
            flush: false,
            horizontalInset: 12
        )
        XCTAssertEqual(result.scaledSize, CGSize(width: 133, height: 296))
        XCTAssertEqual(result.frame, CGRect(x: 12, y: 0, width: 133, height: 296))
        XCTAssertEqual(result.cornerRadius, 8)
    }

    func testPortraitCentersWhenTextMakesBubbleWiderThanMedia() {
        let original = self.frame(CGSize(width: 1080, height: 2400)).frame
        let centered = instantPageV2CenteredStandaloneMediaFrame(original, contentWidth: 260)
        XCTAssertEqual(centered, CGRect(x: 58, y: 0, width: 144, height: 320))
    }

    func testMediaOnlyBubbleRemainsCompactAndLeftAnchored() {
        let original = self.frame(CGSize(width: 1080, height: 2400)).frame
        let centered = instantPageV2CenteredStandaloneMediaFrame(original, contentWidth: 144)
        XCTAssertEqual(centered, original)
    }

    func testCenteringUsesFittedBubbleWidthNotOriginalMaximum() {
        let original = self.frame(CGSize(width: 1080, height: 2400)).frame
        let centered = instantPageV2CenteredStandaloneMediaFrame(original, contentWidth: 200)
        XCTAssertEqual(centered.minX, 28)
        XCTAssertEqual(centered.maxX, 172)
    }

    func testFullBleedMediaDoesNotShift() {
        let original = self.frame(CGSize(width: 1920, height: 1080)).frame
        XCTAssertEqual(original.width, 324)
        XCTAssertEqual(instantPageV2CenteredStandaloneMediaFrame(original, contentWidth: 320), original)
    }

    func testCenteringPreservesVerticalPositionAndSize() {
        let frame = CGRect(x: 0, y: 82, width: 144, height: 320)
        let result = instantPageV2CenteredStandaloneMediaFrame(frame, contentWidth: 231)
        XCTAssertEqual(result, CGRect(x: 43, y: 82, width: 144, height: 320))
    }

    func testMultiplePortraitMediaCenterIndependentlyInOneWideBubble() {
        let first = self.frame(CGSize(width: 1080, height: 2400)).frame.offsetBy(dx: 0, dy: 40)
        let second = self.frame(CGSize(width: 800, height: 1600)).frame.offsetBy(dx: 0, dy: 380)
        let firstCentered = instantPageV2CenteredStandaloneMediaFrame(first, contentWidth: 260)
        let secondCentered = instantPageV2CenteredStandaloneMediaFrame(second, contentWidth: 260)
        XCTAssertEqual(firstCentered, CGRect(x: 58, y: 40, width: 144, height: 320))
        XCTAssertEqual(secondCentered, CGRect(x: 50, y: 380, width: 160, height: 320))
    }

    func testMixedLandscapeAndPortraitKeepIndependentGeometry() {
        let landscape = self.frame(CGSize(width: 1920, height: 1080)).frame
        let portrait = self.frame(CGSize(width: 1080, height: 2400)).frame.offsetBy(dx: 0, dy: 200)
        let landscapeAfter = instantPageV2CenteredStandaloneMediaFrame(landscape, contentWidth: 320)
        let portraitAfter = instantPageV2CenteredStandaloneMediaFrame(portrait, contentWidth: 320)
        XCTAssertEqual(landscapeAfter, landscape, "full-bleed media must not move")
        XCTAssertEqual(portraitAfter, CGRect(x: 88, y: 200, width: 144, height: 320))
    }

    func testTwoDifferentPortraitWidthsDoNotChangeBubbleWidth() {
        let narrow = self.frame(CGSize(width: 1080, height: 2400)).frame
        let wide = self.frame(CGSize(width: 800, height: 1600)).frame
        let widestContentWidth: CGFloat = 160
        let narrowCentered = instantPageV2CenteredStandaloneMediaFrame(narrow, contentWidth: widestContentWidth)
        let wideCentered = instantPageV2CenteredStandaloneMediaFrame(wide, contentWidth: widestContentWidth)
        XCTAssertEqual(narrowCentered.minX, 8)
        XCTAssertEqual(wideCentered.minX, 0)
        XCTAssertEqual(narrowCentered.maxX, 152)
        XCTAssertEqual(wideCentered.maxX, widestContentWidth)
    }

    // A synthetic webpage is sufficient for geometry-only tests: the layout
    // neither fetches media nor opens the webpage.
    private func mediaImage(_ id: Int64, frame: CGRect, webpage: TelegramMediaWebpage) -> InstantPageV2LaidOutItem {
        let representation = TelegramMediaImageRepresentation(
            dimensions: PixelDimensions(width: 1080, height: 2400),
            resource: LocalFileMediaResource(fileId: id),
            progressiveSizes: [],
            immediateThumbnailData: nil
        )
        let image = TelegramMediaImage(
            imageId: EngineMedia.Id(namespace: Namespaces.Media.CloudImage, id: id),
            representations: [representation],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        let media = InstantPageMedia(index: Int(id), media: .image(image), url: nil, caption: nil, credit: nil)
        return .mediaImage(InstantPageV2MediaImageItem(
            frame: frame,
            cornerRadius: 0,
            media: media,
            webPage: webpage,
            attributes: [],
            fit: true
        ))
    }

    private func geometryWebpage() -> TelegramMediaWebpage {
        return TelegramMediaWebpage(
            webpageId: EngineMedia.Id(namespace: Namespaces.Media.LocalWebpage, id: -1),
            content: .Pending(0, nil)
        )
    }

    func testFinalBubbleWidthCentersTwoMediaButDoesNotMutateMeasuredLayout() {
        let webpage = self.geometryWebpage()
        let original = InstantPageV2Layout(
            contentSize: CGSize(width: 180, height: 640),
            items: [
                self.mediaImage(1, frame: CGRect(x: 18, y: 0, width: 144, height: 320), webpage: webpage),
                self.mediaImage(2, frame: CGRect(x: 0, y: 320, width: 180, height: 320), webpage: webpage)
            ],
            detailsIndices: [],
            standaloneMediaIndices: [0, 1]
        )
        let displayed = original.centeredStandaloneMedia(toContentWidth: 260)

        XCTAssertEqual(original.contentSize.width, 180)
        XCTAssertEqual(original.items[0].frame.minX, 18)
        XCTAssertEqual(original.items[1].frame.minX, 0)

        XCTAssertEqual(displayed.contentSize.width, 260)
        XCTAssertEqual(displayed.items[0].frame, CGRect(x: 58, y: 0, width: 144, height: 320))
        XCTAssertEqual(displayed.items[1].frame, CGRect(x: 40, y: 320, width: 180, height: 320))
    }

    func testFinalLayoutDoesNotGrowForMediaOnlyBubble() {
        let webpage = self.geometryWebpage()
        let original = InstantPageV2Layout(
            contentSize: CGSize(width: 144, height: 320),
            items: [self.mediaImage(3, frame: CGRect(x: 0, y: 0, width: 144, height: 320), webpage: webpage)],
            detailsIndices: [],
            standaloneMediaIndices: [0]
        )
        let displayed = original.centeredStandaloneMedia(toContentWidth: 144)
        XCTAssertEqual(displayed.contentSize.width, 144)
        XCTAssertEqual(displayed.items[0].frame.minX, 0)
    }

    func testUntrackedCollageMediaDoesNotShiftWhenHeaderExpandsBubble() {
        let webpage = self.geometryWebpage()
        let tile = self.mediaImage(4, frame: CGRect(x: 0, y: 0, width: 90, height: 120), webpage: webpage)
        let original = InstantPageV2Layout(
            contentSize: CGSize(width: 180, height: 120),
            items: [tile],
            detailsIndices: [],
            standaloneMediaIndices: []
        )
        let displayed = original.centeredStandaloneMedia(toContentWidth: 260)
        XCTAssertEqual(displayed.items[0].frame, tile.frame)
        XCTAssertEqual(displayed.contentSize.width, 260)
    }

    func testFinalBottomMediaFrameTracksCenteredImageStatusPill() {
        let webpage = self.geometryWebpage()
        var original = InstantPageV2Layout(
            contentSize: CGSize(width: 153, height: 320),
            items: [self.mediaImage(5, frame: CGRect(x: 4, y: 0, width: 144, height: 320), webpage: webpage)],
            detailsIndices: [],
            standaloneMediaIndices: [0]
        )
        original.formattedDateUpdatePeriod = 10
        XCTAssertNotNil(lastFullWidthMediaFrame(in: original))

        let displayed = original.centeredStandaloneMedia(toContentWidth: 260)
        XCTAssertEqual(displayed.items[0].frame.minX, 58)
        XCTAssertNil(lastFullWidthMediaFrame(in: displayed), "header expansion changes the full-width gate")
        XCTAssertEqual(lastBottomVisualMediaFrame(in: displayed), displayed.items[0].frame)
        XCTAssertEqual(displayed.formattedDateUpdatePeriod, 10)
        XCTAssertEqual(original.items[0].frame.minX, 4)
    }
}
