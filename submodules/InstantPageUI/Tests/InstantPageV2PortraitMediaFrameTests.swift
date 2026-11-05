import XCTest
import UIKit
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
}
