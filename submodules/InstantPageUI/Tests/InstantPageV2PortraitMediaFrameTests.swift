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
}
