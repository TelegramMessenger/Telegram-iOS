import Foundation
import UIKit
import XCTest
import AccountContext
import ChatMediaSend

final class PassportCarouselTests: XCTestCase {
    func testPassportCarouselPolicy() {
        let intents: [PassportCaptureIntent] = [.document, .multiple, .idCard, .selfie]
        for intent in intents {
            let policy = passportCarouselPolicy(intent: intent)
            XCTAssertTrue(policy.hasCameraCell, "\(intent)")
            XCTAssertTrue(policy.photoOnly, "\(intent)")
            XCTAssertEqual(policy.allowsSelection, intent == .multiple, "\(intent)")
            XCTAssertEqual(policy.selectionLimit, 10, "\(intent)")
            XCTAssertTrue(policy.onlyCrop, "\(intent)")
            XCTAssertEqual(policy.doneTitleKey, "Common.Done", "\(intent)")
            XCTAssertEqual(policy.hasICloudRow, intent != .selfie, "\(intent)")
        }
    }

    func testPassportCarouselNewestFirstCappedAt500() {
        XCTAssertEqual(passportCarouselDisplayedAssetLimit, 500)
        XCTAssertEqual(passportCarouselAssetIndices(fetchCount: 3), [2, 1, 0])
        XCTAssertEqual(passportCarouselAssetIndices(fetchCount: 0), [])
        let indices = passportCarouselAssetIndices(fetchCount: 800)
        XCTAssertEqual(indices.count, 500)
        XCTAssertEqual(indices.first, 799)
        XCTAssertEqual(indices.last, 300)
        XCTAssertEqual(indices, Array((300 ... 799).reversed()))
    }

    func testPassportCarouselMetrics() {
        XCTAssertEqual(passportCarouselCellSize, CGSize(width: 84.0, height: 84.0))
        XCTAssertEqual(passportCarouselEdgeInset, 8.0)
        XCTAssertEqual(passportCarouselHeight(zoomed: false), 100.0)
        XCTAssertEqual(passportCarouselHeight(zoomed: true), 214.0)
        XCTAssertEqual(passportCarouselLeadingInset(zoomed: false, hasCamera: true), 100.0)
        XCTAssertEqual(passportCarouselLeadingInset(zoomed: true, hasCamera: true), 8.0)
        XCTAssertEqual(passportCarouselLeadingInset(zoomed: false, hasCamera: false), 8.0)
        XCTAssertEqual(passportCarouselCameraFrame, CGRect(x: 8.0, y: 8.0, width: 84.0, height: 84.0))
        XCTAssertEqual(passportCarouselItemSize(zoomed: false, assetPixelSize: CGSize(width: 3000.0, height: 4000.0)), CGSize(width: 84.0, height: 84.0))
        XCTAssertEqual(passportCarouselItemSize(zoomed: true, assetPixelSize: CGSize(width: 3000.0, height: 4000.0)), CGSize(width: 149.0, height: 198.0))
        XCTAssertEqual(passportCarouselItemSize(zoomed: true, assetPixelSize: CGSize(width: 4000.0, height: 3000.0)), CGSize(width: 250.0, height: 198.0))
        XCTAssertEqual(passportCarouselItemSize(zoomed: true, assetPixelSize: CGSize(width: 0.0, height: 0.0)), CGSize(width: 198.0, height: 198.0))
    }
}
