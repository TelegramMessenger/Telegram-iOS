import XCTest
import CoreGraphics
@testable import NewsFeedSupport

/// A post row's geometry (Feed2 FeedRow.swift:379-460).
final class NewsPostRowLayoutTests: XCTestCase {
    func testTextColumnLeavesRoomForTheThumbnail() {
        XCTAssertEqual(newsPostTextWidth(width: 402.0, hasThumbnail: true), 272.0)
        XCTAssertEqual(newsPostTextWidth(width: 402.0, hasThumbnail: false), 370.0)
    }

    func testTitleGetsWhatTheHeaderLineLeaves() {
        // 272 − avatar 16 − 4 − (badge 16 + 4) − 4 − time 20
        XCTAssertEqual(newsPostTitleMaxWidth(textWidth: 272.0, credibilityWidth: 16.0, timeWidth: 20.0), 208.0)
        XCTAssertEqual(newsPostTitleMaxWidth(textWidth: 272.0, credibilityWidth: 0.0, timeWidth: 20.0), 228.0)
    }

    func testRowWithThumbnailMatchesTheMockup() {
        let layout = newsPostRowLayout(width: 402.0, titleSize: CGSize(width: 120.0, height: 18.0), credibilitySize: CGSize(width: 16.0, height: 16.0), timeSize: CGSize(width: 20.0, height: 16.0), textSize: CGSize(width: 272.0, height: 57.6), hasThumbnail: true, screenScale: 3.0)
        // Everything in the header line is centred on y 19 (8 + 22 / 2).
        XCTAssertEqual(layout.avatar, CGRect(x: 16.0, y: 11.0, width: 16.0, height: 16.0))
        XCTAssertEqual(layout.title, CGRect(x: 36.0, y: 10.0, width: 120.0, height: 18.0))
        XCTAssertEqual(layout.credibility, CGRect(x: 160.0, y: 11.0, width: 16.0, height: 16.0))
        XCTAssertEqual(layout.time, CGRect(x: 180.0, y: 11.0, width: 20.0, height: 16.0))
        XCTAssertEqual(layout.text.origin, CGPoint(x: 16.0, y: 30.0))
        XCTAssertEqual(layout.thumbnail, CGRect(x: 304.0, y: 8.0, width: 82.0, height: 82.0))
        XCTAssertEqual(layout.height, 98.0)
        XCTAssertEqual(layout.separator, CGRect(x: 16.0, y: 98.0 - 1.0 / 3.0, width: 370.0, height: 1.0 / 3.0))
    }

    func testTextOnlyRowIsAsTallAsItsText() {
        let layout = newsPostRowLayout(width: 402.0, titleSize: CGSize(width: 120.0, height: 18.0), credibilitySize: nil, timeSize: CGSize(width: 20.0, height: 16.0), textSize: CGSize(width: 300.0, height: 18.0), hasThumbnail: false, screenScale: 3.0)
        XCTAssertNil(layout.thumbnail)
        XCTAssertNil(layout.credibility)
        XCTAssertEqual(layout.time.minX, 160.0)
        XCTAssertEqual(layout.height, 30.0 + 18.0 + 8.0)
    }

    // Large Text Size: a row with a thumbnail grows past 98 when its text needs it.
    func testTallTextGrowsARowWithAThumbnail() {
        let layout = newsPostRowLayout(width: 402.0, titleSize: CGSize(width: 120.0, height: 24.0), credibilitySize: nil, timeSize: CGSize(width: 20.0, height: 20.0), textSize: CGSize(width: 272.0, height: 90.0), hasThumbnail: true, screenScale: 3.0)
        XCTAssertEqual(layout.height, 30.0 + 90.0 + 8.0)
    }
}
